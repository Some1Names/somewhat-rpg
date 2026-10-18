-- Smith menu, like Elden Ring's blacksmith: opens from a smith's prompt (a model
-- tagged "Smith") over a full-screen close-up of the smith (ShopFocus, which also
-- makes E leave). On the left the powers and weapons you own with their +level;
-- on the right, for the one you pick, three tabs: STRENGTHEN (the next +level,
-- the damage change and the materials needed against what you hold), AFFINITY
-- (the two slots, opened at +3 and +7, where you choose the affinity and see the
-- value each would have) and AWAKEN (powers only: at +10, Essence awakens it
-- further). The level, affinities and awakening are the Reforge_<Set> attributes
-- the server mirrors; every action goes through the ReforgeAction remote
-- (ReforgeServer), which does all the checking. Closes when you walk away, or
-- when another menu opens (Menus).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local ReforgeRules = require(ReplicatedStorage:WaitForChild("ReforgeRules"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local ShopFocus = require(script.Parent:WaitForChild("ShopFocus"))
local remote = ReplicatedStorage:WaitForChild(ReforgeConfig.Remote)
local player = Players.LocalPlayer

local PANEL_WIDTH = 700
local PADDING = 14
local LIST_WIDTH = 220
local ROW_HEIGHT = 44
local CAMERA_SHIFT = 3.6 -- studs the smith sits right of centre, clear of the wide panel
local BACKGROUND = Color3.fromRGB(20, 20, 28)
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

-- "IridescentRequiem" -> "Iridescent Requiem"
local function displayName(setName)
	return (string.gsub(setName, "(%l)(%u)", "%1 %2"))
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

-- darkens the left of the screen for the menu; the right stays clear for the smith.
-- Active, so a click anywhere on the screen is taken by the menu and never punches or shoots.
local backdrop = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Active = true })
make("UIGradient", {
	Parent = backdrop,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(0.85, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
})

local panel = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 40, 0.5, 0),
	Size = UDim2.new(0, PANEL_WIDTH, 1, -120),
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = panel, Color = FORGE, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})

-- header: the smith's role big with the line above it (like a shop's), close
local subtitle = label(panel, { Text = "Reforge", Font = Enum.Font.Highway, TextSize = 13, TextColor3 = FORGE, Size = UDim2.new(1, -30, 0, 16) })
local title = label(panel, {
	Text = "SMITH",
	Font = Enum.Font.Highway,
	TextSize = 30,
	Position = UDim2.fromOffset(0, 18),
	Size = UDim2.new(1, -30, 0, 38),
})
local closeButton = make("TextButton", {
	Parent = panel,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.Highway,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
})

-- the player's yen, top right of the screen
local balanceBox = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -40, 0, 28),
	Size = UDim2.fromOffset(240, 40),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = balanceBox, Color = GOLD, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
label(balanceBox, { Text = "CASH", TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.4, 0, 1, 0) })
local balance = label(balanceBox, {
	Font = Enum.Font.Highway,
	TextSize = 18,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.new(1, -12, 1, 0),
})

-- the bottom: a status line and the leave button
local leave = make("TextButton", {
	Parent = panel,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	Font = Enum.Font.Highway,
	Text = "LEAVE SMITH",
	TextSize = 13,
	TextColor3 = TEXT,
})
local status = label(panel, {
	Text = "",
	TextSize = 12,
	TextColor3 = MUTED,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -40),
	Size = UDim2.new(1, 0, 0, 16),
})
local function setStatus(text, failed)
	status.Text = text
	status.TextColor3 = failed and DANGER or GOLD
end

