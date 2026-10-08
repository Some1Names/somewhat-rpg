-- Inventory: press B or click INVENTORY. Three columns: on the left what you
-- carry (a power, a weapon, and a melee slot kept for melee weapons still to
-- come), in the middle every set you own with ALL/POWER/WEAPON tabs, on the
-- right the selected set's info with EQUIP/UNEQUIP. Cards show the set's
-- tier and your mastery in it. The owned list is the OwnedSets attribute the
-- server keeps; equipping goes through the EquipSet remote, which checks
-- ownership (see Loadout).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local equipRemote = ReplicatedStorage:WaitForChild("EquipSet")

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.B
local PANEL_SIZE = Vector2.new(840, 460)
local SCREEN_MARGIN = 16 -- the panel shrinks to keep this much screen round it
local PADDING = 14
local COLUMN_PADDING = 10
local GAP = 12 -- between the columns
local LEFT_WIDTH = 190
local RIGHT_WIDTH = 250
local HEADING_HEIGHT = 24 -- a column's title row
local CARD_SIZE = 96
local SLOT_HEIGHT = 84
local BUTTON_HEIGHT = 32
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local SELECTED_BACKGROUND = Color3.fromRGB(40, 40, 54)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local DANGER = Color3.fromRGB(226, 75, 74)
local TIER_ORDER = { S = 1, A = 2, B = 3, C = 4 }
-- the carry slots, top to bottom, with the player attribute Loadout keeps
-- each in; `reserved` ones are shown but can't hold anything yet
local SLOTS = {
	{ kind = "power", title = "POWER", attribute = "PowerSet" },
	{ kind = "weapon", title = "WEAPON", attribute = "WeaponSet" },
	{ kind = "melee", title = "MELEE", reserved = true },
}
local TABS = {
	{ kind = "all", title = "ALL" },
	{ kind = "power", title = "POWER" },
	{ kind = "weapon", title = "WEAPON" },
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

local function outline(parent, transparency, color, thickness)
	return make("UIStroke", {
		Parent = parent,
		Color = color or TEXT,
		Transparency = transparency,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	if not props.TextWrapped then
		props.TextTruncate = Enum.TextTruncate.AtEnd
	end
	return make("TextLabel", props)
end

local function padding(parent, amount)
	return make("UIPadding", {
		Parent = parent,
		PaddingTop = UDim.new(0, amount),
		PaddingBottom = UDim.new(0, amount),
		PaddingLeft = UDim.new(0, amount),
		PaddingRight = UDim.new(0, amount),
	})
end

local function clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function scroller(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.CanvasSize = UDim2.new()
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.ScrollBarThickness = 4
	props.ScrollBarImageColor3 = MUTED
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	props.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	return make("ScrollingFrame", props)
end

local gui = make("ScreenGui", {
	Name = "Inventory",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- INVENTORY button under STATS and INFO (StatsMenu), above ADMIN
local toggle = make("TextButton", {
	Name = "Toggle",
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 72),
	Size = UDim2.fromOffset(64, 28),
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.25,
	Font = Enum.Font.GothamBold,
	Text = "INVENTORY",
	TextSize = 9,
	TextColor3 = TEXT,
})
outline(toggle, 0.5)

local panel = make("Frame", {
	Name = "Panel",
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.15,
	Visible = false,
})
outline(panel, 0.6)
padding(panel, PADDING)

-- smaller screens get a smaller panel, so all three columns stay in view
local panelScale = make("UIScale", { Parent = panel })
local function rescale()
	local viewport = workspace.CurrentCamera.ViewportSize
	panelScale.Scale = math.min(1, (viewport.X - 2 * SCREEN_MARGIN) / PANEL_SIZE.X, (viewport.Y - 2 * SCREEN_MARGIN) / PANEL_SIZE.Y)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

-- header: title and close button
local header = make("Frame", { Parent = panel, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
label(header, { Text = "INVENTORY", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, -30, 1, 0) })
-- Modal frees the mouse while the menu is open, even in shift lock
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
	Modal = true,
})

local body = make("Frame", {
	Parent = panel,
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 1, -32),
	BackgroundTransparency = 1,
})

local function column(position, size, anchor, title)
	local frame = make("Frame", {
		Parent = body,
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.7,
	})
	outline(frame, 0.85)
	padding(frame, COLUMN_PADDING)
	label(frame, {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = MUTED,
		Size = UDim2.new(1, 0, 0, HEADING_HEIGHT - 6),
	})
	return frame
end

local leftColumn = column(UDim2.new(), UDim2.new(0, LEFT_WIDTH, 1, 0), Vector2.zero, "EQUIPPED")
local middleColumn = column(
	UDim2.fromOffset(LEFT_WIDTH + GAP, 0),
	UDim2.new(1, -(LEFT_WIDTH + RIGHT_WIDTH + 2 * GAP), 1, 0),
	Vector2.zero,
	"OWNED"
)
local rightColumn = column(UDim2.fromScale(1, 0), UDim2.new(0, RIGHT_WIDTH, 1, 0), Vector2.new(1, 0), "INFO")

-- left: the carry slots
local slotList = make("Frame", {
	Parent = leftColumn,
	Position = UDim2.fromOffset(0, HEADING_HEIGHT),
	Size = UDim2.new(1, 0, 1, -HEADING_HEIGHT),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = slotList, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

-- middle: tabs beside the title, then the grid of owned sets
local tabRow = make("Frame", {
	Parent = middleColumn,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, -2),
	Size = UDim2.new(1, -60, 0, 20),
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = tabRow,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 4),
})
local grid = scroller(middleColumn, {
	Position = UDim2.fromOffset(0, HEADING_HEIGHT + 4),
	Size = UDim2.new(1, 0, 1, -(HEADING_HEIGHT + 4)),
})
make("UIGridLayout", {
	Parent = grid,
	CellSize = UDim2.fromOffset(CARD_SIZE, CARD_SIZE),
	CellPadding = UDim2.fromOffset(8, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
-- the grid's cells start just inside, so selected cards' thick outlines show
make("UIPadding", { Parent = grid, PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3) })
local emptyLabel = label(middleColumn, {
	Text = "Nothing here yet",
	TextSize = 12,
	TextColor3 = MUTED,
	Position = UDim2.fromOffset(0, HEADING_HEIGHT + 4),
	Size = UDim2.new(1, 0, 0, 20),
	Visible = false,
})

-- right: the selected set's info, with EQUIP at the bottom
local details = scroller(rightColumn, {
	Position = UDim2.fromOffset(0, HEADING_HEIGHT),
	Size = UDim2.new(1, 0, 1, -(HEADING_HEIGHT + BUTTON_HEIGHT + 24)),
})
make("UIListLayout", { Parent = details, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) })
local message = label(rightColumn, {
	Text = "",
	TextSize = 11,
	TextColor3 = DANGER,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -(BUTTON_HEIGHT + 4)),
	Size = UDim2.new(1, 0, 0, 16),
})
local equipButton = make("TextButton", {
	Parent = rightColumn,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
	BackgroundColor3 = TEXT,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = BACKGROUND,
	Text = "EQUIP",
})
local equipStroke = outline(equipButton, 0.5)

local selected -- set name
local tab = "all"
local busy = false
local refresh -- defined below; cards and tabs call it

local function ownedSets()
	local owned = {}
	local list = player:GetAttribute(SkillSetConfig.OwnedSetsAttribute) or ""
	for setName in string.gmatch(list, "[^,]+") do
		if SkillSetConfig.Sets[setName] then
			table.insert(owned, setName)
		end
	end
	-- best tier first, then by name
	table.sort(owned, function(a, b)
		local tierA = TIER_ORDER[SkillSetConfig.Sets[a].tier] or 99
		local tierB = TIER_ORDER[SkillSetConfig.Sets[b].tier] or 99
		if tierA ~= tierB then
			return tierA < tierB
		end
		return SkillSetConfig.Sets[a].tool < SkillSetConfig.Sets[b].tool
	end)
	return owned
end

local function carried(kind)
	for _, slot in ipairs(SLOTS) do
		if slot.kind == kind and slot.attribute then
			return player:GetAttribute(slot.attribute)
		end
	end
	return nil
end

local function tierColor(set)
	local tier = SkillSetConfig.Tiers[set.tier]
	return tier and tier.color or SkillSetConfig.NoTierColor
end

local function mastery(setName)
	return player:GetAttribute(SkillSetConfig.MasteryAttribute(setName)) or 0
end

local function masteryText(setName)
	local level = mastery(setName)
	return level >= SkillSetConfig.MaxMastery and "Mastery MAX" or ("Mastery " .. level)
end

local function selectSet(setName)
	selected = setName
	message.Text = ""
	refresh()
end

-- a square card in the inventory grid
local function makeCard(setName, index)
	local set = SkillSetConfig.Sets[setName]
	local isSelected = setName == selected
	local card = make("TextButton", {
		Parent = grid,
		LayoutOrder = index,
		BackgroundColor3 = isSelected and SELECTED_BACKGROUND or BACKGROUND,
		BackgroundTransparency = 0.2,
		Text = "",
	})
	outline(card, isSelected and 0 or 0.35, tierColor(set), isSelected and 3 or 1)
	label(card, {
		Text = set.tier or "",
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = tierColor(set),
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(24, 22),
	})
	if carried(set.kind) == setName then
		label(card, {
			Text = "EQUIPPED",
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextColor3 = BACKGROUND,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = TEXT,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 8),
			Size = UDim2.fromOffset(56, 14),
		})
	end
	label(card, {
		Text = set.tool,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Position = UDim2.new(0, 8, 1, -52),
		Size = UDim2.new(1, -16, 0, 30),
	})
	label(card, {
		Text = masteryText(setName),
		TextSize = 10,
		TextColor3 = MUTED,
		Position = UDim2.new(0, 8, 1, -20),
		Size = UDim2.new(1, -16, 0, 12),
	})
	-- the set's own colour along the bottom
	make("Frame", {
		Parent = card,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = set.color or TEXT,
		BorderSizePixel = 0,
	})
	card.Activated:Connect(function()
		selectSet(setName)
	end)
end

-- a wide card in the EQUIPPED column: what's in this slot, or that it's empty
local function makeSlot(slot, index)
	local setName = slot.attribute and player:GetAttribute(slot.attribute)
	local set = setName and SkillSetConfig.Sets[setName]
	local isSelected = set ~= nil and setName == selected
	local frame = make(set and "TextButton" or "Frame", {
		Parent = slotList,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, SLOT_HEIGHT),
		BackgroundColor3 = isSelected and SELECTED_BACKGROUND or BACKGROUND,
		BackgroundTransparency = slot.reserved and 0.6 or 0.2,
	})
	if set then
		frame.Text = ""
	end
	outline(frame, isSelected and 0 or (set and 0.35 or 0.8), set and tierColor(set) or TEXT, isSelected and 3 or 1)
	label(frame, {
		Text = slot.title,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -20, 0, 12),
	})
	if not set then
		label(frame, {
			Text = slot.reserved and "Coming soon" or "Empty",
			TextSize = 12,
			TextColor3 = MUTED,
			TextTransparency = slot.reserved and 0.4 or 0,
			Position = UDim2.fromOffset(12, 24),
			Size = UDim2.new(1, -20, 1, -30),
		})
		return
	end
	-- the set's own colour down the left edge
	make("Frame", {
		Parent = frame,
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = set.color or TEXT,
		BorderSizePixel = 0,
	})
	label(frame, {
		Text = set.tier or "",
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = tierColor(set),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.fromOffset(26, 30),
	})
	label(frame, {
		Text = set.tool,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(46, 24),
		Size = UDim2.new(1, -54, 0, 32),
	})
	label(frame, {
		Text = masteryText(setName),
		TextSize = 10,
		TextColor3 = MUTED,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 46, 1, -8),
		Size = UDim2.new(1, -54, 0, 12),
	})
	frame.Activated:Connect(function()
		selectSet(setName)
	end)
