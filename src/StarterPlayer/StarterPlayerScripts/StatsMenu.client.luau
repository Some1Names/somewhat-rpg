-- Stats menu: press M or click STATS to spend stat points on Vitality,
-- Strength, Superliminal and Firearm, and see when the next stamina box unlocks. The
-- INFO button under it shows the milestones and their rewards as bars. Also pops up XP
-- gains and level ups. The numbers come from the player attributes the
-- server keeps (see PlayerStats).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PunchConfig = require(ReplicatedStorage:WaitForChild("PunchConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local allocateEvent = ReplicatedStorage:WaitForChild("AllocateStat")
local progressEvent = ReplicatedStorage:WaitForChild("Progress")

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.M
local AMOUNTS = { 1, 5, 10 } -- points added per click
local PANEL_WIDTH = 300
local PADDING = 14
local STAT_ROW_HEIGHT = 56
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local GOLD = Color3.fromRGB(255, 205, 60) -- same as critical hit numbers

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

local function outline(parent, transparency)
	return make("UIStroke", {
		Parent = parent,
		Color = TEXT,
		Transparency = transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextTruncate = Enum.TextTruncate.AtEnd
	return make("TextLabel", props)
end

local function section(order, height)
	return make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	})
end

local gui = make("ScreenGui", {
	Name = "StatsMenu",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- STATS button on the left edge, with a badge for unspent points
local toggle = make("TextButton", {
	Name = "Toggle",
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(64, 28),
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.25,
	Font = Enum.Font.GothamBold,
	Text = "STATS",
	TextSize = 11,
	TextColor3 = TEXT,
})
outline(toggle, 0.5)
local toggleScale = make("UIScale", { Parent = toggle })
local badge = make("TextLabel", {
	Parent = toggle,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(20, 18),
	BackgroundColor3 = GOLD,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = BACKGROUND,
	Visible = false,
})

-- yen, just above the STATS button
local yenLabel = make("TextLabel", {
	Name = "Yen",
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, -36),
	Size = UDim2.fromOffset(96, 24),
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.25,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
})
make("UIPadding", { Parent = yenLabel, PaddingLeft = UDim.new(0, 8) })
outline(yenLabel, 0.5)

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

local panel = make("Frame", {
	Name = "Panel",
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 92, 0.5, 0),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.15,
	Visible = false,
})
outline(panel, 0.6)
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

-- header: title, level and close button
local header = section(1, 22)
header.Parent = panel
label(header, { Text = "STATS", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.fromScale(0.5, 1) })
local levelLabel = label(header, {
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -30, 0, 0),
	Size = UDim2.new(0.5, -30, 1, 0),
})
-- Modal frees the mouse while the menu is open, even in shift lock
local closeButton = make("TextButton", {
	Parent = header,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
	Modal = true,
})

-- XP bar
local xpSection = section(2, 24)
xpSection.Parent = panel
local xpTrack = make("Frame", {
	Parent = xpSection,
	Size = UDim2.new(1, 0, 0, 6),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
})
local xpFill = make("Frame", {
	Parent = xpTrack,
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
})
local xpLabel = label(xpSection, {
	TextSize = 11,
	TextColor3 = MUTED,
	Position = UDim2.fromOffset(0, 10),
	Size = UDim2.new(0.4, 0, 0, 14),
})
-- stamina boxes come with levels rather than a stat
local boxesLabel = label(xpSection, {
	TextSize = 11,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 10),
	Size = UDim2.new(0.6, 0, 0, 14),
})

-- unspent points and how many each click adds
local pointsSection = section(3, 24)
pointsSection.Parent = panel
local pointsLabel = label(pointsSection, { Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, -120, 1, 0) })
local amount = AMOUNTS[1]
local chips = {}
local function showChips()
	for value, chip in pairs(chips) do
		local selected = value == amount
		chip.BackgroundTransparency = selected and 0 or 1
		chip.TextColor3 = selected and BACKGROUND or TEXT
	end
