-- The loading screen: replaces Roblox's own the moment the player joins (only
-- ReplicatedFirst runs that early). Near-black paper, [ SOMEWHAT ], the big
-- title with RPG on a chip, a status line and a thin progress bar. It waits for
-- the game to load and the asset queue to drain (at least MIN_TIME, and no more
-- than ASSET_TIMEOUT on the assets), then for the title menu (TitleMenu sets
-- Ready on its gui) so the bare world never flashes between the two, and fades.
-- Square everything. The colours are the hub's (HudConfig.HubTheme), written
-- out here because ReplicatedStorage may not have arrived yet.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PAPER = Color3.fromRGB(20, 20, 23)
local NAV = Color3.fromRGB(9, 9, 11)
local INK = Color3.fromRGB(236, 236, 238)
local MUTED = Color3.fromRGB(190, 190, 198)
local BAR_BACK = Color3.fromRGB(50, 50, 58)
local FONT = Enum.Font.Highway

local PAD = 32
local MIN_TIME = 1.5 -- s the screen shows at least, so it doesn't blink
local ASSET_TIMEOUT = 15 -- s after the game loads that the asset queue may take
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
	props.Font = FONT
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

-- the dark band down the left, as on the hub's nav column
make("Frame", { Parent = root, Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = NAV, BorderSizePixel = 0 })
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
	TextSize = 64,
	Size = UDim2.new(1, 0, 0, 64),
})
local chip = label(block, {
	Text = " RPG ",
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
	TextSize = 13,
	TextColor3 = MUTED,
	Position = UDim2.fromOffset(0, 116),
	Size = UDim2.new(1, -60, 0, 16),
})
local percent = label(block, {
	Text = "0%",
	TextSize = 13,
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

-- progress: until the game has loaded the bar creeps up to 40%; then the rest
-- follows the asset queue against the longest it has been
local target, shown = 0, 0
local maxQueue = 1
local loadedAt
local done = false

local stepConnection = RunService.RenderStepped:Connect(function(dt)
	local queue = ContentProvider.RequestQueueSize
	maxQueue = math.max(maxQueue, queue)
	if done then
		target = 1
		status.Text = "READY"
	elseif not loadedAt then
		target = math.min(0.4, (os.clock() - started) / 10 * 0.4)
		status.Text = "LOADING WORLD"
	else
		target = math.max(target, 0.4 + 0.6 * (1 - queue / maxQueue))
		status.Text = queue > 0 and string.format("LOADING ASSETS · %d LEFT", queue) or "STARTING"
	end
	shown += (target - shown) * math.min(1, dt * BAR_SPEED)
	barFill.Size = UDim2.fromScale(shown, 1)
	percent.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
loadedAt = os.clock()
while ContentProvider.RequestQueueSize > 0 and os.clock() - loadedAt < ASSET_TIMEOUT do
	task.wait(0.1)
end
done = true
task.wait(math.max(0.3, MIN_TIME - (os.clock() - started)))

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
