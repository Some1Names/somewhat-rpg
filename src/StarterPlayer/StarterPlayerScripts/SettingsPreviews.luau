-- The previews in the Settings card: for a setting whose change you can see or hear, a
-- small live sample of it at the value it's set to (the vignette over a scene, the field
-- of view's cone from above, a swaying card, the crosshair, damage numbers, the colour
-- filter's swatches before and after, the low health edges, the combo counter, an area
-- name, the key hints, and a volume's PLAY SAMPLE). SettingsPreviews.For(id) is nil for a
-- setting without one, or { build(box) -> state, paint(state, value, ink), step(state,
-- clock, value) } (step only for the moving ones). Square everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local AudioMix = require(script.Parent:WaitForChild("AudioMix"))
local Crosshair = require(script.Parent:WaitForChild("Crosshair"))
local Hub = require(script.Parent:WaitForChild("Hub"))

local Theme = Hub.Theme
local Style = HudConfig.Style
local WHITE = Color3.new(1, 1, 1)
local DIM = 0.75 -- how see-through a sample is while its setting is off

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
	props.Font = props.Font or Theme.LabelFont
	props.TextColor3 = props.TextColor3 or WHITE
	return make("TextLabel", props)
end

-- a stand-in for the world: a dull sky-to-ground fade
local function scene(box)
	local back = make("Frame", { Parent = box, Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0 })
	make("UIGradient", {
		Parent = back,
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(120, 140, 160), Color3.fromRGB(70, 80, 70)),
	})
	return back
end

-- four edge strips with gradients fading inward, like Vignette and LowHealth
local function edges(box, color, depth)
	local strips = {}
	for _, edge in ipairs({
		{ UDim2.fromScale(1, depth), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, depth), UDim2.fromScale(0, 1 - depth), 270 },
		{ UDim2.fromScale(depth, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(depth, 1), UDim2.fromScale(1 - depth, 0), 180 },
	}) do
		local strip = make("Frame", { Parent = box, Size = edge[1], Position = edge[2], BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 2 })
		table.insert(strips, make("UIGradient", { Parent = strip, Rotation = edge[3] }))
	end
	return strips
end

local function fadeEdges(strips, opacity)
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - opacity),
		NumberSequenceKeypoint.new(0.3, 1 - opacity * 0.45),
		NumberSequenceKeypoint.new(0.65, 1 - opacity * 0.12),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, gradient in ipairs(strips) do
		gradient.Transparency = fade
	end
end

-- a sample that's only shown dimmed while its ON/OFF setting is off
local function dimmed(state, on)
	for _, label in ipairs(state.dim) do
		label.TextTransparency = on and 0 or DIM
	end
end

-- a colour through a ColourFilters look, roughly as the ColorCorrection draws it
local function filtered(color, look)
	if not look then
		return color
	end
	local r, g, b = color.R * look.tint.R, color.G * look.tint.G, color.B * look.tint.B
	local grey = 0.299 * r + 0.587 * g + 0.114 * b
	local function channel(value)
		value = grey + (value - grey) * (1 + look.saturation)
		return math.clamp((value - 0.5) * (1 + look.contrast) + 0.5, 0, 1)
	end
	return Color3.new(channel(r), channel(g), channel(b))
end

local SWATCHES = {
	Color3.fromRGB(220, 50, 50),
	Color3.fromRGB(240, 140, 40),
	Color3.fromRGB(235, 210, 60),
	Color3.fromRGB(70, 190, 80),
	Color3.fromRGB(60, 200, 210),
	Color3.fromRGB(60, 100, 220),
	Color3.fromRGB(160, 80, 210),
}

