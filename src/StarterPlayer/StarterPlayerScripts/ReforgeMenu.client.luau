-- Smith menu, like Elden Ring's blacksmith: opens from a smith's prompt (a model
-- tagged "Smith") over a full-screen close-up of the smith (ShopFocus, which also
-- makes E leave). Down the left the powers and weapons you own with their +level;
-- beside them, for the one you pick, three tabs: STRENGTHEN (the next +level,
-- the damage change and the materials needed against what you hold), AFFINITY
-- (the two slots, opened at +3 and +7, where you choose the affinity and see the
-- value each would have) and AWAKEN (powers only: at +10, Essence awakens it
-- further). The level, affinities and awakening are the Reforge_<Set> attributes
-- the server mirrors; every action goes through the ReforgeAction remote
-- (ReforgeServer), which does all the checking. Closes when you walk away, or
-- when another menu opens (Menus).
-- It's in the shops' look (ShopMenu): black bars along the top and bottom (E LEAVE and your yen in
-- the bottom one), the smith on the right, and down the left, over a dark fading off the edge, the
-- smith's line, their title big and their name on a chip in the forge's orange (the ShopSubtitle,
-- ShopTitle and ShopkeeperName attributes), then what you own as rows, the picked one lit, with its
-- tabs in a pane beside them. The server's replies are subtitles under the smith.
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local ReforgeRules = require(ReplicatedStorage:WaitForChild("ReforgeRules"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local MenuFooter = require(script.Parent:WaitForChild("MenuFooter"))
local ShopFocus = require(script.Parent:WaitForChild("ShopFocus"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local remote = ReplicatedStorage:WaitForChild(ReforgeConfig.Remote)
local player = Players.LocalPlayer

local PAD = 64 -- the screen's left edge to the column (as on the title menu and the shops)
local COLUMN_WIDTH = 400 -- a little narrower than a shop's, for the pane beside it
local COLUMN_GAP = 26 -- between the top bar and the column, and the column and the bottom bar
local HEADER = 150 -- the column's top: the smith's line, their title big, their name on a chip
local BOTTOM_BAR = 44 -- the black bar along the bottom; the top one is as tall as Roblox's band
local ROBLOX_BAR_FALLBACK = 58 -- Roblox's band across the top, while GetGuiInset still says 0
local SHADE_SHARE = 0.62 -- how far across the screen the dark fades off the left edge
local SPEECH_AT = 0.85 -- the middle of the smith's subtitles, across the screen (under them: CAMERA_SHIFT)
local SPEECH_WIDTH = 0.26
local OPEN_TIME = 0.45 -- the bars closing in, the column sliding in
local HOVER_TIME = 0.15
local NUMBER_WIDTH = 28 -- a row's number, at its left
local ROW_HEIGHT = 58 -- a set's row: name, what it is
local BADGE_SIZE = 30 -- a set's tier letter
local DETAIL_GAP = 28 -- between the list and the picked set's pane
local DETAIL_WIDTH = 340
local DETAIL_TOP = 102 -- the pane's top: level with the smith's chip, as a shop's item preview
local CAMERA_SHIFT = 3.6 -- studs the smith sits right of centre, clear of the list and the pane
local Style = HudConfig.Style
local Theme = HudConfig.HubTheme
local BACKGROUND = Style.Glass -- Modern Warfare's smoked glass; the text on a filled button
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local GOLD = Color3.fromRGB(255, 205, 60)
local FORGE = Color3.fromRGB(255, 140, 60)
local DANGER = Color3.fromRGB(226, 75, 74)
local TIER_ORDER = { S = 1, A = 2, B = 3, C = 4 }
local TABS = {
	{ id = "strengthen", title = "STRENGTHEN" },
	{ id = "affinity", title = "AFFINITY" },
	{ id = "awaken", title = "AWAKEN" },
}

local function make(className, props)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.Highway
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- a set's name as everywhere else: its Tool's ("Aido" -> "Deus Ex Machina"), else "IridescentRequiem" ->
-- "Iridescent Requiem"
local function displayName(setName)
	local set = SkillSetConfig.Sets[setName]
	return set and set.tool or (string.gsub(setName, "(%l)(%u)", "%1 %2"))
end

-- the sets the player owns, best tier first
local function ownedSets()
	local owned = {}
	local list = player:GetAttribute(SkillSetConfig.OwnedSetsAttribute) or ""
	for setName in string.gmatch(list, "[^,]+") do
		if SkillSetConfig.Sets[setName] then
			table.insert(owned, setName)
		end
	end
	table.sort(owned, function(a, b)
		local tierA = TIER_ORDER[SkillSetConfig.Sets[a].tier] or 99
		local tierB = TIER_ORDER[SkillSetConfig.Sets[b].tier] or 99
		if tierA ~= tierB then
			return tierA < tierB
		end
		return a < b
	end)
	return owned
end

local function stateOf(setName)
	return ReforgeRules.DecodeState(player:GetAttribute(ReforgeConfig.SetAttribute(setName)))
end

local function isPower(setName)
	local set = SkillSetConfig.Sets[setName]
	return set ~= nil and set.kind == "power"
end

local function tierColor(setName)
	local tier = SkillSetConfig.Tiers[SkillSetConfig.Sets[setName].tier]
	return tier and tier.color or SkillSetConfig.NoTierColor
end

-- the materials the player carries, read when asked for
local bag = setmetatable({}, {
	__index = function(_, key)
		return player:GetAttribute(ReforgeConfig.MaterialAttribute(key)) or 0
	end,
})

-- "+5.5% damage" for an affinity's value
local function describeValue(id, value)
	local config = ReforgeConfig.Modifier(id)
	local percent = string.format("%.1f%%", value / 10)
	if config.kind == "damage" then
		return string.format("+%s damage", percent)
	elseif config.kind == "cooldown" then
		return string.format("-%s cooldowns", percent)
	elseif config.kind == "status" then
		return string.format("%s chance to apply %s", percent, config.status)
	end
	return string.format("heal %s of damage dealt", percent)
end

local function percent(bonus)
	return string.format("+%d%%", math.floor(bonus * 100 + 0.5))
end

local gui = make("ScreenGui", {
	Name = "ReforgeMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 30,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local function tween(instance, time, props)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tweenObject:Play()
	return tweenObject
end

-- the colour to write on a fill of `color`
local function onColor(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B > 0.4 and BACKGROUND or TEXT
end

-- the shops' look: black bars along the top and the bottom, the dark fading off the left edge for
-- the column, the right left clear for the smith. The frame over the whole screen is Active, so a
-- click anywhere is taken by the menu and never punches or shoots.
local backdrop = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = true })
local shade = make("Frame", { Parent = backdrop, Size = UDim2.fromScale(SHADE_SHARE, 1), BackgroundColor3 = Theme.Nav, BorderSizePixel = 0 })
make("UIGradient", {
	Parent = shade,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	}),
})
local topBar = make("Frame", { Parent = backdrop, Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4 })
local bottomBar = make("Frame", {
	Parent = backdrop,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 4,
})
for _, edge in ipairs({ { topBar, 1 }, { bottomBar, 0 } }) do
	make("Frame", {
		Parent = edge[1],
		AnchorPoint = Vector2.new(0, edge[2]),
		Position = UDim2.fromScale(0, edge[2]),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Edge,
		BackgroundTransparency = Theme.EdgeTransparency,
		BorderSizePixel = 0,
		ZIndex = 4,
	})
end
-- the player's yen, on the right of the bottom bar (E LEAVE is on its left)
local balance = label(bottomBar, {
	Text = "",
	RichText = true,
	Font = Style.MonoFont,
	TextSize = 12,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -PAD, 0.5, 0),
	Size = UDim2.new(0.5, -PAD, 0, 16),
	ZIndex = 5,
})

-- the column down the left: the smith's line with the forge's orange before it, their title big,
-- their name on a chip with a rule running on, then what you own (it scrolls on a short screen)
local column = make("Frame", { Parent = backdrop, BackgroundTransparency = 1, ZIndex = 5 })
make("Frame", { Parent = column, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = FORGE, BorderSizePixel = 0, ZIndex = 5 })
local subtitle = label(column, { Text = "REFORGE", Font = Style.MonoFont, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -34, 0, 14), ZIndex = 5 })
local title = label(column, {
	Text = "SMITH",
	Font = Style.TitleFont,
	TextScaled = true,
	Position = UDim2.fromOffset(-2, 18),
	Size = UDim2.new(1, 0, 0, 72),
	ZIndex = 5,
})
make("UITextSizeConstraint", { Parent = title, MaxTextSize = 72 })
local chip = make("TextLabel", {
	Parent = column,
	Font = Style.TitleFont,
	TextSize = 20,
	TextColor3 = onColor(FORGE),
	BackgroundColor3 = FORGE,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(1, 102),
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 5,
})
local chipRule = make("Frame", { Parent = column, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = MUTED, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 5 })
local panel = make("ScrollingFrame", {
	Parent = column,
	Position = UDim2.fromOffset(0, HEADER),
	Size = UDim2.new(1, 0, 1, -HEADER),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = MUTED,
	ScrollBarImageTransparency = 0.4,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 5,
})
-- the sets, as tall as they need
local list = make("Frame", { Parent = panel, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 })
make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder })

