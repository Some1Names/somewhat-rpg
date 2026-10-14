-- Unit tests for ReplicatedStorage.GuardConfig's pure rules (what counts as
-- the front, how much a block cuts, posture and its draining). Run with Lune,
-- outside Roblox: tests/run.sh.
local Vector3 = require("@lune/roblox").Vector3
local GuardConfig = require("../src/ReplicatedStorage/GuardConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- a unit vector `degrees` away from the blocker's look (+Z), around Y
local look = Vector3.new(0, 0, 1)
local function toSource(degrees)
	local r = math.rad(degrees)
	return Vector3.new(math.sin(r), 0, math.cos(r))
end

-- front: within 90° either side of where the blocker faces, flat
check("front at 0°", GuardConfig.isFront(look, toSource(0)))
check("front at 89°", GuardConfig.isFront(look, toSource(89)))
check("front at -89°", GuardConfig.isFront(look, toSource(-89)))
check("not front at 91°", not GuardConfig.isFront(look, toSource(91)))
check("not front at 180°", not GuardConfig.isFront(look, toSource(180)))
check("height is ignored", GuardConfig.isFront(look, Vector3.new(0, 50, 1)))
check("height alone is not front", not GuardConfig.isFront(look, Vector3.new(0, 1, -0.1)))
check("a zero direction counts as front", GuardConfig.isFront(look, Vector3.new(0, 0, 0)))

-- cuts by hit kind, and a set's own block replacing the base cut
check("melee cuts 60%", GuardConfig.cut("melee") == 0.6)
check("ranged cuts 50%", GuardConfig.cut("ranged") == 0.5)
check("skill cuts 30%", GuardConfig.cut("skill") == 0.3)
check("unblockable cuts nothing", GuardConfig.cut("unblockable") == 0)
check("an unknown kind cuts nothing", GuardConfig.cut("laser") == 0)
check("a set's melee block replaces the base", GuardConfig.cut("melee", { melee = 0.9 }) == 0.9)
check("a kind the set doesn't list keeps the base", GuardConfig.cut("skill", { melee = 0.9 }) == 0.3)
check("a set can't make unblockable blockable", GuardConfig.cut("unblockable", { unblockable = 1 }) == 0)

-- posture: what a block prevented fills it; at 100 the guard breaks
local posture, broke = GuardConfig.postureAfter(90, 18)
check("posture caps at 100 and breaks", posture == 100 and broke == true)
posture, broke = GuardConfig.postureAfter(10, 18)
check("posture adds the prevented damage", posture == 28 and broke == false)
posture, broke = GuardConfig.postureAfter(82, 18)
check("exactly 100 breaks", posture == 100 and broke == true)

-- draining: 20/s once he hasn't blocked for 1.5 s; 5/s while blocking unhit for 1.5 s
check("no drain too soon", GuardConfig.drain(50, 1, false, 1) == 50)
check("drains 20/s after the delay", GuardConfig.drain(50, 2, false, 1) == 30)
check("drains 5/s while blocking unhit", GuardConfig.drain(50, 2, true, 1) == 45)
check("no drain while blocking and just hit", GuardConfig.drain(50, 1, true, 1) == 50)
check("drain stops at 0", GuardConfig.drain(3, 2, false, 1) == 0)
check("drain scales with dt", GuardConfig.drain(50, 2, false, 0.1) == 48)

if failures > 0 then
	error(failures .. " failed")
end
