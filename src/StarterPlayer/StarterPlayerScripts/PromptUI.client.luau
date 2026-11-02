-- Custom proximity prompts: every ProximityPrompt in the world is switched to the Custom
-- style on this client and drawn here instead of Roblox's round bubble. Walking up to one, a
-- small white dot marks the thing's torso first (from DOT_RANGE studs past the prompt's own
-- range); in range the dot opens into a square key box (see-through, thin white edge,
-- HudConfig.Style) with only the action ("Interact", "Talk") above it, and walking away closes
-- it back to the dot, which then fades. A hold prompt fills the box while the key is held. A
-- prompt that's switched off (or all of them, ProximityPromptService.Enabled) shows no dot. The
-- prompts' own events still fire, so the scripts that listen to PromptTriggered are untouched.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Style = HudConfig.Style

local TEXT = Color3.new(1, 1, 1)
local KEY_SIZE = 50
local LABEL_HEIGHT = 20
local DOT_SIZE = 5
local DOT_RANGE = 30 -- studs past a prompt's own range where its dot shows
local TEXT_DELAY = 0.1 -- seconds after the key box opens before the text fades in
local FADE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OPEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- the box in each state: gone, the dot (a small plain white circle, round at the owner's wish) and the
-- open key box; the circle squares off as it opens
local LOOK = {
	gone = { size = 0, round = 0.5, back = TEXT, backTransparency = 1, edgeTransparency = 1 },
	dot = { size = DOT_SIZE, round = 0.5, back = TEXT, backTransparency = 0.1, edgeTransparency = 1 },
	open = {
		size = KEY_SIZE,
		round = 0,
		back = Style.ChipBack,
		backTransparency = Style.ChipBackTransparency,
		edgeTransparency = Style.ChipEdgeTransparency,
	},
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

-- the key's name as it reads on the box
local function keyText(prompt)
	local code = prompt.KeyboardKeyCode
	if code == Enum.KeyCode.Unknown then
		return "E"
	end
	local name = UserInputService:GetStringForKeyCode(code)
	return string.upper(name ~= "" and name or code.Name)
end

local prompts = {} -- every prompt in the world, checked each frame for its dot
local shown = {} -- prompt -> true while Roblox shows it (it's in range)
local marks = {} -- prompt -> its dot or key box: { gui, box, corner, edge, fill, pop, action, state, version }

-- the prompt sits on the thing's torso when it has one (an NPC's root is lower than its head,
-- and a prompt parented to the head would float up there), else on what it's parented to
local function anchorOf(prompt)
	local model = prompt:FindFirstAncestorOfClass("Model")
	local torso = model and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart"))
	return torso or prompt.Parent
end

local function positionOf(anchor)
	if anchor:IsA("BasePart") then
		return anchor.Position
	elseif anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor:IsA("Model") then
		return anchor:GetPivot().Position
	end
	return nil
end

local function build(prompt)
	-- the box sits on the anchor's centre, so the dot opens in place; the action goes above it
	local gui = make("BillboardGui", {
		Name = "PromptUI",
		Adornee = anchorOf(prompt),
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(240, KEY_SIZE + 2 * (LABEL_HEIGHT + 6)),
		ResetOnSpawn = false,
		Active = true,
		Parent = playerGui,
	})

	local box = make("TextButton", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = LOOK.gone.back,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Style.MonoFont,
		Text = "",
		TextSize = 24,
		TextColor3 = TEXT,
		TextTransparency = 1,
	})
	local pop = make("UIScale", { Parent = box })
	local corner = make("UICorner", { Parent = box, CornerRadius = UDim.new(LOOK.gone.round, 0) })
	local edge = make("UIStroke", { Parent = box, Color = TEXT, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

	-- fills from the bottom while the key is held
	local fill = make("Frame", {
		Parent = box,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = TEXT,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 0,
	})

	-- the action alone ("Interact", "Talk"), above the box
	local action = make("TextLabel", {
		Parent = gui,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 0.5, -(KEY_SIZE / 2 + 6)),
		Size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
		BackgroundTransparency = 1,
		Font = Style.TitleFont,
		Text = "",
		TextSize = 18,
		TextColor3 = TEXT,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	})

	-- touch and mouse: pressing the open box is pressing the key
	box.InputBegan:Connect(function(input)
		if shown[prompt] and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			prompt:InputHoldBegin()
		end
	end)
	box.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)

	return { gui = gui, box = box, corner = corner, edge = edge, fill = fill, pop = pop, action = action, state = "gone", version = 0 }
end

-- the box's size springs to a look and its colours fade to it
local function shape(mark, look, info)
	TweenService:Create(mark.box, info, { Size = UDim2.fromOffset(look.size, look.size) }):Play()
	TweenService:Create(mark.box, FADE, { BackgroundColor3 = look.back, BackgroundTransparency = look.backTransparency }):Play()
	TweenService:Create(mark.corner, FADE, { CornerRadius = UDim.new(look.round, 0) }):Play()
	TweenService:Create(mark.edge, FADE, { Transparency = look.edgeTransparency }):Play()
end

local function showText(mark, visible)
	TweenService:Create(mark.box, FADE, { TextTransparency = visible and 0 or 1 }):Play()
	TweenService:Create(mark.action, FADE, { TextTransparency = visible and 0 or 1, TextStrokeTransparency = visible and 0.4 or 1 }):Play()
end

-- moves a prompt's mark to "dot", "open" or "gone" (removed once it has faded); the version
-- stops a delayed step from an earlier move
local function setState(prompt, mark, state)
	if mark.state == state then
		return
	end
	mark.state = state
	mark.version += 1
	local version = mark.version
	if state == "open" then
		shape(mark, LOOK.open, OPEN)
		task.delay(TEXT_DELAY, function()
			if mark.version == version then
				showText(mark, true)
			end
		end)
		return
	end
	showText(mark, false)
	TweenService:Create(mark.pop, FADE, { Scale = 1 }):Play()
	TweenService:Create(mark.fill, FADE, { Size = UDim2.fromScale(1, 0) }):Play()
	shape(mark, LOOK[state], CLOSE)
	if state == "gone" then
		task.delay(CLOSE.Time, function()
			if mark.version == version then
				mark.gui:Destroy()
				marks[prompt] = nil
			end
		end)
	end
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	shown[prompt] = true
	local mark = marks[prompt]
	if not mark then
		mark = build(prompt)
		marks[prompt] = mark
	end
	mark.box.Text = inputType == Enum.ProximityPromptInputType.Keyboard and keyText(prompt) or "TAP"
	mark.action.Text = string.upper(prompt.ActionText)
	setState(prompt, mark, "open")
end)

