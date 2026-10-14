-- The hub's Backpack tab (B, or the hub's nav). Three columns: on the left what you
-- carry (a power, a weapon, and a melee slot kept for melee weapons still to
-- come), in the middle every set you own with ALL/POWER/WEAPON tabs, on the
-- right the selected set's info with its buttons. Cards show the set's
-- tier and your mastery in it. Powers are the held one, the ones in storage,
-- the lifetime ones and the briefcases you carry (cards tagged HELD, STORED,
-- LIFETIME, BRIEFCASE); their buttons (USE, STORE, SWAP, TAKE OUT, SWITCH)
-- go through the PowerAction remote (Powers), and one that would lose a power
-- asks CONFIRM first. Weapons come from the OwnedSets attribute the server
-- keeps; equipping goes through the EquipSet remote, which checks ownership
-- (see Loadout).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local HubRules = require(ReplicatedStorage:WaitForChild("HubRules"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local equipRemote = ReplicatedStorage:WaitForChild("EquipSet")
local powerAction = ReplicatedStorage:WaitForChild("PowerAction")

local player = Players.LocalPlayer

local PANEL_SIZE = Vector2.new(840, 460)
local COLUMN_PADDING = 10
local GAP = 12 -- between the columns
local LEFT_WIDTH = 190
local RIGHT_WIDTH = 250
local HEADING_HEIGHT = 24 -- a column's title row
local CARD_SIZE = 96
local SLOT_HEIGHT = 84
local SLOT_GAP = 8
local MATERIAL_ROW = 18
local BUTTON_HEIGHT = 32
local BACKGROUND = Hub.Theme.Panel -- cards, and the text on ink buttons
local SELECTED_BACKGROUND = Color3.fromRGB(190, 190, 188)
local COLUMN_BACKGROUND = Color3.fromRGB(218, 218, 216)
local TEXT = Hub.Theme.Ink
local MUTED = Hub.Theme.Muted
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

local tabFrame = Hub.Tab("Backpack", { order = 2, title = "BACKPACK", key = Enum.KeyCode.B, pose = "Crossed" })

local panel = make("Frame", {
	Name = "Panel",
	Parent = tabFrame,
	Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
	BackgroundTransparency = 1,
})

-- a small tab gets a smaller panel, so all three columns stay in view
local panelScale = make("UIScale", { Parent = panel })
local function rescale()
	local room = tabFrame.AbsoluteSize
	if room.X > 0 and room.Y > 0 then
		panelScale.Scale = math.min(1, room.X / PANEL_SIZE.X, room.Y / PANEL_SIZE.Y)
	end
end
rescale()
tabFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

-- a set's colour as text on the paper (a light one is darkened)
local function onPaper(color)
	return Color3.new(HubRules.Ink(color.R, color.G, color.B))
end

local body = make("Frame", {
	Parent = panel,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
})

local function column(position, size, anchor, title)
	local frame = make("Frame", {
		Parent = body,
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		BackgroundColor3 = COLUMN_BACKGROUND,
		BackgroundTransparency = 0,
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

-- left: the carry slots, then the materials you hold
local SLOTS_HEIGHT = #SLOTS * SLOT_HEIGHT + (#SLOTS - 1) * SLOT_GAP
local slotList = make("Frame", {
	Parent = leftColumn,
	Position = UDim2.fromOffset(0, HEADING_HEIGHT),
	Size = UDim2.new(1, 0, 0, SLOTS_HEIGHT),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = slotList, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, SLOT_GAP) })
local MATERIALS_TOP = HEADING_HEIGHT + SLOTS_HEIGHT + 6
label(leftColumn, {
	Text = "MATERIALS",
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = MUTED,
	Position = UDim2.fromOffset(0, MATERIALS_TOP),
	Size = UDim2.new(1, 0, 0, 16),
})
local materialList = scroller(leftColumn, {
	Position = UDim2.fromOffset(0, MATERIALS_TOP + 18),
	Size = UDim2.new(1, 0, 1, -(MATERIALS_TOP + 18)),
})
make("UIListLayout", { Parent = materialList, SortOrder = Enum.SortOrder.LayoutOrder })

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
	Size = UDim2.new(1, 0, 1, -(HEADING_HEIGHT + 4 + 18)), -- room under it for the briefcase warning
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

-- right: the selected set's info, with its buttons at the bottom
local details = scroller(rightColumn, {
	Position = UDim2.fromOffset(0, HEADING_HEIGHT),
	Size = UDim2.new(1, 0, 1, -(HEADING_HEIGHT + 2 * BUTTON_HEIGHT + 40)),
})
make("UIListLayout", { Parent = details, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) })
local message = label(rightColumn, {
	Text = "",
	TextSize = 11,
	TextColor3 = DANGER,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -(2 * BUTTON_HEIGHT + 10)),
	Size = UDim2.new(1, 0, 0, 28),
})
local function makeButton(offset)
	local button = make("TextButton", {
		Parent = rightColumn,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -offset),
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		BackgroundColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = BACKGROUND,
		Text = "",
		Visible = false,
	})
	return button, outline(button, 0.5)
