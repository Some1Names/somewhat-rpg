-- Draws the skill effects the server announces on the SkillEffects remote, so
-- every client gets smooth local copies: the burst when a skill set is
-- equipped, the eruption when it overcharges, ground shockwaves, the slash
-- flashes of weapon hits, enemies shrugging off a stagger, Mandela's thrown
-- axe, Spine Lash, Overcome the Possibility and Misremembered, and
-- Iridescent Requiem's light, including the glow of anyone in Prism Form
-- (their character's PrismForm attribute). Anything tagged Iridescent
-- shimmers between the set's orange and cyan here (SkillSetConfig
-- .IridescentColor), and spins if it has a Spin attribute. The local
-- player's own moves can play here at once through the LocalSkillEffect
-- bindable (Dash's Lightstep) instead of waiting on the server.
-- Most looks come from ReplicatedStorage.VFXPrefabs through the VFX toolkit
-- (ReplicatedStorage.VFX): prefabs, camera shake, impact frames, craters.
-- The tornado and black hole models are drawn by the TornadoEffect and
-- BlackHoleEffect modules under this script (see the end), and Photoshop's
-- looks by PhotoshopEffects.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local VFX = require(ReplicatedStorage:WaitForChild("VFX"))

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local WHITE = Color3.new(1, 1, 1)

local folder = Instance.new("Folder")
folder.Name = "SkillEffects"
folder.Parent = workspace

local function effectPart(shape, color, size, cframe, lifetime)
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
	part.Parent = folder
	Debris:AddItem(part, lifetime)
	return part
end

local function tween(instance, time, goal, style)
	TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

-- flat ring on the ground that races outward and fades
local function ring(position, color, fromSize, toSize, time, thickness)
	local part = effectPart(
		Enum.PartType.Cylinder,
		color,
		Vector3.new(thickness or 0.3, fromSize, fromSize),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		time
	)
	part.Transparency = 0.15
	tween(part, time, { Size = Vector3.new(thickness or 0.3, toSize, toSize), Transparency = 1 })
end

-- a sphere of light that swells and fades
local function flash(position, color, fromSize, toSize, time)
	local part = effectPart(Enum.PartType.Ball, color, Vector3.one * fromSize, CFrame.new(position), time)
	tween(part, time, { Size = Vector3.one * toSize, Transparency = 1 })
end

-- a one-off burst of `count` particles; `size` is the box a Box-shaped
-- emitter fills (a stud by default) and the holder lasts `life` seconds (2)
local function burst(position, props, count, size, life)
	local holder = effectPart(Enum.PartType.Block, WHITE, size or Vector3.one, CFrame.new(position), life or 2)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.SpreadAngle = Vector2.new(180, 180)
	for key, value in pairs(props) do
		emitter[key] = value
	end
	emitter.Parent = holder
	emitter:Emit(count)
end

local function shake(origin, radius, strength, time)
	if not Preferences.Get("CameraShake") then
		return -- turned off in Settings
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local distance = (root.Position - origin).Magnitude
	if distance > radius then
		return
	end
	strength *= 1 - distance / radius
	local startedAt = os.clock()
	local name = "SkillShake" .. HttpService:GenerateGUID(false)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - startedAt
		if t >= time then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local s = strength * (1 - t / time)
		workspace.CurrentCamera.CFrame *= CFrame.new((math.random() - 0.5) * 2 * s, (math.random() - 0.5) * 2 * s, 0)
	end)
end

