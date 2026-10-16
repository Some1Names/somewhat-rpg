-- How powers are held, kept and found (Powers, PowerSources, Inventory, the
-- Power Dealer's shop): the numbers, plus the pure rules (prices, the gacha
-- roll, the saved lists) so they can be tested outside Roblox
-- (tests/PowerConfig.spec.luau). Tiers and set names are passed in, so this
-- requires nothing. All numbers live here.
local PowerConfig = {}

-- strongest first
PowerConfig.Tiers = { "S", "A", "B", "C" }
PowerConfig.TierPrice = { S = 500000, A = 150000, B = 50000, C = 15000 } -- the dealer's price in yen
PowerConfig.TierWeight = { S = 2, A = 8, B = 30, C = 60 } -- gacha and map drop odds (percent)

PowerConfig.StorageSlots = 2
PowerConfig.SellShare = 0.3 -- the dealer buys a briefcase back at this share of its price

-- per power: forSale = false keeps it out of the dealer's yen shop; sellPrice
-- replaces the share of the price (for powers with no yen price)
PowerConfig.Overrides = {
	Aido = { forSale = false, sellPrice = 200000 }, -- Deus Ex Machina, Aido's power
}

PowerConfig.Gacha = {
	price = 25000, -- yen per roll that isn't the free one
	cooldown = 7200, -- seconds of real time between a player's free rolls (extra rolls cost yen any time)
	pity = 60, -- after this many rolls without an S, the next roll is S
	tag = "PowerGacha", -- CollectionService tag on the gacha NPC
	range = 14, -- studs from the NPC
	claimTimeout = 14, -- seconds after a roll before the briefcase is handed over even if the reel never reports done (the reel runs about 7)
}

PowerConfig.Drop = {
	interval = 1200, -- seconds between map briefcases
	lifetime = 1200, -- seconds one waits to be picked up
	tag = "BriefcaseSpawn", -- CollectionService tag on the spawn parts
}

PowerConfig.DealerRange = 14 -- studs from a Power Dealer (a Shop tagged model running the Powers shop)
PowerConfig.DeathDropTime = 60 -- seconds a dropped briefcase waits to be picked up
PowerConfig.DeathPickupDelay = 1 -- seconds before the dead player's new character can grab theirs
PowerConfig.BriefcaseAttribute = "PowerBriefcase" -- on a briefcase Tool: the set inside
PowerConfig.BriefcaseStorageAttribute = "BriefcaseStorage" -- on the player: the briefcases kept in the Backpack (comma separated, not saved)
PowerConfig.BriefcaseStorageLimit = 30 -- most briefcases kept in storage

-- Developer Product ids for lifetime copies, { [setName] = productId }. The
-- owner creates the products (Creator Dashboard -> Developer Products); a
-- power with no entry has no Robux button.
PowerConfig.RobuxProducts = {}

-- A lifetime copy's price in Robux, by tier. These numbers are made up (a placeholder
-- so the shop can show them); the owner sets the real prices with the products.
PowerConfig.RobuxTierPrice = { S = 1500, A = 800, B = 400, C = 150 }

-- the lifetime copy's price in Robux for a power of this tier (a power's Overrides entry
-- can set its own `robuxPrice`); nil when there is none
function PowerConfig.robuxPrice(setName, tier)
	local override = PowerConfig.Overrides[setName]
	if override and override.robuxPrice then
		return override.robuxPrice
	end
	return PowerConfig.RobuxTierPrice[tier]
end

-- the dealer's price in yen for a power of this tier; nil = not for sale
function PowerConfig.price(setName, tier)
	local override = PowerConfig.Overrides[setName]
	if override and override.forSale == false then
		return nil
	end
	return PowerConfig.TierPrice[tier]
end

-- what the dealer pays for a briefcase
function PowerConfig.sellPrice(setName, tier)
	local override = PowerConfig.Overrides[setName]
	if override and override.sellPrice then
		return override.sellPrice
	end
	return math.floor((PowerConfig.TierPrice[tier] or 0) * PowerConfig.SellShare + 1e-9)
end

-- Picks a tier: weighted, over the tiers that have powers (available is
-- { [tier] = { setName } }). With pity at the limit and an S power available
-- the roll is S. rng returns a number in [0, 1).
function PowerConfig.roll(rng, pity, available)
	local usable, total = {}, 0
	for _, tier in ipairs(PowerConfig.Tiers) do
		local list = available[tier]
		if list and #list > 0 then
			table.insert(usable, tier)
			total += PowerConfig.TierWeight[tier]
		end
	end
	if #usable == 0 then
		return nil
	end
	if pity >= PowerConfig.Gacha.pity and table.find(usable, "S") then
		return "S"
	end
	local target = rng() * total
	for _, tier in ipairs(usable) do
		target -= PowerConfig.TierWeight[tier]
		if target < 0 then
			return tier
		end
	end
	return usable[#usable]
end

-- the pity count after a roll that gave this tier
function PowerConfig.nextPity(pity, tier)
	if tier == "S" then
		return 0
	end
	return pity + 1
end

-- a random entry of the list
function PowerConfig.pick(rng, list)
	if #list == 0 then
		return nil
	end
	return list[math.clamp(math.floor(rng() * #list) + 1, 1, #list)]
end

-- the saved text for a list of set names ("A,B"); decode drops repeats,
-- blanks and anything accept (optional) refuses
function PowerConfig.encodeList(list)
	return table.concat(list, ",")
end

function PowerConfig.decodeList(text, accept)
	local list, seen = {}, {}
	if typeof(text) ~= "string" then
		return list
	end
	for name in string.gmatch(text, "[^,]+") do
		if not seen[name] and (not accept or accept(name)) then
			seen[name] = true
			table.insert(list, name)
		end
	end
	return list
end

return PowerConfig
