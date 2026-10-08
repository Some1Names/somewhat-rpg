-- Photoshop's photo Gallery: with a set that has a `gallery` (Photoshop)
-- equipped, its key (T) opens a small panel of saved photos of places, one
-- row per slot. SAVE photographs the spot you're standing on into that slot;
-- GO steps back into it, out of combat only, after the photo develops (any
-- hit meanwhile spoils it). PhotoshopServer does all the checking and keeps
-- the photos in the player's saved PhotoGallery attribute, which this reads
-- to show what each slot holds. Closes when the set is put away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local galleryRemote = ReplicatedStorage:WaitForChild("PhotoGallery") -- made by PhotoshopServer
local player = Players.LocalPlayer

local PANEL_WIDTH = 300
local PADDING = 12
local ROW_HEIGHT = 30
local BUTTON_WIDTH = 52
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local BUTTON = Color3.fromRGB(38, 38, 50)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local PINK = SkillSetConfig.PhotoshopPink
local BLUE = SkillSetConfig.PhotoshopBlue

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

-- the set in hand, if it has a gallery
local function gallerySet()
	local _, setName = SkillSetConfig.Equipped(player.Character)
	local set = setName and SkillSetConfig.Sets[setName]
	return set and set.gallery and set or nil
end

-- the saved photos, as PhotoshopServer writes them: "x,y,z" or "" per slot
local function readSlots(count)
	local text = player:GetAttribute("PhotoGallery")
	local entries = typeof(text) == "string" and string.split(text, ";") or {}
	local slots = {}
	for slot = 1, count do
		local parts = string.split(entries[slot] or "", ",")
		local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
		slots[slot] = (x and y and z) and Vector3.new(x, y, z) or false
	end
	return slots
end

local gui = make("ScreenGui", {
	Name = "PhotoGallery",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
})
make("UIStroke", { Parent = panel, Color = PINK, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

local order = 0
local function section(height)
	order += 1
	return make("Frame", { Parent = panel, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 })
end

local header = section(20)
local title = label(header, { Text = "GALLERY", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = PINK, Size = UDim2.new(1, -24, 1, 0) })
-- Modal frees the mouse while the gallery is open, even in shift lock
local closeButton = make("TextButton", {
	Parent = header,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(20, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
	Modal = true,
})

local function button(parent, text, color, x)
	local b = make("TextButton", {
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, x, 0, 0),
		Size = UDim2.new(0, BUTTON_WIDTH, 1, 0),
		BackgroundColor3 = BUTTON,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextSize = 12,
		TextColor3 = color,
	})
	make("UIStroke", { Parent = b, Color = color, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	return b
end

local rows = {} -- slot -> { place = TextLabel, go = TextButton }
local function buildRows(count)
	if #rows == count then
		return
	end
	for slot = #rows + 1, count do
		local row = section(ROW_HEIGHT)
		label(row, { Text = "PHOTO " .. slot, Font = Enum.Font.GothamBold, TextSize = 12, Size = UDim2.new(0, 64, 1, 0) })
		local place = label(row, {
			TextSize = 11,
			TextColor3 = MUTED,
			Position = UDim2.fromOffset(64, 0),
			Size = UDim2.new(1, -64 - 2 * BUTTON_WIDTH - 12, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local save = button(row, "SAVE", BLUE, -(BUTTON_WIDTH + 6))
		local go = button(row, "GO", PINK, 0)
		save.Activated:Connect(function()
			galleryRemote:FireServer("save", slot)
		end)
		go.Activated:Connect(function()
			galleryRemote:FireServer("travel", slot)
			gui.Enabled = false
		end)
		rows[slot] = { place = place, go = go }
	end
	label(section(14), {
		Text = "Save where you stand. GO works out of combat; a hit spoils the photo.",
		TextSize = 10,
		TextColor3 = MUTED,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	})
end

local function refresh()
	local set = gallerySet()
	if not set then
		return
	end
	title.Text = string.upper(set.gallery.name)
	buildRows(set.gallery.slots)
	local slots = readSlots(set.gallery.slots)
	for slot, row in ipairs(rows) do
		local point = slots[slot]
		row.place.Text = point and string.format("%d, %d, %d", math.round(point.X), math.round(point.Y), math.round(point.Z)) or "empty"
		row.go.TextTransparency = point and 0 or 0.6
	end
end
player:GetAttributeChangedSignal("PhotoGallery"):Connect(refresh)

closeButton.Activated:Connect(function()
	gui.Enabled = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local set = gallerySet()
	if set and input.KeyCode == Enum.KeyCode[set.gallery.key] then
		gui.Enabled = not gui.Enabled
		if gui.Enabled then
			refresh()
		end
	end
end)

-- put away: the gallery closes
RunService.Heartbeat:Connect(function()
	if gui.Enabled and not gallerySet() then
		gui.Enabled = false
	end
end)
