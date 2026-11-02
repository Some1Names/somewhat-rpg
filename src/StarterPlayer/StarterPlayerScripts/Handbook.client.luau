-- The hub's Handbook tab, kept apart at the foot of the nav above Settings (the title menu's
-- HANDBOOK opens it alone with Hub.OpenOnly). A list of topics on the left (Reforging,
-- Awakening ...) and the chosen topic's page on the right, as cards in the Updates tab's
-- style. The pages are data in HandbookConfig; a section's `visual` (key chips, flows, bars,
-- tiles, the reforge ladder, the awakening stages, a worked example) is drawn here from
-- UI pieces, so it needs no uploaded images, and the ladder and stages read the live
-- numbers from ReforgeConfig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local HandbookConfig = require(ReplicatedStorage:WaitForChild("HandbookConfig"))
local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))

local LIST_WIDTH = 250
local LIST_GAP = 18
local ROW_HEIGHT = 40
local CARD_GAP = 14
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

local tabFrame = Hub.Tab("Handbook", { order = 6.5, title = "HANDBOOK", apart = true })

-- the colours that follow the held power: functions called with the accent, the accent as drawn
-- on dark and the text on the accent
local tints = {} -- the list's, kept for good
local pageTints = {} -- the page's cards', dropped with them
local function onTint(fn, bucket)
	table.insert(bucket or tints, fn)
	fn(Hub.Accent(), Hub.InkAccent(), Hub.OnInk())
end
Hub.OnAccent(function(accent, ink)
	local onAccent = Hub.OnInk()
	for _, bucket in ipairs({ tints, pageTints }) do
		for _, fn in ipairs(bucket) do
			fn(accent, ink, onAccent)
		end
	end
end)

-- the topic list
local list = make("ScrollingFrame", {
	Parent = tabFrame,
	Size = UDim2.new(0, LIST_WIDTH, 1, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
})
make("UIPadding", { Parent = list, PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 16) })
make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })

-- the page
local page = make("ScrollingFrame", {
	Parent = tabFrame,
	Position = UDim2.fromOffset(LIST_WIDTH + LIST_GAP, 0),
	Size = UDim2.new(1, -(LIST_WIDTH + LIST_GAP), 1, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
})
make("UIPadding", { Parent = page, PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 16) })
make("UIListLayout", { Parent = page, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, CARD_GAP) })

local function comma(n)
	local text = tostring(n)
	while true do
		local out, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = out
		if count == 0 then
			return text
		end
	end
end

-- a chip colour: { r, g, b }, or a material's name for its drop colour
local function chipColor(value)
	if type(value) == "string" then
		local material = DropConfig.Materials[value]
		return material and DropConfig.TierColor(material.tier) or MUTED
	end
	return Color3.fromRGB(value[1], value[2], value[3])
end

