-- A short shot of the character arriving somewhere: entering the world from the title (TitleMenu)
-- and landing from a fast travel (FastTravelMenu). Under the caller's black `cover`, black bars
-- close top and bottom with a line in the bottom one (a kicker over a big name, the accent's rule
-- before it); the cover lifts while the camera swings round the character to behind them, where
-- the follow camera takes over. Clear slides the bars away. Square everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme

local ArrivalShot = {}

local PAD = 64 -- the screen's left edge to the line (as on the title menu)
local TIME = 2.4 -- s the swing takes
local REVEAL_TIME = 0.6 -- the cover lifting
local TEXT_TIME = 0.5 -- the line sliding in
local STAGGER = 0.06
local BARS = 0.12 -- share of the screen each black bar takes
local BARS_OUT = 0.5 -- s the bars take to leave
local HEAD_HEIGHT = 1.5 -- studs over the root the follow camera looks at (R15)
-- where the swing ends: behind the character, about where the follow camera sits
local END_OUT = 12
local END_HIGH = 3.5
-- where it starts, unless the caller says: round in front of the face (0 is behind them)
local START_ANGLE = math.rad(150)
local START_OUT = 5
local START_HIGH = 0.4

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

local function tween(instance, time, props)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tweenObject:Play()
	return tweenObject
end

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.TextColor3 = props.TextColor3 or Theme.NavText
	props.TextXAlignment = Enum.TextXAlignment.Left
	props.TextTransparency = 1
	props.ZIndex = 9
	return make("TextLabel", props)
end

-- plays the shot in `gui` (a ScreenGui) and yields until the swing ends, with the camera handed
-- back to the character. `cover` is the caller's black frame, lifted here. opts: kicker, name,
-- accent (Color3), and where the swing starts: angle (radians round from behind), out, high (studs).
-- Returns the bars for Clear; nil (cover untouched) with no character.
function ArrivalShot.Play(gui, cover, opts)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local bars = {}
	for _, edge in ipairs({ 0, 1 }) do
		table.insert(bars, make("Frame", {
			Parent = gui,
			AnchorPoint = Vector2.new(0, edge),
			Position = UDim2.fromScale(0, edge),
			Size = UDim2.fromScale(1, BARS),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 8,
		}))
	end
	local rule = make("Frame", { Parent = bars[2], Position = UDim2.new(0, PAD, 0.5, -24), Size = UDim2.fromOffset(0, 2), BackgroundColor3 = opts.accent or Theme.NavText, BorderSizePixel = 0, ZIndex = 9 })
	local kicker = label(bars[2], {
		Text = opts.kicker or "",
		Font = Theme.MonoFont,
		TextSize = 12,
		TextColor3 = Theme.Muted,
		Position = UDim2.new(0, PAD + 34, 0.5, -32),
		Size = UDim2.new(1, -2 * PAD, 0, 16),
	})
	local name = label(bars[2], {
		Text = string.upper(opts.name or ""),
		Font = Theme.TitleFont,
		TextSize = 34,
		Position = UDim2.new(0, PAD - 12, 0.5, -14),
		Size = UDim2.new(1, -2 * PAD, 0, 40),
	})

	local fromAngle = opts.angle or START_ANGLE
	local fromOut = opts.out or START_OUT
	local fromHigh = opts.high or START_HIGH
	-- the facing at the start: the character can turn during the shot without spinning it
	local facing = root.CFrame.Rotation
	local started = os.clock()
	local function shotAt(alpha)
		local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		local angle = fromAngle * (1 - eased)
		local out = fromOut + (END_OUT - fromOut) * eased
		local high = fromHigh + (END_HIGH - fromHigh) * eased
		local focus = root.Position + Vector3.new(0, HEAD_HEIGHT, 0)
		return CFrame.lookAt(focus + facing * Vector3.new(math.sin(angle) * out, high, math.cos(angle) * out), focus)
	end
	local camera = workspace.CurrentCamera
	RunService:BindToRenderStep("ArrivalShot", Enum.RenderPriority.Camera.Value + 1, function()
		camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = shotAt(math.min((os.clock() - started) / TIME, 1))
	end)

	tween(cover, REVEAL_TIME, { BackgroundTransparency = 1 })
	task.wait(REVEAL_TIME * 0.5)
	tween(rule, TEXT_TIME, { Size = UDim2.fromOffset(24, 2) })
	tween(kicker, TEXT_TIME, { TextTransparency = 0, Position = UDim2.new(0, PAD + 22, 0.5, -32) })
	task.wait(STAGGER)
	tween(name, TEXT_TIME, { TextTransparency = 0, Position = UDim2.new(0, PAD, 0.5, -14) })
	task.wait(math.max(TIME - (os.clock() - started), 0))
	RunService:UnbindFromRenderStep("ArrivalShot")
	camera.CFrame = shotAt(1)
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	for _, item in ipairs({ kicker, name }) do
		tween(item, BARS_OUT * 0.6, { TextTransparency = 1 })
	end
	return bars
end

-- slides the bars from Play away and removes them; yields until they're gone
function ArrivalShot.Clear(bars)
	if not bars then
		return
	end
	tween(bars[1], BARS_OUT, { Size = UDim2.fromScale(1, 0) })
	tween(bars[2], BARS_OUT, { Size = UDim2.fromScale(1, 0) }).Completed:Wait()
	for _, bar in ipairs(bars) do
		bar:Destroy()
	end
end

return ArrivalShot
