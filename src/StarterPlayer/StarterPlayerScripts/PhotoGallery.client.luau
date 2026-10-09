-- Photoshop's photo Gallery: with a set that has a `gallery` (Photoshop)
-- equipped, its key (T) opens a small panel of saved photos of places, one
-- row per slot. SAVE photographs the spot you're standing on into that slot;
-- GO steps back into it, out of combat only, after the photo develops (any
-- hit meanwhile spoils it). PhotoshopServer does all the checking and keeps
-- the photos in the player's saved PhotoGallery attribute, which this reads
-- to show what each slot holds. Closes when the set is put away. While the
-- set is in hand, each saved spot also gets a waypoint only this player sees
-- (its photo number and how far away it is), drawn through walls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local galleryRemote = ReplicatedStorage:WaitForChild("PhotoGallery") -- made by PhotoshopServer
local player = Players.LocalPlayer

local PANEL_WIDTH = 300
local PADDING = 12
local ROW_HEIGHT = 30
local BUTTON_WIDTH = 52
local WAYPOINT_SIZE = 44 -- pixels, the square with the photo number
local WAYPOINT_WIDTH = 72 -- pixels, room for the distance under it
local WAYPOINT_HEIGHT = 4 -- studs above the saved spot
local WAYPOINT_UPDATE = 0.2 -- seconds between distance updates
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local BUTTON = Color3.fromRGB(38, 38, 50)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local PINK = SkillSetConfig.PhotoshopPink
local BLUE = SkillSetConfig.PhotoshopBlue

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
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

-- the set in hand, if it has a gallery
local function gallerySet()
	local _, setName = SkillSetConfig.Equipped(player.Character)
	local set = setName and SkillSetConfig.Sets[setName]
	return set and set.gallery and set or nil
end

-- the saved photos, as PhotoshopServer writes them: "x,y,z" or "" per slot
local function readSlots(count)
	local text = player:GetAttribute("PhotoGallery")
	local entries = typeof(text) == "string" and string.split(text, ";") or {}
	local slots = {}
	for slot = 1, count do
		local parts = string.split(entries[slot] or "", ",")
		local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
		slots[slot] = (x and y and z) and Vector3.new(x, y, z) or false
	end
	return slots
end

