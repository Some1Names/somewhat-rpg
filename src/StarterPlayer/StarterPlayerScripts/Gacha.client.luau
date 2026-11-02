-- The power gacha: the prompt on a model tagged "PowerGacha" opens a full-screen close-up of the
-- dealer (ShopFocus, which also makes E leave) in the shops' look (ShopMenu): black bars along the
-- top and bottom (E LEAVE and your yen in the bottom one), and down the left, over a dark fading off
-- the edge, POWER GACHA, the free roll or its countdown big, the dealer's name on a chip (their
-- ShopkeeperName attribute, if set), what extra rolls cost, your pity as a thin line, ROLL as a row
-- that lights under the mouse while it can roll, and a row per tier: its chance now and the powers
-- it can give. The server's replies are subtitles under the dealer.
-- ROLL asks the RollGacha remote (PowerSources decides everything); the reply plays the reveal: the
-- screen darkens round one face-down card whose edge flickers through the tiers and lands on the
-- one you got, then the card flips to name the power. The reveal only shows what the server already
-- decided. The briefcase reaches your inventory when the card flips (the ClaimGacha remote; the
-- server hands it over anyway after a few seconds). A click or Enter puts the card away.
-- Closes when you walk away or another menu opens (Menus).
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local MenuFooter = require(script.Parent:WaitForChild("MenuFooter"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local ShopFocus = require(script.Parent:WaitForChild("ShopFocus"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local rollRemote = ReplicatedStorage:WaitForChild("RollGacha")
local claimRemote = ReplicatedStorage:WaitForChild("ClaimGacha")
local player = Players.LocalPlayer

local Style = HudConfig.Style
local Theme = HudConfig.HubTheme
local PAD = 64 -- the screen's left edge to the column (as on the title menu and the shops)
local COLUMN_WIDTH = 460
local COLUMN_GAP = 26 -- between the top bar and the column, and the column and the bottom bar
local HEADER = 150 -- the column's top: POWER GACHA, the free roll big, the dealer on a chip
local BOTTOM_BAR = 44 -- the black bar along the bottom; the top one is as tall as Roblox's band
local ROBLOX_BAR_FALLBACK = 58 -- Roblox's band across the top, while GetGuiInset still says 0
local SHADE_SHARE = 0.62 -- how far across the screen the dark fades off the left edge
local SPEECH_AT = 0.72 -- the middle of the dealer's subtitles, across the screen (ShopFocus sets them right of centre)
local OPEN_TIME = 0.45 -- the bars closing in, the column sliding in
local HOVER_TIME = 0.15
local CARD_WIDTH = 220
local CARD_HEIGHT = 300
local TEASE_TIME = 1.6 -- seconds the card's edge flickers before it settles
local BACKGROUND = Style.Glass -- the text on a light fill
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local DANGER = Color3.fromRGB(226, 75, 74)
local GOLD = Color3.fromRGB(255, 205, 60)
local STROKE = Color3.new(0, 0, 0)
local ACCENT = TEXT -- the gacha's own: white

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
	props.Font = props.Font or Style.LabelFont
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function formatNumber(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return grouped
end

local function tierColor(tier)
	local info = SkillSetConfig.Tiers[tier]
	return info and info.color or SkillSetConfig.NoTierColor
end

-- a power's name as everywhere else: its Tool's ("Aido" -> "Deus Ex Machina")
local function powerName(setName)
	local set = SkillSetConfig.Sets[setName]
	return set and set.tool or (string.gsub(setName, "(%l)(%u)", "%1 %2"))
end

-- the colour to write on a fill of `color`
local function onColor(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B > 0.4 and BACKGROUND or TEXT
end

local gui = make("ScreenGui", {
	Name = "Gacha",
	ResetOnSpawn = false,
	Enabled = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
})

-- the shops' look: black bars along the top and the bottom, the dark fading off the left edge for
-- the column, the right left clear for the dealer
local backdrop = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
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

-- the column down the left: POWER GACHA with the accent before it, the free roll or its countdown
-- big, the dealer's name on a chip with a rule running on, then the menu
local column = make("Frame", { Parent = backdrop, BackgroundTransparency = 1, ZIndex = 5 })
make("Frame", { Parent = column, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = ACCENT, BorderSizePixel = 0, ZIndex = 5 })
label(column, { Text = "POWER GACHA", Font = Style.MonoFont, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -34, 0, 14), ZIndex = 5 })
local headline = label(column, {
	Font = Style.TitleFont,
	TextScaled = true,
	Position = UDim2.fromOffset(-2, 18),
	Size = UDim2.new(1, 0, 0, 72),
	ZIndex = 5,
})
make("UITextSizeConstraint", { Parent = headline, MaxTextSize = 72 })
local chip = make("TextLabel", {
	Parent = column,
	Font = Style.TitleFont,
	TextSize = 20,
	TextColor3 = onColor(ACCENT),
	BackgroundColor3 = ACCENT,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(1, 102),
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 5,
})
local chipRule = make("Frame", { Parent = column, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = MUTED, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 5 })

-- under the header: what extra rolls cost, the pity line, ROLL, the odds
local menu = make("Frame", {
	Parent = column,
	Position = UDim2.fromOffset(0, HEADER),
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	ZIndex = 5,
})
make("UIListLayout", { Parent = menu, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) })

local order = 0
local function nextOrder()
	order += 1
	return order
end

local subline = label(menu, {
	LayoutOrder = nextOrder(),
	TextSize = 14,
	TextColor3 = MUTED,
	Size = UDim2.new(1, 0, 0, 16),
})

-- pity: a thin line that fills toward the guaranteed S
local pityText = label(menu, {
	LayoutOrder = nextOrder(),
	Font = Style.MonoFont,
	TextSize = 11,
	TextColor3 = MUTED,
	Size = UDim2.new(1, 0, 0, 14),
})
local pityBack = make("Frame", {
	Parent = menu,
	LayoutOrder = nextOrder(),
	Size = UDim2.new(1, 0, 0, 2),
	BackgroundColor3 = TEXT,
	BackgroundTransparency = 0.8,
	BorderSizePixel = 0,
})
local pityFill = make("Frame", {
	Parent = pityBack,
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = tierColor("S"),
	BorderSizePixel = 0,
})

-- ROLL, as the shops' rows: a thin rule under it; hovered while it can roll, the accent fades in
-- behind it and a bar runs down its left edge
local rollButton = make("TextButton", {
	Parent = menu,
	LayoutOrder = nextOrder(),
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "",
})
local rollHighlight = make("Frame", { Parent = rollButton, Size = UDim2.fromScale(1, 1), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, BorderSizePixel = 0 })
make("UIGradient", { Parent = rollHighlight, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
local rollBar = make("Frame", {
	Parent = rollButton,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromOffset(3, 0),
	BackgroundColor3 = ACCENT,
	BorderSizePixel = 0,
	ZIndex = 2,
})
make("Frame", { Parent = rollButton, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
local rollText = label(rollButton, { Font = Style.TitleFont, TextSize = 26, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 1, 0) })
local rollHover = false
local rollLit = false -- the row is painted lit

-- the odds and what can drop, always shown: a row per tier with its letter, the powers it can give
-- now (every power of that tier, as PowerSources pools them) and its chance (refresh). A tier with
-- nothing in it can't come up, so its share goes to the others, as PowerConfig.roll does.
local pool = {} -- tier -> the powers in it
for setName, set in pairs(SkillSetConfig.Sets) do
	if set.kind == "power" then
		pool[set.tier] = pool[set.tier] or {}
		table.insert(pool[set.tier], setName)
	end
end
label(menu, { LayoutOrder = nextOrder(), Text = "ODDS AND DROPS", Font = Style.MonoFont, TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 14) })
local drops = make("Frame", { Parent = menu, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
make("UIListLayout", { Parent = drops, SortOrder = Enum.SortOrder.LayoutOrder })
local chanceLabels = {} -- tier -> its chance, on the right of its row
for index, tier in ipairs(PowerConfig.Tiers) do
	local names = {}
	for _, setName in ipairs(pool[tier] or {}) do
		table.insert(names, string.upper(powerName(setName)))
	end
	table.sort(names)
	local color = tierColor(tier)
	local row = make("Frame", { Parent = drops, LayoutOrder = index, Size = UDim2.new(1, 0, 0, 44), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	-- the thin rule under each row
	make("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
	local badge = label(row, {
		Text = tier,
		Font = Style.TitleFont,
		TextSize = 18,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(14, 7),
		Size = UDim2.fromOffset(30, 30),
	})
	make("UIStroke", { Parent = badge, Color = color, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local powers = label(row, {
		Text = #names > 0 and table.concat(names, "  ·  ") or "NOTHING IN THIS TIER YET",
		Font = Style.MonoFont,
		TextSize = 11,
		TextColor3 = #names > 0 and TEXT or MUTED,
		TextWrapped = true,
		Position = UDim2.fromOffset(56, 0),
		Size = UDim2.new(1, -126, 0, 44),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	make("UIPadding", { Parent = powers, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
	chanceLabels[tier] = label(row, {
		Font = Style.MonoFont,
		TextSize = 16,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 0),
		Size = UDim2.fromOffset(64, 44),
	})
end

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

-- the bars close in and the column slides in from the left
local function intro()
	local info = TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	topBar.Size = UDim2.fromScale(1, 0)
	bottomBar.Size = UDim2.fromScale(1, 0)
	TweenService:Create(topBar, info, { Size = UDim2.new(1, 0, 0, band) }):Play()
	TweenService:Create(bottomBar, info, { Size = UDim2.new(1, 0, 0, BOTTOM_BAR) }):Play()
	shade.BackgroundTransparency = 1
	TweenService:Create(shade, info, { BackgroundTransparency = 0 }):Play()
	local at = UDim2.fromOffset(PAD, band + COLUMN_GAP)
	column.Position = at - UDim2.fromOffset(PAD + COLUMN_WIDTH, 0)
	TweenService:Create(column, info, { Position = at }):Play()
end

-- the dealer's replies, as subtitles under them: their name small over what the server said (gold,
-- or red when it failed)
local speech = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(SPEECH_AT, 0, 1, -(BOTTOM_BAR + 24)),
	Size = UDim2.new(0.42, 0, 0, 0),
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
	TextColor3 = ACCENT,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeColor3 = STROKE,
	TextStrokeTransparency = 0.5,
	Size = UDim2.new(1, 0, 0, 14),
	ZIndex = 6,
})
local status = label(speech, {
	LayoutOrder = 2,
	Text = "",
	TextSize = 14,
	TextColor3 = GOLD,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeColor3 = STROKE,
	TextStrokeTransparency = 0.4,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	ZIndex = 6,
})

-- the dealer's name on the chip (their ShopkeeperName attribute; none hides it) and over the subtitles
local function paintHeader(npc)
	local keeper = npc:GetAttribute("ShopkeeperName")
	chip.Visible = keeper ~= nil
	chip.Text = keeper and (" " .. string.upper(keeper) .. " ") or ""
	local ruleAt = keeper and TextService:GetTextSize(chip.Text, chip.TextSize, chip.Font, Vector2.new(1000, 100)).X + 14 or 0
	chipRule.Position = UDim2.fromOffset(ruleAt, 114)
	chipRule.Size = UDim2.new(1, -ruleAt, 0, 1)
	speakerLabel.Text = string.upper(keeper or npc.Name)
end

-- the reveal: a scrim over the screen and one card in the middle
local scrim = make("Frame", {
	Parent = gui,
	Visible = false,
	Active = true, -- a click on it is for the reveal, not the menu under it
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 10,
})
local flash = make("Frame", {
	Parent = scrim,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = TEXT,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 11,
})
local card = make("Frame", {
	Parent = scrim,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
	BackgroundColor3 = Style.Glass,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	ZIndex = 12,
})
local cardStroke = make("UIStroke", { Parent = card, Color = TEXT, Thickness = 2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
local cardBack = make("Frame", { Parent = card, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 })
label(cardBack, {
	Text = "?",
	Font = Style.TitleFont,
	TextSize = 110,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 12,
})
local cardFront = make("Frame", { Parent = card, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 12 })
local tierLabel = label(cardFront, {
	Font = Style.TitleFont,
	TextSize = 130,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 24),
	Size = UDim2.new(1, 0, 0, 140),
	ZIndex = 12,
})
local nameLabel = label(cardFront, {
	Font = Style.TitleFont,
	TextSize = 24,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.new(0, 10, 0, 176),
	Size = UDim2.new(1, -20, 0, 60),
	ZIndex = 12,
})
local tierBar = make("Frame", {
	Parent = cardFront,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 6),
	BorderSizePixel = 0,
	ZIndex = 12,
})
local continueHint = label(scrim, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, CARD_HEIGHT / 2 + 24),
	Size = UDim2.fromOffset(300, 16),
	Text = "CLICK TO CONTINUE",
	Font = Style.MonoFont,
	TextSize = 11,
	TextColor3 = MUTED,
	TextTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 12,
})

local spinning = false -- a roll is waiting on the server or its reveal is on screen
local revealDone = false -- the card has flipped and waits to be put away
local openAt -- the gacha NPC whose menu is open

local function setStatus(text, failed)
	status.Text = text
	status.TextColor3 = failed and DANGER or GOLD
	speech.Visible = text ~= ""
end

local function clock(seconds)
	seconds = math.max(math.floor(seconds), 0)
	return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

local function refresh()
	local gacha = PowerConfig.Gacha
	local yen = player:GetAttribute("Yen") or 0
	local readyAt = player:GetAttribute("GachaReadyAt") or 0
	local pity = player:GetAttribute("GachaPity") or 0
	local wait = readyAt - os.time()
	local free = wait <= 0
	balance.Text = string.format('CASH  <font color="#%s">¥%s</font>', GOLD:ToHex(), formatNumber(yen))
	headline.Text = free and "FREE ROLL READY" or ("NEXT FREE  " .. clock(wait))
	headline.TextColor3 = free and TEXT or MUTED
	subline.Text = string.format("Extra rolls ¥%s  ·  a free roll every %d hours", formatNumber(gacha.price), gacha.cooldown // 3600)
	pityText.Text = string.format("PITY  %d / %d  ·  S GUARANTEED", pity, gacha.pity)
	pityFill.Size = UDim2.fromScale(math.clamp(pity / gacha.pity, 0, 1), 1)
	local ready = (free or yen >= gacha.price) and not spinning
	if spinning then
		rollText.Text = "..."
	elseif free then
		rollText.Text = "ROLL  ·  FREE"
	else
		rollText.Text = "ROLL  ·  ¥" .. formatNumber(gacha.price)
	end
	rollText.TextTransparency = ready and 0 or 0.55
	local lit = ready and rollHover
	if lit ~= rollLit then
		rollLit = lit
		local info = TweenInfo.new(HOVER_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(rollHighlight, info, { BackgroundTransparency = lit and 0.85 or 1 }):Play()
		TweenService:Create(rollBar, info, { Size = UDim2.new(0, 3, lit and 1 or 0, 0) }):Play()
	end
	-- each tier's chance now: its weight over the tiers that have powers, or S for sure at the pity limit
	local total = 0
	for _, tier in ipairs(PowerConfig.Tiers) do
		if pool[tier] then
			total += PowerConfig.TierWeight[tier]
		end
	end
	local sure = pity >= gacha.pity and pool.S ~= nil
	for tier, chanceLabel in pairs(chanceLabels) do
		local chance = 0
		if pool[tier] then
			chance = sure and (tier == "S" and 100 or 0) or PowerConfig.TierWeight[tier] / total * 100
		end
		chanceLabel.Text = chance == math.floor(chance) and string.format("%d%%", chance) or string.format("%.1f%%", chance)
		chanceLabel.TextTransparency = chance > 0 and 0 or 0.6
	end
end

rollButton.MouseEnter:Connect(function()
	rollHover = true
	refresh()
end)
rollButton.MouseLeave:Connect(function()
	rollHover = false
	refresh()
end)

-- squares thrown out from the card in its tier colour
local function burst(color, count)
	local random = Random.new()
	for _ = 1, count do
		local size = random:NextInteger(5, 11)
		local angle = random:NextNumber() * math.pi * 2
		local distance = random:NextInteger(120, 340)
		local piece = make("Frame", {
			Parent = scrim,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = random:NextInteger(0, 90),
			ZIndex = 13,
		})
		local tween = TweenService:Create(piece, TweenInfo.new(0.8 + random:NextNumber() * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
			BackgroundTransparency = 1,
			Rotation = piece.Rotation + random:NextInteger(-180, 180),
		})
		tween.Completed:Once(function()
			piece:Destroy()
		end)
		tween:Play()
	end
end

-- the card jolts for a moment
local function shake(strength)
	local random = Random.new()
	for step = 1, 14 do
		local fade = 1 - step / 14
		card.Position = UDim2.new(0.5, random:NextInteger(-strength, strength) * fade, 0.5, random:NextInteger(-strength, strength) * fade)
		task.wait(0.03)
	end
	card.Position = UDim2.fromScale(0.5, 0.5)
end

-- the reveal: the scrim comes down, the card's edge flickers through the tiers, slowing, and
-- settles on the one you got; the card flips to name the power, the better tiers hitting harder
local function reveal(setName)
	local tier = SkillSetConfig.Sets[setName].tier
	local color = tierColor(tier)
	local rank = table.find(PowerConfig.Tiers, tier) -- 1 is the best
	local random = Random.new()
	cardBack.Visible = true
	cardFront.Visible = false
	cardStroke.Color = TEXT
	cardStroke.Thickness = 2
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	card.Position = UDim2.fromScale(0.5, 0.5)
	continueHint.TextTransparency = 1
	scrim.Visible = true
	scrim.BackgroundTransparency = 1
	TweenService:Create(scrim, TweenInfo.new(0.35), { BackgroundTransparency = 0.2 }):Play()
	-- the card rises into place
	card.Size = UDim2.fromOffset(CARD_WIDTH * 0.8, CARD_HEIGHT * 0.8)
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT) }):Play()
	task.wait(0.5)
	-- the edge flickers, slower and slower
	local started = os.clock()
	local last
	while os.clock() - started < TEASE_TIME do
		local progress = (os.clock() - started) / TEASE_TIME
		local pick
		repeat
			pick = PowerConfig.Tiers[random:NextInteger(1, #PowerConfig.Tiers)]
		until pick ~= last
		last = pick
		cardStroke.Color = tierColor(pick)
		cardStroke.Thickness = 5
		TweenService:Create(cardStroke, TweenInfo.new(0.08), { Thickness = 2 }):Play()
		task.wait(0.06 + progress * progress * 0.3)
	end
	cardStroke.Color = color
	cardStroke.Thickness = 6
	TweenService:Create(cardStroke, TweenInfo.new(0.3), { Thickness = 3 }):Play()
	task.wait(0.45)
	-- the flip: narrows to an edge, swaps its face, opens again
	TweenService:Create(card, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(0, CARD_HEIGHT) }):Play()
	task.wait(0.17)
	cardBack.Visible = false
	cardFront.Visible = true
	tierLabel.Text = tier
	tierLabel.TextColor3 = color
	nameLabel.Text = string.upper(powerName(setName))
	tierBar.BackgroundColor3 = color
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT) }):Play()
	claimRemote:FireServer() -- the card is face up: the briefcase goes in the hotbar
	burst(color, ({ 34, 20, 10, 5 })[rank] or 5)
	if rank <= 2 then
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = rank == 1 and 0.5 or 0.75
		TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
		task.spawn(shake, rank == 1 and 8 or 4)
	end
	task.wait(0.8)
	TweenService:Create(continueHint, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	revealDone = true
end

-- puts the card away
local function dismiss()
	if not revealDone then
		return
	end
	revealDone = false
	local tween = TweenService:Create(scrim, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Wait()
	scrim.Visible = false
	spinning = false
	refresh()
end

local function roll()
	if spinning then
		return
	end
	spinning = true
	setStatus("")
	refresh()
	local ok, success, message, setName = pcall(rollRemote.InvokeServer, rollRemote)
	if not ok then
		spinning = false
		setStatus("Couldn't reach the gacha", true)
		refresh()
		return
	end
	if not success or not SkillSetConfig.Sets[setName] then
		spinning = false
		setStatus(message or "Couldn't roll", true)
		refresh()
		return
	end
	reveal(setName)
	setStatus(message)
end
rollButton.Activated:Connect(roll)

local function close()
	if not gui.Enabled then
		return
	end
	ShopFocus.End()
	gui.Enabled = false
	scrim.Visible = false
	openAt = nil
	revealDone = false
	spinning = false
	Menus.Close("Gacha")
end

-- E LEAVE, on the left of the bottom bar
MenuFooter.Leave(gui, close, UDim2.new(0, PAD, 1, -(BOTTOM_BAR - HudConfig.HintsHeight) / 2))

scrim.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dismiss()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not gui.Enabled or processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Return then
		if revealDone then
			dismiss()
		else
			roll()
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local npc = prompt:FindFirstAncestorOfClass("Model")
	if npc and CollectionService:HasTag(npc, PowerConfig.Gacha.tag) then
		openAt = npc
		setStatus("")
		paintHeader(npc)
		scrim.Visible = false
		revealDone = false
		spinning = false
		refresh()
		Menus.Open("Gacha", close)
		gui.Enabled = true
		intro()
		-- the close-up on the dealer (E leaves)
		ShopFocus.Begin(npc, { ignoreGui = gui, onLeave = close })
	end
end)

-- keeps the countdown and your yen current, and closes when you walk away
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	if not openAt then
		return
	end
	ShopFocus.Step()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > PowerConfig.Gacha.range then
		close()
		return
	end
	elapsed += dt
	if elapsed >= 0.5 then
		elapsed = 0
		refresh()
	end
end)
