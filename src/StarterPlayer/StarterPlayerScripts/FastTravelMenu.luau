-- The travel map: FastTravelMenu.Open(npc) fills the screen with a map of the travel points (the
-- Spawn Keeper's "travel" reply opens it, SpawnKeeperDialogue; `npc` is whom they're talking to).
-- It has the title menu's and the shops' look: black bars close in along the top and the bottom
-- (E LEAVE on the left of the bottom one, when you can travel again on the right) and under the
-- top bar, over a dark fading down, the NPC's line with the accent before it, FAST TRAVEL big and
-- where you are on a cyan chip. Behind it all is the 3D map (MapModel, the hub map's blocks),
-- tilted and framed so every point shows under the header. Each point is a square marker with its
-- place name: the one you're at says YOU ARE HERE, a locked one is grey (FastTravelConfig.IsUnlocked;
-- none are yet), and any other lights up under the cursor and travels when pressed: the screen
-- fades to black, the server checks the trip, streams the place in and moves you (FastTravelServer),
-- and the fade lifts on a short arrival shot of the new place (ArrivalShot); a refusal shows as a line under the top bar. The points come
-- from the server, since far keepers aren't streamed in. It's the one open menu (Menus); it closes
-- on E, Esc or LEAVE, when you walk away or die, and when you get into PvP combat (it won't open
-- in it). Square everything.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ArrivalShot = require(script.Parent:WaitForChild("ArrivalShot"))
local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local FastTravelConfig = require(ReplicatedStorage:WaitForChild("FastTravelConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local MapLayout = require(ReplicatedStorage:WaitForChild("MapLayout"))
local MapRules = require(ReplicatedStorage:WaitForChild("MapRules"))
local MapModel = require(script.Parent:WaitForChild("MapModel"))
local MenuFooter = require(script.Parent:WaitForChild("MenuFooter"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local remote = ReplicatedStorage:WaitForChild("FastTravel") -- made by FastTravelServer
local player = Players.LocalPlayer

local FastTravelMenu = {}

local Style = HudConfig.Style
local Theme = HudConfig.HubTheme
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local ACCENT = Color3.fromRGB(60, 224, 230) -- the spawns' cyan, as on the hub map
local LOCKED = Color3.fromRGB(110, 110, 110)
local PAD = 64 -- the screen's left edge to the header (as on the title menu and the shops)
local HEADER_WIDTH = 460
local HEADER = 130 -- the header's height: the NPC's line, FAST TRAVEL big, the chip
local HEADER_GAP = 26 -- between the top bar and the header
local BOTTOM_BAR = 44 -- the black bar along the bottom; the top one is as tall as Roblox's band
local ROBLOX_BAR_FALLBACK = 58 -- Roblox's band across the top, while GetGuiInset still says 0
local SHADE = 240 -- px down from the top where the dark under the header has faded out
local ROOM_MARGIN = 30 -- px the points keep from the header and the bottom bar
local NAME_ROOM = 170 -- px kept right of the points for their names
local PITCH = 62 -- degrees the map is tilted (90 looks straight down)
local START_ZOOM = 6 -- the framing starts this close (the town fills the screen)...
local FRAME_STEP = 1.12 -- ...and zooms out by this much a try until every point fits
local PIN = 12 -- px, a marker's square
local PIN_HOVER = 16 -- px, the square under the cursor
local PIN_LINE = 16 -- px from a marker's top to the middle of its square (and its name)
local MARKER_HEIGHT = 40 -- px: the name level with the square, the status line under it
local NAME_SIZE = 16
local STATUS_WIDTH = 90
local OPEN_TIME = 0.45 -- the bars closing in, the header sliding in, the map fading up
local FADE_TIME = 0.35 -- the fade to black, and back, for a trip
local LEAVE_DELAY = 0.4 -- seconds after it opens before E leaves
-- the arrival shot (ArrivalShot) starts high and wide in front of you: radians round from behind, studs out and up
local ARRIVAL_ANGLE = math.rad(120)
local ARRIVAL_OUT = 40
local ARRIVAL_HIGH = 22

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
	props.Font = props.Font or Style.LabelFont
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function tween(instance, time, props)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tweenObject:Play()
	return tweenObject
end

local playerGui = player:WaitForChild("PlayerGui")
local gui = make("ScreenGui", {
	Name = "FastTravel",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 30,
	Enabled = false,
	Parent = playerGui,
})
-- the fade to black for a trip and the line that says why one can't go: over the map, and still
-- up while it closes
local overlay = make("ScreenGui", {
	Name = "FastTravelOverlay",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 31,
	Parent = playerGui,
})
local cover = make("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0 })
local toast = MenuFooter.Toast(overlay)

-- back to front: the paper, the 3D map, the markers, the dark under the top bar, the header and the
-- bars. The frame over the whole screen is Active, so a click anywhere is the menu's and never
-- punches or shoots.
local backdrop = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Paper, BorderSizePixel = 0, Active = true })
local viewport = make("ViewportFrame", { Parent = backdrop, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 })
MapModel.Light(viewport)
local camera = make("Camera", { Parent = viewport, FieldOfView = MapRules.Fov })
viewport.CurrentCamera = camera
local pinLayer = make("Frame", { Parent = backdrop, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 })
local shade = make("Frame", { Parent = backdrop, Size = UDim2.new(1, 0, 0, SHADE), BackgroundColor3 = Theme.Nav, BorderSizePixel = 0, ZIndex = 3 })
make("UIGradient", {
	Parent = shade,
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.6, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	}),
})

-- the header: the NPC's line with the accent before it, FAST TRAVEL big, and where you are on an
-- accent chip with a rule running on
local header = make("Frame", { Parent = backdrop, BackgroundTransparency = 1, Size = UDim2.fromOffset(HEADER_WIDTH, HEADER), ZIndex = 4 })
make("Frame", { Parent = header, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = ACCENT, BorderSizePixel = 0 })
local kicker = label(header, { Text = "", Font = Style.MonoFont, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -34, 0, 14) })
local title = label(header, { Text = "FAST TRAVEL", Font = Style.TitleFont, TextScaled = true, Position = UDim2.fromOffset(-2, 18), Size = UDim2.new(1, 0, 0, 72) })
make("UITextSizeConstraint", { Parent = title, MaxTextSize = 72 })
local chip = make("TextLabel", {
	Parent = header,
	Font = Style.TitleFont,
	TextSize = 20,
	BackgroundColor3 = ACCENT,
	TextColor3 = Style.Glass, -- dark words on the bright cyan
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(1, 102),
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
})
local chipRule = make("Frame", { Parent = header, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = MUTED, BackgroundTransparency = 0.6, BorderSizePixel = 0 })

