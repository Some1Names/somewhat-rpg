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
-- (see Loadout). The ITEMS tab (and ALL) also lists consumables: the Tools
-- equipped on the hotbar and the stacks stored in the Backpack (the saved
-- ConsumableStorage attribute); USE, STORE and EQUIP go through the
-- ConsumableAction remote (Consumables). Power briefcases are items too: equipped on the
-- hotbar or stored in the Backpack (the BriefcaseStorage attribute), with the power buttons
-- plus EQUIP / UNEQUIP (the PowerAction remote). EQUIP asks which free hotbar slot (4 to 9)
-- to use. The ALL tab groups the cards under POWERS, WEAPONS and ITEMS headers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConsumableConfig = require(ReplicatedStorage:WaitForChild("ConsumableConfig"))
local HotbarRules = require(ReplicatedStorage:WaitForChild("HotbarRules"))
local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local HubRules = require(ReplicatedStorage:WaitForChild("HubRules"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local TalismanConfig = require(ReplicatedStorage:WaitForChild("TalismanConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))

-- which server actions put something on (or take it off) and so make the equip sounds
local ACTION_SOUNDS = {
	use = "equip",
	swap = "equip",
	takeOut = "equip",
	switch = "equip",
	equipBriefcase = "equip",
	equip = "equip",
	store = "unequip",
	unequipBriefcase = "unequip",
	unequip = "unequip",
}

-- The take-off sound plays as the button goes down (before the click finishes,
-- see the buttons at the bottom) and again from the action: only the first counts.
local lastUnequipAt = -math.huge
local function playUnequip()
	if os.clock() - lastUnequipAt > 0.5 then
		lastUnequipAt = os.clock()
		UiSfx.Play("unequip")
	end
end
local PRESS_UNEQUIP = { "UNEQUIP", "TAKE OFF", "STORE" } -- button texts that take something off
local talismanRemote = ReplicatedStorage:WaitForChild("TalismanAction")
local equipRemote = ReplicatedStorage:WaitForChild("EquipSet")
local itemRemote = ReplicatedStorage:WaitForChild("ConsumableAction")
local powerAction = ReplicatedStorage:WaitForChild("PowerAction")

local player = Players.LocalPlayer

local PANEL_SIZE = Vector2.new(1000, 460)
local COLUMN_PADDING = 10
local GAP = 12 -- between the columns
local LEFT_WIDTH = 250
local RIGHT_WIDTH = 330
local HEADING_HEIGHT = 24 -- a column's title row
local CARD_SIZE = 96
local SLOT_HEIGHT = 66
local SLOT_GAP = 8
local MATERIAL_ROW = 18
local BUTTON_HEIGHT = 32
local BACKGROUND = Hub.Theme.Panel -- cards, and the text on ink buttons
local SELECTED_BACKGROUND = Color3.fromRGB(58, 58, 66)
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
-- the ALL tab's groups of cards, top to bottom
local SECTIONS = {
	{ kind = "power", title = "POWERS" },
	{ kind = "weapon", title = "WEAPONS" },
	{ kind = "item", title = "ITEMS" },
	{ kind = "talisman", title = "TALISMANS" },
}
local TABS = {
	{ kind = "all", title = "ALL" },
	{ kind = "power", title = "POWER" },
	{ kind = "weapon", title = "WEAPON" },
	{ kind = "item", title = "ITEMS" },
	{ kind = "talisman", title = "TALISMAN", width = 66 },
}
local TALISMAN_BOX = 70 -- a talisman slot in the EQUIPPED column: a square, three in a row
local TALISMAN_GAP = 10

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
	props.Font = props.Font or Enum.Font.Highway
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

local tabFrame = Hub.Tab("Backpack", { order = 2, title = "BACKPACK", key = Enum.KeyCode.B })

local panel = make("Frame", {
	Name = "Panel",
	Parent = tabFrame,
	Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
	BackgroundTransparency = 1,
})

-- the panel fills the tab; a tab smaller than PANEL_SIZE shrinks it (UIScale), so all three columns stay in view
local panelScale = make("UIScale", { Parent = panel })
local function rescale()
	local room = tabFrame.AbsoluteSize / UIScale.Get() -- real pixels to UI pixels
	if room.X > 0 and room.Y > 0 then
		local scale = math.min(1, room.X / PANEL_SIZE.X, room.Y / PANEL_SIZE.Y)
		panelScale.Scale = scale
		panel.Size = UDim2.fromOffset(room.X / scale, room.Y / scale)
	end
end
rescale()
tabFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
UIScale.OnChange(rescale)

-- a set's colour as text on the paper (a dark one is lightened)
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
		BackgroundTransparency = 1,
	})
	padding(frame, COLUMN_PADDING)
	label(frame, {
		Text = title,
		Font = Enum.Font.Highway,
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
-- one thin rule in each gap between the columns
for _, x in ipairs({ UDim.new(0, LEFT_WIDTH + GAP / 2), UDim.new(1, -(RIGHT_WIDTH + GAP / 2)) }) do
	make("Frame", { Parent = body, Position = UDim2.new(x, UDim.new()), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = TEXT, BackgroundTransparency = 0.85, BorderSizePixel = 0 })
end

-- left: the carry slots, then the materials you hold
local SLOTS_HEIGHT = #SLOTS * SLOT_HEIGHT + (#SLOTS - 1) * SLOT_GAP
local slotList = make("Frame", {
	Parent = leftColumn,
	Position = UDim2.fromOffset(0, HEADING_HEIGHT),
	Size = UDim2.new(1, 0, 0, SLOTS_HEIGHT),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = slotList, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, SLOT_GAP) })
-- under the slots: a row of square talisman slots (worn, empty or locked)
local SECTION_GAP = 20 -- between the EQUIPPED slots, the talismans and the materials
local TALISMANS_TOP = HEADING_HEIGHT + SLOTS_HEIGHT + SECTION_GAP
local TALISMANS_HEIGHT = 16 + TALISMAN_BOX
label(leftColumn, {
	Text = "TALISMANS",
	Font = Enum.Font.Highway,
	TextSize = 12,
	TextColor3 = MUTED,
	Position = UDim2.fromOffset(0, TALISMANS_TOP),
	Size = UDim2.new(1, 0, 0, 16),
})
local talismanList = make("Frame", {
	Parent = leftColumn,
	Position = UDim2.fromOffset(0, TALISMANS_TOP + 18),
	Size = UDim2.new(1, 0, 0, TALISMANS_HEIGHT - 16),
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = talismanList,
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, TALISMAN_GAP),
})
local MATERIALS_TOP = TALISMANS_TOP + TALISMANS_HEIGHT + SECTION_GAP
label(leftColumn, {
	Text = "MATERIALS",
	Font = Enum.Font.Highway,
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
-- the grid is a list of sections (a header and a grid of cards each; ALL has a section per kind of card)
make("UIListLayout", { Parent = grid, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })
local cardParent = grid -- where makeCard puts the card it makes
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
	Size = UDim2.new(1, 0, 1, -(HEADING_HEIGHT + 3 * BUTTON_HEIGHT + 52)),
})
make("UIListLayout", { Parent = details, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) })
local message = label(rightColumn, {
	Text = "",
	TextSize = 11,
	TextColor3 = DANGER,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -(3 * BUTTON_HEIGHT + 22)),
	Size = UDim2.new(1, 0, 0, 28),
})
local function makeButton(offset)
	local button = make("TextButton", {
		Parent = rightColumn,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -offset),
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		BackgroundColor3 = TEXT,
		Font = Enum.Font.Highway,
		TextSize = 13,
		TextColor3 = BACKGROUND,
		Text = "",
		Visible = false,
	})
	return button, outline(button, 0.5)
