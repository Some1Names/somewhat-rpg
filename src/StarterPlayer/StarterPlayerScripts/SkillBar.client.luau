-- Skill bar for skill sets (like Mandela): while the set's tool is equipped,
-- its keys (Z/X/C/V, plus F on S-tier sets) cast its skills: hold a key to
-- see where it'll land (AimIndicator), let go to cast at the mouse. The header
-- shows the set's passive (its tier shows on its hotbar slot), and the row
-- under it the set's meter: overcharge stacks, or Luminance for a set that
-- flies, whose G takes off and lands instead (and whose Prism Form spends
-- it: the skills it empowers get a shimmering orange-cyan strip and their
-- `formAim`). In shade the Luminance meter dims above the shade cap, the
-- most it can hold there. A set with an Undo (Photoshop) shows it there
-- instead, filling back up as it recharges; its G undoes.
-- A set with its own dash (Lightstep) gets a small Q slot on the bar's left
-- showing the dodge charges it spends (DodgeCharges), and one with a ranged
-- move a small slot beside it showing its ammo: charges, shots of Luminance
-- or rounds and the reload.
-- Shows the set's mastery
-- and, per skill, its key, name and cooldown, or the mastery it needs while
-- it's locked, plus the set's overcharge stacks (Mandela's Backbone Power):
-- once full they pulse green until G overcharges the set, burn red and drain while
-- it's overcharged, then show the overcharge cooldown. Also pops up mastery
-- level ups. The keys are the player's own (Keybinds, set in Settings); a
-- skill still reaches the server by its slot (Z..F) whatever key cast it.
-- SkillSetServer checks every cast and overcharge; the cooldowns
-- here are just the client's prediction for the display.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local AimIndicator = require(script.Parent:WaitForChild("AimIndicator"))
local DodgeCharges = require(script.Parent:WaitForChild("DodgeCharges"))
local useSkill = ReplicatedStorage:WaitForChild("UseSkill")
local activateOvercharge = ReplicatedStorage:WaitForChild("ActivateOvercharge")
local toggleFlight = ReplicatedStorage:WaitForChild("ToggleFlight")
local undoRemote = ReplicatedStorage:WaitForChild("Undo") -- made by PhotoshopServer
local masteryEvent = ReplicatedStorage:WaitForChild("MasteryUp")
local player = Players.LocalPlayer

local SLOT_SIZE = 58
local SLOT_GAP = 8
local HEADER_HEIGHT = 38
local STACK_ROW_Y = 23
local STACK_HEIGHT = 8
local STACK_LABEL_WIDTH = 96
local STACK_GAP = 2
local BOTTOM_MARGIN = 100 -- pixels, keeps it above the default hotbar
local AIM_DISTANCE = 1000
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local ACCENT = Color3.fromRGB(170, 255, 200) -- Mandela green
local GOLD = Color3.fromRGB(255, 205, 60) -- same as level ups
local DENIED = Color3.fromRGB(226, 75, 74)
local COOLING = Color3.fromRGB(140, 140, 150) -- stacks built while the overcharge cools down
local TRACK_TRANSPARENCY = 0.45 -- a meter segment's empty track
local OUT_OF_REACH_TRANSPARENCY = 0.85 -- a Luminance segment beyond what shade lets it hold
local LUMINANCE_SEGMENTS = 10
local CAST_PRIORITY = Enum.AnimationPriority.Action3 -- over the axe hold and swings
local CAST_BLEND = 0.08

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
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or TEXT
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "SkillBar",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local keys = SkillSetConfig.Keys
local barWidth = 0 -- set by layout() for the keys the equipped set uses
local bar = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
	Size = UDim2.fromOffset(barWidth, HEADER_HEIGHT + SLOT_SIZE),
	BackgroundTransparency = 1,
})

-- header: the set's name, its mastery and progress to the next level
local setLabel = label(bar, { TextSize = 12, TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 0, 14) })
-- the set's passive in the middle: its name when ready, a countdown while it recharges
local passiveLabel = label(bar, {
	TextSize = 9,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 2),
	Size = UDim2.fromOffset(140, 12),
	Visible = false,
})
local masteryLabel = label(bar, {
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.5, 0, 0, 14),
})
local xpTrack = make("Frame", {
	Parent = bar,
	Position = UDim2.fromOffset(0, 16),
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
})
local xpFill = make("Frame", { Parent = xpTrack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACCENT, BorderSizePixel = 0 })

