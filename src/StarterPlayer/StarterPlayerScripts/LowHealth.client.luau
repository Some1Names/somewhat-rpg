-- Low health: the screen's edges turn red below HudConfig.LowHealthStart of max health,
-- stronger as it drops, and pulse below HudConfig.LowHealthPulse. Four edge strips with
-- gradients, a placeholder until there's a vignette image. Gone once dead (the death
-- screen's turn).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local HudRules = require(ReplicatedStorage:WaitForChild("HudRules"))

local player = Players.LocalPlayer

local RED = Color3.fromRGB(200, 20, 30)
local MAX_OPACITY = 0.6 -- at the very edge, at full strength
local DEPTH = 0.16 -- how far in from each edge the red reaches, a share of the screen
local PULSE_SPEED = 6 -- radians a second
local EASE = 6 -- how fast the shown strength follows the real one

local gui = Instance.new("ScreenGui")
gui.Name = "LowHealth"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- the whole screen, under Roblox's top bar too
gui.DisplayOrder = -1 -- under the rest of the HUD
gui.Parent = player:WaitForChild("PlayerGui")

-- { size, position, gradient rotation } with the red at the gradient's start
local EDGES = {
	{ UDim2.fromScale(1, DEPTH), UDim2.fromScale(0, 0), 90 }, -- top
	{ UDim2.fromScale(1, DEPTH), UDim2.fromScale(0, 1 - DEPTH), 270 }, -- bottom
	{ UDim2.fromScale(DEPTH, 1), UDim2.fromScale(0, 0), 0 }, -- left
	{ UDim2.fromScale(DEPTH, 1), UDim2.fromScale(1 - DEPTH, 0), 180 }, -- right
}
local strips = {}
for _, edge in ipairs(EDGES) do
	local strip = Instance.new("Frame")
	strip.Size = edge[1]
	strip.Position = edge[2]
	strip.BackgroundColor3 = RED
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.Active = false
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = edge[3]
	gradient.Transparency = NumberSequence.new(0, 1)
	gradient.Parent = strip
	strip.Parent = gui
	table.insert(strips, strip)
end

local shownStrength = 0
RunService.Heartbeat:Connect(function(dt)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local strength = 0
	if humanoid and humanoid.MaxHealth > 0 then
		local fraction = humanoid.Health / humanoid.MaxHealth
		strength = HudRules.LowHealthIntensity(fraction, HudConfig.LowHealthStart)
		if strength > 0 and fraction < HudConfig.LowHealthPulse then
			strength *= 0.75 + 0.25 * math.sin(os.clock() * PULSE_SPEED)
		end
	end
	shownStrength += (strength - shownStrength) * math.min(1, dt * EASE)
	local transparency = 1 - shownStrength * MAX_OPACITY
	for _, strip in ipairs(strips) do
		strip.BackgroundTransparency = transparency
	end
end)
