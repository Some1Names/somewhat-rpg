-- Unit tests for ReplicatedStorage.ReforgeRules (levels, chosen affinities that
-- scale with the level, awakening, the combat multipliers, the saved text).
-- Run with Lune, outside Roblox: tests/run.sh.
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

local rich = setmetatable({}, {
	__index = function()
		return 1000
	end,
})
local none = {}

-- slots
check("no slot below the first unlock", ReforgeRules.SlotsUnlocked(2) == 0)
check("slot 1 opens at +3", ReforgeRules.SlotsUnlocked(3) == 1)
check("slot 2 opens at +7", ReforgeRules.SlotsUnlocked(7) == 2)

-- levelling
local fresh = ReforgeRules.NewState()
local ok, cost = ReforgeRules.PlanLevelUp(fresh, rich, 1e6)
check("level 1 costs 10 Scrap and 200 yen", ok and cost.material == "Scrap" and cost.amount == 10 and cost.yen == 200)
local _, cost4 = ReforgeRules.PlanLevelUp({ level = 3, mods = {}, awakening = 0 }, rich, 1e6)
check("level 4 costs 5 Core and 1000 yen", cost4.material == "Core" and cost4.amount == 5 and cost4.yen == 1000)
local _, cost7 = ReforgeRules.PlanLevelUp({ level = 6, mods = {}, awakening = 0 }, rich, 1e6)
check("level 7 costs 3 Crystal and 5000 yen", cost7.material == "Crystal" and cost7.amount == 3 and cost7.yen == 5000)
local _, cost10 = ReforgeRules.PlanLevelUp({ level = 9, mods = {}, awakening = 0 }, rich, 1e6)
check("level 10 costs 3 Essence and 20000 yen", cost10.material == "Essence" and cost10.amount == 3 and cost10.yen == 20000)
local lacking, why = ReforgeRules.PlanLevelUp(fresh, none, 1e6)
check("level up refused without the material", not lacking and string.find(why, "Scrap", 1, true) ~= nil)
local poor, whyPoor = ReforgeRules.PlanLevelUp(fresh, rich, 0)
check("level up refused without the yen", not poor and string.find(whyPoor, "¥", 1, true) ~= nil)
check("no level past the top", not (ReforgeRules.PlanLevelUp({ level = 10, mods = {}, awakening = 0 }, rich, 1e6)))

-- affinity values
local might = ReforgeConfig.Modifier("Might")
check("an affinity is at its minimum at +0", ReforgeRules.AffinityValue("Might", 0, 0) == might.min)
check("an affinity is at its maximum at the top level", ReforgeRules.AffinityValue("Might", 10, 0) == might.max)
check("an affinity grows with the level", ReforgeRules.AffinityValue("Might", 5, 0) > ReforgeRules.AffinityValue("Might", 4, 0))
check("awakening strengthens it", ReforgeRules.AffinityValue("Might", 10, 2) == math.floor(might.max * 1.2 + 0.5))
check("an unknown affinity is worth nothing", ReforgeRules.AffinityValue("Nope", 10, 0) == 0)

-- choosing
local open = { level = 3, mods = {}, awakening = 0 }
check("choosing in an open slot works", (ReforgeRules.PlanChoose(open, 1, "Might", rich, 1e6)))
check("a locked slot refuses", not (ReforgeRules.PlanChoose(open, 2, "Might", rich, 1e6)))
check("a bad slot refuses", not (ReforgeRules.PlanChoose(open, 0, "Might", rich, 1e6)) and not (ReforgeRules.PlanChoose(open, 1.5, "Might", rich, 1e6)))
check("an unknown affinity refuses", not (ReforgeRules.PlanChoose(open, 1, "Nope", rich, 1e6)))
local chosen = { level = 7, mods = { { id = "Might" } }, awakening = 0 }
check("the same affinity again refuses", not (ReforgeRules.PlanChoose(chosen, 1, "Might", rich, 1e6)))
check("the other slot's affinity refuses", not (ReforgeRules.PlanChoose(chosen, 2, "Might", rich, 1e6)))
check("a different affinity works", (ReforgeRules.PlanChoose(chosen, 2, "Swift", rich, 1e6)))
check("choosing refused without the material", not (ReforgeRules.PlanChoose(open, 1, "Might", none, 1e6)))

