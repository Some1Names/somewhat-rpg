-- Talismans: small items worn in slots that change how a player plays (more
-- max HP, faster regen, less damage taken, more yen, a heal on each kill, a
-- glass-cannon trade). The numbers and the pure rules live here, free of
-- Roblox types so Lune can test them (tests/TalismanConfig.spec.luau); the
-- server module Talismans runs equipping and the kill heal, and Damage,
-- PlayerStats, Health and Chests read the totals.
-- A player owns each talisman once (the saved TalismanOwned text, keys comma
-- separated) and wears up to Slots(level) of them (the saved TalismanEquipped
-- text). They drop from yen chests (ChestChance); more sources can come later.
-- Fractions are of the stat they change: maxHealthPct 0.15 is +15% max HP.
local TalismanConfig = {}

TalismanConfig.OwnedAttribute = "TalismanOwned" -- on the player, saved (PlayerStats)
TalismanConfig.EquippedAttribute = "TalismanEquipped" -- on the player, saved (PlayerStats)
TalismanConfig.FoundAttribute = "TalismanFound" -- on the player: "<key>:<server time>" of the last one found, for the toast
TalismanConfig.MaxSaveLength = 120
TalismanConfig.SlotLevels = { 0, 15, 40 } -- the level that opens slot 1, 2, 3
TalismanConfig.ChestChance = 0.2 -- chance a yen chest also holds a talisman you don't own yet
TalismanConfig.OwnAll = true -- for now every player owns every talisman (like SkillSetConfig.OwnAllSets); the saved text is left alone

-- in the order the Backpack lists them
--   effects: maxHealthPct, regen (HP/s), damageReduction (share of damage taken
--   cut), yenPct, healOnKill (share of max HP), damageDealt
TalismanConfig.Items = {
	{ key = "Vigor", name = "Vigor Talisman", color = { 226, 75, 74 }, effects = { maxHealthPct = 0.15 }, description = "+15% max HP." },
	{ key = "Regrowth", name = "Regrowth Talisman", color = { 90, 200, 120 }, effects = { regen = 2 }, description = "+2 HP per second of regeneration." },
	{ key = "Bulwark", name = "Bulwark Talisman", color = { 120, 150, 230 }, effects = { damageReduction = 0.08 }, description = "Take 8% less damage." },
	{ key = "Magnate", name = "Magnate Talisman", color = { 240, 200, 70 }, effects = { yenPct = 0.3 }, description = "+30% yen from chests and kills." },
	{ key = "SecondWind", name = "Second Wind Talisman", color = { 60, 224, 230 }, effects = { healOnKill = 0.03 }, description = "Heal 3% max HP on every kill." },
	{
		key = "GlassCharm",
		name = "Glass Charm",
		color = { 255, 154, 60 },
		effects = { damageDealt = 0.2, maxHealthPct = -0.15 },
		description = "+20% damage dealt, but -15% max HP.",
	},
}

local byKey = {}
local orderOf = {}
for index, item in ipairs(TalismanConfig.Items) do
	byKey[item.key] = item
	orderOf[item.key] = index
end

function TalismanConfig.Get(key)
	return byKey[key]
end

function TalismanConfig.Order(key)
	return orderOf[key] or math.huge
end

-- the valid talismans in a saved text, once each, in the order written
function TalismanConfig.Parse(text)
	local list, seen = {}, {}
	if typeof(text) ~= "string" then
		return list
	end
	for key in string.gmatch(text, "[^,]+") do
		if byKey[key] and not seen[key] then
			seen[key] = true
			table.insert(list, key)
		end
	end
	return list
end

function TalismanConfig.Encode(list)
	return table.concat(list, ",")
end

-- how many slots a player of this level has
function TalismanConfig.Slots(level)
	local slots = 0
	for _, at in ipairs(TalismanConfig.SlotLevels) do
		if level >= at then
			slots += 1
		end
	end
	return slots
end

-- the level the next slot opens at, or nil when all are open
function TalismanConfig.NextSlotLevel(level)
	for _, at in ipairs(TalismanConfig.SlotLevels) do
		if level < at then
			return at
		end
	end
	return nil
end

-- the sum of one effect over the worn talismans (`equippedText` is the saved text)
function TalismanConfig.Total(equippedText, effect)
	local total = 0
	for _, key in ipairs(TalismanConfig.Parse(equippedText)) do
		total += byKey[key].effects[effect] or 0
	end
	return total
end

function TalismanConfig.HealthMultiplier(equippedText)
	return math.max(1 + TalismanConfig.Total(equippedText, "maxHealthPct"), 0.25)
end

function TalismanConfig.IncomingMultiplier(equippedText)
	return math.clamp(1 - TalismanConfig.Total(equippedText, "damageReduction"), 0.25, 1)
end

function TalismanConfig.OutgoingMultiplier(equippedText)
	return math.max(1 + TalismanConfig.Total(equippedText, "damageDealt"), 0)
end

function TalismanConfig.YenMultiplier(equippedText)
	return math.max(1 + TalismanConfig.Total(equippedText, "yenPct"), 0)
end

-- the talismans a player owns: all of them while OwnAll is on, else the saved text's
function TalismanConfig.Owned(ownedText)
	if TalismanConfig.OwnAll then
		local all = {}
		for _, item in ipairs(TalismanConfig.Items) do
			table.insert(all, item.key)
		end
		return all
	end
	return TalismanConfig.Parse(ownedText)
end

-- wears `key`: the new worn list, or nil and why not. Slots are the level's;
-- the worn text may hold more than that if a level was taken away (they stay on)
function TalismanConfig.Equip(ownedText, equippedText, key, level)
	if not byKey[key] then
		return nil, "No such talisman"
	end
	if not table.find(TalismanConfig.Owned(ownedText), key) then
		return nil, "You don't own that talisman"
	end
	local worn = TalismanConfig.Parse(equippedText)
	if table.find(worn, key) then
		return nil, "Already worn"
	end
	if #worn >= TalismanConfig.Slots(level) then
		return nil, "No free talisman slot"
	end
	table.insert(worn, key)
	return worn
end

-- takes `key` off: the new worn list, or nil if it wasn't worn
function TalismanConfig.Unequip(equippedText, key)
	local worn = TalismanConfig.Parse(equippedText)
	local at = table.find(worn, key)
	if not at then
		return nil, "Not worn"
	end
	table.remove(worn, at)
	return worn
end

-- the owned text with `key` added, or nil if it's already owned or not a talisman
function TalismanConfig.Grant(ownedText, key)
	if not byKey[key] then
		return nil
	end
	local owned = TalismanConfig.Parse(ownedText)
	if table.find(TalismanConfig.Owned(ownedText), key) then
		return nil
	end
	table.insert(owned, key)
	return TalismanConfig.Encode(owned)
end

-- a random talisman not yet owned (nil when they own them all); `roll(n)` gives 1..n
function TalismanConfig.RollNew(ownedText, roll)
	local owned = TalismanConfig.Owned(ownedText)
	local missing = {}
	for _, item in ipairs(TalismanConfig.Items) do
		if not table.find(owned, item.key) then
			table.insert(missing, item.key)
		end
	end
	if #missing == 0 then
		return nil
	end
	return missing[roll(#missing)]
end

return TalismanConfig
