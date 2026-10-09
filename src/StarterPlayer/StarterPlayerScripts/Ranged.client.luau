-- The ranged move of the skill set in hand (its SkillSetConfig `ranged`):
-- hold right click to ready it and left click to fire. A set whose shots
-- `aims` shows a crosshair and turns to fire where it points (the Revolver
-- also zooms in); one that doesn't throws straight ahead.
-- A `primary` ranged weapon (the Revolver) fires on left click without
-- readying, in place of punches, and the reload key (R unless rebound,
-- Keybinds) reloads it. While left click belongs to this, the local
-- RangedReady attribute is set and Punch leaves it alone.
-- RangedServer checks and pays for every shot; this draws the shooter's own
-- straight away (SkillEffects, through LocalSkillEffect).
-- Aim assist: while a move that aims is readied, everyone it could hit gets
-- a circle round them; firing with the crosshair inside one locks the shot
-- onto them (sent along with it) and it steers in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local fireRanged = ReplicatedStorage:WaitForChild("FireRanged")
local localSkillEffect = ReplicatedStorage:WaitForChild("LocalSkillEffect")
local player = Players.LocalPlayer

local AIM_DISTANCE = 1000
local ZOOM_TIME = 0.15 -- seconds to zoom in or out
local CROSSHAIR_SIZE = 14 -- pixels, aimed
local HIP_CROSSHAIR_SIZE = 24 -- pixels, shooting from the hip (shots stray)
local SHOT_PRIORITY = Enum.AnimationPriority.Action3
local READY_ATTRIBUTE = "RangedReady"
local ASSIST_RADIUS = SkillSetConfig.AimAssistRadius
local LOCKED_COLOR = Color3.new(1, 1, 1)
local SEE_THROUGH = 0.95 -- as on the server (Projectiles): such parts don't stop a shot

local readying = false -- right mouse held
local firing = false -- left mouse held, for this
local lastShotAt = -math.huge
local shotCount = 0
local normalFov -- the camera's own field of view, while zoomed in
local crosshairShown = false

-- the crosshair: a small square with a dot, following the mouse
local gui = Instance.new("ScreenGui")
gui.Name = "RangedCrosshair"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")
local crosshair = Instance.new("Frame")
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(CROSSHAIR_SIZE, CROSSHAIR_SIZE)
crosshair.BackgroundTransparency = 1
crosshair.Parent = gui
local ring = Instance.new("UIStroke")
ring.Thickness = 1.5
ring.Parent = crosshair
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(3, 3)
dot.BorderSizePixel = 0
dot.Parent = crosshair

-- Aim assist: every character in the world (other than ours), each one's
-- circle once it has needed one, and the one the crosshair is inside
local candidates = {} -- Humanoid -> true
local circles = {} -- Humanoid -> BillboardGui
local locked -- Humanoid, while a readied shot would lock onto it
local circlesShown = false

local function track(instance)
	if instance:IsA("Humanoid") then
		candidates[instance] = true
	end
end
for _, descendant in ipairs(workspace:GetDescendants()) do
	track(descendant)
end
workspace.DescendantAdded:Connect(track)
workspace.DescendantRemoving:Connect(function(instance)
	if candidates[instance] then
		candidates[instance] = nil
		if circles[instance] then
			circles[instance]:Destroy()
			circles[instance] = nil
		end
	end
end)

local function circleFor(humanoid)
	local billboard = circles[humanoid]
	if billboard then
		return billboard
	end
	billboard = Instance.new("BillboardGui")
	billboard.Name = "AimAssist"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false
	billboard.Enabled = false
	-- sized in studs, so it covers the same stretch of the world as the hitbox
	billboard.Size = UDim2.fromScale(ASSIST_RADIUS * 2, ASSIST_RADIUS * 2)
	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundColor3 = LOCKED_COLOR
	circle.BackgroundTransparency = 1
	circle.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = circle
	local stroke = Instance.new("UIStroke")
	stroke.Parent = circle
	billboard.Parent = player:WaitForChild("PlayerGui")
	circles[humanoid] = billboard
	return billboard
end

