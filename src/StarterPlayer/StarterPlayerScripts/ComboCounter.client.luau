-- The combo counter: right side, above the bounty and party cards, counting the hits
-- you land (Damage.Deal adds to your HitsLanded attribute; a status tick isn't a hit).
-- It shows from HudConfig.ComboMin hits, pops on each one, steps colour at
-- HudConfig.ComboTiers and fades HudConfig.ComboWindow seconds after the last hit.
-- Plain white text with a dark stroke.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local HudRules = require(ReplicatedStorage:WaitForChild("HudRules"))

local player = Players.LocalPlayer

local POP_SCALE = 1.3
local FADE_TIME = 0.4

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

local function text(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = 1
	props.Font = Enum.Font.Highway
	props.TextColor3 = Color3.new(1, 1, 1)
	props.TextStrokeColor3 = Color3.new(0, 0, 0)
	props.TextXAlignment = Enum.TextXAlignment.Right
	props.TextTransparency = 1
	props.TextStrokeTransparency = 1
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "ComboCounter",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local holder = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -HudConfig.EdgeMargin, 0.32, 0),
	Size = UDim2.fromOffset(160, 62),
	BackgroundTransparency = 1,
})
local pop = make("UIScale", { Parent = holder })
local countLabel = text(holder, { Size = UDim2.new(1, 0, 0, 44), TextSize = 44 })
local hitsLabel = text(holder, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 16), TextSize = 14, Text = "HITS" })

local combo = 0
local lastHitAt = -math.huge
local shown = 0 -- bumps on every hit, so only the newest hit's fade runs

local function fade()
	local info = TweenInfo.new(FADE_TIME)
	for _, label in ipairs({ countLabel, hitsLabel }) do
		TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
end

local function show()
	shown += 1
	local mine = shown
	local tier = HudConfig.ComboTiers[HudRules.ComboTier(HudConfig.ComboTiers, combo)]
	countLabel.Text = tostring(combo)
	for _, label in ipairs({ countLabel, hitsLabel }) do
		label.TextColor3 = tier.color
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0.3
	end
	pop.Scale = POP_SCALE
	TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(HudConfig.ComboWindow, function()
		if shown == mine then
			fade()
		end
	end)
end

-- several hits can land in one frame and arrive as one change, so count the difference
local lastTotal = player:GetAttribute("HitsLanded") or 0
player:GetAttributeChangedSignal("HitsLanded"):Connect(function()
	local total = player:GetAttribute("HitsLanded") or 0
	local gained = total - lastTotal
	lastTotal = total
	if gained <= 0 then
		return
	end
	if os.clock() - lastHitAt > HudConfig.ComboWindow then
		combo = 0
	end
	combo += gained
	lastHitAt = os.clock()
	if combo >= HudConfig.ComboMin then
		show()
	end
end)
