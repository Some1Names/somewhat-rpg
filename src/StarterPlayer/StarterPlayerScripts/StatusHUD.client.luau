-- HP and stamina beside your character, Death Stranding style: your name and
-- level, a thin HP bar and a row of stamina boxes (one per dash, more as you
-- level up), each with a pale "just lost" trail, hidden while full.
-- Diamonds after the stamina boxes show the dodge charges (Q dodge and double
-- jump), each filling as it recharges. Under the stamina, icons for any
-- status effects on you (Burnt, Bleeding...).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local DodgeCharges = require(script.Parent:WaitForChild("DodgeCharges"))
local Stamina = require(script.Parent:WaitForChild("Stamina"))
local StatusIcons = require(ReplicatedStorage:WaitForChild("StatusIcons"))

local player = Players.LocalPlayer

-- camera-relative studs from the root: right of the body, at waist height,
-- so the shift-lock crosshair (around head height) stays clear
local OFFSET = Vector3.new(1.6, -0.2, 0)
local ICON_WIDTH = 22
local ROW_HEIGHT = 18
local ROW_GAP = 6
local BASE_BOXES = 4 -- stamina boxes at level 1
local MAX_BOXES = 8
local BOX_SIZE = 14
local BOX_GAP = 1 -- the outlines sit outside each box, so 1px lets neighbours share one line
local BAR_HEIGHT = BOX_SIZE -- HP bar matches the stamina boxes
local function boxesWidth(count)
	return count * BOX_SIZE + (count - 1) * BOX_GAP
end
local BAR_WIDTH = boxesWidth(BASE_BOXES) * 2 -- HP bar is twice as long as the starting stamina row
local HP_COLOR = Color3.fromRGB(216, 90, 48)
local HP_TRAIL = Color3.fromRGB(245, 196, 179)
local STAMINA_COLOR = Color3.fromRGB(55, 138, 221)
local STAMINA_TRAIL = Color3.fromRGB(133, 183, 235)
local EXHAUSTED_COLOR = Color3.fromRGB(240, 196, 60)
local DODGE_COLOR = Color3.new(1, 1, 1)
local DODGE_SIZE = 10 -- side of the dodge square before it's turned into a diamond
local DODGE_GAP = 10 -- space between the stamina boxes and the dodge diamonds
local DODGE_STEP = BOX_SIZE + 6 -- from one diamond to the next, leaving room for the link
local DODGE_HALF_DIAGONAL = DODGE_SIZE * math.sqrt(2) / 2
-- GUI offsets are whole pixels, so the link is rounded outward to reach both tips
local LINK_START = math.floor(DODGE_HALF_DIAGONAL)
local LINK_WIDTH = math.ceil(DODGE_STEP - DODGE_HALF_DIAGONAL) - LINK_START
local MAX_DODGES = StatConfig.DodgeCharges(math.huge)
-- wide enough for the HP bar or the longest stamina row plus the diamonds
local CONTENT_WIDTH = ICON_WIDTH + math.max(BAR_WIDTH, boxesWidth(MAX_BOXES) + DODGE_GAP + MAX_DODGES * DODGE_STEP)
local TRAIL_HOLD = 0.4 -- seconds the pale segment waits before catching up
local TRAIL_SPEED = 1.2 -- bar fractions per second
local HIDE_AFTER = 2.5 -- seconds full and unchanged before a bar fades out
local FADE_SPEED = 5 -- transparency per second

-- this replaces Roblox's own health bar; CoreGui may not be ready right away
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false) then
			return
		end
		task.wait(0.5)
	end
end)

-- The billboard is twice the content width with everything in its right half,
-- so the left edge sits exactly at OFFSET however far you zoom.
local billboard = Instance.new("BillboardGui")
billboard.Name = "StatusHUD"
billboard.AlwaysOnTop = true
billboard.LightInfluence = 0
billboard.ResetOnSpawn = false
billboard.Size = UDim2.fromOffset(CONTENT_WIDTH * 2, ROW_HEIGHT * 3 + ROW_GAP * 3 + StatusIcons.Size + 2)
billboard.StudsOffset = OFFSET
billboard.Parent = player:WaitForChild("PlayerGui")

