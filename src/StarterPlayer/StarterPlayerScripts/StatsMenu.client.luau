-- The hub's Stats tab (M, or the hub's nav), with two sub-tabs. STATS: a radar of the four
-- stats beside the points to spend on them, the level and its XP bar, and what the stats add
-- up to (max HP, regen, damage, stamina boxes, dodge charges).
-- MILESTONES: reward bars, one per track (the level, then each stat with milestones), in
-- segments with a pin under each reward. Unspent points show as a badge in the hub's nav.
-- Also pops up XP gains and level ups. The numbers come from the player attributes the
-- server keeps (see PlayerStats).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PunchConfig = require(ReplicatedStorage:WaitForChild("PunchConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local allocateEvent = ReplicatedStorage:WaitForChild("AllocateStat")
local progressEvent = ReplicatedStorage:WaitForChild("Progress")

local player = Players.LocalPlayer

local AMOUNTS = { 1, 5, 10 } -- points added per click
local SUBTABS_HEIGHT = 36 -- the STATS / MILESTONES titles, with the gap under them
local PADDING = 14
local POPUP_OFFSET = 120 -- px right of centre for the +XP / +¥ popups, clear of the refusal text
local RADAR_WIDTH = 380
local RADAR_HEIGHT = 320
local RADAR_RADIUS = 104
local SPEND_ROW = 52
local MILESTONE_GAP = 6 -- between the segments of a reward bar
local BACKGROUND = Hub.Theme.Paper -- text on ink buttons
local TEXT = Hub.Theme.Ink
local MUTED = Hub.Theme.Muted
local BAR_BACK = Hub.Theme.BarBack
local CARD = Hub.Theme.Panel
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 60) -- same as critical hit numbers: the popups
local NEXT = Color3.fromRGB(255, 190, 40) -- the milestone you're working towards
local CYAN = Color3.fromRGB(60, 224, 230) -- stamina boxes
local PALE = Color3.fromRGB(200, 240, 242) -- dodge charges

local ink = Hub.InkAccent() -- the held power's colour on the dark, kept current by OnAccent below

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
	props.Font = props.Font or Enum.Font.Highway
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextTruncate = props.TextTruncate or Enum.TextTruncate.AtEnd
	return make("TextLabel", props)
end

local function frame(parent, props)
	props.Parent = parent
	props.BorderSizePixel = 0
	if props.BackgroundColor3 == nil then
		props.BackgroundTransparency = 1
	end
	return make("Frame", props)
end

local function formatNumber(n)
	return n % 1 == 0 and tostring(n) or string.format("%.1f", n)
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

-- the sub-tabs as plain titles, like the Quests tab's: the one showing in ink
local showTab -- defined below
local subTabs = {}
local subTabRow = make("Frame", { Parent = tabFrame, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
make("UIListLayout", { Parent = subTabRow, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder })
for order, name in ipairs({ "STATS", "MILESTONES" }) do
	subTabs[name] = make("TextButton", {
		Parent = subTabRow,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.Highway,
		Text = name,
		TextSize = 16,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	subTabs[name]:SetAttribute("SectionSelect", true)
	subTabs[name].Activated:Connect(function()
		showTab(name)
	end)
end

-- a scrolling page under the sub-tabs
local function page(name)
	local scroller = make("ScrollingFrame", {
		Name = name,
		Parent = tabFrame,
		Position = UDim2.fromOffset(0, SUBTABS_HEIGHT),
		Size = UDim2.new(1, 0, 1, -SUBTABS_HEIGHT),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = MUTED,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Visible = false,
	})
	make("UIPadding", { Parent = scroller, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, PADDING), PaddingRight = UDim.new(0, 12) })
	make("UIListLayout", { Parent = scroller, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14) })
	return scroller
end

local statsPage = page("StatsPage")
local rewardPage = page("RewardPage")

-- STATS ---------------------------------------------------------------------------------------

-- top: the radar on the left, the points to spend on the right
local topRow = frame(statsPage, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, RADAR_HEIGHT) })

local radarCard = frame(topRow, { Size = UDim2.fromOffset(RADAR_WIDTH, RADAR_HEIGHT), BackgroundColor3 = CARD })
local plot = frame(radarCard, { Size = UDim2.fromScale(1, 1) }) -- the radar's lines and labels, rebuilt when the stats change
local radarCentre = Vector2.new(RADAR_WIDTH / 2, RADAR_HEIGHT / 2)
local radarSignature

-- a straight line from a to b as a thin rotated frame
local function line(parent, a, b, thickness, color, zIndex)
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(length, thickness),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color,
		ZIndex = zIndex or 1,
	})
