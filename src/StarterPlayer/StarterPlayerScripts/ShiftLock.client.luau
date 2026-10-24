-- Shift lock everyone can use without turning on Roblox's Shift Lock Switch
-- setting: Left Ctrl locks the mouse to the center, turns the character
-- with the camera and moves the camera over the shoulder. While it's on, the mouse
-- is hidden and a crosshair is drawn in the middle instead: Modern Warfare's, four
-- short white ticks round a dot with a dark edge, square. It steps aside while a
-- ranged move shows its own crosshair (Ranged's RangedCrosshair gui), and for the
-- mouse while a menu is open (Menus).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Menus = require(script.Parent:WaitForChild("Menus"))

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.LeftControl
local SHOULDER_OFFSET = Vector3.new(1.75, 0, 0)
local TICK_LENGTH = 7 -- px
local TICK_WIDTH = 2
local TICK_GAP = 5 -- px from the middle to each tick
local DOT_SIZE = 2
local RENDER_STEP_NAME = "ShiftLock"

local locked = false
local menuOpen = false
Menus.OnChange(function(name)
	menuOpen = name ~= nil
end)

-- the crosshair, in the middle of the real screen
local gui = Instance.new("ScreenGui")
gui.Name = "ShiftLockCrosshair"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function mark(size, offset)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(0, 0, 0)
	edge.Transparency = 0.4
	edge.LineJoinMode = Enum.LineJoinMode.Miter -- square corners
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = frame
end
local reach = TICK_GAP + TICK_LENGTH / 2
mark(Vector2.new(DOT_SIZE, DOT_SIZE), Vector2.zero)
mark(Vector2.new(TICK_WIDTH, TICK_LENGTH), Vector2.new(0, -reach))
mark(Vector2.new(TICK_WIDTH, TICK_LENGTH), Vector2.new(0, reach))
mark(Vector2.new(TICK_LENGTH, TICK_WIDTH), Vector2.new(-reach, 0))
mark(Vector2.new(TICK_LENGTH, TICK_WIDTH), Vector2.new(reach, 0))

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
	-- Ranged turns the mouse back on as its crosshair goes, so this is reapplied too
	UserInputService.MouseIconEnabled = menuOpen
	gui.Enabled = not menuOpen and not rangedCrosshairShown()
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
		gui.Enabled = false
		UserInputService.MouseIconEnabled = not rangedCrosshairShown()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == TOGGLE_KEY then
		setLocked(not locked)
	end
end)

-- a respawned character picks up the current state
player.CharacterAdded:Connect(function(character)
	applyToHumanoid(character:WaitForChild("Humanoid"))
end)