-- a plain label for the pieces of a visual (no wrapping, no automatic size)
local function text(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.Highway
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

-- a row that wraps onto more lines when the page is narrow
local function wrapRow(parent, gap)
	make("UIListLayout", {
		Parent = parent,
		FillDirection = Enum.FillDirection.Horizontal,
		Wraps = true,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
	})
end

local drawers = {}

-- key chips: [Z] Skill 1
function drawers.keys(holder, visual)
	wrapRow(holder, 14)
	for index, item in ipairs(visual.items) do
		local box = make("Frame", { Parent = holder, LayoutOrder = index, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 })
		make("UIListLayout", { Parent = box, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })
		local chip = text(box, {
			LayoutOrder = 1,
			Text = item[1],
			Font = Hub.Theme.MonoFont,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(#item[1] > 1 and 46 or 30, 30),
		})
		local stroke = make("UIStroke", { Parent = chip, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		onTint(function(_, ink)
			stroke.Color = ink
		end, pageTints)
		text(box, { LayoutOrder = 2, Text = item[2], TextSize = 15, TextColor3 = BODY, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X })
	end
end

-- boxes joined by arrows: 01 Kill > 02 Orb
function drawers.flow(holder, visual)
	wrapRow(holder, 6)
	for index, step in ipairs(visual.steps) do
		if index > 1 then
			text(holder, { LayoutOrder = index * 2 - 2, Text = ">", Font = Hub.Theme.TitleFont, TextSize = 18, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(14, 40) })
		end
		local box = make("Frame", {
			Parent = holder,
			LayoutOrder = index * 2 - 1,
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = TEXT,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
		})
		make("UIPadding", { Parent = box, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) })
		make("UIListLayout", { Parent = box, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })
		local number = text(box, { LayoutOrder = 1, Text = string.format("%02d", index), Font = Hub.Theme.MonoFont, TextSize = 13, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X })
		onTint(function(_, ink)
			number.TextColor3 = ink
		end, pageTints)
		text(box, { LayoutOrder = 2, Text = step, TextSize = 15, Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X })
	end
end

-- tiles: a coloured edge, the name in the colour, a line under it
function drawers.chips(holder, visual)
	wrapRow(holder, 10)
	for index, item in ipairs(visual.items) do
		local color = chipColor(item[3] or MUTED)
		local tile = make("Frame", {
			Parent = holder,
			LayoutOrder = index,
			Size = UDim2.fromOffset(0, 50),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = TEXT,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
		})
		make("Frame", { Parent = tile, Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0 })
		make("UIPadding", { Parent = tile, PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 6) })
		make("UIListLayout", { Parent = tile, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) })
		text(tile, { LayoutOrder = 1, Text = item[1], Font = Hub.Theme.TitleFont, TextSize = 16, TextColor3 = color, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X })
		text(tile, { LayoutOrder = 2, Text = item[2], TextSize = 13, TextColor3 = BODY, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X })
	end
end

-- filled bars: Vitality [=======] 75 / 75
function drawers.bars(holder, visual)
	make("UIListLayout", { Parent = holder, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
	if visual.caption then
		text(holder, { LayoutOrder = 0, Text = visual.caption, Font = Hub.Theme.MonoFont, TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 14) })
	end
	for index, item in ipairs(visual.items) do
		local row = make("Frame", { Parent = holder, LayoutOrder = index, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 })
		text(row, { Text = item[1], TextSize = 14, TextColor3 = BODY, Size = UDim2.new(0, 110, 1, 0) })
		local back = make("Frame", { Parent = row, Position = UDim2.fromOffset(116, 5), Size = UDim2.new(1, -184, 0, 10), BackgroundColor3 = Hub.Theme.BarBack, BorderSizePixel = 0 })
		local fill = make("Frame", { Parent = back, Size = UDim2.fromScale(math.clamp(item[2] / item[3], 0, 1), 1), BorderSizePixel = 0 })
		onTint(function(_, ink)
			fill.BackgroundColor3 = ink
		end, pageTints)
		text(row, { Text = string.format("%d / %d", item[2], item[3]), Font = Hub.Theme.MonoFont, TextSize = 12, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -60, 0, 0), Size = UDim2.new(0, 60, 1, 0) })
	end
end

-- the reforge levels +1 .. +10: the material's colour, how many, and the yen
function drawers.ladder(holder)
	make("UIGridLayout", { Parent = holder, SortOrder = Enum.SortOrder.LayoutOrder, CellSize = UDim2.new(0.2, -6, 0, 66), CellPadding = UDim2.fromOffset(6, 6) })
	for level, cost in ipairs(ReforgeConfig.LevelCosts) do
		local color = chipColor(cost.material)
		local cell = make("Frame", { Parent = holder, LayoutOrder = level, BackgroundColor3 = TEXT, BackgroundTransparency = 0.9, BorderSizePixel = 0 })
		make("Frame", { Parent = cell, Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = color, BorderSizePixel = 0 })
		text(cell, { Text = "+" .. level, Font = Hub.Theme.TitleFont, TextSize = 16, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 18) })
		text(cell, { Text = cost.amount .. " " .. cost.material, TextSize = 13, TextColor3 = color, Position = UDim2.fromOffset(8, 25), Size = UDim2.new(1, -16, 0, 16) })
		text(cell, { Text = comma(cost.yen) .. " yen", Font = Hub.Theme.MonoFont, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(8, 43), Size = UDim2.new(1, -16, 0, 14) })
	end
end

