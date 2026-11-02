-- Settings: the hub's Settings tab, kept apart at the foot of its nav (the top bar's gear,
-- or the title menu's SETTINGS, which shows it alone), full screen in the hub's Modern Warfare look. Along the top, its
-- sections as numbered sub-tabs: KEYBINDS, then the Preferences sections (GAMEPLAY,
-- EFFECTS, INTERFACE). On the left the section's rows, on the right a card saying what
-- the selected row does. A click selects a row (the accent fades out behind it; one under
-- the cursor only gets a faint wash); up and down move the selection, left and right
-- change it. A second click on the selected row acts on it. A keybind row: click it
-- again, press a key, and it's bound there (a key another action had
-- swaps the two; reserved keys are refused; Esc calls the wait off). An ON/OFF row flips
-- on that click, a choice goes round its list; its arrows, and a slider's track, work
-- at once (and select the row). A slider drags, or steps with its arrows. Under
-- the card's text, a setting you can see or hear shows a live PREVIEW at its value
-- (SettingsPreviews). Each section ends with RESET TO
-- DEFAULTS. Keys go to SettingsServer on the SetKeybinds remote and settings on
-- SetPreferences, at most once per SEND_SPACING with the newest change winning; until
-- one is echoed back the rows show it, and Preferences previews it so the game changes
-- at once. While waiting for a key, Keybinds.Capturing() is on and the skill bar, dash,
-- reload, gallery and the hub's own keys ignore key presses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GuardConfig = require(ReplicatedStorage:WaitForChild("GuardConfig"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local SettingsPreviews = require(script.Parent:WaitForChild("SettingsPreviews"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local setKeybinds = ReplicatedStorage:WaitForChild("SetKeybinds") -- made by SettingsServer
local setPreferences = ReplicatedStorage:WaitForChild("SetPreferences") -- made by SettingsServer
local player = Players.LocalPlayer

local Theme = Hub.Theme
local TAB_HEIGHT = 30
local TOP = TAB_HEIGHT + 16 -- the rows and the card start this far down
local LIST_SHARE = 0.5 -- of the width, the rows; the card has the rest
local GAP = 16
local ROW_HEIGHT = 40
local ROW_PAD = 16
local CONTROL_WIDTH = 250
local TRACK_WIDTH = 120
local VALUE_WIDTH = 54
local TOGGLE_WIDTH = 110 -- the ‹ ON › at a row's right
local ARROW_WIDTH = 18
local CAPTURE_TIMEOUT = 6 -- seconds of waiting for a key before giving up
local CAPTURE_RELEASE = 0.15 -- seconds the bound key stays swallowed, so it doesn't also cast
local SEND_SPACING = 0.6 -- seconds between saves (SettingsServer takes one per 0.5 s)
local PENDING_TIMEOUT = 3 -- seconds a save may go unanswered before the saved values show again
local DANGER = Color3.fromRGB(226, 75, 74)
local SELECTED_WASH = 0.75 -- the accent behind the selected row, at its left
local HOVER_WASH = 0.92 -- and behind a row the cursor is over
local PREVIEW_TOP = 204 -- px down the card
local PREVIEW_HEIGHT = 170

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
	props.Font = props.Font or Theme.LabelFont
	props.TextColor3 = props.TextColor3 or Theme.Ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

-- whether a screen point (an input's position) is over `gui`
local function inside(gui, position)
	local offset = Vector2.new(position.X, position.Y) - gui.AbsolutePosition
	return offset.X >= 0 and offset.Y >= 0 and offset.X <= gui.AbsoluteSize.X and offset.Y <= gui.AbsoluteSize.Y
end

-- a click (or tap) on `frame` calls `fn`
local function onClick(frame, fn)
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			fn(input)
		end
	end)
end

local tabFrame = Hub.Tab("Settings", { order = 7, title = "SETTINGS", apart = true, key = Enum.KeyCode.P })
local ink = Hub.InkAccent()

-- saving -----------------------------------------------------------------------------

local refresh -- defined below

