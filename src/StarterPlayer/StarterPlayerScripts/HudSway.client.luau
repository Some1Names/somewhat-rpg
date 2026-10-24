-- HUD sway: the screen HUD (Hotbar, SkillBar, KeyHints, the yen above the cards, the
-- bounty tracker, the party HUD, the compass, the XP bar, the combo counter and the zone
-- name) and your HP and stamina billboard (StatusHUD) drift a few pixels against your movement and camera
-- turns, then ease back to rest, so the HUD feels attached to the camera.
-- Strafing shifts it sideways, jumping and falling shift it up and down,
-- running forward nudges it down, and a camera pan pushes it the opposite
-- way. The screen HUD follows the HUD sway setting and the HP and stamina bar
-- the HP bar sway setting (Preferences), each switched off on its own.
-- Each HUD's top-level frames are moved into one full-size "Sway" frame in
-- its ScreenGui (they keep their own positions) and that frame is the only
-- thing moved. The billboard's StudsOffset moves by the same amount, from the
-- offset it had when first seen. Menus (Hub, Settings, the shop) stay put.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- the ScreenGuis that sway: true for all of a gui's frames, or the names of the only frames in it that do
-- (the top bar's icons and the bounty panel and popups stay still)
local TARGETS = {
	Hotbar = true,
	SkillBar = true,
	KeyHints = true,
	TopBar = { "YenCluster" },
	QuestBoard = { "Tracker" },
	PartyHUD = true,
	Compass = true,
	XPBar = true,
	ComboCounter = true,
	ZoneName = true,
}
local MAX_OFFSET = 8 -- pixels, the furthest the HUD drifts
local SMOOTHING = 9 -- how fast it eases to its target, per second
local CAMERA_WEIGHT = 0.5 -- how much a camera pan counts against walking
local WALK_SPEED_FULL = 24 -- studs per second of sideways speed for a full sway
local VERTICAL_SPEED_FULL = 40 -- studs per second up or down for a full sway
local TURN_RATE_FULL = 4 -- radians per second of camera pan for a full sway
local FORWARD_WEIGHT = 0.4 -- how much running forward nudges the HUD down
local VERTICAL_WEIGHT = 0.8
local STUDS_PER_PIXEL = 0.07 -- the HP and stamina billboard's move for each pixel (swings wider than the screen HUD)

local swayFrames = {} -- the "Sway" frames in the HUD ScreenGuis

local function wrap(gui, only)
	local function swaying(child)
		return child:IsA("GuiObject") and child.Name ~= "UIScaleRoot" and (only == true or table.find(only, child.Name) ~= nil)
	end
	local sway = Instance.new("Frame")
	sway.Name = "Sway"
	sway.BackgroundTransparency = 1
	sway.BorderSizePixel = 0
	sway.Active = false
	sway.Size = UDim2.fromScale(1, 1)
	-- inside the UI scale's root frame (the gui itself when it isn't scaled)
	local root = UIScale.Root(gui)
	sway.Parent = root
	for _, container in ipairs({ gui, root }) do
		for _, child in ipairs(container:GetChildren()) do
			if child ~= sway and swaying(child) then
				child.Parent = sway
			end
		end
		-- anything the HUD script adds later goes in too
		container.ChildAdded:Connect(function(child)
			if child ~= sway and swaying(child) then
				task.defer(function()
					if child.Parent == container then
						child.Parent = sway
					end
				end)
			end
		end)
	end
	table.insert(swayFrames, sway)
end

for _, child in ipairs(playerGui:GetChildren()) do
	if child:IsA("ScreenGui") and TARGETS[child.Name] then
		wrap(child, TARGETS[child.Name])
	end
end
playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") and TARGETS[child.Name] then
		wrap(child, TARGETS[child.Name])
	end
end)

local offset = Vector2.zero -- the screen HUD's drift
local statusOffset = Vector2.zero -- the HP and stamina bar's drift
local lastLook
local status, statusBase -- the HP and stamina billboard and the StudsOffset it started with

RunService.RenderStepped:Connect(function(dt)
	dt = math.max(dt, 1e-3)
	local camera = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local push = Vector2.zero -- the full sway for this frame's movement
	if camera and root then
		local look = camera.CFrame.LookVector
		-- how fast the camera is panning (left positive), from the turn of the look direction
		local turn = lastLook and (lastLook.Z * look.X - lastLook.X * look.Z) / dt or 0
		lastLook = look
		local velocity = camera.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
		local x = -math.clamp(velocity.X / WALK_SPEED_FULL, -1, 1) + math.clamp(turn / TURN_RATE_FULL, -1, 1) * CAMERA_WEIGHT
		local y = math.clamp(velocity.Y / VERTICAL_SPEED_FULL, -1, 1) * VERTICAL_WEIGHT
			+ math.clamp(-velocity.Z / WALK_SPEED_FULL, -1, 1) * FORWARD_WEIGHT
		push = Vector2.new(x, y) * MAX_OFFSET
	end
	-- the screen HUD and the HP and stamina bar each follow their own setting
	local hudTarget = Preferences.Get("HudSway") and push or Vector2.zero
	local statusTarget = Preferences.Get("StatusSway") and push or Vector2.zero
	local ease = 1 - math.exp(-SMOOTHING * dt)
	offset += (hudTarget - offset) * ease
	statusOffset += (statusTarget - statusOffset) * ease
	if offset.Magnitude < 0.05 and hudTarget == Vector2.zero then
		offset = Vector2.zero
	end
	if statusOffset.Magnitude < 0.05 and statusTarget == Vector2.zero then
		statusOffset = Vector2.zero
	end

	local position = UDim2.fromOffset(math.round(offset.X), math.round(offset.Y))
	for _, sway in ipairs(swayFrames) do
		if sway.Parent then
			sway.Position = position
		end
	end

	if not status or not status.Parent then
		status = playerGui:FindFirstChild("StatusHUD")
		statusBase = status and status.StudsOffset
	end
	if status then
		status.StudsOffset = statusBase + Vector3.new(statusOffset.X, -statusOffset.Y, 0) * STUDS_PER_PIXEL
	end
end)
