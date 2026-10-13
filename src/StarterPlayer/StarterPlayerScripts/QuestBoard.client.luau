-- Bounties on screen: the Bounty Hunter's panel, the tracker and the popups.
-- Triggering the ProximityPrompt of an NPC tagged QuestGiver (a GiverId
-- attribute names its list in QuestConfig.Givers) opens a small square panel
-- titled BOUNTY HUNTER with that giver's bounties: title, what to defeat,
-- level and reward, and Accept (greyed with "Lv. N" above your level). The
-- server re-checks everything (Quests.Accept). A bounty you've taken shows
-- in a small tracker on the right edge ("Dummies 1/3"), hidden without one.
-- The QuestDone remote pops up "Bounty complete" or "Challenge complete" in
-- gold with its reward. The Quests menu (J) is Quests.client.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local questRemote = ReplicatedStorage:WaitForChild("Quest")
local doneRemote = ReplicatedStorage:WaitForChild("QuestDone")

local player = Players.LocalPlayer

local PANEL_WIDTH = 320
local PADDING = 14
local TRACKER_WIDTH = 190
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local GOLD = Color3.fromRGB(255, 205, 60) -- same as the other popups
local LOCKED = Color3.fromRGB(70, 70, 82)
local STEP_AWAY = 8 -- studs past the giver's reach where the panel closes itself

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

local function plural(name)
	return string.sub(name, -1) == "s" and name or name .. "s"
end

local function rewardText(quest)
	local xp, yen = QuestConfig.reward(quest.count, quest.level)
	return string.format("+%d XP   +¥%d", xp, yen)
end

local gui = make("ScreenGui", {
	Name = "QuestBoard",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- The tracker
local tracker = make("Frame", {
	Name = "Tracker",
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(TRACKER_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.25,
	Visible = false,
})
outline(tracker, 0.5)
make("UIPadding", {
	Parent = tracker,
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
})
make("UIListLayout", { Parent = tracker, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
local trackerKind = label(tracker, { LayoutOrder = 1, Text = "BOUNTY", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = GOLD, Size = UDim2.new(1, 0, 0, 12) })
local trackerTitle = label(tracker, { LayoutOrder = 2, Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, 0, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
local trackerCount = label(tracker, { LayoutOrder = 3, TextSize = 12, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 14) })

local function updateTracker()
	local _, quest = QuestConfig.parseQuestId(player:GetAttribute("QuestId"))
	tracker.Visible = quest ~= nil
	if quest then
		trackerTitle.Text = quest.title
		trackerCount.Text = string.format("%s %d/%d", plural(quest.enemyType), player:GetAttribute("QuestProgress") or 0, quest.count)
	end
end

-- The Bounty Hunter's panel
local panel = make("Frame", {
	Name = "Panel",
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
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

local header = make("Frame", { Parent = panel, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
local panelTitle = label(header, { Text = "BOUNTY HUNTER", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, -30, 1, 0) })
-- Modal frees the mouse while the panel is open, even in shift lock
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
local list = make("Frame", {
	Parent = panel,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

local openGiver -- { id, model } while the panel is open

local function close()
	openGiver = nil
	panel.Visible = false
end

-- one bounty's card
local function card(giverId, quest, order)
	local locked = (player:GetAttribute("Level") or 0) < quest.level
	local current = player:GetAttribute("QuestId") == giverId .. "/" .. quest.id
	local frame = make("Frame", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.7,
	})
	outline(frame, 0.85)
	make("UIPadding", { Parent = frame, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
	local dim = locked and MUTED or TEXT
	label(frame, { Text = quest.title, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = dim, Size = UDim2.new(1, -70, 0, 16) })
	label(frame, {
		Text = string.format("Defeat %d %s", quest.count, plural(quest.enemyType)),
		TextSize = 12,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -70, 0, 14),
	})
	label(frame, { Text = rewardText(quest), TextSize = 12, TextColor3 = locked and MUTED or GOLD, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, -70, 0, 14) })
	label(frame, { Text = "Lv. " .. quest.level, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, -70, 0, 14) })
	local accept = make("TextButton", {
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(62, 26),
		BackgroundColor3 = locked and LOCKED or current and BACKGROUND or GOLD,
		Font = Enum.Font.GothamBold,
		Text = locked and ("Lv. " .. quest.level) or current and "Active" or "Accept",
		TextSize = 11,
		TextColor3 = locked and MUTED or current and GOLD or BACKGROUND,
		AutoButtonColor = not locked and not current,
	})
	outline(accept, current and 0.3 or 1)
	accept.Activated:Connect(function()
		if locked or current then
			return
		end
		questRemote:FireServer("accept", giverId, quest.id)
		close()
	end)
end

local function render()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local giver = openGiver and QuestConfig.Givers[openGiver.id]
	if not giver then
		return
	end
	panelTitle.Text = string.upper(giver.name or "Bounty Hunter")
	for order, quest in ipairs(giver.quests) do
		card(openGiver.id, quest, order)
	end
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
	openGiver = { id = giverId, model = model }
	render()
	panel.Visible = true
end)
closeButton.Activated:Connect(close)

-- walking away closes it
RunService.Heartbeat:Connect(function()
	if not openGiver then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openGiver.model.Parent or (openGiver.model:GetPivot().Position - root.Position).Magnitude > QuestConfig.GiverRange + STEP_AWAY then
		close()
	end
end)

-- popups
local function popup(text, color, size, height, lifetime)
	local popupLabel = make("TextLabel", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, height),
		Size = UDim2.fromOffset(500, size + 6),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		TextStrokeTransparency = 0.5,
	})
	TweenService:Create(popupLabel, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, height - 0.03),
	}):Play()
	TweenService:Create(popupLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, lifetime - 0.4), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(popupLabel, lifetime)
end

doneRemote.OnClientEvent:Connect(function(kind, title, reward)
	if kind == "bounty" then
		popup("Bounty complete", GOLD, 30, 0.38, 3)
		popup(title, TEXT, 16, 0.43, 3)
		if typeof(reward) == "table" then
			popup(string.format("+%d XP   +¥%d", reward.xp or 0, reward.yen or 0), GOLD, 16, 0.47, 3)
		end
	else
		popup("Challenge complete", GOLD, 30, 0.38, 3)
		popup(title, TEXT, 16, 0.43, 3)
		if typeof(reward) == "table" then
			popup(string.format("+%d mastery XP", reward.mastery or 0), GOLD, 16, 0.47, 3)
		end
	end
end)

player:GetAttributeChangedSignal("QuestId"):Connect(function()
	updateTracker()
	if panel.Visible then
		render()
	end
end)
player:GetAttributeChangedSignal("QuestProgress"):Connect(updateTracker)
player:GetAttributeChangedSignal("Level"):Connect(function()
	if panel.Visible then
		render()
	end
end)
updateTracker()
