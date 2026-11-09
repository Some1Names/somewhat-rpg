-- The hub's Backpack tab (B, or the hub's nav). Three columns: on the left the LOADOUT (the held
-- power as a banner in its colour, the weapon and melee tiles, the talisman and gear slots), in
-- the middle every thing you own under four tabs (SETS, ITEMS, GEAR, MATERIALS), on the right a
-- banner of the selected thing, its info (a set's moves as key chips) and its buttons. Cards show
-- the thing's colour slashed across them, its tier or letter big, and your mastery as a bar.
-- Powers are the held one, the ones in storage, the lifetime ones and the briefcases you carry
-- (cards tagged HELD, STORED, LIFETIME, or in ITEMS); their buttons (USE, STORE, SWAP, TAKE OUT,
-- SWITCH) go through the PowerAction remote (Powers), and one that would lose a power asks CONFIRM
-- first. Weapons come from the OwnedSets attribute the server keeps; equipping goes through the
-- EquipSet remote, which checks ownership (see Loadout). The ITEMS tab also lists consumables: the
-- Tools equipped on the hotbar and the stacks stored in the Backpack (the saved ConsumableStorage
-- attribute); USE, STORE and EQUIP go through the ConsumableAction remote (Consumables). Power
-- briefcases are items too: equipped on the hotbar or stored in the Backpack (the
-- BriefcaseStorage attribute), with the power buttons plus EQUIP / UNEQUIP (the PowerAction
-- remote). EQUIP asks which free hotbar slot (4 to 9) to use.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BuildRules = require(ReplicatedStorage:WaitForChild("BuildRules"))
local ConsumableConfig = require(ReplicatedStorage:WaitForChild("ConsumableConfig"))
local HotbarRules = require(ReplicatedStorage:WaitForChild("HotbarRules"))
local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local HubRules = require(ReplicatedStorage:WaitForChild("HubRules"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local CraftConfig = require(ReplicatedStorage:WaitForChild("CraftConfig"))
local GearConfig = require(ReplicatedStorage:WaitForChild("GearConfig"))
local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
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
local gearRemote = ReplicatedStorage:WaitForChild(GearConfig.Remote)
local equipRemote = ReplicatedStorage:WaitForChild("EquipSet")
local itemRemote = ReplicatedStorage:WaitForChild("ConsumableAction")
local powerAction = ReplicatedStorage:WaitForChild("PowerAction")

local player = Players.LocalPlayer

local PANEL_SIZE = Vector2.new(1000, 460)
local COLUMN_PADDING = 10
local GAP = 12 -- between the columns
local LEFT_WIDTH = 260
local RIGHT_WIDTH = 320
local HEADING_HEIGHT = 24 -- a column's title row
local TAB_HEIGHT = 26 -- the tabs over the grid
local CARD_WIDTH = 108
local CARD_HEIGHT = 128
local CARD_GAP = 10
local HERO_HEIGHT = 156 -- the held power's banner at the top of the LOADOUT column
local TILE_HEIGHT = 64 -- the weapon and melee tiles under it
local BOX_HEIGHT = 52 -- a talisman or gear box under those
local BOX_GAP = 8
local BUTTON_HEIGHT = 34
local BACKGROUND = Hub.Theme.Panel -- cards, and the text on ink buttons
local SELECTED_BACKGROUND = Color3.fromRGB(58, 58, 66)
local DARK = Hub.Theme.Nav -- behind the colour of a banner
local TEXT = Hub.Theme.Ink
local MUTED = Hub.Theme.Muted
local DANGER = Color3.fromRGB(226, 75, 74)
local TITLE_FONT = Hub.Theme.TitleFont
local TIER_ORDER = { S = 1, A = 2, B = 3, C = 4 }
-- the tiles under the power banner, with the player attribute Loadout keeps each in
local SLOTS = {
	{ kind = "weapon", title = "WEAPON", attribute = "WeaponSet" },
	{ kind = "melee", title = "MELEE", attribute = "MeleeSet" },
}
-- the tabs over the grid, each a list of sections (a header, when there's more than one, and its cards)
local TABS = {
	{
		id = "sets",
		title = "SETS",
		sections = { { kind = "power", title = "POWERS" }, { kind = "weapon", title = "WEAPONS" }, { kind = "melee", title = "MELEE" } },
	},
	{ id = "items", title = "ITEMS", sections = { { kind = "item" } } },
	{ id = "gear", title = "GEAR", sections = { { kind = "gear", title = "GEAR" }, { kind = "talisman", title = "TALISMANS" } } },
	{ id = "materials", title = "MATERIALS", sections = { { kind = "material" } } },
}
-- the tab each kind of card is in (a briefcase's category is "item")
local KIND_TAB = { power = "sets", weapon = "sets", melee = "sets", item = "items", gear = "gear", talisman = "gear", material = "materials" }
-- the selected thing's banner at the top of the INFO column, the info under it
local PREVIEW_HEIGHT = 220 -- the preview is a square this big
local PREVIEW_TURN = 0.6 -- radians a second a model in it turns (as in the shops)

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

-- a band of `color` over the bottom of `parent`, fading in smoothly from clear going down (`from` is
-- about where it starts, 0 to 1 down): the banners', tiles' and cards' graphic
local function slash(parent, color, from, transparency, zIndex)
	local band = make("Frame", {
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex or 1,
	})
	-- the bottom third, eased (smoothstep) so it blurs in with no visible edge. Only the
	-- transparency is graded: callers recolour the band with BackgroundColor3
	local strongest = math.max(transparency - 0.3, 0.12)
	local keypoints = { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(2 / 3, 1) }
	for step = 1, 10 do
		local t = step / 10
		local eased = t * t * (3 - 2 * t)
		table.insert(keypoints, NumberSequenceKeypoint.new(2 / 3 + t / 3, 1 - (1 - strongest) * eased))
	end
	make("UIGradient", { Parent = band, Rotation = 90, Transparency = NumberSequence.new(keypoints) })
	return band
end

-- a bar: a dark track with `fraction` of it filled in `color` (mastery)
local function progressBar(parent, position, size, fraction, color)
	local track = make("Frame", {
		Parent = parent,
		Position = position,
		Size = size,
		BackgroundColor3 = Hub.Theme.BarBack,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	})
	make("Frame", { Parent = track, Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0 })
	return track
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

local leftColumn = column(UDim2.new(), UDim2.new(0, LEFT_WIDTH, 1, 0), Vector2.zero, "LOADOUT")
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

-- left: the held power's banner, the weapon and melee tiles, then the talismans and the gear you wear
local loadout = make("Frame", {
	Parent = leftColumn,
	Position = UDim2.fromOffset(0, HEADING_HEIGHT),
	Size = UDim2.new(1, 0, 1, -HEADING_HEIGHT),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = loadout, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, BOX_GAP) })
local function loadoutRow(order, height)
	local row = make("Frame", { Parent = loadout, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 })
	make("UIListLayout", {
		Parent = row,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, BOX_GAP),
	})
	return row
end
-- a row's caption ("TALISMANS 1/3"), set on each refresh
local function loadoutHeading(order)
	return label(loadout, {
		Text = "",
		RichText = true,
		TextSize = 11,
		TextColor3 = MUTED,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 18),
	})
end
local heroRow = loadoutRow(1, HERO_HEIGHT)
local tileRow = loadoutRow(2, TILE_HEIGHT)
local talismanHeading = loadoutHeading(3)
local talismanList = loadoutRow(4, BOX_HEIGHT)
local gearHeading = loadoutHeading(5)
local gearList = loadoutRow(6, BOX_HEIGHT)

-- middle: the tabs (the one showing underlined), then the grid of owned things
local tabRow = make("Frame", {
	Parent = middleColumn,
	Position = UDim2.fromOffset(0, HEADING_HEIGHT - 4),
	Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = tabRow,
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 18),
})
make("Frame", {
	Parent = middleColumn,
	Position = UDim2.fromOffset(0, HEADING_HEIGHT - 4 + TAB_HEIGHT),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = TEXT,
	BackgroundTransparency = 0.85,
	BorderSizePixel = 0,
})
local GRID_TOP = HEADING_HEIGHT + TAB_HEIGHT + 8 -- under the tabs
local grid = scroller(middleColumn, {
	Position = UDim2.fromOffset(0, GRID_TOP),
	Size = UDim2.new(1, 0, 1, -(GRID_TOP + 18)), -- room under it for the briefcase warning
})
-- the grid is a list of sections (a header when the tab has more than one, and a grid of cards each)
make("UIListLayout", { Parent = grid, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) })
local cardParent = grid -- where makeCard puts the card it makes
local emptyLabel = label(middleColumn, {
	Text = "Nothing here yet",
	TextSize = 12,
	TextColor3 = MUTED,
	Position = UDim2.fromOffset(0, GRID_TOP),
	Size = UDim2.new(1, 0, 0, 20),
	Visible = false,
})

