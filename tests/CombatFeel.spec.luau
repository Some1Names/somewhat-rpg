-- Unit tests for the combat-feel rules: ReplicatedStorage.CombatFeel (dodge
-- window, i-frames, recovery, swing cost) and EnemyAttackConfig (attack types,
-- the heavy chance and the pick). Run with Lune, outside Roblox: tests/run.sh.
local CombatFeel = require("../src/ReplicatedStorage/CombatFeel")
local EnemyAttackConfig = require("../src/ReplicatedStorage/EnemyAttackConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

-- the dodge window
check("no Agility is 0.15 s", near(CombatFeel.DodgeWindow(0), 0.15))
check("50 Agility is 0.25 s", near(CombatFeel.DodgeWindow(50), 0.25))
check("no Agility value is the base", near(CombatFeel.DodgeWindow(nil), 0.15))
check("negative Agility is the base", near(CombatFeel.DodgeWindow(-5), 0.15))
check("the dodge ends window plus grace later", near(CombatFeel.DodgeUntil(100, 0), 100.25))
check("no dodge means no i-frames", CombatFeel.InDodge(nil, 5) == false)
check("just before the end is still dodging", CombatFeel.InDodge(10, 9.99) == true)
check("the end moment is not dodging", CombatFeel.InDodge(10, 10) == false)

-- the recovery between dashes
check("the first dash is always allowed", CombatFeel.CanDodge(5, nil) == true)
check("a dash 0.2 s after the last is too soon", CombatFeel.CanDodge(5.2, 5) == false)
check("a dash 0.3 s after the last is still too soon", CombatFeel.CanDodge(5.3, 5) == false)
check("a dash 0.4 s after the last is allowed", CombatFeel.CanDodge(5.4, 5) == true)
check("the recovery boundary is inclusive", CombatFeel.CanDodge(0.5 + CombatFeel.DodgeRecovery, 0.5) == true)

-- swing cost
check("a hit costs 6", CombatFeel.SwingCost({}, false) == 6)
check("a finisher costs 12", CombatFeel.SwingCost({}, true) == 12)
check("a weapon can set its own hit cost", CombatFeel.SwingCost({ swingStamina = 3 }, false) == 3)
check("a weapon can set its own finisher cost", CombatFeel.SwingCost({ finisherStamina = 20 }, true) == 20)

-- the attack pick
check("a low roll is heavy", EnemyAttackConfig.Choose(0.1, 0.25, false) == "heavy")
check("never two heavies in a row", EnemyAttackConfig.Choose(0.1, 0.25, true) == "quick")
check("a high roll is quick", EnemyAttackConfig.Choose(0.9, 0.25, false) == "quick")
check("a chance of 0 is never heavy", EnemyAttackConfig.Choose(0, 0, false) == "quick")
check("a chance of 1 is heavy after a quick", EnemyAttackConfig.Choose(0.99, 1, false) == "heavy")
check("a chance of 1 is still quick after a heavy", EnemyAttackConfig.Choose(0.99, 1, true) == "quick")

-- the chance attribute
check("no attribute uses the default", EnemyAttackConfig.Chance(nil) == 0.25)
check("a string uses the default", EnemyAttackConfig.Chance("x") == 0.25)
check("a negative chance is 0", EnemyAttackConfig.Chance(-1) == 0)
check("a chance over 1 is 1", EnemyAttackConfig.Chance(5) == 1)
check("a good chance is kept", EnemyAttackConfig.Chance(0.5) == 0.5)

-- the types
check("heavy winds up for 0.8 s", EnemyAttackConfig.Get("heavy").windUp == 0.8)
check("heavy hits 1.8 times as hard", EnemyAttackConfig.Get("heavy").damage == 1.8)
check("heavy can't be staggered out of", EnemyAttackConfig.Get("heavy").uninterruptible == true)
check("quick can be staggered out of", EnemyAttackConfig.Get("quick").uninterruptible == false)
check("quick winds up for 0.35 s", EnemyAttackConfig.Get("quick").windUp == 0.35)
check("an unknown type is nil", EnemyAttackConfig.Get("nope") == nil)

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all CombatFeel checks passed")
