-- The hotbar, in place of Roblox's own: a square slot per tool, outlined in
-- the colour of the tool's skill-set tier (SkillSetConfig.Tiers: purple S,
-- red A, blue B, green C; gray for tools that aren't skill sets). Keys 1-9
-- or a click equip a tool, or put it away if it's already in hand.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local player = Players.LocalPlayer

local SLOT_SIZE = 52
local SLOT_GAP = 6
local BOTTOM_MARGIN = 16 -- pixels; the skill bar sits above it
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

local row = Instance.new("Frame")
row.AnchorPoint = Vector2.new(0.5, 1)
row.Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN)
row.BackgroundTransparency = 1
row.Parent = gui

local function tierColor(tool)
	local setName = tool:GetAttribute("SkillSet")
	local set = setName and SkillSetConfig.Sets[setName]
	local tier = set and SkillSetConfig.Tiers[set.tier]
	return tier and tier.color or SkillSetConfig.NoTierColor
end

-- the tools in the order they first showed up, so slots don't shuffle
local order = {}
local function refreshOrder()
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
	for i = #order, 1, -1 do
		if not table.find(owned, order[i]) then
			table.remove(order, i)
		end
	end
	for _, tool in ipairs(owned) do
		if not table.find(order, tool) and #order < #NUMBER_KEYS then
			table.insert(order, tool)
		end
	end
end

-- equips the tool in slot i, or puts it away if it's in hand
local function toggle(i)
	local tool = order[i]
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
	button.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	button.Position = UDim2.fromOffset((i - 1) * (SLOT_SIZE + SLOT_GAP), 0)
	button.Parent = row
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Miter -- square corners
	stroke.Parent = button
	local number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Position = UDim2.fromOffset(4, 2)
	number.Size = UDim2.fromOffset(12, 12)
	number.Font = Enum.Font.GothamBold
	number.TextSize = 10
	number.TextColor3 = MUTED
	number.TextXAlignment = Enum.TextXAlignment.Left
	number.Text = tostring(i)
	number.Parent = button
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.Parent = button
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 0.5)
	name.Position = UDim2.fromScale(0.5, 0.55)
	name.Size = UDim2.new(1, -8, 0.6, 0)
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = TEXT
	name.TextWrapped = true
	name.TextScaled = true
	name.Parent = button
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 11
	limit.Parent = name
	button.Activated:Connect(function()
		toggle(i)
	end)
	slots[i] = { button = button, stroke = stroke, icon = icon, name = name }
	return slots[i]
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local i = table.find(NUMBER_KEYS, input.KeyCode)
	if i then
		toggle(i)
	end
end)

RunService.RenderStepped:Connect(function()
	refreshOrder()
	local character = player.Character
	for i, tool in ipairs(order) do
		local slot = slotAt(i)
		local held = tool.Parent == character
		slot.button.Visible = true
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
	for i = #order + 1, #slots do
		slots[i].button.Visible = false
	end
	row.Visible = #order > 0
	row.Size = UDim2.fromOffset(math.max(#order * SLOT_SIZE + (#order - 1) * SLOT_GAP, 0), SLOT_SIZE)
end)
