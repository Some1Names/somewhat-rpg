-- The client-side effects toolkit every skill's visuals share.
--
-- Prefabs live in ReplicatedStorage.VFXPrefabs (Shared/, per-set folders,
-- Rocks/). A prefab is an invisible anchored Part holding ParticleEmitters
-- (left disabled) whose attributes say how Play runs them, so their look can
-- be tuned in Studio's Properties without touching code:
--   EmitCount    particles to burst
--   EmitDelay    seconds to wait first (default 0)
--   EmitDuration seconds to emit at the emitter's Rate instead of bursting
--                (Play's options.duration overrides it)
--   Tint         "Solid", "FromWhite" or "ToWhite": recoloured with Play's
--                options.color ("FromWhite" fades white -> colour)
--   Rotate       true: takes Play's options.rotation (degrees, plus the
--                emitter's own RotationOffset), e.g. a slash's angle
--   Hold         true: its particles live for Play's options.hold seconds
--                (a zone that lasts as long as the skill does)
-- Lights inside can have FadeTime (brightness fades to 0 over it).
--
-- Besides prefabs: camera shake, impact frames (the screen flashing black and
-- white with the fighters as silhouettes), ground craters of rock chunks and
-- thrown rubble. Particle and rock counts drop on low graphics settings.
-- A player can turn camera shake and the impact frames and speed lines off
-- in Settings (Preferences "CameraShake", "Flashes").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))

-- the player's Settings may turn shake and flashes off; only a client has a player to ask
local function allowed(id)
	return not RunService:IsClient() or Preferences.Get(id)
end

local prefabs = ReplicatedStorage:WaitForChild("VFXPrefabs")

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SHAKES = { -- studs of jitter, seconds
	Light = { 0.15, 0.2 },
	Medium = { 0.35, 0.3 },
	Heavy = { 0.75, 0.45 },
}
local SHAKE_RADIUS = 60
local IMPACT_FRAME_GAP = 0.3 -- seconds: never two impact frames closer than this
local IMPACT_FRAME_TIME = 0.045 -- seconds each of the two frames shows
local MAX_SILHOUETTES = 8
-- anime speed-line frames for the screen (ui-resources.com, by kek): wide and tall
local SPEEDLINES_WIDE = "rbxassetid://79563317427441"
local SPEEDLINES_TALL = "rbxassetid://75379928250461"
local SPEEDLINES_TIME = 0.35
local CRATER_LIFETIME = 3 -- seconds the chunks stand before sinking
local GRAVITY = 110 -- studs per second squared, for thrown rubble

local VFX = {}

