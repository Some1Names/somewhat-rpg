-- Unit tests for ReplicatedStorage.DropConfig's pure rules (what a helper
-- rolls, who counts as a helper, the bag cap, pickup rights and range).
-- Run with Lune, outside Roblox: tests/run.sh.
local DropConfig = require("../src/ReplicatedStorage/DropConfig")
local ReforgeConfig = require("../src/ReplicatedStorage/ReforgeConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- a random() that hands back the given values in order
local function sequence(values)
	local index = 0
	return function()
		index += 1
		return values[index] or 0
	end
end

local function same(rolls, expected)
	if #rolls ~= #expected then
		return false
	end
	for i, roll in ipairs(rolls) do
		if roll.material ~= expected[i][1] or roll.amount ~= expected[i][2] then
			return false
		end
	end
	return true
end

-- rolls: the chance draw comes first, then (only if it passed) the amount draw
check("level 1 can only reach Scrap", same(DropConfig.Rolls(1, nil, sequence({ 0.3, 0 })), { { "Scrap", 1 } }))
check("amount draw 0.999 gives the max", same(DropConfig.Rolls(1, nil, sequence({ 0.3, 0.999 })), { { "Scrap", 3 } }))
check("amount draw 0.34 gives 2 of 1-3", same(DropConfig.Rolls(1, nil, sequence({ 0.3, 0.34 })), { { "Scrap", 2 } }))
check("a chance draw equal to the chance fails", same(DropConfig.Rolls(1, nil, sequence({ 0.4 })), {}))
check("a chance draw just under passes", same(DropConfig.Rolls(1, nil, sequence({ 0.39, 0 })), { { "Scrap", 1 } }))
check("a failed chance spends no amount draw", same(DropConfig.Rolls(10, nil, sequence({ 0.9, 0.1, 0 })), { { "Core", 1 } }))
check("level 9 reaches only Scrap", #DropConfig.Rolls(9, nil, function() return 0 end) == 1)
check(
	"level 10 reaches Scrap and Core",
	same(DropConfig.Rolls(10, nil, function() return 0 end), { { "Scrap", 1 }, { "Core", 1 } })
)
check(
	"level 50 reaches all four in tier order",
	same(
		DropConfig.Rolls(50, nil, function() return 0 end),
		{ { "Scrap", 1 }, { "Core", 1 }, { "Crystal", 1 }, { "Essence", 1 } }
	)
)
check("no level counts as level 1", same(DropConfig.Rolls(nil, nil, sequence({ 0, 0 })), { { "Scrap", 1 } }))
check("level 0 counts as level 1", same(DropConfig.Rolls(0, nil, sequence({ 0, 0 })), { { "Scrap", 1 } }))
check(
	"a drop table adds its materials after the generic ones",
	same(DropConfig.Rolls(1, "Wolf", function() return 0 end), { { "Scrap", 1 }, { "WolfFang", 1 } })
)
check("an unknown table rolls only the generic ones", same(DropConfig.Rolls(1, "NoSuchTable", sequence({ 0, 0 })), { { "Scrap", 1 } }))

-- orb variants: a plain tier has one part, Dark picks red or purple by weight (3:1)
check("a plain tier uses its orb part", DropConfig.Variant("Rare", 0.9).part == "RareOrb")
check("Dark rolls red below 0.75", DropConfig.Variant("Dark", 0.74).part == "DarkOrbRed")
check("Dark rolls purple from 0.75", DropConfig.Variant("Dark", 0.75).part == "DarkOrbPurple")
check("roll 0 is red, a roll just under 1 is purple", DropConfig.Variant("Dark", 0).part == "DarkOrbRed" and DropConfig.Variant("Dark", 0.9999).part == "DarkOrbPurple")
check("a variant carries a label colour", #DropConfig.Variant("Dark", 0).rgb == 3)

-- helpers: at least a tenth of the enemy's max health
check("10 of 100 is a helper", DropConfig.IsHelper(10, 100))
check("9.99 of 100 is not", not DropConfig.IsHelper(9.99, 100))
check("zero max health is nobody", not DropConfig.IsHelper(5, 0))
check("no damage is not a helper", not DropConfig.IsHelper(0, 100))

-- the bag cap
local function fits(current, amount, expectedTaken, expectedLeft)
	local taken, left = DropConfig.Fit(current, amount)
	return taken == expectedTaken and left == expectedLeft
end
check("an empty bag takes it all", fits(0, 5, 5, 0))
check("a nearly full bag takes what fits", fits(997, 5, 2, 3))
check("a full bag takes nothing", fits(999, 5, 0, 5))
check("an over-cap bag takes nothing", fits(1500, 5, 0, 5))

-- who may take an orb, and from how far
check("the owner takes it in the private window", DropConfig.CanPickUp(1, 1, 0, 100))
check("others can't in the private window", not DropConfig.CanPickUp(1, 2, 99.9, 100))
check("anyone can once it is public", DropConfig.CanPickUp(1, 2, 100, 100))
check("6 studs flat is in range", DropConfig.InRange(6, 8))
check("over 6 studs flat is out", not DropConfig.InRange(6.1, 0))
check("over 8 studs up is out", not DropConfig.InRange(0, 8.1))
check("8 studs below is in range", DropConfig.InRange(0, -8))

-- the data hangs together
local consistent = true
for key, material in pairs(DropConfig.Materials) do
	if not DropConfig.Tiers[material.tier] then
		consistent = false
		print("      " .. key .. " has an unknown tier")
	end
end
for _, entry in ipairs(DropConfig.Generic) do
	if not DropConfig.Materials[entry.material] then
		consistent = false
		print("      generic entry for unknown " .. entry.material)
	end
end
for name, entries in pairs(DropConfig.Tables) do
	for _, entry in ipairs(entries) do
		if not DropConfig.Materials[entry.material] then
			consistent = false
			print("      table " .. name .. " has unknown " .. entry.material)
		end
	end
end
check("every tier, generic entry and table entry names something that exists", consistent)

local payable = true
for _, costs in ipairs({ ReforgeConfig.LevelCosts, ReforgeConfig.RerollCosts }) do
	for _, cost in ipairs(costs) do
		if not DropConfig.Materials[cost.material] then
			payable = false
			print("      Reforge asks for " .. cost.material)
		end
	end
end
check("every material Reforge asks for can drop", payable)
check("the attribute name matches Reforge's", DropConfig.Attribute("Scrap") == ReforgeConfig.MaterialAttribute("Scrap"))

local sorted = DropConfig.Sorted()
check(
	"sorted by tier, then display name",
	#sorted == 5 and table.concat(sorted, ",") == "Scrap,Core,WolfFang,Crystal,Essence"
)

if failures > 0 then
	error(failures .. " failed")
end
