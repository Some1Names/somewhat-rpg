-- The hub's Map tab (M): the place as a 3D model of blocks in a ViewportFrame, built
-- from MapLayout (baked from the parts by tools/bake_map.luau; bake again after the map
-- changes), lit from the north-west, each height step a little lighter. It's grey where
-- the player hasn't been and in the parts' own colours where they have: walking about
-- paints it, a square MapRules.RevealRadius each way round them (their saved Explored
-- text; MapRules cuts the place into small cells, and a block over many of them into
-- explored and unexplored pieces; MapServer reveals). Over it,
-- flat markers: you (an arrow the way you face), your party mates, the Bounty Hunters,
-- the smith, recruiter, shops and gacha, and the spawns; the legend under the map turns
-- each kind on and off, and a marker's name shows only while the cursor is over it (or
-- a finger holds it). With streaming on far-off parts aren't here, so the NPCs come from
-- ReplicatedStorage.MapMarkers and far party mates from their MapPosition attribute
-- (both MapServer's). The model floats over a faint grid and fades out at the box's
-- edges. Each time it opens it starts afresh, looking
-- straight down at you, north up; the wheel zooms about the cursor (all the way out, the
-- whole place fits), dragging moves it, and holding the right button while dragging up
-- and down tilts it; let go and it eases back to straight down. It never turns. The
-- camera maths is in MapRules. Square everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Hub = require(script.Parent:WaitForChild("Hub"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local MapLayout = require(ReplicatedStorage:WaitForChild("MapLayout"))
local MapRules = require(ReplicatedStorage:WaitForChild("MapRules"))
local markerFolder = ReplicatedStorage:WaitForChild("MapMarkers") -- made by MapServer
local player = Players.LocalPlayer

local Theme = Hub.Theme
local REFRESH = 0.2 -- s between finding your party mates while the tab shows
local ZOOM_STEP = 1.25 -- per notch of the wheel
local OPEN_ZOOM = 6 -- the zoom it opens at, on you (the town fills the box)
local TILT_SPEED = 0.25 -- degrees the map tilts per px of a right-drag up or down
local TILT_RETURN = 8 -- how fast a let-go tilt eases back to straight down (a share of the way, per second)
local LEGEND_HEIGHT = 18
local LEGEND_GAP = 10
local PIN = 8 -- px, a marker's square
local PIN_HOVER = 18 -- px, the area round it that shows its name
local ARROW = 18 -- px, your arrow
local ARROW_REACH = 20 -- studs ahead of you that set which way the arrow points
local LABEL_SIZE = 12
local LABEL_GAP = 4
local GRID = 32 -- px between the background grid's lines
local GRID_TRANSPARENCY = 0.93
local FADE = 56 -- px over which the map fades into the paper at the box's edges
local PAPER_SEE_THROUGH = 0.1 -- the hub paper's own transparency, so the faded edge matches it
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
local UNEXPLORED = Color3.fromRGB(110, 110, 110) -- its square in the legend
local OFF = Theme.BarBack -- a filter that's off
local QUEST = Color3.fromRGB(255, 196, 64)
local PIN_COLOURS = { Quest = QUEST, Service = Theme.Ink, Spawn = Theme.Muted }

local bounds = MapLayout.Bounds

local function make(className, props)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.LabelFont
	props.TextColor3 = props.TextColor3 or Theme.Ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local tabFrame = Hub.Tab("Map", { order = 2.5, title = "MAP", key = Enum.KeyCode.M })

-- the map's box, back to front: the grid, the 3D model, the markers and the faded edges;
-- under it the legend and how to move the map
local box = make("Frame", {
	Parent = tabFrame,
	Size = UDim2.new(1, 0, 1, -(LEGEND_HEIGHT + LEGEND_GAP)),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Active = true,
})
local grid = make("Frame", { Parent = box, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 })
local viewport = make("ViewportFrame", {
	Parent = box,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Ambient = AMBIENT,
	LightColor = LIGHT,
	LightDirection = LIGHT_DIRECTION,
	ZIndex = 2,
})
local camera = make("Camera", { Parent = viewport, FieldOfView = MapRules.Fov })
viewport.CurrentCamera = camera
local blocks = make("Model", { Name = "Blocks", Parent = viewport })
local pinLayer = make("Frame", { Parent = box, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 })
-- left, right, top, bottom: { anchor and position, size, gradient turn (paper at the edge, clear inside) }
for _, edge in ipairs({
	{ Vector2.new(0, 0), UDim2.new(0, FADE, 1, 0), 0 },
	{ Vector2.new(1, 0), UDim2.new(0, FADE, 1, 0), 180 },
	{ Vector2.new(0, 0), UDim2.new(1, 0, 0, FADE), 90 },
	{ Vector2.new(0, 1), UDim2.new(1, 0, 0, FADE), -90 },
}) do
	local fade = make("Frame", {
		Parent = box,
		AnchorPoint = edge[1],
		Position = UDim2.fromScale(edge[1].X, edge[1].Y),
		Size = edge[2],
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		ZIndex = 4,
	})
	make("UIGradient", { Parent = fade, Rotation = edge[3], Transparency = NumberSequence.new(PAPER_SEE_THROUGH, 1) })
end

local legend = make("Frame", {
	Parent = tabFrame,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, LEGEND_HEIGHT),
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = legend,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 14),
})
label(tabFrame, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.fromOffset(0, LEGEND_HEIGHT),
	AutomaticSize = Enum.AutomaticSize.X,
	Text = "WHEEL ZOOMS · DRAG MOVES · RIGHT-DRAG TILTS",
	TextSize = 11,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Right,
})

