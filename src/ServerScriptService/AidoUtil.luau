-- What every Aido blast shares (ServerScriptService.Skills: Fuse, Catastrophe,
-- Collapse, TotalDestruction, GroundZero, FinalCut, AtomicBreath): who a blast
-- hits, its damage (falling off from the centre, or flat), the Half-Life
-- passive's extra damage on someone Burnt, the Burnt it applies, the Fallout
-- patch it leaves, and the aftershocks Chain Reaction adds. His own blasts
-- never hurt him. Clients draw each blast from the SkillEffects `kind` it fires.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AidoMath = require(script.Parent:WaitForChild("AidoMath"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Overcharge = require(ServerScriptService:WaitForChild("Overcharge"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local SET_NAME = "Aido"
local SET = SkillSetConfig.Sets[SET_NAME]
local PASSIVE = SET.passive
local AFTERSHOCK = SET.aftershock
local GROUND_RAY = 70 -- studs down from above a spot to look for ground
local GROUND_RISE = 10 -- studs above a spot the ground search starts
local FALLOUT_TICK = 1 -- seconds between Burnt stacks from a Fallout patch

local AidoUtil = {}

local nextFalloutId = 0

-- everyone alive but `character` whose root is within `radius` of `centre`
-- (a sphere): { { model, humanoid, root } }
function AidoUtil.enemiesWithin(character, centre, radius)
	local found, seen = {}, {}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	for _, part in ipairs(workspace:GetPartBoundsInRadius(centre, radius, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not seen[model] then
			seen[model] = true
			if humanoid.Health > 0 and not model:GetAttribute("Invulnerable") and (root.Position - centre).Magnitude <= radius then
				table.insert(found, { model = model, humanoid = humanoid, root = root })
			end
		end
	end
	return found
end

-- the ground under `position` (past characters and the effects folder); the
-- position itself when there is none
function AidoUtil.groundAt(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local skip = table.clone(ignore or {})
	local effects = workspace:FindFirstChild("SkillEffects")
	if effects then
		table.insert(skip, effects)
	end
	local from = position + Vector3.new(0, GROUND_RISE, 0)
	for _ = 1, 6 do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(from, Vector3.new(0, -(GROUND_RAY + GROUND_RISE), 0), params)
		if not hit then
			return position
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			return hit.Position
		end
		table.insert(skip, model)
	end
	return position
end

-- `aim` pulled to at most `range` studs from `origin`, flat, at origin's height
function AidoUtil.clampFlat(origin, aim, range)
	local offset = Vector3.new(aim.X - origin.X, 0, aim.Z - origin.Z)
	if offset.Magnitude > range then
		offset = offset.Unit * range
	end
	return origin + offset
end

-- a patch of Fallout: for `duration` seconds, one Burnt stack a second to
-- everyone inside (so a patch never gives more than one stack a second, and
-- Burnt's own maxStacks caps overlapping ones)
function AidoUtil.fallout(player, character, centre, radius, duration)
	nextFalloutId += 1
	local id = nextFalloutId
	skillEffects:FireAllClients("Fallout", id, centre, radius, duration)
	task.spawn(function()
		local ticks = math.floor(duration / FALLOUT_TICK + 1e-6)
		for _ = 1, ticks do
			task.wait(FALLOUT_TICK)
			for _, target in ipairs(AidoUtil.enemiesWithin(character, centre, radius)) do
				StatusEffects.Apply(target.humanoid, "Burnt", { source = player.Parent and player or nil, stat = "Superliminal", skillSet = SET_NAME })
			end
		end
		skillEffects:FireAllClients("FalloutEnd", id)
	end)
end

local function scheduleAftershocks(player, character, centre, radius, spec)
	task.delay(AFTERSHOCK.delay, function()
		for _, point in ipairs(AidoMath.scatter(centre, radius * AFTERSHOCK.spread, AFTERSHOCK.count, math.random)) do
			AidoUtil.blast(player, character, point, {
				radius = AFTERSHOCK.radius,
				damage = spec.damage * AFTERSHOCK.share,
				fallout = false,
				aftershocks = false,
				noBonus = true,
				skill = spec.skill,
				guard = spec.guard,
				kind = "Aftershock",
			})
		end
	end)
end

-- One blast at `centre`. spec: radius, damage (and edgeDamage to fall off to
-- at the edge), burnt (stacks), fallout (a { radius, duration } of its own, or
-- false for none; default the passive's), aftershocks (set them off while
-- Chain Reaction is on), form (wider in Final Cut), struck + maxHits (a table
-- shared by one cast that counts hits per humanoid and stops at maxHits),
-- noBonus (no Half-Life bonus), skill and guard (for Damage.Deal), kind (the
-- SkillEffects event, fired with the centre and radius). Returns damage dealt
-- per humanoid.
function AidoUtil.blast(player, character, centre, spec)
	if not player.Parent then
		return {}
	end
	local radius = spec.radius
	if spec.form and SkillSetConfig.InForm(character, SET_NAME) then
		radius *= SET.form.blastScale
	end
	local passiveOn = SkillSetConfig.FeatureUnlocked(player, SET_NAME, "passive")
	local options = { stat = "Superliminal", skillSet = SET_NAME, skill = spec.skill, guard = spec.guard }
	local dealt = {}
	for _, target in ipairs(AidoUtil.enemiesWithin(character, centre, radius)) do
		local humanoid = target.humanoid
		local hits = spec.struck and spec.struck[humanoid] or 0
		if not (spec.maxHits and hits >= spec.maxHits) then
			if spec.struck then
				spec.struck[humanoid] = hits + 1
			end
			local amount = spec.damage
			if spec.edgeDamage then
				amount = AidoMath.falloff((target.root.Position - centre).Magnitude, radius, spec.damage, spec.edgeDamage)
			end
			-- already Burnt before this blast's own Burnt
			if passiveOn and not spec.noBonus and StatusEffects.Has(humanoid, "Burnt") then
				amount *= 1 + PASSIVE.burntBonus
			end
			local taken = Damage.Deal(player, humanoid, amount, options)
			dealt[humanoid] = taken
			if spec.burnt and taken > 0 then
				StatusEffects.Apply(humanoid, "Burnt", { source = player, stat = "Superliminal", skillSet = SET_NAME, stacks = spec.burnt })
			end
		end
	end
	if spec.fallout ~= false and passiveOn then
		local patch = spec.fallout or { radius = PASSIVE.falloutRadius, duration = PASSIVE.falloutDuration }
		AidoUtil.fallout(player, character, centre, patch.radius, patch.duration)
	end
	if spec.aftershocks and player.Parent and Overcharge.IsActive(player, SET_NAME) then
		scheduleAftershocks(player, character, centre, radius, spec)
	end
	skillEffects:FireAllClients(spec.kind, centre, radius)
	return dealt
end

return AidoUtil
