-- Things that fly (thrown knives, bullets), server side. Launch steps one
-- along its path every frame, sweeping a ball ahead of it, and stops it at
-- the first living character (calling onHit) or solid part. Clients draw
-- their own copy from the SkillEffects "Projectile" event and stop it on
-- "ProjectileEnd". Cast is the instant version, for shots of light. A shot
-- locked onto someone (aim assist) steers toward them every step.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local SEE_THROUGH = 0.95 -- parts at least this transparent don't stop anything
local MAX_PASSES = 8 -- things one cast may pass through before giving up

local Projectiles = {}

-- the character a part belongs to (through any models it's nested in)
local function humanoidOf(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid, model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

-- The first living character or solid part from `from` along `offset`
-- (sweeping a ball of `radius`, if given), passing through `ignore`, dead
-- bodies, see-through parts and parts nothing collides with. Returns the
-- RaycastResult and the Humanoid it found, if any.
function Projectiles.Cast(from, offset, ignore, radius)
	local list = table.clone(ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, MAX_PASSES do
		params.FilterDescendantsInstances = list
		local hit
		if radius and radius > 0 then
			hit = workspace:Spherecast(from, radius, offset, params)
		else
			hit = workspace:Raycast(from, offset, params)
		end
		if not hit then
			return nil, nil
		end
		local humanoid, model = humanoidOf(hit.Instance)
		if humanoid then
			if humanoid.Health > 0 then
				return hit, humanoid
			end
			table.insert(list, model)
		elseif hit.Instance.CanCollide and hit.Instance.Transparency < SEE_THROUGH then
			return hit, nil
		else
			table.insert(list, hit.Instance)
		end
	end
	return nil, nil
end

-- Options: owner (Player) and character (the shooter, never hit); id (the
-- name the shooter's client drew its own copy under); model (a
-- ReplicatedStorage.ProjectileModels piece), origin, direction (unit),
-- speed, range, radius; spin and flash (how clients draw it);
-- drawForOwner (a skill's shot, which the owner's client hasn't drawn);
-- homing (a BasePart it turns toward every step while it's there: the
-- root of the character the shot is locked onto); onHit (function(humanoid,
-- position)).
function Projectiles.Launch(options)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= options.owner or options.drawForOwner then
			skillEffects:FireClient(
				other,
				"Projectile",
				options.id,
				options.model,
				options.origin,
				options.direction,
				options.speed,
				options.range,
				options.spin,
				options.flash,
				options.homing
			)
		end
	end
	task.spawn(function()
		local ignore = { options.character }
		local position = options.origin
		local direction = options.direction
		local homing = options.homing
		local travelled = 0
		local stoppedAt, struck
		while travelled < options.range do
			local step = math.min(options.speed * RunService.Heartbeat:Wait(), options.range - travelled)
			if homing and homing.Parent then
				local toward = homing.Position - position
				if toward.Magnitude > 0.1 then
					direction = toward.Unit
				end
			end
			local hit, humanoid = Projectiles.Cast(position, direction * step, ignore, options.radius)
			if hit then
				stoppedAt = position + direction * hit.Distance
				struck = humanoid
				break
			end
			position += direction * step
			travelled += step
		end
		stoppedAt = stoppedAt or position
		if struck and options.onHit then
			local ok, err = pcall(options.onHit, struck, stoppedAt)
			if not ok then
				warn("[Projectiles] " .. tostring(err))
			end
		end
		skillEffects:FireAllClients("ProjectileEnd", options.id, stoppedAt, struck ~= nil)
	end)
end

return Projectiles
