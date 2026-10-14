-- The Quests menu: press J or the top bar's Quests icon (TopBar). The BOUNTY tab shows the bounty
-- you've taken (what to defeat, how far along, what it pays) with Abandon.
-- The CHALLENGES tab lists a skill set's mastery challenges (the one you
-- hold, or pick another you own): each with its progress, its mastery XP
-- reward and a tick once done; ones whose move isn't unlocked yet show the
-- mastery it needs. The numbers come from QuestConfig and the player
-- attributes Quests keeps (QuestId, QuestProgress, the saved Challenges).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local questRemote = ReplicatedStorage:WaitForChild("Quest")

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.J
local PANEL_SIZE = Vector2.new(380, 460)
local SCREEN_MARGIN = 24
local PADDING = 14
local ROW_HEIGHT = 62
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local GOLD = Color3.fromRGB(255, 205, 60)
local BAR_BACK = Color3.fromRGB(45, 45, 58)
local LOCKED = Color3.fromRGB(70, 70, 82)

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

local gui = make("ScreenGui", {
	Name = "Quests",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = make("Frame", {
	Name = "Panel",
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
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

-- smaller screens get a smaller panel
local panelScale = make("UIScale", { Parent = panel })
local function rescale()
	local viewport = workspace.CurrentCamera.ViewportSize
	panelScale.Scale = math.min(1, (viewport.X - 2 * SCREEN_MARGIN) / PANEL_SIZE.X, (viewport.Y - 2 * SCREEN_MARGIN) / PANEL_SIZE.Y)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local header = make("Frame", { Parent = panel, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
label(header, { Text = "QUESTS", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, -30, 1, 0) })
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

-- tabs
local tab = "bounty"
local pickedSet -- the set shown on the challenges tab, once chosen
local tabs = {}
local tabRow = make("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
make("UIListLayout", { Parent = tabRow, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
for order, entry in ipairs({ { "bounty", "BOUNTY" }, { "challenges", "CHALLENGES" } }) do
	tabs[entry[1]] = make("TextButton", {
		Parent = tabRow,
		LayoutOrder = order,
		Size = UDim2.new(0.5, -3, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.7,
		Font = Enum.Font.GothamBold,
		Text = entry[2],
		TextSize = 11,
		TextColor3 = MUTED,
	})
	outline(tabs[entry[1]], 0.85)
end

-- the page under the tabs; rebuilt on every refresh
local body = make("ScrollingFrame", {
	Parent = panel,
	Position = UDim2.fromOffset(0, 64),
	Size = UDim2.new(1, 0, 1, -64),
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
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.7,
	})
	outline(frame, 0.85)
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
		local chosen = setName == pickedSet
		local button = make("TextButton", {
			Parent = picker,
			LayoutOrder = index,
			Size = UDim2.new(1 / #sets, -4, 1, 0),
			BackgroundColor3 = chosen and GOLD or Color3.new(0, 0, 0),
			BackgroundTransparency = chosen and 0 or 0.7,
			Font = Enum.Font.GothamBold,
			Text = setLabel(setName),
			TextSize = 10,
			TextColor3 = chosen and BACKGROUND or MUTED,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		outline(button, 0.85)
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
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.7,
		})
		outline(row, 0.85)
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
		button.BackgroundTransparency = chosen and 0.35 or 0.7
	end
	if tab == "bounty" then
		showBounty()
	else
		showChallenges()
	end
end

local function setOpen(open)
	panel.Visible = open
	if open then
		Menus.Open("Quests", function()
			setOpen(false)
		end)
		refresh()
	else
		Menus.Close("Quests")
	end
end
Menus.Register("Quests", function()
	setOpen(not panel.Visible)
end)

for name, button in pairs(tabs) do
	button.Activated:Connect(function()
		tab = name
		refresh()
	end)
end
closeButton.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and not Keybinds.Capturing() and input.KeyCode == TOGGLE_KEY then
		setOpen(not panel.Visible)
	end
end)

-- what changes what the menu shows: the bounty, the saved challenges, level,
-- what's owned, and each set's mastery (which unlocks challenges)
local watched = { QuestId = true, QuestProgress = true, Challenges = true, [SkillSetConfig.OwnedSetsAttribute] = true }
for setName in pairs(SkillSetConfig.Sets) do
	watched[SkillSetConfig.MasteryAttribute(setName)] = true
end
player.AttributeChanged:Connect(function(name)
	if panel.Visible and watched[name] then
		refresh()
	end
end)