-- the body: the list of sets on the left, the picked set's tabs on the right
local BODY_TOP = 64
local body = make("Frame", {
	Parent = panel,
	Position = UDim2.fromOffset(0, BODY_TOP),
	Size = UDim2.new(1, 0, 1, -(BODY_TOP + 62)),
	BackgroundTransparency = 1,
})
local list = make("ScrollingFrame", {
	Parent = body,
	Size = UDim2.new(0, LIST_WIDTH, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
})
make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
make("Frame", { Parent = body, Position = UDim2.fromOffset(LIST_WIDTH + 8, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = TEXT, BackgroundTransparency = 0.85, BorderSizePixel = 0 })

local DETAIL_LEFT = LIST_WIDTH + 18
local detail = make("Frame", {
	Parent = body,
	Position = UDim2.fromOffset(DETAIL_LEFT, 0),
	Size = UDim2.new(1, -DETAIL_LEFT, 1, 0),
	BackgroundTransparency = 1,
})
local detailTitle = label(detail, { Text = "", Font = Enum.Font.Highway, TextSize = 18, Size = UDim2.new(1, 0, 0, 22) })
local detailSub = label(detail, { Text = "", Font = Enum.Font.Highway, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 14) })
local tabRow = make("Frame", { Parent = detail, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
make("UIListLayout", { Parent = tabRow, FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
local content = make("ScrollingFrame", {
	Parent = detail,
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.new(1, 0, 1, -80),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
})
make("UIListLayout", { Parent = content, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

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
	label(content, { LayoutOrder = nextOrder(), Text = text, Font = Enum.Font.Highway, TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 14) })
end

-- "Damage        +12%  →  +16%"
local function preview(name, from, to, dim)
	local row = make("Frame", { Parent = content, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0 })
	label(row, { Text = name, TextSize = 12, TextColor3 = dim and MUTED or TEXT, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.5, -10, 1, 0) })
	label(row, {
		Text = to and string.format("%s   →   %s", from, to) or from,
		Font = Enum.Font.Highway,
		TextSize = 12,
		TextColor3 = to and FORGE or TEXT,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -10, 1, 0),
	})
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
		local row = make("Frame", { Parent = content, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0 })
		label(row, { Text = entry.name, Font = Enum.Font.Highway, TextSize = 12, TextColor3 = entry.color, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.5, -10, 1, 0) })
		label(row, {
			Text = entry.text,
			TextSize = 12,
			TextColor3 = entry.have >= entry.need and TEXT or DANGER,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -10, 1, 0),
		})
	end
end

-- a wide button; `enabled` greys it out (the server still checks)
local function wideButton(text, enabled, onClick)
	local b = make("TextButton", {
		Parent = content,
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = FORGE,
		BackgroundTransparency = enabled and 0 or 0.6,
		BorderSizePixel = 0,
		Font = Enum.Font.Highway,
		TextSize = 13,
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
		Font = Enum.Font.Highway,
		TextSize = 28,
		TextColor3 = FORGE,
		Size = UDim2.new(1, 0, 0, 34),
	})
	local bonus = ReforgeRules.DamageBonus(state)
	local nextState = { level = math.min(state.level + 1, ReforgeConfig.MaxLevel), mods = state.mods, awakening = state.awakening }
	local nextBonus = ReforgeRules.DamageBonus(nextState)
	preview("Damage", percent(bonus), not atMax and percent(nextBonus) or nil)
	preview("Damage against players", percent(bonus * ReforgeConfig.PvPFactor), not atMax and percent(nextBonus * ReforgeConfig.PvPFactor) or nil, true)
	if ReforgeRules.SlotsUnlocked(state.level) < ReforgeRules.SlotsUnlocked(nextState.level) then
		preview("Unlocks", "an affinity slot")
	end
	label(content, { LayoutOrder = nextOrder(), Text = "Affinities get stronger with every level.", TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 14) })
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
	label(content, { LayoutOrder = nextOrder(), Text = "Pick an affinity for each slot. Its strength grows with the level and with awakening.", TextSize = 11, TextColor3 = MUTED, TextWrapped = true, Size = UDim2.new(1, 0, 0, 28) })
	local open = ReforgeRules.SlotsUnlocked(state.level)
	for slot = 1, #ReforgeConfig.SlotUnlockLevels do
		local block = make("Frame", { Parent = content, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0 })
		make("UIPadding", { Parent = block, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
		make("UIListLayout", { Parent = block, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
		local mod = state.mods[slot]
		local current
		if slot > open then
			current = string.format("locked until +%d", ReforgeConfig.SlotUnlockLevels[slot])
		elseif mod then
			current = string.format("%s: %s", mod.id, describeValue(mod.id, ReforgeRules.AffinityValue(mod.id, state.level, state.awakening)))
		else
			current = "empty"
		end
		label(block, { LayoutOrder = 1, Text = string.format("SLOT %d    %s", slot, current), Font = Enum.Font.Highway, TextSize = 12, TextColor3 = slot > open and MUTED or TEXT, Size = UDim2.new(1, 0, 0, 16) })
		if slot <= open then
			local cost = ReforgeConfig.ChangeCosts[slot]
			local info = DropConfig.Materials[cost.material]
			local short = bag[cost.material] < cost.amount or yen < cost.yen
			label(block, {
				LayoutOrder = 2,
				Text = string.format("Choosing costs %s %d (you have %d) and %s", info and info.display or cost.material, cost.amount, bag[cost.material], formatYen(cost.yen)),
				TextSize = 11,
				TextColor3 = short and DANGER or MUTED,
				Size = UDim2.new(1, 0, 0, 14),
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
				label(option, { Text = config.name .. (blocked and ("  (slot " .. otherSlot .. ")") or ""), Font = Enum.Font.Highway, TextSize = 12, TextColor3 = isCurrent and BACKGROUND or (blocked and MUTED or TEXT), Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 16) })
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
	label(pips, { LayoutOrder = 0, Text = "AWAKENING", Font = Enum.Font.Highway, TextSize = 12, TextColor3 = MUTED, Size = UDim2.fromOffset(86, 20) })
	for index = 1, ReforgeConfig.MaxAwakening do
		local lit = index <= stage
		local pip = make("Frame", { Parent = pips, LayoutOrder = index, Size = UDim2.fromOffset(20, 20), BackgroundColor3 = lit and FORGE or Color3.new(0, 0, 0), BackgroundTransparency = lit and 0 or 0.5, BorderSizePixel = 0 })
		make("UIStroke", { Parent = pip, Color = FORGE, Transparency = lit and 0 or 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	label(content, { LayoutOrder = nextOrder(), Text = string.format("Each stage: +%d%% damage and affinities %d%% stronger. Needs the power at +%d and Essence.", math.floor(ReforgeConfig.DamagePerAwakening * 100 + 0.5), math.floor(ReforgeConfig.AwakenAffinityBonus * 100 + 0.5), ReforgeConfig.MaxLevel), TextSize = 11, TextColor3 = MUTED, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30) })
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
		label(content, { LayoutOrder = nextOrder(), Text = "Fully awakened", Font = Enum.Font.Highway, TextSize = 14, TextColor3 = FORGE, Size = UDim2.new(1, 0, 0, 20) })
		return
	end
	heading("REQUIRED")
	local reached = state.level >= ReforgeConfig.MaxLevel
	local levelRow = make("Frame", { Parent = content, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0 })
	label(levelRow, { Text = "Level", Font = Enum.Font.Highway, TextSize = 12, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.5, -10, 1, 0) })
	label(levelRow, { Text = string.format("+%d / +%d", state.level, ReforgeConfig.MaxLevel), TextSize = 12, TextColor3 = reached and TEXT or DANGER, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, -10, 1, 0) })
	costRows(ReforgeConfig.AwakenCosts[stage + 1], yen)
	local can = ReforgeRules.PlanAwaken(state, true, bag, yen)
	wideButton(string.format("AWAKEN  stage %d → %d", stage, stage + 1), can, function()
		request("awaken", setName)
		render()
	end)
end

local tabButtons = {}
for index, entry in ipairs(TABS) do
	local button = make("TextButton", {
		Parent = tabRow,
		LayoutOrder = index,
		Size = UDim2.fromOffset(112, 26),
		BackgroundColor3 = TEXT,
		Font = Enum.Font.Highway,
		Text = entry.title,
		TextSize = 11,
		BorderSizePixel = 0,
	})
	make("UIStroke", { Parent = button, Color = TEXT, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	button.Activated:Connect(function()
		tab = entry.id
		render()
	end)
	tabButtons[entry.id] = button
end

-- the whole menu --------------------------------------------------------------------

render = function()
	local yen = player:GetAttribute("Yen") or 0
	balance.Text = formatYen(yen)

	-- the list of sets
	clear(list)
	local owned = ownedSets()
	if #owned == 0 then
		label(list, { Text = "You own nothing to reforge", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, ROW_HEIGHT) })
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
			BackgroundColor3 = isSelected and FORGE or Color3.new(0, 0, 0),
			BackgroundTransparency = isSelected and 0.75 or 0.6,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		})
		if isSelected then
			make("UIStroke", { Parent = row, Color = FORGE, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		end
		label(row, { Text = set.tier or "", Font = Enum.Font.Highway, TextSize = 18, TextColor3 = tierColor(setName), TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0, 26, 1, 0) })
		label(row, { Text = displayName(setName), Font = Enum.Font.Highway, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -96, 1, 0) })
		label(row, {
			Text = state.level > 0 and ("+" .. state.level) or "",
			Font = Enum.Font.Highway,
			TextSize = 14,
			TextColor3 = FORGE,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -10, 1, 0),
		})
		if state.awakening > 0 then
			label(row, { Text = "AWK " .. state.awakening, Font = Enum.Font.Highway, TextSize = 9, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -4), Size = UDim2.fromOffset(50, 10) })
		end
		row.Activated:Connect(function()
			selected = setName
			setStatus("")
			render()
		end)
	end

	-- the picked set's tabs
	clear(content)
	contentOrder = 0
	if not selected then
		detailTitle.Text = ""
		detailSub.Text = ""
		for _, button in pairs(tabButtons) do
			button.Visible = false
		end
		return
	end
	local state = stateOf(selected)
	local power = isPower(selected)
	if tab == "awaken" and not power then
		tab = "strengthen"
	end
	detailTitle.Text = string.format("%s   +%d", displayName(selected), state.level)
	detailSub.Text = string.format("%s-tier %s%s", SkillSetConfig.Sets[selected].tier or "?", SkillSetConfig.Sets[selected].kind, state.awakening > 0 and ("   ·   awakened " .. state.awakening) or "")
	detailSub.TextColor3 = tierColor(selected)
	for id, button in pairs(tabButtons) do
		button.Visible = id ~= "awaken" or power
		local active = id == tab
		button.BackgroundTransparency = active and 0 or 1
		button.TextColor3 = active and BACKGROUND or TEXT
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
closeButton.Activated:Connect(close)
leave.Activated:Connect(close)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local smith = prompt:FindFirstAncestorOfClass("Model")
	if smith and CollectionService:HasTag(smith, ReforgeConfig.Tag) then
		openAt = smith
		setStatus("")
		selected = nil
		tab = "strengthen"
		title.Text = smith:GetAttribute("ShopTitle") or "SMITH"
		subtitle.Text = smith:GetAttribute("ShopSubtitle") or "Reforge"
		render()
		list.CanvasPosition = Vector2.zero
		Menus.Open("Reforge", close)
		gui.Enabled = true
		-- the full-screen close-up on the smith (E leaves)
		ShopFocus.Begin(smith, { ignoreGui = gui, onLeave = close, shift = CAMERA_SHIFT })
	end
end)

RunService.Heartbeat:Connect(function()
	if not openAt then
		return
	end
	ShopFocus.Step()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > ReforgeConfig.Range then
		close()
	end
end)
