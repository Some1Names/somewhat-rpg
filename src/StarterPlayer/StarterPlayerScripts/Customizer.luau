-- The character customizer: for an empty slot (a new character) or an existing one
-- (recustomize: its codename stays, its look changes). On the left a smoked-glass panel: the
-- codename, then a catalogue split into tabs: BODY (skin colour), HAIR (square tiles that show
-- each hair on a head, and its colour), FACE (tiles showing each face), OUTFIT (shirt and
-- pants tiles, shown worn, no colours: a picture keeps its own). A tile is the
-- button: pressing one replaces the current choice. Colours come from one colour wheel (hue and
-- saturation round it, brightness on the bar beside it, type a hex, or press one of the
-- palette's presets). Only the page under the tabs scrolls, so the buttons stay on screen. On
-- the right the stage: the player's own character (a stripped, anchored clone in a
-- ViewportFrame, as HubPose does) wearing the look through CharacterLook, standing on a ring
-- inside corner brackets, with the slot's big faint number behind it and the codename under it
-- as it is typed. It turns slowly and can be dragged; HAIR, FACE and EXTRAS bring the camera in
-- on the head (and the figure turns to face it). Styles with no part in
-- ReplicatedStorage.CharacterParts are hidden. Under it all: BACK (plain text at the bottom
-- left, as on the slot screen), RANDOMIZE (rolls a whole look) and CREATE (or SAVE), which asks
-- the server (SlotAction "Create" / "Recustomize"). A small screen shrinks the whole layout.
-- Also holds the helpers SlotMenu shares (buttons, tween, the dressed preview, the backdrop).
-- Square everything (the wheel is the one round thing); the accent is the hub's.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CharacterLook = require(ReplicatedStorage:WaitForChild("CharacterLook"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SlotConfig = require(ReplicatedStorage:WaitForChild("SlotConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme
local remote = ReplicatedStorage:WaitForChild("SlotAction")

local MARGIN = 48 -- the screen's sides to the panel and the stage (BACK lines up with the panel)
local GAP = 32 -- between the panel and the stage
local TOP_GAP = 14 -- under Roblox's band across the top
local ROBLOX_BAR = 58 -- Roblox's band, while GetGuiInset still says 0
local FOOTER = 96 -- the strip under the panel and the stage: BACK, RANDOMIZE and CREATE
local MIN_WIDTH, MIN_HEIGHT = 980, 680 -- a smaller screen shrinks the whole layout to fit
local PANEL_WIDTH = 460
local PANEL_PAD = 22
local HEADER = 126 -- the panel's fixed top (slot, title, tabs); the page scrolls under it
local TILE_SIZE = 75 -- five to a row
local WHEEL_SIZE = 150
local WHEEL_SEGMENTS = 60 -- each bar of the wheel covers a direction and its opposite
local PRESET_SIZE = 28 -- six to a row, beside the wheel
local FIELD_OF_VIEW = 30
local CAMERA_YAW = 20 -- degrees round from straight in front
local LOOK_HEIGHT = -0.25 -- studs above the root part the camera looks at (the middle of a figure, feet to head)
local BODY_DISTANCE = 17.5 -- studs from the camera to the figure, whole
local HEAD_DISTANCE = 10.5 -- and close up on the head and shoulders (HAIR, FACE, EXTRAS)
local HEAD_DROP = 0.55 -- studs under the head's middle the close up aims at, so the head sits high
local FACE_ANGLE = math.rad(-10) -- how the figure settles close up: nearly facing the camera
local FEET = -3.05 -- the ring's height above the root part, negated
local FLOOR = FEET + 0.075 -- the top of the ring: where the figure's feet stand
local TURN_SPEED = 0.6 -- radians a second while nobody drags
local DRAG_SPEED = 0.012 -- radians a pixel
local TURN_RESUME = 2 -- seconds after a drag before it turns again
local TILE_REFRESH = 0.12 -- s at the least between repainting the tiles while a colour is dragged
local ERROR_COLOR = Color3.fromRGB(235, 90, 90)
local CLOSE_UP = { HAIR = true, FACE = true, EXTRAS = true } -- the tabs that bring the camera in on the head

-- the tile kinds: the CharacterParts prefix, the look field and what a tile shows
local KINDS = {
	hair = { prefix = "Hair", field = "hair", styles = SlotConfig.HairStyles, head = true },
	face = { prefix = "Face", field = "face", styles = SlotConfig.FaceStyles, head = true },
	accessory = { prefix = "Acc", field = "accessory", styles = SlotConfig.AccessoryStyles, head = true },
	shirt = { prefix = "Shirt", field = "shirt", styles = SlotConfig.ShirtStyles, body = true },
	pants = { prefix = "Pants", field = "pants", styles = SlotConfig.PantsStyles, body = true },
}

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

