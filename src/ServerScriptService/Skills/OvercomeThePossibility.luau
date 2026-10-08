-- Mandela V, Overcome the Possibility: the caster crushes their mask and
-- the zone round them, a column Radius across reaching Height above and
-- below (so it catches people in the air too), marks everyone in it. For
-- Delay seconds reality holds its breath (clients inside grey out, and a
-- ghost of each marked target stays where it stood): anyone in the zone
-- takes TickDamage every TickInterval, and anyone who comes in is marked
-- where they entered. Then it corrects itself: every marked target still
-- alive snaps back to where it was marked, takes a heavy hit (harder inside
-- the caster's Event Horizon), is left Weakened and is stunned for a moment,
-- and a flyer is knocked out of the air. A player protected by
-- CrowdControl, or who dodged (Q) after being marked, takes the hit but
-- isn't snapped back, stunned or grounded.
-- While Mandela is overcharged the cast spends what's left of the overcharge:
-- every second left adds damage, and instead of the stun giant backbones burst
-- out of the ground under the targets and throw them up. Clients draw it
-- from the SkillEffects "Possibility", "PossibilityMark" (late marks) and
-- "PossibilitySnap" events.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BlackHole = require(script.Parent:WaitForChild("BlackHole"))
local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))
local Overcharge = require(ServerScriptService:WaitForChild("Overcharge"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Radius = 34, -- studs around the caster, across
	Height = 80, -- studs above and below the caster it still reaches
	Delay = 3, -- seconds before reality snaps back
	ReleaseDelay = 0.35, -- lines the mark up with the mask crush in the cast animation
	TickInterval = 0.5, -- seconds between hits on everyone in the zone while it holds
	TickDamage = 6, -- per hit, before the caster's Superliminal bonus
	Damage = 70, -- the snap, before the caster's Superliminal bonus
	StunTime = 1.2, -- seconds frozen after the snap
	OverchargeDamagePerSecond = 4, -- extra damage per second of overcharge spent
	LaunchSpeed = 70, -- studs per second up when the backbones throw them, overcharged
	LaunchTime = 0.25,
}
local SET = SkillSetConfig.Sets.Mandela
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Mandela", critical = true }
local TICK_OPTIONS = { stat = "Superliminal", skillSet = "Mandela" }
local FLYING = "Flying" -- LuminanceServer's attribute on a flying character

local castCount = 0

local function groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -100, 0), params)
	return hit and hit.Position or position - Vector3.new(0, 3, 0)
end

local function inZone(center, position)
	local offset = position - center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= CONFIG.Radius and math.abs(offset.Y) <= CONFIG.Height
end

-- everyone alive in the zone right now (humanoid -> model)
local function inside(character, center)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local found = {}
	local box = Vector3.new(CONFIG.Radius * 2, CONFIG.Height * 2, CONFIG.Radius * 2)
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(center), box, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not found[humanoid] and humanoid.Health > 0 and not model:GetAttribute("Invulnerable") and inZone(center, root.Position) then
			found[humanoid] = model
		end
	end
	return found
end

-- frozen in place for a moment (anchored roots are left as they were)
local function stun(root)
	if root.Anchored then
		return
	end
	root.Anchored = true
	task.delay(CONFIG.StunTime, function()
		if root.Parent then
			root.Anchored = false
		end
	end)
end

local function launch(root)
	if root.Anchored then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PossibilityLaunch"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "PossibilityLaunch"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.new(0, CONFIG.LaunchSpeed, 0)
	velocity.Parent = root
	Debris:AddItem(velocity, CONFIG.LaunchTime)
	Debris:AddItem(attachment, CONFIG.LaunchTime)
end

local function run(player, character)
	task.wait(CONFIG.ReleaseDelay)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return
	end
	local secondsSpent = Overcharge.Spend(player, "Mandela")
	local overcharged = secondsSpent > 0
	local damage = CONFIG.Damage + secondsSpent * CONFIG.OverchargeDamagePerSecond
	local color = overcharged and SET.overcharge.color or SET.color
	local center = groundBelow(root.Position, { character })
	local zoneCenter = root.Position
	-- humanoid -> { humanoid, model, pivot (where to snap back to), markedAt }
	local marked = {}
	local order = {}
	local function markNew()
		local fresh = {}
		for humanoid, model in pairs(inside(character, zoneCenter)) do
			if not marked[humanoid] then
				local entry = { humanoid = humanoid, model = model, pivot = model:GetPivot(), markedAt = os.clock() }
				marked[humanoid] = entry
				table.insert(order, entry)
				table.insert(fresh, model)
			end
		end
		return fresh
	end
	castCount += 1
	local castId = castCount
	skillEffects:FireAllClients("Possibility", castId, character, center, CONFIG.Radius, CONFIG.Delay, markNew(), overcharged, color)

	-- while reality holds its breath, the zone hurts, and marks whoever comes in
	local snapAt = os.clock() + CONFIG.Delay
	while os.clock() + CONFIG.TickInterval <= snapAt + 0.01 do
		task.wait(CONFIG.TickInterval)
		local fresh = markNew()
		if #fresh > 0 then
			skillEffects:FireAllClients("PossibilityMark", castId, fresh, color)
		end
		for humanoid, model in pairs(inside(character, zoneCenter)) do
			if marked[humanoid] and model.Parent then
				Damage.Deal(player, humanoid, CONFIG.TickDamage, TICK_OPTIONS)
			end
		end
	end
	task.wait(math.max(snapAt - os.clock(), 0))

	-- reality corrects itself
	local snapped = {}
	for _, entry in ipairs(order) do
		local targetRoot = entry.humanoid.RootPart
		if entry.model.Parent and targetRoot and entry.humanoid.Health > 0 then
			-- caught inside the caster's Event Horizon, the snap hits harder
			local hitDamage = damage
			if BlackHole.Contains(player, targetRoot.Position) then
				hitDamage *= 1 + SET.links.snapInHoleBonus
			end
			local controllable = CrowdControl.CanControl(entry.model) and not CrowdControl.DodgedSince(entry.model, entry.markedAt)
			if controllable then
				-- knocked out of the air: they fall once it lets go
				if entry.model:GetAttribute(FLYING) then
					entry.model:SetAttribute(FLYING, nil)
				end
				entry.model:PivotTo(entry.pivot)
				targetRoot.AssemblyLinearVelocity = Vector3.zero
			end
			if Damage.Deal(player, entry.humanoid, hitDamage, DAMAGE_OPTIONS) > 0 then
				StatusEffects.Apply(entry.humanoid, "Weakened", { source = player, stat = "Superliminal", skillSet = "Mandela" })
			end
			table.insert(snapped, controllable and entry.pivot.Position or targetRoot.Position)
			if controllable and entry.humanoid.Health > 0 then
				if overcharged then
					launch(targetRoot)
					CrowdControl.Apply(entry.model, CONFIG.LaunchTime)
				else
					stun(targetRoot)
					CrowdControl.Apply(entry.model, CONFIG.StunTime)
				end
			end
		end
	end
	skillEffects:FireAllClients("PossibilitySnap", castId, center, CONFIG.Radius, snapped, overcharged, color)
end

local OvercomeThePossibility = {}

function OvercomeThePossibility.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid.RootPart then
		return false
	end
	task.spawn(function()
		local ok, err = pcall(run, player, character)
		if not ok then
			warn("[Skills.OvercomeThePossibility] " .. tostring(err))
		end
	end)
	return true
end

return OvercomeThePossibility
