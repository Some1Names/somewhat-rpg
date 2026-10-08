-- Draws Event Horizon (a model whose ClientEffect attribute is "BlackHole")
-- on this client so it stays smooth: a small white orb flies out of the
-- caster's hand and swells on the way, then the black hole grows, spins and
-- shrinks. When it opens: an impact frame for the caster and everyone in
-- reach, a shockwave and a quake. While it's open: light streaks into it,
-- spiral arms close in on the core, lightning flickers round it, a dark
-- swirl turns on the ground beneath it, and crackling tendrils latch onto
-- everyone it's pulling (VFXPrefabs.Mandela.HoleDisk / HoleStain). When it
-- collapses: a burst, speed lines and the ground cratered under it. Colours
-- and reach come from the model's attributes, so the green and the
-- overcharged red versions share this.
-- It runs from SkillEffects rather than a script inside the model, so it
-- still cleans up if the model is removed early (or streamed out).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VFX = require(ReplicatedStorage:WaitForChild("VFX"))

local ORB_START_SIZE = 0.4 -- studs across as it leaves the hand
local ORB_END_SIZE = 6
local ORB_START_COLOR = Color3.new(1, 1, 1)
local OPENING_TIME = 0.5 -- a client that gets the black hole later than this skips the opening impact
local TENDRIL_REFRESH = 0.1 -- seconds between checks for who's being pulled
local SHAKE_RADIUS = 60
local TUNED_RADIUS = 30 -- the Radius HoleDisk and HoleStain are tuned for
local CLEANUP_GRACE = 3 -- seconds past its end before leftovers are cleared regardless

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