-- right: the selected thing's banner at the top, its info under it (scrolling when it's long), its
-- buttons at the bottom
local DETAILS_TOP = HEADING_HEIGHT + PREVIEW_HEIGHT + 28
local details = scroller(rightColumn, {
	Position = UDim2.fromOffset(0, DETAILS_TOP),
	Size = UDim2.new(1, 0, 1, -DETAILS_TOP), -- placeDetails stops it above the buttons
})
make("UIListLayout", { Parent = details, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
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
-- the info reaches down to the buttons showing (they stack up from the bottom), leaving room for
-- the message line over them only while it has something to say
local function placeDetails()
	local reserve = 0 -- px up from the bottom
	for i, button in ipairs({ equipButton, altButton, hotbarButton }) do
		if button.Visible then
			reserve = i * (BUTTON_HEIGHT + 6)
		end
	end
	message.Position = UDim2.new(0, 0, 1, -(reserve + 4))
	if message.Text ~= "" then
		reserve += 34
	end
	details.Size = UDim2.new(1, 0, 1, -(DETAILS_TOP + reserve + 10))
end
for _, button in ipairs({ equipButton, altButton, hotbarButton }) do
	button:GetPropertyChangedSignal("Visible"):Connect(placeDetails)
end
message:GetPropertyChangedSignal("Text"):Connect(placeDetails)
placeDetails()

-- at the top of the column, still while the info under it scrolls: the selected thing's banner, its
-- colour slashed across a dark box, with its picture, its model turning, or its letter big on the colour
local preview = make("Frame", {
	Parent = rightColumn,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, HEADING_HEIGHT),
	Size = UDim2.fromOffset(PREVIEW_HEIGHT, PREVIEW_HEIGHT), -- a square, in the middle of the column
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 2,
})
-- the preview is the shop's box: a faint wash of the item's colour rising from the bottom and
-- corner brackets in it (both recoloured with the selection)
local previewBand = make("Frame", { Parent = preview, Size = UDim2.fromScale(1, 1), BackgroundColor3 = MUTED, BorderSizePixel = 0, ZIndex = 2 })
make("UIGradient", {
	Parent = previewBand,
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.6, 0.88),
		NumberSequenceKeypoint.new(1, 0.72),
	}),
})
local previewBrackets = {}
for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
	for _, size in ipairs({ Vector2.new(16, 2), Vector2.new(2, 16) }) do
		table.insert(previewBrackets, make("Frame", {
			Parent = preview,
			AnchorPoint = Vector2.new(corner[1], corner[2]),
			Position = UDim2.fromScale(corner[1], corner[2]),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundColor3 = MUTED,
			BorderSizePixel = 0,
			ZIndex = 4,
		}))
	end
