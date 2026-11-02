-- The title menu: shown once as the player joins, built under the loading
-- screen (LoadingScreen fades once this gui has Ready). Black bars close in along the
-- top and bottom (the bottom one says who's playing and where the menu screen is); down the
-- left, over a dark fading off the edge, the version, SOMEWHAT big with RPG on an accent
-- chip, and PLAY / UPDATES / HANDBOOK / SETTINGS sliding in one after another (a hovered one
-- says what it opens). Behind it the menu screen: a part in
-- workspace.MenuCameras, the one named by the MenuScreen attribute of the SpawnLocation the
-- character stands at, else the one MenuCameras' Default attribute names. The camera looks out
-- of the part's front face and moves slowly in along it and back out (the part's Drift and
-- Period attributes override SCREEN_DRIFT and SCREEN_PERIOD); with no part it circles the
-- spawn. The place streams, so MenuCameras should be a Model with ModelStreamingMode
-- Persistent; the screen's area is streamed in before the loading screen lifts.
-- While it's up the title is the open menu to Menus (the character can't move
-- or fight), the rest of the HUD is hidden the way the hub hides it, and "press
-- E" prompts are off, and the hub's tab keys do nothing (Hub checks for this
-- gui). SETTINGS opens the Settings menu, UPDATES and HANDBOOK the hub's page of that name alone
-- (Hub.OpenOnly): opening them closes the column, and it comes back when they
-- close. PLAY opens the slot screen (SlotMenu); once a character is chosen or made it
-- fades through black into a short entry shot (black bars, the codename, the camera swinging
-- from the character's face round behind them), then hands the camera back and shows the HUD. Square everything; the accent is the hub's.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local UpdateNotes = require(ReplicatedStorage:WaitForChild("UpdateNotes"))
local ArrivalShot = require(script.Parent:WaitForChild("ArrivalShot"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local SlotMenu = require(script.Parent:WaitForChild("SlotMenu"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme

local PAD = 64 -- the screen's left edge to the title and the buttons (and the bottom bar's lines)
local ROBLOX_BAR_FALLBACK = 58 -- Roblox's band across the top, while GetGuiInset still says 0
local BOTTOM_BAR = 44 -- the black bar along the bottom; the top one is as tall as Roblox's band
local SHADE_SHARE = 0.62 -- how far across the screen the dark fades off the left edge
local STACK_WIDTH = 420 -- the title and the buttons
local STACK_HEIGHT = 424
local PLAY_HEIGHT = 66
local BUTTON_HEIGHT = 42
local BUTTON_GAP = 6

local OPEN_TIME = 0.5 -- the bars closing in, the title and the buttons sliding in
local STAGGER = 0.06 -- s between one thing sliding in and the next
local HOVER_TIME = 0.15
local HOVER_NUDGE = 10 -- px a button's text moves right on hover
local PLAY_FADE = 0.35 -- to black on PLAY
local REVEAL_TIME = 0.6 -- from black onto the character
local ENTRY_STREAM_TIMEOUT = 3 -- s the black may hold while the character's area streams in
local SCREEN_DRIFT = 10 -- studs the camera moves in along a menu screen before coming back out
local SCREEN_PERIOD = 24 -- s for one move in and back out
local CHARACTER_WAIT = 5 -- s the title waits for the character (under the loading screen): its spawn picks the screen
local ORBIT_TIME = 90 -- s for one turn round the spawn, with no shots
local ORBIT_RADIUS = 45
local ORBIT_HEIGHT = 20

-- guis the title leaves alone: the menus it opens, the top bar's pill (it sits in Roblox's band), the loading screen
local LEFT_SHOWING = { Hub = true, Settings = true, MenuButton = true, LoadingScreen = true, SlotMenu = true, Customizer = true }

local function tween(instance, time, props)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tweenObject:Play()
	return tweenObject
end

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
	props.Font = props.Font or Theme.LabelFont
	props.TextColor3 = props.TextColor3 or Theme.NavText
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "TitleMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 50, -- over the whole HUD, under the loading screen
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- back to front: the title's contents, all in `column` (the dark fading off the left edge, the
-- black bars, the title and the buttons), then the black of PLAY
local column = make("Frame", {
	Name = "Column",
	Parent = gui,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Active = true,
})
local shade = make("Frame", {
	Parent = column,
	Size = UDim2.fromScale(SHADE_SHARE, 1),
	BackgroundColor3 = Theme.Nav,
	BorderSizePixel = 0,
	ZIndex = 2,
})
make("UIGradient", {
	Parent = shade,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	}),
})
-- the black bars, along the top (Roblox's band sits in it) and the bottom, each with Modern
-- Warfare's thin light line on its inner edge
local topBar = make("Frame", { Parent = column, Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4 })
local bottomBar = make("Frame", {
	Parent = column,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 4,
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
		ZIndex = 4,
	})
end
local blackout = make("Frame", {
	Parent = gui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 10,
})

-- in the bottom bar: who's playing on the left, where the menu screen is on the right
label(bottomBar, {
	Text = string.format('PLAYER  <font color="#%s">@%s</font>', Theme.NavText:ToHex(), player.Name),
	RichText = true,
	Font = Theme.MonoFont,
	TextSize = 12,
	TextColor3 = Theme.Muted,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, PAD, 0.5, 0),
	Size = UDim2.new(0.5, -PAD, 0, 16),
	ZIndex = 5,
})
local placeLine = label(bottomBar, {
	Text = "",
	RichText = true,
	Font = Theme.MonoFont,
	TextSize = 12,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -PAD, 0.5, 0),
	Size = UDim2.new(0.5, -PAD, 0, 16),
	ZIndex = 5,
})
-- names the menu screen showing, in the bottom bar: its Caption attribute, else its name in words
local function showPlace(screenPart)
	local caption = screenPart and (screenPart:GetAttribute("Caption") or screenPart.Name:gsub("(%l)(%u)", "%1 %2"))
	placeLine.Text = caption and string.format('LOCATION  <font color="#%s">%s</font>', Theme.NavText:ToHex(), string.upper(tostring(caption))) or ""
