-- Crafting at the 3D printer: every recipe and number, and the pure rules,
-- free of Roblox types so Lune can test them (tests/CraftConfig.spec.luau). The
-- server module Crafting spends materials (DropConfig's Mat_<key>) and yen and
-- keeps the saved texts; CraftServer makes the CraftAction remote; PrinterMenu
-- is the client's menu, opened at anything tagged "Printer".
-- A print is a job: the saved PrintJobs text, "recipe|seed|finishAt" per job
-- (finishAt is os.time(), so offline time counts). The result is rolled from the
-- seed only when it's collected, so rejoining can't reroll it.
-- A recipe is known from the start (access "known") or learned (access "learn",
-- kept in the saved RecipesKnown text) by one of its routes: buy (yen), drop
-- (a blueprint, a counted material), quest (taught when that bounty is done,
-- "giverId/questId") or faction (a rank, 1 = the lowest, in a faction or "Any").
-- An empty `routes` means only a script gives it. Numbers are placeholders.
local CraftConfig = {}

CraftConfig.Tag = "Printer" -- a part or model in workspace
CraftConfig.Range = 14 -- studs from the printer the player must be within
CraftConfig.Remote = "CraftAction" -- RemoteFunction, made by CraftServer
CraftConfig.JobsAttribute = "PrintJobs" -- on the player, saved (PlayerStats)
CraftConfig.KnownAttribute = "RecipesKnown" -- on the player, saved (PlayerStats)
CraftConfig.MaxSaveLength = 400
CraftConfig.JobSlotLevels = { 0, 20, 50 } -- the level that opens job slot 1, 2, 3
CraftConfig.CancelRefund = 0.5 -- share of the materials a cancelled print gives back (no yen)

-- in the order the menu lists them
--   tier: the grade of the materials (Scrap, Core, Crystal, Essence)
--   output: { kind = "gear", slot = "Head" | "Body" } or { kind = "talisman", key }
--   gear only: rarityWeights, maxLevel (the piece's level is the player's, capped), affix (a themed affix hint)
CraftConfig.Recipes = {
	{
		id = "RoughHelm",
		name = "Rough Helm",
		tier = "Scrap",
		materials = { { material = "Scrap", amount = 20 } },
		yen = 300,
		seconds = 60,
		output = { kind = "gear", slot = "Head" },
		access = "known",
		rarityWeights = { Common = 80, Uncommon = 20 },
		maxLevel = 20,
	},
	{
		id = "RoughPlate",
		name = "Rough Plate",
		tier = "Scrap",
		materials = { { material = "Scrap", amount = 20 } },
		yen = 300,
		seconds = 60,
		output = { kind = "gear", slot = "Body" },
		access = "known",
		rarityWeights = { Common = 80, Uncommon = 20 },
		maxLevel = 20,
	},
	{
		id = "ReinforcedHelm",
		name = "Reinforced Helm",
		tier = "Core",
		materials = { { material = "Core", amount = 15 } },
		yen = 2000,
		seconds = 300,
		output = { kind = "gear", slot = "Head" },
		access = "learn",
		routes = { { kind = "buy", yen = 5000 } },
		rarityWeights = { Uncommon = 55, Rare = 45 },
		maxLevel = 50,
	},
	{
		id = "PrismHelm",
		name = "Prism Helm",
		tier = "Essence",
		materials = { { material = "PrismShard", amount = 5 }, { material = "Essence", amount = 3 } },
		yen = 50000,
		seconds = 1800,
		output = { kind = "gear", slot = "Head" },
		access = "learn",
		routes = { { kind = "drop", blueprint = "PrismHelmBlueprint" } },
		rarityWeights = { Epic = 70, Legendary = 30 },
		affix = "damageDealt",
		maxLevel = 100,
	},
	{
		id = "VigorCharm",
		name = "Vigor Talisman",
		tier = "Core",
		materials = { { material = "Core", amount = 8 } },
		yen = 1500,
		seconds = 120,
		output = { kind = "talisman", key = "Vigor" },
		access = "learn",
		routes = { { kind = "quest", id = "Frontier/henchmen" }, { kind = "faction", faction = "Any", rank = 2 } },
	},
}

local byId = {}
for _, recipe in ipairs(CraftConfig.Recipes) do
	byId[recipe.id] = recipe
end

function CraftConfig.Get(id)
	return byId[id]
end

-- a whole number from a saved text, or nil
local function wholeNumber(text, min)
	local number = tonumber(text)
	if not number or number ~= number or number < min or number >= 2 ^ 53 or number % 1 ~= 0 then
		return nil
	end
	return number
end

-- the valid jobs in a saved text, in order
function CraftConfig.ParseJobs(text)
	local jobs = {}
	if typeof(text) ~= "string" then
		return jobs
	end
	for entry in string.gmatch(text, "[^;]+") do
		local id, seed, finishAt = string.match(entry, "^([^|]+)|([^|]+)|([^|]+)$")
		seed, finishAt = wholeNumber(seed, 1), wholeNumber(finishAt, 0)
		if id and byId[id] and seed and finishAt then
			table.insert(jobs, { recipe = id, seed = seed, finishAt = finishAt })
		end
	end
	return jobs
end

function CraftConfig.EncodeJobs(jobs)
	local parts = {}
	for _, job in ipairs(jobs) do
		table.insert(parts, string.format("%s|%d|%d", job.recipe, job.seed, job.finishAt))
	end
	return table.concat(parts, ";")
end

-- the learned recipes in a saved text (only learnable ones), once each
function CraftConfig.ParseKnown(text)
	local list, seen = {}, {}
	if typeof(text) ~= "string" then
		return list
	end
	for id in string.gmatch(text, "[^,]+") do
		local recipe = byId[id]
		if recipe and recipe.access == "learn" and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	return list
end

function CraftConfig.EncodeKnown(list)
	return table.concat(list, ",")
end

function CraftConfig.IsKnown(knownText, id)
	local recipe = byId[id]
	if not recipe then
		return false
	end
	return recipe.access == "known" or table.find(CraftConfig.ParseKnown(knownText), id) ~= nil
end

-- how many prints a player of this level can run at once
function CraftConfig.JobSlots(level)
	local slots = 0
	for _, at in ipairs(CraftConfig.JobSlotLevels) do
		if level >= at then
			slots += 1
		end
	end
	return slots
end

-- the level the next job slot opens at, or nil when all are open
function CraftConfig.NextSlotLevel(level)
	for _, at in ipairs(CraftConfig.JobSlotLevels) do
		if level < at then
			return at
		end
	end
	return nil
end

-- `material(key)` is how many the player holds
function CraftConfig.CanAfford(recipe, material, yen)
	if (yen or 0) < recipe.yen then
		return false
	end
	for _, cost in ipairs(recipe.materials) do
		if material(cost.material) < cost.amount then
			return false
		end
	end
	return true
end

-- the jobs text with a new print of `id`, or nil and why not (the cost is checked apart)
function CraftConfig.Start(knownText, jobsText, id, level, now, seed)
	local recipe = byId[id]
	if not recipe then
		return nil, "Unknown recipe"
	end
	if not CraftConfig.IsKnown(knownText, id) then
		return nil, "Recipe not learned"
	end
	local jobs = CraftConfig.ParseJobs(jobsText)
	if #jobs >= CraftConfig.JobSlots(level) then
		return nil, "No free print slot"
	end
	table.insert(jobs, { recipe = id, seed = seed, finishAt = now + recipe.seconds })
	local text = CraftConfig.EncodeJobs(jobs)
	if #text > CraftConfig.MaxSaveLength then
		return nil, "No free print slot"
	end
	return text
end

function CraftConfig.IsReady(job, now)
	return now >= job.finishAt
end

-- the jobs text without job `index`, and that job; nil when there's no such job
function CraftConfig.Remove(jobsText, index)
	local jobs = CraftConfig.ParseJobs(jobsText)
	local job = jobs[index]
	if not job then
		return nil
	end
	table.remove(jobs, index)
	return CraftConfig.EncodeJobs(jobs), job
end

-- the materials a cancelled print gives back
function CraftConfig.Refund(recipe)
	local back = {}
	for _, cost in ipairs(recipe.materials) do
		local amount = math.floor(cost.amount * CraftConfig.CancelRefund)
		if amount > 0 then
			table.insert(back, { material = cost.material, amount = amount })
		end
	end
	return back
end

-- the recipe's route of this kind, or nil
function CraftConfig.Route(recipe, routeKind)
	for _, route in ipairs(recipe.routes or {}) do
		if route.kind == routeKind then
			return route
		end
	end
	return nil
end

-- the known text with `id` learned, or nil and why not (whether the route's
-- condition is met is the server's to check)
function CraftConfig.Learn(knownText, id, routeKind)
	local recipe = byId[id]
	if not recipe then
		return nil, "Unknown recipe"
	end
	if CraftConfig.IsKnown(knownText, id) then
		return nil, "Already known"
	end
	if not CraftConfig.Route(recipe, routeKind) then
		return nil, "Can't be learned that way"
	end
	local known = CraftConfig.ParseKnown(knownText)
	table.insert(known, id)
	local text = CraftConfig.EncodeKnown(known)
	if #text > CraftConfig.MaxSaveLength then
		return nil, "Too many recipes to save"
	end
	return text
end

-- the recipes a bounty teaches when it's done ("giverId/questId")
function CraftConfig.TaughtBy(questId)
	local list = {}
	for _, recipe in ipairs(CraftConfig.Recipes) do
		local route = CraftConfig.Route(recipe, "quest")
		if route and route.id == questId then
			table.insert(list, recipe.id)
		end
	end
	return list
end

-- a rarity from weights; `random()` is in [0, 1). Rarities are walked in name
-- order, so the same seed gives the same rarity everywhere
function CraftConfig.RollRarity(weights, random)
	local names, total = {}, 0
	for name, weight in pairs(weights) do
		table.insert(names, name)
		total += weight
	end
	table.sort(names)
	local left = random() * total
	for _, name in ipairs(names) do
		if left < weights[name] then
			return name
		end
		left -= weights[name]
	end
	return names[#names]
end

-- a gear piece's level: the player's, capped by the recipe
function CraftConfig.GearLevel(recipe, playerLevel)
	return math.clamp(playerLevel, 1, recipe.maxLevel or playerLevel)
end

return CraftConfig
