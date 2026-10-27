-- The character customizer for an empty slot. A codename, then a catalogue split into tabs:
-- BODY (skin colour), HAIR (square tiles that show each hair on a head, and its colour),
-- FACE (square tiles showing each face) and OUTFIT (top and bottom colours). A tile is the
-- button: pressing one replaces the current hair or face. Colours come from one colour wheel
-- (hue and saturation round it, brightness on the bar beside it, or type a hex), so any
-- colour will do. The big preview on the right is the player's own character (a stripped,
-- anchored clone in a ViewportFrame, as HubPose does) wearing the look through CharacterLook;
-- it turns slowly on an accent ring and can be dragged. Styles with no part in
-- ReplicatedStorage.CharacterParts are hidden. CREATE asks the server (SlotAction "Create")
-- and, on success, lets the player in. Also holds the helpers SlotMenu shares (buttons,
-- tween, the dressed preview, the backdrop). Square everything (the wheel is the one round
-- thing); the accent is the hub's.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CharacterLook = require(ReplicatedStorage:WaitForChild("CharacterLook"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SlotConfig = require(ReplicatedStorage:WaitForChild("SlotConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme
local remote = ReplicatedStorage:WaitForChild("SlotAction")

local PANEL_WIDTH = 480
local TILE_SIZE = 84
local WHEEL_SIZE = 220
local WHEEL_SEGMENTS = 60 -- each bar of the wheel covers a direction and its opposite
local FIELD_OF_VIEW = 30
local CAMERA_YAW = 20 -- degrees round from straight in front
local LOOK_HEIGHT = -0.25 -- studs above the root part the camera looks at (the middle of a figure, feet to head)
local FEET = -3.05 -- the root part's height above the floor of the preview, negated
local TURN_SPEED = 0.6 -- radians a second while nobody drags
local DRAG_SPEED = 0.012 -- radians a pixel
local TURN_RESUME = 2 -- seconds after a drag before it turns again
local TILE_REFRESH = 0.12 -- s at the least between repainting the tiles while a colour is dragged
local ERROR_COLOR = Color3.fromRGB(235, 90, 90)

local Customizer = {}

-- what the server's short reasons say to the player
local REASONS = {
	load = "Couldn't load your characters, try again",
	save = "Couldn't save, try again",
	busy = "One moment...",
	error = "Something went wrong, try again",
}

function Customizer.Reason(reason)
	return REASONS[reason] or tostring(reason or "Something went wrong")
end

-- a SlotAction call; always a table with `ok`
function Customizer.Call(...)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, reason = "Couldn't reach the server" }
	end
	return result
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
Customizer.Make = make

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Theme.LabelFont
	props.TextColor3 = props.TextColor3 or Theme.NavText
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end
Customizer.Label = label

local function tween(instance, time, props, style)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tweenObject:Play()
	return tweenObject
end
Customizer.Tween = tween

-- the colour to write on a fill of `color`
local function onColor(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B > 0.4 and Theme.Nav or Color3.new(1, 1, 1)
end

-- a square button; `filled` buttons are the accent (the hub's, or props.Accent), the rest
-- dark with a thin edge. An accent line sweeps along the bottom on hover.
local function button(parent, props, onClick)
	local filled = props.Filled
	local accent = props.Accent or Hub.InkAccent()
	props.Filled = nil
	props.Accent = nil
	props.Parent = parent
	props.Font = props.Font or Theme.TitleFont
	props.TextSize = props.TextSize or 18
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	props.BackgroundColor3 = filled and accent or Theme.Nav
	props.TextColor3 = filled and onColor(accent) or Theme.NavText
	local instance = make("TextButton", props)
	make("UIStroke", { Parent = instance, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local sweep = make("Frame", {
		Parent = instance,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = filled and onColor(accent) or accent,
		BorderSizePixel = 0,
		ZIndex = instance.ZIndex + 1,
	})
	instance.MouseEnter:Connect(function()
		if instance.Active then
			tween(sweep, 0.2, { Size = UDim2.new(1, 0, 0, 2) })
		end
	end)
	instance.MouseLeave:Connect(function()
		tween(sweep, 0.2, { Size = UDim2.fromOffset(0, 2) })
	end)
	instance.Activated:Connect(function()
		if instance.Active then
			UiSfx.Play("menuSelect")
			onClick()
		end
	end)
	return instance
end
Customizer.Button = button

-- the dark fill behind a screen, with its edges darker
function Customizer.Backdrop(gui, alpha)
	local fill = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Nav, BackgroundTransparency = alpha, BorderSizePixel = 0 })
	local vignette = make("Frame", { Parent = fill, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 })
	make("UIGradient", {
		Parent = vignette,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.9),
			NumberSequenceKeypoint.new(1, 0.35),
		}),
	})
	return fill
