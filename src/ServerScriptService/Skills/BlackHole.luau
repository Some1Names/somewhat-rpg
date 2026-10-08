-- Mandela X, Event Horizon (the green black hole): an orb flies from the caster's left hand to
-- where they aimed and opens into a black hole that pulls in and damages every
-- character in range except the caster, then collapses. A player is only
-- dragged for CrowdControl's MaxHold (or until they dodge), then left to get
-- out of it on their own feet while it keeps hurting them. Pressing X again
-- while it's open detonates it (Recast): it collapses at once, dealing the
-- damage it had left in one hit and throwing everyone in reach outward.
-- While Mandela is overcharged it's the red black hole instead: bigger,
-- longer, stronger. Someone flying (Iridescent Requiem) is hurt but never
-- dragged or thrown: light outruns the pull. SkillSetServer checks the
-- tool, mastery and cooldown before calling Cast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Overcharge = require(ServerScriptService:WaitForChild("Overcharge"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	MaxRange = 60, -- studs from the caster
	GrowTime = 0.4, -- seconds to grow in and to shrink out
	CollapseTime = 0.25, -- seconds the model stays after the pull ends so clients can play the collapse burst
	DamageInterval = 0.5, -- seconds between damage ticks
	OrbSpeed = 90, -- studs per second from the hand to where it opens
	MinTravelTime = 0.25,
	MaxTravelTime = 0.7,
	DetonateDamageShare = 1, -- of the damage it had left, dealt at once
	DetonateFlingSpeed = 70, -- studs per second outward
	DetonateFlingLift = 35,
	DetonateFlingTime = 0.3,
}
local DETONATE_ATTRIBUTE = SkillSetConfig.RecastAttribute("Mandela", "X") -- on the player, for the skill bar
local BURST_COLORS = {
	normal = SkillSetConfig.Sets.Mandela.color,
	overcharged = SkillSetConfig.Sets.Mandela.overcharge.color,
}

local active = {} -- caster -> { detonate } while their black hole is open

local assets = ServerStorage:WaitForChild("SkillSets"):WaitForChild("Mandela")
-- what changes between the normal and the overcharged black hole
local VARIANTS = {
	normal = {
		template = assets:WaitForChild("BlackHole"),
		scale = 1, -- of the template's size
		hoverHeight = 6, -- studs above the ground
		duration = 4, -- seconds, once it opens
		radius = 30, -- pull and damage radius in studs
		maxPullSpeed = 50, -- studs per second
		damagePerSecond = 15, -- before the caster's Superliminal bonus
	},
	overcharged = {
		template = assets:WaitForChild("BlackHoleOvercharged"),
		scale = 1.6,
		hoverHeight = 9,
		duration = 5,
		radius = 48,
		maxPullSpeed = 75,
		damagePerSecond = 27,
	},
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Mandela" }
local START_SCALE_FRACTION = 0.05
local TRAIL_COLORS = {
	normal = ColorSequence.new(Color3.fromRGB(150, 255, 190), Color3.fromRGB(20, 80, 40)),
	overcharged = ColorSequence.new(Color3.fromRGB(255, 150, 150), Color3.fromRGB(90, 10, 20)),
}

-- The client only says where it aimed; the server clamps the range and
-- finds the ground itself.
local function findCastCenter(character, origin, aim, hoverHeight)
	local flat = Vector3.new(aim.X - origin.X, 0, aim.Z - origin.Z)
	if flat.Magnitude > CONFIG.MaxRange then
		flat = flat.Unit * CONFIG.MaxRange
	end
	local top = math.min(math.max(origin.Y, aim.Y), origin.Y + CONFIG.MaxRange) + 20
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(
		Vector3.new(origin.X + flat.X, top, origin.Z + flat.Z),
		Vector3.new(0, -(top - origin.Y) - 200, 0),
		params
	)
	return hit and hit.Position + Vector3.new(0, hoverHeight, 0)
end

local function findTargets(center, radius, overlap)
	local targets = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, overlap)) do
		local character = part:FindFirstAncestorOfClass("Model")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and not targets[humanoid] and humanoid.Health > 0 then
			local root = humanoid.RootPart
			if root and (root.Position - center).Magnitude <= radius then
				targets[humanoid] = root
			end
		end
	end
	return targets
