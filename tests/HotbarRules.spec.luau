-- Unit tests for ReplicatedStorage.HotbarRules (the item grid's layout and its
-- free slots). Run with Lune, outside Roblox: tests/run.sh.
local HotbarRules = require("../src/ReplicatedStorage/HotbarRules")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local function layoutOf(entries)
	local layout = HotbarRules.Layout(entries)
	local text = {}
	for slot = 1, HotbarRules.Slots do
		table.insert(text, layout[slot] or "-")
	end
	return table.concat(text, ",")
end

check("no tools, no slots taken", layoutOf({}) == "-,-,-,-,-,-")
check("unclaimed tools fill from the first slot", layoutOf({ { id = "a" }, { id = "b" } }) == "a,b,-,-,-,-")
check("a claimed slot is kept", layoutOf({ { id = "a", slot = 4 } }) == "-,-,-,a,-,-")
check("unclaimed tools go around a claimed slot", layoutOf({ { id = "a", slot = 1 }, { id = "b" }, { id = "c" } }) == "a,b,c,-,-,-")
check("a claim wins over a tool that came first", layoutOf({ { id = "a" }, { id = "b", slot = 1 } }) == "b,a,-,-,-,-")
check("the first of two claims on a slot keeps it", layoutOf({ { id = "a", slot = 2 }, { id = "b", slot = 2 } }) == "b,a,-,-,-,-")
check("a bad claim counts as unclaimed", layoutOf({ { id = "a", slot = 0 }, { id = "b", slot = 7 }, { id = "c", slot = 2.5 }, { id = "d", slot = "x" } }) == "a,b,c,d,-,-")
check("tools past the last slot are left out", layoutOf({ { id = "1" }, { id = "2" }, { id = "3" }, { id = "4" }, { id = "5" }, { id = "6" }, { id = "7" } }) == "1,2,3,4,5,6")

local free = HotbarRules.FreeSlots({ { id = "a", slot = 2 }, { id = "b" } })
check("free slots skip the taken ones", #free == 4 and free[1] == 3 and free[4] == 6)
check("free slots when full", #HotbarRules.FreeSlots({ { id = "1" }, { id = "2" }, { id = "3" }, { id = "4" }, { id = "5" }, { id = "6" } }) == 0)

check("power and weapon tools are not in the grid", not HotbarRules.InGrid("power") and not HotbarRules.InGrid("weapon"))
check("other tools are", HotbarRules.InGrid(nil) and HotbarRules.InGrid("melee"))

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all HotbarRules checks passed")
