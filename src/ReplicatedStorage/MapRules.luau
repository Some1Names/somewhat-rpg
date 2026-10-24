-- The map tab's plain rules (MapMenu uses them): the 3D map's camera (where it sits for
-- a view, where a world point lands on screen, which ground point is under the cursor,
-- the distance that fits the whole place, zooming about a point), which way an arrow
-- points, a shape's height step, and exploring (MapServer reveals, PlayerStats saves).
-- A view is { x, z (the ground point it looks at), yaw, pitch (degrees: yaw 0 has north
-- up, pitch 90 looks straight down), zoom (1 fits the place) }; `fit` is the camera's
-- distance at zoom 1, `bounds` MapLayout's { minX, minZ, maxX, maxZ } in studs, and
-- screen points are px from the box's top-left. tests/MapRules.spec.luau runs it outside Roblox.
local MapRules = {}

MapRules.MinZoom = 1 -- the whole map fits
MapRules.MaxZoom = 16 -- the place is big: the town is a small part of it
MapRules.MinPitch = 35 -- degrees above the ground, tilted as far as it goes
MapRules.MaxPitch = 90 -- straight down
MapRules.Fov = 30 -- the camera's vertical field of view, degrees
MapRules.Ground = 12 -- studs: the ground's top, the plane the view looks at

-- the tops (studs) where each height step ends but the last: the map shades by step
MapRules.HeightSteps = { 15, 40, 80, 150, 250 }