end

-- the four stats' tips sit at the top, right, bottom and left
local ANGLES = { -math.pi / 2, 0, math.pi / 2, math.pi }

local function drawRadar()
	local stats = StatConfig.Stats
	local values, top = {}, 10
	for i, stat in ipairs(stats) do
		values[i] = player:GetAttribute(stat.key) or 0
		top = math.max(top, math.ceil(values[i] / 10) * 10)
	end
	local signature = table.concat(values, ",") .. "|" .. top .. "|" .. tostring(ink)
	if signature == radarSignature then
		return
	end
	radarSignature = signature
	plot:ClearAllChildren()

	local function tip(index, share)
		local angle = ANGLES[index]
		return radarCentre + Vector2.new(math.cos(angle), math.sin(angle)) * RADAR_RADIUS * share
	end
	-- the rings at a quarter, half, three quarters and all of the scale, and the axes
	for ring = 1, 4 do
		for i = 1, #stats do
			line(plot, tip(i, ring / 4), tip(i % #stats + 1, ring / 4), 1, BAR_BACK, 1)
		end
	end
	for i = 1, #stats do
		line(plot, radarCentre, tip(i, 1), 1, BAR_BACK, 1)
	end
	-- the scale along the top axis
	for ring = 1, 4 do
		local at = tip(1, ring / 4)
		label(plot, {
			Text = tostring(top * ring / 4),
			TextSize = 11,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(at.X + 4, at.Y - 7),
			Size = UDim2.fromOffset(30, 12),
			ZIndex = 2,
		})
	end
	-- the shape: filled with lines from the centre to its edge, then outlined
	local points = {}
	for i = 1, #stats do
		points[i] = tip(i, math.clamp(values[i] / top, 0, 1))
	end
	local fill = Color3.new(ink.R * 0.45 + CARD.R * 0.55, ink.G * 0.45 + CARD.G * 0.55, ink.B * 0.45 + CARD.B * 0.55)
	for i = 1, #points do
		local from, to = points[i], points[i % #points + 1]
		local steps = math.max(1, math.ceil((to - from).Magnitude / 2))
		for step = 0, steps do
			line(plot, radarCentre, from:Lerp(to, step / steps), 3, fill, 3)
		end
	end
	for i = 1, #points do
		line(plot, points[i], points[i % #points + 1], 2, ink, 4)
		frame(plot, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(points[i].X, points[i].Y),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = ink,
			ZIndex = 5,
		})
	end
	-- each stat's name and points at its tip
	for i, stat in ipairs(stats) do
		local at = tip(i, 1)
		local x, y, align, anchor = at.X, at.Y, Enum.TextXAlignment.Center, Vector2.new(0.5, 0.5)
		if i == 1 then
			y -= 28
		elseif i == 3 then
			y += 28
		elseif i == 2 then
			x += 12
			align, anchor = Enum.TextXAlignment.Left, Vector2.new(0, 0.5)
		else
			x -= 12
			align, anchor = Enum.TextXAlignment.Right, Vector2.new(1, 0.5)
		end
		local holder = frame(plot, { AnchorPoint = anchor, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(92, 38), ZIndex = 6 })
		label(holder, { Text = string.upper(stat.key), TextSize = 12, TextColor3 = MUTED, TextXAlignment = align, Size = UDim2.new(1, 0, 0, 14) })
		label(holder, { Text = tostring(values[i]), TextSize = 20, TextXAlignment = align, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 24) })
	end
end

-- the points to spend: how many, how many each click adds, then a row per stat with its +
local spendCard = frame(topRow, {
	Position = UDim2.fromOffset(RADAR_WIDTH + 14, 0),
	Size = UDim2.new(1, -(RADAR_WIDTH + 14), 1, 0),
	BackgroundColor3 = CARD,
})
make("UIPadding", { Parent = spendCard, PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) })
local pointsRow = frame(spendCard, { Size = UDim2.new(1, 0, 0, 54) })
label(pointsRow, { Text = "POINTS TO SPEND", TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, -130, 0, 14) })
local pointsLabel = label(pointsRow, { TextSize = 34, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, -130, 0, 38) })
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
		Parent = pointsRow,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(#AMOUNTS - i) * 44, 0.5, 0),
		Size = UDim2.fromOffset(40, 28),
		BackgroundColor3 = TEXT,
		Font = Enum.Font.Highway,
		Text = "x" .. value,
		TextSize = 14,
	})
	outline(chip, 0.5)
	chip.Activated:Connect(function()
		amount = value
		showChips()
	end)
	chips[value] = chip
end
showChips()

