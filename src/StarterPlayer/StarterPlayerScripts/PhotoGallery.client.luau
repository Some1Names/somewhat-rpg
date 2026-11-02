-- Photoshop's photo Gallery: with a set that has a `gallery` (Photoshop)
-- equipped, its key (Y) opens the saved photos of places: just the polaroids,
-- laid out over the game and dealt in one by one; the key, Esc or a click off
-- the photos closes it (no title, count or close button). Each shows the area
-- it was taken in (ZoneConfig) and how far away it is. SAVE photographs the
-- spot you're standing on into that slot (the photo flashes and develops);
-- GO steps back into it, out of combat only, after the photo develops (any
-- hit meanwhile spoils it). PhotoshopServer does all the checking and keeps
-- the photos in the player's saved PhotoGallery attribute, which this reads
-- to show what each slot holds. Closes when the set is put away.
-- GO plays the trip on screen: the photo flies to the middle, develops while
-- the server's GalleryDevelop runs, and on GalleryTravel grows to fill the
-- screen in a white flash (you step into it); on GalleryCancel, or if the
-- server never starts it, it spoils and falls away. The world effects for
-- everyone are PhotoshopEffects'.
-- Each saved spot also has a waypoint only this player sees, drawn through
-- walls, but only when it's wanted: while the gallery is open, for a few
-- seconds after the set is taken out or a photo is saved, and the one whose
-- card the mouse is over. Never when you're standing at it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudRules = require(ReplicatedStorage:WaitForChild("HudRules"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("ZoneConfig"))
local galleryRemote = ReplicatedStorage:WaitForChild("PhotoGallery") -- made by PhotoshopServer
local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")
local player = Players.LocalPlayer

local PANEL_WIDTH = 600
local PADDING = 20 -- room round the cards for their tilt, pop and shadow
local CARD_GAP = 22 -- pixels between cards
local CARD_HEIGHT = 214
local CARD_INSET = 8 -- the polaroid's white edge
local PHOTO_HEIGHT = 120
local CARD_TILT = { -3, 2, -1.5 } -- degrees, each card hangs a little crooked until hovered
local DEAL_STAGGER = 0.07 -- seconds between cards popping in as the gallery opens
local HOVER_LIFT = 10 -- pixels a hovered card rises
local TRAVEL_SCALE = 1.5 -- how big the photo grows in the middle of the screen while it develops
local TRAVEL_WAIT = 0.8 -- seconds GO waits for the server to start the photo before it counts as refused
local WAYPOINT_SIZE = 34 -- pixels, the diamond with the photo number
local WAYPOINT_WIDTH = 140 -- pixels, room for the place and distance under it
local WAYPOINT_HEIGHT = 4 -- studs above the saved spot
local WAYPOINT_UPDATE = 0.2 -- seconds between distance updates
local WAYPOINT_LINGER = 4 -- seconds the waypoints stay up after taking the set out or saving
local WAYPOINT_NEAR = 12 -- studs: closer than this, you're there, so it hides
local WAYPOINT_DIM = 0.3 -- how faded a shown waypoint is that isn't hovered (0 full, 1 gone)
local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BACKGROUND = Color3.fromRGB(16, 15, 22)
local CARD = Color3.fromRGB(236, 233, 242)
local INK = Color3.fromRGB(30, 28, 40)
local INK_MUTED = Color3.fromRGB(120, 116, 135)
local SPOILED = Color3.fromRGB(110, 106, 100)
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
	props.Font = props.Font or Enum.Font.Highway
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function tween(instance, info, goal)
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

-- the pink-to-blue wash Photoshop's UI uses
local function wash(parent, rotation)
	return make("UIGradient", {
		Parent = parent,
		Rotation = rotation or 0,
		Color = ColorSequence.new(PINK, BLUE),
	})
end

