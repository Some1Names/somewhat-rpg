-- The hub's Profile tab, its cover page: the player's name with the level,
-- an XP bar, yen, then the power held (big, in caps), its tier, mastery and
-- reforge level, the bounty taken, the faction and its rank, and unspent
-- stat points (a link to Stats). The right side is left to the posed character
-- (HubPose), with a huge faded "01" behind it.
-- Everything comes from player attributes other systems keep.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local ReforgeRules = require(ReplicatedStorage:WaitForChild("ReforgeRules"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local TalismanConfig = require(ReplicatedStorage:WaitForChild("TalismanConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))

local player = Players.LocalPlayer
local Theme = Hub.Theme

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

-- an ink chip of microtext (dark text on the light ink)
local function chip(parent, text, order)
	return label(parent, {
		LayoutOrder = order,
		Text = " " .. text .. " ",
		TextSize = 11,
		TextColor3 = Theme.Paper,
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

-- the faction card: its colour for the rank down the left edge, the rank and name,
-- and the standing toward the next rank
local factionCard = make("Frame", { Parent = column, LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 })
local factionBar = make("Frame", { Parent = factionCard, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 })
label(factionCard, { Text = "FACTION", TextSize = 10, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 12) })
local factionLabel = label(factionCard, { Font = Theme.BodyFont, TextSize = 13, Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -24, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
local factionBack = make("Frame", { Parent = factionCard, Position = UDim2.new(0, 12, 1, -12), Size = UDim2.new(1, -24, 0, 4), BackgroundColor3 = Theme.BarBack, BorderSizePixel = 0 })
local factionFill = make("Frame", { Parent = factionBack, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 })
local factionNote = label(factionCard, { TextSize = 10, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 12) })

-- the talismans: a line per slot (worn, empty, or locked until its level)
chip(column, "TALISMANS", 7)
local talismanBox = make("Frame", { Parent = column, LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
make("UIListLayout", { Parent = talismanBox, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) })
local talismanLines = {}
for i = 1, #TalismanConfig.SlotLevels do
	local line = make("Frame", { Parent = talismanBox, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 })
	local bar = make("Frame", { Parent = line, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 })
	local text = label(line, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 1, 0), Font = Theme.BodyFont, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd })
	local note = label(line, {
		TextSize = 10,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	talismanLines[i] = { bar = bar, text = text, note = note }
end

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
	LayoutOrder = 9,
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

	local factionKey = player:GetAttribute("Faction")
	local faction = factionKey and FactionConfig.Get(factionKey)
	if faction then
		local standing = player:GetAttribute("FactionStanding") or 0
		local color = Color3.fromRGB(table.unpack(FactionConfig.RankColor(factionKey, standing)))
		factionLabel.Text = string.format("%s  %s", FactionConfig.Title(factionKey, standing), faction.name)
		factionLabel.TextColor3 = color
		factionBar.BackgroundColor3 = color
		factionFill.BackgroundColor3 = color
		local nextStanding = FactionConfig.NextRankStanding(standing)
		if nextStanding then
			factionNote.Text = string.format("%d / %d STANDING", standing, nextStanding)
			local base = FactionConfig.Ranks[FactionConfig.RankIndex(standing)].standing
			factionFill.Size = UDim2.fromScale(math.clamp((standing - base) / (nextStanding - base), 0, 1), 1)
		else
			factionNote.Text = "TOP RANK"
			factionFill.Size = UDim2.fromScale(1, 1)
		end
		factionBack.Visible = true
	else
		factionLabel.Text = "NO FACTION. FIND A RECRUITER."
		factionLabel.TextColor3 = Theme.Muted
		factionBar.BackgroundColor3 = Theme.Muted
		factionNote.Text = ""
		factionBack.Visible = false
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
	local worn = TalismanConfig.Parse(player:GetAttribute(TalismanConfig.EquippedAttribute))
	local open = TalismanConfig.Slots(level)
	for i, line in ipairs(talismanLines) do
		local talisman = worn[i] and TalismanConfig.Get(worn[i])
		if talisman then
			line.text.Text = talisman.name
			line.text.TextColor3 = Theme.Ink
			line.bar.BackgroundColor3 = Color3.fromRGB(table.unpack(talisman.color))
			line.bar.BackgroundTransparency = 0
			line.note.Text = talisman.description
		else
			local isOpen = i <= open
			line.text.Text = isOpen and "EMPTY SLOT" or "LOCKED"
			line.text.TextColor3 = Theme.Muted
			line.bar.BackgroundColor3 = Theme.Muted
			line.bar.BackgroundTransparency = 0.6
			line.note.Text = isOpen and "WEAR ONE IN THE BACKPACK" or string.format("LEVEL %d", TalismanConfig.SlotLevels[i])
		end
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
	Faction = true,
	FactionStanding = true,
	[TalismanConfig.EquippedAttribute] = true,
}
player.AttributeChanged:Connect(function(name)
	if Hub.IsOpen("Profile") and (watched[name] or string.find(name, "Mastery$") or string.find(name, "^Reforge_")) then
		refresh()
	end
end)
