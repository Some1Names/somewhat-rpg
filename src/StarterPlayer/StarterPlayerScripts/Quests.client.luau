-- The hub's Quests tab (J, or the hub's nav). The BOUNTY sub-tab shows the bounty
-- you've taken (what to defeat, how far along, what it pays) with Abandon.
-- The CHALLENGES sub-tab lists a skill set's mastery challenges (the one you
-- hold, or pick another you own): each with its progress, its mastery XP
-- reward and a tick once done; ones whose move isn't unlocked yet show the
-- mastery it needs. The numbers come from QuestConfig and the player
-- attributes Quests keeps (QuestId, QuestProgress, the saved Challenges).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hub = require(script.Parent:WaitForChild("Hub"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local questRemote = ReplicatedStorage:WaitForChild("Quest")

local player = Players.LocalPlayer

local PANEL_WIDTH = 620
local ROW_HEIGHT = 62
local BACKGROUND = Hub.Theme.Paper -- text on gold buttons
local TEXT = Hub.Theme.Ink
local MUTED = Hub.Theme.Muted
local GOLD = Color3.fromRGB(190, 130, 0) -- dark enough for the paper
local BAR_BACK = Hub.Theme.BarBack
local LOCKED = Color3.fromRGB(180, 180, 178)
local CARD = Hub.Theme.Panel

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
	return make("TextLabel", props)
end

-- "IridescentRequiem" as "Iridescent Requiem"
local function setLabel(setName)
	return (string.gsub(setName, "(%l)(%u)", "%1 %2"))
end

local tabFrame = Hub.Tab("Quests", { order = 3, title = "QUESTS", key = Enum.KeyCode.J, pose = "Wide" })

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
		Font = Enum.Font.GothamBold,
		Text = entry[2],
		TextSize = 14,
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

local refresh -- defined below; the set picker calls it
local order = 0
local function nextOrder()
	order += 1
	return order
end

-- BOUNTY tab
local function showBounty()
	local _, quest = QuestConfig.parseQuestId(player:GetAttribute("QuestId"))
	if not quest then
		label(body, {
			LayoutOrder = nextOrder(),
			Text = "No bounty taken.\nTalk to a Bounty Hunter to take one.",
			TextSize = 13,
			TextColor3 = MUTED,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 44),
		})
		return
	end
	local progress = player:GetAttribute("QuestProgress") or 0
	local xp, yen = QuestConfig.reward(quest.count, quest.level)
	local frame = make("Frame", {
		Parent = body,
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 132),
		BackgroundColor3 = CARD,
		BackgroundTransparency = 0,
	})
	make("UIPadding", { Parent = frame, PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
	label(frame, { Text = quest.title, Font = Enum.Font.GothamBold, TextSize = 15, Size = UDim2.new(1, 0, 0, 18) })
	label(frame, {
		Text = string.format("Defeat %d %s  ·  Lv. %d", quest.count, QuestConfig.plural(quest), quest.level),
		TextSize = 12,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 14),
	})
	progressBar(frame, progress / quest.count, GOLD, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 8))
	label(frame, {
		Text = string.format("%s %d/%d", QuestConfig.plural(quest), progress, quest.count),
		TextSize = 12,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 14),
	})
	label(frame, { Text = string.format("Reward  +%d XP   +¥%d", xp, yen), TextSize = 12, TextColor3 = GOLD, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 14) })
	local abandon = make("TextButton", {
		Parent = frame,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(74, 24),
		BackgroundColor3 = LOCKED,
		Font = Enum.Font.GothamBold,
		Text = "Abandon",
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

-- CHALLENGES tab
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
	local picker = make("Frame", { Parent = body, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
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
			Font = Enum.Font.GothamBold,
			Text = setLabel(setName),
			TextSize = 10,
			TextColor3 = chosen and (light and TEXT or BACKGROUND) or MUTED,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		outline(button, chosen and 1 or 0.7)
		button.Activated:Connect(function()
			pickedSet = setName
			refresh()
		end)
	end

	local progress = QuestConfig.decode(player:GetAttribute("Challenges"))
	local mastery = player:GetAttribute(SkillSetConfig.MasteryAttribute(pickedSet)) or 1
	local set = SkillSetConfig.Sets[pickedSet]
	for _, challenge in ipairs(QuestConfig.Challenges[pickedSet]) do
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
		make("UIPadding", { Parent = row, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
		label(row, {
			Text = challenge.text,
			TextSize = 12,
			TextColor3 = (locked or done) and MUTED or TEXT,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -64, 0, 28),
		})
		local count = done and challenge.count or (value or 0)
		progressBar(row, count / challenge.count, done and GOLD or TEXT, UDim2.fromOffset(0, 32), UDim2.new(1, -64, 0, 6))
		label(row, {
			Text = locked and ("Mastery " .. needed) or string.format("%d/%d", count, challenge.count),
			TextSize = 11,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, -64, 0, 12),
		})
		label(row, {
			Text = done and "✓" or string.format("+%d", challenge.reward),
			Font = Enum.Font.GothamBold,
			TextSize = done and 20 or 13,
			TextColor3 = done and GOLD or (locked and MUTED or GOLD),
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(58, 24),
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
