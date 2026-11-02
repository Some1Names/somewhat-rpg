-- The loading screen: replaces Roblox's own the moment the player joins (only
-- ReplicatedFirst runs that early). Near-black paper with the hub's rail down the left,
-- [ SOMEWHAT ], the big condensed title with RPG on a chip, a mono status line and a
-- thin progress bar (Modern Warfare's look, as the hub). It waits for the game to
-- load, the map round the character to stream in and its meshes and textures to
-- preload (at least MIN_TIME, no more than ASSET_TIMEOUT on the map, or until SKIP
-- is pressed), then for the title menu (TitleMenu sets
-- Ready on its gui) so the bare world never flashes between the two, and fades.
-- Square everything. The colours are the hub's (HudConfig.HubTheme), written
-- out here because ReplicatedStorage may not have arrived yet.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PAPER = Color3.fromRGB(12, 13, 15)
local NAV = Color3.fromRGB(9, 9, 11)
local INK = Color3.fromRGB(236, 236, 238)
local MUTED = Color3.fromRGB(170, 172, 178)
local BAR_BACK = Color3.fromRGB(50, 50, 58)
local FONT = Enum.Font.Highway
local TITLE_FONT = Enum.Font.Oswald
local MONO_FONT = Enum.Font.RobotoMono
local RAIL_WIDTH = 52

local PAD = 32 + RAIL_WIDTH
local MIN_TIME = 1.5 -- s the screen shows at least, so it doesn't blink
local ASSET_TIMEOUT = 40 -- s after the game loads that the map and its assets may take
local CHARACTER_WAIT = 5 -- s it waits for the character, whose spawn is the area streamed in
local STREAM_TIMEOUT = 8 -- s the server may take streaming that area in
local BATCH_SIZE = 60 -- instances preloaded at a time (the bar moves per batch)
local TITLE_TIMEOUT = 10 -- s it waits for the title menu to be ready
local FADE_TIME = 0.6
local BAR_SPEED = 6 -- how fast the bar catches up with the real progress
-- the same scale as UIScale (LoadingScreen is in its SkipGui, since it shows before UIScale starts)
local REFERENCE_HEIGHT = 771
local MAX_SCALE = 3

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local started = os.clock()
-- the map is Persistent models (the place streams), sent after the join: the event says all have come
local persistentLoaded = not workspace.StreamingEnabled
local persistentConnection = workspace.PersistentLoaded:Connect(function()
	persistentLoaded = true
end)

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
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or INK
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "LoadingScreen",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})
-- one group, so the whole screen fades as one
local group = make("CanvasGroup", {
	Parent = gui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = PAPER,
	BorderSizePixel = 0,
	Active = true,
})
-- the layout is drawn in a virtual screen 1/scale of the real one, like the rest of the UI
local root = make("Frame", { Parent = group, BackgroundTransparency = 1 })
local uiScale = make("UIScale", { Parent = root })
local function rescale()
	local camera = workspace.CurrentCamera
	local value = camera and math.clamp(camera.ViewportSize.Y / REFERENCE_HEIGHT, 1, MAX_SCALE) or 1
	uiScale.Scale = value
	root.Size = UDim2.fromScale(1 / value, 1 / value)
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

-- the dark rail down the left with its thin light edge, as on the hub
local rail = make("Frame", { Parent = root, Size = UDim2.new(0, RAIL_WIDTH, 1, 0), BackgroundColor3 = NAV, BorderSizePixel = 0 })
make("Frame", {
	Parent = rail,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0, 1, 1, 0),
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.82,
	BorderSizePixel = 0,
})
label(root, {
	Text = "[ SOMEWHAT ]",
	TextSize = 14,
	Position = UDim2.fromOffset(PAD, PAD),
	Size = UDim2.fromOffset(200, 18),
})

-- bottom left: the title over the status line and the bar
local block = make("Frame", {
	Parent = root,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, PAD, 1, -PAD),
	Size = UDim2.new(1, -2 * PAD, 0, 150),
	BackgroundTransparency = 1,
})
label(block, {
	Text = "SOMEWHAT",
	Font = TITLE_FONT,
	TextSize = 64,
	Size = UDim2.new(1, 0, 0, 64),
})
local chip = label(block, {
	Text = " RPG ",
	Font = TITLE_FONT,
	TextSize = 22,
	TextColor3 = NAV,
	BackgroundColor3 = INK,
	BackgroundTransparency = 0,
	Position = UDim2.fromOffset(4, 70),
	Size = UDim2.fromOffset(0, 26),
	AutomaticSize = Enum.AutomaticSize.X,
})
local status = label(block, {
	Text = "LOADING WORLD",
	Font = MONO_FONT,
	TextSize = 12,
	TextColor3 = MUTED,
	Position = UDim2.fromOffset(0, 116),
	Size = UDim2.new(1, -60, 0, 16),
})
local percent = label(block, {
	Text = "0%",
	Font = MONO_FONT,
	TextSize = 12,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 116),
	Size = UDim2.fromOffset(60, 16),
})
local barBack = make("Frame", {
	Parent = block,
	Position = UDim2.fromOffset(0, 140),
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = BAR_BACK,
	BorderSizePixel = 0,
})
local barFill = make("Frame", {
	Parent = barBack,
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = INK,
	BorderSizePixel = 0,
})

