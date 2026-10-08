-- Settings menu: a square gear button at the right edge of the screen, or
-- P, opens it; × or Esc closes it. Its first section, KEYBINDS, lists the
-- rebindable actions (Keybinds.Actions) with the key each is on: click one,
-- press a key, and it's bound there (a key another action had swaps the
-- two; reserved keys are refused). RESET TO DEFAULTS puts every action back.
-- Each change goes to SettingsServer on the SetKeybinds remote, which saves
-- the player's Keybinds attribute; the rows show that attribute, so they
-- always match what's saved. While waiting for a key, Keybinds.Capturing()
-- is on and the skill bar, dash, reload and gallery ignore key presses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local setKeybinds = ReplicatedStorage:WaitForChild("SetKeybinds") -- made by SettingsServer
local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.P
local PANEL_WIDTH = 330
local PADDING = 12
local ROW_HEIGHT = 26
local KEY_WIDTH = 70
local GEAR_SIZE = 36
local CAPTURE_TIMEOUT = 6 -- seconds of waiting for a key before giving up
local CAPTURE_RELEASE = 0.15 -- seconds the bound key stays swallowed, so it doesn't also cast
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local BUTTON = Color3.fromRGB(38, 38, 50)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local ACCENT = Color3.fromRGB(175, 90, 255)
local DANGER = Color3.fromRGB(226, 75, 74)

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

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "Settings",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- the gear, always there
local gear = make("TextButton", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(GEAR_SIZE, GEAR_SIZE),
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "⚙",
	TextSize = 22,
	TextColor3 = TEXT,
})
make("UIStroke", { Parent = gear, Color = TEXT, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

local panel = make("Frame", {
	Parent = gui,
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = panel, Color = ACCENT, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
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
	return make("Frame", { Parent = panel, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 })
end

local header = section(22)
label(header, { Text = "SETTINGS", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, -24, 1, 0) })
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

label(section(16), { Text = "KEYBINDS", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = ACCENT, Size = UDim2.fromScale(1, 1) })

local function button(parent, props)
	props.Parent = parent
	props.BackgroundColor3 = props.BackgroundColor3 or BUTTON
	props.BorderSizePixel = 0
	props.AutoButtonColor = true
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextSize = props.TextSize or 12
	props.TextColor3 = props.TextColor3 or TEXT
	local b = make("TextButton", props)
	make("UIStroke", { Parent = b, Color = TEXT, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	return b
end

local keyButtons = {} -- action id -> TextButton
local capturing -- the action id waiting for a key, or nil
local captureToken
local status

local function refresh()
	for id, keyButton in pairs(keyButtons) do
		if id == capturing then
			keyButton.Text = "Press a key…"
			keyButton.TextColor3 = ACCENT
		else
			keyButton.Text = Keybinds.Text(id)
			keyButton.TextColor3 = TEXT
		end
	end
end

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or MUTED
end

local function stopCapture()
	capturing = nil
	captureToken = nil
	-- a beat later, so the key that was just bound doesn't also cast
	task.delay(CAPTURE_RELEASE, function()
		if not capturing then
			Keybinds.SetCapturing(false)
		end
	end)
	refresh()
end

local function startCapture(id)
	capturing = id
	local token = {}
	captureToken = token
	Keybinds.SetCapturing(true)
	setStatus("Press a key for this action. Esc cancels.")
	refresh()
	task.delay(CAPTURE_TIMEOUT, function()
		if captureToken == token then
			stopCapture()
			setStatus("")
		end
	end)
end

for _, action in ipairs(Keybinds.Actions) do
	local row = section(ROW_HEIGHT)
	label(row, { Text = action.label, TextSize = 12, Size = UDim2.new(1, -KEY_WIDTH - 8, 1, 0) })
	local keyButton = button(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, KEY_WIDTH, 1, 0),
	})
	keyButton.Activated:Connect(function()
		if capturing == action.id then
			stopCapture()
			setStatus("")
		else
			startCapture(action.id)
		end
	end)
	keyButtons[action.id] = keyButton
end

local resetButton = button(section(ROW_HEIGHT), {
	Size = UDim2.fromScale(1, 1),
	Text = "RESET TO DEFAULTS",
	TextColor3 = MUTED,
})
status = label(section(16), { Text = "", TextSize = 11, TextColor3 = MUTED, TextWrapped = true, Size = UDim2.fromScale(1, 1) })

local function labelOf(id)
	for _, action in ipairs(Keybinds.Actions) do
		if action.id == id then
			return action.label
		end
	end
	return id
end

-- the key the player pressed while an action waited for one
local function bindPressed(keyCode)
	local id = capturing
	local current = Keybinds.Current()
	local bound, reason = Keybinds.Bind(current, id, keyCode.Name)
	if not bound then
		setStatus(reason == "reserved" and "That key is reserved. Pick another." or "Can't bind that.", DANGER)
		return -- keep waiting
	end
	local message = string.format("%s → %s", labelOf(id), Keybinds.ShortName(keyCode.Name))
	for otherId, key in pairs(current) do
		if otherId ~= id and key == keyCode.Name then
			message ..= string.format("  (%s moved to %s)", labelOf(otherId), Keybinds.ShortName(current[id]))
		end
	end
	setKeybinds:FireServer(Keybinds.Serialize(bound))
	stopCapture()
	setStatus(message, TEXT)
end

local function setOpen(open)
	panel.Visible = open
	if not open and capturing then
		stopCapture()
	end
	if open then
		setStatus("")
		refresh()
	end
end

gear.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
resetButton.Activated:Connect(function()
	if capturing then
		stopCapture()
	end
	setKeybinds:FireServer("")
	setStatus("Every key is back on its default.", TEXT)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	-- waiting for a key: this one is it, whatever else wanted it
	if capturing then
		if input.KeyCode == Enum.KeyCode.Escape then
			stopCapture()
			setStatus("")
		else
			bindPressed(input.KeyCode)
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		setOpen(false)
	elseif input.KeyCode == TOGGLE_KEY and not gameProcessed then
		setOpen(not panel.Visible)
	end
end)

-- the rows show what's saved, so a refused or late save never shows wrong
Keybinds.Changed(refresh)
refresh()
