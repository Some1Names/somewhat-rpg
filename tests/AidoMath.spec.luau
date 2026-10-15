-- Unit tests for ServerScriptService.AidoMath (the pure blast maths). Run
-- with Lune, outside Roblox: tests/run.sh.
local Vector3 = require("@lune/roblox").Vector3
local AidoMath = require("../src/ServerScriptService/AidoMath")

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
	return math.abs(a - b) < 1e-3
end

check("falloff at the centre", AidoMath.falloff(0, 40, 110, 40) == 110)
check("falloff at the edge", AidoMath.falloff(40, 40, 110, 40) == 40)
check("falloff halfway", AidoMath.falloff(20, 40, 110, 40) == 75)
check("falloff past the radius", AidoMath.falloff(50, 40, 110, 40) == 0)

local points = AidoMath.scatter(Vector3.zero, 8, 3, math.random)
local inside = #points == 3
for _, point in ipairs(points) do
	inside = inside and point.Y == 0 and Vector3.new(point.X, 0, point.Z).Magnitude <= 8 + 1e-3
end
check("scatter gives count flat points within the radius", inside)

local line = AidoMath.linePoints(Vector3.zero, Vector3.new(0, 0, -1), 80, 6)
check("linePoints gives 6 points", #line == 6)
check("linePoints ends at the length", near(line[6].Z, -80))
check("linePoints spacing", near(line[1].Z, -80 / 6) and near((line[2] - line[1]).Magnitude, 80 / 6))

local forward = Vector3.new(0, 0, -1)
local fan = AidoMath.fan(forward, 3, 25)
check("fan gives 3 vectors", #fan == 3)
check("fan middle is the direction", (fan[2] - forward).Magnitude < 1e-3)
local function angleBetween(a, b)
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end
check("fan outer two are 25 degrees off", near(angleBetween(fan[1], forward), 25) and near(angleBetween(fan[3], forward), 25))
check("fan sides are opposite", (fan[1].X + fan[3].X) < 1e-3 and fan[1].X ~= fan[3].X)
check("fan vectors are unit", near(fan[1].Magnitude, 1) and near(fan[3].Magnitude, 1))
local single = AidoMath.fan(forward, 1, 25)
check("fan of one is the direction", #single == 1 and (single[1] - forward).Magnitude < 1e-3)

if failures > 0 then
	error(failures .. " check(s) failed")
end
