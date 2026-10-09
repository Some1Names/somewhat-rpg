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
local SHARD_COUNT = 36 -- Kaleidoscope's mirror shards (fewer on low quality)
local PIXEL_COUNT = 18 -- cubes a body breaks into when it's cut out (fewer on low quality)
local DESATURATE_HEIGHT = 60 -- studs, the grey column

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

	-- a see-through copy of a character, fading over `time`
	local function afterimage(model, color, time)
		if not model or not model.Parent then
			return
		end
		local ghost = ghostOf(model, color)
		ghost.Parent = folder
		for _, part in ipairs(ghost:GetChildren()) do
			part.Transparency = 0.35
			tween(part, time, { Transparency = 1 })
		end
		Debris:AddItem(ghost, time)
	end

	-- a camera flash: a white pop with a coloured ring and glints
	local function cameraFlash(position, size, color)
		flash(position, WHITE, size * 0.3, size, 0.12)
		VFX.Play("Photoshop/CameraFlash", position, { color = color or PINK, scale = size / 4 })
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

	-- the ring on the ground where someone is pasted in (`position`: their root)
	local function pasteRing(position, color, scale)
		VFX.Play("Shared/Shockwave", CFrame.new(position - Vector3.new(0, 2.8, 0)), { color = color, scale = scale })
	end

	function effects.Shutter(origin, finish, struck)
		lightBeam(origin, finish, struck and PINK or BLUE, 0.25, 0.2)
		flash(origin, WHITE, 0.3, 1.6, 0.1)
		VFX.Play("Photoshop/CameraFlash", origin, { color = BLUE, scale = 0.35 })
		if struck then
			cameraFlash(finish, 3)
			VFX.Play("Shared/Impact", finish, { color = PINK, scale = 0.6 })
		else
			flash(finish, BLUE, 0.4, 1.5, 0.12)
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
		local hand = character and (character:FindFirstChild("RightHand") or rootOf(character))
		local root = rootOf(model)
		if hand then
			flash(hand.Position, WHITE, 0.4, 2.5, 0.1)
		end
		if root then
			cameraFlash(root.Position, 5)
			VFX.Play("Shared/Sparks", root.Position, { color = PINK })
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
		pasteRing(to, PINK, 0.5)
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

	-- Desaturate: a grey column; anyone inside goes grey, and your own view
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
		local column = effectPart(
			Enum.PartType.Cylinder,
			GREY,
			Vector3.new(DESATURATE_HEIGHT, radius * 2, radius * 2),
			CFrame.new(center + Vector3.new(0, DESATURATE_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			duration + 1
		)
		column.Material = Enum.Material.ForceField
		column.Transparency = 1
		tween(column, 0.3, { Transparency = 0.6 })
		table.insert(zone.parts, column)
		ring(center + Vector3.new(0, 0.2, 0), GREY, radius * 0.5, radius * 2, 0.5, 0.25)
		VFX.Play("Shared/Shockwave", CFrame.new(center + Vector3.new(0, 0.2, 0)), { color = GREY, scale = radius / 10 })
		VFX.Shake(center, "Light", radius * 2)
		-- grey pixels sift down through the whole column while it lasts
		zone.ash = VFX.Play("Photoshop/GreyAsh", CFrame.new(center + Vector3.new(0, 12, 0)), { duration = duration })
		stretch(zone.ash, Vector3.new(radius * 2, 1, radius * 2))

		local insideMe = false
		local endsAt = os.clock() + duration
		task.spawn(function()
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances = { folder }
			while os.clock() < endsAt and not zone.ended do
				local here = {}
				for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(center + Vector3.new(0, DESATURATE_HEIGHT / 2, 0)), Vector3.new(radius * 2, DESATURATE_HEIGHT, radius * 2), overlap)) do
					local model = part.Name == "HumanoidRootPart" and part.Parent
					if model and ((part.Position - center) * Vector3.new(1, 0, 1)).Magnitude <= radius then
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
			VFX.Play("Shared/BigImpact", point, { color = PINK, scale = 1.3 })
			VFX.Play("Shared/Shockwave", CFrame.new(point - Vector3.new(0, 2.8, 0)), { color = PINK, scale = splashRadius / 8 })
			pixelate(point, BLUE, 2)
			VFX.Shake(point, caught and "Heavy" or "Medium")
			VFX.Crater(point, splashRadius * 0.6)
			if caught then
				VFX.ImpactFrameNear(point, splashRadius + 4)
			end
		end)
	end

	-- Kaleidoscope: a dome of mirror shards, slowly turning
	local scopes = {} -- id -> { shards, done, center, glitter }
	function effects.Kaleidoscope(id, character, center, radius, duration)
		local scope = { shards = {}, done = false, center = center }
		scopes[id] = scope
		local count = math.max(12, math.round(SHARD_COUNT * VFX.Quality()))
		for i = 1, count do
			local wedge = Instance.new("WedgePart")
			wedge.Anchored = true
			wedge.CanCollide = false
			wedge.CanQuery = false
			wedge.CanTouch = false
			wedge.CastShadow = false
			wedge.Material = Enum.Material.Glass
			wedge.Reflectance = 0.45
			wedge.Color = i % 2 == 0 and PINK or BLUE
			wedge.Transparency = 1
			wedge.Size = Vector3.new(0.3, 6 + math.random() * 6, 5 + math.random() * 5)
			wedge.Parent = folder
			Debris:AddItem(wedge, duration + 2)
			-- spread over the dome: golden-angle round, rising row by row
			local up = math.rad(8 + (i / count) * 70)
			local around = i * 2.39996
			table.insert(scope.shards, { part = wedge, up = up, around = around, spin = (math.random() - 0.5) * 2 })
		end
		for _, shard in ipairs(scope.shards) do
			tween(shard.part, 0.4, { Transparency = 0.45 })
		end
		ring(center, PINK, 2, radius * 2, 0.6, 0.4)
		cameraFlash(center + Vector3.new(0, 3, 0), 8)
		-- the ultimate going up: everyone inside sees it land
		VFX.Play("Shared/Shockwave", CFrame.new(center + Vector3.new(0, 0.2, 0)), { color = PINK, scale = radius / 10 })
		VFX.Play("Shared/BigImpact", center + Vector3.new(0, 3, 0), { color = BLUE, scale = 1.4 })
		VFX.Shake(center, "Heavy", radius * 3)
		VFX.ImpactFrameNear(center, radius + 4, character)
		-- glints and pixels hang in the dome while it stands, around head height
		scope.glitter = VFX.Play("Photoshop/PrismGlitter", CFrame.new(center + Vector3.new(0, 6, 0)), { duration = duration })
		stretch(scope.glitter, Vector3.new(radius * 1.6, 12, radius * 1.6))
		local started = os.clock()
		local connection
		connection = RunService.Heartbeat:Connect(function()
			local t = os.clock() - started
			if scope.done or t > duration then
				connection:Disconnect()
				effects.KaleidoscopeEnd(id)
				return
			end
			for _, shard in ipairs(scope.shards) do
				local around = shard.around + t * 0.25
				local offset = Vector3.new(math.cos(around) * math.cos(shard.up), math.sin(shard.up), math.sin(around) * math.cos(shard.up)) * radius
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
		VFX.Play("Shared/SlashArc", root.Position, { color = color, rotation = math.random(0, 180) })
		VFX.Play("Shared/Impact", root.Position, { color = color, scale = 0.6 })
		VFX.Shake(root.Position, "Light", 20)
	end

	function effects.KaleidoscopeEnd(id)
		local scope = scopes[id]
		if not scope then
			return
		end
		scopes[id] = nil
		scope.done = true
		VFX.Stop(scope.glitter)
		-- the mirrors shatter
		VFX.Play("Shared/Sparks", scope.center + Vector3.new(0, 3, 0), { color = BLUE, scale = 2 })
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
		VFX.Play("Shared/Impact", to, { color = PINK, scale = 0.8 })
	end

	-- Undo: a blue copy of her at the spot she left, folding back into her
	function effects.Undo(character, from, to)
		afterimage(character, BLUE, 0.5)
		pixelate(from, BLUE)
		lightBeam(from, to, BLUE, 0.4, 0.3)
		flash(to, BLUE, 0.5, 4, 0.2)
		sparkles(to, PINK, 10)
		pasteRing(to, BLUE, 0.6)
		local root = rootOf(character)
		if root then
			VFX.Play("Shared/AuraBurst", root, { color = BLUE, offset = CFrame.new(0, -0.5, 0) })
		end
		-- her own screen rushes back with her
		if character == Players.LocalPlayer.Character then
			VFX.ScreenSpeedLines(0.35)
		end
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
