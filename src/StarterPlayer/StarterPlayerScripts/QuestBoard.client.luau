-- Bounties on screen: the talk with a Bounty Hunter and the tracker.
-- Triggering the ProximityPrompt of an NPC tagged QuestGiver (a GiverId
-- attribute names its list in QuestConfig.Givers) starts a dialogue (Dialogue) that lists
-- that giver's bounties as replies. A bounty you've taken shows
-- in a small tracker on the right edge ("Dummies 1/3"), hidden without one.
-- A bounty or challenge done shows in the pickup feed (PickupFeed). The Quests
-- menu (J) is Quests.client.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dialogue = require(script.Parent:WaitForChild("Dialogue"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local questRemote = ReplicatedStorage:WaitForChild("Quest")

local player = Players.LocalPlayer

local TRACKER_WIDTH = HudConfig.SideWidth -- as wide as the tool grid it sits above
local BACKGROUND = HudConfig.Style.Glass -- Modern Warfare's smoked glass
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local GOLD = Color3.fromRGB(255, 205, 60) -- same as the other popups

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

local function rewardText(quest)
	local xp, yen = QuestConfig.reward(quest.count, quest.level)
	return string.format("+%d XP   +¥%d", xp, yen)
end

local gui = make("ScreenGui", {
	Name = "QuestBoard",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- popup heights are fractions of the real screen
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- The tracker
local tracker = make("Frame", {
	Name = "Tracker",
	Parent = gui,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -HudConfig.EdgeMargin, 1, -(HudConfig.BottomReserve + HudConfig.SideHeight + HudConfig.SideGap)),
	Size = UDim2.fromOffset(TRACKER_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = HudConfig.Style.GlassTransparency,
	Visible = false,
})
outline(tracker, HudConfig.Style.EdgeTransparency)
make("UIPadding", {
	Parent = tracker,
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
})
make("UIListLayout", { Parent = tracker, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
local trackerKind = label(tracker, { LayoutOrder = 1, Text = "BOUNTY", Font = HudConfig.Style.MonoFont, TextSize = 10, TextColor3 = GOLD, Size = UDim2.new(1, 0, 0, 12) })
local trackerTitle = label(tracker, { LayoutOrder = 2, Font = HudConfig.Style.TitleFont, TextSize = 15, Size = UDim2.new(1, 0, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
local trackerCount = label(tracker, { LayoutOrder = 3, Font = HudConfig.Style.MonoFont, TextSize = 11, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 14) })

local adminOpen = false -- the Admin panel takes the right side, so the tracker steps aside

local function updateTracker()
	local _, quest = QuestConfig.parseQuestId(player:GetAttribute("QuestId"))
	tracker.Visible = quest ~= nil and not adminOpen
	if quest then
		trackerTitle.Text = quest.title
		trackerCount.Text = string.format("%s %d/%d", QuestConfig.plural(quest), player:GetAttribute("QuestProgress") or 0, quest.count)
	end
end

-- Talking to a Bounty Hunter: one step. The greeting has the giver's bounties as the replies
-- (title, what to defeat, the reward in gold); picking one takes it and ends the talk, and the
-- tracker shows it. A bounty above your level answers with what you need, one you're already on
-- says so; both go back to the list. The server re-checks everything (Quests.Accept).
local GOLD_HEX = "#FFCD3C"

local function bountyTree(giverId, giver)
	local nodes = {}
	local choices = {}
	local level = player:GetAttribute("Level") or 0
	for index, quest in ipairs(giver.quests) do
		local current = player:GetAttribute("QuestId") == giverId .. "/" .. quest.id
		local choice
		if level < quest.level then
			nodes["locked" .. index] = { text = string.format("That one needs level %d. Come back stronger.", quest.level), next = "start" }
			choice = { label = string.format('%s  <font transparency="0.5">needs Lv. %d</font>', quest.title, quest.level), next = "locked" .. index }
		elseif current then
			nodes["active" .. index] = { text = "You're already on that one. Go finish it.", next = "start" }
			choice = { label = string.format('%s  <font transparency="0.5">active</font>', quest.title), next = "active" .. index }
		else
			choice = {
				label = string.format(
					'%s  <font transparency="0.4">Defeat %d %s</font>  <font color="%s">%s</font>',
					quest.title, quest.count, QuestConfig.plural(quest), GOLD_HEX, rewardText(quest)
				),
				action = "accept:" .. quest.id,
			}
		end
		table.insert(choices, choice)
	end
	table.insert(choices, { label = "Not now" })
	nodes.start = { text = "Looking for work? Take a job, and come back when it's done.", choices = choices }
	return { speaker = giver.name or "Bounty Hunter", start = "start", nodes = nodes }
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	if not model or not CollectionService:HasTag(model, QuestConfig.GiverTag) then
		return
	end
	local giverId = model:GetAttribute("GiverId")
	if typeof(giverId) ~= "string" or not QuestConfig.Givers[giverId] then
		return
	end
	Dialogue.Open(bountyTree(giverId, QuestConfig.Givers[giverId]), {
		npc = model,
		range = QuestConfig.GiverRange, -- the server's reach: the talk ends before a pick could be refused
		onAction = function(action)
			local questId = string.match(action, "^accept:(.+)$")
			if questId then
				questRemote:FireServer("accept", giverId, questId)
			end
		end,
	})
end)

player:GetAttributeChangedSignal("QuestId"):Connect(updateTracker)
player:GetAttributeChangedSignal("QuestProgress"):Connect(updateTracker)
Menus.OnChange(function(openName)
	adminOpen = openName == "Admin"
	updateTracker()
end)
updateTracker()
