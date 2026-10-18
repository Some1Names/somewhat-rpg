-- Swaps Roblox's default walk, run, idle, jump and fall (the character's
-- Animate script) for ours in ReplicatedStorage.MovementAnimations. One with
-- an empty AnimationId (not published yet) leaves the default. Walk serves
-- for both walking and running; sprinting has its own (Sprint).
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ours = ReplicatedStorage:WaitForChild("MovementAnimations")
local animate = script.Parent:WaitForChild("Animate", 10)
if not animate then
	return
end

-- the Animate values each of ours stands in for
local SLOTS = {
	Walk = { "walk", "run" },
	Idle = { "idle" },
	Jump = { "jump" },
	Fall = { "fall" },
}

-- ours are downloaded before the swap, so the default keeps playing (no frozen pose
-- while running) until they are ready
local loading = {}
for name in pairs(SLOTS) do
	local animation = ours:FindFirstChild(name)
	if animation and animation.AnimationId ~= "" then
		table.insert(loading, animation)
	end
end
pcall(ContentProvider.PreloadAsync, ContentProvider, loading)

-- Animate notices the change and reloads that set
for name, slots in pairs(SLOTS) do
	local animation = ours:FindFirstChild(name)
	if animation and animation.AnimationId ~= "" then
		for _, slot in ipairs(slots) do
			local value = animate:WaitForChild(slot, 5)
			if value then
				for _, child in ipairs(value:GetChildren()) do
					if child:IsA("Animation") then
						child.AnimationId = animation.AnimationId
					end
				end
			end
		end
	end
end

-- Safety net: if the walk/run animation is still playing while the character stands
-- on the ground and isn't moving (Animate missed the stop, e.g. when its animations
-- were swapped or loaded late), stop it and hold our idle until the player moves again.
local RunService = game:GetService("RunService")
local humanoid = script.Parent:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local walk = ours:FindFirstChild("Walk")
local idle = ours:FindFirstChild("Idle")
local STILL_SPEED = 0.5 -- studs per second
local STILL_TIME = 0.25 -- how long it must stand still before the walk is stopped

local idleTrack
local stillFor = 0
RunService.Heartbeat:Connect(function(dt)
	local root = humanoid.RootPart
	local state = humanoid:GetState()
	local grounded = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
	local still = grounded and root and humanoid.MoveDirection.Magnitude < 0.1 and root.AssemblyLinearVelocity.Magnitude < STILL_SPEED
	if not still then
		stillFor = 0
		if idleTrack and idleTrack.IsPlaying then
			idleTrack:Stop(0.15)
		end
		return
	end
	stillFor += dt
	if stillFor < STILL_TIME or not walk or walk.AnimationId == "" then
		return
	end
	local stopped = false
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation and track.Animation.AnimationId == walk.AnimationId then
			track:Stop(0.1)
			stopped = true
		end
	end
	if stopped and idle and idle.AnimationId ~= "" then
		idleTrack = idleTrack or animator:LoadAnimation(idle)
		idleTrack.Looped = true
		if not idleTrack.IsPlaying then
			idleTrack:Play(0.1)
		end
	end
end)
