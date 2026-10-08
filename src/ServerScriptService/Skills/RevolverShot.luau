-- The Revolver's own shot (its left click): one bullet the way the client
-- aimed it, steering into `target` when aim assist locked it on.
-- RangedServer has already checked it and taken a round.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local CONFIG = {
	Damage = 20, -- before the shooter's Firearm bonus
}
local DAMAGE_OPTIONS = { stat = "Firearm", skillSet = "Revolver", melee = true }
local FLIGHT = SkillSetConfig.Sets.Revolver.ranged.projectile

local RevolverShot = {}

function RevolverShot.Fire(player, character, origin, direction, id, target)
	Projectiles.Launch({
		owner = player,
		character = character,
		id = id,
		model = FLIGHT.model,
		origin = origin,
		direction = direction,
		speed = FLIGHT.speed,
		range = FLIGHT.range,
		radius = FLIGHT.radius,
		flash = FLIGHT.flash,
		homing = target and target.RootPart,
		onHit = function(humanoid)
			Damage.Deal(player, humanoid, CONFIG.Damage, DAMAGE_OPTIONS)
		end,
	})
end

return RevolverShot