local topBar = make("Frame", { Parent = backdrop, Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 })
local bottomBar = make("Frame", {
	Parent = backdrop,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 5,
})
for _, edge in ipairs({ { topBar, 1 }, { bottomBar, 0 } }) do
	make("Frame", {
		Parent = edge[1],
		AnchorPoint = Vector2.new(0, edge[2]),
		Position = UDim2.fromScale(0, edge[2]),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Edge,
		BackgroundTransparency = Theme.EdgeTransparency,
		BorderSizePixel = 0,
	})
end
-- when you can travel again, on the right of the bottom bar (E LEAVE is on its left)
local status = label(bottomBar, {
	Text = "",
	Font = Style.MonoFont,
	TextSize = 12,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -PAD, 0.5, 0),
	Size = UDim2.new(0.5, -PAD, 0, 16),
})

local isOpen = false
local travelling = false
local openAt -- the NPC it was opened at, so walking away closes it
local openedAt = 0 -- os.clock() when it opened
local readyAt = 0 -- os.clock() when the next trip is off cooldown
local points = {} -- the server's: { id, name, position, here, unlocked }
local here -- the point you're at
local markers = {} -- { button, point }
local band = ROBLOX_BAR_FALLBACK

-- seconds until you're out of combat with other players (CombatRules.PvPAttribute on your character),
-- nil if you are
local function combatLeft()
	local character = player.Character
	return CombatRules.SecondsLeft(character and character:GetAttribute(CombatRules.PvPAttribute), workspace:GetServerTimeNow())
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	openAt = nil
	gui.Enabled = false
	ProximityPromptService.Enabled = true
	UiSfx.Play("shopLeave")
	Menus.Close("FastTravel")
