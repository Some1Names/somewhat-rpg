-- The hub: one full-screen menu holding Profile, Backpack (Inventory), Map, Quests,
-- Stats and Updates, with locked slots for later features. The first script to
-- require it builds the screen in Modern Warfare's style with Arknights' editorial bits:
-- dark see-through paper (darkest on the left), the nav on the left (a narrow rail with
-- the level, the swatches and ESC, then the numbered list of tabs on smoked glass), the
-- header (#TITLE, the accent bar and the tab's number), the footer (an ESC key chip and
-- #SOMEWHAT), and on the right the strip HubPose draws the posed character in. Tab cards
-- (frames in Theme.Panel) are drawn as smoked glass with a thin light edge.
-- Each tab is a script that asks Hub.Tab(name, opts) for a frame and builds in
-- it; a tab's key (B, J, M) opens the hub on it, closes it if it's the one
-- showing, or switches to it; not while the title menu is up, nor when
-- Hub.OpenOnly showed one tab alone (the title's UPDATES), with the nav's list
-- of tabs hidden. Esc closes. To Menus the hub is the one menu
-- "Hub", so opening Settings or the Shop closes it and the other way round.
-- The accent is the held power's colour (white with none); on the paper it's
-- drawn through HubRules.Ink so a light one stays visible. Square everything.
-- Motion: the nav slides in on open; on each tab the page eases up into place,
-- the title fades in and its bar sweeps across. Hover: nav entries nudge right,
-- the × turns, and every button in a tab gets an accent line under it.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HubRules = require(ReplicatedStorage:WaitForChild("HubRules"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme

local PAD = 16
local NAV_PAD = 14
local NAV_ROW = 34
local NAV_TOP = 64 -- the first tab button, this far under the brand
local LIST_TRANSPARENCY = 0.35 -- the nav's list, smoked glass beside the solid rail
local BAR_HEIGHT = 4 -- the accent bar after the #TITLE
local APART_GAP = 17 -- px between the numbered tabs' room and a tab kept apart
-- Roblox's own buttons sit in a band across the top: the hub leaves it empty paper.
-- Its height is read on each open (it's often still 0 while the game loads).
local ROBLOX_BAR_FALLBACK = 58
local SWATCH = 10
local TITLE_WIDTH = 330 -- the #TITLE's room, so the bar after it starts in the same place on every tab
local CLOSE_ROOM = 48 -- the header stops short of the × at the top right
local WHITE = Color3.new(1, 1, 1)

local OPEN_TIME = 0.35 -- the nav sliding in
local CLOSE_BLUR_TIME = 0.2
local BLUR_SIZE = 40 -- the gaussian blur of the world behind the hub
-- how much of that world shows through the paper: little on the left, more on the right
local PAPER_LEFT, PAPER_RIGHT = 0.05, 0.4
local PAGE_TIME = 0.3 -- a tab easing up into place, its title fading in
local BAR_TIME = 0.45 -- the title's bar sweeping across
local HOVER_TIME = 0.15
local PAGE_DROP = 18 -- px a tab starts below its place

local Hub = {}
Hub.Theme = Theme

local function tween(instance, time, props)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tweenObject:Play()
	return tweenObject
end

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
	props.Font = props.Font or Theme.LabelFont
	props.TextColor3 = props.TextColor3 or Theme.Ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "Hub",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- the whole screen, Roblox's top bar too
	DisplayOrder = 8,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- back to front: paper, the pose strip, the main column with the header and
-- footer (both always the full width, so they don't move between tabs), the nav, the ×
-- (Active: it catches clicks, so nothing behind the hub, the top bar's icons say, can be pressed)
-- see-through paper: the world behind it is gaussian-blurred while the hub is open
local paper = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Paper, BorderSizePixel = 0, ZIndex = 1, Active = true })
make("UIGradient", {
	Parent = paper,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, PAPER_LEFT),
		NumberSequenceKeypoint.new(0.45, (PAPER_LEFT + PAPER_RIGHT) / 2),
		NumberSequenceKeypoint.new(1, PAPER_RIGHT),
	}),
})
local blur = make("BlurEffect", { Name = "HubBlur", Size = 0, Parent = game:GetService("Lighting") })
-- everything else, below Roblox's band
local body = make("Frame", {
	Name = "Body",
	Parent = gui,
	BackgroundTransparency = 1,
	ZIndex = 2,
})
-- the nav column's colours (the solid rail, the smoked list) run up through the band, behind Roblox's buttons
local navCap = make("Frame", { Parent = gui, BackgroundTransparency = 1, ZIndex = 2 })
make("Frame", { Parent = navCap, Size = UDim2.new(0, Theme.RailWidth, 1, 0), BackgroundColor3 = Theme.Nav, BorderSizePixel = 0 })
make("Frame", {
	Parent = navCap,
	Position = UDim2.fromOffset(Theme.RailWidth, 0),
	Size = UDim2.new(1, -Theme.RailWidth, 1, 0),
	BackgroundColor3 = Theme.Nav,
	BackgroundTransparency = LIST_TRANSPARENCY,
	BorderSizePixel = 0,
})
local function placeBody()
	local band = GuiService:GetGuiInset().Y / UIScale.Get() -- Roblox's band is in real pixels
	band = band > 0 and band or ROBLOX_BAR_FALLBACK / UIScale.Get()
	body.Position = UDim2.fromOffset(0, band)
	body.Size = UDim2.new(1, 0, 1, -band)
	navCap.Size = UDim2.fromOffset(Theme.NavWidth, band)
end
placeBody()
UIScale.OnChange(placeBody)

-- between the header and the footer, so the character never covers the top
local poseStrip = make("Frame", {
	Name = "PoseStrip",
	Parent = body,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, Theme.HeaderHeight),
	Size = UDim2.new(Theme.PoseShare, 0, 1, -(Theme.HeaderHeight + Theme.FooterHeight)),
	BackgroundTransparency = 1,
	ZIndex = 2,
})
Hub.PoseStrip = poseStrip

local main = make("Frame", {
	Name = "Main",
	Parent = body,
	Position = UDim2.fromOffset(Theme.NavWidth, Theme.HeaderHeight),
	BackgroundTransparency = 1,
	ZIndex = 3,
})
local top = make("Frame", {
	Name = "Header",
	Parent = body,
	Position = UDim2.fromOffset(Theme.NavWidth, 0),
	Size = UDim2.new(1, -(Theme.NavWidth + CLOSE_ROOM), 0, Theme.HeaderHeight),
	BackgroundTransparency = 1,
	ZIndex = 3,
})

-- the strip shows on wide screens, on tabs that have a pose; the main column ends where it starts
local stripWanted = true -- the showing tab has a pose
local function layout()
	local shown = stripWanted and workspace.CurrentCamera.ViewportSize.X / UIScale.Get() >= Theme.PoseMinScreen
	poseStrip.Visible = shown
	local height = -(Theme.HeaderHeight + Theme.FooterHeight)
	main.Size = shown and UDim2.new(1 - Theme.PoseShare, -Theme.NavWidth, 1, height) or UDim2.new(1, -Theme.NavWidth, 1, height)
end
layout()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
UIScale.OnChange(layout)

-- header: a line of microtext, then #TITLE, the accent bar and (0n)
label(top, {
	Text = "2026 · SECTOR 01 · INDEX 004.19",
	TextSize = 11,
	TextColor3 = Theme.Muted,
	Position = UDim2.fromOffset(PAD, 10),
	Size = UDim2.new(1, -2 * PAD, 0, 12),
})
local titleRow = make("Frame", {
	Parent = top,
	Position = UDim2.fromOffset(PAD, 24),
	Size = UDim2.new(1, -2 * PAD, 0, 44),
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = titleRow,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 12),
})
local titleLabel = label(titleRow, {
	LayoutOrder = 1,
	Font = Theme.TitleFont,
	TextSize = 40,
	Size = UDim2.fromOffset(TITLE_WIDTH, 44),
})
local barHolder = make("Frame", { Parent = titleRow, LayoutOrder = 2, Size = UDim2.fromOffset(0, 44), BackgroundTransparency = 1 })
make("UIFlexItem", { Parent = barHolder, FlexMode = Enum.UIFlexMode.Fill })
local titleBar = make("Frame", {
	Parent = barHolder,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -12),
	Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
	BorderSizePixel = 0,
})
local numberLabel = label(titleRow, {
	LayoutOrder = 3,
	Font = Theme.MonoFont,
	TextSize = 20,
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
})

