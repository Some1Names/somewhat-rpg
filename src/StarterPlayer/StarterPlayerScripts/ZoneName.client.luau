-- The zone name: walking into a named area (ZoneConfig, a mockup for now) fades its name
-- in near the top of the screen for a few seconds, with a thin line drawing out under it.
-- Shown once per change of area, and only while the HUD shows (not under the title menu
-- or the hub), so a name isn't spent while nobody can see it. Plain white text with a
-- dark stroke, square.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HudRules = require(ReplicatedStorage:WaitForChild("HudRules"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))

local player = Players.LocalPlayer

local CHECK_SPACING = 0.5 -- seconds between looks at where you are
local HOLD = 2.5 -- seconds the name stays
local FADE_TIME = 0.6
local LINE_WIDTH = 180

local gui = Instance.new("ScreenGui")
gui.Name = "ZoneName"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local hudRoot = UIScale.Root(gui) -- the title menu and the hub hide it

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(0.5, 0)
holder.Position = UDim2.fromScale(0.5, 0.14)
holder.Size = UDim2.fromOffset(480, 40)
holder.BackgroundTransparency = 1
holder.Parent = gui

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, 0, 0, 30)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.Highway
nameLabel.TextSize = 28
nameLabel.TextColor3 = Color3.new(1, 1, 1)
nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
nameLabel.TextTransparency = 1
nameLabel.TextStrokeTransparency = 1
nameLabel.Parent = holder

local line = Instance.new("Frame")
line.AnchorPoint = Vector2.new(0.5, 0)
line.Position = UDim2.new(0.5, 0, 0, 34)
line.Size = UDim2.fromOffset(0, 1)
line.BackgroundColor3 = Color3.new(1, 1, 1)
line.BorderSizePixel = 0
line.Parent = holder

local shown = 0
local function show(name)
	shown += 1
	local mine = shown
	nameLabel.Text = string.upper(name)
	nameLabel.TextTransparency = 1
	nameLabel.TextStrokeTransparency = 1
	line.Size = UDim2.fromOffset(0, 1)
	line.BackgroundTransparency = 0
	local fadeIn = TweenInfo.new(FADE_TIME)
	TweenService:Create(nameLabel, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	TweenService:Create(line, TweenInfo.new(FADE_TIME * 1.5, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(LINE_WIDTH, 1) }):Play()
	task.delay(FADE_TIME + HOLD, function()
		if shown ~= mine then
			return
		end
		local fadeOut = TweenInfo.new(FADE_TIME)
		TweenService:Create(nameLabel, fadeOut, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(line, fadeOut, { BackgroundTransparency = 1 }):Play()
	end)
end

local lastShown = nil
while true do
	task.wait(CHECK_SPACING)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and hudRoot.Visible then
		local zone = HudRules.ZoneAt(ZoneConfig.Zones, root.Position.X, root.Position.Z)
		if zone and zone ~= lastShown then
			lastShown = zone
			show(zone)
		end
	end
end
