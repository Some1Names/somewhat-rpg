-- Photoshop's looks, drawn for the SkillEffects events its skills send
-- (Skills.Shutter, Snapshot, PhotoTeleport, Desaturate, IrisHorizon,
-- Kaleidoscope, and PhotoshopServer), in the set's pink and light blue.
-- Photos (thin white cards with a coloured outline) and pixels (someone cut
-- out of the picture breaking into little glowing cubes) are built here; the
-- particles are VFXPrefabs.Photoshop (CameraFlash: a camera flash going off;
-- PhotoGlint: sparkles off a photo; GreyAsh: Desaturate's falling grey;
-- PrismGlitter: Kaleidoscope's dome) and the Shared ones. Returns a function
-- that takes the SkillEffects script's own helpers and gives back the
-- effects by name, which that script adds to its own.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local VFX = require(ReplicatedStorage:WaitForChild("VFX"))

local PINK = SkillSetConfig.PhotoshopPink
local BLUE = SkillSetConfig.PhotoshopBlue
local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(150, 150, 160)
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local CARD_SIZE = Vector3.new(3, 3.6, 0.1) -- a photo, studs
local IRIS_CARDS = 8
local STAGE_SHARDS = 12 -- more small shards swirl in at each stage (fewer on low quality)
local KALEIDOSCOPE_PREFAB_RADIUS = 60 -- the radius Photoshop/KaleidoscopeDome is built for
local SHOCKWAVE_RADIUS = 22.5 -- studs the ground ring of Photoshop/ShockwaveStepIn reaches at scale 1 (its biggest layers are 45 across); a call's scale is its skill's radius over this
local PIXEL_COUNT = 18 -- cubes a body breaks into when it's cut out (fewer on low quality)

-- a hue round the rainbow, for Iris Horizon's black hole
local function rainbow(share)
	return Color3.fromHSV(share % 1, 0.65, 1)
end

local function rootOf(model)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.RootPart or (model and model:FindFirstChild("HumanoidRootPart"))
end

return function(helpers)
	local folder = helpers.folder
	local effectPart = helpers.effectPart
	local tween = helpers.tween
	local flash = helpers.flash
	local ring = helpers.ring
	local burst = helpers.burst
	local lightBeam = helpers.lightBeam
	local ghostOf = helpers.ghostOf

	local effects = {}

	-- a photo card: a white sheet with a coloured border, lasting `lifetime`
	local function photoCard(cframe, color, lifetime, size)
		local card = effectPart(Enum.PartType.Block, WHITE, size or CARD_SIZE, cframe, lifetime)
		card.Material = Enum.Material.SmoothPlastic
		card.Transparency = 0.15
		local border = Instance.new("SelectionBox")
		border.Adornee = card
		border.Color3 = color
		border.LineThickness = 0.08
		border.SurfaceTransparency = 1
		border.Parent = card
		return card, border
	end

	local function fadeCard(card, border, time)
		if not card.Parent then
			return
		end
		tween(card, time, { Transparency = 1 })
		if border then
			tween(border, time, { Transparency = 1 })
		end
		Debris:AddItem(card, time)
	end

	local function sparkles(position, color, count)
		burst(position, {
			Texture = SPARKLE_TEXTURE,
			Color = ColorSequence.new(WHITE, color),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.25, 0.5),
			Speed = NumberRange.new(5, 12),
			Drag = 5,
		}, count)
	end

	-- a see-through copy of a character, fading over `time` (starting at
	-- `startTransparency`, 0.35 by default)
	local function afterimage(model, color, time, startTransparency)
		if not model or not model.Parent then
			return
		end
		local ghost = ghostOf(model, color)
		ghost.Parent = folder
		for _, part in ipairs(ghost:GetChildren()) do
			part.Transparency = startTransparency or 0.35
			tween(part, time, { Transparency = 1 })
		end
		Debris:AddItem(ghost, time)
	end

	-- a camera flash: a white pop with a coloured ring and glints (`prefab`: another
	-- flash made for one skill, the all-purpose Photoshop/CameraFlash by default)
	local function cameraFlash(position, size, color, prefab)
		flash(position, WHITE, size * 0.3, size, 0.12)
		VFX.Play(prefab or "Photoshop/CameraFlash", position, { color = color or PINK, scale = size / 4 })
	end

	-- where someone was cut out of the picture: it breaks into square pixels
	-- that drift off and fade (`scale` 1: a body's worth)
	local function pixelate(position, color, scale)
		scale = scale or 1
		local count = math.max(6, math.round(PIXEL_COUNT * VFX.Quality()))
		for i = 1, count do
			local offset = Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 2, math.random() - 0.5) * 2.5 * scale
			local size = (0.25 + math.random() * 0.35) * scale
			local pixel = effectPart(Enum.PartType.Block, i % 3 == 0 and WHITE or color, Vector3.one * size, CFrame.new(position + offset), 1)
			local out = offset.Magnitude > 0.01 and offset.Unit or Vector3.zero
			local drift = (out * (1 + math.random() * 2) + Vector3.new(0, 2 + math.random() * 2, 0)) * scale
			tween(pixel, 0.5 + math.random() * 0.4, { CFrame = pixel.CFrame + drift, Size = Vector3.one * 0.05, Transparency = 1 })
		end
	end

	-- a zone prefab stretched over `size`; its emitters speed up with the
	-- ground it covers (up to 10x) so it stays as thick as the prefab's own
	local function stretch(holder, size)
		if not holder then
			return
		end
		local area = math.min(size.X * size.Z / (holder.Size.X * holder.Size.Z), 10)
		holder.Size = size
		for _, emitter in ipairs(holder:GetDescendants()) do
			if emitter:IsA("ParticleEmitter") then
				emitter.Rate *= area
			end
		end
	end

	-- the ring on the ground where someone is pasted in (`position`: their root);
	-- `prefab`: another ring made for one skill, Photoshop/ShockwaveStepIn by default
	local function pasteRing(position, color, scale, prefab)
		VFX.Play(prefab or "Photoshop/ShockwaveStepIn", CFrame.new(position - Vector3.new(0, 2.8, 0)), { color = color, scale = scale })
	end

	function effects.Shutter(origin, finish, struck)
		lightBeam(origin, finish, struck and PINK or BLUE, 0.25, 0.2)
		flash(origin, WHITE, 0.3, 1.6, 0.1)
		VFX.Play("Photoshop/CameraFlash", origin, { color = BLUE, scale = 0.35 })
		if struck then
			cameraFlash(finish, 3)
			VFX.Play("Photoshop/ShutterHit", finish, { color = PINK, scale = 0.6 })
		else
			flash(finish, BLUE, 0.4, 1.5, 0.12)
		end
	end

	-- her entrance, when she takes up the set: Photoshop's own version of the
	-- shared Equip (the rest of the sets keep theirs). `feet`, `root`: from the
	-- Equip in SkillEffects, which hands it over; `color`: the set's pink
	function effects.PhotoshopEquip(character, color, feet, root)
		VFX.Play("Photoshop/AuraEnter", root, { color = color, offset = CFrame.new(0, -0.5, 0) })
		VFX.Play("Photoshop/SparksSnapshot", root.Position, { color = color })
		if character == Players.LocalPlayer.Character then
			VFX.Shake(nil, "Light")
		end
	end

	-- one of her punches landing (PunchCombat, and Step In's combo): a camera flash
	function effects.PhotoshopPunchHit(point, critical)
		VFX.Play("Photoshop/CameraFlash", point, { scale = critical and 1.6 or 1 })
	end

	-- Step In's punches on the caster's own screen: her arms throw Punch1..hits,
	-- `interval` apart, in time with the server's (Snapshot)
	local comboTracks = setmetatable({}, { __mode = "k" }) -- animator -> { Punch1, ... }
	function effects.StepInCombo(character, hits, interval)
		local humanoid = character == Players.LocalPlayer.Character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local animations = ReplicatedStorage:FindFirstChild("PunchAnimations")
		if not animator or not animations then
			return
		end
		local tracks = comboTracks[animator] or {}
		comboTracks[animator] = tracks
		for i = 1, hits do
			task.delay(interval * i, function()
				local animation = animations:FindFirstChild("Punch" .. i)
				-- not published yet: the punches still land, just without arms
				if not animation or animation.AnimationId == "" or not animator.Parent then
					return
				end
				if not tracks[i] then
					tracks[i] = animator:LoadAnimation(animation)
					tracks[i].Priority = Enum.AnimationPriority.Action3
				end
				tracks[i]:Play(0.05)
			end)
		end
	end

	-- Framed: four pink corners round them, for the caster only
	local frames = {} -- model -> { gui, endsAt }
	function effects.Framed(model, duration)
		local root = rootOf(model)
		if not root then
			return
		end
		local existing = frames[model]
		if existing and existing.gui.Parent then
			existing.endsAt = os.clock() + duration
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "Framed"
		gui.Adornee = root
		gui.AlwaysOnTop = true
		gui.Size = UDim2.fromScale(6, 7)
		gui.LightInfluence = 0
		gui.Parent = folder
		for _, corner in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
			for _, horizontal in ipairs({ true, false }) do
				local line = Instance.new("Frame")
				line.BorderSizePixel = 0
				line.BackgroundColor3 = PINK
				line.AnchorPoint = corner
				line.Position = UDim2.fromScale(corner.X, corner.Y)
				line.Size = horizontal and UDim2.new(0.25, 0, 0, 3) or UDim2.new(0, 3, 0.22, 0)
				line.Parent = gui
			end
		end
		local entry = { gui = gui, endsAt = os.clock() + duration }
		frames[model] = entry
		task.spawn(function()
			while os.clock() < entry.endsAt and model.Parent and gui.Parent do
				task.wait(0.1)
			end
			if frames[model] == entry then
				frames[model] = nil
			end
			gui:Destroy()
		end)
	end

	function effects.Snapshot(character, model)
		local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or rootOf(character))
		local root = rootOf(model)
		if hand then
			flash(hand.Position, WHITE, 0.4, 2.5, 0.1)
		end
		if root then
			cameraFlash(root.Position, 5, nil, "Photoshop/SnapshotFlash")
			VFX.Play("Photoshop/SparksSnapshot", root.Position, { color = PINK })
			VFX.Shake(root.Position, "Light", 30)
			local card, border = photoCard(CFrame.new(root.Position + Vector3.new(0, 4, 0)), PINK, 0.6)
			tween(card, 0.6, { CFrame = card.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(0, math.pi, 0) })
			fadeCard(card, border, 0.6)
		end
	end

	-- cut out of one spot and pasted into the other
	function effects.StepIn(character, from, to)
		afterimage(character, PINK, 0.4)
		pixelate(from, PINK)
		local card, border = photoCard(CFrame.new(from), PINK, 0.35, Vector3.new(4, 6, 0.1))
		fadeCard(card, border, 0.35)
		cameraFlash(to, 4)
		pasteRing(to, PINK, 0.5, "Photoshop/ShockwaveStepIn")
		VFX.Shake(to, "Light", 30)
	end

	-- Photo Teleport's pinned photo, standing at the spot until it's used or fades
	local photos = {} -- id -> { card, border, glint }
	function effects.PhotoPin(id, character, point, lifetime)
		local root = rootOf(character)
		local facing = root and Vector3.new(root.Position.X, point.Y, root.Position.Z) or point + Vector3.new(0, 0, 1)
		if (facing - point).Magnitude < 0.1 then
			facing = point + Vector3.new(0, 0, 1)
		end
		local card, border = photoCard(CFrame.lookAt(point, facing), BLUE, lifetime + 1, Vector3.new(3.4, 4.2, 0.12))
		-- it glints for as long as it stands there
		local glint = VFX.Play("Photoshop/PhotoGlint", card, { color = BLUE, duration = lifetime })
		photos[id] = { card = card, border = border, glint = glint }
		ring(point - Vector3.new(0, 2.8, 0), BLUE, 1, 6, 0.4, 0.2)
		cameraFlash(point, 2.5, BLUE)
		task.delay(lifetime, function()
			effects.PhotoGone(id)
		end)
	end

	function effects.PhotoGone(id)
		local photo = photos[id]
		if not photo then
			return
		end
		photos[id] = nil
		VFX.Stop(photo.glint)
		fadeCard(photo.card, photo.border, 0.3)
	end

	function effects.PhotoPaste(id, model, from, to)
		local photo = photos[id]
		if photo and photo.card.Parent then
			-- the photo flips as they come through it
			tween(photo.card, 0.25, { CFrame = photo.card.CFrame * CFrame.Angles(0, math.pi, 0) })
		end
		afterimage(model, BLUE, 0.4)
		pixelate(from, BLUE)
		local card, border = photoCard(CFrame.new(from), BLUE, 0.35, Vector3.new(4, 6, 0.1))
		fadeCard(card, border, 0.35)
		cameraFlash(to, 4, BLUE)
		pasteRing(to, BLUE, 0.5)
		VFX.Shake(to, "Light", 30)
		effects.PhotoGone(id)
	end

	-- the burst where Photo Teleport's photo landed (Skills.PhotoTeleport)
	function effects.PhotoBurst(point, radius)
		VFX.Play("Photoshop/ShockwaveStepIn", CFrame.new(point + Vector3.new(0, 0.2, 0)), { color = BLUE, scale = radius / SHOCKWAVE_RADIUS })
		VFX.Play("Photoshop/BigImpactIrisBurst", point + Vector3.new(0, 2, 0), { color = BLUE, scale = radius / 13 })
		VFX.Shake(point, "Light", radius * 3)
	end

	-- Desaturate: a grey dome; anyone inside goes grey, and your own view
	-- drains of colour while you're in it
	local zones = {} -- id -> { parts, ended, inside = { model -> true } }
	local greyed = {} -- model -> { outline, zones = how many zones hold them }

	-- a zone takes hold of someone, or lets go; the grey stays while any zone holds them
	local function grey(model)
		local entry = greyed[model]
		if entry then
			entry.zones += 1
			return
		end
		local outline = Instance.new("Highlight")
		outline.Name = "Desaturated"
		outline.FillColor = GREY
		outline.FillTransparency = 0.35
		outline.OutlineColor = WHITE
		outline.OutlineTransparency = 0.6
		outline.Adornee = model
		outline.Parent = folder
		greyed[model] = { outline = outline, zones = 1 }
	end
	local function ungrey(model)
		local entry = greyed[model]
		if not entry then
			return
		end
		entry.zones -= 1
		if entry.zones <= 0 then
			greyed[model] = nil
			tween(entry.outline, 0.6, { FillTransparency = 1, OutlineTransparency = 1 })
			Debris:AddItem(entry.outline, 0.6)
		end
	end
	local localGrade
	local localZones = 0
	function effects.Desaturate(id, center, radius, duration)
		local zone = { parts = {}, ended = false, inside = {} }
		zones[id] = zone
		-- a ball sunk to its middle in the ground: the half above it is the dome
		local dome = effectPart(Enum.PartType.Ball, GREY, Vector3.one * radius * 2, CFrame.new(center), duration + 1)
		dome.Material = Enum.Material.ForceField
		dome.Transparency = 1
		tween(dome, 0.3, { Transparency = 0.6 })
		table.insert(zone.parts, dome)
		VFX.Shake(center, "Light", radius * 2)
		-- grey pixels fill the dome while it lasts: its emitters spread through a
		-- sphere on the ground (the half under it is hidden by the ground)
		zone.ash = VFX.Play("Photoshop/GreyAsh", CFrame.new(center), { duration = duration })
		if zone.ash then
			for _, emitter in ipairs(zone.ash:GetDescendants()) do
				if emitter:IsA("ParticleEmitter") then
					emitter.Shape = Enum.ParticleEmitterShape.Sphere
					emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
				end
			end
			stretch(zone.ash, Vector3.one * radius * 2)
		end

		local insideMe = false
		local endsAt = os.clock() + duration
		task.spawn(function()
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances = { folder }
			while os.clock() < endsAt and not zone.ended do
				local here = {}
				for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, overlap)) do
					local model = part.Name == "HumanoidRootPart" and part.Parent
					if model and (part.Position - center).Magnitude <= radius and part.Position.Y >= center.Y - 4 then
						here[model] = true
						if not zone.inside[model] then
							zone.inside[model] = true
							grey(model)
						end
					end
				end
				local me = Players.LocalPlayer.Character
				local nowInside = me ~= nil and here[me] == true
				if nowInside ~= insideMe then
					insideMe = nowInside
					localZones += nowInside and 1 or -1
					if not localGrade then
						localGrade = Instance.new("ColorCorrectionEffect")
						localGrade.Name = "Desaturated"
						localGrade.Parent = Lighting
					end
					tween(localGrade, 0.3, { Saturation = localZones > 0 and -1 or 0 })
				end
				for model in pairs(zone.inside) do
					if not here[model] or not model.Parent then
						zone.inside[model] = nil
						ungrey(model)
					end
				end
				task.wait(0.15)
			end
			if insideMe then
				localZones -= 1
				if localGrade then
					tween(localGrade, 0.5, { Saturation = localZones > 0 and -1 or 0 })
				end
			end
			effects.DesaturateEnd(id)
		end)
	end

	function effects.DesaturateEnd(id)
		local zone = zones[id]
		if not zone then
			return
		end
		zones[id] = nil
		zone.ended = true
		VFX.Stop(zone.ash)
		for model in pairs(zone.inside) do
			ungrey(model)
		end
		table.clear(zone.inside)
		for _, part in ipairs(zone.parts) do
			if part.Parent then
				tween(part, 0.5, { Transparency = 1 })
				for _, emitter in ipairs(part:GetChildren()) do
					if emitter:IsA("ParticleEmitter") then
						emitter.Enabled = false
					end
				end
				Debris:AddItem(part, 2.5)
			end
		end
	end

	-- Iris Horizon: photos in a ring round the target close in like iris
	-- blades, drifting after them as the server's does
	local irises = {} -- id -> { cards, done, center }
	function effects.IrisHorizon(id, model, ringRadius, closeTime, startShare, followSpeed)
		local root = rootOf(model)
		if not root then
			return
		end
		local iris = { cards = {}, done = false, center = root.Position }
		irises[id] = iris
		for _ = 1, IRIS_CARDS do
			local card, border = photoCard(CFrame.new(root.Position), PINK, closeTime + 2, Vector3.new(3.2, 4, 0.1))
			-- each blade trails glints as it closes
			local glint = VFX.Play("Photoshop/PhotoGlint", card, { color = PINK, duration = closeTime })
			table.insert(iris.cards, { card = card, border = border, glint = glint })
		end
		local startRadius = ringRadius * (1 - startShare)
		local started = os.clock()
		local connection
		connection = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock() - started
			if iris.done or t > closeTime + 1 then
				connection:Disconnect()
				return
			end
			local current = rootOf(model)
			if current and current.Parent then
				local toward = (current.Position - iris.center) * Vector3.new(1, 0, 1)
				local step = math.min(toward.Magnitude, followSpeed * dt)
				if step > 0 then
					iris.center += toward.Unit * step
				end
				iris.center = Vector3.new(iris.center.X, current.Position.Y, iris.center.Z)
			end
			local share = math.clamp(t / closeTime, 0, 1)
			local radius = math.max(startRadius * (1 - share), 0.4)
			local turn = share * math.pi * 0.75 -- the blades turn as they close
			for i, entry in ipairs(iris.cards) do
				local angle = (i - 1) / IRIS_CARDS * math.pi * 2 + turn
				local spot = iris.center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
				-- each card faces the middle, tipped in like a blade
				entry.card.CFrame = CFrame.lookAt(spot, iris.center) * CFrame.Angles(0, 0, math.rad(25))
				entry.border.Color3 = rainbow(share * 0.6 + i / IRIS_CARDS * 0.4):Lerp(PINK, 1 - share)
			end
		end)
	end

	local function endIris(id)
		local iris = irises[id]
		if not iris then
			return nil
		end
		irises[id] = nil
		iris.done = true
		for _, entry in ipairs(iris.cards) do
			VFX.Stop(entry.glint)
			fadeCard(entry.card, entry.border, 0.2)
		end
		return iris
	end

	function effects.IrisCancel(id)
		endIris(id)
	end

	-- the rainbow black hole: a dark core with rainbow rims folds in, then bursts
	function effects.IrisBurst(id, point, splashRadius, caught)
		endIris(id)
		local core = effectPart(Enum.PartType.Ball, Color3.fromRGB(8, 6, 14), Vector3.one * 2, CFrame.new(point), 1)
		core.Material = Enum.Material.SmoothPlastic
		tween(core, 0.15, { Size = Vector3.one * splashRadius * 0.9 })
		for i = 1, 6 do
			local tilt = CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.rad(i * 30))
			local rim = effectPart(Enum.PartType.Cylinder, rainbow(i / 6), Vector3.new(0.25, splashRadius * 1.3, splashRadius * 1.3), CFrame.new(point) * tilt, 0.5)
			rim.Transparency = 0.2
			tween(rim, 0.25, { Size = Vector3.new(0.25, 1, 1), Transparency = 0.6 })
		end
		task.delay(0.25, function()
			tween(core, 0.2, { Size = Vector3.one * 0.5, Transparency = 1 })
			flash(point, WHITE, 1, splashRadius * 2, 0.25)
			for i = 1, 4 do
				ring(point, rainbow(i / 4), 2, splashRadius * (2 + i * 0.5), 0.45, 0.4)
			end
			sparkles(point, PINK, caught and 24 or 12)
			sparkles(point, BLUE, caught and 24 or 12)
			VFX.Play("Photoshop/BigImpactIrisBurst", point, { color = PINK, scale = 1.3 })
			VFX.Play("Photoshop/ShockwaveStepIn", CFrame.new(point - Vector3.new(0, 2.8, 0)), { color = PINK, scale = splashRadius / SHOCKWAVE_RADIUS })
			pixelate(point, BLUE, 2)
			VFX.Shake(point, caught and "Heavy" or "Medium")
			VFX.Crater(point, splashRadius * 0.6)
			if caught then
				VFX.ImpactFrameNear(point, splashRadius + 4)
			end
		end)
	end

	-- Iris Horizon's second, wider burst a moment after the first (Skills.IrisHorizon)
	function effects.IrisAftershock(center, radius)
		VFX.Play("Photoshop/ShockwaveStepIn", CFrame.new(center - Vector3.new(0, 2.8, 0)), { color = PINK, scale = radius / SHOCKWAVE_RADIUS })
		VFX.Play("Photoshop/BigImpactIrisBurst", center, { color = PINK, scale = radius / 12 })
		VFX.Shake(center, "Medium", radius * 3)
	end

	-- Kaleidoscope: the finished dome model (VFXPrefabs.Photoshop.KaleidoscopeDome:
	-- glass shards with their outline, a bubble and ground glow, floor particles,
	-- clouds, outline particles and a ring of beams) laid over the spot. Its
	-- glass is turned here; the rest just plays. Each stage, as more mirror
	-- images strike (Skills.Kaleidoscope's StageTime), a pulse runs out, the
	-- shards turn faster and thicken, and more glass swirls in; when it runs its
	-- course they burst outward.
	local scopes = {} -- id -> { shards, done, center, radius, glitter, dome, bubble, floor }
	local KALEIDOSCOPE_SHARD_TRANSPARENCY = { 0.45, 0.32, 0.2 } -- by stage
	function effects.Kaleidoscope(id, character, center, radius, duration, stageTime)
		stageTime = stageTime or 2
		local scope = { shards = {}, done = false, center = center, radius = radius }
		scopes[id] = scope
		-- the root stands about 3 up
		local ground = center - Vector3.new(0, 2.9, 0)
		local dome = VFX.Find("Photoshop/KaleidoscopeDome")
		dome = dome and dome:Clone()
		local smalls = {} -- the small shards: more are copied from these at each stage
		if dome then
			if math.abs(radius - KALEIDOSCOPE_PREFAB_RADIUS) > 0.5 then
				dome:ScaleTo(radius / KALEIDOSCOPE_PREFAB_RADIUS)
			end
			dome:PivotTo(CFrame.new(center)) -- its pivot is the middle of its bubble
			dome.Parent = folder
			Debris:AddItem(dome, duration + 3)
			local all = {}
			for _, part in ipairs(dome:GetDescendants()) do
				if part:IsA("WedgePart") then
					table.insert(all, part)
				elseif part:IsA("ParticleEmitter") then
					part.Enabled = true
				end
			end
			-- fewer shards on low quality
			local keep = math.max(12, math.round(#all * VFX.Quality()))
			for i = #all, keep + 1, -1 do
				table.remove(all, math.random(i)):Destroy()
			end
			for _, part in ipairs(all) do
				-- where it stands in the dome gives its place; the big mirrors turn
				-- one way, the small ones deeper in the other, and every one bobs
				local offset = part.Position - center
				local distance = math.max(offset.Magnitude, 0.1)
				local small = part.Name == "SmallShard"
				if small then
					table.insert(smalls, part)
				end
				table.insert(scope.shards, {
					part = part,
					up = math.asin(math.clamp(offset.Y / distance, -1, 1)),
					around = math.atan2(offset.Z, offset.X),
					spin = (math.random() - 0.5) * (small and 5 or 2),
					reach = distance / radius, -- share of the radius
					direction = small and -1 or 1,
					bob = math.random() * math.pi * 2,
				})
				part.Transparency = 1
				tween(part, 0.4, { Transparency = KALEIDOSCOPE_SHARD_TRANSPARENCY[1] })
			end
			-- the reach: its bubble and ground glow fade in to the look they were made with
			scope.dome = dome
			local reach = dome:FindFirstChild("Reach")
			scope.bubble = reach and reach:FindFirstChild("Bubble")
			scope.floor = reach and reach:FindFirstChild("GroundGlow")
			for _, extra in ipairs({ scope.bubble, scope.floor }) do
				local shown = extra.Transparency
				extra.Transparency = 1
				tween(extra, 0.5, { Transparency = shown })
			end
		else
			warn("[Kaleidoscope] no Photoshop/KaleidoscopeDome prefab")
		end
		ring(center, PINK, 2, radius * 2, 0.6, 0.4)
		cameraFlash(center + Vector3.new(0, 3, 0), 8)
		-- the ultimate going up: everyone inside sees it land
		VFX.Play("Photoshop/ShockwaveStepIn", CFrame.new(center + Vector3.new(0, 0.2, 0)), { color = PINK, scale = radius / SHOCKWAVE_RADIUS })
		VFX.Play("Photoshop/BigImpactIrisBurst", center + Vector3.new(0, 3, 0), { color = BLUE, scale = 1.4 })
		VFX.Shake(center, "Heavy", radius * 3)
		VFX.ImpactFrameNear(center, radius + 4, character)
		-- glints and pixels hang in the dome while it stands, around head height
		scope.glitter = VFX.Play("Photoshop/PrismGlitter", CFrame.new(center + Vector3.new(0, 6, 0)), { duration = duration })
		stretch(scope.glitter, Vector3.new(radius * 1.6, 12, radius * 1.6))
		local started = os.clock()
		local stages = math.max(1, math.floor(duration / stageTime))
		local stage = 1
		local turn = 0
		local connection
		connection = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock() - started
			if scope.done or t > duration then
				connection:Disconnect()
				effects.KaleidoscopeEnd(id, not scope.done) -- running its course: the finale
				return
			end
			local now = math.min(math.floor(t / stageTime) + 1, stages)
			if now > stage then
				-- more mirrors: a pulse out, the shards thicken and turn faster
				stage = now
				ring(ground, stage == stages and PINK or BLUE, 2, radius * 2, 0.5, 0.4)
				flash(center + Vector3.new(0, 3, 0), WHITE, 2, radius * 0.5, 0.2)
				VFX.Shake(center, "Medium", radius * 3)
				-- and more glass swirls in: copies of the small shards, in their own colour group
				if #smalls > 0 then
					local more = math.max(4, math.round(STAGE_SHARDS * VFX.Quality()))
					for _ = 1, more do
						local template = smalls[math.random(#smalls)]
						local part = template:Clone()
						part.Transparency = 1
						part.Parent = template.Parent
						table.insert(scope.shards, {
							part = part,
							up = math.rad(4 + math.random() * 76),
							around = math.random() * math.pi * 2,
							spin = (math.random() - 0.5) * 5,
							reach = 0.5 + math.random() * 0.45,
							direction = -1,
							bob = math.random() * math.pi * 2,
						})
					end
				end
				for _, shard in ipairs(scope.shards) do
					tween(shard.part, 0.3, { Transparency = KALEIDOSCOPE_SHARD_TRANSPARENCY[math.min(stage, #KALEIDOSCOPE_SHARD_TRANSPARENCY)] })
				end
			end
			turn += dt * (0.25 + 0.15 * (stage - 1))
			for _, shard in ipairs(scope.shards) do
				local around = shard.around + turn * shard.direction
				local bob = math.sin(t * 1.5 + shard.bob) * (shard.reach < 1 and 1.2 or 0.4)
				local offset = Vector3.new(math.cos(around) * math.cos(shard.up), math.sin(shard.up), math.sin(around) * math.cos(shard.up)) * radius * shard.reach + Vector3.new(0, bob, 0)
				local spot = center + offset
				shard.part.CFrame = CFrame.lookAt(spot, center) * CFrame.Angles(0, math.rad(90), t * shard.spin)
			end
		end)
	end

	function effects.KaleidoscopeHit(id, model)
		local root = rootOf(model)
		if not root then
			return
		end
		-- one of their mirror images strikes them
		local side = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		side = side.Magnitude > 0.01 and side.Unit or Vector3.new(1, 0, 0)
		local from = root.Position + side * 4
		local color = math.random() < 0.5 and PINK or BLUE
		local shard = effectPart(Enum.PartType.Block, color, Vector3.new(0.2, 3, 2), CFrame.lookAt(from, root.Position), 0.3)
		shard.Material = Enum.Material.Glass
		shard.Reflectance = 0.5
		tween(shard, 0.15, { CFrame = CFrame.lookAt(root.Position, root.Position + side), Transparency = 1 })
		flash(root.Position, WHITE, 0.5, 2.5, 0.12)
		VFX.Play("Photoshop/KaleidoscopeSlash", root.Position, { color = color, rotation = math.random(0, 180) })
		VFX.Play("Photoshop/ImpactKaleidoscopeReflect", root.Position, { color = color, scale = 0.6 })
		VFX.Shake(root.Position, "Light", 20)
	end

	-- `finale`: it ran its course (Skills.Kaleidoscope's last hit on everyone
	-- inside), so the mirrors burst outward; otherwise it was cut short and they just shatter
	function effects.KaleidoscopeEnd(id, finale)
		local scope = scopes[id]
		if not scope then
			return
		end
		scopes[id] = nil
		scope.done = true
		VFX.Stop(scope.glitter)
		local center, radius = scope.center, scope.radius
		local ground = center - Vector3.new(0, 2.9, 0)
		if scope.dome then
			-- its particles and beams stop; the glass goes as below, then the model
			for _, d in ipairs(scope.dome:GetDescendants()) do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") then
					d.Enabled = false
				end
			end
			Debris:AddItem(scope.dome, 2)
		end
		for _, extra in ipairs({ scope.bubble, scope.floor }) do
			if extra.Parent then
				tween(extra, 0.5, finale and extra == scope.bubble and { Size = Vector3.one * radius * 2.4, Transparency = 1 } or { Transparency = 1 })
			end
		end
		if finale then
			local middle = center + Vector3.new(0, 3, 0)
			for _, shard in ipairs(scope.shards) do
				if shard.part.Parent then
					local outward = shard.part.Position - center
					outward = outward.Magnitude > 0.1 and outward.Unit or Vector3.yAxis
					tween(shard.part, 0.7, { CFrame = shard.part.CFrame + outward * radius * 0.5, Transparency = 1, Size = shard.part.Size * 0.2 })
					Debris:AddItem(shard.part, 0.7)
				end
			end
			flash(middle, WHITE, 2, radius, 0.3)
			for i, color in ipairs({ PINK, BLUE, WHITE }) do
				ring(ground, color, 2, radius * (1.6 + i * 0.3), 0.4 + i * 0.1, 0.5)
			end
			cameraFlash(middle, 14)
			sparkles(middle, PINK, 30)
			sparkles(middle, BLUE, 30)
			VFX.Play("Photoshop/ShockwaveStepIn", CFrame.new(ground), { color = PINK, scale = radius / SHOCKWAVE_RADIUS })
			VFX.Play("Photoshop/BigImpactIrisBurst", middle, { color = PINK, scale = 2 })
			VFX.Shake(center, "Heavy", radius * 3)
			VFX.ImpactFrameNear(center, radius + 4)
			return
		end
		-- the mirrors shatter
		VFX.Play("Photoshop/SparksSnapshot", scope.center + Vector3.new(0, 3, 0), { color = BLUE, scale = 2 })
		for _, shard in ipairs(scope.shards) do
			if shard.part.Parent then
				tween(shard.part, 0.4, { Transparency = 1, Size = shard.part.Size * 0.3 })
				Debris:AddItem(shard.part, 0.4)
			end
		end
	end

	-- light bounced back off Kaleidoscope's mirrors
	function effects.Reflect(from, to)
		lightBeam(from, to, PINK, 0.35, 0.25)
		lightBeam(from, to, BLUE, 0.15, 0.3)
		cameraFlash(from, 2.5)
		flash(to, PINK, 0.5, 3, 0.15)
		VFX.Play("Photoshop/ImpactKaleidoscopeReflect", to, { color = PINK, scale = 0.8 })
	end

	-- Undo: she's carried back the way she came, like a video scrubbed
	-- backwards. Her own client moves her along `path` (where she's been,
	-- newest first) over `duration`, running the animations she's in
	-- backwards (the rig's Animate script is paused meanwhile, so it doesn't
	-- start new ones). Everyone sees a trail of copies of her left along the
	-- way (close together, pink where she began the rewind to blue where it
	-- ends, each fading slowly), a thin blue line down the path and a flash
	-- where she lands. The server puts her exactly on the last spot when it's over.
	local REWIND_ANIMATION_SPEED = -2 -- the animations she's in, played backwards this fast
	local REWIND_GHOST_EVERY = 0.035 -- seconds between the copies left along the way
	local REWIND_GHOST_FADE = 0.8 -- seconds a copy takes to fade out
	local REWIND_GHOST_OPACITY = 0.2 -- how see-through a copy starts (0 solid, 1 gone)

	-- the pivot `share` (0 to 1) of the way along a path of pivots
	local function alongPath(path, share)
		local scaled = math.clamp(share, 0, 1) * (#path - 1)
		local i = math.min(math.floor(scaled) + 1, #path - 1)
		return path[i]:Lerp(path[i + 1], scaled - (i - 1))
	end

	function effects.Undo(character, path, duration)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = rootOf(character)
		if #path < 1 or not humanoid or not root then
			return
		end
		local landing = path[#path].Position
		afterimage(character, BLUE, 0.5)
		for i = 1, #path - 1 do
			lightBeam(path[i].Position, path[i + 1].Position, BLUE, 0.2, duration + 0.3)
		end

		-- her own client carries her back and runs her animations backwards
		local carries = character == Players.LocalPlayer.Character and #path >= 2
		local animate = carries and character:FindFirstChild("Animate")
		local speeds = {} -- track -> its speed before
		if carries then
			if animate then
				animate.Enabled = false
			end
			local animator = humanoid:FindFirstChildOfClass("Animator")
			for _, track in ipairs(animator and animator:GetPlayingAnimationTracks() or {}) do
				speeds[track] = track.Speed
				track:AdjustSpeed(REWIND_ANIMATION_SPEED)
			end
			VFX.ScreenSpeedLines(duration)
		end

		local started = os.clock()
		local lastCopy = 0
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - started
			local done = elapsed >= duration or not character.Parent or humanoid.Health <= 0
			if carries and character.Parent then
				character:PivotTo(done and path[#path] or alongPath(path, elapsed / duration))
				root.AssemblyLinearVelocity = Vector3.zero
			end
			if not done then
				if elapsed - lastCopy >= REWIND_GHOST_EVERY / math.max(VFX.Quality(), 0.35) then
					lastCopy = elapsed
					afterimage(character, PINK:Lerp(BLUE, math.clamp(elapsed / duration, 0, 1)), REWIND_GHOST_FADE, REWIND_GHOST_OPACITY)
				end
				return
			end
			connection:Disconnect()
			-- with the rig's Animate script back, it picks the right pose
			-- again; without one, the tracks just play forwards again
			for track, speed in pairs(speeds) do
				if animate then
					track:Stop(0.15)
				else
					track:AdjustSpeed(speed)
				end
			end
			if animate and animate.Parent then
				animate.Enabled = true
			end
			if character.Parent then
				flash(landing, BLUE, 0.5, 4, 0.2)
				sparkles(landing, PINK, 10)
				pasteRing(landing, BLUE, 0.6)
			end
		end)
	end

	-- the Gallery's photo developing over her head, then taking her or spoiling
	local developing = {} -- character -> card
	function effects.GalleryDevelop(character, time)
		local root = rootOf(character)
		if not root then
			return
		end
		local card, border = photoCard(root.CFrame * CFrame.new(0, 5, 0), BLUE, time + 1, Vector3.new(2.6, 3.2, 0.1))
		card.Color = Color3.fromRGB(30, 30, 40)
		card.Transparency = 0.6
		tween(card, time, { Color = WHITE, Transparency = 0.1 })
		developing[character] = { card = card, border = border }
		local started = os.clock()
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if developing[character] == nil or not card.Parent or os.clock() - started > time + 0.5 then
				connection:Disconnect()
				return
			end
			local now = rootOf(character)
			if now then
				card.CFrame = now.CFrame * CFrame.new(0, 5, 0) * CFrame.Angles(0, (os.clock() - started) * 2, 0)
			end
		end)
	end

	local function stopDeveloping(character)
		local entry = developing[character]
		developing[character] = nil
		return entry
	end

	function effects.GalleryTravel(character, from, to)
		local entry = stopDeveloping(character)
		if entry then
			fadeCard(entry.card, entry.border, 0.2)
		end
		cameraFlash(from, 4, BLUE)
		pixelate(from, BLUE)
		cameraFlash(to, 4, BLUE)
		pasteRing(to, BLUE, 0.6)
	end

	function effects.GalleryCancel(character)
		local entry = stopDeveloping(character)
		if entry and entry.card.Parent then
			-- the photo spoils: it greys, crumbles and drops
			pixelate(entry.card.Position, GREY, 0.5)
			tween(entry.card, 0.4, { Color = GREY, Transparency = 1, CFrame = entry.card.CFrame * CFrame.new(0, -2, 0) })
			Debris:AddItem(entry.card, 0.4)
		end
	end

	return effects
end