local gui = make("ScreenGui", {
	Name = "PhotoGallery",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = panel, Color = PINK, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

local order = 0
local function section(height)
	order += 1
	return make("Frame", { Parent = panel, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 })
end

local header = section(20)
local title = label(header, { Text = "GALLERY", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = PINK, Size = UDim2.new(1, -24, 1, 0) })
-- Modal frees the mouse while the gallery is open, even in shift lock
local closeButton = make("TextButton", {
	Parent = header,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(20, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
	Modal = true,
})

local function button(parent, text, color, x)
	local b = make("TextButton", {
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, x, 0, 0),
		Size = UDim2.new(0, BUTTON_WIDTH, 1, 0),
		BackgroundColor3 = BUTTON,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextSize = 12,
		TextColor3 = color,
	})
	make("UIStroke", { Parent = b, Color = color, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	return b
end

local rows = {} -- slot -> { place = TextLabel, go = TextButton }
local function buildRows(count)
	if #rows == count then
		return
	end
	for slot = #rows + 1, count do
		local row = section(ROW_HEIGHT)
		label(row, { Text = "PHOTO " .. slot, Font = Enum.Font.GothamBold, TextSize = 12, Size = UDim2.new(0, 64, 1, 0) })
		local place = label(row, {
			TextSize = 11,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(64, 0),
			Size = UDim2.new(1, -64 - 2 * BUTTON_WIDTH - 12, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local save = button(row, "SAVE", BLUE, -(BUTTON_WIDTH + 6))
		local go = button(row, "GO", PINK, 0)
		save.Activated:Connect(function()
			galleryRemote:FireServer("save", slot)
		end)
		go.Activated:Connect(function()
			galleryRemote:FireServer("travel", slot)
			gui.Enabled = false
		end)
		rows[slot] = { place = place, go = go }
	end
	label(section(14), {
		Text = "Save where you stand. GO works out of combat; a hit spoils the photo.",
		TextSize = 10,
		TextColor3 = MUTED,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	})
end

local function refresh()
	local set = gallerySet()
	if not set then
		return
	end
	title.Text = string.upper(set.gallery.name)
	buildRows(set.gallery.slots)
	local slots = readSlots(set.gallery.slots)
	for slot, row in ipairs(rows) do
		local point = slots[slot]
		row.place.Text = point and string.format("%d, %d, %d", math.round(point.X), math.round(point.Y), math.round(point.Z)) or "empty"
		row.go.TextTransparency = point and 0 or 0.6
	end
end
player:GetAttributeChangedSignal("PhotoGallery"):Connect(refresh)

-- the waypoints: a client-side Attachment at each saved spot, with a
-- BillboardGui on it; made the first time a slot holds a photo
local waypoints = {} -- slot -> { anchor = Attachment, board = BillboardGui, distance = TextLabel }
local function waypoint(slot)
	if waypoints[slot] then
		return waypoints[slot]
	end
	local anchor = make("Attachment", { Name = "PhotoWaypoint" .. slot, Parent = workspace.Terrain })
	local board = make("BillboardGui", {
		Name = "PhotoWaypoint" .. slot,
		Adornee = anchor,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
		LightInfluence = 0,
		Size = UDim2.fromOffset(WAYPOINT_WIDTH, WAYPOINT_SIZE + 18),
		StudsOffsetWorldSpace = Vector3.new(0, WAYPOINT_HEIGHT, 0),
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local square = make("Frame", {
		Parent = board,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(WAYPOINT_SIZE, WAYPOINT_SIZE),
		BackgroundColor3 = BACKGROUND,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	})
	make("UIStroke", { Parent = square, Color = PINK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	label(square, {
		Text = tostring(slot),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = PINK,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})
	local distance = label(board, {
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, WAYPOINT_SIZE + 2),
		Size = UDim2.new(1, 0, 0, 16),
	})
	waypoints[slot] = { anchor = anchor, board = board, distance = distance }
	return waypoints[slot]
end

local function updateDistances()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, each in pairs(waypoints) do
		if each.board.Enabled then
			local away = root and (each.anchor.WorldPosition - root.Position).Magnitude
			each.distance.Text = away and string.format("%d m", math.round(away)) or ""
		end
	end
end

-- shows a waypoint for every saved photo while the set is in hand, none otherwise
local waypointsShown = false
local function updateWaypoints()
	local set = gallerySet()
	waypointsShown = set ~= nil
	local slots = set and readSlots(set.gallery.slots) or {}
	for slot, point in ipairs(slots) do
		if point then
			local each = waypoint(slot)
			each.anchor.WorldPosition = point
			each.board.Enabled = true
		end
	end
	for slot, each in pairs(waypoints) do
		if not slots[slot] then
			each.board.Enabled = false
		end
	end
	updateDistances()
end
player:GetAttributeChangedSignal("PhotoGallery"):Connect(updateWaypoints)

closeButton.Activated:Connect(function()
	gui.Enabled = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or Keybinds.Capturing() then
		return
	end
	local set = gallerySet()
	-- the player's own gallery key (Keybinds; the set's gallery.key unless rebound)
	if set and input.KeyCode == Keybinds.Key("Gallery") then
		gui.Enabled = not gui.Enabled
		if gui.Enabled then
			refresh()
		end
	end
end)

-- put away: the gallery closes and the waypoints hide (taken out: they show)
local sinceDistances = 0
RunService.Heartbeat:Connect(function(dt)
	local inHand = gallerySet() ~= nil
	if gui.Enabled and not inHand then
		gui.Enabled = false
	end
	if inHand ~= waypointsShown then
		updateWaypoints()
	end
	sinceDistances += dt
	if waypointsShown and sinceDistances >= WAYPOINT_UPDATE then
		sinceDistances = 0
		updateDistances()
	end
end)
