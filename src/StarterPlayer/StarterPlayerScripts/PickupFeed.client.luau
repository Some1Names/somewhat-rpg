-- Pickup feed: bottom left, just above the yen, a line for each reward as it comes in,
-- newest at the bottom. XP and yen from one source (a kill, a bounty, a chest: the
-- Progress event's source, PlayerStats.Source) share a line: its name on the left,
-- "+12 XP  +¥30" on the right. Materials picked up (Mat_<key> going up) get a line each,
-- and more of the same while it shows adds to it. Each line fades from its rarity's
-- colour (DropConfig tiers) on the left to clear, with a bar of it on the edge. Square;
-- a line slides in, and fades out LIFETIME seconds after its last change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DropConfig = require(ReplicatedStorage:WaitForChild("DropConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local progressEvent = ReplicatedStorage:WaitForChild("Progress")

local player = Players.LocalPlayer

local ROW_HEIGHT = 24
local ROW_GAP = 4
local MAX_LINES = 5
local LIFETIME = 4 -- seconds a line stays after its last change
local FADE_TIME = 0.4
local SLIDE = 16 -- px a line slides in from
local EDGE_WIDTH = 3
local YEN = Color3.fromRGB(255, 205, 60)
local Style = HudConfig.Style

local gui = Instance.new("ScreenGui")
gui.Name = "PickupFeed"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- the column above the yen line, as wide as the cards
local feed = Instance.new("Frame")
feed.Name = "Feed"
feed.AnchorPoint = Vector2.new(0, 1)
feed.Position = UDim2.new(0, HudConfig.EdgeMargin, 1, -(HudConfig.BottomReserve + HudConfig.CardHeight + HudConfig.ClusterGap + HudConfig.YenHeight + 6))
feed.Size = UDim2.fromOffset(HudConfig.SideWidth, MAX_LINES * (ROW_HEIGHT + ROW_GAP))
feed.BackgroundTransparency = 1
feed.Parent = gui
local layout = Instance.new("UIListLayout")
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, ROW_GAP)
layout.Parent = feed

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Style.LabelFont
	l.TextSize = 13
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.6
	l.TextTruncate = Enum.TextTruncate.AtEnd
	for key, value in pairs(props) do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

local function tierColor(tier)
	return DropConfig.Tiers[tier] and DropConfig.TierColor(tier) or DropConfig.TierColor("Common")
end

local lines = {} -- key -> line, while it shows
local order = 0

local function remove(key)
	local line = lines[key]
	if not line then
		return
	end
	lines[key] = nil
	local fade = TweenService:Create(line.group, TweenInfo.new(FADE_TIME), { GroupTransparency = 1 })
	fade:Play()
	fade.Completed:Once(function()
		line.holder:Destroy()
	end)
end

-- the line for `key`, made (sliding in) if it isn't showing
local function lineFor(key, title, tier)
	local line = lines[key]
	if line then
		return line
	end
	order += 1
	local color = tierColor(tier)
	local holder = Instance.new("Frame")
	holder.LayoutOrder = order
	holder.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	holder.BackgroundTransparency = 1
	holder.Parent = feed
	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.Position = UDim2.fromOffset(-SLIDE, 0)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = holder
	-- the rarity colour, fading out to the right (its own frame, so the text stays solid)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = group
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = fill
	local edge = Instance.new("Frame")
	edge.Size = UDim2.new(0, EDGE_WIDTH, 1, 0)
	edge.BackgroundColor3 = color
	edge.BorderSizePixel = 0
	edge.Parent = group
	line = {
		holder = holder,
		group = group,
		xp = 0,
		yen = 0,
		count = 0,
		title = label(group, {
			Position = UDim2.fromOffset(EDGE_WIDTH + 8, 0),
			Size = UDim2.new(0.55, 0, 1, 0),
			Font = Style.TitleFont,
			TextSize = 15,
			Text = string.upper(title),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		amounts = label(group, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.new(0.45, -8, 1, 0),
			Font = Style.MonoFont,
			TextSize = 12,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	}
	lines[key] = line
	TweenService:Create(group, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
		Position = UDim2.new(),
	}):Play()
	-- too many: the oldest goes
	local oldestKey, oldest
	local shown = 0
	for otherKey, other in pairs(lines) do
		shown += 1
		if not oldest or other.holder.LayoutOrder < oldest.holder.LayoutOrder then
			oldestKey, oldest = otherKey, other
		end
	end
	if shown > MAX_LINES then
		remove(oldestKey)
	end
	return line
end

-- keeps the line up for LIFETIME more seconds
local function touch(key, line)
	line.stamp = (line.stamp or 0) + 1
	local stamp = line.stamp
	task.delay(LIFETIME, function()
		if lines[key] == line and line.stamp == stamp then
			remove(key)
		end
	end)
end

-- XP and yen, one line per source; rewards without a source (refunds, sales) don't show
progressEvent.OnClientEvent:Connect(function(xp, _levels, yen, source)
	if typeof(source) ~= "table" or (xp <= 0 and yen <= 0) then
		return
	end
	local key = "source:" .. tostring(source.id)
	local line = lineFor(key, tostring(source.label or ""), source.tier)
	line.xp += xp
	line.yen += yen
	local parts = {}
	if line.xp > 0 then
		table.insert(parts, string.format("+%d XP", line.xp))
	end
	if line.yen > 0 then
		table.insert(parts, string.format('<font color="#%s">+%s</font>', YEN:ToHex(), formatYen(line.yen)))
	end
	line.amounts.Text = table.concat(parts, "  ")
	touch(key, line)
end)

-- materials picked up; the first value seen for one is the load from the save, no line
for key, material in pairs(DropConfig.Materials) do
	local attribute = DropConfig.Attribute(key)
	local last = player:GetAttribute(attribute)
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local value = player:GetAttribute(attribute)
		if typeof(value) == "number" and typeof(last) == "number" and value > last then
			local lineKey = "material:" .. key
			local line = lineFor(lineKey, material.display, material.tier)
			line.count += value - last
			line.amounts.Text = string.format('<font color="#%s">+%d</font>', tierColor(material.tier):ToHex(), line.count)
			touch(lineKey, line)
		end
		last = value
	end)
end
