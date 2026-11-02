-- Crafting at the 3D printer (recipes and rules: ReplicatedStorage.CraftConfig).
-- The running prints and the learned recipes are the saved PrintJobs /
-- RecipesKnown attributes (PlayerStats). Each action checks everything before it
-- takes anything, so a refusal costs nothing: Start pays materials and yen and
-- saves the job, Collect rolls the result from the job's seed and gives it
-- (gear through ServerScriptService.Gear once the equipment system exists, a
-- talisman through Talismans), Cancel gives back CancelRefund of the materials,
-- Learn pays a route's yen or blueprint. CraftServer calls these for the
-- printer's menu (it checks the player is at a printer). A quest route is
-- taught by Quests when that bounty is done.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CraftConfig = require(ReplicatedStorage:WaitForChild("CraftConfig"))
local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))
local TalismanConfig = require(ReplicatedStorage:WaitForChild("TalismanConfig"))
local Factions = require(script.Parent:WaitForChild("Factions"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local Talismans = require(script.Parent:WaitForChild("Talismans"))

local Crafting = {}

local rng = Random.new()

-- the equipment system's module, when it exists (gear recipes wait for it)
local function gearModule()
	local module = script.Parent:FindFirstChild("Gear")
	return module and require(module)
end

local function loaded(player)
	return player:GetAttribute(CraftConfig.JobsAttribute) ~= nil
		and player:GetAttribute(CraftConfig.KnownAttribute) ~= nil
		and player:GetAttribute("Yen") ~= nil
end

local function materialOf(player)
	return function(key)
		return player:GetAttribute(DropConfig.Attribute(key)) or 0
	end
end

local function addMaterials(player, list)
	for _, entry in ipairs(list) do
		local attribute = DropConfig.Attribute(entry.material)
		local current = player:GetAttribute(attribute) or 0
		local taken = DropConfig.Fit(current, entry.amount)
		player:SetAttribute(attribute, current + taken)
	end
end

local function ownsTalisman(player, key)
	return table.find(TalismanConfig.Owned(player:GetAttribute(TalismanConfig.OwnedAttribute)), key) ~= nil
end

-- starts a print of recipe `id`
function Crafting.Start(player, id)
	if not loaded(player) then
		return false, "Still loading"
	end
	local recipe = CraftConfig.Get(id)
	if not recipe then
		return false, "Unknown recipe"
	end
	if recipe.output.kind == "gear" and not gearModule() then
		return false, "Gear can't be printed yet"
	end
	if recipe.output.kind == "talisman" and ownsTalisman(player, recipe.output.key) then
		return false, "You already own that talisman"
	end
	local jobs, why = CraftConfig.Start(
		player:GetAttribute(CraftConfig.KnownAttribute),
		player:GetAttribute(CraftConfig.JobsAttribute),
		id,
		player:GetAttribute("Level") or 0,
		os.time(),
		rng:NextInteger(1, 2 ^ 31 - 1)
	)
	if not jobs then
		return false, why
	end
	if not CraftConfig.CanAfford(recipe, materialOf(player), player:GetAttribute("Yen")) then
		return false, "Not enough materials or yen"
	end
	if not PlayerStats.SpendYen(player, recipe.yen) then
		return false, "Not enough yen"
	end
	for _, cost in ipairs(recipe.materials) do
		local attribute = DropConfig.Attribute(cost.material)
		player:SetAttribute(attribute, player:GetAttribute(attribute) - cost.amount)
	end
	player:SetAttribute(CraftConfig.JobsAttribute, jobs)
	return true, recipe.name .. " is printing"
end

-- takes a finished print out of slot `index`
function Crafting.Collect(player, index)
	if not loaded(player) then
		return false, "Still loading"
	end
	local jobsText = player:GetAttribute(CraftConfig.JobsAttribute)
	local job = CraftConfig.ParseJobs(jobsText)[index]
	if not job then
		return false, "No such print"
	end
	if not CraftConfig.IsReady(job, os.time()) then
		return false, "Still printing"
	end
	local recipe = CraftConfig.Get(job.recipe)
	local rest = CraftConfig.Remove(jobsText, index)
	if recipe.output.kind == "talisman" then
		if not Talismans.Grant(player, recipe.output.key) then
			-- owned some other way since the print started: the materials come back
			player:SetAttribute(CraftConfig.JobsAttribute, rest)
			addMaterials(player, recipe.materials)
			return true, "You already had it, so the materials came back"
		end
		player:SetAttribute(CraftConfig.JobsAttribute, rest)
		return true, recipe.name .. " collected"
	end
	local Gear = gearModule()
	if not Gear then
		return false, "Gear can't be printed yet"
	end
	-- rolled from the saved seed: the same job always gives the same piece
	local seeded = Random.new(job.seed)
	local rarity = CraftConfig.RollRarity(recipe.rarityWeights, function()
		return seeded:NextNumber()
	end)
	local level = CraftConfig.GearLevel(recipe, player:GetAttribute("Level") or 1)
	local ok, why = Gear.Grant(player, recipe.output.slot, rarity, level, job.seed, recipe.affix)
	if not ok then
		return false, why or "Gear bag is full"
	end
	player:SetAttribute(CraftConfig.JobsAttribute, rest)
	return true, string.format("%s %s collected", rarity, recipe.name)
end

-- stops a running print in slot `index`; part of the materials come back, no yen
function Crafting.Cancel(player, index)
	if not loaded(player) then
		return false, "Still loading"
	end
	local jobsText = player:GetAttribute(CraftConfig.JobsAttribute)
	local job = CraftConfig.ParseJobs(jobsText)[index]
	if not job then
		return false, "No such print"
	end
	if CraftConfig.IsReady(job, os.time()) then
		return false, "It's finished: collect it"
	end
	local recipe = CraftConfig.Get(job.recipe)
	player:SetAttribute(CraftConfig.JobsAttribute, (CraftConfig.Remove(jobsText, index)))
	addMaterials(player, CraftConfig.Refund(recipe))
	return true, recipe.name .. " cancelled"
end

-- whether the player has a faction route's rank
local function hasRank(player, route)
	local key, standing = Factions.Get(player)
	return key ~= nil and (route.faction == "Any" or route.faction == key) and FactionConfig.RankIndex(standing or 0) >= route.rank
end

-- learns recipe `id` by one of its routes ("buy", "drop", "faction")
function Crafting.Learn(player, id, routeKind)
	if not loaded(player) then
		return false, "Still loading"
	end
	local known, why = CraftConfig.Learn(player:GetAttribute(CraftConfig.KnownAttribute), id, routeKind)
	if not known then
		return false, why
	end
	local recipe = CraftConfig.Get(id)
	local route = CraftConfig.Route(recipe, routeKind)
	if route.kind == "buy" then
		if not PlayerStats.SpendYen(player, route.yen) then
			return false, "Not enough yen"
		end
	elseif route.kind == "drop" then
		local attribute = DropConfig.Attribute(route.blueprint)
		local held = player:GetAttribute(attribute) or 0
		if held < 1 then
			return false, "You need its blueprint"
		end
		player:SetAttribute(attribute, held - 1)
	elseif route.kind == "quest" then
		return false, "Finish its bounty to learn it" -- taught by Quests when the bounty is done
	elseif not hasRank(player, route) then
		return false, "Your faction rank is too low"
	end
	player:SetAttribute(CraftConfig.KnownAttribute, known)
	return true, "Learned " .. recipe.name
end

-- (admin) every job finishes now
function Crafting.FinishAll(player)
	local jobs = CraftConfig.ParseJobs(player:GetAttribute(CraftConfig.JobsAttribute))
	for _, job in ipairs(jobs) do
		job.finishAt = math.min(job.finishAt, os.time())
	end
	player:SetAttribute(CraftConfig.JobsAttribute, CraftConfig.EncodeJobs(jobs))
end

-- (admin) every learnable recipe is known
function Crafting.LearnAll(player)
	local all = {}
	for _, recipe in ipairs(CraftConfig.Recipes) do
		if recipe.access == "learn" then
			table.insert(all, recipe.id)
		end
	end
	player:SetAttribute(CraftConfig.KnownAttribute, CraftConfig.EncodeKnown(all))
end

return Crafting
