-- Unit tests for ReplicatedStorage.Water's pure functions (is a point inside
-- a water part, and where is the surface above it). Run with Lune, outside
-- Roblox: tests/run.sh. The game helpers (Find, IsIn) run only in Roblox.
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Water = require("../src/ReplicatedStorage/Water")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local size = Vector3.new(10, 4, 10)
local flat = CFrame.new(0, 0, 0)

check("the numbers", Water.Tag == "Water" and Water.SwimSpeed == 16 and Water.SurfaceOffset == 1.2 and Water.RiseSpeed == 10)

-- an unrotated 10 x 4 x 10 box at the origin
check("centre is inside", Water.inside(flat, size, Vector3.new(0, 0, 0)))
check("just above the top is outside", not Water.inside(flat, size, Vector3.new(0, 2.1, 0)))
check("just below the bottom is outside", not Water.inside(flat, size, Vector3.new(0, -2.1, 0)))
check("a corner just inside", Water.inside(flat, size, Vector3.new(4.9, 0, 4.9)))
check("just past the side is outside", not Water.inside(flat, size, Vector3.new(5.1, 0, 0)))
check("the surface above any inside point is the top", Water.surfaceY(flat, size, Vector3.new(1, 0, -3)) == 2)
check("the surface follows the part's height", Water.surfaceY(CFrame.new(0, 10, 0), size, Vector3.new(0, 10, 0)) == 12)

-- the same box turned 45 degrees about Y: its corners now point along the axes
local turned = CFrame.Angles(0, math.rad(45), 0)
check("turned: on the axis, near the corner", Water.inside(turned, size, Vector3.new(6, 0, 0)))
check("turned: past the corner", not Water.inside(turned, size, Vector3.new(7.2, 0, 0)))
check("turned: on the diagonal", Water.inside(turned, size, Vector3.new(3.4, 0, 3.4)))
check("turned: outside the diagonal", not Water.inside(turned, size, Vector3.new(4, 0, 4)))
check("turned: the surface is still the top", math.abs(Water.surfaceY(turned, size, Vector3.new(6, 0, 0)) - 2) < 1e-9)

-- two touching parts: a point on the seam is inside at least one of them, and each side is inside its own
local left = CFrame.new(-5, 0, 0)
local right = CFrame.new(5, 0, 0)
local seam = Vector3.new(0, 0, 0)
check("seam: inside one or the other", Water.inside(left, size, seam) or Water.inside(right, size, seam))
check("seam: each side inside its own part", Water.inside(left, size, Vector3.new(-0.2, 0, 0)) and Water.inside(right, size, Vector3.new(0.2, 0, 0)))
check("seam: not inside the far part", not Water.inside(right, size, Vector3.new(-0.2, 0, 0)))

-- a part tilted 45 degrees about Z: its top face slopes, so the surface depends on where you are
local tilted = CFrame.Angles(0, 0, math.rad(45))
check("tilted: the surface over the middle is higher than the flat top", math.abs(Water.surfaceY(tilted, size, Vector3.new(0, 0, 0)) - 2.8284271247) < 1e-6)
check("tilted: the surface rises towards +X, where the top face leans up", Water.surfaceY(tilted, size, Vector3.new(2, 0, 0)) > Water.surfaceY(tilted, size, Vector3.new(-2, 0, 0)))

if failures > 0 then
	error(failures .. " failed")
end
