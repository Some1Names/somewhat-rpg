-- The dialogue box: an NPC's words typed out low on the screen over a soft dark fade, the
-- player's replies as plain numbered lines under them (click, or press the number). Trees are
-- data in DialogueConfig. Dialogue.Open(tree, { npc?, range?, speaker?, onAction? }): `onAction(action)`
-- gets the action of each choice picked; `npc` (a model) is whom they're talking to (the talk ends past `range` studs from it, 18 by default). The skill
-- bar hides itself while it's open (SkillBar asks Menus) and the talk takes its place. It is the
-- one open menu (Menus): the player can walk, but nothing else (Menus.BlocksActions: no skills,
-- shots, swings, blocks or hotbar keys, so the number keys are free for the replies). It ends
-- when they walk out of range of `npc`, die, or press Esc. Enter or a click skips the typing.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local DialogueConfig = require(ReplicatedStorage:WaitForChild("DialogueConfig"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local Dialogue = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Style = HudConfig.Style
local TEXT = Color3.new(1, 1, 1)
local STROKE = Color3.new(0, 0, 0)
local WIDTH = 620
local LEAVE_RANGE = 18 -- studs from the NPC past which the talk ends
local SLIDE = 16 -- px the words rise from when it opens and sink to when it closes
local OPEN_TIME = 0.35
local CLOSE_TIME = 0.2
local CHOICE_STAGGER = 0.07 -- seconds between one reply fading in and the next
local TYPE_DELAY = 0.025 -- seconds per letter
local KEY_SIZE = 24 -- a reply's number key, px
local IDLE = 0.4 -- a reply's text transparency until it's hovered
local NUMBER_KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

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

local gui = make("ScreenGui", {
	Name = "Dialogue",
	ResetOnSpawn = false,
	Enabled = false,
	DisplayOrder = 20,
	Parent = playerGui,
})

-- a dark fade rising from the bottom edge, so the words read over any scene
local shade = make("CanvasGroup", {
	Parent = gui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 300),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	GroupTransparency = 1,
	Active = false,
})
make("UIGradient", {
	Parent = shade,
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	}),
})

local REST = UDim2.new(0.5, 0, 1, -(HudConfig.BottomReserve + 6))
local HIDDEN = REST + UDim2.fromOffset(0, SLIDE)

local panel = make("CanvasGroup", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = REST,
	Size = UDim2.fromOffset(WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	GroupTransparency = 1,
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })

-- a short rule over the speaker's name (an accented node tints it)
local rule = make("Frame", {
	Parent = panel,
	LayoutOrder = 1,
	Size = UDim2.fromOffset(36, 2),
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
})