-- a volume's preview: its level as a bar, and PLAY SAMPLE through its group
local function volume(groupName)
	return {
		build = function(box)
			local state = {}
			local button = make("TextButton", {
				Parent = box,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromOffset(170, 34),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				Font = Theme.TitleFont,
				Text = "▶  PLAY SAMPLE",
				TextSize = 16,
				TextColor3 = WHITE,
			})
			state.edge = make("UIStroke", { Parent = button, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
			button.Activated:Connect(function()
				AudioMix.Sample(groupName)
			end)
			local back = make("Frame", {
				Parent = box,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.4, 30),
				Size = UDim2.fromOffset(170, 4),
				BackgroundColor3 = Theme.BarBack,
				BorderSizePixel = 0,
			})
			state.fill = make("Frame", { Parent = back, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 })
			return state
		end,
		paint = function(state, value, ink)
			state.fill.Size = UDim2.fromScale(value / 100, 1)
			state.fill.BackgroundColor3 = ink
			state.edge.Color = ink
		end,
	}
end

local PREVIEWS = {}

PREVIEWS.Vignette = {
	build = function(box)
		scene(box)
		return { strips = edges(box, Color3.new(0, 0, 0), 0.3) }
	end,
	paint = function(state, value)
		fadeEdges(state.strips, 0.45 * value / 100)
	end,
}

PREVIEWS.LowHealthEdges = {
	build = function(box)
		scene(box)
		return { strips = edges(box, Color3.fromRGB(200, 20, 30), 0.3) }
	end,
	paint = function(state, value)
		state.on = value
	end,
	step = function(state, clock)
		fadeEdges(state.strips, state.on and 0.45 * (0.75 + 0.25 * math.sin(clock * 6)) or 0)
	end,
}

-- the field of view from above: you at the bottom, the cone you see, the default's lines faint
PREVIEWS.Fov = {
	build = function(box)
		local state = { lines = {} }
		local origin = UDim2.new(0.5, 0, 1, -14)
		-- a frame turns about its middle, so each line is the top half of one centred on you
		for i, faint in ipairs({ true, true, false, false }) do
			local pivot = make("Frame", {
				Parent = box,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = origin,
				Size = UDim2.fromOffset(2, 240),
				BackgroundTransparency = 1,
			})
			state.lines[i] = make("Frame", {
				Parent = pivot,
				Size = UDim2.fromScale(1, 0.5),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = faint and 0.8 or 0,
				BorderSizePixel = 0,
			})
			state["pivot" .. i] = pivot
		end
		make("Frame", { Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = origin, Size = UDim2.fromOffset(8, 8), BackgroundColor3 = WHITE, BorderSizePixel = 0 })
		state.label = text(box, {
			Font = Theme.MonoFont,
			TextSize = 12,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromOffset(220, 14),
		})
		local default = Preferences.Option("Fov").default
		state.pivot1.Rotation, state.pivot2.Rotation = -default / 2, default / 2
		return state
	end,
	paint = function(state, value, ink)
		-- the camera's FieldOfView is up and down; across a wide screen it sees about this much more
		state.pivot3.Rotation, state.pivot4.Rotation = -value / 2, value / 2
		state.lines[3].BackgroundColor3, state.lines[4].BackgroundColor3 = ink, ink
		state.label.Text = string.format("%d°  (DEFAULT %d°)", value, Preferences.Option("Fov").default)
	end,
}

-- a little HUD card drifting as it would, at the setting's strength
local function sway(width, height)
	return {
		build = function(box)
			local card = make("Frame", {
				Parent = box,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(width, height),
				BackgroundColor3 = Style.Glass,
				BackgroundTransparency = Style.GlassTransparency,
				BorderSizePixel = 0,
			})
			make("UIStroke", { Parent = card, Color = WHITE, Transparency = Style.EdgeTransparency })
			make("Frame", { Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, -20), BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, BorderSizePixel = 0 })
			return { card = card }
		end,
		paint = function() end,
		step = function(state, clock, value)
			local amount = 14 * value / 100
			state.card.Position = UDim2.new(0.5, math.sin(clock * 1.7) * amount, 0.5, math.sin(clock * 2.3) * amount * 0.4)
		end,
	}
end
PREVIEWS.HudSway = sway(120, 46)
PREVIEWS.StatusSway = sway(110, 10)

PREVIEWS.Xhair = {
	build = function(box)
		scene(box)
		local holder = make("Frame", {
			Parent = box,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			ZIndex = 3,
		})
		make("UIScale", { Parent = holder, Scale = 2 })
		return { holder = holder }
	end,
	paint = function(state, value)
		Crosshair.Build(state.holder, Preferences.Option("Xhair").choices[value])
		make("UIScale", { Parent = state.holder, Scale = 2 })
	end,
}

-- a normal hit and a critical, as HitFeedback draws them
local function damage(id)
	return {
		build = function(box)
			scene(box)
			local state = { dim = {} }
			for i, sample in ipairs({ { "128", 0.35 }, { "256!", 0.68 } }) do
				local label = text(box, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(sample[2], 0.5),
					Size = UDim2.fromOffset(160, 80),
					Text = sample[1],
					Font = Enum.Font.Highway,
					ZIndex = 3,
				})
				state[i] = { label = label, stroke = make("UIStroke", { Parent = label, Thickness = 2 }) }
				table.insert(state.dim, label)
			end
			return state
		end,
		paint = function(state)
			local scale = Preferences.Get("DmgSize") / 100
			local colors = HudConfig.DamageNumberColors[Preferences.Get("DmgColor")]
			state[1].label.TextSize = 24 * scale
			state[1].label.TextColor3 = colors.text
			state[1].stroke.Color = colors.outline
			state[2].label.TextSize = 36 * scale
			state[2].label.TextColor3 = Color3.fromRGB(255, 205, 60)
			state[2].stroke.Color = Color3.fromRGB(60, 30, 0)
			dimmed(state, id ~= "DamageNumbers" or Preferences.Get("DamageNumbers"))
		end,
	}
