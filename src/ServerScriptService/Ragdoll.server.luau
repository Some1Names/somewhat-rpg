-- Ragdolls every character that dies, players and NPCs alike, instead of
-- Roblox's default of breaking it apart. Each body joint becomes a loose
-- ball socket, limited by LIMITS so limbs don't bend backwards, and the
-- limbs turn solid so the body lands on the floor. Older rigs pose with
-- Motor6Ds; newer ones (players' avatars here) pose with AnimationConstraints
-- and already carry limited ball sockets, so for those the pose is just let
-- go and their own sockets are kept. The HumanoidRootPart is welded to the
-- torso, so it (and the camera) follows the body: the engine switches off a
-- new rig's root AnimationConstraint itself on death, which would otherwise
-- drop it out of the world. Works for R15 and
-- R6 rigs: each socket points from the joint to the limb it carries, whatever
-- the rig's joint frames are. A body standing straight would balance on its
-- legs, so it's pushed over: away from whoever last hit it (Damage), or any
-- way if nobody did. The body lies there until it respawns
-- (Players.RespawnTime for players, DummyRespawn for NPCs).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Damage = require(script.Parent:WaitForChild("Damage"))

local PUSH_SPEED = 14 -- studs/s the torso's top is shoved away
local PUSH_LIFT = 4 -- and up

-- per joint name: how far the limb may swing from where it was (degrees) and
-- twist either way; joints not listed get DEFAULT_LIMIT
local DEFAULT_LIMIT = { swing = 45, twist = 30 }
local LIMITS = {
	Neck = { swing = 40, twist = 40 },
	Waist = { swing = 25, twist = 20 },
	LeftShoulder = { swing = 90, twist = 60 },
	RightShoulder = { swing = 90, twist = 60 },
	["Left Shoulder"] = { swing = 90, twist = 60 },
	["Right Shoulder"] = { swing = 90, twist = 60 },
	LeftElbow = { swing = 75, twist = 5 },
	RightElbow = { swing = 75, twist = 5 },
	LeftWrist = { swing = 30, twist = 10 },
	RightWrist = { swing = 30, twist = 10 },
	LeftHip = { swing = 60, twist = 30 },
	RightHip = { swing = 60, twist = 30 },
	["Left Hip"] = { swing = 60, twist = 30 },
	["Right Hip"] = { swing = 60, twist = 30 },
	LeftKnee = { swing = 75, twist = 5 },
	RightKnee = { swing = 75, twist = 5 },
	LeftAnkle = { swing = 30, twist = 10 },
	RightAnkle = { swing = 30, twist = 10 },
}
-- joints that stay rigid: the root keeps the HumanoidRootPart with the body
local KEEP = { Root = true, RootJoint = true }
local TAG = "Ragdolled"

-- the parts a joint holds together and where they meet, for a Motor6D or an
-- AnimationConstraint; nil for anything else or a joint missing a part
local function jointInfo(joint)
	if joint:IsA("Motor6D") then
		if joint.Part0 and joint.Part1 then
			return joint.Part0, joint.Part1, (joint.Part0.CFrame * joint.C0).Position
		end
	elseif joint:IsA("AnimationConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		if a0 and a1 and a0.Parent:IsA("BasePart") and a1.Parent:IsA("BasePart") then
			return a0.Parent, a1.Parent, a0.WorldPosition
		end
	end
	return nil
end

-- whether a working ball socket already joins the two parts
local function hasSocket(character, part0, part1)
	for _, socket in ipairs(character:GetDescendants()) do
		if socket:IsA("BallSocketConstraint") and socket.Enabled and socket.Attachment0 and socket.Attachment1 then
			local p0, p1 = socket.Attachment0.Parent, socket.Attachment1.Parent
			if (p0 == part0 and p1 == part1) or (p0 == part1 and p1 == part0) then
				return true
			end
		end
	end
	return false
end

-- a frame at the joint whose X axis (a ball socket's swing axis) points at the limb
local function socketFrame(joint, limb)
	local toLimb = limb.Position - joint
	local axis = toLimb.Magnitude > 0.05 and toLimb.Unit or Vector3.new(0, -1, 0)
	local up = math.abs(axis.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
	local back = axis:Cross(up).Unit
	return CFrame.fromMatrix(joint, axis, back:Cross(axis).Unit, back)
end

local function ragdoll(character, humanoid)
	if CollectionService:HasTag(character, TAG) then
		return
	end
	CollectionService:AddTag(character, TAG)

	for _, joint in ipairs(character:GetDescendants()) do
		local part0, part1, where = jointInfo(joint)
		if part0 and KEEP[joint.Name] then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "RagdollRoot"
			weld.Part0 = part0
			weld.Part1 = part1
			weld.Parent = part1
		elseif part0 then
			if not hasSocket(character, part0, part1) then
				local frame = socketFrame(where, part1)
				local attachment0 = Instance.new("Attachment")
				attachment0.Name = "Ragdoll" .. joint.Name .. "0"
				attachment0.CFrame = part0.CFrame:ToObjectSpace(frame)
				attachment0.Parent = part0
				local attachment1 = Instance.new("Attachment")
				attachment1.Name = "Ragdoll" .. joint.Name .. "1"
				attachment1.CFrame = part1.CFrame:ToObjectSpace(frame)
				attachment1.Parent = part1

				local limit = LIMITS[joint.Name] or DEFAULT_LIMIT
				local socket = Instance.new("BallSocketConstraint")
				socket.Name = "Ragdoll" .. joint.Name
				socket.Attachment0 = attachment0
				socket.Attachment1 = attachment1
				socket.LimitsEnabled = true
				socket.UpperAngle = limit.swing
				socket.TwistLimitsEnabled = true
				socket.TwistLowerAngle = -limit.twist
				socket.TwistUpperAngle = limit.twist
				socket.Parent = part1
			end

			-- neighbouring limbs overlap at the joint; colliding there would jitter
			local noCollide = Instance.new("NoCollisionConstraint")
			noCollide.Part0 = part0
			noCollide.Part1 = part1
			noCollide.Parent = part1

			joint.Enabled = false
		end
	end

	local root = humanoid.RootPart
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			if part == root then
				-- invisible: it rides along with the torso without propping it up
				part.CanCollide = false
				part.Massless = true
			else
				part.CanCollide = true
			end
		end
	end

	-- a player's body is simulated by their own client; the server takes it
	-- over so the push below lands and everyone sees the same fall
	if Players:GetPlayerFromCharacter(character) then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and not part.Anchored then
				pcall(part.SetNetworkOwner, part, nil)
			end
		end
	end

	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso then
		local attacker = Damage.LastAttacker(humanoid)
		local from = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
		local away = from and (torso.Position - from.Position) * Vector3.new(1, 0, 1)
		if not away or away.Magnitude < 0.1 then
			local angle = math.random() * 2 * math.pi
			away = Vector3.new(math.cos(angle), 0, math.sin(angle))
		end
		local impulse = (away.Unit * PUSH_SPEED + Vector3.yAxis * PUSH_LIFT) * torso.AssemblyMass
		-- at the top of the torso, so it tips over rather than slides
		torso:ApplyImpulseAtPosition(impulse, torso.Position + torso.CFrame.UpVector * torso.Size.Y / 2)
	end
end

local function watch(humanoid)
	local character = humanoid.Parent
	if not character or not character:IsA("Model") then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Once(function()
		ragdoll(character, humanoid)
	end)
end

workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("Humanoid") then
		watch(instance)
	end
end)
for _, instance in ipairs(workspace:GetDescendants()) do
	if instance:IsA("Humanoid") then
		watch(instance)
	end
end
