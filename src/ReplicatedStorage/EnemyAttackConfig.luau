-- Enemy attack types (tests/CombatFeel.spec.luau): a quick swing and a slow,
-- harder heavy one. EnemyAI picks one per swing and tells the clients to draw a
-- warning for the wind-up (SkillEffects "Telegraph"; `color` is the placeholder's).
-- A heavy wind-up can't be staggered out of, so it has to be dodged.
local Color3 = Color3 or require("@lune/roblox").Color3

local EnemyAttackConfig = {}

EnemyAttackConfig.Types = {
	quick = { windUp = 0.35, damage = 1, uninterruptible = false, color = Color3.new(1, 1, 1) },
	heavy = { windUp = 0.8, damage = 1.8, uninterruptible = true, color = Color3.fromRGB(255, 60, 50) },
}
-- the chance a swing is heavy; a model's HeavyChance attribute overrides it
EnemyAttackConfig.HeavyChance = 0.25

function EnemyAttackConfig.Get(name)
	return EnemyAttackConfig.Types[name]
end

-- a model's HeavyChance attribute as a chance from 0 to 1 (the default if it isn't a number)
function EnemyAttackConfig.Chance(value)
	if typeof(value) ~= "number" or value ~= value then
		return EnemyAttackConfig.HeavyChance
	end
	return math.clamp(value, 0, 1)
end

-- which attack to swing, given a random `roll` from 0 to 1: never two heavies in a row
function EnemyAttackConfig.Choose(roll, chance, lastWasHeavy)
	if not lastWasHeavy and roll < chance then
		return "heavy"
	end
	return "quick"
end

return EnemyAttackConfig