end

-- the title and the buttons, down the left between the bars, shrunk to fit a short screen
local stack = make("Frame", {
	Parent = column,
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(STACK_WIDTH, STACK_HEIGHT),
	BackgroundTransparency = 1,
	ZIndex = 5,
})
local fit = make("UIScale", { Parent = stack })
local slideIns = {} -- what slides in from the left as the title opens, in order
local accented = {} -- frames in the accent's colour

-- the title: the version over it, SOMEWHAT big, then RPG on the accent with a rule running on
local logo = make("Frame", { Parent = stack, Size = UDim2.fromOffset(STACK_WIDTH, 190), BackgroundTransparency = 1, ZIndex = 5 })
table.insert(slideIns, logo)
table.insert(accented, make("Frame", { Parent = logo, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(24, 2), BorderSizePixel = 0, ZIndex = 5 }))
label(logo, {
	Text = "VERSION " .. string.upper(UpdateNotes.Version),
	Font = Theme.MonoFont,
	TextSize = 12,
	TextColor3 = Theme.Muted,
	Position = UDim2.fromOffset(34, 0),
	Size = UDim2.new(1, -34, 0, 14),
	ZIndex = 5,
})
local title = label(logo, {
	Text = "SOMEWHAT",
	Font = Theme.TitleFont,
	TextSize = 100,
	Position = UDim2.fromOffset(-3, 20),
	Size = UDim2.fromOffset(330, 100),
	ZIndex = 5,
})
make("UIScale", { Parent = title, Scale = 1.3 }) -- text stops growing at 100 pixels; this takes it past
local chip = label(logo, {
	Text = " RPG ",
	Font = Theme.TitleFont,
	TextSize = 22,
	BackgroundTransparency = 0,
	Position = UDim2.fromOffset(2, 158),
	Size = UDim2.fromOffset(0, 26),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 5,
})
make("Frame", {
	Parent = logo,
	Position = UDim2.fromOffset(64, 171),
	Size = UDim2.new(1, -64, 0, 1),
	BackgroundColor3 = Theme.Muted,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	ZIndex = 5,
})

