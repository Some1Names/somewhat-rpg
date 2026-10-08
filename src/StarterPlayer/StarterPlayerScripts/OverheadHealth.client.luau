-- Health over everyone else (other players, enemies, dummies): their name and
-- four square boxes of HP, a quarter each, emptying from right to left like
-- your own HP bar, with the same pale "just lost" trail.
-- The boxes show while they're hurt and fade out once they're back to full.
-- This replaces Roblox's own name and health bar over those characters.
-- Enemies (anything that isn't a player) also show their level (the model's
-- Level attribute), with the name in red when they're StatConfig.
-- DangerLevelGap or more levels above you, and get a red outline while
-- something stands between them and your camera. A target your Z left
-- exposed (open to your axe finisher) shows red edges on its boxes.
-- Status effects on them (Burnt, Bleeding...) show as icons above the name.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local StatusIcons = require(ReplicatedStorage:WaitForChild("StatusIcons"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BOX_COUNT = 4
local BOX_SIZE = 12
local BOX_GAP = 1 -- the outlines sit outside each box, so 1px lets neighbours share one line
local NAME_HEIGHT = 14
local ROW_GAP = 3
local ICON_ROW = StatusIcons.Size + 2 + ROW_GAP -- the status icons above the name
local WIDTH = 160
local HEIGHT_ABOVE_HEAD = 2 -- studs above the middle of the head
local MAX_DISTANCE = 100 -- studs, like Roblox's own name display
local HP_COLOR = Color3.fromRGB(216, 90, 48)
local HP_TRAIL = Color3.fromRGB(245, 196, 179)
local TRAIL_HOLD = 0.4 -- seconds the pale segment waits before catching up
local TRAIL_SPEED = 1.2 -- fractions of the whole bar per second
local HIDE_AFTER = 2.5 -- seconds at full health before the boxes fade out
local FADE_SPEED = 5 -- transparency per second
local ALWAYS_SHOW_BOXES = false -- true keeps the boxes up even at full health
local NAME_COLOR = Color3.new(1, 1, 1)
local DANGER_COLOR = Color3.fromRGB(255, 80, 80) -- an enemy far above your level
local OUTLINE_COLOR = Color3.fromRGB(255, 70, 80)
local OUTLINE_CHECK_INTERVAL = 0.1 -- seconds between line-of-sight checks
local OUTLINE_DISTANCE = 150 -- studs from the camera
local MAX_OUTLINES = 25 -- Roblox draws at most 31 Highlights at once, and hit flashes use some
local SEE_THROUGH = 0.9 -- parts at least this transparent don't hide anyone
local EXPOSED_COLOR = Color3.fromRGB(255, 70, 80)

local tracked = {} -- humanoid -> its billboard and meter state

local function frame(parent, color, size, position)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Size = size
	f.Position = position
	f.Parent = parent
	return f
end

local function outline(parent)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.5
	stroke.LineJoinMode = Enum.LineJoinMode.Miter -- square corners
	stroke.Parent = parent
	return stroke
end

-- how full box i is (0..1) for an overall fraction
local function boxShare(fraction, i)
	return math.clamp(fraction * BOX_COUNT - (i - 1), 0, 1)
end

local function nameFor(model, humanoid)
	local owner = Players:GetPlayerFromCharacter(model)
	if owner then
		return owner.DisplayName
	end
	return humanoid.DisplayName ~= "" and humanoid.DisplayName or model.Name
end

local function isMine(model)
	return model == player.Character or Players:GetPlayerFromCharacter(model) == player
end

local function untrack(humanoid)
	local entry = tracked[humanoid]
	if entry then
		tracked[humanoid] = nil
		entry.billboard:Destroy()
		if entry.outline then
			entry.outline:Destroy()
		end
	end
end

-- "Dummy  ·  Lv 1" for an enemy with a level, red when it's far above yours
local function showName(entry)
	local level = entry.model:GetAttribute("Level")
	local text = entry.name
	local color = NAME_COLOR
	if entry.enemy and typeof(level) == "number" then
		text = string.format("%s  ·  Lv %d", entry.name, level)
		if level - (player:GetAttribute("Level") or 0) >= StatConfig.DangerLevelGap then
			color = DANGER_COLOR
		end
	end
	if entry.nameLabel.Text ~= text then
		entry.nameLabel.Text = text
	end
	entry.nameLabel.TextColor3 = color
end

-- true unless something solid is in the way (characters and effects don't count)
local function lineOfSight(from, to, exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = table.clone(exclude)
	for _ = 1, 4 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then
			return true
		end
		if hit.Instance.Transparency < SEE_THROUGH then
			return false
		end
		table.insert(ignore, hit.Instance)
	end
	return false
end

-- outlines the nearest enemies whose head and body are both out of sight
local function updateOutlines()
	local eye = workspace.CurrentCamera.CFrame.Position
	local exclude = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local effects = workspace:FindFirstChild("SkillEffects")
	if effects then
		table.insert(exclude, effects)
	end
	for _, entry in pairs(tracked) do
		table.insert(exclude, entry.model)
	end

	local hidden = {}
	for humanoid, entry in pairs(tracked) do
		local root = humanoid.RootPart
		if entry.outline and root and entry.head.Parent and humanoid.Health > 0 then
			local distance = (root.Position - eye).Magnitude
			if distance <= OUTLINE_DISTANCE
				and not lineOfSight(eye, entry.head.Position, exclude)
				and not lineOfSight(eye, root.Position, exclude)
			then
				table.insert(hidden, { entry = entry, distance = distance })
			end
		end
	end
	table.sort(hidden, function(a, b)
		return a.distance < b.distance
	end)
	local outlined = {}
	for i = 1, math.min(#hidden, MAX_OUTLINES) do
		outlined[hidden[i].entry] = true
	end
	for _, entry in pairs(tracked) do
		if entry.outline then
			entry.outline.Enabled = outlined[entry] == true
		end
	end
end

local function track(humanoid)
	local model = humanoid.Parent
	if tracked[humanoid] or not model or not model:IsA("Model") or model:GetAttribute("Invulnerable") then
		return
	end
	local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 5)
	-- your own HP is on your HUD; checked after the wait, once Character is set
	if not head or isMine(model) or tracked[humanoid] or not humanoid:IsDescendantOf(workspace) then
		return
	end
	-- a character that already hides Roblox's name keeps its name hidden here too
	local nameShown = humanoid.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OverheadHealth"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = MAX_DISTANCE
	billboard.ResetOnSpawn = false
	billboard.Size = UDim2.fromOffset(WIDTH, ICON_ROW + NAME_HEIGHT + ROW_GAP + BOX_SIZE + 2)

	local icons = StatusIcons.new(billboard, Enum.HorizontalAlignment.Center)
	billboard.StudsOffset = Vector3.new(0, HEIGHT_ABOVE_HEAD, 0)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(0, ICON_ROW)
	nameLabel.Size = UDim2.new(1, 0, 0, NAME_HEIGHT)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = NAME_COLOR
	nameLabel.TextStrokeTransparency = 0.6
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Visible = nameShown
	nameLabel.Parent = billboard

	-- the boxes fade as one; the 1px margin keeps their outlines inside the group
	local rowWidth = BOX_COUNT * BOX_SIZE + (BOX_COUNT - 1) * BOX_GAP
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0)
	group.Position = UDim2.new(0.5, 0, 0, ICON_ROW + NAME_HEIGHT + ROW_GAP)
	group.Size = UDim2.fromOffset(rowWidth + 2, BOX_SIZE + 2)
	group.Parent = billboard
	local boxes = {}
	for i = 1, BOX_COUNT do
		local box = frame(group, Color3.new(0, 0, 0), UDim2.fromOffset(BOX_SIZE, BOX_SIZE), UDim2.fromOffset(1 + (i - 1) * (BOX_SIZE + BOX_GAP), 1))
		box.BackgroundTransparency = 0.65
		local stroke = outline(box)
		local trail = frame(box, HP_TRAIL, UDim2.fromScale(1, 1), UDim2.new())
		local fill = frame(box, HP_COLOR, UDim2.fromScale(1, 1), UDim2.new())
		boxes[i] = { fill = fill, trail = trail, stroke = stroke }
	end
	billboard.Parent = playerGui

	-- enemies only: the outline that shows them through walls
	local enemy = Players:GetPlayerFromCharacter(model) == nil
	local outlineHighlight
	if enemy then
		outlineHighlight = Instance.new("Highlight")
		outlineHighlight.Name = "BehindWallOutline"
		outlineHighlight.Adornee = model
		outlineHighlight.FillTransparency = 1
		outlineHighlight.OutlineColor = OUTLINE_COLOR
		outlineHighlight.OutlineTransparency = 0
		outlineHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		outlineHighlight.Enabled = false
		outlineHighlight.Parent = model
	end

	local fraction = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
	tracked[humanoid] = {
		model = model,
		head = head,
		name = nameFor(model, humanoid),
		enemy = enemy,
		nameLabel = nameLabel,
		outline = outlineHighlight,
		billboard = billboard,
		group = group,
		boxes = boxes,
		icons = icons,
		last = fraction,
		trailFraction = fraction,
		trailHoldUntil = 0,
		lastChangeAt = -math.huge,
		shown = 1,
	}
	humanoid.AncestryChanged:Connect(function()
		if not humanoid:IsDescendantOf(workspace) then
			untrack(humanoid)
		end
	end)
end

local sinceOutlineCheck = 0
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	sinceOutlineCheck += dt
	if sinceOutlineCheck >= OUTLINE_CHECK_INTERVAL then
		sinceOutlineCheck = 0
		updateOutlines()
	end
	for humanoid, entry in pairs(tracked) do
		showName(entry)
		entry.icons:Update(entry.model)
		local fraction = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
		if fraction < entry.last then
			entry.trailHoldUntil = now + TRAIL_HOLD
		end
		if fraction ~= entry.last or fraction < 1 or ALWAYS_SHOW_BOXES then
			entry.lastChangeAt = now
		end
		entry.last = fraction

		-- the pale trail jumps up on gains and slides down after losses
		if fraction > entry.trailFraction then
			entry.trailFraction = fraction
		elseif now >= entry.trailHoldUntil then
			entry.trailFraction = math.max(fraction, entry.trailFraction - TRAIL_SPEED * dt)
		end

		-- exposed to your finisher: the boxes stay up with red edges
		local exposed = entry.enemy
			and entry.model:GetAttribute("ExposedBy") == player.UserId
			and (entry.model:GetAttribute("ExposedUntil") or 0) > workspace:GetServerTimeNow()
		if exposed then
			entry.lastChangeAt = now
		end
		local target = (now - entry.lastChangeAt < HIDE_AFTER) and 0 or 1
		entry.shown += math.clamp(target - entry.shown, -FADE_SPEED * dt, FADE_SPEED * dt)
		entry.group.GroupTransparency = entry.shown
		for i, box in ipairs(entry.boxes) do
			box.fill.Size = UDim2.fromScale(boxShare(fraction, i), 1)
			box.trail.Size = UDim2.fromScale(boxShare(entry.trailFraction, i), 1)
			box.stroke.Color = exposed and EXPOSED_COLOR or Color3.new(1, 1, 1)
			box.stroke.Transparency = exposed and 0 or 0.5
		end
	end
end)

local function consider(instance)
	if instance:IsA("Humanoid") then
		task.spawn(track, instance)
	end
end
for _, descendant in ipairs(workspace:GetDescendants()) do
	consider(descendant)
end
workspace.DescendantAdded:Connect(consider)
