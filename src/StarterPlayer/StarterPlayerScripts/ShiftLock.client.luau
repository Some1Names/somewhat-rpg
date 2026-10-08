-- Shift lock everyone can use without turning on Roblox's Shift Lock Switch
-- setting: Left Ctrl locks the mouse to the center, turns the character
-- with the camera and moves the camera over the shoulder.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.LeftControl
local SHOULDER_OFFSET = Vector3.new(1.75, 0, 0)
local CROSSHAIR = "rbxasset://textures/MouseLockedCursor.png"
local RENDER_STEP_NAME = "ShiftLock"

local locked = false

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
	-- a dash roll faces its own direction until it finishes
	if not root or humanoid.Health <= 0 or humanoid.Sit or player:GetAttribute("Dashing") then
		return
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
	end
end

local function setLocked(value)
	locked = value
	applyToHumanoid(currentHumanoid())
	if locked then
		UserInputService.MouseIcon = CROSSHAIR
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, faceCamera)
	else
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIcon = ""
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
