-- The hub's Stats tab (from the hub's nav), with three sub-tabs. STATS: the level big with its XP bar, the build (a radar
-- of the six stats beside what they add up to: max HP, regen, damage, stamina boxes, dodge charges), and under them the
-- points to spend, a row per stat with its points as a bar up to the cap.
-- MILESTONES: reward bars, one per track (the level, then each stat with milestones), in
-- segments with a pin under each reward. TALENTS: the perks each stat opens at 15, 30 and 50 points,
-- equipped with talent points (BuildRules, Talents). Unspent points show as a badge in the hub's nav.
-- The numbers come from the player attributes the server keeps (see PlayerStats); XP,
-- yen and level ups show in the pickup feed (PickupFeed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildRules = require(ReplicatedStorage:WaitForChild("BuildRules"))
local PunchConfig = require(ReplicatedStorage:WaitForChild("PunchConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local TalentConfig = require(ReplicatedStorage:WaitForChild("TalentConfig"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local allocateEvent = ReplicatedStorage:WaitForChild("AllocateStat")

local player = Players.LocalPlayer

local AMOUNTS = { 1, 5, 10 } -- points added per click
local SUBTABS_HEIGHT = 36 -- the STATS / MILESTONES titles, with the gap under them
local PADDING = 14
local POSE_ROOM = 150 -- px kept clear on the right, where the posed character reaches over the page
local SPEND_ROW = 58
local LEVEL_WIDTH = 104 -- the level's big number, left of its XP bar
local RADAR = 190 -- the build radar's square
local RADAR_REACH = 64 -- px from its middle to a spoke's end
local RADAR_FLOOR = 10 -- the radar's edge stands for the highest stat's points, never fewer than this
local FILL_STEP = 3 -- px between the scan lines filling the build's shape
local TILE_HEIGHT = 70 -- a total's tile, right of the radar
local MILESTONE_GAP = 6 -- between the segments of a reward bar
local BACKGROUND = Hub.Theme.Paper -- text on ink buttons
local TEXT = Hub.Theme.Ink
local MUTED = Hub.Theme.Muted
local BAR_BACK = Hub.Theme.BarBack
local NEXT = Color3.fromRGB(255, 190, 40) -- the milestone you're working towards
local CYAN = Color3.fromRGB(55, 138, 221) -- stamina boxes, as in the HUD
local PALE = Color3.new(1, 1, 1) -- dodge charges, as in the HUD
local TITLE_FONT = Hub.Theme.TitleFont -- big numbers and the stats' names on the STATS page
local MONO_FONT = Hub.Theme.MonoFont -- its captions

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

local tabFrame = Hub.Tab("Stats", { order = 4, title = "STATS", pose = "Guard" })

-- the sub-tabs as plain titles, like the Quests tab's: the one showing in ink
local showTab -- defined below
local subTabs = {}
local subTabRow = make("Frame", { Parent = tabFrame, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
make("UIListLayout", { Parent = subTabRow, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder })
for order, name in ipairs({ "STATS", "MILESTONES", "TALENTS" }) do
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

-- a page under the sub-tabs: no scrolling, its content shrinks to fit the room there is
-- (never below MIN_FIT). Returns the holder (show and hide it), the content (build in it) and the shrink.
local MIN_FIT = 0.55
local function page(name)
	local holder = make("Frame", {
		Name = name,
		Parent = tabFrame,
		Position = UDim2.fromOffset(0, SUBTABS_HEIGHT),
		Size = UDim2.new(1, -POSE_ROOM, 1, -SUBTABS_HEIGHT),
		BackgroundTransparency = 1,
		Visible = false,
	})
	local content = make("Frame", {
		Parent = holder,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	local shrink = make("UIScale", { Parent = content })
	local layout = make("UIListLayout", { Parent = content, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14) })
	local function fit()
		local factor = UIScale.Get() * shrink.Scale
		local contentHeight = layout.AbsoluteContentSize.Y / factor
		local room = holder.AbsoluteSize.Y / UIScale.Get() - 6 - PADDING
		if contentHeight <= 0 or room <= 0 then
			return
		end
		local fitted = math.clamp(room / contentHeight, MIN_FIT, 1)
		if math.abs(fitted - shrink.Scale) > 0.005 then
			shrink.Scale = fitted
			content.Size = UDim2.new(1 / fitted, 0, 0, 0)
		end
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	UIScale.OnChange(fit)
	return holder, content, shrink
end

local statsHolder, statsPage = page("StatsPage")
local rewardHolder, rewardPage = page("RewardPage")
local talentsHolder, talentsPage = page("TalentsPage")

-- STATS ---------------------------------------------------------------------------------------

-- a line from `a` to `b` (Vector2s in its parent's pixels): a thin frame turned to run between them
local function placeLine(bar, a, b)
	local delta = b - a
	bar.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	bar.Size = UDim2.fromOffset(delta.Magnitude, bar.Size.Y.Offset)
	bar.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end
local function line(parent, thickness, color, transparency, zIndex)
	return frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, thickness),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		ZIndex = zIndex,
	})
end

-- the level: its number big, the XP bar (in tenths) with the XP over it and the next level reward under it
local levelBlock = frame(statsPage, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 72) })
label(levelBlock, { Text = "LEVEL", Font = MONO_FONT, TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromOffset(LEVEL_WIDTH, 14) })
local levelLabel = label(levelBlock, { Font = TITLE_FONT, TextSize = 56, Position = UDim2.fromOffset(-2, 12), Size = UDim2.fromOffset(LEVEL_WIDTH - 6, 60) })
local xpLabel = label(levelBlock, {
	Font = MONO_FONT,
	TextSize = 12,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.fromOffset(LEVEL_WIDTH, 14),
	Size = UDim2.new(1, -LEVEL_WIDTH, 0, 14),
})
local xpTrack = frame(levelBlock, { Position = UDim2.fromOffset(LEVEL_WIDTH, 34), Size = UDim2.new(1, -LEVEL_WIDTH, 0, 10), BackgroundColor3 = BAR_BACK })
local xpFill = frame(xpTrack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ink })
for tenth = 1, 9 do
	frame(xpTrack, { Position = UDim2.fromScale(tenth / 10, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = BACKGROUND, ZIndex = 2 })
end
-- stamina boxes and dodge charges come with levels rather than a stat
local boxesLabel = label(levelBlock, { TextSize = 13, TextColor3 = MUTED, Position = UDim2.fromOffset(LEVEL_WIDTH, 50), Size = UDim2.new(1, -LEVEL_WIDTH, 0, 16) })

-- the build: a radar of the six stats on the left, what they add up to on the right
local buildCard = frame(statsPage, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, RADAR + 16) })
frame(buildCard, { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = BAR_BACK })

