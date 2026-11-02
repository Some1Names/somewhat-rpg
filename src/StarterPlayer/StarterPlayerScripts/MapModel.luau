-- The 3D map's blocks, shared by the hub's Map tab (MapMenu) and the travel map (FastTravelMenu):
-- the place as a model of blocks built from MapLayout (baked from the parts by tools/bake_map.luau;
-- bake again after the map changes), each height step a little lighter. It's grey where the player
-- hasn't been and in the parts' own colours where they have: walking about paints it (their saved
-- Explored text; MapRules cuts the place into small cells, and a block over many of them into
-- explored and unexplored pieces; MapServer reveals). There is one model, built the first time it's
-- shown: MapModel.Show(viewport) moves it into that ViewportFrame (only one menu is open at a time,
-- Menus). MapModel.Light(viewport) lights a ViewportFrame from the north-west, high, and
-- MapModel.StepColours() are the height steps' tones, low to high (the legend's key).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapLayout = require(ReplicatedStorage:WaitForChild("MapLayout"))
local MapRules = require(ReplicatedStorage:WaitForChild("MapRules"))

local player = Players.LocalPlayer

local KIND_COLOURS = {
	green = Color3.fromRGB(34, 46, 37),
	land = Color3.fromRGB(50, 46, 40),
	road = Color3.fromRGB(84, 84, 92),
	water = Color3.fromRGB(24, 36, 54),
	build = Color3.fromRGB(56, 56, 64),
}
local HIGH = Color3.fromRGB(226, 226, 232) -- what each height step lightens a colour toward
local STEP_LIGHT = { 0, 0.12, 0.24, 0.38, 0.52, 0.68 } -- how far, by MapRules.HeightBand
local FLOOR = -20 -- studs: no block goes lower (the backdrop towers reach far underground)
local LIGHT_DIRECTION = Vector3.new(1, -3, 1) -- the way the light falls: from the north-west, high
local LIGHT = Color3.fromRGB(200, 200, 200)
local AMBIENT = Color3.fromRGB(100, 100, 110) -- the sides facing away from the light
local WATER = Color3.fromRGB(46, 104, 150) -- the sea, whatever its parts are made of
local HEIGHT_TINT = 0.5 -- how much of a height step's lightening the parts' own colours take
local GREY_DIM = 0.8 -- an unexplored block's grey, as a share of its colour's lightness

local MapModel = {}

function MapModel.Light(viewport)
	viewport.Ambient = AMBIENT
	viewport.LightColor = LIGHT
	viewport.LightDirection = LIGHT_DIRECTION
end

function MapModel.StepColours()
	local steps = {}
	for i = 1, #STEP_LIGHT do
		steps[i] = KIND_COLOURS.build:Lerp(HIGH, STEP_LIGHT[i])
	end
	return steps
end

-- a block for the model: a box from `bottom` to `top`, turned about its middle
local function block(parent, x, z, width, depth, turn, bottom, top, colour)
	local height = math.max(top - bottom, 0.2)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = colour
	part.Size = Vector3.new(width, height, depth)
	part.CFrame = CFrame.new(x, bottom + height / 2, z) * CFrame.Angles(0, -math.rad(turn), 0)
	part.Parent = parent
	return part
end

-- the blocks, each with its colour and its grey. A square-on block over more than one cell is
-- built by paint, as the pieces of it that are explored or not; any other block is one part,
-- listed under the cell its middle is in (an older bake has no bottoms or colours: a slab under
-- each top, in its kind's tone)
local model -- built on the first Show
local cellBlocks = {} -- cell (0 off the grid) -> { { part, colour, grey } }
local wideBlocks = {} -- { minX, minZ, maxX, maxZ, bottom, top, colour, grey, parts = {}, key }
local function build()
	model = Instance.new("Model")
	model.Name = "Blocks"
	for _, shape in ipairs(MapLayout.Shapes) do
		local top = shape[6]
		local own = shape[7] == "water" and WATER or shape[9] and Color3.fromHex(shape[9]) or KIND_COLOURS[shape[7]] or KIND_COLOURS.build
		local colour = own:Lerp(HIGH, STEP_LIGHT[MapRules.HeightBand(top)] * HEIGHT_TINT)
		local lightness = (0.299 * colour.R + 0.587 * colour.G + 0.114 * colour.B) * GREY_DIM
		local grey = Color3.new(lightness, lightness, lightness)
		local bottom = math.max(shape[8] or top - 1, FLOOR)
		local minX, minZ, maxX, maxZ = MapRules.SquareFootprint(shape[1], shape[2], shape[3], shape[4], shape[5])
		if minX and MapRules.CellAt(minX, minZ) ~= MapRules.CellAt(maxX - 0.01, maxZ - 0.01) then
			table.insert(wideBlocks, { minX, minZ, maxX, maxZ, bottom, top, colour, grey, parts = {}, key = "" })
		else
			local cell = MapRules.CellAt(shape[1], shape[2]) or 0
			cellBlocks[cell] = cellBlocks[cell] or {}
			table.insert(cellBlocks[cell], { block(model, shape[1], shape[2], shape[3], shape[4], shape[5], bottom, top, grey), colour, grey })
		end
	end
end

-- each explored cell's blocks in their colours, the rest grey; a wide block is built again
-- only when its pieces change
local painted = {} -- cell -> whether its blocks show their colours
local function paint()
	local explored = MapRules.DecodeExplored(player:GetAttribute("Explored"))
	for cell, list in pairs(cellBlocks) do
		local on = explored[cell] == true
		if painted[cell] ~= on then
			painted[cell] = on
			for _, entry in ipairs(list) do
				entry[1].Color = on and entry[2] or entry[3]
			end
		end
	end
	for _, wide in ipairs(wideBlocks) do
		local rects = MapRules.PaintRects(wide[1], wide[2], wide[3], wide[4], explored)
		local keys = {}
		for i, rect in ipairs(rects) do
			keys[i] = string.format("%g %g %g %g %s", rect[1], rect[2], rect[3], rect[4], tostring(rect[5]))
		end
		table.sort(keys)
		local key = table.concat(keys, ";")
		if key ~= wide.key then
			wide.key = key
			for _, part in ipairs(wide.parts) do
				part:Destroy()
			end
			table.clear(wide.parts)
			for _, rect in ipairs(rects) do
				local x, z = (rect[1] + rect[3]) / 2, (rect[2] + rect[4]) / 2
				local colour = rect[5] and wide[7] or wide[8]
				table.insert(wide.parts, block(model, x, z, rect[3] - rect[1], rect[4] - rect[2], 0, wide[5], wide[6], colour))
			end
		end
	end
end
player:GetAttributeChangedSignal("Explored"):Connect(function()
	if model then
		paint()
	end
end)

-- puts the blocks in `viewport` (built and painted the first time)
function MapModel.Show(viewport)
	if not model then
		build()
		paint()
	end
	model.Parent = viewport
end

return MapModel
