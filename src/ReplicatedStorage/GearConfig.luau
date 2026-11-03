-- Gear: rolled defense and stat pieces worn in a Head and a Body slot. The numbers
-- and the pure rules live here, free of Roblox types so Lune can test them
-- (tests/GearConfig.spec.luau); the server module Gear runs the actions and
-- Damage, PlayerStats, Health and Chests read the totals, beside the talismans'.
-- A piece is rolled once (a rarity, a base, a base stat and affixes) and saved with
-- its rolled values, so rebalancing never changes a piece a player owns. The bag is
-- the saved GearBag text, the worn pieces the saved GearWorn text. Pieces are
-- "id|slot|rarity|level|base|affix=value,affix=value" joined by ";".
-- Fractions are of the stat they change: maxHealthPct 0.15 is +15% max HP; a
-- "stat:<Name>" affix is whole stat points that count toward damage and HP only.
local GearConfig = {}

GearConfig.BagAttribute = "GearBag" -- on the player, saved (PlayerStats)
GearConfig.WornAttribute = "GearWorn" -- on the player, saved (PlayerStats)
GearConfig.Remote = "GearAction" -- RemoteFunction in ReplicatedStorage, made by GearServer
GearConfig.BagLimit = 30
GearConfig.MaxSaveLength = 2400 -- 30 bag pieces and 2 worn, about 70 characters each
GearConfig.Slots = { "Head", "Body" }
GearConfig.ModelsFolder = "GearModels" -- under ReplicatedStorage: an Accessory per base id (the owner's, optional)

-- in order, worst to best
--   affixes: random affixes besides the base stat; valueScale: multiplies every value;
--   salvage: the materials (DropConfig keys) salvaging one gives back
GearConfig.Rarities = {
	{ key = "Common", name = "Common", color = { 170, 170, 175 }, affixes = 0, valueScale = 1.0, salvage = { { material = "Scrap", amount = 2 } } },
	{ key = "Uncommon", name = "Uncommon", color = { 90, 200, 120 }, affixes = 1, valueScale = 1.2, salvage = { { material = "Scrap", amount = 4 } } },
	{ key = "Rare", name = "Rare", color = { 70, 140, 255 }, affixes = 2, valueScale = 1.5, salvage = { { material = "Core", amount = 2 } } },
	{ key = "Epic", name = "Epic", color = { 170, 110, 230 }, affixes = 3, valueScale = 1.9, salvage = { { material = "Crystal", amount = 2 } } },
	{ key = "Legendary", name = "Legendary", color = { 255, 205, 60 }, affixes = 3, valueScale = 2.4, salvage = { { material = "Essence", amount = 1 } } },
}

-- the base a piece is rolled on: the best one whose minLevel the piece's level reaches
-- (placeholder names to rename; `model` is the Accessory under ModelsFolder)
GearConfig.Bases = {
	{ id = "RoughHelm", name = "Rough Helm", slot = "Head", minLevel = 1, model = "RoughHelm" },
	{ id = "ReinforcedHelm", name = "Reinforced Helm", slot = "Head", minLevel = 20, model = "ReinforcedHelm" },
	{ id = "PrismHelm", name = "Prism Helm", slot = "Head", minLevel = 60, model = "PrismHelm" },
	{ id = "RoughPlate", name = "Rough Plate", slot = "Body", minLevel = 1, model = "RoughPlate" },
	{ id = "ReinforcedPlate", name = "Reinforced Plate", slot = "Body", minLevel = 20, model = "ReinforcedPlate" },
	{ id = "PrismPlate", name = "Prism Plate", slot = "Body", minLevel = 60, model = "PrismPlate" },
}

-- the base stat a slot always has: `base + perLevel * level`, times the rarity's valueScale
GearConfig.BaseStats = {
	Head = { id = "maxHealthPct", base = 0.02, perLevel = 0.0015 },
	Body = { id = "damageReduction", base = 0.01, perLevel = 0.0006 },
}

-- the random affixes, before the rarity's valueScale. An id is a talisman effect name
-- (maxHealthPct, regen, damageReduction, yenPct, healOnKill, damageDealt) or "stat:<Name>"
GearConfig.Affixes = {
	{ id = "maxHealthPct", min = 0.02, max = 0.06 },
	{ id = "regen", min = 0.5, max = 2 },
	{ id = "damageReduction", min = 0.01, max = 0.04 },
	{ id = "damageDealt", min = 0.02, max = 0.06 },
	{ id = "yenPct", min = 0.05, max = 0.15 },
	{ id = "healOnKill", min = 0.005, max = 0.015 },
	{ id = "stat:Vitality", min = 1, max = 3, whole = true },
	{ id = "stat:Strength", min = 1, max = 3, whole = true },
	{ id = "stat:Superliminal", min = 1, max = 3, whole = true },
	{ id = "stat:Firearm", min = 1, max = 3, whole = true },
	{ id = "stat:Agility", min = 1, max = 3, whole = true },
	{ id = "stat:Willpower", min = 1, max = 3, whole = true },
}

local rarityByKey = {}
local rarityOrder = {}
for index, rarity in ipairs(GearConfig.Rarities) do
	rarityByKey[rarity.key] = rarity
	rarityOrder[rarity.key] = index
end
local baseById = {}
for _, base in ipairs(GearConfig.Bases) do
	baseById[base.id] = base
end
local affixById = {}
for _, affix in ipairs(GearConfig.Affixes) do
	affixById[affix.id] = affix
end

function GearConfig.Rarity(key)
	return rarityByKey[key]
end

function GearConfig.RarityOrder(key)
	return rarityOrder[key] or 0
end

function GearConfig.Base(id)
	return baseById[id]
end

-- a small seeded generator (no Roblox Random, so Lune can run it): values in (0, 1)
local MODULUS = 2147483647
local function generator(seed)
	local state = math.floor(math.abs(seed)) % (MODULUS - 1) + 1
	local function nextValue()
		state = (state * 48271) % MODULUS
		return state / MODULUS
	end
	for _ = 1, 3 do
		nextValue() -- small seeds start out close together
	end
	return nextValue
end

local function round4(value)
	return math.floor(value * 10000 + 0.5) / 10000
end

-- the piece with `id` rolled from `seed`; `affixHint` (an affix id) is always on it, even on a Common
function GearConfig.Roll(slot, rarityKey, level, seed, affixHint, id)
	local rarity = rarityByKey[rarityKey]
	local random = generator(seed)
	level = math.max(math.floor(level), 1)

	local eligible, best = {}, 0
	for _, base in ipairs(GearConfig.Bases) do
		if base.slot == slot and base.minLevel <= level then
			best = math.max(best, base.minLevel)
		end
	end
	for _, base in ipairs(GearConfig.Bases) do
		if base.slot == slot and base.minLevel == best then
			table.insert(eligible, base)
		end
	end
	local base = eligible[math.floor(random() * #eligible) + 1]

	local stat = GearConfig.BaseStats[slot]
	local affixes = { { id = stat.id, value = round4((stat.base + stat.perLevel * level) * rarity.valueScale) } }

	local count = rarity.affixes
	local hint = affixHint and affixById[affixHint] and affixHint ~= stat.id and affixHint or nil
	if hint then
		count = math.max(count, 1)
	end
	local pool = {}
	for _, affix in ipairs(GearConfig.Affixes) do
		if affix.id ~= stat.id and affix.id ~= hint then
			table.insert(pool, affix)
		end
	end
	local function addAffix(affix)
		local value = (affix.min + (affix.max - affix.min) * random()) * rarity.valueScale
		value = affix.whole and math.max(math.floor(value + 0.5), 1) or round4(value)
		table.insert(affixes, { id = affix.id, value = value })
	end
	if hint then
		addAffix(affixById[hint])
		count -= 1
	end
	for _ = 1, count do
		local pick = math.floor(random() * #pool) + 1
		addAffix(table.remove(pool, pick))
	end

	return { id = id, slot = slot, rarity = rarityKey, level = level, base = base.id, affixes = affixes }
end

-- saved text ------------------------------------------------------------

local function encodePiece(piece)
	local affixes = {}
	for _, affix in ipairs(piece.affixes) do
		table.insert(affixes, string.format("%s=%.4f", affix.id, affix.value))
	end
	return string.format("%s|%s|%s|%d|%s|%s", piece.id, piece.slot, piece.rarity, piece.level, piece.base, table.concat(affixes, ","))
end

local function parsePiece(text)
	local fields = string.split(text, "|")
	if #fields ~= 6 then
		return nil
	end
	local id, slot, rarity, level, base, affixText = table.unpack(fields)
	level = tonumber(level)
	if not string.match(id, "^[%w_]+$") or not table.find(GearConfig.Slots, slot) or not rarityByKey[rarity] or not level or level < 1 or level ~= math.floor(level) then
		return nil
	end
	if not string.match(base, "^[%w_]+$") then
		return nil
	end
	local affixes = {}
	for part in string.gmatch(affixText, "[^,]+") do
		local affixId, value = string.match(part, "^([^=]+)=(.+)$")
		value = tonumber(value)
		if affixId and affixById[affixId] and value and value == value and math.abs(value) <= 100 then
			table.insert(affixes, { id = affixId, value = value })
		end
	end
	return { id = id, slot = slot, rarity = rarity, level = level, base = base, affixes = affixes }
end

local function parsePieces(text)
	local pieces, seen = {}, {}
	if typeof(text) ~= "string" then
		return pieces
	end
	for part in string.gmatch(text, "[^;]+") do
		local piece = parsePiece(part)
		if piece and not seen[piece.id] then
			seen[piece.id] = true
			table.insert(pieces, piece)
		end
	end
	return pieces
end

local function encodePieces(list)
	local parts = {}
	for _, piece in ipairs(list) do
		table.insert(parts, encodePiece(piece))
	end
	return table.concat(parts, ";")
end

-- the bag's pieces, at most BagLimit, in saved order
function GearConfig.ParseBag(text)
	local pieces = parsePieces(text)
	while #pieces > GearConfig.BagLimit do
		table.remove(pieces)
	end
	return pieces
end

function GearConfig.EncodeBag(list)
	return encodePieces(list)
end

-- the worn pieces by slot (the first piece written for a slot wins)
function GearConfig.ParseWorn(text)
	local worn = {}
	for _, piece in ipairs(parsePieces(text)) do
		if not worn[piece.slot] then
			worn[piece.slot] = piece
		end
	end
	return worn
end

function GearConfig.EncodeWorn(worn)
	local list = {}
	for _, slot in ipairs(GearConfig.Slots) do
		if worn[slot] then
			table.insert(list, worn[slot])
		end
	end
	return encodePieces(list)
end

-- totals ------------------------------------------------------------------

-- the sum of one affix over the worn pieces (`wornText` is the saved text)
function GearConfig.Total(wornText, effect)
	local total = 0
	for _, piece in pairs(GearConfig.ParseWorn(wornText)) do
		for _, affix in ipairs(piece.affixes) do
			if affix.id == effect then
				total += affix.value
			end
		end
	end
	return total
end

function GearConfig.StatBonus(wornText, statName)
	return GearConfig.Total(wornText, "stat:" .. statName)
end

function GearConfig.HealthMultiplier(wornText)
	return math.max(1 + GearConfig.Total(wornText, "maxHealthPct"), 0.25)
end

function GearConfig.IncomingMultiplier(wornText)
	return math.clamp(1 - GearConfig.Total(wornText, "damageReduction"), 0.25, 1)
end

function GearConfig.OutgoingMultiplier(wornText)
	return math.max(1 + GearConfig.Total(wornText, "damageDealt"), 0)
end

function GearConfig.YenMultiplier(wornText)
	return math.max(1 + GearConfig.Total(wornText, "yenPct"), 0)
end

-- actions -----------------------------------------------------------------

function GearConfig.CanAdd(bagText)
	return #GearConfig.ParseBag(bagText) < GearConfig.BagLimit
end

-- the bag text with `piece` added, or nil and why
function GearConfig.Add(bagText, piece)
	local bag = GearConfig.ParseBag(bagText)
	if #bag >= GearConfig.BagLimit then
		return nil, "Gear bag is full"
	end
	table.insert(bag, piece)
	return GearConfig.EncodeBag(bag)
end

-- an id no bag or worn piece uses
function GearConfig.NewId(bagText, wornText)
	local highest = 0
	local function scan(pieces)
		for _, piece in ipairs(pieces) do
			highest = math.max(highest, tonumber(string.match(piece.id, "%d+$")) or 0)
		end
	end
	scan(GearConfig.ParseBag(bagText))
	scan(parsePieces(wornText))
	return "g" .. (highest + 1)
end

local function indexOf(bag, id)
	for index, piece in ipairs(bag) do
		if piece.id == id then
			return index
		end
	end
	return nil
end

-- wears bag piece `id`: the new bag and worn texts, or nil and why. A piece already
-- worn in that slot swaps places with it, so equipping never needs a free bag slot
function GearConfig.Equip(bagText, wornText, id, playerLevel)
	local bag = GearConfig.ParseBag(bagText)
	local at = indexOf(bag, id)
	if not at then
		return nil, nil, "No such piece"
	end
	local piece = bag[at]
	if piece.level > playerLevel then
		return nil, nil, "Level too low"
	end
	local worn = GearConfig.ParseWorn(wornText)
	local old = worn[piece.slot]
	worn[piece.slot] = piece
	if old then
		bag[at] = old
	else
		table.remove(bag, at)
	end
	return GearConfig.EncodeBag(bag), GearConfig.EncodeWorn(worn)
end

-- takes the piece in `slot` off, into the bag: the new texts, or nil and why
function GearConfig.Unequip(bagText, wornText, slot)
	local worn = GearConfig.ParseWorn(wornText)
	local piece = worn[slot]
	if not piece then
		return nil, nil, "Nothing worn there"
	end
	local bag = GearConfig.ParseBag(bagText)
	if #bag >= GearConfig.BagLimit then
		return nil, nil, "Gear bag is full"
	end
	table.insert(bag, piece)
	worn[slot] = nil
	return GearConfig.EncodeBag(bag), GearConfig.EncodeWorn(worn)
end

-- removes bag piece `id`: the new bag text and the materials it gives, or nil and why
function GearConfig.Salvage(bagText, id)
	local bag = GearConfig.ParseBag(bagText)
	local at = indexOf(bag, id)
	if not at then
		return nil, nil, "No such piece"
	end
	local piece = table.remove(bag, at)
	local yield = {}
	for _, entry in ipairs(rarityByKey[piece.rarity].salvage) do
		table.insert(yield, { material = entry.material, amount = entry.amount })
	end
	return GearConfig.EncodeBag(bag), yield
end

return GearConfig