local function feetOf(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root then
		return nil
	end
	return root.Position - Vector3.new(0, (humanoid and humanoid.HipHeight or 2) + root.Size.Y / 2, 0), root
end

-- Mandela's backbone spikes (ReplicatedStorage.MandelaEffects.Spikes), if present
local function spikesAsset()
	local assets = ReplicatedStorage:FindFirstChild("MandelaEffects")
	return assets and assets:FindFirstChild("Spikes")
end

-- a glowing spindle with its base at `cframe`, pointing along its look vector;
-- it starts as a stub, so tween Size.Z and CFrame (base * (0, 0, -length / 2)) to grow it
local function spindle(cframe, color, width, lifetime)
	local part = effectPart(Enum.PartType.Block, color, Vector3.new(width, width, 0.2), cframe * CFrame.new(0, 0, -0.1), lifetime)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function randomAngles()
	return CFrame.Angles(math.random() * math.pi * 2, math.random() * math.pi * 2, math.random() * math.pi * 2)
end

-- splinters of light flying apart, like breaking glass
local function shatter(position, color, count, speed)
	for _ = 1, count do
		local direction = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
		direction = direction.Magnitude > 0.01 and direction.Unit or Vector3.yAxis
		local shard = effectPart(
			Enum.PartType.Block,
			math.random() < 0.5 and WHITE or color,
			Vector3.new(0.08, 0.4 + math.random() * 0.8, 0.3 + math.random() * 0.6),
			CFrame.new(position) * randomAngles(),
			0.6
		)
		local goal = CFrame.new(position + direction * speed * (0.6 + math.random() * 0.6)) * randomAngles()
		tween(shard, 0.55, { CFrame = goal, Transparency = 1 })
	end
end

-- a circle of short glowing bars; `place` lays it out (call it every frame to spin it)
local function segmentRing(count, color, thickness, lifetime)
	local bars = {}
	for i = 1, count do
		bars[i] = effectPart(Enum.PartType.Block, color, Vector3.new(thickness, thickness, 1), CFrame.new(), lifetime)
	end
	local function place(center, radius, angle)
		local length = math.max(2 * math.pi * radius / count * 0.7, 0.05)
		for i, bar in ipairs(bars) do
			local a = angle + i / count * 2 * math.pi
			local position = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			bar.Size = Vector3.new(thickness, thickness, length)
			bar.CFrame = CFrame.lookAt(position, position + Vector3.new(-math.sin(a), 0, math.cos(a)))
		end
	end
	return bars, place
end

-- a see-through copy of a character, frozen as it stands now
local function ghostOf(model, color)
	local ghost = Instance.new("Model")
	ghost.Name = "PossibilityGhost"
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
			local ok, copy = pcall(part.Clone, part)
			if ok and copy then
				for _, child in ipairs(copy:GetDescendants()) do
					if child:IsA("DataModelMesh") then
						if child:IsA("SpecialMesh") then
							child.TextureId = ""
						end
					else
						child:Destroy()
					end
				end
				if copy:IsA("MeshPart") then
					pcall(function()
						copy.TextureID = ""
					end)
				end
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
				copy.CastShadow = false
				copy.Material = Enum.Material.ForceField
				copy.Color = color
				copy.Transparency = 0
				copy.Parent = ghost
			end
		end
	end
	return ghost
end

-- giant backbones bursting out of the ground, then sinking back
local function erupt(ground, color)
	ring(ground + Vector3.new(0, 0.2, 0), color, 2, 18, 0.4, 0.4)
	local asset = spikesAsset()
	if asset then
		local spikes = asset:Clone()
		local size = asset.Size * 5
		local turn = CFrame.Angles(0, math.random() * math.pi * 2, 0)
		local up = CFrame.new(ground + Vector3.new(0, size.Y * 0.35, 0)) * turn
		local down = CFrame.new(ground - Vector3.new(0, size.Y * 0.6, 0)) * turn
		spikes.Size = size
		spikes.Color = color
		spikes.CFrame = down
		spikes.Parent = folder
		tween(spikes, 0.12, { CFrame = up }, Enum.EasingStyle.Back)
		task.delay(0.7, function()
			if spikes.Parent then
				TweenService:Create(spikes, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = down, Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(spikes, 1.3)
	end
	-- and a crown of bone spears around it
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + math.random() * 0.4
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local from = ground + out * 1.5
		local base = CFrame.lookAt(from, from + (Vector3.yAxis * 2 + out).Unit)
		local length = 5 + math.random() * 3
		local spear = spindle(base, color, 0.6, 1.1)
		tween(spear, 0.12, { Size = Vector3.new(0.6, 0.6, length), CFrame = base * CFrame.new(0, 0, -length / 2) }, Enum.EasingStyle.Back)
		task.delay(0.6, tween, spear, 0.35, { Transparency = 1 })
	end
	burst(ground + Vector3.new(0, 1, 0), {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(200, 190, 175)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(12, 22),
		SpreadAngle = Vector2.new(180, 20),
		Drag = 4,
	}, 14)
end

local effects = {}

-- the set's power flares up around its new wielder
function effects.Equip(character, color)
	local feet, root = feetOf(character)
	if not feet then
		return
	end
	VFX.Play("Shared/Shockwave", CFrame.new(feet + Vector3.new(0, 0.2, 0)), { color = color, scale = 0.7 })
	VFX.Play("Shared/AuraBurst", root, { color = color, offset = CFrame.new(0, -0.5, 0) })
	VFX.Play("Shared/Sparks", root.Position, { color = color })
	if character == Players.LocalPlayer.Character then
		VFX.Shake(nil, "Light")
	end
end

-- the backbones tear out: a pillar of light, the ground cratered, the aura
-- flaring up, an impact frame for the wielder and anyone close, and a quake
function effects.Overcharge(character, color)
	local feet, root = feetOf(character)
	if not feet then
		return
	end
	local pillar = effectPart(Enum.PartType.Cylinder, color, Vector3.new(60, 7, 7), CFrame.new(feet + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.6)
	pillar.Transparency = 0.2
	tween(pillar, 0.6, { Size = Vector3.new(70, 0.3, 0.3), Transparency = 1 })
	VFX.Play("Shared/Shockwave", CFrame.new(feet + Vector3.new(0, 0.2, 0)), { color = color, scale = 2.2 })
	VFX.Play("Shared/BigImpact", root.Position, { color = color, scale = 1.6 })
	VFX.Play("Shared/AuraBurst", root, { color = color, scale = 1.3, duration = 1.2, offset = CFrame.new(0, -0.5, 0) })
	VFX.Crater(feet, 9)
	VFX.Shake(root.Position, "Heavy", 70)
	VFX.ImpactFrameNear(root.Position, 20, character)
end

-- a blast wave along the ground (a black hole detonating, the overcharged
-- tornado's blast, a spike finisher): rings and dust racing out, the ground
-- cratered, and an impact frame for anyone it caught
function effects.Shockwave(position, radius, color)
	local scale = radius / 12
	VFX.Play("Shared/Shockwave", CFrame.new(position + Vector3.new(0, 0.2, 0)), { color = color, scale = scale })
	VFX.Play("Shared/BigImpact", position + Vector3.new(0, 2, 0), { color = color, scale = math.clamp(scale, 0.6, 1.6) })
	VFX.Crater(position, math.clamp(radius * 0.45, 3, 14))
	VFX.Shake(position, radius >= 15 and "Heavy" or "Medium", radius * 3)
	VFX.ImpactFrameNear(position, radius + 3)
end

-- a crescent swipe across whatever the weapon hit; a finisher crosses it with
-- a second one, speed lines and a ring of dust
function effects.Slash(position, direction, critical, color)
	color = color or WHITE
	local angle = math.random(-55, 55) + (math.random() < 0.5 and 180 or 0)
	VFX.Play("Shared/SlashArc", position, { color = color, rotation = angle, scale = critical and 1.5 or 1 })
	VFX.Play("Shared/Impact", position, { color = color, scale = critical and 1.3 or 0.8 })
	if critical then
		VFX.Play("Shared/SlashArc", position, { color = color, rotation = angle + 70, scale = 1.3 })
		VFX.Play("Shared/SpeedLines", position, { scale = 0.6 })
		local ground = VFX.Ground(position)
		if ground and position.Y - ground.Y < 8 then
			VFX.Play("Shared/Shockwave", CFrame.new(ground + Vector3.new(0, 0.2, 0)), { color = color, scale = 0.6 })
		end
		VFX.Shake(position, "Medium", 30)
	else
		VFX.Shake(position, "Light", 30)
	end
end

-- a fist landing, kept small (a punch is the weakest attack): a little
-- jagged burst on the body and a ring of air blown out along the punch with
-- streaks out the far side; the finisher's are a bit bigger, with a second
-- ring further along and a light shake
function effects.FistHit(position, direction, critical, color)
	color = color or WHITE
	-- the rings lie across the punch: the holder's up points along it
	local along = CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	VFX.Play("Shared/Impact", position, { color = color, scale = critical and 0.75 or 0.45 })
	VFX.Play("Shared/PunchRing", along, { color = color, scale = critical and 0.65 or 0.35 })
	if critical then
		task.delay(0.05, function()
			VFX.Play("Shared/PunchRing", along * CFrame.new(0, 1.5, 0), { color = color, scale = 0.5 })
		end)
		VFX.Shake(position, "Light", 20)
	end
end

-- Mandela Z, Axe Boomerang: a copy of the caster's worn axe flies the same
-- path the server uses, spinning like a wheel turned to face this client's
-- camera (so everyone sees the blade, not its edge): out to `to` (easing to
-- a stop), or until it's recalled, then home to the right hand until the
-- server says it's caught
local THROW_SPIN = 26 -- radians per second
local CATCH_DISTANCE = 2.5

-- the axe is thin along X: point X at the camera and its flat side faces it
local function facingCamera(position)
	local toCamera = workspace.CurrentCamera.CFrame.Position - position
	toCamera = toCamera.Magnitude > 0.01 and toCamera.Unit or Vector3.zAxis
	local up = math.abs(toCamera.Y) < 0.98 and Vector3.yAxis or Vector3.zAxis
	return CFrame.fromMatrix(position, toCamera, (up - toCamera * up:Dot(toCamera)).Unit)
end

function effects.AxeThrow(character, from, to, startedAt, outTime, returnSpeed, color)
	local worn = character:FindFirstChild("SkillSetWearables")
	worn = worn and worn:FindFirstChild("Axe")
	local hand = character:FindFirstChild("RightHand")
	if not worn or not hand then
		return
	end
	local axe = worn:Clone()
	for _, instance in ipairs({ axe, table.unpack(axe:GetDescendants()) }) do
		if instance:IsA("JointInstance") or instance:IsA("WeldConstraint") then
			instance:Destroy()
		elseif instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanQuery = false
			instance.CanTouch = false
			-- the server may already have hidden the worn one
			instance.Transparency = instance:GetAttribute("ShownTransparency") or instance.Transparency
		elseif instance:IsA("ParticleEmitter") or instance:IsA("Light") then
			if instance:GetAttribute("ShownEnabled") ~= nil then
				instance.Enabled = instance:GetAttribute("ShownEnabled")
			end
		elseif instance:IsA("Trail") then
			instance.Color = ColorSequence.new(WHITE, color)
			instance.Enabled = true
		end
	end
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 10
	glow.Brightness = 2
	glow.Parent = axe
	axe.CFrame = facingCamera(from)
	axe.Parent = folder
	-- wind rings and crescent afterimages whirl round it in flight
	local wind = VFX.Play("Mandela/AxeWind", CFrame.new(from), { color = color, duration = 5 })
	VFX.Play("Shared/Impact", from, { color = color, scale = 0.5 })

	local position = from
	local spin = 0
	local returning = false
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local t = workspace:GetServerTimeNow() - startedAt
		local done = not character.Parent or not hand.Parent or t > 5
		local recalled = character:GetAttribute("WeaponRecalled") == true
		if not done and t < outTime and not recalled then
			local progress = math.max(t / outTime, 0)
			position = from + (to - from) * (1 - (1 - progress) ^ 2)
		elseif not done then
			if not returning then
				returning = true
				-- a recalled axe turns back from wherever it got to
				if not recalled then
					position = to
				end
			end
			local offset = hand.Position - position
			if offset.Magnitude <= CATCH_DISTANCE or not character:GetAttribute("WeaponThrown") then
				done = true
			else
				position += offset.Unit * math.min(returnSpeed * dt, offset.Magnitude)
			end
		end
		if done then
			connection:Disconnect()
			if hand.Parent then
				VFX.Play("Shared/Impact", hand.Position, { color = color, scale = 0.6 })
			end
			VFX.Stop(wind)
			axe:Destroy()
			return
		end
		spin += THROW_SPIN * dt
		axe.CFrame = facingCamera(position) * CFrame.Angles(spin, 0, 0)
		if wind then
			wind.CFrame = CFrame.new(position)
		end
	end)
end

-- Mandela Z overcharged, Spine Lash: a whip of vertebrae with red spikes
-- shoots from the left hand to `to`, then snaps back
local BONE_COLOR = Color3.fromRGB(60, 52, 50)
local LASH_SPACING = 1.1 -- studs between vertebrae

function effects.SpineLash(character, from, to, extendTime, retractTime, color)
	local hand = character:FindFirstChild("LeftHand") or character:FindFirstChild("HumanoidRootPart")
	if not hand then
		return
	end
	local total = extendTime + retractTime
	local count = math.max(math.ceil((to - from).Magnitude / LASH_SPACING), 1)
	local vertebrae = {}
	for i = 1, count do
		local bone = effectPart(Enum.PartType.Block, BONE_COLOR, Vector3.new(0.75, 0.55, 0.8), CFrame.new(from), total + 0.5)
		bone.Material = Enum.Material.Slate
		bone.Transparency = 1
		local spike
		if i % 2 == 0 then
			spike = spindle(CFrame.new(from), color, 0.25, total + 0.5)
			spike.Size = Vector3.new(0.25, 1.2, 0.25)
			spike.Transparency = 1
		end
		vertebrae[i] = { bone = bone, spike = spike }
	end
	local tip = spindle(CFrame.new(from), color, 0.55, total + 0.5)
	tip.Size = Vector3.new(0.55, 0.55, 2)
	-- red sparks and a glow trail the tip
	VFX.Play("Mandela/LashTip", tip, { color = color, duration = total })
	VFX.Play("Shared/Impact", from, { color = color, scale = 0.6 })
	-- a glowing cord running down the middle
	local anchor = effectPart(Enum.PartType.Block, WHITE, Vector3.one * 0.1, CFrame.new(), total + 0.5)
	anchor.Transparency = 1
	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor
	local cord = Instance.new("Beam")
	cord.Attachment0 = a0
	cord.Attachment1 = a1
	cord.Color = ColorSequence.new(color)
	cord.Width0 = 0.7
	cord.Width1 = 0.4
	cord.Texture = "rbxassetid://7216849788"
	cord.TextureMode = Enum.TextureMode.Wrap
	cord.TextureLength = 3
	cord.TextureSpeed = 4
	cord.LightEmission = 1
	cord.Transparency = NumberSequence.new(0.15)
	cord.FaceCamera = true
	cord.Parent = anchor

	local pieces = { tip, anchor }
	for _, v in ipairs(vertebrae) do
		table.insert(pieces, v.bone)
		if v.spike then
			table.insert(pieces, v.spike)
		end
	end
	local startedAt = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - startedAt
		if t >= total or not hand.Parent then
			connection:Disconnect()
			for _, piece in ipairs(pieces) do
				piece:Destroy()
			end
			return
		end
		local base = hand.Position
		local tipPosition
		if t < extendTime then
			tipPosition = from + (to - from) * (t / extendTime)
		else
			local back = (t - extendTime) / retractTime
			tipPosition = to:Lerp(base, 1 - (1 - back) ^ 2)
		end
		local span = tipPosition - base
		local length = span.Magnitude
		local direction = length > 0.01 and span.Unit or Vector3.zAxis
		local side = direction:Cross(Vector3.yAxis)
		side = side.Magnitude > 0.01 and side.Unit or Vector3.xAxis
		local shown = math.min(math.floor(length / LASH_SPACING), count)
		for i, v in ipairs(vertebrae) do
			if i <= shown then
				local along = i * LASH_SPACING
				local ripple = math.sin(i * 0.8 - t * 35) * 0.25
				local position = base + direction * along + side * ripple
				local cframe = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, 0, i * 0.6)
				v.bone.CFrame = cframe
				v.bone.Transparency = 0
				if v.spike then
					v.spike.CFrame = cframe * CFrame.new(0, 0.65, 0)
					v.spike.Transparency = 0
				end
			else
				v.bone.Transparency = 1
				if v.spike then
					v.spike.Transparency = 1
				end
			end
		end
		tip.CFrame = CFrame.lookAt(tipPosition, tipPosition + direction)
		a0.WorldPosition = base
		a1.WorldPosition = tipPosition
	end)
end

-- red spikes tearing out of whatever Spine Lash strikes (or an overcharged
-- finisher), cratering the ground under it, with an impact frame
function effects.BoneSpikes(position, color, scale)
	scale = scale or 1
	local asset = spikesAsset()
	if asset then
		local spikes = asset:Clone()
		local size = asset.Size * 1.8 * scale
		spikes.Size = size * 0.15
		spikes.Color = color
		spikes.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 0.6 - 0.3, math.random() * math.pi * 2, math.random() * 0.6 - 0.3)
		spikes.Parent = folder
		tween(spikes, 0.1, { Size = size }, Enum.EasingStyle.Back)
		task.delay(0.3, tween, spikes, 0.3, { Transparency = 1 })
		Debris:AddItem(spikes, 0.7)
	end
	for _ = 1, 5 do
		local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
		direction = direction.Magnitude > 0.01 and direction.Unit or Vector3.yAxis
		local base = CFrame.lookAt(position, position + direction)
		local length = (2.5 + math.random() * 1.5) * scale
		local width = 0.35 * scale
		local spear = spindle(base, color, width, 0.7)
		tween(spear, 0.08, { Size = Vector3.new(width, width, length), CFrame = base * CFrame.new(0, 0, -length / 2) })
		task.delay(0.3, tween, spear, 0.3, { Transparency = 1 })
	end
	VFX.Play("Shared/BigImpact", position, { color = color, scale = 0.8 * scale })
	VFX.Crater(position, 3.5 * scale)
	VFX.Shake(position, "Medium", 40)
	VFX.ImpactFrameNear(position, 6 * scale)
end

-- Mandela V, Overcome the Possibility: the mask breaks and the zone turns
-- into a mirror world. A ring of tall glass panes rises round it, reflecting
-- the scene, and cracks a little more every second of the countdown; glints
-- drift up inside; everyone caught leaves a mirror-glass reflection of
-- themselves where they stood, tethered to them; and for whoever is inside,
-- the world greys out behind faint cracks across the screen.
-- PossibilitySnap shatters it all.
local MIRROR_PANES = 14
local MIRROR_HEIGHT = 17 -- studs, give or take
local MIRROR_TINT = Color3.fromRGB(225, 245, 238)
local GLINT_TEXTURE = "rbxassetid://298984512" -- a sharp four-point star
local SHARDS_PER_PANE = 9
local possibilities = {} -- cast id -> what to clean up

local function clearPossibility(castId)
	local state = possibilities[castId]
	if not state then
		return nil
	end
	possibilities[castId] = nil
	if state.connection then
		state.connection:Disconnect()
	end
	for _, instance in ipairs(state.instances) do
		instance:Destroy()
	end
	return state
end

-- a part turned to mirror glass
local function mirrorGlass(part, transparency)
	part.Material = Enum.Material.Glass
	part.Reflectance = 0.6
	part.Color = MIRROR_TINT
	part.Transparency = transparency
end

-- Cracks are drawn as lines (no texture): rays branching out from a point,
-- each with a kink, reaching further as `progress` goes from 0 to 1, and at
-- 1 a web joining neighbouring rays. `line(from, to)` draws one segment;
-- `crack` keeps the origin, rays and reach between calls.
local function spreadCracks(crack, progress, maxReach, line, clamp)
	if #crack.rays == 0 then
		local n = crack.rayCount
		for i = 1, n do
			table.insert(crack.rays, (i + math.random() * 0.6) / n * math.pi * 2)
		end
	end
	local reach = maxReach * (0.25 + 0.75 * progress)
	for _, angle in ipairs(crack.rays) do
		local direction = Vector2.new(math.cos(angle), math.sin(angle))
		local side = Vector2.new(-direction.Y, direction.X)
		local from = clamp(crack.origin + direction * crack.reach)
		local kink = clamp(crack.origin + direction * (crack.reach + reach) / 2 + side * (math.random() - 0.5) * reach * 0.15)
		local to = clamp(crack.origin + direction * reach)
		line(from, kink)
		line(kink, to)
	end
	if progress >= 1 then
		for i, angle in ipairs(crack.rays) do
			local nextAngle = crack.rays[i % #crack.rays + 1]
			local r = reach * (0.3 + math.random() * 0.25)
			line(clamp(crack.origin + Vector2.new(math.cos(angle), math.sin(angle)) * r), clamp(crack.origin + Vector2.new(math.cos(nextAngle), math.sin(nextAngle)) * r))
		end
	end
	crack.reach = reach
end

-- a thin bright crack across a pane, through both faces (points in the pane's own X/Y)
local function paneLine(part, from, to)
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return
	end
	local middle = (from + to) / 2
	local line = Instance.new("Part")
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.CastShadow = false
	line.Material = Enum.Material.Neon
	line.Color = WHITE
	line.Transparency = 0.1
	line.Size = Vector3.new(0.07, delta.Magnitude, part.Size.Z + 0.06)
	line.CFrame = part.CFrame * CFrame.new(middle.X, middle.Y, 0) * CFrame.Angles(0, 0, math.atan2(delta.Y, delta.X) - math.pi / 2)
	line.Parent = part
end

local function crackPane(pane, progress)
	local part = pane.part
	if not part.Parent then
		return
	end
	local half = Vector2.new(part.Size.X, part.Size.Y) / 2 * 0.97
	spreadCracks(pane.crack, progress, math.max(half.X, half.Y) * 1.3, function(from, to)
		paneLine(part, from, to)
	end, function(point)
		return Vector2.new(math.clamp(point.X, -half.X, half.X), math.clamp(point.Y, -half.Y, half.Y))
	end)
end

-- a pane bursts: shards of mirror glass fly outward, spinning, and fade
local function shatterPane(pane, center)
	local part = pane.part
	if not part.Parent then
		return
	end
	local count = math.max(3, math.round(SHARDS_PER_PANE * VFX.Quality()))
	for _ = 1, count do
		local spot = CFrame.new((math.random() - 0.5) * part.Size.X, (math.random() - 0.5) * part.Size.Y, 0)
		local size = Vector3.new(0.6 + math.random() * 1.8, 0.8 + math.random() * 2.4, 0.12)
		local shard = effectPart(Enum.PartType.Block, MIRROR_TINT, size, part.CFrame * spot * randomAngles(), 1)
		mirrorGlass(shard, 0.25)
		local outward = (shard.Position - center) * Vector3.new(1, 0, 1)
		outward = outward.Magnitude > 0.1 and outward.Unit or pane.out
		local goal = shard.Position + outward * (10 + math.random() * 12) + Vector3.new(0, math.random() * 6 - 4, 0)
		tween(shard, 0.8, { CFrame = CFrame.new(goal) * randomAngles(), Transparency = 1 })
	end
	part:Destroy()
end

-- a marked target's mirror-glass reflection where it stood, tethered to it
local function possibilityGhost(state, model, color)
	if not model.Parent then
		return
	end
	local ghost = ghostOf(model, color)
	table.insert(state.instances, ghost)
	for _, part in ipairs(ghost:GetChildren()) do
		mirrorGlass(part, 0.35)
	end
	ghost.Parent = folder
	local torso = ghost:FindFirstChild("UpperTorso") or ghost:FindFirstChild("Torso")
	local targetRoot = model:FindFirstChild("HumanoidRootPart")
	if torso and targetRoot then
		local fromGhost = Instance.new("Attachment")
		fromGhost.Parent = torso
		local toTarget = Instance.new("Attachment")
		toTarget.Name = "PossibilityTether"
		toTarget.Parent = targetRoot
		table.insert(state.instances, toTarget)
		local tether = Instance.new("Beam")
		tether.Attachment0 = fromGhost
		tether.Attachment1 = toTarget
		tether.Color = ColorSequence.new(WHITE, color)
		tether.Width0 = 0.25
		tether.Width1 = 0.1
		tether.LightEmission = 1
		tether.Transparency = NumberSequence.new(0.2, 0.6)
		tether.FaceCamera = true
		tether.Texture = "rbxassetid://7216849788"
		tether.TextureMode = Enum.TextureMode.Wrap
		tether.TextureLength = 3
		tether.TextureSpeed = 3
		tether.Parent = torso
	end
end

-- for someone inside: the world goes black and white, like the ultimate's dome
local function possibilityGrade(state, lifetime)
	if state.grade then
		return
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "PossibilityGrade"
	grade.Parent = Lighting
	tween(grade, 0.3, { Saturation = -1, Contrast = 0.2 })
	state.grade = grade
	-- removed by the snap, or by the fallback below
	Debris:AddItem(grade, lifetime + 1)
end

function effects.Possibility(castId, character, center, radius, delay, models, overcharged, color)
	local state = { instances = {}, caster = character, lifetime = delay + 3 }
	possibilities[castId] = state
	local function keep(instance)
		table.insert(state.instances, instance)
		return instance
	end

	local head = character and character:FindFirstChild("Head")
	if head then
		VFX.Play("Shared/Impact", head.Position, { color = color, scale = 0.8 })
		shatter(head.Position, color, 14, 8)
	end
	if overcharged then
		flash(center + Vector3.new(0, 3, 0), color, 2, 12, 0.35)
	end

	-- the mirror world: a ring of tall glass panes rising round the zone,
	-- each facing the middle and leaning a little its own way
	local lifetime = delay + 3
	local ground = VFX.Ground(center) or center
	local paneWidth = 2 * math.pi * radius / MIRROR_PANES * 1.04
	local paneModel = Instance.new("Model")
	paneModel.Name = "MirrorPanes"
	local panes = {}
	for i = 1, MIRROR_PANES do
		local angle = (i + math.random() * 0.2) / MIRROR_PANES * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local height = MIRROR_HEIGHT * (0.8 + math.random() * 0.45)
		local base = ground + out * radius
		local standing = CFrame.lookAt(base, base - out)
			* CFrame.Angles(math.rad(math.random(-8, 4)), 0, math.rad(math.random(-5, 5)))
			* CFrame.new(0, height / 2, 0)
		local pane = effectPart(Enum.PartType.Block, MIRROR_TINT, Vector3.new(paneWidth, height, 0.3), standing * CFrame.new(0, -height, 0), lifetime + 1)
		mirrorGlass(pane, 0.5)
		pane.Parent = paneModel
		tween(pane, 0.4, { CFrame = standing }, Enum.EasingStyle.Back)
		local origin = Vector2.new((math.random() - 0.5) * paneWidth * 0.5, (math.random() - 0.5) * height * 0.5)
		table.insert(panes, { part = pane, out = out, crack = { origin = origin, rays = {}, rayCount = 5, reach = 0 } })
	end
	-- crisp bright edges on every pane
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = color:Lerp(WHITE, 0.5)
	outline.OutlineTransparency = 0.15
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = paneModel
	outline.Parent = paneModel
	paneModel.Parent = folder
	Debris:AddItem(paneModel, lifetime + 1)
	state.panes = panes
	state.paneModel = paneModel

	-- glints of light drifting up inside the mirror
	local motes = keep(effectPart(Enum.PartType.Block, WHITE, Vector3.new(radius * 2, 0.2, radius * 2), CFrame.new(center + Vector3.new(0, 0.3, 0)), lifetime))
	motes.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = GLINT_TEXTURE
	emitter.Color = ColorSequence.new(WHITE, MIRROR_TINT)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Rotation = NumberRange.new(0, 90)
	emitter.Rate = 35
	emitter.Parent = motes

	-- for anyone inside (the zone is a column, so up in the air too)
	local myCharacter = Players.LocalPlayer.Character
	local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
	if myRoot then
		local offset = myRoot.Position - center
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + 4 then
			possibilityGrade(state, lifetime)
		end
	end

	-- each target leaves a mirror-glass reflection where it stood, tethered to it
	for _, model in ipairs(models) do
		possibilityGhost(state, model, color)
	end

	-- the glass cracks further every second, counting down
	local seconds = math.ceil(delay)
	for second = 1, seconds - 1 do
		task.delay(second, function()
			if possibilities[castId] ~= state then
				return
			end
			local progress = second / (seconds - 1)
			for _, pane in ipairs(panes) do
				crackPane(pane, progress)
			end
			for _ = 1, 3 do
				local pane = panes[math.random(#panes)].part
				if pane.Parent then
					local spot = CFrame.new((math.random() - 0.5) * pane.Size.X * 0.8, (math.random() - 0.5) * pane.Size.Y * 0.8, 0)
					VFX.Play("Shared/Sparks", pane.CFrame * spot, { color = WHITE, scale = 0.6 })
				end
			end
			VFX.Shake(center, "Light", radius * 2)
		end)
	end
	-- in case the snap never arrives
	task.delay(lifetime, function()
		if possibilities[castId] == state then
			clearPossibility(castId)
		end
	end)
end

-- Mandela's Knife pinning someone (three in a row): a red impact and
-- splinters on them, and while they're stunned (`stunTime`, 0 if they
-- weren't) a red outline holds them
local PIN_RED = Color3.fromRGB(200, 30, 45)
function effects.KnifePin(model, stunTime)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	VFX.Play("Shared/Impact", root.Position, { color = PIN_RED, scale = 0.7 })
	shatter(root.Position, PIN_RED, 10, 6)
	if stunTime > 0 then
		local outline = Instance.new("Highlight")
		outline.FillColor = PIN_RED
		outline.FillTransparency = 0.7
		outline.OutlineColor = PIN_RED
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Adornee = model
		outline.Parent = model
		task.delay(stunTime, function()
			tween(outline, 0.2, { FillTransparency = 1, OutlineTransparency = 1 })
		end)
		Debris:AddItem(outline, stunTime + 0.25)
	end
end

-- someone came into the zone while it held: they're marked where they came in
function effects.PossibilityMark(castId, models, color)
	local state = possibilities[castId]
	if not state then
		return
	end
	for _, model in ipairs(models) do
		possibilityGhost(state, model, color)
		if model == Players.LocalPlayer.Character then
			possibilityGrade(state, state.lifetime)
		end
	end
end

-- reality corrects itself: the mirror world shatters (every pane bursts into
-- flying glass), an impact frame for the
-- caster and everyone inside, the colour slams back, every target bursts
-- like glass where it's snapped back to, and overcharged, backbones erupt there
function effects.PossibilitySnap(castId, center, radius, positions, overcharged, color)
	local state = clearPossibility(castId)
	if state and state.panes then
		for _, pane in ipairs(state.panes) do
			shatterPane(pane, center)
		end
		state.paneModel:Destroy()
	end
	if state and state.grade and state.grade.Parent then
		local grade = state.grade
		grade.Saturation = 0.6
		grade.Contrast = 0.35
		grade.Brightness = 0.25
		grade.TintColor = WHITE
		tween(grade, 0.45, { Saturation = 0, Contrast = 0, Brightness = 0 })
		Debris:AddItem(grade, 0.5)
	end
	VFX.Play("Shared/Shockwave", CFrame.new(center + Vector3.new(0, 0.2, 0)), { color = color, scale = radius / 10 })
	VFX.Play("Shared/BigImpact", center + Vector3.new(0, 3, 0), { color = color, scale = 1.4 })
	VFX.Shake(center, "Heavy", radius * 3)
	VFX.ImpactFrameNear(center, radius + 4, state and state.caster)
	for _, position in ipairs(positions) do
		VFX.Play("Shared/Impact", position, { color = WHITE, scale = 1.3 })
		shatter(position, color, 18, 12)
		if overcharged then
			erupt(position - Vector3.new(0, 3, 0), color)
			VFX.Crater(position, 6)
		end
	end
end

-- Mandela F, Place Where Dream Ends: the wrong timeline. A dome of mirror
-- glass assembles from the ground up where the server's (invisible, solid)
-- one stands, and the slam sends a wave of glass tiles out across the
-- ground that turns it into a rolling ocean of black glass; for anyone
-- inside, the world goes black and white; the glass cracks further every
-- second and with every recorded hit, each of which leaves a frozen red
-- reflection of the target.
-- RewriteSnap: an impact frame, the reflections slam into their targets,
-- backbones erupt under them, the ocean breaks apart and all the glass
-- shatters.
local rewrites = {} -- cast id -> what to clean up

local function clearRewrite(castId)
	local state = rewrites[castId]
	if not state then
		return nil
	end
	rewrites[castId] = nil
	if state.connection then
		state.connection:Disconnect()
	end
	for _, instance in ipairs(state.instances) do
		instance:Destroy()
	end
	return state
end

-- The black glass ocean: the slam sends a wave of glass tiles flipping up
-- out of the ground and racing out to the dome's edge; behind it they
-- settle into a floor of black glass that keeps rolling in slow swells.
-- Every tile is placed on the ground under it once, then all of them move
-- together each frame (BulkMoveTo). breakOcean throws them up and fades
-- them at the Rewrite.
local OCEAN_TILE = 7 -- studs across a tile (bigger on lower graphics quality)
local OCEAN_COLOR = Color3.fromRGB(8, 8, 12)
local OCEAN_REFLECTANCE = 0.2 -- a sheen; much more and it mirrors the sky white
local WAVE_SPEED = 120 -- studs per second the tile wave spreads
local WAVE_TIME = 0.4 -- seconds a tile takes to flip up and land
local WAVE_HEIGHT = 3.5 -- studs a tile jumps as the wave passes
local SWELL_HEIGHT = 0.45 -- studs the ocean rises and falls
local SWELL_LENGTH = 26 -- studs between swells
local SWELL_SPEED = 2.2 -- radians per second
local BREAK_TIME = 0.6 -- seconds the tiles take to fly apart at the Rewrite

local function removeOcean(ocean)
	if ocean.connection then
		ocean.connection:Disconnect()
		ocean.connection = nil
	end
	ocean.model:Destroy()
end

local function glassOcean(origin, radius)
	local size = OCEAN_TILE / math.sqrt(math.max(VFX.Quality(), 0.25))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore = CollectionService:GetTagged("RewriteWall")
	table.insert(ignore, folder)
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore

	local model = Instance.new("Model")
	model.Name = "GlassOcean"
	local tiles, parts = {}, {}
	local steps = math.floor(radius / size)
	for ix = -steps, steps do
		for iz = -steps, steps do
			local offset = Vector3.new(ix * size, 0, iz * size)
			local distance = offset.Magnitude
			local hit = distance <= radius - size * 0.5
				and workspace:Raycast(origin + offset + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
			if hit and hit.Normal.Y > 0.5 then
				local part = Instance.new("Part")
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Material = Enum.Material.Glass
				part.Color = OCEAN_COLOR
				part.Reflectance = OCEAN_REFLECTANCE
				part.Transparency = 1
				part.Size = Vector3.new(size * 1.04, 0.4, size * 1.04)
				part.CFrame = CFrame.new(hit.Position)
				part.Parent = model
				local radial = distance > 0.1 and offset.Unit or Vector3.xAxis
				table.insert(parts, part)
				table.insert(tiles, {
					part = part,
					base = hit.Position + Vector3.new(0, 0.2, 0),
					distance = distance,
					axis = Vector3.new(-radial.Z, 0, radial.X), -- across the wave, to flip and tilt about
					flip = math.random() < 0.5 and 1 or -1,
					lift = 0.6 + math.random() * 0.4,
					burst = Vector3.new((math.random() - 0.5) * 8, 8 + math.random() * 12, (math.random() - 0.5) * 8),
					shown = false,
				})
			end
		end
	end
	model.Parent = folder

	local ocean = { model = model, startedAt = os.clock() }
	local frames = {}
	ocean.connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - ocean.startedAt
		local breaking = ocean.brokenAt and math.min((os.clock() - ocean.brokenAt) / BREAK_TIME, 1)
		for i, tile in ipairs(tiles) do
			local since = t - tile.distance / WAVE_SPEED -- since the wave reached it
			local frame
			if since < 0 then
				frame = CFrame.new(tile.base - Vector3.new(0, 2, 0))
			else
				if not tile.shown then
					tile.shown = true
					tile.part.Transparency = 0.05
				end
				-- the swell, and the tile tilted along its slope
				local phase = tile.distance / SWELL_LENGTH * math.pi * 2 - t * SWELL_SPEED
				local height = math.sin(phase) * SWELL_HEIGHT
				local angle = -math.cos(phase) * SWELL_HEIGHT * math.pi * 2 / SWELL_LENGTH
				-- the wave passing: a jump and a flip
				if since < WAVE_TIME then
					local k = since / WAVE_TIME
					height += math.sin(k * math.pi) * WAVE_HEIGHT * tile.lift
					angle += k * math.pi * tile.flip
				end
				frame = CFrame.new(tile.base + Vector3.new(0, height, 0)) * CFrame.fromAxisAngle(tile.axis, angle)
			end
			if breaking then
				frame = (frame + tile.burst * breaking) * CFrame.fromAxisAngle(tile.axis, breaking * 4 * tile.flip)
				tile.part.Transparency = 0.05 + 0.95 * breaking
			end
			frames[i] = frame
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		if breaking and breaking >= 1 then
			removeOcean(ocean)
		end
	end)
	return ocean
end

-- the world in black and white while the local player is inside
local function enterRewrite(state)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RewriteGrade"
	grade.Parent = Lighting
	tween(grade, 0.3, { Saturation = -1, Contrast = 0.2 })
	state.grade = grade
end

local function leaveRewrite(state)
	if state.grade then
		state.grade:Destroy()
		state.grade = nil
	end
end

local REWRITE_ASSEMBLE_TIME = 0.7 -- seconds from the bottom ring to the top one
local REWRITE_CRACK_SHARE = 0.5 -- of the panes that crack further each second (there are many)

function effects.Rewrite(castId, character, center, radius, duration, frames, sizes, color)
	local state = { instances = {}, ghosts = {}, caster = character, progress = 0 }
	rewrites[castId] = state
	local function keep(instance)
		table.insert(state.instances, instance)
		return instance
	end
	local lifetime = duration + 4

	-- the axe slam
	local ground = VFX.Ground(center) or center
	VFX.Play("Shared/BigImpact", ground + Vector3.new(0, 2, 0), { color = color, scale = 1.6 })
	VFX.Play("Shared/Shockwave", CFrame.new(ground + Vector3.new(0, 0.2, 0)), { color = color, scale = radius / 10 })
	VFX.Crater(ground, 7)
	VFX.Shake(center, "Heavy", radius * 2)
	ring(ground + Vector3.new(0, 0.3, 0), color, 4, radius * 2, 0.5, 0.5)
	state.ocean = glassOcean(ground, radius)

	-- the dome assembles from the ground up where the solid one stands: each
	-- pane flies in from outside, the low ones first
	-- (not kept: the panes outlive the state long enough to shatter)
	local paneModel = Instance.new("Model")
	paneModel.Name = "RewritePanes"
	Debris:AddItem(paneModel, lifetime + 1)
	local panes = {}
	for i, frame in ipairs(frames) do
		local size = sizes[i]
		local out = frame.Position - center
		out = out.Magnitude > 0.1 and out.Unit or Vector3.yAxis
		local pane = effectPart(Enum.PartType.Block, MIRROR_TINT, Vector3.new(size.X, size.Y, 0.3), frame + out * 25, lifetime + 1)
		mirrorGlass(pane, 1)
		pane.Parent = paneModel
		local rise = math.clamp((frame.Position.Y - center.Y) / radius, 0, 1)
		task.delay(rise * REWRITE_ASSEMBLE_TIME, function()
			if pane.Parent then
				tween(pane, 0.35, { CFrame = frame, Transparency = 0.55 }, Enum.EasingStyle.Back)
			end
		end)
		local flat = out * Vector3.new(1, 0, 1)
		local origin = Vector2.new((math.random() - 0.5) * size.X * 0.5, (math.random() - 0.5) * size.Y * 0.4)
		table.insert(panes, { part = pane, out = flat.Magnitude > 0.1 and flat.Unit or Vector3.xAxis, crack = { origin = origin, rays = {}, rayCount = 4, reach = 0 } })
	end
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = color:Lerp(WHITE, 0.35)
	outline.OutlineTransparency = 0.1
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = paneModel
	outline.Parent = paneModel
	paneModel.Parent = folder
	state.panes = panes
	state.paneModel = paneModel

	-- glints drifting up inside
	local motes = keep(effectPart(Enum.PartType.Block, WHITE, Vector3.new(radius * 2, 0.2, radius * 2), CFrame.new(ground + Vector3.new(0, 0.3, 0)), lifetime))
	motes.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = GLINT_TEXTURE
	emitter.Color = ColorSequence.new(WHITE, color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.1), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(2, 6)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Rotation = NumberRange.new(0, 90)
	emitter.Rate = 70 * VFX.Quality()
	emitter.Parent = motes

	-- the black and white timeline for whoever is inside, coming and going as they cross the glass
	local inside = false
	state.connection = RunService.RenderStepped:Connect(function()
		local myCharacter = Players.LocalPlayer.Character
		local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
		local nowInside = myRoot ~= nil and (myRoot.Position - center).Magnitude <= radius
		if nowInside ~= inside then
			inside = nowInside
			if inside then
				enterRewrite(state)
			else
				leaveRewrite(state)
			end
		end
	end)

	-- the glass cracks further every second
	local seconds = math.ceil(duration)
	for second = 1, seconds - 1 do
		task.delay(second, function()
			if rewrites[castId] ~= state then
				return
			end
			state.progress = second / (seconds - 1)
			for _, pane in ipairs(panes) do
				if math.random() < REWRITE_CRACK_SHARE then
					crackPane(pane, state.progress)
				end
			end
			for _ = 1, 8 do
				local pane = panes[math.random(#panes)].part
				if pane.Parent then
					local spot = CFrame.new((math.random() - 0.5) * pane.Size.X * 0.8, (math.random() - 0.5) * pane.Size.Y * 0.6, 0)
					VFX.Play("Shared/Sparks", pane.CFrame * spot, { color = WHITE, scale = 0.8 })
				end
			end
			VFX.Shake(center, "Light", radius * 2)
		end)
	end
	-- in case the Rewrite never arrives
	task.delay(lifetime, function()
		if rewrites[castId] == state then
			clearRewrite(castId)
			leaveRewrite(state)
			removeOcean(state.ocean)
			paneModel:Destroy()
			for _, entry in ipairs(state.ghosts) do
				entry.ghost:Destroy()
			end
		end
	end)
end

-- a recorded hit: the target leaves a frozen red reflection, and the glass cracks
function effects.RewriteHit(castId, model, color)
	local state = rewrites[castId]
	if not state or not model or not model.Parent then
		return
	end
	local ghost = ghostOf(model, color)
	ghost.Name = "RewriteGhost"
	for _, part in ipairs(ghost:GetChildren()) do
		mirrorGlass(part, 0.3)
		part.Color = color:Lerp(WHITE, 0.45)
	end
	ghost.Parent = folder
	table.insert(state.ghosts, { ghost = ghost, model = model })
	local torso = ghost:FindFirstChild("UpperTorso") or ghost:FindFirstChild("Torso")
	if torso then
		VFX.Play("Shared/Impact", torso.Position, { color = color, scale = 0.6 })
	end
	for _ = 1, 2 do
		local pane = state.panes[math.random(#state.panes)]
		crackPane(pane, math.max(state.progress, 0.3))
	end
end

function effects.RewriteSnap(castId, center, radius, positions, models, color)
	local state = clearRewrite(castId)
	VFX.ImpactFrameNear(center, radius + 4, state and state.caster)
	if state then
		-- every reflection slams into its target
		for _, entry in ipairs(state.ghosts) do
			local ghost = entry.ghost
			local torso = ghost:FindFirstChild("UpperTorso") or ghost:FindFirstChild("Torso")
			local targetRoot = entry.model.Parent and entry.model:FindFirstChild("HumanoidRootPart")
			if torso and targetRoot then
				local shift = targetRoot.Position - torso.Position
				for _, part in ipairs(ghost:GetChildren()) do
					tween(part, 0.15, { CFrame = part.CFrame + shift, Transparency = 1 }, Enum.EasingStyle.Quad)
				end
			end
			Debris:AddItem(ghost, 0.2)
		end
		-- all the glass shatters
		for _, pane in ipairs(state.panes) do
			shatterPane(pane, center)
		end
		state.paneModel:Destroy()
		-- and the ocean flies apart
		if not state.ocean.brokenAt then
			state.ocean.brokenAt = os.clock()
		end
		if state.grade and state.grade.Parent then
			local grade = state.grade
			grade.Saturation = 0.6
			grade.Contrast = 0.35
			grade.Brightness = 0.25
			grade.TintColor = WHITE
			tween(grade, 0.45, { Saturation = 0, Contrast = 0, Brightness = 0 })
			Debris:AddItem(grade, 0.5)
			state.grade = nil
		end
	end
	VFX.Play("Shared/Shockwave", CFrame.new(center + Vector3.new(0, 0.2, 0)), { color = color, scale = radius / 8 })
	VFX.Shake(center, "Heavy", radius * 3)
	-- what was written down happens: a burst, backbones and a crater under each target
	task.delay(0.12, function()
		for _, position in ipairs(positions) do
			VFX.Play("Shared/BigImpact", position, { color = color, scale = 1.4 })
			shatter(position, color, 20, 14)
			erupt(position - Vector3.new(0, 3, 0), color)
			VFX.Crater(position, 7)
		end
	end)
end

-- an enemy shrugging off a stagger: a white flash over it and a ring at its feet
function effects.PoiseBreak(model)
	local feet = feetOf(model)
	if not feet then
		return
	end
	ring(feet + Vector3.new(0, 0.2, 0), WHITE, 2, 12, 0.35, 0.3)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = WHITE
	highlight.FillTransparency = 0.4
	highlight.OutlineColor = WHITE
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	tween(highlight, 0.35, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(highlight, 0.35)
end

-- Misremembered erasing a hit: the body glitches into a green and a red
-- copy that split apart and flicker, it shatters, and the word jitters up
local GLITCH_RED = Color3.fromRGB(255, 70, 80) -- Mandela's overcharged red
function effects.Misremember(character, color)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local split = root.CFrame.RightVector * (math.random() < 0.5 and -1 or 1)
	for i, tint in ipairs({ color, GLITCH_RED }) do
		local ghost = ghostOf(character, tint)
		local side = split * (i == 1 and 1.2 or -1.2)
		for _, part in ipairs(ghost:GetChildren()) do
			part.CFrame += side
		end
		ghost.Parent = folder
		for flicker = 1, 4 do
			task.delay(flicker * 0.05, function()
				local jitter = Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.4, math.random() - 0.5) * 0.6
				for _, part in ipairs(ghost:GetChildren()) do
					part.CFrame += jitter
					part.Transparency = flicker % 2 == 0 and 0.15 or 0.6
				end
			end)
		end
		task.delay(0.25, function()
			for _, part in ipairs(ghost:GetChildren()) do
				tween(part, 0.2, { Transparency = 1 })
			end
		end)
		Debris:AddItem(ghost, 0.5)
	end
	shatter(root.Position, color, 10, 6)
	VFX.Play("Shared/Impact", root.Position, { color = color, scale = 0.7 })

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = character:FindFirstChild("Head") or root
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(160, 24)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 16
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.4
	text.Text = "MISREMEMBERED"
	text.Parent = billboard
	for i = 1, 4 do
		task.delay(i * 0.05, function()
			text.Position = UDim2.fromOffset(math.random(-4, 4), math.random(-2, 2))
		end)
	end
	task.delay(0.25, function()
		text.Position = UDim2.new()
	end)
	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	tween(billboard, 0.8, { StudsOffset = Vector3.new(0, 5, 0) })
	tween(text, 0.8, { TextTransparency = 1, TextStrokeTransparency = 1 })
	Debris:AddItem(billboard, 0.8)
end

-- Iridescent Requiem ----------------------------------------------------

-- the orange-cyan shimmer, each tagged thing a little out of step with the next
local function shimmer(t, phase)
	return SkillSetConfig.IridescentColor(0.5 + 0.5 * math.sin(t * 1.6 + phase))
end

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for i, instance in ipairs(CollectionService:GetTagged("Iridescent")) do
		if instance:IsA("BasePart") or instance:IsA("Light") then
			instance.Color = shimmer(t, i * 0.9)
		elseif instance:IsA("Highlight") then
			instance.FillColor = shimmer(t, i * 0.9)
		end
		local spin = instance:IsA("BasePart") and instance:GetAttribute("Spin")
		if spin then
			instance.CFrame *= CFrame.Angles(0, math.rad(spin) * dt, 0)
		end
	end
end)

-- a shade of the set's light, from orange (0) through a pale sheen to cyan (1)
local function spectrum(share)
	return SkillSetConfig.IridescentColor(share)
end

-- a straight bolt of light that thins and fades
local function lightBeam(from, to, color, width, lifetime)
	local offset = to - from
	if offset.Magnitude < 0.05 then
		return
	end
	local part = effectPart(Enum.PartType.Block, color, Vector3.new(width, width, offset.Magnitude), CFrame.lookAt(from + offset / 2, to), lifetime)
	tween(part, lifetime, { Size = Vector3.new(width * 0.2, width * 0.2, offset.Magnitude), Transparency = 1 })
end

local function sparkle(position, color, count)
	burst(position, {
		Texture = SPARKLE_TEXTURE,
		Color = ColorSequence.new(WHITE, color),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.2, 0.45),
		Speed = NumberRange.new(6, 14),
		Drag = 5,
	}, count)
end

-- Soft out-of-focus orbs of the set's light drifting about, like the bokeh in
-- a photo of sunlit water: `count` of them anywhere in a box `size` round `cframe`.
local BOKEH_TEXTURE = "rbxassetid://196969716" -- a soft round glow
local function bokeh(cframe, size, count, lifetime)
	local holder = effectPart(Enum.PartType.Block, WHITE, size, cframe, (lifetime or 1) + 1.2)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = BOKEH_TEXTURE
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, SkillSetConfig.IridescentOrange),
		ColorSequenceKeypoint.new(0.5, spectrum(0.5)),
		ColorSequenceKeypoint.new(1, SkillSetConfig.IridescentCyan),
	})
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new((lifetime or 1) * 0.6, lifetime or 1)
	emitter.Speed = NumberRange.new(0.5, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 1
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(math.max(1, math.round(count * VFX.Quality())))
end

-- A ribbon of light from `from` to `to`: a white core inside a wider band
-- that runs orange to cyan along its length (or `colors`), fading over `lifetime`.
local RIBBON_TEXTURE = "rbxassetid://14191581119" -- fine white streaks
local function lightRibbon(from, to, width, lifetime, colors)
	if (to - from).Magnitude < 0.1 then
		return
	end
	local holder = effectPart(Enum.PartType.Block, WHITE, Vector3.one * 0.2, CFrame.new(from), lifetime + 0.1)
	holder.Transparency = 1
	local a0 = Instance.new("Attachment")
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Parent = holder -- first: WorldPosition only means the world once it's parented
	a1.WorldPosition = to
	local function beam(color, beamWidth, texture)
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Color = color
		b.Width0 = beamWidth
		b.Width1 = beamWidth
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Segments = 1
		if texture then
			b.Texture = texture
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureSpeed = 2
		end
		b.Parent = holder
		return b
	end
	local band = beam(colors or ColorSequence.new({
		ColorSequenceKeypoint.new(0, SkillSetConfig.IridescentOrange),
		ColorSequenceKeypoint.new(0.5, spectrum(0.5)),
		ColorSequenceKeypoint.new(1, SkillSetConfig.IridescentCyan),
	}), width, RIBBON_TEXTURE)
	band.Segments = 10
	local core = beam(ColorSequence.new(WHITE), width * 0.25)
	-- thins and fades, the far end first
	local startedAt = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - startedAt) / lifetime
		if k >= 1 or not holder.Parent then
			connection:Disconnect()
			return
		end
		local near, far = math.clamp(k * 1.3, 0, 1), math.clamp(k * 1.3 + 0.35, 0, 1)
		band.Transparency = NumberSequence.new(near, far)
		core.Transparency = NumberSequence.new(math.min(near + 0.1, 1), far)
		band.Width0 = width * (1 - k * 0.6)
		band.Width1 = width * (1 - k)
		core.Width0 = width * 0.25 * (1 - k)
		core.Width1 = width * 0.25 * (1 - k)
	end)
end

-- a glimpse of a character as it was: a shimmering glass copy, orange at the
-- head to cyan at the feet, that fades from `opacity` over `fade` seconds,
-- drifting along `drift`
local function glimpse(character, opacity, fade, drift)
	local ghost = ghostOf(character, WHITE)
	ghost.Name = "LightstepGlimpse"
	local root = character:FindFirstChild("HumanoidRootPart")
	local top = root and root.Position.Y + 3 or 0
	for _, part in ipairs(ghost:GetChildren()) do
		part.Color = spectrum(math.clamp((top - part.Position.Y) / 5.5, 0, 1))
		part.Transparency = 1 - opacity
		tween(part, fade, { Transparency = 1, CFrame = part.CFrame + drift }, Enum.EasingStyle.Quad)
	end
	ghost.Parent = folder
	Debris:AddItem(ghost, fade + 0.05)
end

-- a lens flare: a four-point star that blooms and spins away, on a soft glow
local STAR_TEXTURE = "rbxassetid://243728206"
local function flare(position, color, size)
	flash(position, color, size * 0.3, size, 0.18)
	burst(position, {
		Texture = STAR_TEXTURE,
		Color = ColorSequence.new(WHITE, color),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.4), NumberSequenceKeypoint.new(0.3, size * 1.4), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.3, 0.35),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 45),
		RotSpeed = NumberRange.new(-120, 120),
		SpreadAngle = Vector2.zero,
	}, 1)
