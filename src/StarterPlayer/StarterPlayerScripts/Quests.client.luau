-- The hub's Quests tab (J, or the hub's nav). The BOUNTY sub-tab shows the bounty
-- you've taken (what to defeat, how far along, what it pays) with Abandon.
-- The CHALLENGES sub-tab lists a skill set's mastery challenges (the one you
-- hold, or pick another you own): each with its progress, its mastery XP
-- reward and a tick once done; ones whose move isn't unlocked yet show the
-- mastery it needs. The numbers come from QuestConfig and the player
-- attributes Quests keeps (QuestId, QuestProgress, the saved Challenges).
-- Drawn like the Stats tab: titles and big numbers in Oswald, captions and counts in mono.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hub = require(script.Parent:WaitForChild("Hub"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local questRemote = ReplicatedStorage:WaitForChild("Quest")

local player = Players.LocalPlayer

local PANEL_WIDTH = 620
local ROW_HEIGHT = 66
local BOUNTY_HEIGHT = 186
local SEGMENTS_MAX = 20 -- a progress bar is a segment per step up to this many, one bar past it
local REWARD_WIDTH = 90 -- a challenge's reward, at its right
local BACKGROUND = Hub.Theme.Paper -- text on gold buttons
local TEXT = Hub.Theme.Ink
local MUTED = Hub.Theme.Muted
local GOLD = Color3.fromRGB(255, 190, 40)
local BAR_BACK = Hub.Theme.BarBack
local LOCKED = Color3.fromRGB(70, 70, 76)
local CARD = Hub.Theme.Panel
local TITLE_FONT = Hub.Theme.TitleFont -- titles and big numbers
local MONO_FONT = Hub.Theme.MonoFont -- captions and counts

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
	return make("TextLabel", props)
end

-- a set as players know it: its power's name (Aido is "Deus Ex Machina"), else its key in words
local function setLabel(setName)
	local set = SkillSetConfig.Sets[setName]
	return set and set.tool or (string.gsub(setName, "(%l)(%u)", "%1 %2"))
end

local tabFrame = Hub.Tab("Quests", { order = 3, title = "QUESTS", pose = "Wide", key = Enum.KeyCode.J })

local panel = make("Frame", {
	Name = "Panel",
	Parent = tabFrame,
	Size = UDim2.new(0, PANEL_WIDTH, 1, 0),
	BackgroundTransparency = 1,
})

-- tabs
local tab = "bounty"
local pickedSet -- the set shown on the challenges tab, once chosen
local tabs = {}
-- the sub-tabs as plain titles, like the Stats tab's: the one showing in ink
local tabRow = make("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
make("UIListLayout", { Parent = tabRow, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder })
for order, entry in ipairs({ { "bounty", "BOUNTY" }, { "challenges", "CHALLENGES" } }) do
	tabs[entry[1]] = make("TextButton", {
		Parent = tabRow,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.Highway,
		Text = entry[2],
		TextSize = 16,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- the page under the tabs; rebuilt on every refresh
local body = make("ScrollingFrame", {
	Parent = panel,
	Position = UDim2.fromOffset(0, 34),
	Size = UDim2.new(1, 0, 1, -34),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
})
make("UIListLayout", { Parent = body, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
-- a pixel of room, so the outlines on the cards' edges aren't cut off
make("UIPadding", { Parent = body, PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 6) })

local function clearBody()
	for _, child in ipairs(body:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function progressBar(parent, fraction, color, position, size)
	local back = make("Frame", { Parent = parent, Position = position, Size = size, BackgroundColor3 = BAR_BACK, BorderSizePixel = 0 })
	make("Frame", { Parent = back, Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0 })
	return back
end

-- how far along as a segment per step, the ones reached in `color` (one bar past SEGMENTS_MAX steps)
local function stepBar(parent, done, total, color, position, size)
	if total > SEGMENTS_MAX then
		return progressBar(parent, done / total, color, position, size)
	end
	local bar = make("Frame", { Parent = parent, Position = position, Size = size, BackgroundTransparency = 1 })
	make("UIListLayout", { Parent = bar, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	for step = 1, total do
		make("Frame", {
			Parent = bar,
			LayoutOrder = step,
			Size = UDim2.new(1 / total, -4 * (total - 1) / total, 1, 0),
			BackgroundColor3 = step <= done and color or BAR_BACK,
			BorderSizePixel = 0,
		})
	end
	return bar
end

local refresh -- defined below; the set picker calls it
local order = 0
local function nextOrder()
	order += 1
	return order
end

-- BOUNTY tab: the contract on a card with a gold edge (its title big, what to defeat, the count
-- big over a segment per target, the rewards as chips, Abandon), or a card saying where to get one
local function showBounty()
	local _, quest = QuestConfig.parseQuestId(player:GetAttribute("QuestId"))
	if not quest then
		local empty = make("Frame", { Parent = body, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = CARD, BackgroundTransparency = 0 })
		make("UIPadding", { Parent = empty, PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) })
		label(empty, { Text = "NO ACTIVE BOUNTY", Font = TITLE_FONT, TextSize = 22, Size = UDim2.new(1, 0, 0, 24) })
		label(empty, { Text = "Talk to a Bounty Hunter to take one.", TextSize = 13, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 16) })
		return
	end
	local progress = player:GetAttribute("QuestProgress") or 0
	local xp, yen = QuestConfig.reward(quest.count, quest.level)
	local frame = make("Frame", {
		Parent = body,
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, BOUNTY_HEIGHT),
		BackgroundColor3 = CARD,
		BackgroundTransparency = 0,
	})
	make("Frame", { Parent = frame, Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = GOLD, BorderSizePixel = 0 })
	local inside = make("Frame", { Parent = frame, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	make("UIPadding", { Parent = inside, PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 14) })
	label(inside, { Text = "ACTIVE BOUNTY", Font = MONO_FONT, TextSize = 11, TextColor3 = GOLD, Size = UDim2.new(1, 0, 0, 14) })
	label(inside, {
		Text = "LV " .. quest.level,
		Font = MONO_FONT,
		TextSize = 11,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 14),
	})
	label(inside, {
		Text = string.upper(quest.title),
		Font = TITLE_FONT,
		TextSize = 26,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(-1, 16),
		Size = UDim2.new(1, 0, 0, 30),
	})
	label(inside, {
		Text = string.upper(string.format("Defeat %d %s", quest.count, QuestConfig.plural(quest))),
		Font = MONO_FONT,
		TextSize = 11,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 14),
	})
	label(inside, {
		Text = string.format('%d<font face="RobotoMono" size="14" color="#%s">  / %d</font>', progress, MUTED:ToHex(), quest.count),
		RichText = true,
		Font = TITLE_FONT,
		TextSize = 40,
		Position = UDim2.fromOffset(-1, 64),
		Size = UDim2.new(1, 0, 0, 44),
	})
	stepBar(inside, progress, quest.count, GOLD, UDim2.fromOffset(0, 110), UDim2.new(1, 0, 0, 8))
	-- the rewards as gold chips along the foot, Abandon at its right
	local rewards = make("Frame", {
		Parent = inside,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -100, 0, 24),
		BackgroundTransparency = 1,
	})
	make("UIListLayout", {
		Parent = rewards,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	label(rewards, { LayoutOrder = 0, Text = "REWARD", Font = MONO_FONT, TextSize = 10, TextColor3 = MUTED, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X })
	for index, text in ipairs({ string.format("+%d XP", xp), string.format("+¥%d", yen) }) do
		local chip = label(rewards, {
			LayoutOrder = index,
			Text = text,
			Font = MONO_FONT,
			TextSize = 12,
			TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
		})
		make("UIPadding", { Parent = chip, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
		outline(chip, 0.6).Color = GOLD
	end
	local abandon = make("TextButton", {
		Parent = inside,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(84, 24),
		BackgroundColor3 = LOCKED,
		Font = MONO_FONT,
		Text = "ABANDON",
		TextSize = 11,
		TextColor3 = TEXT,
	})
	abandon.Activated:Connect(function()
		questRemote:FireServer("abandon")
	end)
end

-- the sets the player owns that have challenges, by name (the held one is picked first)
local function challengeSets()
	local owned = {}
	local list = player:GetAttribute(SkillSetConfig.OwnedSetsAttribute) or ""
	local seen = {}
	for setName in string.gmatch(list, "[^,]+") do
		if QuestConfig.Challenges[setName] and not seen[setName] then
			seen[setName] = true
			table.insert(owned, setName)
		end
	end
	if SkillSetConfig.OwnAllSets then
		for setName in pairs(QuestConfig.Challenges) do
			if not seen[setName] then
				seen[setName] = true
				table.insert(owned, setName)
			end
		end
	end
	table.sort(owned)
	return owned
end

-- CHALLENGES tab: the set picker, the set's name big in its colour with its mastery and how many
-- are done, then a numbered card per challenge (an edge in the set's colour, gold once done)
local function showChallenges()
	local sets = challengeSets()
	if #sets == 0 then
		label(body, {
			LayoutOrder = nextOrder(),
			Text = "No skill set with challenges yet.",
			TextSize = 13,
			TextColor3 = MUTED,
			Size = UDim2.new(1, 0, 0, 20),
		})
		return
	end
	if not pickedSet or not table.find(sets, pickedSet) then
		local _, held = SkillSetConfig.Equipped(player.Character)
		pickedSet = held and table.find(sets, held) and held or sets[1]
	end
	-- the set picker
	local picker = make("Frame", { Parent = body, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 })
	make("UIListLayout", { Parent = picker, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	for index, setName in ipairs(sets) do
		-- the chosen set is filled in its own colour, the rest are outlines
		local chosen = setName == pickedSet
		local color = SkillSetConfig.Sets[setName].color or TEXT
		local light = 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B > 0.5
		local button = make("TextButton", {
			Parent = picker,
			LayoutOrder = index,
			Size = UDim2.new(1 / #sets, -4, 1, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = chosen and 0 or 1,
			Font = Enum.Font.Highway,
			Text = setLabel(setName),
			TextSize = 11,
			TextColor3 = chosen and (light and BACKGROUND or TEXT) or MUTED,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		outline(button, chosen and 1 or 0.7)
		button:SetAttribute("SectionSelect", true)
		button.Activated:Connect(function()
			pickedSet = setName
			refresh()
		end)
	end

	local progress = QuestConfig.decode(player:GetAttribute("Challenges"))
	local mastery = player:GetAttribute(SkillSetConfig.MasteryAttribute(pickedSet)) or 1
	local set = SkillSetConfig.Sets[pickedSet]
	local setColor = set and set.color or TEXT
	local challenges = QuestConfig.Challenges[pickedSet]
	local doneCount = 0
	for _, challenge in ipairs(challenges) do
		if progress[pickedSet .. "." .. challenge.id] == "done" then
			doneCount += 1
		end
	end
	local header = make("Frame", { Parent = body, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 })
	label(header, {
		Text = string.upper(setLabel(pickedSet)),
		Font = TITLE_FONT,
		TextSize = 26,
		TextColor3 = setColor,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(-1, 6),
		Size = UDim2.new(1, 0, 0, 30),
	})
	label(header, {
		Text = string.format("MASTERY %d  ·  %d / %d DONE", mastery, doneCount, #challenges),
		Font = MONO_FONT,
		TextSize = 11,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 14),
	})

	for index, challenge in ipairs(challenges) do
		local value = progress[pickedSet .. "." .. challenge.id]
		local done = value == "done"
		local needed = challenge.gate and set and set.skills and set.skills[challenge.gate] and set.skills[challenge.gate].mastery
		local locked = needed ~= nil and mastery < needed
		local row = make("Frame", {
			Parent = body,
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = CARD,
			BackgroundTransparency = 0,
		})
		make("Frame", { Parent = row, Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = done and GOLD or locked and LOCKED or setColor, BorderSizePixel = 0 })
		local dim = locked or done
		label(row, {
			Text = string.format("%02d", index),
			Font = MONO_FONT,
			TextSize = 11,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.fromOffset(24, 14),
		})
		label(row, {
			Text = challenge.text,
			TextSize = 13,
			TextColor3 = dim and MUTED or TEXT,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(42, 6),
			Size = UDim2.new(1, -(42 + REWARD_WIDTH), 0, 30),
		})
		local count = done and challenge.count or (value or 0)
		stepBar(row, count, challenge.count, done and GOLD or TEXT, UDim2.fromOffset(42, 40), UDim2.new(1, -(42 + REWARD_WIDTH), 0, 4))
		label(row, {
			Text = locked and ("MASTERY " .. needed) or string.format("%d / %d", count, challenge.count),
			Font = MONO_FONT,
			TextSize = 10,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(42, 48),
			Size = UDim2.new(1, -(42 + REWARD_WIDTH), 0, 12),
		})
		-- the reward on the right: the mastery XP big, or a tick once done
		label(row, {
			Text = done and "✓" or string.format("+%d", challenge.reward),
			Font = done and Enum.Font.Highway or TITLE_FONT,
			TextSize = done and 24 or 22,
			TextColor3 = locked and MUTED or GOLD,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
			Size = UDim2.fromOffset(REWARD_WIDTH - 16, 26),
		})
		label(row, {
			Text = done and "DONE" or "MASTERY XP",
			Font = MONO_FONT,
			TextSize = 9,
			TextColor3 = done and GOLD or MUTED,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 38),
			Size = UDim2.fromOffset(REWARD_WIDTH - 16, 12),
		})
	end
end

function refresh()
	order = 0
	clearBody()
	for name, button in pairs(tabs) do
		local chosen = name == tab
		button.TextColor3 = chosen and TEXT or MUTED
	end
	if tab == "bounty" then
		showBounty()
	else
		showChallenges()
	end
end

for name, button in pairs(tabs) do
	button:SetAttribute("SectionSelect", true)
	button.Activated:Connect(function()
		tab = name
		refresh()
	end)
end
Hub.OnShown("Quests", refresh)

-- what changes what the menu shows: the bounty, the saved challenges, level,
-- what's owned, and each set's mastery (which unlocks challenges)
local watched = { QuestId = true, QuestProgress = true, Challenges = true, [SkillSetConfig.OwnedSetsAttribute] = true }
for setName in pairs(SkillSetConfig.Sets) do
	watched[SkillSetConfig.MasteryAttribute(setName)] = true
end
player.AttributeChanged:Connect(function(name)
	if Hub.IsOpen("Quests") and watched[name] then
		refresh()
	end
end)