local folder = workspace:FindFirstChild("VFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "VFX"
	folder.Parent = workspace
end
VFX.Folder = folder

local function tween(instance, time, goal, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- 0.35 .. 1 from the player's graphics level (Automatic counts as full)
function VFX.Quality()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok or level == Enum.SavedQualitySetting.Automatic then
		return 1
	end
	return math.clamp(0.25 + level.Value * 0.075, 0.35, 1)
end

function VFX.Find(path)
	local node = prefabs
	for name in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function scaleSequence(sequence, factor)
	local points = {}
	for i, point in ipairs(sequence.Keypoints) do
		points[i] = NumberSequenceKeypoint.new(point.Time, point.Value * factor, point.Envelope * factor)
	end
	return NumberSequence.new(points)
end

local function tinted(style, color)
	if style == "FromWhite" then
		return ColorSequence.new(WHITE, color)
	elseif style == "ToWhite" then
		return ColorSequence.new(color, WHITE)
	end
	return ColorSequence.new(color)
end

-- prefabs following a part (a hand, a root) are moved every frame
local following = {}
RunService.RenderStepped:Connect(function()
	for holder, entry in pairs(following) do
		if not holder.Parent then
			following[holder] = nil
		elseif not entry.part.Parent then
			following[holder] = nil
			VFX.Stop(holder)
		else
			holder.CFrame = entry.part.CFrame * entry.offset
		end
	end
end)

-- Plays the prefab at `path` ("Shared/Impact") at `where`: a CFrame, a
-- position, or a BasePart to follow. Options: scale, color (for Tint),
-- rotation (for Rotate), hold (for Hold), duration (for EmitDuration
-- emitters), offset (from a followed part),
-- lifetime (seconds before it's removed; worked out from the emitters
-- otherwise). Returns the holder part.
function VFX.Play(path, where, options)
	options = options or {}
	local prefab = VFX.Find(path)
	if not prefab then
		warn("[VFX] no prefab " .. path)
		return nil
	end
	local holder = prefab:Clone()
	local scale = options.scale or 1
	local quality = VFX.Quality()
	local follow = typeof(where) == "Instance" and where:IsA("BasePart") and where or nil
	local offset = options.offset or CFrame.identity
	if follow then
		holder.CFrame = follow.CFrame * offset
		following[holder] = { part = follow, offset = offset }
	elseif typeof(where) == "CFrame" then
		holder.CFrame = where
	else
		holder.CFrame = CFrame.new(where)
	end
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	if scale ~= 1 then
		holder.Size *= scale
	end
	holder.Parent = folder

	local longest = 0.1
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("Attachment") and scale ~= 1 then
			-- emitters set off from the holder (a bolt rising from where it strikes) keep their place
			d.Position *= scale
		end
		if d:IsA("ParticleEmitter") then
			if scale ~= 1 then
				d.Size = scaleSequence(d.Size, scale)
				d.Speed = NumberRange.new(d.Speed.Min * scale, d.Speed.Max * scale)
				d.Acceleration *= scale
			end
			local tint = d:GetAttribute("Tint")
			if tint and options.color then
				d.Color = tinted(tint, options.color)
			end
			if options.rotation and d:GetAttribute("Rotate") then
				d.Rotation = NumberRange.new(options.rotation + (d:GetAttribute("RotationOffset") or 0))
			end
			if options.hold and d:GetAttribute("Hold") then
				d.Lifetime = NumberRange.new(options.hold)
			end
			d.Enabled = false
			local delay = d:GetAttribute("EmitDelay") or 0
			local duration = d:GetAttribute("EmitDuration")
			if duration and options.duration then
				duration = options.duration
			end
			local count = d:GetAttribute("EmitCount")
			if duration then
				d.Rate *= quality
				task.delay(delay, function()
					if d.Parent and not holder:GetAttribute("Stopped") then
						d.Enabled = true
					end
				end)
				task.delay(delay + duration, function()
					if d.Parent then
						d.Enabled = false
					end
				end)
				longest = math.max(longest, delay + duration + d.Lifetime.Max)
			elseif count then
				local n = math.max(1, math.round(count * quality))
				if delay > 0 then
					task.delay(delay, function()
						if d.Parent and not holder:GetAttribute("Stopped") then
							d:Emit(n)
						end
					end)
				else
					d:Emit(n)
				end
				longest = math.max(longest, delay + d.Lifetime.Max)
			end
		elseif d:IsA("Light") then
			if d:GetAttribute("Tint") and options.color then
				d.Color = options.color
			end
			local fade = d:GetAttribute("FadeTime")
			if fade then
				tween(d, fade, { Brightness = 0 })
				longest = math.max(longest, fade)
			end
		end
	end
	Debris:AddItem(holder, options.lifetime or longest + 0.1)
	return holder
end

-- stops a prefab's emitters; it's removed once the last particle is gone
function VFX.Stop(holder)
	if not holder or not holder.Parent then
		return
	end
	holder:SetAttribute("Stopped", true)
	local longest = 0
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
			longest = math.max(longest, d.Lifetime.Max)
		elseif d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = false
		end
	end
	Debris:AddItem(holder, longest + 0.1)
end

-- Camera shake ---------------------------------------------------------------

local shakes = {}
local shaking = false

local function stepShake()
	local now = os.clock()
	local strength = 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local t = (now - s.startedAt) / s.time
		if t >= 1 then
			table.remove(shakes, i)
		else
			strength += s.strength * (1 - t) ^ 2
		end
	end
	if #shakes == 0 then
		shaking = false
		RunService:UnbindFromRenderStep("VFXShake")
		return
	end
	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.new((math.random() - 0.5) * 2 * strength, (math.random() - 0.5) * 2 * strength, 0)
		* CFrame.Angles(0, 0, (math.random() - 0.5) * strength * 0.04)
end

-- `power`: "Light", "Medium", "Heavy" or studs; weaker with distance from
-- `origin` (nil: full strength), none past `radius`
function VFX.Shake(origin, power, radius)
	if not allowed("CameraShake") then
		return
	end
	local preset = SHAKES[power] or { tonumber(power) or 0.3, 0.3 }
	local falloff = 1
	if origin then
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local distance = (root.Position - origin).Magnitude
		radius = radius or SHAKE_RADIUS
		if distance > radius then
			return
		end
		falloff = 1 - distance / radius * 0.7
	end
	table.insert(shakes, { strength = preset[1] * falloff, time = preset[2], startedAt = os.clock() })
	if not shaking then
		shaking = true
		RunService:BindToRenderStep("VFXShake", Enum.RenderPriority.Camera.Value + 1, stepShake)
	end
end

-- Screen speed lines ---------------------------------------------------------

-- speed lines rush in from the screen's edges and fade (after an impact
-- frame, or any big moment for this player)
function VFX.ScreenSpeedLines(time)
	if not allowed("Flashes") then
		return
	end
	time = time or SPEEDLINES_TIME
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local viewport = workspace.CurrentCamera.ViewportSize
	local gui = Instance.new("ScreenGui")
	gui.Name = "VFXSpeedLines"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = viewport.Y > viewport.X and SPEEDLINES_TALL or SPEEDLINES_WIDE
	image.ScaleType = Enum.ScaleType.Stretch
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(1.25, 1.25)
	image.ImageTransparency = 0.05
	image.Parent = gui
	gui.Parent = playerGui
	tween(image, time, { Size = UDim2.fromScale(1.02, 1.02), ImageTransparency = 1 })
	Debris:AddItem(gui, time + 0.05)
end

-- Impact frames --------------------------------------------------------------

local lastImpactFrameAt = -math.huge

-- a closed box of slabs just around the camera hides the world; highlights
-- drawn on top show the fighters through it
local function screenBox(color)
	local box = Instance.new("Model")
	box.Name = "ImpactFrame"
	local faces = {
		CFrame.new(0, 0, -1.5), CFrame.new(0, 0, 1.5) * CFrame.Angles(0, math.pi, 0),
		CFrame.new(-1.5, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(1.5, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		CFrame.new(0, 1.5, 0) * CFrame.Angles(math.pi / 2, 0, 0), CFrame.new(0, -1.5, 0) * CFrame.Angles(-math.pi / 2, 0, 0),
	}
	local slabs = {}
	for i, offset in ipairs(faces) do
		local slab = Instance.new("Part")
		slab.Anchored = true
		slab.CanCollide = false
		slab.CanQuery = false
		slab.CanTouch = false
		slab.CastShadow = false
		slab.Material = Enum.Material.Neon
		slab.Color = color
		slab.Size = Vector3.new(3.2, 3.2, 0.05)
		slab.Parent = box
		slabs[i] = { part = slab, offset = offset }
	end
	box.Parent = workspace.CurrentCamera
	return box, slabs
end

-- the screen flashes black with `subjects` (character models) as white
-- silhouettes, then the other way round, then snaps back with a contrast pop
function VFX.ImpactFrame(subjects)
	if not allowed("Flashes") then
		return
	end
	local now = os.clock()
	if now - lastImpactFrameAt < IMPACT_FRAME_GAP then
		return
	end
	lastImpactFrameAt = now
	local box, slabs = screenBox(BLACK)
	local highlights = {}
	for _, model in ipairs(subjects or {}) do
		if #highlights >= MAX_SILHOUETTES then
			break
		end
		if model and model.Parent then
			local highlight = Instance.new("Highlight")
			highlight.Adornee = model
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.FillColor = WHITE
			highlight.FillTransparency = 0
			highlight.OutlineColor = WHITE
			highlight.OutlineTransparency = 0
			highlight.Parent = box
			table.insert(highlights, highlight)
		end
	end
	local bindName = "VFXImpactFrame" .. tostring(now)
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 2, function()
		local camera = workspace.CurrentCamera.CFrame
		for _, slab in ipairs(slabs) do
			slab.part.CFrame = camera * slab.offset
		end
	end)
	task.delay(IMPACT_FRAME_TIME, function()
		for _, slab in ipairs(slabs) do
			slab.part.Color = WHITE
		end
		for _, highlight in ipairs(highlights) do
			highlight.FillColor = BLACK
			highlight.OutlineColor = BLACK
		end
	end)
	task.delay(IMPACT_FRAME_TIME * 2, function()
		RunService:UnbindFromRenderStep(bindName)
		box:Destroy()
		VFX.ScreenSpeedLines()
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "VFXImpactPop"
		grade.Contrast = 0.5
		grade.Saturation = -0.35
		grade.Parent = Lighting
		tween(grade, 0.25, { Contrast = 0, Saturation = 0 })
		Debris:AddItem(grade, 0.3)
	end)
end

-- an impact frame only for the caster and for whoever stands within
-- `radius` of `origin`; they and everyone else inside become the silhouettes
function VFX.ImpactFrameNear(origin, radius, caster)
	if not allowed("Flashes") then
		return
	end
	local me = Players.LocalPlayer.Character
	local myRoot = me and me:FindFirstChild("HumanoidRootPart")
	if not myRoot then
		return
	end
	local involved = caster ~= nil and caster == me
	if not involved and (myRoot.Position - origin).Magnitude > radius then
		return
	end
	local subjects, seen = {}, {}
	if caster then
		table.insert(subjects, caster)
		seen[caster] = true
	end
	for _, part in ipairs(workspace:GetPartBoundsInRadius(origin, radius)) do
		local model = part.Parent
		if part.Name == "HumanoidRootPart" and model and not seen[model] and model:FindFirstChildOfClass("Humanoid") then
			seen[model] = true
			table.insert(subjects, model)
		end
	end
	VFX.ImpactFrame(subjects)
end

-- Ground, rocks, craters, rubble --------------------------------------------

local BAD_ROCK_MATERIALS = {
	[Enum.Material.Neon] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.Water] = true,
	[Enum.Material.Air] = true,
}

-- the solid ground under `position`: point, colour and material (or nil)
function VFX.Ground(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	for _ = 1, 4 do
		local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
		if not hit then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			-- an NPC standing there: look past it
			table.insert(ignore, model)
			params.FilterDescendantsInstances = ignore
		else
			local color
			if hit.Instance:IsA("Terrain") then
				local ok, terrainColor = pcall(workspace.Terrain.GetMaterialColor, workspace.Terrain, hit.Material)
				color = ok and terrainColor or Color3.fromRGB(110, 102, 92)
			else
				color = hit.Instance.Color
			end
			return hit.Position, color, hit.Material
		end
	end
	return nil
end

-- a copy of one of the rock meshes in VFXPrefabs.Rocks, `size` studs across
function VFX.Rock(size, big)
	local pool = {}
	for _, rock in ipairs(prefabs.Rocks:GetChildren()) do
		if (rock.Name:find("^Large") ~= nil) == (big == true) then
			table.insert(pool, rock)
		end
	end
	if #pool == 0 then
		pool = prefabs.Rocks:GetChildren()
	end
	local rock = pool[math.random(#pool)]:Clone()
	rock.Size = Vector3.new(size * (0.8 + math.random() * 0.4), size * (0.7 + math.random() * 0.35), size * (0.8 + math.random() * 0.4))
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false
	return rock
end

local function rockLook(rock, color, material)
	rock.Color = color:Lerp(BLACK, 0.08 + math.random() * 0.18)
	rock.Material = (material and not BAD_ROCK_MATERIALS[material]) and material or Enum.Material.Slate
end

-- rubble thrown from `position` in arcs; it lands, rests a moment and fades.
-- One mover runs all the time (set up when the module first loads), so
-- rubble keeps moving even if the script that threw it is gone.
local flyingRubble = {}
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for i = #flyingRubble, 1, -1 do
		local piece = flyingRubble[i]
		if not piece.part.Parent then
			table.remove(flyingRubble, i)
		elseif not piece.landedAt then
			piece.velocity -= Vector3.new(0, GRAVITY * dt, 0)
			local position = piece.part.Position + piece.velocity * dt
			if position.Y <= piece.floor and piece.velocity.Y < 0 then
				position = Vector3.new(position.X, piece.floor, position.Z)
				piece.landedAt = now
			end
			piece.part.CFrame = CFrame.new(position) * piece.part.CFrame.Rotation * CFrame.Angles(piece.spin.X * dt, piece.spin.Y * dt, piece.spin.Z * dt)
		elseif now - piece.landedAt > piece.rest then
			table.remove(flyingRubble, i)
			tween(piece.part, 0.4, { Transparency = 1 })
			Debris:AddItem(piece.part, 0.45)
		end
	end
end)

function VFX.Rubble(position, count, speed, options)
	options = options or {}
	local ground, color, material = VFX.Ground(position)
	if not ground then
		return
	end
	count = math.max(1, math.round(count * VFX.Quality()))
	for _ = 1, count do
		local size = (options.size or 1) * (0.4 + math.random() * 0.8)
		local rock = VFX.Rock(size)
		rockLook(rock, options.color or color, material)
		local angle = math.random() * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		rock.CFrame = CFrame.new(ground + out * (options.spread or 1) + Vector3.new(0, size / 2, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		rock.Parent = folder
		table.insert(flyingRubble, {
			part = rock,
			velocity = out * speed * (0.4 + math.random() * 0.6) + Vector3.new(0, speed * (0.8 + math.random() * 0.6), 0),
			spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20,
			floor = ground.Y + size * 0.3,
			rest = 0.8 + math.random() * 0.8,
		})
		Debris:AddItem(rock, 8)
	end
end

-- a ring of ground chunks punched up around `position`, leaning outward and
-- coloured like the ground there; they stand a few seconds, then sink.
-- Options: count, lifetime, rubble (pebbles thrown, default by radius),
-- dust (false to skip the dust ring)
function VFX.Crater(position, radius, options)
	options = options or {}
	local ground, color, material = VFX.Ground(position)
	if not ground then
		return
	end
	local quality = VFX.Quality()
	local count = math.max(4, math.round((options.count or (6 + radius * 0.8)) * quality))
	local lifetime = options.lifetime or CRATER_LIFETIME
	local turn = math.random() * math.pi * 2
	for i = 1, count do
		local angle = turn + i / count * math.pi * 2 + (math.random() - 0.5) * 0.4
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local size = math.clamp(radius * (0.28 + math.random() * 0.22), 0.8, 9)
		local rock = VFX.Rock(size, size > 3 and math.random() < 0.4)
		rockLook(rock, color, material)
		local base = ground + out * radius * (0.75 + math.random() * 0.35)
		local tangent = Vector3.new(-out.Z, 0, out.X)
		local lean = CFrame.fromAxisAngle(tangent, -math.rad(30 + math.random() * 30))
		local standing = CFrame.new(base) * lean * CFrame.Angles(0, math.random() * 6, 0)
		local up = standing * CFrame.new(0, rock.Size.Y * 0.2, 0)
		local down = standing * CFrame.new(0, -rock.Size.Y * 0.9, 0)
		rock.CFrame = down
		rock.Parent = folder
		tween(rock, 0.12, { CFrame = up }, Enum.EasingStyle.Back)
		task.delay(lifetime + math.random() * 0.4, function()
			if rock.Parent then
				tween(rock, 0.7, { CFrame = down }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
		Debris:AddItem(rock, lifetime + 1.3)
	end
	if options.dust ~= false then
		VFX.Play("Shared/DustRing", CFrame.new(ground), { scale = math.max(radius / 8, 0.5) })
	end
	local rubble = options.rubble or math.round(4 + radius * 0.6)
	if rubble > 0 then
		VFX.Rubble(ground, rubble, 22 + radius * 1.2, { size = math.clamp(radius / 8, 0.6, 1.6), spread = radius * 0.4 })
	end
	return ground
end

return VFX
