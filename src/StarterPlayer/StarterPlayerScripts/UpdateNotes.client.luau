-- The "What's new" modal: opens once, a moment after a player's save loads, the
-- first time they join after UpdateNotes.Version changes. × , Continue or Esc
-- closes it and tells UpdateNotesServer on the SeenUpdateNotes remote, which saves
-- the version as the player's SeenUpdate. It is a menu (one at a time, Menus) but
-- has no top bar icon. In Studio saves are off, so it shows on every playtest.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Menus = require(script.Parent:WaitForChild("Menus"))
local UpdateNotes = require(ReplicatedStorage:WaitForChild("UpdateNotes"))
local seenEvent = ReplicatedStorage:WaitForChild("SeenUpdateNotes") -- made by UpdateNotesServer
local player = Players.LocalPlayer

local PANEL_WIDTH = 440
local PADDING = 14
local SECTION_GAP = 14 -- extra space above each topic after the first
local SHOW_DELAY = 1.5 -- seconds after the save loads, so the screen has settled
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local BUTTON = Color3.fromRGB(38, 38, 50)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local ACCENT = Color3.fromRGB(215, 215, 225) -- headings, divider lines and the border: light gray

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
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = Enum.TextXAlignment.Left
	props.TextYAlignment = Enum.TextYAlignment.Top
	props.TextWrapped = true
	props.AutomaticSize = Enum.AutomaticSize.Y
	props.Size = UDim2.new(1, 0, 0, 0)
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "UpdateNotes",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = make("ScrollingFrame", {
	Parent = gui,
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = panel, Color = ACCENT, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })
Menus.Fit(panel)

local order = 0
local function nextOrder()
	order += 1
	return order
end

-- title row: the title, the version under it, × at the right
local header = make("Frame", { Parent = panel, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 })
label(header, { Text = UpdateNotes.Title, Font = Enum.Font.GothamBold, TextSize = 18, Size = UDim2.new(1, -24, 0, 22) })
label(header, {
	Text = string.upper(UpdateNotes.Version),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = ACCENT,
	Position = UDim2.fromOffset(0, 22),
	Size = UDim2.new(1, -24, 0, 16),
})
local closeButton = make("TextButton", {
	Parent = header,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
})

local function escape(text)
	return (string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

-- "Name: what it does" shows the name in bold white and the rest softer
local function richLine(line)
	local name, rest = string.match(line, "^(.-):%s*(.*)$")
	if not name or rest == "" then
		return "•  " .. escape(line)
	end
	return string.format('•  <b><font color="#FFFFFF">%s:</font></b>  <font color="#C4C4D4">%s</font>', escape(name), escape(rest))
end

for index, section in ipairs(UpdateNotes.Sections) do
	local heading, lines = section[1], section[2]
	if index > 1 then
		make("Frame", { Parent = panel, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, SECTION_GAP), BackgroundTransparency = 1 })
	end
	label(panel, { LayoutOrder = nextOrder(), Text = heading, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = ACCENT })
	make("Frame", { Parent = panel, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = ACCENT, BackgroundTransparency = 0.6, BorderSizePixel = 0 })
	for _, line in ipairs(lines) do
		label(panel, { LayoutOrder = nextOrder(), Text = richLine(line), TextSize = 14, RichText = true })
	end
end

if UpdateNotes.Footer then
	label(panel, { LayoutOrder = nextOrder(), Text = UpdateNotes.Footer, TextSize = 12, TextColor3 = MUTED })
end

local continueButton = make("TextButton", {
	Parent = panel,
	LayoutOrder = nextOrder(),
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundColor3 = BUTTON,
	BorderSizePixel = 0,
	AutoButtonColor = true,
	Font = Enum.Font.GothamBold,
	Text = "CONTINUE",
	TextSize = 12,
	TextColor3 = TEXT,
})
make("UIStroke", { Parent = continueButton, Color = TEXT, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

local function setOpen(open)
	if gui.Enabled == open then
		return
	end
	gui.Enabled = open
	if open then
		-- after the panel has sized itself (Menus.Fit), or it can open scrolled down
		task.defer(function()
			panel.CanvasPosition = Vector2.zero
		end)
		Menus.Open("UpdateNotes", function()
			setOpen(false)
		end)
	else
		Menus.Close("UpdateNotes")
		seenEvent:FireServer(UpdateNotes.Version)
	end
end

closeButton.Activated:Connect(function()
	setOpen(false)
end)
continueButton.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		setOpen(false)
	end
end)

-- the saved attributes appear once the save has loaded (Level is one of them)
while player.Parent and player:GetAttribute("Level") == nil do
	task.wait(0.25)
end
if player.Parent and player:GetAttribute("SeenUpdate") ~= UpdateNotes.Version then
	task.wait(SHOW_DELAY)
	setOpen(true)
end