local rowsHolder = frame(spendCard, { Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 1, -64) })
make("UIListLayout", { Parent = rowsHolder, SortOrder = Enum.SortOrder.LayoutOrder })

-- what a point in each stat gives, in words
local function perPoint(stat)
	if stat.key == "Vitality" then
		return string.format("+%d max HP per point", StatConfig.HealthPerVitality)
	end
	local kinds = { Strength = "melee", Superliminal = "skill", Firearm = "gun" }
	return string.format("+%s%% %s damage per point", formatNumber(stat.damageBonus * 100), kinds[stat.key] or "")
end

local rows = {}
for i, stat in ipairs(StatConfig.Stats) do
	local rowFrame = frame(rowsHolder, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, SPEND_ROW) })
	if i > 1 then
		frame(rowFrame, { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = BAR_BACK })
	end
	label(rowFrame, { Text = stat.key, TextSize = 18, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, -110, 0, 22) })
	local effect = label(rowFrame, {
		Text = perPoint(stat),
		TextSize = 13,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, -110, 0, 16),
	})
	local value = label(rowFrame, {
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.fromOffset(60, 26),
	})
	local plus = make("TextButton", {
		Parent = rowFrame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = TEXT,
		BorderSizePixel = 0,
		Font = Enum.Font.Highway,
		Text = "+",
		TextSize = 24,
		TextColor3 = BACKGROUND,
	})
	plus.Activated:Connect(function()
		local maxed = (player:GetAttribute(stat.key) or 0) >= StatConfig.StatCap(stat.key)
		if (player:GetAttribute("StatPoints") or 0) > 0 and not maxed then
			UiSfx.Play("statUp")
		else
			UiSfx.Play("denied")
		end
		allocateEvent:FireServer(stat.key, amount)
	end)
	rows[i] = { stat = stat, value = value, effect = effect, plus = plus }
end

-- side by side on a wide tab; on a narrow one the points to spend go under the radar
local STACK_BELOW = 700 -- tab width (UI pixels)
local SPEND_HEIGHT = 300
local function layoutTop()
	local wide = topRow.AbsoluteSize.X / UIScale.Get() >= STACK_BELOW or topRow.AbsoluteSize.X == 0
	if wide then
		topRow.Size = UDim2.new(1, 0, 0, RADAR_HEIGHT)
		spendCard.Position = UDim2.fromOffset(RADAR_WIDTH + 14, 0)
		spendCard.Size = UDim2.new(1, -(RADAR_WIDTH + 14), 1, 0)
	else
		topRow.Size = UDim2.new(1, 0, 0, RADAR_HEIGHT + 14 + SPEND_HEIGHT)
		spendCard.Position = UDim2.fromOffset(0, RADAR_HEIGHT + 14)
		spendCard.Size = UDim2.new(1, 0, 0, SPEND_HEIGHT)
	end
end
layoutTop()
topRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTop)
UIScale.OnChange(layoutTop)

-- the level and its XP bar across the page
local levelBlock = frame(statsPage, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 78) })
local levelLabel = label(levelBlock, { TextSize = 28, Size = UDim2.new(0.5, 0, 0, 32) })
local xpLabel = label(levelBlock, {
	TextSize = 15,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.5, 0, 0, 32),
})
local xpTrack = frame(levelBlock, { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = BAR_BACK })
local xpFill = frame(xpTrack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ink })
-- stamina boxes and dodge charges come with levels rather than a stat
local boxesLabel = label(levelBlock, {
	TextSize = 14,
	TextColor3 = MUTED,
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, 0, 0, 18),
})

-- what the stats add up to: big numbers, then the stamina boxes and dodge charges
local totalsCard = frame(statsPage, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 206), BackgroundColor3 = CARD })
make("UIPadding", { Parent = totalsCard, PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) })
local CURRENT = { "MAX HP", "MELEE", "SKILL DMG", "GUN DMG" }
local currentValues = {}
local regenLabel
local tiles = frame(totalsCard, { Size = UDim2.new(1, 0, 0, 76) })
make("UIGridLayout", { Parent = tiles, CellSize = UDim2.new(0.25, 0, 0, 76), CellPadding = UDim2.fromOffset(0, 0), SortOrder = Enum.SortOrder.LayoutOrder })
for i, caption in ipairs(CURRENT) do
	local tile = frame(tiles, { LayoutOrder = i })
	label(tile, { Text = caption, TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, -8, 0, 14) })
	currentValues[i] = label(tile, { TextSize = i == 1 and 44 or 34, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, -8, 0, 46) })
	if i == 1 then
		regenLabel = label(tile, { TextSize = 13, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, -8, 0, 16) })
	end
end