-- a legend entry: squares then a word; a filter's entry is a button
local function legendEntry(order, text, colours, isFilter)
	local holder = make(isFilter and "TextButton" or "Frame", {
		Parent = legend,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, LEGEND_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	})
	if isFilter then
		holder.Text = ""
		holder.AutoButtonColor = false
		holder:SetAttribute("SectionSelect", true) -- Hub's click sound
	end
	make("UIListLayout", {
		Parent = holder,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	})
	local swatches = {}
	for i, colour in ipairs(colours) do
		local swatch = make("Frame", {
			Parent = holder,
			LayoutOrder = i,
			Size = UDim2.fromOffset(PIN, PIN),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
		})
		table.insert(swatches, swatch)
	end
	local word = label(holder, {
		LayoutOrder = #colours + 1,
		Text = " " .. text,
		TextSize = 11,
		TextColor3 = Theme.Muted,
		Size = UDim2.fromOffset(0, LEGEND_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	return holder, swatches, word
end

-- a block for the model: a box from `bottom` to `top`, turned about its middle
local function block(parent, x, z, width, depth, turn, bottom, top, colour)
	local height = math.max(top - bottom, 0.2)
	return make("Part", {
		Parent = parent,
		Anchored = true,
		CanCollide = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		Color = colour,
		Size = Vector3.new(width, height, depth),
		CFrame = CFrame.new(x, bottom + height / 2, z) * CFrame.Angles(0, -math.rad(turn), 0),
	})
end

-- the blocks, built on the first showing, each with its colour and its grey. A square-on
-- block over more than one cell is built by paint, as the pieces of it that are explored
-- or not; any other block is one part, listed under the cell its middle is in (an older
-- bake has no bottoms or colours: a slab under each top, in its kind's tone)
local drawn = false
local cellBlocks = {} -- cell (0 off the grid) -> { { part, colour, grey } }
local wideBlocks = {} -- { minX, minZ, maxX, maxZ, bottom, top, colour, grey, parts = {}, key }
local function drawShapes()
	drawn = true
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
			table.insert(cellBlocks[cell], { block(blocks, shape[1], shape[2], shape[3], shape[4], shape[5], bottom, top, grey), colour, grey })
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
				table.insert(wide.parts, block(blocks, x, z, rect[3] - rect[1], rect[4] - rect[2], 0, wide[5], wide[6], colour))
			end
		end
	end
end
player:GetAttributeChangedSignal("Explored"):Connect(function()
	if drawn then
		paint()
	end
end)

-- markers: a square at a point in the world, its name shown while hovered; `filter` is
-- the legend entry that shows or hides it
local pins = {} -- every marker: { frame (the hover area), square, filter, world }
local shown = { Self = true, Quest = true, Service = true, Spawn = true }
local ink = Theme.Ink

local function makePin(colour, text, filter)
	local frame = make("Frame", {
		Parent = pinLayer,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(PIN_HOVER, PIN_HOVER),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
	})
	local square = make("Frame", {
		Parent = frame,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PIN, PIN),
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
	})
	make("UIStroke", { Parent = square, Color = Theme.Nav, Thickness = 1 })
	local name = label(frame, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.5, PIN / 2 + LABEL_GAP, 0.5, 0),
		Size = UDim2.fromOffset(0, LABEL_SIZE),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = string.upper(text),
		TextSize = LABEL_SIZE,
		TextStrokeColor3 = Theme.Nav,
		TextStrokeTransparency = 0.2,
		Visible = false,
	})
	-- the hovered marker's name shows, over the other markers and your arrow
	local function hover(on)
		name.Visible = on
		frame.ZIndex = on and 4 or 2
	end
	frame.MouseEnter:Connect(function()
		hover(true)
	end)
	frame.MouseLeave:Connect(function()
		hover(false)
	end)
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			hover(true)
		end
	end)
	frame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			hover(false)
		end
	end)
	local pin = { frame = frame, square = square, filter = filter, world = Vector3.zero }
	table.insert(pins, pin)
	return pin