-- overcharge stacks: a label and a row of square segments
local stackRow = make("Frame", {
	Parent = bar,
	Position = UDim2.fromOffset(0, STACK_ROW_Y),
	Size = UDim2.new(1, 0, 0, STACK_HEIGHT),
	BackgroundTransparency = 1,
	Visible = false,
})
local stackLabel = label(stackRow, {
	TextSize = 9,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(0, STACK_LABEL_WIDTH, 1, 0),
})
local stackSegments = {}
local stacksBuiltFor -- the count and bar width the segments were built for
local function buildStacks(count)
	local builtFor = count .. "@" .. barWidth
	if stacksBuiltFor == builtFor then
		return
	end
	stacksBuiltFor = builtFor
	for _, segment in ipairs(stackSegments) do
		segment.track:Destroy()
	end
	table.clear(stackSegments)
	local width = (barWidth - STACK_LABEL_WIDTH - (count - 1) * STACK_GAP) / count
	for i = 1, count do
		local track = make("Frame", {
			Parent = stackRow,
			Position = UDim2.fromOffset(STACK_LABEL_WIDTH + (i - 1) * (width + STACK_GAP), 0),
			Size = UDim2.new(0, width, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = TRACK_TRANSPARENCY,
			BorderSizePixel = 0,
		})
		local fill = make("Frame", { Parent = track, Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACCENT, BorderSizePixel = 0 })
		stackSegments[i] = { track = track, fill = fill }
	end
end

local slots = {}
for i, key in ipairs(keys) do
	local frame = make("Frame", {
		Parent = bar,
		Position = UDim2.fromOffset((i - 1) * (SLOT_SIZE + SLOT_GAP), HEADER_HEIGHT),
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = BACKGROUND,
		BackgroundTransparency = 0.25,
		Visible = false,
	})
	local stroke = make("UIStroke", { Parent = frame, Color = TEXT, Transparency = 0.5, Thickness = 1.5 })
	local scale = make("UIScale", { Parent = frame })
	-- dark cover whose top edge moves down as the cooldown runs out
	local cover = make("Frame", {
		Parent = frame,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	})
	local keycap = label(frame, {
		Text = key,
		TextSize = 12,
		TextColor3 = BACKGROUND,
		BackgroundTransparency = 0,
		BackgroundColor3 = TEXT,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(18, 18),
		AutomaticSize = Enum.AutomaticSize.X, -- wider for keys like F5 or LAlt
	})
	local status = label(frame, { TextSize = 14, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(1, 0, 0, 18) })
	-- strip along the top while this skill is in its overcharged form
	local empowered = make("Frame", {
		Parent = frame,
		Size = UDim2.new(1, 0, 0, 3),
		BorderSizePixel = 0,
		Visible = false,
	})
	-- up to two lines, shrinking a little for long names
	local name = label(frame, {
		TextSize = 9,
		TextWrapped = true,
		TextScaled = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -6, 0, 20),
	})
	make("UITextSizeConstraint", { Parent = name, MaxTextSize = 9 })
	slots[key] = { frame = frame, stroke = stroke, scale = scale, cover = cover, keycap = keycap, status = status, name = name, empowered = empowered }
end

