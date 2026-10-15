-- Aido V, Ground Zero: a circle marked at the aim point with a countdown every
-- player can see, then the nuke: damage falling off from the centre to the
-- edge, Burnt, and a big Fallout field. It goes off even if Aido dies or puts
-- the set away during the countdown (the damage is still his); only him
-- leaving the game stops it. In Final Cut the circle is wider (set when it's
-- marked, so what players saw is what hits). SkillSetServer checks the tool,
-- mastery and cooldown before calling Cast.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AidoUtil = require(ServerScriptService:WaitForChild("AidoUtil"))
local Quests = require(ServerScriptService:WaitForChild("Quests"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local SET_NAME = "Aido"
local CONFIG = {
	Range = 80, -- studs from the caster
	Radius = 40, -- studs (times the form's blastScale)
	Countdown = 3, -- seconds
	Damage = 110, -- at the centre, before the caster's Superliminal bonus
	EdgeDamage = 40, -- at the edge
	Burnt = 2, -- stacks
	FalloutRadius = 30,
	FalloutDuration = 6,
}

local GroundZero = {}

function GroundZero.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	local centre = AidoUtil.groundAt(AidoUtil.clampFlat(root.Position, aim, CONFIG.Range), { character })
	local radius = CONFIG.Radius
	if SkillSetConfig.InForm(character, SET_NAME) then
		radius *= SkillSetConfig.Sets[SET_NAME].form.blastScale
	end
	skillEffects:FireAllClients("GroundZeroCountdown", HttpService:GenerateGUID(false), centre, radius, CONFIG.Countdown)
	task.delay(CONFIG.Countdown, function()
		local dealt = AidoUtil.blast(player, character, centre, {
			radius = radius,
			damage = CONFIG.Damage,
			edgeDamage = CONFIG.EdgeDamage,
			burnt = CONFIG.Burnt,
			fallout = { radius = CONFIG.FalloutRadius, duration = CONFIG.FalloutDuration },
			aftershocks = true,
			skill = "V",
			kind = "GroundZeroBlast",
		})
		local hits = 0
		for _, taken in pairs(dealt) do
			if taken > 0 then
				hits += 1
			end
		end
		if player.Parent then
			Quests.Report(player, SET_NAME, "GroundZeroHits", hits)
		end
	end)
	return true
end

return GroundZero
