-- Named areas of the map, for the name that fades in as you walk into one (ZoneName).
-- A MOCKUP: rough boxes around what is there today, to be redrawn and renamed once the
-- map is finished. Each zone is a flat box, min/max = { x, z } in studs (height doesn't
-- matter). Where two overlap the one listed first wins, so small areas go before the
-- big ones around them; two boxes with the same name count as one area.
local ZoneConfig = {}

ZoneConfig.Zones = {
	{ name = "The Pit", min = { 100, -370 }, max = { 240, -230 } }, -- the Evil Boss
	{ name = "East Docks", min = { 280, -320 }, max = { 460, -140 } }, -- a Bounty Hunter and a Spawn Keeper
	{ name = "Market Square", min = { 0, -70 }, max = { 180, 60 } }, -- the spawn, shops, smith and gacha
	{ name = "Training Grounds", min = { -130, -70 }, max = { 0, 60 } },
	{ name = "Training Grounds", min = { -130, 60 }, max = { 90, 220 } }, -- the drop-test dummies
	{ name = "Upper Shrine", min = { -130, 220 }, max = { 130, 480 } }, -- a Spawn Keeper, the Strong Dummy
	{ name = "Solar Works", min = { 2750, 1300 }, max = { 3200, 1760 } }, -- the Henchmen and Workers
}

return ZoneConfig