end
local equipButton, equipStroke = makeButton(0) -- the main action
local altButton, altStroke = makeButton(BUTTON_HEIGHT + 6) -- a second one, for powers

-- a note under the grid while briefcases are carried (they aren't saved)
local warning = label(middleColumn, {
	Text = "Unstored briefcases are lost when you leave.",
	TextSize = 11,
	TextColor3 = DANGER,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 16),
	Visible = false,
})

local selected -- the selected card's key: a set name, or "briefcase:<set>"
local tab = "all"
local busy = false
local pending -- { action, set }: a power action waiting for CONFIRM
local primaryAction, altAction -- what the two buttons do now
local refresh -- defined below; cards and tabs call it

local BRIEFCASE_PREFIX = "briefcase:"

local function powerList(attribute)
	return PowerConfig.decodeList(player:GetAttribute(attribute), function(name)
		local set = SkillSetConfig.Sets[name]
		return set ~= nil and set.kind == "power"
	end)
end

local function heldPower()
	local name = player:GetAttribute("CurrentPower")
	local set = typeof(name) == "string" and SkillSetConfig.Sets[name]
	return set and set.kind == "power" and name or nil
end

local function isLifetime(setName)
	return SkillSetConfig.OwnAllSets or table.find(powerList("LifetimePowers"), setName) ~= nil
end

-- the power sets of the briefcases being carried
local function carriedBriefcases()
	local found, seen = {}, {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ player.Character, backpack }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			local setName = tool:IsA("Tool") and tool:GetAttribute(PowerConfig.BriefcaseAttribute)
			if setName and SkillSetConfig.Sets[setName] and not seen[setName] then
				seen[setName] = true
				table.insert(found, setName)
			end
		end
	end
	return found
end

local function carried(kind)
	for _, slot in ipairs(SLOTS) do
		if slot.kind == kind and slot.attribute then
			return player:GetAttribute(slot.attribute)
		end
	end
	return nil
end

-- every card: the held power, stored ones, lifetime ones, carried briefcases,
-- then the weapons you own. { key, setName, kind, rank, held, stored, lifetime, briefcase }
local function entries()
	local list = {}
	local held, stored = heldPower(), powerList("PowerStorage")
	for setName, set in pairs(SkillSetConfig.Sets) do
		if set.kind == "power" and not set.placeholder then
			local entry = { setName = setName, key = setName, kind = "power", held = held == setName }
			entry.stored = table.find(stored, setName) ~= nil
			entry.lifetime = isLifetime(setName)
			entry.rank = entry.held and 1 or entry.stored and 2 or 3
			if entry.held or entry.stored or entry.lifetime then
				table.insert(list, entry)
			end
		end
	end
	for _, setName in ipairs(carriedBriefcases()) do
		table.insert(list, { setName = setName, key = BRIEFCASE_PREFIX .. setName, kind = "power", briefcase = true, rank = 4 })
	end
	local ownedList = player:GetAttribute(SkillSetConfig.OwnedSetsAttribute) or ""
	for setName in string.gmatch(ownedList, "[^,]+") do
		local set = SkillSetConfig.Sets[setName]
		if set and set.kind == "weapon" then
			table.insert(list, { setName = setName, key = setName, kind = "weapon", held = carried("weapon") == setName, rank = 5 })
		end
	end
	-- held first, then stored, lifetime, briefcases, weapons; best tier, then name
	table.sort(list, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		local tierA = TIER_ORDER[SkillSetConfig.Sets[a.setName].tier] or 99
		local tierB = TIER_ORDER[SkillSetConfig.Sets[b.setName].tier] or 99
		if tierA ~= tierB then
			return tierA < tierB
		end
		return SkillSetConfig.Sets[a.setName].tool < SkillSetConfig.Sets[b.setName].tool
	end)
	return list
end

local function tagText(entry)
	if entry.briefcase then
		return "BRIEFCASE"
	elseif entry.kind == "weapon" then
		return entry.held and "EQUIPPED" or nil
	end
	return entry.held and "HELD" or entry.stored and "STORED" or entry.lifetime and "LIFETIME" or nil
end

local function stateText(entry)
	if entry.briefcase then
		return "Briefcase"
	elseif entry.kind == "weapon" then
		return entry.held and "Equipped" or "Owned"
	end
	local parts = {}
	if entry.held or entry.stored then
		table.insert(parts, entry.held and "Held" or "In storage")
	end
	if entry.lifetime then
		table.insert(parts, "Lifetime")
	end
	return table.concat(parts, " · ")
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