local speakerLabel = make("TextLabel", {
	Parent = panel,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	Font = Style.TitleFont,
	TextSize = 15,
	TextColor3 = TEXT,
	TextTransparency = 0.25,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local body = make("TextLabel", {
	Parent = panel,
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Font = Style.LabelFont,
	TextSize = 21,
	TextColor3 = TEXT,
	TextStrokeColor3 = STROKE,
	TextStrokeTransparency = 0.6,
	RichText = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})

local choiceList = make("Frame", {
	Parent = panel,
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = choiceList, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
make("UIPadding", { Parent = choiceList, PaddingTop = UDim.new(0, 4) })

local isOpen = false
local session = 0 -- bumped on every node and close, so a stale typing loop stops itself
local tree, options
local typing = false
local skip = false
local picks = {} -- the shown choices' callbacks, by number

local function clearChoices()
	picks = {}
	for _, child in ipairs(choiceList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	session += 1
	local closing = session
	TweenService:Create(panel, TweenInfo.new(CLOSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = HIDDEN, GroupTransparency = 1 }):Play()
	TweenService:Create(shade, TweenInfo.new(CLOSE_TIME), { GroupTransparency = 1 }):Play()
	task.delay(CLOSE_TIME, function()
		if session == closing then
			gui.Enabled = false
		end
	end)
	tree, options = nil, nil
	typing = false
	ProximityPromptService.Enabled = true
	Menus.Close("Dialogue")
end

local show

-- one reply: its number as a small key (square, thin outline) then the words. Hovering lights
-- the key and slides the words over, each in its own place so nothing overlaps
local function addChoice(index, label, callback, accent)
	local button = make("TextButton", {
		Parent = choiceList,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, KEY_SIZE + 6),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	})
	local key = make("Frame", {
		Parent = button,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE),
		BackgroundColor3 = Style.ChipBack,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	local tint = accent and DialogueConfig.Accents[accent] or TEXT
	local outline = make("UIStroke", { Parent = key, Color = tint, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local number = make("TextLabel", {
		Parent = key,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Style.MonoFont,
		Text = tostring(index),
		TextSize = 14,
		TextColor3 = tint,
		TextTransparency = 1,
	})
	local words = make("TextLabel", {
		Parent = button,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KEY_SIZE + 12, 0.5, 0),
		Size = UDim2.new(1, -(KEY_SIZE + 12 + 8), 1, 0),
		BackgroundTransparency = 1,
		Font = Style.LabelFont,
		Text = label,
		RichText = true,
		TextSize = 17,
		TextColor3 = TEXT,
		TextTransparency = 1,
		TextStrokeColor3 = STROKE,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- fades in, each reply a moment after the one above
	local fadeIn = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, (index - 1) * CHOICE_STAGGER)
	TweenService:Create(key, fadeIn, { BackgroundTransparency = Style.ChipBackTransparency }):Play()
	TweenService:Create(outline, fadeIn, { Transparency = Style.ChipEdgeTransparency }):Play()
	TweenService:Create(number, fadeIn, { TextTransparency = 0 }):Play()
	TweenService:Create(words, fadeIn, { TextTransparency = IDLE, TextStrokeTransparency = 0.7 }):Play()
	local quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function light(on)
		TweenService:Create(words, quick, { TextColor3 = on and tint or TEXT, TextTransparency = on and 0 or IDLE, Position = UDim2.new(0, KEY_SIZE + (on and 18 or 12), 0.5, 0) }):Play()
		TweenService:Create(key, quick, { BackgroundTransparency = on and 0.1 or Style.ChipBackTransparency }):Play()
		TweenService:Create(outline, quick, { Transparency = on and 0 or Style.ChipEdgeTransparency }):Play()
	end
	button.MouseEnter:Connect(function()
		light(true)
	end)
	button.MouseLeave:Connect(function()
		light(false)
	end)
	button.Activated:Connect(callback)
	picks[index] = callback
end

local function advance(nextId)
	if nextId then
		show(nextId)
	else
		close()
	end
end

function show(id)
	local node = tree and tree.nodes[id]
	if not node then
		close()
		return
	end
	clearChoices()
	session += 1
	local mine = session
	body.Text = node.text
	rule.BackgroundColor3 = node.accent and DialogueConfig.Accents[node.accent] or TEXT
	body.MaxVisibleGraphemes = 0
	typing, skip = true, false
	task.spawn(function()
		local plain = string.gsub(node.text, "<[^>]+>", "") -- the letters that show, without the markup
		local total = utf8.len(plain) or #plain
		for visible = 1, total do
			if session ~= mine then
				return
			end
			if skip then
				break
			end
			body.MaxVisibleGraphemes = visible
			task.wait(TYPE_DELAY)
		end
		if session ~= mine then
			return
		end
		body.MaxVisibleGraphemes = -1
		typing = false
		if node.choices then
			for index, choice in ipairs(node.choices) do
				addChoice(index, choice.label, function()
					if choice.action and options and options.onAction then
						options.onAction(choice.action)
					end
					advance(choice.next)
				end, choice.accent)
			end
		else
			addChoice(1, node.next and "Continue" or "Leave", function()
				advance(node.next)
			end)
		end
	end)
end

-- opens `treeData` (a DialogueConfig tree)
function Dialogue.Open(treeData, opts)
	options = opts or {}
	tree = treeData
	speakerLabel.Text = string.upper(options.speaker or tree.speaker or "")
	ProximityPromptService.Enabled = false
	Menus.Open("Dialogue", close)
	isOpen = true
	gui.Enabled = true
	-- the fade comes up and the words rise into place
	panel.Position = HIDDEN
	panel.GroupTransparency = 1
	TweenService:Create(shade, TweenInfo.new(OPEN_TIME), { GroupTransparency = 0 }):Play()
	TweenService:Create(panel, TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = REST }):Play()
	TweenService:Create(panel, TweenInfo.new(OPEN_TIME * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
	show(tree.start)
end

function Dialogue.Close()
	close()
end

-- walking away, or dying, ends the talk
RunService.Heartbeat:Connect(function()
	if not isOpen then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		close()
		return
	end
	local npc = options and options.npc
	if npc and (npc:GetPivot().Position - root.Position).Magnitude > (options.range or LEAVE_RANGE) then
		close()
	end
end)

-- a click on the words skips the typing
panel.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		skip = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not isOpen or processed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Escape then
		close()
	elseif key == Enum.KeyCode.Return then
		if typing then
			skip = true
		elseif picks[1] and not picks[2] then
			picks[1]()
		end
	elseif not typing then
		local index = table.find(NUMBER_KEYS, key)
		if index and picks[index] then
			picks[index]()
		end
	end
end)

return Dialogue
