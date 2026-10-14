-- Unit tests for ReplicatedStorage.PowerConfig (prices, selling, the gacha
-- roll and pity, the saved lists). Run with Lune, outside Roblox: tests/run.sh.
local PowerConfig = require("../src/ReplicatedStorage/PowerConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- a small deterministic generator (Park-Miller), so the odds test never flakes
local function seeded(seed)
	local state = seed
	return function()
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function always(value)
	return function()
		return value
	end
end

check("S dealer price is 500,000", PowerConfig.price("Mandela", "S") == 500000)
check("A dealer price is 150,000", PowerConfig.price("X", "A") == 150000)
check("B dealer price is 50,000", PowerConfig.price("X", "B") == 50000)
check("C dealer price is 15,000", PowerConfig.price("X", "C") == 15000)
check("Aido is not for sale", PowerConfig.price("Aido", "S") == nil)
check("an unknown tier has no price", PowerConfig.price("X", "Z") == nil)

check("S sells for 150,000", PowerConfig.sellPrice("Mandela", "S") == 150000)
check("C sells for 4,500", PowerConfig.sellPrice("X", "C") == 4500)
check("Aido sells for 200,000", PowerConfig.sellPrice("Aido", "S") == 200000)

local all = { S = { "a", "b" }, A = { "c" }, B = { "d" }, C = { "e" } }
local rng = seeded(7)
local counts = { S = 0, A = 0, B = 0, C = 0 }
local ROLLS = 20000
for _ = 1, ROLLS do
	local tier = PowerConfig.roll(rng, 0, all)
	counts[tier] += 1
end
check("S is about 5% of rolls", math.abs(counts.S / ROLLS - 0.05) < 0.01)
check("A is about 15% of rolls", math.abs(counts.A / ROLLS - 0.15) < 0.015)
check("B is about 30% of rolls", math.abs(counts.B / ROLLS - 0.30) < 0.02)
check("C is about 50% of rolls", math.abs(counts.C / ROLLS - 0.50) < 0.02)

-- tiers with no powers are skipped and the rest re-weighted
rng = seeded(11)
local onlyS = { S = { "a" }, A = {}, C = {} }
local allS = true
for _ = 1, 200 do
	if PowerConfig.roll(rng, 0, onlyS) ~= "S" then
		allS = false
	end
end
check("with only S powers every roll is S", allS)
check("nothing available rolls nothing", PowerConfig.roll(rng, 0, {}) == nil)
check("pity can't force a tier with no powers", PowerConfig.roll(always(0), 99, { A = { "c" }, B = { "d" } }) == "A")

-- pity
check("29 rolls without S doesn't force S", PowerConfig.roll(always(0.99), 29, all) ~= "S")
check("30 rolls without S forces S", PowerConfig.roll(always(0.99), 30, all) == "S")
check("pity counts a non-S roll", PowerConfig.nextPity(4, "B") == 5)
check("pity resets on S", PowerConfig.nextPity(29, "S") == 0)

-- pick
check("pick takes the first at 0", PowerConfig.pick(always(0), { "a", "b", "c" }) == "a")
check("pick takes the last just under 1", PowerConfig.pick(always(0.999999), { "a", "b", "c" }) == "c")
check("pick of an empty list is nil", PowerConfig.pick(always(0.5), {}) == nil)

-- saved lists
check("encode joins with commas", PowerConfig.encodeList({ "a", "b" }) == "a,b")
check("encode of an empty list is empty text", PowerConfig.encodeList({}) == "")
local decoded = PowerConfig.decodeList("a,,b,a")
check("decode drops blanks and repeats", #decoded == 2 and decoded[1] == "a" and decoded[2] == "b")
check("decode of empty text is empty", #PowerConfig.decodeList("") == 0)
check("decode of a non-string is empty", #PowerConfig.decodeList(nil) == 0)
local filtered = PowerConfig.decodeList("a,Nope,b", function(name)
	return name ~= "Nope"
end)
check("decode drops names accept refuses", #filtered == 2 and filtered[2] == "b")

if failures > 0 then
	error(failures .. " failed")
end
