-- Enemy drops: every number and name. Enemies tagged "Enemy" drop materials
-- as orbs (ServerScriptService.Drops); each player who helped gets their own.
-- Materials are the saved player attributes Mat_<key>, spent in Reforge
-- (ReforgeConfig). The rules at the bottom are pure so tests/ can check them.
local DropConfig = {}

DropConfig.ContributionShare = 0.1 -- a helper dealt this share of the enemy's max health
DropConfig.HoverHeight = 2 -- studs an orb floats over the ground
DropConfig.ScatterRadius = 4 -- orbs land up to this far from where the enemy died
DropConfig.OwnerWindow = 30 -- seconds only the owner can take an orb
DropConfig.PublicWindow = 30 -- seconds anyone can, after that
DropConfig.MaxDrops = 200 -- orbs that exist at once (the oldest go first)
DropConfig.PickupRange = 6 -- studs, flat
DropConfig.PickupHeight = 8 -- studs up or down
DropConfig.PickupInterval = 0.2 -- seconds between pickup checks
DropConfig.MaxPerMaterial = 999

DropConfig.PrefabPath = "DroppedItemOrb" -- under ReplicatedStorage.VFXPrefabs
DropConfig.FolderName = "Drops" -- in workspace
DropConfig.EnemyTag = "Enemy"
DropConfig.TableAttribute = "DropTable" -- on an enemy model: a key of Tables

-- a tier picks the orb part (a child of the prefab) and the colour; a tier
-- with `variants` picks one by weight per drop, each with its own label colour
DropConfig.Tiers = {
	Common = { order = 1, orb = "CommonOrb", rgb = { 170, 170, 175 } },
	Rare = { order = 2, orb = "RareOrb", rgb = { 70, 140, 255 } },
	Gold = { order = 3, orb = "GoldOrb", rgb = { 255, 205, 60 } },
	Dark = {
		order = 4,
		rgb = { 170, 110, 230 },
		variants = {
			{ part = "DarkOrbRed", weight = 3, rgb = { 230, 60, 60 } },
			{ part = "DarkOrbPurple", weight = 1, rgb = { 170, 110, 230 } },
		},
	},
}

-- the orb part and label colour for one drop of a tier; `roll` is in [0, 1)
function DropConfig.Variant(tier, roll)
	local info = DropConfig.Tiers[tier]
	if not info.variants then
		return { part = info.orb, rgb = info.rgb }
	end
	local total = 0
	for _, variant in ipairs(info.variants) do
		total += variant.weight
	end
	local left = roll * total
	for _, variant in ipairs(info.variants) do
		if left < variant.weight then
			return variant
		end
		left -= variant.weight
	end
	return info.variants[#info.variants]
end

function DropConfig.TierColor(tier)
	local rgb = DropConfig.Tiers[tier].rgb
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- every material: its tier and the name players see (placeholders to rename)
DropConfig.Materials = {
	Scrap = { tier = "Common", display = "Scrap" },
	Core = { tier = "Rare", display = "Core" },
	Crystal = { tier = "Gold", display = "Crystal" },
	Essence = { tier = "Dark", display = "Essence" },
	WolfFang = { tier = "Rare", display = "Wolf Fang" },
}

-- what any enemy of at least `minLevel` rolls, per helper
DropConfig.Generic = {
	{ material = "Scrap", minLevel = 1, chance = 0.4, min = 1, max = 3 },
	{ material = "Core", minLevel = 10, chance = 0.12, min = 1, max = 2 },
	{ material = "Crystal", minLevel = 30, chance = 0.03, min = 1, max = 1 },
	{ material = "Essence", minLevel = 50, chance = 0.005, min = 1, max = 1 },
}

-- extra rolls for an enemy whose DropTable attribute names one
DropConfig.Tables = {
	Wolf = { { material = "WolfFang", chance = 0.1, min = 1, max = 1 } },
}

-- the player attribute holding a material (same as ReforgeConfig.MaterialAttribute)
function DropConfig.Attribute(key)
	return "Mat_" .. key
end

-- what one helper gets from one kill: a list of { material, amount }.
-- `random()` returns [0, 1); per entry one draw decides the chance (passes
-- when below it) and, only if it passed, a second picks the amount
function DropConfig.Rolls(level, tableName, random)
	level = math.max(level or 1, 1)
	local rolls = {}
	local function roll(entry)
		if random() < entry.chance then
			local amount = math.min(entry.min + math.floor(random() * (entry.max - entry.min + 1)), entry.max)
			table.insert(rolls, { material = entry.material, amount = amount })
		end
	end
	for _, entry in ipairs(DropConfig.Generic) do
		if level >= entry.minLevel then
			roll(entry)
		end
	end
	for _, entry in ipairs(tableName and DropConfig.Tables[tableName] or {}) do
		roll(entry)
	end
	return rolls
end

function DropConfig.IsHelper(damage, maxHealth)
	return maxHealth > 0 and damage > 0 and damage >= maxHealth * DropConfig.ContributionShare
end

-- how much of `amount` a bag holding `current` takes, and how much is left over
function DropConfig.Fit(current, amount)
	local taken = math.clamp(DropConfig.MaxPerMaterial - current, 0, amount)
	return taken, amount - taken
end

-- the owner at any time; anyone once the orb is public
function DropConfig.CanPickUp(ownerUserId, playerUserId, now, publicAt)
	return ownerUserId == playerUserId or now >= publicAt
end

function DropConfig.InRange(flatDistance, heightDifference)
	return flatDistance <= DropConfig.PickupRange and math.abs(heightDifference) <= DropConfig.PickupHeight
end

-- every material key, by tier and then display name (for the Inventory)
function DropConfig.Sorted()
	local keys = {}
	for key in pairs(DropConfig.Materials) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local materialA, materialB = DropConfig.Materials[a], DropConfig.Materials[b]
		local orderA, orderB = DropConfig.Tiers[materialA.tier].order, DropConfig.Tiers[materialB.tier].order
		if orderA ~= orderB then
			return orderA < orderB
		end
		return materialA.display < materialB.display
	end)
	return keys
end

return DropConfig
