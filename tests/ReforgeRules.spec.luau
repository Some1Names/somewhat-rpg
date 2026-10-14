-- Unit tests for ReplicatedStorage.ReforgeRules (level and reroll costs, slot
-- unlocks, modifier rolls, the combat multipliers and the saved text) over
-- ReforgeConfig's numbers. Run with Lune, outside Roblox: tests/run.sh.
local ReforgeConfig = require("../src/ReplicatedStorage/ReforgeConfig")
local ReforgeRules = require("../src/ReplicatedStorage/ReforgeRules")

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

local function stateWith(level, mods)
	return { level = level, mods = mods or {} }
end

local RICH = { Scrap = 999, Core = 999, Crystal = 999, Essence = 999 }

-- level-up costs: the cost of the next level, by tier
local ok, cost = ReforgeRules.PlanLevelUp(stateWith(0), RICH, 1e6)
check("level 1 costs 10 Scrap and 200 yen", ok and cost.material == "Scrap" and cost.amount == 10 and cost.yen == 200)
ok, cost = ReforgeRules.PlanLevelUp(stateWith(3), RICH, 1e6)
check("level 4 costs 5 Core and 1000 yen", ok and cost.material == "Core" and cost.amount == 5 and cost.yen == 1000)
ok, cost = ReforgeRules.PlanLevelUp(stateWith(6), RICH, 1e6)
check("level 7 costs 3 Crystal and 5000 yen", ok and cost.material == "Crystal" and cost.amount == 3 and cost.yen == 5000)
ok, cost = ReforgeRules.PlanLevelUp(stateWith(9), RICH, 1e6)
check("level 10 costs 3 Essence and 20000 yen", ok and cost.material == "Essence" and cost.amount == 3 and cost.yen == 20000)
ok, cost = ReforgeRules.PlanLevelUp(stateWith(10), RICH, 1e6)
check("level 10 is the cap", ok == false and type(cost) == "string")
ok, cost = ReforgeRules.PlanLevelUp(stateWith(0), { Scrap = 9 }, 1e6)
check("short on materials is refused, naming the material", ok == false and string.find(cost, "Scrap") ~= nil)
ok, cost = ReforgeRules.PlanLevelUp(stateWith(0), RICH, 199)
check("short on yen is refused, naming the shortfall", ok == false and string.find(cost, "¥1 more", 1, true) ~= nil)
ok = ReforgeRules.PlanLevelUp(stateWith(0), {}, 1e6)
check("an empty bag is refused", ok == false)

-- slots
check("no slot at level 2", ReforgeRules.SlotsUnlocked(2) == 0)
check("one slot at level 3", ReforgeRules.SlotsUnlocked(3) == 1)
check("one slot at level 6", ReforgeRules.SlotsUnlocked(6) == 1)
check("two slots at level 7", ReforgeRules.SlotsUnlocked(7) == 2)

-- reroll costs and checks
ok, cost = ReforgeRules.PlanReroll(stateWith(3), 1, RICH, 1e6)
check("slot 1 reroll is 3 Core and 500 yen", ok and cost.material == "Core" and cost.amount == 3 and cost.yen == 500)
ok, cost = ReforgeRules.PlanReroll(stateWith(7), 2, RICH, 1e6)
check("slot 2 reroll is 3 Crystal and 2500 yen", ok and cost.material == "Crystal" and cost.amount == 3 and cost.yen == 2500)
check("a locked slot can't be rerolled", ReforgeRules.PlanReroll(stateWith(3), 2, RICH, 1e6) == false)
check("slot 3 doesn't exist", ReforgeRules.PlanReroll(stateWith(10), 3, RICH, 1e6) == false)
check("slot 0 doesn't exist", ReforgeRules.PlanReroll(stateWith(10), 0, RICH, 1e6) == false)
check("a fractional slot doesn't exist", ReforgeRules.PlanReroll(stateWith(10), 1.5, RICH, 1e6) == false)
check("a reroll needs the materials", ReforgeRules.PlanReroll(stateWith(3), 1, { Core = 2 }, 1e6) == false)
check("a reroll needs the yen", ReforgeRules.PlanReroll(stateWith(3), 1, RICH, 499) == false)

-- rolls stay in each modifier's range and skip taken ones
local rollsOk = true
for _, modifier in ipairs(ReforgeConfig.Modifiers) do
	local others = {}
	for _, other in ipairs(ReforgeConfig.Modifiers) do
		if other.id ~= modifier.id then
			others[other.id] = true
		end
	end
	-- only this modifier is left: the roll must be it, at the low and high end
	local low = ReforgeRules.Roll(function(lo)
		return lo
	end, others)
	local high = ReforgeRules.Roll(function(_, hi)
		return hi
	end, others)
	rollsOk = rollsOk and low.id == modifier.id and low.value == modifier.min and high.id == modifier.id and high.value == modifier.max
