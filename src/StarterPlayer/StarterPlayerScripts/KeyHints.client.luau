-- Key hints, bottom left: plain text, one line per basic move, a small white
-- key cap then the move's name. Dash and Block show the player's own keys
-- (Keybinds, so a rebind updates it), and Dash the set's own dash name when
-- the set in hand has one unlocked (Lightstep). RMB Aim shows only while
-- holding a set with a ranged move. Space, Shift and Ctrl are fixed. The
-- Key hints setting (Preferences) turns the panel off. Touch-only devices
-- have no keys, so they don't get it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local player = Players.LocalPlayer

local LINE_HEIGHT = 20
local CHECK_SPACING = 0.25 -- seconds between looks at what's in hand
local TEXT = Color3.new(1, 1, 1)
local KEYCAP_TEXT = Color3.fromRGB(20, 20, 28)

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
	Name = "KeyHints",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local list = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, HudConfig.EdgeMargin, 1, -HudConfig.EdgeMargin),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1,
})
make("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) })

local function line(order, key, name)
	local row = make("Frame", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, LINE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	})
	make("UIListLayout", {
		Parent = row,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	local cap = make("TextLabel", {
		Parent = row,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = TEXT,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = key,
		TextSize = 11,
		TextColor3 = KEYCAP_TEXT,
	})
	make("UIPadding", { Parent = cap, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	make("TextLabel", {
		Parent = row,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = name,
		TextSize = 13,
		TextColor3 = TEXT,
		TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	})
end

-- the lines for what's in hand, as { key, name } pairs top to bottom
local function hints()
	local _, setName = SkillSetConfig.Equipped(player.Character)
	local set = setName and SkillSetConfig.Sets[setName]
	local dashName = "Dash"
	if set and set.dash and SkillSetConfig.FeatureUnlocked(player, setName, "dash") then
		dashName = set.dash.name or dashName
	end
	local result = { { Keybinds.Text("Dash"), dashName } }
	if Keybinds.Current().Block then
		table.insert(result, { Keybinds.Text("Block"), "Block / Parry" })
	end
	if set and set.ranged then
		table.insert(result, { "RMB", "Aim" })
	end
	table.insert(result, { "Space", "Double jump" })
	table.insert(result, { "Shift", "Sprint" })
	table.insert(result, { "Ctrl", "Shift lock" })
	return result
end

local shown -- the signature of the lines drawn, so they're rebuilt only when they change

local function refresh()
	local visible = Preferences.Get("KeyHints") and (UserInputService.KeyboardEnabled or not UserInputService.TouchEnabled)
	list.Visible = visible
	if not visible then
		return
	end
	local lines = hints()
	local parts = {}
	for _, entry in ipairs(lines) do
		table.insert(parts, entry[1] .. "=" .. entry[2])
	end
	local signature = table.concat(parts, "|")
	if signature == shown then
		return
	end
	shown = signature
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, entry in ipairs(lines) do
		line(i, entry[1], entry[2])
	end
end

Keybinds.Changed(refresh)
Preferences.Changed(refresh)
-- what's in hand changes with equipping, putting away and mastery: look now and then
local since = 0
RunService.Heartbeat:Connect(function(dt)
	since += dt
	if since >= CHECK_SPACING then
		since = 0
		refresh()
	end
end)
refresh()