end

local function dropPin(pin)
	table.remove(pins, table.find(pins, pin))
	pin.frame:Destroy()
end

local you = label(pinLayer, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(ARROW, ARROW),
	Text = "▲",
	TextSize = ARROW,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeColor3 = Theme.Nav,
	TextStrokeTransparency = 0,
	ZIndex = 3,
	Visible = false,
})

-- the grid's lines, for a box this big
local gridWidth, gridHeight = 0, 0
local function drawGrid(width, height)
	gridWidth, gridHeight = width, height
	grid:ClearAllChildren()
	for x = 0, width, GRID do
		make("Frame", {
			Parent = grid,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Theme.Ink,
			BackgroundTransparency = GRID_TRANSPARENCY,
			BorderSizePixel = 0,
		})
	end
	for y = 0, height, GRID do
		make("Frame", {
			Parent = grid,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Ink,
			BackgroundTransparency = GRID_TRANSPARENCY,
			BorderSizePixel = 0,
		})
	end
end

-- the view (MapRules' { x, z, yaw, pitch, zoom }; yaw stays 0, north up): set by resetView
local view

-- where each opening starts: looking straight down at you (at the whole place while you have no character)
local function resetView()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local at = root and root.Position or Vector3.zero
	view = MapRules.ClampView({
		x = at.X,
		z = at.Z,
		yaw = 0,
		pitch = MapRules.MaxPitch,
		zoom = root and OPEN_ZOOM or MapRules.MinZoom,
	}, bounds)
end
resetView()

-- the box's size and a point in it, in UI px
local function boxSize()
	local scale = UIScale.Get()
	return box.AbsoluteSize.X / scale, box.AbsoluteSize.Y / scale
end
local function boxPoint(input)
	local scale = UIScale.Get()
	return (input.Position.X - box.AbsolutePosition.X) / scale, (input.Position.Y - box.AbsolutePosition.Y) / scale
end

-- each frame while the tab shows: the camera (moved only when the view changes, so the
-- model isn't drawn again for nothing) and the markers over the model
local function render()
	local width, height = boxSize()
	if width <= 0 or height <= 0 then
		return
	end
	if width ~= gridWidth or height ~= gridHeight then
		drawGrid(width, height)
	end
	local fit = MapRules.FitDistance(bounds, width, height)
	local position, right, up, look = MapRules.Camera(view, fit)
	local frame = CFrame.fromMatrix(
		Vector3.new(position[1], position[2], position[3]),
		Vector3.new(right[1], right[2], right[3]),
		Vector3.new(up[1], up[2], up[3]),
		-Vector3.new(look[1], look[2], look[3])
	)
	if camera.CFrame ~= frame then
		camera.CFrame = frame
	end
	for _, pin in ipairs(pins) do
		local x, y = MapRules.Project(view, fit, width, height, pin.world.X, pin.world.Y, pin.world.Z)
		pin.frame.Visible = shown[pin.filter] and x ~= nil
		if x then
			pin.frame.Position = UDim2.fromOffset(x, y)
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local x, y, aheadX, aheadY
	if root then
		local at = root.Position
		local ahead = at + Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit * ARROW_REACH
		x, y = MapRules.Project(view, fit, width, height, at.X, at.Y, at.Z)
		aheadX, aheadY = MapRules.Project(view, fit, width, height, ahead.X, ahead.Y, ahead.Z)
	end
	you.Visible = shown.Self and x ~= nil and aheadX ~= nil
	if you.Visible then
		you.Position = UDim2.fromOffset(x, y)
		you.Rotation = MapRules.Heading(aheadX - x, aheadY - y)
	end
end

-- the wheel zooms about the ground under the cursor (its input's position is measured as
-- AbsolutePosition is, under Roblox's top bar; GetMouseLocation isn't)
box.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local width, height = boxSize()
		local px, py = boxPoint(input)
		local x, z = MapRules.GroundAt(view, MapRules.FitDistance(bounds, width, height), width, height, px, py)
		view = MapRules.ClampView(MapRules.ZoomAt(view, ZOOM_STEP ^ input.Position.Z, x or view.x, z or view.z), bounds)
	end
end)

-- dragging with the left button (or a finger) moves the map along the ground; with the
-- right button, up and down tilts it (by the cursor's movement, or the mouse's while
-- Roblox holds the cursor still)
local dragging, tilting, lastX, lastY
box.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton2 then
		dragging, tilting = input, kind == Enum.UserInputType.MouseButton2
		lastX, lastY = boxPoint(input)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging or not (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement) then
		return
	end
	local px, py = boxPoint(input)
	if tilting then
		local dy = py - lastY
		if px == lastX and dy == 0 then
			dy = input.Delta.Y / UIScale.Get()
		end
		view.pitch += dy * TILT_SPEED
	else
		local width, height = boxSize()
		local fit = MapRules.FitDistance(bounds, width, height)
		local fromX, fromZ = MapRules.GroundAt(view, fit, width, height, lastX, lastY)
		local toX, toZ = MapRules.GroundAt(view, fit, width, height, px, py)
		if fromX and toX then
			view.x, view.z = view.x + fromX - toX, view.z + fromZ - toZ
		end
	end
	lastX, lastY = px, py
	view = MapRules.ClampView(view, bounds)
end)
UserInputService.InputEnded:Connect(function(input)
	if dragging and (input == dragging or input.UserInputType == dragging.UserInputType) then
		dragging = nil
	end
end)