end
local equipButton, equipStroke = makeButton(0) -- the main action
local altButton, altStroke = makeButton(BUTTON_HEIGHT + 6) -- a second one, for powers
local hotbarButton, hotbarStroke = makeButton(2 * (BUTTON_HEIGHT + 6)) -- a briefcase's EQUIP / UNEQUIP

-- a note under the grid while you have briefcases (they aren't saved)
local warning = label(middleColumn, {
	Text = "Briefcases are lost when you leave.",
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
local pickingSlot = false -- EQUIP was pressed: the hotbar slots are shown to pick from
local primaryAction, altAction, hotbarAction -- what the buttons do now
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

-- every briefcase the player has: the Tools equipped on the hotbar, then the ones in storage
-- ({ setName, tool } or { setName, storedIndex })
local function allBriefcases()
	local found = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ player.Character, backpack }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			local setName = tool:IsA("Tool") and tool:GetAttribute(PowerConfig.BriefcaseAttribute)
			if setName and SkillSetConfig.Sets[setName] then
				table.insert(found, { setName = setName, tool = tool, equipped = true })
			end
		end
	end
	local index = 0
	for setName in string.gmatch(player:GetAttribute(PowerConfig.BriefcaseStorageAttribute) or "", "[^,]+") do
		index += 1
		if SkillSetConfig.Sets[setName] then
			table.insert(found, { setName = setName, storedIndex = index })
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
	for index, found in ipairs(allBriefcases()) do
		table.insert(list, {
			setName = found.setName,
			key = BRIEFCASE_PREFIX .. index .. ":" .. found.setName,
			kind = "power",
			category = "item",
			briefcase = true,
			equipped = found.equipped,
			tool = found.tool,
			storedIndex = found.storedIndex,
			rank = found.equipped and 6.5 or 7.5,
		})
	end
	local worn = TalismanConfig.Parse(player:GetAttribute(TalismanConfig.EquippedAttribute))
	for _, key in ipairs(TalismanConfig.Parse(player:GetAttribute(TalismanConfig.OwnedAttribute))) do
		table.insert(list, {
			kind = "talisman",
			talisman = TalismanConfig.Get(key),
			key = "talisman:" .. key,
			equipped = table.find(worn, key) ~= nil,
			rank = 8,
			order = TalismanConfig.Order(key),
		})
	end
	local ownedList = player:GetAttribute(SkillSetConfig.OwnedSetsAttribute) or ""
	for setName in string.gmatch(ownedList, "[^,]+") do
		local set = SkillSetConfig.Sets[setName]
		if set and set.kind == "weapon" then
			table.insert(list, { setName = setName, key = setName, kind = "weapon", held = carried("weapon") == setName, rank = 5 })
		end
	end
	-- consumables: the Tools equipped on the hotbar, then the stacks stored in the Backpack
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			local key = tool:IsA("Tool") and tool:GetAttribute(ConsumableConfig.Attribute)
			local item = key and ConsumableConfig.Get(key)
			if item then
				local stackId = tool:GetAttribute(ConsumableConfig.StackAttribute) or 0
				table.insert(list, {
					kind = "item",
					item = item,
					tool = tool,
					uses = tool:GetAttribute(ConsumableConfig.UsesAttribute),
					equipped = true,
					key = "stack:" .. stackId,
					rank = 6,
					order = stackId,
				})
			end
		end
	end
	for index, stack in ipairs(ConsumableConfig.ParseStorage(player:GetAttribute(ConsumableConfig.StorageAttribute))) do
		table.insert(list, {
			kind = "item",
			item = ConsumableConfig.Get(stack.key),
			uses = stack.uses,
			storedIndex = index,
			key = "stored:" .. index,
			rank = 7,
			order = index,
		})
	end
	-- held first, then stored, lifetime, briefcases, weapons, items; best tier, then name
	table.sort(list, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		if a.kind == "item" or a.kind == "talisman" then
			return a.order < b.order
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
		return entry.equipped and "EQUIPPED" or nil
	elseif entry.kind == "weapon" then
		return entry.held and "EQUIPPED" or nil
	end
	return entry.held and "HELD" or entry.stored and "STORED" or entry.lifetime and "LIFETIME" or nil
end

local function stateText(entry)
	if entry.briefcase then
		return entry.equipped and "Briefcase · equipped" or "Briefcase · stored"
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
	if key ~= selected then
		UiSfx.Play("itemSelect")
	end
	selected = key
	pending = nil
	pickingSlot = false
	message.Text = ""
	refresh()
end

-- consumables: orange when limited, cyan for a lifetime item
local function itemColor(item)
	return item.kind == "lifetime" and Color3.fromRGB(60, 224, 230) or Color3.fromRGB(255, 154, 60)
end

-- a card for an equipped or stored consumable
local function makeItemCard(entry, index)
	local item = entry.item
	local isSelected = entry.key == selected
	local color = itemColor(item)
	local card = make("TextButton", {
		Parent = cardParent,
		LayoutOrder = index,
		BackgroundColor3 = isSelected and SELECTED_BACKGROUND or BACKGROUND,
		BackgroundTransparency = 0.2,
		Text = "",
	})
	outline(card, isSelected and 0 or 0.35, onPaper(color), isSelected and 3 or 1)
	label(card, {
		Text = item.kind == "limited" and string.format("%d/%d", entry.uses or 0, item.maxUses) or "LIFE",
		Font = Enum.Font.Highway,
		TextSize = item.kind == "limited" and 20 or 15,
		TextColor3 = onPaper(color),
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(44, 22),
	})
	-- only an equipped item is tagged; a stored one has no tag
	if entry.equipped then
		label(card, {
			Text = "EQUIPPED",
			Font = Enum.Font.Highway,
			TextSize = 9,
			TextColor3 = BACKGROUND,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = TEXT,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 30),
			Size = UDim2.fromOffset(64, 14),
		})
	end
	label(card, {
		Text = item.name,
		Font = Enum.Font.Highway,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Position = UDim2.new(0, 8, 1, -52),
		Size = UDim2.new(1, -16, 0, 30),
	})
	label(card, {
		Text = item.kind == "limited" and "Limited use" or "Lifetime",
		TextSize = 10,
		TextColor3 = MUTED,
		Position = UDim2.new(0, 8, 1, -20),
		Size = UDim2.new(1, -16, 0, 12),
	})
	make("Frame", {
		Parent = card,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	})
	card.Activated:Connect(function()
		selectKey(entry.key)
	end)
end

local function talismanColor(talisman)
	return Color3.fromRGB(table.unpack(talisman.color))
end

-- a card for an owned talisman
local function makeTalismanCard(entry, index)
	local talisman = entry.talisman
	local isSelected = entry.key == selected
	local color = talismanColor(talisman)
	local card = make("TextButton", {
		Parent = cardParent,
		LayoutOrder = index,
		BackgroundColor3 = isSelected and SELECTED_BACKGROUND or BACKGROUND,
		BackgroundTransparency = 0.2,
		Text = "",
	})
	outline(card, isSelected and 0 or 0.35, onPaper(color), isSelected and 3 or 1)
	-- a diamond-ish mark: the first letter in the talisman's colour
	label(card, {
		Text = string.sub(talisman.name, 1, 1),
		Font = Enum.Font.Highway,
		TextSize = 24,
		TextColor3 = onPaper(color),
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.fromOffset(30, 28),
	})
	if entry.equipped then
		label(card, {
			Text = "WORN",
			Font = Enum.Font.Highway,
			TextSize = 9,
			TextColor3 = BACKGROUND,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = TEXT,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 8),
			Size = UDim2.fromOffset(44, 14),
		})
	end
	label(card, {
		Text = talisman.name,
		Font = Enum.Font.Highway,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Position = UDim2.new(0, 8, 1, -52),
		Size = UDim2.new(1, -16, 0, 30),
	})
	label(card, {
		Text = "Talisman",
		TextSize = 10,
		TextColor3 = MUTED,
		Position = UDim2.new(0, 8, 1, -20),
		Size = UDim2.new(1, -16, 0, 12),
	})
	make("Frame", {
		Parent = card,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	})
	card.Activated:Connect(function()
		selectKey(entry.key)
	end)
end

-- a square card in the inventory grid
local function makeCard(entry, index)
	if entry.kind == "item" then
		makeItemCard(entry, index)
		return
	elseif entry.kind == "talisman" then
		makeTalismanCard(entry, index)
		return
	end
	local setName = entry.setName
	local set = SkillSetConfig.Sets[setName]
	local isSelected = entry.key == selected
	local card = make("TextButton", {
		Parent = cardParent,
		LayoutOrder = index,
		BackgroundColor3 = isSelected and SELECTED_BACKGROUND or BACKGROUND,
		BackgroundTransparency = 0.2,
		Text = "",
	})
	outline(card, isSelected and 0 or 0.35, tierColor(set), isSelected and 3 or 1)
	label(card, {
		Text = set.tier or "",
		Font = Enum.Font.Highway,
		TextSize = 20,
		TextColor3 = tierColor(set),
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(24, 22),
	})
	local tag = tagText(entry)
	if tag then
		label(card, {
			Text = tag,
			Font = Enum.Font.Highway,
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
		Font = Enum.Font.Highway,
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
		Font = Enum.Font.Highway,
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
		Font = Enum.Font.Highway,
		TextSize = 24,
		TextColor3 = tierColor(set),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.fromOffset(26, 30),
	})
	label(frame, {
		Text = set.tool,
		Font = Enum.Font.Highway,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(46, 24),
		Size = UDim2.new(1, -54, 0, 20),
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

-- the EQUIPPED column's talisman slots, three squares in a row: a worn one (click to
-- select it), or a placeholder name for an empty or locked slot (with its level)
local function makeTalismanSlots()
	clear(talismanList)
	local worn = TalismanConfig.Parse(player:GetAttribute(TalismanConfig.EquippedAttribute))
	local open = TalismanConfig.Slots(player:GetAttribute("Level") or 0)
	for i, at in ipairs(TalismanConfig.SlotLevels) do
		local key = worn[i]
		local talisman = key and TalismanConfig.Get(key)
		local isSelected = talisman ~= nil and "talisman:" .. key == selected
		local box = make(talisman and "TextButton" or "Frame", {
			Parent = talismanList,
			LayoutOrder = i,
			Size = UDim2.fromOffset(TALISMAN_BOX, TALISMAN_BOX),
			BackgroundColor3 = isSelected and SELECTED_BACKGROUND or BACKGROUND,
			BackgroundTransparency = talisman and 0.2 or 0.6,
		})
		if talisman then
			box.Text = ""
		end
		outline(box, isSelected and 0 or (talisman and 0.35 or 0.8), talisman and onPaper(talismanColor(talisman)) or TEXT, isSelected and 3 or 1)
		-- the slot number, top left
		label(box, {
			Text = tostring(i),
			Font = Enum.Font.Highway,
			TextSize = 10,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(20, 12),
		})
		-- the worn talisman's name, or a placeholder name (with the level that opens a locked slot)
		label(box, {
			Text = talisman and talisman.name or string.format("Talisman %d", i),
			Font = talisman and Enum.Font.Highway or Enum.Font.Highway,
			TextSize = 11,
			TextColor3 = talisman and TEXT or MUTED,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Position = UDim2.fromOffset(4, 16),
			Size = UDim2.new(1, -8, 1, -34),
		})
		if i > open then
			label(box, {
				Text = string.format("LV %d", at),
				Font = Enum.Font.Highway,
				TextSize = 9,
				TextColor3 = MUTED,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -8),
				Size = UDim2.new(1, 0, 0, 12),
			})
		end
		if talisman then
			make("Frame", {
				Parent = box,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundColor3 = talismanColor(talisman),
				BorderSizePixel = 0,
			})
			box.Activated:Connect(function()
				selectKey("talisman:" .. key)
			end)
		end
	end
end

local tabButtons = {}
for i, entry in ipairs(TABS) do
	local button = make("TextButton", {
		Parent = tabRow,
		LayoutOrder = i,
		Size = UDim2.fromOffset(entry.width or (entry.kind == "all" and 38 or 60), 20),
		BackgroundColor3 = TEXT,
		Font = Enum.Font.Highway,
		Text = entry.title,
		TextSize = 10,
	})
	outline(button, 0.5)
	button:SetAttribute("SectionSelect", true)
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
		Font = Enum.Font.Highway,
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
local function runPower(action, setName, confirm, slot)
	if busy then
		return
	end
	busy = true
	if ACTION_SOUNDS[action] == "unequip" then
		playUnequip() -- at once, not after the trip to the server
	end
	local ok, result, why, needsConfirm = pcall(powerAction.InvokeServer, powerAction, action, { set = setName, confirm = confirm, slot = slot })
	busy = false
	pending = nil
	if not ok then
		message.Text = "Couldn't reach the server"
		UiSfx.Play("denied")
	elseif result then
		message.Text = ""
		pickingSlot = false
		if ACTION_SOUNDS[action] == "equip" then -- (taking off already sounded when it was asked)
			UiSfx.Play("equip")
		end
	elseif needsConfirm then
		pending = { action = action, set = setName }
		message.Text = why or "Are you sure?"
	else
		message.Text = why or "Couldn't do that"
		UiSfx.Play("denied")
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
		primaryText, altText = heldPower() and "SWAP WITH HELD" or "EQUIP", "TAKE OUT"
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
	elseif entry.held then
		primaryText = "UNEQUIP"
		primaryAction = function()
			runPower("unequip", setName, false)
		end
	end
	setButton(equipButton, equipStroke, primaryText, false)
	setButton(altButton, altStroke, altText, true)
end

-- the hotbar's item slots (the 4 to 9 keys) as they are now: slot -> the Tool in it
local function hotbarOccupants()
	local tools = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ player.Character, backpack }) do
		for _, tool in ipairs(container and container:GetChildren() or {}) do
			if tool:IsA("Tool") then
				local set = SkillSetConfig.Sets[tool:GetAttribute("SkillSet")]
				if HotbarRules.InGrid(set and set.kind) then
					table.insert(tools, tool)
				end
			end
		end
	end
	table.sort(tools, function(a, b)
		local slotA, slotB = a:GetAttribute(HotbarRules.Attribute) or math.huge, b:GetAttribute(HotbarRules.Attribute) or math.huge
		if slotA ~= slotB then
			return slotA < slotB
		end
		return a.Name < b.Name
	end)
	local entries = {}
	for _, tool in ipairs(tools) do
		table.insert(entries, { id = tool, slot = tool:GetAttribute(HotbarRules.Attribute) })
	end
	return HotbarRules.Layout(entries)
