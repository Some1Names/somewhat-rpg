-- Unit tests for ReplicatedStorage.ChestConfig (how many chests, which spot,
-- how much yen). Run with Lune, outside Roblox: tests/run.sh.
local ChestConfig = require("../src/ReplicatedStorage/ChestConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local first = function()
	return 1
end
local last = function(n)
	return n
end

check("target is the Active count", ChestConfig.target(10) == ChestConfig.Active)
check("target never exceeds the spots", ChestConfig.target(2) == 2)
check("target with no spots is 0", ChestConfig.target(0) == 0)

check("picks the roll-th free spot", ChestConfig.pickSpot(5, { [1] = true, [3] = true }, nil, first) == 2)
check("skips taken spots", ChestConfig.pickSpot(5, { [1] = true, [3] = true }, nil, last) == 5)
check("avoids the collected spot while another is free", ChestConfig.pickSpot(3, {}, 1, first) == 2)
check("uses the avoided spot when it's the only one free", ChestConfig.pickSpot(3, { [2] = true, [3] = true }, 1, first) == 1)
check("nil when every spot is taken", ChestConfig.pickSpot(2, { [1] = true, [2] = true }, nil, first) == nil)

local range
local function roll(a, b)
	range = { a, b }
	return a
end
check("yen rolls between YenMin and YenMax", ChestConfig.yen(roll) == ChestConfig.YenMin and range[2] == ChestConfig.YenMax)
check("the yen range is sane", ChestConfig.YenMin > 0 and ChestConfig.YenMin <= ChestConfig.YenMax)

if failures > 0 then
	error(failures .. " failed")
end