-- the character a part belongs to (through any models it's nested in)
local function humanoidOf(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- whether a shot from `from` would get to `humanoid` before anything else
-- (like Projectiles.Cast: dead bodies, see-through parts and parts nothing
-- collides with don't count)
local function inSight(character, from, humanoid)
	local ignore = { character }
	local effectsFolder = workspace:FindFirstChild("SkillEffects")
	if effectsFolder then
		table.insert(ignore, effectsFolder)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local offset = humanoid.RootPart.Position - from
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, offset, params)
		if not hit then
			return true
		end
		local struck = humanoidOf(hit.Instance)
		if struck == humanoid then
			return true
		elseif struck and struck.Health > 0 then
			return false
		elseif struck then
			table.insert(ignore, struck.Parent)
		elseif hit.Instance.CanCollide and hit.Instance.Transparency < SEE_THROUGH then
			return false
		else
			table.insert(ignore, hit.Instance)
		end
	end
	return false
end

-- While `ranged` (which aims) is readied: circles round everyone within its
-- reach and in sight, and `locked` set to the one whose circle the
-- crosshair is inside (the nearest middle wins). Otherwise none.
local function updateAssist(active, character, ranged, color)
	locked = nil
	local root = active and character:FindFirstChild("HumanoidRootPart")
	local from = root and SkillSetConfig.ShotOrigin(character)
	if not from then
		if circlesShown then
			circlesShown = false
			for _, billboard in pairs(circles) do
				billboard.Enabled = false
			end
		end
		return
	end
	circlesShown = true
	local camera = workspace.CurrentCamera
	local reach = SkillSetConfig.RangedReach(ranged)
	local mouse = UserInputService:GetMouseLocation()
	local bestOff
	for humanoid in pairs(candidates) do
		local model = humanoid.Parent
		local targetRoot = humanoid.RootPart
		local shown = false
		if
			targetRoot
			and model ~= character
			and humanoid.Health > 0
			and not model:GetAttribute("Invulnerable")
			and (targetRoot.Position - root.Position).Magnitude <= reach
		then
			local center, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
			if onScreen and inSight(character, from, humanoid) then
				shown = true
				-- how far the crosshair is from the middle, in circle radii
				local edge = camera:WorldToViewportPoint(targetRoot.Position + camera.CFrame.RightVector * ASSIST_RADIUS)
				local radius = math.max((Vector2.new(edge.X, edge.Y) - Vector2.new(center.X, center.Y)).Magnitude, 1)
				local off = (Vector2.new(center.X, center.Y) - mouse).Magnitude / radius
				if off <= 1 and (not bestOff or off < bestOff) then
					locked, bestOff = humanoid, off
				end
			end
		end
		if shown then
			local billboard = circleFor(humanoid)
			billboard.Adornee = targetRoot
			billboard.Enabled = true
		elseif circles[humanoid] then
			circles[humanoid].Enabled = false
		end
	end
	-- the one a shot would lock onto lights up
	for humanoid, billboard in pairs(circles) do
		if billboard.Enabled then
			local isLocked = humanoid == locked
			billboard.Circle.BackgroundTransparency = isLocked and 0.85 or 1
			billboard.Circle.UIStroke.Color = isLocked and LOCKED_COLOR or color
			billboard.Circle.UIStroke.Thickness = isLocked and 3 or 1.5
		end
	end
end

-- the set in hand and its ranged move, while alive (and not being rewound
-- by Photoshop's Undo)
local function heldSet()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not humanoid.RootPart or character:GetAttribute("Rewinding") then
		return nil
	end
	local _, setName = SkillSetConfig.Equipped(character)
	local ranged = setName and SkillSetConfig.Sets[setName].ranged
	if not ranged then
		return nil
	end
	return setName, ranged, character, humanoid
end

local function mousePoint(character)
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("SkillEffects") }
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	return result and result.Position or ray.Origin + ray.Direction * AIM_DISTANCE
end

-- whether a shot can be paid for right now (the server checks again)
local function canFire(setName, ranged)
	if os.clock() - lastShotAt < ranged.interval then
		return false
	end
	if ranged.charges then
		return SkillSetConfig.RangedCharges(player, setName) >= 1
	elseif ranged.luminanceCost then
		return (player:GetAttribute(SkillSetConfig.LuminanceAttribute(setName)) or 0) >= ranged.luminanceCost - 1e-6
	elseif ranged.rounds then
		local rounds, reloading = SkillSetConfig.Rounds(player, setName)
		return rounds >= 1 and reloading <= 0
	end
	return true
end

-- `direction` turned up to `degrees` off, for shots from the hip
local function stray(direction, degrees)
	local yaw = math.rad((math.random() * 2 - 1) * degrees)
	local pitch = math.rad((math.random() * 2 - 1) * degrees)
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(pitch, yaw, 0)).LookVector
end

local shotTracks = setmetatable({}, { __mode = "k" })

-- the set's animation for the move, once it's published
local function playShot(humanoid, setName, ranged)
	local folder = ranged.animation and ReplicatedStorage:FindFirstChild(setName .. "Animations")
	local animation = folder and folder:FindFirstChild(ranged.animation)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animation or animation.AnimationId == "" or not animator then
		return
	end
	local tracks = shotTracks[animator]
	if not tracks then
		tracks = {}
		shotTracks[animator] = tracks
	end
	if not tracks[animation] then
		tracks[animation] = animator:LoadAnimation(animation)
		tracks[animation].Priority = SHOT_PRIORITY
	end
	tracks[animation]:Play(0.05)
end

local function reload()
	local setName, ranged = heldSet()
	if not setName or not ranged.rounds then
		return
	end
	local rounds, reloading = SkillSetConfig.Rounds(player, setName)
	if reloading <= 0 and rounds < ranged.rounds then
		fireRanged:FireServer("reload")
	end
end

local function fire()
	local setName, ranged, character, humanoid = heldSet()
	if not setName then
		return
	end
	if not canFire(setName, ranged) then
		-- clicking an empty cylinder reloads it
		if ranged.rounds and SkillSetConfig.Rounds(player, setName) < 1 then
			reload()
		end
		return
	end
	local root = humanoid.RootPart
	local direction
	-- locked on by aim assist: straight at them, and it steers in from there
	local target = ranged.aims and readying and locked and locked.RootPart and locked or nil
	if ranged.aims then
		-- turn to face where it's going, so it leaves from the front
		local point = target and target.RootPart.Position or mousePoint(character)
		local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
		if flat.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
		local origin = SkillSetConfig.ShotOrigin(character)
		direction = point - origin
		if direction.Magnitude < 0.5 then
			direction = root.CFrame.LookVector
		end
		direction = direction.Unit
		if ranged.hipSpread and not readying then
			direction = stray(direction, ranged.hipSpread)
		end
	else
		direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	end
	local origin = SkillSetConfig.ShotOrigin(character)
	lastShotAt = os.clock()
	shotCount += 1
	local id = player.UserId .. ":" .. shotCount
	fireRanged:FireServer("fire", origin, direction, id, target and target.Parent)
	playShot(humanoid, setName, ranged)
	-- drawn here straight away; everyone else sees the server's copy
	if ranged.projectile then
		local flight = ranged.projectile
		localSkillEffect:Fire(
			"Projectile",
			id,
			flight.model,
			origin,
			direction,
			flight.speed,
			flight.range,
			flight.spin,
			flight.flash,
			target and target.RootPart
		)
	elseif ranged.beam then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, workspace:FindFirstChild("SkillEffects") }
		local hit = workspace:Raycast(origin, direction * ranged.beam.range, params)
		localSkillEffect:Fire(ranged.beam.effect or "LightShot", origin, hit and hit.Position or origin + direction * ranged.beam.range, false)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or Keybinds.Capturing() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		readying = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		local _, ranged = heldSet()
		if ranged and (ranged.primary or readying) then
			firing = true
			fire()
		end
	elseif input.KeyCode == Keybinds.Key("Reload") then -- R unless rebound in Settings
		reload()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		readying = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
	end
