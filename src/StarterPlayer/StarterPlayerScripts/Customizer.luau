-- The character customizer for an empty slot: a name box, a row of choices for each part
-- of the look (skin, hair, hair colour, face, top, bottom) and a live preview of the
-- player's own character (a stripped, anchored clone in a ViewportFrame, as HubPose does)
-- wearing the look through CharacterLook. Hair and face styles with no part in
-- ReplicatedStorage.CharacterParts are hidden. CREATE asks the server (SlotAction
-- "Create") and, on success, lets the player in. Also holds the small helpers SlotMenu
-- shares. Square everything; the accent is the hub's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterLook = require(ReplicatedStorage:WaitForChild("CharacterLook"))
local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local SlotConfig = require(ReplicatedStorage:WaitForChild("SlotConfig"))
local Hub = require(script.Parent:WaitForChild("Hub"))
local UiSfx = require(script.Parent:WaitForChild("UiSfx"))

local player = Players.LocalPlayer
local Theme = HudConfig.HubTheme
local remote = ReplicatedStorage:WaitForChild("SlotAction")

local PANEL_WIDTH = 480
local OPTION_SIZE = 30
local FIELD_OF_VIEW = 30
local CAMERA_DISTANCE = 11.5
local CAMERA_YAW = 20 -- degrees round from straight in front
local LOOK_HEIGHT = 0.2 -- studs above the root part the camera looks at
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

