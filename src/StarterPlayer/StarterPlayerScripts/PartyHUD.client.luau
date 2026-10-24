-- Party on the main screen: your party mates down the left edge (name and a square
-- HP bar, hidden when you are alone), a line of text for party news (the PartyNotice
-- attribute), and while an invite to you is open a card on the right edge, above the
-- bounty tracker: Y accepts, N declines (or use the Party tab in the hub). Square.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local PartyRules = require(ReplicatedStorage:WaitForChild("PartyRules"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local action = ReplicatedStorage:WaitForChild("PartyAction") -- made by PartyServer

local player = Players.LocalPlayer

local ROW_WIDTH = 150
local ROW_HEIGHT = 26
local ROW_GAP = 4
local ACCEPT_KEY = Enum.KeyCode.Y
local DECLINE_KEY = Enum.KeyCode.N
local PROMPT_HEIGHT = 76
local INVITE_ACCENT = Color3.fromRGB(110, 200, 255)

local gui = Instance.new("ScreenGui")
gui.Name = "PartyHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Highway
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.3
	for key, value in pairs(props) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

-- the mates down the left edge
local list = Instance.new("Frame")
list.AnchorPoint = Vector2.new(0, 0.5)
list.Position = UDim2.new(0, 14, 0.4, 0)
list.Size = UDim2.fromOffset(ROW_WIDTH, 3 * (ROW_HEIGHT + ROW_GAP))
list.BackgroundTransparency = 1
list.Parent = gui
local rows = {}
for i = 1, PartyRules.MaxMembers - 1 do
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(0, (i - 1) * (ROW_HEIGHT + ROW_GAP))
	row.Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.Parent = list
	local name = text(row, { Size = UDim2.new(1, 0, 0, 14), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 17)
	back.Size = UDim2.new(1, 0, 0, 6)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.5
	back.BorderSizePixel = 0
	back.Parent = row
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(226, 75, 74)
	fill.BorderSizePixel = 0
	fill.Parent = back
	rows[i] = { row = row, name = name, fill = fill }
end

-- party news
local news = text(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.26, 0),
	Size = UDim2.fromOffset(420, 26),
	TextSize = 20,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
})

-- the invite: a card on the right edge, above the bounty tracker (or in its spot
-- when there's no bounty), dressed like the tracker
local prompt = Instance.new("Frame")
prompt.AnchorPoint = Vector2.new(1, 1)
prompt.Size = UDim2.fromOffset(HudConfig.SideWidth, PROMPT_HEIGHT)
prompt.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
prompt.BackgroundTransparency = 0.25
prompt.BorderSizePixel = 0
prompt.Visible = false
prompt.Parent = gui
local promptStroke = Instance.new("UIStroke")
promptStroke.Color = Color3.new(1, 1, 1)
promptStroke.Transparency = 0.5
promptStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
promptStroke.Parent = prompt
text(prompt, {
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.new(1, -20, 0, 12),
	Text = "PARTY INVITE",
	TextSize = 10,
	TextColor3 = INVITE_ACCENT,
	TextStrokeTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local promptText = text(prompt, {
	Position = UDim2.fromOffset(10, 22),
	Size = UDim2.new(1, -20, 0, 16),
	TextSize = 13,
	TextStrokeTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

-- square ACCEPT / DECLINE buttons under the line (the keys work too)
local BUTTON_WIDTH = (HudConfig.SideWidth - 20 - HudConfig.SideGap) / 2
local function promptButton(label, x, fill, kind)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, 44)
	b.Size = UDim2.fromOffset(BUTTON_WIDTH, 24)
	b.BackgroundColor3 = fill and Color3.fromRGB(236, 236, 238) or Color3.fromRGB(40, 40, 46)
	b.BackgroundTransparency = fill and 0 or 0.15
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.Highway
	b.Text = label
	b.TextSize = 13
	b.TextColor3 = fill and Color3.fromRGB(20, 20, 23) or Color3.new(1, 1, 1)
	b.Parent = prompt
	b.Activated:Connect(function()
		action:InvokeServer(kind)
	end)
end
promptButton("ACCEPT [Y]", 10, true, "accept")
promptButton("DECLINE [N]", 10 + BUTTON_WIDTH + HudConfig.SideGap, false, "decline")

-- sit where the bounty tracker sits, lifted over it while it's showing
local function placePrompt()
	local board = player.PlayerGui:FindFirstChild("QuestBoard")
	local tracker = board and board:FindFirstChild("Tracker", true) -- inside its UIScaleRoot
	local lift = tracker and tracker.Visible and tracker.AbsoluteSize.Y / UIScale.Get() + HudConfig.SideGap or 0
	prompt.Position = UDim2.new(1, -HudConfig.EdgeMargin, 1, -(HudConfig.BottomReserve + HudConfig.SideHeight + HudConfig.SideGap + lift))
end

local shown = 0
player:GetAttributeChangedSignal("PartyNotice"):Connect(function()
	local line = string.match(player:GetAttribute("PartyNotice") or "", "^(.-)|")
	if not line then
		return
	end
	shown += 1
	local mine = shown
	news.Text = line
	news.TextTransparency = 0
	news.TextStrokeTransparency = 0.3
	task.delay(2.4, function()
		if shown == mine then
			TweenService:Create(news, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

local function openInvite()
	local fromId, expires = PartyRules.DecodeInvite(player:GetAttribute("PartyInvite"))
	if fromId and PartyRules.InviteOpen(expires, workspace:GetServerTimeNow()) then
		return Players:GetPlayerByUserId(fromId)
	end
	return nil
end

local function mates()
	local id = player:GetAttribute("PartyId")
	local list = {}
	if id then
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other:GetAttribute("PartyId") == id then
				table.insert(list, other)
			end
		end
		table.sort(list, function(a, b)
			return (a:GetAttribute("PartyIndex") or 99) < (b:GetAttribute("PartyIndex") or 99)
		end)
	end
	return list
end

RunService.Heartbeat:Connect(function()
	local group = mates()
	for i, slot in ipairs(rows) do
		local mate = group[i]
		slot.row.Visible = mate ~= nil
		if mate then
			local leader = mate:GetAttribute("PartyLeader") == mate.UserId
			slot.name.Text = (leader and "★ " or "") .. mate.DisplayName
			local humanoid = mate.Character and mate.Character:FindFirstChildOfClass("Humanoid")
			local fraction = humanoid and humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
			slot.fill.Size = UDim2.fromScale(fraction, 1)
		end
	end
	local inviter = openInvite()
	prompt.Visible = inviter ~= nil
	if inviter then
		promptText.Text = string.format("%s invited you", inviter.DisplayName)
		placePrompt()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not openInvite() then
		return
	end
	if input.KeyCode == ACCEPT_KEY then
		action:InvokeServer("accept")
	elseif input.KeyCode == DECLINE_KEY then
		action:InvokeServer("decline")
	end
end)