local function selectKey(key)
	selected = key
	pending = nil
	message.Text = ""
	refresh()
end

-- a square card in the inventory grid
local function makeCard(entry, index)
	local setName = entry.setName
	local set = SkillSetConfig.Sets[setName]
	local isSelected = entry.key == selected
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
	local tag = tagText(entry)
	if tag then
		label(card, {
			Text = tag,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextColor3 = BACKGROUND,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = TEXT,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 8),
			Size = UDim2.fromOffset(64, 14),
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
		selectKey(entry.key)
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
		selectKey(setName)
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

-- shows a button (or hides it with nil text), filled for a main action and outlined for a quiet one
local function setButton(button, stroke, text, quiet)
	button.Visible = text ~= nil
	button.Text = text or ""
	button.BackgroundTransparency = quiet and 1 or 0
	button.TextColor3 = quiet and TEXT or BACKGROUND
	stroke.Transparency = quiet and 0.4 or 0.5
end

-- asks the server for a power action; a refusal that needs a yes becomes CONFIRM / CANCEL
local function runPower(action, setName, confirm)
	if busy then
		return
	end
	busy = true
	local ok, result, why, needsConfirm = pcall(powerAction.InvokeServer, powerAction, action, { set = setName, confirm = confirm })
	busy = false
	pending = nil
	if not ok then
		message.Text = "Couldn't reach the server"
	elseif result then
		message.Text = ""
	elseif needsConfirm then
		pending = { action = action, set = setName }
		message.Text = why or "Are you sure?"
	else
		message.Text = why or "Couldn't do that"
	end
	refresh()
end

-- the buttons for a power card (a weapon's are set where it's shown)
local function powerButtons(entry)
	local setName = entry.setName
	if pending then
		primaryAction = function()
			runPower(pending.action, pending.set, true)
		end
		altAction = function()
			pending = nil
			message.Text = ""
			refresh()
		end
		setButton(equipButton, equipStroke, "CONFIRM", false)
		setButton(altButton, altStroke, "CANCEL", true)
		return
	end
	local mine = heldPower() == setName or table.find(powerList("PowerStorage"), setName) ~= nil or isLifetime(setName)
	local primaryText, altText
	if entry.briefcase then
		if SkillSetConfig.Sets[setName].placeholder then
			message.Text = "This power isn't made yet. Sell the briefcase to the Power Dealer."
		elseif mine then
			message.Text = "You already own this power. Sell the briefcase to the Power Dealer."
		else
			primaryText, altText = "USE", "STORE"
			primaryAction = function()
				runPower("use", setName, false)
			end
			altAction = function()
				runPower("store", setName, false)
			end
		end
	elseif entry.stored then
		primaryText, altText = "SWAP WITH HELD", "TAKE OUT"
		primaryAction = function()
			runPower("swap", setName, false)
		end
		altAction = function()
			runPower("takeOut", setName, false)
		end
	elseif entry.lifetime and not entry.held then
		primaryText = "SWITCH TO IT"
		primaryAction = function()
			runPower("switch", setName, false)
		end
	end
	setButton(equipButton, equipStroke, primaryText, false)
	setButton(altButton, altStroke, altText, true)
end

local function showDetails(entry)
	clear(details)
	detailOrder = 0
	primaryAction, altAction = nil, nil
	setButton(equipButton, equipStroke, nil, false)
	setButton(altButton, altStroke, nil, true)
	local set = entry and SkillSetConfig.Sets[entry.setName]
	if not set then
		label(details, { Text = "Pick a set to see its moves.", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 20) })
		return
	end
	local selectedSet = entry.setName

	local title = make("Frame", { Parent = details, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	label(title, { Text = set.tool, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = set.color and onPaper(set.color) or TEXT, Size = UDim2.new(1, 0, 0, 22) })
	label(title, {
		Text = string.format("%s-tier %s  ·  %s  ·  %s", set.tier or "?", set.kind, masteryText(selectedSet), stateText(entry)),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = tierColor(set),
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 14),
	})

	local level = mastery(selectedSet)
	-- a feature that isn't unlocked yet is dimmed with its mastery, like a locked skill
	local function featureRow(key, feature, name, note)
		local at = set[feature].mastery
		if at and level < at then
			detailRow(key, name, "Mastery " .. at, true)
		else
			detailRow(key, name, note)
		end
	end
	if set.passive then
		featureRow("PASSIVE", "passive", set.passive.name)
	end
	if set.ranged then
		detailRow(set.ranged.primary and "LMB" or "RMB+LMB", set.ranged.name)
	end
	if set.dash then
		featureRow(Keybinds.Text("Dash"), "dash", set.dash.name)
	end
	if set.overcharge then
		featureRow(Keybinds.Text("Special"), "overcharge", set.overcharge.name, "overcharge")
	end
	if set.flight then
		featureRow(Keybinds.Text("Special"), "flight", "Flight")
	end
	if set.undo then
		featureRow(Keybinds.Text("Special"), "undo", set.undo.name)
	end
	if set.gallery then
		featureRow(Keybinds.Text("Gallery"), "gallery", set.gallery.name)
	end
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
			detailRow(Keybinds.Text("Skill" .. key), name, note, locked)
		end
	end

	if entry.kind == "power" then
		powerButtons(entry)
		return
	end
	local isCarried = entry.held
	setButton(equipButton, equipStroke, isCarried and "UNEQUIP" or "EQUIP WEAPON", isCarried)
	primaryAction = function()
		if busy then
			return
		end
		busy = true
		local ok, result, why = pcall(equipRemote.InvokeServer, equipRemote, not isCarried and selectedSet or nil, set.kind)
		busy = false
		if not ok then
			message.Text = "Couldn't reach the server"
		elseif not result then
			message.Text = why or "Couldn't do that"
		else
			message.Text = ""
		end
		refresh()
	end
end

local function findEntry(list, key)
	for _, entry in ipairs(list) do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

-- one row per material you hold: its name in the tier's colour, the amount on the right
local function showMaterials()
	clear(materialList)
	local count = 0
	for _, key in ipairs(DropConfig.Sorted()) do
		local amount = player:GetAttribute(DropConfig.Attribute(key)) or 0
		if amount > 0 then
			count += 1
			local info = DropConfig.Materials[key]
			local row = make("Frame", {
				Parent = materialList,
				LayoutOrder = count,
				Size = UDim2.new(1, 0, 0, MATERIAL_ROW),
				BackgroundTransparency = 1,
			})
			label(row, {
				Text = info.display,
				TextSize = 12,
				TextColor3 = DropConfig.TierColor(info.tier),
				Size = UDim2.new(1, -40, 1, 0),
			})
			label(row, {
				Text = tostring(amount),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.new(1, 0, 1, 0),
			})
		end
	end
	if count == 0 then
		label(materialList, { Text = "None yet", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, MATERIAL_ROW) })
	end
