-- The quick setup a player sees the first time they press PLAY, before any character exists
-- (SlotMenu): the few settings worth choosing up front, Field of view, Shoulder side and
-- Sprint hold or toggle, each a row with the setting's own description and, on its right, the
-- value between plain ‹ › arrows, as in Settings (the field of view a slider to drag between them).
-- The field of view shows at once as it changes. CONTINUE saves what was picked the way
-- Settings does (the SetPreferences remote), and everything stays changeable in Settings.
-- Square everything; the accent is the hub's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local Customizer = require(script.Parent:WaitForChild("Customizer"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme
local make, label, button = Customizer.Make, Customizer.Label, Customizer.Button

local SETTINGS = { "Fov", "Side", "Sprint" }
local PANEL_WIDTH = 760
local ROW_TOP = 96 -- px under the panel's top, where the first row starts
local ROW_HEIGHT = 96
local PICKER_WIDTH = 228 -- the ‹ value › (or ‹ track value ›) on a row's right
local ARROW_WIDTH = 18
local CONTROL_HEIGHT = 40
local TRACK_WIDTH = 120 -- a slider's track
local VALUE_WIDTH = 54 -- a slider's value, right of its track
local SAVE_PREVIEW_TIMEOUT = 3 -- s the preview is kept for the server's answer

local FirstSetup = {}

local function pressed(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Builds the setup in `parent` (a frame the size of the cards' area). onDone() after CONTINUE.
function FirstSetup.Build(parent, accent, onDone)
	local map = Preferences.Parse(player:GetAttribute(Preferences.Attribute))

	local panel = make("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(PANEL_WIDTH, ROW_TOP + #SETTINGS * ROW_HEIGHT + 70),
		BackgroundTransparency = 1,
	})
	label(panel, { Text = "QUICK SETUP", Font = Theme.TitleFont, TextSize = 30, Size = UDim2.new(1, 0, 0, 36) })
	label(panel, {
		Text = "Pick how you like to play. You can change all of this later in Settings.",
		TextSize = 15,
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 20),
	})

	-- a slider follows the mouse while it's held (until the setup goes)
	local dragging -- the slider being dragged: its dragTo(x), or nil
	local connections = {
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				dragging(input.Position.X)
			end
		end),
		UserInputService.InputEnded:Connect(function(input)
			if pressed(input) then
				dragging = nil
			end
		end),
	}
	panel.Destroying:Connect(function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end)

	for i, id in ipairs(SETTINGS) do
		local option = Preferences.Option(id)
		local y = ROW_TOP + (i - 1) * ROW_HEIGHT
		local controlTop = y + 14
		local slider = option.kind == "slider"
		make("Frame", {
			Parent = panel,
			Position = UDim2.fromOffset(0, y - 10),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Muted,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
		})
		label(panel, { Text = string.upper(option.label), Font = Theme.TitleFont, TextSize = 22, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, -(PICKER_WIDTH + 24), 0, 26) })
		label(panel, {
			Text = option.description,
			TextSize = 14,
			TextColor3 = Theme.Muted,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, y + 28),
			Size = UDim2.new(1, -(PICKER_WIDTH + 24), 0, 50),
		})

		-- the value: between the arrows, or right of a slider's track
		local value = label(panel, {
			Text = "",
			Font = Theme.TitleFont,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -ARROW_WIDTH - (slider and 4 or 0), 0, controlTop),
			Size = UDim2.fromOffset(slider and VALUE_WIDTH or PICKER_WIDTH - 2 * ARROW_WIDTH, CONTROL_HEIGHT),
		})
		local fill, handle
		local function show()
			value.Text = Preferences.Text(option, map[id])
			if slider then
				local fraction = (map[id] - option.min) / (option.max - option.min)
				fill.Size = UDim2.fromScale(fraction, 1)
				handle.Position = UDim2.fromScale(fraction, 0.5)
			end
		end
		local function set(newValue)
			map[id] = newValue
			show()
			Preferences.Preview(map)
		end
		-- plain arrows, no box: ‹ steps back, › forward
		for _, side in ipairs({ { "‹", 0, -PICKER_WIDTH, -1 }, { "›", 1, 0, 1 } }) do
			local arrow = label(panel, {
				Text = side[1],
				Font = Theme.TitleFont,
				TextSize = 26,
				TextColor3 = Theme.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(side[2], 0),
				Position = UDim2.new(1, side[3], 0, controlTop),
				Size = UDim2.fromOffset(ARROW_WIDTH, CONTROL_HEIGHT),
				Active = true,
			})
			arrow.InputBegan:Connect(function(input)
				if pressed(input) then
					set(Preferences.Nudge(option, map[id], side[4]))
				end
			end)
		end
		if slider then
			-- the track's hit area is taller than the line, so it's easy to grab
			local track = make("Frame", {
				Parent = panel,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -(ARROW_WIDTH + 4 + VALUE_WIDTH + 8), 0, controlTop + CONTROL_HEIGHT / 2),
				Size = UDim2.fromOffset(TRACK_WIDTH, 22),
				BackgroundTransparency = 1,
				Active = true,
			})
			local line = make("Frame", {
				Parent = track,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundColor3 = Theme.BarBack,
				BorderSizePixel = 0,
			})
			fill = make("Frame", { Parent = line, Size = UDim2.fromScale(0, 1), BackgroundColor3 = accent, BorderSizePixel = 0 })
			handle = make("Frame", {
				Parent = line,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(4, 14),
				BackgroundColor3 = Theme.Ink,
				BorderSizePixel = 0,
			})
			local function dragTo(x)
				local nearest = Preferences.SliderAt(option, (x - track.AbsolutePosition.X) / track.AbsoluteSize.X)
				if nearest ~= map[id] then
					set(nearest)
				end
			end
			track.InputBegan:Connect(function(input)
				if pressed(input) then
					dragging = dragTo
					dragTo(input.Position.X)
				end
			end)
		end
		show()
	end

	local done = false
	button(panel, {
		Text = "CONTINUE",
		Filled = true,
		Accent = accent,
		Position = UDim2.new(1, -240, 0, ROW_TOP + #SETTINGS * ROW_HEIGHT + 6),
		Size = UDim2.fromOffset(240, 48),
	}, function()
		if done then
			return
		end
		done = true
		local text = Preferences.Serialize(map)
		if text ~= "" then
			ReplicatedStorage:WaitForChild("SetPreferences"):FireServer(text)
			-- keep showing the pick until the server's answer arrives
			local changed
			changed = player:GetAttributeChangedSignal(Preferences.Attribute):Connect(function()
				if player:GetAttribute(Preferences.Attribute) == text then
					changed:Disconnect()
					Preferences.Preview(nil)
				end
			end)
			task.delay(SAVE_PREVIEW_TIMEOUT, function()
				changed:Disconnect()
				Preferences.Preview(nil)
			end)
		else
			Preferences.Preview(nil)
		end
		panel:Destroy()
		onDone()
	end)
end

return FirstSetup