end

-- a row of the six hotbar slots to pick from: a free one equips the item there, a taken one shows what's in it.
-- `equipTo(slot)` does the equipping
local function slotPicker(equipTo)
	detailOrder += 1
	local frame = make("Frame", { Parent = details, LayoutOrder = detailOrder, Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1 })
	label(frame, { Text = "PICK A HOTBAR SLOT", Font = Enum.Font.Highway, TextSize = 10, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 14) })
	local row = make("Frame", { Parent = frame, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1 })
	make("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
	local occupants = hotbarOccupants()
	for slot = 1, HotbarRules.Slots do
		local tool = occupants[slot]
		local box = make("TextButton", {
			Parent = row,
			LayoutOrder = slot,
			Size = UDim2.new(1 / HotbarRules.Slots, -4, 1, 0),
			BackgroundColor3 = TEXT,
			BackgroundTransparency = tool and 0.85 or 0,
			AutoButtonColor = tool == nil,
			Text = "",
		})
		outline(box, tool and 0.7 or 0.4)
		label(box, {
			Text = tostring(3 + slot),
			Font = Enum.Font.Highway,
			TextSize = 14,
			TextColor3 = tool and MUTED or BACKGROUND,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 0, 18),
		})
		label(box, {
			Text = tool and tool.Name or "free",
			TextSize = 8,
			TextColor3 = tool and MUTED or BACKGROUND,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Position = UDim2.fromOffset(2, 24),
			Size = UDim2.new(1, -4, 0, 26),
		})
		if not tool then
			box.Activated:Connect(function()
				equipTo(slot)
			end)
		end
	end