local content = Instance.new("Frame")
content.BackgroundTransparency = 1
content.Position = UDim2.fromScale(0.5, 0)
content.Size = UDim2.fromScale(0.5, 1)
content.Parent = billboard

local function frame(parent, color, size, position)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Size = size
	f.Position = position
	f.Parent = parent
	return f
end

local function row(index)
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	group.Position = UDim2.fromOffset(0, (index - 1) * (ROW_HEIGHT + ROW_GAP))
	group.GroupTransparency = 1
	group.Parent = content
	return group
end

local function icon(group, glyph)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(14, ROW_HEIGHT)
	label.Font = Enum.Font.GothamBold
	label.Text = glyph
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = group
	return label
end

local function outline(parent)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.5
	stroke.LineJoinMode = Enum.LineJoinMode.Miter -- square corners
	stroke.Parent = parent
end

local function meter(group)
	return { group = group, shown = 1, last = 1, trailFraction = 1, trailHoldUntil = 0, lastChangeAt = -math.huge }
end

-- name
local nameGroup = row(1)
local nameLabel = Instance.new("TextLabel")
nameLabel.BackgroundTransparency = 1
nameLabel.Size = UDim2.fromScale(1, 1)
nameLabel.Font = Enum.Font.GothamMedium
nameLabel.TextSize = 12
nameLabel.TextColor3 = Color3.new(1, 1, 1)
nameLabel.TextStrokeTransparency = 0.6
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Parent = nameGroup

local function showName()
	local level = player:GetAttribute("Level")
	nameLabel.Text = level and string.format("%s  ·  Lv %d", player.DisplayName, level) or player.DisplayName
end
showName()
player:GetAttributeChangedSignal("Level"):Connect(showName)

-- HP bar
local hp = meter(row(2))
icon(hp.group, "\u{2665}")
local hpTrack = frame(hp.group, Color3.new(0, 0, 0), UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
	UDim2.fromOffset(ICON_WIDTH, (ROW_HEIGHT - BAR_HEIGHT) / 2))
hpTrack.BackgroundTransparency = 0.65
outline(hpTrack)
hp.trail = frame(hpTrack, HP_TRAIL, UDim2.fromScale(1, 1), UDim2.new())
hp.fill = frame(hpTrack, HP_COLOR, UDim2.fromScale(1, 1), UDim2.new())

-- stamina boxes, filling from the bottom up
local stamina = meter(row(3))
stamina.icon = icon(stamina.group, "\u{00BB}")
stamina.boxes = {}
for i = 1, MAX_BOXES do
	local box = frame(stamina.group, Color3.new(0, 0, 0), UDim2.fromOffset(BOX_SIZE, BOX_SIZE),
		UDim2.fromOffset(ICON_WIDTH + (i - 1) * (BOX_SIZE + BOX_GAP), (ROW_HEIGHT - BOX_SIZE) / 2))
	box.BackgroundTransparency = 0.65
	outline(box)
	local trail = frame(box, STAMINA_TRAIL, UDim2.fromScale(1, 1), UDim2.fromScale(0, 1))
	trail.AnchorPoint = Vector2.new(0, 1)
	local fill = frame(box, STAMINA_COLOR, UDim2.fromScale(1, 1), UDim2.fromScale(0, 1))
	fill.AnchorPoint = Vector2.new(0, 1)
	stamina.boxes[i] = { box = box, fill = fill, trail = trail }
end

-- dodge diamonds, one per charge: solid when ready, filling out from the
-- middle while it recharges
local dodges = {}
for i = 1, MAX_DODGES do
	local diamond = Instance.new("Frame")
	diamond.BackgroundTransparency = 1
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Rotation = 45
	diamond.Size = UDim2.fromOffset(DODGE_SIZE, DODGE_SIZE)
	diamond.Parent = stamina.group
	outline(diamond)
	local fill = frame(diamond, DODGE_COLOR, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5))
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	local scale = Instance.new("UIScale")
	scale.Parent = diamond
	dodges[i] = { diamond = diamond, fill = fill, scale = scale, wasReady = true }
end
-- thin lines joining neighbouring diamonds tip to tip
local dodgeLinks = {}
for i = 1, MAX_DODGES - 1 do
	local link = frame(stamina.group, Color3.new(1, 1, 1), UDim2.fromOffset(LINK_WIDTH, 1), UDim2.new())
	link.AnchorPoint = Vector2.new(0, 0.5)
	link.BackgroundTransparency = 0.5
	dodgeLinks[i] = link
