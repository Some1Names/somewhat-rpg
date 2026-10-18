-- "Found <talisman>" near the top of the screen when a chest (or anything else
-- calling Talismans.Grant) gives the player one: the server sets the
-- TalismanFound attribute to "<key>:<server time>". Plain white text with a dark
-- stroke, fading out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TalismanConfig = require(ReplicatedStorage:WaitForChild("TalismanConfig"))

local player = Players.LocalPlayer

local SHOW_TIME = 3 -- seconds on screen before the fade
local FADE_TIME = 0.8

local gui = Instance.new("ScreenGui")
gui.Name = "TalismanToast"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local text = Instance.new("TextLabel")
text.BackgroundTransparency = 1
text.AnchorPoint = Vector2.new(0.5, 0)
text.Position = UDim2.new(0.5, 0, 0.16, 0)
text.Size = UDim2.fromOffset(500, 28)
text.Font = Enum.Font.Highway
text.TextSize = 20
text.TextColor3 = Color3.new(1, 1, 1)
text.TextStrokeColor3 = Color3.new(0, 0, 0)
text.TextTransparency = 1
text.TextStrokeTransparency = 1
text.Parent = gui

local shown = 0 -- counts toasts, so an old fade doesn't hide a new one
local function show(key)
	local talisman = TalismanConfig.Get(key)
	if not talisman then
		return
	end
	shown += 1
	local mine = shown
	text.Text = "Found " .. talisman.name .. "!  (Backpack → Talisman)"
	text.TextTransparency = 0
	text.TextStrokeTransparency = 0.2
	task.delay(SHOW_TIME, function()
		if shown == mine then
			TweenService:Create(text, TweenInfo.new(FADE_TIME), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

player:GetAttributeChangedSignal(TalismanConfig.FoundAttribute):Connect(function()
	local found = player:GetAttribute(TalismanConfig.FoundAttribute)
	local key = typeof(found) == "string" and string.match(found, "^([^:]+):")
	if key then
		show(key)
	end
end)