end
local previewPop = make("UIScale", { Parent = preview })
local previewKey -- the card it shows, so a refresh leaves it be
local previewContent -- what's in the box: an ImageLabel, a ViewportFrame or the letter
local previewModel -- the model turning in it, if any
local previewAngle = 0

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
local tab = "sets"
local busy = false
local pending -- { action, set }: a power action waiting for CONFIRM
local salvageArmed -- the gear piece key whose SALVAGE is waiting for CONFIRM
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
	for _, key in ipairs(TalismanConfig.Owned(player:GetAttribute(TalismanConfig.OwnedAttribute))) do
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
		if set and (set.kind == "weapon" or set.kind == "melee") then
			table.insert(list, { setName = setName, key = setName, kind = set.kind, held = carried(set.kind) == setName, rank = 5 })
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
	-- materials you hold
	for index, key in ipairs(DropConfig.Sorted()) do
		local amount = player:GetAttribute(DropConfig.Attribute(key)) or 0
		if amount > 0 then
			table.insert(list, {
				kind = "material",
				material = DropConfig.Materials[key],
				materialKey = key,
				amount = amount,
				key = "material:" .. key,
				rank = 9,
				order = index,
			})
		end
	end
	-- gear: the worn pieces, then the bag's, best first
	local function addGear(piece, equipped)
		table.insert(list, {
			kind = "gear",
			piece = piece,
			equipped = equipped,
			key = "gear:" .. piece.id,
			rank = equipped and 10 or 11,
			order = -(GearConfig.RarityOrder(piece.rarity) * 1000 + piece.level),
		})
	end
	local wornGear = GearConfig.ParseWorn(player:GetAttribute(GearConfig.WornAttribute))
	for _, slot in ipairs(GearConfig.Slots) do
		if wornGear[slot] then
			addGear(wornGear[slot], true)
		end
	end
	for _, piece in ipairs(GearConfig.ParseBag(player:GetAttribute(GearConfig.BagAttribute))) do
		addGear(piece, false)
	end
	-- held first, then stored, lifetime, briefcases, weapons, items, materials, gear; best tier, then name
	table.sort(list, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		if a.order then
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
	elseif entry.kind == "weapon" or entry.kind == "melee" then
		return entry.held and "EQUIPPED" or nil
	end
	return entry.held and "HELD" or entry.stored and "STORED" or entry.lifetime and "LIFETIME" or nil
end

local function stateText(entry)
	if entry.briefcase then
		return entry.equipped and "Briefcase · equipped" or "Briefcase · stored"
	elseif entry.kind == "weapon" or entry.kind == "melee" then
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

-- selects a card; `kind` (from the LOADOUT column) also shows that kind's tab
local function selectKey(key, kind)
	if key ~= selected then
		UiSfx.Play("itemSelect")
	end
	selected = key
	tab = kind and KIND_TAB[kind] or tab
	pending = nil
	salvageArmed = nil
	pickingSlot = false
	message.Text = ""
	refresh()
end

-- consumables: orange when limited, cyan for a lifetime item
local function itemColor(item)
	return item.kind == "lifetime" and Color3.fromRGB(60, 224, 230) or Color3.fromRGB(255, 154, 60)
end

local function talismanColor(talisman)
	return Color3.fromRGB(table.unpack(talisman.color))
end

-- a gear piece's rarity colour
local function gearColor(piece)
	return Color3.fromRGB(table.unpack(GearConfig.Rarity(piece.rarity).color))
end

-- "Epic Rough Helm"
local function gearName(piece)
	local base = GearConfig.Base(piece.base)
	return string.format("%s %s", GearConfig.Rarity(piece.rarity).name, base and base.name or piece.base)
end

-- "Needs Strength 10" when the player is below the set's stat requirement
local function needsText(setName)
	local requires = SkillSetConfig.Sets[setName].requires
	local stats = {}
	for key in pairs(requires or {}) do
		stats[key] = player:GetAttribute(key) or 0
	end
	local ok, missing = BuildRules.Meets(stats, requires)
	return not ok and string.format("Needs %s %d", missing, requires[missing]) or nil
end

-- what a card shows, for any kind of thing: its colour, the big glyph (and its colour), its name,
-- a tag (HELD, WORN...), a corner note (uses, amount, level), a bar along the bottom (mastery,
-- 0 to 1) and whether the player is below its stat requirement
local function cardLook(entry)
	if entry.kind == "item" then
		local item = entry.item
		return {
			color = itemColor(item),
			glyph = string.sub(item.name, 1, 1),
			name = item.name,
			tag = entry.equipped and "EQUIPPED" or nil,
			corner = item.kind == "limited" and string.format("%d/%d", entry.uses or 0, item.maxUses) or "LIFE",
		}
	elseif entry.kind == "talisman" then
		local talisman = entry.talisman
		return {
			color = talismanColor(talisman),
			glyph = string.sub(talisman.name, 1, 1),
			name = talisman.name,
			tag = entry.equipped and "WORN" or nil,
		}
	elseif entry.kind == "material" then
		local info = entry.material
		return {
			color = DropConfig.TierColor(info.tier),
			glyph = string.sub(info.display, 1, 1),
			name = info.display,
			corner = "x" .. entry.amount,
		}
	elseif entry.kind == "gear" then
		local piece = entry.piece
		local base = GearConfig.Base(piece.base)
		return {
			color = gearColor(piece),
			glyph = string.sub(base and base.name or piece.base, 1, 1),
			name = gearName(piece),
			tag = entry.equipped and "WORN" or nil,
			corner = "LV " .. piece.level,
		}
	end
	local set = SkillSetConfig.Sets[entry.setName]
	return {
		color = set.color or tierColor(set),
		glyph = set.tier or string.sub(set.tool, 1, 1),
		glyphColor = tierColor(set),
		name = set.tool,
		tag = tagText(entry),
		corner = entry.briefcase and "CASE" or nil,
		bar = mastery(entry.setName) / SkillSetConfig.MaxMastery,
		locked = needsText(entry.setName) ~= nil,
	}
end

-- a card in the grid: a dark tile with its colour slashed across it, the big glyph, the name under
-- it, a tag chip, a corner note and a bar along the bottom
local function makeCard(entry, index)
	local look = cardLook(entry)
	local isSelected = entry.key == selected
	local card = make("TextButton", {
		Parent = cardParent,
		LayoutOrder = index,
		BackgroundColor3 = isSelected and SELECTED_BACKGROUND or BACKGROUND,
		BackgroundTransparency = 0.15,
		ClipsDescendants = true,
		Text = "",
	})
	outline(card, isSelected and 0 or 0.75, isSelected and onPaper(look.color) or TEXT, isSelected and 2 or 1)
	slash(card, look.color, 0.55, isSelected and 0.5 or 0.72)
	label(card, {
		Text = look.glyph,
		Font = TITLE_FONT,
		TextSize = 54,
		TextColor3 = onPaper(look.glyphColor or look.color),
		TextTransparency = look.locked and 0.6 or 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(70, 60),
	})
	if look.tag then
		label(card, {
			Text = look.tag,
			TextSize = 9,
			TextColor3 = BACKGROUND,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = TEXT,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(56, 14),
		})
	end
	if look.locked then
		label(card, {
			Text = "LOCKED",
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = DANGER,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(44, 14),
		})
	elseif look.corner then
		label(card, {
			Text = look.corner,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 5),
			Size = UDim2.fromOffset(50, 16),
		})
	end
	label(card, {
		Text = look.name,
		Font = Enum.Font.Highway,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Position = UDim2.new(0, 8, 1, -44),
		Size = UDim2.new(1, -16, 0, 30),
	})
	progressBar(card, UDim2.new(0, 8, 1, -9), UDim2.new(1, -16, 0, 3), look.bar or 1, look.color)
	card.Activated:Connect(function()
		selectKey(entry.key)
	end)