end
-- E LEAVE, on the left of the bottom bar
MenuFooter.Leave(gui, close, UDim2.new(0, PAD, 1, -(BOTTOM_BAR - HudConfig.HintsHeight) / 2))

-- a trip to `point`: refused here when the answer is plain, else the screen fades to black while
-- the server checks it and moves you; arrived, the map closes and the fade lifts on the new place
local function travel(point)
	if travelling or not isOpen then
		return
	end
	local refusal = FastTravelConfig.Refusal({
		from = here and here.id,
		to = point.id,
		unlocked = point.unlocked,
		combatLeft = combatLeft(),
		cooldownLeft = readyAt > os.clock() and readyAt - os.clock() or nil,
	})
	if refusal then
		UiSfx.Play("denied")
		toast(refusal, true)
		return
	end
	travelling = true
	toast("")
	UiSfx.Play("menuSelect")
	tween(cover, FADE_TIME, { BackgroundTransparency = 0 })
	task.wait(FADE_TIME)
	local ok, answer = pcall(remote.InvokeServer, remote, "Travel", point.id)
	travelling = false
	if ok and type(answer) == "table" and answer.ok then
		close()
		-- arrived: the camera comes down from high over the place to behind you, its name in the bars
		local bars = ArrivalShot.Play(overlay, cover, {
			kicker = "ARRIVED AT",
			name = point.name,
			accent = ACCENT,
			angle = ARRIVAL_ANGLE,
			out = ARRIVAL_OUT,
			high = ARRIVAL_HIGH,
		})
		if bars then
			ArrivalShot.Clear(bars)
			return
		end
	else
		UiSfx.Play("denied")
		toast(ok and type(answer) == "table" and answer.reason or "Travel failed", true)
	end
	tween(cover, FADE_TIME, { BackgroundTransparency = 1 })
end

local function clearMarkers()
	for _, marker in ipairs(markers) do
		marker.button:Destroy()
	end
	table.clear(markers)
end

-- a point's marker: its square on the point, the place's name level with it and a status line under
-- it (YOU ARE HERE, LOCKED, or TRAVEL while the cursor is over one you can go to)
local function addMarker(point)
	local name = string.upper(point.name)
	local nameWidth = TextService:GetTextSize(name, NAME_SIZE, Style.TitleFont, Vector2.new(1000, 100)).X
	local button = make("TextButton", {
		Parent = pinLayer,
		Size = UDim2.fromOffset(PIN_HOVER + 8 + math.max(nameWidth, STATUS_WIDTH), MARKER_HEIGHT),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = point.here and 3 or 2,
	})
	local square = make("Frame", {
		Parent = button,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(PIN_HOVER / 2, PIN_LINE),
		Size = UDim2.fromOffset(PIN, PIN),
		BackgroundColor3 = point.here and TEXT or point.unlocked and ACCENT or LOCKED,
		BorderSizePixel = 0,
	})
	make("UIStroke", { Parent = square, Color = point.here and ACCENT or Theme.Nav, Thickness = point.here and 2 or 1 })
	local nameLabel = label(button, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(PIN_HOVER + 8, PIN_LINE),
		Size = UDim2.fromOffset(nameWidth, NAME_SIZE + 2),
		Text = name,
		Font = Style.TitleFont,
		TextSize = NAME_SIZE,
		TextColor3 = point.unlocked and TEXT or MUTED,
		TextStrokeColor3 = Theme.Nav,
		TextStrokeTransparency = 0.2,
	})
	local statusLabel = label(button, {
		Position = UDim2.fromOffset(PIN_HOVER + 9, PIN_LINE + 10),
		Size = UDim2.fromOffset(STATUS_WIDTH, 12),
		Text = point.here and "YOU ARE HERE" or not point.unlocked and "LOCKED" or "",
		Font = Style.MonoFont,
		TextSize = 10,
		TextColor3 = point.here and ACCENT or MUTED,
		TextStrokeColor3 = Theme.Nav,
		TextStrokeTransparency = 0.4,
	})
	if not point.here and point.unlocked then
		local function light(on)
			square.Size = on and UDim2.fromOffset(PIN_HOVER, PIN_HOVER) or UDim2.fromOffset(PIN, PIN)
			nameLabel.TextColor3 = on and ACCENT or TEXT
			statusLabel.Text = on and "TRAVEL" or ""
			button.ZIndex = on and 4 or 2
		end
		button.MouseEnter:Connect(function()
			light(true)
		end)
		button.MouseLeave:Connect(function()
			light(false)
		end)
	end
	button.Activated:Connect(function()
		travel(point)
	end)
	table.insert(markers, { button = button, point = point })