-- awakening
local top = { level = 10, mods = {}, awakening = 0 }
local can, awakenCost = ReforgeRules.PlanAwaken(top, true, rich, 1e6)
check("a power at +10 can awaken, with Essence", can and awakenCost.material == "Essence")
check("a weapon can't awaken", not (ReforgeRules.PlanAwaken(top, false, rich, 1e6)))
check("a power below +10 can't awaken", not (ReforgeRules.PlanAwaken({ level = 9, mods = {}, awakening = 0 }, true, rich, 1e6)))
check("awakening needs the Essence", not (ReforgeRules.PlanAwaken(top, true, none, 1e6)))
check("awakening needs the yen", not (ReforgeRules.PlanAwaken(top, true, rich, 0)))
check("no awakening past the last stage", not (ReforgeRules.PlanAwaken({ level = 10, mods = {}, awakening = ReforgeConfig.MaxAwakening }, true, rich, 1e6)))

-- combat numbers
check("a fresh set changes nothing", near(ReforgeRules.DamageMultiplier(fresh, false), 1))
check("a level adds damage", near(ReforgeRules.DamageMultiplier({ level = 5, mods = {}, awakening = 0 }, false), 1 + 5 * ReforgeConfig.DamagePerLevel))
check("the bonus is halved against a player", near(ReforgeRules.DamageMultiplier({ level = 5, mods = {}, awakening = 0 }, true), 1 + 5 * ReforgeConfig.DamagePerLevel * ReforgeConfig.PvPFactor))
check("awakening adds damage", near(ReforgeRules.DamageBonus({ level = 10, mods = {}, awakening = 2 }), 10 * ReforgeConfig.DamagePerLevel + 2 * ReforgeConfig.DamagePerAwakening))
local mighty = { level = 10, mods = { { id = "Might" } }, awakening = 0 }
check("Might adds its value to damage", near(ReforgeRules.DamageBonus(mighty), 10 * ReforgeConfig.DamagePerLevel + might.max / 1000))
local swift = { level = 10, mods = { { id = "Swift" } }, awakening = 0 }
check("Swift shortens cooldowns", near(ReforgeRules.CooldownMultiplier(swift), 1 - ReforgeConfig.Modifier("Swift").max / 1000))
local burning = { level = 10, mods = { { id = "Searing" } }, awakening = 0 }
check("a status affinity gives its chance", near(ReforgeRules.StatusChance(burning, "Burnt"), ReforgeConfig.Modifier("Searing").max / 1000) and ReforgeRules.StatusChance(burning, "Poisoned") == 0)
local vampire = { level = 10, mods = { { id = "Vampiric" } }, awakening = 0 }
check("Vampiric steals life", near(ReforgeRules.Lifesteal(vampire), ReforgeConfig.Modifier("Vampiric").max / 1000))

-- saved text
check("a state round trips", ReforgeRules.EncodeState({ level = 7, mods = { { id = "Might" } }, awakening = 0 }) == "7:Might,-")
check("an awakened state round trips", ReforgeRules.EncodeState({ level = 10, mods = { { id = "Might" }, { id = "Swift" } }, awakening = 2 }) == "10:Might,Swift:2")
local decoded = ReforgeRules.DecodeState("10:Might,Swift:2")
check("it decodes", decoded.level == 10 and decoded.mods[1].id == "Might" and decoded.mods[2].id == "Swift" and decoded.awakening == 2)
local old = ReforgeRules.DecodeState("7:Might=55,-")
check("an old save's values are ignored", old.level == 7 and old.mods[1].id == "Might" and old.mods[2] == nil and old.awakening == 0)
check("an awakening below the top level is dropped", ReforgeRules.DecodeState("9:-,-:3").awakening == 0)
check("an awakening past the last stage is clamped", ReforgeRules.DecodeState("10:-,-:9").awakening == ReforgeConfig.MaxAwakening)
check("a slot past the open ones is dropped", ReforgeRules.DecodeState("3:Might,Swift").mods[2] == nil)
check("a repeated affinity is dropped", ReforgeRules.DecodeState("7:Might,Might").mods[2] == nil)
check("an unknown affinity is dropped", ReforgeRules.DecodeState("7:Nope,Might").mods[1] == nil and ReforgeRules.DecodeState("7:Nope,Might").mods[2].id == "Might")
check("a level past the top is clamped", ReforgeRules.DecodeState("99:-,-").level == ReforgeConfig.MaxLevel)
check("garbage is a fresh state", ReforgeRules.DecodeState("???").level == 0 and ReforgeRules.DecodeState(nil).level == 0)

local text = ReforgeRules.Encode({ Mandela = decoded, Revolver = { level = 4, mods = { { id = "Venom" } }, awakening = 0 }, Idle = fresh })
check("sets are saved sorted, a level-0 set left out", text == "Mandela=10:Might,Swift:2;Revolver=4:Venom,-")
local states = ReforgeRules.Decode(text, function(name)
	return name ~= "Revolver"
end)
check("decoding keeps only real sets", states.Mandela ~= nil and states.Revolver == nil)

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all ReforgeRules checks passed")