end

-- the LOADOUT column's banner: the held power in its colour, its tier letter huge in the colour,
-- its name, and its mastery as a bar (or that no power is held)
local function makeHero()
	clear(heroRow)
	local setName = player:GetAttribute("PowerSet")
	local set = setName and SkillSetConfig.Sets[setName]
	local hero = make(set and "TextButton" or "Frame", {
		Parent = heroRow,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	if not set then
		outline(hero, 0.8)
		label(hero, { Text = "NO POWER", Font = TITLE_FONT, TextSize = 26, TextColor3 = MUTED, Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 0, 30) })
		label(hero, {
			Text = "Open a briefcase, or switch to a lifetime power.",
			TextSize = 11,
			TextColor3 = MUTED,
			TextWrapped = true,
			Position = UDim2.fromOffset(14, 48),
			Size = UDim2.new(1, -28, 0, 30),
		})
		return
	end
	hero.Text = ""
	hero.AutoButtonColor = false
	local color = set.color or tierColor(set)
	local isSelected = setName == selected
	outline(hero, isSelected and 0 or 0.6, onPaper(color), isSelected and 2 or 1)
	slash(hero, color, 0.5, 0.35)
	-- the tier letter, bigger than text goes (a UIScale), dark and cut by the banner's edge
	local letter = label(hero, {
		Text = set.tier or string.sub(set.tool, 1, 1),
		Font = TITLE_FONT,
		TextSize = 100,
		TextColor3 = DARK,
		TextTransparency = 0.45,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -50, 0.5, 8),
		Size = UDim2.fromOffset(100, 110),
	})
	make("UIScale", { Parent = letter, Scale = 1.7 })
	label(hero, { Text = "POWER", TextSize = 10, TextColor3 = MUTED, Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(120, 12) })
	label(hero, {
		Text = string.format("%s-TIER", set.tier or "?"),
		Font = TITLE_FONT,
		TextSize = 14,
		TextColor3 = onPaper(tierColor(set)),
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.fromOffset(120, 18),
	})
	label(hero, {
		Text = string.upper(set.tool),
		Font = TITLE_FONT,
		TextSize = 26,
		TextWrapped = true,
		TextStrokeTransparency = 0.7,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 50),
		Size = UDim2.new(0.66, 0, 0, 64),
	})
	label(hero, {
		Text = masteryText(setName),
		TextSize = 10,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -18),
		Size = UDim2.fromOffset(120, 12),
	})
	progressBar(hero, UDim2.new(0, 14, 1, -12), UDim2.new(0.55, 0, 0, 4), mastery(setName) / SkillSetConfig.MaxMastery, color)
	hero.Activated:Connect(function()
		selectKey(setName, "power")
	end)
end

-- a weapon or melee tile under the banner: what's carried in that slot, or that it's empty
local TILE_WIDTH = (LEFT_WIDTH - 2 * COLUMN_PADDING - BOX_GAP) / 2
local function makeTile(slot, index)
	local setName = player:GetAttribute(slot.attribute)
	local set = setName and SkillSetConfig.Sets[setName]
	local isSelected = set ~= nil and setName == selected
	local tile = make(set and "TextButton" or "Frame", {
		Parent = tileRow,
		LayoutOrder = index,
		Size = UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT),
		BackgroundColor3 = isSelected and SELECTED_BACKGROUND or BACKGROUND,
		BackgroundTransparency = set and 0.15 or 0.6,
		ClipsDescendants = true,
	})
	label(tile, { Text = slot.title, TextSize = 9, TextColor3 = MUTED, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 10) })
	if not set then
		outline(tile, 0.85)
		label(tile, { Text = "Empty", TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(8, 24), Size = UDim2.new(1, -16, 0, 16) })
		return
	end
	tile.Text = ""
	local color = set.color or tierColor(set)
	outline(tile, isSelected and 0 or 0.75, isSelected and onPaper(color) or TEXT, isSelected and 2 or 1)
	slash(tile, color, 0.62, 0.7)
	label(tile, {
		Text = set.tier or "",
		Font = TITLE_FONT,
		TextSize = 34,
		TextColor3 = onPaper(tierColor(set)),
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(30, 40),
	})
	label(tile, { Text = set.tool, Font = TITLE_FONT, TextSize = 15, Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -44, 0, 20) })
	progressBar(tile, UDim2.new(0, 8, 1, -11), UDim2.new(1, -44, 0, 3), mastery(setName) / SkillSetConfig.MaxMastery, color)
	tile.Activated:Connect(function()
		selectKey(setName, set.kind)
	end)
