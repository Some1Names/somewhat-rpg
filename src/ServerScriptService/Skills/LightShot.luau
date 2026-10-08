-- Iridescent Requiem's ranged move, Light Shot: a shot of light straight to
-- where he aimed (or at whoever aim assist locked onto), there at once,
-- stopped by the first person or wall. Fired at Photoshop inside her own
-- Kaleidoscope, it bounces back (Kaleidoscope.Reflect). RangedServer has
-- already checked it, pointed it and taken its Luminance. Other clients draw
-- it from the SkillEffects "LightShot" event (the shooter drew his own).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Kaleidoscope = require(ServerScriptService:WaitForChild("Skills"):WaitForChild("Kaleidoscope"))
local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Damage = 8, -- before the shooter's Superliminal bonus
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "IridescentRequiem" }
local RANGE = SkillSetConfig.Sets.IridescentRequiem.ranged.beam.range

local LightShot = {}

function LightShot.Fire(player, character, origin, direction)
	local hit, humanoid = Projectiles.Cast(origin, direction * RANGE, { character })
	local finish = hit and hit.Position or origin + direction * RANGE
	if humanoid and not Kaleidoscope.Reflect(humanoid, character, CONFIG.Damage) then
		Damage.Deal(player, humanoid, CONFIG.Damage, DAMAGE_OPTIONS)
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			skillEffects:FireClient(other, "LightShot", origin, finish, humanoid ~= nil)
		end
	end
end

return LightShot