-- the picked set's pane, beside the list: its name and +level, what it is, the tabs over a rule, then
-- the tab's rows (they scroll)
local detail = make("Frame", {
	Parent = column,
	Position = UDim2.fromOffset(COLUMN_WIDTH + DETAIL_GAP, DETAIL_TOP),
	Size = UDim2.new(0, DETAIL_WIDTH, 1, -HEADER),
	BackgroundColor3 = Theme.Nav,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = detail, Color = Theme.Edge, Transparency = Theme.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", {
	Parent = detail,
	PaddingTop = UDim.new(0, 16),
	PaddingBottom = UDim.new(0, 16),
	PaddingLeft = UDim.new(0, 16),
	PaddingRight = UDim.new(0, 16),
})
local detailTitle = label(detail, { Text = "", RichText = true, Font = Style.TitleFont, TextSize = 28, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 30) })
local detailSub = label(detail, { Text = "", Font = Style.MonoFont, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 14) })
local tabRow = make("Frame", { Parent = detail, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 })
make("UIListLayout", { Parent = tabRow, FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 18) })
make("Frame", { Parent = detail, Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
local content = make("ScrollingFrame", {
	Parent = detail,
	Position = UDim2.fromOffset(0, 98),
	Size = UDim2.new(1, 0, 1, -98),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = MUTED,
	ScrollBarImageTransparency = 0.4,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
})
make("UIListLayout", { Parent = content, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })

local setRows = {} -- the list's rows
local hoveredRow -- the row under the mouse, lit

-- the top bar is as tall as Roblox's band; the column fills the room between the bars
local band = ROBLOX_BAR_FALLBACK
local function place()
	band = GuiService:GetGuiInset().Y / UIScale.Get() -- Roblox's band is in real pixels
	band = band > 0 and band or ROBLOX_BAR_FALLBACK / UIScale.Get()
	column.Position = UDim2.fromOffset(PAD, band + COLUMN_GAP)
	column.Size = UDim2.new(0, COLUMN_WIDTH, 1, -(band + BOTTOM_BAR + 2 * COLUMN_GAP))
	if topBar.Size.Y.Offset > 0 then
		topBar.Size = UDim2.new(1, 0, 0, band)
	end
end
place()
UIScale.OnChange(place)

-- the bars close in and the column (with the pane) slides in from the left
local function intro()
	topBar.Size = UDim2.fromScale(1, 0)
	bottomBar.Size = UDim2.fromScale(1, 0)
	tween(topBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, band) })
	tween(bottomBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, BOTTOM_BAR) })
	shade.BackgroundTransparency = 1
	tween(shade, OPEN_TIME, { BackgroundTransparency = 0 })
	local at = UDim2.fromOffset(PAD, band + COLUMN_GAP)
	column.Position = at - UDim2.fromOffset(PAD + COLUMN_WIDTH + DETAIL_GAP + DETAIL_WIDTH, 0)
	tween(column, OPEN_TIME, { Position = at })
