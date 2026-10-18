-- Aido's looks, drawn for the SkillEffects events his skills send (Skills.Fuse,
-- Catastrophe, Collapse, TotalDestruction, GroundZero, FinalCut, AtomicBreath,
-- and AidoUtil's blasts, Fallout and aftershocks), in the set's red and hot
-- core. PLACEHOLDERS until the owner's VFX pack pass: each effect plays the
-- VFXPrefabs.Aido/<Kind> prefab when there is one, else a red-tinted
-- Shared/* prefab and simple parts. Also draws Final Cut from the character's
-- FinalCut attribute for everyone: the dragon copy the server welds on
-- (FinalCutDragon) with its idle/walk/breath animations from
-- ReplicatedStorage.AidoAnimations, his own body hidden, and (for the local
-- player) the camera kept back; with no dragon model, a red aura instead.
-- Also glows anyone melting down (their character's Meltdown attribute).
-- Returns a function that takes the SkillEffects script's own helpers and
-- gives back the effects by name, which that script adds to its own.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local VFX = require(ReplicatedStorage:WaitForChild("VFX"))

local RED = SkillSetConfig.AidoRed
local CORE = SkillSetConfig.AidoCore
local WHITE = Color3.new(1, 1, 1)
local FORM = SkillSetConfig.Sets.Aido.form
local DRAGON_FOLDER = "FinalCutDragon" -- the server's welded copy, in the character
local WALK_SPEED = 2 -- studs per second of root speed that counts as walking

local localPlayer = Players.LocalPlayer

-- plays VFXPrefabs.Aido/<name> if the owner has made it, else `fallback`
-- (a Shared prefab) tinted red
local function playPrefab(name, fallback, where, scale)
	local path = VFX.Find("Aido/" .. name) and "Aido/" .. name or fallback
	return VFX.Play(path, where, { color = RED, scale = scale })
end

return function(helpers)
	local effectPart = helpers.effectPart
	local tween = helpers.tween
	local flash = helpers.flash
	local ring = helpers.ring
	local lightBeam = helpers.lightBeam

	local effects = {}

	-- a blast: the fireball and ground ring, the core flash, rubble and a quake
	local function blast(name, position, radius, options)
		options = options or {}
		local scale = math.clamp(radius / 12, 0.4, options.maxScale or 3)
		playPrefab(name, "Shared/BigImpact", position + Vector3.new(0, 2, 0), scale)
		VFX.Play("Shared/Shockwave", CFrame.new(position + Vector3.new(0, 0.2, 0)), { color = RED, scale = radius / 12 })
		flash(position + Vector3.new(0, 2, 0), CORE, radius * 0.3, radius * 1.4, 0.3)
		ring(position + Vector3.new(0, 0.3, 0), RED, radius * 0.5, radius * 2, 0.45)
		if options.crater then
			VFX.Crater(position, math.clamp(radius * 0.45, 3, 14))
		end
		if options.shake then
			VFX.Shake(position, options.shake, radius * 3)
		end
		if options.frame then
			VFX.ImpactFrameNear(position, radius + 3)
		end
	end

	function effects.CatastropheBlast(position, radius)
		blast("CatastropheBlast", position, radius, { crater = true, shake = "Heavy", frame = true })
	end

	function effects.CollapseBlast(position, radius)
		blast("CollapseBlast", position, radius, { crater = true, shake = "Medium" })
	end

	function effects.TotalDestructionBlast(position, radius)
		blast("TotalDestructionBlast", position, radius, { shake = "Light", maxScale = 1.2 })
	end

	function effects.GroundZeroBlast(position, radius)
		blast("GroundZeroBlast", position, radius, { crater = true, shake = "Heavy", frame = true, maxScale = 5 })
		flash(position + Vector3.new(0, 6, 0), WHITE, radius * 0.2, radius * 1.1, 0.5)
	end

	function effects.FinalCutRoar(position, radius)
		playPrefab("FinalCutRoar", "Shared/AuraBurst", position, 1.5)
		blast("FinalCutBlast", position, radius, { crater = true, shake = "Heavy" })
	end

	function effects.FuseBlast(position, radius)
		playPrefab("FuseBlast", "Shared/Impact", position + Vector3.new(0, 1, 0), math.clamp(radius / 6, 0.5, 1.3))
		flash(position, CORE, radius * 0.3, radius * 1.2, 0.2)
	end

	function effects.Aftershock(position, radius)
		playPrefab("Aftershock", "Shared/Impact", position + Vector3.new(0, 1, 0), 0.8)
		flash(position, CORE, radius * 0.3, radius * 1.1, 0.2)
		VFX.Shake(position, "Light", radius * 4)
	end

	-- Fuse: the seed glows where it stuck (on a person it rides along) until it pops
	local seeds = {} -- id -> the part
	function effects.FuseStick(id, attachTo, position)
		local seed = effectPart(Enum.PartType.Ball, CORE, Vector3.one * 0.9, CFrame.new(position), 1.6)
		seeds[id] = seed
		if attachTo and attachTo.Parent then
			seed.Anchored = false
			seed.CFrame = attachTo.CFrame * CFrame.new(0, 0.5, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = attachTo
			weld.Part1 = seed
			weld.Parent = seed
		end
		tween(seed, 1, { Size = Vector3.one * 1.8, Color = RED })
	end

	function effects.FusePop(id)
		local seed = seeds[id]
		seeds[id] = nil
		if seed then
			seed:Destroy()
		end
	end

	-- Catastrophe: a warhead on the ground with a ring closing in on it
	function effects.CatastropheArm(_, position, fuseTime)
		local warhead = effectPart(Enum.PartType.Ball, CORE, Vector3.one * 2, CFrame.new(position + Vector3.new(0, 1.5, 0)), fuseTime + 0.2)
		tween(warhead, fuseTime, { Size = Vector3.one * 3.2, Color = RED })
		ring(position + Vector3.new(0, 0.2, 0), RED, 30, 4, fuseTime, 0.2)
	end

	-- Collapse: rings racing inward
	function effects.CollapsePull(position, reach, time)
		ring(position + Vector3.new(0, 0.3, 0), RED, reach * 2, 2, time, 0.3)
		task.delay(time * 0.4, ring, position + Vector3.new(0, 0.3, 0), CORE, reach * 1.3, 2, time * 0.6, 0.2)
		flash(position + Vector3.new(0, 3, 0), RED, reach * 0.4, 1, time)
	end

	-- Fallout: a red patch on the ground for as long as it burns
	local patches = {} -- id -> { part, holder }
	function effects.Fallout(id, centre, radius, duration)
		local disc = effectPart(
			Enum.PartType.Cylinder,
			RED,
			Vector3.new(0.2, radius * 2, radius * 2),
			CFrame.new(centre + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			duration + 2
		)
		disc.Transparency = 0.8
		local holder = VFX.Find("Aido/Fallout") and VFX.Play("Aido/Fallout", centre, { color = RED, scale = radius / 10, hold = duration }) or nil
		patches[id] = { part = disc, holder = holder }
	end

	function effects.FalloutEnd(id)
		local patch = patches[id]
		patches[id] = nil
		if patch then
			tween(patch.part, 0.6, { Transparency = 1 })
			VFX.Stop(patch.holder)
		end
	end

	-- Ground Zero: the circle on the ground and a big 3-2-1 over it
	function effects.GroundZeroCountdown(_, centre, radius, time)
		local disc = effectPart(
			Enum.PartType.Cylinder,
			RED,
			Vector3.new(0.2, radius * 2, radius * 2),
			CFrame.new(centre + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			time + 0.3
		)
		disc.Transparency = 0.85
		tween(disc, time, { Transparency = 0.55 })
		ring(centre + Vector3.new(0, 0.3, 0), RED, radius * 2, radius * 0.4, time, 0.3)
		local anchor = effectPart(Enum.PartType.Block, WHITE, Vector3.one * 0.2, CFrame.new(centre + Vector3.new(0, 12, 0)), time + 0.3)
		anchor.Transparency = 1
		local billboard = Instance.new("BillboardGui")
		billboard.Adornee = anchor
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(160, 160)
		billboard.Parent = anchor
		local number = Instance.new("TextLabel")
		number.BackgroundTransparency = 1
		number.Size = UDim2.fromScale(1, 1)
		number.Font = Enum.Font.Highway
		number.TextScaled = true
		number.TextColor3 = WHITE
		number.TextStrokeColor3 = Color3.fromRGB(60, 0, 0)
		number.TextStrokeTransparency = 0
		number.Parent = billboard
		task.spawn(function()
			local startedAt = os.clock()
			while billboard.Parent and os.clock() - startedAt < time do
				number.Text = tostring(math.ceil(time - (os.clock() - startedAt)))
				task.wait(0.1)
			end
		end)
	end

	-- Atomic Breath: a thick red beam with a hot core
	function effects.AtomicBreath(origin, finish, struck)
		lightBeam(origin, finish, RED, 1.4, 0.25)
		lightBeam(origin, finish, CORE, 0.6, 0.25)
		flash(origin, CORE, 0.8, 2.5, 0.15)
		flash(finish, RED, 1, struck and 4.5 or 3, 0.2)
	end

	-- Final Cut, drawn from the character's FinalCut attribute ---------------

	local function watchForm(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		local active -- while the form is on: { aura, step, restore }

		local function begin()
			local state = {}
			local dragonFolder = character:WaitForChild(DRAGON_FOLDER, 1)
			local dragon = dragonFolder and dragonFolder:FindFirstChildOfClass("Model")
			if dragon then
				-- his body gives way to the dragon (the camera resets this, so every frame)
				local tracks = {}
				local controller = dragon:FindFirstChildOfClass("AnimationController")
				local animator = controller and controller:FindFirstChildOfClass("Animator")
				local animations = ReplicatedStorage:FindFirstChild("AidoAnimations")
				if animator and animations then
					for _, name in ipairs({ "DragonIdle", "DragonWalk", "DragonBreath" }) do
						local animation = animations:FindFirstChild(name)
						if animation then
							tracks[name] = animator:LoadAnimation(animation)
							tracks[name].Looped = name ~= "DragonBreath"
						end
					end
				end
				local playing
				local function setTrack(name)
					local track = tracks[name]
					if track and playing ~= track then
						if playing then
							playing:Stop(0.2)
						end
						track:Play(0.2)
						playing = track
					end
				end
				state.step = RunService.RenderStepped:Connect(function()
					for _, part in ipairs(character:GetDescendants()) do
						if part:IsA("BasePart") and not part:IsDescendantOf(dragonFolder) then
							part.LocalTransparencyModifier = 1
						end
					end
					local breathing = character == localPlayer.Character and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
					if breathing and tracks.DragonBreath then
						setTrack("DragonBreath")
					elseif root.AssemblyLinearVelocity.Magnitude > WALK_SPEED and tracks.DragonWalk then
						setTrack("DragonWalk")
					else
						setTrack("DragonIdle")
					end
				end)
				state.restore = function()
					if playing then
						playing:Stop(0.2)
					end
					for _, part in ipairs(character:GetDescendants()) do
						if part:IsA("BasePart") then
							part.LocalTransparencyModifier = 0
						end
					end
				end
			else
				-- no dragon model yet: a red aura on him instead
				state.aura = playPrefab("FinalCutAura", "Shared/AuraBurst", root, 1.5)
			end
			if character == localPlayer.Character then
				local before = localPlayer.CameraMinZoomDistance
				localPlayer.CameraMinZoomDistance = math.max(before, FORM.camera)
				local restoreZoom = state.restore
				state.restore = function()
					localPlayer.CameraMinZoomDistance = before
					if restoreZoom then
						restoreZoom()
					end
				end
			end
			return state
		end

		local function undo(state)
			if state.step then
				state.step:Disconnect()
			end
			if state.restore then
				state.restore()
			end
			VFX.Stop(state.aura)
		end

		local function finish()
			if active then
				undo(active)
				active = nil
			end
		end

		local function update()
			local on = character:GetAttribute(FORM.attribute) == true
			if on and not active then
				-- the server attaches the dragon just after setting the attribute
				task.spawn(function()
					if active or character:GetAttribute(FORM.attribute) ~= true then
						return
					end
					local state = begin()
					-- (the form may have ended while it waited for the dragon)
					if character:GetAttribute(FORM.attribute) == true and not active then
						active = state
					else
						undo(state)
					end
				end)
			elseif not on then
				finish()
			end
		end
		character:GetAttributeChangedSignal(FORM.attribute):Connect(update)
		character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(workspace) then
				finish()
			end
		end)
		update()
	end

	-- Meltdown: a red glow (and a held aura) on whoever is melting down
	local function watchMeltdown(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		local glow, aura
		local function update()
			local on = character:GetAttribute("Meltdown") == true
			if on and not glow then
				glow = Instance.new("Highlight")
				glow.Name = "MeltdownGlow"
				glow.FillColor = RED
				glow.FillTransparency = 0.6
				glow.OutlineColor = CORE
				glow.OutlineTransparency = 0.1
				glow.Parent = character
				aura = playPrefab("Meltdown", "Shared/AuraBurst", root, 1.2)
			elseif not on and glow then
				glow:Destroy()
				glow = nil
				VFX.Stop(aura)
				aura = nil
			end
		end
		character:GetAttributeChangedSignal("Meltdown"):Connect(update)
		update()
	end

	local function watchPlayer(other)
		other.CharacterAdded:Connect(watchForm)
		other.CharacterAdded:Connect(watchMeltdown)
		if other.Character then
			task.spawn(watchForm, other.Character)
			task.spawn(watchMeltdown, other.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in ipairs(Players:GetPlayers()) do
		watchPlayer(other)
	end

	return effects
end