-- back to the dot; the frame loop takes the dot away once it's out of range or switched off
ProximityPromptService.PromptHidden:Connect(function(prompt)
	shown[prompt] = nil
	local mark = marks[prompt]
	if mark then
		setState(prompt, mark, "dot")
	end
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	local mark = shown[prompt] and marks[prompt]
	if mark then
		TweenService:Create(mark.pop, FADE, { Scale = 0.9 }):Play()
	end
	if mark and prompt.HoldDuration > 0 then
		TweenService:Create(mark.fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	end
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	local mark = marks[prompt]
	if mark then
		TweenService:Create(mark.pop, FADE, { Scale = 1 }):Play()
		TweenService:Create(mark.fill, FADE, { Size = UDim2.fromScale(1, 0) }):Play()
	end
end)

-- a custom prompt takes no input by itself: the prompt's own key holds it
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	for prompt in pairs(shown) do
		if prompt.KeyboardKeyCode == input.KeyCode then
			prompt:InputHoldBegin()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	for prompt in pairs(shown) do
		if prompt.KeyboardKeyCode == input.KeyCode then
			prompt:InputHoldEnd()
		end
	end
end)

-- a prompt's dot shows from DOT_RANGE studs past its own range, while the prompt is on
local function wantsDot(prompt, root)
	if not root or not ProximityPromptService.Enabled or not prompt.Enabled or prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return false
	end
	if prompt:IsDescendantOf(root.Parent) then -- the player's own
		return false
	end
	local position = positionOf(anchorOf(prompt))
	return position ~= nil and (position - root.Position).Magnitude <= prompt.MaxActivationDistance + DOT_RANGE
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for prompt in pairs(prompts) do
		if shown[prompt] then
			continue -- open; PromptHidden closes it
		end
		local mark = marks[prompt]
		if wantsDot(prompt, root) then
			if not mark then
				mark = build(prompt)
				marks[prompt] = mark
			end
			setState(prompt, mark, "dot")
		elseif mark then
			setState(prompt, mark, "gone")
		end
	end
end)

-- every prompt, now and as the world streams in, draws as Custom
local function adopt(instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
		prompts[instance] = true
	end
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	adopt(descendant)
end
workspace.DescendantAdded:Connect(adopt)

-- a prompt that streams out or is removed takes its mark with it
workspace.DescendantRemoving:Connect(function(instance)
	if not prompts[instance] then
		return
	end
	prompts[instance] = nil
	shown[instance] = nil
	local mark = marks[instance]
	if mark then
		mark.version += 1
		mark.gui:Destroy()
		marks[instance] = nil
	end
end)
