-- Draws Mandela's tornado (a model whose ClientEffect attribute is
-- "Tornado") on this client, so it moves and spins smoothly: it grows in,
-- wanders forward along the same path Skills.Tornado pulls along, spins
-- rings of wind up the funnel over a ring of dust kicked off the ground
-- (VFXPrefabs.Mandela.TornadoBase), trails ribbons of spirit light round it,
-- crackles with lightning, whirls rock rubble round, rumbles the camera of
-- anyone close by, and bursts apart at the end: an impact frame for the
-- caster and whoever it holds, a shockwave and a crater. Its light is green,
-- or the model's Tint when overcharged.
-- It runs from SkillEffects rather than a script inside the model, so it
-- still cleans up if the model is removed early (or streamed out).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VFX = require(ReplicatedStorage:WaitForChild("VFX"))

local MIN_SCALE_FRACTION = 0.05
local BASE_SIZE = 0.5 -- the size (of the template) TornadoBase is tuned for
local RIBBON_COUNT = 4
local RIBBON_TURNS_PER_SECOND = 0.9
local RIBBON_CLIMB_SECONDS = 1.4 -- for a ribbon to rise from the base to the top
local RUMBLE_RADIUS = 50
local RUMBLE_INTERVAL = 0.3 -- seconds between rumbles of the camera
local BOLT_SEGMENTS = 6
local BOLT_LIFETIME = 0.12
local BOLT_INTERVAL = NumberRange.new(0.08, 0.22) -- seconds between bolts
local DEBRIS_COUNT = 14
local DEBRIS_COLORS = {
	Color3.fromRGB(92, 86, 80),
	Color3.fromRGB(110, 102, 92),
	Color3.fromRGB(78, 74, 70),
	Color3.fromRGB(120, 108, 92),
}
local CLEANUP_GRACE = 3 -- seconds past its end before leftovers are cleared regardless