end

-- the screen in UI px (the gui covers Roblox's band too, so it's the whole viewport)
local function screenSize()
	local view = workspace.CurrentCamera
	local size = view and view.ViewportSize or Vector2.new(1371, 771)
	return size.X / UIScale.Get(), size.Y / UIScale.Get()
end

-- the map's view: tilted, with the points' middle in the middle of `room` ({ left, top, right,
-- bottom } px), zoomed out from START_ZOOM a step at a time until every point is in the room
local function frameView(width, height, room)
	local fit = MapRules.FitDistance(MapLayout.Bounds, width, height)
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, point in ipairs(points) do
		minX, maxX = math.min(minX, point.position.X), math.max(maxX, point.position.X)
		minZ, maxZ = math.min(minZ, point.position.Z), math.max(maxZ, point.position.Z)
	end
	local midX, midZ = (minX + maxX) / 2, (minZ + maxZ) / 2
	local view = { x = midX, z = midZ, yaw = 0, pitch = PITCH, zoom = START_ZOOM }
	for _ = 1, 40 do
		-- moved so the ground under the room's middle is the points' middle
		local groundX, groundZ = MapRules.GroundAt(view, fit, width, height, (room[1] + room[3]) / 2, (room[2] + room[4]) / 2)
		if groundX then
			view.x, view.z = view.x + midX - groundX, view.z + midZ - groundZ
		end
		local inside = true
		for _, point in ipairs(points) do
			local x, y = MapRules.Project(view, fit, width, height, point.position.X, point.position.Y, point.position.Z)
			if not x or x < room[1] or x > room[3] or y < room[2] or y > room[4] then
				inside = false
				break
			end
		end
		if inside or view.zoom <= MapRules.MinZoom then
			break
		end
		view.zoom = math.max(view.zoom / FRAME_STEP, MapRules.MinZoom)
	end
	return view, fit
end

-- the bars and the header for this screen, the map's camera framed on the points and each marker
-- on its point; the top bar is as tall as Roblox's band
local function place()
	band = GuiService:GetGuiInset().Y / UIScale.Get() -- Roblox's band is in real pixels
	band = band > 0 and band or ROBLOX_BAR_FALLBACK / UIScale.Get()
	if topBar.Size.Y.Offset > 0 then
		topBar.Size = UDim2.new(1, 0, 0, band)
	end
	header.Position = UDim2.fromOffset(PAD, band + HEADER_GAP)
	if not isOpen or #points == 0 then
		return
	end
	local width, height = screenSize()
	local room = { PAD, band + HEADER_GAP + HEADER + ROOM_MARGIN, width - PAD - NAME_ROOM, height - BOTTOM_BAR - ROOM_MARGIN }
	local view, fit = frameView(width, height, room)
	local position, right, up, look = MapRules.Camera(view, fit)
	camera.CFrame = CFrame.fromMatrix(
		Vector3.new(position[1], position[2], position[3]),
		Vector3.new(right[1], right[2], right[3]),
		Vector3.new(up[1], up[2], up[3]),
		-Vector3.new(look[1], look[2], look[3])
	)
	for _, marker in ipairs(markers) do
		local at = marker.point.position
		local x, y = MapRules.Project(view, fit, width, height, at.X, at.Y, at.Z)
		marker.button.Visible = x ~= nil
		if x then
			marker.button.Position = UDim2.fromOffset(x - PIN_HOVER / 2, y - PIN_LINE)
		end
	end
