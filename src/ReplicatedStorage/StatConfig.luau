-- Levels, stat points and what each stat buys. The server applies these
-- numbers and the stats menu shows them, so both read this one module.
local StatConfig = {}

-- Players start at level 0 and earn PointsPerLevel for every level after.
-- Both can change between updates: unspent points are recalculated from
-- level, and XP earned at the cap is kept, when players next join.
StatConfig.PointsPerLevel = 3
StatConfig.MaxLevel = 100
StatConfig.KillXP = 50 -- for killing an NPC that has no XPReward attribute
StatConfig.KillYen = 25 -- for killing an NPC that has no YenReward attribute
-- an NPC's level is its model's Level attribute; one this many levels above
-- you has its name shown in red
StatConfig.DangerLevelGap = 10

-- What an NPC enemy gets from its level. A model can still set its own with
-- MaxHealth, AttackDamage, XPReward or YenReward attributes. Level 1 matches
-- the plain training dummy (100 HP, KillXP, KillYen).
function StatConfig.EnemyHealth(level)
	return 100 + 40 * (level - 1)
end
function StatConfig.EnemyDamage(level)
	return math.floor(4 + 1.6 * level)
end
function StatConfig.EnemyXP(level)
	return 40 + 10 * level
end
function StatConfig.EnemyYen(level)
	return 20 + 5 * level
end
StatConfig.StaminaPerBox = 25 -- one box is one dash

-- stamina boxes unlock as the player levels up
StatConfig.StaminaBoxLevels = {
	{ level = 0, boxes = 4 },
	{ level = 10, boxes = 5 },
	{ level = 25, boxes = 6 },
	{ level = 50, boxes = 7 },
	{ level = 100, boxes = 8 },
}

-- dodge charges (spent by the Q dodge and the double jump) unlock the same way
StatConfig.DodgeChargeLevels = {
	{ level = 0, charges = 1 },
	{ level = 25, charges = 2 },
	{ level = 60, charges = 3 },
}
StatConfig.BaseHealth = 100
StatConfig.HealthPerVitality = 10

-- XP needed to go from this level to the next
function StatConfig.XPToLevelUp(level)
	return 100 + 50 * level
end

-- In menu order. Each milestone applies once the stat reaches `at` points.
-- A stat takes at most MaxLevel points (so the cap rises with the level cap),
-- or its own `max` if that's lower. A stat with `damageBonus` scales every
-- attack tagged with it by that fraction of its base damage per point.
StatConfig.Stats = {
	{
		key = "Vitality", -- max HP per point, regen at milestones
		milestones = {
			{ at = 0, regen = 1 },
			{ at = 10, regen = 2 },
			{ at = 25, regen = 3 },
			{ at = 50, regen = 5 },
		},
	},
	{
		key = "Strength", -- punches and other melee
		damageBonus = 0.05,
		milestones = {},
	},
	{
		key = "Superliminal", -- skill-set skills like Mandela's, and their ranged moves (Knife, Light Shot)
		damageBonus = 0.05,
		milestones = {},
	},
	{
		key = "Firearm", -- guns: every shot of a gun weapon set (the Revolver), its skills too
		damageBonus = 0.05,
		milestones = {},
	},
}

local byKey = {}
for _, stat in ipairs(StatConfig.Stats) do
	byKey[stat.key] = stat
end

function StatConfig.Get(key)
	return byKey[key]
end

-- the most points this stat can hold
function StatConfig.StatCap(key)
	return math.min(byKey[key].max or math.huge, StatConfig.MaxLevel)
end

-- the highest milestone these points have reached, and the next one (if any)
function StatConfig.Milestones(key, points)
	local current, upcoming
	for _, milestone in ipairs(byKey[key].milestones) do
		if points >= milestone.at then
			current = milestone
		elseif not upcoming then
			upcoming = milestone
		end
	end
	return current, upcoming
end

-- milestone base HP plus a little for every point
function StatConfig.MaxHealth(vitality)
	return StatConfig.BaseHealth + StatConfig.HealthPerVitality * vitality
end

function StatConfig.RegenPerSecond(vitality)
	return StatConfig.Milestones("Vitality", vitality).regen
end

-- dodge charges at this level, and the next unlock (if any)
function StatConfig.DodgeCharges(level)
	local charges, upcoming = 0, nil
	for _, unlock in ipairs(StatConfig.DodgeChargeLevels) do
		if level >= unlock.level then
			charges = unlock.charges
		elseif not upcoming then
			upcoming = unlock
		end
	end
	return charges, upcoming
end

-- stamina boxes at this level, and the next unlock (if any)
function StatConfig.StaminaBoxes(level)
	local boxes, upcoming = 0, nil
	for _, unlock in ipairs(StatConfig.StaminaBoxLevels) do
		if level >= unlock.level then
			boxes = unlock.boxes
		elseif not upcoming then
			upcoming = unlock
		end
	end
	return boxes, upcoming
end

-- how much an attack tagged with this stat is multiplied by
function StatConfig.DamageMultiplier(key, points)
	return 1 + (byKey[key].damageBonus or 0) * points
end

return StatConfig