end
for i, value in ipairs(AMOUNTS) do
	local chip = make("TextButton", {
		Parent = pointsSection,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(#AMOUNTS - i) * 38, 0.5, 0),
		Size = UDim2.fromOffset(34, 22),
		BackgroundColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		Text = "x" .. value,
		TextSize = 11,
	})
	outline(chip, 0.5)
	chip.Activated:Connect(function()
		amount = value
		showChips()
	end)
	chips[value] = chip
end
showChips()

local divider = section(4, 1)
divider.BackgroundTransparency = 0.85
divider.BackgroundColor3 = TEXT
divider.BorderSizePixel = 0
divider.Parent = panel

local function formatNumber(n)
	return n % 1 == 0 and tostring(n) or string.format("%.1f", n)
end

-- what a stat gives now, and what comes next
local describe = {
	Vitality = function(points)
		local _, upcoming = StatConfig.Milestones("Vitality", points)
		local now = string.format("%d max HP  ·  %s HP/s regen", StatConfig.MaxHealth(points), formatNumber(StatConfig.RegenPerSecond(points)))
		if upcoming then
			return now, string.format("+%d HP per point  ·  %s HP/s regen at %d", StatConfig.HealthPerVitality, formatNumber(upcoming.regen), upcoming.at)
		end
		return now, string.format("+%d HP per point  ·  regen maxed", StatConfig.HealthPerVitality)
	end,
	Strength = function(points)
		local multiplier = StatConfig.DamageMultiplier("Strength", points)
		local fists = PunchConfig.Weapons.Fists.baseDamage * multiplier
		local axe = PunchConfig.Weapons.MandelaAxe.baseDamage * multiplier
		local now = string.format("%s punch  ·  %s Mandela axe", formatNumber(fists), formatNumber(axe))
		return now, string.format("+%d%% melee damage per point", math.round(StatConfig.Get("Strength").damageBonus * 100))
	end,
	Superliminal = function(points)
		local now = string.format("%d%% skill damage", math.round(StatConfig.DamageMultiplier("Superliminal", points) * 100))
		return now, string.format("+%d%% per point  ·  skills, Knife, Light Shot", math.round(StatConfig.Get("Superliminal").damageBonus * 100))
	end,
	Firearm = function(points)
		local now = string.format("%d%% gun damage", math.round(StatConfig.DamageMultiplier("Firearm", points) * 100))
		return now, string.format("+%d%% per point  ·  Revolver shots and skills", math.round(StatConfig.Get("Firearm").damageBonus * 100))
	end,
}

local rows = {}
for i, stat in ipairs(StatConfig.Stats) do
	local rowFrame = section(4 + i, STAT_ROW_HEIGHT)
	rowFrame.Parent = panel
	label(rowFrame, { Text = stat.key, Font = Enum.Font.GothamBold, TextSize = 14, Size = UDim2.new(1, -90, 0, 18) })
	local value = label(rowFrame, {
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -42, 0, 0),
		Size = UDim2.fromOffset(48, 18),
	})
	local effect = label(rowFrame, { TextSize = 12, Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, -42, 0, 15) })
	local upcoming = label(rowFrame, {
		TextSize = 11,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, -42, 0, 14),
	})
	local plus = make("TextButton", {
		Parent = rowFrame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		Text = "+",
		TextSize = 20,
		TextColor3 = BACKGROUND,
	})
	plus.Activated:Connect(function()
		allocateEvent:FireServer(stat.key, amount)
	end)
	rows[i] = { stat = stat, value = value, effect = effect, upcoming = upcoming, plus = plus }
end

local function refresh()
	local level = player:GetAttribute("Level")
	local points = player:GetAttribute("StatPoints") or 0
	yenLabel.Text = formatYen(player:GetAttribute("Yen") or 0)
	badge.Visible = points > 0
	badge.Text = points > 99 and "99+" or tostring(points)
	if not level then
		levelLabel.Text = ""
		xpLabel.Text = "Loading…"
		return
	end

	levelLabel.Text = "Lv " .. level
	if level >= StatConfig.MaxLevel then
		xpFill.Size = UDim2.fromScale(1, 1)
		xpLabel.Text = "Max level"
	else
		local needed = StatConfig.XPToLevelUp(level)
		local xp = player:GetAttribute("XP") or 0
		xpFill.Size = UDim2.fromScale(math.clamp(xp / needed, 0, 1), 1)
		xpLabel.Text = string.format("%d / %d XP", xp, needed)
	end
	-- the soonest level reward: a stamina box or a dodge charge
	local _, nextBox = StatConfig.StaminaBoxes(level)
	local _, nextCharge = StatConfig.DodgeCharges(level)
	if nextCharge and (not nextBox or nextCharge.level < nextBox.level) then
		boxesLabel.Text = string.format("Lv %d: +1 dodge charge", nextCharge.level)
	elseif nextBox then
		boxesLabel.Text = string.format("Lv %d: +1 stamina box", nextBox.level)
	else
		boxesLabel.Text = "All level rewards unlocked"
	end
	pointsLabel.Text = points == 1 and "1 point to spend" or points .. " points to spend"

	for _, row in ipairs(rows) do
		local value = player:GetAttribute(row.stat.key) or 0
		row.value.Text = tostring(value)
		row.effect.Text, row.upcoming.Text = describe[row.stat.key](value)
		local cap = StatConfig.StatCap(row.stat.key)
		if value >= cap then
			row.upcoming.Text = string.format("Maxed  ·  %d points is the cap", cap)
		end
		local canAdd = points > 0 and value < cap
		row.plus.AutoButtonColor = canAdd
		row.plus.BackgroundTransparency = canAdd and 0 or 0.8
		row.plus.TextTransparency = canAdd and 0 or 0.5
	end
