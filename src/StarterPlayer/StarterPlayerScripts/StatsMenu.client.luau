-- The hub's Stats tab (M, or the hub's nav): spend stat points on Vitality,
-- Strength, Superliminal and Firearm, and see when the next stamina box
-- unlocks. Its MILESTONES sub-tab shows the milestones and their rewards as
-- bars. Beside them, CURRENT lists what the stats add up to (max HP, regen,
-- damage, stamina, dodges). Unspent points show as a badge in the hub's nav. Also pops up XP
-- gains and level ups. The numbers come from the player attributes the
-- server keeps (see PlayerStats).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PunchConfig = require(ReplicatedStorage:WaitForChild("PunchConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local allocateEvent = ReplicatedStorage:WaitForChild("AllocateStat")
local progressEvent = ReplicatedStorage:WaitForChild("Progress")

local player = Players.LocalPlayer

local AMOUNTS = { 1, 5, 10 } -- points added per click
local PANEL_SHARE = 0.6 -- of the tab's width; CURRENT has the rest
local PADDING = 14
local POPUP_OFFSET = 120 -- px right of centre for the +XP / +¥ popups, clear of the refusal text
local STAT_ROW_HEIGHT = 40
local BACKGROUND = Hub.Theme.Paper -- text on ink buttons
local TEXT = Hub.Theme.Ink
local MUTED = Hub.Theme.Muted
local BAR_BACK = Hub.Theme.BarBack
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 60) -- same as critical hit numbers: the popups
local NEXT = Color3.fromRGB(190, 130, 0) -- the milestone you're working towards: gold dark enough for the paper

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

local tabFrame = Hub.Tab("Stats", { order = 4, title = "STATS", key = Enum.KeyCode.M, pose = "Guard" })

-- the popups get a full-screen gui (no top inset), so their heights are fractions of the real screen
local popupGui = make("ScreenGui", {
	Name = "StatsPopups",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	Parent = player:WaitForChild("PlayerGui"),
})

local function formatYen(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "¥" .. grouped
end

local showTab -- defined below: switches between the STATS and MILESTONES panels

-- the two tab titles in a panel's header; the one for the panel shown is white
local function tabTitles(header, current)
	for i, name in ipairs({ "STATS", "MILESTONES" }) do
		local tab = make("TextButton", {
			Parent = header,
			Position = UDim2.fromOffset(i == 1 and 0 or 58, 0),
			Size = UDim2.fromOffset(i == 1 and 52 or 100, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = name,
			TextSize = 14,
			TextColor3 = name == current and TEXT or MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		tab.Activated:Connect(function()
			showTab(name)
		end)
	end
end

local panel = make("ScrollingFrame", {
	Name = "Panel",
	Parent = tabFrame,
	Size = UDim2.new(PANEL_SHARE, -16, 1, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Visible = false,
})
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

-- header: the two sub-tabs and the level
local header = section(1, 22)
header.Parent = panel
tabTitles(header, "STATS")
local levelLabel = label(header, {
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(70, 22),
})

-- XP bar
local xpSection = section(2, 24)
xpSection.Parent = panel
local xpTrack = make("Frame", {
	Parent = xpSection,
	Size = UDim2.new(1, 0, 0, 6),
	BackgroundColor3 = BAR_BACK,
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

-- what a stat gives now, in one line (the Milestones tab has the rest)
local describe = {
	Vitality = function(points)
		return string.format("%d max HP  ·  %s HP/s regen", StatConfig.MaxHealth(points), formatNumber(StatConfig.RegenPerSecond(points)))
	end,
	Strength = function(points)
		local fists = PunchConfig.Weapons.Fists.baseDamage * StatConfig.DamageMultiplier("Strength", points)
		return string.format("%s punch damage", formatNumber(fists))
	end,
	Superliminal = function(points)
		return string.format("%d%% skill damage", math.round(StatConfig.DamageMultiplier("Superliminal", points) * 100))
	end,
	Firearm = function(points)
		return string.format("%d%% gun damage", math.round(StatConfig.DamageMultiplier("Firearm", points) * 100))
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
	rows[i] = { stat = stat, value = value, effect = effect, plus = plus }
end

-- CURRENT: what the stats add up to, a caption over a big number each, right of the panel
local current = make("Frame", {
	Parent = tabFrame,
	Position = UDim2.new(PANEL_SHARE, 16, 0, 0),
	Size = UDim2.new(1 - PANEL_SHARE, -16, 1, 0),
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = current, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
label(current, { LayoutOrder = 0, Text = "CURRENT", Font = Enum.Font.GothamBold, TextSize = 14, Size = UDim2.new(1, 0, 0, 22) })
local currentValues = {}
for i, caption in ipairs({ "MAX HP", "HP REGEN / S", "MELEE DAMAGE", "SKILL DAMAGE", "GUN DAMAGE", "STAMINA BOXES", "DODGE CHARGES" }) do
	local holder = section(i, 44)
	holder.Parent = current
	label(holder, { Text = caption, TextSize = 10, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 12) })
	currentValues[i] = label(holder, { Font = Enum.Font.GothamBlack, TextSize = 24, Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 0, 28) })
end

local function showCurrent(level)
	local function points(key)
		return player:GetAttribute(key) or 0
	end
	local vitality = points("Vitality")
	local values = {
		tostring(StatConfig.MaxHealth(vitality)),
		formatNumber(StatConfig.RegenPerSecond(vitality)),
		formatNumber(PunchConfig.Weapons.Fists.baseDamage * StatConfig.DamageMultiplier("Strength", points("Strength"))),
		math.round(StatConfig.DamageMultiplier("Superliminal", points("Superliminal")) * 100) .. "%",
		math.round(StatConfig.DamageMultiplier("Firearm", points("Firearm")) * 100) .. "%",
		tostring((StatConfig.StaminaBoxes(level))),
		tostring((StatConfig.DodgeCharges(level))),
	}
	for i, text in ipairs(values) do
		currentValues[i].Text = text
	end
end

local function refresh()
	local level = player:GetAttribute("Level")
	local points = player:GetAttribute("StatPoints") or 0
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
		row.effect.Text = describe[row.stat.key](value)
		local cap = StatConfig.StatCap(row.stat.key)
		if value >= cap then
			row.effect.Text ..= "  ·  MAX"
		end
		local canAdd = points > 0 and value < cap
		row.plus.AutoButtonColor = canAdd
		row.plus.BackgroundTransparency = canAdd and 0 or 0.8
		row.plus.TextTransparency = canAdd and 0 or 0.5
	end
	showCurrent(level)
end
refresh()
player.AttributeChanged:Connect(refresh)

-- The MILESTONES tab: the milestones (level rewards, then each stat's)
-- as a stack of bars, one per milestone, that together read as one
-- progress track: reached ones full, the next one filling in gold with how
-- far along you are, later ones empty. It opens where the stats panel does,
-- so only one of the two is shown at a time.
local INFO_MAX_BODY_HEIGHT = 380 -- past this the list scrolls
local INFO_BAR_HEIGHT = 22
local INFO_AT_WIDTH = 70 -- the milestone column inside a bar
local INFO_COUNT_WIDTH = 48 -- the progress count on the right of a bar

local infoPanel = make("ScrollingFrame", {
	Name = "InfoPanel",
	Parent = tabFrame,
	Size = UDim2.new(PANEL_SHARE, -16, 1, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Visible = false,
})
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
tabTitles(infoHeader, "MILESTONES")

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
		local color = reached and TEXT or isNext and NEXT or MUTED
		local share = math.clamp((current - from) / math.max(entry.at - from, 1), 0, 1)
		from = entry.at

		local bar = infoLine(INFO_BAR_HEIGHT)
		bar.BackgroundColor3 = BAR_BACK
		bar.BackgroundTransparency = 0
		bar.BorderSizePixel = 0
		local stroke = outline(bar, isNext and 0.3 or 0.85)
		stroke.Color = isNext and NEXT or TEXT
		make("Frame", {
			Parent = bar,
			Size = UDim2.fromScale(share, 1),
			BackgroundColor3 = isNext and NEXT or TEXT,
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
			TextColor3 = NEXT,
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

-- kept current while it's open
player.AttributeChanged:Connect(function(name)
	if infoPanel.Visible and Hub.IsOpen("Stats") and (name == "Level" or StatConfig.Get(name) ~= nil) then
		buildInfo()
	end
end)

-- shows the STATS or MILESTONES panel
function showTab(name)
	if name == "MILESTONES" then
		buildInfo()
	end
	panel.Visible = name == "STATS"
	infoPanel.Visible = name == "MILESTONES"
end

-- the hub always opens it on STATS
Hub.OnShown("Stats", function()
	showTab("STATS")
end)

-- the XP bar in the accent; unspent points as a badge in the hub's nav
Hub.OnAccent(function(_, ink)
	xpFill.BackgroundColor3 = ink
end)
local function showBadge()
	local points = player:GetAttribute("StatPoints") or 0
	Hub.Badge("Stats", points > 0 and tostring(points) or nil)
end
player:GetAttributeChangedSignal("StatPoints"):Connect(showBadge)
showBadge()

-- a line of text that drifts up and fades, for XP and level ups
local function popup(text, color, size, height, lifetime, xOffset)
	local popupLabel = make("TextLabel", {
		Parent = popupGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, xOffset or 0, height, 0),
		Size = UDim2.fromOffset(400, size + 8),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		TextStrokeTransparency = 0.5,
	})
	TweenService:Create(popupLabel, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, xOffset or 0, height - 0.03, 0),
	}):Play()
	local fade = TweenInfo.new(lifetime / 2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, lifetime / 2)
	TweenService:Create(popupLabel, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(popupLabel, lifetime)
end

progressEvent.OnClientEvent:Connect(function(xpGained, levelsGained, yenGained)
	if xpGained > 0 then
		popup(string.format("+%d XP", xpGained), WHITE, 18, 0.62, 1.2, POPUP_OFFSET)
	end
	if yenGained and yenGained > 0 then
		popup("+" .. formatYen(yenGained), GOLD, 18, 0.66, 1.2, POPUP_OFFSET)
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
	end
end)