end
PREVIEWS.DamageNumbers = damage("DamageNumbers")
PREVIEWS.DmgSize = damage("DmgSize")
PREVIEWS.DmgColor = damage("DmgColor")

PREVIEWS.Filter = {
	build = function(box)
		local state = { before = {}, after = {} }
		for row, name in ipairs({ "OFF", "ON" }) do
			local y = row == 1 and 0.2 or 0.58
			state[name .. "Label"] = text(box, {
				Font = Theme.MonoFont,
				TextSize = 11,
				TextColor3 = Theme.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.new(0, 14, y, 0),
				Size = UDim2.fromOffset(90, 30),
				Text = name == "OFF" and "OFF" or "",
			})
			for i, color in ipairs(SWATCHES) do
				local swatch = make("Frame", {
					Parent = box,
					Position = UDim2.new(0, 110 + (i - 1) * 32, y, 0),
					Size = UDim2.fromOffset(28, 30),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
				})
				table.insert(row == 1 and state.before or state.after, swatch)
			end
		end
		return state
	end,
	paint = function(state, value)
		local name = Preferences.Option("Filter").choices[value]
		local look = HudConfig.ColourFilters[name]
		state.ONLabel.Text = look and string.sub(name, 1, 6) .. "." or "SAME"
		for i, swatch in ipairs(state.after) do
			swatch.BackgroundColor3 = filtered(SWATCHES[i], look)
		end
	end,
}

PREVIEWS.ComboCounter = {
	build = function(box)
		local state = { dim = {} }
		table.insert(state.dim, text(box, { Text = "12", Font = Style.TitleFont, TextSize = 48, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.42, 0), Size = UDim2.fromOffset(100, 50), TextXAlignment = Enum.TextXAlignment.Right }))
		table.insert(state.dim, text(box, { Text = "HITS", Font = Style.MonoFont, TextSize = 12, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0.42, 26), Size = UDim2.fromOffset(100, 16), TextXAlignment = Enum.TextXAlignment.Right }))
		return state
	end,
	paint = function(state, value)
		dimmed(state, value)
	end,
}

PREVIEWS.ZoneNames = {
	build = function(box)
		local state = { dim = {} }
		table.insert(state.dim, text(box, { Text = "MARKET SQUARE", Font = Style.TitleFont, TextSize = 30, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(1, 0, 0, 36) }))
		state.line = make("Frame", { Parent = box, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 22), Size = UDim2.fromOffset(160, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0 })
		return state
	end,
	paint = function(state, value)
		dimmed(state, value)
		state.line.BackgroundTransparency = value and 0 or DIM
	end,
}

PREVIEWS.KeyHints = {
	build = function(box)
		local state = { dim = {}, edges = {} }
		local row = make("Frame", { Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 })
		make("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		for i, pair in ipairs({ { "Q", "DASH" }, { "Space", "DOUBLE JUMP" }, { "Shift", "SPRINT" } }) do
			local chip = text(row, { LayoutOrder = i * 2, Text = pair[1], Font = Style.MonoFont, TextSize = 9, Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X })
			make("UIPadding", { Parent = chip, PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })
			table.insert(state.edges, make("UIStroke", { Parent = chip, Color = WHITE, Transparency = Style.ChipEdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }))
			table.insert(state.dim, chip)
			table.insert(state.dim, text(row, { LayoutOrder = i * 2 + 1, Text = pair[2] .. "  ", TextSize = 11, Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X }))
		end
		return state
	end,
	paint = function(state, value)
		dimmed(state, value)
		for _, edge in ipairs(state.edges) do
			edge.Transparency = value and Style.ChipEdgeTransparency or 0.9
		end
	end,
}

PREVIEWS.VolMaster = volume("Master")
PREVIEWS.VolFx = volume("Effects")
PREVIEWS.VolUi = volume("Interface")

local SettingsPreviews = {}

function SettingsPreviews.For(id)
	return PREVIEWS[id]
end

return SettingsPreviews
