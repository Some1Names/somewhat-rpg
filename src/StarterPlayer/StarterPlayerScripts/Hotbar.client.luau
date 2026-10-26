-- The hotbar, in place of Roblox's own. Bottom left, three tall cards for what
-- you carry (with the yen and the Menu icon above them, TopBar), like Elden Ring's equipment slots: POWER (key 1), WEAPON (2) and
-- MELEE (3, coming), each outlined in the colour of its skill set's tier
-- (SkillSetConfig.Tiers: purple S, red A, blue B, green C) with the set's name
-- and your mastery in it. Bottom right, the other tools (anything that isn't a
-- power or weapon set) in a 3x2 grid of six slots, keys 4-9, empty ones shown
-- dimmed. Both blocks are the same size and sit above the key hints line. A key or a click equips a tool,
-- or puts it away if it's already in hand. 4-9 are a long reach, so the grid also opens as an item
-- wheel on one key (Keybinds "ItemWheel", Caps Lock by default). No tools in the water: they can't
-- be equipped there and one in hand is put away when you swim in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local ActionLock = require(ReplicatedStorage:WaitForChild("ActionLock"))
local HotbarRules = require(ReplicatedStorage:WaitForChild("HotbarRules"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local player = Players.LocalPlayer

local SLOT_WIDTH = HudConfig.SlotWidth
local SLOT_HEIGHT = HudConfig.SlotHeight
local SLOT_GAP = HudConfig.SideGap
local GRID_COLUMNS = 3
local GRID_SLOTS = 6
local CARD_WIDTH = HudConfig.CardWidth
local CARD_HEIGHT = HudConfig.CardHeight
local BACKGROUND = HudConfig.Style.Glass -- Modern Warfare's smoked glass
local HELD_BACKGROUND = Color3.fromRGB(44, 44, 58)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
-- the three cards, left to right; `kind` is a SkillSetConfig set kind (melee has none yet)
local CARDS = {
	{ label = "POWER", kind = "power" },
	{ label = "WEAPON", kind = "weapon" },
	{ label = "MELEE", kind = "melee" },
}

-- Roblox's own hotbar goes; CoreGui may not be ready right away
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			return
		end
		task.wait(0.5)
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "Hotbar"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local cardRow = Instance.new("Frame")
cardRow.AnchorPoint = Vector2.new(0, 1)
cardRow.Position = UDim2.new(0, HudConfig.EdgeMargin, 1, -HudConfig.BottomReserve)
cardRow.Size = UDim2.fromOffset(HudConfig.SideWidth, CARD_HEIGHT)
cardRow.BackgroundTransparency = 1
cardRow.Parent = gui

local grid = Instance.new("Frame")
grid.AnchorPoint = Vector2.new(1, 1)
grid.Position = UDim2.new(1, -HudConfig.EdgeMargin, 1, -HudConfig.BottomReserve)
grid.Size = UDim2.fromOffset(HudConfig.SideWidth, HudConfig.SideHeight)
grid.BackgroundTransparency = 1
grid.Parent = gui

-- the Admin panel takes the right side of the screen, so the grid steps aside while it's open
Menus.OnChange(function(openName)
	grid.Visible = openName ~= "Admin"
end)

local function setOf(tool)
	local setName = tool:GetAttribute("SkillSet")
	return setName, setName and SkillSetConfig.Sets[setName]
end

local function tierColor(tool)
	local _, set = setOf(tool)
	local tier = set and SkillSetConfig.Tiers[set.tier]
	return tier and tier.color or SkillSetConfig.NoTierColor
end

-- every tool the player has, in the backpack or in hand
local function ownedTools()
	local owned = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, child in ipairs(backpack and backpack:GetChildren() or {}) do
		if child:IsA("Tool") then
			table.insert(owned, child)
		end
	end
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if held then
		table.insert(owned, held)
	end
	return owned
end

-- the grid's tools (not a power or weapon set), in the order they first showed up, so slots don't shuffle
local seen = {}
-- slot -> tool: a Tool with a HotbarSlot attribute (the Backpack's EQUIP) keeps that slot, the rest fill the
-- empty ones in the order they came (HotbarRules); there can be gaps
local order = {}
local function refreshOrder(owned)
	local others = {}
	for _, tool in ipairs(owned) do
		local _, set = setOf(tool)
		if HotbarRules.InGrid(set and set.kind) then
			table.insert(others, tool)
		end
	end
	for i = #seen, 1, -1 do
		if not table.find(others, seen[i]) then
			table.remove(seen, i)
		end
	end
	for _, tool in ipairs(others) do
		if not table.find(seen, tool) and #seen < GRID_SLOTS then
			table.insert(seen, tool)
		end
	end
	local entries = {}
	for _, tool in ipairs(seen) do
		table.insert(entries, { id = tool, slot = tool:GetAttribute(HotbarRules.Attribute) })
	end
	order = HotbarRules.Layout(entries, GRID_SLOTS)
end

-- equips the tool, or puts it away if it's in hand
local function toggleTool(tool)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not humanoid or humanoid.Health <= 0 then
		return
	end
	if tool.Parent == character then
		humanoid:UnequipTools()
	elseif not ActionLock.InWater(character) then
		humanoid:EquipTool(tool)
	end
end

local function newStroke(parent)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Miter -- square corners
	stroke.Parent = parent
	return stroke
end

local function newLabel(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.Font or Enum.Font.Highway
	l.TextColor3 = props.TextColor3 or TEXT
	l.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	l.TextWrapped = true
	l.TextSize = props.TextSize
	l.Position = props.Position
	l.Size = props.Size
	l.AnchorPoint = props.AnchorPoint or Vector2.zero
	l.Text = props.Text or ""
	l.Parent = parent
	return l
end

-- the equipment cards
local cards = {}
for i, spec in ipairs(CARDS) do
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = ""
	button.BorderSizePixel = 0
	button.BackgroundColor3 = BACKGROUND
	button.BackgroundTransparency = HudConfig.Style.GlassTransparency
	button.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	button.Position = UDim2.fromOffset((i - 1) * (CARD_WIDTH + SLOT_GAP), 0)
	button.Parent = cardRow
	local stroke = newStroke(button)
	newLabel(button, { Text = tostring(i), Font = HudConfig.Style.MonoFont, TextSize = 10, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(5, 3), Size = UDim2.fromOffset(14, 12) })
	newLabel(button, { Text = spec.label, Font = HudConfig.Style.MonoFont, TextSize = 9, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 12) })
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 36)
	icon.Size = UDim2.fromOffset(CARD_WIDTH - 12, CARD_WIDTH - 12)
	icon.Parent = button
	local name = newLabel(button, { TextSize = 12, Position = UDim2.fromOffset(2, 38), Size = UDim2.new(1, -4, 0, 56) })
	name.TextScaled = true
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 13
	nameLimit.MinTextSize = 8
	nameLimit.Parent = name
	local mastery = newLabel(button, { TextSize = 9, TextColor3 = MUTED, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 12) })
	button.Activated:Connect(function()
		toggleTool(cards[i].tool)
	end)
	cards[i] = { button = button, stroke = stroke, icon = icon, name = name, mastery = mastery, kind = spec.kind }
end

-- the grid's slots
local slots = {}
local function slotAt(i)
	if slots[i] then
		return slots[i]
	end
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = ""
	button.BorderSizePixel = 0
	button.BackgroundColor3 = BACKGROUND
	button.BackgroundTransparency = HudConfig.Style.GlassTransparency
	button.Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT)
	local column, rowIndex = (i - 1) % GRID_COLUMNS, math.floor((i - 1) / GRID_COLUMNS)
	button.Position = UDim2.fromOffset(column * (SLOT_WIDTH + SLOT_GAP), rowIndex * (SLOT_HEIGHT + SLOT_GAP))
	button.Parent = grid
	local stroke = newStroke(button)
	newLabel(button, { Text = tostring(#CARDS + i), Font = HudConfig.Style.MonoFont, TextSize = 10, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(12, 12) })
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.Parent = button
	local name = newLabel(button, { TextSize = 11, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.new(1, -8, 0.6, 0) })
	button.Activated:Connect(function()
		toggleTool(order[i])
	end)
	slots[i] = { button = button, stroke = stroke, icon = icon, name = name }
	return slots[i]
end

-- the item wheel: hold its key and the six grid slots open in a ring round the middle of the
-- screen; point at one and let go to equip it. A quick tap leaves the wheel open to click
-- instead (a Mac's Caps Lock only reports the toggle); the key again, Escape or a right click
-- shuts it
local WHEEL_RADIUS = 110
local WHEEL_TILE = 64
local WHEEL_DEADZONE = 30 -- px from the middle before a slot is picked
local WHEEL_TAP = 0.25 -- s: let go sooner and it stays open

local wheelGui = Instance.new("ScreenGui")
wheelGui.Name = "ItemWheel"
wheelGui.ResetOnSpawn = false
wheelGui.IgnoreGuiInset = true -- so the mouse location and the gui share coordinates
wheelGui.DisplayOrder = 5
wheelGui.Enabled = false
wheelGui.Parent = gui.Parent

-- a full-screen button: Modal frees the mouse from shift lock and first person, and it eats the clicks
local wheelCatcher = Instance.new("TextButton")
wheelCatcher.Modal = true
wheelCatcher.AutoButtonColor = false
wheelCatcher.Text = ""
wheelCatcher.BackgroundColor3 = Color3.new(0, 0, 0)
wheelCatcher.BackgroundTransparency = 0.6
wheelCatcher.Size = UDim2.fromScale(1, 1)
wheelCatcher.Parent = wheelGui

local wheelCenter = Instance.new("Frame")
wheelCenter.BackgroundTransparency = 1
wheelCenter.Position = UDim2.fromScale(0.5, 0.5)
wheelCenter.Size = UDim2.fromOffset(0, 0)
wheelCenter.Parent = wheelGui
local wheelName = newLabel(wheelCenter, { Font = HudConfig.Style.MonoFont, TextSize = 14, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(150, 40) })
wheelName.TextStrokeTransparency = 0.4

-- slot 1 at the top, the rest clockwise
local wheelTiles = {}
for i = 1, GRID_SLOTS do
	local angle = -math.pi / 2 + (i - 1) * 2 * math.pi / GRID_SLOTS
	local tile = Instance.new("Frame")
	tile.BorderSizePixel = 0
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.fromOffset(math.cos(angle) * WHEEL_RADIUS, math.sin(angle) * WHEEL_RADIUS)
	tile.Size = UDim2.fromOffset(WHEEL_TILE, WHEEL_TILE)
	tile.Parent = wheelCenter
	local stroke = newStroke(tile)
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.Parent = tile
	local name = newLabel(tile, { TextSize = 11, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 1, -8) })
	wheelTiles[i] = { tile = tile, stroke = stroke, icon = icon, name = name }
end

local wheelOpenedAt -- os.clock() of the key press that opened it; nil while shut
local wheelHover -- the slot pointed at

local function openWheel()
	wheelGui.Enabled = true
	wheelOpenedAt = os.clock()
	wheelHover = nil
end

-- shuts the wheel, equipping slot `pick` if given
local function closeWheel(pick)
	if not wheelGui.Enabled then
		return
	end
	wheelGui.Enabled = false
	wheelOpenedAt = nil
	if pick then
		toggleTool(order[pick])
	end
end

-- the slot in the mouse's direction from the middle, nil inside the dead zone
local function slotUnderMouse()
	local offset = UserInputService:GetMouseLocation() - wheelCenter.AbsolutePosition
	if offset.Magnitude < WHEEL_DEADZONE then
		return nil
	end
	local step = 2 * math.pi / GRID_SLOTS
	return math.floor((math.atan2(offset.Y, offset.X) + math.pi / 2) / step + 0.5) % GRID_SLOTS + 1
end

local function drawWheel(character)
	wheelHover = slotUnderMouse()
	for i, w in ipairs(wheelTiles) do
		local tool = order[i]
		local hovered = i == wheelHover and tool ~= nil
		w.tile.BackgroundColor3 = hovered and HELD_BACKGROUND or BACKGROUND
		w.tile.BackgroundTransparency = tool and (hovered and 0.05 or HudConfig.Style.GlassTransparency) or 0.6
		w.stroke.Color = tool and tierColor(tool) or SkillSetConfig.NoTierColor
		w.stroke.Thickness = hovered and 3 or (tool and tool.Parent == character) and 2 or 1
		w.stroke.Transparency = tool and 0 or 0.7
		w.icon.Image = tool and tool.TextureId or ""
		w.icon.Visible = tool ~= nil and tool.TextureId ~= ""
		w.name.Visible = tool ~= nil and tool.TextureId == ""
		w.name.Text = tool and tool.Name or ""
	end
	local tool = wheelHover and order[wheelHover]
	wheelName.Text = tool and tool.Name or "ITEMS"
end

wheelCatcher.Activated:Connect(function()
	closeWheel(wheelHover)
end)
wheelCatcher.MouseButton2Click:Connect(function()
	closeWheel()
end)
Menus.OnChange(function(openName)
	if openName then
		closeWheel()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if wheelOpenedAt and os.clock() - wheelOpenedAt > WHEEL_TAP and Keybinds.ActionFor(input.KeyCode) == "ItemWheel" then
		closeWheel(wheelHover)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if wheelGui.Enabled and (input.KeyCode == Enum.KeyCode.Escape or Keybinds.ActionFor(input.KeyCode) == "ItemWheel") then
		closeWheel()
		return
	end
	if gameProcessed or Menus.Blocks() then
		return
	end
	if Keybinds.ActionFor(input.KeyCode) == "ItemWheel" and not Keybinds.Capturing() then
		openWheel()
		return
	end
	local key = table.find(NUMBER_KEYS, input.KeyCode)
	if not key then
		return
	end
	if key <= #CARDS then
		toggleTool(cards[key].tool)
	else
		toggleTool(order[key - #CARDS])
	end
end)

-- the tool of a card's kind, if the player carries one
local function toolOfKind(owned, kind)
	for _, tool in ipairs(owned) do
		local _, set = setOf(tool)
		if set and set.kind == kind then
			return tool
		end
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	local owned = ownedTools()
	refreshOrder(owned)
	local character = player.Character
	if character and character:GetAttribute("Swimming") == true then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end

	for _, card in ipairs(cards) do
		local tool = toolOfKind(owned, card.kind)
		card.tool = tool
		local held = tool ~= nil and tool.Parent == character
		card.button.BackgroundColor3 = held and HELD_BACKGROUND or BACKGROUND
		card.button.BackgroundTransparency = held and 0.05 or HudConfig.Style.GlassTransparency
		if tool then
			local setName = setOf(tool)
			card.stroke.Color = tierColor(tool)
			card.stroke.Thickness = held and 2 or 1
			card.stroke.Transparency = held and 0 or 0.15
			card.icon.Image = tool.TextureId
			card.icon.Visible = tool.TextureId ~= ""
			card.name.Visible = tool.TextureId == ""
			card.name.Text = tool.Name
			card.name.TextColor3 = TEXT
			local mastery = setName and player:GetAttribute(SkillSetConfig.MasteryAttribute(setName))
			card.mastery.Text = mastery and ("Mastery " .. mastery) or ""
		else
			card.stroke.Color = SkillSetConfig.NoTierColor
			card.stroke.Thickness = 1
			card.stroke.Transparency = 0.6
			card.icon.Visible = false
			card.name.Visible = true
			card.name.Text = "Empty"
			card.name.TextColor3 = MUTED
			card.mastery.Text = ""
		end
	end

	-- all six slots always show; the ones with no tool are dimmed
	for i = 1, GRID_SLOTS do
		local slot = slotAt(i)
		local tool = order[i]
		if not tool then
			slot.button.BackgroundColor3 = BACKGROUND
			slot.button.BackgroundTransparency = 0.6
			slot.stroke.Color = SkillSetConfig.NoTierColor
			slot.stroke.Thickness = 1
			slot.stroke.Transparency = 0.7
			slot.icon.Visible = false
			slot.name.Visible = false
			continue
		end
		local held = tool.Parent == character
		slot.button.BackgroundColor3 = held and HELD_BACKGROUND or BACKGROUND
		slot.button.BackgroundTransparency = held and 0.05 or HudConfig.Style.GlassTransparency
		-- the tier colour, bolder on the tool in hand
		slot.stroke.Color = tierColor(tool)
		slot.stroke.Thickness = held and 2 or 1
		slot.stroke.Transparency = held and 0 or 0.15
		slot.icon.Image = tool.TextureId
		slot.icon.Visible = tool.TextureId ~= ""
		slot.name.Visible = tool.TextureId == ""
		slot.name.Text = tool.Name
	end

	if wheelGui.Enabled then
		drawWheel(character)
	end
end)