-- a square button; `filled` buttons are the accent, the rest dark with a thin edge
local function button(parent, props, onClick)
	local filled = props.Filled
	props.Filled = nil
	props.Parent = parent
	props.Font = props.Font or Theme.TitleFont
	props.TextSize = props.TextSize or 18
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	props.BackgroundColor3 = filled and Hub.InkAccent() or Theme.Nav
	props.TextColor3 = filled and Hub.OnInk() or Theme.NavText
	local instance = make("TextButton", props)
	make("UIStroke", { Parent = instance, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	instance.Activated:Connect(function()
		if instance.Active then
			UiSfx.Play("menuSelect")
			onClick()
		end
	end)
	return instance
end
Customizer.Button = button

local function colorOf(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- a stripped, anchored copy of the player's character in a ViewportFrame; returns the
-- copy (nil with no character)
local function buildPreview(parent)
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
		Vector3.new(CAMERA_DISTANCE * math.sin(yaw), LOOK_HEIGHT + 0.3, -CAMERA_DISTANCE * math.cos(yaw)),
		Vector3.new(0, LOOK_HEIGHT, 0)
	)
	viewport.CurrentCamera = camera
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
	local world = make("WorldModel", { Parent = viewport })
	copy.Parent = world
	return copy
end

local function anchorAll(model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
end

-- Opens the customizer for an empty slot. onDone(true) once the character is made and
-- the player let in, onDone(false) on BACK.
function Customizer.Open(slot, onDone)
	local parts = ReplicatedStorage:FindFirstChild("CharacterParts")
	local look = SlotConfig.DefaultLook()
	local busy = false

	local gui = make("ScreenGui", {
		Name = "Customizer",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 52,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Nav, BackgroundTransparency = 0.25, BorderSizePixel = 0 })

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
	make("UIPadding", { Parent = panel, PaddingTop = UDim.new(0, 70), PaddingBottom = UDim.new(0, 30), PaddingRight = UDim.new(0, 12) })
	make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 16) })

	label(panel, {
		Text = "NEW CHARACTER",
		Font = Theme.TitleFont,
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 1,
	})

	-- the name
	local nameBlock = make("Frame", { Parent = panel, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1 })
	label(nameBlock, { Text = "CODENAME", Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, 14) })
	local nameBox = make("TextBox", {
		Parent = nameBlock,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Nav,
		BorderSizePixel = 0,
		Font = Theme.LabelFont,
		TextSize = 18,
		TextColor3 = Theme.NavText,
		PlaceholderText = "Codename",
		PlaceholderColor3 = Theme.Muted,
		Text = "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	make("UIStroke", { Parent = nameBox, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	make("UIPadding", { Parent = nameBox, PaddingLeft = UDim.new(0, 10) })
	local hint = label(nameBlock, {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Muted,
	})

	-- the preview, on the right
	local previewHolder = make("Frame", {
		Parent = gui,
		Position = UDim2.new(0, 60 + PANEL_WIDTH + 20, 0, 0),
		Size = UDim2.new(1, -(60 + PANEL_WIDTH + 80), 1, 0),
		BackgroundTransparency = 1,
	})
	local model = buildPreview(previewHolder)

	local function repaint()
		if model then
			CharacterLook.Apply(model, look, parts)
			anchorAll(model)
		end
	end

	-- one row of choices for a part of the look; `swatches` are colours, the rest names
	local choices = {} -- field -> { [index] = button }
	local function refreshRow(field)
		for index, option in pairs(choices[field]) do
			local selected = look[field] == index
			local stroke = option:FindFirstChildOfClass("UIStroke")
			stroke.Color = selected and Color3.new(1, 1, 1) or Theme.Edge
			stroke.Transparency = selected and 0 or 0.6
			stroke.Thickness = selected and 2 or 1
		end
	end
	local order = 3
	local function addRow(field, title, count, build)
		order += 1
		local frame = make("Frame", {
			Parent = panel,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		make("UIListLayout", { Parent = frame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) })
		label(frame, { Text = title, Font = Theme.MonoFont, TextSize = 12, TextColor3 = Theme.Muted, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1 })
		local options = make("Frame", {
			Parent = frame,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		make("UIListLayout", {
			Parent = options,
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
		choices[field] = {}
		for index = 1, count do
			local option = build(options, index)
			if option then
				option.LayoutOrder = index
				choices[field][index] = option
				option.Activated:Connect(function()
					UiSfx.Play("menuSelect")
					look[field] = index
					refreshRow(field)
					repaint()
				end)
			end
		end
		refreshRow(field)
	end

	local function swatches(palette)
		return function(parent, index)
			local swatch = make("TextButton", {
				Parent = parent,
				Size = UDim2.fromOffset(OPTION_SIZE, OPTION_SIZE),
				BackgroundColor3 = colorOf(palette[index]),
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
			})
			make("UIStroke", { Parent = swatch, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
			return swatch
		end
	end
	local function styles(names, has)
		return function(parent, index)
			if not has(parts, index) then
				return nil
			end
			local option = make("TextButton", {
				Parent = parent,
				Size = UDim2.fromOffset(0, OPTION_SIZE),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Nav,
				BorderSizePixel = 0,
				Font = Theme.LabelFont,
				TextSize = 15,
				TextColor3 = Theme.NavText,
				Text = " " .. string.upper(names[index]) .. " ",
				AutoButtonColor = false,
			})
			make("UIStroke", { Parent = option, Color = Theme.Edge, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
			return option
		end
	end

	addRow("skin", "SKIN", #SlotConfig.SkinTones, swatches(SlotConfig.SkinTones))
	addRow("hair", "HAIR", #SlotConfig.HairStyles, styles(SlotConfig.HairStyles, CharacterLook.HasHair))
	addRow("hairColor", "HAIR COLOUR", #SlotConfig.HairColors, swatches(SlotConfig.HairColors))
	addRow("face", "FACE", #SlotConfig.FaceStyles, styles(SlotConfig.FaceStyles, CharacterLook.HasFace))
	addRow("top", "TOP", #SlotConfig.OutfitColors, swatches(SlotConfig.OutfitColors))
	addRow("bottom", "BOTTOM", #SlotConfig.OutfitColors, swatches(SlotConfig.OutfitColors))

	-- the answer from the server, or what is wrong with the name
	order += 1
	local status = label(panel, {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		TextSize = 14,
		TextColor3 = ERROR_COLOR,
	})
	order += 1
	local buttons = make("Frame", { Parent = panel, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
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

	repaint()
end

return Customizer