end
check("a roll is the only modifier left, at its min and max", rollsOk)
local never = true
for pick = 1, #ReforgeConfig.Modifiers - 1 do
	local rolled = ReforgeRules.Roll(function(lo, hi)
		return math.min(pick, hi)
	end, { Might = true })
	never = never and rolled.id ~= "Might"
end
check("a roll never returns a taken modifier", never)

-- combat multipliers
check("level 0 changes no damage", near(ReforgeRules.DamageMultiplier(stateWith(0), false), 1))
check("level 10 is +40% damage", near(ReforgeRules.DamageMultiplier(stateWith(10), false), 1.4))
local maxed = stateWith(10, { { id = "Might", value = 100 } })
check("level 10 with Might 10% is x1.50", near(ReforgeRules.DamageMultiplier(maxed, false), 1.5))
check("the same against a player is x1.25", near(ReforgeRules.DamageMultiplier(maxed, true), 1.25))
check("Might 5.5% adds 0.055", near(ReforgeRules.DamageMultiplier(stateWith(7, { { id = "Might", value = 55 } }), false), 1 + 7 * 0.04 + 0.055))
check("Might in slot 2 counts too", near(ReforgeRules.DamageMultiplier(stateWith(7, { [2] = { id = "Might", value = 100 } }), false), 1 + 7 * 0.04 + 0.1))
check("Swift 10% is x0.9 cooldown", near(ReforgeRules.CooldownMultiplier(stateWith(3, { { id = "Swift", value = 100 } })), 0.9))
check("no Swift is x1 cooldown", near(ReforgeRules.CooldownMultiplier(stateWith(10)), 1))
check("Searing 20% is a 0.2 Burnt chance", near(ReforgeRules.StatusChance(stateWith(3, { { id = "Searing", value = 200 } }), "Burnt"), 0.2))
check("Searing gives no Bleeding chance", ReforgeRules.StatusChance(stateWith(3, { { id = "Searing", value = 200 } }), "Bleeding") == 0)
check("nothing gives no chance", ReforgeRules.StatusChance(stateWith(3), "Burnt") == 0)
check("Vampiric 6% heals 0.06", near(ReforgeRules.Lifesteal(stateWith(3, { { id = "Vampiric", value = 60 } })), 0.06))
check("no Vampiric heals nothing", ReforgeRules.Lifesteal(stateWith(3)) == 0)

-- saved text
local saved = "Mandela=3:Vampiric=40,-;Revolver=7:Might=55,-"
local decoded = ReforgeRules.Decode(saved, function()
	return true
end)
check("decode reads the level", decoded.Revolver.level == 7 and decoded.Mandela.level == 3)
check("decode reads a modifier", decoded.Revolver.mods[1].id == "Might" and decoded.Revolver.mods[1].value == 55)
check("decode leaves an empty slot empty", decoded.Revolver.mods[2] == nil)
check("encode round-trips, sets in name order", ReforgeRules.Encode(decoded) == saved)
check("a state round-trips", ReforgeRules.EncodeState(ReforgeRules.DecodeState("7:Might=55,Swift=30")) == "7:Might=55,Swift=30")
check("a level 0 set isn't saved", ReforgeRules.Encode({ Revolver = stateWith(0) }) == "")
check("a half-empty state encodes with a dash", ReforgeRules.EncodeState(stateWith(7, { [2] = { id = "Swift", value = 30 } })) == "7:-,Swift=30")

-- bad text is cleaned, never an error
check("level 99 becomes the cap", ReforgeRules.DecodeState("99:-,-").level == 10)
check("a negative or letter level becomes 0", ReforgeRules.DecodeState("x:Might=50").level == 0)
check("an unknown modifier is dropped", ReforgeRules.DecodeState("7:Bogus=50,-").mods[1] == nil)
check("a value over the max is clamped", ReforgeRules.DecodeState("7:Might=999,-").mods[1].value == 100)
check("a value under the min is clamped", ReforgeRules.DecodeState("7:Might=1,-").mods[1].value == 30)
check("a duplicate modifier in slot 2 is dropped", ReforgeRules.DecodeState("7:Might=50,Might=60").mods[2] == nil)
check("a modifier in a locked slot is dropped", ReforgeRules.DecodeState("3:-,Swift=50").mods[2] == nil)
check("an unknown set is dropped", ReforgeRules.Decode("Nope=7:Might=50,-", function(name)
	return name ~= "Nope"
end).Nope == nil)
check("empty text decodes to nothing", next(ReforgeRules.Decode("", function()
	return true
end)) == nil)
check("garbage decodes to nothing", next(ReforgeRules.Decode("%%;;==", function()
	return true
end)) == nil)
check("garbage state is a level 0 state", ReforgeRules.DecodeState("%%==,,").level == 0)
check("non-string text is a level 0 state", ReforgeRules.DecodeState(nil).level == 0)

if failures > 0 then
	error(failures .. " failed")
end
