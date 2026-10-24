-- Unit tests for ReplicatedStorage.MapRules (the 3D map's camera, projection, ground
-- picking, fit, zoom and limits, the arrow, height steps and exploring). Run with Lune,
-- outside Roblox: tests/run.sh.
local MapRules = require("../src/ReplicatedStorage/MapRules")

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

local BOUNDS = { -100, -50, 300, 150 } -- 400 wide, 200 deep
local W, H = 800, 400 -- the box, px
local FIT = MapRules.FitDistance(BOUNDS, W, H)
local GROUND = MapRules.Ground
local TOP = { x = 100, z = 50, yaw = 0, pitch = 90, zoom = 1 } -- fitted: straight down at the middle

do
	local x, y = MapRules.Project(TOP, FIT, W, H, 100, GROUND, 50)
	check("the point looked at is the box's middle", near(x, W / 2) and near(y, H / 2))
	x, y = MapRules.Project(TOP, FIT, W, H, 100, GROUND, -50)
	check("north is up", near(x, W / 2) and y < H / 2)
	x = MapRules.Project(TOP, FIT, W, H, 300, GROUND, 50)
	check("east is right", x > W / 2)
	local left = MapRules.Project(TOP, FIT, W, H, -100, GROUND, 50)
	local _, top = MapRules.Project(TOP, FIT, W, H, 100, GROUND, -50)
	check("fitted: the place reaches the box's edges", near(left, 0) and near(top, 0))
	local gx, gz = MapRules.GroundAt(TOP, FIT, W, H, W / 2, H / 2)
	check("the box's middle picks the point looked at", near(gx, 100) and near(gz, 50))
end

do
	local tilted = { x = 100, z = 50, yaw = 30, pitch = 40, zoom = 3 }
	local px, py = MapRules.Project(tilted, FIT, W, H, 130, GROUND, 10)
	local gx, gz = MapRules.GroundAt(tilted, FIT, W, H, px, py)
	check("tilted and turned, picking the ground undoes projecting", near(gx, 130) and near(gz, 10))
	local _, _, _, look = MapRules.Camera(tilted, FIT)
	check("pitch is how far the camera looks below level", near(math.deg(math.asin(-look[2])), 40))
	local low = { x = 100, z = 50, yaw = 0, pitch = 10, zoom = 1 }
	check("above the horizon there's no ground", MapRules.GroundAt(low, FIT, W, H, W / 2, 0) == nil)
	check("behind the camera doesn't project", MapRules.Project(low, FIT, W, H, 100, GROUND, 50 + 10 * FIT) == nil)
end

do
	local zoomed = MapRules.ZoomAt(TOP, 2, 200, 100)
	check("zoom doubles", zoomed.zoom == 2)
	check("zooming in halves the way to the point", near(zoomed.x, 150) and near(zoomed.z, 75))
	local tilted = { x = 100, z = 50, yaw = 20, pitch = 50, zoom = 2 }
	local gx, gz = MapRules.GroundAt(tilted, FIT, W, H, 600, 120)
	local ax, ay = MapRules.Project(MapRules.ZoomAt(tilted, 1.25, gx, gz), FIT, W, H, gx, GROUND, gz)
	check("the spot under the cursor stays under it", math.abs(ax - 600) < 1e-4 and math.abs(ay - 120) < 1e-4)
	local most = { x = 0, z = 0, yaw = 0, pitch = 90, zoom = MapRules.MaxZoom }
	check("zoom stops at the most", MapRules.ZoomAt(most, 2, 0, 0).zoom == MapRules.MaxZoom)
	check("zoom stops at the least", MapRules.ZoomAt(TOP, 0.5, 0, 0).zoom == MapRules.MinZoom)
end

do
	local view = MapRules.ClampView({ x = 900, z = -900, yaw = 370, pitch = 10, zoom = 4 }, BOUNDS)
	check("the point looked at stays on the map", view.x == 300 and view.z == -50)
	check("tilt stops at the least", view.pitch == MapRules.MinPitch)
	check("turning wraps round", view.yaw == 10)
	local fitted = MapRules.ClampView({ x = 0, z = 0, yaw = 0, pitch = 120, zoom = 1 }, BOUNDS)
	check("fitted: back to the middle, looking straight down", fitted.x == 100 and fitted.z == 50 and fitted.pitch == 90)
end

check("up on screen is 0", near(MapRules.Heading(0, -1), 0))
check("right is 90", near(MapRules.Heading(1, 0), 90))
check("down is 180", near(math.abs(MapRules.Heading(0, 1)), 180))
check("left is -90", near(MapRules.Heading(-1, 0), -90))