-- "01  SKIN COLOUR" in mono, the number in the accent's colour, and a thin rule from its end
-- to the right edge. A page's first heading (number 1) sits right under the tabs; the rest
-- get some room above them.
local function heading(parent, number, title, layoutOrder)
	local top = number == 1 and 0 or 12
	local row = make("Frame", { Parent = parent, LayoutOrder = layoutOrder, Size = UDim2.new(1, 0, 0, top + 14), BackgroundTransparency = 1 })
	label(row, {
		Text = string.format('<font color="#%s">%02d</font>  %s', Hub.InkAccent():ToHex(), number, title),
		RichText = true,
		Font = Theme.MonoFont,
		TextSize = 12,
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 0, 14),
	})
	local width = TextService:GetTextSize(string.format("%02d  %s", number, title), 12, Theme.MonoFont, Vector2.new(1000, 100)).X + 10
	make("Frame", {
		Parent = row,
		Position = UDim2.fromOffset(width, top + 7),
		Size = UDim2.new(1, -width, 0, 1),
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.75,
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

-- where a pointer is, in the same pixels as AbsolutePosition: those count from under Roblox's band
-- (even on these screens that ignore the gui inset), as a touch's Position does; the mouse's
-- location counts from the very top
local function pointerAt(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end

-- a stripped, anchored copy of the player's character in a ViewportFrame, standing on a
-- ring when `ring` (true: the hub's accent; or a Color3), the camera `distance` studs away
-- and aimed `lookHeight` studs above the root part (a whole figure when left out); returns
-- the copy (nil with no character) and the camera. Dress it with Customizer.Dress.
function Customizer.BuildPreview(parent, distance, ring, lookHeight)
	lookHeight = lookHeight or LOOK_HEIGHT
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
		Vector3.new(distance * math.sin(yaw), lookHeight + 0.3, -distance * math.cos(yaw)),
		Vector3.new(0, lookHeight, 0)
	)
	viewport.CurrentCamera = camera
	local world = make("WorldModel", { Parent = viewport })
	if ring then
		-- a dark disc to stand on, a thin glowing rim round it and a faint halo, each a little
		-- lower than the last (a cylinder's axis is X, so each is turned on its side):
		-- { across, drop, thickness, material, colour, transparency }
		local color = typeof(ring) == "Color3" and ring or Hub.InkAccent()
		for _, disc in ipairs({
			{ 6.4, 0, 0.15, Enum.Material.SmoothPlastic, Color3.fromRGB(16, 17, 20), 0 },
			{ 6.6, 0.01, 0.06, Enum.Material.Neon, color, 0.1 },
			{ 9.5, 0.06, 0.05, Enum.Material.Neon, color, 0.93 },
		}) do
			make("Part", {
				Parent = world,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(disc[3], disc[1], disc[1]),
				CFrame = CFrame.new(0, FEET - disc[2], 0) * CFrame.Angles(0, 0, math.pi / 2),
				Anchored = true,
				CanCollide = false,
				Material = disc[4],
				Color = disc[5],
				Transparency = disc[6],
			})
		end
	end
	local character = player.Character
	if not character then
		return nil, camera
	end
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return nil, camera
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
	return copy, camera
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

-- how far up a preview copy must go for its feet to stand on the ring (it sits where the
-- character's root part is; the copy's pivot is not always where the feet are)
local function standOnRing(model)
	local center, size = model:GetBoundingBox()
	return FLOOR - (center.Position.Y - size.Y / 2)
end

-- a square tile showing one hair, face or accessory on a head: a ViewportFrame with the
-- player's own head (so its attachments and shape are right) and a Humanoid, so CharacterLook
-- can dress it like a character. Returns { model } (model nil with no character).
local function buildHeadTile(parent, kind)
	local viewport = make("ViewportFrame", {
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, 1),
	})
	-- hair and hats are seen from a little way off and to one side; a face straight on and close
	local distance, height, yaw = 7, 0.6, math.rad(20)
	if kind == "face" then
		distance, height, yaw = 3.6, 0, 0
	elseif kind == "accessory" then
		distance, height, yaw = 6, 0.5, math.rad(15)
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
	make("Humanoid", { Parent = model, RigType = Enum.HumanoidRigType.R15 })
	return { model = model }
end

-- a square tile showing a shirt or pants worn: a copy of the player's character in a
-- ViewportFrame, framed on the chest (shirt) or the legs (pants). Returns { model }.
local function buildBodyTile(parent, kind)
	local viewport = make("ViewportFrame", {
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, 1),
	})
	local distance, height, yaw = 9, 0.5, math.rad(20)
	if kind == "pants" then
		height = -1.5
	end
	local camera = make("Camera", { Parent = viewport, FieldOfView = FIELD_OF_VIEW })
	camera.CFrame = CFrame.lookAt(Vector3.new(distance * math.sin(yaw), height + 0.1, -distance * math.cos(yaw)), Vector3.new(0, height, 0))
	viewport.CurrentCamera = camera
	local character = player.Character
	if not character then
		return { model = nil }
	end
	local world = make("WorldModel", { Parent = viewport })
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return { model = nil }
	end
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("BaseScript") or item:IsA("Tool") or item:IsA("ForceField") or item:IsA("Animator") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	copy:PivotTo(CFrame.new())
	copy.Parent = world
	return { model = copy }
end

-- a copy of the look with this tile's style in it (a face tile is bald and a hair tile
-- hatless, a shirt tile has no pants and a pants tile no shirt: they would hide what the tile shows)
local function tileLook(look, kind, index)
	local copy = {}
	for key, value in pairs(look) do
		copy[key] = value
	end
	if kind == "face" then
		copy.hair = 1
		copy.accessory = 1
	elseif kind == "hair" then
		copy.accessory = 1
	elseif kind == "shirt" or kind == "pants" then
		copy.hair = 1
		copy.accessory = 1
		copy.shirt = 1
		copy.pants = 1
	end
	copy[KINDS[kind].field] = index
	return copy
end

-- a colour wheel: hue round it, saturation out from the middle, brightness on the bar
-- beside it, the colour as a swatch with its hex to type into, and the palette's presets to
-- press. Built from bars turned about the middle (each bar covers a direction and the
-- opposite one). Returns { Frame, Bind(rgb, onChange, presets) }: Bind points it at a colour,
-- a function to call with the new {r, g, b} when the player changes it, and the presets
-- (a palette from SlotConfig) to show.
local function buildPicker(connections)
	local frame = make("Frame", { Size = UDim2.new(1, 0, 0, WHEEL_SIZE + 8), BackgroundTransparency = 1 })
	local wheel = make("Frame", { Parent = frame, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(WHEEL_SIZE, WHEEL_SIZE), BackgroundTransparency = 1 })
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

	local slider = make("Frame", { Parent = frame, Position = UDim2.fromOffset(WHEEL_SIZE + 14, 8), Size = UDim2.fromOffset(18, WHEEL_SIZE), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	local sliderGradient = make("UIGradient", { Parent = slider, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)) })
	make("UIStroke", { Parent = slider, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local handle = make("Frame", { Parent = slider, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 })
	make("UIStroke", { Parent = handle, Color = Color3.new(0, 0, 0), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local sliderHit = make("TextButton", { Parent = slider, Size = UDim2.new(1, 8, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5 })

	-- the column beside the bar: the swatch and its hex, then the presets
	local side = WHEEL_SIZE + 14 + 18 + 22
	local swatch = make("Frame", { Parent = frame, Position = UDim2.fromOffset(side, 8), Size = UDim2.fromOffset(44, 44), BorderSizePixel = 0 })
	make("UIStroke", { Parent = swatch, Color = Theme.Edge, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	label(frame, { Text = "HEX", Font = Theme.MonoFont, TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(side + 56, 8), Size = UDim2.fromOffset(100, 14) })
	local hexBox = make("TextBox", {
		Parent = frame,
		Position = UDim2.fromOffset(side + 56, 24),
		Size = UDim2.fromOffset(104, 28),
		BackgroundColor3 = Theme.Nav,
		BorderSizePixel = 0,
		Font = Theme.MonoFont,
		TextSize = 15,
		TextColor3 = Theme.NavText,
		Text = "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	make("UIStroke", { Parent = hexBox, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	make("UIPadding", { Parent = hexBox, PaddingLeft = UDim.new(0, 8) })
	local presetsLabel = label(frame, { Text = "PRESETS", Font = Theme.MonoFont, TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(side, 66), Size = UDim2.fromOffset(100, 14) })
	local presetGrid = make("Frame", { Parent = frame, Position = UDim2.fromOffset(side, 84), Size = UDim2.fromOffset(6 * PRESET_SIZE + 5 * 6, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	make("UIGridLayout", { Parent = presetGrid, CellSize = UDim2.fromOffset(PRESET_SIZE, PRESET_SIZE), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	local hue, saturation, value = 0, 0, 1
	local current = { 255, 255, 255 } -- the colour as {r, g, b}, exactly as the look holds it
	local onChange
	local chips = {} -- the preset buttons, made as a palette needs them
	local presets = {}
	local hovered = nil -- the preset chip under the mouse
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
			hexBox.Text = SlotConfig.FormatColor(current)
		end
		for index, chip in ipairs(chips) do
			local rgb = presets[index]
			local selected = rgb ~= nil and rgb[1] == current[1] and rgb[2] == current[2] and rgb[3] == current[3]
			local stroke = chip:FindFirstChildOfClass("UIStroke")
			stroke.Color = selected and Color3.new(1, 1, 1) or Theme.Edge
			stroke.Transparency = (selected and 0) or (hovered == index and 0.2) or 0.7
			stroke.Thickness = selected and 2 or 1
		end
	end
	local function changed()
		current = rgbOf(Color3.fromHSV(hue, saturation, value))
		render()
		if onChange then
			onChange(current)
		end
	end
	local function setFromRGB(rgb)
		current = { rgb[1], rgb[2], rgb[3] }
		hue, saturation, value = colorOf(rgb):ToHSV()
		render()
	end
	-- a preset or a typed hex: taken exactly (the wheel's own colours go through HSV)
	local function choose(rgb)
		setFromRGB(rgb)
		if onChange then
			onChange(current)
		end
	end
	local function newChip(index)
		local chip = make("TextButton", { Parent = presetGrid, LayoutOrder = index, BorderSizePixel = 0, Text = "", AutoButtonColor = false })
		make("UIStroke", { Parent = chip, Color = Theme.Edge, Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		chip.MouseEnter:Connect(function()
			hovered = index
			render()
		end)
		chip.MouseLeave:Connect(function()
			if hovered == index then
				hovered = nil
				render()
			end
		end)
		chip.Activated:Connect(function()
			if presets[index] then
				UiSfx.Play("menuSelect")
				choose(presets[index])
			end
		end)
		return chip
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
			choose(rgb)
		else
			render()
		end
	end)

	return {
		Frame = frame,
		Bind = function(rgb, callback, palette, presetsOnly)
			onChange = nil
			-- presets only: no wheel, bar, swatch or hex, just the palette to press
			for _, piece in ipairs({ wheel, slider, swatch, hexBox, presetsLabel }) do
				piece.Visible = not presetsOnly
			end
			for _, child in ipairs(frame:GetChildren()) do
				if child:IsA("TextLabel") and child ~= presetsLabel then
					child.Visible = not presetsOnly
				end
			end
			presetGrid.Position = presetsOnly and UDim2.fromOffset(0, 8) or UDim2.fromOffset(side, 84)
			presets = palette or {}
			for index = #chips + 1, #presets do
				chips[index] = newChip(index)
			end
			for index, chip in ipairs(chips) do
				chip.Visible = presets[index] ~= nil
				if presets[index] then
					chip.BackgroundColor3 = colorOf(presets[index])
				end
			end
			setFromRGB(rgb)
			onChange = callback
		end,
	}
end

-- Opens the customizer for slot `slot`. options: { name, lookText } to recustomize that
-- character (its codename stays), { random = true } to start from a random look. onDone(true)
-- once the character is made (and the player let in) or saved, onDone(false) on BACK.
function Customizer.Open(slot, onDone, options)
	options = options or {}
	local recustomize = options.name ~= nil
	local parts = ReplicatedStorage:FindFirstChild("CharacterParts")
	local look = options.lookText and SlotConfig.ParseLook(options.lookText) or SlotConfig.DefaultLook()
	local busy = false
	local accent = Hub.InkAccent()
	local connections = {}
	local random = Random.new()

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
	Customizer.Backdrop(gui, 0.04)

	-- everything else sits in one frame that a small screen shrinks (as the slot screen does):
	-- the panel on the left, the stage on the right, BACK, RANDOMIZE and CREATE under them
	local root = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local fit = make("UIScale", { Parent = root })

	-- the panel: smoked glass, as the hub's cards, with the accent along its top
	local panel = make("Frame", { Parent = root, BackgroundColor3 = Theme.Panel, BackgroundTransparency = Theme.PanelTransparency, BorderSizePixel = 0 })
	make("UIStroke", { Parent = panel, Color = Theme.Edge, Transparency = Theme.EdgeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	make("Frame", { Parent = panel, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = accent, BackgroundTransparency = 0.45, BorderSizePixel = 0 })
	local inner = make("Frame", { Parent = panel, Position = UDim2.fromOffset(PANEL_PAD, 20), Size = UDim2.new(1, -2 * PANEL_PAD, 1, -32), BackgroundTransparency = 1 })

	label(inner, {
		Text = string.format('[ <font color="#%s">SLOT %02d</font> ]', accent:ToHex(), slot),
		RichText = true,
		Font = Theme.MonoFont,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 14),
	})
	label(inner, {
		Text = recustomize and "RECUSTOMIZE" or "NEW CHARACTER",
		Font = Theme.TitleFont,
		TextSize = 36,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 40),
	})
	-- the rule under the title, the accent along its start (as on the slot screen)
	make("Frame", { Parent = inner, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Muted, BackgroundTransparency = 0.6, BorderSizePixel = 0 })
	make("Frame", { Parent = inner, Position = UDim2.fromOffset(0, 62), Size = UDim2.fromOffset(90, 2), BackgroundColor3 = accent, BorderSizePixel = 0 })

	-- (the codename is typed on the stage: click the name under the figure)

	-- the stage, on the right: the figure on its ring inside corner brackets, a wash of the
	-- accent behind it, the slot's big faint number and the codename under it as it is typed.
	-- It turns on its own and can be dragged.
	local stage = make("Frame", { Parent = root, BackgroundTransparency = 1 })
	local wash = make("Frame", { Parent = stage, Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 0 })
	make("UIGradient", {
		Parent = wash,
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.75, 0.9),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	local bigNumber = label(stage, {
		Text = string.format("%02d", slot),
		Font = Theme.TitleFont,
		TextSize = 100,
		TextColor3 = accent,
		TextTransparency = 0.93,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, -16),
		Size = UDim2.fromOffset(120, 100),
		ZIndex = 0,
	})
	make("UIScale", { Parent = bigNumber, Scale = 3 }) -- text stops growing at 100 pixels; this takes it past
	local model, camera = Customizer.BuildPreview(stage, BODY_DISTANCE, true)
	local hit = make("TextButton", {
		Parent = stage,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
	})
	for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		for _, size in ipairs({ Vector2.new(22, 2), Vector2.new(2, 22) }) do
			make("Frame", {
				Parent = stage,
				AnchorPoint = Vector2.new(corner[1], corner[2]),
				Position = UDim2.fromScale(corner[1], corner[2]),
				Size = UDim2.fromOffset(size.X, size.Y),
				BackgroundColor3 = accent,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				ZIndex = 3,
			})
		end
	end
	local plate = make("Frame", {
		Parent = stage,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 26, 1, -22),
		Size = UDim2.new(0.55, -26, 0, 72),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	local plateBar = make("Frame", { Parent = plate, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 3 })
	local plateCaption = label(plate, { Text = string.format("SLOT %02d", slot), Font = Theme.MonoFont, TextSize = 11, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 0, 14), ZIndex = 3 })
	-- the codename: click the name to type it (its length, or what is wrong with it, shows beside
	-- the slot). A recustomized character keeps its codename: shown, not typed.
	local hint = label(plate, {
		Text = recustomize and "LOCKED" or "CLICK THE NAME TO TYPE IT",
		Font = Theme.MonoFont,
		TextSize = 11,
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(100, 0),
		Size = UDim2.new(1, -100, 0, 14),
		ZIndex = 3,
	})
	local nameBox
	local plateName
	if recustomize then
		plateName = label(plate, {
			Text = string.upper(options.name),
			Font = Theme.TitleFont,
			TextSize = 52,
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.new(1, 0, 0, 58),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
		})
	else
		nameBox = make("TextBox", {
			Parent = plate,
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.new(1, 0, 0, 58),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Theme.TitleFont,
			TextSize = 52,
			TextColor3 = Theme.NavText,
			PlaceholderText = "UNNAMED",
			PlaceholderColor3 = Theme.Muted,
			Text = "",
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		})
		plateName = nameBox
	end
	label(stage, {
		Text = "DRAG TO TURN",
		Font = Theme.MonoFont,
		TextSize = 11,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -26, 1, -24),
		Size = UDim2.fromOffset(200, 14),
		ZIndex = 3,
	})
	-- the plate fades out close up (the figure fills the stage then)
	local zoom, zoomGoal = 0, 0 -- 0 the whole figure, 1 close up on the head
	local function fadePlate()
		plateBar.BackgroundTransparency = zoom
		plateCaption.TextTransparency = zoom
		hint.TextTransparency = zoom
		plateName.TextTransparency = zoom
		if nameBox then
			nameBox.PlaceholderColor3 = Theme.Muted:Lerp(Color3.new(0, 0, 0), zoom)
		end
	end
	fadePlate()

	local angle = 0
	local turning = false
	local lastX = 0
	local turnAgainAt = 0
	local headY -- the head's height on the ring, found at the first paint
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

	-- the panel and the stage start below Roblox's band and stop above the buttons
	local function place()
		local scale = UIScale.Get()
		local screen = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize / scale or Vector2.new(MIN_WIDTH, MIN_HEIGHT)
		local shrink = math.min(1, screen.X / MIN_WIDTH, screen.Y / MIN_HEIGHT)
		fit.Scale = shrink
		root.Size = UDim2.fromScale(1 / shrink, 1 / shrink)
		local inset = GuiService:GetGuiInset().Y
		local top = (inset > 0 and inset or ROBLOX_BAR) / (scale * shrink) + TOP_GAP
		panel.Position = UDim2.fromOffset(MARGIN, top)
		panel.Size = UDim2.new(0, PANEL_WIDTH, 1, -(top + FOOTER))
		stage.Position = UDim2.fromOffset(MARGIN + PANEL_WIDTH + GAP, top)
		stage.Size = UDim2.new(1, -(2 * MARGIN + PANEL_WIDTH + GAP), 1, -(top + FOOTER))
	end
	place()
	table.insert(connections, UIScale.OnChange(place))
	if workspace.CurrentCamera then
		table.insert(connections, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place))
	end

	-- the camera eases between the whole figure and the head
	local function placeCamera()
		local height = LOOK_HEIGHT + ((headY or 1.5) - HEAD_DROP - LOOK_HEIGHT) * zoom
		local distance = BODY_DISTANCE + (HEAD_DISTANCE - BODY_DISTANCE) * zoom
		local yaw = math.rad(CAMERA_YAW)
		camera.CFrame = CFrame.lookAt(Vector3.new(distance * math.sin(yaw), height + 0.3, -distance * math.cos(yaw)), Vector3.new(0, height, 0))
	end

	-- the tiles, kept so they can be repainted when a colour (or the face a hair is shown with) changes
	local tiles = {} -- { model, kind, index }
	local refreshers = {} -- functions that redraw which tile (or option) is selected
	local previewDirty = false
	local tilesDirty = false
	local lastTilesAt = 0
	local lift -- how far up the preview goes to stand on the ring, worked out at the first paint
	local function markDirty()
		previewDirty = true
		tilesDirty = true
	end
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if previewDirty then
			previewDirty = false
			if model then
				Customizer.Dress(model, look, parts)
				lift = lift or standOnRing(model)
			end
		end
		if model then
			if not turning and os.clock() >= turnAgainAt then
				if zoomGoal > 0 then
					-- close up: the figure turns (the short way) to face the camera
					local delta = (FACE_ANGLE - angle + math.pi) % (2 * math.pi) - math.pi
					angle += delta * (1 - math.exp(-dt * 5))
				else
					angle += dt * TURN_SPEED
				end
			end
			model:PivotTo(CFrame.new(0, lift or 0, 0) * CFrame.Angles(0, angle, 0))
			if lift and not headY then
				local head = model:FindFirstChild("Head")
				headY = head and head.Position.Y or 1.5
			end
			zoom += (zoomGoal - zoom) * (1 - math.exp(-dt * 7))
			placeCamera()
			fadePlate()
		end
		if tilesDirty and os.clock() - lastTilesAt >= TILE_REFRESH then
			tilesDirty = false
			lastTilesAt = os.clock()
			for _, tile in ipairs(tiles) do
				if tile.model then
					Customizer.Dress(tile.model, tileLook(look, tile.kind, tile.index), parts)
					-- (a head tile's lone head sits at the middle; a body tile's rig stays where it is)
					local head = KINDS[tile.kind].head and tile.model:FindFirstChild("Head")
					if head then
						head.CFrame = CFrame.new()
					end
				end
			end
		end
	end))

	-- the catalogue: the tab bar, and under it one page at a time in a frame that scrolls
	local picker = buildPicker(connections)
	local tabBar = make("Frame", { Parent = inner, Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	make("Frame", {
		Parent = tabBar,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
	})
	local scroller = make("ScrollingFrame", {
		Parent = inner,
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 1, -HEADER),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Muted,
		ScrollBarImageTransparency = 0.4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	local pages = make("Frame", { Parent = scroller, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	local tabs = {} -- name -> { button, line, page }
	local currentTab

	-- a tab: its name, lit with a faint fill and the accent under it while it's the one showing
	local TAB_COUNT = 5
	local function newPage(name, tabIndex)
		local page = make("Frame", { Parent = pages, Visible = false, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIListLayout", { Parent = page, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })
		local tabButton = make("TextButton", {
			Parent = tabBar,
			Position = UDim2.fromScale((tabIndex - 1) / TAB_COUNT, 0),
			Size = UDim2.fromScale(1 / TAB_COUNT, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Theme.TitleFont,
			TextSize = 17,
			Text = name,
			TextColor3 = Theme.Muted,
			AutoButtonColor = false,
		})
		local line = make("Frame", {
			Parent = tabButton,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
		tabButton.MouseEnter:Connect(function()
			if currentTab ~= name then
				tween(tabButton, 0.15, { TextColor3 = Theme.NavText })
			end
		end)
		tabButton.MouseLeave:Connect(function()
			if currentTab ~= name then
				tween(tabButton, 0.15, { TextColor3 = Theme.Muted })
			end
		end)
		tabs[name] = { button = tabButton, line = line, page = page }
		return page
	end

	-- the colour wheel sits in whichever page is showing; each page says which colour it edits,
	-- the palette it offers as presets (and may say the wheel can't be used right now)
	local pickerSlots = {} -- tab name -> a Frame to hold the wheel
	local pickerField = {} -- tab name -> the look field the wheel edits there
	local pickerPresets = {} -- tab name -> its palette
	local pickerBlocked = {} -- tab name -> function() -> a reason the wheel is off, or nil
	local notes = {} -- tab name -> the note shown in place of a wheel that is off
	local function bindPicker(tabName)
		local field = pickerField[tabName]
		if not field then
			return
		end
		local reason = pickerBlocked[tabName] and pickerBlocked[tabName]()
		notes[tabName].Visible = reason ~= nil
		if reason then
			notes[tabName].Text = reason
			picker.Frame.Parent = nil
			return
		end
		picker.Frame.Parent = pickerSlots[tabName]
		picker.Bind(look[field], function(rgb)
			look[field] = rgb
			markDirty()
		end, pickerPresets[tabName], tabName == "BODY")
	end
	local function showTab(name)
		currentTab = name
		for tabName, tab in pairs(tabs) do
			local active = tabName == name
			tab.page.Visible = active
			tab.button.TextColor3 = active and Theme.NavText or Theme.Muted
			tween(tab.button, 0.2, { BackgroundTransparency = active and 0.93 or 1 })
			tween(tab.line, 0.2, { BackgroundTransparency = active and 0 or 1 })
		end
		scroller.CanvasPosition = Vector2.zero
		zoomGoal = CLOSE_UP[name] and 1 or 0
		bindPicker(name)
	end

	-- a page's slot for the wheel, with a note that stands in for it when it is off
	local function addPickerSlot(page, tabName, field, order, palette, blocked)
		local slotFrame = make("Frame", { Parent = page, LayoutOrder = order, Size = UDim2.new(1, 0, 0, WHEEL_SIZE + 8), BackgroundTransparency = 1 })
		notes[tabName] = label(slotFrame, {
			Visible = false,
			Font = Theme.MonoFont,
			TextSize = 12,
			TextColor3 = Theme.Muted,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 40),
			Text = "",
		})
		pickerSlots[tabName] = slotFrame
		pickerField[tabName] = field
		pickerPresets[tabName] = palette
		pickerBlocked[tabName] = blocked
	end

	-- a grid of square tiles for one kind of style; pressing one replaces the current choice.
	-- Head kinds show the style on a head; clothes show their picture. The chosen tile wears
	-- the accent (its edge and its name). Nothing is made (and false is returned) when no part
	-- exists for any style but the first.
	local function addTiles(page, number, title, kind, order)
		local spec = KINDS[kind]
		local available = {}
		for index = 1, #spec.styles do
			if CharacterLook.Has(parts, spec.prefix, index) then
				table.insert(available, index)
			end
		end
		if #available < 2 then
			return false
		end
		heading(page, number, title, order)
		local grid = make("Frame", { Parent = page, LayoutOrder = order + 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIGridLayout", { Parent = grid, CellSize = UDim2.fromOffset(TILE_SIZE, TILE_SIZE), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		local chosen = {} -- index -> { tile, edge, tag }
		local hovered = nil
		local function refresh(animate)
			for index, entry in pairs(chosen) do
				local selected = look[spec.field] == index
				local over = hovered == index
				entry.edge.Color = selected and accent or Theme.Edge
				entry.edge.Transparency = (selected and 0) or (over and 0.35) or 0.8
				entry.edge.Thickness = selected and 2 or 1
				entry.tag.BackgroundColor3 = selected and accent or Color3.new(0, 0, 0)
				entry.tag.BackgroundTransparency = selected and 0 or 0.4
				entry.tag.TextColor3 = (selected and onColor(accent)) or (over and Theme.NavText) or Theme.Muted
				if selected and animate then
					local pop = entry.tile:FindFirstChild("Pop")
					pop.Scale = 1.12
					tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				end
			end
		end
		table.insert(refreshers, refresh)
		for _, index in ipairs(available) do
			local tile = make("Frame", { Parent = grid, LayoutOrder = index, BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.1, BorderSizePixel = 0 })
			make("UIGradient", { Parent = tile, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 140)) })
			local edge = make("UIStroke", { Parent = tile, Color = Theme.Edge, Transparency = 0.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
			make("UIScale", { Name = "Pop", Parent = tile })
			if spec.head then
				local built = buildHeadTile(tile, kind)
				table.insert(tiles, { model = built.model, kind = kind, index = index })
			else
				-- a shirt or pants: worn on the body
				local built = buildBodyTile(tile, kind)
				table.insert(tiles, { model = built.model, kind = kind, index = index })
			end
			local tag = label(tile, {
				Text = string.upper(spec.styles[index]),
				Font = Theme.MonoFont,
				TextSize = 10,
				BackgroundTransparency = 0.4,
				BackgroundColor3 = Color3.new(0, 0, 0),
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 3,
			})
			local pick = make("TextButton", { Parent = tile, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5 })
			pick.MouseEnter:Connect(function()
				hovered = index
				refresh(false)
			end)
			pick.MouseLeave:Connect(function()
				if hovered == index then
					hovered = nil
					refresh(false)
				end
			end)
			pick.Activated:Connect(function()
				UiSfx.Play("menuSelect")
				look[spec.field] = index
				refresh(true)
				markDirty()
				if currentTab then
					bindPicker(currentTab)
				end
			end)
			chosen[index] = { tile = tile, edge = edge, tag = tag }
		end
		refresh(false)
		return true
	end

	-- BODY: the skin colour
	local body = newPage("BODY", 1)
	heading(body, 1, "SKIN COLOUR", 1)
	addPickerSlot(body, "BODY", "skin", 3, SlotConfig.SkinTones)

	-- HAIR: the style, then its colour
	local hair = newPage("HAIR", 2)
	addTiles(hair, 1, "STYLE", "hair", 1)
	heading(hair, 2, "HAIR COLOUR", 4)
	addPickerSlot(hair, "HAIR", "hairColor", 6, SlotConfig.HairColors)

	-- FACE: the style
	local face = newPage("FACE", 3)
	addTiles(face, 1, "STYLE", "face", 1)

	-- OUTFIT: the tiles for shirts and pants, each shown worn (no colours: a picture keeps its
	-- own, and what it leaves bare is the skin)
	local outfit = newPage("OUTFIT", 4)
	local number = 0
	for _, extra in ipairs({ { "shirt", "SHIRT", 1 }, { "pants", "PANTS", 4 } }) do
		if addTiles(outfit, number + 1, extra[2], extra[1], extra[3]) then
			number += 1
		end
	end

	-- (no EXTRAS tab for now: addTiles(newPage("EXTRAS", 5), 1, "ACCESSORY", "accessory", 1) brings it back)

	for name, tab in pairs(tabs) do
		tab.button.Activated:Connect(function()
			UiSfx.Play("menuSelect")
			showTab(name)
		end)
	end
	showTab("BODY")

	-- RANDOMIZE: a whole look at once. Colours are random but never muddy; styles come from
	-- what exists.
	local function randomColor(saturationLow, saturationHigh, valueLow, valueHigh)
		return rgbOf(Color3.fromHSV(random:NextNumber(), random:NextNumber(saturationLow, saturationHigh), random:NextNumber(valueLow, valueHigh)))
	end
	local function pickStyle(kind)
		local spec = KINDS[kind]
		local choices = {}
		for index = 1, #spec.styles do
			if CharacterLook.Has(parts, spec.prefix, index) then
				table.insert(choices, index)
			end
		end
		return choices[random:NextInteger(1, #choices)]
	end
	local function randomLook()
		local rolled = SlotConfig.DefaultLook()
		local tone = SlotConfig.SkinTones[random:NextInteger(1, #SlotConfig.SkinTones)]
		rolled.skin = { tone[1], tone[2], tone[3] }
		rolled.hair = pickStyle("hair")
		local natural = SlotConfig.HairColors[random:NextInteger(1, #SlotConfig.HairColors)]
		rolled.hairColor = random:NextInteger(1, 2) == 1 and { natural[1], natural[2], natural[3] } or randomColor(0.3, 0.95, 0.3, 0.95)
		rolled.face = pickStyle("face")
		rolled.shirt = pickStyle("shirt")
		rolled.pants = pickStyle("pants")
		return rolled
	end
	local function takeLook(newLook)
		for key, value in pairs(newLook) do
			look[key] = value
		end
		for _, refresh in ipairs(refreshers) do
			refresh(false)
		end
		bindPicker(currentTab)
		markDirty()
	end

	-- BACK: plain text at the bottom left, as on the slot screen; it lights up and nudges on hover
	local back = make("TextButton", {
		Parent = root,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, MARGIN, 1, -40),
		Size = UDim2.fromOffset(120, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.TitleFont,
		TextSize = 22,
		Text = "< BACK",
		TextColor3 = Theme.NavText,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
	})
	back.MouseEnter:Connect(function()
		tween(back, 0.15, { TextColor3 = accent, Position = UDim2.new(0, MARGIN - 6, 1, -40) })
	end)
	back.MouseLeave:Connect(function()
		tween(back, 0.15, { TextColor3 = Theme.NavText, Position = UDim2.new(0, MARGIN, 1, -40) })
	end)
	back.Activated:Connect(function()
		if busy then
			return
		end
		UiSfx.Play("menuSelect")
		gui:Destroy()
		onDone(false)
	end)

	-- bottom right: the answer from the server (or what is wrong with the codename), RANDOMIZE
	-- and CREATE
	local status = label(root, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(MARGIN + 376), 1, -58),
		Size = UDim2.fromOffset(420, 18),
		Text = "",
		TextSize = 14,
		TextColor3 = ERROR_COLOR,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	button(root, { Text = "RANDOMIZE", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -(MARGIN + 210), 1, -34), Size = UDim2.fromOffset(150, 48) }, function()
		takeLook(randomLook())
		if nameBox then -- a new character gets a random codename too (one different from the last)
			local names = SlotConfig.RandomNames
			local pick = names[random:NextInteger(1, #names)]
			if pick == nameBox.Text then
				pick = names[(table.find(names, pick) % #names) + 1]
			end
			nameBox.Text = pick
		end
	end)
	local create
	create = button(root, { Text = recustomize and "SAVE" or "CREATE", Filled = true, TextSize = 20, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -MARGIN, 1, -34), Size = UDim2.fromOffset(200, 48) }, function()
		if busy then
			return
		end
		local result
		busy = true
		status.Text = ""
		create.Text = "..."
		if recustomize then
			result = Customizer.Call("Recustomize", slot, SlotConfig.FormatLook(look))
		else
			local name, reason = SlotConfig.CleanName(nameBox.Text)
			if not name then
				busy = false
				create.Text = "CREATE"
				status.Text = reason
				return
			end
			result = Customizer.Call("Create", slot, name, SlotConfig.FormatLook(look))
		end
		busy = false
		create.Text = recustomize and "SAVE" or "CREATE"
		if result.ok then
			gui:Destroy()
			onDone(true)
		else
			status.Text = Customizer.Reason(result.reason)
		end
	end)

	if nameBox then
		nameBox:GetPropertyChangedSignal("Text"):Connect(function()
			local english = nameBox.Text:gsub("[^%w _]", "") -- English letters, numbers, space, _ only
			if english ~= nameBox.Text then
				nameBox.Text = english
				return
			end
			if #nameBox.Text > SlotConfig.NameMax then
				nameBox.Text = nameBox.Text:sub(1, SlotConfig.NameMax)
				return
			end
			status.Text = ""
			local name, reason = SlotConfig.CleanName(nameBox.Text)
			if nameBox.Text == "" then
				hint.Text = "CLICK THE NAME TO TYPE IT"
			else
				hint.Text = name and string.format("%d/%d", #nameBox.Text, SlotConfig.NameMax) or string.upper(reason)
			end
		end)
	end

	-- the panel slides in from the left and the name plate rises
	local panelAt = panel.Position
	panel.Position = panelAt - UDim2.fromOffset(24, 0)
	tween(panel, 0.45, { Position = panelAt })
	plate.Position = UDim2.new(0, 26, 1, -6)
	tween(plate, 0.5, { Position = UDim2.new(0, 26, 1, -22) })

	if options.random then
		takeLook(randomLook())
	else
		markDirty()
	end
end

return Customizer
