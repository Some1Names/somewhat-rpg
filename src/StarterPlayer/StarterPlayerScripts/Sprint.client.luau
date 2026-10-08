-- Hold Left Shift to sprint while moving; sprinting drains stamina and swaps
-- the normal run for the SprintRun animation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Stamina = require(script.Parent:WaitForChild("Stamina"))
local sprintAnimation = ReplicatedStorage:WaitForChild("SprintAnimation")

local player = Players.LocalPlayer

local SPRINT_KEY = Enum.KeyCode.LeftShift
local SPRINT_SPEED = 32
local WALK_SPEED = StarterPlayer.CharacterWalkSpeed
local DRAIN_PER_SECOND = 10 -- a full bar lasts 10 seconds of sprinting
local BLEND_TIME = 0.15 -- seconds to fade between the normal run and the sprint

local holding = false
local sprintTracks = setmetatable({}, { __mode = "k" })

local function sprintTrack(humanoid)
	-- sprinting still works before the animation has been published
	if sprintAnimation.AnimationId == "" then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local track = sprintTracks[animator]
	if not track then
		track = animator:LoadAnimation(sprintAnimation)
		track.Priority = Enum.AnimationPriority.Movement
		track.Looped = true
		sprintTracks[animator] = track
	end
	return track
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == SPRINT_KEY then
		holding = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == SPRINT_KEY then
		holding = false
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	-- only drains while actually moving
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sprinting = holding and moving and Stamina.Drain(DRAIN_PER_SECOND * dt)
	humanoid.WalkSpeed = sprinting and SPRINT_SPEED or WALK_SPEED

	-- the sprint animation only shows while actually running fast on the ground
	local track = sprintTrack(humanoid)
	if not track then
		return
	end
	local velocity = humanoid.RootPart and humanoid.RootPart.AssemblyLinearVelocity or Vector3.zero
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if sprinting and grounded and speed > WALK_SPEED then
		if not track.IsPlaying then
			track:Play(BLEND_TIME)
		end
		-- stride rate follows actual speed so the feet don't skate
		track:AdjustSpeed(speed / SPRINT_SPEED)
	elseif track.IsPlaying then
		track:Stop(BLEND_TIME)
	end
end)