end

-- a crystal that appears at the hand, splits the light, and breaks
local function handPrism(position)
	local crystal = effectPart(Enum.PartType.Block, WHITE, Vector3.new(0.5, 0.9, 0.5), CFrame.new(position) * randomAngles(), 0.3)
	crystal.Material = Enum.Material.Glass
	crystal.Transparency = 0.2
	crystal.Reflectance = 0.4
	tween(crystal, 0.22, { CFrame = crystal.CFrame * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(0.9, 1.6, 0.9), Transparency = 1 })
	shatter(position, WHITE, 6, 3)
end

-- Prism Shot: a crystal at the hand splits the light into beams that
-- alternate orange and cyan, each a white core in its colour, ending in a
-- lens flare and a drift of bokeh
function effects.PrismShot(origin, tips)
	handPrism(origin)
	flare(origin, spectrum(0.5), 3)
	for i, tip in ipairs(tips) do
		local share = i % 2 == 0 and 1 or 0
		local color = spectrum(share)
		lightRibbon(origin, tip, 0.9, 0.35, ColorSequence.new(spectrum(0.5), color))
		flare(tip, color, 2.2)
		bokeh(CFrame.new(tip), Vector3.one * 2.5, 3, 0.7)
	end
end

-- Lightstep: a glass glimpse of Ayato is left fading where he stood, two
-- fainter ones flicker along the way, and a ribbon of light marks the path;
-- the body blinks out while it's light, then fades back in at the end
local LIGHTSTEP_FADE_IN = 0.15 -- seconds the body takes to reappear
function effects.Lightstep(character, from, to, travelTime)
	local path = to - from
	local along = path.Magnitude > 0.1 and path.Unit or Vector3.zero
	glimpse(character, 0.75, 0.45, -along * 1.5)
	-- the flickers along the way, placed where he passes
	for i, share in ipairs({ 0.4, 0.75 }) do
		task.delay(travelTime * share, function()
			local root = character.Parent and character:FindFirstChild("HumanoidRootPart")
			if root then
				local ghost = ghostOf(character, spectrum(i == 1 and 0.2 or 0.8))
				local shift = from + path * share - root.Position
				for _, part in ipairs(ghost:GetChildren()) do
					part.CFrame += shift
					part.Transparency = 0.55
					tween(part, 0.2, { Transparency = 1 })
				end
				ghost.Parent = folder
				Debris:AddItem(ghost, 0.25)
			end
		end)
	end

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = 1
		end
	end
	task.delay(travelTime, function()
		local startedAt = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - startedAt) / LIGHTSTEP_FADE_IN, 0, 1)
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.LocalTransparencyModifier = 1 - k
				end
			end
			if k >= 1 or not character.Parent then
				connection:Disconnect()
			end
		end)
	end)

	lightRibbon(from, to, 2.2, 0.4)
	lightRibbon(from + Vector3.new(0, 1.2, 0), to + Vector3.new(0, 1.2, 0), 0.7, 0.3)
	local middle = (from + to) / 2
	local pathFrame = path.Magnitude > 0.1 and CFrame.lookAt(middle, to) or CFrame.new(middle)
	bokeh(pathFrame, Vector3.new(2.5, 3, math.max(path.Magnitude, 1)), 14, 0.9)
	flash(from, SkillSetConfig.IridescentOrange, 0.8, 4, 0.18)
	task.delay(travelTime, function()
		flash(to, SkillSetConfig.IridescentCyan, 0.8, 5, 0.22)
		sparkle(to, spectrum(1), 10)
	end)