-- the tabs draw in here
local content = make("Frame", {
	Name = "Content",
	Parent = main,
	Position = UDim2.fromOffset(PAD, 0),
	Size = UDim2.new(1, -2 * PAD, 1, 0),
	BackgroundTransparency = 1,
})

-- footer: a thin rule, the [ESC] CLOSE MENU key chip, the record line, and #SOMEWHAT on an accent chip
local footer = make("Frame", {
	Parent = body,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, Theme.NavWidth + PAD, 1, 0),
	Size = UDim2.new(1, -(Theme.NavWidth + 2 * PAD), 0, Theme.FooterHeight),
	BackgroundTransparency = 1,
	ZIndex = 3,
})
make("Frame", { Parent = footer, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Edge, BackgroundTransparency = Theme.EdgeTransparency, BorderSizePixel = 0 })
local footerLeft = make("Frame", { Parent = footer, Size = UDim2.new(1, -120, 1, 0), BackgroundTransparency = 1 })
make("UIListLayout", {
	Parent = footerLeft,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 18),
})
local escButton = make("TextButton", {
	Parent = footerLeft,
	LayoutOrder = 1,
	Size = UDim2.fromOffset(0, 18),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Text = "",
})
make("UIListLayout", {
	Parent = escButton,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
})
-- the key in a small square box, the way Modern Warfare prints its prompts
local escChip = label(escButton, {
	LayoutOrder = 1,
	Text = "ESC",
	Font = Theme.MonoFont,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromOffset(30, 16),
})
make("UIStroke", { Parent = escChip, Color = Theme.Ink, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
local escText = label(escButton, {
	LayoutOrder = 2,
	Text = "CLOSE MENU",
	TextSize = 12,
	TextColor3 = Theme.Muted,
	Size = UDim2.fromOffset(0, 16),
	AutomaticSize = Enum.AutomaticSize.X,
})
label(footerLeft, {
	LayoutOrder = 2,
	Text = "SOMEWHAT RPG. INTERNAL RECORD. DATA SAVED ON LEAVE.",
	TextSize = 11,
	TextColor3 = Theme.Muted,
	Size = UDim2.fromOffset(0, 16),
	AutomaticSize = Enum.AutomaticSize.X,
})
local footerTag = make("Frame", {
	Parent = footer,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.fromOffset(0, 18),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = footerTag,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
})
label(footerTag, { LayoutOrder = 1, Text = "#", Font = Theme.TitleFont, TextSize = 14, Size = UDim2.fromOffset(10, 18) })
local footerChip = label(footerTag, {
	LayoutOrder = 2,
	Text = " SOMEWHAT ",
	Font = Theme.TitleFont,
	TextSize = 14,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(0, 18),
	AutomaticSize = Enum.AutomaticSize.X,
})
footerChip.BackgroundTransparency = 0

-- the nav column: the solid rail on the far left, the smoked list of tabs beside it
local nav = make("Frame", {
	Name = "Nav",
	Parent = body,
	Size = UDim2.new(0, Theme.NavWidth, 1, 0),
	BackgroundTransparency = 1,
	ZIndex = 4,
})
local rail = make("Frame", {
	Name = "Rail",
	Parent = nav,
	Size = UDim2.new(0, Theme.RailWidth, 1, 0),
	BackgroundColor3 = Theme.Nav,
	BorderSizePixel = 0,
})
local listPanel = make("Frame", {
	Parent = nav,
	Position = UDim2.fromOffset(Theme.RailWidth, 0),
	Size = UDim2.new(1, -Theme.RailWidth, 1, 0),
	BackgroundColor3 = Theme.Nav,
	BackgroundTransparency = LIST_TRANSPARENCY,
	BorderSizePixel = 0,
})
-- thin light edges after the rail and after the list
for _, holder in ipairs({ rail, listPanel }) do
	make("Frame", {
		Parent = holder,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Theme.Edge,
		BackgroundTransparency = Theme.EdgeTransparency,
		BorderSizePixel = 0,
	})
end

-- the rail: the level up top, under it a short accent tick; the four swatches (accent, grey,
-- black, light) stacked at the bottom
label(rail, {
	Text = "LVL",
	TextSize = 10,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 12),
	Size = UDim2.new(1, 0, 0, 12),
})
local levelLabel = label(rail, {
	Font = Theme.MonoFont,
	TextSize = 18,
	TextColor3 = Theme.NavText,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 24),
	Size = UDim2.new(1, 0, 0, 20),
})
local railTick = make("Frame", {
	Parent = rail,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 50),
	Size = UDim2.fromOffset(20, 2),
	BorderSizePixel = 0,
})
local swatches = make("Frame", {
	Parent = rail,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(SWATCH, 4 * (SWATCH + 4)),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = swatches, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
local accentSwatch
for i, color in ipairs({ WHITE, Color3.fromRGB(136, 136, 136), Color3.fromRGB(10, 10, 10), Color3.fromRGB(204, 204, 204) }) do
	local swatch = make("Frame", { Parent = swatches, LayoutOrder = i, Size = UDim2.fromOffset(SWATCH, SWATCH), BackgroundColor3 = color, BorderSizePixel = 0 })
	if i == 1 then
		accentSwatch = swatch
	end
end

-- the list: the brand, the file line, then the numbered tabs
local brand = label(listPanel, {
	Font = Theme.TitleFont,
	TextSize = 18,
	TextColor3 = Theme.NavText,
	RichText = true,
	Position = UDim2.fromOffset(NAV_PAD, 12),
	Size = UDim2.new(1, -2 * NAV_PAD, 0, 22),
})
label(listPanel, {
	Text = "FILE NO. 049 / PLAYER",
	TextSize = 10,
	TextColor3 = Theme.Muted,
	Position = UDim2.fromOffset(NAV_PAD, 36),
	Size = UDim2.new(1, -2 * NAV_PAD, 0, 12),
})
local navList = make("Frame", {
	Parent = listPanel,
	Position = UDim2.fromOffset(0, NAV_TOP),
	Size = UDim2.new(1, -1, 1, -(NAV_TOP + 20 + NAV_ROW + APART_GAP)),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = navList, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
-- at the list's foot, apart from the rest behind a thin line: the tabs registered `apart`
-- (Settings), with no number
local navApart = make("Frame", {
	Parent = listPanel,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -20),
	Size = UDim2.new(1, -1, 0, NAV_ROW),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = navApart, SortOrder = Enum.SortOrder.LayoutOrder })
make("Frame", {
	Parent = listPanel,
	Position = UDim2.new(0, NAV_PAD, 1, -(20 + NAV_ROW + APART_GAP / 2)),
	Size = UDim2.new(1, -2 * NAV_PAD, 0, 1),
	BackgroundColor3 = Theme.Edge,
	BackgroundTransparency = Theme.EdgeTransparency,
	BorderSizePixel = 0,
})

local closeButton = make("TextButton", {
	Parent = body,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -PAD, 0, 8),
	Size = UDim2.fromOffset(28, 28),
	BackgroundTransparency = 1,
	Font = Theme.LabelFont,
	Text = "×",
	TextSize = 26,
	TextColor3 = Theme.Ink,
	ZIndex = 5,
})

-- state
local tabs = {} -- name -> { name, order, title, key, locked, pose, frame, button, nameLabel, marker, badge }
local current -- the tab showing, while the hub is open
local only = false -- opened by Hub.OpenOnly: that tab alone
local wanted -- a tab asked for before it registered
local shownListeners = {} -- name -> { fn }
local changedListeners = {}
local closedListeners = {}
local accentListeners = {}
local accent, ink = Theme.NoPower, Theme.Ink

local function tabList()
	local list = {}
	for _, tab in pairs(tabs) do
		table.insert(list, tab)
	end
	return list
end

-- the numbered tabs (not the ones kept apart) in nav order
local function numberedOrder()
	local list = {}
	for _, tab in pairs(tabs) do
		if not tab.apart then
			table.insert(list, tab)
		end
	end
	return HubRules.Order(list)
end

-- each entry: its number (01, 02 ...), and the selected one in the accent, larger, with the
-- accent bar on its left and the accent fading out behind it
local function paintNav()
	for i, name in ipairs(numberedOrder()) do
		tabs[name].numberLabel.Text = string.format("%02d", i)
	end
	for _, tab in pairs(tabs) do
		local selected = tab.name == current
		tab.marker.Visible = selected
		tab.marker.BackgroundColor3 = accent
		tab.highlight.Visible = selected
		tab.highlight.BackgroundColor3 = accent
		tab.nameLabel.TextColor3 = tab.locked and Theme.Muted or selected and accent or Theme.NavText
		tab.nameLabel.TextSize = selected and 20 or 15
		tab.numberLabel.TextColor3 = selected and accent or Theme.Muted
	end
end

local function paintAccent()
	local r, g, b = HubRules.Ink(accent.R, accent.G, accent.B)
	ink = Color3.new(r, g, b)
	brand.Text = string.format('[ <font color="#%s">SOMEWHAT</font> ]', accent:ToHex())
	accentSwatch.BackgroundColor3 = accent
	railTick.BackgroundColor3 = accent
	titleBar.BackgroundColor3 = ink
	footerChip.BackgroundColor3 = ink
	footerChip.TextColor3 = Hub.OnInk()
	paintNav()
	for _, fn in ipairs(accentListeners) do
		task.spawn(fn, accent, ink)
	end
end

local function readAccent()
	local set = SkillSetConfig.Sets[player:GetAttribute("CurrentPower") or ""]
	accent = set and set.color or Theme.NoPower
	paintAccent()
end

local function paintHeader()
	local tab = current and tabs[current]
	titleLabel.Text = tab and ("#" .. tab.title) or ""
	local position = 0
	for i, name in ipairs(numberedOrder()) do
		if name == current then
			position = i
		end
	end
	numberLabel.Text = position > 0 and string.format("(%02d)", position) or ""
end

-- shows `name`'s frame, and tells its listeners and the pose
local function show(name)
	local tab = tabs[name]
	if not tab or tab.locked then
		wanted = name
		return
	end
	wanted = nil
	current = name
	stripWanted = tab.pose ~= nil
	layout()
	for _, other in pairs(tabs) do
		if other.frame then
			other.frame.Visible = other.name == name
		end
	end
	paintNav()
	paintHeader()
	-- the page eases up, the title fades in, its bar sweeps across
	tab.frame.Position = UDim2.fromOffset(0, PAGE_DROP)
	tween(tab.frame, PAGE_TIME, { Position = UDim2.new() })
	titleLabel.TextTransparency, numberLabel.TextTransparency = 1, 1
	tween(titleLabel, PAGE_TIME, { TextTransparency = 0 })
	tween(numberLabel, PAGE_TIME, { TextTransparency = 0 })
	titleBar.Size = UDim2.new(0, 0, 0, BAR_HEIGHT)
	tween(titleBar, BAR_TIME, { Size = UDim2.new(1, 0, 0, BAR_HEIGHT) })
	for _, fn in ipairs(shownListeners[name] or {}) do
		task.spawn(fn)
	end
	for _, fn in ipairs(changedListeners) do
		task.spawn(fn, name)
	end
end

-- the rest of the HUD (every ScreenGui under the hub, and the billboards over characters) is
-- hidden while the hub is open: each gui's scale-root frame (and the top bar's pill) is turned
-- invisible, so the HUD scripts themselves are left alone
local hiddenHud = {} -- { instance, property } pairs to turn back on
local hudWatch
local function hideHudGui(other)
	if other == gui or other.Name == "MenuButton" then
		return
	end
	if other:IsA("BillboardGui") then
		if other.Enabled then
			other.Enabled = false
			table.insert(hiddenHud, { other, "Enabled" })
		end
	elseif other:IsA("ScreenGui") and other.DisplayOrder < gui.DisplayOrder then
		UIScale.Root(other) -- makes sure the gui has its root frame
		for _, child in ipairs(other:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible and (child.Name == "UIScaleRoot" or UIScale.SkipChild[child.Name]) then
				child.Visible = false
				table.insert(hiddenHud, { child, "Visible" })
			end
		end
	end
end
local function hideHud()
	local playerGui = player:WaitForChild("PlayerGui")
	for _, other in ipairs(playerGui:GetChildren()) do
		hideHudGui(other)
	end
	-- a gui that appears meanwhile goes too
	hudWatch = playerGui.ChildAdded:Connect(function(other)
		task.defer(hideHudGui, other)
	end)
end
-- the world behind the hub is out of reach: no "press E" prompts (the shop's) and a frozen camera
-- (a right click held before it opened would otherwise keep turning it)
local savedCamera
local function lockWorld()
	ProximityPromptService.Enabled = false
	local camera = workspace.CurrentCamera
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		savedCamera = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
	end
end
local function unlockWorld()
	ProximityPromptService.Enabled = true
	local camera = workspace.CurrentCamera
	if savedCamera and camera then
		camera.CameraType = savedCamera
	end
	savedCamera = nil
end

local function showHud()
	if hudWatch then
		hudWatch:Disconnect()
		hudWatch = nil
	end
	for _, entry in ipairs(hiddenHud) do
		if entry[1].Parent then
			entry[1][entry[2]] = true
		end
	end
	hiddenHud = {}
end

local function close()
	if not gui.Enabled then
		return
	end
	gui.Enabled = false
	tween(blur, CLOSE_BLUR_TIME, { Size = 0 })
	showHud()
	unlockWorld()
	local last = current
	current = nil
	wanted = nil
	only = false
	navList.Visible = true
	navApart.Visible = true
	for _, fn in ipairs(closedListeners) do
		task.spawn(fn, last)
	end
end

-- opens the hub on `name` (nil: the first tab that isn't locked), or switches to it if open
function Hub.Open(name)
	name = name or HubRules.FirstOpen(tabList())
	if not gui.Enabled then
		placeBody()
		gui.Enabled = true
		tween(blur, OPEN_TIME, { Size = BLUR_SIZE })
		hideHud()
		lockWorld()
		UiSfx.Play("menuOpen") -- once as the hub opens; switching tabs inside it stays quiet
		Menus.Open("Hub", close)
		nav.Position = UDim2.fromOffset(-Theme.NavWidth, 0)
		tween(nav, OPEN_TIME, { Position = UDim2.new() })
	end
	show(name)
end

-- opens the hub on `name` alone: the nav's list of tabs is hidden and the tab keys
-- don't switch away; closing puts the hub back as it was
function Hub.OpenOnly(name)
	only = true
	navList.Visible = false
	navApart.Visible = false
	Hub.Open(name)
end

function Hub.Close()
	if gui.Enabled then
		close()
		Menus.Close("Hub")
	end
end

-- opens on `name`, or closes if `name` is the one showing
function Hub.Toggle(name)
	if gui.Enabled and (name == nil or name == current) then
		Hub.Close()
	else
		Hub.Open(name)
	end
end

-- with no name: is the hub open at all
function Hub.IsOpen(name)
	return gui.Enabled and (name == nil or current == name)
end

function Hub.Current()
	return gui.Enabled and current or nil
end

function Hub.PoseFor(name)
	local tab = tabs[name]
	return tab and tab.pose
end

function Hub.Accent()
	return accent
end

-- the accent as drawn on the paper
function Hub.InkAccent()
	return ink
end

-- the text colour for writing on an InkAccent fill
function Hub.OnInk()
	local r, g, b = ink.R, ink.G, ink.B
	return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4 and Theme.Nav or WHITE
end

-- `fn(accent, ink)` now and whenever the held power changes
function Hub.OnAccent(fn)
	table.insert(accentListeners, fn)
	task.spawn(fn, accent, ink)
end

-- `fn()` each time tab `name` becomes the one showing
function Hub.OnShown(name, fn)
	shownListeners[name] = shownListeners[name] or {}
	table.insert(shownListeners[name], fn)
end

-- `fn(name)` whenever the showing tab changes (HubPose)
function Hub.OnTabChanged(fn)
	table.insert(changedListeners, fn)
end

-- `fn(lastTab)` when the hub closes
function Hub.OnClosed(fn)
	table.insert(closedListeners, fn)
end

-- a small chip by tab `name` in the nav (nil clears it)
function Hub.Badge(name, text)
	local tab = tabs[name]
	if tab and tab.badge then
		tab.badge.Text = text and (" " .. text .. " ") or ""
		tab.badge.Visible = text ~= nil
	end
end

-- registers a tab: opts = { order, title, key (Enum.KeyCode), locked, pose, apart }.
-- An `apart` tab sits at the foot of the nav, unnumbered (Settings).
-- A tab with no pose gets the whole width (no character strip).
-- Returns the frame to build it in (nil for a locked slot).
function Hub.Tab(name, opts)
	local tab = {
		name = name,
		order = opts.order,
		title = opts.title or string.upper(name),
		key = opts.key,
		locked = opts.locked == true,
		pose = opts.pose,
		apart = opts.apart == true,
	}
	tab.button = make("TextButton", {
		Parent = tab.apart and navApart or navList,
		LayoutOrder = opts.order * 10, -- in tenths: a tab can slot in between (Map's 2.5)
		Size = UDim2.new(1, 0, 0, NAV_ROW),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	-- behind the selected entry: the accent fading out to the right, and a bar on its left edge
	tab.highlight = make("Frame", { Parent = tab.button, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, Visible = false })
	make("UIGradient", {
		Parent = tab.highlight,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	})
	tab.marker = make("Frame", { Parent = tab.button, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, Visible = false })
	local row = make("Frame", { Parent = tab.button, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local hoverPad = make("UIPadding", { Parent = row, PaddingLeft = UDim.new(0, NAV_PAD) })
	make("UIListLayout", {
		Parent = row,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	tab.numberLabel = label(row, {
		LayoutOrder = 1,
		Font = Theme.MonoFont,
		TextSize = 13,
		TextColor3 = Theme.Muted,
		Size = UDim2.fromOffset(20, NAV_ROW),
		Visible = not tab.apart,
	})
	tab.nameLabel = label(row, {
		LayoutOrder = 2,
		Text = tab.locked and "[LOCKED]" or tab.title,
		Font = Theme.TitleFont,
		TextSize = 15,
		TextColor3 = Theme.NavText,
		Size = UDim2.fromOffset(0, NAV_ROW),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	if tab.key then
		local keyChip = label(row, {
			LayoutOrder = 3,
			Text = Keybinds.ShortName(tab.key.Name),
			Font = Theme.MonoFont,
			TextSize = 10,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(16, 16),
		})
		make("UIStroke", { Parent = keyChip, Color = Theme.Muted, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	tab.badge = label(row, {
		LayoutOrder = 4,
		TextSize = 10,
		TextColor3 = Theme.Nav,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.NavText,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
	})
	tab.badge.BackgroundTransparency = 0
	if not tab.locked then
		tab.frame = make("Frame", {
			Name = name,
			Parent = content,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Visible = false,
		})
		tab.button.Activated:Connect(function()
			UiSfx.Play("menuSelect") -- (pressing the tab already showing sounds too)
			show(name)
		end)
		-- hover: the entry nudges right and takes the accent
		tab.button.MouseEnter:Connect(function()
			tween(hoverPad, HOVER_TIME, { PaddingLeft = UDim.new(0, NAV_PAD + 6) })
			tab.nameLabel.TextColor3 = accent
		end)
		tab.button.MouseLeave:Connect(function()
			tween(hoverPad, HOVER_TIME, { PaddingLeft = UDim.new(0, NAV_PAD) })
			paintNav()
		end)
	end
	tabs[name] = tab
	paintNav()
	if gui.Enabled then
		paintHeader()
		if wanted == name then
			show(name)
		end
	end
	return tab.frame
end

-- keys: a tab's key opens, switches or closes; Esc closes
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- (Esc while Settings waits for a key calls the wait off instead)
	if input.KeyCode == Enum.KeyCode.Escape then
		if not Keybinds.Capturing() then
			Hub.Close()
		end
		return
	end
	if gameProcessed or Keybinds.Capturing() then
		return
	end
	-- no tab keys on the title menu (its gui is there until PLAY, Settings opened from it too) or one tab alone
	if only or player.PlayerGui:FindFirstChild("TitleMenu") then
		return
	end
	for name, tab in pairs(tabs) do
		if tab.key == input.KeyCode and not tab.locked then
			local action = HubRules.KeyAction(Hub.Current(), name)
			if action == "close" then
				Hub.Close()
			else
				Hub.Open(name)
			end
			return
		end
	end
end)
-- Esc opens Roblox's own menu: close the hub
GuiService.MenuOpened:Connect(Hub.Close)
closeButton.Activated:Connect(Hub.Close)
escButton.Activated:Connect(Hub.Close)
closeButton.MouseEnter:Connect(function()
	tween(closeButton, HOVER_TIME, { Rotation = 90 })
end)
closeButton.MouseLeave:Connect(function()
	tween(closeButton, HOVER_TIME, { Rotation = 0 })
end)
escButton.MouseEnter:Connect(function()
	escText.TextColor3 = Theme.NavText
end)
escButton.MouseLeave:Connect(function()
	escText.TextColor3 = Theme.Muted
end)

-- every button in a tab (sub-tabs, chips, cards, links) gets an accent line
-- that sweeps in just under it on hover
local function hoverLine(button)
	if button:FindFirstChild("HoverLine") or button:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return
	end
	button.AutoButtonColor = false -- the line is the hover; no darkening as well
	local line = make("Frame", {
		Name = "HoverLine",
		Parent = button,
		Position = UDim2.new(0, 0, 1, 2),
		Size = UDim2.new(0, 0, 0, 2),
		BorderSizePixel = 0,
	})
	button.MouseEnter:Connect(function()
		line.BackgroundColor3 = ink
		tween(line, HOVER_TIME, { Size = UDim2.new(1, 0, 0, 2) })
	end)
	button.MouseLeave:Connect(function()
		tween(line, HOVER_TIME, { Size = UDim2.new(0, 0, 0, 2) })
	end)
end
-- a tab's card (a frame or button filled with Theme.Panel) becomes smoked glass with a thin light edge
local function smoke(item)
	if
		(item:IsA("Frame") or item:IsA("GuiButton"))
		and item.BackgroundColor3 == Theme.Panel
		and item.BackgroundTransparency == 0
		and not item:FindFirstChildWhichIsA("UIStroke")
	then
		item.BackgroundTransparency = Theme.PanelTransparency
		make("UIStroke", {
			Parent = item,
			Color = Theme.Edge,
			Transparency = Theme.EdgeTransparency,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end
end
content.DescendantAdded:Connect(function(item)
	if item:IsA("GuiObject") then
		task.defer(function()
			if item.Parent then
				smoke(item)
			end
		end)
	end
	if item:IsA("GuiButton") then
		-- choosing a section (a sub-tab, a category) sounds like the side bar:
		-- those buttons set SectionSelect, and it plays as they go down
		item.MouseButton1Down:Connect(function()
			if item:GetAttribute("SectionSelect") then
				UiSfx.Play("menuSelect")
			end
		end)
		task.defer(function()
			if item.Parent then
				hoverLine(item)
			end
		end)
	end
end)

-- the top bar's Menu icon: opens on Profile (or the first open tab), closes if open
Menus.Register("Hub", function()
	if gui.Enabled then
		Hub.Close()
	else
		Hub.Open(tabs.Profile and "Profile" or nil)
	end
end)

local function readLevel()
	levelLabel.Text = tostring(player:GetAttribute("Level") or 1)
end

player.AttributeChanged:Connect(function(name)
	if name == "CurrentPower" then
		readAccent()
	elseif name == "Level" then
		readLevel()
	end
end)
readAccent()
readLevel()

return Hub
