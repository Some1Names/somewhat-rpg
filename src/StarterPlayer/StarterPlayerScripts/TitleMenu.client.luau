-- The title menu: shown once as the player joins, built under the loading
-- screen (LoadingScreen fades once this gui has Ready). A dark column on the
-- left holds [ SOMEWHAT ], the title with RPG on an accent chip, PLAY /
-- SETTINGS / UPDATES and the version. Behind it the camera drifts through the
-- shots in workspace.MenuCameras (parts, in name order, each looking out of its
-- front face; SHOT_TIME each, through black between them) or, with none, slowly
-- circles the spawn. The place streams, so MenuCameras should be a Model with
-- ModelStreamingMode Persistent, and the area round the next shot is asked for
-- before the cut.
-- While it's up the title is the open menu to Menus (the character can't move
-- or fight), the rest of the HUD is hidden the way the hub hides it, and "press
-- E" prompts are off. SETTINGS and UPDATES open the Settings menu and the hub's
-- Updates tab: opening them closes the column, and it comes back when they
-- close. PLAY fades through black, hands the camera back to the character and
-- shows the HUD. Square everything; the accent is the hub's.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local UpdateNotes = require(ReplicatedStorage:WaitForChild("UpdateNotes"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme

local COLUMN_WIDTH = 340
local PAD = 28
local ROBLOX_BAR_FALLBACK = 58 -- Roblox's band across the top, while GetGuiInset still says 0
local BUTTON_HEIGHT = 44
local SHADE_WIDTH = 260 -- the dark fading off the column's edge into the world

local OPEN_TIME = 0.35 -- the column sliding in
local HOVER_TIME = 0.15
local HOVER_NUDGE = 8 -- px a button's text moves right on hover
local PLAY_FADE = 0.35 -- to black on PLAY
local REVEAL_TIME = 0.6 -- from black onto the character
local SHOT_TIME = 12 -- s on each MenuCameras shot
local SHOT_FADE = 0.6 -- s through black at each end of a shot
local SHOT_DRIFT = 10 -- studs the camera moves forward over a shot
local STREAM_AHEAD = 4 -- s before a cut that the next shot's area is asked for
local ORBIT_TIME = 90 -- s for one turn round the spawn, with no shots
local ORBIT_RADIUS = 45
local ORBIT_HEIGHT = 20

-- guis the title leaves alone: the menus it opens, the top bar's pill (it sits in Roblox's band), the loading screen
local LEFT_SHOWING = { Hub = true, Settings = true, MenuButton = true, LoadingScreen = true }

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

-- back to front: the black between shots, the shade, the column, the black of PLAY
local shotVeil = make("Frame", {
	Parent = gui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 1,
})
local shade = make("Frame", {
	Parent = gui,
	Position = UDim2.fromOffset(COLUMN_WIDTH, 0),
	Size = UDim2.new(0, SHADE_WIDTH, 1, 0),
	BackgroundColor3 = Theme.Nav,
	BorderSizePixel = 0,
	ZIndex = 2,
})
make("UIGradient", {
	Parent = shade,
	Transparency = NumberSequence.new(0.35, 1),
})
local column = make("Frame", {
	Name = "Column",
	Parent = gui,
	Size = UDim2.new(0, COLUMN_WIDTH, 1, 0),
	BackgroundColor3 = Theme.Nav,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	ZIndex = 3,
	Active = true,
})
local blackout = make("Frame", {
	Parent = gui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 10,
})

-- the column's contents, below Roblox's band
local inner = make("Frame", { Parent = column, BackgroundTransparency = 1, ZIndex = 3 })
local function placeInner()
	local band = GuiService:GetGuiInset().Y / UIScale.Get() -- Roblox's band is in real pixels
	band = band > 0 and band or ROBLOX_BAR_FALLBACK / UIScale.Get()
	inner.Position = UDim2.fromOffset(PAD, band + PAD)
	inner.Size = UDim2.new(1, -2 * PAD, 1, -(band + 2 * PAD))
end
placeInner()
UIScale.OnChange(placeInner)

local brand = label(inner, {
	Text = "[ SOMEWHAT ]",
	RichText = true,
	TextSize = 14,
	Size = UDim2.new(1, 0, 0, 18),
	ZIndex = 3,
})
label(inner, {
	Text = "SOMEWHAT",
	Font = Theme.TitleFont,
	TextSize = 52,
	Position = UDim2.fromOffset(0, 48),
	Size = UDim2.new(1, 0, 0, 52),
	ZIndex = 3,
})
local chip = label(inner, {
	Text = " RPG ",
	Font = Theme.TitleFont,
	TextSize = 20,
	BackgroundTransparency = 0,
	Position = UDim2.fromOffset(3, 106),
	Size = UDim2.fromOffset(0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 3,
})
make("Frame", {
	Parent = inner,
	Position = UDim2.fromOffset(0, 156),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = Theme.Muted,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	ZIndex = 3,
})

local buttons = make("Frame", {
	Parent = inner,
	Position = UDim2.fromOffset(0, 180),
	Size = UDim2.new(1, 0, 0, 3 * BUTTON_HEIGHT),
	BackgroundTransparency = 1,
	ZIndex = 3,
})
make("UIListLayout", { Parent = buttons, SortOrder = Enum.SortOrder.LayoutOrder })

-- footer: a rule and the version
local footer = make("Frame", {
	Parent = inner,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	ZIndex = 3,
})
make("Frame", {
	Parent = footer,
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = Theme.Muted,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	ZIndex = 3,
})
label(footer, {
	Text = "VERSION " .. string.upper(UpdateNotes.Version),
	TextSize = 11,
	TextColor3 = Theme.Muted,
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 14),
	ZIndex = 3,
})