end

-- Refraction Field: a cluster of glass crystals floating over the spot (a
-- tall one in the middle, smaller ones circling it, tilted out), each with a
-- bright core, slowly turning and bobbing, in the shimmer. Kept by id until
-- its PrismBreak.
local fields = {} -- field id -> { model, connection }
local FIELD_SATELLITES = 5

local function removeField(id)
	local field = fields[id]
	if not field then
		return
	end
	fields[id] = nil
	field.connection:Disconnect()
	field.model:Destroy()
end

function effects.RefractionField(id, center, radius, scale, duration)
	removeField(id)
	local model = Instance.new("Model")
	model.Name = "RefractionCrystals"
	local crystals = {}
	local function crystal(size, offset)
		local part = effectPart(Enum.PartType.Block, WHITE, size, CFrame.new(center), duration + 3)
		part.Material = Enum.Material.Glass
		part.Transparency = 0.2
		part.Reflectance = 0.35
		part.Parent = model
		CollectionService:AddTag(part, "Iridescent")
		local core = effectPart(Enum.PartType.Block, WHITE, Vector3.new(size.X * 0.3, size.Y * 0.8, size.Z * 0.3), CFrame.new(center), duration + 3)
		core.Transparency = 0.25
		core.Parent = model
		table.insert(crystals, { part = part, core = core, offset = offset, phase = math.random() * math.pi * 2 })
	end
	crystal(Vector3.new(1, 3.4, 1) * scale, Vector3.zero)
	for i = 1, FIELD_SATELLITES do
		local a = i / FIELD_SATELLITES * math.pi * 2
		crystal(Vector3.new(0.55, 1.7, 0.55) * scale * (0.8 + math.random() * 0.4), Vector3.new(math.cos(a), 0, math.sin(a)) * 2 * scale)
	end
	local light = Instance.new("PointLight")
	light.Range = math.min(radius, 60)
	light.Brightness = 2
	light.Parent = crystals[1].part
	CollectionService:AddTag(light, "Iridescent")
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = WHITE
	outline.OutlineTransparency = 0.4
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	model.Parent = folder

	local startedAt = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - startedAt
		local rise = math.min(t / 0.3, 1) -- they float up into place
		local orbit = CFrame.Angles(0, t * 0.6, 0)
		for i, entry in ipairs(crystals) do
			local offset = orbit * entry.offset
			local bob = math.sin(t * 2 + entry.phase) * 0.25 * scale
			local position = center + offset + Vector3.new(0, bob - (1 - rise) * 3, 0)
			local tilt = CFrame.identity
			if i > 1 then
				local outward = offset.Unit
				tilt = CFrame.fromAxisAngle(Vector3.new(-outward.Z, 0, outward.X), math.rad(-25))
			end
			local frame = CFrame.new(position) * tilt * CFrame.Angles(0, t * 0.9 + entry.phase, 0) * CFrame.Angles(0, math.pi / 4, 0)
			entry.part.CFrame = frame
			entry.core.CFrame = frame
		end
	end)
	fields[id] = { model = model, connection = connection }
	-- in case its PrismBreak never comes
	task.delay(duration + 3, removeField, id)

	local ground = VFX.Ground(center) or (center - Vector3.new(0, 4, 0))
	ring(ground + Vector3.new(0, 0.2, 0), SkillSetConfig.IridescentCyan, 2, radius * 2, 0.45, 0.3)
	task.delay(0.08, ring, ground + Vector3.new(0, 0.3, 0), SkillSetConfig.IridescentOrange, 1, radius * 1.6, 0.4, 0.25)
	flare(center, spectrum(0.5), 4 * scale)
	bokeh(CFrame.new(center), Vector3.new(5, 4, 5) * scale, 10, 1.2)