end

-- Faster toward the center, easing off at the very middle so targets
-- settle there instead of overshooting.
local function pullVelocity(toCenter, variant)
	local distance = toCenter.Magnitude
	if distance < 0.05 then
		return Vector3.zero
	end
	local closeness = 1 - math.min(distance / variant.radius, 1)
	local speed = math.min(variant.maxPullSpeed * (0.35 + 0.65 * closeness), distance * 4)
	return toCenter.Unit * speed
end

local function attachPull(root, trailColor)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BlackHolePull"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "BlackHolePull"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	-- a hold a player can dodge out of: their client lets go of it at once (Dash)
	velocity:SetAttribute("Hold", true)
	velocity.Parent = root

	local trailTop = Instance.new("Attachment")
	trailTop.Name = "BlackHoleTrailTop"
	trailTop.Position = Vector3.new(0, 1.5, 0)
	trailTop.Parent = root
	local trailBottom = Instance.new("Attachment")
	trailBottom.Name = "BlackHoleTrailBottom"
	trailBottom.Position = Vector3.new(0, -1.5, 0)
	trailBottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "BlackHoleTrail"
	trail.Attachment0 = trailTop
	trail.Attachment1 = trailBottom
	trail.Color = trailColor
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.35
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Parent = root

	return {
		attachment = attachment,
		velocity = velocity,
		trailTop = trailTop,
		trailBottom = trailBottom,
		trail = trail,
	}
end

local function releasePull(pull)
	for _, instance in pairs(pull) do
		instance:Destroy()
	end
end

local function fling(root, from)
	local flat = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	local outward = flat.Magnitude > 0.1 and flat.Unit or Vector3.xAxis
	local attachment = Instance.new("Attachment")
	attachment.Name = "BlackHoleFling"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "BlackHoleFling"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = outward * CONFIG.DetonateFlingSpeed + Vector3.new(0, CONFIG.DetonateFlingLift, 0)
	velocity.Parent = root
	task.delay(CONFIG.DetonateFlingTime, function()
		velocity:Destroy()
		attachment:Destroy()
	end)
end