end
refresh()
player.AttributeChanged:Connect(refresh)

-- INFO button under STATS: the milestones (level rewards, then each stat's)
-- as a stack of bars, one per milestone, that together read as one
-- progress track: reached ones full, the next one filling in gold with how
-- far along you are, later ones empty. It opens where the stats panel does,
-- so only one of the two is open at a time.
local INFO_MAX_BODY_HEIGHT = 380 -- past this the list scrolls
local INFO_BAR_HEIGHT = 22
local INFO_AT_WIDTH = 70 -- the milestone column inside a bar
local INFO_COUNT_WIDTH = 48 -- the progress count on the right of a bar

local infoToggle = make("TextButton", {
	Name = "InfoToggle",
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 36),
	Size = UDim2.fromOffset(64, 28),
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.25,
	Font = Enum.Font.GothamBold,
	Text = "INFO",
	TextSize = 11,
	TextColor3 = TEXT,
})
outline(infoToggle, 0.5)

local infoPanel = make("Frame", {
	Name = "InfoPanel",
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 92, 0.5, 0),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.15,
	Visible = false,
})
outline(infoPanel, 0.6)
make("UIPadding", {
	Parent = infoPanel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = infoPanel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

local infoHeader = section(1, 22)
infoHeader.Parent = infoPanel
label(infoHeader, { Text = "MILESTONES", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, -30, 1, 0) })
local infoClose = make("TextButton", {
	Parent = infoHeader,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
	Modal = true,
})

-- the list scrolls, so the panel never runs off a short screen
local infoBody = make("ScrollingFrame", {
	Parent = infoPanel,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, INFO_MAX_BODY_HEIGHT),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIPadding", { Parent = infoBody, PaddingRight = UDim.new(0, 10) })
local infoLayout = make("UIListLayout", { Parent = infoBody, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) })
-- only as tall as the bars need, up to the cap
infoLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	infoBody.Size = UDim2.new(1, 0, 0, math.min(infoLayout.AbsoluteContentSize.Y, INFO_MAX_BODY_HEIGHT))
end)

local infoOrder = 0
local function infoLine(height)
	infoOrder += 1
	return make("Frame", {
		Parent = infoBody,
		LayoutOrder = infoOrder,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	})
end

local function infoHeading(text, first)
	local line = infoLine(first and 18 or 28)
	label(line, {
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = MUTED,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Size = UDim2.new(1, 0, 1, -3),
	})
end

-- One bar per milestone ({ at, label, reward }). Each bar is the stretch
-- from the milestone before it (or `base`) to its own, filled as far as
-- `current` has got, so the stack reads as one track.
local function infoMilestones(entries, current, base)
	table.sort(entries, function(a, b)
		return a.at < b.at
	end)
	local from = base
	local nextFound = false
	for _, entry in ipairs(entries) do
		local reached = current >= entry.at
		local isNext = not reached and not nextFound
		nextFound = nextFound or isNext
		local color = reached and TEXT or isNext and GOLD or MUTED
		local share = math.clamp((current - from) / math.max(entry.at - from, 1), 0, 1)
		from = entry.at

		local bar = infoLine(INFO_BAR_HEIGHT)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BackgroundTransparency = 0.5
		bar.BorderSizePixel = 0
		local stroke = outline(bar, isNext and 0.3 or 0.85)
		stroke.Color = isNext and GOLD or TEXT
		make("Frame", {
			Parent = bar,
			Size = UDim2.fromScale(share, 1),
			BackgroundColor3 = isNext and GOLD or TEXT,
			BackgroundTransparency = isNext and 0.6 or 0.8,
			BorderSizePixel = 0,
		})
		label(bar, {
			Text = entry.label,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = color,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0, INFO_AT_WIDTH, 1, 0),
		})
		label(bar, {
			Text = entry.reward,
			TextSize = 12,
			TextColor3 = color,
			Position = UDim2.fromOffset(8 + INFO_AT_WIDTH, 0),
			Size = UDim2.new(1, -(16 + INFO_AT_WIDTH + INFO_COUNT_WIDTH), 1, 0),
		})
		-- how far along, on the one you're working towards
		label(bar, {
			Text = isNext and string.format("%d/%d", current, entry.at) or "",
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.new(0, INFO_COUNT_WIDTH, 1, 0),
		})
	end
