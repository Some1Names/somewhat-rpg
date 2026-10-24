-- Shift lock everyone can use without turning on Roblox's Shift Lock Switch
-- setting: Left Ctrl locks the mouse to the center, turns the character
-- with the camera and moves the camera over the shoulder. While it's on, the mouse
-- is hidden and a crosshair is drawn in the middle instead: a small white x with a
-- dark edge, square ends. While something is locked onto (LockOn), shift lock or not,
-- the x sits on them instead and the mouse stays hidden: the cursor is where every
-- move aims. It steps aside while a ranged move shows its own crosshair (Ranged's
-- RangedCrosshair gui, which goes onto the target too), and for the mouse while a
-- menu is open (Menus).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LockOn = require(script.Parent:WaitForChild("LockOn"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.LeftControl
local SHOULDER_OFFSET = Vector3.new(1.75, 0, 0)
local X_SIZE = 10 -- px, each stroke of the x
local X_WIDTH = 2
local RENDER_STEP_NAME = "ShiftLock"
local CROSSHAIR_STEP_NAME = "ShiftLockCrosshair"

local locked = false
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
holder.Size = UDim2.fromOffset(X_SIZE, X_SIZE)
holder.BackgroundTransparency = 1
holder.Parent = gui

-- one bar of the x through the middle at `rotation` degrees; the dark edges are a
-- slightly bigger bar behind (ZIndex 1), so both white bars sit over both edges and
-- the crossing stays clean
local function bar(rotation, grow, color, transparency, zIndex)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(X_WIDTH + grow, X_SIZE + grow)
	frame.Rotation = rotation
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	frame.Parent = holder
end
for _, rotation in ipairs({ 45, -45 }) do
	bar(rotation, 2, Color3.new(0, 0, 0), 0.4, 1)
	bar(rotation, 0, Color3.new(1, 1, 1), 0, 2)
end

-- a ranged move's crosshair, when it's showing, stands in for this one
local function rangedCrosshairShown()
	local ranged = player.PlayerGui:FindFirstChild("RangedCrosshair")
	return ranged ~= nil and ranged.Enabled
end

local function currentHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function applyToHumanoid(humanoid)
	if humanoid then
		humanoid.AutoRotate = not locked
		humanoid.CameraOffset = locked and SHOULDER_OFFSET or Vector3.zero
	end
end

-- runs right after the camera updates each frame
local function faceCamera()
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
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == TOGGLE_KEY then
		setLocked(not locked)
	end
end)

-- a respawned character picks up the current state
player.CharacterAdded:Connect(function(character)
	applyToHumanoid(character:WaitForChild("Humanoid"))
end)
