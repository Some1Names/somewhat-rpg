-- Fast travel: the numbers and the pure rules, kept free of Roblox types so Lune can test them
-- (tests/FastTravelConfig.spec.luau). FastTravelServer decides every trip with them, and the
-- client's map (FastTravelMenu) draws what the server sends. Every model tagged `Tag` is a travel
-- point; today that's the Spawn Keepers, and the reply that opens the map is in their talk
-- (SpawnKeeperDialogue). To move the feature to another NPC, change `Tag` and open FastTravelMenu
-- from that NPC's script instead.
-- Unlocking: IsUnlocked is the one rule for "may this player go there". It says yes to every
-- point while RequireUnlock is off; switched on, a player may only go to the points in their
-- `UnlockAttribute` text (point ids joined by commas), which something will have to fill in
-- (finding a keeper, say) and PlayerStats save.
local FastTravelConfig = {
	Tag = "SpawnSetter", -- the models that are travel points
	Range = 14, -- studs from a point's keeper a player must be within to travel (SpawnServer's reach)
	Cooldown = 10, -- seconds after a trip before the next
	StreamTimeout = 6, -- seconds the server waits for the destination's area to stream in
	LandAhead = 5, -- the traveller lands this far in front of the keeper (as SpawnServer's saved spawn)
	Lift = 3, -- and this far up, so they drop onto the ground, not into it
	RequireUnlock = false,
	UnlockAttribute = "TravelUnlocked",
	DefaultName = "Spawn Keeper", -- a point with no PlaceName attribute outside every named area
}

-- a point's id: its TravelId attribute when it has one, else its spot on the map (x and z rounded
-- to the stud), which stays the same from server to server while the keeper isn't moved
function FastTravelConfig.PointId(travelId, x, z)
	if type(travelId) == "string" and travelId ~= "" then
		return travelId
	end
	return string.format("%d:%d", math.floor(x + 0.5), math.floor(z + 0.5))
end

-- a point's name on the map: its PlaceName attribute, else the named area it stands in (ZoneConfig),
-- else DefaultName
function FastTravelConfig.PlaceName(placeName, zoneName)
	if type(placeName) == "string" and placeName ~= "" then
		return placeName
	end
	return zoneName or FastTravelConfig.DefaultName
end

-- whether the player may travel to point `id`, given their unlocked text (nil: none yet)
function FastTravelConfig.IsUnlocked(id, unlocked)
	if not FastTravelConfig.RequireUnlock then
		return true
	end
	return type(unlocked) == "string" and table.find(string.split(unlocked, ","), id) ~= nil
end

-- seconds left before the player can travel again after a trip at `lastTrip` (nil: never), or nil
function FastTravelConfig.CooldownLeft(lastTrip, now)
	if type(lastTrip) ~= "number" then
		return nil
	end
	local left = lastTrip + FastTravelConfig.Cooldown - now
	return left > 0 and left or nil
end

-- why a trip can't go, as a line for the player, or nil when it can. `trip` is what the server found:
-- from (the id of the point the player stands at, nil when they aren't at one), to (the destination's
-- id, nil when it isn't a point), unlocked (whether they may go there), combatLeft and cooldownLeft
-- (seconds, nil when they're clear)
function FastTravelConfig.Refusal(trip)
	if not trip.from then
		return "Talk to a keeper to travel"
	elseif not trip.to then
		return "That place is gone"
	elseif trip.to == trip.from then
		return "You're already here"
	elseif not trip.unlocked then
		return "You haven't found that place yet"
	elseif trip.combatLeft then
		return string.format("You can't travel while in combat (%ds)", math.ceil(trip.combatLeft))
	elseif trip.cooldownLeft then
		return string.format("You can travel again in %ds", math.ceil(trip.cooldownLeft))
	end
	return nil
end

return FastTravelConfig