end
UIScale.OnChange(place)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
end

-- the bars close in, the header slides in from the left and the map fades up
local function intro()
	topBar.Size = UDim2.fromScale(1, 0)
	bottomBar.Size = UDim2.fromScale(1, 0)
	tween(topBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, band) })
	tween(bottomBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, BOTTOM_BAR) })
	local at = UDim2.fromOffset(PAD, band + HEADER_GAP)
	header.Position = at - UDim2.fromOffset(PAD + HEADER_WIDTH, 0)
	tween(header, OPEN_TIME, { Position = at })
	viewport.ImageTransparency = 1
	tween(viewport, OPEN_TIME, { ImageTransparency = 0 })
end

-- opens the map at `npc` (whom the player is talking to). It asks the server for the points first,
-- so it yields a moment; it doesn't open in PvP combat or away from a keeper (the reason shows)
function FastTravelMenu.Open(npc)
	if isOpen or travelling then
		return
	end
	local left = combatLeft()
	if left then
		UiSfx.Play("denied")
		toast(string.format("You can't travel while in combat (%ds)", math.ceil(left)), true)
		return
	end
	local ok, answer = pcall(remote.InvokeServer, remote, "Points")
	if not ok or type(answer) ~= "table" or not answer.ok then
		UiSfx.Play("denied")
		toast(ok and type(answer) == "table" and answer.reason or "Travel failed", true)
		return
	end
	points, here = answer.points, nil
	clearMarkers()
	for _, point in ipairs(points) do
		if point.here then
			here = point
		end
		addMarker(point)
	end
	readyAt = os.clock() + (answer.cooldown or 0)
	kicker.Text = npc and string.upper(npc:GetAttribute("ShopTitle") or npc.Name) or ""
	chip.Visible = here ~= nil
	chip.Text = here and (" " .. string.upper(here.name) .. " ") or ""
	local ruleAt = here and TextService:GetTextSize(chip.Text, chip.TextSize, chip.Font, Vector2.new(1000, 100)).X + 14 or 0
	chipRule.Position = UDim2.fromOffset(ruleAt, 114)
	chipRule.Size = UDim2.new(1, -ruleAt, 0, 1)
	openAt = npc
	openedAt = os.clock()
	isOpen = true
	Menus.Open("FastTravel", close)
	ProximityPromptService.Enabled = false -- after Menus.Open: the talk it closes turns them back on
	MapModel.Show(viewport)
	gui.Enabled = true
	toast("")
	place()
	intro()
	UiSfx.Play("shopEnter")
end

-- walking away, dying or PvP combat closes it; the bottom bar counts down the cooldown
RunService.Heartbeat:Connect(function()
	if not isOpen or travelling then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		close()
		return
	end
	if openAt and (not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > FastTravelConfig.Range) then
		close()
		return
	end
	if combatLeft() then
		close()
		UiSfx.Play("denied")
		toast("You can't travel while in combat", true)
		return
	end
	local cooldown = readyAt - os.clock()
	status.Text = cooldown > 0 and string.format("TRAVEL AGAIN IN %dS", math.ceil(cooldown)) or "PICK A KEEPER TO TRAVEL"
end)

-- E (a moment after it opened) or Esc leaves
UserInputService.InputBegan:Connect(function(input, processed)
	if not isOpen or travelling or processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or (input.KeyCode == Enum.KeyCode.E and os.clock() - openedAt > LEAVE_DELAY) then
		close()
	end
end)

return FastTravelMenu
