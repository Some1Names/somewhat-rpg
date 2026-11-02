-- Shift lock everyone gets without turning on Roblox's Shift Lock Switch
-- setting: it is always on (the mouse locked to the center, the character turned
-- with the camera, the camera over the shoulder), except while Left Alt is held, which frees the
-- camera and mouse, and while a menu or the title screen is up. While it's on, the mouse
-- is hidden and a crosshair is drawn in the middle instead, in the Crosshair setting's
-- style (Crosshair; NONE draws nothing). While something is locked onto (LockOn), shift
-- lock or not, it sits on them instead and the mouse stays hidden: the cursor is where every
-- move aims. It steps aside while a ranged move shows its own crosshair (Ranged's
-- RangedCrosshair gui, which goes onto the target too), and for the mouse while a
-- menu is open (Menus). Switching slides the camera to and from the shoulder and eases the
-- character round to face the camera, rather than snapping (TRANSITION_TIME). The Shoulder
-- side setting puts the camera over the left shoulder instead.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local Crosshair = require(script.Parent:WaitForChild("Crosshair"))
local LockOn = require(script.Parent:WaitForChild("LockOn"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local player = Players.LocalPlayer

local FREE_KEY = Enum.KeyCode.LeftAlt -- held: the camera and mouse are free
local SHOULDER_OFFSET = Vector3.new(1.75, 0, 0)
local CROSSHAIR_SIZE = 24 -- px, the room the crosshair is drawn in
local RENDER_STEP_NAME = "ShiftLock"
local CROSSHAIR_STEP_NAME = "ShiftLockCrosshair"
local TRANSITION_TIME = 0.25 -- seconds the camera takes to slide to or from the shoulder
local TURN_RATE = 18 -- how fast the character eases round to the camera while it slides in

local locked = false
local lockedAt = 0 -- os.clock() when shift lock last turned on
local offsetTween
local menuOpen = false
Menus.OnChange(function(name)
	menuOpen = name ~= nil
end)

-- the crosshair, in real pixels (UIScale skips it) so it can sit on a point of the screen
local gui = Instance.new("ScreenGui")
gui.Name = "ShiftLockCrosshair"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Size = UDim2.fromOffset(CROSSHAIR_SIZE, CROSSHAIR_SIZE)
holder.BackgroundTransparency = 1
holder.Parent = gui

-- drawn again whenever the setting changes
local drawnStyle
local function drawCrosshair()
	local style = Preferences.Choice("Xhair")
	if style ~= drawnStyle then
		drawnStyle = style
		Crosshair.Build(holder, style)
	end
end
Preferences.Changed(drawCrosshair)
drawCrosshair()

-- a ranged move's crosshair, when it's showing, stands in for this one
local function rangedCrosshairShown()
	local ranged = player.PlayerGui:FindFirstChild("RangedCrosshair")
	return ranged ~= nil and ranged.Enabled
end

local function currentHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- `instant` (a new character) skips the slide
local function applyToHumanoid(humanoid, instant)
	if not humanoid then
		return
	end
	humanoid.AutoRotate = not locked
	local side = Preferences.Choice("Side") == "LEFT" and -1 or 1
	local offset = locked and SHOULDER_OFFSET * Vector3.new(side, 1, 1) or Vector3.zero
	if offsetTween then
		offsetTween:Cancel()
		offsetTween = nil
	end
	if instant then
		humanoid.CameraOffset = offset
	else
		offsetTween = TweenService:Create(humanoid, TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CameraOffset = offset })
		offsetTween:Play()
	end
end

-- runs right after the camera updates each frame
local function faceCamera(dt)
	-- the camera scripts can reset this, so it is reapplied every frame
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	local humanoid = currentHumanoid()
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	-- a swimmer lies along the water and turns the way they swim (Swim script);
	-- standing them upright to face the camera would drop the swim pose
	local swimming = humanoid.Parent:GetAttribute("Swimming") == true
	humanoid.AutoRotate = swimming
	-- a dash roll faces its own direction until it finishes
	if swimming or player:GetAttribute("Dashing") then
		return
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.01 then
		local facing = CFrame.lookAt(root.Position, root.Position + flatLook)
		if os.clock() - lockedAt < TRANSITION_TIME then
			facing = root.CFrame:Lerp(facing, 1 - math.exp(-TURN_RATE * dt))
		end
		root.CFrame = facing
	end
end

-- Roblox's camera scripts set the mouse back to free at times (a right-click
-- release, a menu closing); that is undone at once, not a frame later
UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
	if locked and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end)

local function setLocked(value)
	locked = value
	lockedAt = os.clock()
	applyToHumanoid(currentHumanoid())
	if locked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, faceCamera)
	else
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

-- each frame, after the camera and LockOn have turned it: the x on the target, or in
-- the middle in shift lock, and the mouse hidden while either is on
local hidingMouse = false
local function placeCrosshair()
	-- shift lock follows the free-camera key, menus and the title screen
	local wantLocked = not UserInputService:IsKeyDown(FREE_KEY) and not Menus.Blocks() and not player.PlayerGui:FindFirstChild("TitleMenu")
	if wantLocked ~= locked then
		setLocked(wantLocked)
	end
	local camera = workspace.CurrentCamera
	local _, targetRoot = LockOn.Target()
	local point
	if targetRoot then
		local screen, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
		point = onScreen and Vector2.new(screen.X, screen.Y) or nil
	elseif locked then
		point = camera.ViewportSize / 2
	end
	gui.Enabled = point ~= nil and not menuOpen and not rangedCrosshairShown()
	if point then
		holder.Position = UDim2.fromOffset(point.X, point.Y)
	end
	-- reapplied every frame: Ranged turns the mouse back on as its crosshair goes
	if (locked or targetRoot ~= nil) and not menuOpen then
		UserInputService.MouseIconEnabled = false
		hidingMouse = true
	elseif hidingMouse then
		hidingMouse = false
		UserInputService.MouseIconEnabled = not rangedCrosshairShown()
	end
end
RunService:BindToRenderStep(CROSSHAIR_STEP_NAME, Enum.RenderPriority.Camera.Value + 3, placeCrosshair)

-- a new Shoulder side slides the camera across
local drawnSide = Preferences.Choice("Side")
Preferences.Changed(function()
	local side = Preferences.Choice("Side")
	if side ~= drawnSide then
		drawnSide = side
		applyToHumanoid(currentHumanoid())
	end
end)

-- a respawned character picks up the current state
player.CharacterAdded:Connect(function(character)
	applyToHumanoid(character:WaitForChild("Humanoid"), true)
end)