end

-- the smith's replies, as subtitles under them: their name small in the forge's orange over what the
-- server said (gold, or red when it refused)
local speech = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(SPEECH_AT, 0, 1, -(BOTTOM_BAR + 24)),
	Size = UDim2.new(SPEECH_WIDTH, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 6,
})
make("UIListLayout", { Parent = speech, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
local speakerLabel = label(speech, {
	LayoutOrder = 1,
	Text = "",
	Font = Style.MonoFont,
	TextSize = 12,
	TextColor3 = FORGE,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.5,
	Size = UDim2.new(1, 0, 0, 14),
	ZIndex = 6,
})
local note = label(speech, {
	LayoutOrder = 2,
	Text = "",
	TextSize = 14,
	TextColor3 = GOLD,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0.4,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	ZIndex = 6,
})

local function setStatus(text, failed)
	note.Text = text
	note.TextColor3 = failed and DANGER or GOLD
	speech.Visible = text ~= ""
end

-- names the smith: their line, their title big and their name on the chip (the ShopSubtitle,
-- ShopTitle and ShopkeeperName attributes; no name hides the chip), and over the subtitles
local function paintHeader(smith)
	local keeper = smith:GetAttribute("ShopkeeperName")
	title.Text = string.upper(smith:GetAttribute("ShopTitle") or "SMITH")
	subtitle.Text = string.upper(smith:GetAttribute("ShopSubtitle") or "Reforge")
	chip.Visible = keeper ~= nil
	chip.Text = keeper and (" " .. string.upper(keeper) .. " ") or ""
	local ruleAt = keeper and TextService:GetTextSize(chip.Text, chip.TextSize, chip.Font, Vector2.new(1000, 100)).X + 14 or 0
	chipRule.Position = UDim2.fromOffset(ruleAt, 114)
	chipRule.Size = UDim2.new(1, -ruleAt, 0, 1)
	speakerLabel.Text = string.upper(keeper or title.Text)
end

local selected -- the set picked in the list
local tab = "strengthen"
local busy = false
local render

-- one action to the server; returns whether it went through
local function request(action, setName, slot, id)
	if busy then
		return false
	end
	busy = true
	local ok, success, message = pcall(remote.InvokeServer, remote, action, setName, slot, id)
	busy = false
	if not ok then
		setStatus("Couldn't reach the smith", true)
		return false
	end
	if message and message ~= "" then
		setStatus(message, not success)
	end
	return success
end

-- the content's rows ---------------------------------------------------------------

local contentOrder = 0
local function nextOrder()
	contentOrder += 1
	return contentOrder
end

local function heading(text)
	label(content, { LayoutOrder = nextOrder(), Text = text, Font = Style.MonoFont, TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 16) })
end

-- a row with a thin rule under it, as the list's: `name` on the left, `value` on the right (it wraps
-- when it's long)
local function ruledRow(name, nameColor, value, valueColor)
	local row = make("Frame", { Parent = content, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	make("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
	label(row, { Text = name, TextSize = 13, TextColor3 = nameColor, Size = UDim2.new(1, 0, 0, 26) })
	local valueLabel = label(row, {
		Text = value,
		TextSize = 12,
		TextColor3 = valueColor,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.62, 0, 0, 26),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	make("UIPadding", { Parent = valueLabel, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) })
end

-- "Damage        +12%  →  +16%"
local function preview(name, from, to, dim)
	ruledRow(name, dim and MUTED or TEXT, to and string.format("%s   →   %s", from, to) or from, to and FORGE or TEXT)
end

-- a cost as rows of what's needed against what you hold: the material in its tier's colour, the
-- yen; a short one is red
local function costRows(cost, yen)
	local info = DropConfig.Materials[cost.material]
	local have = bag[cost.material]
	local rows = {
		{ name = info and info.display or cost.material, color = info and DropConfig.TierColor(info.tier) or TEXT, need = cost.amount, have = have, text = string.format("%d / %d", have, cost.amount) },
		{ name = "Yen", color = GOLD, need = cost.yen, have = yen, text = string.format("%s / %s", formatYen(yen), formatYen(cost.yen)) },
	}
	for _, entry in ipairs(rows) do
		ruledRow(entry.name, entry.color, entry.text, entry.have >= entry.need and TEXT or DANGER)
	end
end

-- a wide button in the forge's orange; `enabled` greys it out (the server still checks)
local function wideButton(text, enabled, onClick)
	local b = make("TextButton", {
		Parent = content,
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = FORGE,
		BackgroundTransparency = enabled and 0 or 0.6,
		BorderSizePixel = 0,
		Font = Style.TitleFont,
		TextSize = 16,
		TextColor3 = BACKGROUND,
		Text = text,
		AutoButtonColor = enabled,
	})
	b.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	return b
end

-- the tabs ---------------------------------------------------------------------------

local function strengthenTab(setName, state, yen)
	local atMax = state.level >= ReforgeConfig.MaxLevel
	label(content, {
		LayoutOrder = nextOrder(),
		Text = atMax and string.format("+%d   MAX", state.level) or string.format("+%d   →   +%d", state.level, state.level + 1),
		Font = Style.TitleFont,
		TextSize = 32,
		TextColor3 = FORGE,
		Size = UDim2.new(1, 0, 0, 36),
	})
	local bonus = ReforgeRules.DamageBonus(state)
	local nextState = { level = math.min(state.level + 1, ReforgeConfig.MaxLevel), mods = state.mods, awakening = state.awakening }
	local nextBonus = ReforgeRules.DamageBonus(nextState)
	preview("Damage", percent(bonus), not atMax and percent(nextBonus) or nil)
	preview("Damage against players", percent(bonus * ReforgeConfig.PvPFactor), not atMax and percent(nextBonus * ReforgeConfig.PvPFactor) or nil, true)
	if ReforgeRules.SlotsUnlocked(state.level) < ReforgeRules.SlotsUnlocked(nextState.level) then
		preview("Unlocks", "an affinity slot")
	end
	label(content, { LayoutOrder = nextOrder(), Text = "Affinities get stronger with every level.", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 16) })
	if atMax then
		return
	end
	local cost = ReforgeConfig.LevelCosts[state.level + 1]
	heading("REQUIRED")
	costRows(cost, yen)
	local can = ReforgeRules.PlanLevelUp(state, bag, yen)
	wideButton(string.format("STRENGTHEN  +%d → +%d", state.level, state.level + 1), can, function()
		request("level", setName)
		render()
	end)
end

local function affinityTab(setName, state, yen)
	label(content, { LayoutOrder = nextOrder(), Text = "Pick an affinity for each slot. Its strength grows with the level and with awakening.", TextSize = 12, TextColor3 = MUTED, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30) })
	local open = ReforgeRules.SlotsUnlocked(state.level)
	for slot = 1, #ReforgeConfig.SlotUnlockLevels do
		local block = make("Frame", { Parent = content, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIPadding", { Parent = block, PaddingBottom = UDim.new(0, 6) })
		make("UIListLayout", { Parent = block, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
		-- the thin rule over each slot
		make("Frame", { Parent = block, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
		local mod = state.mods[slot]
		local current
		if slot > open then
			current = string.format("locked until +%d", ReforgeConfig.SlotUnlockLevels[slot])
		elseif mod then
			current = string.format("%s: %s", mod.id, describeValue(mod.id, ReforgeRules.AffinityValue(mod.id, state.level, state.awakening)))
		else
			current = "empty"
		end
		label(block, {
			LayoutOrder = 1,
			RichText = true,
			Text = string.format('<font color="#%s">SLOT %d</font>   %s', (slot > open and MUTED or FORGE):ToHex(), slot, current),
			TextSize = 13,
			TextColor3 = slot > open and MUTED or TEXT,
			Size = UDim2.new(1, 0, 0, 18),
		})
		if slot <= open then
			local cost = ReforgeConfig.ChangeCosts[slot]
			local info = DropConfig.Materials[cost.material]
			local short = bag[cost.material] < cost.amount or yen < cost.yen
			label(block, {
				LayoutOrder = 2,
				Text = string.format("Choosing costs %s %d (you have %d) and %s", info and info.display or cost.material, cost.amount, bag[cost.material], formatYen(cost.yen)),
				TextSize = 11,
				TextColor3 = short and DANGER or MUTED,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			})
			local grid = make("Frame", { Parent = block, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
			make("UIGridLayout", { Parent = grid, CellSize = UDim2.new(0.5, -3, 0, 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder })
			for index, config in ipairs(ReforgeConfig.Modifiers) do
				local otherSlot
				for other, otherMod in pairs(state.mods) do
					if other ~= slot and otherMod.id == config.id then
						otherSlot = other
					end
				end
				local isCurrent = mod ~= nil and mod.id == config.id
				local blocked = otherSlot ~= nil
				local option = make("TextButton", {
					Parent = grid,
					LayoutOrder = index,
					BackgroundColor3 = isCurrent and FORGE or Color3.new(0, 0, 0),
					BackgroundTransparency = isCurrent and 0.1 or (blocked and 0.85 or 0.4),
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = not isCurrent and not blocked,
				})
				if not isCurrent then
					make("UIStroke", { Parent = option, Color = Theme.Edge, Transparency = Theme.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
				end
				label(option, { Text = string.upper(config.name) .. (blocked and ("  (SLOT " .. otherSlot .. ")") or ""), Font = Style.TitleFont, TextSize = 15, TextColor3 = isCurrent and BACKGROUND or (blocked and MUTED or TEXT), Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 17) })
				label(option, {
					Text = describeValue(config.id, ReforgeRules.AffinityValue(config.id, state.level, state.awakening)),
					TextSize = 10,
					TextColor3 = isCurrent and BACKGROUND or MUTED,
					Position = UDim2.fromOffset(8, 21),
					Size = UDim2.new(1, -16, 0, 14),
				})
				if not isCurrent and not blocked then
					option.Activated:Connect(function()
						request("choose", setName, slot, config.id)
						render()
					end)
				end
			end
		end
	end
end

local function awakenTab(setName, state, yen)
	local stage = state.awakening
	local atMax = stage >= ReforgeConfig.MaxAwakening
	-- the stages as squares
	local pips = make("Frame", { Parent = content, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 })
	make("UIListLayout", { Parent = pips, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
	label(pips, { LayoutOrder = 0, Text = "AWAKENING", Font = Style.MonoFont, TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromOffset(86, 20) })
	for index = 1, ReforgeConfig.MaxAwakening do
		local lit = index <= stage
		local pip = make("Frame", { Parent = pips, LayoutOrder = index, Size = UDim2.fromOffset(18, 18), BackgroundColor3 = lit and FORGE or Color3.new(0, 0, 0), BackgroundTransparency = lit and 0 or 0.5, BorderSizePixel = 0 })
		make("UIStroke", { Parent = pip, Color = FORGE, Transparency = lit and 0 or 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	label(content, { LayoutOrder = nextOrder(), Text = string.format("Each stage: +%d%% damage and affinities %d%% stronger. Needs the power at +%d and Essence.", math.floor(ReforgeConfig.DamagePerAwakening * 100 + 0.5), math.floor(ReforgeConfig.AwakenAffinityBonus * 100 + 0.5), ReforgeConfig.MaxLevel), TextSize = 12, TextColor3 = MUTED, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30) })
	local nextState = { level = state.level, mods = state.mods, awakening = math.min(stage + 1, ReforgeConfig.MaxAwakening) }
	preview("Damage", percent(ReforgeRules.DamageBonus(state)), not atMax and percent(ReforgeRules.DamageBonus(nextState)) or nil)
	for slot = 1, #ReforgeConfig.SlotUnlockLevels do
		local mod = state.mods[slot]
		if mod then
			local now = ReforgeRules.AffinityValue(mod.id, state.level, stage)
			local after = ReforgeRules.AffinityValue(mod.id, state.level, nextState.awakening)
			preview(string.format("Slot %d  %s", slot, mod.id), describeValue(mod.id, now), not atMax and describeValue(mod.id, after) or nil, true)
		end
	end
	if atMax then
		label(content, { LayoutOrder = nextOrder(), Text = "FULLY AWAKENED", Font = Style.TitleFont, TextSize = 18, TextColor3 = FORGE, Size = UDim2.new(1, 0, 0, 22) })
		return
	end
	heading("REQUIRED")
	local reached = state.level >= ReforgeConfig.MaxLevel
	ruledRow("Level", TEXT, string.format("+%d / +%d", state.level, ReforgeConfig.MaxLevel), reached and TEXT or DANGER)
	costRows(ReforgeConfig.AwakenCosts[stage + 1], yen)
	local can = ReforgeRules.PlanAwaken(state, true, bag, yen)
	wideButton(string.format("AWAKEN  STAGE %d → %d", stage, stage + 1), can, function()
		request("awaken", setName)
		render()
	end)
end

-- the tabs: titles over the pane's rule, the open one white and underlined in the forge's orange
local tabButtons = {}
for index, entry in ipairs(TABS) do
	local button = make("TextButton", {
		Parent = tabRow,
		LayoutOrder = index,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Style.TitleFont,
		Text = entry.title,
		TextSize = 16,
		TextColor3 = MUTED,
	})
	local underline = make("Frame", { Parent = button, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = FORGE, BorderSizePixel = 0, Visible = false })
	button.Activated:Connect(function()
		tab = entry.id
		render()
	end)
	tabButtons[entry.id] = { button = button, underline = underline }
end

-- the whole menu --------------------------------------------------------------------

render = function()
	local yen = player:GetAttribute("Yen") or 0
	balance.Text = string.format('CASH  <font color="#%s">%s</font>', GOLD:ToHex(), formatYen(yen))

	-- the list of sets, as the shops' rows: number, tier, name, what it is and the +level. The picked
	-- one is lit; a row under the mouse brightens a little (hoverRows)
	clear(list)
	setRows = {}
	hoveredRow = nil
	local owned = ownedSets()
	if #owned == 0 then
		label(list, { Text = "You own nothing to reforge", TextSize = 13, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, ROW_HEIGHT) })
	end
	if selected and not table.find(owned, selected) then
		selected = nil
	end
	selected = selected or owned[1]
	for index, setName in ipairs(owned) do
		local set = SkillSetConfig.Sets[setName]
		local state = stateOf(setName)
		local isSelected = setName == selected
		local row = make("TextButton", {
			Parent = list,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
		})
		local highlight = make("Frame", { Parent = row, Size = UDim2.fromScale(1, 1), BackgroundColor3 = FORGE, BackgroundTransparency = isSelected and 0.82 or 1, BorderSizePixel = 0 })
		make("UIGradient", { Parent = highlight, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
		local bar = make("Frame", {
			Parent = row,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(0, 3, isSelected and 1 or 0, 0),
			BackgroundColor3 = FORGE,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
		-- the thin rule under each row
		make("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
		local body = make("Frame", { Parent = row, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 })
		make("UIPadding", { Parent = body, PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
		local number = label(body, {
			Text = string.format("%02d", index),
			Font = Style.MonoFont,
			TextSize = 11,
			TextColor3 = isSelected and FORGE or MUTED,
			Size = UDim2.fromOffset(NUMBER_WIDTH, 22),
		})
		local badge = label(body, {
			Text = set.tier or "",
			Font = Style.TitleFont,
			TextSize = 18,
			TextColor3 = tierColor(setName),
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, NUMBER_WIDTH, 0.5, 0),
			Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
		})
		if set.tier then
			make("UIStroke", { Parent = badge, Color = tierColor(setName), Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		end
		local textLeft = NUMBER_WIDTH + BADGE_SIZE + 10
		label(body, {
			Text = string.upper(displayName(setName)),
			Font = Style.TitleFont,
			TextSize = 22,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(textLeft, 0),
			Size = UDim2.new(1, -(textLeft + 44), 0, 22),
		})
		label(body, {
			Text = string.upper(string.format("%s-tier %s%s", set.tier or "?", set.kind, state.awakening > 0 and ("  ·  awakened " .. state.awakening) or "")),
			Font = Style.MonoFont,
			TextSize = 11,
			TextColor3 = FORGE,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(textLeft, 26),
			Size = UDim2.new(1, -(textLeft + 44), 0, 14),
		})
		-- the +level, top right (where a shop's row has its price)
		label(body, {
			Text = state.level > 0 and ("+" .. state.level) or "",
			Font = Style.MonoFont,
			TextSize = 16,
			TextColor3 = FORGE,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(44, 20),
		})
		-- under the mouse a row only brightens a little, so the picked one stays the one lit
		local function paint(over)
			tween(highlight, HOVER_TIME, { BackgroundTransparency = isSelected and 0.82 or over and 0.93 or 1 })
			tween(number, HOVER_TIME, { TextColor3 = isSelected and FORGE or over and TEXT or MUTED })
		end
		row.Activated:Connect(function()
			selected = setName
			setStatus("")
			render()
		end)
		table.insert(setRows, { frame = row, paint = paint })
	end

	-- the picked set's pane
	clear(content)
	contentOrder = 0
	detail.Visible = selected ~= nil
	if not selected then
		return
	end
	local state = stateOf(selected)
	local power = isPower(selected)
	if tab == "awaken" and not power then
		tab = "strengthen"
	end
	detailTitle.Text = string.format('%s  <font color="#%s">+%d</font>', string.upper(displayName(selected)), FORGE:ToHex(), state.level)
	detailSub.Text = string.upper(string.format("%s-tier %s%s", SkillSetConfig.Sets[selected].tier or "?", SkillSetConfig.Sets[selected].kind, state.awakening > 0 and ("   ·   awakened " .. state.awakening) or ""))
	detailSub.TextColor3 = tierColor(selected)
	for id, entry in pairs(tabButtons) do
		entry.button.Visible = id ~= "awaken" or power
		local active = id == tab
		entry.button.TextColor3 = active and TEXT or MUTED
		entry.underline.Visible = active
	end
	if tab == "strengthen" then
		strengthenTab(selected, state, yen)
	elseif tab == "affinity" then
		affinityTab(selected, state, yen)
	else
		awakenTab(selected, state, yen)
	end
end

-- (only what the menu shows: other attributes tick all the time, and rebuilding the rows drops clicks)
local MATERIAL_PREFIX = ReforgeConfig.MaterialAttribute("")
local REFORGE_PREFIX = ReforgeConfig.SetAttribute("")
player.AttributeChanged:Connect(function(name)
	if
		gui.Enabled
		and (
			name == "Yen"
			or name == SkillSetConfig.OwnedSetsAttribute
			or string.sub(name, 1, #MATERIAL_PREFIX) == MATERIAL_PREFIX
			or string.sub(name, 1, #REFORGE_PREFIX) == REFORGE_PREFIX
		)
	then
		render()
	end
end)

-- the smith whose menu is open, so walking away can close it
local openAt

local function close()
	ShopFocus.End()
	gui.Enabled = false
	openAt = nil
	Menus.Close("Reforge")
end
-- E LEAVE, on the left of the bottom bar
MenuFooter.Leave(gui, close, UDim2.new(0, PAD, 1, -(BOTTOM_BAR - HudConfig.HintsHeight) / 2))

-- lights the row under the mouse (polled, as the shops' rows are)
local function hoverRows()
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset() -- (AbsolutePosition starts under Roblox's band)
	local function inside(frame)
		local position, size = frame.AbsolutePosition, frame.AbsoluteSize
		return mouse.X >= position.X and mouse.X <= position.X + size.X and mouse.Y >= position.Y and mouse.Y <= position.Y + size.Y
	end
	local over
	if inside(panel) then
		for _, row in ipairs(setRows) do
			if inside(row.frame) then
				over = row
				break
			end
		end
	end
	if over ~= hoveredRow then
		if hoveredRow then
			hoveredRow.paint(false)
		end
		hoveredRow = over
		if over then
			over.paint(true)
		end
	end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local smith = prompt:FindFirstAncestorOfClass("Model")
	if smith and CollectionService:HasTag(smith, ReforgeConfig.Tag) then
		openAt = smith
		setStatus("")
		selected = nil
		tab = "strengthen"
		paintHeader(smith)
		render()
		panel.CanvasPosition = Vector2.zero
		Menus.Open("Reforge", close)
		gui.Enabled = true
		intro()
		-- the full-screen close-up on the smith (E leaves)
		ShopFocus.Begin(smith, { ignoreGui = gui, onLeave = close, shift = CAMERA_SHIFT })
	end
end)

RunService.Heartbeat:Connect(function()
	if not openAt then
		return
	end
	hoverRows()
	ShopFocus.Step()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > ReforgeConfig.Range then
		close()
	end
end)
