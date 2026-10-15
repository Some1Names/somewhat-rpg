-- The out-of-combat countdown: 30 seconds after you last dealt or took damage
-- (Guard's LastCombatAt on your character; the rules are in CombatRules) you
-- are out of combat, and the last 10 of them are counted down at the top of the
-- screen. Plain white text with a dark stroke.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "CombatTimer"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, HudConfig.TopMargin + 8)
label.Size = UDim2.fromOffset(320, 26)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextSize = 18
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeColor3 = Color3.new(0, 0, 0)
label.TextStrokeTransparency = 0.3
label.Visible = false
label.Parent = gui

local shown = nil -- the whole second on the label now
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local left = CombatRules.SecondsLeft(character and character:GetAttribute("LastCombatAt"), workspace:GetServerTimeNow())
	if not CombatRules.ShowCountdown(left) then
		label.Visible = false
		shown = nil
		return
	end
	local seconds = math.ceil(left)
	if seconds ~= shown then
		shown = seconds
		label.Text = "OUT OF COMBAT IN " .. seconds
	end
	label.Visible = true
end)
