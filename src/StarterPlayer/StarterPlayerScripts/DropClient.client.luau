-- Enemy drops, client side. Orbs that aren't yours stay hidden while only their
-- owner can take them (the server enforces that either way; this just keeps
-- you from seeing loot you can't take), and "+2 Scrap" pops up when a material
-- in your bag goes up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))

local player = Players.LocalPlayer

local POPUP_SECONDS = 2
local STROKE = Color3.fromRGB(20, 20, 28)

-- hiding others' orbs

local function setVisible(orb, visible)
	orb.LocalTransparencyModifier = visible and 0 or 1
	for _, descendant in ipairs(orb:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Light") or descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
		end
	end
end

local function apply(orb)
	if not orb:IsA("BasePart") then
		return
	end
	local ownerId, publicAt = orb:GetAttribute("OwnerUserId"), orb:GetAttribute("PublicAt")
	if ownerId == player.UserId or not publicAt then
		return
	end
	local wait = publicAt - workspace:GetServerTimeNow()
	if wait <= 0 then
		return
	end
	setVisible(orb, false)
	task.delay(wait, function()
		if orb.Parent then
			setVisible(orb, true)
		end
	end)
end

task.spawn(function()
	local folder = workspace:WaitForChild(DropConfig.FolderName)
	folder.ChildAdded:Connect(apply)
	for _, orb in ipairs(folder:GetChildren()) do
		apply(orb)
	end
end)

-- "+N Name" pop-ups

local gui = Instance.new("ScreenGui")
gui.Name = "DropPopups"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local stack = Instance.new("Frame")
stack.AnchorPoint = Vector2.new(0.5, 1)
stack.Position = UDim2.fromScale(0.5, 0.72)
stack.Size = UDim2.fromOffset(240, 160)
stack.BackgroundTransparency = 1
stack.Parent = gui
local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = stack

local popupCount = 0
local function popup(text)
	popupCount += 1
	local label = Instance.new("TextLabel")
	label.LayoutOrder = popupCount
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = STROKE
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = stack
	local fade = TweenService:Create(
		label,
		TweenInfo.new(0.5),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	task.delay(POPUP_SECONDS - 0.5, function()
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

-- the first value we see for a material is the load from the save: no pop-up
for key, material in pairs(DropConfig.Materials) do
	local attribute = DropConfig.Attribute(key)
	local last = player:GetAttribute(attribute)
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local value = player:GetAttribute(attribute)
		if typeof(value) == "number" and typeof(last) == "number" and value > last then
			popup(string.format("+%d %s", value - last, material.display))
		end
		last = value
	end)
end
