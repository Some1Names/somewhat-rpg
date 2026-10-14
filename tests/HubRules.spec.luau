-- Unit tests for ReplicatedStorage.HubRules (the hub menu's ink colour, key
-- routing and nav order). Run with Lune, outside Roblox: tests/run.sh.
local HubRules = require("../src/ReplicatedStorage/HubRules")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local function isInk(r, g, b)
	return r == 0.08 and g == 0.08 and b == 0.08
end

check("white turns to ink", isInk(HubRules.Ink(1, 1, 1)))
check("pale grey turns to ink", isInk(HubRules.Ink(0.9, 0.9, 0.88)))
do
	local r, g, b = HubRules.Ink(0.667, 1, 0.784) -- Mandela's mint
	check("light mint stays as it is", r == 0.667 and g == 1 and b == 0.784)
end
do
	local r, g, b = HubRules.Ink(0.36, 0.88, 0.54)
	check("mid green stays", r == 0.36 and g == 0.88 and b == 0.54)
end
do
	local r, g, b = HubRules.Ink(1, 0.6, 0.235)
	check("Iridescent orange stays", r == 1 and g == 0.6 and b == 0.235)
end

check("closed hub: key opens", HubRules.KeyAction(nil, "Stats") == "open")
check("same tab: key closes", HubRules.KeyAction("Stats", "Stats") == "close")
check("other tab: key switches", HubRules.KeyAction("Quests", "Stats") == "switch")

do
	local order = HubRules.Order({
		{ name = "Stats", order = 4 },
		{ name = "Profile", order = 1 },
		{ name = "Slot7", order = 7, locked = true },
		{ name = "Backpack", order = 2 },
	})
	check("nav order", table.concat(order, ",") == "Profile,Backpack,Stats,Slot7")
	local ties = HubRules.Order({ { name = "B", order = 1 }, { name = "A", order = 1 } })
	check("ties by name", table.concat(ties, ",") == "A,B")
end

check("first open skips locked", HubRules.FirstOpen({ { name = "A", order = 1, locked = true }, { name = "B", order = 2 } }) == "B")
check("first open of none", HubRules.FirstOpen({}) == nil)

if failures > 0 then
	error(failures .. " failed")
end