end

-- a level table's unlocks after the starting one, each as what it adds to the one before
local function levelUnlocks(unlocks, field, singular, plural, entries)
	local previous
	for _, unlock in ipairs(unlocks) do
		if previous then
			local gained = unlock[field] - previous
			table.insert(entries, {
				at = unlock.level,
				label = "Lv " .. unlock.level,
				reward = string.format("+%d %s", gained, gained == 1 and singular or plural),
			})
		end
		previous = unlock[field]
	end
end

-- what a stat milestone gives, in words
local function milestoneReward(milestone)
	if milestone.regen then
		return formatNumber(milestone.regen) .. " HP/s regen"
	end
	local parts = {}
	for key, value in pairs(milestone) do
		if key ~= "at" then
			table.insert(parts, key .. " " .. tostring(value))
		end
	end
	return table.concat(parts, ", ")
end

local function buildInfo()
	for _, child in ipairs(infoBody:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	infoOrder = 0

	local levelEntries = {}
	levelUnlocks(StatConfig.StaminaBoxLevels, "boxes", "stamina box", "stamina boxes", levelEntries)
	levelUnlocks(StatConfig.DodgeChargeLevels, "charges", "dodge charge", "dodge charges", levelEntries)
	infoHeading("LEVEL", true)
	infoMilestones(levelEntries, player:GetAttribute("Level") or 0, 0)

	for _, stat in ipairs(StatConfig.Stats) do
		local entries = {}
		for _, milestone in ipairs(stat.milestones) do
			if milestone.at > 0 then
				table.insert(entries, { at = milestone.at, label = milestone.at .. " points", reward = milestoneReward(milestone) })
			end
		end
		if #entries > 0 then
			infoHeading(string.upper(stat.key))
			infoMilestones(entries, player:GetAttribute(stat.key) or 0, 0)
		end
	end
end

local function setInfoOpen(open)
	if open then
		buildInfo()
		panel.Visible = false
	end
	infoPanel.Visible = open
end

infoToggle.Activated:Connect(function()
	setInfoOpen(not infoPanel.Visible)
end)
infoClose.Activated:Connect(function()
	setInfoOpen(false)
end)
-- kept current while it's open
player.AttributeChanged:Connect(function(name)
	if infoPanel.Visible and (name == "Level" or StatConfig.Get(name) ~= nil) then
		buildInfo()
	end
end)

local function setOpen(open)
	panel.Visible = open
	if open then
		infoPanel.Visible = false
	end
end

toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == TOGGLE_KEY then
		setOpen(not panel.Visible)
	end
end)

-- a line of text that drifts up and fades, for XP and level ups
local function popup(text, color, size, height, lifetime)
	local popupLabel = make("TextLabel", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, height),
		Size = UDim2.fromOffset(400, size + 8),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		TextStrokeTransparency = 0.5,
	})
	TweenService:Create(popupLabel, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, height - 0.03),
	}):Play()
	local fade = TweenInfo.new(lifetime / 2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, lifetime / 2)
	TweenService:Create(popupLabel, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(popupLabel, lifetime)
end

progressEvent.OnClientEvent:Connect(function(xpGained, levelsGained, yenGained)
	if xpGained > 0 then
		popup(string.format("+%d XP", xpGained), TEXT, 18, 0.72, 1.2)
	end
	if yenGained and yenGained > 0 then
		popup("+" .. formatYen(yenGained), GOLD, 18, 0.76, 1.2)
	end
	if levelsGained > 0 then
		popup("LEVEL UP", GOLD, 34, 0.22, 2.5)
		local level = player:GetAttribute("Level") or 0
		popup(string.format("Lv %d  ·  +%d stat points", level, levelsGained * StatConfig.PointsPerLevel), TEXT, 16, 0.27, 2.5)
		local newBoxes = StatConfig.StaminaBoxes(level) - StatConfig.StaminaBoxes(level - levelsGained)
		if newBoxes > 0 then
			popup(newBoxes == 1 and "+1 stamina box" or string.format("+%d stamina boxes", newBoxes), GOLD, 16, 0.31, 2.5)
		end
		local newCharges = StatConfig.DodgeCharges(level) - StatConfig.DodgeCharges(level - levelsGained)
		if newCharges > 0 then
			popup(newCharges == 1 and "+1 dodge charge" or string.format("+%d dodge charges", newCharges), GOLD, 16, newBoxes > 0 and 0.35 or 0.31, 2.5)
		end
		toggleScale.Scale = 1.3
		TweenService:Create(toggleScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end)
