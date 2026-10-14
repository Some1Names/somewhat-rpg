-- The hub's Updates tab, "What's new". The first time a player joins after
-- UpdateNotes.Version changes it gets a NEW badge in the hub's nav (it never
-- opens by itself). Closing the hub after the tab showed (×, Esc, Continue)
-- tells UpdateNotesServer on the SeenUpdateNotes remote, which saves the
-- version as the player's SeenUpdate. In Studio saves are off, so the badge
-- shows on every playtest.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hub = require(script.Parent:WaitForChild("Hub"))
local UpdateNotes = require(ReplicatedStorage:WaitForChild("UpdateNotes"))
local seenEvent = ReplicatedStorage:WaitForChild("SeenUpdateNotes") -- made by UpdateNotesServer
local player = Players.LocalPlayer

local PANEL_WIDTH = 560
local SECTION_GAP = 14 -- extra space above each topic after the first
local TEXT = Hub.Theme.Ink
local MUTED = Hub.Theme.Muted
local WHITE = Color3.new(1, 1, 1)

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

local tabFrame = Hub.Tab("Updates", { order = 5, title = "UPDATES", pose = "Lean" })

local panel = make("ScrollingFrame", {
	Parent = tabFrame,
	Size = UDim2.new(0, PANEL_WIDTH, 1, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

local order = 0
local function nextOrder()
	order += 1
	return order
end

-- the version on a black chip, the title under it
make("TextLabel", {
	Parent = panel,
	LayoutOrder = nextOrder(),
	Size = UDim2.fromOffset(0, 16),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
	Font = Hub.Theme.LabelFont,
	Text = " " .. string.upper(UpdateNotes.Version) .. " ",
	TextSize = 11,
	TextColor3 = WHITE,
})
label(panel, { LayoutOrder = nextOrder(), Text = string.upper(UpdateNotes.Title), Font = Hub.Theme.TitleFont, TextSize = 22 })

local function escape(text)
	return (string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

-- "Name: what it does" shows the name in bold ink and the rest softer
local function richLine(line)
	local name, rest = string.match(line, "^(.-):%s*(.*)$")
	if not name or rest == "" then
		return "•  " .. escape(line)
	end
	return string.format('•  <b>%s:</b>  <font color="#4A4A4A">%s</font>', escape(name), escape(rest))
end

for index, section in ipairs(UpdateNotes.Sections) do
	local heading, lines = section[1], section[2]
	if index > 1 then
		make("Frame", { Parent = panel, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, SECTION_GAP), BackgroundTransparency = 1 })
	end
	label(panel, { LayoutOrder = nextOrder(), Text = string.upper(heading), Font = Hub.Theme.TitleFont, TextSize = 14 })
	make("Frame", { Parent = panel, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = TEXT, BorderSizePixel = 0 })
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
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
	AutoButtonColor = true,
	Font = Enum.Font.GothamBold,
	Text = "CONTINUE",
	TextSize = 12,
	TextColor3 = WHITE,
})

local unseen = false -- this version hasn't been marked seen yet
local shown = false -- the tab showed since then

Hub.OnShown("Updates", function()
	shown = unseen
	-- after the list has sized itself, or it can open scrolled down
	task.defer(function()
		panel.CanvasPosition = Vector2.zero
	end)
end)
Hub.OnClosed(function()
	if unseen and shown then
		unseen, shown = false, false
		Hub.Badge("Updates", nil)
		seenEvent:FireServer(UpdateNotes.Version)
	end
end)
continueButton.Activated:Connect(Hub.Close)

-- the saved attributes appear once the save has loaded (Level is one of them)
while player.Parent and player:GetAttribute("Level") == nil do
	task.wait(0.25)
end
if player.Parent and player:GetAttribute("SeenUpdate") ~= UpdateNotes.Version then
	unseen = true
	Hub.Badge("Updates", "NEW")
end
