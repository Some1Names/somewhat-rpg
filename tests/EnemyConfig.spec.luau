-- Unit tests for ReplicatedStorage.EnemyConfig (per-type settings, combo order,
-- aggro range, the talisman roll). Run with Lune, outside Roblox: tests/run.sh.
local E = require("../src/ReplicatedStorage/EnemyConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local henchman = E.Get("Henchman")

-- lookup
check("henchman has an entry", type(henchman) == "table")
check("unknown, missing and non-string types have none", E.Get("Nope") == nil and E.Get(nil) == nil and E.Get(5) == nil)
check(
	"henchman numbers",
	henchman.AggroRange == 50 and henchman.GiveUpDistance == 140 and henchman.comboPause == 1.2 and henchman.dropTable == "Henchman"
)
check(
	"henchman combo is jab, jab, heavy with a lunge on the heavy",
	#henchman.attacks == 3
		and henchman.attacks[1].type == "quick"
		and henchman.attacks[2].type == "quick"
		and henchman.attacks[3].type == "heavy"
		and henchman.attacks[3].lunge == 6
)
check("henchman talisman", henchman.talisman.key == "ThugKnuckle" and henchman.talisman.chance == 0.03)

-- attribute, then entry, then default
check("an attribute wins", E.Setting(30, "Henchman", "AggroRange", 0) == 30)
check("then the type's entry", E.Setting(nil, "Henchman", "AggroRange", 0) == 50)
check("then the default for an unknown type", E.Setting(nil, "Nope", "AggroRange", 7) == 7)
check("and for no type", E.Setting(nil, nil, "AttackRange", 5) == 5)

-- combo
local step, nextIndex, finishes = E.NextAttack(henchman, 1)
check("first step is a quick one", step.type == "quick" and nextIndex == 2 and finishes == false)
step, nextIndex, finishes = E.NextAttack(henchman, 3)
check("last step is the heavy, ends the combo and wraps", step.type == "heavy" and nextIndex == 1 and finishes == true)
check("a bad index counts as the first step", E.NextAttack(henchman, 4).type == "quick" and E.NextAttack(henchman, 0).type == "quick" and E.NextAttack(henchman, nil).type == "quick")
check("no combo without attacks", E.NextAttack(nil, 1) == nil and E.NextAttack({}, 1) == nil)

-- aggro
check("inside aggro range", E.InAggro(henchman, 50) == true and E.InAggro(henchman, 3) == true)
check("outside aggro range", E.InAggro(henchman, 50.01) == false)
check("no aggro range means passive", E.InAggro({}, 1) == false and E.InAggro(nil, 1) == false)

-- talisman roll
check("a pass below the chance", E.TalismanDrop(henchman, {}, function()
	return 0.029
end) == "ThugKnuckle")
check("no pass at the chance", E.TalismanDrop(henchman, {}, function()
	return 0.03
end) == nil)
local called = false
check("owned: no drop and no roll", E.TalismanDrop(henchman, { "ThugKnuckle" }, function()
	called = true
	return 0
end) == nil and not called)
check("no talisman entry, no drop", E.TalismanDrop({}, {}, function()
	return 0
end) == nil and E.TalismanDrop(nil, {}, function()
	return 0
end) == nil)

if failures > 0 then
	error(failures .. " failed")
end
