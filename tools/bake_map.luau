-- Bakes the map tab's layout. Run it in Studio's command bar (in Edit, not a playtest)
-- whenever the map's parts change. It reads every visible part in the place, the far-off
-- areas too (not characters, NPCs or enemies, nor the effect and animation folders), turns
-- each into the rectangle it covers seen from above, keeps the biggest, and writes them,
-- lowest top first, into ReplicatedStorage.MapLayout (a ModuleScript that MapMenu draws).
-- Then export it to the repo like any other script (Studio -> Repo in CLAUDE.md).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MIN_AREA = 36 -- square studs: smaller footprints are props too small to see
local MAX_SHAPES = 3000 -- the biggest footprints are kept
local SKIP = { VFX = true, ["Particle Pack"] = true, Drops = true, MenuCameras = true }

-- a part's kind, by material: what the map colours it as
local KINDS = {
	Grass = "green",
	LeafyGrass = "green",
	Ground = "land",
	Mud = "land",
	Sand = "land",
	Pebble = "land",
	Asphalt = "road",
	Pavement = "road",
	Concrete = "road",
	Cobblestone = "road",
	Water = "water",
}

local function skipped(part)
	if part:IsA("Terrain") or part.Transparency >= 0.9 then
		return true
	end
	local ancestor = part.Parent
	while ancestor and ancestor ~= workspace do
		if ancestor:FindFirstChildOfClass("Humanoid") or ancestor:IsA("Camera") then
			return true
		end
		if ancestor.Parent == workspace and (SKIP[ancestor.Name] or (ancestor:IsA("Folder") and ancestor.Name:find("Anim"))) then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

-- every part sharing a parent with a part tagged Water is the sea or a lake
local waterParents = {}
for _, part in ipairs(CollectionService:GetTagged("Water")) do
	if part.Parent then
		waterParents[part.Parent] = true
	end
end

local function kindOf(part)
	if waterParents[part.Parent] or CollectionService:HasTag(part, "Water") then
		return "water"
	end
	local kind = KINDS[part.Material.Name]
	if kind then
		return kind
	end
	local colour = part.Color
	if colour.G > colour.R * 1.15 and colour.G > colour.B * 1.15 then
		return "green" -- leaves, hedges, painted grass
	end
	return "build"
end

-- the rectangle seen from above: the two axes that lie flattest, their lengths on
-- the ground, the turn of the first (degrees clockwise from +X, as the map draws),
-- and the part's top and bottom
local function footprint(part)
	local cf, size = part.CFrame, part.Size
	local axes = { { cf.RightVector, size.X }, { cf.UpVector, size.Y }, { cf.LookVector, size.Z } }
	local upright = 1
	for i = 2, 3 do
		if math.abs(axes[i][1].Y) > math.abs(axes[upright][1].Y) then
			upright = i
		end
	end
	local flat = {}
	for i, axis in ipairs(axes) do
		if i ~= upright then
			table.insert(flat, axis)
		end
	end
	local a, b = flat[1], flat[2]
	local width = a[2] * Vector2.new(a[1].X, a[1].Z).Magnitude
	local depth = b[2] * Vector2.new(b[1].X, b[1].Z).Magnitude
	local turn = math.deg(math.atan2(a[1].Z, a[1].X))
	local halfHeight = 0
	for _, axis in ipairs(axes) do
		halfHeight += math.abs(axis[1].Y) * axis[2] / 2
	end
	return width, depth, turn, cf.Position.Y + halfHeight, cf.Position.Y - halfHeight
end

local shapes = {}
for _, part in ipairs(workspace:GetDescendants()) do
	if part:IsA("BasePart") and not skipped(part) then
		local width, depth, turn, top, bottom = footprint(part)
		if width * depth >= MIN_AREA then
			table.insert(shapes, { part.Position.X, part.Position.Z, width, depth, turn, top, kindOf(part), bottom, part.Color:ToHex() })
		end
	end
end
table.sort(shapes, function(p, q)
	return p[3] * p[4] > q[3] * q[4]
end)
for i = #shapes, MAX_SHAPES + 1, -1 do
	shapes[i] = nil
end
table.sort(shapes, function(p, q)
	return p[6] < q[6]
end)

-- the bounds: every shape's turned rectangle fits inside
local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
local lines = {}
for _, shape in ipairs(shapes) do
	local x, z, width, depth, turn = shape[1], shape[2], shape[3], shape[4], math.rad(shape[5])
	local halfX = (math.abs(math.cos(turn)) * width + math.abs(math.sin(turn)) * depth) / 2
	local halfZ = (math.abs(math.sin(turn)) * width + math.abs(math.cos(turn)) * depth) / 2
	minX, maxX = math.min(minX, x - halfX), math.max(maxX, x + halfX)
	minZ, maxZ = math.min(minZ, z - halfZ), math.max(maxZ, z + halfZ)
	local round = math.round
	table.insert(lines, string.format(
		"\t\t{ %d, %d, %d, %d, %d, %d, %q, %d, %q },",
		round(x), round(z), math.max(1, round(width)), math.max(1, round(depth)), round(shape[5]), round(shape[6]), shape[7], round(shape[8]), shape[9]
	))
end

local source = table.concat({
	"-- The map tab's layout, made by tools/bake_map.luau from the parts in Studio: don't",
	"-- edit it by hand, bake again after the map changes. MapMenu draws it. Bounds =",
	"-- { minX, minZ, maxX, maxZ } in studs; Shapes, lowest top first, are",
	"-- { x, z, width, depth, turn (degrees clockwise from +X, seen from above), top, kind, bottom,",
	"-- colour (the part's, as hex) }.",
	"return {",
	string.format("\tBounds = { %d, %d, %d, %d },", math.floor(minX), math.floor(minZ), math.ceil(maxX), math.ceil(maxZ)),
	"\tShapes = {",
	table.concat(lines, "\n"),
	"\t},",
	"}",
	"",
}, "\n")

local module = ReplicatedStorage:FindFirstChild("MapLayout")
if not module then
	module = Instance.new("ModuleScript")
	module.Name = "MapLayout"
	module.Parent = ReplicatedStorage
end
module.Source = source
print(string.format("MapLayout: %d shapes, %d characters", #shapes, #source))
