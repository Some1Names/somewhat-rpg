-- The hotbar, in place of Roblox's own. Bottom left, three tall cards for what
-- you carry, like Elden Ring's equipment slots: POWER (key 1), WEAPON (2) and
-- MELEE (3, coming), each outlined in the colour of its skill set's tier
-- (SkillSetConfig.Tiers: purple S, red A, blue B, green C) with the set's name
-- and your mastery in it. Bottom right, the other tools (anything that isn't a
-- power or weapon set) in a 2x3 grid of six slots, keys 4-9, empty ones shown
-- dimmed. Both blocks are the same size and sit above the key hints line. A key or a click equips a tool,
-- or puts it away if it's already in hand.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local player = Players.LocalPlayer

local SLOT_WIDTH = HudConfig.SlotWidth
local SLOT_HEIGHT = HudConfig.SlotHeight
local SLOT_GAP = HudConfig.SideGap
local GRID_COLUMNS = 2
local GRID_SLOTS = 6
local CARD_WIDTH = HudConfig.CardWidth
local CARD_HEIGHT = HudConfig.SideHeight
local BACKGROUND = Color3.fromRGB(20, 20, 28)
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
local order = {}
local function refreshOrder(owned)
	local others = {}
	for _, tool in ipairs(owned) do
		local _, set = setOf(tool)
		if not (set and (set.kind == "power" or set.kind == "weapon")) then
			table.insert(others, tool)
		end
	end
	for i = #order, 1, -1 do
		if not table.find(others, order[i]) then
			table.remove(order, i)
		end
	end
	for _, tool in ipairs(others) do
		if not table.find(order, tool) and #order < GRID_SLOTS then
			table.insert(order, tool)
		end
	end
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
	else
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
	l.Font = props.Font or Enum.Font.GothamBold
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
	button.BackgroundTransparency = 0.25
	button.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	button.Position = UDim2.fromOffset((i - 1) * (CARD_WIDTH + SLOT_GAP), 0)
	button.Parent = cardRow
	local stroke = newStroke(button)
	newLabel(button, { Text = tostring(i), TextSize = 10, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(5, 3), Size = UDim2.fromOffset(14, 12) })
	newLabel(button, { Text = spec.label, TextSize = 9, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 12) })
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
	button.BackgroundTransparency = 0.25
	button.Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT)
	local column, rowIndex = (i - 1) % GRID_COLUMNS, math.floor((i - 1) / GRID_COLUMNS)
	button.Position = UDim2.fromOffset(column * (SLOT_WIDTH + SLOT_GAP), rowIndex * (SLOT_HEIGHT + SLOT_GAP))
	button.Parent = grid
	local stroke = newStroke(button)
	newLabel(button, { Text = tostring(#CARDS + i), TextSize = 10, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(12, 12) })
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
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

	for _, card in ipairs(cards) do
		local tool = toolOfKind(owned, card.kind)
		card.tool = tool
		local held = tool ~= nil and tool.Parent == character
		card.button.BackgroundColor3 = held and HELD_BACKGROUND or BACKGROUND
		card.button.BackgroundTransparency = held and 0.05 or 0.25
		if tool then
			local setName = setOf(tool)
			card.stroke.Color = tierColor(tool)
			card.stroke.Thickness = held and 3 or 2
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
			card.name.Text = card.kind == "melee" and "Coming soon" or "Empty"
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
		slot.button.BackgroundTransparency = held and 0.05 or 0.25
		-- the tier colour, bolder on the tool in hand
		slot.stroke.Color = tierColor(tool)
		slot.stroke.Thickness = held and 3 or 2
		slot.stroke.Transparency = held and 0 or 0.15
		slot.icon.Image = tool.TextureId
		slot.icon.Visible = tool.TextureId ~= ""
		slot.name.Visible = tool.TextureId == ""
		slot.name.Text = tool.Name
	end
end)
