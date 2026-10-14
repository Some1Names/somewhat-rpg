-- The hub: one full-screen menu holding Profile, Backpack (Inventory), Quests,
-- Stats and Updates, with locked slots for later features. The first script to
-- require it builds the screen: grey paper, the dark nav column on the left,
-- the header (#TITLE, the accent bar, the tab's number, level and yen), the
-- footer, and on the right the strip HubPose draws the posed character in.
-- Each tab is a script that asks Hub.Tab(name, opts) for a frame and builds in
-- it; a tab's key (B, J, M) opens the hub on it, closes it if it's the one
-- showing, or switches to it. Esc closes. To Menus the hub is the one menu
-- "Hub", so opening Settings or the Shop closes it and the other way round.
-- The accent is the held power's colour (white with none); on the paper it's
-- drawn through HubRules.Ink so a light one stays visible. Square everything.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubRules = require(ReplicatedStorage:WaitForChild("HubRules"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme

local PAD = 16
local NAV_PAD = 14
local NAV_ROW = 30
local NAV_TOP = 76 -- the first tab button, under the brand and file number
local SWATCH = 10
local WHITE = Color3.new(1, 1, 1)

local Hub = {}
Hub.Theme = Theme

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

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
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

-- back to front: paper, the pose strip, the main column, the nav, the ×
make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Paper, BorderSizePixel = 0, ZIndex = 1 })

local poseStrip = make("Frame", {
	Name = "PoseStrip",
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromScale(Theme.PoseShare, 1),
	BackgroundTransparency = 1,
	ZIndex = 2,
})
Hub.PoseStrip = poseStrip

local main = make("Frame", {
	Name = "Main",
	Parent = gui,
	Position = UDim2.fromOffset(Theme.NavWidth, 0),
	BackgroundTransparency = 1,
	ZIndex = 3,
})

-- the strip shows on wide screens only; the main column ends where it starts
local function layout()
	local wide = workspace.CurrentCamera.ViewportSize.X >= Theme.PoseMinScreen
	poseStrip.Visible = wide
	main.Size = wide and UDim2.new(1 - Theme.PoseShare, -Theme.NavWidth, 1, 0) or UDim2.new(1, -Theme.NavWidth, 1, 0)
end
layout()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

-- header: a line of microtext, then #TITLE, the accent bar and (0n)
label(main, {
	Text = "2026 · SECTOR 01 · INDEX 004.19",
	TextSize = 11,
	TextColor3 = Theme.Muted,
	Position = UDim2.fromOffset(PAD, 10),
	Size = UDim2.new(1, -2 * PAD, 0, 12),
})
local statusLabel = label(main, {
	TextSize = 11,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.fromOffset(PAD, 10),
	Size = UDim2.new(1, -2 * PAD, 0, 12),
})
local titleRow = make("Frame", {
	Parent = main,
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
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
})
local barHolder = make("Frame", { Parent = titleRow, LayoutOrder = 2, Size = UDim2.fromOffset(0, 44), BackgroundTransparency = 1 })
make("UIFlexItem", { Parent = barHolder, FlexMode = Enum.UIFlexMode.Fill })
local titleBar = make("Frame", {
	Parent = barHolder,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -10),
	Size = UDim2.new(1, 0, 0, 8),
	BorderSizePixel = 0,
})
local numberLabel = label(titleRow, {
	LayoutOrder = 3,
	Font = Theme.LabelFont,
	TextSize = 24,
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
})

-- the tabs draw in here
local content = make("Frame", {
	Name = "Content",
	Parent = main,
	Position = UDim2.fromOffset(PAD, Theme.HeaderHeight),
	Size = UDim2.new(1, -2 * PAD, 1, -(Theme.HeaderHeight + Theme.FooterHeight)),
	BackgroundTransparency = 1,
})

-- footer: a rule, the record line, and #SOMEWHAT on an accent chip
local footer = make("Frame", {
	Parent = main,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, PAD, 1, 0),
	Size = UDim2.new(1, -2 * PAD, 0, Theme.FooterHeight),
	BackgroundTransparency = 1,
})
make("Frame", { Parent = footer, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Ink, BorderSizePixel = 0 })
label(footer, {
	Text = "SOMEWHAT RPG. INTERNAL RECORD. DATA SAVED ON LEAVE.",
	TextSize = 11,
	TextColor3 = Theme.Muted,
	Size = UDim2.new(1, -120, 1, 0),
	TextTruncate = Enum.TextTruncate.AtEnd,
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

-- the nav column
local nav = make("Frame", {
	Name = "Nav",
	Parent = gui,
	Size = UDim2.new(0, Theme.NavWidth, 1, 0),
	BackgroundColor3 = Theme.Nav,
	BorderSizePixel = 0,
	ZIndex = 4,
})
local brand = label(nav, {
	Font = Theme.LabelFont,
	TextSize = 16,
	TextColor3 = Theme.NavText,
	RichText = true,
	Position = UDim2.fromOffset(NAV_PAD, 18),
	Size = UDim2.new(1, -2 * NAV_PAD, 0, 20),
})
label(nav, {
	Text = "FILE NO. 049 / PLAYER",
	TextSize = 10,
	TextColor3 = Theme.Muted,
	Position = UDim2.fromOffset(NAV_PAD, 40),
	Size = UDim2.new(1, -2 * NAV_PAD, 0, 12),
})
local navList = make("Frame", {
	Parent = nav,
	Position = UDim2.fromOffset(NAV_PAD, NAV_TOP),
	Size = UDim2.new(1, -2 * NAV_PAD, 1, -(NAV_TOP + 60)),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = navList, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })

-- the four swatches (accent, grey, black, light) and ESC / CLOSE at the bottom
local swatches = make("Frame", {
	Parent = nav,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, NAV_PAD, 1, -36),
	Size = UDim2.fromOffset(4 * (SWATCH + 4), SWATCH),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = swatches, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) })
