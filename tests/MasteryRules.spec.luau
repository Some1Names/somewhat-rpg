-- Unit tests for ReplicatedStorage.MasteryRules (mastery from players, from
-- kills and from training dummies, and how XP turns into levels with an
-- optional level cap). Run with Lune, outside Roblox: tests/run.sh.
local MasteryRules = require("../src/ReplicatedStorage/MasteryRules")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- the numbers
check("constants", MasteryRules.PvPShare == 0.5 and MasteryRules.PvPCap == 500 and MasteryRules.PvPWindow == 600
	and MasteryRules.KillShare == 0.5 and MasteryRules.DummyCap == 10 and MasteryRules.DummyTag == "TrainingDummy")

-- damage to a player: half the NPC rate, at most 500 per victim per window
check("pvp is half the rate", MasteryRules.pvpXP(100, 0.25, 0) == 12.5)
check("pvp stops at what's left of the cap", MasteryRules.pvpXP(100, 0.25, 495) == 5)
check("pvp gives nothing at the cap", MasteryRules.pvpXP(100, 0.25, 500) == 0)
check("pvp gives nothing past the cap", MasteryRules.pvpXP(100, 0.25, 900) == 0)
check("pvp nothing for no damage", MasteryRules.pvpXP(0, 0.25, 0) == 0 and MasteryRules.pvpXP(-5, 0.25, 0) == 0)
check("pvp ignores a NaN hit", MasteryRules.pvpXP(0 / 0, 0.25, 0) == 0)

-- a kill: half the kill XP
check("kill bonus is half", MasteryRules.killXP(50) == 25)
check("kill bonus at level 50", MasteryRules.killXP(540) == 270)
check("kill bonus never negative", MasteryRules.killXP(-4) == 0)

-- a training dummy: the normal rate below mastery 10, nothing from there
check("dummy below the cap", MasteryRules.dummyXP(100, 0.25, 9) == 25)
check("dummy at the cap", MasteryRules.dummyXP(100, 0.25, 10) == 0)
check("dummy past the cap", MasteryRules.dummyXP(100, 0.25, 40) == 0)
check("dummy counts the damage, however big", MasteryRules.dummyXP(1e9, 0.25, 1) == 2.5e8)
check("dummy ignores a NaN hit", MasteryRules.dummyXP(0 / 0, 0.25, 1) == 0)

-- XP into levels, with a cost per level like SkillSetConfig.MasteryToLevelUp
local function cost(level)
	return 40 + 20 * (level - 1)
end
local level, xp = MasteryRules.addXP(1, 0, 40, nil, 100, cost)
check("addXP: exactly a level", level == 2 and xp == 0)
level, xp = MasteryRules.addXP(1, 10, 20, nil, 100, cost)
check("addXP: part of a level", level == 1 and xp == 30)
level, xp = MasteryRules.addXP(1, 0, 40 + 60, nil, 100, cost)
check("addXP: two levels at once", level == 3 and xp == 0)
level, xp = MasteryRules.addXP(9, 0, 100000, 10, 100, cost)
check("addXP: a big hit at 9 levels to 10 and stops there with no XP", level == 10 and xp == 0)
level, xp = MasteryRules.addXP(10, 0, 50, 10, 100, cost)
check("addXP: nothing at the cap", level == 10 and xp == 0)
level, xp = MasteryRules.addXP(20, 5, 50, 10, 100, cost)
check("addXP: above the cap changes nothing", level == 20 and xp == 5)
level, xp = MasteryRules.addXP(99, 0, 100000, nil, 100, cost)
check("addXP: at the top, XP banks up to one level", level == 100 and xp == cost(100))
level, xp = MasteryRules.addXP(100, 0, 100000, nil, 100, cost)
check("addXP: at the top already, the same", level == 100 and xp == cost(100))

if failures > 0 then
	error(failures .. " failed")
end
