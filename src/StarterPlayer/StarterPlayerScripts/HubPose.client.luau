-- The player's own character, posed, drawn over the right of the hub (Hub's
-- PoseStrip) like the illustrated characters on a magazine cover. A clone of
-- the character (no scripts, tools or animator, every part anchored) sits in
-- a ViewportFrame; each tab names a pose from HubPoses, and the parts are
-- placed by walking the joints from the HumanoidRootPart, so nothing waits on
-- the physics. Works on R6 and R15, with Motor6D joints or the newer
-- AnimationConstraint ones (accessories on RigidConstraints). Rebuilt when the
-- character spawns or its look loads.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubPoses = require(ReplicatedStorage:WaitForChild("HubPoses"))
local Hub = require(script.Parent:WaitForChild("Hub"))

local player = Players.LocalPlayer

local BLEED = 1.4 -- the viewport is this many strips wide, reaching left over the main column
local FIELD_OF_VIEW = 30
local CAMERA_DISTANCE = 10.5
local CAMERA_YAW = 20 -- degrees round from straight in front
local LOOK_HEIGHT = -0.4 -- studs above the root part the camera looks at: the feet run off the bottom

local viewport = Instance.new("ViewportFrame")
viewport.Name = "Pose"
viewport.AnchorPoint = Vector2.new(1, 0)
viewport.Position = UDim2.fromScale(1, 0)
viewport.Size = UDim2.fromScale(BLEED, 1)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(190, 190, 190)
viewport.LightColor = Color3.new(1, 1, 1)
viewport.LightDirection = Vector3.new(-1, -1, -1)
viewport.Parent = Hub.PoseStrip

local camera = Instance.new("Camera")
camera.FieldOfView = FIELD_OF_VIEW
local yaw = math.rad(CAMERA_YAW)
local target = Vector3.new(0, LOOK_HEIGHT, 0)
camera.CFrame = CFrame.lookAt(Vector3.new(CAMERA_DISTANCE * math.sin(yaw), LOOK_HEIGHT + 0.3, -CAMERA_DISTANCE * math.cos(yaw)), target)
camera.Parent = viewport
viewport.CurrentCamera = camera

-- HubPoses uses R6 joint names; an R15 joint turns with the R6 joint it stands for
local R15_NAMES = {
	Root = "RootJoint",
	RightShoulder = "Right Shoulder",
	LeftShoulder = "Left Shoulder",
	RightHip = "Right Hip",
	LeftHip = "Left Hip",
}

local world = Instance.new("WorldModel")
world.Parent = viewport

local clone -- the posed copy
local links = {} -- { part0, part1, c0, c1, pose name }: every joint and weld in the clone, at rest

local function strip(model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BaseScript") or item:IsA("Tool") or item:IsA("ForceField") or item:IsA("Animator") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end

local function rebuild()
	local character = player.Character
	if clone then
		clone:Destroy()
		clone = nil
	end
	links = {}
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return
	end
	strip(copy)
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
		elseif item:IsA("JointInstance") and item.Part0 and item.Part1 then
			table.insert(links, { item.Part0, item.Part1, item.C0, item.C1, R15_NAMES[item.Name] or item.Name })
		elseif (item:IsA("AnimationConstraint") or item:IsA("RigidConstraint")) and item.Attachment0 and item.Attachment1 then
			-- the attachments sit at the joint: they play the part of C0 and C1
			local a0, a1 = item.Attachment0, item.Attachment1
			if a0.Parent:IsA("BasePart") and a1.Parent:IsA("BasePart") then
				table.insert(links, { a0.Parent, a1.Parent, a0.CFrame, a1.CFrame, R15_NAMES[item.Name] or item.Name })
			end
		elseif item:IsA("WeldConstraint") and item.Part0 and item.Part1 then
			-- keeps the offset it had: as a joint with that offset for C0
			table.insert(links, { item.Part0, item.Part1, item.Part0.CFrame:ToObjectSpace(item.Part1.CFrame), CFrame.identity, item.Name })
		end
	end
	copy.Parent = world
	clone = copy
end

-- places every part from the root part out, turning the joints `pose` names
local function pose(name)
	if not clone then
		rebuild()
	end
	if not clone then
		return
	end
	if name == "Random" then
		name = HubPoses.RandomPool[math.random(#HubPoses.RandomPool)]
	end
	local angles = HubPoses.Poses[name] or HubPoses.Poses.Idle
	local root = clone:FindFirstChild("HumanoidRootPart")
	root.CFrame = CFrame.new()
	local placed = { [root] = true }
	local progress = true
	while progress do
		progress = false
		for _, link in ipairs(links) do
			local part0, part1, c0, c1, poseName = link[1], link[2], link[3], link[4], link[5]
			local turn = angles[poseName]
			if turn then
				c0 = CFrame.new(c0.Position) * CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z)) * c0.Rotation
			end
			if placed[part0] and not placed[part1] then
				part1.CFrame = part0.CFrame * c0 * c1:Inverse()
				placed[part1] = true
				progress = true
			elseif placed[part1] and not placed[part0] then
				part0.CFrame = part1.CFrame * c1 * c0:Inverse()
				placed[part0] = true
				progress = true
			end
		end
	end
end

Hub.OnTabChanged(function(name)
	pose(Hub.PoseFor(name) or "Idle")
end)

local function onCharacter(character)
	character:WaitForChild("HumanoidRootPart", 10)
	rebuild()
	local showing = Hub.Current()
	if showing then
		pose(Hub.PoseFor(showing) or "Idle")
	end
end
player.CharacterAdded:Connect(onCharacter)
player.CharacterAppearanceLoaded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
