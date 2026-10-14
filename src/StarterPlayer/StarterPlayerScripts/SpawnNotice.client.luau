-- Shows a short line of text when a Spawn Keeper sets the spawn (SpawnServer
-- writes the SpawnNotice attribute). Plain white text with a dark stroke.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "SpawnNotice"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0.18, 0)
label.Size = UDim2.fromOffset(300, 30)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextSize = 22
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeColor3 = Color3.new(0, 0, 0)
label.TextStrokeTransparency = 0.3
label.TextTransparency = 1
label.Text = ""
label.Parent = gui

local shown = 0
player:GetAttributeChangedSignal("SpawnNotice"):Connect(function()
	local text = string.match(player:GetAttribute("SpawnNotice") or "", "^(.-)|")
	if not text then
		return
	end
	shown += 1
	local mine = shown
	label.Text = text
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.3
	task.delay(1.8, function()
		if shown == mine then
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)