-- a camera viewfinder's four corner brackets inside `parent`
local function brackets(parent, color)
	local LENGTH, THICK, INSET = 12, 2, 6
	local holders = {}
	for _, corner in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
		local x = corner.X == 0 and INSET or -INSET
		local y = corner.Y == 0 and INSET or -INSET
		local position = UDim2.new(corner.X, x, corner.Y, y)
		holders[#holders + 1] = make("Frame", { Parent = parent, AnchorPoint = corner, Position = position, Size = UDim2.fromOffset(LENGTH, THICK), BackgroundColor3 = color, BorderSizePixel = 0 })
		holders[#holders + 1] = make("Frame", { Parent = parent, AnchorPoint = corner, Position = position, Size = UDim2.fromOffset(THICK, LENGTH), BackgroundColor3 = color, BorderSizePixel = 0 })
	end
	return holders
end

-- the set in hand, if it has a gallery its mastery unlocks
local function gallerySet()
	local _, setName = SkillSetConfig.Equipped(player.Character)
	local set = setName and SkillSetConfig.Sets[setName]
	return set and set.gallery and SkillSetConfig.FeatureUnlocked(player, setName, "gallery") and set or nil
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

local function placeName(point)
	return HudRules.ZoneAt(ZoneConfig.Zones, point.X, point.Z) or "Somewhere"
end

local function distanceTo(point)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and (point - root.Position).Magnitude
end

-- One polaroid in `parent` (which it fills): a shadow, the paper, the photo
-- with its number and viewfinder marks, and the writing under it. `lift`
-- tilts and rises, `pop` scales; `paint(point)` shows a saved spot or an
-- empty slot.
local function polaroid(parent, slot)
	local lift = make("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
	local pop = make("UIScale", { Parent = lift })
	local shadow = make("Frame", {
		Parent = lift,
		Position = UDim2.fromOffset(5, 7),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
	})
	local paper = make("Frame", { Parent = lift, Size = UDim2.fromScale(1, 1), BackgroundColor3 = CARD, BorderSizePixel = 0 })
	local photo = make("Frame", {
		Parent = paper,
		Position = UDim2.fromOffset(CARD_INSET, CARD_INSET),
		Size = UDim2.new(1, -2 * CARD_INSET, 0, PHOTO_HEIGHT),
		BackgroundColor3 = TEXT,
		BorderSizePixel = 0,
	})
	wash(photo, 35)
	-- darkens the wash so it reads as a photo, not a button; an empty slot is all dark
	local shade = make("Frame", { Parent = photo, Size = UDim2.fromScale(1, 1), BackgroundColor3 = BACKGROUND, BorderSizePixel = 0 })
	local number = label(photo, {
		Text = string.format("%02d", slot),
		TextSize = 56,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})
	local coords = label(photo, {
		TextSize = 10,
		TextTransparency = 0.3,
		Position = UDim2.new(0, 24, 1, -19),
		Size = UDim2.new(1, -48, 0, 12),
	})
	local marks = brackets(photo, TEXT)
	-- the shutter's flash over the photo
	local flash = make("Frame", { Parent = photo, Size = UDim2.fromScale(1, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 })
	local place = label(paper, {
		Font = Enum.Font.PermanentMarker,
		TextSize = 16,
		TextColor3 = INK,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(CARD_INSET + 2, CARD_INSET + PHOTO_HEIGHT + 6),
		Size = UDim2.new(1, -2 * CARD_INSET - 4, 0, 22),
	})
	local sub = label(paper, {
		TextSize = 12,
		TextColor3 = INK_MUTED,
		Position = UDim2.fromOffset(CARD_INSET + 2, CARD_INSET + PHOTO_HEIGHT + 28),
		Size = UDim2.new(1, -2 * CARD_INSET - 4, 0, 14),
	})
	local card = { lift = lift, pop = pop, shadow = shadow, paper = paper, shade = shade, number = number, flash = flash, place = place, sub = sub }
	function card.paint(point)
		shade.BackgroundTransparency = point and 0.45 or 0
		number.TextTransparency = point and 0.1 or 0.8
		coords.Text = point and string.format("%d, %d, %d", math.round(point.X), math.round(point.Y), math.round(point.Z)) or ""
		for _, mark in ipairs(marks) do
			mark.BackgroundColor3 = point and TEXT or MUTED
			mark.BackgroundTransparency = point and 0 or 0.6
		end
		place.Text = point and placeName(point) or "empty"
		place.TextColor3 = point and INK or INK_MUTED
	end
	return card
end

-- the shutter goes: the photo flashes white and develops from dark
local function snap(card, develop)
	card.flash.BackgroundTransparency = 0
	tween(card.flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	card.shade.BackgroundTransparency = 0
	card.number.TextTransparency = 0.8
	tween(card.shade, TweenInfo.new(develop), { BackgroundTransparency = 0.45 })
	tween(card.number, TweenInfo.new(develop), { TextTransparency = 0.1 })
	card.pop.Scale = 1.12
	tween(card.pop, POP, { Scale = 1 })
end

local gui = make("ScreenGui", {
	Name = "PhotoGallery",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- the trip's photo and the flash you step through, over everything else
local travelGui = make("ScreenGui", {
	Name = "PhotoGalleryTravel",
	ResetOnSpawn = false,
	DisplayOrder = 20,
	Parent = player:WaitForChild("PlayerGui"),
})
local whiteout = make("Frame", {
	Parent = travelGui,
	Position = UDim2.fromOffset(0, -100), -- up over Roblox's top bar too (the gui keeps the inset, like the gallery's)
	Size = UDim2.new(1, 0, 1, 100),
	BackgroundColor3 = TEXT,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 5,
})

-- an invisible button over the whole screen, under the photos: clicking off them closes
local backdrop = make("TextButton", {
	Parent = gui,
	Position = UDim2.fromOffset(0, -100),
	Size = UDim2.new(1, 0, 1, 100),
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "",
})

-- the panel is only for layout and scrolling: no background, no bar, the photos float
local panel = make("ScrollingFrame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 0, -- no bar floating over the world; a short screen still scrolls with the wheel
	ScrollBarImageTransparency = 1, -- (a 0-thick bar still draws a pixel)
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 2, -- over the backdrop
})
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14) })
Menus.Fit(panel)

local order = 0
local function section(height)
	order += 1
	return make("Frame", { Parent = panel, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 })
end

local cardRow = section(CARD_HEIGHT)
make("UIListLayout", {
	Parent = cardRow,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, CARD_GAP),
})

local function button(parent, text, color, x)
	return make("TextButton", {
		Parent = parent,
		Position = UDim2.new(x, x == 0 and CARD_INSET or 3, 1, -CARD_INSET),
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(0.5, -CARD_INSET - 3, 0, 28),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.Highway,
		Text = text,
		TextSize = 14,
		TextColor3 = INK,
	})
end

-- the trip on screen: the photo GO was pressed on, flying to the middle
local trip = nil -- { card, frame, started, developing } while a trip is under way

-- the photo spoils (greyed) and drops off the bottom of the screen
local function spoilTrip()
	local current = trip
	trip = nil
	if not current then
		return
	end
	local card = current.card
	tween(card.shade, TweenInfo.new(0.2), { BackgroundColor3 = SPOILED, BackgroundTransparency = 0.1 })
	local fall = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(current.frame, fall, { Position = UDim2.fromScale(0.5, 1.4) })
	tween(card.lift, fall, { Rotation = 35 })
	task.delay(0.65, function()
		current.frame:Destroy()
	end)
end

-- the photo grows past the edges of the screen in a white flash, which fades on the far side
local function enterTrip()
	local current = trip
	trip = nil
	if not current then
		return
	end
	local zoom = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(current.card.pop, zoom, { Scale = 14 })
	tween(current.card.lift, zoom, { Rotation = 0 })
	tween(whiteout, TweenInfo.new(0.25), { BackgroundTransparency = 0 })
	task.delay(0.3, function()
		current.frame:Destroy()
		tween(whiteout, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	end)
end

-- GO: a copy of the card lifts out of the gallery to the middle of the screen
local function startTrip(from, slot, point)
	if trip then
		trip.frame:Destroy()
	end
	local scale = UIScale.Get()
	local frame = make("Frame", {
		Parent = travelGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((from.AbsolutePosition.X + from.AbsoluteSize.X / 2) / scale, (from.AbsolutePosition.Y + from.AbsoluteSize.Y / 2) / scale),
		Size = UDim2.fromOffset(from.AbsoluteSize.X / scale, from.AbsoluteSize.Y / scale),
		BackgroundTransparency = 1,
	})
	local card = polaroid(frame, slot)
	card.paint(point)
	card.sub.Text = "developing..."
	card.lift.Rotation = from.Rotation
	-- how far along the photo is, under the writing
	local bar = make("Frame", {
		Parent = card.paper,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, CARD_INSET, 1, -CARD_INSET),
		Size = UDim2.new(0, 0, 0, 3),
		BackgroundColor3 = TEXT,
		BorderSizePixel = 0,
	})
	wash(bar)
	card.bar = bar
	trip = { card = card, frame = frame, started = os.clock(), developing = false }
	tween(frame, POP, { Position = UDim2.fromScale(0.5, 0.45) })
	tween(card.pop, POP, { Scale = TRAVEL_SCALE })
	tween(card.lift, POP, { Rotation = 0 })
	local mine = trip
	task.delay(TRAVEL_WAIT, function()
		-- the server never started the photo (in combat, held): it spoils
		if trip == mine and not mine.developing then
			spoilTrip()
		end
	end)
end

-- the server's word on this player's own photo
skillEffects.OnClientEvent:Connect(function(kind, character, time)
	if character ~= player.Character or not trip then
		return
	end
	if kind == "GalleryDevelop" then
		trip.developing = true
		local card = trip.card
		card.shade.BackgroundTransparency = 0
		card.number.TextTransparency = 0.8
		tween(card.shade, TweenInfo.new(time), { BackgroundTransparency = 0.45 })
		tween(card.number, TweenInfo.new(time), { TextTransparency = 0.1 })
		tween(card.bar, TweenInfo.new(time), { Size = UDim2.new(1, -2 * CARD_INSET, 0, 3) })
	elseif kind == "GalleryTravel" then
		enterTrip()
	elseif kind == "GalleryCancel" then
		spoilTrip()
	end
end)

local setOpen -- opens and closes the gallery; defined below
local hovered = nil -- the slot whose card the mouse is over
local cards = {} -- slot -> polaroid parts plus { holder, tilt, save, go, point }
local function buildCards(slotCount)
	if #cards == slotCount then
		return
	end
	for slot = #cards + 1, slotCount do
		local holder = make("Frame", {
			Parent = cardRow,
			LayoutOrder = slot,
			Size = UDim2.new(1 / slotCount, -CARD_GAP * (slotCount - 1) / slotCount, 1, 0),
			BackgroundTransparency = 1,
		})
		local card = polaroid(holder, slot)
		card.holder = holder
		card.tilt = CARD_TILT[(slot - 1) % #CARD_TILT + 1]
		card.lift.Rotation = card.tilt
		card.save = button(card.paper, "SAVE", BLUE, 0)
		card.go = button(card.paper, "GO", PINK, 0.5)
		card.save.Activated:Connect(function()
			galleryRemote:FireServer("save", slot)
		end)
		card.go.Activated:Connect(function()
			if card.point then
				galleryRemote:FireServer("travel", slot)
				startTrip(card.lift, slot, card.point)
				setOpen(false) -- through Menus too, or it stays open and holds her still
			end
		end)
		-- hovering lifts and straightens the card and lights up its waypoint
		holder.MouseEnter:Connect(function()
			hovered = slot
			tween(card.lift, FADE, { Rotation = 0, Position = UDim2.new(0.5, 0, 0.5, -HOVER_LIFT) })
			tween(card.shadow, FADE, { Position = UDim2.fromOffset(8, 14), BackgroundTransparency = 0.7 })
			tween(card.pop, FADE, { Scale = 1.05 })
		end)
		holder.MouseLeave:Connect(function()
			if hovered == slot then
				hovered = nil
			end
			tween(card.lift, FADE, { Rotation = card.tilt, Position = UDim2.fromScale(0.5, 0.5) })
			tween(card.shadow, FADE, { Position = UDim2.fromOffset(5, 7), BackgroundTransparency = 0.55 })
			tween(card.pop, FADE, { Scale = 1 })
		end)
		cards[slot] = card
	end
end

-- the cards are dealt in, one after another, from a steeper tilt
local function deal()
	for slot, card in ipairs(cards) do
		card.pop.Scale = 0
		card.lift.Rotation = card.tilt * 5
		card.lift.Position = UDim2.fromScale(0.5, 0.5)
		task.delay((slot - 1) * DEAL_STAGGER, function()
			tween(card.pop, POP, { Scale = hovered == slot and 1.05 or 1 })
			tween(card.lift, POP, { Rotation = hovered == slot and 0 or card.tilt })
		end)
	end
end

local function updateCardDistances()
	for slot, card in ipairs(cards) do
		local away = card.point and distanceTo(card.point)
		card.sub.Text = "PHOTO " .. slot .. (away and string.format("  ·  %d m", math.round(away)) or "")
	end
end

local function refresh()
	local set = gallerySet()
	if not set then
		return
	end
	buildCards(set.gallery.slots)
	local slots = readSlots(set.gallery.slots)
	for slot, card in ipairs(cards) do
		local point = slots[slot] or nil
		local retaken = gui.Enabled and point and point ~= card.point and card.shown
		card.point = point
		card.shown = true
		card.paint(point)
		if retaken then
			snap(card, 0.9)
		end
		card.save.Text = point and "RETAKE" or "SAVE"
		card.go.BackgroundTransparency = point and 0 or 0.7
		card.go.AutoButtonColor = point ~= nil
	end
	updateCardDistances()
end
player:GetAttributeChangedSignal("PhotoGallery"):Connect(refresh)

-- the waypoints: a client-side Attachment at each saved spot, with a
-- BillboardGui on it; made the first time a slot holds a photo. A CanvasGroup
-- doesn't draw in a BillboardGui, so a NumberValue (0 shown, 1 gone) fades
-- each piece from its own transparency.
local waypoints = {} -- slot -> { anchor, board, fade, scale, place, distance, saved, shown, strong }
local function waypoint(slot)
	if waypoints[slot] then
		return waypoints[slot]
	end
	local anchor = make("Attachment", { Name = "PhotoWaypoint" .. slot, Parent = workspace.Terrain })
	local board = make("BillboardGui", {
		Name = "PhotoWaypoint" .. slot,
		Adornee = anchor,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
		LightInfluence = 0,
		Size = UDim2.fromOffset(WAYPOINT_WIDTH, WAYPOINT_SIZE + 44),
		StudsOffsetWorldSpace = Vector3.new(0, WAYPOINT_HEIGHT, 0),
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local group = make("Frame", { Parent = board, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local scale = make("UIScale", { Parent = group })
	-- a square turned on its corner, with the number upright over it
	local diamond = make("Frame", {
		Parent = group,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, WAYPOINT_SIZE / 2 + 6),
		Size = UDim2.fromOffset(WAYPOINT_SIZE * 0.75, WAYPOINT_SIZE * 0.75),
		Rotation = 45,
		BackgroundColor3 = BACKGROUND,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	})
	wash(make("UIStroke", { Parent = diamond, Color = TEXT, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), -45)
	label(group, {
		Text = tostring(slot),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, WAYPOINT_SIZE),
	})
	local place = label(group, {
		TextSize = 13,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, WAYPOINT_SIZE + 10),
		Size = UDim2.new(1, 0, 0, 15),
	})
	local distance = label(group, {
		TextSize = 11,
		TextColor3 = MUTED,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, WAYPOINT_SIZE + 25),
		Size = UDim2.new(1, 0, 0, 13),
	})
	-- every piece's transparency as built, which the fade scales up to 1
	local pieces = {}
	for _, piece in ipairs(group:GetDescendants()) do
		local properties = piece:IsA("UIStroke") and { "Transparency" }
			or piece:IsA("TextLabel") and { "BackgroundTransparency", "TextTransparency", "TextStrokeTransparency" }
			or piece:IsA("GuiObject") and { "BackgroundTransparency" }
			or {}
		for _, property in ipairs(properties) do
			table.insert(pieces, { piece, property, piece[property] })
		end
	end
	local fade = make("NumberValue", { Parent = board, Value = 1 })
	local function apply()
		for _, each in ipairs(pieces) do
			each[1][each[2]] = each[3] + (1 - each[3]) * fade.Value
		end
	end
	fade.Changed:Connect(apply)
	apply()
	waypoints[slot] = { anchor = anchor, board = board, fade = fade, scale = scale, place = place, distance = distance, saved = false, shown = false, strong = false }
	return waypoints[slot]
end

local function updateDistances()
	for _, each in pairs(waypoints) do
		if each.shown then
			local away = distanceTo(each.anchor.WorldPosition)
			each.distance.Text = away and string.format("%d m", math.round(away)) or ""
		end
	end
	if gui.Enabled then
		updateCardDistances()
	end
end

-- moves the waypoints onto the saved photos (which ones show is decided each frame)
local function placeWaypoints()
	local set = gallerySet() or SkillSetConfig.Sets.Photoshop
	local slots = set and set.gallery and readSlots(set.gallery.slots) or {}
	for slot, point in ipairs(slots) do
		if point then
			local each = waypoint(slot)
			each.anchor.WorldPosition = point
			each.place.Text = placeName(point)
			each.saved = true
			each.board.Enabled = true
		end
	end
	for slot, each in pairs(waypoints) do
		if not slots[slot] then
			each.saved = false
		end
	end
end

local lingerUntil = 0
player:GetAttributeChangedSignal("PhotoGallery"):Connect(function()
	placeWaypoints()
	lingerUntil = os.clock() + WAYPOINT_LINGER -- a new photo: show where it is for a moment
end)
placeWaypoints()

local function showWaypoint(each, shown, strong)
	if each.shown == shown and each.strong == strong then
		return
	end
	each.shown, each.strong = shown, strong
	TweenService:Create(each.fade, FADE, { Value = not shown and 1 or strong and 0 or WAYPOINT_DIM }):Play()
	TweenService:Create(each.scale, FADE, { Scale = strong and 1.2 or 1 }):Play()
end

-- which waypoints are wanted right now: all of them with the gallery open or just
-- after taking the set out or saving, the hovered card's always; none out of hand
local function updateVisibility(inHand)
	local all = inHand and (gui.Enabled or os.clock() < lingerUntil)
	for slot, each in pairs(waypoints) do
		local strong = inHand and gui.Enabled and hovered == slot
		local away = each.saved and distanceTo(each.anchor.WorldPosition)
		local near = away ~= nil and away < WAYPOINT_NEAR
		showWaypoint(each, each.saved and (all or strong) and not near, strong)
	end
end

function setOpen(open)
	gui.Enabled = open
	if open then
		Menus.Open("Gallery", function()
			setOpen(false)
		end)
		refresh()
		deal()
	else
		hovered = nil
		Menus.Close("Gallery")
	end
end

-- a click anywhere off the photos closes it
backdrop.Activated:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled and not Keybinds.Capturing() then
		setOpen(false)
		return
	end
	if gameProcessed or Keybinds.Capturing() then
		return
	end
	local set = gallerySet()
	-- the player's own gallery key (Keybinds; the set's gallery.key unless rebound)
	if set and input.KeyCode == Keybinds.Key("Gallery") then
		setOpen(not gui.Enabled)
	end
end)

-- put away: the gallery closes and the waypoints hide (taken out: they show for a moment)
local wasInHand = false
local sinceDistances = 0
RunService.Heartbeat:Connect(function(dt)
	local inHand = gallerySet() ~= nil
	if gui.Enabled and not inHand then
		setOpen(false)
	end
	if inHand ~= wasInHand then
		wasInHand = inHand
		if inHand then
			lingerUntil = os.clock() + WAYPOINT_LINGER
		end
	end
	updateVisibility(inHand)
	sinceDistances += dt
	if sinceDistances >= WAYPOINT_UPDATE then
		sinceDistances = 0
		updateDistances()
	end
end)