-- the radar: three rings and a spoke per stat, faint, with the stat's short name and points past the
-- spoke's end; over them the build's shape in the accent (scan lines inside, an edge between each pair
-- of neighbouring stats, a square at each one's points). Its edge stands for the highest stat's points
-- (RADAR_FLOOR at least), so the shape shows how the points are spread
local radar = frame(buildCard, { Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(RADAR, RADAR) })
label(radar, { Text = "BUILD", Font = MONO_FONT, TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromOffset(60, 14) })
local middle = Vector2.new(RADAR / 2, RADAR / 2)
local STAT_COUNT = #StatConfig.Stats
-- the way stat `i`'s spoke points: the first straight up, the rest going round clockwise
local function spoke(i)
	local angle = math.rad(-90 + (i - 1) * 360 / STAT_COUNT)
	return Vector2.new(math.cos(angle), math.sin(angle))
end
for ring = 1, 3 do
	local reach = RADAR_REACH * ring / 3
	for i = 1, STAT_COUNT do
		placeLine(line(radar, 1, TEXT, 0.85), middle + spoke(i) * reach, middle + spoke(i % STAT_COUNT + 1) * reach)
	end
end
local radarValues = {}
for i, stat in ipairs(StatConfig.Stats) do
	placeLine(line(radar, 1, TEXT, 0.88), middle, middle + spoke(i) * RADAR_REACH)
	local tip = middle + spoke(i) * (RADAR_REACH + 20)
	local tag = frame(radar, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(tip.X, tip.Y), Size = UDim2.fromOffset(44, 30) })
	label(tag, { Text = string.upper(string.sub(stat.key, 1, 3)), Font = MONO_FONT, TextSize = 10, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 12) })
	radarValues[i] = label(tag, { Font = TITLE_FONT, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 18) })
