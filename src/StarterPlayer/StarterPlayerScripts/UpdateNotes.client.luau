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
local HEADING_SIZE = 20
local NAME_SIZE = 20
local TEXT_SIZE = 16
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

-- three clearly different levels: the group heading is a solid band in the held power's colour with
-- dark capitals, a topic's name is bold and coloured with a square marker, and its info is plain
-- light text, smaller and indented under it, with a thin rule between topics
local tints = {} -- functions that colour the cards, called with the accent, the accent as drawn on dark, and the text on the accent
local function onTint(fn)
	table.insert(tints, fn)
	fn(Hub.Accent(), Hub.InkAccent(), Hub.OnInk())
end
Hub.OnAccent(function(accent, ink)
	local onAccent = Hub.OnInk()
	for index = #tints, 1, -1 do
		local ok = pcall(tints[index], accent, ink, onAccent)
		if not ok then
			table.remove(tints, index)
		end
	end
end)

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
	make("UIListLayout", { Parent = frame, SortOrder = Enum.SortOrder.LayoutOrder })
	-- the heading band
	local band = make("Frame", {
		Parent = frame,
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Hub.Accent(),
		BorderSizePixel = 0,
	})
	make("UIPadding", {
		Parent = band,
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, CARD_PADDING),
		PaddingRight = UDim.new(0, CARD_PADDING),
	})
	local bandText = label(band, { Text = string.upper(heading), Font = Hub.Theme.TitleFont, TextSize = HEADING_SIZE })
	onTint(function(accent, _, onAccent)
		band.BackgroundColor3 = accent
		bandText.TextColor3 = onAccent
	end)
	-- the topics under it
	local body = make("Frame", {
		Parent = frame,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	make("UIPadding", {
		Parent = body,
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, CARD_PADDING),
		PaddingRight = UDim.new(0, CARD_PADDING),
	})
	make("UIListLayout", { Parent = body, SortOrder = Enum.SortOrder.LayoutOrder })
	for index, line in ipairs(lines) do
		local name, rest = string.match(line, "^(.-):%s*(.*)$")
		if not name or rest == "" then
			name, rest = nil, line
		end
		if index > 1 then
			make("Frame", { -- the rule between topics
				Parent = body,
				LayoutOrder = index * 2 - 2,
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Hub.Theme.BarBack,
				BorderSizePixel = 0,
			})
		end
		local entry = make("Frame", {
			Parent = body,
			LayoutOrder = index * 2 - 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		make("UIPadding", { Parent = entry, PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) })
		make("UIListLayout", { Parent = entry, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
		if name then
			local top = make("Frame", {
				Parent = entry,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			})
			local marker = make("Frame", { Parent = top, Position = UDim2.fromOffset(0, 7), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0 })
			local nameLabel = label(top, {
				Text = name,
				TextSize = NAME_SIZE,
				Position = UDim2.fromOffset(18, 0),
				Size = UDim2.new(1, -18, 0, 0),
			})
			onTint(function(_, ink)
				marker.BackgroundColor3 = ink
				nameLabel.TextColor3 = ink
			end)
		end
		local info = make("Frame", {
			Parent = entry,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		make("UIPadding", { Parent = info, PaddingLeft = UDim.new(0, name and 18 or 0) }) -- under the name, past its marker
		label(info, { Text = rest, TextSize = TEXT_SIZE, TextColor3 = name and BODY or TEXT })
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
	tints = {}
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