-- Saves go out at most once per SEND_SPACING, the newest one winning, so quick changes
-- aren't dropped by the server's limit. Until it's echoed back, what's shown and built on
-- is the pending map. One of these each for the keybinds and the settings: `module` is
-- Keybinds or Preferences, `current()` the saved map.
local function saver(remote, module, current)
	local self = { pending = nil, lastSentAt = -math.huge, queued = false }

	function self.shown()
		return self.pending or current()
	end

	local function flush()
		self.queued = false
		if not self.pending then
			return
		end
		self.lastSentAt = os.clock()
		local sent = self.pending
		remote:FireServer(module.Serialize(sent))
		-- never echoed (refused, or nothing changed): show what's saved again
		task.delay(PENDING_TIMEOUT, function()
			if self.pending == sent and not self.queued then
				self.pending = nil
				refresh()
			end
		end)
	end

	function self.save(map)
		self.pending = map
		if self.queued then
			return
		end
		local wait = SEND_SPACING - (os.clock() - self.lastSentAt)
		if wait <= 0 then
			flush()
		else
			self.queued = true
			task.delay(wait, flush)
		end
	end

	-- the saved map changed: once it's what was sent, stop showing the pending one
	function self.echoed()
		if self.pending and not self.queued and module.Serialize(self.pending) == module.Serialize(current()) then
			self.pending = nil
		end
	end

	return self
end

local keys = saver(setKeybinds, Keybinds, Keybinds.Current)
local prefs = saver(setPreferences, Preferences, function()
	return Preferences.Parse(player:GetAttribute(Preferences.Attribute))
end)

-- layout -----------------------------------------------------------------------------

-- the sections: KEYBINDS, then Preferences' in their order
local sections = { { name = "KEYBINDS", rows = {} } }
for _, option in ipairs(Preferences.Options) do
	if sections[#sections].name ~= option.section then
		table.insert(sections, { name = option.section, rows = {} })
	end
end
local currentSection = sections[1]
local selected -- the selected row

local tabRow = make("Frame", { Parent = tabFrame, Size = UDim2.new(1, 0, 0, TAB_HEIGHT), BackgroundTransparency = 1 })
make("UIListLayout", {
	Parent = tabRow,
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 26),
})
make("Frame", {
	Parent = tabFrame,
	Position = UDim2.fromOffset(0, TAB_HEIGHT + 4),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = Theme.Edge,
	BackgroundTransparency = Theme.EdgeTransparency,
	BorderSizePixel = 0,
})

