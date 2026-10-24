-- Unit tests for the build-depth rules: StatConfig's cap and new stats,
-- TalentConfig and ReplicatedStorage.BuildRules (requirements, talent points,
-- tiers, equipping, pruning, the saved text, modifiers).
-- Run with Lune, outside Roblox: tests/run.sh.
local StatConfig = require("../src/ReplicatedStorage/StatConfig")
local BuildRules = require("../src/ReplicatedStorage/BuildRules")

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

local function same(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- stats and the cap
check("Vitality caps at a quarter of the level points", StatConfig.StatCap("Vitality") == StatConfig.MaxLevel * StatConfig.PointsPerLevel / 4)
check("Agility has the same cap", StatConfig.StatCap("Agility") == StatConfig.StatCap("Vitality"))
check("Willpower exists", StatConfig.Get("Willpower") ~= nil)
check("the level points can't max every stat", StatConfig.MaxLevel * StatConfig.PointsPerLevel < StatConfig.MaxStatPoints * #StatConfig.Stats)
check("they can max four", StatConfig.MaxLevel * StatConfig.PointsPerLevel >= StatConfig.MaxStatPoints * 4)
check("50 Agility is 50 extra stamina", StatConfig.AgilityStamina(50) == 50)
check("no Willpower lets all the posture through", StatConfig.WillpowerPostureMultiplier(0) == 1)
check("50 Willpower halves posture taken", StatConfig.WillpowerPostureMultiplier(50) == 0.5)
check("20 Willpower cuts status time to 80%", near(StatConfig.WillpowerStatusMultiplier(20), 0.8))

-- requirements
check("a requirement that is met", BuildRules.Meets({ Strength = 20 }, { Strength = 20 }))
local met, missing = BuildRules.Meets({}, { Strength = 1, Firearm = 1 })
check("the first missing stat is named alphabetically", met == false and missing == "Firearm")
check("no requirement is always met", BuildRules.Meets({}, nil) == true)
check("an empty requirement is always met", BuildRules.Meets({}, {}) == true)

-- talent points and tiers
check("no talent points at level 0", BuildRules.TalentPoints(0) == 0)
check("no talent points at level 4", BuildRules.TalentPoints(4) == 0)
check("1 talent point at level 5", BuildRules.TalentPoints(5) == 1)
check("20 talent points at level 100", BuildRules.TalentPoints(100) == 20)
check("tier 15 stays locked at 14 points", BuildRules.TierUnlocked(14, 15) == false)
check("tier 15 opens at 15 points", BuildRules.TierUnlocked(15, 15) == true)

-- equipping
local ok, reason = BuildRules.CanEquip({}, "Hardy", { Vitality = 14 }, 100)
check("a locked tier can't be equipped", ok == false and reason == "locked")
ok, reason = BuildRules.CanEquip({}, "Hardy", { Vitality = 15 }, 0)
check("no talent points can't equip", ok == false and reason == "budget")
check("equips with a point and the tier", BuildRules.CanEquip({}, "Hardy", { Vitality = 15 }, 5) == true)
ok, reason = BuildRules.CanEquip({ "Hardy" }, "Hardy", { Vitality = 15 }, 100)
check("can't equip twice", ok == false and reason == "already")
ok, reason = BuildRules.CanEquip({}, "Nope", { Vitality = 15 }, 100)
check("an unknown talent can't be equipped", ok == false and reason == "unknown")
check("Spent adds the costs", BuildRules.Spent({ "Hardy", "SecondWind" }) == 3)

-- pruning
check(
	"prune drops trailing talents over budget",
	same(BuildRules.Prune({ "Hardy", "Brutal" }, { Vitality = 15, Strength = 30 }, 5), { "Hardy" })
)
check("prune drops locked talents", same(BuildRules.Prune({ "Hardy" }, { Vitality = 3 }, 100), {}))
check(
	"prune keeps what fits",
	same(BuildRules.Prune({ "Hardy", "Brutal" }, { Vitality = 15, Strength = 30 }, 15), { "Hardy", "Brutal" })
)

-- the saved text
check("decode skips unknown and duplicate keys", same(BuildRules.Decode("Hardy,Hardy,Bogus,Brutal"), { "Hardy", "Brutal" }))
check("decode of nil is empty", same(BuildRules.Decode(nil), {}))
check("decode of a huge string is empty", same(BuildRules.Decode(string.rep("a", 500)), {}))
check("encode and decode round-trip", same(BuildRules.Decode(BuildRules.Encode({ "Hardy", "Brutal" })), { "Hardy", "Brutal" }))

-- modifiers
check("mult modifiers multiply", near(BuildRules.Modifier({ "Hardy", "Unyielding" }, "maxHealth"), 1.05 * 1.10))
check("a damage talent counts only for its own stat", BuildRules.Modifier({ "HeavyHands" }, "damage", "Firearm") == 1)
check("a damage talent counts for its stat", near(BuildRules.Modifier({ "HeavyHands" }, "damage", "Strength"), 1.05))
check("no talents add nothing", BuildRules.Modifier({}, "regen") == 0)
check("add modifiers add", BuildRules.Modifier({ "SecondWind" }, "regen") == 2)

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all BuildRules checks passed")