end

-- "01  SKIN" in the accent's colour and a thin rule under it
local function heading(parent, number, title, layoutOrder)
	label(parent, {
		Text = string.format('<font color="#%s">%02d</font>  %s', Hub.InkAccent():ToHex(), number, title),
		RichText = true,
		Font = Theme.MonoFont,
		TextSize = 13,
		TextColor3 = Theme.Muted,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = layoutOrder,
	})
	make("Frame", {
		Parent = parent,
		LayoutOrder = layoutOrder + 1,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	})
end

local function colorOf(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function rgbOf(color)
	return { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) }
end

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- where a pointer is, in the same pixels as AbsolutePosition (the screens ignore the gui inset)
local function pointerAt(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
	end
	return UserInputService:GetMouseLocation()
end

-- a stripped, anchored copy of the player's character in a ViewportFrame, standing on a
-- ring when `ring` (true: the hub's accent; or a Color3); returns the copy (nil with no
-- character). Dress it with Customizer.Dress.
function Customizer.BuildPreview(parent, distance, ring)
	local viewport = make("ViewportFrame", {
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, 1),
	})
	local camera = make("Camera", { Parent = viewport, FieldOfView = FIELD_OF_VIEW })
	local yaw = math.rad(CAMERA_YAW)
	camera.CFrame = CFrame.lookAt(
		Vector3.new(distance * math.sin(yaw), LOOK_HEIGHT + 0.3, -distance * math.cos(yaw)),
		Vector3.new(0, LOOK_HEIGHT, 0)
	)
	viewport.CurrentCamera = camera
	local world = make("WorldModel", { Parent = viewport })
	if ring then
		-- two flat discs (a cylinder's axis is X, so it is turned on its side)
		for _, disc in ipairs({ { 6, 0.35 }, { 9, 0.75 } }) do
			make("Part", {
				Parent = world,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.15, disc[1], disc[1]),
				CFrame = CFrame.new(0, FEET, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Anchored = true,
				CanCollide = false,
				Material = Enum.Material.Neon,
				Color = typeof(ring) == "Color3" and ring or Hub.InkAccent(),
				Transparency = disc[2],
			})
		end
	end
	local character = player.Character
	if not character then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return nil
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("BaseScript") or item:IsA("Tool") or item:IsA("ForceField") or item:IsA("Animator") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	copy:PivotTo(CFrame.new())
	copy.Parent = world
	return copy
end

-- paints `look` on a preview copy and keeps every part anchored (nothing steps its physics)
function Customizer.Dress(model, look, parts)
	CharacterLook.Apply(model, look, parts)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
end

-- a square tile showing one hair or face on a head: a ViewportFrame with the player's own
-- head (so its attachments and shape are right) and a Humanoid, so CharacterLook can dress
-- it like a character. Returns { model } (model nil with no character). `kind` is "hair"
-- or "face".
local function buildHeadTile(parent, kind)
	local viewport = make("ViewportFrame", {
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, 1),
	})
	-- hair is seen from a little way off and to one side; a face straight on and close
	local distance, height, yaw = 7, 0.6, math.rad(20)
	if kind == "face" then
		distance, height, yaw = 3.6, 0, 0
	end
	local camera = make("Camera", { Parent = viewport, FieldOfView = FIELD_OF_VIEW })
	camera.CFrame = CFrame.lookAt(Vector3.new(distance * math.sin(yaw), height + 0.1, -distance * math.cos(yaw)), Vector3.new(0, height, 0))
	viewport.CurrentCamera = camera
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return { model = nil }
	end
	local world = make("WorldModel", { Parent = viewport })
	local model = make("Model", { Name = "TileHead", Parent = world })
	local copy = head:Clone()
	for _, item in ipairs(copy:GetChildren()) do
		if item:IsA("BaseScript") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	copy.Anchored = true
	copy.CFrame = CFrame.new()
	copy.Parent = model
	make("Humanoid", { Parent = model, RigType = Enum.HumanoidRigType.R6 })
	return { model = model }
end

