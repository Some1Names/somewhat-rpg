-- Consumable items: Tools a player uses from the hotbar. Two kinds, each item
-- picks one:
--   limited:  carries `maxUses` charges, one spent per use, the Tool is gone
--             at 0. Sold again and again at the shopkeeper (ShopConfig `stack`).
--   lifetime: bought once and owned for good (the shop's Owns<id> attribute),
--             never spent, only held back by its `cooldown`. The server hands
--             the Tool back after every respawn (Consumables).
-- The numbers and the pure rules live here (Lune-tested); the server module
-- Consumables runs the effects. An `effect` names a handler there.
-- All times are seconds, fractions are of max HP.
local ConsumableConfig = {}

ConsumableConfig.Attribute = "Consumable" -- on a Tool: the item's key
ConsumableConfig.UsesAttribute = "Uses" -- on a limited Tool: charges left
ConsumableConfig.CarryLimit = 3 -- most stacks of one limited item a player has (equipped and stored together)
ConsumableConfig.HotbarSlots = 6 -- most consumable Tools equipped on the hotbar (its grid slots 4 to 9)
ConsumableConfig.StorageLimit = 30 -- most stacks kept stored in the Backpack
ConsumableConfig.StorageAttribute = "ConsumableStorage" -- on the player: the stored stacks, saved (PlayerStats)
ConsumableConfig.StackAttribute = "StackId" -- on a Tool: its own number, so the Backpack can follow it
ConsumableConfig.MaxSaveLength = 600 -- StorageLimit entries at most 18 characters each

-- in the order the shop lists them
ConsumableConfig.Items = {
	{
		key = "NanoSyringe",
		name = "Nano-Syringe",
		kind = "limited",
		maxUses = 5,
		price = 120,
		cooldown = 3,
		effect = "Heal",
		heal = 0.30,
		description = "An auto-injector of nanites. Restores 30% max HP.",
	},
	{
		key = "PurgeAmpoule",
		name = "Purge Ampoule",
		kind = "limited",
		maxUses = 3,
		price = 90,
		cooldown = 5,
		effect = "Purge",
		description = "Flushes the foreign signal from your body: clears Poisoned, Bleeding and Burnt.",
	},
	{
		key = "OverclockChip",
		name = "Overclock Chip",
		kind = "limited",
		maxUses = 2,
		price = 200,
		cooldown = 8,
		effect = "Overclock",
		duration = 20, -- the boost
		damageBoost = 0.25, -- outgoing damage while it runs
		crash = 10, -- seconds of the crash that follows
		crashVulnerability = 0.15, -- extra damage taken during the crash
		description = "+25% damage for 20 s, then a 10 s crash where you take 15% more.",
	},
	{
		key = "RiftSuture",
		name = "Rift Suture",
		kind = "lifetime",
		price = 1500,
		cooldown = 90,
		effect = "Suture",
		heal = 0.35, -- total, spread over `duration`
		duration = 5,
		description = "Threads of off-dimension matter knit your wounds: 35% max HP over 5 s, cancelled if you're hit. 90 s cooldown.",
	},
	{
		key = "AnchorGrapple",
		name = "Anchor Grapple",
		kind = "lifetime",
		price = 1200,
		cooldown = 15,
		effect = "Grapple",
		distance = 40,
		description = "A wire launcher: dashes you about 40 studs toward where you face. 15 s cooldown.",
	},
}

local byKey = {}
for _, item in ipairs(ConsumableConfig.Items) do
	byKey[item.key] = item
end

function ConsumableConfig.Get(key)
	return byKey[key]
end

-- the shop id of a lifetime item (what the player attribute Owns<id> is named for)
function ConsumableConfig.ShopId(item)
	return "Consumable_" .. item.key
end

-- a limited Tool's display name, e.g. "Nano-Syringe (3/5)"
function ConsumableConfig.Label(item, uses)
	if item.kind == "limited" then
		return string.format("%s (%d/%d)", item.name, uses, item.maxUses)
	end
	return item.name
end

-- what the shop says about how many uses an item has
function ConsumableConfig.UsesText(item)
	if item.kind == "limited" then
		return string.format("%d uses", item.maxUses)
	end
	return "Unlimited uses"
end

-- the charges left after one use (nil for a lifetime item: nothing is spent)
function ConsumableConfig.Spend(item, uses)
	if item.kind ~= "limited" then
		return nil
	end
	return uses - 1
end

-- whether a limited Tool is used up
function ConsumableConfig.Spent(item, uses)
	return item.kind == "limited" and uses <= 0
end

-- seconds of cooldown left (0 when ready); `readyAt` is when it ends, nil if never used
function ConsumableConfig.CooldownLeft(readyAt, now)
	if not readyAt or readyAt <= now then
		return 0
	end
	return readyAt - now
end

-- whether a player carrying `carried` stacks of a limited item may buy another
function ConsumableConfig.CanCarryMore(carried)
	return carried < ConsumableConfig.CarryLimit
end

-- Overclock: outgoing damage multiplier at `now`, given when the boost ends
function ConsumableConfig.OutgoingMultiplier(boostEndsAt, now)
	local item = byKey.OverclockChip
	if boostEndsAt and now < boostEndsAt then
		return 1 + item.damageBoost
	end
	return 1
end

-- Overclock: incoming damage multiplier at `now`; the crash runs from when the
-- boost ends until `crashEndsAt`
function ConsumableConfig.IncomingMultiplier(boostEndsAt, crashEndsAt, now)
	local item = byKey.OverclockChip
	if boostEndsAt and crashEndsAt and now >= boostEndsAt and now < crashEndsAt then
		return 1 + item.crashVulnerability
	end
	return 1
end

-- Stored stacks: the saved text is "NanoSyringe:5,RiftSuture:-", a limited item's key
-- and the uses it has left, a lifetime item's key and "-". It becomes a list of
-- { key =, uses = } (a lifetime entry has no uses). Anything wrong in it is
-- dropped: an unknown item, uses out of range, a second copy of a lifetime
-- item, entries past StorageLimit.
function ConsumableConfig.ParseStorage(text)
	local list = {}
	if type(text) ~= "string" or #text > ConsumableConfig.MaxSaveLength then
		return list
	end
	local lifetimeSeen = {}
	for key, uses in string.gmatch(text, "(%w+):([%d%-]+)") do
		local item = byKey[key]
		if item and #list < ConsumableConfig.StorageLimit then
			if item.kind == "lifetime" then
				if uses == "-" and not lifetimeSeen[key] then
					lifetimeSeen[key] = true
					table.insert(list, { key = key })
				end
			else
				local count = tonumber(uses)
				if count and count == math.floor(count) and count >= 1 and count <= item.maxUses then
					table.insert(list, { key = key, uses = count })
				end
			end
		end
	end
	return list
end

function ConsumableConfig.SerializeStorage(list)
	local parts = {}
	for _, entry in ipairs(list) do
		table.insert(parts, entry.key .. ":" .. (entry.uses and tostring(entry.uses) or "-"))
	end
	return table.concat(parts, ",")
end

-- how many stored stacks are of this item
function ConsumableConfig.StoredCount(list, key)
	local count = 0
	for _, entry in ipairs(list) do
		if entry.key == key then
			count += 1
		end
	end
	return count
end

-- whether another Tool fits on the hotbar, given how many consumable Tools are equipped
function ConsumableConfig.CanEquip(equipped)
	return equipped < ConsumableConfig.HotbarSlots
end

-- whether another stack fits in storage, given how many are stored
function ConsumableConfig.CanStore(stored)
	return stored < ConsumableConfig.StorageLimit
end

-- the HP a heal item restores, capped to what's missing
function ConsumableConfig.HealAmount(fraction, maxHealth, health)
	return math.max(0, math.min(maxHealth * fraction, maxHealth - health))
end

return ConsumableConfig