-- exploring: the place is cut into square cells from a fixed corner (so baking the map
-- again never moves a save's cells), and a player reveals the cells around them. The
-- saved Explored text holds 6 cells a character
MapRules.ExploreOrigin = { -2000, -3400 } -- the grid's north-west corner, x and z
MapRules.ExploreCell = 50 -- studs: small, so the painted patch round a player is nearly round
MapRules.ExploreColumns = 144
MapRules.ExploreRows = 136
MapRules.RevealRadius = 187.5 -- studs each way round a player: the square they paint
MapRules.Cells = MapRules.ExploreColumns * MapRules.ExploreRows
MapRules.MaxSaveLength = math.ceil(MapRules.Cells / 6)

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- the camera for a view: its position and its right, up and look directions, each { x, y, z }
function MapRules.Camera(view, fit)
	local distance = fit / view.zoom
	local yaw, pitch = math.rad(view.yaw), math.rad(view.pitch)
	local backX, backZ = math.sin(yaw), math.cos(yaw) -- along the ground, from the point looked at to the camera
	local flat, rise = math.cos(pitch), math.sin(pitch)
	local position = { view.x + distance * flat * backX, MapRules.Ground + distance * rise, view.z + distance * flat * backZ }
	return position, { backZ, 0, -backX }, { -rise * backX, flat, -rise * backZ }, { -flat * backX, -rise, -flat * backZ }
end

-- where world point (x, y, z) lands in a box `width` by `height`, or nil behind the camera
function MapRules.Project(view, fit, width, height, x, y, z)
	local position, right, up, look = MapRules.Camera(view, fit)
	local dx, dy, dz = x - position[1], y - position[2], z - position[3]
	local ahead = dx * look[1] + dy * look[2] + dz * look[3]
	if ahead <= 0.1 then
		return nil
	end
	local half = math.tan(math.rad(MapRules.Fov) / 2)
	local across = (dx * right[1] + dy * right[2] + dz * right[3]) / (ahead * half * width / height)
	local upward = (dx * up[1] + dy * up[2] + dz * up[3]) / (ahead * half)
	return (across + 1) / 2 * width, (1 - upward) / 2 * height
end

-- the point on the ground (x, z) under screen point (px, py), or nil above the horizon
function MapRules.GroundAt(view, fit, width, height, px, py)
	local position, right, up, look = MapRules.Camera(view, fit)
	local half = math.tan(math.rad(MapRules.Fov) / 2)
	local across, upward = (px / width * 2 - 1) * half * width / height, (1 - py / height * 2) * half
	local ray = {}
	for i = 1, 3 do
		ray[i] = look[i] + right[i] * across + up[i] * upward
	end
	if ray[2] >= -1e-6 then
		return nil
	end
	local reach = (MapRules.Ground - position[2]) / ray[2]
	return position[1] + ray[1] * reach, position[3] + ray[3] * reach
end

-- the camera's distance at zoom 1: looking straight down, the whole place fits the box
function MapRules.FitDistance(bounds, width, height)
	local half = math.tan(math.rad(MapRules.Fov) / 2)
	return math.max((bounds[4] - bounds[2]) / 2 / half, (bounds[3] - bounds[1]) / 2 / (half * width / height))
end

-- zooming by `factor` about ground point (x, z): the camera moves straight toward or away
-- from it, so it stays under the cursor
function MapRules.ZoomAt(view, factor, x, z)
	local zoom = math.clamp(view.zoom * factor, MapRules.MinZoom, MapRules.MaxZoom)
	local shrink = view.zoom / zoom
	return { x = x + (view.x - x) * shrink, z = z + (view.z - z) * shrink, yaw = view.yaw, pitch = view.pitch, zoom = zoom }
end

-- a view kept in range: tilt between MinPitch and MaxPitch, looking at a point on the map,
-- and at zoom 1 at the map's middle
function MapRules.ClampView(view, bounds)
	local x, z = math.clamp(view.x, bounds[1], bounds[3]), math.clamp(view.z, bounds[2], bounds[4])
	if view.zoom <= MapRules.MinZoom then
		x, z = (bounds[1] + bounds[3]) / 2, (bounds[2] + bounds[4]) / 2
	end
	return { x = x, z = z, yaw = view.yaw % 360, pitch = math.clamp(view.pitch, MapRules.MinPitch, MapRules.MaxPitch), zoom = view.zoom }
end

-- an arrow's Rotation (degrees clockwise from pointing up) for a direction on screen (x right, y down)
function MapRules.Heading(dx, dy)
	return math.deg(math.atan2(dx, -dy))
end

-- a top's height step: 1 (the ground) to #HeightSteps + 1 (the tallest)
function MapRules.HeightBand(top)
	for i, step in ipairs(MapRules.HeightSteps) do
		if top < step then
			return i
		end
	end
	return #MapRules.HeightSteps + 1
end

-- the cell (1 to Cells) point (x, z) is in, or nil off the grid
function MapRules.CellAt(x, z)
	local column = math.floor((x - MapRules.ExploreOrigin[1]) / MapRules.ExploreCell)
	local row = math.floor((z - MapRules.ExploreOrigin[2]) / MapRules.ExploreCell)
	if column < 0 or row < 0 or column >= MapRules.ExploreColumns or row >= MapRules.ExploreRows then
		return nil
	end
	return row * MapRules.ExploreColumns + column + 1
end

-- a shape's footprint as minX, minZ, maxX, maxZ when it's square-on (turned a multiple
-- of 90 degrees), or nil when it's slanted
function MapRules.SquareFootprint(x, z, width, depth, turn)
	local slant = turn % 90
	if slant > 0.5 and slant < 89.5 then
		return nil
	end
	if math.abs(turn % 180 - 90) < 0.5 then
		width, depth = depth, width
	end
	return x - width / 2, z - depth / 2, x + width / 2, z + depth / 2
end

-- the area minX..maxX, minZ..maxZ cut along the cells into rectangles that are all
-- explored or all not, as few as rows of runs allow (a run the same as the one above it
-- joins its rectangle): { minX, minZ, maxX, maxZ, explored } each. Off the grid is unexplored
function MapRules.PaintRects(minX, minZ, maxX, maxZ, explored)
	local origin, size, columns = MapRules.ExploreOrigin, MapRules.ExploreCell, MapRules.ExploreColumns
	local firstColumn, lastColumn = math.floor((minX - origin[1]) / size), math.ceil((maxX - origin[1]) / size) - 1
	local firstRow, lastRow = math.floor((minZ - origin[2]) / size), math.ceil((maxZ - origin[2]) / size) - 1
	local rects, open = {}, {} -- open: "first:last:explored" -> the rectangle still growing down
	for row = firstRow, lastRow do
		local z1 = math.min(maxZ, origin[2] + (row + 1) * size)
		local growing, first, state = {}, nil, nil
		for column = firstColumn, lastColumn + 1 do
			local on
			if column <= lastColumn then
				local inGrid = column >= 0 and row >= 0 and column < columns and row < MapRules.ExploreRows
				on = inGrid and explored[row * columns + column + 1] == true
			end
			if first and on ~= state then
				local key = first .. ":" .. (column - 1) .. ":" .. tostring(state)
				local rect = open[key]
					or { math.max(minX, origin[1] + first * size), math.max(minZ, origin[2] + row * size), math.min(maxX, origin[1] + column * size), 0, state }
				rect[4] = z1
				growing[key], open[key] = rect, nil
				first = nil
			end
			if on ~= nil and not first then
				first, state = column, on
			end
		end
		for _, rect in pairs(open) do
			table.insert(rects, rect)
		end
		open = growing
	end
	for _, rect in pairs(open) do
		table.insert(rects, rect)
	end
	return rects
end

-- the cells a player at (x, z) reveals: every cell the square RevealRadius each way round
-- them reaches into, whole cells at a time
function MapRules.CellsNear(x, z)
	local origin, size, reach = MapRules.ExploreOrigin, MapRules.ExploreCell, MapRules.RevealRadius
	local firstColumn = math.max(0, math.floor((x - reach - origin[1]) / size))
	local lastColumn = math.min(MapRules.ExploreColumns - 1, math.ceil((x + reach - origin[1]) / size) - 1)
	local firstRow = math.max(0, math.floor((z - reach - origin[2]) / size))
	local lastRow = math.min(MapRules.ExploreRows - 1, math.ceil((z + reach - origin[2]) / size) - 1)
	local cells = {}
	for row = firstRow, lastRow do
		for column = firstColumn, lastColumn do
			table.insert(cells, row * MapRules.ExploreColumns + column + 1)
		end
	end
	return cells
end

-- explored cells (cell -> true) as the saved text; trailing empty characters are dropped
function MapRules.EncodeExplored(explored)
	local chars = {}
	for i = 0, MapRules.MaxSaveLength - 1 do
		local value = 0
		for bit = 0, 5 do
			if explored[i * 6 + bit + 1] then
				value = bit32.bor(value, bit32.lshift(1, bit))
			end
		end
		chars[i + 1] = string.sub(ALPHABET, value + 1, value + 1)
	end
	return (string.gsub(table.concat(chars), "A+$", ""))
end

-- the saved text back to cell -> true; anything that isn't the alphabet counts as unexplored
function MapRules.DecodeExplored(text)
	local explored = {}
	if type(text) ~= "string" then
		return explored
	end
	for i = 1, math.min(#text, MapRules.MaxSaveLength) do
		local value = (string.find(ALPHABET, string.sub(text, i, i), 1, true) or 1) - 1
		for bit = 0, 5 do
			local cell = (i - 1) * 6 + bit + 1
			if bit32.extract(value, bit) == 1 and cell <= MapRules.Cells then
				explored[cell] = true
			end
		end
	end
	return explored
end

return MapRules
