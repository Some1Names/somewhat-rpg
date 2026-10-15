-- Mandela V, Place Where Dream Ends: the caster crushes their mask and
-- reality is overwritten round them. Their Misremembered is ready again at
-- once, and a very large shockwave (a column Radius across reaching Height
-- above and below, so it catches people in the air too) hurts everyone in it
-- a little and mutes every player it catches: no skills for MuteTime seconds.
-- It also marks up to CombatRules.MaxMarks of them (the nearest first; the
-- mark lasts until they're out of combat). A player who is already marked
-- when it hits them has the skill they use the most erased instead
-- (CombatState.EraseMostUsed): they can't cast it again until the fight is
-- over, which is when they've been out of combat for 30 seconds
-- (CombatRules). While Mandela is overcharged the wave is wider and the mute
-- longer. Clients draw it from the SkillEffects "PossibilityWave" event; the
-- marks and erased skills draw from CombatState's events.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatState = require(ServerScriptService:WaitForChild("CombatState"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Radius = 70, -- studs round the caster, across
	OverchargedRadius = 90,
	Height = 80, -- studs above and below the caster it still reaches
	ReleaseDelay = 0.35, -- lines the wave up with the mask crush in the cast animation
	Damage = 25, -- before the caster's Superliminal bonus
	MuteTime = 8, -- seconds a caught player can't cast skills
	OverchargedMuteTime = 12,
}
local SET = SkillSetConfig.Sets.Mandela
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Mandela", skill = "V" }

local function inZone(center, radius, position)
	local offset = position - center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) <= CONFIG.Height
end

-- everyone alive in the zone right now (humanoid -> model)
local function inside(character, center, radius)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local found = {}
	local box = Vector3.new(radius * 2, CONFIG.Height * 2, radius * 2)
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(center), box, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not found[humanoid] and humanoid.Health > 0 and not model:GetAttribute("Invulnerable") and inZone(center, radius, root.Position) then
			found[humanoid] = model
		end
	end
	return found
end

local function groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -100, 0), params)
	return hit and hit.Position or position - Vector3.new(0, 3, 0)
end

local function run(player, character)
	task.wait(CONFIG.ReleaseDelay)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return
	end
	local overcharged = SkillSetConfig.IsOvercharged(player, "Mandela")
	local radius = overcharged and CONFIG.OverchargedRadius or CONFIG.Radius
	local muteTime = overcharged and CONFIG.OverchargedMuteTime or CONFIG.MuteTime
	local color = overcharged and SET.overcharge.color or SET.color
	local origin = root.Position

	-- reality is rewritten: Misremembered is ready again
	player:SetAttribute(SkillSetConfig.PassiveReadyAttribute("Mandela"), 0)

	local caught = inside(character, origin, radius)
	local models = {}
	local fresh = {} -- players it caught that weren't marked yet
	for victim, model in pairs(caught) do
		table.insert(models, model)
		local victimPlayer = Players:GetPlayerFromCharacter(model)
		if victimPlayer then
			CombatState.Mute(victimPlayer, muteTime)
			if CombatState.IsMarked(victimPlayer) then
				-- hit by it a second time: the skill they lean on most is gone
				CombatState.EraseMostUsed(victimPlayer, color)
			else
				table.insert(fresh, { id = victimPlayer, distance = (victim.RootPart.Position - origin).Magnitude })
			end
		end
	end
	for _, victimPlayer in ipairs(CombatRules.PickMarks(fresh, CombatState.MarkCount(player))) do
		CombatState.Mark(player, victimPlayer, color)
	end
	skillEffects:FireAllClients("PossibilityWave", character, groundBelow(origin, { character }), radius, overcharged, color, models)
	for victim, model in pairs(caught) do
		if model.Parent then
			Damage.Deal(player, victim, CONFIG.Damage, DAMAGE_OPTIONS)
		end
	end
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