end

-- status effects, lined up with the stamina boxes; shown whenever you have any
local statusIcons = StatusIcons.new(content, Enum.HorizontalAlignment.Left,
	UDim2.fromOffset(ICON_WIDTH - 1, 3 * (ROW_HEIGHT + ROW_GAP)))
statusIcons.row.Size = UDim2.new(1, -(ICON_WIDTH - 1), 0, StatusIcons.Size + 2)

local function updateMeter(m, fraction, dt, stayVisible)
	local now = os.clock()
	if fraction < m.last then
		m.trailHoldUntil = now + TRAIL_HOLD
	end
	if fraction ~= m.last or stayVisible then
		m.lastChangeAt = now
	end
	m.last = fraction

	-- the pale trail jumps up on gains and slides down after losses
	if fraction > m.trailFraction then
		m.trailFraction = fraction
	elseif now >= m.trailHoldUntil then
		m.trailFraction = math.max(fraction, m.trailFraction - TRAIL_SPEED * dt)
	end

	local target = (now - m.lastChangeAt < HIDE_AFTER) and 0 or 1
	m.shown += math.clamp(target - m.shown, -FADE_SPEED * dt, FADE_SPEED * dt)
	m.group.GroupTransparency = m.shown
end

-- how full box i of `count` is (0..1) for an overall fraction
local function boxShare(fraction, i, count)
	return math.clamp(fraction * count - (i - 1), 0, 1)
end

local function onCharacter(character)
	billboard.Adornee = character:WaitForChild("HumanoidRootPart")
	showName()
	for _, m in ipairs({ hp, stamina }) do
		m.last, m.trailFraction = 1, 1
	end
end
if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	statusIcons:Update(character)

	-- HP stays on screen the whole time you're hurt
	local hpFraction = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	updateMeter(hp, hpFraction, dt, hpFraction < 1)
	hp.fill.Size = UDim2.fromScale(hpFraction, 1)
	hp.trail.Size = UDim2.fromScale(hp.trailFraction, 1)

	updateMeter(stamina, Stamina.Get() / Stamina.Max, dt, false)
	local fillColor = Stamina.IsExhausted() and EXHAUSTED_COLOR or STAMINA_COLOR
	stamina.icon.TextColor3 = Stamina.IsExhausted() and EXHAUSTED_COLOR or Color3.new(1, 1, 1)
	local boxCount = math.clamp(math.round(Stamina.Max / StatConfig.StaminaPerBox), 1, MAX_BOXES)
	for i, box in ipairs(stamina.boxes) do
		box.box.Visible = i <= boxCount
		box.fill.Size = UDim2.fromScale(1, boxShare(stamina.last, i, boxCount))
		box.trail.Size = UDim2.fromScale(1, boxShare(stamina.trailFraction, i, boxCount))
		box.fill.BackgroundColor3 = fillColor
	end
	local charges = DodgeCharges.Get()
	local firstX = ICON_WIDTH + boxesWidth(boxCount) + DODGE_GAP + BOX_SIZE / 2
	for i, link in ipairs(dodgeLinks) do
		link.Visible = i + 1 <= DodgeCharges.Max
		link.Position = UDim2.fromOffset(firstX + (i - 1) * DODGE_STEP + LINK_START, ROW_HEIGHT / 2)
	end
	for i, dodge in ipairs(dodges) do
		dodge.diamond.Visible = i <= DodgeCharges.Max
		dodge.diamond.Position = UDim2.fromOffset(firstX + (i - 1) * DODGE_STEP, ROW_HEIGHT / 2)
		local charged = math.clamp(charges - (i - 1), 0, 1)
		local ready = charged >= 1
		dodge.fill.Size = UDim2.fromScale(charged, charged)
		dodge.fill.BackgroundTransparency = ready and 0 or 0.5
		if ready and not dodge.wasReady then
			dodge.scale.Scale = 1.4
			TweenService:Create(dodge.scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		dodge.wasReady = ready
	end

	-- the name shows whenever either meter does
	nameGroup.GroupTransparency = math.min(hp.shown, stamina.shown)
end)
