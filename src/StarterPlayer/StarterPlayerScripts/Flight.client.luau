-- Flying, for skill sets with it (Iridescent Requiem). The skill bar sends
-- FlightKey to the server, which turns the character's Flying attribute on or
-- off; while it's on, this carries the character where the camera points with
-- the movement keys (Space rises, sprint flies faster) and holds it upright,
-- leaning into the flight, with the set's Fly pose once it's published.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local player = Players.LocalPlayer
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local RISE_SHARE = 0.8 -- of flight speed, holding jump
local TILT = math.rad(20) -- lean while moving
local POSE_BLEND = 0.15 -- seconds
local SPRINT_KEY = Enum.KeyCode.LeftShift
local RISE_KEY = Enum.KeyCode.Space

local movers -- { attachment, velocity, orientation } while flying
local flyTrack

local function flightOf(character)
	local _, setName = SkillSetConfig.Equipped(character)
	local set = setName and SkillSetConfig.Sets[setName]
	return set and set.flight, setName
end

local function land(character)
	if movers then
		for _, mover in pairs(movers) do
			mover:Destroy()
		end
		movers = nil
	end
	if flyTrack then
		flyTrack:Stop(POSE_BLEND)
		flyTrack = nil
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function takeOff(humanoid, root, setName)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Flight"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "Flight"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "Flight"
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.MaxTorque = math.huge
	orientation.Responsiveness = 25
	orientation.CFrame = root.CFrame.Rotation
	orientation.Parent = root
	movers = { attachment = attachment, velocity = velocity, orientation = orientation }
	humanoid.PlatformStand = true

	local folder = ReplicatedStorage:FindFirstChild(setName .. "Animations")
	local animation = folder and folder:FindFirstChild("Fly")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animation and animation.AnimationId ~= "" and animator then
		flyTrack = animator:LoadAnimation(animation)
		flyTrack.Looped = true
		flyTrack.Priority = Enum.AnimationPriority.Action
		flyTrack:Play(POSE_BLEND)
	end
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	local flight, setName = flightOf(character)
	local flying = root and flight and humanoid.Health > 0 and character:GetAttribute("Flying") == true
	if not flying then
		if movers then
			land(character)
		end
		return
	end
	-- after a respawn the old movers went with the old character
	if not movers or movers.attachment.Parent ~= root then
		takeOff(humanoid, root, setName)
	end

	local camera = workspace.CurrentCamera.CFrame
	local input = controls:GetMoveVector() -- camera-relative: x right, z back
	local direction = camera.LookVector * -input.Z + camera.RightVector * input.X
	if UserInputService:IsKeyDown(RISE_KEY) then
		direction += Vector3.yAxis * RISE_SHARE
	end
	if direction.Magnitude > 1 then
		direction = direction.Unit
	end
	local speed = flight.speed * (UserInputService:IsKeyDown(SPRINT_KEY) and flight.boostMultiplier or 1)
	movers.velocity.VectorVelocity = direction * speed

	local flatLook = Vector3.new(camera.LookVector.X, 0, camera.LookVector.Z)
	if flatLook.Magnitude > 0.01 then
		local lean = direction.Magnitude > 0.1 and TILT or 0
		movers.orientation.CFrame = CFrame.lookAt(Vector3.zero, flatLook) * CFrame.Angles(-lean, 0, 0)
	end
end)