-- a copy of the look with this tile's hair or face in it (a face tile is bald: hair would
-- hide the face)
local function tileLook(look, kind, index)
	local copy = {}
	for key, value in pairs(look) do
		copy[key] = value
	end
	if kind == "face" then
		copy.face = index
		copy.hair = 1
	else
		copy.hair = index
	end
	return copy
end

-- a colour wheel: hue round it, saturation out from the middle, brightness on the bar
-- beside it, and the colour as a swatch with its hex to type into. Built from bars turned
-- about the middle (each bar covers a direction and the opposite one). Returns
-- { Frame, Bind(rgb, onChange) }: Bind points it at a colour and a function to call with
-- the new {r, g, b} when the player changes it.
local function buildPicker(connections)
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, WHEEL_SIZE + 16), BackgroundTransparency = 1 })
	local wheel = make("Frame", { Parent = frame, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(WHEEL_SIZE, WHEEL_SIZE), BackgroundTransparency = 1 })
	local barWidth = math.ceil(math.pi * WHEEL_SIZE / WHEEL_SEGMENTS) + 1
	for index = 0, WHEEL_SEGMENTS - 1 do
		local rotation = index * 180 / WHEEL_SEGMENTS
		local hue = rotation / 360
		local bar = make("Frame", {
			Parent = wheel,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(WHEEL_SIZE, barWidth),
			Rotation = rotation,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		})
		make("UIGradient", {
			Parent = bar,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV((hue + 0.5) % 1, 1, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, 1, 1)),
			}),
		})
	end
	local marker = make("Frame", { Parent = wheel, Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0, ZIndex = 3 })
	make("UIStroke", { Parent = marker, Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local wheelHit = make("TextButton", { Parent = wheel, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5 })

	local slider = make("Frame", { Parent = frame, Position = UDim2.fromOffset(WHEEL_SIZE + 28, 8), Size = UDim2.fromOffset(22, WHEEL_SIZE), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	local sliderGradient = make("UIGradient", { Parent = slider, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)) })
	make("UIStroke", { Parent = slider, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local handle = make("Frame", { Parent = slider, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 })
	make("UIStroke", { Parent = handle, Color = Color3.new(0, 0, 0), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local sliderHit = make("TextButton", { Parent = slider, Size = UDim2.new(1, 8, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5 })

	local side = WHEEL_SIZE + 28 + 22 + 20
	local swatch = make("Frame", { Parent = frame, Position = UDim2.fromOffset(side, 8), Size = UDim2.fromOffset(64, 64), BorderSizePixel = 0 })
	make("UIStroke", { Parent = swatch, Color = Theme.Edge, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	label(frame, { Text = "HEX", Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(side, 82), Size = UDim2.fromOffset(100, 14) })
	local hexBox = make("TextBox", {
		Parent = frame,
		Position = UDim2.fromOffset(side, 98),
		Size = UDim2.fromOffset(110, 32),
		BackgroundColor3 = Theme.Nav,
		BorderSizePixel = 0,
		Font = Theme.MonoFont,
		TextSize = 16,
		TextColor3 = Theme.NavText,
		Text = "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	make("UIStroke", { Parent = hexBox, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	make("UIPadding", { Parent = hexBox, PaddingLeft = UDim.new(0, 8) })

	local hue, saturation, value = 0, 0, 1
	local onChange
	local function render()
		local color = Color3.fromHSV(hue, saturation, value)
		local radius = WHEEL_SIZE / 2
		local angle = hue * 2 * math.pi
		marker.Position = UDim2.fromOffset(radius + saturation * radius * math.cos(angle) - 7, radius + saturation * radius * math.sin(angle) - 7)
		marker.BackgroundColor3 = color
		swatch.BackgroundColor3 = color
		sliderGradient.Color = ColorSequence.new(Color3.fromHSV(hue, saturation, 1), Color3.new(0, 0, 0))
		handle.Position = UDim2.fromScale(0, 1 - value)
		if not hexBox:IsFocused() then
			hexBox.Text = SlotConfig.FormatColor(rgbOf(color))
		end
	end
	local function changed()
		render()
		if onChange then
			onChange(rgbOf(Color3.fromHSV(hue, saturation, value)))
		end
	end
	local function setFromRGB(rgb)
		hue, saturation, value = colorOf(rgb):ToHSV()
		render()
	end

	local dragging = nil -- "wheel" or "slider"
	local function drag(kind, position)
		if kind == "wheel" then
			local center = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
			local delta = position - center
			saturation = math.clamp(delta.Magnitude / (wheel.AbsoluteSize.X / 2), 0, 1)
			hue = (math.atan2(delta.Y, delta.X) / (2 * math.pi)) % 1
		else
			value = 1 - math.clamp((position.Y - slider.AbsolutePosition.Y) / slider.AbsoluteSize.Y, 0, 1)
		end
		changed()
	end
	wheelHit.InputBegan:Connect(function(input)
		if isPointer(input) then
			dragging = "wheel"
			drag("wheel", pointerAt(input))
		end
	end)
	sliderHit.InputBegan:Connect(function(input)
		if isPointer(input) then
			dragging = "slider"
			drag("slider", pointerAt(input))
		end
	end)
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			drag(dragging, pointerAt(input))
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if dragging and isPointer(input) then
			dragging = nil
		end
	end))
	hexBox.FocusLost:Connect(function()
		local rgb = SlotConfig.ParseColor((hexBox.Text:gsub("[#%s]", "")):upper())
		if rgb then
			setFromRGB(rgb)
			changed()
		else
			render()
		end
	end)

	return {
		Frame = frame,
		Bind = function(rgb, callback)
			onChange = nil
			setFromRGB(rgb)
			onChange = callback
		end,
	}
end

-- Opens the customizer for an empty slot. onDone(true) once the character is made and
-- the player let in, onDone(false) on BACK.
function Customizer.Open(slot, onDone)
	local parts = ReplicatedStorage:FindFirstChild("CharacterParts")
	local look = SlotConfig.DefaultLook()
	local busy = false
	local accent = Hub.InkAccent()
	local connections = {}

	local gui = make("ScreenGui", {
		Name = "Customizer",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 52,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	gui.Destroying:Once(function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end)
	Customizer.Backdrop(gui, 0.25)

	-- the left panel scrolls: a small screen still reaches CREATE
	local panel = make("ScrollingFrame", {
		Parent = gui,
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.new(0, PANEL_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	make("UIPadding", { Parent = panel, PaddingTop = UDim.new(0, 70), PaddingBottom = UDim.new(0, 30), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12) })
	make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 16) })

	label(panel, {
		Text = string.format('[ <font color="#%s">SLOT %02d</font> ]', accent:ToHex(), slot),
		RichText = true,
		Font = Theme.MonoFont,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
	})
	label(panel, {
		Text = "NEW CHARACTER",
		Font = Theme.TitleFont,
		TextSize = 40,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
	})

	-- the codename: no box, just a line under it that lights up while typing
	local nameBlock = make("Frame", {
		Parent = panel,
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	make("UIListLayout", { Parent = nameBlock, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
	heading(nameBlock, 0, "CODENAME", 1)
	local nameBox = make("TextBox", {
		Parent = nameBlock,
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.TitleFont,
		TextSize = 28,
		TextColor3 = Theme.NavText,
		PlaceholderText = "Codename",
		PlaceholderColor3 = Theme.Muted,
		Text = "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local underline = make("Frame", {
		Parent = nameBlock,
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Theme.Muted,
		BorderSizePixel = 0,
	})
	nameBox.Focused:Connect(function()
		tween(underline, 0.2, { BackgroundColor3 = accent })
	end)
	nameBox.FocusLost:Connect(function()
		tween(underline, 0.2, { BackgroundColor3 = Theme.Muted })
	end)
	local hint = label(nameBlock, {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 16),
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Muted,
	})

	-- the preview, on the right: it turns on its own and can be dragged
	local previewHolder = make("Frame", {
		Parent = gui,
		Position = UDim2.new(0, 60 + PANEL_WIDTH + 20, 0, 0),
		Size = UDim2.new(1, -(60 + PANEL_WIDTH + 80), 1, 0),
		BackgroundTransparency = 1,
	})
	local model = Customizer.BuildPreview(previewHolder, 17.5, true)
	local hit = make("TextButton", {
		Parent = previewHolder,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
	})
	label(previewHolder, {
		Text = "DRAG TO TURN",
		Font = Theme.MonoFont,
		TextSize = 12,
		TextColor3 = Theme.Muted,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})
	local angle = 0
	local turning = false
	local lastX = 0
	local turnAgainAt = 0
	hit.InputBegan:Connect(function(input)
		if isPointer(input) then
			turning = true
			lastX = input.Position.X
		end
	end)
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if turning and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			angle += (input.Position.X - lastX) * DRAG_SPEED
			lastX = input.Position.X
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if turning and isPointer(input) then
			turning = false
			turnAgainAt = os.clock() + TURN_RESUME
		end
	end))

	-- the tiles, kept so they can be repainted when a colour (or the face a hair is shown with) changes
	local tiles = {} -- { model, kind, index }
	local previewDirty = false
	local tilesDirty = false
	local lastTilesAt = 0
	local function markDirty()
		previewDirty = true
		tilesDirty = true
	end
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if model then
			if previewDirty then
				previewDirty = false
				Customizer.Dress(model, look, parts)
			end
			if not turning and os.clock() >= turnAgainAt then
				angle += dt * TURN_SPEED
			end
			model:PivotTo(CFrame.Angles(0, angle, 0))
		end
		if tilesDirty and os.clock() - lastTilesAt >= TILE_REFRESH then
			tilesDirty = false
			lastTilesAt = os.clock()
			for _, tile in ipairs(tiles) do
				if tile.model then
					Customizer.Dress(tile.model, tileLook(look, tile.kind, tile.index), parts)
					local head = tile.model:FindFirstChild("Head")
					if head then
						head.CFrame = CFrame.new()
					end
				end
			end
		end
	end))

	-- the catalogue: a tab bar and one page at a time
	local picker = buildPicker(connections)
	local tabBar = make("Frame", { Parent = panel, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	local pages = make("Frame", { Parent = panel, LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	local tabs = {} -- name -> { button, line, page, show }
	local currentTab

	local function newPage(name, tabIndex)
		local page = make("Frame", { Parent = pages, Visible = false, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIListLayout", { Parent = page, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })
		local tabButton = make("TextButton", {
			Parent = tabBar,
			Position = UDim2.new((tabIndex - 1) * 0.25, 0, 0, 0),
			Size = UDim2.new(0.25, -4, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.TitleFont,
			TextSize = 20,
			Text = name,
			TextColor3 = Theme.Muted,
			AutoButtonColor = false,
		})
		local line = make("Frame", { Parent = tabButton, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0 })
		tabs[name] = { button = tabButton, line = line, page = page }
		return page
	end

	-- the colour wheel sits in whichever page is showing; each page says which colour it edits
	local pickerSlots = {} -- tab name -> a Frame to hold the wheel
	local pickerField = {} -- tab name -> the look field the wheel edits there
	local function bindPicker(tabName)
		local field = pickerField[tabName]
		if not field then
			return
		end
		picker.Frame.Parent = pickerSlots[tabName]
		picker.Bind(look[field], function(rgb)
			look[field] = rgb
			markDirty()
		end)
	end
	local function showTab(name)
		currentTab = name
		for tabName, tab in pairs(tabs) do
			local active = tabName == name
			tab.page.Visible = active
			tab.button.TextColor3 = active and Theme.NavText or Theme.Muted
			tween(tab.line, 0.2, { BackgroundTransparency = active and 0 or 1 })
		end
		bindPicker(name)
	end

	-- a page's slot for the wheel
	local function addPickerSlot(page, tabName, field, order)
		local slotFrame = make("Frame", { Parent = page, LayoutOrder = order, Size = UDim2.new(1, 0, 0, WHEEL_SIZE + 16), BackgroundTransparency = 1 })
		pickerSlots[tabName] = slotFrame
		pickerField[tabName] = field
	end

	-- a grid of square tiles, each a head showing one hair or face; pressing one replaces
	-- the current choice
	local function addTiles(page, kind, names, has, order)
		local grid = make("Frame", { Parent = page, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIGridLayout", { Parent = grid, CellSize = UDim2.fromOffset(TILE_SIZE, TILE_SIZE), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		local chosen = {} -- index -> its tile frame
		local function refresh(animate)
			for index, tile in pairs(chosen) do
				local selected = look[kind] == index
				local stroke = tile:FindFirstChildOfClass("UIStroke")
				stroke.Color = selected and Color3.new(1, 1, 1) or Theme.Edge
				stroke.Transparency = selected and 0 or 0.6
				stroke.Thickness = selected and 3 or 1
				if selected and animate then
					local pop = tile:FindFirstChild("Pop")
					pop.Scale = 1.15
					tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				end
			end
		end
		for index = 1, #names do
			if has(parts, index) then
				local tile = make("Frame", { Parent = grid, LayoutOrder = index, BackgroundColor3 = Theme.Nav, BackgroundTransparency = 0.2, BorderSizePixel = 0 })
				make("UIStroke", { Parent = tile, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
				make("UIScale", { Name = "Pop", Parent = tile })
				local built = buildHeadTile(tile, kind)
				table.insert(tiles, { model = built.model, kind = kind, index = index })
				label(tile, {
					Text = string.upper(names[index]),
					Font = Theme.MonoFont,
					TextSize = 11,
					BackgroundTransparency = 0.35,
					BackgroundColor3 = Color3.new(0, 0, 0),
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 16),
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 3,
				})
				local pick = make("TextButton", { Parent = tile, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5 })
				pick.Activated:Connect(function()
					UiSfx.Play("menuSelect")
					look[kind] = index
					refresh(true)
					markDirty()
				end)
				chosen[index] = tile
			end
		end
		refresh(false)
	end

	-- BODY: the skin colour
	local body = newPage("BODY", 1)
	heading(body, 1, "SKIN COLOUR", 1)
	addPickerSlot(body, "BODY", "skin", 3)

	-- HAIR: the style, then its colour
	local hair = newPage("HAIR", 2)
	heading(hair, 1, "STYLE", 1)
	addTiles(hair, "hair", SlotConfig.HairStyles, CharacterLook.HasHair, 3)
	heading(hair, 2, "HAIR COLOUR", 4)
	addPickerSlot(hair, "HAIR", "hairColor", 6)

	-- FACE: the style
	local face = newPage("FACE", 3)
	heading(face, 1, "STYLE", 1)
	addTiles(face, "face", SlotConfig.FaceStyles, CharacterLook.HasFace, 3)

	-- OUTFIT: top or bottom, then its colour
	local outfit = newPage("OUTFIT", 4)
	heading(outfit, 1, "PIECE", 1)
	local chips = make("Frame", { Parent = outfit, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	local chipFor = {}
	local function selectPiece(field)
		pickerField.OUTFIT = field
		for chipField, chip in pairs(chipFor) do
			local selected = chipField == field
			local stroke = chip:FindFirstChildOfClass("UIStroke")
			stroke.Color = selected and Color3.new(1, 1, 1) or Theme.Edge
			stroke.Transparency = selected and 0 or 0.6
			stroke.Thickness = selected and 2 or 1
		end
		if currentTab == "OUTFIT" then
			bindPicker("OUTFIT")
		end
	end
	for position, piece in ipairs({ { "top", "TOP" }, { "bottom", "BOTTOM" } }) do
		local chip = button(chips, { Text = piece[2], TextSize = 16, Position = UDim2.new((position - 1) * 0.5, position == 2 and 4 or 0, 0, 0), Size = UDim2.new(0.5, -4, 1, 0) }, function()
			selectPiece(piece[1])
		end)
		chipFor[piece[1]] = chip
	end
	heading(outfit, 2, "COLOUR", 4)
	addPickerSlot(outfit, "OUTFIT", "top", 6)
	selectPiece("top")

	for name, tab in pairs(tabs) do
		tab.button.Activated:Connect(function()
			UiSfx.Play("menuSelect")
			showTab(name)
		end)
	end
	showTab("BODY")

	-- the answer from the server, or what is wrong with the codename
	local status = label(panel, {
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		TextSize = 14,
		TextColor3 = ERROR_COLOR,
	})
	local buttons = make("Frame", { Parent = panel, LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 })
	local create
	create = button(buttons, { Text = "CREATE", Filled = true, Size = UDim2.new(0.5, -4, 1, 0) }, function()
		if busy then
			return
		end
		local name, reason = SlotConfig.CleanName(nameBox.Text)
		if not name then
			status.Text = reason
			return
		end
		busy = true
		create.Text = "..."
		status.Text = ""
		local result = Customizer.Call("Create", slot, name, SlotConfig.FormatLook(look))
		busy = false
		create.Text = "CREATE"
		if result.ok then
			gui:Destroy()
			onDone(true)
		else
			status.Text = Customizer.Reason(result.reason)
		end
	end)
	button(buttons, { Text = "BACK", Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0) }, function()
		if busy then
			return
		end
		gui:Destroy()
		onDone(false)
	end)

	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #nameBox.Text > SlotConfig.NameMax then
			nameBox.Text = nameBox.Text:sub(1, SlotConfig.NameMax)
			return
		end
		status.Text = ""
		if nameBox.Text == "" then
			hint.Text = ""
			return
		end
		local name, reason = SlotConfig.CleanName(nameBox.Text)
		hint.Text = name and "" or reason
	end)

	markDirty()
end

return Customizer
