-- Unit tests for ReplicatedStorage.HudRules (compass, XP bar, combo, low health, zones)
-- and the shape of ZoneConfig. Run with Lune, outside Roblox: tests/run.sh.
local HudRules = require("../src/ReplicatedStorage/HudRules")
local ZoneConfig = require("../src/ReplicatedStorage/ZoneConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local function near(a, b)
	return a ~= nil and b ~= nil and math.abs(a - b) < 1e-6
end

-- headings: north is -Z, east +X, clockwise
check("looking along -Z is north", near(HudRules.Heading(0, -1), 0))
check("looking along +X is east", near(HudRules.Heading(1, 0), 90))
check("looking along +Z is south", near(HudRules.Heading(0, 1), 180))
check("looking along -X is west", near(HudRules.Heading(-1, 0), 270))
check("north-east is 45", near(HudRules.Heading(1, -1), 45))

-- offsets wrap around north
check("a bearing ahead is 0 off", near(HudRules.Offset(90, 90), 0))
check("10 past north from 350 is 20 to the right", near(HudRules.Offset(350, 10), 20))
check("350 from 10 is 20 to the left", near(HudRules.Offset(10, 350), -20))
check("behind is -180", near(HudRules.Offset(0, 180), -180))

-- the strip
check("ahead is the strip's middle", near(HudRules.StripX(0, 180, 400), 200))
check("90 to the right is its right end", near(HudRules.StripX(90, 180, 400), 400))
check("45 to the left is a quarter in", near(HudRules.StripX(-45, 180, 400), 100))
check("past the span is off the strip", HudRules.StripX(91, 180, 400) == nil)
check("the middle doesn't fade", near(HudRules.EdgeFade(0, 180, 0.25), 0))
check("just inside the fade is solid", near(HudRules.EdgeFade(67.5, 180, 0.25), 0))
check("the end is fully faded", near(HudRules.EdgeFade(-90, 180, 0.25), 1))
check("halfway through the fade is half", near(HudRules.EdgeFade(78.75, 180, 0.25), 0.5))

-- points
check("0 is N", HudRules.PointName(0) == "N")
check("315 is NW", HudRules.PointName(315) == "NW")
check("360 wraps to N", HudRules.PointName(360) == "N")
check("15 has no letter", HudRules.PointName(15) == nil)

-- XP
check("half the XP is half the bar", near(HudRules.XPFraction(75, 150, false), 0.5))
check("no XP yet is empty", near(HudRules.XPFraction(nil, 150, false), 0))
check("more than needed stays full", near(HudRules.XPFraction(500, 150, false), 1))
check("the level cap is full", near(HudRules.XPFraction(0, 150, true), 1))

-- combo tiers
local TIERS = { { from = 0 }, { from = 10 }, { from = 25 } }
check("a few hits are the first tier", HudRules.ComboTier(TIERS, 3) == 1)
check("10 hits are the second", HudRules.ComboTier(TIERS, 10) == 2)
check("40 hits are the last", HudRules.ComboTier(TIERS, 40) == 3)

-- low health
check("healthy is no red", near(HudRules.LowHealthIntensity(0.8, 0.3), 0))
check("at the start it's still none", near(HudRules.LowHealthIntensity(0.3, 0.3), 0))
check("half of the start is half", near(HudRules.LowHealthIntensity(0.15, 0.3), 0.5))
check("dead is none", near(HudRules.LowHealthIntensity(0, 0.3), 0))

-- zones
local ZONES = {
	{ name = "Small", min = { 0, 0 }, max = { 10, 10 } },
	{ name = "Big", min = { -100, -100 }, max = { 100, 100 } },
}
check("inside both, the first listed wins", HudRules.ZoneAt(ZONES, 5, 5) == "Small")
check("inside the big one only", HudRules.ZoneAt(ZONES, 50, -50) == "Big")
check("the edge counts as inside", HudRules.ZoneAt(ZONES, 10, 10) == "Small")
check("outside every zone is nil", HudRules.ZoneAt(ZONES, 500, 0) == nil)

local shaped = true
for _, zone in ipairs(ZoneConfig.Zones) do
	if type(zone.name) ~= "string" or zone.min[1] >= zone.max[1] or zone.min[2] >= zone.max[2] then
		shaped = false
	end
end
check("every ZoneConfig zone has a name and min below max", shaped)
check("the spawn is in a zone", HudRules.ZoneAt(ZoneConfig.Zones, 113, 2) ~= nil)

if failures > 0 then
	error(string.format("%d HudRules test(s) failed", failures))
end
print("all HudRules tests passed")