-- Smaller slots hanging off the left of the bar, level with the skill slots'
-- bottoms: the set's own dash, and its ranged move further out.
local MINI_SLOT_SIZE = 40
local function miniSlot(keyText)
	local slot = {}
	slot.frame = make("Frame", {
		Parent = bar,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(MINI_SLOT_SIZE, MINI_SLOT_SIZE),
		BackgroundColor3 = BACKGROUND,
		BackgroundTransparency = 0.25,
		Visible = false,
	})
	slot.stroke = make("UIStroke", { Parent = slot.frame, Color = TEXT, Transparency = 0.5, Thickness = 1.5 })
	slot.scale = make("UIScale", { Parent = slot.frame })
	slot.cover = make("Frame", {
		Parent = slot.frame,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	})
	slot.keycap = label(slot.frame, {
		Text = keyText,
		TextSize = 10,
		TextColor3 = BACKGROUND,
		BackgroundTransparency = 0,
		BackgroundColor3 = TEXT,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(14, 14),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	slot.status = label(slot.frame, { TextSize = 11, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.new(1, 0, 0, 14) })
	slot.name = label(slot.frame, {
		TextSize = 8,
		TextScaled = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, -4, 0, 10),
	})
	make("UITextSizeConstraint", { Parent = slot.name, MaxTextSize = 8 })
	return slot
end
local dashSlot = miniSlot(Keybinds.Text("Dash"))
local rangedSlot = miniSlot("M2")

-- the keycaps show the player's own keys (Settings), kept up as they change
local function refreshKeys()
	for key, slot in pairs(slots) do
		slot.keycap.Text = Keybinds.Text("Skill" .. key)
	end
	dashSlot.keycap.Text = Keybinds.Text("Dash")
end
refreshKeys()
Keybinds.Changed(refreshKeys)
local dashWasCooling = false
local lastDodgeCharges = DodgeCharges.Get()

-- one slot per key the set has a skill on, side by side, the bar centred on them
local laidOutFor
local function layout(setName)
	if laidOutFor == setName then
		return
	end
	laidOutFor = setName
	local skills = SkillSetConfig.Sets[setName].skills
	local shown = 0
	for _, key in ipairs(keys) do
		local slot = slots[key]
		slot.frame.Visible = skills[key] ~= nil
		if skills[key] then
			slot.frame.Position = UDim2.fromOffset(shown * (SLOT_SIZE + SLOT_GAP), HEADER_HEIGHT)
			shown += 1
		end
	end
	barWidth = shown * SLOT_SIZE + math.max(shown - 1, 0) * SLOT_GAP
	bar.Size = UDim2.fromOffset(barWidth, HEADER_HEIGHT + SLOT_SIZE)
end

local predictedReadyAt = {} -- ["Mandela.X"] = os.clock() the skill is ready again
-- an admin cooldown reset clears the prediction too
player:GetAttributeChangedSignal("CooldownsResetAt"):Connect(function()
	table.clear(predictedReadyAt)
end)

local function equippedSet()
	local _, setName = SkillSetConfig.Equipped(player.Character)
	return setName
end

-- the point the mouse is on (or far off along it), and what it hit if anything
local function mouseHit()
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	return result and result.Position or ray.Origin + ray.Direction * AIM_DISTANCE, result
end

local function aimPoint()
	return (mouseHit())
end

local castTracks = setmetatable({}, { __mode = "k" })

-- e.g. MandelaAnimations.CastX, or CastZOvercharged for an overcharged form
-- with its own; skipped until it has been published
local function playCast(humanoid, setName, key, overcharged)
	local folder = ReplicatedStorage:FindFirstChild(setName .. "Animations")
	local animation = folder
		and (overcharged and folder:FindFirstChild("Cast" .. key .. "Overcharged") or folder:FindFirstChild("Cast" .. key))
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animation or animation.AnimationId == "" or not animator then
		return
	end
	local set = castTracks[animator]
	if not set then
		set = {}
		castTracks[animator] = set
	end
	if not set[animation] then
		set[animation] = animator:LoadAnimation(animation)
		set[animation].Priority = CAST_PRIORITY
	end
	set[animation]:Play(CAST_BLEND)
end

local function pulse(slot, color)
	slot.scale.Scale = color and 0.9 or 1.12
	TweenService:Create(slot.scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if color then
		slot.stroke.Color = color
		TweenService:Create(slot.stroke, TweenInfo.new(0.4), { Color = TEXT }):Play()
	end
end

-- whether the equipped set's Luminance is full (a skill's `fullName` version)
local function atFullLight()
	local setName = equippedSet()
	return setName ~= nil and (player:GetAttribute(SkillSetConfig.LuminanceAttribute(setName)) or 0) >= SkillSetConfig.FullLuminance
end

local function aimSpecFor(skill, overcharged, inForm)
	if skill.fullAim and atFullLight() then
		return skill.fullAim
	end
	return overcharged and skill.overchargedAim or inForm and skill.formAim or skill.aim
end

-- Skills that shoot (a line, a fan or a lock-on) fly at the mouse, up or
-- down; a point on the floor counts as FLOOR_LIFT above it, so aiming at the
-- ground sends them skimming over it at chest height instead of into it.
local SHOT_KINDS = { line = true, fan = true, lock = true }
local FLOOR_LIFT = 3 -- studs

-- where a skill is cast: at the mouse, or at a lock-on skill's target
local function castPoint(skill, overcharged, inForm)
	local point, hit = mouseHit()
	local spec = aimSpecFor(skill, overcharged, inForm)
	if spec and spec.kind == "lock" then
		local target = AimIndicator.LockTarget(player.Character, point, spec.range, spec.cone)
		if target then
			return target.Position
		end
	end
	if spec and SHOT_KINDS[spec.kind] and hit and hit.Normal.Y > 0.7 then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			point += Vector3.new(0, FLOOR_LIFT, 0)
		end
	end
	return point
end

local aiming -- the key held down to aim; it casts when let go

local function stopAiming()
	aiming = nil
	AimIndicator.Hide()
end

-- the equipped set, while the character is alive
local function activeSet()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return equippedSet()
end

-- whether the skill could go off right now
local function readyToCast(setName, key, skill)
	local mastery = player:GetAttribute(SkillSetConfig.MasteryAttribute(setName)) or 1
	local overcharged = SkillSetConfig.IsOvercharged(player, setName)
	-- a form that throws the weapon waits for it to come back
	local waitingForWeapon = skill.needsWeapon
		and not (overcharged and skill.overchargedHandler)
		and player.Character:GetAttribute("WeaponThrown")
	-- a form (Prism Form) takes some light to start
	local form = SkillSetConfig.Sets[setName].form
	local lacksLight = form ~= nil
		and form.key == key
		and (player:GetAttribute(SkillSetConfig.LuminanceAttribute(setName)) or 0) < form.minimumToStart
	-- (a skill with charges: when all are back, so one is ready a few recharges sooner)
	return skill.handler ~= nil
		and mastery >= skill.mastery
		and os.clock() >= (predictedReadyAt[setName .. "." .. key] or 0) - ((skill.charges or 1) - 1) * skill.cooldown
		and not waitingForWeapon
		and not lacksLight
		and not (skill.overchargedOnly and not overcharged)
end

local function cast(key)
	local setName = activeSet()
	local skill = setName and SkillSetConfig.Sets[setName].skills[key]
	if not skill then
		return
	end
	local slot = slots[key]
	-- things may have changed while it was held (the axe still out, say)
	if not readyToCast(setName, key, skill) then
		pulse(slot, DENIED)
		return
	end
	local overcharged = SkillSetConfig.IsOvercharged(player, setName)
	local inForm = SkillSetConfig.InForm(player.Character, setName)
	local id = setName .. "." .. key
	predictedReadyAt[id] = math.max(predictedReadyAt[id] or 0, os.clock()) + skill.cooldown
	playCast(player.Character:FindFirstChildOfClass("Humanoid"), setName, key, overcharged)
	useSkill:FireServer(key, castPoint(skill, overcharged, inForm))
	pulse(slot)
end

-- A skill's key recasts it if it's still out (Recall, Detonate), or starts
-- aiming it, casting when the key is let go; one with nothing to aim casts
-- straight away.
local function pressSkill(key)
	local setName = activeSet()
	local skill = setName and SkillSetConfig.Sets[setName].skills[key]
	if not skill then
		return
	end
	local slot = slots[key]
	if skill.recast and player:GetAttribute(SkillSetConfig.RecastAttribute(setName, key)) then
		stopAiming()
		useSkill:FireServer(key, aimPoint())
		pulse(slot)
		return
	end
	if not readyToCast(setName, key, skill) then
		pulse(slot, DENIED)
		return
	end
	if aimSpecFor(skill, SkillSetConfig.IsOvercharged(player, setName), SkillSetConfig.InForm(player.Character, setName)) then
		aiming = key
	else
		cast(key)
	end
end

-- the Special key (G unless rebound) does something only with full stacks and no cooldown
local overchargeDeniedUntil = 0 -- the meter's label flashes red after a refused press
local function tryOvercharge()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local setName = equippedSet()
	-- on a set with an Undo, the same key rewinds (once it's recharged)
	local undo = setName and SkillSetConfig.Sets[setName].undo
	if undo and humanoid and humanoid.Health > 0 then
		if (player:GetAttribute(SkillSetConfig.UndoReadyAttribute(setName)) or 0) > workspace:GetServerTimeNow() then
			overchargeDeniedUntil = os.clock() + 0.4
			return
		end
		undoRemote:FireServer()
		return
	end
	-- on a set that flies, the same key takes off or lands (it takes some light)
	local flight = setName and SkillSetConfig.Sets[setName].flight
	if flight and humanoid and humanoid.Health > 0 then
		local luminance = player:GetAttribute(SkillSetConfig.LuminanceAttribute(setName)) or 0
		if not character:GetAttribute("Flying") and luminance < flight.minimumToStart then
			overchargeDeniedUntil = os.clock() + 0.4
			return
		end
		toggleFlight:FireServer()
		return
	end
	local settings = setName and SkillSetConfig.Sets[setName].overcharge
	if not settings or not humanoid or humanoid.Health <= 0 or SkillSetConfig.IsOvercharged(player, setName) then
		return
	end
	local full = (player:GetAttribute(SkillSetConfig.StacksAttribute(setName)) or 0) >= settings.maxStacks
	local cooling = (player:GetAttribute(SkillSetConfig.OverchargeCooldownAttribute(setName)) or 0) > workspace:GetServerTimeNow()
	if not full or cooling then
		overchargeDeniedUntil = os.clock() + 0.4
		return
	end
	activateOvercharge:FireServer()
end

-- the skill slot a key is bound to (Keybinds' SkillZ..SkillF), if any
local function slotFor(keyCode)
	local action = Keybinds.ActionFor(keyCode)
	local slot = action and string.match(action, "^Skill(%u)$")
	return slot and slots[slot] and slot or nil
end
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or Keybinds.Capturing() then
		return
	end
	local key = slotFor(input.KeyCode)
	if key then
		pressSkill(key)
	elseif Keybinds.ActionFor(input.KeyCode) == "Special" then
		tryOvercharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and aiming then
		-- right click calls the aim off
		stopAiming()
	end
end)
-- letting go of the aimed key casts it, even over a menu
UserInputService.InputEnded:Connect(function(input)
	local key = slotFor(input.KeyCode)
	if key and key == aiming then
		stopAiming()
		cast(key)
	end
end)

RunService.RenderStepped:Connect(function()
	local setName = equippedSet()
	gui.Enabled = setName ~= nil
	if not setName then
		if aiming then
			stopAiming()
		end
		return
	end
	layout(setName)
	local set = SkillSetConfig.Sets[setName]
	local mastery = player:GetAttribute(SkillSetConfig.MasteryAttribute(setName)) or 1
	local xp = player:GetAttribute(SkillSetConfig.MasteryXPAttribute(setName)) or 0
	setLabel.Text = string.upper(set.tool)
	setLabel.TextColor3 = set.color
	xpFill.BackgroundColor3 = set.color
	passiveLabel.Visible = set.passive ~= nil
	local inForm = SkillSetConfig.InForm(player.Character, setName)
	if set.passive and set.passive.name == "Luminance" then
		-- the meter below shows the light; up here, what it's worth right now
		local luminance = player:GetAttribute(SkillSetConfig.LuminanceAttribute(setName)) or 0
		local cut = inForm and set.form.physicalReduction or set.passive.physicalReduction * luminance
		passiveLabel.Text = cut >= 1 and "PHYSICAL IMMUNE" or string.format("-%d%% PHYSICAL", math.round(cut * 100))
		passiveLabel.TextColor3 = cut > 0 and set.color or MUTED
	elseif set.passive then
		local recharging = (player:GetAttribute(SkillSetConfig.PassiveReadyAttribute(setName)) or 0) - workspace:GetServerTimeNow()
		if recharging > 0 then
			passiveLabel.Text = string.format("%s  %ds", string.upper(set.passive.name), math.ceil(recharging))
			passiveLabel.TextColor3 = MUTED
		else
			passiveLabel.Text = string.upper(set.passive.name)
			passiveLabel.TextColor3 = set.color
		end
	end
	masteryLabel.Text = "Mastery " .. mastery
	local progress = mastery >= SkillSetConfig.MaxMastery and 1 or xp / SkillSetConfig.MasteryToLevelUp(mastery)
	xpFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)

	local settings = set.overcharge
	local overcharged = settings ~= nil and SkillSetConfig.IsOvercharged(player, setName)
	local luminancePassive = set.passive ~= nil and set.passive.name == "Luminance"
	local undo = set.undo
	stackRow.Visible = settings ~= nil or luminancePassive or undo ~= nil
	if undo then
		-- one segment that fills back up as Undo recharges
		buildStacks(1)
		local left = (player:GetAttribute(SkillSetConfig.UndoReadyAttribute(setName)) or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			stackLabel.Text = string.format("%s %ds", string.upper(undo.name), math.ceil(left))
			stackLabel.TextColor3 = MUTED
		else
			stackLabel.Text = string.format("%s  [%s]", string.upper(undo.name), Keybinds.Text("Special"))
			stackLabel.TextColor3 = set.color
		end
		if os.clock() < overchargeDeniedUntil then
			stackLabel.TextColor3 = DENIED
		end
		local segment = stackSegments[1]
		segment.fill.Size = UDim2.fromScale(math.clamp(1 - left / undo.cooldown, 0, 1), 1)
		segment.fill.BackgroundColor3 = left > 0 and COOLING or set.color
		segment.fill.BackgroundTransparency = 0
		segment.track.BackgroundTransparency = TRACK_TRANSPARENCY
	elseif luminancePassive then
		-- the light held, one band of the spectrum per segment
		buildStacks(LUMINANCE_SEGMENTS)
		local luminance = player:GetAttribute(SkillSetConfig.LuminanceAttribute(setName)) or 0
		local flying = player.Character and player.Character:GetAttribute("Flying")
		local shaded = player:GetAttribute(SkillSetConfig.ShadedAttribute) == true
		local state = inForm and string.upper(set.form.name) or flying and "FLYING" or shaded and "SHADE" or "LUMINANCE"
		stackLabel.Text = string.format("%s  %d%%", state, math.round(luminance * 100))
		stackLabel.TextColor3 = os.clock() < overchargeDeniedUntil and DENIED or shaded and MUTED or set.color
		-- the light shimmers while the form burns it
		local shimmer = inForm and (0.5 - 0.5 * math.cos(os.clock() * 8)) * 0.4 or 0
		local capSegments = shaded and set.passive.shadeCap * LUMINANCE_SEGMENTS or LUMINANCE_SEGMENTS
		for i, segment in ipairs(stackSegments) do
			segment.fill.Size = UDim2.fromScale(math.clamp(luminance * LUMINANCE_SEGMENTS - (i - 1), 0, 1), 1)
			segment.fill.BackgroundColor3 = SkillSetConfig.IridescentColor((i - 1) / (LUMINANCE_SEGMENTS - 1))
			segment.fill.BackgroundTransparency = shimmer
			-- out of reach in the shade: the segment's track fades
			segment.track.BackgroundTransparency = i > capSegments and OUT_OF_REACH_TRANSPARENCY or TRACK_TRANSPARENCY
		end
	elseif settings then
		buildStacks(settings.maxStacks)
		local filled
		local ready = false
		local cooling = false
		if overcharged then
			-- drains as the overcharge runs out
			local remaining = (player:GetAttribute(SkillSetConfig.OverchargeEndAttribute(setName)) or 0) - workspace:GetServerTimeNow()
			filled = settings.maxStacks * math.clamp(remaining / settings.duration, 0, 1)
			stackLabel.Text = string.format("OVERCHARGE %.1fs", math.max(remaining, 0))
			stackLabel.TextColor3 = settings.color
		else
			filled = player:GetAttribute(SkillSetConfig.StacksAttribute(setName)) or 0
			local cooldownLeft = (player:GetAttribute(SkillSetConfig.OverchargeCooldownAttribute(setName)) or 0) - workspace:GetServerTimeNow()
			if cooldownLeft > 0 then
				cooling = true
				stackLabel.Text = string.format("COOLDOWN %ds", math.ceil(cooldownLeft))
				stackLabel.TextColor3 = MUTED
			elseif filled >= settings.maxStacks then
				ready = true
				stackLabel.Text = string.format("READY  [%s]", Keybinds.Text("Special"))
				stackLabel.TextColor3 = ACCENT
			else
				stackLabel.Text = string.upper(settings.name)
				stackLabel.TextColor3 = MUTED
			end
		end
		if os.clock() < overchargeDeniedUntil then
			stackLabel.TextColor3 = DENIED
		end
		-- a full meter waiting for the key pulses
		local pulseTransparency = ready and (0.5 - 0.5 * math.cos(os.clock() * 6)) * 0.45 or 0
		for i, segment in ipairs(stackSegments) do
			segment.fill.Size = UDim2.fromScale(math.clamp(filled - (i - 1), 0, 1), 1)
			segment.fill.BackgroundColor3 = overcharged and settings.color or cooling and COOLING or ACCENT
			segment.fill.BackgroundTransparency = pulseTransparency
			segment.track.BackgroundTransparency = TRACK_TRANSPARENCY
		end
	end

	local now = os.clock()
	for key, slot in pairs(slots) do
		local skill = set.skills[key]
		if not skill then
			continue
		end
		slot.empowered.Visible = overcharged and skill.overcharged == true or inForm and skill.form == true
		if settings then
			slot.empowered.BackgroundColor3 = settings.color
		elseif inForm then
			slot.empowered.BackgroundColor3 = SkillSetConfig.IridescentColor(0.5 + 0.5 * math.sin(os.clock() * 1.6))
		end
		local available = skill.handler ~= nil and mastery >= skill.mastery
		local remaining = math.max((predictedReadyAt[setName .. "." .. key] or 0) - now, 0)
		local skillName = overcharged and skill.overchargedName or skill.fullName and atFullLight() and skill.fullName or skill.name
		slot.name.Text = skill.handler and skillName or "Soon"
		slot.name.TextTransparency = available and 0 or 0.4
		slot.keycap.BackgroundTransparency = available and 0 or 0.5
		if not skill.handler then
			slot.status.Text = "?"
			slot.status.TextColor3 = MUTED
			slot.cover.Size = UDim2.fromScale(1, 1)
		elseif not available then
			slot.status.Text = "Lv " .. skill.mastery
			slot.status.TextColor3 = MUTED
			slot.cover.Size = UDim2.fromScale(1, 1)
		elseif skill.overchargedOnly and not overcharged then
			-- an ultimate waits for the overcharge
			slot.status.Text = "OC ONLY"
			slot.status.TextColor3 = settings and settings.color or MUTED
			slot.cover.Size = UDim2.fromScale(1, 1)
		elseif skill.recast and player:GetAttribute(SkillSetConfig.RecastAttribute(setName, key)) then
			-- still out: the key does its recast now
			slot.status.Text = string.upper(skill.recast)
			slot.status.TextColor3 = GOLD
			slot.cover.Size = UDim2.fromScale(1, remaining / skill.cooldown)
		elseif skill.charges then
			-- charges ready, or the next one's refill when none are
			local ready = skill.charges - math.ceil(remaining / skill.cooldown - 1e-6)
			if ready >= 1 then
				slot.status.Text = "x" .. ready
				slot.cover.Size = UDim2.fromScale(1, 0)
			else
				local nextIn = remaining - (skill.charges - 1) * skill.cooldown
				slot.status.Text = string.format("%.1f", nextIn)
				slot.cover.Size = UDim2.fromScale(1, nextIn / skill.cooldown)
			end
			slot.status.TextColor3 = TEXT
		else
			slot.status.Text = remaining > 0 and string.format("%.1f", remaining) or ""
			slot.status.TextColor3 = TEXT
			slot.cover.Size = UDim2.fromScale(1, remaining / skill.cooldown)
		end
		-- longer words like DETONATE shrink to fit
		slot.status.TextSize = #slot.status.Text > 5 and 10 or 14
		-- the slot being aimed lights up
		slot.stroke.Transparency = aiming == key and 0 or 0.5
	end

	-- the set's own dash: the dodge charges it spends (how many are ready, or
	-- the next one refilling)
	local dashSpec = set.dash
	dashSlot.frame.Visible = dashSpec ~= nil
	local charges = DodgeCharges.Get()
	-- a charge just went: pop
	if dashSpec and charges < lastDodgeCharges - 0.5 then
		pulse(dashSlot)
	end
	lastDodgeCharges = charges
	if dashSpec then
		local ready = math.floor(charges)
		local remaining = ready >= 1 and 0 or (1 - charges) * DodgeCharges.RechargeTime
		dashSlot.name.Text = dashSpec.name
		if remaining > 0 then
			dashSlot.status.Text = string.format("%.1f", remaining)
		else
			dashSlot.status.Text = DodgeCharges.Max > 1 and "x" .. ready or ""
		end
		dashSlot.cover.Size = UDim2.fromScale(1, remaining / DodgeCharges.RechargeTime)
		dashSlot.keycap.BackgroundTransparency = remaining > 0 and 0.5 or 0
		-- a flash of the set's colour the moment it's back
		if dashWasCooling and remaining <= 0 then
			dashSlot.stroke.Color = set.color
			dashSlot.stroke.Transparency = 0
			TweenService:Create(dashSlot.stroke, TweenInfo.new(0.4), { Color = TEXT, Transparency = 0.5 }):Play()
		end
		dashWasCooling = remaining > 0
	end

	-- the ranged move's ammo: charges ready (or the next one's refill), shots
	-- of Luminance left, or rounds (or the reload)
	local ranged = set.ranged
	rangedSlot.frame.Visible = ranged ~= nil
	if ranged then
		local status, cover = "", 0
		if ranged.charges then
			local stored = SkillSetConfig.RangedCharges(player, setName)
			if stored >= 1 then
				status = "x" .. math.floor(stored)
			else
				status = string.format("%.1f", (1 - stored) * ranged.recharge)
				cover = 1 - stored
			end
		elseif ranged.luminanceCost then
			local light = player:GetAttribute(SkillSetConfig.LuminanceAttribute(setName)) or 0
			local shots = math.floor(light / ranged.luminanceCost + 1e-6)
			status = "x" .. shots
			cover = shots < 1 and 1 or 0
		elseif ranged.rounds then
			local rounds, reloading = SkillSetConfig.Rounds(player, setName)
			if reloading > 0 then
				status = string.format("%.1f", reloading)
				cover = reloading / ranged.reload
			else
				status = rounds .. "/" .. ranged.rounds
			end
		end
		rangedSlot.name.Text = ranged.name
		rangedSlot.keycap.Text = ranged.primary and "M1" or "M2"
		rangedSlot.keycap.Size = UDim2.fromOffset(18, 14)
		rangedSlot.status.Text = status
		rangedSlot.cover.Size = UDim2.fromScale(1, math.clamp(cover, 0, 1))
		rangedSlot.keycap.BackgroundTransparency = cover > 0 and 0.5 or 0
	end
	-- the mini slots line up leftward from the bar, the dash nearest
	local miniOffset = SLOT_GAP
	for _, mini in ipairs({ dashSlot, rangedSlot }) do
		if mini.frame.Visible then
			mini.frame.Position = UDim2.fromOffset(-miniOffset, HEADER_HEIGHT + SLOT_SIZE - MINI_SLOT_SIZE)
			miniOffset += MINI_SLOT_SIZE + SLOT_GAP
		end
	end

	-- the held skill's aim preview
	local aimedSkill = aiming and set.skills[aiming]
	if aimedSkill then
		local color = overcharged and settings.color or set.color
		AimIndicator.Draw(aimSpecFor(aimedSkill, overcharged, inForm), player.Character, aimPoint(), color)
	end
end)