return function(model)
	local startedAt = model:GetAttribute("StartedAt")
	local duration = model:GetAttribute("Duration")
	local growTime = model:GetAttribute("GrowTime")
	local start = model:GetAttribute("StartPosition")
	local direction = model:GetAttribute("Direction")
	local speed = model:GetAttribute("Speed")
	local wobbleAmplitude = model:GetAttribute("WobbleAmplitude")
	local wobbleFrequency = model:GetAttribute("WobbleFrequency")
	local fullScale = model:GetAttribute("FullScale")
	local templateScale = model:GetAttribute("TemplateScale")
	local baseOffset = model:GetAttribute("BaseOffset") -- pivot height above the base at templateScale
	local templateHeight = model:GetAttribute("TemplateHeight")
	local casterUserId = model:GetAttribute("CasterUserId")
	if not (startedAt and duration and start and direction and fullScale and templateScale) then
		return
	end
	local side = Vector3.new(direction.Z, 0, -direction.X)
	local spiritColor = model:GetAttribute("Tint") or Color3.fromRGB(170, 255, 200)
	local fullSize = fullScale / templateScale -- 1 = the size the template was built at
	local effectScale = fullSize / BASE_SIZE

	local function elapsed()
		return workspace:GetServerTimeNow() - startedAt
	end

	-- same formula as Skills.Tornado
	local function basePosition(t)
		return start + direction * speed * t + side * math.sin(t * wobbleFrequency) * wobbleAmplitude
	end

	local function scaleAt(t)
		local grow = math.clamp(t / growTime, 0, 1)
		grow = 1 - (1 - grow) ^ 3
		return fullScale * (MIN_SCALE_FRACTION + (1 - MIN_SCALE_FRACTION) * grow)
	end

	-- Effects live in their own folder in Workspace so they can outlast the
	-- model; whatever happens, they're gone a little after its end.
	local effects = Instance.new("Folder")
	effects.Name = "TornadoEffects"
	effects.Parent = workspace
	Debris:AddItem(effects, math.max(duration - elapsed(), 0) + CLEANUP_GRACE)

	local function effectPart(shape, size, cframe)
		local part = Instance.new("Part")
		part.Shape = shape
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Transparency = 1
		part.Size = size
		part.CFrame = cframe
		part.Parent = effects
		return part
	end

	-- the dust ring and climbing wind rings follow this along the ground
	local base = effectPart(Enum.PartType.Block, Vector3.one, CFrame.new(start))
	local baseEffect -- played once the tornado has mostly grown in

	-- a late client skips the touchdown puff
	if elapsed() < 0.2 then
		VFX.Play("Shared/Shockwave", CFrame.new(start + Vector3.new(0, 0.2, 0)), { color = spiritColor, scale = 0.6 * effectScale })
	end

	-- ribbons of spirit light spiralling up the funnel
	local ribbons = {}
	for i = 1, RIBBON_COUNT do
		local wisp = effectPart(Enum.PartType.Ball, Vector3.one * 0.3, CFrame.new(start))
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 0.7, 0)
		top.Parent = wisp
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -0.7, 0)
		bottom.Parent = wisp
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), spiritColor)
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		trail.Lifetime = 0.35
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = wisp
		ribbons[i] = { part = wisp, trail = trail }
	end

	-- rock rubble whirled round the funnel at different heights and speeds:
	-- mostly small stones, every fourth one a bigger rock
	local debris = {}
	for i = 1, DEBRIS_COUNT do
		local big = i % 4 == 0
		local chunk = VFX.Rock(big and 1.6 + math.random() * 0.8 or 0.5 + math.random() * 0.8, big)
		chunk.Material = Enum.Material.Slate
		chunk.Color = DEBRIS_COLORS[math.random(#DEBRIS_COLORS)]
		chunk.CFrame = CFrame.new(start)
		chunk.Parent = effects
		debris[i] = {
			part = chunk,
			height = 0.1 + 0.8 * math.random(),
			turnsPerSecond = 0.6 + math.random() * 0.6,
			phase = math.random() * 2 * math.pi,
			tumble = Vector3.new(math.random(), math.random(), math.random()) * 6,
		}
	end

	-- a jagged bolt between two points on the funnel, gone in a blink
	local function bolt(at, height)
		local function onFunnel(climb)
			local angle = math.random() * 2 * math.pi
			local r = height * (0.1 + 0.6 * climb)
			return at + Vector3.new(math.cos(angle) * r, climb * height, math.sin(angle) * r)
		end
		local from = onFunnel(math.random() * 0.5)
		local to = onFunnel(0.4 + math.random() * 0.6)
		local previous = from
		for i = 1, BOLT_SEGMENTS do
			local point = from:Lerp(to, i / BOLT_SEGMENTS)
			if i < BOLT_SEGMENTS then
				point += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * height * 0.12
			end
			local length = (point - previous).Magnitude
			local segment = effectPart(Enum.PartType.Block, Vector3.new(0.18, 0.18, length), CFrame.lookAt((previous + point) / 2, point))
			segment.Color = spiritColor:Lerp(Color3.new(1, 1, 1), 0.4)
			segment.Transparency = 0
			TweenService:Create(segment, TweenInfo.new(BOLT_LIFETIME), { Transparency = 1 }):Play()
			Debris:AddItem(segment, BOLT_LIFETIME)
			previous = point
		end
		local light = effectPart(Enum.PartType.Ball, Vector3.one * 0.1, CFrame.new((from + to) / 2))
		local glow = Instance.new("PointLight")
		glow.Color = spiritColor
		glow.Range = height * 0.8
		glow.Brightness = 3
		glow.Parent = light
		Debris:AddItem(light, BOLT_LIFETIME)
	end

	local spinners = {}
	for _, part in ipairs(model:GetDescendants()) do
		local degreesPerSecond = part:GetAttribute("SpinDegreesPerSecond")
		if part:IsA("BasePart") and degreesPerSecond then
			table.insert(spinners, { part = part, radiansPerSecond = math.rad(degreesPerSecond) })
		end
	end

	local function casterCharacter()
		local caster = casterUserId and Players:GetPlayerByUserId(casterUserId)
		return caster and caster.Character
	end

	-- it bursts: a flash in the funnel, an impact frame for the caster and
	-- whoever it holds, a shockwave and a crater, and the rubble thrown clear
	local function burst(at)
		local height = templateHeight * fullSize
		local middle = at + Vector3.new(0, height * 0.35, 0)
		VFX.Play("Shared/BigImpact", middle, { color = spiritColor, scale = 1.3 * effectScale })
		VFX.Play("Shared/Shockwave", CFrame.new(at + Vector3.new(0, 0.2, 0)), { color = spiritColor, scale = 1.4 * effectScale })
		VFX.Crater(at, 7 * effectScale)
		VFX.Shake(at, "Heavy", RUMBLE_RADIUS)
		VFX.ImpactFrameNear(middle, height * 0.9, casterCharacter())
		for _, chunk in ipairs(debris) do
			local part = chunk.part
			local outward = Vector3.new(part.Position.X - at.X, 0, part.Position.Z - at.Z)
			outward = outward.Magnitude > 0.1 and outward.Unit or Vector3.xAxis
			local landing = part.Position + outward * (25 + math.random() * 20) + Vector3.new(0, 6 + math.random() * 8, 0)
			local tumble = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(landing) * part.CFrame.Rotation * tumble,
				Transparency = 1,
			}):Play()
		end
	end

	local finished = false
	local connection
	local nextBoltAt = 0
	local nextRumbleAt = 0
	-- the burst at its end, or (removed early) just a quick fade of the rubble
	local function finish(withBurst)
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
		end
		if baseEffect then
			VFX.Stop(baseEffect)
		end
		for _, ribbon in ipairs(ribbons) do
			ribbon.trail.Enabled = false
		end
		if withBurst then
			burst(basePosition(duration))
		else
			for _, chunk in ipairs(debris) do
				TweenService:Create(chunk.part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = 1
			end
		end
		-- let the last particles fade before clearing up
		Debris:AddItem(effects, 1.5)
	end

	connection = RunService.RenderStepped:Connect(function(dt)
		if not model.Parent then
			finish(false)
			return
		end
		local t = math.max(elapsed(), 0)
		if t >= duration then
			finish(true)
			return
		end

		local scale = scaleAt(t)
		local size = scale / templateScale
		local currentBase = basePosition(t)
		for _, spinner in ipairs(spinners) do
			local part = spinner.part
			part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, spinner.radiansPerSecond * dt, 0) * part.CFrame.Rotation
		end
		model:ScaleTo(scale)
		model:PivotTo(CFrame.new(currentBase + Vector3.new(0, baseOffset * size, 0)))

		base.CFrame = CFrame.new(currentBase + Vector3.new(0, 0.3, 0))
		if not baseEffect and t >= growTime * 0.6 then
			baseEffect = VFX.Play("Mandela/TornadoBase", base, { color = spiritColor, scale = effectScale, duration = duration - t })
		end

		-- the funnel narrows to the ground, so ribbons swing wider as they climb
		local height = templateHeight * size
		for i, ribbon in ipairs(ribbons) do
			local climb = (t / RIBBON_CLIMB_SECONDS + i / RIBBON_COUNT) % 1
			local angle = (t * RIBBON_TURNS_PER_SECOND + i / RIBBON_COUNT) * 2 * math.pi
			local radius = height * (0.12 + 0.75 * climb)
			-- same turning direction as the spinning layers and the server's pull
			ribbon.part.Position = currentBase + Vector3.new(math.cos(angle) * radius, climb * height, -math.sin(angle) * radius)
			-- a ribbon wrapping from the top back to the base would streak across the funnel
			ribbon.trail.Enabled = climb > 0.04
		end

		for _, chunk in ipairs(debris) do
			local angle = chunk.phase + t * chunk.turnsPerSecond * 2 * math.pi
			local radius = height * (0.15 + 0.6 * chunk.height)
			local tumble = CFrame.Angles(chunk.tumble.X * t, chunk.tumble.Y * t, chunk.tumble.Z * t)
			chunk.part.CFrame = CFrame.new(currentBase + Vector3.new(math.cos(angle) * radius, chunk.height * height, -math.sin(angle) * radius)) * tumble
		end

		local now = os.clock()
		if now >= nextBoltAt and t > growTime * 0.5 then
			nextBoltAt = now + BOLT_INTERVAL.Min + math.random() * (BOLT_INTERVAL.Max - BOLT_INTERVAL.Min)
			bolt(currentBase, height)
		end
		if now >= nextRumbleAt then
			nextRumbleAt = now + RUMBLE_INTERVAL
			VFX.Shake(currentBase, 0.12, RUMBLE_RADIUS)
		end
	end)
end
