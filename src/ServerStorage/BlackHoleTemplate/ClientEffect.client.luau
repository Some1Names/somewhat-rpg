-- Runs on each client so the black hole's visuals stay smooth: grow, spin
-- and shrink, a shockwave ring and camera shake on cast, and a burst when
-- it collapses.
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local model = script.Parent
local duration = model:GetAttribute("Duration")
local growTime = model:GetAttribute("GrowTime")
local startedAt = model:GetAttribute("StartedAt")
local groundY = model:GetAttribute("GroundY")
local fullScale = model:GetAttribute("FullScale")
local minScale = model:GetScale()
local center = model:GetPivot().Position

local RING_COLOR = Color3.fromRGB(255, 120, 150)
local RING_SIZE = 70 -- studs across when fully expanded
local RING_TIME = 0.5
local SHAKE_RADIUS = 60
local SHAKE_STRENGTH = 0.6 -- studs
local SHAKE_TIME = 0.35
local BURST_COLOR = Color3.fromRGB(255, 200, 220)
local BURST_PARTICLES = 40
local PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function elapsed()
	return workspace:GetServerTimeNow() - startedAt
end

-- Effect parts live in Workspace, not in the model, so they finish even
-- after the server removes the black hole.
local function effectPart(shape, color, size, cframe)
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = workspace
	return part
end

local function playShockwave()
	local ring = effectPart(
		Enum.PartType.Cylinder,
		RING_COLOR,
		Vector3.new(0.3, 4, 4),
		CFrame.new(center.X, groundY + 0.2, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	)
	ring.Name = "BlackHoleShockwave"
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(RING_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, RING_SIZE, RING_SIZE),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, RING_TIME)
end

local function shakeCamera()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - center).Magnitude > SHAKE_RADIUS then
		return
	end
	local shakeStartedAt = os.clock()
	local bindName = "BlackHoleShake" .. HttpService:GenerateGUID(false)
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - shakeStartedAt
		if t >= SHAKE_TIME then
			RunService:UnbindFromRenderStep(bindName)
			return
		end
		local strength = SHAKE_STRENGTH * (1 - t / SHAKE_TIME)
		workspace.CurrentCamera.CFrame *= CFrame.new(
			(math.random() - 0.5) * 2 * strength,
			(math.random() - 0.5) * 2 * strength,
			0
		)
	end)
end

local function playCollapse()
	local flash = effectPart(Enum.PartType.Ball, BURST_COLOR, Vector3.one * 2, CFrame.new(center))
	flash.Name = "BlackHoleCollapseFlash"
	TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 18,
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.3)

	local holder = effectPart(Enum.PartType.Block, BURST_COLOR, Vector3.one, CFrame.new(center))
	holder.Name = "BlackHoleCollapseBurst"
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = PARTICLE_TEXTURE
	emitter.Color = ColorSequence.new(BURST_COLOR, Color3.fromRGB(170, 60, 255))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(30, 55)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(BURST_PARTICLES)
	Debris:AddItem(holder, 1.5)

	-- hide what's left of the model until the server removes it
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end
end

local spinners = {}
for _, part in ipairs(model:GetDescendants()) do
	local degreesPerSecond = part:GetAttribute("SpinDegreesPerSecond")
	if part:IsA("BasePart") and degreesPerSecond then
		table.insert(spinners, { part = part, radiansPerSecond = math.rad(degreesPerSecond) })
	end
end

local function sizeAt(t)
	local alpha
	if t < growTime then
		alpha = t / growTime
	elseif t > duration - growTime then
		alpha = (duration - t) / growTime
	else
		alpha = 1
	end
	alpha = math.clamp(alpha, 0, 1)
	alpha = 1 - (1 - alpha) ^ 2
	return minScale + (fullScale - minScale) * alpha
end

-- a client that receives the black hole late skips the cast impact
if elapsed() < RING_TIME then
	playShockwave()
	shakeCamera()
end

local collapsed = false
RunService.RenderStepped:Connect(function(dt)
	if collapsed or not model.Parent then
		return
	end
	local t = elapsed()
	if t >= duration then
		collapsed = true
		playCollapse()
		return
	end
	model:ScaleTo(sizeAt(t))
	for _, spinner in ipairs(spinners) do
		spinner.part.CFrame *= CFrame.Angles(0, spinner.radiansPerSecond * dt, 0)
	end
end)
