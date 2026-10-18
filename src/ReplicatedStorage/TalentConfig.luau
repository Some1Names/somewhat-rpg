-- Talents: perks picked from a pool. A talent's tier opens once its stat has
-- that many points (Tiers); equipping costs talent points (1 per LevelsPerPoint
-- levels, see BuildRules). Numbers only: BuildRules combines them by `kind`
-- and the systems that care (Damage, Guard, StatusEffects, PlayerStats,
-- Stamina) read the result.
local TalentConfig = {}

TalentConfig.Tiers = { 15, 30, 50 }
TalentConfig.LevelsPerPoint = 5
TalentConfig.SaveAttribute = "Talents" -- the equipped keys, comma-separated
TalentConfig.MaxSaveLength = 400
TalentConfig.Remote = "EquipTalent"

-- how a kind combines: "mult" talents multiply (1 when none), "add" talents add (0 when none)
TalentConfig.Kinds = {
	maxHealth = "mult",
	regen = "add", -- HP per second
	damage = "mult", -- only for hits tagged with the talent's damageStat
	staminaMax = "add",
	postureTaken = "mult",
	statusDuration = "mult",
}

function TalentConfig.Attribute(key)
	return "Talent_" .. key
end

-- ordered by stat, then tier; cost is 1 / 2 / 3 for tier 15 / 30 / 50
TalentConfig.List = {
	{ key = "Hardy", name = "Hardy", stat = "Vitality", tier = 15, cost = 1, kind = "maxHealth", amount = 1.05 },
	{ key = "SecondWind", name = "Second Wind", stat = "Vitality", tier = 30, cost = 2, kind = "regen", amount = 2 },
	{ key = "Unyielding", name = "Unyielding", stat = "Vitality", tier = 50, cost = 3, kind = "maxHealth", amount = 1.10 },
	{ key = "HeavyHands", name = "Heavy Hands", stat = "Strength", tier = 15, cost = 1, kind = "damage", amount = 1.05, damageStat = "Strength" },
	{ key = "Brutal", name = "Brutal", stat = "Strength", tier = 30, cost = 2, kind = "damage", amount = 1.10, damageStat = "Strength" },
	{ key = "Crusher", name = "Crusher", stat = "Strength", tier = 50, cost = 3, kind = "damage", amount = 1.15, damageStat = "Strength" },
	{ key = "Focus", name = "Focus", stat = "Superliminal", tier = 15, cost = 1, kind = "damage", amount = 1.05, damageStat = "Superliminal" },
	{ key = "Overflow", name = "Overflow", stat = "Superliminal", tier = 30, cost = 2, kind = "damage", amount = 1.10, damageStat = "Superliminal" },
	{ key = "Apex", name = "Apex", stat = "Superliminal", tier = 50, cost = 3, kind = "damage", amount = 1.15, damageStat = "Superliminal" },
	{ key = "SteadyAim", name = "Steady Aim", stat = "Firearm", tier = 15, cost = 1, kind = "damage", amount = 1.05, damageStat = "Firearm" },
	{ key = "Marksman", name = "Marksman", stat = "Firearm", tier = 30, cost = 2, kind = "damage", amount = 1.10, damageStat = "Firearm" },
	{ key = "Deadeye", name = "Deadeye", stat = "Firearm", tier = 50, cost = 3, kind = "damage", amount = 1.15, damageStat = "Firearm" },
	{ key = "QuickLungs", name = "Quick Lungs", stat = "Agility", tier = 15, cost = 1, kind = "staminaMax", amount = 10 },
	{ key = "LightFeet", name = "Light Feet", stat = "Agility", tier = 30, cost = 2, kind = "staminaMax", amount = 15 },
	{ key = "Windrunner", name = "Windrunner", stat = "Agility", tier = 50, cost = 3, kind = "staminaMax", amount = 25 },
	{ key = "Steady", name = "Steady", stat = "Willpower", tier = 15, cost = 1, kind = "postureTaken", amount = 0.95 },
	{ key = "Resolute", name = "Resolute", stat = "Willpower", tier = 30, cost = 2, kind = "statusDuration", amount = 0.85 },
	{ key = "IronMind", name = "Iron Mind", stat = "Willpower", tier = 50, cost = 3, kind = "postureTaken", amount = 0.85 },
}

local byKey = {}
for _, talent in ipairs(TalentConfig.List) do
	byKey[talent.key] = talent
end

function TalentConfig.Get(key)
	return byKey[key]
end

-- a talent's effect in words, for the menu
function TalentConfig.Describe(talent)
	local kind, amount = talent.kind, talent.amount
	if kind == "maxHealth" then
		return string.format("+%d%% max HP", math.round((amount - 1) * 100))
	elseif kind == "regen" then
		return string.format("+%d HP per second", amount)
	elseif kind == "damage" then
		return string.format("+%d%% %s damage", math.round((amount - 1) * 100), talent.damageStat)
	elseif kind == "staminaMax" then
		return string.format("+%d max stamina", amount)
	elseif kind == "postureTaken" then
		return string.format("-%d%% posture taken blocking", math.round((1 - amount) * 100))
	end
	return string.format("-%d%% status time on you", math.round((1 - amount) * 100))
end

return TalentConfig
