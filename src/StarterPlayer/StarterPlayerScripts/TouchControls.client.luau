-- On-screen combat buttons for phones and tablets (a touch screen with no keyboard): Attack, Dash,
-- Block and the Special (G) key, plus Aim and Reload while the set in hand has a ranged move.
-- Skills are cast by tapping their slots on the SkillBar. A button only calls TouchInput.Press/Release;
-- the scripts that own each action (Punch, Ranged, Dash, Block, SkillBar) listen, so a tap does what the key does.
-- Laid out in real pixels (TouchControls is in UIScale.SkipGui), around Roblox's own jump button
-- (about 70 px, 25 px in from the bottom right), with fingers in mind: nothing under 48 px.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GuardConfig = require(ReplicatedStorage:WaitForChild("GuardConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local TouchInput = require(script.Parent:WaitForChild("TouchInput"))

local player = Players.LocalPlayer
local Style = HudConfig.Style

local IDLE_TRANSPARENCY = Style.GlassTransparency
local HELD_TRANSPARENCY = 0.1
local RANGED_CHECK = 0.25 -- seconds between looks at what's in hand

-- `right`/`bottom`: pixels in from the screen's corner to the button's corner
local BUTTONS = {
	{ action = "Attack", text = "ATK", size = 72, right = 25, bottom = 105 },
	{ action = "Dash", text = "DASH", size = 56, right = 105, bottom = 25 },
	{ action = "Block", text = "BLOCK", size = 56, right = 110, bottom = 95, needs = "block" },
	{ action = "Special", text = "G", size = 52, right = 28, bottom = 190 },
	{ action = "Aim", text = "AIM", size = 52, right = 180, bottom = 25, needs = "ranged" },
	{ action = "Reload", text = "R", size = 52, right = 180, bottom = 85, needs = "ranged" },
}

local gui = Instance.new("ScreenGui")
gui.Name = "TouchControls"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local buttons = {} -- action -> { button, needs }

for _, spec in ipairs(BUTTONS) do
	local button = Instance.new("TextButton")
	button.Name = spec.action
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -spec.right, 1, -spec.bottom)
	button.Size = UDim2.fromOffset(spec.size, spec.size)
	button.AutoButtonColor = false
	button.Active = true
	button.BackgroundColor3 = Color3.new(0, 0, 0)
	button.BackgroundTransparency = IDLE_TRANSPARENCY
	button.BorderSizePixel = 0
	button.Font = Style.MonoFont
	button.Text = spec.text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = spec.size >= 70 and 18 or 14
	button.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.5
	stroke.Parent = button

	-- a finger down is the key down; lifting it (or the touch being taken away) is the key up
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		button.BackgroundTransparency = HELD_TRANSPARENCY
		TouchInput.Press(spec.action)
		local connection
		connection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
				connection:Disconnect()
				button.BackgroundTransparency = IDLE_TRANSPARENCY
				TouchInput.Release(spec.action)
			end
		end)
	end)
	buttons[spec.action] = { button = button, needs = spec.needs }
end

-- Aim and Reload only matter with a ranged move in hand
local hasRanged = false
local function checkRanged()
	local character = player.Character
	local _, setName = SkillSetConfig.Equipped(character)
	hasRanged = setName ~= nil and SkillSetConfig.RangedFor(character, setName) ~= nil
end

local function refreshButtons()
	for _, entry in pairs(buttons) do
		entry.button.Visible = entry.needs == nil
			or (entry.needs == "block" and GuardConfig.Enabled)
			or (entry.needs == "ranged" and hasRanged)
	end
end

refreshButtons()
local sinceCheck = 0
RunService.Heartbeat:Connect(function(dt)
	-- off for a keyboard, and while a menu or a talk has the screen
	local show = TouchInput.Active() and not Menus.BlocksActions()
	if gui.Enabled ~= show then
		gui.Enabled = show
		if not show then
			for action in pairs(buttons) do
				TouchInput.Release(action)
			end
		end
	end
	sinceCheck += dt
	if show and sinceCheck >= RANGED_CHECK then
		sinceCheck = 0
		checkRanged()
		refreshButtons()
	end
end)

-- plugging a keyboard in or out changes which input the player is using
UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(refreshButtons)
