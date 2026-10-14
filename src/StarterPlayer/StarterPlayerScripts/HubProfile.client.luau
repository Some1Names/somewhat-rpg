-- The hub's Profile tab, its cover page: the player's name with the level,
-- an XP bar, yen, then the power held (big, in caps), its tier, mastery and
-- reforge level, the bounty taken, and unspent
-- stat points (a link to Stats). The right side is left to the posed character
-- (HubPose), with a huge faded "01" behind it.
-- Everything comes from player attributes other systems keep.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local ReforgeRules = require(ReplicatedStorage:WaitForChild("ReforgeRules"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))

local player = Players.LocalPlayer
local Theme = Hub.Theme
local WHITE = Color3.new(1, 1, 1)

local LEFT_SHARE = 0.62 -- the text column; the rest is the faded number

local function make(className, props)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Theme.LabelFont
	props.TextColor3 = props.TextColor3 or Theme.Ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

-- a black chip of microtext
local function chip(parent, text, order)
	return label(parent, {
		LayoutOrder = order,
		Text = " " .. text .. " ",
		TextSize = 11,
		TextColor3 = WHITE,
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
	})
end

-- "IridescentRequiem" as "IRIDESCENT REQUIEM"
local function setTitle(setName)
	return string.upper((string.gsub(setName, "(%l)(%u)", "%1 %2")))
end

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

local frame = Hub.Tab("Profile", { order = 1, title = "PROFILE", pose = "Random" })

-- the faded number, on the right
label(frame, {
	Text = "01",
	Font = Theme.BodyFont,
	TextSize = 200,
	TextColor3 = Theme.Ink,
	TextTransparency = 0.8,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, -20),
	Size = UDim2.new(1 - LEFT_SHARE, 0, 0, 200),
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 0,
})

