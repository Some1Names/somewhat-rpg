-- Unit tests for ReplicatedStorage.FastTravelConfig (point ids and names, the unlock rule, the
-- cooldown and why a trip is refused). Run with Lune, outside Roblox: tests/run.sh.
local FastTravelConfig = require("../src/ReplicatedStorage/FastTravelConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- ids
check("a TravelId attribute is the id", FastTravelConfig.PointId("docks", 1, 2) == "docks")
check("an empty TravelId falls back to the spot", FastTravelConfig.PointId("", 756.88, -409.89) == "757:-410")
check("no TravelId: the spot, rounded to the stud", FastTravelConfig.PointId(nil, 34.5, 248.4) == "35:248")
check("the same spot always gives the same id", FastTravelConfig.PointId(nil, 1155.149, 2437.74) == FastTravelConfig.PointId(nil, 1155.2, 2437.6))
check("a spot id holds no comma (the unlocked text is comma-joined)", not string.find(FastTravelConfig.PointId(nil, -12, 40), ","))

-- names
check("a PlaceName attribute is the name", FastTravelConfig.PlaceName("Harbour", "East Docks") == "Harbour")
check("no PlaceName: the area it stands in", FastTravelConfig.PlaceName(nil, "East Docks") == "East Docks")
check("an empty PlaceName counts as none", FastTravelConfig.PlaceName("", "Upper Shrine") == "Upper Shrine")
check("outside every area: the default name", FastTravelConfig.PlaceName(nil, nil) == FastTravelConfig.DefaultName)

-- unlocking
check("today every point is unlocked", FastTravelConfig.IsUnlocked("757:-410", nil) and FastTravelConfig.IsUnlocked("docks", ""))
FastTravelConfig.RequireUnlock = true
check("with unlocks on, a listed point is unlocked", FastTravelConfig.IsUnlocked("35:248", "757:-410,35:248"))
check("with unlocks on, an unlisted point is locked", not FastTravelConfig.IsUnlocked("1155:2438", "757:-410,35:248"))
check("with unlocks on, nothing is unlocked before any is found", not FastTravelConfig.IsUnlocked("35:248", nil))
check("with unlocks on, part of an id doesn't count", not FastTravelConfig.IsUnlocked("35:24", "35:248"))
FastTravelConfig.RequireUnlock = false

-- cooldown
check("never travelled: no cooldown", FastTravelConfig.CooldownLeft(nil, 100) == nil)
check("just travelled: the whole cooldown is left", FastTravelConfig.CooldownLeft(100, 100) == FastTravelConfig.Cooldown)
check("partway: the rest is left", FastTravelConfig.CooldownLeft(100, 104) == FastTravelConfig.Cooldown - 4)
check("once it's over: none", FastTravelConfig.CooldownLeft(100, 100 + FastTravelConfig.Cooldown) == nil)

-- refusals
local function trip(changes)
	local fields = { from = "a", to = "b", unlocked = true }
	for key, value in pairs(changes) do
		fields[key] = value
	end
	return fields
end
check("a good trip is not refused", FastTravelConfig.Refusal(trip({})) == nil)
check("away from every keeper: refused", FastTravelConfig.Refusal(trip({ from = false })) ~= nil)
check("an unknown destination: refused", FastTravelConfig.Refusal(trip({ to = false })) ~= nil)
check("to where you stand: refused", FastTravelConfig.Refusal(trip({ to = "a" })) == "You're already here")
check("a locked destination: refused", FastTravelConfig.Refusal(trip({ unlocked = false })) ~= nil)
check("in combat: refused with the seconds left", FastTravelConfig.Refusal(trip({ combatLeft = 12.2 })) == "You can't travel while in combat (13s)")
check("on cooldown: refused with the seconds left", FastTravelConfig.Refusal(trip({ cooldownLeft = 3.5 })) == "You can travel again in 4s")
check("combat is named before the cooldown", string.find(FastTravelConfig.Refusal(trip({ combatLeft = 5, cooldownLeft = 5 })), "combat") ~= nil)

if failures > 0 then
	error(failures .. " FastTravelConfig test(s) failed")
end