return function(model)
	local duration = model:GetAttribute("Duration")
	local growTime = model:GetAttribute("GrowTime")
	local startedAt = model:GetAttribute("StartedAt")
	local groundY = model:GetAttribute("GroundY")
	local fullScale = model:GetAttribute("FullScale")
	local launchFrom = model:GetAttribute("LaunchFrom")
	local travelTime = model:GetAttribute("TravelTime") or 0
	local radius = model:GetAttribute("Radius") or 30
	local casterUserId = model:GetAttribute("CasterUserId")
	if not (duration and growTime and startedAt and groundY and fullScale) then
		return
	end
	local minScale = model:GetScale()
	local center = model:GetPivot().Position
	local ground = Vector3.new(center.X, groundY, center.Z)
	local orbEndColor = model:GetAttribute("OrbColor") or Color3.fromRGB(190, 255, 210)
	local ringColor = model:GetAttribute("GlowColor") or Color3.fromRGB(150, 255, 190)
	local burstColor = model:GetAttribute("BurstColor") or Color3.fromRGB(205, 255, 220)
	local stainTransparency = model:GetAttribute("StainTransparency") or 0.45
	local effectScale = radius / TUNED_RADIUS

	local function elapsed()
		return workspace:GetServerTimeNow() - startedAt
	end
	-- how long anything made now should live at most
	local function safetyLife()
		return math.max(duration - elapsed(), 0) + CLEANUP_GRACE
	end

	local function casterCharacter()
		local caster = casterUserId and Players:GetPlayerByUserId(casterUserId)
		return caster and caster.Character
	end

	-- the opening: an impact frame, a flash, a shockwave along the ground, a quake
	local function playOpening()
		VFX.ImpactFrameNear(center, radius, casterCharacter())
		VFX.Play("Shared/BigImpact", center, { color = ringColor, scale = 1.5 * effectScale })
		VFX.Play("Shared/Shockwave", CFrame.new(ground + Vector3.new(0, 0.2, 0)), { color = ringColor, scale = 2.3 * effectScale })
		VFX.Shake(center, "Heavy", SHAKE_RADIUS)
	end

	-- What plays while it's open (the disk, the stain, a glow, tendrils to the
	-- pulled), made when it opens and cleared when it collapses.
	local extras = {}
	local tendrils = {} -- target root -> { attachment, beam }
	local coreAttachment

	local function makeExtras()
		local remaining = math.max(duration - elapsed(), 0.5)
		local disk = VFX.Play("Mandela/HoleDisk", CFrame.new(center), { color = ringColor, scale = effectScale, duration = remaining })
		local stain = VFX.Play("Mandela/HoleStain", CFrame.new(ground + Vector3.new(0, 0.15, 0)), { color = ringColor, scale = effectScale, hold = remaining })
		local stainEmitter = stain and stain:FindFirstChild("Stain", true)
		if stainEmitter then
			stainEmitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.08, stainTransparency),
				NumberSequenceKeypoint.new(0.92, stainTransparency),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
		local core = effectPart(Enum.PartType.Ball, ringColor, Vector3.one, CFrame.new(center))
		core.Name = "BlackHoleCore"
		core.Transparency = 1
		Debris:AddItem(core, safetyLife())
		coreAttachment = Instance.new("Attachment")
		coreAttachment.Parent = core
		local glow = Instance.new("PointLight")
		glow.Color = ringColor
		glow.Range = radius * 1.6
		glow.Brightness = 4
		glow.Parent = core
		extras = { disk = disk, stain = stain, core = core }
	end

	-- writhing, crackling beams from the core to every character inside its reach
	local lastTendrilCheck = 0
	local function updateTendrils(now)
		if not coreAttachment then
			return
		end
		if now - lastTendrilCheck >= TENDRIL_REFRESH then
			lastTendrilCheck = now
			local inReach = {}
			for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius)) do
				if part.Name == "HumanoidRootPart" and part.Parent:FindFirstChildOfClass("Humanoid") then
					local owner = Players:GetPlayerFromCharacter(part.Parent)
					if not owner or owner.UserId ~= casterUserId then
						inReach[part] = true
					end
				end
			end
			for root, tendril in pairs(tendrils) do
				if not inReach[root] then
					tendril.attachment:Destroy()
					tendrils[root] = nil
				end
			end
			for root in pairs(inReach) do
				if not tendrils[root] then
					local attachment = Instance.new("Attachment")
					attachment.Name = "BlackHoleTendril"
					attachment.Parent = root
					Debris:AddItem(attachment, safetyLife())
					local beam = Instance.new("Beam")
					beam.Attachment0 = coreAttachment
					beam.Attachment1 = attachment
					beam.Color = ColorSequence.new(Color3.new(1, 1, 1), ringColor)
					beam.Transparency = NumberSequence.new(0.1, 0.5)
					beam.LightEmission = 1
					beam.FaceCamera = true
					beam.Segments = 16
					beam.Width0 = 1.4
					beam.Width1 = 0.4
					beam.Texture = "rbxassetid://7216849788"
					beam.TextureMode = Enum.TextureMode.Wrap
					beam.TextureLength = 4
					beam.TextureSpeed = -3
					beam.Parent = attachment
					tendrils[root] = { attachment = attachment, beam = beam, seed = math.random() * 10 }
				end
			end
		end
		for _, tendril in pairs(tendrils) do
			local wave = now * 7 + tendril.seed
			tendril.beam.CurveSize0 = math.sin(wave) * 5
			tendril.beam.CurveSize1 = math.cos(wave * 1.3) * 4
		end
	end

	local function clearExtras()
		if extras.disk then
			VFX.Stop(extras.disk)
		end
		if extras.stain then
			extras.stain:Destroy()
		end
		if extras.core then
			extras.core:Destroy()
		end
		extras = {}
		for _, tendril in pairs(tendrils) do
			tendril.attachment:Destroy()
		end
		table.clear(tendrils)
		coreAttachment = nil
	end

	-- the collapse: a burst with speed lines and the ground cratered under it
	local function playCollapse()
		clearExtras()
		VFX.Play("Shared/BigImpact", center, { color = burstColor, scale = 2 * effectScale })
		VFX.Play("Shared/SpeedLines", center, { scale = 1.5 * effectScale })
		if center.Y - groundY < radius then
			VFX.Crater(ground, radius * 0.35)
		end
		VFX.Shake(center, "Heavy", SHAKE_RADIUS)
		VFX.ImpactFrameNear(center, radius * 0.6, casterCharacter())
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

	-- While the orb is in flight the black hole itself stays hidden.
	local emitterWasEnabled = {}
	local function setHidden(hidden)
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = hidden and 1 or 0
			elseif descendant:IsA("ParticleEmitter") then
				if emitterWasEnabled[descendant] == nil then
					emitterWasEnabled[descendant] = descendant.Enabled
				end
				descendant.Enabled = not hidden and emitterWasEnabled[descendant]
			end
		end
	end

	-- the orb: a white ball with a ribbon of light behind it
	local function makeOrb()
		local orb = effectPart(Enum.PartType.Ball, ORB_START_COLOR, Vector3.one * ORB_START_SIZE, CFrame.new(launchFrom))
		orb.Name = "BlackHoleOrb"
		Debris:AddItem(orb, travelTime + CLEANUP_GRACE)
		local light = Instance.new("PointLight")
		light.Color = orbEndColor
		light.Range = 12
		light.Brightness = 2
		light.Parent = orb
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 0.4, 0)
		top.Parent = orb
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -0.4, 0)
		bottom.Parent = orb
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = ColorSequence.new(ORB_START_COLOR, orbEndColor)
		trail.Transparency = NumberSequence.new(0, 1)
		trail.Lifetime = 0.25
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = orb
		return orb
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

	local orb
	if launchFrom and elapsed() < 0 then
		setHidden(true)
		orb = makeOrb()
	end

	local opened = false
	local function open()
		opened = true
		if orb then
			orb:Destroy()
			orb = nil
			setHidden(false)
		end
		makeExtras()
		if elapsed() < OPENING_TIME then
			playOpening()
		end
	end

	local connection
	local function stop()
		connection:Disconnect()
		if orb then
			orb:Destroy()
			orb = nil
		end
	end
	connection = RunService.RenderStepped:Connect(function(dt)
		if not model.Parent then
			-- removed before it collapsed
			clearExtras()
			stop()
			return
		end
		local t = elapsed()
		if t < 0 then
			-- in flight: grows mostly near the end, shifting from white to green
			if orb then
				local progress = math.clamp(1 + t / travelTime, 0, 1)
				orb.Position = launchFrom:Lerp(center, progress)
				orb.Size = Vector3.one * (ORB_START_SIZE + (ORB_END_SIZE - ORB_START_SIZE) * progress ^ 2)
				orb.Color = ORB_START_COLOR:Lerp(orbEndColor, progress)
			end
			return
		end
		if not opened then
			open()
		end
		-- the server shortens it when it's detonated early
		duration = model:GetAttribute("Duration") or duration
		if t >= duration then
			playCollapse()
			stop()
			return
		end
		model:ScaleTo(sizeAt(t))
		for _, spinner in ipairs(spinners) do
			spinner.part.CFrame *= CFrame.Angles(0, spinner.radiansPerSecond * dt, 0)
		end
		updateTendrils(os.clock())
	end)
end