local buttons = make("Frame", {
	Parent = stack,
	Position = UDim2.fromOffset(0, 212),
	Size = UDim2.new(1, 0, 0, PLAY_HEIGHT + 3 * (BUTTON_HEIGHT + BUTTON_GAP)),
	BackgroundTransparency = 1,
	ZIndex = 5,
})
make("UIListLayout", { Parent = buttons, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, BUTTON_GAP) })

-- a button: a bar down its left edge (half up on PLAY), its number and its name. On hover the
-- accent fades out behind it (Modern Warfare's), the bar runs its height, the number takes the
-- accent, the name nudges right and a line says what it opens.
local ink = Hub.InkAccent()
local function button(order, text, note, primary, onClick)
	local rest = primary and 0.55 or 0 -- the bar's height unhovered, as a share of the button's
	local holder = make("TextButton", {
		Parent = buttons,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, primary and PLAY_HEIGHT or BUTTON_HEIGHT),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	})
	local highlight = make("Frame", {
		Parent = holder,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ink,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	})
	make("UIGradient", {
		Parent = highlight,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	})
	local bar = make("Frame", {
		Parent = holder,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 3, rest, 0),
		BackgroundColor3 = ink,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
	table.insert(accented, highlight)
	table.insert(accented, bar)
	local content = make("Frame", { Parent = holder, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6 })
	table.insert(slideIns, content)
	local number = label(content, {
		Text = string.format("%02d", order),
		Font = Theme.MonoFont,
		TextSize = 12,
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0, 26, 1, 0),
		ZIndex = 6,
	})
	local size = primary and 46 or 24
	label(content, {
		Text = text,
		Font = Theme.TitleFont,
		TextSize = size,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -44, 1, 0),
		ZIndex = 6,
	})
	local noteAt = 44 + TextService:GetTextSize(text, size, Theme.TitleFont, Vector2.new(1000, 100)).X + 14
	local noteLabel = label(content, {
		Text = note,
		Font = Theme.MonoFont,
		TextSize = 11,
		TextColor3 = Theme.Muted,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(noteAt, 0),
		Size = UDim2.new(1, -noteAt, 1, 0),
		ZIndex = 6,
	})
	local function paint(over)
		tween(content, HOVER_TIME, { Position = UDim2.fromOffset(over and HOVER_NUDGE or 0, 0) })
		tween(highlight, HOVER_TIME, { BackgroundTransparency = over and 0.8 or 1 })
		tween(bar, HOVER_TIME, { Size = UDim2.new(0, 3, over and 1 or rest, 0) })
		tween(number, HOVER_TIME, { TextColor3 = over and ink or Theme.Muted })
		tween(noteLabel, HOVER_TIME, { TextTransparency = over and 0.1 or 1 })
	end
	holder.MouseEnter:Connect(function()
		paint(true)
	end)
	holder.MouseLeave:Connect(function()
		paint(false)
	end)
	holder.Activated:Connect(onClick)
	return holder
end

Hub.OnAccent(function(_, newInk)
	ink = newInk
	chip.BackgroundColor3 = ink
	chip.TextColor3 = Hub.OnInk()
	for _, frame in ipairs(accented) do
		frame.BackgroundColor3 = ink
	end
end)

-- the top bar is as tall as Roblox's band; the stack sits in the middle of the room between the
-- bars, shrunk to fit a short screen
local band = ROBLOX_BAR_FALLBACK
local function place()
	band = GuiService:GetGuiInset().Y / UIScale.Get() -- Roblox's band is in real pixels
	band = band > 0 and band or ROBLOX_BAR_FALLBACK / UIScale.Get()
	local view = workspace.CurrentCamera
	local room = (view and view.ViewportSize.Y or 771) / UIScale.Get() - band - BOTTOM_BAR
	fit.Scale = math.clamp((room - 40) / STACK_HEIGHT, 0.3, 1)
	stack.Position = UDim2.fromOffset(PAD, band + room / 2)
	if topBar.Size.Y.Offset > 0 then
		topBar.Size = UDim2.new(1, 0, 0, band)
	end
end
place()
UIScale.OnChange(place)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
end

