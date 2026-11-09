-- Speed lines: the speed-line image (the one VFX.ScreenSpeedLines uses) stays on the screen's
-- border while you run very fast (the top of Sprint's build-up), stronger the faster you go.
-- Not while dashing. Off with the Flashes setting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))

local player = Players.LocalPlayer

local SPEEDLINES_WIDE = "rbxassetid://79563317427441" -- same images as VFX.ScreenSpeedLines
local SPEEDLINES_TALL = "rbxassetid://75379928250461"
local START_SPEED = 36 -- horizontal speed where the lines begin (Sprint starts at 32, tops out at 44)
local FULL_SPEED = 46 -- and where they are at full strength
local MAX_OPACITY = 0.85 -- at full strength
local EASE = 8 -- how fast the shown strength follows the real one
local PULSE_SPEED = 14 -- radians a second; the lines breathe in and out a little
local PULSE_SIZE = 0.03

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedLines"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = -1 -- under the rest of the HUD
gui.Parent = player:WaitForChild("PlayerGui")

local image = Instance.new("ImageLabel")
image.BackgroundTransparency = 1
image.ScaleType = Enum.ScaleType.Stretch
image.AnchorPoint = Vector2.new(0.5, 0.5)
image.Position = UDim2.fromScale(0.5, 0.5)
image.Size = UDim2.fromScale(1.1, 1.1)
image.ImageTransparency = 1
image.Active = false
image.Parent = gui

local shownStrength = 0
RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local strength = 0
	if root and character:GetAttribute("Swimming") ~= true and Preferences.Get("Flashes") ~= false then
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		strength = math.clamp((speed - START_SPEED) / (FULL_SPEED - START_SPEED), 0, 1)
		if player:GetAttribute("Dashing") then
			strength = 0 -- a dash has its own look; the dash's speed isn't a run
		end
	end
	shownStrength += (strength - shownStrength) * math.min(1, dt * EASE)

	if shownStrength < 0.02 then
		image.ImageTransparency = 1
		return
	end
	local viewport = workspace.CurrentCamera.ViewportSize
	image.Image = viewport.Y > viewport.X and SPEEDLINES_TALL or SPEEDLINES_WIDE
	image.ImageTransparency = 1 - shownStrength * MAX_OPACITY
	local size = 1.1 + math.sin(os.clock() * PULSE_SPEED) * PULSE_SIZE
	image.Size = UDim2.fromScale(size, size)
end)