end

-- Refraction Field: the light splitting off the crystals into a beam that
-- jumps through each target, orange and cyan by turns, flaring where it hits
function effects.RefractionBeams(from, chain)
	local previous = from
	for i, position in ipairs(chain) do
		local color = spectrum(i % 2 == 0 and 0 or 1)
		lightRibbon(previous, position, 0.7, 0.3, ColorSequence.new(spectrum(0.5), color))
		flare(position, color, 1.6)
		previous = position
	end
end

-- crystals (or a Prism Form) breaking: they shatter into glints and bokeh
function effects.PrismBreak(position, color, id)
	if id then
		removeField(id)
	end
	flash(position, WHITE, 1, 6, 0.25)
	shatter(position, spectrum(0), 8, 8)
	shatter(position, spectrum(1), 8, 8)
	bokeh(CFrame.new(position), Vector3.new(4, 4, 4), 8, 1)
end

-- Sunmark: someone Prism Shot or Refraction Field hit burns with the set's
-- light, shown only to the caster (the server tells only them): an orange
-- outline seen through walls, so they can be tracked for Solar Lance, and a
-- fire aura (orange flames with cyan tips, and embers) rising off the body.
-- A fresh hit renews it; it fades out when the mark runs out or Solar Lance
-- uses it.
-- Kek's flames (from ui-resources.com, made white with the shading in the
-- alpha so the tint shows); each body part burns with a different one
local FLAME_TEXTURES = {
	"rbxassetid://79654899423199",
	"rbxassetid://109804096536909",
	"rbxassetid://125981240093621",
	"rbxassetid://124612888704862",
	"rbxassetid://95065817964593",
}
local SUNMARK_FADE = 0.3 -- seconds the burn takes to die down
local sunmarks = {} -- model -> { until, parts }

local function sunmarkFlames(part, scale, texture)
	local flames = Instance.new("ParticleEmitter")
	flames.Name = "SunmarkFlames"
	flames.Texture = texture
	flames.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 35)),
		ColorSequenceKeypoint.new(0.55, SkillSetConfig.IridescentOrange),
		ColorSequenceKeypoint.new(0.85, SkillSetConfig.IridescentCyan),
		ColorSequenceKeypoint.new(1, SkillSetConfig.IridescentCyan),
	})
	flames.LightEmission = 1
	flames.LightInfluence = 0
	-- soft, puffy flames: big enough to wrap round the body, and drawn a
	-- little toward the camera so the body doesn't swallow them
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6 * scale), NumberSequenceKeypoint.new(0.5, 3.6 * scale), NumberSequenceKeypoint.new(1, 1.2 * scale) })
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.7, 0.25), NumberSequenceKeypoint.new(1, 1) })
	flames.ZOffset = 1
	flames.Lifetime = NumberRange.new(0.4, 0.7)
	flames.Speed = NumberRange.new(2, 4)
	flames.Acceleration = Vector3.new(0, 6, 0)
	flames.EmissionDirection = Enum.NormalId.Top
	flames.SpreadAngle = Vector2.new(15, 15)
	flames.Rotation = NumberRange.new(-20, 20)
	flames.RotSpeed = NumberRange.new(-40, 40)
	flames.Shape = Enum.ParticleEmitterShape.Box
	flames.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	flames.Rate = 32 * scale * VFX.Quality()
	flames.Parent = part
	return flames
end

function effects.Sunmark(model, duration)
	if not model or not model.Parent then
		return
	end
	local existing = sunmarks[model]
	if existing and not existing.fading then
		-- still burning: just renew it
		existing.endsAt = os.clock() + duration
		return
	end
	local parts = {}
	local outline = Instance.new("Highlight")
	outline.Name = "Sunmark"
	outline.FillColor = SkillSetConfig.IridescentOrange
	outline.FillTransparency = 0.8
	outline.OutlineColor = SkillSetConfig.IridescentOrange
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Adornee = model
	outline.Parent = model
	table.insert(parts, outline)
	-- flames off the torso, the head and the limbs
	local emitters = {}
	for _, name in ipairs({ "UpperTorso", "Torso", "Head", "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm", "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local big = name == "UpperTorso" or name == "Torso"
			local flames = sunmarkFlames(part, big and 1.2 or 0.6, FLAME_TEXTURES[#emitters % #FLAME_TEXTURES + 1])
			table.insert(emitters, flames)
			table.insert(parts, flames)
		end
	end
	-- embers drifting up off it
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		local embers = Instance.new("ParticleEmitter")
		embers.Name = "SunmarkEmbers"
		embers.Texture = SPARKLE_TEXTURE
		embers.Color = ColorSequence.new(SkillSetConfig.IridescentOrange, SkillSetConfig.IridescentCyan)
		embers.LightEmission = 1
		embers.LightInfluence = 0
		embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		embers.Lifetime = NumberRange.new(0.8, 1.3)
		embers.Speed = NumberRange.new(3, 6)
		embers.Acceleration = Vector3.new(0, 3, 0)
		embers.SpreadAngle = Vector2.new(35, 35)
		embers.EmissionDirection = Enum.NormalId.Top
		embers.Rate = 12 * VFX.Quality()
		embers.Parent = root
		table.insert(emitters, embers)
		table.insert(parts, embers)
		flash(root.Position, SkillSetConfig.IridescentOrange, 1, 5, 0.2)
	end

	local mark = { endsAt = os.clock() + duration }
	sunmarks[model] = mark
	local fadingSince
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local used = (model:GetAttribute("SunmarkUntil") or 0) <= workspace:GetServerTimeNow()
		if not fadingSince and (now >= mark.endsAt or used or not model.Parent) then
			fadingSince = now
			mark.fading = true
			for _, emitter in ipairs(emitters) do
				emitter.Enabled = false
			end
		end
		if fadingSince then
			local k = (now - fadingSince) / SUNMARK_FADE
			outline.OutlineTransparency = k
			outline.FillTransparency = 0.8 + 0.2 * k
			if k >= 1 or not model.Parent then
				connection:Disconnect()
				if sunmarks[model] == mark then
					sunmarks[model] = nil
				end
				-- the embers already out get a moment to finish
				for _, instance in ipairs(parts) do
					Debris:AddItem(instance, instance:IsA("ParticleEmitter") and 1.3 or 0)
				end
			end
			return
		end
		-- the outline breathes, orange through the sheen
		local pulse = 0.5 + 0.5 * math.sin(now * 6)
		outline.OutlineColor = spectrum(0.35 * pulse)
		outline.FillTransparency = 0.72 + 0.12 * pulse
	end)
end

-- Images from ui-resources.com (made white with the shading in the alpha, so
-- the tints show true), shared by Solar Lance and Prism Form: a light
-- sunburst, a glowing orb, an expanding ring, twinkling sparkles, crackling
-- sparks and slivers of light.
local FORM_SUNBURST = "rbxassetid://83570036773765"
local FORM_ORB = "rbxassetid://137116168491430"
local FORM_RING = "rbxassetid://91324726902981"
local FORM_SPARKLE = "rbxassetid://76655855113006"
local FORM_SPARKS = { "rbxassetid://135187430795546", "rbxassetid://110061452780758" }
local FORM_SLIVERS = { "rbxassetid://104814144434713", "rbxassetid://138850010013699" }

local function sizes(from, peak, to)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(0.3, peak), NumberSequenceKeypoint.new(1, to) })
end

local function fadeOut(start)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, start or 0), NumberSequenceKeypoint.new(1, 1) })
end

-- emitter settings that lay particles flat on the ground (facing up)
-- instead of turning them to the camera
local function lyingFlat(props)
	props.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	props.EmissionDirection = Enum.NormalId.Top
	props.SpreadAngle = Vector2.zero
	props.Speed = NumberRange.new(0.01)
	return props
end