local accentSwatch
for i, color in ipairs({ WHITE, Color3.fromRGB(136, 136, 136), Color3.fromRGB(10, 10, 10), Color3.fromRGB(204, 204, 204) }) do
	local swatch = make("Frame", { Parent = swatches, LayoutOrder = i, Size = UDim2.fromOffset(SWATCH, SWATCH), BackgroundColor3 = color, BorderSizePixel = 0 })
	if i == 1 then
		accentSwatch = swatch
	end
end
local escButton = make("TextButton", {
	Parent = nav,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, NAV_PAD, 1, -14),
	Size = UDim2.fromOffset(100, 14),
	BackgroundTransparency = 1,
	Font = Theme.LabelFont,
	Text = "ESC / CLOSE",
	TextSize = 11,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local closeButton = make("TextButton", {
	Parent = gui,
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

local function paintNav()
	for _, tab in pairs(tabs) do
		local selected = tab.name == current
		tab.marker.Visible = selected
		tab.marker.BackgroundColor3 = accent
		tab.nameLabel.TextColor3 = tab.locked and Theme.Muted or selected and accent or Theme.NavText
		tab.nameLabel.TextSize = selected and 16 or 13
	end
end

local function paintAccent()
	local r, g, b = HubRules.Ink(accent.R, accent.G, accent.B)
	ink = Color3.new(r, g, b)
	brand.Text = string.format('[ <font color="#%s">SOMEWHAT</font> ]', accent:ToHex())
	accentSwatch.BackgroundColor3 = accent
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
	for i, name in ipairs(HubRules.Order(tabList())) do
		if name == current then
			position = i
		end
	end
	numberLabel.Text = string.format("(%02d)", position)
end

local function paintStatus()
	statusLabel.Text = string.format("LV %d     %s", player:GetAttribute("Level") or 1, formatYen(player:GetAttribute("Yen") or 0))
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
	for _, other in pairs(tabs) do
		if other.frame then
			other.frame.Visible = other.name == name
		end
	end
	paintNav()
	paintHeader()
	for _, fn in ipairs(shownListeners[name] or {}) do
		task.spawn(fn)
	end
	for _, fn in ipairs(changedListeners) do
		task.spawn(fn, name)
	end
end

local function close()
	if not gui.Enabled then
		return
	end
	gui.Enabled = false
	local last = current
	current = nil
	wanted = nil
	for _, fn in ipairs(closedListeners) do
		task.spawn(fn, last)
	end
end

-- opens the hub on `name` (nil: the first tab that isn't locked), or switches to it if open
function Hub.Open(name)
	name = name or HubRules.FirstOpen(tabList())
	if not gui.Enabled then
		gui.Enabled = true
		Menus.Open("Hub", close)
		paintStatus()
	end
	show(name)
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
	return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4 and Theme.Ink or WHITE
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

-- registers a tab: opts = { order, title, key (Enum.KeyCode), locked, pose }.
-- Returns the frame to build it in (nil for a locked slot).
function Hub.Tab(name, opts)
	local tab = {
		name = name,
		order = opts.order,
		title = opts.title or string.upper(name),
		key = opts.key,
		locked = opts.locked == true,
		pose = opts.pose,
	}
	tab.button = make("TextButton", {
		Parent = navList,
		LayoutOrder = opts.order,
		Size = UDim2.new(1, 0, 0, NAV_ROW),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	make("UIListLayout", {
		Parent = tab.button,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})
	-- the ↖ chip on the selected tab; the others keep its room so names line up
	local markerSlot = make("Frame", { Parent = tab.button, LayoutOrder = 1, Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1 })
	tab.marker = label(markerSlot, {
		Text = "↖",
		TextSize = 13,
		TextColor3 = Theme.Nav,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})
	tab.marker.BackgroundTransparency = 0
	tab.nameLabel = label(tab.button, {
		LayoutOrder = 2,
		Text = tab.locked and "[LOCKED]" or tab.title,
		TextSize = 13,
		TextColor3 = Theme.NavText,
		Size = UDim2.fromOffset(0, NAV_ROW),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	if tab.key then
		label(tab.button, {
			LayoutOrder = 3,
			Text = Keybinds.ShortName(tab.key.Name),
			TextSize = 11,
			TextColor3 = Theme.Muted,
			Size = UDim2.fromOffset(0, NAV_ROW),
			AutomaticSize = Enum.AutomaticSize.X,
		})
	end
	tab.badge = label(tab.button, {
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
			show(name)
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
	if input.KeyCode == Enum.KeyCode.Escape then
		Hub.Close()
		return
	end
	if gameProcessed or Keybinds.Capturing() then
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

-- the top bar's Menu icon: opens on Profile (or the first open tab), closes if open
Menus.Register("Hub", function()
	if gui.Enabled then
		Hub.Close()
	else
		Hub.Open(tabs.Profile and "Profile" or nil)
	end
end)

player.AttributeChanged:Connect(function(name)
	if name == "CurrentPower" then
		readAccent()
	elseif name == "Level" or name == "Yen" then
		paintStatus()
	end
end)
readAccent()

return Hub