local function unitsRow(order, caption, y)
	label(totalsCard, { Text = caption, TextSize = 13, TextColor3 = MUTED, Position = UDim2.fromOffset(0, y + 7), Size = UDim2.fromOffset(90, 16) })
	return frame(totalsCard, { Position = UDim2.fromOffset(100, y), Size = UDim2.new(1, -100, 0, 30) })
end
local staminaRow = unitsRow(1, "STAMINA", 90)
local dodgeRow = unitsRow(2, "DODGES", 134)
local STAMINA_TOTAL = StatConfig.StaminaBoxLevels[#StatConfig.StaminaBoxLevels].boxes
local DODGE_TOTAL = StatConfig.DodgeChargeLevels[#StatConfig.DodgeChargeLevels].charges
local staminaBoxes, dodgeDiamonds = {}, {}
for i = 1, STAMINA_TOTAL do
	staminaBoxes[i] = frame(staminaRow, { Position = UDim2.fromOffset((i - 1) * 32, 3), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = BAR_BACK })
end
for i = 1, DODGE_TOTAL do
	dodgeDiamonds[i] = frame(dodgeRow, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(14 + (i - 1) * 36, 15),
		Size = UDim2.fromOffset(19, 19),
		Rotation = 45,
		BackgroundColor3 = BAR_BACK,
	})
end

local function showCurrent(level)
	local function points(key)
		return player:GetAttribute(key) or 0
	end
	local vitality = points("Vitality")
	local values = {
		tostring(StatConfig.MaxHealth(vitality)),
		formatNumber(PunchConfig.Weapons.Fists.baseDamage * StatConfig.DamageMultiplier("Strength", points("Strength"))),
		math.round(StatConfig.DamageMultiplier("Superliminal", points("Superliminal")) * 100) .. "%",
		math.round(StatConfig.DamageMultiplier("Firearm", points("Firearm")) * 100) .. "%",
	}
	for i, text in ipairs(values) do
		currentValues[i].Text = text
	end
	regenLabel.Text = "REGEN " .. formatNumber(StatConfig.RegenPerSecond(vitality)) .. " HP/S"
	local boxes = StatConfig.StaminaBoxes(level)
	for i, box in ipairs(staminaBoxes) do
		box.BackgroundColor3 = i <= boxes and CYAN or BAR_BACK
	end
	local charges = StatConfig.DodgeCharges(level)
	for i, diamond in ipairs(dodgeDiamonds) do
		diamond.BackgroundColor3 = i <= charges and PALE or BAR_BACK
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

	levelLabel.Text = "LEVEL " .. level
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
	pointsLabel.Text = tostring(points)

	for _, row in ipairs(rows) do
		local value = player:GetAttribute(row.stat.key) or 0
		row.value.Text = tostring(value)
		local cap = StatConfig.StatCap(row.stat.key)
		row.effect.Text = value >= cap and "MAX" or perPoint(row.stat)
		local canAdd = points > 0 and value < cap
		row.plus.BackgroundTransparency = canAdd and 0 or 0.8
		row.plus.TextTransparency = canAdd and 0 or 0.5
	end
	showCurrent(level)
	drawRadar()
end
refresh()
player.AttributeChanged:Connect(refresh)

-- MILESTONES ----------------------------------------------------------------------------------
-- A reward bar per track: the level (stamina boxes and dodge charges), then each stat that has
-- milestones. The bar is split into one segment per reward, each filling as you get from the
-- reward before it to its own, with a pin under the segment's end showing what it gives: reached
-- ones lit, the next one outlined in gold, later ones dark.

local infoOrder = 0

-- one reward bar: `entries` are { at, label, reward, glyph }, `current` how far along you are
local function rewardTrack(title, currentText, current, entries)
	table.sort(entries, function(a, b)
		return a.at < b.at
	end)
	infoOrder += 1
	local card = frame(rewardPage, { LayoutOrder = infoOrder, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CARD })
	make("UIPadding", { Parent = card, PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) })
	make("UIListLayout", { Parent = card, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) })

	-- the title, how far along, and what comes next
	local nextEntry
	for _, entry in ipairs(entries) do
		if current < entry.at then
			nextEntry = entry
			break
		end
	end
	local header = frame(card, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 44) })
	label(header, { Text = title, TextSize = 22, Size = UDim2.new(0.5, 0, 0, 26) })
	label(header, { Text = currentText, TextSize = 14, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(0.5, 0, 0, 18) })
	label(header, {
		Text = nextEntry and string.format("NEXT   %s  ·  %s", nextEntry.label, nextEntry.reward) or "ALL UNLOCKED",
		TextSize = 15,
		TextColor3 = nextEntry and NEXT or MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, 0, 0, 26),
	})

	local count = #entries
	local segmentSize = UDim2.new(1 / count, -MILESTONE_GAP * (count - 1) / count, 0, 0)
	local bar = frame(card, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14) })
	make("UIListLayout", { Parent = bar, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, MILESTONE_GAP), SortOrder = Enum.SortOrder.LayoutOrder })
	local pins = frame(card, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	make("UIListLayout", { Parent = pins, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, MILESTONE_GAP), SortOrder = Enum.SortOrder.LayoutOrder })

	local from = 0
	for index, entry in ipairs(entries) do
		local reached = current >= entry.at
		local isNext = entry == nextEntry
		local share = math.clamp((current - from) / math.max(entry.at - from, 1), 0, 1)
		from = entry.at
		local color = reached and ink or isNext and NEXT or MUTED

		local segment = frame(bar, { LayoutOrder = index, Size = UDim2.new(segmentSize.X.Scale, segmentSize.X.Offset, 1, 0), BackgroundColor3 = BAR_BACK })
		frame(segment, { Size = UDim2.fromScale(share, 1), BackgroundColor3 = isNext and NEXT or ink })

		-- the pin under the segment's end: a square with the reward's letter, then its words
		local pin = frame(pins, { LayoutOrder = index, Size = UDim2.new(segmentSize.X.Scale, segmentSize.X.Offset, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		make("UIListLayout", { Parent = pin, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6) })
		local marker = frame(pin, {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = reached and ink or BAR_BACK,
		})
		if isNext then
			outline(marker, 0).Color = NEXT
		end
		label(marker, {
			Text = entry.glyph,
			TextSize = 18,
			TextColor3 = reached and BACKGROUND or color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
		label(pin, {
			LayoutOrder = 2,
			Text = entry.label,
			TextSize = 15,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 0, 18),
		})
		label(pin, {
			LayoutOrder = 3,
			Text = entry.reward,
			TextSize = 13,
			TextColor3 = reached and TEXT or MUTED,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		})
	end
end

-- a level table's unlocks after the starting one, each as what it adds to the one before
local function levelUnlocks(unlocks, field, singular, plural, glyph, entries)
	local previous
	for _, unlock in ipairs(unlocks) do
		if previous then
			local gained = unlock[field] - previous
			table.insert(entries, {
				at = unlock.level,
				label = "Lv " .. unlock.level,
				reward = string.format("+%d %s", gained, gained == 1 and singular or plural),
				glyph = glyph,
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
	for _, child in ipairs(rewardPage:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	infoOrder = 0

	local level = player:GetAttribute("Level") or 0
	local levelEntries = {}
	levelUnlocks(StatConfig.StaminaBoxLevels, "boxes", "stamina box", "stamina boxes", "S", levelEntries)
	levelUnlocks(StatConfig.DodgeChargeLevels, "charges", "dodge charge", "dodge charges", "D", levelEntries)
	rewardTrack("LEVEL", "Level " .. level, level, levelEntries)

	for _, stat in ipairs(StatConfig.Stats) do
		local entries = {}
		for _, milestone in ipairs(stat.milestones) do
			if milestone.at > 0 then
				table.insert(entries, { at = milestone.at, label = milestone.at .. " points", reward = milestoneReward(milestone), glyph = milestone.regen and "R" or "+" })
			end
		end
		if #entries > 0 then
			local value = player:GetAttribute(stat.key) or 0
			rewardTrack(string.upper(stat.key), value .. (value == 1 and " point" or " points"), value, entries)
		end
	end
end

-- kept current while it's open
player.AttributeChanged:Connect(function(name)
	if rewardPage.Visible and Hub.IsOpen("Stats") and (name == "Level" or StatConfig.Get(name) ~= nil) then
		buildInfo()
	end
end)

-- shows the STATS or MILESTONES sub-tab
function showTab(name)
	if name == "MILESTONES" then
		buildInfo()
	end
	for tabName, button in pairs(subTabs) do
		button.TextColor3 = tabName == name and TEXT or MUTED
	end
	statsPage.Visible = name == "STATS"
	rewardPage.Visible = name == "MILESTONES"
end

-- the hub always opens it on STATS
Hub.OnShown("Stats", function()
	showTab("STATS")
end)

-- the held power's colour: the XP bar, the radar and the reward bars; unspent points as a badge in the hub's nav
Hub.OnAccent(function(_, accentInk)
	ink = accentInk
	xpFill.BackgroundColor3 = ink
	drawRadar()
	if rewardPage.Visible then
		buildInfo()
	end
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
		Font = Enum.Font.Highway,
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