end
local shapeLines = {} -- the scan lines filling the shape, made as they're needed
local shapeEdges, shapeDots = {}, {}
for i = 1, STAT_COUNT do
	shapeEdges[i] = line(radar, 2, ink, 0, 3)
	shapeDots[i] = frame(radar, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = ink, ZIndex = 4 })
end
local drawnBuild -- the points the shape was drawn for, so a refresh that changes none of them leaves it be
local function showRadar()
	local values, highest = {}, RADAR_FLOOR
	for i, stat in ipairs(StatConfig.Stats) do
		values[i] = player:GetAttribute(stat.key) or 0
		highest = math.max(highest, values[i])
	end
	local build = table.concat(values, ",")
	if build == drawnBuild then
		return
	end
	drawnBuild = build
	local corners = {}
	for i, points in ipairs(values) do
		radarValues[i].Text = tostring(points)
		corners[i] = middle + spoke(i) * RADAR_REACH * math.max(points / highest, 0.06)
		shapeDots[i].Position = UDim2.fromOffset(corners[i].X, corners[i].Y)
	end
	for i, edge in ipairs(shapeEdges) do
		placeLine(edge, corners[i], corners[i % STAT_COUNT + 1])
	end
	-- scan lines across the shape: where each crosses the edges, filled between pairs of crossings
	local used = 0
	for y = middle.Y - RADAR_REACH, middle.Y + RADAR_REACH, FILL_STEP do
		local crossings = {}
		for i, a in ipairs(corners) do
			local b = corners[i % STAT_COUNT + 1]
			if (a.Y <= y) ~= (b.Y <= y) then
				table.insert(crossings, a.X + (y - a.Y) / (b.Y - a.Y) * (b.X - a.X))
			end
		end
		table.sort(crossings)
		for k = 1, #crossings - 1, 2 do
			used += 1
			local scan = shapeLines[used]
			if not scan then
				scan = frame(radar, { BackgroundColor3 = ink, BackgroundTransparency = 0.45, ZIndex = 2 })
				shapeLines[used] = scan
			end
			scan.Visible = true
			scan.Position = UDim2.fromOffset(crossings[k], y)
			scan.Size = UDim2.fromOffset(crossings[k + 1] - crossings[k], 1)
		end
	end
	for i = used + 1, #shapeLines do
		shapeLines[i].Visible = false
	end
end

-- what the stats add up to, right of the radar: four tiles, then the stamina boxes and dodge charges
local totals = frame(buildCard, { Position = UDim2.fromOffset(RADAR + 24, 12), Size = UDim2.new(1, -(RADAR + 24), 0, RADAR) })
local CURRENT = { "MAX HP", "MELEE", "SKILL DMG", "GUN DMG" }
local currentValues = {}
local regenLabel
local tiles = frame(totals, { Size = UDim2.new(1, 0, 0, 2 * TILE_HEIGHT) })
make("UIGridLayout", { Parent = tiles, CellSize = UDim2.new(0.5, -8, 0, TILE_HEIGHT), CellPadding = UDim2.fromOffset(16, 0), SortOrder = Enum.SortOrder.LayoutOrder })
for i, caption in ipairs(CURRENT) do
	local tile = frame(tiles, { LayoutOrder = i })
	label(tile, { Text = caption, Font = MONO_FONT, TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 14) })
	currentValues[i] = label(tile, { Font = TITLE_FONT, TextSize = 36, Position = UDim2.fromOffset(-1, 12), Size = UDim2.new(1, 0, 0, 38) })
	if i == 1 then
		regenLabel = label(tile, { Font = MONO_FONT, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 14) })
	end
end

local function unitsRow(caption, y)
	label(totals, { Text = caption, Font = MONO_FONT, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(0, y + 6), Size = UDim2.fromOffset(70, 14) })
	return frame(totals, { Position = UDim2.fromOffset(76, y), Size = UDim2.new(1, -76, 0, 26) })
