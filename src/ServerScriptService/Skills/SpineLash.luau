-- Mandela Z while overcharged, Spine Lash: a whip of backbone shoots from the
-- caster's left arm, locking onto the enemy nearest where they aimed (within
-- AutoAimCone; the skill bar's preview picks the same one), piercing the
-- first few enemies along the way. Red spikes burst out of each one as it's struck
-- (two stacks of Bleeding), and once the
-- whip is fully out it yanks them all back to just in front of the caster,
-- exposed to the caster's next axe finisher.
-- Clients draw it from the SkillEffects "SpineLash" and "BoneSpikes" events.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 40, -- studs
	ExtendSpeed = 150, -- studs per second the whip shoots out
	Width = 3.5, -- studs either side of the whip that it catches
	MaxTargets = 3,
	Damage = 24, -- per target, before the caster's Superliminal bonus
	PullTime = 0.3, -- seconds the yank takes
	BrakeTime = 0.1, -- seconds holding them still where they land
	BleedStacks = 2,
	LandDistance = 5, -- studs in front of the caster they land
	LandSpacing = 3, -- studs between targets landing side by side
	MaxPullSpeed = 140,
	ReleaseDelay = 0.1, -- lines the whip up with the cast animation's lash
	AutoAimCone = 30, -- degrees either side of the aim it locks onto a target in
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Mandela" }
local COLOR = SkillSetConfig.Sets.Mandela.overcharge.color
local LINKS = SkillSetConfig.Sets.Mandela.links

-- first thing in the way that isn't a character (it pierces those)
local function firstWall(from, offset, character)
	local ignore = { character }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, offset, params)
		if not hit then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			return hit.Position
		end
		table.insert(ignore, model)
	end
	return nil
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- the character nearest the direction of `aim`, within range and the cone
-- (the same pick as AimIndicator.LockTarget on the client)
local function lockOn(character, root, aim)
	local wanted = flat(aim - root.Position)
	if wanted.Magnitude < 0.1 then
		wanted = flat(root.CFrame.LookVector)
	end
	wanted = wanted.Unit
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local best, bestAngle
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, CONFIG.Range, overlap)) do
		local model = part.Parent
		local humanoid = part.Name == "HumanoidRootPart" and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not model:GetAttribute("Invulnerable") then
			local toward = flat(part.Position - root.Position)
			if toward.Magnitude > 0.1 then
				local angle = math.deg(math.acos(math.clamp(toward.Unit:Dot(wanted), -1, 1)))
				if angle <= CONFIG.AutoAimCone and (not bestAngle or angle < bestAngle) then
					best, bestAngle = part, angle
				end
			end
		end
	end
	return best
end

-- the targets along the whip, nearest first
local function findTargets(character, from, direction, length)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local box = CFrame.lookAt(from + direction * length / 2, from + direction * length)
	local size = Vector3.new(CONFIG.Width * 2, CONFIG.Width * 2, length)
	local targets, seen = {}, {}
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, size, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not seen[humanoid] and humanoid.Health > 0 and not model:GetAttribute("Invulnerable") then
			seen[humanoid] = true
			local along = (root.Position - from):Dot(direction)
			if along > 0 then
				table.insert(targets, { humanoid = humanoid, root = root, along = along })
			end
		end
	end
	table.sort(targets, function(a, b)
		return a.along < b.along
	end)
	for i = #targets, CONFIG.MaxTargets + 1, -1 do
		table.remove(targets, i)
	end
	return targets
end

-- reels a target in to `landing`, then holds it there a moment so it
-- doesn't slide on into the caster
local function pull(root, landing)
	local velocity = (landing - root.Position) / CONFIG.PullTime
	if velocity.Magnitude > CONFIG.MaxPullSpeed then
		velocity = velocity.Unit * CONFIG.MaxPullSpeed
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SpineLashPull"
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "SpineLashPull"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.MaxForce = math.huge
	mover.VectorVelocity = velocity
	mover.Parent = root
	task.delay(CONFIG.PullTime, function()
		if mover.Parent then
			mover.VectorVelocity = Vector3.zero
		end
	end)
	Debris:AddItem(mover, CONFIG.PullTime + CONFIG.BrakeTime)
	Debris:AddItem(attachment, CONFIG.PullTime + CONFIG.BrakeTime)
end

local function lash(player, character, aim)
	task.wait(CONFIG.ReleaseDelay)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return
	end
	local hand = character:FindFirstChild("LeftHand") or root
	local from = hand.Position
	-- at the locked-on target if there is one, otherwise toward where they
	-- aimed, up or down (SkillBar raises a point on the floor to chest height)
	local locked = lockOn(character, root, aim)
	if locked then
		aim = locked.Position
	end
	local toAim = aim - from
	if Vector3.new(toAim.X, 0, toAim.Z).Magnitude < 2 then
		toAim = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	local direction = toAim.Unit
	local wall = firstWall(from, direction * CONFIG.Range, character)
	local length = wall and math.max((wall - from).Magnitude, 1) or CONFIG.Range
	local extendTime = length / CONFIG.ExtendSpeed
	local targets = findTargets(character, from, direction, length)
	skillEffects:FireAllClients("SpineLash", character, from, from + direction * length, extendTime, CONFIG.PullTime, COLOR)

	-- each one is struck as the tip passes through it
	for _, target in ipairs(targets) do
		task.delay(target.along / CONFIG.ExtendSpeed, function()
			if target.root.Parent and target.humanoid.Health > 0 then
				skillEffects:FireAllClients("BoneSpikes", target.root.Position, COLOR, 1)
				if Damage.Deal(player, target.humanoid, CONFIG.Damage, DAMAGE_OPTIONS) > 0 then
					StatusEffects.Apply(target.humanoid, "Bleeding", { source = player, stat = "Superliminal", skillSet = "Mandela", stacks = CONFIG.BleedStacks })
				end
			end
		end)
	end
	task.wait(extendTime)

	-- then the whip snaps back with everyone still standing
	root = humanoid.RootPart
	if not root or not root.Parent or #targets == 0 then
		return
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(direction.X, 0, direction.Z).Unit
	local side = Vector3.new(-look.Z, 0, look.X)
	for i, target in ipairs(targets) do
		local model = target.humanoid.Parent
		if target.root.Parent and target.humanoid.Health > 0 then
			Damage.Expose(player, model, LINKS.exposedDuration)
		end
		if target.root.Parent and not target.root.Anchored and target.humanoid.Health > 0 and CrowdControl.CanControl(model) then
			local spread = (i - (#targets + 1) / 2) * CONFIG.LandSpacing
			local landing = root.Position + look * CONFIG.LandDistance + side * spread
			pull(target.root, Vector3.new(landing.X, target.root.Position.Y, landing.Z))
			CrowdControl.Apply(model, CONFIG.PullTime + CONFIG.BrakeTime)
		end
	end
end

local SpineLash = {}

function SpineLash.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid.RootPart then
		return false
	end
	task.spawn(function()
		local ok, err = pcall(lash, player, character, aim)
		if not ok then
			warn("[Skills.SpineLash] " .. tostring(err))
		end
	end)
	return true
end

return SpineLash