-- a button: its number, its name, and an accent line that sweeps under it on hover
local underlines = {}
local function button(order, text, size, onClick)
	local holder = make("TextButton", {
		Parent = buttons,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
	})
	local content = make("Frame", { Parent = holder, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 })
	label(content, {
		Text = string.format("%02d", order),
		TextSize = 12,
		TextColor3 = Theme.Muted,
		Size = UDim2.new(0, 28, 1, 0),
		ZIndex = 3,
	})
	label(content, {
		Text = text,
		Font = Theme.TitleFont,
		TextSize = size,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -28, 1, 0),
		ZIndex = 3,
	})
	local underline = make("Frame", {
		Parent = holder,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -4),
		Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = Hub.InkAccent(),
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	table.insert(underlines, underline)
	holder.MouseEnter:Connect(function()
		tween(content, HOVER_TIME, { Position = UDim2.fromOffset(HOVER_NUDGE, 0) })
		tween(underline, HOVER_TIME, { Size = UDim2.new(1, -28, 0, 2) })
	end)
	holder.MouseLeave:Connect(function()
		tween(content, HOVER_TIME, { Position = UDim2.new() })
		tween(underline, HOVER_TIME, { Size = UDim2.fromOffset(0, 2) })
	end)
	holder.Activated:Connect(onClick)
	return holder
end

Hub.OnAccent(function(_, ink)
	brand.Text = string.format('[ <font color="#%s">SOMEWHAT</font> ]', ink:ToHex())
	chip.BackgroundColor3 = ink
	chip.TextColor3 = Hub.OnInk()
	for _, underline in ipairs(underlines) do
		underline.BackgroundColor3 = ink
	end
end)

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

-- the camera: through the MenuCameras shots, or round the spawn
local camera = workspace.CurrentCamera
local shots = {}
local shotIndex, shotStart = 0, 0
local streamedFor -- the shot whose area was last asked for
local orbitCenter

local function shotList()
	local found = {}
	local folder = workspace:FindFirstChild("MenuCameras")
	if folder then
		for _, part in ipairs(folder:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(found, part)
			end
		end
		table.sort(found, function(a, b)
			return a.Name < b.Name
		end)
	end
	return found
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
	local now = os.clock()
	if shotIndex == 0 or now - shotStart >= SHOT_TIME then
		shots = shotList()
		shotIndex = shotIndex % math.max(#shots, 1) + 1
		shotStart = now
	end
	local elapsed = now - shotStart
	local shot = shots[shotIndex]
	if shot and shot.Parent then
		camera.CFrame = shot.CFrame * CFrame.new(0, 0, -SHOT_DRIFT * elapsed / SHOT_TIME)
		shotVeil.BackgroundTransparency = math.clamp(math.min(elapsed, SHOT_TIME - elapsed) / SHOT_FADE, 0, 1)
		local nextShot = shots[shotIndex % #shots + 1]
		if elapsed >= SHOT_TIME - STREAM_AHEAD and streamedFor ~= nextShot then
			streamedFor = nextShot
			streamAround(nextShot.Position)
		end
	else
		orbitCenter = orbitCenter or findOrbitCenter()
		local center = orbitCenter or Vector3.zero
		local angle = now / ORBIT_TIME * 2 * math.pi
		local position = center + Vector3.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
		camera.CFrame = CFrame.lookAt(position, center + Vector3.new(0, 5, 0))
		shotVeil.BackgroundTransparency = 1
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
	column.Position = UDim2.fromOffset(-COLUMN_WIDTH, 0)
	tween(column, OPEN_TIME, { Position = UDim2.new() })
end

Menus.OnChange(function(openName)
	if openName == nil and away and not playing then
		showColumn()
	end
end)

local function play()
	if playing then
		return
	end
	playing = true
	UiSfx.Play("menuSelect")
	tween(blackout, PLAY_FADE, { BackgroundTransparency = 0 }).Completed:Wait()
	RunService:UnbindFromRenderStep("TitleCamera")
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	column.Visible = false
	shade.Visible = false
	shotVeil.Visible = false
	showHud()
	ProximityPromptService.Enabled = true
	Menus.Close("Title")
	tween(blackout, REVEAL_TIME, { BackgroundTransparency = 1 }).Completed:Wait()
	gui:Destroy()
end

button(1, "PLAY", 30, play)
button(2, "SETTINGS", 22, function()
	UiSfx.Play("menuSelect")
	Menus.Toggle("Settings")
end)
button(3, "UPDATES", 22, function()
	Hub.Open("Updates")
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
hideHud()
-- the first shot's area, before the loading screen lifts
local first = shotList()[1]
if first then
	pcall(player.RequestStreamAroundAsync, player, first.Position, 5)
end
RunService:BindToRenderStep("TitleCamera", Enum.RenderPriority.Camera.Value + 1, step)
showColumn()
RunService.RenderStepped:Wait()
gui:SetAttribute("Ready", true)