-- A shaft of sunlight from `height` up onto `point`, drawn with beams that
-- always face the camera: a soft cyan glow round an orange body streaked
-- with light running down it, and a white core, thinner and paler up in the
-- sky. Its width goes from `fromWidth` to `toWidth` over `lifetime`;
-- `appearing` brightens it as it goes (a warning) instead of fading it out.
local SHAFT_GLOW_TEXTURE = "rbxassetid://14050983225" -- a soft glowing streak
local function sunShaft(point, height, fromWidth, toWidth, lifetime, appearing, brightness)
	local holder = effectPart(Enum.PartType.Block, WHITE, Vector3.one * 0.2, CFrame.new(point), lifetime + 0.1)
	holder.Transparency = 1
	local top = Instance.new("Attachment")
	top.Parent = holder -- first: WorldPosition only means the world once it's parented
	top.WorldPosition = point + Vector3.new(0, height, 0)
	local bottom = Instance.new("Attachment")
	bottom.Parent = holder
	local layers = {}
	local function layer(color, share, opacity, texture, textureLength, speed)
		local beam = Instance.new("Beam")
		beam.Attachment0 = top
		beam.Attachment1 = bottom
		beam.Color = ColorSequence.new(color)
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Brightness = brightness or 1
		beam.Segments = 1
		if texture then
			beam.Texture = texture
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = textureLength
			beam.TextureSpeed = speed
		end
		beam.Parent = holder
		table.insert(layers, { beam = beam, share = share, opacity = opacity })
	end
	layer(SkillSetConfig.IridescentCyan, 1, 0.8, SHAFT_GLOW_TEXTURE, height, 0)
	layer(SkillSetConfig.IridescentOrange, 0.7, 1, RIBBON_TEXTURE, 24, 3)
	layer(WHITE, 0.16, 1)
	local function draw(k)
		local width = fromWidth + (toWidth - fromWidth) * (1 - (1 - k) ^ 2)
		local strength = appearing and (0.25 + 0.75 * k) or (1 - k * k)
		for _, entry in ipairs(layers) do
			local shown = 1 - entry.opacity * strength
			entry.beam.Width0 = width * entry.share * 0.6
			entry.beam.Width1 = width * entry.share
			entry.beam.Transparency = NumberSequence.new(1 - (1 - shown) * 0.35, shown)
		end
	end
	draw(0)
	local startedAt = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - startedAt) / lifetime
		if k >= 1 or not holder.Parent then
			connection:Disconnect()
			return
		end
		draw(k)
	end)
end

-- slivers of sunlight raining down a shaft onto `point`
local function sunfall(point, radius, count)
	for i, texture in ipairs(FORM_SLIVERS) do
		burst(point + Vector3.new(0, 70, 0), {
			Texture = texture,
			Color = ColorSequence.new(WHITE, i == 1 and SkillSetConfig.IridescentOrange or spectrum(0.5)),
			LightEmission = 1,
			LightInfluence = 0,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NumberSequence.new(1.5 + radius * 0.25),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.3, 0.55),
			Speed = NumberRange.new(150, 170),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.zero,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		}, math.max(2, math.round(count * VFX.Quality())), Vector3.new(radius * 1.2, 50, radius * 1.2))
	end
end

-- Solar Lance's warning: a thin shaft of sunlight brightening onto the spot
-- with a spark of light falling down it trailing sparkles, while a turning
-- sunburst and orange and cyan rings close in on the ground to the edge of
-- where it'll hit
function effects.SolarLanceWarning(point, radius, time)
	sunShaft(point, 220, 0.8, 2.6, time, true, 1.5)
	local ground = point + Vector3.new(0, 0.25, 0)
	burst(ground, lyingFlat({
		Texture = FORM_SUNBURST,
		Color = ColorSequence.new(SkillSetConfig.IridescentOrange),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(radius * 3.2, radius * 2),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(0.9, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(time),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(90),
	}), 1, nil, time + 0.5)
	for i, color in ipairs({ SkillSetConfig.IridescentOrange, SkillSetConfig.IridescentCyan }) do
		burst(ground + Vector3.new(0, i * 0.05, 0), lyingFlat({
			Texture = FORM_RING,
			Color = ColorSequence.new(color),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new(radius * (i == 1 and 3.4 or 4), radius * 2.3),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.1), NumberSequenceKeypoint.new(1, 0.4) }),
			Lifetime = NumberRange.new(time),
		}), 1, nil, time + 0.5)
	end
	-- the spark falling down the shaft onto the spot
	local glow = effectPart(Enum.PartType.Ball, WHITE, Vector3.one * 1.6, CFrame.new(point + Vector3.new(0, 70, 0)), time + 0.5)
	glow.Transparency = 0.1
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = FORM_SPARKLE
	trail.Color = ColorSequence.new(WHITE, spectrum(0.15))
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Size = NumberSequence.new(2.5, 0)
	trail.Lifetime = NumberRange.new(0.25, 0.4)
	trail.Speed = NumberRange.new(0, 1)
	trail.Rotation = NumberRange.new(0, 360)
	trail.Rate = 60 * VFX.Quality()
	trail.Parent = glow
	tween(glow, time, { CFrame = CFrame.new(point + Vector3.new(0, 2, 0)) }, Enum.EasingStyle.Quad)
	task.delay(time, function()
		trail.Enabled = false
		glow.Transparency = 1
	end)
end

-- the strike: a shaft of sunlight (cyan glow, orange body streaked with
-- light, white core) slamming down with slivers of light raining in it;
-- where it lands a sunburst, a white orb and orange and cyan rings across
-- the ground, flames, embers and sparks thrown up, a crater of ground chunks
-- and dust, a scorch that cools, bokeh and a shake; locked onto a Sunmark
-- it flares bigger
local SCORCH = Color3.fromRGB(45, 25, 15)
function effects.SolarLance(point, radius, locked)
	local scale = locked and 1.3 or 1
	sunShaft(point, 260, radius * 2.6, radius * 0.16, 0.65, false, locked and 2 or 1.3)
	-- a white-hot neon core for a blink, so it blooms
	local core = effectPart(Enum.PartType.Cylinder, WHITE, Vector3.new(260, radius * 0.5, radius * 0.5), CFrame.new(point + Vector3.new(0, 130, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.2)
	tween(core, 0.2, { Size = Vector3.new(260, 0.2, 0.2), Transparency = 1 })
	sunfall(point, radius, 10)

	-- where it lands: a sunburst (an orange one and a cyan one turning the
	-- other way) round a white orb
	local center = point + Vector3.new(0, 2, 0)
	for i, color in ipairs({ spectrum(0.15), spectrum(0.85) }) do
		burst(center, {
			Texture = FORM_SUNBURST,
			Color = ColorSequence.new(color),
			LightEmission = 1,
			LightInfluence = 0,
			Size = sizes(radius * 0.5, radius * (i == 1 and 3.2 or 2.4) * scale, radius * (i == 1 and 3.8 or 2.8) * scale),
			Transparency = fadeOut(0),
			Lifetime = NumberRange.new(0.5),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(i == 1 and 50 or -70),
			ZOffset = 1,
		}, 1)
	end
	burst(center, {
		Texture = FORM_ORB,
		Color = ColorSequence.new(WHITE),
		LightEmission = 1,
		LightInfluence = 0,
		Size = sizes(radius * 0.4, radius * 1.4 * scale, radius * 1.6 * scale),
		Transparency = fadeOut(0),
		Lifetime = NumberRange.new(0.3),
		Speed = NumberRange.new(0),
		ZOffset = 1.5,
	}, 1)
	flare(center + Vector3.new(0, 1, 0), spectrum(0.5), radius * (locked and 1.6 or 1.1))
	-- rings racing out across the ground
	for i, color in ipairs({ SkillSetConfig.IridescentOrange, SkillSetConfig.IridescentCyan }) do
		task.delay((i - 1) * 0.07, burst, point + Vector3.new(0, 0.3 + i * 0.05, 0), lyingFlat({
			Texture = FORM_RING,
			Color = ColorSequence.new(color),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new(radius * 1.5, radius * (i == 1 and 5 or 4) * scale),
			Transparency = fadeOut(0),
			Lifetime = NumberRange.new(0.45),
		}), 1)
	end
	-- flames flaring up off the ground it lit
	for _, texture in ipairs(FLAME_TEXTURES) do
		burst(point + Vector3.new(0, 0.5, 0), {
			Texture = texture,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 95, 20)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 130, 40)),
				ColorSequenceKeypoint.new(1, SkillSetConfig.IridescentCyan),
			}),
			LightEmission = 1,
			LightInfluence = 0,
			Size = sizes(2.5, 3 + radius * 0.45, 1.5),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.45, 0.8),
			Speed = NumberRange.new(8, 16),
			Acceleration = Vector3.new(0, 12, 0),
			Drag = 3,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(30, 30),
			Rotation = NumberRange.new(-25, 25),
			RotSpeed = NumberRange.new(-50, 50),
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			ZOffset = 2,
		}, math.max(1, math.round((2 + radius / 6) * VFX.Quality())), Vector3.new(radius * 1.4, 1, radius * 1.4))
	end
	-- embers thrown up, arcing back down
	burst(point + Vector3.new(0, 1, 0), {
		Texture = FORM_SPARKLE,
		Color = ColorSequence.new(WHITE, SkillSetConfig.IridescentOrange),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(1.6, 0),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(25, 45),
		Acceleration = Vector3.new(0, -50, 0),
		Drag = 1.5,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(40, 40),
		Rotation = NumberRange.new(0, 360),
		Shape = Enum.ParticleEmitterShape.Box,
	}, math.max(8, math.round(36 * VFX.Quality())), Vector3.new(radius, 1, radius))
	-- sparks crackling round where it hit
	for _, texture in ipairs(FORM_SPARKS) do
		burst(center, {
			Texture = texture,
			Color = ColorSequence.new(spectrum(0.3), SkillSetConfig.IridescentCyan),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new(radius * 0.6),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.15, 0.3),
			Speed = NumberRange.new(0, 1),
			Rotation = NumberRange.new(0, 360),
			Shape = Enum.ParticleEmitterShape.Box,
			ZOffset = 1,
		}, math.max(1, math.round(3 * VFX.Quality())), Vector3.new(radius * 1.2, 3, radius * 1.2))
	end
	-- the ground punched in: chunks round the edge, dust and rubble
	VFX.Crater(point, math.clamp(radius * 0.6, 4, 11))
	-- the scorch: a dark burnt ring with a glowing edge, cooling off
	local flatDisc = CFrame.new(point + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local scorch = effectPart(Enum.PartType.Cylinder, SCORCH, Vector3.new(0.15, radius * 1.6, radius * 1.6), flatDisc, 2.6)
	scorch.Material = Enum.Material.SmoothPlastic
	scorch.Transparency = 0.25
	local edge = effectPart(Enum.PartType.Cylinder, SkillSetConfig.IridescentOrange, Vector3.new(0.12, radius * 1.75, radius * 1.75), flatDisc * CFrame.new(-0.02, 0, 0), 2.6)
	edge.Transparency = 0.3
	task.delay(0.4, function()
		tween(edge, 1.4, { Transparency = 1 })
		tween(scorch, 2.2, { Transparency = 1 })
	end)
	bokeh(CFrame.new(point + Vector3.new(0, 4, 0)), Vector3.new(radius * 1.6, 8, radius * 1.6), 16, 1.4)
	VFX.Shake(point, locked and "Heavy" or "Medium", radius * 4)
	if locked then
		VFX.ImpactFrameNear(point, radius + 6)
	end
end

-- F, Below the Stratus / Above the Cumulonimbus: a shaft of sunlight lifts
-- Ayato (golden beams rising, a ripple of light across the ground, god rays
-- where he stops) and cloud gathers above where he hovers: a flat sheet of
-- stratus, or towering cumulonimbus with lightning crackling inside and now
-- and then striking the ground, and a wide anvil on top. It fades away when
-- the rain of light ends. The pack pieces are VFXPrefabs.Iridescent (copied
-- from Workspace."Particle effects").
local CLOUD_LIGHT = Color3.fromRGB(240, 242, 248)
local CLOUD_DARK = Color3.fromRGB(140, 146, 165)

-- a soft billow of cloud: an invisible holder breathing out big slow smoke
-- puffs over its `size` (the cloud is the particles, so it has no hard edge)
local function cloudPuff(model, cframe, size, color, lifetime)
	local holder = effectPart(Enum.PartType.Block, color, size, cframe, lifetime + 4)
	holder.Transparency = 1
	holder.Parent = model
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE_TEXTURE
	smoke.Color = ColorSequence.new(color)
	smoke.LightInfluence = 0.6
	local puffSize = math.max(size.X, size.Z) * 0.9
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, puffSize * 0.6), NumberSequenceKeypoint.new(1, puffSize) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.35), NumberSequenceKeypoint.new(0.75, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(3, 4)
	smoke.Speed = NumberRange.new(0.3, 1)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-8, 8)
	smoke.Shape = Enum.ParticleEmitterShape.Box
	smoke.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	smoke.Rate = 2.5 * VFX.Quality()
	smoke.Parent = holder
	smoke:Emit(math.max(2, math.round(5 * VFX.Quality())))
	return holder
end

