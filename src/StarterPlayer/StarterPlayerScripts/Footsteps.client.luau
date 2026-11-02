-- Footstep sounds: a clip from FootstepConfig plays when a foot touches the ground, for every
-- player near the camera. A step is the higher foot coming down level with the other
-- (FootstepConfig.Step) while its character runs along the ground, so they follow whatever
-- animation is playing. The ground's material picks the set; with no set there, Roblox's own
-- footsteps (the root's "Running" sound) are left alone, and with one they are muted. Played
-- 3D from the foot through the Effects volume setting.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FootstepConfig = require(ReplicatedStorage:WaitForChild("FootstepConfig"))
local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))
local AudioMix = require(script.Parent:WaitForChild("AudioMix"))

local DEFAULT_VOLUME = 0.5
local DEFAULT_PITCH = { 0.95, 1.05 }
local GROUND_RAY = 10 -- studs down from the root that ground is looked for

local walkers = setmetatable({}, { __mode = "k" }) -- character -> { side, peak (FootstepConfig.Step), last = id }
local random = Random.new()

-- the two feet: R15 feet, or R6 legs
local function feetOf(character)
	local left = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
	local right = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
	return left, right
end

-- the world height of the lowest point of a part
local function bottomOf(part)
	local cf, size = part.CFrame, part.Size
	local half = (math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z) / 2
	return cf.Position.Y - half
end

local function play(foot, set, walker)
	local id = FootstepConfig.Pick(set, walker.last, function(low, high)
		return random:NextInteger(low, high)
	end)
	walker.last = id
	local pitch = set.pitch or DEFAULT_PITCH
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = (set.volume or DEFAULT_VOLUME) * SoundConfig.MasterVolume
	sound.PlaybackSpeed = pitch[1] + random:NextNumber() * (pitch[2] - pitch[1])
	sound.RollOffMaxDistance = FootstepConfig.Range
	sound.SoundGroup = AudioMix.Group("Effects")
	sound.Parent = foot
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 5)
	sound:Play()
end

-- Roblox's own footsteps are muted while one of our sets covers the ground
local function muteDefault(root, muted)
	local running = root:FindFirstChild("Running")
	if running and running:IsA("Sound") then
		if running:GetAttribute("StepVolume") == nil then
			running:SetAttribute("StepVolume", running.Volume)
		end
		running.Volume = muted and 0 or running:GetAttribute("StepVolume")
	end
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function update(character, camera)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if (root.Position - camera.CFrame.Position).Magnitude > FootstepConfig.Range * 1.5 then
		return
	end
	local walker = walkers[character]
	if not walker then
		walker = {}
		walkers[character] = walker
	end

	local state = humanoid:GetState()
	local grounded = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
	local velocity = root.AssemblyLinearVelocity
	local moving = grounded and Vector3.new(velocity.X, 0, velocity.Z).Magnitude >= FootstepConfig.MinSpeed
	if not grounded then
		-- in the air or swimming: the next step starts afresh
		walker.side, walker.peak = 0, 0
		return
	end

	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -GROUND_RAY, 0), params)
	local set = hit and FootstepConfig.ForMaterial(hit.Material.Name)
	muteDefault(root, set ~= nil)
	local left, right = feetOf(character)
	if not left or not right then
		return
	end
	if not hit or not moving then
		walker.side, walker.peak = 0, 0
		return
	end

	local landed = FootstepConfig.Step(walker, bottomOf(left) - bottomOf(right))
	if landed and set then
		play(landed == "Left" and left or right, set, walker)
	end
end

RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			update(other.Character, camera)
		end
	end
end)