end

-- asks the server to use, store or equip a consumable (`target` is the equipped Tool, or a stored stack's number)
local function runItem(action, target, slot)
	if busy then
		return
	end
	busy = true
	if ACTION_SOUNDS[action] == "unequip" then
		playUnequip()
	end
	local ok, result, why = pcall(itemRemote.InvokeServer, itemRemote, action, target, slot)
	busy = false
	if not ok then
		message.Text = "Couldn't reach the server"
		UiSfx.Play("denied")
	elseif result then
		message.Text = ""
		pickingSlot = false
		if ACTION_SOUNDS[action] == "equip" then -- (taking off already sounded when it was asked)
			UiSfx.Play("equip")
		end
	else
		message.Text = why or "Couldn't do that"
		UiSfx.Play("denied")
	end
	refresh()
end

-- the info and buttons for a consumable: USE, and STORE (equipped) or EQUIP (stored)
local function itemDetails(entry)
	local item = entry.item
	local color = onPaper(itemColor(item))
	local title = make("Frame", { Parent = details, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	label(title, { Text = item.name, Font = Enum.Font.Highway, TextSize = 16, TextColor3 = color, Size = UDim2.new(1, 0, 0, 22) })
	label(title, {
		Text = string.format("%s  ·  %s", item.kind == "limited" and "Limited use" or "Lifetime", entry.equipped and "Equipped on the hotbar" or "Stored in the Backpack"),
		Font = Enum.Font.Highway,
		TextSize = 11,
		TextColor3 = color,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 14),
	})
	if pickingSlot and not entry.equipped then
		slotPicker(function(slot)
			runItem("equip", entry.storedIndex, slot)
		end)
	end
	detailRow("INFO", item.description)
	detailRow("USES", item.kind == "limited" and string.format("%d of %d left", entry.uses or 0, item.maxUses) or "Unlimited")
	local readyAt = player:GetAttribute("ConsumableReadyAt_" .. item.key)
	local left = readyAt and readyAt - workspace:GetServerTimeNow() or 0
	detailRow("COOLDOWN", string.format("%d s", item.cooldown), left > 0 and string.format("ready in %d s", math.ceil(left)) or "ready")
	primaryAction = function()
		runItem("use", entry.tool or entry.storedIndex)
	end
	altAction = function()
		if entry.equipped then
			runItem("store", entry.tool)
		else
			-- EQUIP shows the hotbar's slots to pick from
			pickingSlot = not pickingSlot
			refresh()
		end
	end
	setButton(equipButton, equipStroke, "USE", false)
	setButton(altButton, altStroke, entry.equipped and "STORE" or (pickingSlot and "CANCEL" or "EQUIP"), true)
end

-- the info and the WEAR / TAKE OFF button for a talisman
local function talismanDetails(entry)
	local talisman = entry.talisman
	local color = onPaper(talismanColor(talisman))
	local title = make("Frame", { Parent = details, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	label(title, { Text = talisman.name, Font = Enum.Font.Highway, TextSize = 16, TextColor3 = color, Size = UDim2.new(1, 0, 0, 22) })
	label(title, {
		Text = entry.equipped and "Talisman  ·  Worn" or "Talisman  ·  In your collection",
		Font = Enum.Font.Highway,
		TextSize = 11,
		TextColor3 = color,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 14),
	})
	detailRow("EFFECT", talisman.description)
	local level = player:GetAttribute("Level") or 0
	local worn = TalismanConfig.Parse(player:GetAttribute(TalismanConfig.EquippedAttribute))
	local slots = TalismanConfig.Slots(level)
	detailRow("SLOTS", string.format("%d of %d in use", #worn, slots), TalismanConfig.NextSlotLevel(level) and string.format("next slot at level %d", TalismanConfig.NextSlotLevel(level)) or nil)
	local key = talisman.key
	primaryAction = function()
		if busy then
			return
		end
		busy = true
		if entry.equipped then
			playUnequip()
		end
		local ok, result, why = pcall(talismanRemote.InvokeServer, talismanRemote, entry.equipped and "unequip" or "equip", key)
		busy = false
		if not ok then
			message.Text = "Couldn't reach the server"
			UiSfx.Play("denied")
		elseif not result then
			message.Text = why or "Couldn't do that"
			UiSfx.Play("denied")
		else
			message.Text = ""
			if not entry.equipped then
				UiSfx.Play("equip")
			end
		end
		refresh()
	end
	setButton(equipButton, equipStroke, entry.equipped and "TAKE OFF" or "WEAR", entry.equipped)
end

local function showDetails(entry)
	clear(details)
	detailOrder = 0
	primaryAction, altAction, hotbarAction = nil, nil, nil
	setButton(equipButton, equipStroke, nil, false)
	setButton(altButton, altStroke, nil, true)
	setButton(hotbarButton, hotbarStroke, nil, true)
	if entry and entry.kind == "item" then
		itemDetails(entry)
		return
	elseif entry and entry.kind == "talisman" then
		talismanDetails(entry)
		return
	end
	local set = entry and SkillSetConfig.Sets[entry.setName]
	if not set then
		label(details, { Text = "Pick a set to see its moves.", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 20) })
		return
	end
	local selectedSet = entry.setName

	local title = make("Frame", { Parent = details, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	label(title, { Text = set.tool, Font = Enum.Font.Highway, TextSize = 16, TextColor3 = set.color and onPaper(set.color) or TEXT, Size = UDim2.new(1, 0, 0, 22) })
	label(title, {
		Text = string.format("%s-tier %s  ·  %s  ·  %s", set.tier or "?", set.kind, masteryText(selectedSet), stateText(entry)),
		Font = Enum.Font.Highway,
		TextSize = 11,
		TextColor3 = tierColor(set),
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 14),
	})

	if pickingSlot and entry.briefcase and not entry.equipped then
		slotPicker(function(slot)
			runPower("equipBriefcase", selectedSet, false, slot)
		end)
	end
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
		detailRow(set.ranged.primary and "LMB" or "RANGED", set.ranged.name)
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
		if entry.briefcase and not pending then
			-- a briefcase also goes on the hotbar and back
			if entry.equipped then
				hotbarAction = function()
					runPower("unequipBriefcase", selectedSet, false)
				end
				setButton(hotbarButton, hotbarStroke, "UNEQUIP", true)
			else
				hotbarAction = function()
					pickingSlot = not pickingSlot
					refresh()
				end
				setButton(hotbarButton, hotbarStroke, pickingSlot and "CANCEL" or "EQUIP", true)
			end
		end
		return
	end
	local isCarried = entry.held
	setButton(equipButton, equipStroke, isCarried and "UNEQUIP" or "EQUIP WEAPON", isCarried)
	primaryAction = function()
		if busy then
			return
		end
		busy = true
		if isCarried then
			playUnequip()
		end
		local ok, result, why = pcall(equipRemote.InvokeServer, equipRemote, not isCarried and selectedSet or nil, set.kind)
		busy = false
		if not ok then
			message.Text = "Couldn't reach the server"
			UiSfx.Play("denied")
		elseif not result then
			message.Text = why or "Couldn't do that"
			UiSfx.Play("denied")
		else
			message.Text = ""
			if not isCarried then
				UiSfx.Play("equip")
			end
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
		-- every material is listed; the ones you hold none of are dimmed placeholders
		local amount = player:GetAttribute(DropConfig.Attribute(key)) or 0
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
			TextTransparency = amount > 0 and 0 or 0.6,
			Size = UDim2.new(1, -40, 1, 0),
		})
		label(row, {
			Text = tostring(amount),
			Font = Enum.Font.Highway,
			TextSize = 12,
			TextColor3 = amount > 0 and TEXT or MUTED,
			TextTransparency = amount > 0 and 0 or 0.4,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 1, 0),
		})
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
	-- the ITEMS and TALISMAN tabs select one of theirs (the first) when what's selected isn't
	if tab == "item" or tab == "talisman" then
		local current = selected and findEntry(list, selected)
		if not (current and (current.category or current.kind) == tab) then
			for _, entry in ipairs(list) do
				if (entry.category or entry.kind) == tab then
					selected = entry.key
					pending = nil
					break
				end
			end
		end
	end

	clear(slotList)
	for i, slot in ipairs(SLOTS) do
		makeSlot(slot, i)
	end
	makeTalismanSlots()
	showMaterials()

	for kind, button in pairs(tabButtons) do
		local active = kind == tab
		button.BackgroundTransparency = active and 0 or 1
		button.TextColor3 = active and BACKGROUND or TEXT
	end
	clear(grid)
	local count = 0
	-- a section is a header (ALL only) and a grid of cards under it
	local sectionOrder = 0
	local function newSection(title)
		sectionOrder += 1
		local section = make("Frame", { Parent = grid, LayoutOrder = sectionOrder, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIListLayout", { Parent = section, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
		if title then
			label(section, { Text = title, Font = Enum.Font.Highway, TextSize = 11, TextColor3 = MUTED, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 14) })
		end
		local cards = make("Frame", { Parent = section, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIGridLayout", { Parent = cards, CellSize = UDim2.fromOffset(CARD_SIZE, CARD_SIZE), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		-- the cells start just inside, so selected cards' thick outlines show
		make("UIPadding", { Parent = cards, PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3) })
		return cards
	end
	if tab == "all" then
		for _, group in ipairs(SECTIONS) do
			local members = {}
			for _, entry in ipairs(list) do
				if (entry.category or entry.kind) == group.kind then
					table.insert(members, entry)
				end
			end
			if #members > 0 then
				cardParent = newSection(group.title)
				for i, entry in ipairs(members) do
					count += 1
					makeCard(entry, i)
				end
			end
		end
	else
		cardParent = newSection(nil)
		for _, entry in ipairs(list) do
			if (entry.category or entry.kind) == tab then
				count += 1
				makeCard(entry, count)
			end
		end
	end
	emptyLabel.Visible = count == 0
	warning.Visible = #allBriefcases() > 0

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
hotbarButton.Activated:Connect(function()
	if hotbarAction then
		hotbarAction()
	end
end)
for _, button in ipairs({ equipButton, altButton, hotbarButton }) do
	button.MouseButton1Down:Connect(function()
		for _, text in ipairs(PRESS_UNEQUIP) do
			if string.find(button.Text, text, 1, true) then
				playUnequip()
				return
			end
		end
	end)
end

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
	[ConsumableConfig.StorageAttribute] = true,
	[PowerConfig.BriefcaseStorageAttribute] = true,
	[TalismanConfig.OwnedAttribute] = true,
	[TalismanConfig.EquippedAttribute] = true,
	Level = true, -- opens talisman slots
}
for setName in pairs(SkillSetConfig.Sets) do
	watched[SkillSetConfig.MasteryAttribute(setName)] = true
end
for key in pairs(DropConfig.Materials) do
	watched[DropConfig.Attribute(key)] = true
end
player.AttributeChanged:Connect(function(name)
	if Hub.IsOpen("Backpack") and (watched[name] or string.find(name, "^ConsumableReadyAt_")) then
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
	-- a consumable's uses change on the Tool itself
	local function watchTool(tool)
		if tool:IsA("Tool") then
			tool.AttributeChanged:Connect(onToolsChanged)
		end
	end
	for _, child in ipairs(container:GetChildren()) do
		watchTool(child)
	end
	container.ChildAdded:Connect(function(child)
		watchTool(child)
		onToolsChanged()
	end)
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
