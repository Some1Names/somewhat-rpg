-- The kill feed, top right: a line for every player death the server
-- announces on the KillFeed remote (ServerScriptService.KillFeed), newest
-- on top, "Killer [Set] Victim" with the set's name in its colour (or
-- "Victim was defeated" when no player did it). Lines involving you are
-- outlined: gold for your kills, red for your deaths. Each fades after
-- LINE_TIME; only MAX_LINES are kept.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local MAX_LINES = 5
local LINE_TIME = 6 -- seconds a line stays before fading
local FADE_TIME = 0.5
local LINE_HEIGHT = 26
local TOP = 60 -- clear of the Roblox buttons
local MARGIN = 16
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local BORDER = Color3.fromRGB(60, 60, 75)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local YOUR_KILL = Color3.fromRGB(255, 200, 90)
local YOUR_DEATH = Color3.fromRGB(226, 75, 74)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "KillFeed"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local list = Instance.new("Frame")
list.Name = "Lines"
list.AnchorPoint = Vector2.new(1, 0)
list.Position = UDim2.new(1, -MARGIN, 0, TOP)
list.Size = UDim2.fromOffset(420, (LINE_HEIGHT + 4) * MAX_LINES)
list.BackgroundTransparency = 1
list.Parent = gui

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.Padding = UDim.new(0, 4)
layout.Parent = list

local function label(parent, text, color, font, order)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, LINE_HEIGHT)
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = 14
	l.TextColor3 = color
	l.Text = text
	l.LayoutOrder = order
	l.Parent = parent
	return l
end

local lines = {}
local counter = 0

local function fade(line)
	if not line.Parent then
		return
	end
	TweenService:Create(line, TweenInfo.new(FADE_TIME), { GroupTransparency = 1 }):Play()
	task.delay(FADE_TIME, function()
		line:Destroy()
	end)
end

local function addLine(victimId, victimName, killerId, killerName, setName)
	counter += 1
	local line = Instance.new("CanvasGroup")
	line.AutomaticSize = Enum.AutomaticSize.X
	line.Size = UDim2.fromOffset(0, LINE_HEIGHT)
	line.BackgroundColor3 = BACKGROUND
	line.BackgroundTransparency = 0.15
	line.LayoutOrder = -counter -- newest on top
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = BORDER
	stroke.Thickness = 1
	if killerId == player.UserId then
		stroke.Color = YOUR_KILL
		stroke.Thickness = 2
	elseif victimId == player.UserId then
		stroke.Color = YOUR_DEATH
		stroke.Thickness = 2
	end
	stroke.Parent = line
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = line
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 8)
	row.Parent = line

	if killerName then
		label(line, killerName, TEXT, nil, 1)
		local set = setName and SkillSetConfig.Sets[setName]
		if set then
			-- the set it was done with, in its colour, in a square tag
			local tag = Instance.new("Frame")
			tag.AutomaticSize = Enum.AutomaticSize.X
			tag.Size = UDim2.fromOffset(0, LINE_HEIGHT - 8)
			tag.BackgroundColor3 = set.color
			tag.BackgroundTransparency = 0.85
			tag.LayoutOrder = 2
			tag.Parent = line
			local tagStroke = Instance.new("UIStroke")
			tagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			tagStroke.Color = set.color
			tagStroke.Parent = tag
			local tagPadding = Instance.new("UIPadding")
			tagPadding.PaddingLeft = UDim.new(0, 6)
			tagPadding.PaddingRight = UDim.new(0, 6)
			tagPadding.Parent = tag
			local tagText = label(tag, set.tool or setName, set.color, Enum.Font.GothamMedium, 1)
			tagText.Size = UDim2.new(0, 0, 1, 0)
			tagText.TextSize = 12
		else
			label(line, "killed", MUTED, Enum.Font.GothamMedium, 2)
		end
		label(line, victimName, TEXT, nil, 3)
	else
		label(line, victimName, TEXT, nil, 1)
		label(line, "was defeated", MUTED, Enum.Font.GothamMedium, 2)
	end
	line.Parent = list

	table.insert(lines, line)
	while #lines > MAX_LINES do
		table.remove(lines, 1):Destroy()
	end
	task.delay(LINE_TIME, function()
		local index = table.find(lines, line)
		if index then
			table.remove(lines, index)
		end
		fade(line)
	end)
end

ReplicatedStorage:WaitForChild("KillFeed").OnClientEvent:Connect(addLine)