-- mastery popups get their own screen, which stays on even when the bar hides
local popupGui = make("ScreenGui", {
	Name = "SkillPopups",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- a line of text that drifts up and fades
local function popup(text, color, size, height, lifetime)
	local popupLabel = label(popupGui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, height),
		Size = UDim2.fromOffset(400, size + 8),
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		TextStrokeTransparency = 0.5,
	})
	TweenService:Create(popupLabel, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, height - 0.03),
	}):Play()
	local fade = TweenInfo.new(lifetime / 2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, lifetime / 2)
	TweenService:Create(popupLabel, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(popupLabel, lifetime)
end

masteryEvent.OnClientEvent:Connect(function(setName, fromLevel, toLevel)
	local set = SkillSetConfig.Sets[setName]
	if not set then
		return
	end
	popup(string.format("%s MASTERY %d", string.upper(setName), toLevel), ACCENT, 26, 0.16, 2.5)
	local line = 0
	for _, key in ipairs(keys) do
		local skill = set.skills[key]
		if skill and skill.handler and skill.mastery > fromLevel and skill.mastery <= toLevel then
			line += 1
			popup(string.format("%s (%s) unlocked", skill.name, Keybinds.Text("Skill" .. key)), GOLD, 16, 0.16 + 0.045 * line, 2.5)
		end
	end
end)