local column = make("Frame", {
	Parent = frame,
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(LEFT_SHARE, 0, 1, -8),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = column, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

chip(column, "CURRENT POWER", 1)
local powerLabel = label(column, {
	LayoutOrder = 2,
	Font = Theme.TitleFont,
	TextSize = 44,
	Size = UDim2.new(1, 0, 0, 48),
	AutomaticSize = Enum.AutomaticSize.Y, -- a long name wraps onto more lines
	TextWrapped = true,
})
local tierRow = make("Frame", { Parent = column, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1 })
make("UIListLayout", {
	Parent = tierRow,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
})
local tierChip = chip(tierRow, "", 1)
local masteryLabel = label(tierRow, { LayoutOrder = 2, TextSize = 11, TextColor3 = Theme.Muted, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X })
local masteryBack = make("Frame", { Parent = column, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Theme.BarBack, BorderSizePixel = 0 })
local masteryFill = make("Frame", { Parent = masteryBack, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 })

-- the bounty card: a panel with an accent bar down its left edge
local bounty = make("Frame", { Parent = column, LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 })
local bountyBar = make("Frame", { Parent = bounty, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 })
label(bounty, { Text = "ACTIVE BOUNTY", TextSize = 10, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 12) })
local bountyLabel = label(bounty, { Font = Theme.BodyFont, TextSize = 13, Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -24, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })

-- at the top: the player's name with the level at the far right, the XP
-- toward the next level as a bar, then yen; all plain on the paper
local nameRow = make("Frame", { Parent = column, LayoutOrder = -5, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
label(nameRow, {
	Text = string.upper(player.DisplayName),
	Font = Theme.TitleFont,
	TextSize = 30,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	Size = UDim2.new(1, -110, 1, 0),
	TextTruncate = Enum.TextTruncate.AtEnd,
})
label(nameRow, {
	Text = "LEVEL",
	TextSize = 10,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(100, 12),
})
local levelFigure = label(nameRow, {
	Font = Theme.TitleFont,
	TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.fromOffset(100, 30),
})
label(column, { LayoutOrder = -4, Text = "@" .. player.Name, TextSize = 11, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, 12) })

local xpRow = make("Frame", { Parent = column, LayoutOrder = -3, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
label(xpRow, { Text = "XP", TextSize = 10, TextColor3 = Theme.Muted, Size = UDim2.fromOffset(40, 12) })
local levelLabel = label(xpRow, {
	TextSize = 10,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.new(1, 0, 0, 12),
})
local xpBack = make("Frame", { Parent = xpRow, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Theme.BarBack, BorderSizePixel = 0 })
local xpFill = make("Frame", { Parent = xpBack, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 })

local yenRow = make("Frame", { Parent = column, LayoutOrder = -2, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
label(yenRow, { Text = "YEN", TextSize = 10, TextColor3 = Theme.Muted, Size = UDim2.fromOffset(60, 12) })
local yenFigure = label(yenRow, { Font = Theme.TitleFont, TextSize = 26, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 30) })

-- a gap before CURRENT POWER
make("Frame", { Parent = column, LayoutOrder = -1, Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1 })
local pointsButton = make("TextButton", {
	Parent = column,
	LayoutOrder = 8,
	Size = UDim2.fromOffset(0, 14),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Font = Theme.LabelFont,
	TextSize = 11,
	TextColor3 = Theme.Ink,
	TextXAlignment = Enum.TextXAlignment.Left,
})
pointsButton.Activated:Connect(function()
	Hub.Open("Stats")
end)

local function refresh()
	local setName = player:GetAttribute("CurrentPower")
	local set = setName and SkillSetConfig.Sets[setName]
	if set then
		powerLabel.Text = setTitle(setName)
		powerLabel.TextColor3 = Theme.Ink
		local tier = SkillSetConfig.TierOf(setName)
		tierChip.Text = " " .. set.tier .. " "
		tierChip.BackgroundColor3 = tier and tier.color or SkillSetConfig.NoTierColor
		local mastery = player:GetAttribute(SkillSetConfig.MasteryAttribute(setName)) or 0
		local reforge = ReforgeRules.DecodeState(player:GetAttribute(ReforgeConfig.SetAttribute(setName))).level
		masteryLabel.Text = string.format("MASTERY %d / %d  ·  FORGE +%d", mastery, SkillSetConfig.MaxMastery, reforge)
		masteryFill.Size = UDim2.fromScale(math.clamp(mastery / SkillSetConfig.MaxMastery, 0, 1), 1)
		tierRow.Visible, masteryBack.Visible = true, true
	else
		powerLabel.Text = "NO POWER"
		powerLabel.TextColor3 = Theme.Muted
		tierRow.Visible, masteryBack.Visible = false, false
	end

	local _, quest = QuestConfig.parseQuestId(player:GetAttribute("QuestId"))
	if quest then
		bountyLabel.Text = string.format("%s   %d / %d", quest.title, player:GetAttribute("QuestProgress") or 0, quest.count)
	else
		bountyLabel.Text = "NO BOUNTY. TALK TO A BOUNTY HUNTER."
	end

	local level = player:GetAttribute("Level") or 1
	levelFigure.Text = tostring(level)
	yenFigure.Text = formatYen(player:GetAttribute("Yen") or 0)
	if level >= StatConfig.MaxLevel then
		levelLabel.Text = "MAX LEVEL"
		xpFill.Size = UDim2.fromScale(1, 1)
	else
		local xp, needed = player:GetAttribute("XP") or 0, StatConfig.XPToLevelUp(level)
		levelLabel.Text = string.format("%d / %d XP", xp, needed)
		xpFill.Size = UDim2.fromScale(math.clamp(xp / needed, 0, 1), 1)
	end
	local points = player:GetAttribute("StatPoints") or 0
	pointsButton.Text = string.format("%d UNSPENT POINT%s  →  STATS", points, points == 1 and "" or "S")
	pointsButton.Visible = points > 0
end

Hub.OnAccent(function(_, ink)
	masteryFill.BackgroundColor3 = ink
	bountyBar.BackgroundColor3 = ink
	xpFill.BackgroundColor3 = ink
end)
Hub.OnShown("Profile", refresh)

local watched = {
	CurrentPower = true,
	QuestId = true,
	QuestProgress = true,
	Level = true,
	XP = true,
	Yen = true,
	StatPoints = true,
}
player.AttributeChanged:Connect(function(name)
	if Hub.IsOpen("Profile") and (watched[name] or string.find(name, "Mastery$") or string.find(name, "^Reforge_")) then
		refresh()
	end
end)