-- the bars close in, then the title and the buttons slide in from the left one after another
local function intro()
	topBar.Size = UDim2.fromScale(1, 0)
	bottomBar.Size = UDim2.fromScale(1, 0)
	tween(topBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, band) })
	tween(bottomBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, BOTTOM_BAR) })
	shade.BackgroundTransparency = 1
	tween(shade, OPEN_TIME, { BackgroundTransparency = 0 })
	for index, item in ipairs(slideIns) do
		item.Position = UDim2.fromOffset(-(PAD + STACK_WIDTH), 0)
		task.delay(index * STAGGER, function()
			tween(item, OPEN_TIME, { Position = UDim2.new() })
		end)
	end
end

-- the rest of the HUD (every other ScreenGui, and the billboards over characters) is hidden
-- while the title is up: each gui's scale-root frame is turned invisible, as the hub does it
local hiddenHud = {} -- { instance, property } pairs to turn back on
local hudWatch
local function hideHudGui(other)
	if other == gui or LEFT_SHOWING[other.Name] then
		return
	end
	if other:IsA("BillboardGui") then
		if other.Enabled then
			other.Enabled = false
			table.insert(hiddenHud, { other, "Enabled" })
		end
	elseif other:IsA("ScreenGui") then
		UIScale.Root(other) -- makes sure the gui has its root frame
		for _, child in ipairs(other:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible and (child.Name == "UIScaleRoot" or UIScale.SkipChild[child.Name]) then
				child.Visible = false
				table.insert(hiddenHud, { child, "Visible" })
			end
		end
	end
end
local function hideHud()
	local playerGui = player:WaitForChild("PlayerGui")
	for _, other in ipairs(playerGui:GetChildren()) do
		hideHudGui(other)
	end
	-- a gui that appears meanwhile goes too
	hudWatch = playerGui.ChildAdded:Connect(function(other)
		task.defer(hideHudGui, other)
	end)
end
local function showHud()
	if hudWatch then
		hudWatch:Disconnect()
		hudWatch = nil
	end
	for _, entry in ipairs(hiddenHud) do
		if entry[1].Parent then
			entry[1][entry[2]] = true
		end
	end
	hiddenHud = {}
end

-- the camera: the menu screen of the spawn the character stands at, or round the spawn
local camera = workspace.CurrentCamera
local screen -- the MenuCameras part showing
local screenStart = 0
local spawnChecked = false
local spawnLocation -- the SpawnLocation the character stands at, once it's in
local orbitCenter

-- the SpawnLocation nearest `position`
local function nearestSpawn(position)
	local best, bestDistance = nil, math.huge
	for _, item in ipairs(workspace:GetDescendants()) do
		if item:IsA("SpawnLocation") and (item.Position - position).Magnitude < bestDistance then
			best, bestDistance = item, (item.Position - position).Magnitude
		end
	end
	return best
end

-- the part of MenuCameras called `name`, or nil
local function screenNamed(folder, name)
	local part = type(name) == "string" and folder:FindFirstChild(name)
	return part and part:IsA("BasePart") and part or nil
end

-- the menu screen for `spawnPart`: the part its MenuScreen attribute names, else the one
-- MenuCameras' Default attribute names, else the first by name; nil with none
local function screenFor(spawnPart)
	local folder = workspace:FindFirstChild("MenuCameras")
	if not folder then
		return nil
	end
	local found = (spawnPart and screenNamed(folder, spawnPart:GetAttribute("MenuScreen"))) or screenNamed(folder, folder:GetAttribute("Default"))
	if not found then
		for _, part in ipairs(folder:GetChildren()) do
			if part:IsA("BasePart") and (not found or part.Name < found.Name) then
				found = part
			end
		end
	end
	return found
end

-- settles which screen shows: the default until the character is in, then its spawn's (the
-- spawn is looked for once). True when the screen changed.
local function pickScreen()
	if not spawnChecked then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			spawnChecked = true
			spawnLocation = nearestSpawn(root.Position)
		end
	end
	local part = screenFor(spawnLocation)
	if part == screen then
		return false
	end
	screen = part
	screenStart = os.clock()
	showPlace(part)
	return true
end

-- asks the server to stream in the area round `position` (the place streams; the character is at the spawn)
local function streamAround(position)
	task.spawn(function()
		pcall(player.RequestStreamAroundAsync, player, position, 5)
	end)
end

