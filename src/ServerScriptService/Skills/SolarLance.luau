-- Iridescent Requiem V, Solar Lance: after a moment's warning, a column of
-- focused sunlight slams down where Ayato aimed (up to Range away), striking
-- everyone inside it and throwing them up. The more Luminance he holds, the
-- wider and harder it hits; where the sun can't reach (indoors, under cover)
-- it's weaker still. Cast in Prism Form, it leaves a pool of burning light
-- that keeps hurting anyone standing in it and sets them Burnt, a stack a
-- second. Aimed near someone carrying the
-- caster's Sunmark (from Prism Shot or Refraction Field), it locks onto
-- them instead: almost no warning, it follows them through it, hits
-- LockedBonus harder and uses the mark up. Clients draw it from the
-- SkillEffects "SolarLanceWarning", "SolarLance" and "SolarPool" events.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))
local Sunmark = require(ServerScriptService:WaitForChild("Sunmark"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 70, -- studs from the caster
	WarningTime = 0.8, -- seconds between the warning and the strike
	MinRadius = 8, -- studs, with no Luminance
	MaxRadius = 18, -- studs, with full Luminance
	MinDamage = 40, -- before the caster's Superliminal bonus
	MaxDamage = 80,
	CoveredShare = 0.5, -- of the size and damage where sunlight can't reach
	Height = 20, -- studs above and below the ground it reaches
	LaunchSpeed = 45, -- studs per second up
	LaunchTime = 0.2,
	-- locking onto a Sunmark
	LockRadius = 18, -- studs round the aim point it looks for one
	LockedWarningTime = 0.15, -- seconds
	LockedBonus = 0.25, -- extra share of damage
	-- the pool it leaves in Prism Form
	PoolShare = 0.75, -- of the strike's radius
	PoolDuration = 4, -- seconds
	PoolInterval = 0.5, -- seconds between burns
	PoolDamage = 6, -- per target per burn, before the caster's Superliminal bonus
	PoolHeight = 6, -- studs above the ground it reaches
	PoolBurnInterval = 1, -- seconds between Burnt stacks for someone standing in it
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "IridescentRequiem", critical = true }
local POOL_OPTIONS = { stat = "Superliminal", skillSet = "IridescentRequiem" }
local LUMINANCE = SkillSetConfig.LuminanceAttribute("IridescentRequiem")

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function groundAt(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -200, 0), params)
	return hit and hit.Position
end

-- whether sunlight reaches this point (characters don't count as cover)
local function underSky(position)
	local sun = Lighting:GetSunDirection()
	if sun.Y <= 0 then
		return false
	end
	local ignore = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(position + Vector3.new(0, 2, 0), sun * 1000, params) == nil
end

local function launch(root)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SolarLanceLaunch"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "SolarLanceLaunch"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.new(0, CONFIG.LaunchSpeed, 0)
	velocity.Parent = root
	Debris:AddItem(velocity, CONFIG.LaunchTime)
	Debris:AddItem(attachment, CONFIG.LaunchTime)
end

-- the pool of light left behind, burning everyone in it every PoolInterval
local function burn(player, character, point, radius)
	skillEffects:FireAllClients("SolarPool", point, radius, CONFIG.PoolDuration)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local endsAt = os.clock() + CONFIG.PoolDuration
	local lastBurntAt = {} -- humanoid -> os.clock() of its last Burnt stack
	while os.clock() < endsAt do
		task.wait(CONFIG.PoolInterval)
		local struck = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(point, radius + CONFIG.PoolHeight, overlap)) do
			local model = part:FindFirstAncestorOfClass("Model")
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")
			local root = humanoid and humanoid.RootPart
			if root and not struck[humanoid] and humanoid.Health > 0 then
				local offset = root.Position - point
				if flat(offset).Magnitude <= radius and offset.Y >= -2 and offset.Y <= CONFIG.PoolHeight then
					struck[humanoid] = true
					local dealt = Damage.Deal(player, humanoid, CONFIG.PoolDamage, POOL_OPTIONS)
					if dealt > 0 and os.clock() - (lastBurntAt[humanoid] or -math.huge) >= CONFIG.PoolBurnInterval - 0.05 then
						lastBurntAt[humanoid] = os.clock()
						StatusEffects.Apply(humanoid, "Burnt", { source = player, stat = "Superliminal", skillSet = "IridescentRequiem" })
					end
				end
			end
		end
	end
end

-- `locked`: the Sunmarked model it's locked onto, if any
local function strike(player, character, point, inForm, locked)
	local luminance = player:GetAttribute(LUMINANCE) or 0
	local radius = CONFIG.MinRadius + (CONFIG.MaxRadius - CONFIG.MinRadius) * luminance
	local damage = CONFIG.MinDamage + (CONFIG.MaxDamage - CONFIG.MinDamage) * luminance
	if not underSky(point) then
		radius *= CONFIG.CoveredShare
		damage *= CONFIG.CoveredShare
	end
	local warning = CONFIG.WarningTime
	if locked then
		Sunmark.Consume(locked)
		damage *= 1 + CONFIG.LockedBonus
		warning = CONFIG.LockedWarningTime
	end
	skillEffects:FireAllClients("SolarLanceWarning", point, radius, warning)
	task.wait(warning)
	-- locked on, it lands wherever they went
	local lockedRoot = locked and locked.Parent and locked:FindFirstChild("HumanoidRootPart")
	if lockedRoot then
		point = groundAt(lockedRoot.Position, { character }) or point
	end
	skillEffects:FireAllClients("SolarLance", point, radius, locked ~= nil)

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local struck = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(point, radius + CONFIG.Height, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not struck[humanoid] and humanoid.Health > 0 then
			local offset = root.Position - point
			if flat(offset).Magnitude <= radius and math.abs(offset.Y) <= CONFIG.Height then
				struck[humanoid] = true
				Damage.Deal(player, humanoid, damage, DAMAGE_OPTIONS)
				if humanoid.Health > 0 and not root.Anchored and CrowdControl.CanControl(model) then
					launch(root)
					CrowdControl.Apply(model, CONFIG.LaunchTime)
				end
			end
		end
	end
	if inForm then
		burn(player, character, point, radius * CONFIG.PoolShare)
	end
end

local SolarLance = {}

-- returns false when there's no ground there, so no cooldown is spent
function SolarLance.Cast(player, character, aim)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local reach = flat(aim - root.Position)
	if reach.Magnitude > CONFIG.Range then
		reach = reach.Unit * CONFIG.Range
	end
	local point = groundAt(root.Position + reach, { character })
	if not point then
		return false
	end
	-- someone Sunmarked near where he aimed (and in range): lock onto them
	local locked = Sunmark.Nearest(player, point, CONFIG.LockRadius)
	local lockedRoot = locked and locked:FindFirstChild("HumanoidRootPart")
	if lockedRoot and flat(lockedRoot.Position - root.Position).Magnitude <= CONFIG.Range + CONFIG.LockRadius then
		point = groundAt(lockedRoot.Position, { character }) or point
	else
		locked = nil
	end
	task.spawn(function()
		local ok, err = pcall(strike, player, character, point, SkillSetConfig.InForm(character, "IridescentRequiem"), locked)
		if not ok then
			warn("[Skills.SolarLance] " .. tostring(err))
		end
	end)
	return true
end

return SolarLance
