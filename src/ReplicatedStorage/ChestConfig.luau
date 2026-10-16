-- Yen chests (ServerScriptService.Chests): the numbers and the pure rules, kept
-- free of Roblox types so Lune can test them (tests/ChestConfig.spec.luau).
-- Each part named `TestChest` in Workspace is a chest spot (the part is the chest's
-- look; the script takes them out of the map when the game starts and clones
-- them back in). Only `Active` chests are out at once, on random spots; walking
-- onto one gives yen, and after `RespawnDelay` another appears on a free spot.
local ChestConfig = {
	SpotName = "TestChest", -- the parts in Workspace that mark where a chest can be
	Active = 4, -- chests out at once (never more than there are spots)
	RespawnDelay = 45, -- seconds after a pickup before another chest appears
	YenMin = 50,
	YenMax = 150,
}

-- how many chests should be out with `spots` places to put them
function ChestConfig.target(spots)
	return math.min(ChestConfig.Active, spots)
end

-- a free spot for the next chest: `taken[i]` is true for spots holding a chest,
-- `avoid` is a spot to skip while another is free (the one just collected, so
-- the chest doesn't reappear in the same place); `roll(n)` gives 1..n. nil if
-- every spot is taken.
function ChestConfig.pickSpot(spots, taken, avoid, roll)
	local free, others = {}, {}
	for i = 1, spots do
		if not taken[i] then
			table.insert(free, i)
			if i ~= avoid then
				table.insert(others, i)
			end
		end
	end
	local pool = #others > 0 and others or free
	if #pool == 0 then
		return nil
	end
	return pool[roll(#pool)]
end

-- the yen in one chest; `roll(a, b)` gives an integer in a..b
function ChestConfig.yen(roll)
	return roll(ChestConfig.YenMin, ChestConfig.YenMax)
end

return ChestConfig
