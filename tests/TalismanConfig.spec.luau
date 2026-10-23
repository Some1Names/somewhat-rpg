-- Unit tests for ReplicatedStorage.TalismanConfig (parsing, slots, totals,
-- equipping, granting). Run with Lune, outside Roblox: tests/run.sh.
local T = require("../src/ReplicatedStorage/TalismanConfig")
T.OwnAll = false -- the tests are about real ownership

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

-- every item has a name, a description and effects, and keys are unique
local keys = {}
local sane = true
for _, item in ipairs(T.Items) do
	if keys[item.key] or not item.name or not item.description or next(item.effects) == nil then
		sane = false
	end
	keys[item.key] = true
end
check("items are well formed", sane and #T.Items >= 6)

check("parse keeps valid keys once, in order", table.concat(T.Parse("Vigor,Nope,Bulwark,Vigor"), ",") == "Vigor,Bulwark")
check("parse of nothing is empty", #T.Parse("") == 0 and #T.Parse(nil) == 0)
check("encode round-trips", T.Encode(T.Parse("Regrowth,Magnate")) == "Regrowth,Magnate")

check("slots by level", T.Slots(0) == 1 and T.Slots(14) == 1 and T.Slots(15) == 2 and T.Slots(39) == 2 and T.Slots(40) == 3 and T.Slots(100) == 3)
check("next slot level", T.NextSlotLevel(0) == 15 and T.NextSlotLevel(15) == 40 and T.NextSlotLevel(40) == nil)

check("total sums an effect", near(T.Total("Vigor,GlassCharm", "maxHealthPct"), 0))
check("total of an effect nobody has is 0", T.Total("Vigor", "yenPct") == 0)
check("health multiplier", near(T.HealthMultiplier("Vigor"), 1.15) and near(T.HealthMultiplier("GlassCharm"), 0.85) and T.HealthMultiplier("") == 1)
check("incoming multiplier", near(T.IncomingMultiplier("Bulwark"), 0.92) and T.IncomingMultiplier(nil) == 1)
check("outgoing multiplier", near(T.OutgoingMultiplier("GlassCharm"), 1.2) and T.OutgoingMultiplier("") == 1)
check("yen multiplier", near(T.YenMultiplier("Magnate"), 1.3) and T.YenMultiplier("") == 1)

-- equipping
local worn = T.Equip("Vigor,Bulwark", "", "Vigor", 0)
check("equip an owned talisman", worn and worn[1] == "Vigor")
check("can't equip one you don't own", T.Equip("Vigor", "", "Bulwark", 0) == nil)
check("can't equip a made-up one", T.Equip("Vigor", "", "Nope", 0) == nil)
check("can't equip twice", T.Equip("Vigor", "Vigor", "Vigor", 50) == nil)
check("no free slot at level 0 with one worn", T.Equip("Vigor,Bulwark", "Vigor", "Bulwark", 0) == nil)
check("a second slot at level 15", T.Equip("Vigor,Bulwark", "Vigor", "Bulwark", 15) ~= nil)
local off = T.Unequip("Vigor,Bulwark", "Vigor")
check("unequip", off and #off == 1 and off[1] == "Bulwark")
check("unequip something not worn", T.Unequip("Bulwark", "Vigor") == nil)

-- granting
check("grant adds to the owned text", T.Grant("Vigor", "Bulwark") == "Vigor,Bulwark")
check("grant of an owned one is nil", T.Grant("Vigor", "Vigor") == nil)
check("grant of a made-up one is nil", T.Grant("", "Nope") == nil)

-- rolling a new one
local owned = "Vigor,Regrowth,Bulwark,Magnate,SecondWind"
check("roll picks the one missing", T.RollNew(owned, function(n)
	return n
end) == "GlassCharm")
check("roll is nil once all are owned", T.RollNew(owned .. ",GlassCharm", function(n)
	return n
end) == nil)
check("roll never picks an owned one", T.RollNew("Vigor", function()
	return 1
end) ~= "Vigor")

-- the Thug's Knuckle: only an enemy gives it (EnemyConfig), never a yen chest
check("thug's knuckle is drop only", T.Get("ThugKnuckle").dropOnly == true and T.Get("Vigor").dropOnly == nil)
check("thug's knuckle effects add up", near(T.Total("ThugKnuckle,Vigor", "damageDealt"), 0.1) and near(T.Total("ThugKnuckle", "healOnKill"), 0.02))
check("a roll never picks it", T.RollNew("", function(n)
	return n
end) == "GlassCharm")
check("a roll is nil with every common one owned", T.RollNew(owned .. ",GlassCharm", function()
	return 1
end) == nil)
check("it can be granted once", T.Grant("Vigor", "ThugKnuckle") == "Vigor,ThugKnuckle" and T.Grant("Vigor,ThugKnuckle", "ThugKnuckle") == nil)

if failures > 0 then
	error(failures .. " failed")
end
