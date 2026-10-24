-- Lock-on for the local player: middle click locks onto the enemy, training
-- dummy or player outside your party (never an NPC or a party-mate) nearest
-- the cursor (on screen, within RANGE) and again lets go. While
-- locked the camera turns to keep them in view (zoom and the shift lock
-- shoulder kept), the body faces them, a reticle spins over them, and a hard
-- flick of the camera (right-drag, or any mouse move in shift lock) switches
-- to the next one that side. It lets go when they die (moving on to the next
-- in view, if any), leave, turn invulnerable or get past BREAK_RANGE.
-- SkillBar, Ranged and Punch aim at Target() while it's set. Runs once, on
-- whichever of them requires it first.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MasteryRules = require(ReplicatedStorage:WaitForChild("MasteryRules"))

local player = Players.LocalPlayer

local RANGE = 90 -- studs, to lock on
local BREAK_RANGE = 120 -- studs, it lets go past this
local DISTANCE_WEIGHT = 3 -- px of cursor distance one stud of distance is worth when picking
local PITCH = math.rad(12) -- the camera looks this far below the line to the target
local CAMERA_SMOOTH = 12 -- per second
local FLICK_PIXELS = 60 -- mouse movement, within about FLICK_WINDOW, that switches target
local FLICK_WINDOW = 0.15 -- seconds
local SWITCH_COOLDOWN = 0.25 -- seconds between two switches
local RETICLE_SIZE = 44 -- px
local RETICLE_SPIN = 90 -- degrees per second
local RENDER_STEP_NAME = "LockOn"

local LockOn = {}

local targetHumanoid -- Humanoid locked onto, or nil
local reticle -- BillboardGui over them
local bound = false -- update is on the render step
local flick = 0
local lastFlickAt = 0
local lastSwitchAt = -math.huge

-- enemies, training dummies and players outside your party
local function lockable(model)
	if CollectionService:HasTag(model, "Enemy") or CollectionService:HasTag(model, MasteryRules.DummyTag) then
		return true
	end
	local other = Players:GetPlayerFromCharacter(model)
	if not other or other == player then
		return false
	end
	local party = player:GetAttribute("PartyId")
	return party == nil or other:GetAttribute("PartyId") ~= party
end

-- the target's root part, if they still count as a target
local function rootOf(humanoid)
	local model = humanoid and humanoid.Parent
	local root = humanoid and humanoid.RootPart
	if
		not root
		or not model
		or not model.Parent
		or humanoid.Health <= 0
		or model:GetAttribute("Invulnerable")
		or not lockable(model)
	then
		return nil
	end
	return root
end

-- everyone that could be locked onto, with where they are on screen
local function candidates()
	local character = player.Character
	local ownRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not ownRoot then
		return {}
	end
	local camera = workspace.CurrentCamera
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local list = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(ownRoot.Position, RANGE, params)) do
		local humanoid = part.Name == "HumanoidRootPart" and part.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and rootOf(humanoid) then
			local screen, onScreen = camera:WorldToViewportPoint(part.Position)
			if onScreen then
				table.insert(list, {
					humanoid = humanoid,
					x = screen.X,
					y = screen.Y,
					distance = (part.Position - ownRoot.Position).Magnitude,
				})
			end
		end
	end
	return list
end

