-- Unit tests for ReplicatedStorage.CraftConfig (recipes, job slots, the saved
-- texts, starting, readiness, refunds, learning, rarity rolls). Run with Lune,
-- outside Roblox: tests/run.sh.
local C = require("../src/ReplicatedStorage/CraftConfig")
local Gear = require("../src/ReplicatedStorage/GearConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- every recipe is well formed and ids are unique
local ids = {}
local sane = true
for _, recipe in ipairs(C.Recipes) do
	local kind = recipe.output and recipe.output.kind
	if ids[recipe.id] or not (recipe.seconds and recipe.seconds > 0) or #recipe.materials == 0 then
		sane = false
	end
	if kind ~= "gear" and kind ~= "talisman" then
		sane = false
	end
	if recipe.access == "learn" and typeof(recipe.routes) ~= "table" then
		sane = false
	end
	if C.Get(recipe.id) ~= recipe then
		sane = false
	end
	ids[recipe.id] = true
end
check("recipes are well formed", sane and #C.Recipes >= 5)
check("get of a made-up recipe is nil", C.Get("Nope") == nil)

check("job slots by level", C.JobSlots(1) == 1 and C.JobSlots(19) == 1 and C.JobSlots(20) == 2 and C.JobSlots(50) == 3)
check("next slot level", C.NextSlotLevel(1) == 20 and C.NextSlotLevel(20) == 50 and C.NextSlotLevel(50) == nil)

-- the jobs text
local jobs = C.ParseJobs("RoughHelm|5|100;Nope|1|1;RoughHelm|x|y;;RoughHelm|-3|-9")
check("parse keeps only valid jobs", #jobs == 1 and jobs[1].recipe == "RoughHelm" and jobs[1].seed == 5 and jobs[1].finishAt == 100)
check("parse of nothing is empty", #C.ParseJobs("") == 0 and #C.ParseJobs(nil) == 0 and #C.ParseJobs(42) == 0)
check("jobs round-trip", C.EncodeJobs(C.ParseJobs("RoughHelm|5|100;RoughPlate|7|200")) == "RoughHelm|5|100;RoughPlate|7|200")
check("parse drops fractions and junk numbers", #C.ParseJobs("RoughHelm|1.5|100;RoughHelm|1|1e400") == 0)

-- the known text
check("known keeps learnable ids once", table.concat(C.ParseKnown("ReinforcedHelm,Nope,RoughHelm,ReinforcedHelm"), ",") == "ReinforcedHelm")
check("known round-trips", C.EncodeKnown(C.ParseKnown("ReinforcedHelm,PrismHelm")) == "ReinforcedHelm,PrismHelm")
check("a known recipe is always known", C.IsKnown("", "RoughHelm") and C.IsKnown(nil, "RoughPlate"))
check("a learn recipe needs learning", not C.IsKnown("", "ReinforcedHelm") and C.IsKnown("ReinforcedHelm", "ReinforcedHelm"))
check("a made-up recipe isn't known", not C.IsKnown("Nope", "Nope"))

-- affordability
local helm = C.Get("RoughHelm")
local need = helm.materials[1]
local function bag(amount)
	return function(key)
		return key == need.material and amount or 0
	end
end
check("can afford at exactly enough", C.CanAfford(helm, bag(need.amount), helm.yen))
check("can't afford one material short", not C.CanAfford(helm, bag(need.amount - 1), helm.yen))
check("can't afford one yen short", not C.CanAfford(helm, bag(need.amount), helm.yen - 1))

-- starting
local text, why = C.Start("", "", "RoughHelm", 1, 1000, 42)
check("start appends a job", text == "RoughHelm|42|" .. (1000 + helm.seconds) and why == nil)
local full, fullWhy = C.Start("", text, "RoughPlate", 1, 1000, 43)
check("one slot, one job: no free slot", full == nil and fullWhy == "No free print slot")
check("a second slot at level 20", C.Start("", text, "RoughPlate", 20, 1000, 43) ~= nil)
local locked, lockedWhy = C.Start("", "", "ReinforcedHelm", 50, 1000, 1)
check("an unlearned recipe can't start", locked == nil and lockedWhy == "Recipe not learned")
check("a learned one can", C.Start("ReinforcedHelm", "", "ReinforcedHelm", 50, 1000, 1) ~= nil)
local unknown, unknownWhy = C.Start("", "", "Nope", 50, 1000, 1)
check("a made-up recipe can't start", unknown == nil and unknownWhy == "Unknown recipe")

-- readiness
check("not ready a second early", C.IsReady({ finishAt = 100 }, 99) == false)
check("ready on time", C.IsReady({ finishAt = 100 }, 100) == true)

-- removing
check("remove out of range is nil", C.Remove("RoughHelm|1|100", 2) == nil and C.Remove("RoughHelm|1|100", 0) == nil)
local rest, job = C.Remove("RoughHelm|1|100;RoughPlate|2|200", 1)
check("remove returns the job and the rest", rest == "RoughPlate|2|200" and job and job.recipe == "RoughHelm" and job.seed == 1)

-- refunds
local small = { materials = { { material = "Scrap", amount = 1 } } }
check("a refund of 1 is nothing", #C.Refund(small) == 0)
local big = C.Refund({ materials = { { material = "Scrap", amount = 15 }, { material = "Core", amount = 1 } } })
check("a refund of 15 is 7", #big == 1 and big[1].material == "Scrap" and big[1].amount == 7)

-- learning
local learned = C.Learn("", "ReinforcedHelm", "buy")
check("learn adds the recipe", learned == "ReinforcedHelm")
local again, againWhy = C.Learn(learned, "ReinforcedHelm", "buy")
check("learning twice is refused", again == nil and againWhy == "Already known")
local wrong, wrongWhy = C.Learn("", "ReinforcedHelm", "drop")
check("a route the recipe hasn't is refused", wrong == nil and wrongWhy == "Can't be learned that way")
local starter, starterWhy = C.Learn("", "RoughHelm", "buy")
check("a starter recipe is already known", starter == nil and starterWhy == "Already known")
check("learning a made-up recipe is refused", select(2, C.Learn("", "Nope", "buy")) == "Unknown recipe")
check("route finds the recipe's route", C.Route(C.Get("ReinforcedHelm"), "buy").yen > 0 and C.Route(C.Get("ReinforcedHelm"), "drop") == nil)

-- rarity
check("rarity roll high", C.RollRarity({ Common = 1, Rare = 1 }, function()
	return 0.99
end) == "Rare")
check("rarity roll low", C.RollRarity({ Common = 1, Rare = 1 }, function()
	return 0
end) == "Common")
check("rarity of a lone weight", C.RollRarity({ Epic = 5 }, function()
	return 0.5
end) == "Epic")

-- gear levels
check("gear level is the player's, capped", C.GearLevel(helm, 7) == 7 and C.GearLevel(helm, 99) == helm.maxLevel)

-- a recipe's themed affix must be a real gear affix, or GearConfig.Roll silently drops it
local affixIds = {}
for _, affix in ipairs(Gear.Affixes) do
	affixIds[affix.id] = true
end
local affixesReal = true
for _, recipe in ipairs(C.Recipes) do
	if recipe.affix and not affixIds[recipe.affix] then
		affixesReal = false
	end
end
check("every recipe affix is a gear affix", affixesReal)

if failures > 0 then
	error(failures .. " failed")
end
