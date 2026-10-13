-- More ways to earn skill-set mastery (applied in ServerScriptService.Damage;
-- tests/MasteryRules.spec.luau runs these outside Roblox). The base rate stays
-- SkillSetConfig.MasteryXPPerDamage per point of damage to an NPC. On top:
-- damage to another player earns PvPShare of it, at most PvPCap per victim per
-- PvPWindow seconds; finishing a kill earns KillShare of the kill's XP; and a
-- model tagged DummyTag (training dummies) teaches at the normal rate, but only
-- below mastery DummyCap.
local MasteryRules = {
	PvPShare = 0.5, -- of the NPC rate, for damage dealt to a player
	PvPCap = 500, -- mastery XP from one victim in one PvPWindow
	PvPWindow = 600, -- seconds
	KillShare = 0.5, -- of a kill's XP, as mastery for the set that got it
	DummyCap = 10, -- training dummies teach up to this mastery level
	DummyTag = "TrainingDummy", -- CollectionService tag on the training dummies
}

-- a hit that isn't a number, or does nothing, earns nothing
local function amountOf(damage)
	if damage ~= damage or damage <= 0 then
		return 0
	end
	return damage
end

-- mastery XP for `damage` dealt to a player, given the `earnedInWindow` XP
-- already earned from that victim in the last PvPWindow
function MasteryRules.pvpXP(damage, perDamage, earnedInWindow)
	local want = amountOf(damage) * perDamage * MasteryRules.PvPShare
	return math.min(want, math.max(MasteryRules.PvPCap - earnedInWindow, 0))
end

-- mastery XP for a kill worth `killXP` of ordinary XP
function MasteryRules.killXP(killXP)
	return amountOf(killXP) * MasteryRules.KillShare
end

-- mastery XP for `damage` dealt to a training dummy by someone at `mastery`
function MasteryRules.dummyXP(damage, perDamage, mastery)
	if mastery >= MasteryRules.DummyCap then
		return 0
	end
	return amountOf(damage) * perDamage
end

-- A set's level and the XP into it after `amount` more XP. `costOf(level)` is
-- the XP to go from that level to the next. Past `maxLevel`, XP is banked up
-- to one level's worth. With `capLevel`, nothing is gained at or above it, and
-- reaching it leaves no XP.
function MasteryRules.addXP(level, xp, amount, capLevel, maxLevel, costOf)
	if capLevel and level >= capLevel then
		return level, xp
	end
	xp += amount
	local stop = math.min(maxLevel, capLevel or maxLevel)
	while level < stop and xp >= costOf(level) do
		xp -= costOf(level)
		level += 1
	end
	if capLevel and level >= capLevel then
		xp = 0
	elseif level >= maxLevel then
		xp = math.min(xp, costOf(level))
	end
	return level, xp
end

return MasteryRules
