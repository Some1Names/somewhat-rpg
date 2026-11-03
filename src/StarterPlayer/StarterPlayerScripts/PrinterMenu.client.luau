-- The 3D printer's menu, in the shops' look like the smith's (ReforgeMenu): opens from a prompt this
-- script puts on everything tagged "Printer" (a part or a model) over a full-screen close-up of the
-- printer (ShopFocus, which also makes E leave). Black bars close in along the top and bottom (E
-- LEAVE and your yen in the bottom one), a dark fades off the left edge, and the column slides in:
-- the printer's line, its title big, your open print slots as cards (each with its print's name,
-- countdown and progress bar: click a finished one to collect it, × cancels one still running),
-- then a search box, the sort (click to change it) and a chip per category over the recipes you
-- know as rows (ones still to learn are left out). Beside them a pane for the picked recipe: what
-- it makes, the materials it needs against what you hold, the yen and print time, then PRINT. A
-- cyan scan sweeps the pane as it opens and when a print starts, and the printer glows a moment.
-- Every action goes
-- through the CraftAction remote (CraftServer), which does all the checking; its replies are
-- subtitles under the printer. Closes when you walk away, or when another menu opens (Menus).
-- A printer's ShopTitle / ShopSubtitle / ShopkeeperName attributes rename the header.
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CraftConfig = require(ReplicatedStorage:WaitForChild("CraftConfig"))
local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local TalismanConfig = require(ReplicatedStorage:WaitForChild("TalismanConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local MenuFooter = require(script.Parent:WaitForChild("MenuFooter"))
local ShopFocus = require(script.Parent:WaitForChild("ShopFocus"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local remote = ReplicatedStorage:WaitForChild(CraftConfig.Remote)
local player = Players.LocalPlayer

local PAD = 64 -- the screen's left edge to the column (as on the title menu and the shops)
local COLUMN_WIDTH = 400
local COLUMN_GAP = 26 -- between the top bar and the column, and the column and the bottom bar
local FILTER_TOP = 186 -- the search box and the sort, under the slot cards
local FILTER_HEIGHT = 30
local FILTER_GAP = 6
local CHIP_HEIGHT = 22 -- the category chips, under the search
local SORT_WIDTH = 130
local HEADER = FILTER_TOP + FILTER_HEIGHT + FILTER_GAP + CHIP_HEIGHT + 12 -- the list's top: under all of the above
local SLOT_TOP = 102 -- the slot cards' top (level with the pane's)
local SLOT_HEIGHT = 66
local SLOT_GAP = 8
local BOTTOM_BAR = 44
local ROBLOX_BAR_FALLBACK = 58 -- Roblox's band across the top, while GetGuiInset still says 0
local SHADE_SHARE = 0.62 -- how far across the screen the dark fades off the left edge
local SPEECH_AT = 0.85 -- the middle of the subtitles, across the screen (under the printer)
local SPEECH_WIDTH = 0.26
local OPEN_TIME = 0.45 -- the bars closing in, the column sliding in
local ROW_STAGGER = 0.05 -- seconds between rows fading in as it opens
local SCAN_TIME = 0.7 -- the cyan line sweeping down the pane
local GLOW_TIME = 0.9 -- the printer's glow fading out
local HOVER_TIME = 0.15
local NUMBER_WIDTH = 28
local ROW_HEIGHT = 58
local BADGE_SIZE = 30
local DETAIL_GAP = 28
local DETAIL_WIDTH = 340
local DETAIL_TOP = 102
local CAMERA_SHIFT = 4.5 -- studs the printer sits right of centre (the camera stands further back for a prop)
local SHIFT_PER_SIZE = 0.35 -- a bigger printer sits further right: this much of its size (its diagonal)
local PROMPT_DISTANCE = CraftConfig.Range - 2
local PROMPT_RETRY = 2 -- seconds between looks for printers without a prompt yet (streamed in later)
local Style = HudConfig.Style
local Theme = HudConfig.HubTheme
local BACKGROUND = Style.Glass
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local GOLD = Color3.fromRGB(255, 205, 60)
local ACCENT = Color3.fromRGB(60, 224, 230) -- the printer's cyan
local DANGER = Color3.fromRGB(226, 75, 74)
local GOOD = Color3.fromRGB(90, 200, 120)
local RARITY_COLORS = {
	Common = Color3.fromRGB(190, 190, 195),
	Uncommon = Color3.fromRGB(90, 200, 120),
	Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 110, 230),
	Legendary = Color3.fromRGB(255, 170, 50),
}
local RARITY_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

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

local function tween(instance, time, props, style)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tweenObject:Play()
	return tweenObject
end

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

local function formatTime(seconds)
	seconds = math.max(math.ceil(seconds), 0)
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function now()
	return workspace:GetServerTimeNow() -- the server's os.time(), give or take, so countdowns match
end

local function held(key)
	return player:GetAttribute(DropConfig.Attribute(key)) or 0
end

local function materialName(key)
	local material = DropConfig.Materials[key]
	return material and material.display or key
end

local function materialColor(key)
	local material = DropConfig.Materials[key]
	return material and DropConfig.TierColor(material.tier) or TEXT
end

-- a recipe's colour: its first material's tier
local function recipeColor(recipe)
	return materialColor(recipe.materials[1].material)
end

local function outputName(recipe)
	if recipe.output.kind == "talisman" then
		return "TALISMAN"
	end
	return string.upper(recipe.output.slot) .. " GEAR"
end

-- the list's sorts, in the order the sort button goes through them (no key: the recipes' own order)
local SORTS = {
	{ title = "DEFAULT" },
	{
		title = "NAME",
		key = function(recipe)
			return recipe.name
		end,
	},
	{
		title = "PRINT TIME",
		key = function(recipe)
			return recipe.seconds
		end,
	},
	{
		title = "COST",
		key = function(recipe)
			return recipe.yen
		end,
	},
}

local function categoryOf(recipe)
	return recipe.output.kind == "talisman" and "Talisman" or recipe.output.slot
end

-- the category chips: All, then each kind of thing the recipes make, in the order they first come
local CATEGORIES = { "All" }
for _, recipe in ipairs(CraftConfig.Recipes) do
	if not table.find(CATEGORIES, categoryOf(recipe)) then
		table.insert(CATEGORIES, categoryOf(recipe))
	end
end

local gui = make("ScreenGui", {
	Name = "PrinterMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 30,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- the shops' look: black bars along the top and the bottom, the dark fading off the left edge for
-- the column, the right left clear for the printer. The frame over the whole screen is Active, so a
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

-- the column down the left: the printer's line with the cyan before it, its title big, the slot
-- cards, then the recipes (they scroll on a short screen)
local column = make("Frame", { Parent = backdrop, BackgroundTransparency = 1, ZIndex = 5 })
make("Frame", { Parent = column, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = ACCENT, BorderSizePixel = 0, ZIndex = 5 })
local subtitle = label(column, { Text = "FABRICATION", Font = Style.MonoFont, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -34, 0, 14), ZIndex = 5 })
local title = label(column, {
	Text = "3D PRINTER",
	Font = Style.TitleFont,
	TextScaled = true,
	Position = UDim2.fromOffset(-2, 18),
	Size = UDim2.new(1, 0, 0, 72),
	ZIndex = 5,
})
make("UITextSizeConstraint", { Parent = title, MaxTextSize = 72 })
-- the open print slots, as cards in a row (renderSlots)
local slotStrip = make("Frame", { Parent = column, Position = UDim2.fromOffset(0, SLOT_TOP), Size = UDim2.new(1, -8, 0, SLOT_HEIGHT), BackgroundTransparency = 1, ZIndex = 5 })
make("UIListLayout", { Parent = slotStrip, FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, SLOT_GAP) })
-- over the recipes: a search box and the sort (a click picks the next one), then a chip per category
local filterBar = make("Frame", { Parent = column, Position = UDim2.fromOffset(0, FILTER_TOP), Size = UDim2.new(1, -8, 0, FILTER_HEIGHT), BackgroundTransparency = 1, ZIndex = 5 })
local searchBox = make("TextBox", {
	Parent = filterBar,
	Size = UDim2.new(1, -(SORT_WIDTH + FILTER_GAP), 1, 0),
	BackgroundColor3 = Theme.Nav,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Style.MonoFont,
	PlaceholderText = "SEARCH RECIPES",
	PlaceholderColor3 = MUTED,
	Text = "",
	TextColor3 = TEXT,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})
make("UIStroke", { Parent = searchBox, Color = Theme.Edge, Transparency = Theme.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", { Parent = searchBox, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
local sortButton = make("TextButton", {
	Parent = filterBar,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, SORT_WIDTH, 1, 0),
	BackgroundColor3 = Theme.Nav,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Font = Style.MonoFont,
	Text = "",
	TextColor3 = ACCENT,
	TextSize = 11,
	ZIndex = 5,
})
make("UIStroke", { Parent = sortButton, Color = Theme.Edge, Transparency = Theme.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
local chipRow = make("Frame", {
	Parent = column,
	Position = UDim2.fromOffset(0, FILTER_TOP + FILTER_HEIGHT + FILTER_GAP),
	Size = UDim2.new(1, -8, 0, CHIP_HEIGHT),
	BackgroundTransparency = 1,
	ZIndex = 5,
})
make("UIListLayout", { Parent = chipRow, FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, FILTER_GAP) })
local categoryChips = {} -- category -> its chip
for index, category in ipairs(CATEGORIES) do
	local chip = make("TextButton", {
		Parent = chipRow,
		LayoutOrder = index,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Style.MonoFont,
		Text = string.upper(category),
		TextColor3 = MUTED,
		TextSize = 11,
		ZIndex = 5,
	})
	make("UIPadding", { Parent = chip, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
	make("UIStroke", { Parent = chip, Color = Theme.Edge, Transparency = Theme.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	categoryChips[category] = chip
end
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
local list = make("Frame", { Parent = panel, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 })
make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder })

-- the picked recipe's pane, beside the list: its name and what it makes over a rule, then its
-- rows (they scroll)
local detail = make("Frame", {
	Parent = column,
	Position = UDim2.fromOffset(COLUMN_WIDTH + DETAIL_GAP, DETAIL_TOP),
	Size = UDim2.new(0, DETAIL_WIDTH, 1, -(DETAIL_TOP + 48)),
	BackgroundColor3 = Theme.Nav,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	ClipsDescendants = true,
})
make("UIStroke", { Parent = detail, Color = Theme.Edge, Transparency = Theme.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
-- the scan: a cyan line with a glow trailing above it, swept down the pane (scan())
local scanLine = make("Frame", {
	Parent = detail,
	Size = UDim2.new(1, 0, 0, 2),
	BackgroundColor3 = ACCENT,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 8,
})
local scanGlow = make("Frame", {
	Parent = scanLine,
	AnchorPoint = Vector2.new(0, 1),
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundColor3 = ACCENT,
	BorderSizePixel = 0,
	ZIndex = 8,
})
make("UIGradient", {
	Parent = scanGlow,
	Rotation = 90,
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.75) }),
})
local inner = make("Frame", { Parent = detail, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
make("UIPadding", {
	Parent = inner,
	PaddingTop = UDim.new(0, 16),
	PaddingBottom = UDim.new(0, 16),
	PaddingLeft = UDim.new(0, 16),
	PaddingRight = UDim.new(0, 16),
})
local detailTitle = label(inner, { Text = "", RichText = true, Font = Style.TitleFont, TextSize = 28, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 30) })
local detailSub = label(inner, { Text = "", Font = Style.MonoFont, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 14) })
make("Frame", { Parent = inner, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
local content = make("ScrollingFrame", {
	Parent = inner,
	Position = UDim2.fromOffset(0, 70),
	Size = UDim2.new(1, 0, 1, -70),
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

local recipeRows = {} -- the list's rows
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

-- the cyan line sweeps down the pane
local function scan()
	scanLine.Visible = true
	scanLine.BackgroundTransparency = 0
	scanGlow.BackgroundTransparency = 0
	scanLine.Position = UDim2.fromScale(0, 0)
	local sweep = tween(scanLine, SCAN_TIME, { Position = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Sine)
	sweep.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			scanLine.Visible = false
		end
	end)
end

-- the printer glows cyan a moment (a placeholder until the owner's print effect)
local function glow(printer)
	local highlight = make("Highlight", {
		Parent = printer,
		Adornee = printer,
		FillColor = ACCENT,
		OutlineColor = ACCENT,
		FillTransparency = 0.85,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.Occluded,
	})
	tween(highlight, GLOW_TIME, { FillTransparency = 1, OutlineTransparency = 1 }, Enum.EasingStyle.Quad).Completed:Connect(function()
		highlight:Destroy()
	end)
end

-- the bars close in, the column (with the pane) slides in from the left, the rows fade in one by
-- one, and the scan sweeps the pane
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
	for index, row in ipairs(recipeRows) do
		row.group.GroupTransparency = 1
		row.group.Position = UDim2.fromOffset(-24, 0)
		task.delay(OPEN_TIME * 0.5 + index * ROW_STAGGER, function()
			tween(row.group, 0.3, { GroupTransparency = 0, Position = UDim2.new() })
		end)
	end
	task.delay(OPEN_TIME * 0.6, scan)
end

-- the printer's replies, as subtitles under it: its name small in cyan over what the server said
-- (gold, or red when it refused)
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
	TextColor3 = ACCENT,
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

local selected = CraftConfig.Recipes[1].id
local busy = false
local openAt -- the printer whose menu is open, so walking away can close it
local render
local countdowns = {} -- { label, fill, finishAt, seconds } of the running prints, ticked while open
local query = "" -- the search box's text
local sortIndex = 1 -- into SORTS
local category = "All" -- the chip picked

-- the chips and the sort button show what's picked
local function paintFilters()
	sortButton.Text = "SORT  ·  " .. SORTS[sortIndex].title
	for name, chip in pairs(categoryChips) do
		local on = name == category
		chip.BackgroundTransparency = on and 0 or 1
		chip.TextColor3 = on and BACKGROUND or MUTED
	end
end

local function setStatus(text, failed)
	note.Text = text
	note.TextColor3 = failed and DANGER or GOLD
	speech.Visible = text ~= ""
end

-- names the printer: its line and title big (the ShopSubtitle and ShopTitle attributes, else
-- FABRICATION and 3D PRINTER), and over the subtitles
local function paintHeader(printer)
	title.Text = string.upper(printer:GetAttribute("ShopTitle") or "3D Printer")
	subtitle.Text = string.upper(printer:GetAttribute("ShopSubtitle") or "Fabrication")
	speakerLabel.Text = string.upper(printer:GetAttribute("ShopkeeperName") or title.Text)
end

-- one action to the server; returns whether it went through
local function request(...)
	if busy then
		return false
	end
	busy = true
	local ok, success, message = pcall(remote.InvokeServer, remote, ...)
	busy = false
	if not ok then
		setStatus("The printer didn't answer", true)
		return false
	end
	if message and message ~= "" then
		setStatus(message, not success)
	end
	return success
end

-- the open print slots as cards: the print's name, countdown and progress bar (a finished one is
-- lit green and collects on a click; × cancels one still running), or EMPTY. The line over the
-- title says the level the next slot opens at.
local function renderSlots(jobs, slots, nextAt)
	subtitle.Text = string.upper(openAt and openAt:GetAttribute("ShopSubtitle") or "Fabrication") .. (nextAt and string.format("   ·   NEXT SLOT AT LV %d", nextAt) or "")
	clear(slotStrip)
	for index = 1, slots do
		local job = jobs[index]
		local recipe = job and CraftConfig.Get(job.recipe)
		local ready = job ~= nil and CraftConfig.IsReady(job, now())
		local card = make("TextButton", {
			Parent = slotStrip,
			LayoutOrder = index,
			Size = UDim2.new(1 / slots, -SLOT_GAP * (slots - 1) / slots, 1, 0),
			BackgroundColor3 = ready and GOOD or Theme.Nav,
			BackgroundTransparency = ready and 0.8 or 0.25,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = ready,
			ZIndex = 5,
		})
		make("UIStroke", { Parent = card, Color = ready and GOOD or Theme.Edge, Transparency = ready and 0.2 or Theme.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		make("UIPadding", { Parent = card, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 8) })
		label(card, { Text = string.format("SLOT %d", index), Font = Style.MonoFont, TextSize = 10, TextColor3 = ready and GOOD or ACCENT, Size = UDim2.new(1, -18, 0, 12), ZIndex = 5 })
		label(card, {
			Text = recipe and string.upper(recipe.name) or "EMPTY",
			Font = Style.TitleFont,
			TextSize = 17,
			TextColor3 = recipe and TEXT or MUTED,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.new(1, 0, 0, 20),
			ZIndex = 5,
		})
		if not job then
			continue
		end
		local timeLabel = label(card, {
			Text = ready and "READY · COLLECT" or formatTime(job.finishAt - now()),
			Font = Style.MonoFont,
			TextSize = 11,
			TextColor3 = ready and GOOD or ACCENT,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(0, 35),
			Size = UDim2.new(1, 0, 0, 12),
			ZIndex = 5,
		})
		-- the progress bar along the bottom
		local track = make("Frame", { Parent = card, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Theme.BarBack, BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 5 })
		local fill = make("Frame", {
			Parent = track,
			Size = UDim2.fromScale(ready and 1 or math.clamp(1 - (job.finishAt - now()) / recipe.seconds, 0, 1), 1),
			BackgroundColor3 = ready and GOOD or ACCENT,
			BorderSizePixel = 0,
			ZIndex = 5,
		})
		if ready then
			card.Activated:Connect(function()
				if request("collect", index) and openAt then
					glow(openAt)
				end
				render()
			end)
		else
			table.insert(countdowns, { label = timeLabel, fill = fill, finishAt = job.finishAt, seconds = recipe.seconds })
			-- × cancels it (half the materials back)
			local cancel = make("TextButton", {
				Parent = card,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, -2),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Font = Style.MonoFont,
				Text = "×",
				TextSize = 14,
				TextColor3 = DANGER,
				ZIndex = 6,
			})
			cancel.Activated:Connect(function()
				request("cancel", index)
				render()
			end)
		end
	end
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
local function ruledRow(name, nameColor, value, valueColor, richValue)
	local row = make("Frame", { Parent = content, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	make("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
	label(row, { Text = name, TextSize = 13, TextColor3 = nameColor, Size = UDim2.new(1, 0, 0, 26) })
	local valueLabel = label(row, {
		Text = value,
		RichText = richValue == true,
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

-- a wide button in the printer's cyan (or `color`); `enabled` greys it out (the server still checks);
-- `outlined` draws it as an outline instead
local function wideButton(text, enabled, onClick, color, outlined)
	color = color or ACCENT
	local b = make("TextButton", {
		Parent = content,
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = color,
		BackgroundTransparency = outlined and 1 or (enabled and 0 or 0.6),
		BorderSizePixel = 0,
		Font = Style.TitleFont,
		TextSize = 16,
		TextColor3 = outlined and color or BACKGROUND,
		Text = text,
		AutoButtonColor = enabled and not outlined,
	})
	if outlined then
		make("UIStroke", { Parent = b, Color = color, Transparency = enabled and 0.3 or 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	b.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	return b
end

-- the tabs ---------------------------------------------------------------------------

local function recipeTab(recipe, jobs, slots, yen)
	if recipe.output.kind == "talisman" then
		local item = TalismanConfig.Get(recipe.output.key)
		ruledRow("Makes", TEXT, item and item.name or recipe.output.key, ACCENT)
		ruledRow("Effect", TEXT, item and item.description or "", TEXT)
	else
		ruledRow("Makes", TEXT, string.format("%s gear, up to Lv %d", recipe.output.slot, recipe.maxLevel or 1), ACCENT)
		-- the rarities it can roll and their odds, each in its colour
		local rarities, total = {}, 0
		for rarity, weight in pairs(recipe.rarityWeights or {}) do
			table.insert(rarities, rarity)
			total += weight
		end
		table.sort(rarities, function(a, b)
			return (RARITY_ORDER[a] or 99) < (RARITY_ORDER[b] or 99)
		end)
		local parts = {}
		for _, rarity in ipairs(rarities) do
			table.insert(parts, string.format('<font color="#%s">%s %d%%</font>', (RARITY_COLORS[rarity] or TEXT):ToHex(), rarity, math.floor(recipe.rarityWeights[rarity] / total * 100 + 0.5)))
		end
		ruledRow("Rolls", TEXT, table.concat(parts, "  ·  "), TEXT, true)
	end
	ruledRow("Print time", TEXT, formatTime(recipe.seconds), TEXT)
	heading("REQUIRED")
	for _, cost in ipairs(recipe.materials) do
		local have = held(cost.material)
		ruledRow(materialName(cost.material), materialColor(cost.material), string.format("%d / %d", have, cost.amount), have >= cost.amount and TEXT or DANGER)
	end
	ruledRow("Yen", GOLD, string.format("%s / %s", formatYen(yen), formatYen(recipe.yen)), yen >= recipe.yen and TEXT or DANGER)
	local free = #jobs < slots
	local can = free and CraftConfig.CanAfford(recipe, held, yen)
	wideButton(free and "PRINT" or "NO FREE PRINT SLOT", can, function()
		if request("start", recipe.id) then
			scan()
			if openAt then
				glow(openAt)
			end
		end
		render()
	end)
end

-- the whole menu --------------------------------------------------------------------

render = function()
	if not gui.Enabled then
		return
	end
	local yen = player:GetAttribute("Yen") or 0
	local level = player:GetAttribute("Level") or 0
	local known = player:GetAttribute(CraftConfig.KnownAttribute)
	local jobs = CraftConfig.ParseJobs(player:GetAttribute(CraftConfig.JobsAttribute))
	local slots = CraftConfig.JobSlots(level)
	balance.Text = string.format('CASH  <font color="#%s">%s</font>', GOLD:ToHex(), formatYen(yen))
	table.clear(countdowns)
	renderSlots(jobs, slots, CraftConfig.NextSlotLevel(level))

	-- the recipes you know, as the shops' rows: number, what it makes, name, its grade and the print time.
	-- The picked one is lit; a row under the mouse brightens a little (hoverRows)
	clear(list)
	recipeRows = {}
	hoveredRow = nil
	-- the known ones in the picked category whose name has the search in it, sorted
	local recipes, anyKnown = {}, false
	local needle = string.lower(query)
	for _, recipe in ipairs(CraftConfig.Recipes) do
		if CraftConfig.IsKnown(known, recipe.id) then
			anyKnown = true
			if (category == "All" or categoryOf(recipe) == category) and string.find(string.lower(recipe.name), needle, 1, true) then
				table.insert(recipes, recipe)
			end
		end
	end
	local sortKey = SORTS[sortIndex].key
	if sortKey then
		local order = {}
		for index, recipe in ipairs(recipes) do
			order[recipe] = index
		end
		table.sort(recipes, function(a, b)
			local keyA, keyB = sortKey(a), sortKey(b)
			if keyA ~= keyB then
				return keyA < keyB
			end
			return order[a] < order[b]
		end)
	end
	-- the picked one stays picked while it's listed (or nothing is), else the first listed is
	if recipes[1] and not table.find(recipes, CraftConfig.Get(selected)) then
		selected = recipes[1].id
	end
	if not CraftConfig.IsKnown(known, selected) then
		selected = nil
	end
	paintFilters()
	if #recipes == 0 then
		label(list, { Text = anyKnown and "No recipes match" or "You don't know any recipes yet", TextSize = 13, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, ROW_HEIGHT) })
	end
	for index, recipe in ipairs(recipes) do
		local isSelected = recipe.id == selected
		local color = recipeColor(recipe)
		local row = make("TextButton", {
			Parent = list,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
		})
		-- the row's insides, faded in one by one as the menu opens (intro)
		local group = make("CanvasGroup", { Parent = row, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 })
		local highlight = make("Frame", { Parent = group, Size = UDim2.fromScale(1, 1), BackgroundColor3 = ACCENT, BackgroundTransparency = isSelected and 0.82 or 1, BorderSizePixel = 0 })
		make("UIGradient", { Parent = highlight, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
		make("Frame", {
			Parent = group,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(0, 3, isSelected and 1 or 0, 0),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
		-- the thin rule under each row
		make("Frame", { Parent = group, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.88, BorderSizePixel = 0 })
		local body = make("Frame", { Parent = group, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 })
		make("UIPadding", { Parent = body, PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
		local number = label(body, {
			Text = string.format("%02d", index),
			Font = Style.MonoFont,
			TextSize = 11,
			TextColor3 = isSelected and ACCENT or MUTED,
			Size = UDim2.fromOffset(NUMBER_WIDTH, 22),
		})
		-- the badge: what it makes (H head, B body, T talisman) in its grade's colour
		local badgeColor = color
		local badge = label(body, {
			Text = recipe.output.kind == "talisman" and "T" or string.sub(recipe.output.slot, 1, 1),
			Font = Style.TitleFont,
			TextSize = 18,
			TextColor3 = badgeColor,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, NUMBER_WIDTH, 0.5, 0),
			Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE),
		})
		make("UIStroke", { Parent = badge, Color = badgeColor, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		local textLeft = NUMBER_WIDTH + BADGE_SIZE + 10
		label(body, {
			Text = string.upper(recipe.name),
			Font = Style.TitleFont,
			TextSize = 22,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(textLeft, 0),
			Size = UDim2.new(1, -(textLeft + 56), 0, 22),
		})
		label(body, {
			Text = string.format("%s  ·  %s", outputName(recipe), string.upper(recipe.tier)),
			Font = Style.MonoFont,
			TextSize = 11,
			TextColor3 = ACCENT,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(textLeft, 26),
			Size = UDim2.new(1, -(textLeft + 56), 0, 14),
		})
		-- the print time, top right (where a shop's row has its price)
		label(body, {
			Text = formatTime(recipe.seconds),
			Font = Style.MonoFont,
			TextSize = 14,
			TextColor3 = ACCENT,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(56, 20),
		})
		-- under the mouse a row only brightens a little, so the picked one stays the one lit
		local function paint(over)
			tween(highlight, HOVER_TIME, { BackgroundTransparency = isSelected and 0.82 or over and 0.93 or 1 })
			tween(number, HOVER_TIME, { TextColor3 = isSelected and ACCENT or over and TEXT or MUTED })
		end
		row.Activated:Connect(function()
			if selected ~= recipe.id then
				selected = recipe.id
				setStatus("")
				render()
			end
		end)
		table.insert(recipeRows, { frame = row, group = group, paint = paint })
	end

	-- the picked recipe's pane
	clear(content)
	contentOrder = 0
	local recipe = selected and CraftConfig.Get(selected)
	detail.Visible = recipe ~= nil
	if not recipe then
		return
	end
	detailTitle.Text = string.upper(recipe.name)
	detailSub.Text = string.format("%s  ·  %s GRADE", outputName(recipe), string.upper(recipe.tier))
	detailSub.TextColor3 = recipeColor(recipe)
	recipeTab(recipe, jobs, slots, yen)
end

-- (only what the menu shows: other attributes tick all the time, and rebuilding the rows drops clicks)
local MATERIAL_PREFIX = DropConfig.Attribute("")
player.AttributeChanged:Connect(function(name)
	if
		gui.Enabled
		and (
			name == "Yen"
			or name == "Level"
			or name == CraftConfig.JobsAttribute
			or name == CraftConfig.KnownAttribute
			or string.sub(name, 1, #MATERIAL_PREFIX) == MATERIAL_PREFIX
		)
	then
		render()
	end
end)

local function close()
	ShopFocus.End()
	gui.Enabled = false
	openAt = nil
	Menus.Close("Printer")
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
		for _, row in ipairs(recipeRows) do
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

-- searching, sorting and picking a category redraw the list
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	query = searchBox.Text
	render()
end)
sortButton.Activated:Connect(function()
	sortIndex = sortIndex % #SORTS + 1
	render()
end)
for name, chip in pairs(categoryChips) do
	chip.Activated:Connect(function()
		category = name
		render()
	end)
end

local function open(printer)
	openAt = printer
	setStatus("")
	-- a fresh search and category each time (the sort stays)
	searchBox.Text = ""
	query, category = "", "All"
	paintHeader(printer)
	Menus.Open("Printer", close)
	gui.Enabled = true
	render()
	panel.CanvasPosition = Vector2.zero
	intro()
	glow(printer)
	-- the full-screen close-up on the printer (E leaves)
	local size = printer:IsA("Model") and printer:GetExtentsSize() or printer.Size
	ShopFocus.Begin(printer, { ignoreGui = gui, onLeave = close, shift = math.max(CAMERA_SHIFT, size.Magnitude * SHIFT_PER_SIZE) })
end

-- the prompt on each printer: a part's own, or on a model the biggest part of its "ProximityPrompt"
-- child (the console), else its primary or first part
local function promptPart(printer)
	if printer:IsA("BasePart") then
		return printer
	end
	local console = printer:FindFirstChild("ProximityPrompt")
	if console and console:IsA("BasePart") then
		return console
	end
	local best
	for _, part in ipairs(console and console:GetDescendants() or {}) do
		if part:IsA("BasePart") and (not best or part.Size.Magnitude > best.Size.Magnitude) then
			best = part
		end
	end
	if console then
		return best -- (nil while the console hasn't streamed in: the next look tries again)
	end
	return printer.PrimaryPart or printer:FindFirstChildWhichIsA("BasePart", true)
end

local function addPrompt(printer)
	local part = (printer:IsA("BasePart") or printer:IsA("Model")) and promptPart(printer)
	if not part or part:FindFirstChild("PrinterPrompt") then
		return
	end
	make("ProximityPrompt", {
		Name = "PrinterPrompt",
		Parent = part,
		ActionText = "Print",
		ObjectText = "3D Printer",
		MaxActivationDistance = PROMPT_DISTANCE,
		RequiresLineOfSight = false,
	})
end
CollectionService:GetInstanceAddedSignal(CraftConfig.Tag):Connect(addPrompt)
-- a printer (or its console) streamed in later gets its prompt on the next look
task.spawn(function()
	while true do
		for _, printer in ipairs(CollectionService:GetTagged(CraftConfig.Tag)) do
			addPrompt(printer)
		end
		task.wait(PROMPT_RETRY)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= "PrinterPrompt" or openAt then
		return
	end
	local printer = prompt.Parent
	while printer and not CollectionService:HasTag(printer, CraftConfig.Tag) do
		printer = printer.Parent
	end
	if printer then
		open(printer)
	end
end)

-- countdowns and progress bars tick, a print that finishes turns to COLLECT, and walking away closes
local lastTick = 0
RunService.Heartbeat:Connect(function()
	if not openAt then
		return
	end
	hoverRows()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > CraftConfig.Range then
		close()
		return
	end
	if os.clock() - lastTick < 0.2 then
		return
	end
	lastTick = os.clock()
	local time = now()
	for _, countdown in ipairs(countdowns) do
		if time >= countdown.finishAt then
			render()
			return
		end
		countdown.label.Text = formatTime(countdown.finishAt - time)
		countdown.fill.Size = UDim2.fromScale(math.clamp(1 - (countdown.finishAt - time) / countdown.seconds, 0, 1), 1)
	end
end)
