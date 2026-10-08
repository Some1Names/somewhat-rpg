-- Admin panel, shown only to admins (the AdminServer script decides who and
-- checks every request). Press ` or click ADMIN to change any player's XP,
-- level, stat points, stats and mastery, reset their skill cooldowns, give
-- them a skill set, heal or respawn them, or put status effects on them (or
-- the NPC nearest them). The overcharge and reset
-- cooldowns buttons each have a key box: click it and press a key, and that
-- key does the action on yourself from then on, panel open or not
-- (Backspace clears it, Escape cancels). Binds are kept in the saved
-- AdminKeybinds attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))
local adminAction = ReplicatedStorage:WaitForChild("AdminAction")

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.Backquote
local PANEL_WIDTH = 320
local PADDING = 14
local ROW_HEIGHT = 28
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local DANGER = Color3.fromRGB(226, 75, 74)
local GOLD = Color3.fromRGB(255, 205, 60)
local CONFIRM_TIME = 3 -- seconds a risky button waits for its second click
local KEY_BOX_WIDTH = 64
-- keys the game already uses, which can't be bound
local TAKEN_KEYS = {}
for _, name in ipairs({
	"W", "A", "S", "D", "Space", "LeftShift", "RightShift", "Q", "E", "R", "Z", "X", "C", "V", "F", "G", "B", "M",
	"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero",
	"Backquote", "Tab", "Slash", "Return", "Escape", "Backspace",
}) do
	TAKEN_KEYS[name] = true
end

if player:GetAttribute("IsAdmin") == nil then
	player:GetAttributeChangedSignal("IsAdmin"):Wait()
end
if not player:GetAttribute("IsAdmin") then
	return
end

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

local function outline(parent, transparency, color)
	return make("UIStroke", {
		Parent = parent,
		Color = color or TEXT,
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
	props.TextTruncate = Enum.TextTruncate.AtEnd
	return make("TextLabel", props)
end

local function button(parent, text, props)
	props.Parent = parent
	props.BackgroundColor3 = props.BackgroundColor3 or TEXT
	props.Font = Enum.Font.GothamBold
	props.Text = text
	props.TextSize = 12
	props.TextColor3 = props.TextColor3 or BACKGROUND
	local instance = make("TextButton", props)
	return instance
end

local gui = make("ScreenGui", {
	Name = "AdminPanel",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- ADMIN button under the STATS, INFO (StatsMenu) and INVENTORY (Inventory) buttons
local toggle = make("TextButton", {
	Name = "Toggle",
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 108),
	Size = UDim2.fromOffset(64, 28),
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.25,
	Font = Enum.Font.GothamBold,
	Text = "ADMIN",
	TextSize = 11,
	TextColor3 = TEXT,
})
outline(toggle, 0.5)

-- on the right, so it can sit open next to the stats menu
local panel = make("Frame", {
	Name = "Panel",
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
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
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })

local order = 0
local function section(height)
	order += 1
	return make("Frame", {
		Parent = panel,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	})
end

local function heading(text)
	label(section(18), { Text = text, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromScale(1, 1) })
end

-- header
local header = section(22)
label(header, { Text = "ADMIN", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, -30, 1, 0) })
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

-- which player the panel acts on
local targetRow = section(26)
local previous = button(targetRow, "‹", { Size = UDim2.fromOffset(26, 26), TextColor3 = TEXT, BackgroundTransparency = 1 })
outline(previous, 0.5)
local nextButton = button(targetRow, "›", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(26, 26),
	TextColor3 = TEXT,
	BackgroundTransparency = 1,
})
outline(nextButton, 0.5)
local targetName = label(targetRow, {
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(32, 0),
	Size = UDim2.new(1, -64, 1, 0),
})
local summary = label(section(14), { TextSize = 11, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })

local statusLabel -- created last so it sits at the bottom
local function setStatus(text, failed)
	statusLabel.Text = text
	statusLabel.TextColor3 = failed and DANGER or MUTED
end

local targetUserId = player.UserId

local function currentTarget()
	return Players:GetPlayerByUserId(targetUserId)
end

local function run(action, ...)
	local target = currentTarget()
	if not target then
		setStatus("That player has left", true)
		return
	end
	local ok, success, message = pcall(adminAction.InvokeServer, adminAction, action, target.UserId, ...)
	if not ok then
		setStatus("Request failed: " .. tostring(success), true)
		return
	end
	setStatus(message, not success)
end

-- a label, a number box and a button that sends the number; with a
-- `maxValue`, also a Max button that sends that straight away
local function inputRow(labelText, buttonText, submit, maxValue)
	local row = section(ROW_HEIGHT)
	local boxWidth = maxValue and 64 or 84
	local labelRoom = 78 + boxWidth + (maxValue and 44 or 8)
	local name = label(row, { Text = labelText, TextSize = 13, Size = UDim2.new(1, -labelRoom, 1, 0) })
	local box = make("TextBox", {
		Parent = row,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -78, 0.5, 0),
		Size = UDim2.fromOffset(boxWidth, 26),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = TEXT,
		PlaceholderText = "0",
		PlaceholderColor3 = MUTED,
		Text = "",
		ClearTextOnFocus = false,
	})
	local go = button(row, buttonText, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(70, 26),
	})
	local function send()
		local value = tonumber(box.Text)
		if not value then
			setStatus("Enter a number for " .. labelText, true)
			return
		end
		submit(value)
	end
	go.Activated:Connect(send)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			send()
		end
	end)
	if maxValue then
		local max = button(row, "Max", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(82 + boxWidth), 0.5, 0),
			Size = UDim2.fromOffset(36, 26),
			BackgroundTransparency = 1,
			TextColor3 = TEXT,
		})
		outline(max, 0.5)
		max.Activated:Connect(function()
			box.Text = tostring(maxValue)
			submit(maxValue)
		end)
	end
	return name
end

heading("PROGRESS")
inputRow("XP", "Give", function(value)
	run("GiveXP", value)
end)
inputRow("Yen", "Give", function(value)
	run("GiveYen", value)
end)
inputRow("Level", "Set", function(value)
	run("SetLevel", value)
end, StatConfig.MaxLevel)
inputRow("Stat points", "Set", function(value)
	run("SetPoints", value)
end)

heading("STATS")
local statLabels = {}
for _, stat in ipairs(StatConfig.Stats) do
	statLabels[stat.key] = inputRow(stat.key, "Set", function(value)
		run("SetStat", stat.key, value)
	end)
end

heading("MASTERY")
local masteryLabels = {}
for setName in pairs(SkillSetConfig.Sets) do
	masteryLabels[setName] = inputRow(setName .. " mastery", "Set", function(value)
		run("SetMastery", setName, value)
	end, SkillSetConfig.MaxMastery)
end

-- Key binds: bind id ("ResetCooldowns", "Overcharge:Mandela") -> key name,
-- read from and saved to the AdminKeybinds attribute as "id=Key,id=Key"
local hotkeys = {} -- bind id -> { name, action, args }
local binds = {}
local keyBoxes = {} -- bind id -> its button
local capturing -- the bind id waiting for a key press

local function loadBinds()
	binds = {}
	for id, key in string.gmatch(player:GetAttribute("AdminKeybinds") or "", "([%w:]+)=(%w+)") do
		if hotkeys[id] and pcall(function()
			return Enum.KeyCode[key]
		end) then
			binds[id] = key
		end
	end
end

local function showBinds()
	for id, box in pairs(keyBoxes) do
		if capturing == id then
			box.Text = "Press a key…"
			box.TextColor3 = GOLD
		else
			box.Text = binds[id] or "none"
			box.TextColor3 = binds[id] and TEXT or MUTED
		end
	end
end

local function saveBinds()
	local parts = {}
	for id, key in pairs(binds) do
		table.insert(parts, id .. "=" .. key)
	end
	table.sort(parts)
	local ok, success, message = pcall(adminAction.InvokeServer, adminAction, "SetKeybinds", player.UserId, table.concat(parts, ","))
	if not ok or not success then
		setStatus("Couldn't save the key: " .. tostring(ok and message or success), true)
	end
end

-- a small box after a button: click, then press the key to bind
local function keyBox(row, id, name, action, ...)
	hotkeys[id] = { name = name, action = action, args = { ... } }
	local box = button(row, "none", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, KEY_BOX_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		TextColor3 = MUTED,
	})
	outline(box, 0.5)
	box.Activated:Connect(function()
		capturing = capturing ~= id and id or nil
		showBinds()
		setStatus(capturing and "Press a key for " .. name .. " (Backspace clears, Escape cancels)" or "")
	end)
	keyBoxes[id] = box
end

heading("SKILLS  ·  KEY BINDS ACT ON YOU")
for setName, set in pairs(SkillSetConfig.Sets) do
	if set.overcharge then
		local row = section(ROW_HEIGHT)
		button(row, "Overcharge " .. setName, { Size = UDim2.new(1, -(KEY_BOX_WIDTH + 4), 1, 0) }).Activated:Connect(function()
			run("Overcharge", setName)
		end)
		keyBox(row, "Overcharge:" .. setName, "Overcharge " .. setName, "Overcharge", setName)
	end
end
local resetRow = section(ROW_HEIGHT)
button(resetRow, "Reset cooldowns", { Size = UDim2.new(1, -(KEY_BOX_WIDTH + 4), 1, 0) }).Activated:Connect(function()
	run("ResetCooldowns")
end)
keyBox(resetRow, "ResetCooldowns", "Reset cooldowns", "ResetCooldowns")
loadBinds()
showBinds()
player:GetAttributeChangedSignal("AdminKeybinds"):Connect(function()
	loadBinds()
	showBinds()
end)

-- swaps the player's power (or weapon) for that set
heading("GIVE SET")
local setNames = {}
for setName in pairs(SkillSetConfig.Sets) do
	table.insert(setNames, setName)
end
table.sort(setNames)
for _, setName in ipairs(setNames) do
	button(section(ROW_HEIGHT), SkillSetConfig.Sets[setName].tool, { Size = UDim2.fromScale(1, 1) }).Activated:Connect(function()
		run("GiveSet", setName)
	end)
end

heading("CHARACTER")
local characterRow = section(ROW_HEIGHT)
for i, entry in ipairs({ { "Reset stats", "ResetStats" }, { "Heal", "Heal" }, { "Respawn", "Respawn" } }) do
	local action = entry[2]
	button(characterRow, entry[1], {
		Position = UDim2.new((i - 1) / 3, i == 1 and 0 or 3, 0, 0),
		Size = UDim2.new(1 / 3, -4, 1, 0),
	}).Activated:Connect(function()
		run(action)
	end)
end

-- pick an effect, then put a stack of it on the player or the NPC nearest them
heading("STATUS EFFECTS")
local effectRow = section(ROW_HEIGHT)
local effectButtons = {}
local chosenEffect = StatusConfig.Order[1]
local function showChosenEffect()
	for name, effectButton in pairs(effectButtons) do
		local chosen = name == chosenEffect
		effectButton.BackgroundColor3 = StatusConfig.Effects[name].color
		effectButton.BackgroundTransparency = chosen and 0 or 0.7
		effectButton.TextColor3 = TEXT
		effectButton.TextTransparency = chosen and 0 or 0.35
	end
end
local effectCount = #StatusConfig.Order
for i, name in ipairs(StatusConfig.Order) do
	local effectButton = button(effectRow, name, {
		Position = UDim2.new((i - 1) / effectCount, i == 1 and 0 or 3, 0, 0),
		Size = UDim2.new(1 / effectCount, -4, 1, 0),
	})
	effectButtons[name] = effectButton
	effectButton.Activated:Connect(function()
		chosenEffect = name
		showChosenEffect()
	end)
end
showChosenEffect()
local statusRow = section(ROW_HEIGHT)
for i, entry in ipairs({
	{ "On player", "ApplyStatus", "player" },
	{ "On nearest NPC", "ApplyStatus", "npc" },
	{ "Clear both", "ClearStatus" },
}) do
	button(statusRow, entry[1], {
		Position = UDim2.new((i - 1) / 3, i == 1 and 0 or 3, 0, 0),
		Size = UDim2.new(1 / 3, -4, 1, 0),
	}).Activated:Connect(function()
		if entry[2] == "ApplyStatus" then
			run("ApplyStatus", chosenEffect, entry[3])
		else
			run("ClearStatus")
		end
	end)
end

-- wiping progress takes a second click
local resetAll = button(section(ROW_HEIGHT), "Reset all progress", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	TextColor3 = DANGER,
})
outline(resetAll, 0.3, DANGER)
local armedUntil = 0
resetAll.Activated:Connect(function()
	if os.clock() < armedUntil then
		armedUntil = 0
		resetAll.Text = "Reset all progress"
		run("ResetProgress")
		return
	end
	armedUntil = os.clock() + CONFIRM_TIME
	resetAll.Text = "Click again to reset to level 1"
	task.delay(CONFIRM_TIME, function()
		if os.clock() >= armedUntil then
			resetAll.Text = "Reset all progress"
		end
	end)
end)

statusLabel = label(section(16), { Text = "", TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromScale(1, 1) })

-- show the target's current numbers, kept live as they change
local function showTarget()
	local target = currentTarget() or player
	targetName.Text = target.DisplayName .. "  @" .. target.Name
	local level = target:GetAttribute("Level")
	if not level then
		summary.Text = "Stats loading…"
	else
		local xpText = level >= StatConfig.MaxLevel and "max level"
			or string.format("%d / %d XP", target:GetAttribute("XP") or 0, StatConfig.XPToLevelUp(level))
		summary.Text = string.format("Lv %d  ·  %s  ·  %d points  ·  ¥%d", level, xpText, target:GetAttribute("StatPoints") or 0, target:GetAttribute("Yen") or 0)
	end
	for key, nameLabel in pairs(statLabels) do
		nameLabel.Text = string.format("%s  (%d)", key, target:GetAttribute(key) or 0)
	end
	for setName, nameLabel in pairs(masteryLabels) do
		local mastery = target:GetAttribute(SkillSetConfig.MasteryAttribute(setName)) or 1
		nameLabel.Text = string.format("%s  (%d)", setName, mastery)
	end
end

local targetConnection
local function selectTarget(target)
	targetUserId = target.UserId
	if targetConnection then
		targetConnection:Disconnect()
	end
	targetConnection = target.AttributeChanged:Connect(showTarget)
	showTarget()
end

local function step(direction)
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)
	local index = table.find(list, currentTarget()) or 1
	selectTarget(list[(index - 1 + direction) % #list + 1])
	setStatus("")
end

previous.Activated:Connect(function()
	step(-1)
end)
nextButton.Activated:Connect(function()
	step(1)
end)
Players.PlayerRemoving:Connect(function(leaving)
	if leaving.UserId == targetUserId then
		selectTarget(player)
	end
end)
selectTarget(player)

local function setOpen(open)
	panel.Visible = open
end
toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	-- binding a key: the next key press is it
	if capturing then
		local id = capturing
		local key = input.KeyCode.Name
		if input.KeyCode == Enum.KeyCode.Escape then
			setStatus("")
		elseif input.KeyCode == Enum.KeyCode.Backspace then
			binds[id] = nil
			saveBinds()
			setStatus(hotkeys[id].name .. " key cleared")
		elseif TAKEN_KEYS[key] or input.KeyCode == TOGGLE_KEY then
			setStatus(key .. " is taken by the game, pick another", true)
			return -- still waiting
		else
			-- one key, one action: it moves off whatever had it
			for other, otherKey in pairs(binds) do
				if otherKey == key then
					binds[other] = nil
				end
			end
			binds[id] = key
			saveBinds()
			setStatus(hotkeys[id].name .. " is on " .. key)
		end
		capturing = nil
		showBinds()
		return
	end
	if gameProcessed then
		return
	end
	if input.KeyCode == TOGGLE_KEY then
		setOpen(not panel.Visible)
		return
	end
	-- a bound key: its action, on yourself
	for id, key in pairs(binds) do
		if input.KeyCode.Name == key then
			local hotkey = hotkeys[id]
			local ok, success, message = pcall(adminAction.InvokeServer, adminAction, hotkey.action, player.UserId, table.unpack(hotkey.args))
			setStatus(ok and message or "Request failed", not (ok and success))
			return
		end
	end
end)