function effects.SkyVeil(center, rise, radius, variant, duration)
	local lifetime = duration + 1.5
	local feet = center - Vector3.new(0, 3, 0)
	sunShaft(feet, rise + 12, 10, 2, 0.9, false, 1.4)
	VFX.Play("Iridescent/RisingBeams", feet, { scale = 2 })
	VFX.Play("Iridescent/GroundRadial", feet + Vector3.new(0, 0.2, 0), { scale = math.min(radius / 5, 8) })
	VFX.Play("Iridescent/GodRays", center + Vector3.new(0, rise, 0), { scale = 3 })
	for i, color in ipairs({ SkillSetConfig.IridescentOrange, SkillSetConfig.IridescentCyan }) do
		task.delay((i - 1) * 0.08, burst, feet + Vector3.new(0, 0.3 + i * 0.05, 0), lyingFlat({
			Texture = FORM_RING,
			Color = ColorSequence.new(color),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new(4, math.min(radius * (i == 1 and 2.6 or 2.2), 100)),
			Transparency = fadeOut(0),
			Lifetime = NumberRange.new(0.55),
		}), 1)
	end

	local model = Instance.new("Model")
	model.Name = "SkyVeil"
	local base = center.Y + rise + (variant == "cumulonimbus" and 14 or 10)
	local puffs = {}
	if variant == "cumulonimbus" then
		-- towers in a ring round the middle, darker underneath, an anvil on top
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2 + math.random() * 0.3
			local spot = Vector3.new(center.X + math.cos(a) * radius * 0.55, base, center.Z + math.sin(a) * radius * 0.55)
			for level = 0, 2 do
				local width = (22 - level * 3) * (0.85 + math.random() * 0.3)
				local tint = CLOUD_DARK:Lerp(CLOUD_LIGHT, level / 2)
				table.insert(puffs, cloudPuff(model, CFrame.new(spot + Vector3.new(0, level * 12, 0)), Vector3.new(width, 12, width), tint, lifetime))
			end
		end
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local spot = Vector3.new(center.X + math.cos(a) * radius * 0.5, base + 40, center.Z + math.sin(a) * radius * 0.5)
			table.insert(puffs, cloudPuff(model, CFrame.new(spot), Vector3.new(radius * 0.6, 5, radius * 0.6), CLOUD_LIGHT, lifetime))
		end
	else
		-- a flat sheet, lit warm from below at its middle
		for i = 1, 16 do
			local a = math.random() * math.pi * 2
			local d = math.sqrt(math.random()) * radius * 0.85
			local spot = Vector3.new(center.X + math.cos(a) * d, base + math.random() * 2, center.Z + math.sin(a) * d)
			local width = 14 + math.random() * 8
			local tint = CLOUD_LIGHT:Lerp(spectrum(0.25), math.max(0, 0.35 - d / radius * 0.35))
			table.insert(puffs, cloudPuff(model, CFrame.new(spot), Vector3.new(width, 2, width * (0.7 + math.random() * 0.5)), tint, lifetime))
		end
	end
	model.Parent = folder
	Debris:AddItem(model, lifetime + 4) -- room for the last billows to fade

	-- lightning crackling inside the storm cloud, lighting a billow from
	-- within; every third flicker or so a bolt strikes the ground below
	if variant == "cumulonimbus" then
		local startedAt = os.clock()
		local groundY = feet.Y
		task.spawn(function()
			while os.clock() - startedAt < duration and model.Parent do
				task.wait(0.3 + math.random() * 0.4)
				local puff = puffs[math.random(#puffs)]
				if puff.Parent then
					local glow = Instance.new("PointLight")
					glow.Color = SkillSetConfig.IridescentCyan
					glow.Range = 40
					glow.Brightness = 10
					glow.Parent = puff
					Debris:AddItem(glow, 0.1)
					local bolt = math.random() < 0.5 and "Iridescent/SkyBolt" or "Iridescent/SkyBolt2"
					-- the bolts rise 25 studs (at scale 1) from where they're played
					VFX.Play(bolt, puff.Position - Vector3.new(0, 9, 0), { scale = 0.7, color = SkillSetConfig.IridescentCyan })
					if math.random() < 0.35 then
						-- down to the ground
						local a = math.random() * math.pi * 2
						local d = math.random() * radius * 0.8
						local x, z = center.X + math.cos(a) * d, center.Z + math.sin(a) * d
						VFX.Play(bolt, Vector3.new(x, groundY, z), { scale = (base - groundY) / 25, color = SkillSetConfig.IridescentCyan })
						VFX.Play("Iridescent/LanceHitCyan", Vector3.new(x, groundY + 1.5, z), { scale = 0.8 })
					end
				end
			end
		end)
	end
	-- the cloud thins away when it's over: no new billows, the old ones fade
	task.delay(duration, function()
		for _, puff in ipairs(puffs) do
			local smoke = puff.Parent and puff:FindFirstChildOfClass("ParticleEmitter")
			if smoke then
				smoke.Rate = 0
			end
		end
	end)
end

-- the rain of light: a ray from the cloud onto each target, orange and cyan
-- by turns, flaring and ringing where it lands
function effects.PrismRays(from, targets, variant)
	local big = variant == "cumulonimbus"
	for i, position in ipairs(targets) do
		local color = spectrum((i + math.floor(os.clock() * 5)) % 2)
		local sky = position + Vector3.new((math.random() - 0.5) * 6, (big and 60 or 36), (math.random() - 0.5) * 6)
		lightRibbon(sky, position, big and 1.6 or 1.1, 0.3, ColorSequence.new(spectrum(0.5), color))
		flare(position, color, big and 3 or 2.2)
		VFX.Play(i % 2 == 0 and "Iridescent/LanceHitCyan" or "Iridescent/LanceHit", position, { scale = big and 1.4 or 1.1 })
	end
end

-- Above the Cumulonimbus's columns of sunlight, a lighter cousin of Solar
-- Lance's strike so a whole volley can land at once: each falls from the
-- storm cloud as a shaft of light (sunShaft) and bursts orange where it
-- lands, with a ring across the ground and a brief scorch; one on a
-- Sunmarked target is wider, bursts cyan too, and lightning comes down with
-- it. A volley with a marked target in it gives a light shake.
local SKY_LANCE_HEIGHT = 80 -- studs from the ground up into the cloud
local SKY_LANCE_WIDTH = 10
local function skyLance(point, marked)
	local width = SKY_LANCE_WIDTH * (marked and 1.4 or 1)
	sunShaft(point, SKY_LANCE_HEIGHT, width * 1.3, width * 0.1, 0.45, false, marked and 2 or 1.3)
	flare(point + Vector3.new(0, 2.5, 0), spectrum(marked and 0.15 or 0.5), marked and 9 or 5)
	VFX.Play("Iridescent/LanceHit", point + Vector3.new(0, 2, 0), { scale = marked and 2.8 or 2.1 })
	burst(point + Vector3.new(0, 0.3, 0), lyingFlat({
		Texture = FORM_RING,
		Color = ColorSequence.new(SkillSetConfig.IridescentOrange),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(width * 0.6, width * 2.6),
		Transparency = fadeOut(0),
		Lifetime = NumberRange.new(0.4),
	}), 1)
	if marked then
		VFX.Play("Iridescent/LanceHitCyan", point + Vector3.new(0, 2.5, 0), { scale = 2.4 })
		VFX.Play(math.random() < 0.5 and "Iridescent/SkyBolt" or "Iridescent/SkyBolt2", point, { scale = SKY_LANCE_HEIGHT / 25, color = SkillSetConfig.IridescentCyan })
		sparkle(point + Vector3.new(0, 2, 0), spectrum(0.2), 14)
	end
	local flatDisc = CFrame.new(point + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local scorch = effectPart(Enum.PartType.Cylinder, SCORCH, Vector3.new(0.12, width * 0.9, width * 0.9), flatDisc, 1.4)
	scorch.Material = Enum.Material.SmoothPlastic
	scorch.Transparency = 0.35
	tween(scorch, 1.4, { Transparency = 1 })
	bokeh(CFrame.new(point + Vector3.new(0, 3, 0)), Vector3.new(width, 5, width), marked and 8 or 4, 1)
end

function effects.SkyLances(from, strikes)
	local anyMarked = false
	for _, strike in ipairs(strikes) do
		skyLance(strike.point, strike.marked)
		anyMarked = anyMarked or strike.marked
	end
	if anyMarked and strikes[1] then
		VFX.Shake(strikes[1].point, "Light", 120)
	end
end

-- Above the Cumulonimbus's finale: the sun bursts out of Ayato (a huge
-- sunburst, orange and cyan turning against each other, round a white orb
-- and god rays), rays strike everyone below and burst on them, light ripples
-- and rings race across the ground, an impact frame
function effects.SunBurst(from, center, radius, struck, caster)
	for i, color in ipairs({ SkillSetConfig.IridescentOrange, SkillSetConfig.IridescentCyan }) do
		burst(from, {
			Texture = FORM_SUNBURST,
			Color = ColorSequence.new(color),
			LightEmission = 1,
			LightInfluence = 0,
			Size = sizes(8, math.min(radius * (i == 1 and 1.1 or 0.8), 90), math.min(radius * (i == 1 and 1.3 or 0.95), 100)),
			Transparency = fadeOut(0),
			Lifetime = NumberRange.new(0.8),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(i == 1 and 40 or -55),
			ZOffset = 1,
		}, 1)
	end
	burst(from, {
		Texture = FORM_ORB,
		Color = ColorSequence.new(WHITE),
		LightEmission = 1,
		LightInfluence = 0,
		Size = sizes(4, 22, 26),
		Transparency = fadeOut(0),
		Lifetime = NumberRange.new(0.45),
		Speed = NumberRange.new(0),
		ZOffset = 1.5,
	}, 1)
	VFX.Play("Iridescent/GodRays", from, { scale = 6 })
	flare(from, spectrum(0.5), 18)
	for i, position in ipairs(struck) do
		lightRibbon(from, position, 2.5, 0.45)
		VFX.Play(i % 2 == 0 and "Iridescent/LanceHitCyan" or "Iridescent/LanceHit", position, { scale = 2.2 })
	end
	local ground = VFX.Ground(center) or center
	VFX.Play("Iridescent/GroundRadial", ground + Vector3.new(0, 0.2, 0), { scale = math.min(radius / 4, 9) })
	for i, color in ipairs({ SkillSetConfig.IridescentOrange, SkillSetConfig.IridescentCyan }) do
		task.delay((i - 1) * 0.1, burst, ground + Vector3.new(0, 0.3 + i * 0.05, 0), lyingFlat({
			Texture = FORM_RING,
			Color = ColorSequence.new(color),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new(radius * 0.3, math.min(radius * (i == 1 and 2.6 or 2.2), 100)),
			Transparency = fadeOut(0),
			Lifetime = NumberRange.new(0.75),
		}), 1)
	end
	bokeh(CFrame.new(from), Vector3.new(radius, 20, radius), 40, 2)
	VFX.Shake(center, "Heavy", radius * 3)
	VFX.ImpactFrameNear(center, radius + 10, caster)
end

-- a physical hit passing straight through someone in Prism Form
function effects.Refract(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local color = spectrum(math.random())
	flash(root.Position, color, 1, 4, 0.15)
	sparkle(root.Position, color, 8)
end

-- Solar Lance's pool in Prism Form: a sunburst lying on the ground, turning
-- slowly, with ripples of light running out of it in time with the burns,
-- Kek's flames licking up all over it, motes rising and a warm light; it
-- dies down at the end
function effects.SolarPool(point, radius, duration)
	local sunlight = SkillSetConfig.IridescentOrange
	local life = duration + 1.5
	-- the warm light it casts
	local lamp = effectPart(Enum.PartType.Block, sunlight, Vector3.one * 0.2, CFrame.new(point + Vector3.new(0, 1, 0)), duration)
	lamp.Transparency = 1
	local glow = Instance.new("PointLight")
	glow.Color = sunlight
	glow.Range = math.min(radius * 1.5, 60)
	glow.Brightness = 3
	glow.Parent = lamp
	local emitters = {}
	local function emitter(position, size, props)
		local holder = effectPart(Enum.PartType.Block, WHITE, size, CFrame.new(position), life)
		holder.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		for key, value in pairs(props) do
			e[key] = value
		end
		e.Parent = holder
		table.insert(emitters, e)
		return e
	end
	-- the sunburst lying on the ground
	emitter(point + Vector3.new(0, 0.25, 0), Vector3.one * 0.2, lyingFlat({
		Texture = FORM_SUNBURST,
		Color = ColorSequence.new(spectrum(0.15)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(radius * 2.6),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.3), NumberSequenceKeypoint.new(0.85, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(duration),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(20),
		Rate = 0,
	})):Emit(1)
	-- ripples running out of it, two a second like the burns
	emitter(point + Vector3.new(0, 0.3, 0), Vector3.one * 0.2, lyingFlat({
		Texture = FORM_RING,
		Color = ColorSequence.new(sunlight, SkillSetConfig.IridescentCyan),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(radius * 0.4, radius * 2.4),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.3, 0.05), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.9),
		Rate = 2,
	}))
	-- flames licking up all over it
	for _, texture in ipairs(FLAME_TEXTURES) do
		emitter(point + Vector3.new(0, 0.4, 0), Vector3.new(radius * 1.6, 0.2, radius * 1.6), {
			Texture = texture,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 95, 20)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 130, 40)),
				ColorSequenceKeypoint.new(1, SkillSetConfig.IridescentCyan),
			}),
			LightEmission = 1,
			LightInfluence = 0,
			Size = sizes(1.8, 4.5, 1),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(2, 5),
			Acceleration = Vector3.new(0, 8, 0),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(10, 10),
			Rotation = NumberRange.new(-20, 20),
			RotSpeed = NumberRange.new(-40, 40),
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Rate = radius / 3 * VFX.Quality(),
			ZOffset = 1,
		})
	end
	-- motes rising off it
	emitter(point + Vector3.new(0, 0.3, 0), Vector3.new(radius * 1.6, 0.2, radius * 1.6), {
		Texture = FORM_SPARKLE,
		Color = ColorSequence.new(WHITE, sunlight),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(4, 8),
		EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(0, 360),
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = (12 + radius) * VFX.Quality(),
	})
	ring(point + Vector3.new(0, 0.3, 0), sunlight, radius * 0.5, radius * 2, 0.4, 0.3)
	task.delay(math.max(duration - 0.5, 0), function()
		for _, e in ipairs(emitters) do
			e.Enabled = false
		end
		tween(glow, 0.5, { Brightness = 0 })
	end)
end

-- Prism Form: while a character's PrismForm attribute is on, its body turns
-- to light that bends what's behind it (ForceField material, tinted orange
-- at the head to cyan at the feet), outlined in the shimmer, shedding motes,
-- bokeh and light; it bursts going in and shatters coming out. Each
-- client changes the parts' look only on its own screen and puts it back.
local FORM_ATTRIBUTE = "PrismForm"

-- Going in and coming out it uses the ui-resources.com images (FORM_*) above Solar Lance.