-- the one nearest the cursor (the screen's centre in shift lock), nearer ones first
local function pickNearCursor()
	local mouse = UserInputService:GetMouseLocation()
	local best, bestScore
	for _, entry in ipairs(candidates()) do
		local score = (Vector2.new(entry.x, entry.y) - mouse).Magnitude + entry.distance * DISTANCE_WEIGHT
		if not bestScore or score < bestScore then
			best, bestScore = entry.humanoid, score
		end
	end
	return best
end

-- the next one on screen to the left (-1) or right (1) of the current target
local function pickSide(direction)
	local root = rootOf(targetHumanoid)
	if not root then
		return nil
	end
	local current = workspace.CurrentCamera:WorldToViewportPoint(root.Position)
	local best, bestScore
	for _, entry in ipairs(candidates()) do
		local dx = (entry.x - current.X) * direction
		if entry.humanoid ~= targetHumanoid and dx > 8 then
			local score = dx + math.abs(entry.y - current.Y) * 0.5
			if not bestScore or score < bestScore then
				best, bestScore = entry.humanoid, score
			end
		end
	end
	return best
end

-- a placeholder reticle: four white corner brackets with a dark edge, spinning
local function buildReticle()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LockOnReticle"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(RETICLE_SIZE, RETICLE_SIZE)
	billboard.ResetOnSpawn = false
	local spinner = Instance.new("Frame")
	spinner.Name = "Spinner"
	spinner.BackgroundTransparency = 1
	spinner.Size = UDim2.fromScale(1, 1)
	spinner.Parent = billboard
	local scale = Instance.new("UIScale")
	scale.Parent = spinner
	local LENGTH, THICK = 0.32, 3
	for _, corner in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
		for _, horizontal in ipairs({ true, false }) do
			local bar = Instance.new("Frame")
			bar.BackgroundColor3 = Color3.new(1, 1, 1)
			bar.BorderSizePixel = 0
			bar.AnchorPoint = corner
			bar.Position = UDim2.fromScale(corner.X, corner.Y)
			bar.Size = horizontal and UDim2.new(LENGTH, 0, 0, THICK) or UDim2.new(0, THICK, LENGTH, 0)
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(0, 0, 0)
			stroke.Transparency = 0.4
			stroke.Parent = bar
			bar.Parent = spinner
		end
	end
	billboard.Parent = player:WaitForChild("PlayerGui")
	return billboard
end

local function showReticle(root)
	reticle = reticle or buildReticle()
	reticle.Adornee = root
	reticle.Enabled = true
	-- snaps in from bigger each time it lands on someone
	local scale = reticle.Spinner.UIScale
	scale.Scale = 1.8
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function ownHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local update

local function setTarget(humanoid)
	targetHumanoid = humanoid
	flick = 0
	if humanoid then
		showReticle(humanoid.RootPart)
		if not bound then
			bound = true
			RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 2, update)
		end
	else
		if bound then
			bound = false
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end
		if reticle then
			reticle.Enabled = false
			reticle.Adornee = nil
		end
		-- ShiftLock sets this itself every frame while it's on
		local own = ownHumanoid()
		if own then
			own.AutoRotate = true
		end
	end
end

-- runs right after the camera (and ShiftLock) each frame
function update(dt)
	local humanoid = ownHumanoid()
	local root = humanoid and humanoid.RootPart
	local targetRoot = rootOf(targetHumanoid)
	if not root or humanoid.Health <= 0 then
		setTarget(nil)
		return
	end
	if not targetRoot or (targetRoot.Position - root.Position).Magnitude > BREAK_RANGE then
		-- a downed target hands over to the next in view
		local dead = targetHumanoid and targetHumanoid.Health <= 0
		setTarget(dead and pickNearCursor() or nil)
		return
	end
	reticle.Spinner.Rotation = (reticle.Spinner.Rotation + RETICLE_SPIN * dt) % 360

	-- the camera turns about what it follows, so zoom and the shoulder offset stay
	local camera = workspace.CurrentCamera
	if camera.CameraType == Enum.CameraType.Custom then
		local current = camera.CFrame
		local focus = camera.Focus.Position
		local toward = targetRoot.Position - focus
		local flatLength = Vector3.new(toward.X, 0, toward.Z).Magnitude
		if flatLength > 1 then
			local yaw = math.atan2(-toward.X, -toward.Z)
			local pitch = math.clamp(math.atan2(toward.Y, flatLength) - PITCH, math.rad(-70), math.rad(60))
			local wanted = current.Rotation:Lerp(CFrame.fromEulerAnglesYXZ(pitch, yaw, 0), 1 - math.exp(-CAMERA_SMOOTH * dt))
			local offset = current.Rotation:Inverse() * (current.Position - focus)
			camera.CFrame = CFrame.new(focus + wanted * offset) * wanted
		end
	end

	-- the body faces them, as ShiftLock faces the camera
	local swimming = humanoid.Parent:GetAttribute("Swimming") == true
	humanoid.AutoRotate = swimming
	if
		swimming
		or humanoid.Sit
		or player:GetAttribute("Dashing")
		or humanoid.Parent:GetAttribute("Flying")
	then
		return
	end
	local flat = Vector3.new(targetRoot.Position.X - root.Position.X, 0, targetRoot.Position.Z - root.Position.Z)
	if flat.Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton3 then
		return
	end
	if targetHumanoid then
		setTarget(nil)
	else
		setTarget(pickNearCursor())
	end
end)

-- a hard flick of the camera switches target that way
UserInputService.InputChanged:Connect(function(input)
	if not targetHumanoid or input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local turning = UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default
	if not turning then
		return
	end
	local now = os.clock()
	flick = flick * math.exp(-(now - lastFlickAt) / FLICK_WINDOW) + input.Delta.X
	lastFlickAt = now
	if math.abs(flick) >= FLICK_PIXELS and now - lastSwitchAt >= SWITCH_COOLDOWN then
		local nextTarget = pickSide(flick > 0 and 1 or -1)
		flick = 0
		if nextTarget then
			lastSwitchAt = now
			setTarget(nextTarget)
		end
	end
end)

player.CharacterAdded:Connect(function()
	setTarget(nil)
end)

-- the Humanoid locked onto and its root part, or nil
function LockOn.Target()
	local root = rootOf(targetHumanoid)
	if root then
		return targetHumanoid, root
	end
	return nil
end

return LockOn
