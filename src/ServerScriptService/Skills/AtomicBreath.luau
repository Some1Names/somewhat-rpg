-- Aido's ranged move in Final Cut, Atomic Breath: a beam straight to where he
-- aimed, there at once, stopped by the first person or wall. Held left click
-- repeats it; it costs nothing (a ranged move with no cost field is free).
-- RangedServer has already checked it. Other clients draw it from the
-- SkillEffects "AtomicBreath" event (the shooter drew his own).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Damage = 8, -- before the shooter's Superliminal bonus
	Burnt = 1, -- stacks per hit
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Aido", guard = "ranged", skill = "ranged" }
local RANGE = SkillSetConfig.Sets.Aido.form.ranged.beam.range

local AtomicBreath = {}

function AtomicBreath.Fire(player, character, origin, direction)
	local hit, humanoid = Projectiles.Cast(origin, direction * RANGE, { character })
	local finish = hit and hit.Position or origin + direction * RANGE
	if humanoid and Damage.Deal(player, humanoid, CONFIG.Damage, DAMAGE_OPTIONS) > 0 then
		StatusEffects.Apply(humanoid, "Burnt", { source = player, stat = "Superliminal", skillSet = "Aido", stacks = CONFIG.Burnt })
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			skillEffects:FireClient(other, "AtomicBreath", origin, finish, humanoid ~= nil)
		end
	end
end

return AtomicBreath
