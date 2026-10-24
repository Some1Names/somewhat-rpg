-- The compass: a strip in the middle of Roblox's top bar row. A tick every 15°, letters
-- at the eight points, the way you look in the middle, and markers: the Headhunter
-- (red), party mates (blue) and your bounty's nearest target (gold). Far-off positions
-- come from MapServer (MapPosition, QuestTarget), since far-off parts aren't streamed
-- in. The marker nearest the middle shows its name. Plain white with a dark stroke,
-- square; a placeholder look.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local HudRules = require(ReplicatedStorage:WaitForChild("HudRules"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))

local player = Players.LocalPlayer

local SPAN = HudConfig.CompassSpan
local WIDTH = HudConfig.CompassWidth
local HEIGHT = HudConfig.CompassHeight
local TICK_STEP = 15
local FADE_SHARE = 0.3 -- the outer share of each half that fades out
local NAME_WITHIN = 8 -- degrees from the middle where a marker shows its name
local BAR_MIDDLE = 12 + 44 / 2 -- px from the top to the middle of Roblox's buttons (TopBar's BUTTON_TOP + BUTTON_HEIGHT / 2)
local TEXT = Color3.new(1, 1, 1)
local STROKE = Color3.new(0, 0, 0)
local MARKERS = {
	Headhunter = { glyph = "◆", color = Color3.fromRGB(226, 75, 74) }, -- the head tag's red
	Mate = { glyph = "▼", color = Color3.fromRGB(110, 200, 255) },
	Quest = { glyph = "!", color = Color3.fromRGB(255, 205, 60) },
}

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
	props.Font = Enum.Font.Highway
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextStrokeColor3 = STROKE
	props.TextStrokeTransparency = 0.3
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "Compass",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- up in Roblox's top bar
	Parent = player:WaitForChild("PlayerGui"),
})

local strip = make("Frame", {
	Name = "Strip",
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
})

-- the way you look: a taller tick in the middle
make("Frame", {
	Parent = strip,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.fromOffset(2, 14),
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
	ZIndex = 2,
})

-- a tick every 15°, longer with a letter at the eight points
local ticks = {}
for angle = 0, 360 - TICK_STEP, TICK_STEP do
	local point = HudRules.PointName(angle)
	local line = make("Frame", {
		Parent = strip,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(1, point and 8 or 5),
		BackgroundColor3 = TEXT,
		BorderSizePixel = 0,
	})
	local stroke = make("UIStroke", { Parent = line, Color = STROKE, Transparency = 0.5 })
	local label = point
		and text(strip, {
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.fromOffset(28, 14),
			Text = point,
			TextSize = #point == 1 and 15 or 12,
		})
	table.insert(ticks, { angle = angle, line = line, stroke = stroke, label = label })
end

-- markers, reused from a pool as the list changes
local pool = {}
local function markerAt(i)
	if not pool[i] then
		local glyph = text(strip, { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(14, 13), TextSize = 13 })
		local name = text(strip, {
			AnchorPoint = Vector2.new(0, 0),
			Size = UDim2.fromOffset(120, 13),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		pool[i] = { glyph = glyph, name = name }
	end
	return pool[i]
end

-- another player's position: their character if it's streamed in, else MapServer's MapPosition
local function playerPosition(other)
	local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
	local position = root and root.Position or other:GetAttribute("MapPosition")
	return typeof(position) == "Vector3" and position or nil
end

-- what to mark: { kind, name, position }
local function gather()
	local list = {}
	local hunterId = ReplicatedStorage:GetAttribute("Headhunter") -- set by Headhunter (server)
	local hunter = hunterId and Players:GetPlayerByUserId(hunterId)
	local hunterAt = hunter and hunter ~= player and playerPosition(hunter)
	if hunterAt then
		table.insert(list, { kind = "Headhunter", name = hunter.DisplayName, position = hunterAt })
	end
	local party = player:GetAttribute("PartyId")
	if party then
		for _, other in ipairs(Players:GetPlayers()) do
			local position = other ~= player and other ~= hunter and other:GetAttribute("PartyId") == party and playerPosition(other)
			if position then
				table.insert(list, { kind = "Mate", name = other.DisplayName, position = position })
			end
		end
	end
	local _, quest = QuestConfig.parseQuestId(player:GetAttribute("QuestId"))
	local target = player:GetAttribute("QuestTarget")
	if quest and typeof(target) == "Vector3" then
		table.insert(list, { kind = "Quest", name = quest.title, position = target })
	end
	return list
end

-- in line with Roblox's buttons; the gui is scaled (UIScale), the inset is real pixels
local function place()
	local inset = GuiService.TopbarInset
	strip.Position = UDim2.new(0.5, 0, 0, (inset.Min.Y + BAR_MIDDLE) / UIScale.Get())
end
place()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
UIScale.OnChange(place)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local look = camera.CFrame.LookVector
	local heading = HudRules.Heading(look.X, look.Z)
	for _, notch in ipairs(ticks) do
		local offset = HudRules.Offset(heading, notch.angle)
		local x = HudRules.StripX(offset, SPAN, WIDTH)
		notch.line.Visible = x ~= nil
		if notch.label then
			notch.label.Visible = x ~= nil
		end
		if x then
			local fade = HudRules.EdgeFade(offset, SPAN, FADE_SHARE)
			notch.line.Position = UDim2.new(0, x, 1, 0)
			notch.line.BackgroundTransparency = fade
			notch.stroke.Transparency = 0.5 + 0.5 * fade
			if notch.label then
				notch.label.Position = UDim2.new(0, x, 1, -10)
				notch.label.TextTransparency = fade
				notch.label.TextStrokeTransparency = 0.3 + 0.7 * fade
			end
		end
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local list = root and gather() or {}
	local nearest, nearestOff = nil, NAME_WITHIN
	for i, entry in ipairs(list) do
		local marker = markerAt(i)
		local delta = entry.position - root.Position
		local offset = HudRules.Offset(heading, HudRules.Heading(delta.X, delta.Z))
		local x = HudRules.StripX(offset, SPAN, WIDTH)
		marker.glyph.Visible = x ~= nil
		marker.name.Visible = false
		if x then
			local style = MARKERS[entry.kind]
			local fade = HudRules.EdgeFade(offset, SPAN, FADE_SHARE)
			marker.glyph.Text = style.glyph
			marker.glyph.TextColor3 = style.color
			marker.glyph.Position = UDim2.fromOffset(x, 0)
			marker.glyph.TextTransparency = fade
			marker.glyph.TextStrokeTransparency = 0.3 + 0.7 * fade
			marker.name.Text = entry.name
			marker.name.TextColor3 = style.color
			marker.name.Position = UDim2.fromOffset(x + 9, 0)
			if math.abs(offset) <= nearestOff then
				nearest, nearestOff = marker, math.abs(offset)
			end
		end
	end
	if nearest then
		nearest.name.Visible = true
	end
	for i = #list + 1, #pool do
		pool[i].glyph.Visible = false
		pool[i].name.Visible = false
	end
end)