end

local tabButtons = {}
for i, entry in ipairs(TABS) do
	local button = make("TextButton", {
		Parent = tabRow,
		LayoutOrder = i,
		Size = UDim2.fromOffset(entry.kind == "all" and 38 or 60, 20),
		BackgroundColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		Text = entry.title,
		TextSize = 10,
	})
	outline(button, 0.5)
	button.Activated:Connect(function()
		tab = entry.kind
		refresh()
	end)
	tabButtons[entry.kind] = button
end

-- one line of the info: a key (or tag) box, then the move's name and a note
local detailOrder = 0
local function detailRow(key, name, note, dim)
	detailOrder += 1
	local row = make("Frame", {
		Parent = details,
		LayoutOrder = detailOrder,
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	local color = dim and MUTED or TEXT
	local keyBox = label(row, {
		Text = key,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(50, 20),
	})
	outline(keyBox, dim and 0.8 or 0.6)
	label(row, {
		Text = note and string.format('%s  <font color="#a5a5b4" size="10">%s</font>', name, note) or name,
		RichText = true,
		TextSize = 12,
		TextColor3 = color,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(58, 0),
		Size = UDim2.new(1, -58, 0, 20),
	})
end

local function showDetails()
	clear(details)
	detailOrder = 0
	local set = selected and SkillSetConfig.Sets[selected]
	equipButton.Visible = set ~= nil
	if not set then
		label(details, { Text = "Pick a set to see its moves.", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 20) })
		return
	end

	local title = make("Frame", { Parent = details, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	label(title, { Text = set.tool, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = set.color or TEXT, Size = UDim2.new(1, 0, 0, 22) })
	label(title, {
		Text = string.format("%s-tier %s  ·  %s", set.tier or "?", set.kind, masteryText(selected)),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = tierColor(set),
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 14),
	})

	if set.passive then
		detailRow("PASSIVE", set.passive.name)
	end
	if set.ranged then
		detailRow(set.ranged.primary and "LMB" or "RMB+LMB", set.ranged.name)
	end
	if set.dash then
		detailRow("Q", set.dash.name)
	end
	if set.overcharge then
		detailRow(SkillSetConfig.OverchargeKey, set.overcharge.name, "overcharge")
	end
	if set.flight then
		detailRow(SkillSetConfig.FlightKey, "Flight")
	end
	local level = mastery(selected)
	for _, key in ipairs(SkillSetConfig.Keys) do
		local skill = set.skills and set.skills[key]
		if skill then
			local name = skill.name
			if skill.overchargedName then
				name ..= " / " .. skill.overchargedName
			end
			if skill.fullName then
				name ..= " / " .. skill.fullName
			end
			local locked = level < (skill.mastery or 0)
			local note = locked and ("Mastery " .. skill.mastery) or skill.overchargedOnly and "overcharge only" or nil
			detailRow(key, name, note, locked)
		end
	end

	local isCarried = carried(set.kind) == selected
	equipButton.Text = isCarried and "UNEQUIP" or ("EQUIP " .. string.upper(set.kind))
	equipButton.BackgroundTransparency = isCarried and 1 or 0
	equipButton.TextColor3 = isCarried and TEXT or BACKGROUND
	equipStroke.Transparency = isCarried and 0.4 or 0.5
end

function refresh()
	local owned = ownedSets()
	-- keep the selection on something owned
	if selected and not table.find(owned, selected) then
		selected = nil
	end
	selected = selected or carried("power") or owned[1]

	clear(slotList)
	for i, slot in ipairs(SLOTS) do
		makeSlot(slot, i)
	end

	for kind, button in pairs(tabButtons) do
		local active = kind == tab
		button.BackgroundTransparency = active and 0 or 1
		button.TextColor3 = active and BACKGROUND or TEXT
	end
	clear(grid)
	local count = 0
	for _, setName in ipairs(owned) do
		if tab == "all" or SkillSetConfig.Sets[setName].kind == tab then
			count += 1
			makeCard(setName, count)
		end
	end
	emptyLabel.Visible = count == 0

	showDetails()
end

equipButton.Activated:Connect(function()
	local set = selected and SkillSetConfig.Sets[selected]
	if busy or not set then
		return
	end
	busy = true
	local unequip = carried(set.kind) == selected
	local ok, result, why = pcall(equipRemote.InvokeServer, equipRemote, not unequip and selected or nil, set.kind)
	busy = false
	if not ok then
		message.Text = "Couldn't reach the server"
	elseif not result then
		message.Text = why or "Couldn't do that"
	else
		message.Text = ""
	end
	refresh()
end)

local function setOpen(open)
	panel.Visible = open
	if open then
		message.Text = ""
		refresh()
	end
end

toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == TOGGLE_KEY then
		setOpen(not panel.Visible)
	end
end)

-- which attributes change what the menu shows: ownership, what's carried, mastery
local watched = { [SkillSetConfig.OwnedSetsAttribute] = true, PowerSet = true, WeaponSet = true }
for setName in pairs(SkillSetConfig.Sets) do
	watched[SkillSetConfig.MasteryAttribute(setName)] = true
end
player.AttributeChanged:Connect(function(name)
	if panel.Visible and watched[name] then
		refresh()
	end
end)