-- the card on the right: what the selected row is and does
local card = make("Frame", {
	Parent = tabFrame,
	Position = UDim2.new(LIST_SHARE, GAP, 0, TOP),
	Size = UDim2.new(1 - LIST_SHARE, -GAP, 1, -TOP),
	BackgroundColor3 = Theme.Panel, -- the hub draws it as smoked glass
	BorderSizePixel = 0,
})
make("UIPadding", {
	Parent = card,
	PaddingTop = UDim.new(0, 20),
	PaddingBottom = UDim.new(0, 20),
	PaddingLeft = UDim.new(0, 22),
	PaddingRight = UDim.new(0, 22),
})
local cardKicker = label(card, { Font = Theme.MonoFont, TextSize = 11, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, 14) })
local cardTitle = label(card, {
	Font = Theme.TitleFont,
	TextSize = 30,
	TextWrapped = true,
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, 0, 0, 38),
})
local cardRule = make("Frame", { Parent = card, Position = UDim2.fromOffset(0, 64), Size = UDim2.fromOffset(40, 3), BorderSizePixel = 0 })
local cardBody = label(card, {
	TextSize = 15,
	TextColor3 = Theme.Muted,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.new(1, 0, 0, 90),
})
local cardDefault = label(card, { Font = Theme.MonoFont, TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 0, 14) })
-- the preview: a dark box under the text, PREVIEW in its corner
local previewBox = make("Frame", {
	Parent = card,
	Position = UDim2.fromOffset(0, PREVIEW_TOP),
	Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Visible = false,
})
make("UIStroke", { Parent = previewBox, Color = Theme.Edge, Transparency = Theme.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
local previewContent = make("Frame", { Parent = previewBox, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
label(previewBox, {
	Text = "PREVIEW",
	Font = Theme.MonoFont,
	TextSize = 10,
	TextColor3 = Theme.Muted,
	Position = UDim2.fromOffset(8, 6),
	Size = UDim2.fromOffset(80, 12),
	ZIndex = 5,
})
-- at the card's foot: how to use the rows, and what just happened to a key
local status = label(card, {
	TextSize = 13,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -30),
	Size = UDim2.new(1, 0, 0, 40),
})
local hints = make("Frame", {
	Parent = card,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
})
make("UIListLayout", {
	Parent = hints,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
})
-- a key in a small box, then what it does
local function hint(order, key, text)
	local chip = label(hints, {
		LayoutOrder = order * 2,
		Text = key,
		Font = Theme.MonoFont,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	make("UIPadding", { Parent = chip, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) })
	make("UIStroke", { Parent = chip, Color = Theme.Ink, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	label(hints, {
		LayoutOrder = order * 2 + 1,
		Text = text .. "   ",
		TextSize = 11,
		TextColor3 = Theme.Muted,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
	})
end
hint(1, "↑↓", "SELECT")
hint(2, "←→", "CHANGE")
hint(3, "ESC", "BACK")

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or Theme.Muted
end

-- rows -------------------------------------------------------------------------------

local capturing -- the action id waiting for a key, or nil
local captureToken
local dragging -- the slider row being dragged, or nil

-- the keyboard -----------------------------------------------------------------------

-- A 75% keyboard drawn above the card's text while the KEYBINDS tab is open, always there (it
-- doesn't depend on the selected row; the text moves down under it). Only two things are lit:
-- the keys that have an action of yours (the accent, tagged with what they do) and the selected
-- row's key (bright). Clicking a lit key selects its row.
local KEYBOARD_TOP = 0
local KEY_HEIGHT = 26
local KEY_GAP = 3
local KEYBOARD_UNITS = 16 -- a 75% keyboard is 16 keys wide
local KEYBOARD_WIDTH = 0.8 -- of the card
local KEYBOARD_GAP = 22 -- px between the keyboard and the text under it

-- { KeyCode name, what's drawn, width in keys }
local function k(code, text, width)
	return { code, text, width or 1 }
end
local function join(...)
	local row = {}
	for _, part in ipairs({ ... }) do
		for _, key in ipairs(part) do
			table.insert(row, key)
		end
	end
	return row
end
local function letters(text)
	local list = {}
	for char in string.gmatch(text, ".") do
		table.insert(list, k(char, char))
	end
	return list
end
local DIGIT_NAMES = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero" }
local digits = {}
for i, name in ipairs(DIGIT_NAMES) do
	table.insert(digits, k(name, tostring(i % 10)))
end
local functionKeys = {}
for i = 1, 12 do
	table.insert(functionKeys, k("F" .. i, "F" .. i))
end
local KEYBOARD_ROWS = {
	join({ k("Escape", "Esc") }, functionKeys, { k("Print", "Prt"), k("Delete", "Del"), k("Insert", "Ins") }),
	join({ k("Backquote", "`") }, digits, { k("Minus", "-"), k("Equals", "="), k("Backspace", "Bksp", 2), k("Home", "Home") }),
	join({ k("Tab", "Tab", 1.5) }, letters("QWERTYUIOP"), { k("LeftBracket", "["), k("RightBracket", "]"), k("BackSlash", "\\", 1.5), k("PageUp", "PgUp") }),
	join({ k("CapsLock", "Caps", 1.75) }, letters("ASDFGHJKL"), { k("Semicolon", ";"), k("Quote", "'"), k("Return", "Enter", 2.25), k("PageDown", "PgDn") }),
	join({ k("LeftShift", "Shift", 2.25) }, letters("ZXCVBNM"), { k("Comma", ","), k("Period", "."), k("Slash", "/"), k("RightShift", "Shift", 1.75), k("Up", "^"), k("End", "End") }),
	{
		k("LeftControl", "Ctrl", 1.25),
		k("LeftSuper", "Win", 1.25),
		k("LeftAlt", "Alt", 1.25),
		k("Space", "", 6.25),
		k("RightAlt", "Alt"),
		k("Fn", "Fn"),
		k("RightControl", "Ctrl"),
		k("Left", "<"),
		k("Down", "v"),
		k("Right", ">"),
	},
}

-- what a key of yours is tagged with
local ACTION_TAGS = {
	SkillZ = "SK1",
	SkillX = "SK2",
	SkillC = "SK3",
	SkillV = "SK4",
	SkillF = "ULT",
	Special = "PASV",
	Dash = "DASH",
	Block = "BLOCK",
	Reload = "RELD",
	Gallery = "PASV2",
	HideHud = "HUD",
	ItemWheel = "WHEEL",
}

local keyboard = make("Frame", {
	Parent = card,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, KEYBOARD_TOP),
	Size = UDim2.new(KEYBOARD_WIDTH, 0, 0, #KEYBOARD_ROWS * (KEY_HEIGHT + KEY_GAP)),
	BackgroundTransparency = 1,
})
local keyCells = {} -- KeyCode name -> { frame, name, tag, stroke, action }
local selectRow, showSection -- (defined below)
for rowIndex, row in ipairs(KEYBOARD_ROWS) do
	local x = 0
	for _, key in ipairs(row) do
		local code, text, width = key[1], key[2], key[3]
		local frame = make("Frame", {
			Parent = keyboard,
			Position = UDim2.new(x / KEYBOARD_UNITS, 0, 0, (rowIndex - 1) * (KEY_HEIGHT + KEY_GAP)),
			Size = UDim2.new(width / KEYBOARD_UNITS, -KEY_GAP, 0, KEY_HEIGHT),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
		})
		local stroke = make("UIStroke", { Parent = frame, Color = Theme.Muted, Transparency = 0.75, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		local name = label(frame, {
			Text = text,
			Font = Theme.MonoFont,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
		local tag = label(frame, {
			Font = Theme.MonoFont,
			TextSize = 8,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -2),
			Size = UDim2.new(1, 0, 0, 10),
		})
		keyCells[code] = { frame = frame, name = name, tag = tag, stroke = stroke, action = nil }
		x += width
	end
end

-- a click on a key of yours: its row
for _, cell in pairs(keyCells) do
	onClick(cell.frame, function()
		local id = cell.action
		if not id or currentSection ~= sections[1] then
			return
		end
		for _, row in ipairs(sections[1].rows) do
			if row.info and row.info.id == id then
				selectRow(row)
			end
		end
	end)
end

-- shows or hides the keyboard, and puts the card's text under it (or back at the top)
local function paintKeyboard()
	keyboard.Visible = currentSection == sections[1]
	local off = keyboard.Visible and (keyboard.Size.Y.Offset + KEYBOARD_GAP) or 0
	cardKicker.Position = UDim2.fromOffset(0, off)
	cardTitle.Position = UDim2.fromOffset(0, off + 20)
	cardRule.Position = UDim2.fromOffset(0, off + 64)
	cardBody.Position = UDim2.fromOffset(0, off + 80)
	cardDefault.Position = UDim2.fromOffset(0, off + 176)
	previewBox.Position = UDim2.fromOffset(0, PREVIEW_TOP + off)
	if not keyboard.Visible then
		return
	end
	local owner = {} -- KeyCode name -> action id
	for id, keyName in pairs(keys.shown()) do
		if keyName ~= Keybinds.None then
			owner[keyName] = id
		end
	end
	local chosen = selected and selected.info and selected.info.id
	for code, cell in pairs(keyCells) do
		local id = owner[code]
		cell.action = id
		cell.tag.Text = id and ACTION_TAGS[id] or ""
		cell.name.Position = UDim2.fromOffset(0, id and -5 or 0)
		if id and id == chosen then
			cell.frame.BackgroundColor3 = ink
			cell.frame.BackgroundTransparency = 0.05
			cell.stroke.Color = ink
			cell.stroke.Transparency = 0
			cell.name.TextColor3 = Color3.new(0, 0, 0)
			cell.tag.TextColor3 = Color3.new(0, 0, 0)
		elseif id then
			cell.frame.BackgroundColor3 = ink
			cell.frame.BackgroundTransparency = 0.7
			cell.stroke.Color = ink
			cell.stroke.Transparency = 0.1
			cell.name.TextColor3 = Theme.Ink
			cell.tag.TextColor3 = ink
		else
			cell.frame.BackgroundColor3 = Color3.new(0, 0, 0)
			cell.frame.BackgroundTransparency = 0.6
			cell.stroke.Color = Theme.Muted
			cell.stroke.Transparency = 0.75
			cell.name.TextColor3 = Theme.Muted
			cell.tag.TextColor3 = Theme.Muted
		end
	end
end

-- a row in `section`'s list: the accent behind it while selected, its name on the left
-- and its control on the right (filled in by the kind of row)
local function newRow(section, name, info)
	local row = { section = section, info = info }
	row.frame = make("Frame", {
		Parent = section.list,
		LayoutOrder = #section.rows + 1,
		Size = UDim2.new(1, -6, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		Active = true,
	})
	row.highlight = make("Frame", { Parent = row.frame, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.75, BorderSizePixel = 0, Visible = false })
	make("UIGradient", {
		Parent = row.highlight,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	})
	row.marker = make("Frame", { Parent = row.frame, Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, Visible = false })
	make("Frame", {
		Parent = row.frame,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Edge,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
	})
	row.name = label(row.frame, {
		Text = name,
		TextSize = 15,
		Position = UDim2.fromOffset(ROW_PAD, 0),
		Size = UDim2.new(1, -(CONTROL_WIDTH + ROW_PAD), 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	row.control = make("Frame", {
		Parent = row.frame,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -ROW_PAD, 0, 0),
		Size = UDim2.new(0, CONTROL_WIDTH, 1, 0),
		BackgroundTransparency = 1,
	})
	-- the cursor over it only washes it faintly; a click selects it (see `pressed`)
	row.frame.MouseEnter:Connect(function()
		row.hovered = true
		refresh()
	end)
	row.frame.MouseLeave:Connect(function()
		row.hovered = false
		refresh()
	end)
	table.insert(section.rows, row)
	return row
end

-- a click on `row`: the first selects it, one on it while it's selected calls `act`
local function pressed(row, act)
	if selected == row then
		act()
	else
		selectRow(row)
	end
end

-- an arrow at either end of a control, stepping the value
local function arrow(parent, text, x, anchor, fn)
	local a = label(parent, {
		Text = text,
		Font = Theme.TitleFont,
		TextSize = 20,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(anchor, 0.5),
		Position = UDim2.new(x, 0, 0.5, 0),
		Size = UDim2.fromOffset(ARROW_WIDTH, ROW_HEIGHT),
		Active = true,
	})
	onClick(a, fn)
	return a
end

-- a setting's value changed by the player
local function setPreference(id, value)
	local map = table.clone(prefs.shown())
	if map[id] == value then
		return
	end
	map[id] = value
	prefs.save(map)
	refresh()
end

-- (an arrow's click selects its row too)
local function nudge(row, steps)
	selectRow(row)
	local option = row.option
	setPreference(option.id, Preferences.Nudge(option, prefs.shown()[option.id], steps))
end

-- an ON/OFF or choice row: ‹ ON › at the right; a click anywhere on the row flips it, or
-- moves a choice on
local function toggleRow(section, option)
	local row = newRow(section, option.label, option)
	row.option = option
	local left = arrow(row.control, "‹", 1, 1, function()
		nudge(row, -1)
	end)
	left.Position = UDim2.new(1, -(TOGGLE_WIDTH - ARROW_WIDTH), 0.5, 0)
	row.value = label(row.control, {
		Font = Theme.TitleFont,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -ARROW_WIDTH, 0, 0),
		Size = UDim2.new(0, TOGGLE_WIDTH - 2 * ARROW_WIDTH, 1, 0),
	})
	local right = arrow(row.control, "›", 1, 1, function()
		nudge(row, 1)
	end)
	onClick(row.frame, function(input)
		-- not when the click was on an arrow (that steps it already)
		if not inside(left, input.Position) and not inside(right, input.Position) then
			pressed(row, function()
				nudge(row, 1)
			end)
		end
	end)
	function row.paint(map)
		local value = map[option.id]
		local shown = Preferences.Text(option, value)
		local off = value == false or shown == "OFF" or shown == "NONE"
		row.value.Text = shown
		row.value.TextColor3 = off and Theme.Muted or ink
	end
	return row
end

-- a slider row: ‹ [track] 100% › at the right; drag the track or step with the arrows
local function sliderRow(section, option)
	local row = newRow(section, option.label, option)
	row.option = option
	local right = ARROW_WIDTH + VALUE_WIDTH + 6
	arrow(row.control, "‹", 1, 1, function()
		nudge(row, -1)
	end).Position = UDim2.new(1, -(right + TRACK_WIDTH + 6), 0.5, 0)
	-- the track's hit area is taller than the line, so it's easy to grab
	row.track = make("Frame", {
		Parent = row.control,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -right, 0.5, 0),
		Size = UDim2.fromOffset(TRACK_WIDTH, 22),
		BackgroundTransparency = 1,
		Active = true,
	})
	local line = make("Frame", {
		Parent = row.track,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Theme.BarBack,
		BorderSizePixel = 0,
	})
	row.fill = make("Frame", { Parent = line, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 })
	row.handle = make("Frame", {
		Parent = line,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(4, 14),
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
	})
	row.value = label(row.control, {
		Font = Theme.MonoFont,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(ARROW_WIDTH + 3), 0.5, 0),
		Size = UDim2.fromOffset(VALUE_WIDTH, 22),
	})
	make("UIStroke", { Parent = row.value, Color = Theme.Ink, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	arrow(row.control, "›", 1, 1, function()
		nudge(row, 1)
	end)
	-- a click on the row selects it (a slider has nothing to flip)
	onClick(row.frame, function()
		selectRow(row)
	end)
	onClick(row.track, function(input)
		selectRow(row)
		dragging = row
		row.dragTo(input.Position.X)
	end)
	function row.dragTo(x)
		local fraction = (x - row.track.AbsolutePosition.X) / row.track.AbsoluteSize.X
		setPreference(option.id, Preferences.SliderAt(option, fraction))
	end
	function row.paint(map)
		local value = map[option.id]
		local fraction = (value - option.min) / (option.max - option.min)
		row.fill.Size = UDim2.fromScale(fraction, 1)
		row.fill.BackgroundColor3 = ink
		row.handle.Position = UDim2.fromScale(fraction, 0.5)
		row.value.Text = Preferences.Text(option, value)
	end
	return row
end

-- a keybind row: the key in a box at the right; a click waits for the new key
local startCapture, stopCapture
local function keyRow(section, action)
	local row = newRow(section, action.label, {
		label = action.label,
		description = "The key for " .. string.lower(action.label) .. ". Click the row, then press the new key. A key another action has swaps the two.",
	})
	row.action = action
	row.value = label(row.control, {
		Font = Theme.MonoFont,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	make("UIPadding", { Parent = row.value, PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
	row.valueEdge = make("UIStroke", { Parent = row.value, Color = Theme.Ink, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	onClick(row.frame, function()
		pressed(row, function()
			if capturing == action.id then
				stopCapture()
				setStatus("")
			else
				startCapture(action.id)
			end
		end)
	end)
	function row.paint()
		if capturing == action.id then
			row.value.Text = "PRESS A KEY"
			row.value.TextColor3 = ink
			row.valueEdge.Color = ink
		else
			row.value.Text = Keybinds.ShortName(keys.shown()[action.id])
			row.value.TextColor3 = Theme.Ink
			row.valueEdge.Color = Theme.Ink
		end
	end
	return row
end

-- the last row of a section: RESET TO DEFAULTS
local function resetRow(section, reset)
	local row = newRow(section, "", {
		label = "Reset to defaults",
		description = "Puts everything in " .. section.name .. " back the way it started.",
	})
	row.name.Text = "RESET TO DEFAULTS"
	row.name.Font = Theme.TitleFont
	row.name.TextColor3 = Theme.Muted
	onClick(row.frame, function()
		pressed(row, reset)
	end)
	function row.paint() end
	return row
end

-- the sections' tabs and lists
local tabButtons = {}
for i, section in ipairs(sections) do
	local button = make("TextButton", {
		Parent = tabRow,
		LayoutOrder = i,
		Size = UDim2.fromOffset(0, TAB_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Font = Theme.TitleFont,
		TextSize = 20,
		TextColor3 = Theme.Muted,
		Text = string.format("%02d  %s", i, section.name),
	})
	button:SetAttribute("SectionSelect", true) -- the hub's click sound
	tabButtons[section] = button
	section.number = string.format("%02d", i)
	section.list = make("ScrollingFrame", {
		Parent = tabFrame,
		Position = UDim2.fromOffset(0, TOP),
		Size = UDim2.new(LIST_SHARE, 0, 1, -TOP),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Muted,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
	})
	make("UIListLayout", { Parent = section.list, SortOrder = Enum.SortOrder.LayoutOrder })
	button.Activated:Connect(function()
		showSection(section)
	end)
end

for _, action in ipairs(Keybinds.Actions) do
	if action.id ~= "Block" or GuardConfig.Enabled then
		keyRow(sections[1], action)
	end
end
resetRow(sections[1], function()
	if capturing then
		stopCapture()
	end
	keys.save(Keybinds.Defaults())
	refresh()
	setStatus("Every key is back on its default.", Theme.Ink)
end)
for _, section in ipairs(sections) do
	if section ~= sections[1] then
		for _, option in ipairs(Preferences.Options) do
			if option.section == section.name then
				if option.kind == "slider" then
					sliderRow(section, option)
				else
					toggleRow(section, option)
				end
			end
		end
		resetRow(section, function()
			local map = table.clone(prefs.shown())
			for _, option in ipairs(Preferences.Options) do
				if option.section == section.name then
					map[option.id] = option.default
				end
			end
			prefs.save(map)
			refresh()
			setStatus(section.name .. " is back on its defaults.", Theme.Ink)
		end)
	end
end

-- showing ----------------------------------------------------------------------------

-- the selected setting's preview: built when the selection moves to it, painted on every
-- change, and stepped each frame (below) if it moves
local previewId, preview, previewState
local function paintPreview()
	local option = selected and selected.option
	local id = option and SettingsPreviews.For(option.id) and option.id
	if id ~= previewId then
		previewId = id
		preview = id and SettingsPreviews.For(id)
		previewContent:ClearAllChildren()
		previewState = preview and preview.build(previewContent)
		previewBox.Visible = preview ~= nil
	end
	if preview then
		preview.paint(previewState, prefs.shown()[previewId], ink)
	end
end
RunService.RenderStepped:Connect(function()
	if preview and preview.step and Hub.Current() == "Settings" then
		preview.step(previewState, os.clock(), prefs.shown()[previewId])
	end
end)

local function paintCard()
	local info = selected and selected.info
	if not info then
		return
	end
	cardKicker.Text = currentSection.number .. "  ·  " .. currentSection.name
	cardTitle.Text = string.upper(info.label)
	cardBody.Text = info.description or ""
	cardDefault.Text = info.default ~= nil and ("DEFAULT  " .. Preferences.Text(info, info.default)) or ""
	cardRule.BackgroundColor3 = ink
	paintPreview()
end

function refresh()
	Preferences.Preview(prefs.pending)
	local map = prefs.shown()
	for _, section in ipairs(sections) do
		local on = section == currentSection
		section.list.Visible = on
		tabButtons[section].TextColor3 = on and Theme.Ink or Theme.Muted
		for _, row in ipairs(section.rows) do
			row.paint(map)
			local isSelected = row == selected
			row.highlight.Visible = isSelected or row.hovered == true
			row.highlight.BackgroundTransparency = isSelected and SELECTED_WASH or HOVER_WASH
			row.highlight.BackgroundColor3 = ink
			row.marker.Visible = isSelected
			row.marker.BackgroundColor3 = ink
		end
	end
	paintKeyboard()
	paintCard()
end

function selectRow(row)
	if selected ~= row then
		selected = row
		refresh()
	end
end

function showSection(section)
	if capturing then
		stopCapture()
	end
	currentSection = section
	selected = section.rows[1]
	section.list.CanvasPosition = Vector2.zero
	setStatus("")
	refresh()
end

-- keys -------------------------------------------------------------------------------

local function labelOf(id)
	for _, action in ipairs(Keybinds.Actions) do
		if action.id == id then
			return action.label
		end
	end
	return id
end

function stopCapture()
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

function startCapture(id)
	capturing = id
	local token = {}
	captureToken = token
	Keybinds.SetCapturing(true)
	setStatus("Press a key for this action. Backspace clears it, Esc cancels.")
	refresh()
	task.delay(CAPTURE_TIMEOUT, function()
		if captureToken == token then
			stopCapture()
			setStatus("")
		end
	end)
end

-- the key the player pressed while an action waited for one
local function bindPressed(keyCode)
	local id = capturing
	local current = keys.shown()
	local keyName = keyCode == Enum.KeyCode.Backspace and Keybinds.None or keyCode.Name -- Backspace unbinds
	local bound, reason = Keybinds.Bind(current, id, keyName)
	if not bound then
		setStatus(reason == "reserved" and "That key is reserved. Pick another." or "Can't bind that.", DANGER)
		return -- keep waiting
	end
	local message = string.format("%s → %s", labelOf(id), Keybinds.ShortName(keyName))
	for otherId, key in pairs(current) do
		if otherId ~= id and key == keyName and keyName ~= Keybinds.None then
			message ..= string.format("  (%s moved to %s)", labelOf(otherId), Keybinds.ShortName(current[id]))
		end
	end
	keys.save(bound)
	stopCapture()
	setStatus(message, Theme.Ink)
end

-- the selection moves `steps` rows within the section
local function moveSelection(steps)
	local rows = currentSection.rows
	local index = table.find(rows, selected) or 0
	local row = rows[math.clamp(index + steps, 1, #rows)]
	selectRow(row)
	-- keep it in view
	local list = currentSection.list
	local top = row.frame.AbsolutePosition.Y - list.AbsolutePosition.Y
	local scale = UIScale.Get()
	if top < 0 then
		list.CanvasPosition -= Vector2.new(0, -top / scale)
	elseif top + row.frame.AbsoluteSize.Y > list.AbsoluteSize.Y then
		list.CanvasPosition += Vector2.new(0, (top + row.frame.AbsoluteSize.Y - list.AbsoluteSize.Y) / scale)
	end
end

UserInputService.InputBegan:Connect(function(input)
	if Hub.Current() ~= "Settings" then
		return
	end
	if capturing then
		-- waiting for a key: this one is it, whatever else wanted it (but not typing into chat or
		-- another text box: that calls the wait off)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if UserInputService:GetFocusedTextBox() or input.KeyCode == Enum.KeyCode.Escape then
			stopCapture()
			setStatus("")
		else
			bindPressed(input.KeyCode)
		end
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Up then
		moveSelection(-1)
	elseif input.KeyCode == Enum.KeyCode.Down then
		moveSelection(1)
	elseif (input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.Right) and selected and selected.option then
		nudge(selected, input.KeyCode == Enum.KeyCode.Right and 1 or -1)
	end
end)

-- a slider follows the mouse while it's held
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		dragging.dragTo(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = nil
	end
end)

-- opening ----------------------------------------------------------------------------

-- the top bar's gear and the title menu's SETTINGS: the hub on this tab (alone, from the title)
Menus.Register("Settings", function()
	if player.PlayerGui:FindFirstChild("TitleMenu") then
		Hub.OpenOnly("Settings")
	else
		Hub.Toggle("Settings")
	end
end)
Hub.OnShown("Settings", function()
	setStatus("")
	showSection(currentSection)
end)
Hub.OnClosed(function()
	dragging = nil
	if capturing then
		stopCapture()
	end
end)
Hub.OnAccent(function(_, accentInk)
	ink = accentInk
	refresh()
end)

-- the rows show what's saved once it's echoed back (or refused: then the saved values show again)
Keybinds.Changed(function()
	keys.echoed()
	refresh()
end)
Preferences.Changed(function()
	prefs.echoed()
	refresh()
end)
selected = currentSection.rows[1]
refresh()
