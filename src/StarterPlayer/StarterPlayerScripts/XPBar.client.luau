-- XP to the next level, bottom left under the equipment cards, in line with the key
-- hints: "LV 12" and "340 / 700 XP" over a thin bar, white, flashing gold on a level
-- up; full with "MAX" at the cap. Reads the Level and XP attributes (PlayerStats) and
-- StatConfig.XPToLevelUp. Plain white text with a dark stroke, square.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local HudRules = require(ReplicatedStorage:WaitForChild("HudRules"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))

local player = Players.LocalPlayer

local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(190, 190, 198)
local GOLD = Color3.fromRGB(255, 205, 60)
local BAR_HEIGHT = 3

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
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextStrokeColor3 = Color3.new(0, 0, 0)
	props.TextStrokeTransparency = 0.3
	return make("TextLabel", props)
end

-- 12345 -> "12,345"
local function commas(n)
	local s = tostring(math.floor(n))
	repeat
		local count
		s, count = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return s
end

local gui = make("ScreenGui", {
	Name = "XPBar",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local row = make("Frame", {
	Name = "Row",
	Parent = gui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, HudConfig.EdgeMargin, 1, -HudConfig.EdgeMargin),
	Size = UDim2.fromOffset(HudConfig.SideWidth, HudConfig.HintsHeight),
	BackgroundTransparency = 1,
	Visible = false,
})
local levelLabel = text(row, {
	Size = UDim2.new(0.5, 0, 0, 12),
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local amountLabel = text(row, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.5, 0, 0, 12),
	TextSize = 11,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local back = make("Frame", {
	Parent = row,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
})
local fill = make("Frame", {
	Parent = back,
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
})

local shownLevel = nil
local function update()
	local level = player:GetAttribute("Level")
	local xp = player:GetAttribute("XP")
	if typeof(level) ~= "number" or typeof(xp) ~= "number" then
		return -- not loaded yet
	end
	row.Visible = true
	local capped = level >= StatConfig.MaxLevel
	local need = StatConfig.XPToLevelUp(level)
	local fraction = HudRules.XPFraction(xp, need, capped)
	levelLabel.Text = "LV " .. level
	amountLabel.Text = capped and "MAX" or string.format("%s / %s XP", commas(xp), commas(need))
	if shownLevel and level > shownLevel then
		-- a level up: start the new bar from where it is, and flash gold
		fill.Size = UDim2.fromScale(fraction, 1)
		fill.BackgroundColor3 = GOLD
		levelLabel.TextColor3 = GOLD
		TweenService:Create(fill, TweenInfo.new(1.2), { BackgroundColor3 = TEXT }):Play()
		TweenService:Create(levelLabel, TweenInfo.new(1.2), { TextColor3 = TEXT }):Play()
	else
		TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) }):Play()
	end
	shownLevel = level
end

player:GetAttributeChangedSignal("Level"):Connect(update)
player:GetAttributeChangedSignal("XP"):Connect(update)
update()