end
local staminaRow = unitsRow("STAMINA", 2 * TILE_HEIGHT + 2)
local dodgeRow = unitsRow("CHARGE", 2 * TILE_HEIGHT + 28)
local STAMINA_TOTAL = StatConfig.StaminaBoxLevels[#StatConfig.StaminaBoxLevels].boxes
local DODGE_TOTAL = StatConfig.DodgeChargeLevels[#StatConfig.DodgeChargeLevels].charges
local staminaBoxes, dodgeDiamonds = {}, {}
for i = 1, STAMINA_TOTAL do
	staminaBoxes[i] = frame(staminaRow, { Position = UDim2.fromOffset((i - 1) * 26, 3), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = BAR_BACK })
end
for i = 1, DODGE_TOTAL do
	dodgeDiamonds[i] = frame(dodgeRow, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(10 + (i - 1) * 30, 13),
		Size = UDim2.fromOffset(15, 15),
		Rotation = 45,
		BackgroundColor3 = BAR_BACK,
	})
end

-- the points to spend, at the bottom: how many, how many each click adds, then a row per stat with its
-- points (a bar of them up to the cap along its foot) and its +
local spendCard = frame(statsPage, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 72 + 3 * SPEND_ROW) })
frame(spendCard, { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = BAR_BACK })
local pointsRow = frame(spendCard, { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 54) })
label(pointsRow, { Text = "POINTS TO SPEND", Font = MONO_FONT, TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, -130, 0, 14) })
local pointsLabel = label(pointsRow, { Font = TITLE_FONT, TextSize = 38, Position = UDim2.fromOffset(-1, 14), Size = UDim2.new(1, -130, 0, 40) })
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