-- once the right button lets go, the tilt eases back to straight down
local function easeTilt(dt)
	if (dragging and tilting) or view.pitch >= MapRules.MaxPitch then
		return
	end
	local pitch = view.pitch + (MapRules.MaxPitch - view.pitch) * math.min(1, dt * TILT_RETURN)
	view.pitch = MapRules.MaxPitch - pitch < 0.1 and MapRules.MaxPitch or pitch
end

-- the NPCs, as MapServer lists them
local npcPins = {} -- Vector3Value -> pin
local function addMarker(value)
	if not value:IsA("Vector3Value") then
		return
	end
	local kind = PIN_COLOURS[value:GetAttribute("Kind")] and value:GetAttribute("Kind") or "Service"
	local pin = makePin(PIN_COLOURS[kind], value.Name, kind)
	npcPins[value] = pin
	pin.world = value.Value
	value.Changed:Connect(function()
		pin.world = value.Value
	end)
end
for _, value in ipairs(markerFolder:GetChildren()) do
	addMarker(value)
end
markerFolder.ChildAdded:Connect(addMarker)
markerFolder.ChildRemoved:Connect(function(value)
	if npcPins[value] then
		dropPin(npcPins[value])
		npcPins[value] = nil
	end
end)

-- your party mates (the same PartyId), found every REFRESH while the tab shows
local mates = {} -- player -> pin
local function refreshMates()
	local party = player:GetAttribute("PartyId")
	local seen = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and party ~= nil and other:GetAttribute("PartyId") == party then
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local position = otherRoot and otherRoot.Position or other:GetAttribute("MapPosition")
			if typeof(position) == "Vector3" then
				mates[other] = mates[other] or makePin(ink, other.DisplayName, "Self")
				mates[other].world = position
				seen[other] = true
			end
		end
	end
	for other, pin in pairs(mates) do
		if not seen[other] then
			dropPin(pin)
			mates[other] = nil
		end
	end
