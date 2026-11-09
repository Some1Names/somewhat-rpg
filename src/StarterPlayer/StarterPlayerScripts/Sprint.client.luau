-- Hold Left Shift to sprint while moving (or press it to start and stop, in the Sprint
-- setting; toggled sprint also ends when you stop moving); sprinting drains stamina and swaps
-- the normal run for the SprintRun animation. Blocking (Guard) halves the walk
-- and rules out sprinting; a guard break's stun holds you still. No sprinting
-- while swimming (Swim sets the character's Swimming attribute).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local CombatFeel = require(ReplicatedStorage:WaitForChild("CombatFeel"))
local GuardConfig = require(ReplicatedStorage:WaitForChild("GuardConfig"))
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local Stamina = require(script.Parent:WaitForChild("Stamina"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local sprintAnimation = ReplicatedStorage:WaitForChild("SprintAnimation", 10) -- nil: sprinting works without it

local player = Players.LocalPlayer

local SPRINT_KEY = Enum.KeyCode.LeftShift
local SPRINT_SPEED = 32
local MAX_SPRINT_SPEED = 44 -- reached after RAMP_TIME seconds of unbroken sprinting
local RAMP_TIME = 6
local WALK_SPEED = StarterPlayer.CharacterWalkSpeed
local DRAIN_PER_SECOND = 10 -- a full bar lasts 10 seconds of sprinting
local BLEND_TIME = 0.15 -- seconds to fade between the normal run and the sprint

local holding = false
local wasMoving = false
local runTime = 0 -- seconds of unbroken sprinting
local sprintTracks = setmetatable({}, { __mode = "k" })
local nextLoadTry = 0 -- a failed load is retried after a pause, not every frame

local function sprintTrack(humanoid)
	-- sprinting still works before the animation has been published or while it hasn't loaded
	if not sprintAnimation or sprintAnimation.AnimationId == "" then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local track = sprintTracks[animator]
	if not track then
		if os.clock() < nextLoadTry then
			return nil
		end
		local ok, loaded = pcall(animator.LoadAnimation, animator, sprintAnimation)
		if not ok or not loaded then
			nextLoadTry = os.clock() + 3
			return nil
		end
		track = loaded
		track.Priority = Enum.AnimationPriority.Movement
		track.Looped = true
		sprintTracks[animator] = track
	end
	-- a track whose animation hasn't loaded (or failed to) has no length yet: don't play it
	if track.Length <= 0 then
		return nil
	end
	return track
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and not Menus.Blocks() and input.KeyCode == SPRINT_KEY then
		if Preferences.Choice("Sprint") == "TOGGLE" then
			holding = not holding
		else
			holding = true
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == SPRINT_KEY and Preferences.Choice("Sprint") ~= "TOGGLE" then
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
	if wasMoving and not moving and Preferences.Choice("Sprint") == "TOGGLE" then
		holding = false -- a toggled sprint ends when you stop
	end
	wasMoving = moving
	local stunned = (character:GetAttribute("HitstunUntil") or 0) > workspace:GetServerTimeNow()
	local blocking = character:GetAttribute("Blocking") == true
	local swimming = character:GetAttribute("Swimming") == true
	local swinging = os.clock() < (player:GetAttribute("SwingUntil") or 0)
	local sprinting = holding and moving and not stunned and not blocking and not swimming and not swinging and Stamina.Drain(DRAIN_PER_SECOND * dt)
	if stunned or blocking or swinging then
		runTime = 0 -- any interruption restarts the build-up
	end
	if stunned then
		humanoid.WalkSpeed = 0
		humanoid.Jump = false
	elseif blocking then
		humanoid.WalkSpeed = WALK_SPEED * GuardConfig.BlockWalkShare
	elseif swinging then
		humanoid.WalkSpeed = WALK_SPEED * CombatFeel.SwingWalkShare
	else
		-- the longer you keep sprinting, the faster you get; stopping resets it
		runTime = sprinting and math.min(runTime + dt, RAMP_TIME) or 0
		humanoid.WalkSpeed = sprinting and SPRINT_SPEED + (MAX_SPRINT_SPEED - SPRINT_SPEED) * runTime / RAMP_TIME or WALK_SPEED
	end

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