local rowsHolder = frame(spendCard, { Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72) })
make("UIGridLayout", {
	Parent = rowsHolder,
	CellSize = UDim2.new(0.5, -12, 0, SPEND_ROW),
	CellPadding = UDim2.fromOffset(24, 0),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

-- what a point in each stat gives, in words
local function perPoint(stat)
	if stat.key == "Vitality" then
		return string.format("+%d max HP per point", StatConfig.HealthPerVitality)
	end
	if stat.key == "Agility" then
		return string.format("+%d max stamina per point", StatConfig.AgilityStamina(1))
	elseif stat.key == "Willpower" then
		return "-1% posture taken and status time per point"
	end
	local kinds = { Strength = "melee", Superliminal = "skill", Firearm = "gun" }
	return string.format("+%s%% %s damage per point", formatNumber(stat.damageBonus * 100), kinds[stat.key] or "")
end

local rows = {}
for i, stat in ipairs(StatConfig.Stats) do
	local rowFrame = frame(rowsHolder, { LayoutOrder = i })
	label(rowFrame, { Text = string.upper(stat.key), Font = TITLE_FONT, TextSize = 19, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, -110, 0, 22) })
	local effect = label(rowFrame, {
		Text = perPoint(stat),
		TextSize = 13,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(0, 29),
		Size = UDim2.new(1, -110, 0, 16),
	})
	local value = label(rowFrame, {
		Font = TITLE_FONT,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, -4),
		Size = UDim2.fromOffset(60, 30),
	})
	-- its points as a bar up to the cap, along the row's foot
	local track = frame(rowFrame, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -4), Size = UDim2.new(1, -46, 0, 3), BackgroundColor3 = BAR_BACK })
	local fill = frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ink })
	local plus = make("TextButton", {
		Parent = rowFrame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, -4),
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
	rows[i] = { stat = stat, value = value, effect = effect, plus = plus, fill = fill }
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

	levelLabel.Text = tostring(level)
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
		row.fill.Size = UDim2.fromScale(math.clamp(value / cap, 0, 1), 1)
		local canAdd = points > 0 and value < cap
		row.plus.BackgroundTransparency = canAdd and 0 or 0.8
		row.plus.TextTransparency = canAdd and 0 or 0.5
	end
	showCurrent(level)
	showRadar()
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
	local card = frame(rewardPage, { LayoutOrder = infoOrder, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	make("UIPadding", { Parent = card, PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	make("UIListLayout", { Parent = card, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) })
	frame(card, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = BAR_BACK })

	-- the title and how far along on the left; how many rewards are reached and what comes next on the right
	local nextEntry
	local reachedCount = 0
	for _, entry in ipairs(entries) do
		if current >= entry.at then
			reachedCount += 1
		elseif not nextEntry then
			nextEntry = entry
		end
	end
	local header = frame(card, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 44) })
	label(header, { Text = title, Font = TITLE_FONT, TextSize = 24, Size = UDim2.new(0.5, 0, 0, 28) })
	label(header, { Text = string.upper(currentText), Font = MONO_FONT, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 29), Size = UDim2.new(0.5, 0, 0, 14) })
	label(header, {
		Text = string.format("%d / %d UNLOCKED", reachedCount, #entries),
		Font = MONO_FONT,
		TextSize = 11,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, 0, 0, 14),
	})
	label(header, {
		Text = nextEntry and string.format("NEXT   %s  ·  %s", nextEntry.label, nextEntry.reward) or "ALL UNLOCKED",
		TextSize = 15,
		TextColor3 = nextEntry and NEXT or MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 18),
		Size = UDim2.new(0.5, 0, 0, 22),
	})

	local count = #entries
	local segmentSize = UDim2.new(1 / count, -MILESTONE_GAP * (count - 1) / count, 0, 0)
	local bar = frame(card, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 10) })
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
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = reached and ink or BAR_BACK,
		})
		if isNext then
			local edge = outline(marker, 0)
			edge.Color = NEXT
			edge.Thickness = 2
		end
		label(marker, {
			Text = entry.glyph,
			Font = TITLE_FONT,
			TextSize = 18,
			TextColor3 = reached and BACKGROUND or color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
		label(pin, {
			LayoutOrder = 2,
			Text = string.upper(entry.label),
			Font = MONO_FONT,
			TextSize = 12,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, 0, 0, 16),
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

-- TALENTS -------------------------------------------------------------------------------------

local TALENT_ROW = 68
local TALENT_NAME_WIDTH = 120

-- a row per stat: its three talents, one for each tier. Click to equip or take off.
local function buildTalents()
	for _, child in ipairs(talentsPage:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local level = player:GetAttribute("Level") or 0
	local equipped = BuildRules.Equipped(player)
	local total = BuildRules.TalentPoints(level)
	local free = total - BuildRules.Spent(equipped)

	local header = frame(talentsPage, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 56) })
	label(header, { Text = "TALENT POINTS", Font = MONO_FONT, TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 14) })
	label(header, { Text = string.format("%d / %d", free, total), Font = TITLE_FONT, TextSize = 38, Position = UDim2.fromOffset(-1, 14), Size = UDim2.fromOffset(160, 42) })
	label(header, {
		Text = string.format("1 point per %d levels  ·  tiers open at %s points in the stat", TalentConfig.LevelsPerPoint, table.concat(TalentConfig.Tiers, " / ")),
		TextSize = 13,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(170, 32),
		Size = UDim2.new(1, -170, 0, 18),
	})

	local lastTier = TalentConfig.Tiers[#TalentConfig.Tiers]
	for order, stat in ipairs(StatConfig.Stats) do
		local points = player:GetAttribute(stat.key) or 0
		local row = frame(talentsPage, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, TALENT_ROW) })
		frame(row, { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = BAR_BACK })
		label(row, { Text = string.upper(stat.key), Font = TITLE_FONT, TextSize = 19, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(TALENT_NAME_WIDTH, 22) })
		label(row, { Text = points .. " PTS", Font = MONO_FONT, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 31), Size = UDim2.fromOffset(TALENT_NAME_WIDTH, 14) })
		-- the stat's points as a bar up to the last tier, notched at the tiers before it
		local track = frame(row, { Position = UDim2.fromOffset(0, 52), Size = UDim2.fromOffset(TALENT_NAME_WIDTH - 16, 3), BackgroundColor3 = BAR_BACK })
		frame(track, { Size = UDim2.fromScale(math.clamp(points / lastTier, 0, 1), 1), BackgroundColor3 = ink })
		for _, tier in ipairs(TalentConfig.Tiers) do
			if tier < lastTier then
				frame(track, { Position = UDim2.fromScale(tier / lastTier, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = BACKGROUND, ZIndex = 2 })
			end
		end
		local cells = frame(row, { Position = UDim2.fromOffset(TALENT_NAME_WIDTH, 6), Size = UDim2.new(1, -TALENT_NAME_WIDTH, 1, -10) })
		make("UIListLayout", { Parent = cells, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		local index = 0
		for _, talent in ipairs(TalentConfig.List) do
			if talent.stat == stat.key then
				index += 1
				local on = table.find(equipped, talent.key) ~= nil
				local open = BuildRules.TierUnlocked(points, talent.tier)
				local textColor = on and BACKGROUND or open and TEXT or MUTED
				local cell = make("TextButton", {
					Parent = cells,
					LayoutOrder = index,
					Size = UDim2.new(1 / 3, -6, 1, 0),
					BackgroundColor3 = on and ink or BAR_BACK,
					BackgroundTransparency = (on or open) and 0 or 0.6,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
				})
				label(cell, { Text = string.upper(talent.name), Font = TITLE_FONT, TextSize = 16, TextColor3 = textColor, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -40, 0, 20) })
				-- its tier, top right
				label(cell, {
					Text = "T" .. (table.find(TalentConfig.Tiers, talent.tier) or "?"),
					Font = MONO_FONT,
					TextSize = 10,
					TextColor3 = textColor,
					TextTransparency = 0.3,
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 7),
					Size = UDim2.fromOffset(24, 12),
				})
				label(cell, { Text = TalentConfig.Describe(talent), TextSize = 12, TextColor3 = textColor, Position = UDim2.fromOffset(8, 23), Size = UDim2.new(1, -16, 0, 16) })
				label(cell, {
					Text = on and "EQUIPPED" or open and ("COST " .. talent.cost) or string.format("NEEDS %d POINTS", talent.tier),
					Font = MONO_FONT,
					TextSize = 10,
					TextColor3 = on and BACKGROUND or open and NEXT or MUTED,
					Position = UDim2.fromOffset(8, 40),
					Size = UDim2.new(1, -16, 0, 14),
				})
				cell.Activated:Connect(function()
					local remote = ReplicatedStorage:FindFirstChild(TalentConfig.Remote)
					if remote and (open or on) then
						UiSfx.Play("statUp")
						remote:FireServer(talent.key, not on)
					end
				end)
			end
		end
	end
end

-- kept current while it's open
player.AttributeChanged:Connect(function(name)
	if rewardHolder.Visible and Hub.IsOpen("Stats") and (name == "Level" or StatConfig.Get(name) ~= nil) then
		buildInfo()
	end
	if talentsHolder.Visible and Hub.IsOpen("Stats") and (name == "Level" or name == TalentConfig.SaveAttribute or StatConfig.Get(name) ~= nil) then
		buildTalents()
	end
end)

-- shows the STATS, MILESTONES or TALENTS sub-tab
function showTab(name)
	if name == "MILESTONES" then
		buildInfo()
	elseif name == "TALENTS" then
		buildTalents()
	end
	for tabName, button in pairs(subTabs) do
		button.TextColor3 = tabName == name and TEXT or MUTED
	end
	statsHolder.Visible = name == "STATS"
	rewardHolder.Visible = name == "MILESTONES"
	talentsHolder.Visible = name == "TALENTS"
end

-- the hub always opens it on STATS
Hub.OnShown("Stats", function()
	showTab("STATS")
end)

-- the held power's colour: the XP bar, the stats' bars, the radar's shape and the reward bars; unspent points as a
-- badge in the hub's nav
Hub.OnAccent(function(_, accentInk)
	ink = accentInk
	xpFill.BackgroundColor3 = ink
	for _, row in ipairs(rows) do
		row.fill.BackgroundColor3 = ink
	end
	for _, group in ipairs({ shapeEdges, shapeDots, shapeLines }) do
		for _, part in ipairs(group) do
			part.BackgroundColor3 = ink
		end
	end
	if rewardHolder.Visible then
		buildInfo()
	end
	if talentsHolder.Visible then
		buildTalents()
	end
end)
local function showBadge()
	local points = player:GetAttribute("StatPoints") or 0
	Hub.Badge("Stats", points > 0 and tostring(points) or nil)
end
player:GetAttributeChangedSignal("StatPoints"):Connect(showBadge)
showBadge()