end

function refresh()
	local list = entries()
	-- keep the selection on something that's still there
	if selected and not findEntry(list, selected) then
		selected = nil
		pending = nil
	end
	selected = selected or heldPower() or (list[1] and list[1].key)

	clear(slotList)
	for i, slot in ipairs(SLOTS) do
		makeSlot(slot, i)
	end
	showMaterials()

	for kind, button in pairs(tabButtons) do
		local active = kind == tab
		button.BackgroundTransparency = active and 0 or 1
		button.TextColor3 = active and BACKGROUND or TEXT
	end
	clear(grid)
	local count = 0
	for _, entry in ipairs(list) do
		if tab == "all" or entry.kind == tab then
			count += 1
			makeCard(entry, count)
		end
	end
	emptyLabel.Visible = count == 0
	warning.Visible = #carriedBriefcases() > 0

	showDetails(selected and findEntry(list, selected))
end

equipButton.Activated:Connect(function()
	if primaryAction then
		primaryAction()
	end
end)
altButton.Activated:Connect(function()
	if altAction then
		altAction()
	end
end)

Hub.OnShown("Backpack", function()
	message.Text = ""
	refresh()
end)

-- which attributes change what the menu shows: ownership, what's carried,
-- mastery, the player's keys
local watched = {
	[SkillSetConfig.OwnedSetsAttribute] = true,
	PowerSet = true,
	WeaponSet = true,
	CurrentPower = true,
	PowerStorage = true,
	LifetimePowers = true,
	[Keybinds.Attribute] = true,
}
for setName in pairs(SkillSetConfig.Sets) do
	watched[SkillSetConfig.MasteryAttribute(setName)] = true
end
for key in pairs(DropConfig.Materials) do
	watched[DropConfig.Attribute(key)] = true
end
player.AttributeChanged:Connect(function(name)
	if Hub.IsOpen("Backpack") and watched[name] then
		refresh()
	end
end)

-- briefcases are Tools: the menu follows them in and out of the backpack and hands
local toolsChanged = false
local function onToolsChanged()
	if toolsChanged then
		return
	end
	toolsChanged = true
	task.defer(function()
		toolsChanged = false
		if Hub.IsOpen("Backpack") then
			refresh()
		end
	end)
end
local function watchTools(container)
	container.ChildAdded:Connect(onToolsChanged)
	container.ChildRemoved:Connect(onToolsChanged)
end
local function watchCharacter(character)
	watchTools(character)
	watchTools(player:WaitForChild("Backpack"))
	onToolsChanged()
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
