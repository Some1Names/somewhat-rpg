-- Iridescent Requiem F, in two sizes picked by the Luminance it's cast with
-- (SkillSetConfig's F: name / fullName).
--   Below the Stratus (anything short of full): Ayato bursts up into the sky
--   with his Luminance filled and hovers (the Flying attribute) under a sheet
--   of cloud, and for RainTime seconds prismatic rays rain down on up to
--   RaysPerVolley people within Radius of where he rose, every RainInterval.
--   Above the Cumulonimbus (full Luminance): bigger and higher, under a
--   towering storm cloud, and instead of rays, columns of sunlight like
--   Solar Lance's slam down on up to LancesPerVolley people every
--   LanceInterval, hurting everyone within LanceRadius of each; on someone
--   carrying his Sunmark a column hits MarkedBonus harder (the mark isn't
--   used up). It ends in a sun-burst that hurts everyone in the Radius and
--   spends all his Luminance (so his flight ends with it).
-- Clients draw the clouds from the SkillEffects "SkyVeil" event, the rays
-- from "PrismRays", the columns from "SkyLances" and the finale from
-- "SunBurst".
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Sunmark = require(ServerScriptService:WaitForChild("Sunmark"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local VERSIONS = {
	stratus = {
		RiseSpeed = 60, -- studs per second
		RiseTime = 0.4, -- seconds (about 24 studs up)
		Radius = 30, -- studs around where he rose (SkillSetConfig's aim shows the same)
		RainTime = 2.5, -- seconds
		RainInterval = 0.2,
		RaysPerVolley = 2,
		RayDamage = 11, -- before the caster's Superliminal bonus
	},
	cumulonimbus = {
		RiseSpeed = 100,
		RiseTime = 0.6, -- about 60 studs up
		Radius = 60, -- (SkillSetConfig's fullAim)
		RainTime = 4,
		LanceInterval = 0.4, -- seconds between volleys of columns
		LancesPerVolley = 5,
		LanceDamage = 36, -- before the caster's Superliminal bonus
		LanceRadius = 8, -- studs round each column it hurts
		LanceHeight = 12, -- studs above and below the ground it reaches
		MarkedBonus = 0.75, -- extra share on a Sunmarked target
		BurstDamage = 40, -- the finale, to everyone in the Radius
	},
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "IridescentRequiem" }
local LANCE_OPTIONS = { stat = "Superliminal", skillSet = "IridescentRequiem" }
local MARKED_LANCE_OPTIONS = { stat = "Superliminal", skillSet = "IridescentRequiem", critical = true }
local BURST_OPTIONS = { stat = "Superliminal", skillSet = "IridescentRequiem", critical = true }
local SET_NAME = "IridescentRequiem"
local LUMINANCE = SkillSetConfig.LuminanceAttribute(SET_NAME)

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function groundAt(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position or position - Vector3.new(0, 3, 0)
end

local function rise(root, config)
	local attachment = Instance.new("Attachment")
	attachment.Name = "AboveTheClouds"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "AboveTheClouds"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.new(0, config.RiseSpeed, 0)
	velocity.Parent = root
	Debris:AddItem(velocity, config.RiseTime)
	Debris:AddItem(attachment, config.RiseTime)
end

-- everyone (not the caster) within the radius of the spot, in a random order
local function below(character, center, radius)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local found, seen = {}, {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius + 30, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not seen[humanoid] and humanoid.Health > 0 and flat(root.Position - center).Magnitude <= radius then
			seen[humanoid] = true
			table.insert(found, { humanoid = humanoid, root = root, order = math.random() })
		end
	end
	table.sort(found, function(a, b)
		return a.order < b.order
	end)
	return found
end

-- one volley of the storm cloud's columns: one on each of up to
-- LancesPerVolley people, each hurting everyone near it (once a volley);
-- returns what the clients draw, { point, marked } per column
local function lanceVolley(player, character, center, config)
	local strikes = {}
	local struck = {}
	local targets = below(character, center, config.Radius)
	for i, target in ipairs(targets) do
		if i > config.LancesPerVolley then
			break
		end
		local point = groundAt(target.root.Position, { character, target.humanoid.Parent })
		local marked = Sunmark.Has(player, target.humanoid.Parent)
		table.insert(strikes, { point = point, marked = marked })
		for _, other in ipairs(targets) do
			local offset = other.root.Position - point
			if not struck[other.humanoid] and flat(offset).Magnitude <= config.LanceRadius and math.abs(offset.Y) <= config.LanceHeight then
				struck[other.humanoid] = true
				local onMark = Sunmark.Has(player, other.humanoid.Parent)
				local damage = config.LanceDamage * (onMark and 1 + config.MarkedBonus or 1)
				Damage.Deal(player, other.humanoid, damage, onMark and MARKED_LANCE_OPTIONS or LANCE_OPTIONS)
			end
		end
	end
	-- with nobody there a column still strikes somewhere below
	if #strikes == 0 then
		local a = math.random() * math.pi * 2
		local d = math.random() * config.Radius
		table.insert(strikes, { point = groundAt(center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), { character }), marked = false })
	end
	return strikes
end

local function ascend(player, character, root, variant)
	local config = VERSIONS[variant]
	local center = root.Position
	if variant == "stratus" then
		player:SetAttribute(LUMINANCE, 1)
	end
	rise(root, config)
	skillEffects:FireAllClients("SkyVeil", center, config.RiseSpeed * config.RiseTime, config.Radius, variant, config.RiseTime + config.RainTime)
	task.wait(config.RiseTime)
	-- hovering up there now
	local _, setName = SkillSetConfig.Equipped(character)
	if setName == SET_NAME and character.Parent then
		character:SetAttribute("Flying", true)
	end
	local startedAt = os.clock()
	-- the storm cloud: columns of sunlight
	while variant == "cumulonimbus" and os.clock() - startedAt < config.RainTime and character.Parent and root.Parent do
		skillEffects:FireAllClients("SkyLances", root.Position, lanceVolley(player, character, center, config))
		task.wait(config.LanceInterval)
	end
	-- the stratus: a rain of rays
	while variant == "stratus" and os.clock() - startedAt < config.RainTime and character.Parent and root.Parent do
		local rays = {}
		for i, target in ipairs(below(character, center, config.Radius)) do
			if i > config.RaysPerVolley then
				break
			end
			Damage.Deal(player, target.humanoid, config.RayDamage, DAMAGE_OPTIONS)
			table.insert(rays, target.root.Position)
		end
		-- with nobody there it still lights up the ground
		if #rays == 0 then
			local a = math.random() * math.pi * 2
			local d = math.random() * config.Radius
			table.insert(rays, center + Vector3.new(math.cos(a) * d, -3, math.sin(a) * d))
		end
		skillEffects:FireAllClients("PrismRays", root.Position, rays, variant)
		task.wait(config.RainInterval)
	end

	-- the storm cloud's finale: the sun bursts out, spending all the light
	if variant == "cumulonimbus" and character.Parent and root.Parent then
		local struck = {}
		for _, target in ipairs(below(character, center, config.Radius)) do
			Damage.Deal(player, target.humanoid, config.BurstDamage, BURST_OPTIONS)
			table.insert(struck, target.root.Position)
		end
		skillEffects:FireAllClients("SunBurst", root.Position, center, config.Radius, struck, character)
		player:SetAttribute(LUMINANCE, 0)
	end
end

local AboveTheClouds = {}

function AboveTheClouds.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	local full = (player:GetAttribute(LUMINANCE) or 0) >= SkillSetConfig.FullLuminance
	task.spawn(function()
		local ok, err = pcall(ascend, player, character, root, full and "cumulonimbus" or "stratus")
		if not ok then
			warn("[Skills.AboveTheClouds] " .. tostring(err))
		end
	end)
	return true
end

return AboveTheClouds