-- `scale` 1 going in; smaller coming out
local function formBurst(position, scale, entering)
	-- the light sunburst: one in orange, a smaller cyan one turning the other way
	for i, color in ipairs({ spectrum(0.15), spectrum(0.85) }) do
		burst(position, {
			Texture = FORM_SUNBURST,
			Color = ColorSequence.new(color),
			LightEmission = 1,
			LightInfluence = 0,
			Size = sizes(4 * scale, (i == 1 and 18 or 13) * scale, (i == 1 and 22 or 16) * scale),
			Transparency = fadeOut(0),
			Lifetime = NumberRange.new(0.55),
			Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(i == 1 and 40 or -60),
			ZOffset = 1,
		}, 1)
	end
	-- the burst sphere: a white orb swelling inside a ring racing out
	burst(position, {
		Texture = FORM_ORB,
		Color = ColorSequence.new(WHITE),
		LightEmission = 1,
		LightInfluence = 0,
		Size = sizes(1.5 * scale, 5 * scale, 6 * scale),
		Transparency = fadeOut(0),
		Lifetime = NumberRange.new(0.3),
		Speed = NumberRange.new(0),
		ZOffset = 1.5,
	}, 1)
	for i, color in ipairs({ SkillSetConfig.IridescentOrange, SkillSetConfig.IridescentCyan }) do
		task.delay((i - 1) * 0.06, burst, position, {
			Texture = FORM_RING,
			Color = ColorSequence.new(color),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * scale), NumberSequenceKeypoint.new(1, 9 * scale) }),
			Transparency = fadeOut(0),
			Lifetime = NumberRange.new(0.4),
			Speed = NumberRange.new(0),
			ZOffset = 1,
		}, 1)
	end
	-- flames flaring up round the body, orange cooling to cyan (Kek's, as
	-- the Sunmark's burn)
	for _, texture in ipairs(FLAME_TEXTURES) do
		burst(position - Vector3.new(0, 1.5, 0), {
			Texture = texture,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 95, 20)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 130, 40)),
				ColorSequenceKeypoint.new(1, SkillSetConfig.IridescentCyan),
			}),
			LightEmission = 1,
			LightInfluence = 0,
			Size = sizes(2.5 * scale, 6 * scale, 2 * scale),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.5, 0.85),
			Speed = NumberRange.new(6, 11),
			Acceleration = Vector3.new(0, 10, 0),
			Drag = 3,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(55, 55),
			Rotation = NumberRange.new(-25, 25),
			RotSpeed = NumberRange.new(-50, 50),
			Shape = Enum.ParticleEmitterShape.Box,
			ZOffset = 2, -- in front of the burst sphere's glow
		}, math.max(2, math.round(3 * VFX.Quality())))
	end
	-- sparkles twinkling round the body
	burst(position, {
		Texture = FORM_SPARKLE,
		Color = ColorSequence.new(WHITE, spectrum(entering and 0.85 or 0.15)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = sizes(1, 5 * scale, 0),
		Transparency = fadeOut(0),
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(2, 6),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		Shape = Enum.ParticleEmitterShape.Sphere,
	}, math.max(2, math.round(5 * VFX.Quality())))
	-- sparks crackling off it
	for _, texture in ipairs(FORM_SPARKS) do
		burst(position, {
			Texture = texture,
			Color = ColorSequence.new(spectrum(0.5), SkillSetConfig.IridescentCyan),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new(4 * scale),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.15, 0.3),
			Speed = NumberRange.new(0, 1),
			Rotation = NumberRange.new(0, 360),
			Shape = Enum.ParticleEmitterShape.Sphere,
		}, math.max(1, math.round(3 * VFX.Quality())))
	end
end

-- coming out: slivers of light flying apart, streaking along their flight
local function formSplinter(position)
	for i, texture in ipairs(FORM_SLIVERS) do
		burst(position, {
			Texture = texture,
			Color = ColorSequence.new(i == 1 and SkillSetConfig.IridescentOrange or SkillSetConfig.IridescentCyan, WHITE),
			LightEmission = 1,
			LightInfluence = 0,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0.5) }),
			Transparency = fadeOut(0),
			Lifetime = NumberRange.new(0.3, 0.5),
			Speed = NumberRange.new(28, 45),
			Drag = 5,
			Shape = Enum.ParticleEmitterShape.Sphere,
		}, math.max(4, math.round(10 * VFX.Quality())))
	end
end

-- the body turned to light; returns how to turn it back
local function refractBody(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local top = root and root.Position.Y + 3 or 0
	local saved = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 and not part:FindFirstAncestor("SkillSetWearables") then
			saved[part] = { Material = part.Material, Color = part.Color }
			part.Material = Enum.Material.ForceField
			part.Color = spectrum(math.clamp((top - part.Position.Y) / 5.5, 0, 1))
		elseif part:IsA("Decal") and part.Parent and part.Parent.Name == "Head" then
			saved[part] = { Transparency = part.Transparency }
			part.Transparency = math.max(part.Transparency, 0.6)
		end
	end
	return function()
		for instance, properties in pairs(saved) do
			if instance.Parent then
				for key, value in pairs(properties) do
					instance[key] = value
				end
			end
		end
	end
end

local function watchForm(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local glow -- the instances it wears while it lasts
	local function update(quiet)
		local on = character:GetAttribute(FORM_ATTRIBUTE) == true
		if on and not glow then
			local restore = refractBody(character)
			local highlight = Instance.new("Highlight")
			highlight.Name = "PrismFormGlow"
			highlight.FillTransparency = 0.85
			highlight.OutlineColor = WHITE
			highlight.OutlineTransparency = 0.2
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = character
			CollectionService:AddTag(highlight, "Iridescent")
			local attachment = Instance.new("Attachment")
			attachment.Name = "PrismFormGlow"
			attachment.Parent = root
			local motes = Instance.new("ParticleEmitter")
			motes.Texture = SPARKLE_TEXTURE
			motes.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, spectrum(0)),
				ColorSequenceKeypoint.new(0.5, spectrum(0.5)),
				ColorSequenceKeypoint.new(1, spectrum(1)),
			})
			motes.LightEmission = 1
			motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			motes.Lifetime = NumberRange.new(0.5, 0.9)
			motes.Speed = NumberRange.new(2, 5)
			motes.SpreadAngle = Vector2.new(180, 180)
			motes.Rate = 35
			motes.Parent = attachment
			local light = Instance.new("PointLight")
			light.Range = 14
			light.Brightness = 2.5
			light.Parent = attachment
			CollectionService:AddTag(light, "Iridescent")
			-- out-of-focus light drifting off the body the whole time
			local drift = Instance.new("ParticleEmitter")
			drift.Texture = BOKEH_TEXTURE
			drift.Color = ColorSequence.new(SkillSetConfig.IridescentOrange, SkillSetConfig.IridescentCyan)
			drift.LightEmission = 1
			drift.LightInfluence = 0
			drift.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 0.3) })
			drift.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.4), NumberSequenceKeypoint.new(1, 1) })
			drift.Lifetime = NumberRange.new(0.8, 1.4)
			drift.Speed = NumberRange.new(0.5, 2)
			drift.SpreadAngle = Vector2.new(180, 180)
			drift.Rate = 10 * VFX.Quality()
			drift.Parent = attachment
			glow = { highlight, attachment, restore = restore }
			if not quiet then
				formBurst(root.Position, 1, true)
				ring(root.Position - Vector3.new(0, 2.5, 0), SkillSetConfig.IridescentOrange, 2, 20, 0.45, 0.3)
				task.delay(0.07, ring, root.Position - Vector3.new(0, 2.4, 0), SkillSetConfig.IridescentCyan, 2, 16, 0.45, 0.3)
				bokeh(root.CFrame, Vector3.new(4, 6, 4), 12, 1)
			end
		elseif not on and glow then
			for _, instance in ipairs(glow) do
				instance:Destroy()
			end
			glow.restore()
			glow = nil
			if not quiet and root.Parent then
				formBurst(root.Position, 0.75, false)
				formSplinter(root.Position)
				bokeh(root.CFrame, Vector3.new(4, 6, 4), 10, 0.8)
			end
		end
	end
	character:GetAttributeChangedSignal(FORM_ATTRIBUTE):Connect(function()
		update(false)
	end)
	update(true)
end

local function watchPlayer(other)
	other.CharacterAdded:Connect(watchForm)
	if other.Character then
		task.spawn(watchForm, other.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in ipairs(Players:GetPlayers()) do
	watchPlayer(other)
end

-- Ranged moves and guns --------------------------------------------------

local projectileModels = ReplicatedStorage:WaitForChild("ProjectileModels")
local flying = {} -- projectile id -> the copy being drawn
local projectileKinds = {} -- projectile id -> its model's name, until it ends
local MANDELA_COLOR = Color3.fromRGB(170, 255, 200)
local STUCK_TIME = 0.8 -- seconds a thrown knife stays stuck in a wall or the floor
local KNIFE_FADE = 0.25 -- seconds a knife takes to fade out
local TRAIL_FADE = 0.3 -- seconds a bullet's trail gets to fade after it stops

-- whether a knife that stopped at `position`, flying along `direction`, is
-- buried in a wall or the floor (not a character, not thin air)
local function stuckInSurface(position, direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder, VFX.Folder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position - direction * 1.5, direction * 3, params)
	if not hit then
		return false
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	return not (model and model:FindFirstChildOfClass("Humanoid"))
end

-- A knife or bullet flying from `origin` along `direction`, until the
-- server's "ProjectileEnd" says where it stopped. With `spin` (degrees a
-- second) it tumbles end over end, flat side to the side (the knife);
-- without, it flies nose first along its long Y axis (the bullet).
-- `muzzle` lights up where it left from. A shot locked onto someone (aim
-- assist) steers toward `homing`, their root, like the server's copy.
function effects.Projectile(id, modelName, origin, direction, speed, range, spin, muzzle, homing)
	local template = projectileModels:FindFirstChild(modelName)
	if not template or flying[id] then
		return
	end
	local piece = template:Clone()
	piece.Parent = folder
	local entry = {} -- `finish`: where the server's copy stopped, once it has
	flying[id] = entry
	if muzzle then
		flash(origin, muzzle, 0.4, 2, 0.08)
	end
	projectileKinds[id] = modelName
	local streak
	if modelName == "Knife" then
		-- Mandela's knife leaves a thin green line of light
		streak = VFX.Play("Mandela/KnifeStreak", piece, { color = MANDELA_COLOR, duration = range / speed + 0.5 })
		VFX.Play("Shared/Sparks", origin, { color = MANDELA_COLOR, scale = 0.4 })
	end
	local startedAt = os.clock()
	local position = origin
	local travelled = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local elapsed = os.clock() - startedAt
		local step = math.min(speed * dt, range - travelled)
		local done = false
		local goal = entry.finish or (homing and homing.Parent and homing.Position)
		if goal then
			local toward = goal - position
			if entry.finish and (toward.Magnitude <= step or toward:Dot(direction) <= 0) then
				-- there (or already past it, drawn ahead of the server): stop on it
				position = entry.finish
				done = true
			elseif toward.Magnitude > 0.1 then
				direction = toward.Unit
			end
		end
		if not done then
			position += direction * step
			travelled += step
			done = travelled >= range
		end
		local side = direction:Cross(Vector3.yAxis)
		side = side.Magnitude > 0.01 and side.Unit or Vector3.xAxis
		if spin then
			piece.CFrame = CFrame.fromMatrix(position, direction, side) * CFrame.Angles(0, -math.rad(spin) * elapsed, 0)
		else
			piece.CFrame = CFrame.fromMatrix(position, side, direction)
		end
		if done then
			connection:Disconnect()
			flying[id] = nil
			VFX.Stop(streak)
			if spin then
				-- a knife in a wall or the floor sticks a moment; one that
				-- struck someone, or ran out of reach in the air, fades away
				if not entry.struck and stuckInSurface(position, direction) then
					VFX.Play("Shared/Sparks", position, { color = WHITE, scale = 0.4 })
					task.delay(STUCK_TIME, tween, piece, KNIFE_FADE, { Transparency = 1 })
					Debris:AddItem(piece, STUCK_TIME + KNIFE_FADE)
				else
					tween(piece, KNIFE_FADE, { Transparency = 1, CFrame = piece.CFrame + direction * 2 - Vector3.new(0, 1.5, 0) })
					Debris:AddItem(piece, KNIFE_FADE)
				end
			else
				piece.Transparency = 1
				Debris:AddItem(piece, TRAIL_FADE)
			end
		end
	end)
end

-- where the server's copy stopped, and whether it struck someone
function effects.ProjectileEnd(id, position, struck)
	local entry = flying[id]
	if entry then
		entry.finish = position
		entry.struck = struck
	end
	local kind = projectileKinds[id]
	projectileKinds[id] = nil
	if kind == "Knife" then
		-- (a knife stuck in a wall gets its sparks where it stops)
		if struck then
			VFX.Play("Shared/Impact", position, { color = MANDELA_COLOR, scale = 0.6 })
			VFX.Play("Shared/SlashArc", position, { color = MANDELA_COLOR, rotation = math.random(0, 359), scale = 0.6 })
		end
	elseif struck then
		sparkle(position, Color3.fromRGB(255, 120, 110), 6)
	else
		flash(position, WHITE, 0.3, 1.2, 0.1)
	end
end

-- Light Shot: a thin bolt of one colour of the spectrum
function effects.LightShot(origin, finish, struck)
	local color = spectrum(math.random())
	lightBeam(origin, finish, color, 0.3, 0.25)
	flash(origin, WHITE, 0.3, 1.5, 0.1)
	flash(finish, color, 0.4, struck and 3 or 2, 0.15)
	if struck then
		sparkle(finish, color, 8)
	end
end

-- Dead Eye lining up: a red diamond closing in over the target (or the spot)
function effects.DeadEyeMark(model, point, time)
	local adornee = model and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart"))
	if not adornee then
		adornee = effectPart(Enum.PartType.Block, WHITE, Vector3.one * 0.2, CFrame.new(point), time + 0.1)
		adornee.Transparency = 1
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(56, 56)
	billboard.StudsOffsetWorldSpace = model and Vector3.new(0, 1.5, 0) or Vector3.zero
	billboard.Parent = folder
	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(1, 1)
	diamond.Rotation = 45
	diamond.BackgroundTransparency = 1
	diamond.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(235, 60, 70)
	stroke.Thickness = 3
	stroke.Parent = diamond
	tween(diamond, time, { Size = UDim2.fromScale(0.35, 0.35), Rotation = 225 })
	Debris:AddItem(billboard, time + 0.05)
end

-- an enemy's dash: a red streak behind it while it lasts
function effects.EnemyDash(root, time)
	if not root or not root.Parent then
		return
	end
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1.5, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -1.5, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 120, 110), Color3.fromRGB(120, 20, 30))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 0.4
	trail.FaceCamera = true
	trail.Parent = root
	for _, instance in ipairs({ trail, top, bottom }) do
		Debris:AddItem(instance, time + 0.25)
	end
end

-- Photoshop's looks live in their own module, built on the helpers here
local photoshopEffects = require(script:WaitForChild("PhotoshopEffects"))({
	folder = folder,
	effectPart = effectPart,
	tween = tween,
	flash = flash,
	ring = ring,
	burst = burst,
	lightBeam = lightBeam,
	ghostOf = ghostOf,
})
for kind, draw in pairs(photoshopEffects) do
	effects[kind] = draw
end

local function play(kind, ...)
	local effect = effects[kind]
	if effect then
		effect(...)
	end
end
skillEffects.OnClientEvent:Connect(play)

-- Skills whose model carries its own look (the tornado, the black hole): the
-- model's ClientEffect attribute names the module under this script that
-- draws it. They run from here rather than from inside the model, so their
-- cleanup can't be cut short when the model goes.
local modelEffects = {
	Tornado = require(script:WaitForChild("TornadoEffect")),
	BlackHole = require(script:WaitForChild("BlackHoleEffect")),
}
local function drawModel(child)
	local run = child:IsA("Model") and modelEffects[child:GetAttribute("ClientEffect") or ""]
	if run then
		task.spawn(run, child)
	end
end
workspace.ChildAdded:Connect(drawModel)
for _, child in ipairs(workspace:GetChildren()) do
	drawModel(child)
end
ReplicatedStorage:WaitForChild("LocalSkillEffect").Event:Connect(play)