check("ground is the first step", MapRules.HeightBand(0) == 1 and MapRules.HeightBand(14) == 1)
check("a step starts at its edge", MapRules.HeightBand(15) == 2)
check("the tallest step has no end", MapRules.HeightBand(5000) == #MapRules.HeightSteps + 1)

do
	local origin, size = MapRules.ExploreOrigin, MapRules.ExploreCell
	local cell = MapRules.ExploreColumns + 2 -- second row, second column
	check("cells run along rows", MapRules.CellAt(origin[1] + 1.5 * size, origin[2] + 1.5 * size) == cell)

	local near = MapRules.CellsNear(origin[1] + 1.5 * size, origin[2] + 1.5 * size)
	check("a player reveals their own cell", table.find(near, cell) ~= nil)
	check("and the cells beside it", table.find(near, cell + 1) ~= nil and table.find(near, cell - MapRules.ExploreColumns) ~= nil)
	check("a far player reveals nothing", #MapRules.CellsNear(origin[1] - 10000, origin[2]) == 0)
	-- from the middle of a cell well inside the grid, 187.5 studs reach 4 cells of 50 each way
	local midX, midZ = origin[1] + 20.5 * size, origin[2] + 20.5 * size
	local square = MapRules.CellsNear(midX, midZ)
	check("the reveal is a square of whole cells", #square == 9 * 9)
	check("its corners are in it", table.find(square, MapRules.CellAt(midX + 4 * size, midZ + 4 * size)) ~= nil)
	local corner = MapRules.CellsNear(origin[1], origin[2])
	check("at the grid's corner, only cells inside it", #corner > 0 and table.find(corner, 0) == nil)
end

do
	local origin, size = MapRules.ExploreOrigin, MapRules.ExploreCell
	check("a point is in its cell", MapRules.CellAt(origin[1] + 1, origin[2] + 1) == 1)
	check("off the grid is no cell", MapRules.CellAt(origin[1] - 1, origin[2]) == nil)
	local x0, z0, x1, z1 = MapRules.SquareFootprint(0, 0, 300, 100, 90)
	check("a quarter turn swaps width and depth", near(x1 - x0, 100) and near(z1 - z0, 300))
	check("a slanted shape has no square footprint", MapRules.SquareFootprint(0, 0, 50, 30, 30) == nil)

	-- a 4 by 3 cell area well inside the grid
	local ax, az = origin[1] + 10 * size, origin[2] + 10 * size
	local function cellOf(column, row)
		return (10 + row) * MapRules.ExploreColumns + 10 + column + 1
	end
	local grey = MapRules.PaintRects(ax, az, ax + 4 * size, az + 3 * size, {})
	check("unexplored: one grey rectangle", #grey == 1 and grey[1][5] == false and near(grey[1][3] - grey[1][1], 4 * size) and near(grey[1][4] - grey[1][2], 3 * size))
	local explored = { [cellOf(1, 0)] = true, [cellOf(2, 0)] = true, [cellOf(1, 1)] = true, [cellOf(2, 1)] = true }
	local rects = MapRules.PaintRects(ax, az, ax + 4 * size, az + 3 * size, explored)
	local area, coloured = 0, 0
	for _, rect in ipairs(rects) do
		local piece = (rect[3] - rect[1]) * (rect[4] - rect[2])
		area += piece
		coloured += rect[5] and piece or 0
	end
	check("the rectangles cover the area", near(area, 12 * size * size))
	check("the explored part is the coloured part", near(coloured, 4 * size * size))
	check("matching runs on the next row join up", #rects == 4)
	local edge = MapRules.PaintRects(ax + 10, az + 10, ax + 60, az + 20, {})
	check("an area's own edges are kept", #edge == 1 and near(edge[1][1], ax + 10) and near(edge[1][3], ax + 60))
	local off = MapRules.PaintRects(origin[1] - 100, origin[2], origin[1] - 50, origin[2] + 50, { [1] = true })
	check("off the grid stays unexplored", #off == 1 and off[1][5] == false)
end

do
	local explored = { [1] = true, [7] = true, [MapRules.Cells] = true }
	local text = MapRules.EncodeExplored(explored)
	check("explored text fits the save", #text <= MapRules.MaxSaveLength)
	local back = MapRules.DecodeExplored(text)
	check("explored round-trips", back[1] and back[7] and back[MapRules.Cells] and not back[2])
	check("nothing explored saves as empty", MapRules.EncodeExplored({}) == "")
	check("trailing empties are dropped", #MapRules.EncodeExplored({ [1] = true }) == 1)
	check("garbage decodes as unexplored", next(MapRules.DecodeExplored("!!!")) == nil and next(MapRules.DecodeExplored(nil)) == nil)
end

if failures > 0 then
	error(failures .. " MapRules test(s) failed")
end