-- SKIP, bottom right once the game has loaded: stops waiting on the map and its assets (they
-- go on loading behind the title)
local skipped = false
local skip = make("TextButton", {
	Parent = root,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -PAD, 1, -PAD),
	Size = UDim2.fromOffset(96, 30),
	BackgroundColor3 = NAV,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Font = MONO_FONT,
	Text = "SKIP",
	TextSize = 12,
	TextColor3 = MUTED,
	Visible = false,
})
local skipStroke = make("UIStroke", { Parent = skip, Color = INK, Transparency = 0.82, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
skip.MouseEnter:Connect(function()
	skip.TextColor3 = INK
	skipStroke.Transparency = 0.3
end)
skip.MouseLeave:Connect(function()
	skip.TextColor3 = MUTED
	skipStroke.Transparency = 0.82
end)
skip.Activated:Connect(function()
	skipped = true
	skip.Visible = false
end)

-- progress: until the game has loaded the bar creeps up to 30%; streaming the map round the
-- character takes it to 45%; then the rest follows the map's meshes and textures, a batch at a time
local target, shown = 0, 0
local loadedAt
local phase = "world" -- world, map, assets, done
local batchesDone, batchCount = 0, 1

local stepConnection = RunService.RenderStepped:Connect(function(dt)
	if phase == "done" then
		target = 1
		status.Text = "READY"
	elseif phase == "world" then
		target = math.min(0.3, (os.clock() - started) / 10 * 0.3)
		status.Text = "LOADING WORLD"
	elseif phase == "map" then
		target = math.max(target, math.min(0.45, 0.3 + (os.clock() - loadedAt) / 10 * 0.15))
		status.Text = "LOADING MAP"
	else
		target = math.max(target, 0.45 + 0.55 * batchesDone / batchCount)
		status.Text = string.format("LOADING ASSETS · %d / %d", batchesDone, batchCount)
	end
	shown += (target - shown) * math.min(1, dt * BAR_SPEED)
	barFill.Size = UDim2.fromScale(shown, 1)
	percent.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
end)

-- what the map draws with: meshes, textures and the sky, so nothing pops in once the screen lifts
local function mapAssets()
	local list = {}
	for _, item in ipairs(workspace:GetDescendants()) do
		if item:IsA("MeshPart") or item:IsA("SpecialMesh") or item:IsA("Decal") or item:IsA("SurfaceAppearance") or item:IsA("UnionOperation") then
			table.insert(list, item)
		end
	end
	for _, item in ipairs(game:GetService("Lighting"):GetDescendants()) do
		if item:IsA("Sky") then
			table.insert(list, item)
		end
	end
	return list
end

-- the place streams: wait for the Persistent map, and ask for the area round the character (its
-- spawn, the NPCs there) before the assets, so what the title and the entry shot show is all there
local function loadMap()
	while not persistentLoaded and os.clock() - loadedAt < ASSET_TIMEOUT and not skipped do
		task.wait(0.1)
	end
	persistentConnection:Disconnect()
	local waitUntil = os.clock() + CHARACTER_WAIT
	while not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) and os.clock() < waitUntil and not skipped do
		task.wait(0.1)
	end
	local character = player.Character
	local characterRoot = character and character:FindFirstChild("HumanoidRootPart")
	if characterRoot and workspace.StreamingEnabled then
		pcall(player.RequestStreamAroundAsync, player, characterRoot.Position, STREAM_TIMEOUT)
	end
	if phase ~= "done" then
		phase = "assets"
	end
	local assets = mapAssets()
	batchCount = math.max(1, math.ceil(#assets / BATCH_SIZE))
	for first = 1, #assets, BATCH_SIZE do
		pcall(ContentProvider.PreloadAsync, ContentProvider, table.move(assets, first, math.min(first + BATCH_SIZE - 1, #assets), 1, {}))
		batchesDone += 1
	end
	batchesDone = batchCount
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end
loadedAt = os.clock()
phase = "map"
skip.Visible = true
local mapLoaded = false
task.spawn(function()
	loadMap()
	mapLoaded = true
end)
while not mapLoaded and not skipped and os.clock() - loadedAt < ASSET_TIMEOUT do
	task.wait(0.1)
end
phase = "done"
skip.Visible = false
task.wait(skipped and 0.1 or math.max(0.3, MIN_TIME - (os.clock() - started)))

-- the title menu builds under this screen; fade once it's ready (or it never comes)
local title = playerGui:WaitForChild("TitleMenu", TITLE_TIMEOUT)
local deadline = os.clock() + TITLE_TIMEOUT
while title and title.Parent and not title:GetAttribute("Ready") and os.clock() < deadline do
	task.wait(0.1)
end

local fade = TweenService:Create(group, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 })
fade:Play()
fade.Completed:Wait()
stepConnection:Disconnect()
gui:Destroy()
