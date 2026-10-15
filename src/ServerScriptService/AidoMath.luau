-- The pure maths behind Aido's blasts (AidoUtil and his Skills): Ground Zero's
-- damage falloff, where aftershocks land, the points a marching line of blasts
-- stands on, and the directions of Total Destruction's lines. Only Vector3 and
-- math, so tests/AidoMath.spec.luau can run it with Lune.
local Vector3 = Vector3 or require("@lune/roblox").Vector3

local AidoMath = {}

-- damage at `distance` from the centre: `centre` at 0, `edge` at `radius`
-- (straight line between), 0 past the radius
function AidoMath.falloff(distance, radius, centre, edge)
	if distance > radius then
		return 0
	end
	local t = math.clamp(distance / radius, 0, 1)
	return centre + (edge - centre) * t
end

-- `count` points scattered flat (same height as `centre`) within `radius` of
-- it; `rng` returns 0 to 1 (math.random in the game)
function AidoMath.scatter(centre, radius, count, rng)
	local points = {}
	for i = 1, count do
		local angle = rng() * math.pi * 2
		local distance = radius * math.sqrt(rng()) -- sqrt: an even spread over the disc
		points[i] = centre + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	end
	return points
end

-- `count` points evenly along `direction` from `origin`: the first at
-- length / count, the last at length
function AidoMath.linePoints(origin, direction, length, count)
	local points = {}
	local unit = direction.Unit
	for i = 1, count do
		points[i] = origin + unit * (length * i / count)
	end
	return points
end

-- `count` unit vectors `spread` degrees apart, flat, the middle one along
-- `direction`
function AidoMath.fan(direction, count, spread)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	flat = flat.Magnitude > 1e-6 and flat.Unit or Vector3.new(0, 0, -1)
	local directions = {}
	for i = 1, count do
		local angle = math.rad((i - (count + 1) / 2) * spread)
		local cos, sin = math.cos(angle), math.sin(angle)
		-- turned about the Y axis
		directions[i] = Vector3.new(flat.X * cos + flat.Z * sin, 0, -flat.X * sin + flat.Z * cos)
	end
	return directions
end

return AidoMath