-- awakening stages: pips, the bonus, the price
function drawers.stages(holder)
	local count = ReforgeConfig.MaxAwakening
	make("UIGridLayout", { Parent = holder, SortOrder = Enum.SortOrder.LayoutOrder, CellSize = UDim2.new(1 / (count + 1), -6, 0, 104), CellPadding = UDim2.fromOffset(6, 6) })
	for stage = 0, count do
		local cell = make("Frame", { Parent = holder, LayoutOrder = stage, BackgroundColor3 = TEXT, BackgroundTransparency = 0.9, BorderSizePixel = 0 })
		text(cell, { Text = stage == 0 and "+10" or ("AWAKEN " .. stage), Font = Hub.Theme.TitleFont, TextSize = 15, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 18) })
		local pips = make("Frame", { Parent = cell, Position = UDim2.fromOffset(8, 28), Size = UDim2.new(1, -16, 0, 10), BackgroundTransparency = 1 })
		make("UIListLayout", { Parent = pips, FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
		for pip = 1, count do
			local box = make("Frame", { Parent = pips, LayoutOrder = pip, Size = UDim2.fromOffset(18, 10), BackgroundColor3 = Hub.Theme.BarBack, BorderSizePixel = 0 })
			if pip <= stage then
				onTint(function(_, ink)
					box.BackgroundColor3 = ink
				end, pageTints)
			end
		end
		local damage = math.floor((ReforgeConfig.MaxLevel * ReforgeConfig.DamagePerLevel + stage * ReforgeConfig.DamagePerAwakening) * 100 + 0.5)
		local bonus = math.floor(stage * ReforgeConfig.AwakenAffinityBonus * 100 + 0.5)
		text(cell, { Text = string.format("+%d%% damage", damage), TextSize = 13, TextColor3 = BODY, Position = UDim2.fromOffset(8, 44), Size = UDim2.new(1, -16, 0, 15) })
		text(cell, { Text = stage == 0 and "affinities base" or string.format("affinities +%d%%", bonus), TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(8, 60), Size = UDim2.new(1, -16, 0, 14) })
		local cost = ReforgeConfig.AwakenCosts[stage]
		text(cell, { Text = cost and string.format("%d Essence, %s", cost.amount, comma(cost.yen)) or "no Essence", Font = Hub.Theme.MonoFont, TextSize = 10, TextColor3 = chipColor("Essence"), Position = UDim2.fromOffset(8, 80), Size = UDim2.new(1, -16, 0, 14) })
	end
end

-- a worked example in a frame with an accent edge
function drawers.example(holder, visual)
	local framed = make("Frame", {
		Parent = holder,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = TEXT,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
	})
	local edge = make("Frame", { Parent = framed, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 })
	make("UIPadding", { Parent = framed, PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) })
	make("UIListLayout", { Parent = framed, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
	local title = text(framed, { LayoutOrder = 0, Text = visual.title, Font = Hub.Theme.MonoFont, TextSize = 12, Size = UDim2.new(1, 0, 0, 16) })
	onTint(function(_, ink)
		edge.BackgroundColor3 = ink
		title.TextColor3 = ink
	end, pageTints)
	for index, line in ipairs(visual.lines) do
		label(framed, { LayoutOrder = index, Text = "- " .. line, TextSize = TEXT_SIZE - 1, TextColor3 = BODY })
	end
end

-- a section's visual, in a strip between the heading band and the lines
local function drawVisual(parent, visual, order)
	local draw = drawers[visual.kind]
	if not draw then
		return
	end
	local holder = make("Frame", {
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	make("UIPadding", { Parent = holder, PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, CARD_PADDING), PaddingRight = UDim.new(0, CARD_PADDING) })
	draw(holder, visual)
end

-- a card: the heading as a band in the accent, then its lines, each "Name: info" with a coloured
-- name and a square marker, a thin rule between them
local function card(section, order)
	local heading, lines = section[1], section[2]
	local frame = make("Frame", {
		Parent = page,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
	})
	make("UIListLayout", { Parent = frame, SortOrder = Enum.SortOrder.LayoutOrder })
	local band = make("Frame", {
		Parent = frame,
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
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
	end, pageTints)
	if section.visual then
		drawVisual(frame, section.visual, 1)
	end
	local body = make("Frame", {
		Parent = frame,
		LayoutOrder = 2,
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
		if not name or rest == "" or #name > 40 then
			name, rest = nil, line
		end
		rest = string.upper(string.sub(rest, 1, 1)) .. string.sub(rest, 2) -- "stand within ..." reads as a sentence under its name
		if index > 1 then
			make("Frame", {
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
			end, pageTints)
		end
		local info = make("Frame", {
			Parent = entry,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		make("UIPadding", { Parent = info, PaddingLeft = UDim.new(0, name and 18 or 0) })
		label(info, { Text = rest, TextSize = TEXT_SIZE, TextColor3 = name and BODY or TEXT })
	end
end

local rows = {} -- id -> { button, name, marker }
local selected

local function paintRows()
	for id, row in pairs(rows) do
		local on = id == selected
		row.marker.Visible = on
		row.name.TextColor3 = on and Hub.InkAccent() or TEXT
	end
end

local function showTopic(id)
	local topic = HandbookConfig.Find(id)
	if not topic then
		return
	end
	selected = id
	-- the old page's cards and their tints go
	table.clear(pageTints)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	label(page, {
		LayoutOrder = 0,
		Text = topic.title,
		Font = Hub.Theme.TitleFont,
		TextSize = TITLE_SIZE,
	})
	label(page, { LayoutOrder = 1, Text = topic.summary, TextSize = TEXT_SIZE + 1, TextColor3 = MUTED })
	for index, section in ipairs(topic.sections) do
		card(section, 1 + index)
	end
	paintRows()
	task.defer(function()
		page.CanvasPosition = Vector2.zero
	end)
end

for index, topic in ipairs(HandbookConfig.Topics) do
	local button = make("TextButton", {
		Parent = list,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	})
	local marker = make("Frame", { Parent = button, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, Visible = false })
	local number = label(button, {
		Text = string.format("%02d", index),
		Font = Hub.Theme.MonoFont,
		TextSize = 12,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0, 24, 1, 0),
	})
	local name = label(button, {
		Text = topic.title,
		Font = Hub.Theme.TitleFont,
		TextSize = 15,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -46, 1, 0),
	})
	for _, text in ipairs({ number, name }) do -- one line, centred (the page's label wraps from the top)
		text.AutomaticSize = Enum.AutomaticSize.None
		text.TextYAlignment = Enum.TextYAlignment.Center
		text.TextWrapped = false
	end
	rows[topic.id] = { button = button, name = name, marker = marker }
	onTint(function(accent)
		marker.BackgroundColor3 = accent
	end)
	button.Activated:Connect(function()
		UiSfx.Play("menuSelect")
		showTopic(topic.id)
	end)
end

Hub.OnAccent(paintRows)

-- opens on the first topic each time
Hub.OnShown("Handbook", function()
	showTopic(HandbookConfig.Topics[1].id)
end)
showTopic(HandbookConfig.Topics[1].id)