local function findOrbitCenter()
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.Position
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function step()
	camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if pickScreen() and screen then
		streamAround(screen.Position)
	end
	local now = os.clock()
	if screen then
		-- in along the way it looks and back out, easing at both ends
		local drift = tonumber(screen:GetAttribute("Drift")) or SCREEN_DRIFT
		local period = math.max(tonumber(screen:GetAttribute("Period")) or SCREEN_PERIOD, 1)
		local travel = drift * (1 - math.cos((now - screenStart) / period * 2 * math.pi)) / 2
		camera.CFrame = screen.CFrame * CFrame.new(0, 0, -travel)
	else
		orbitCenter = orbitCenter or findOrbitCenter()
		local center = orbitCenter or Vector3.zero
		local angle = now / ORBIT_TIME * 2 * math.pi
		local position = center + Vector3.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
		camera.CFrame = CFrame.lookAt(position, center + Vector3.new(0, 5, 0))
	end
end

-- open: the title is the menu that's open; another menu opening (Settings, the hub) closes the
-- column, and it comes back once nothing is open
local playing = false -- PLAY was pressed
local away = false -- another menu took over from the title

local function closedByOther()
	away = true
	gui.Enabled = false
end

local function showColumn()
	away = false
	gui.Enabled = true
	ProximityPromptService.Enabled = false -- the hub turns prompts back on as it closes
	Menus.Open("Title", closedByOther)
	intro()
end

Menus.OnChange(function(openName)
	if openName == nil and away and not playing then
		showColumn()
	end
end)

-- a character was chosen or made (SlotMenu): into the world
local function enterWorld()
	if playing then
		return
	end
	playing = true
	tween(blackout, PLAY_FADE, { BackgroundTransparency = 0 }).Completed:Wait()
	RunService:UnbindFromRenderStep("TitleCamera")
	column.Visible = false
	-- under the black: the area round the character streamed in, so the shot shows no pop-in
	local characterRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if characterRoot then
		pcall(player.RequestStreamAroundAsync, player, characterRoot.Position, ENTRY_STREAM_TIMEOUT)
	end
	-- the entry shot: the camera swings from the character's face round behind them, their codename in the bars
	local bars = ArrivalShot.Play(gui, blackout, {
		kicker = "ENTERING AS",
		name = tostring(player:GetAttribute("CharName") or player.DisplayName),
		accent = ink,
	})
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	showHud()
	ProximityPromptService.Enabled = true
	Menus.Close("Title")
	if bars then
		ArrivalShot.Clear(bars)
	else
		tween(blackout, REVEAL_TIME, { BackgroundTransparency = 1 }).Completed:Wait()
	end
	gui:Destroy()
end

-- PLAY: the slot screen first (SlotMenu); BACK from it returns to the column
local choosing = false
local function play()
	if playing or choosing then
		return
	end
	choosing = true
	UiSfx.Play("menuSelect")
	column.Visible = false
	SlotMenu.Open(enterWorld, function()
		choosing = false
		column.Visible = true
		intro()
	end)
end

button(1, "PLAY", "CHOOSE YOUR CHARACTER", true, play)
button(2, "UPDATES", "WHAT'S NEW", false, function()
	Hub.OpenOnly("Updates")
end)
button(3, "HANDBOOK", "HOW THE GAME WORKS", false, function()
	UiSfx.Play("menuSelect")
	Hub.OpenOnly("Handbook")
end)
button(4, "SETTINGS", "CONTROLS, SOUND AND MORE", false, function()
	UiSfx.Play("menuSelect")
	Menus.Toggle("Settings")
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
hideHud()
-- the menu screen, its area streamed in before the loading screen lifts; the spawn picks it,
-- so the character gets a moment to come in first
local waitUntil = os.clock() + CHARACTER_WAIT
while not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) and os.clock() < waitUntil do
	task.wait(0.1)
end
pickScreen()
if screen then
	pcall(player.RequestStreamAroundAsync, player, screen.Position, 5)
	screenStart = os.clock() -- the move starts as the screen shows
end
RunService:BindToRenderStep("TitleCamera", Enum.RenderPriority.Camera.Value + 1, step)
showColumn()
RunService.RenderStepped:Wait()
gui:SetAttribute("Ready", true)