end)

local function zoomTo(fov)
	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(ZOOM_TIME), { FieldOfView = fov }):Play()
end

RunService.RenderStepped:Connect(function()
	local setName, ranged, character = heldSet()
	local ready = ranged ~= nil and (ranged.primary == true or readying)
	if player:GetAttribute(READY_ATTRIBUTE) ~= ready then
		player:SetAttribute(READY_ATTRIBUTE, ready)
	end
	-- aim assist only while actually aiming (not shooting from the hip)
	updateAssist(ranged ~= nil and ranged.aims == true and readying, character, ranged, setName and SkillSetConfig.Sets[setName].color)
	-- holding left click keeps firing, as fast as the move allows
	if not ready then
		firing = false
	elseif firing then
		fire()
	end

	-- the crosshair stands in for the mouse while shots go where it points
	local showCrosshair = ready and ranged.aims == true
	if showCrosshair ~= crosshairShown then
		crosshairShown = showCrosshair
		gui.Enabled = showCrosshair
		UserInputService.MouseIconEnabled = not showCrosshair
	end
	if showCrosshair then
		local mouse = UserInputService:GetMouseLocation()
		local color = SkillSetConfig.Sets[setName].color
		local size = (ranged.hipSpread and not readying) and HIP_CROSSHAIR_SIZE or CROSSHAIR_SIZE
		crosshair.Position = UDim2.fromOffset(mouse.X, mouse.Y)
		crosshair.Size = UDim2.fromOffset(size, size)
		-- white while a shot would lock on
		ring.Color = locked and LOCKED_COLOR or color
		dot.BackgroundColor3 = locked and LOCKED_COLOR or color
	end

	-- aiming a gun zooms in
	local zoom = ranged and ranged.zoom and readying and ranged.zoom
	if zoom and not normalFov then
		normalFov = workspace.CurrentCamera.FieldOfView
		zoomTo(zoom)
	elseif not zoom and normalFov then
		zoomTo(normalFov)
		normalFov = nil
	end
end)