end

-- a small box in the LOADOUT column (a talisman or gear slot): the worn thing's letter in its colour
-- and its name, or the slot's caption (EMPTY, the level that opens it) faint
local function makeBox(parent, index, width, color, glyph, name, caption, onClick, isSelected)
	local box = make(color and "TextButton" or "Frame", {
		Parent = parent,
		LayoutOrder = index,
		Size = UDim2.fromOffset(width, BOX_HEIGHT),
		BackgroundColor3 = isSelected and SELECTED_BACKGROUND or BACKGROUND,
		BackgroundTransparency = color and 0.15 or 0.6,
		ClipsDescendants = true,
	})
	if not color then
		outline(box, 0.85)
		label(box, { Text = caption, TextSize = 10, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
		return
	end
	box.Text = ""
	outline(box, isSelected and 0 or 0.75, isSelected and onPaper(color) or TEXT, isSelected and 2 or 1)
	slash(box, color, 0.6, 0.7)
	label(box, { Text = glyph, Font = TITLE_FONT, TextSize = 24, TextColor3 = onPaper(color), Position = UDim2.fromOffset(7, 2), Size = UDim2.fromOffset(24, 28) })
	label(box, { Text = name, TextSize = 10, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 7, 1, -5), Size = UDim2.new(1, -14, 0, 12) })
	box.Activated:Connect(onClick)
end

-- the talisman slots, three boxes in a row: a worn one (click to select it), an empty one, or a
-- locked one with its level
local function makeTalismanSlots()
	clear(talismanList)
	local worn = TalismanConfig.Parse(player:GetAttribute(TalismanConfig.EquippedAttribute))
	local open = TalismanConfig.Slots(player:GetAttribute("Level") or 0)
	talismanHeading.Text = string.format('TALISMANS  <font color="#ececee">%d/%d</font>', #worn, open)
	local width = (LEFT_WIDTH - 2 * COLUMN_PADDING - 2 * BOX_GAP) / 3
	for i, at in ipairs(TalismanConfig.SlotLevels) do
		local key = worn[i]
		local talisman = key and TalismanConfig.Get(key)
		makeBox(
			talismanList,
			i,
			width,
			talisman and talismanColor(talisman),
			talisman and string.sub(talisman.name, 1, 1),
			talisman and talisman.name,
			i > open and string.format("LV %d", at) or "EMPTY",
			talisman and function()
				selectKey("talisman:" .. key, "talisman")
			end,
			talisman ~= nil and "talisman:" .. key == selected
		)
	end
end

-- the gear slots, Head and Body: a worn piece (click to select it) or an empty slot
local function makeGearSlots()
	clear(gearList)
	local worn = GearConfig.ParseWorn(player:GetAttribute(GearConfig.WornAttribute))
	local count = 0
	for _, slotName in ipairs(GearConfig.Slots) do
		if worn[slotName] then
			count += 1
		end
	end
	gearHeading.Text = string.format('GEAR  <font color="#ececee">%d/%d</font>', count, #GearConfig.Slots)
	local width = (LEFT_WIDTH - 2 * COLUMN_PADDING - (#GearConfig.Slots - 1) * BOX_GAP) / #GearConfig.Slots
	for i, slotName in ipairs(GearConfig.Slots) do
		local piece = worn[slotName]
		local base = piece and GearConfig.Base(piece.base)
		local baseName = piece and (base and base.name or piece.base)
		makeBox(
			gearList,
			i,
			width,
			piece and gearColor(piece),
			baseName and string.sub(baseName, 1, 1),
			baseName,
			string.upper(slotName),
			piece and function()
				selectKey("gear:" .. piece.id, "gear")
			end,
			piece ~= nil and "gear:" .. piece.id == selected
		)
	end
end

-- the tabs: big titles with how many cards each has, the one showing in ink and underlined in the accent
local tabButtons = {}
for i, entry in ipairs(TABS) do
	local button = make("TextButton", {
		Parent = tabRow,
		LayoutOrder = i,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = TITLE_FONT,
		RichText = true,
		Text = entry.title,
		TextSize = 16,
		TextColor3 = MUTED,
	})
	local underline = make("Frame", {
		Parent = button,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = TEXT,
		BorderSizePixel = 0,
		Visible = false,
	})
	button:SetAttribute("SectionSelect", true)
	button.Activated:Connect(function()
		tab = entry.id
		refresh()
	end)
	tabButtons[entry.id] = { button = button, underline = underline, title = entry.title }
end
Hub.OnAccent(function(accent)
	for _, tabButton in pairs(tabButtons) do
		tabButton.underline.BackgroundColor3 = accent
	end
end)

-- one line of the info: a caption (or key), then the value and a note
local detailOrder = 0
local function detailRow(key, name, note, dim)
	detailOrder += 1
	local row = make("Frame", {
		Parent = details,
		LayoutOrder = detailOrder,
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	label(row, {
		Text = key,
		TextSize = 10,
		TextColor3 = MUTED,
		TextTransparency = dim and 0.4 or 0,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(64, 12),
	})
	label(row, {
		Text = note and string.format('%s  <font color="#a5a5b4" size="11">%s</font>', name, note) or name,
		RichText = true,
		TextSize = 13,
		TextColor3 = dim and MUTED or TEXT,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(70, 0),
		Size = UDim2.new(1, -70, 0, 18),
	})
end

-- the info's title: the thing's name big, a line about it under it in its colour
local function detailTitle(name, subtitle, color)
	detailOrder += 1
	local title = make("Frame", { Parent = details, LayoutOrder = detailOrder, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 })
	label(title, { Text = string.upper(name), Font = TITLE_FONT, TextSize = 24, Size = UDim2.new(1, 0, 0, 28) })
	label(title, { Text = subtitle, TextSize = 11, TextColor3 = color, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 14) })
end

-- a set's moves as a row of key chips; the one hovered (or clicked) names its move under the row
local MOVE_CHIP = Vector2.new(42, 30)
local function moveChips(moves)
	detailOrder += 1
	local frame = make("Frame", {
		Parent = details,
		LayoutOrder = detailOrder,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	make("UIListLayout", { Parent = frame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })
	label(frame, { Text = "MOVES", TextSize = 10, TextColor3 = MUTED, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 12) })
	local chips = make("Frame", {
		Parent = frame,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	make("UIGridLayout", {
		Parent = chips,
		CellSize = UDim2.fromOffset(MOVE_CHIP.X, MOVE_CHIP.Y),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	-- (inset a pixel, so the chips' outlines show)
	make("UIPadding", { Parent = chips, PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1) })
	local line = label(frame, {
		Text = "",
		RichText = true,
		TextSize = 13,
		TextWrapped = true,
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 18),
	})
	local buttons = {}
	local function show(index)
		local move = moves[index]
		line.Text = move.note and string.format('%s  <font color="#a5a5b4" size="11">%s</font>', move.name, move.note) or move.name
		line.TextColor3 = move.locked and MUTED or TEXT
		for i, chip in ipairs(buttons) do
			chip.BackgroundTransparency = i == index and 0 or 1
			chip.TextColor3 = i == index and BACKGROUND or (moves[i].locked and MUTED or TEXT)
		end
	end
	for i, move in ipairs(moves) do
		local chip = make("TextButton", {
			Parent = chips,
			LayoutOrder = i,
			BackgroundColor3 = TEXT,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Font = Enum.Font.Highway,
			Text = move.key,
			TextSize = 12,
		})
		outline(chip, move.locked and 0.85 or 0.5)
		chip.MouseEnter:Connect(function()
			show(i)
		end)
		chip.Activated:Connect(function()
			show(i)
		end)
		table.insert(buttons, chip)
	end
	show(1)
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
	-- below the set's stat requirement, a power can't be held: say what's missing instead
	local needs = primaryAction and (entry.briefcase or entry.stored or (entry.lifetime and not entry.held)) and needsText(setName)
	if needs then
		message.Text = needs
		primaryText, primaryAction = nil, nil
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
	detailTitle(item.name, string.format("%s  ·  %s", item.kind == "limited" and "Limited use" or "Lifetime", entry.equipped and "Equipped on the hotbar" or "Stored in the Backpack"), color)
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
	detailTitle(talisman.name, entry.equipped and "Talisman  ·  Worn" or "Talisman  ·  In your collection", color)
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

-- asks the server to wear, take off or salvage a gear piece (`target` is a piece id, or a slot to take off)
local function runGear(action, target)
	if busy then
		return
	end
	busy = true
	if action == "unequip" then
		playUnequip()
	end
	local ok, result, why = pcall(gearRemote.InvokeServer, gearRemote, action, target)
	busy = false
	salvageArmed = nil
	if not ok then
		message.Text = "Couldn't reach the server"
		UiSfx.Play("denied")
	elseif not result then
		message.Text = why or "Couldn't do that"
		UiSfx.Play("denied")
	else
		message.Text = ""
		if action == "equip" then
			UiSfx.Play("equip")
		end
	end
	refresh()
end

-- the info for a gear piece: its stats, and WEAR / TAKE OFF and SALVAGE (asks CONFIRM first)
local function gearDetails(entry)
	local piece = entry.piece
	local color = onPaper(gearColor(piece))
	detailTitle(gearName(piece), string.format("%s  ·  Level %d  ·  %s", piece.slot, piece.level, entry.equipped and "Worn" or "In your bag"), color)
	for index, affix in ipairs(piece.affixes) do
		detailRow(index == 1 and "BASE" or "AFFIX", GearConfig.AffixLine(affix))
	end
	local level = math.max(player:GetAttribute("Level") or 0, 1) -- GearConfig.Equip counts a level 0 character as level 1
	if piece.level > level then
		detailRow("LEVEL", string.format("Needs level %d", piece.level), nil, true)
	end
	primaryAction = function()
		if entry.equipped then
			runGear("unequip", piece.slot)
		else
			runGear("equip", piece.id)
		end
	end
	setButton(equipButton, equipStroke, entry.equipped and "TAKE OFF" or "WEAR", entry.equipped)
	if not entry.equipped then
		altAction = function()
			if salvageArmed == entry.key then
				runGear("salvage", piece.id)
			else
				salvageArmed = entry.key
				refresh()
			end
		end
		setButton(altButton, altStroke, salvageArmed == entry.key and "CONFIRM" or "SALVAGE", true)
	end
end

-- where a material is spent: Reforge's steps and the printer's recipes
local function usedIn(key)
	local uses = {}
	local levels = {}
	for level, cost in ipairs(ReforgeConfig.LevelCosts) do
		if cost.material == key then
			table.insert(levels, "+" .. level)
		end
	end
	if #levels > 0 then
		table.insert(uses, "Reforge levels " .. table.concat(levels, " "))
	end
	for _, cost in ipairs(ReforgeConfig.ChangeCosts) do
		if cost.material == key then
			table.insert(uses, "Reforge: change an affinity")
			break
		end
	end
	for _, cost in ipairs(ReforgeConfig.AwakenCosts) do
		if cost.material == key then
			table.insert(uses, "Reforge: awaken a power")
			break
		end
	end
	for _, recipe in ipairs(CraftConfig.Recipes) do
		for _, need in ipairs(recipe.materials) do
			if need.material == key then
				table.insert(uses, "Print: " .. recipe.name)
				break
			end
		end
	end
	return uses
end

-- the info for a material: how many you hold and where it is spent (no buttons)
local function materialDetails(entry)
	local info = entry.material
	local color = onPaper(DropConfig.TierColor(info.tier))
	detailTitle(info.display, "Material  ·  " .. info.tier, color)
	detailRow("HELD", tostring(entry.amount), string.format("of %d", DropConfig.MaxPerMaterial))
	local uses = usedIn(entry.materialKey)
	if #uses == 0 then
		detailRow("USED IN", "Nothing yet", nil, true)
	end
	for _, use in ipairs(uses) do
		detailRow("USED IN", use)
	end
end

-- the picture the shops show for a set: a power's `image`, or the model of a weapon's tool
-- (ReplicatedStorage.ShopPreviews, by the shop item's id); nil when there's neither
local function previewSource(setName)
	local folder = ReplicatedStorage:FindFirstChild("ShopPreviews")
	for _, item in ipairs(ShopConfig.Items) do
		if item.set == setName then
			if item.image then
				return item.image
			end
			local model = folder and folder:FindFirstChild(item.id)
			if model then
				return model
			end
		end
	end
	return nil
end

-- puts the selected card's thing in the preview, popping in, when the selection changes: its
-- picture, its model turning, or its letter (a set's tier, else the first letter) big and faint
local function showPreview(entry)
	local key = entry and entry.key
	if key == previewKey then
		return
	end
	if previewContent then
		previewContent:Destroy()
		previewContent, previewModel = nil, nil
	end
	local set = entry and entry.setName and SkillSetConfig.Sets[entry.setName]
	local color, letter, letterColor
	if entry and entry.kind == "talisman" then
		color = talismanColor(entry.talisman)
		letter, letterColor = string.sub(entry.talisman.name, 1, 1), color
	elseif entry and entry.kind == "item" then
		color = itemColor(entry.item)
		letter, letterColor = string.sub(entry.item.name, 1, 1), color
	elseif entry and entry.kind == "material" then
		color = DropConfig.TierColor(entry.material.tier)
		letter, letterColor = string.sub(entry.material.display, 1, 1), color
	elseif entry and entry.kind == "gear" then
		color = gearColor(entry.piece)
		letter, letterColor = string.sub(gearName(entry.piece), 1, 1), color
	elseif set then
		color = set.color or tierColor(set)
		letter, letterColor = set.tier or string.sub(set.tool, 1, 1), tierColor(set)
	end
	previewKey = color and key
	details.CanvasPosition = Vector2.zero -- a new selection's info starts at its top
	previewBand.BackgroundColor3 = color or MUTED
	for _, bracket in ipairs(previewBrackets) do
		bracket.BackgroundColor3 = color and onPaper(color) or MUTED
	end
	if not color then
		return
	end
	local source = set and previewSource(entry.setName)
	if type(source) == "string" then
		previewContent = make("ImageLabel", {
			Parent = preview,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			BackgroundTransparency = 1,
			Image = source,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		})
	elseif source then
		local model = source:Clone()
		model.WorldPivot = model:GetBoundingBox()
		model:PivotTo(CFrame.new())
		local viewport = make("ViewportFrame", {
			Parent = preview,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(170, 170, 170),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -1, -1),
			ZIndex = 3,
		})
		local _, size = model:GetBoundingBox()
		local reach = size.Magnitude / 2
		local camera = make("Camera", { Parent = viewport, FieldOfView = 30 })
		camera.CFrame = CFrame.lookAt(Vector3.new(0, reach * 0.25, reach / math.tan(math.rad(15)) * 1.05), Vector3.zero)
		viewport.CurrentCamera = camera
		model.Parent = viewport
		previewContent, previewModel, previewAngle = viewport, model, 0
	else
		previewContent = label(preview, {
			Text = letter,
			Font = TITLE_FONT,
			TextSize = 100,
			TextColor3 = onPaper(letterColor),
			TextTransparency = 0.1,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(100, 110),
			ZIndex = 3,
		})
		-- bigger than text goes, and cut by the banner's bottom edge
		make("UIScale", { Parent = previewContent, Scale = 1.5 })
	end
	previewPop.Scale = 0.94
	TweenService:Create(previewPop, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
-- a model in the preview turns while the Backpack shows it
RunService.Heartbeat:Connect(function(dt)
	if previewModel and Hub.IsOpen("Backpack") then
		previewAngle += dt * PREVIEW_TURN
		previewModel:PivotTo(CFrame.Angles(0, previewAngle, 0))
	end
end)

local function showDetails(entry)
	clear(details)
	detailOrder = 0
	primaryAction, altAction, hotbarAction = nil, nil, nil
	setButton(equipButton, equipStroke, nil, false)
	setButton(altButton, altStroke, nil, true)
	setButton(hotbarButton, hotbarStroke, nil, true)
	showPreview(entry)
	if entry and entry.kind == "item" then
		itemDetails(entry)
		return
	elseif entry and entry.kind == "talisman" then
		talismanDetails(entry)
		return
	elseif entry and entry.kind == "material" then
		materialDetails(entry)
		return
	elseif entry and entry.kind == "gear" then
		gearDetails(entry)
		return
	end
	local set = entry and SkillSetConfig.Sets[entry.setName]
	if not set then
		label(details, { Text = "Pick something to see it here.", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 20) })
		return
	end
	local selectedSet = entry.setName
	local level = mastery(selectedSet)
	local color = set.color or tierColor(set)
	detailTitle(set.tool, string.format("%s-tier %s  ·  %s", set.tier or "?", set.kind, stateText(entry)), onPaper(tierColor(set)))
	-- mastery, as a bar under its number
	detailOrder += 1
	local masteryRow = make("Frame", { Parent = details, LayoutOrder = detailOrder, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 })
	label(masteryRow, { Text = masteryText(selectedSet), TextSize = 11, Size = UDim2.new(1, 0, 0, 12) })
	progressBar(masteryRow, UDim2.fromOffset(0, 17), UDim2.new(1, -4, 0, 4), level / SkillSetConfig.MaxMastery, color)
	-- a weapon below its stat requirement says so here (a power's message says it over its buttons)
	local needs = entry.kind ~= "power" and needsText(selectedSet)
	if needs then
		detailOrder += 1
		label(details, { Text = needs, TextSize = 12, TextColor3 = DANGER, LayoutOrder = detailOrder, Size = UDim2.new(1, 0, 0, 16) })
	end

	if pickingSlot and entry.briefcase and not entry.equipped then
		slotPicker(function(slot)
			runPower("equipBriefcase", selectedSet, false, slot)
		end)
	end
	-- the passive on its own line, then the moves as key chips; one that isn't unlocked yet is
	-- dimmed with its mastery, like a locked skill
	if set.passive then
		local at = set.passive.mastery
		local locked = at ~= nil and level < at
		detailRow("PASSIVE", set.passive.name, locked and ("Mastery " .. at) or nil, locked)
	end
	local moves = {}
	local function addMove(key, name, at, note)
		local locked = at ~= nil and level < at
		table.insert(moves, { key = key, name = name, note = locked and ("Mastery " .. at) or note, locked = locked })
	end
	if set.ranged then
		addMove(set.ranged.primary and "LMB" or "RNG", set.ranged.name)
	end
	if set.dash then
		addMove(Keybinds.Text("Dash"), set.dash.name, set.dash.mastery)
	end
	if set.overcharge then
		addMove(Keybinds.Text("Special"), set.overcharge.name, set.overcharge.mastery, "overcharge")
	end
	if set.flight then
		addMove(Keybinds.Text("Special"), "Flight", set.flight.mastery)
	end
	if set.undo then
		addMove(Keybinds.Text("Special"), set.undo.name, set.undo.mastery)
	end
	if set.gallery then
		addMove(Keybinds.Text("Gallery"), set.gallery.name, set.gallery.mastery)
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
			addMove(Keybinds.Text("Skill" .. key), name, skill.mastery, skill.overchargedOnly and "overcharge only" or nil)
		end
	end
	if #moves > 0 then
		moveChips(moves)
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

function refresh()
	local list = entries()
	-- keep the selection on something that's still there
	if selected and not findEntry(list, selected) then
		selected = nil
		pending = nil
	end
	selected = selected or heldPower() or (list[1] and list[1].key)
	-- a tab shows only its own cards: it selects its first one when what's selected is elsewhere
	local current = selected and findEntry(list, selected)
	if not (current and KIND_TAB[current.category or current.kind] == tab) then
		for _, entry in ipairs(list) do
			if KIND_TAB[entry.category or entry.kind] == tab then
				selected = entry.key
				pending = nil
				break
			end
		end
	end

	makeHero()
	clear(tileRow)
	for i, slot in ipairs(SLOTS) do
		makeTile(slot, i)
	end
	makeTalismanSlots()
	makeGearSlots()

	for id, tabButton in pairs(tabButtons) do
		local n = 0
		for _, entry in ipairs(list) do
			if KIND_TAB[entry.category or entry.kind] == id then
				n += 1
			end
		end
		local active = id == tab
		tabButton.button.Text = string.format('%s <font size="12" color="#aaacb2">%d</font>', tabButton.title, n)
		tabButton.button.TextColor3 = active and TEXT or MUTED
		tabButton.underline.Visible = active
	end
	clear(grid)
	local count = 0
	-- a section is a header (when the tab has more than one) and a grid of cards under it
	local sectionOrder = 0
	local function newSection(title)
		sectionOrder += 1
		local section = make("Frame", { Parent = grid, LayoutOrder = sectionOrder, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIListLayout", { Parent = section, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
		if title then
			label(section, { Text = title, Font = TITLE_FONT, TextSize = 13, TextColor3 = MUTED, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 16) })
		end
		local cards = make("Frame", { Parent = section, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIGridLayout", {
			Parent = cards,
			CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
			CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		-- the cells start just inside, so selected cards' outlines show
		make("UIPadding", { Parent = cards, PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) })
		return cards
	end
	local sections = {}
	for _, entry in ipairs(TABS) do
		if entry.id == tab then
			sections = entry.sections
		end
	end
	for _, group in ipairs(sections) do
		local members = {}
		for _, entry in ipairs(list) do
			if (entry.category or entry.kind) == group.kind then
				table.insert(members, entry)
			end
		end
		if #members > 0 then
			cardParent = newSection(#sections > 1 and group.title or nil)
			for i, entry in ipairs(members) do
				count += 1
				makeCard(entry, i)
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
	MeleeSet = true,
	CurrentPower = true,
	PowerStorage = true,
	LifetimePowers = true,
	[Keybinds.Attribute] = true,
	[ConsumableConfig.StorageAttribute] = true,
	[PowerConfig.BriefcaseStorageAttribute] = true,
	[TalismanConfig.OwnedAttribute] = true,
	[TalismanConfig.EquippedAttribute] = true,
	[GearConfig.BagAttribute] = true,
	[GearConfig.WornAttribute] = true,
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
