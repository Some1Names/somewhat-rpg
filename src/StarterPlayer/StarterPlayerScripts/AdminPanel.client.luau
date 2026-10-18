-- Admin panel, shown only to admins (the AdminServer script decides who and
-- checks every request). Press ` or the top bar's Admin icon (TopBar) to open it.
-- The player it acts on is picked at the top (a list of everyone in the server),
-- with their live numbers under it, and every result shows in the status line
-- at the bottom. The rest is in four tabs:
--   PLAYER  XP, yen, level, stat points, materials, stats, resets
--   POWERS  give a skill set, mastery, overcharge and reset cooldowns
--   STATUS  status effects (on the player or the NPC nearest them), heal, respawn
--   WORLD   the time of day, and freezing it
-- The overcharge and reset cooldowns buttons each have a key box: click it and press a key, and that
-- key does the action on yourself from then on, panel open or not
-- (Backspace clears it, Escape cancels). Binds are kept in the saved
-- AdminKeybinds attribute.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Menus = require(script.Parent:WaitForChild("Menus"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))
local adminAction = ReplicatedStorage:WaitForChild("AdminAction")

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.Backquote
local PANEL_WIDTH = 400
local PANEL_HEIGHT = 540 -- shorter when the screen is
local PANEL_MIN_HEIGHT = 300
local PANEL_TOP = 12 -- px under the top bar, like Menus.Fit
local PADDING = 14
local ROW_HEIGHT = 28
local GAP = 4 -- between buttons side by side
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local DANGER = Color3.fromRGB(226, 75, 74)
local GOLD = Color3.fromRGB(255, 205, 60)
local CONFIRM_TIME = 3 -- seconds a risky button waits for its second click
local KEY_BOX_WIDTH = 64
-- vertical layout inside the panel (below the padding)
local TARGET_Y = 28
local SUMMARY_Y = 62
local TABS_Y = 82
local CONTENT_Y = 118
local STATUS_HEIGHT = 18
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
	props.Font = props.Font or Enum.Font.Highway
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextTruncate = Enum.TextTruncate.AtEnd
	return make("TextLabel", props)
end

local function button(parent, text, props)
	props.Parent = parent
	props.BackgroundColor3 = props.BackgroundColor3 or TEXT
	props.Font = Enum.Font.Highway
	props.Text = text
	props.TextSize = 12
	props.TextColor3 = props.TextColor3 or BACKGROUND
	props.AutoButtonColor = false
	local instance = make("TextButton", props)
	return instance
end

-- position and size of cell `i` of `n` side by side with GAP between
local function cell(n, i)
	return UDim2.new((i - 1) / n, (i - 1) * GAP / n, 0, 0), UDim2.new(1 / n, -GAP * (n - 1) / n, 1, 0)
end

local gui = make("ScreenGui", {
	Name = "AdminPanel",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- at the right edge (it's too tall to centre above the skill bar); only one menu is open at a time
local panel = make("Frame", {
	Name = "Panel",
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
	BorderSizePixel = 0,
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

-- the free space under the top bar: as tall as PANEL_HEIGHT, or as the space allows
local function fitPanel()
	local screen = gui.AbsoluteSize.Y
	if screen <= 0 then -- a disabled ScreenGui reports 0, so ask the camera
		screen = workspace.CurrentCamera.ViewportSize.Y - GuiService:GetGuiInset().Y
	end
	screen /= UIScale.Get() -- real pixels to UI pixels
	local available = screen - PANEL_TOP - HudConfig.BottomReserve
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, math.min(PANEL_HEIGHT, math.max(available, PANEL_MIN_HEIGHT)))
	panel.Position = UDim2.new(1, -HudConfig.EdgeMargin, 0, PANEL_TOP + available / 2)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
UIScale.OnChange(fitPanel)
fitPanel()

-- header
local header = make("Frame", { Parent = panel, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
label(header, { Text = "ADMIN", Font = Enum.Font.Highway, TextSize = 16, Size = UDim2.new(1, -30, 1, 0) })
local closeButton = make("TextButton", {
	Parent = header,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.Highway,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
})

-- the status line, pinned under everything so a result is never off-screen
local statusLabel = label(panel, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, STATUS_HEIGHT),
	Text = "",
	TextSize = 11,
	TextColor3 = MUTED,
})
local function setStatus(text, failed)
	statusLabel.Text = text
	statusLabel.TextColor3 = failed and DANGER or MUTED
end

-- which player the panel acts on: a button that opens the list of players
local targetButton = button(panel, "", {
	Position = UDim2.fromOffset(0, TARGET_Y),
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
	TextColor3 = TEXT,
	TextSize = 13,
})
outline(targetButton, 0.5)
local summary = label(panel, {
	Position = UDim2.fromOffset(0, SUMMARY_Y),
	Size = UDim2.new(1, 0, 0, 14),
	TextSize = 11,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Center,
})

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

-- tabs: each is a scrolling page; `page` is the one being built
local TAB_NAMES = { "PLAYER", "POWERS", "STATUS", "WORLD" }
local pages = {}
local tabButtons = {}
local activeTab = TAB_NAMES[1] -- kept while the game runs, so the panel reopens where it was
local page
local order = 0

for _, name in ipairs(TAB_NAMES) do
	local scroller = make("ScrollingFrame", {
		Name = name,
		Parent = panel,
		Position = UDim2.fromOffset(0, CONTENT_Y),
		Size = UDim2.new(1, 0, 1, -(CONTENT_Y + STATUS_HEIGHT + 6)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = MUTED,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Visible = false,
	})
	make("UIPadding", { Parent = scroller, PaddingRight = UDim.new(0, 10) })
	make("UIListLayout", { Parent = scroller, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
	pages[name] = scroller
end

local function showTab()
	for name, scroller in pairs(pages) do
		scroller.Visible = name == activeTab
		local tab = tabButtons[name]
		local active = name == activeTab
		tab.BackgroundTransparency = active and 0 or 1
		tab.TextColor3 = active and BACKGROUND or MUTED
	end
end

for i, name in ipairs(TAB_NAMES) do
	local position, size = cell(#TAB_NAMES, i)
	local tab = button(panel, name, {
		Position = position + UDim2.fromOffset(0, TABS_Y),
		Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 28),
		TextSize = 11,
	})
	outline(tab, 0.5)
	tab.Activated:Connect(function()
		activeTab = name
		showTab()
	end)
	tabButtons[name] = tab
end

local function section(height)
	order += 1
	return make("Frame", {
		Parent = page,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	})
end

local function heading(text)
	label(section(18), { Text = text, Font = Enum.Font.Highway, TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromScale(1, 1) })
end

-- a row of equal buttons: entries are { text, function }
local function buttonRow(entries, height, filled)
	local row = section(height or ROW_HEIGHT)
	local buttons = {}
	for i, entry in ipairs(entries) do
		local position, size = cell(#entries, i)
		local instance = button(row, entry[1], {
			Position = position,
			Size = size,
			BackgroundTransparency = filled and 0 or 1,
			TextColor3 = filled and BACKGROUND or TEXT,
		})
		if not filled then
			outline(instance, 0.5)
		end
		instance.Activated:Connect(entry[2])
		buttons[i] = instance
	end
	return buttons
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
		Font = Enum.Font.Highway,
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

-- quick amounts under a row: one click gives that much
local function quickRow(amounts, give)
	local entries = {}
	for _, amount in ipairs(amounts) do
		table.insert(entries, {
			"+" .. (amount >= 1000 and (amount / 1000) .. "k" or amount),
			function()
				give(amount)
			end,
		})
	end
	buttonRow(entries, 24)
end

local setNames = {}
for setName in pairs(SkillSetConfig.Sets) do
	table.insert(setNames, setName)
end
table.sort(setNames)

-- PLAYER
page = pages.PLAYER
heading("PROGRESS")
inputRow("XP", "Give", function(value)
	run("GiveXP", value)
end)
quickRow({ 100, 1000, 10000 }, function(amount)
	run("GiveXP", amount)
end)
inputRow("Yen", "Give", function(value)
	run("GiveYen", value)
end)
quickRow({ 1000, 10000, 100000 }, function(amount)
	run("GiveYen", amount)
end)
inputRow("Level", "Set", function(value)
	run("SetLevel", value)
end, StatConfig.MaxLevel)
inputRow("Stat points", "Set", function(value)
	run("SetPoints", value)
end)
buttonRow({ { "Materials +50 each", function()
	run("GiveMaterials")
end } })

heading("STATS")
local statLabels = {}
for _, stat in ipairs(StatConfig.Stats) do
	statLabels[stat.key] = inputRow(stat.key, "Set", function(value)
		run("SetStat", stat.key, value)
	end)
end
buttonRow({ { "Refund stat points", function()
	run("ResetStats")
end } })

-- wiping progress takes a second click
heading("DANGER")
local resetAll = buttonRow({ { "Reset all progress", function() end } })[1]
resetAll.TextColor3 = DANGER
resetAll.UIStroke.Color = DANGER
resetAll.UIStroke.Transparency = 0.3
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

-- POWERS
page = pages.POWERS
-- swaps the player's power (or weapon) for that set, two to a row
heading("GIVE SET")
for i = 1, #setNames, 2 do
	local entries = {}
	for _, setName in ipairs({ setNames[i], setNames[i + 1] }) do
		table.insert(entries, { SkillSetConfig.Sets[setName].tool, function()
			run("GiveSet", setName)
		end })
	end
	buttonRow(entries, ROW_HEIGHT, true)
end

heading("MASTERY")
local masteryLabels = {}
for _, setName in ipairs(setNames) do
	masteryLabels[setName] = inputRow(setName .. " mastery", "Set", function(value)
		run("SetMastery", setName, value)
	end, SkillSetConfig.MaxMastery)
end

heading("OVERCHARGE AND COOLDOWNS  ·  KEY BINDS ACT ON YOU")
for _, setName in ipairs(setNames) do
	if SkillSetConfig.Sets[setName].overcharge then
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

-- STATUS: pick an effect, then put a stack of it on the player or the NPC nearest them
page = pages.STATUS
heading("EFFECT")
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
local effectEntries = {}
for _, name in ipairs(StatusConfig.Order) do
	table.insert(effectEntries, { name, function()
		chosenEffect = name
		showChosenEffect()
	end })
end
for i, effectButton in ipairs(buttonRow(effectEntries, ROW_HEIGHT, true)) do
	effectButtons[StatusConfig.Order[i]] = effectButton
end
showChosenEffect()
heading("APPLY")
buttonRow({
	{ "On player", function()
		run("ApplyStatus", chosenEffect, "player")
	end },
	{ "On nearest NPC", function()
		run("ApplyStatus", chosenEffect, "npc")
	end },
	{ "Clear both", function()
		run("ClearStatus")
	end },
})
heading("CHARACTER")
buttonRow({
	{ "Heal", function()
		run("Heal")
	end },
	{ "Respawn", function()
		run("Respawn")
	end },
})

-- WORLD: the time is the world's, whoever the panel's player is
page = pages.WORLD
heading("TIME OF DAY")
inputRow("Time (0-24)", "Set", function(value)
	run("SetTime", value)
end)
local presets = {}
for _, preset in ipairs({ { "Dawn", 6 }, { "Noon", 12 }, { "Dusk", 18 }, { "Midnight", 0 } }) do
	table.insert(presets, { preset[1], function()
		run("SetTime", preset[2])
	end })
end
buttonRow(presets)
local freezeButton = buttonRow({ { "Freeze time", function()
	run("FreezeTime")
end } })[1]
local function showFrozen()
	freezeButton.Text = ReplicatedStorage:GetAttribute("DayFrozen") and "Resume time" or "Freeze time"
end
showFrozen()
ReplicatedStorage:GetAttributeChangedSignal("DayFrozen"):Connect(showFrozen)

showTab()

-- show the target's current numbers, kept live as they change
local function showTarget()
	local target = currentTarget() or player
	targetButton.Text = target.DisplayName .. "  @" .. target.Name .. "  ▾"
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

-- the player list, over the tabs, opened by the target button
local PICK_HEIGHT = 26
local picker = make("ScrollingFrame", {
	Name = "Picker",
	Parent = panel,
	Position = UDim2.fromOffset(0, TARGET_Y + 30),
	Size = UDim2.new(1, 0, 0, PICK_HEIGHT),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MUTED,
	BorderSizePixel = 0,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0,
	ZIndex = 5,
	Visible = false,
})
outline(picker, 0.4)
make("UIListLayout", { Parent = picker, SortOrder = Enum.SortOrder.LayoutOrder })

local function closePicker()
	picker.Visible = false
end

local function openPicker()
	for _, child in ipairs(picker:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)
	for i, listed in ipairs(list) do
		local text = listed.DisplayName .. "  @" .. listed.Name .. (listed == player and "  (you)" or "")
		local entry = button(picker, text, {
			LayoutOrder = i,
			Size = UDim2.new(1, -6, 0, PICK_HEIGHT),
			BackgroundTransparency = listed.UserId == targetUserId and 0.85 or 1,
			TextColor3 = TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 6,
		})
		make("UIPadding", { Parent = entry, PaddingLeft = UDim.new(0, 8) })
		entry.Activated:Connect(function()
			selectTarget(listed)
			setStatus("")
			closePicker()
		end)
	end
	picker.Size = UDim2.new(1, 0, 0, math.min(#list * PICK_HEIGHT, PICK_HEIGHT * 7))
	picker.Visible = true
end

targetButton.Activated:Connect(function()
	if picker.Visible then
		closePicker()
	else
		openPicker()
	end
end)
Players.PlayerRemoving:Connect(function(leaving)
	if leaving.UserId == targetUserId then
		selectTarget(player)
	end
end)
selectTarget(player)

local function setOpen(open)
	panel.Visible = open
	if open then
		Menus.Open("Admin", function()
			setOpen(false)
		end)
	else
		closePicker()
		Menus.Close("Admin")
	end
end
Menus.Register("Admin", function()
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