-- in flight (LuminanceServer's Flying attribute): it can't hold them
local function flying(model)
	return model ~= nil and model:GetAttribute("Flying") == true
end

-- collapses early: everything it would still have dealt, at once, and
-- everyone in reach thrown clear (those it was holding, or anyone not
-- protected by CrowdControl); returns who it threw
local function detonate(caster, model, center, variant, variantName, timeLeft, overlap, held)
	-- clients play their collapse now
	model:SetAttribute("Duration", workspace:GetServerTimeNow() - model:GetAttribute("StartedAt"))
	local ground = Vector3.new(center.X, center.Y - variant.hoverHeight, center.Z)
	skillEffects:FireAllClients("Shockwave", ground, variant.radius * 0.7, BURST_COLORS[variantName])
	local damage = variant.damagePerSecond * timeLeft * CONFIG.DetonateDamageShare
	local thrown = {}
	for humanoid, root in pairs(findTargets(center, variant.radius, overlap)) do
		Damage.Deal(caster, humanoid, damage, DAMAGE_OPTIONS)
		local target = humanoid.Parent
		if root.Parent and not root.Anchored and not flying(target) and (held[humanoid] or CrowdControl.CanControl(target)) then
			fling(root, center)
			CrowdControl.Apply(target, CONFIG.DetonateFlingTime)
			thrown[humanoid] = true
		end
	end
	return thrown
end

local function runBlackHole(caster, casterCharacter, center, launchFrom, travelTime, variantName)
	local variant = VARIANTS[variantName]
	local model = variant.template:Clone()
	local fullScale = model:GetScale() * variant.scale
	model:PivotTo(CFrame.new(center))
	model:ScaleTo(fullScale * START_SCALE_FRACTION)
	model:SetAttribute("FullScale", fullScale)
	model:SetAttribute("Duration", variant.duration)
	model:SetAttribute("GrowTime", CONFIG.GrowTime)
	model:SetAttribute("GroundY", center.Y - variant.hoverHeight)
	model:SetAttribute("Radius", variant.radius)
	model:SetAttribute("CasterUserId", caster.UserId)
	-- clients fly an orb from the hand until StartedAt, then open the black hole
	model:SetAttribute("StartedAt", workspace:GetServerTimeNow() + travelTime)
	model:SetAttribute("LaunchFrom", launchFrom)
	model:SetAttribute("TravelTime", travelTime)
	model.Parent = workspace
	task.wait(travelTime)

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { model, casterCharacter }

	local pulls = {}
	local state = { detonate = false, center = center, radius = variant.radius }
	active[caster] = state
	caster:SetAttribute(DETONATE_ATTRIBUTE, true)
	local timeLeft = 0
	local ok, err = pcall(function()
		local startedAt = os.clock()
		local nextDamageAt = startedAt + CONFIG.DamageInterval
		while true do
			local targets = findTargets(center, variant.radius, overlap)
			-- let go of anyone out of reach, and of players whose hold is up
			-- (CrowdControl.MaxHold, or they dodged out)
			for humanoid, pull in pairs(pulls) do
				if not targets[humanoid] or not CrowdControl.Holding(humanoid.Parent) or flying(humanoid.Parent) then
					releasePull(pull)
					pulls[humanoid] = nil
					CrowdControl.End(humanoid.Parent)
				end
			end
			-- everyone in reach is hurt; only those not protected are dragged
			for humanoid, root in pairs(targets) do
				if not pulls[humanoid] and not flying(humanoid.Parent) and CrowdControl.CanControl(humanoid.Parent) then
					pulls[humanoid] = attachPull(root, TRAIL_COLORS[variantName])
					CrowdControl.Begin(humanoid.Parent)
				end
				if pulls[humanoid] then
					pulls[humanoid].velocity.VectorVelocity = pullVelocity(center - root.Position, variant)
				end
			end
			if os.clock() >= nextDamageAt then
				nextDamageAt += CONFIG.DamageInterval
				for humanoid in pairs(targets) do
					Damage.Deal(caster, humanoid, variant.damagePerSecond * CONFIG.DamageInterval, DAMAGE_OPTIONS)
				end
			end
			-- checked after damage so the tick that lands exactly at the end still counts
			if os.clock() - startedAt >= variant.duration then
				break
			end
			if state.detonate then
				timeLeft = variant.duration - (os.clock() - startedAt)
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
	local held = {}
	for humanoid, pull in pairs(pulls) do
		releasePull(pull)
		held[humanoid] = true
	end
	active[caster] = nil
	if caster.Parent then
		caster:SetAttribute(DETONATE_ATTRIBUTE, nil)
	end
	local thrown = {}
	if ok and state.detonate and timeLeft > 0 then
		thrown = detonate(caster, model, center, VARIANTS[variantName], variantName, timeLeft, overlap, held)
	end
	-- whoever it let go of can't be grabbed again for a moment
	for humanoid in pairs(held) do
		if not thrown[humanoid] then
			CrowdControl.End(humanoid.Parent)
		end
	end
	task.wait(CONFIG.CollapseTime)
	model:Destroy()
	if not ok then
		warn("[Skills.BlackHole] " .. tostring(err))
	end
end

local BlackHole = {}

-- whether `position` is inside the player's open black hole (Overcome the
-- Possibility hits harder there)
function BlackHole.Contains(player, position)
	local state = active[player]
	return state ~= nil and (position - state.center).Magnitude <= state.radius
end

-- X again while it's open
function BlackHole.Recast(player)
	local state = active[player]
	if state then
		state.detonate = true
	end
end

-- returns false when there's nowhere to put it, so no cooldown is spent
function BlackHole.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root then
		return false
	end
	local variantName = Overcharge.IsActive(player, "Mandela") and "overcharged" or "normal"
	local center = findCastCenter(character, root.Position, aim, VARIANTS[variantName].hoverHeight)
	if not center then
		return false
	end
	local hand = character:FindFirstChild("LeftHand") or root
	local launchFrom = hand.Position
	local travelTime = math.clamp((center - launchFrom).Magnitude / CONFIG.OrbSpeed, CONFIG.MinTravelTime, CONFIG.MaxTravelTime)
	task.spawn(runBlackHole, player, character, center, launchFrom, travelTime, variantName)
	return true
end

return BlackHole