end

-- the legend: the four filters, then the height steps and the unexplored grey (just a key)
local filterEntries = {} -- filter -> { swatch, word }
local function paintFilter(filter)
	local entry = filterEntries[filter]
	entry.swatch.BackgroundTransparency = shown[filter] and 0 or 1
	entry.word.TextColor3 = shown[filter] and Theme.Muted or OFF
end
for i, filter in ipairs({
	{ "Self", "YOU / PARTY", Theme.Ink },
	{ "Quest", "BOUNTY", QUEST },
	{ "Service", "SHOPS & SERVICES", Theme.Ink },
	{ "Spawn", "SPAWN", Theme.Muted },
}) do
	local key = filter[1]
	local button, swatches, word = legendEntry(i, filter[2], { filter[3] }, true)
	make("UIStroke", { Parent = swatches[1], Color = filter[3], Thickness = 1 }) -- stays when off: a hollow square
	filterEntries[key] = { swatch = swatches[1], word = word }
	button.Activated:Connect(function()
		shown[key] = not shown[key]
		paintFilter(key)
	end)
end
local steps = {}
for i = 1, #STEP_LIGHT do
	steps[i] = KIND_COLOURS.build:Lerp(HIGH, STEP_LIGHT[i])
end
legendEntry(10, "LOW TO HIGH", steps, false)
legendEntry(11, "UNEXPLORED", { UNEXPLORED }, false)

Hub.OnAccent(function(_, accentInk)
	ink = accentInk
	you.TextColor3 = accentInk
	filterEntries.Self.swatch.BackgroundColor3 = accentInk
	filterEntries.Self.swatch:FindFirstChildOfClass("UIStroke").Color = accentInk
	for _, pin in pairs(mates) do
		pin.square.BackgroundColor3 = accentInk
	end
end)

-- while the tab shows: the camera and markers every frame, the party mates every REFRESH
local rendering
local running = false
Hub.OnShown("Map", function()
	if not drawn then
		drawShapes()
		paint()
	end
	resetView()
	if not rendering then
		rendering = RunService.RenderStepped:Connect(function(dt)
			if Hub.Current() ~= "Map" then
				rendering:Disconnect()
				rendering = nil
				return
			end
			easeTilt(dt)
			render()
		end)
	end
	if running then
		return
	end
	running = true
	while Hub.Current() == "Map" do
		refreshMates()
		task.wait(REFRESH)
	end
	running = false
end)
