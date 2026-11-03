-- Unit tests for ReplicatedStorage.GearConfig (rolls, saved texts, totals, equip,
-- unequip, salvage). Run with Lune, outside Roblox: tests/run.sh.
local G = require("../src/ReplicatedStorage/GearConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- rarities and bases are well formed
local rarityOk, seenRarity = true, {}
for _, rarity in ipairs(G.Rarities) do
	if seenRarity[rarity.key] or not rarity.color or not rarity.affixes or not rarity.salvage or #rarity.salvage == 0 then
		rarityOk = false
	end
	seenRarity[rarity.key] = true
end
check("rarities are well formed", rarityOk and #G.Rarities == 5)
local baseOk, seenBase = true, {}
for _, base in ipairs(G.Bases) do
	if seenBase[base.id] or not table.find(G.Slots, base.slot) or not base.name or not base.model then
		baseOk = false
	end
	seenBase[base.id] = true
end
check("bases are well formed", baseOk and #G.Bases >= 2)

-- rolls
local a = G.Roll("Head", "Epic", 35, 7, nil, "g1")
local b = G.Roll("Head", "Epic", 35, 7, nil, "g1")
check("roll is deterministic per seed", G.EncodeBag({ a }) == G.EncodeBag({ b }))
local differs = false
for seed = 8, 17 do
	if G.EncodeBag({ G.Roll("Head", "Epic", 35, seed, nil, "g1") }) ~= G.EncodeBag({ a }) then
		differs = true
	end
end
check("roll changes with the seed", differs)
check("epic has its base stat plus three affixes", #a.affixes == 1 + 3)
check("head's base stat is max HP", a.affixes[1].id == "maxHealthPct")
check("body's base stat is damage reduction", G.Roll("Body", "Rare", 10, 3, nil, "g2").affixes[1].id == "damageReduction")
local unique = true
local seen = {}
for _, affix in ipairs(a.affixes) do
	if seen[affix.id] then
		unique = false
	end
	seen[affix.id] = true
end
check("no duplicate affix on a piece", unique)
local hinted = G.Roll("Body", "Epic", 40, 99, "regen", "g3")
local hasHint = false
for _, affix in ipairs(hinted.affixes) do
	hasHint = hasHint or affix.id == "regen"
end
check("the hint is always included", hasHint and #hinted.affixes == 1 + 3)
check("a common piece has only its base stat", #G.Roll("Head", "Common", 1, 5, nil, "g4").affixes == 1)
check("a hint gives a common piece one affix", #G.Roll("Head", "Common", 1, 5, "regen", "g4").affixes == 2)
check("an unknown hint is ignored", #G.Roll("Head", "Common", 1, 5, "nope", "g4").affixes == 1)
check("higher level picks a later base", G.Roll("Head", "Common", 60, 1, nil, "g5").base ~= G.Roll("Head", "Common", 1, 1, nil, "g5").base)

-- saved texts
local list = {}
for i = 1, 5 do
	table.insert(list, G.Roll(i % 2 == 0 and "Head" or "Body", "Rare", 10 + i, i, nil, "g" .. i))
end
local text = G.EncodeBag(list)
check("bag round trips", G.EncodeBag(G.ParseBag(text)) == text and #G.ParseBag(text) == 5)
check("junk bag parses to nothing", #G.ParseBag("junk|x;;g1|Nope|Epic|1|b|;") == 0 and #G.ParseBag(nil) == 0)
check("duplicate ids drop", #G.ParseBag(text .. ";" .. G.EncodeBag({ list[1] })) == 5)
check("bad rarity drops", #G.ParseBag("g1|Head|Mythic|1|b|") == 0)
local two = G.EncodeBag({ G.Roll("Head", "Rare", 5, 1, nil, "g1"), G.Roll("Head", "Rare", 5, 2, nil, "g2") })
local worn = G.ParseWorn(two)
check("worn keeps the first piece per slot", worn.Head and worn.Head.id == "g1" and worn.Body == nil)
check("worn round trips", G.EncodeWorn(worn) == G.EncodeBag({ worn.Head }))

-- totals
local plain = G.EncodeWorn({ Head = { id = "g1", slot = "Head", rarity = "Rare", level = 5, base = "x", affixes = { { id = "maxHealthPct", value = 0.1 }, { id = "stat:Vitality", value = 3 } } } })
check("total sums an effect", math.abs(G.Total(plain, "maxHealthPct") - 0.1) < 1e-9)
check("stat bonus sums stat points", G.StatBonus(plain, "Vitality") == 3 and G.StatBonus(plain, "Strength") == 0)
check("health multiplier", math.abs(G.HealthMultiplier(plain) - 1.1) < 1e-9)
local heavy = G.EncodeWorn({ Head = { id = "g1", slot = "Head", rarity = "Rare", level = 5, base = "x", affixes = { { id = "maxHealthPct", value = -5 }, { id = "damageReduction", value = 5 } } } })
check("health multiplier floors at 0.25", G.HealthMultiplier(heavy) == 0.25)
check("incoming multiplier clamps", G.IncomingMultiplier(heavy) == 0.25 and G.IncomingMultiplier("") == 1)
check("outgoing and yen start at 1", G.OutgoingMultiplier("") == 1 and G.YenMultiplier("") == 1)

-- equip, unequip, salvage
local bag = {}
for i = 1, G.BagLimit do
	table.insert(bag, G.Roll("Head", "Common", 1, i, nil, "g" .. i))
end
local fullBag = G.EncodeBag(bag)
check("a full bag can't add", not G.CanAdd(fullBag) and select(1, G.Add(fullBag, G.Roll("Head", "Common", 1, 99, nil, "g99"))) == nil)
local newBag, newWorn = G.Equip(fullBag, "", "g1", 1)
check("equip moves the piece to worn", newBag and #G.ParseBag(newBag) == G.BagLimit - 1 and G.ParseWorn(newWorn).Head.id == "g1")
local swapBag, swapWorn = G.Equip(newBag, newWorn, "g2", 1)
check("equip swaps in place, bag size unchanged", swapBag and #G.ParseBag(swapBag) == G.BagLimit - 1 and G.ParseWorn(swapWorn).Head.id == "g2")
check("the old piece returns to the bag", string.find(swapBag, "g1|Head", 1, true) ~= nil)
local high = G.EncodeBag({ G.Roll("Head", "Rare", 20, 1, nil, "g1") })
local failBag, _, why = G.Equip(high, "", "g1", 5)
check("level too low refuses", failBag == nil and why == "Level too low")
check("unknown piece refuses", select(1, G.Equip(fullBag, "", "nope", 99)) == nil)
local ub, _, uwhy = G.Unequip(fullBag, newWorn, "Head")
check("unequip with a full bag refuses", ub == nil and uwhy == "Gear bag is full")
local ub2, uw2 = G.Unequip(newBag, newWorn, "Head")
check("unequip returns the piece to the bag", ub2 and #G.ParseBag(ub2) == G.BagLimit and G.ParseWorn(uw2).Head == nil)
check("unequip of an empty slot refuses", select(1, G.Unequip(fullBag, "", "Body")) == nil)
local sb, yield = G.Salvage(fullBag, "g3")
check("salvage removes the piece and yields materials", sb and #G.ParseBag(sb) == G.BagLimit - 1 and yield and #yield > 0)
check("salvage of an unknown id refuses", select(1, G.Salvage(fullBag, "nope")) == nil)
local fresh = G.NewId(fullBag, newWorn)
check("new ids don't collide", fresh ~= nil and not string.find(fullBag, "^" .. fresh .. "|") and not string.find(fullBag, ";" .. fresh .. "|"))

if failures > 0 then
	error(failures .. " failed")
end
