-- The hub's Updates tab, "What's new". The first time a player joins after
-- UpdateNotes.Version changes it gets a NEW badge in the hub's nav (it never
-- opens by itself). Closing the hub after the tab showed (×, Esc, a tab key)
-- tells UpdateNotesServer on the SeenUpdateNotes remote, which saves the
-- version as the player's SeenUpdate. In Studio saves are off, so the badge
-- shows on every playtest.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hub = require(script.Parent:WaitForChild("Hub"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local UpdateNotes = require(ReplicatedStorage:WaitForChild("UpdateNotes"))
local seenEvent = ReplicatedStorage:WaitForChild("SeenUpdateNotes") -- made by UpdateNotesServer
local player = Players.LocalPlayer

local TWO_COLUMNS_FROM = 880 -- tab width (UI pixels) from which the topics sit in two columns
local COLUMN_GAP = 20
local CARD_GAP = 18
local CARD_PADDING = 18
local TITLE_SIZE = 30
local HEADING_SIZE = 22
local NAME_SIZE = 18
local TEXT_SIZE = 17
local TEXT = Hub.Theme.Ink
local MUTED = Hub.Theme.Muted
local CARD = Hub.Theme.Panel
local BODY = Color3.fromRGB(214, 214, 222) -- the description under a name

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
	props.TextXAlignment = Enum.TextXAlignment.Left
	props.TextYAlignment = Enum.TextYAlignment.Top
	props.TextWrapped = true
	props.AutomaticSize = Enum.AutomaticSize.Y
	props.Size = props.Size or UDim2.new(1, 0, 0, 0)
	return make("TextLabel", props)
end

local tabFrame = Hub.Tab("Updates", { order = 5, title = "UPDATES" })

-- the whole tab scrolls: the version and title, then the topics as cards in one or two columns
local panel = make("ScrollingFrame", {
	Parent = tabFrame,
	Size = UDim2.fromScale(1, 1),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
})
make("UIPadding", { Parent = panel, PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 16) })
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14) })

-- the version on a light chip, the title beside it
local head = make("Frame", {
	Parent = panel,
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = head,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 14),
})
make("TextLabel", {
	Parent = head,
	LayoutOrder = 1,
	Size = UDim2.fromOffset(0, 26),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
	Font = Hub.Theme.LabelFont,
	Text = " " .. string.upper(UpdateNotes.Version) .. " ",
	TextSize = 16,
	TextColor3 = Hub.Theme.Paper,
})
make("TextLabel", {
	Parent = head,
	LayoutOrder = 2,
	Size = UDim2.fromOffset(0, 34),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Font = Hub.Theme.TitleFont,
	Text = string.upper(UpdateNotes.Title),
	TextSize = TITLE_SIZE,
	TextColor3 = TEXT,
})

local accentBars = {} -- the cards' left edges, in the held power's colour
Hub.OnAccent(function(accent)
	for _, bar in ipairs(accentBars) do
		if bar.Parent then
			bar.BackgroundColor3 = accent
		end
	end
end)

-- one topic: a card with an accent edge, its heading, then each line as a bold name over its description
local function card(parent, section, order)
	local heading, lines = section[1], section[2]
	local frame = make("Frame", {
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
	})
	local bar = make("Frame", { Parent = frame, Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Hub.Accent(), BorderSizePixel = 0 })
	table.insert(accentBars, bar)
	local body = make("Frame", {
		Parent = frame,
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	make("UIPadding", {
		Parent = body,
		PaddingTop = UDim.new(0, CARD_PADDING),
		PaddingBottom = UDim.new(0, CARD_PADDING),
		PaddingLeft = UDim.new(0, CARD_PADDING),
		PaddingRight = UDim.new(0, CARD_PADDING),
	})
	make("UIListLayout", { Parent = body, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) })
	label(body, { LayoutOrder = 0, Text = string.upper(heading), Font = Hub.Theme.TitleFont, TextSize = HEADING_SIZE })
	for index, line in ipairs(lines) do
		local name, rest = string.match(line, "^(.-):%s*(.*)$")
		if not name or rest == "" then
			name, rest = nil, line
		end
		local entry = make("Frame", {
			Parent = body,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		make("UIListLayout", { Parent = entry, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
		if name then
			label(entry, { LayoutOrder = 1, Text = name, TextSize = NAME_SIZE })
		end
		label(entry, { LayoutOrder = 2, Text = rest, TextSize = TEXT_SIZE, TextColor3 = name and BODY or TEXT })
	end
	return frame
end

-- the topics, split between the columns so they come out about as tall as each other
local columns = make("Frame", {
	Parent = panel,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})

local builtCount
local function build()
	local count = tabFrame.AbsoluteSize.X / UIScale.Get() >= TWO_COLUMNS_FROM and 2 or 1
	if count == builtCount then
		return
	end
	builtCount = count
	accentBars = {}
	columns:ClearAllChildren()
	make("UIListLayout", {
		Parent = columns,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, COLUMN_GAP),
	})
	local holders, heights = {}, {}
	for index = 1, count do
		holders[index] = make("Frame", {
			Parent = columns,
			LayoutOrder = index,
			Size = UDim2.new(1 / count, -COLUMN_GAP * (count - 1) / count, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		make("UIListLayout", { Parent = holders[index], SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, CARD_GAP) })
		heights[index] = 0
	end
	for index, section in ipairs(UpdateNotes.Sections) do
		-- the next topic goes in the shortest column (a topic's weight: its heading and its characters)
		local shortest = 1
		for column = 2, count do
			if heights[column] < heights[shortest] then
				shortest = column
			end
		end
		card(holders[shortest], section, index)
		local weight = 80
		for _, line in ipairs(section[2]) do
			weight += 40 + #line
		end
		heights[shortest] += weight
	end
end
build()
tabFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(build)
UIScale.OnChange(build)

if UpdateNotes.Footer then
	label(panel, { LayoutOrder = 3, Text = UpdateNotes.Footer, TextSize = 15, TextColor3 = MUTED })
end

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

-- the saved attributes appear once the save has loaded (Level is one of them)
while player.Parent and player:GetAttribute("Level") == nil do
	task.wait(0.25)
end
if player.Parent and player:GetAttribute("SeenUpdate") ~= UpdateNotes.Version then
	unseen = true
	Hub.Badge("Updates", "NEW")
end
