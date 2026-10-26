-- Raid bosses (numbers and pure rules in ReplicatedStorage.RaidConfig): Spawn
-- puts one in the world and fights it until it dies, leaves (its lifetime) or
-- is removed. RaidServer spawns them on their timers; the admin panel can too.
-- The boss is its model in ServerStorage.Bosses.<key> if there is one, else a
-- plain R6 stand-in; either way it's unanchored and stood on the ground by its root. It's tagged RaidBoss (so EnemyAI leaves it alone) and
-- Enemy (lock-on, aim assist, Drops: its EnemyConfig entry has the drops).
-- Each tick it picks a target among the living players in its arena (the
-- nearest, kept a few seconds) and casts a move RaidConfig.PickMove allows, or
-- walks at them. Moves warn first: a ground marking (RaidEvent "Warn") and/or
-- the red Telegraph flash. Every hit goes through Damage.Deal with no attacker,
-- so dodges, blocks and passives work as on any enemy hit.
-- Damage.SetAbsorber gives it Misremembered (every few seconds the next hit is
-- erased) and the dome's shield, and counts each player's damage: helpers get
-- the XP and yen (its XPReward/YenReward are 0, so the killing blow pays nothing
-- extra). The grab (SpineLash) holds a player for a QTE their client shows
-- (RaidEvent "Qte"; they answer with ("Qte", key)): finish it, or have allies
-- hit him hard enough, and he reels; fail and they're impaled.
-- He wears the Mandela set's wearables (ServerStorage.SkillSets.Mandela; the R15
-- pieces moved onto R6 arms) and his moves use the set's own visuals: the axe
-- throw, the black hole and tornado templates (drawn by SkillEffects from their
-- attributes, as for a player's cast), Spine Lash, the knives, BoneSpikes,
-- Shockwave, Misremember, Overcharge and the dome of mirror glass from his
-- ultimate (the Rewrite events of Skills.PlaceWhereDreamEnds, without its solid
-- wall). RaidClient draws the ground markings.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CombatFeel = require(ReplicatedStorage:WaitForChild("CombatFeel"))
local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local EnemyAttackConfig = require(ReplicatedStorage:WaitForChild("EnemyAttackConfig"))
local PlayerStats = require(ServerScriptService:WaitForChild("PlayerStats"))
local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local RaidConfig = require(ReplicatedStorage:WaitForChild("RaidConfig"))
local PlaceWhereDreamEnds = require(ServerScriptService:WaitForChild("Skills"):WaitForChild("PlaceWhereDreamEnds"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local remote = Instance.new("RemoteEvent")
remote.Name = RaidConfig.RemoteName
remote.Parent = ReplicatedStorage

local TICK = 0.15 -- seconds between decisions
local RETARGET = 4 -- seconds it keeps a target before looking for the nearest again
local REACH_TOLERANCE = 1.5 -- extra studs a target may have moved during a swing's wind-up
local LUNGE_SPEED = 70 -- studs per second
local QTE_PRESS_SPACING = 0.05 -- seconds; faster presses are ignored
local CORPSE_TIME = 10 -- seconds the body stays after it dies
local FLING_SPEED = 55
local FLING_TIME = 0.3
local BOSS_FOLDER = "Bosses" -- in ServerStorage
local WALK_ANIMATION = "rbxassetid://180426354" -- R6, when its model's Animate has none
local SLASH_ANIMATION = "rbxassetid://129967390"
local WEARABLES_FOLDER = "SkillSetWearables" -- SkillEffects' AxeThrow finds the axe here
local TINT_AMOUNT = 0.45 -- how far a TintWhenOvercharged piece shifts toward the red
-- the R15 body parts the wearables name, on an R6 body: its part and an offset
local R6_PARTS = {
	RightHand = { "Right Arm", CFrame.new(0, -0.85, 0) },
	LeftHand = { "Left Arm", CFrame.new(0, -0.85, 0) },
	RightUpperArm = { "Right Arm", CFrame.new(0, 0.4, 0) },
	LeftUpperArm = { "Left Arm", CFrame.new(0, 0.4, 0) },
	UpperTorso = { "Torso", CFrame.new(0, 0.2, 0) },
}
local HOLE_TUNED_RADIUS = 30 -- the radius the BlackHole templates are built at
local HOLE_HOVER = 6 -- studs above the ground
local HOLE_GROW_TIME = 0.4
local HOLE_COLLAPSE_TIME = 0.25
local ORB_SPEED = 90 -- studs per second from his hand to where the hole opens
local TORNADO_SIZE = 0.42 -- of the template, like the overcharged cast's three
local TORNADO_GROW_TIME = 0.5
local TORNADO_WOBBLE = 4 -- studs side to side, as Skills.Tornado
local TORNADO_WOBBLE_FREQUENCY = 2.2
local TORNADO_CLEANUP = 0.6
local DOME_GHOSTS = 3 -- reflections of him the glass keeps as his shield is hit
local domeCount = 0
local mandela = ServerStorage:WaitForChild("SkillSets"):WaitForChild("Mandela")

local RaidBoss = {}
local live = {} -- boss key -> its fight
local projectileCount = 0

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function flatUnit(vector, fallback)
	local f = flat(vector)
	return f.Magnitude > 0.05 and f.Unit or fallback
end

local function rotated(direction, degrees)
	return CFrame.fromAxisAngle(Vector3.yAxis, math.rad(degrees)):VectorToWorldSpace(direction)
end

-- every living player within `radius` of `center` (flat distance if `flatOnly`)
local function playersIn(center, radius, flatOnly)
	local found = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and humanoid.Health > 0 then
			local offset = root.Position - center
			if (flatOnly and flat(offset) or offset).Magnitude <= radius then
				table.insert(found, { player = player, character = character, humanoid = humanoid, root = root })
			end
		end
	end
	return found
end

local function stillThere(target)
	return target and target.player.Parent and target.root.Parent and target.humanoid.Health > 0
end

-- the floor under a point (or a little under the point if there's none)
local function ground(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(ignore, player.Character)
	end
	for _, model in ipairs(CollectionService:GetTagged(RaidConfig.Tag)) do
		table.insert(ignore, model)
	end
	-- black holes and tornadoes
	for _, child in ipairs(workspace:GetChildren()) do
		if child:GetAttribute("ClientEffect") then
			table.insert(ignore, child)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position or position - Vector3.new(0, 3, 0)
end

local function alive(fight)
	return not fight.ended and fight.model.Parent ~= nil and fight.humanoid.Health > 0 and fight.humanoid.RootPart ~= nil
end

local function color(fight)
	local phase = fight.boss.phases[fight.phase]
	return RaidConfig.Color(phase.overcharged and fight.boss.overchargeColor or fight.boss.color)
end

-- one of its hits: `multiplier` of its damage
local function hurt(fight, humanoid, multiplier, options)
	return Damage.Deal(nil, humanoid, fight.boss.damage * multiplier, options or { guard = "skill" })
end

local function face(fight, position)
	local root = fight.humanoid.RootPart
	local direction = flatUnit(position - root.Position)
	if direction then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end
end

-- a push along the ground for `time` seconds (a lunge, a fling)
local function push(root, velocity, time, name)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = name
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	mover.MaxAxesForce = Vector3.new(math.huge, 0, math.huge)
	mover.VectorVelocity = velocity
	mover.Parent = root
	if time then
		Debris:AddItem(mover, time)
		Debris:AddItem(attachment, time)
	end
	return mover, attachment
end

-- throws a player away from `from`, if nothing else is holding them
local function fling(target, from)
	if target.root.Anchored or not CrowdControl.CanControl(target.character) then
		return
	end
	local away = flatUnit(target.root.Position - from, Vector3.xAxis)
	CrowdControl.Apply(target.character, FLING_TIME)
	push(target.root, away * FLING_SPEED, FLING_TIME, "RaidFling")
end

-- ground markings on every client: a circle of `size` radius, or a line `size`
-- (width, 0, length) starting at `cframe` and running along its look vector
local function mark(shape, cframe, size, time, warnColor)
	remote:FireAllClients("Warn", shape, cframe, size, time, warnColor)
end

local MOVES = {}

function MOVES.Combo(fight, target)
	local move = fight.boss.moves.Combo
	for _, kind in ipairs(move.steps) do
		if not alive(fight) or not stillThere(target) then
			return
		end
		local root = fight.humanoid.RootPart
		local attack = EnemyAttackConfig.Get(kind)
		local offset = flat(target.root.Position - root.Position)
		face(fight, target.root.Position)
		if kind == "heavy" and offset.Magnitude > 3 then
			local distance = math.min(offset.Magnitude - 3, move.lunge)
			push(root, offset.Unit * LUNGE_SPEED, distance / LUNGE_SPEED, "RaidLunge")
		end
		fight.slashTrack:Play(0.1)
		skillEffects:FireAllClients("Telegraph", fight.model, kind, attack.windUp)
		task.wait(attack.windUp)
		root = fight.humanoid.RootPart
		if not alive(fight) or not stillThere(target) then
			return
		end
		if (target.root.Position - root.Position).Magnitude <= move.reach + REACH_TOLERANCE then
			if hurt(fight, target.humanoid, attack.damage, { melee = true, guard = "melee" }) > 0 then
				skillEffects:FireAllClients("Slash", target.root.Position, flatUnit(target.root.Position - root.Position, Vector3.zAxis), kind == "heavy", color(fight))
			end
		end
		task.wait(0.25)
	end
end

-- his worn axe, hidden while it's thrown (as Skills.AxeBoomerang does)
local function hideAxe(fight, hidden)
	local folder = fight.model:FindFirstChild(WEARABLES_FOLDER)
	local axe = folder and folder:FindFirstChild("Axe")
	if not axe then
		return
	end
	for _, instance in ipairs({ axe, table.unpack(axe:GetDescendants()) }) do
		if instance:IsA("BasePart") then
			if hidden then
				instance:SetAttribute("ShownTransparency", instance:GetAttribute("ShownTransparency") or instance.Transparency)
				instance.Transparency = 1
			elseif instance:GetAttribute("ShownTransparency") then
				instance.Transparency = instance:GetAttribute("ShownTransparency")
			end
		end
	end
end

-- the axe flies out along a line and back to his hand, striking everyone on
-- each pass; the out leg eases to a stop like SkillEffects' AxeThrow draws it
function MOVES.AxeBoomerang(fight, target)
	local move = fight.boss.moves.AxeBoomerang
	local root = fight.humanoid.RootPart
	local direction = flatUnit(target.root.Position - root.Position, root.CFrame.LookVector)
	face(fight, target.root.Position)
	mark("line", CFrame.lookAt(ground(root.Position), ground(root.Position) + direction), Vector3.new(move.radius * 2, 0, move.length), move.windUp, color(fight))
	fight.slashTrack:Play(0.1)
	task.wait(move.windUp)
	if not alive(fight) then
		return
	end
	local hand = fight.model:FindFirstChild("Right Arm") or fight.humanoid.RootPart
	local from = hand.Position
	local to = from + direction * move.length
	local returnSpeed = move.length / move.outTime
	fight.model:SetAttribute("WeaponThrown", true)
	skillEffects:FireAllClients("AxeThrow", fight.model, from, to, workspace:GetServerTimeNow(), move.outTime, returnSpeed, color(fight))
	hideAxe(fight, true)
	local struck = { {}, {} } -- out, back
	local started = os.clock()
	local position = from
	while alive(fight) and os.clock() - started < move.outTime * 4 do
		local t = os.clock() - started
		local pass = 1
		if t < move.outTime then
			position = from + (to - from) * (1 - (1 - t / move.outTime) ^ 2)
		else
			pass = 2
			local offset = hand.Position - position
			if offset.Magnitude <= 2 then
				break
			end
			position += offset.Unit * math.min(returnSpeed * RunService.Heartbeat:Wait(), offset.Magnitude)
		end
		for _, victim in ipairs(playersIn(position, move.radius)) do
			if not struck[pass][victim.humanoid] then
				struck[pass][victim.humanoid] = true
				hurt(fight, victim.humanoid, move.damage)
			end
		end
		if pass == 1 then
			RunService.Heartbeat:Wait()
		end
	end
	fight.model:SetAttribute("WeaponThrown", nil)
	hideAxe(fight, false)
end

-- a fan of Mandela's knives
function MOVES.KnifeFan(fight, target)
	local move = fight.boss.moves.KnifeFan
	local root = fight.humanoid.RootPart
	face(fight, target.root.Position)
	skillEffects:FireAllClients("Telegraph", fight.model, "quick", move.windUp)
	task.wait(move.windUp)
	if not alive(fight) then
		return
	end
	root = fight.humanoid.RootPart
	local aim = target.root.Parent and target.root.Position or root.Position + root.CFrame.LookVector
	local direction = flatUnit(aim - root.Position, root.CFrame.LookVector)
	for i = 1, move.count do
		local angle = (i - (move.count + 1) / 2) * move.spread / math.max(move.count - 1, 1)
		projectileCount += 1
		Projectiles.Launch({
			character = fight.model,
			id = "Raid" .. projectileCount,
			model = "Knife",
			origin = root.Position + direction * 2,
			direction = rotated(direction, angle),
			speed = move.speed,
			range = move.length,
			radius = move.radius,
			spin = 900,
			onHit = function(humanoid)
				if Players:GetPlayerFromCharacter(humanoid.Parent) then
					hurt(fight, humanoid, move.damage, { guard = "ranged" })
				end
			end,
		})
	end
	task.wait(0.3)
end

-- a black hole on the target: drags and hurts everyone in it, then bursts
function MOVES.EventHorizon(fight, target)
	local move = fight.boss.moves.EventHorizon
	local center = ground(target.root.Position)
	face(fight, center)
	mark("circle", CFrame.new(center), move.radius, move.windUp, color(fight))
	task.wait(move.windUp)
	if not alive(fight) then
		return
	end
	-- Mandela's own black hole: an orb from his left hand, then the hole (BlackHoleEffect)
	local overcharged = fight.boss.phases[fight.phase].overcharged
	local hole = mandela:WaitForChild(overcharged and "BlackHoleOvercharged" or "BlackHole"):Clone()
	local hand = fight.model:FindFirstChild("Left Arm") or fight.humanoid.RootPart
	local holeCenter = center + Vector3.new(0, HOLE_HOVER, 0)
	local travelTime = math.clamp((holeCenter - hand.Position).Magnitude / ORB_SPEED, 0.25, 0.7)
	local fullScale = hole:GetScale() * move.radius / HOLE_TUNED_RADIUS
	hole:PivotTo(CFrame.new(holeCenter))
	hole:ScaleTo(fullScale * 0.05)
	hole:SetAttribute("FullScale", fullScale)
	hole:SetAttribute("Duration", move.duration)
	hole:SetAttribute("GrowTime", HOLE_GROW_TIME)
	hole:SetAttribute("GroundY", center.Y)
	hole:SetAttribute("Radius", move.radius)
	hole:SetAttribute("StartedAt", workspace:GetServerTimeNow() + travelTime)
	hole:SetAttribute("LaunchFrom", hand.Position)
	hole:SetAttribute("TravelTime", travelTime)
	hole.Parent = workspace
	task.delay(travelTime + move.duration + HOLE_COLLAPSE_TIME + 0.2, function()
		hole:Destroy()
	end)
	task.wait(travelTime)
	local pulled = {} -- humanoid -> { character, root, mover, attachment }
	local function release(humanoid)
		local pull = pulled[humanoid]
		pulled[humanoid] = nil
		pull.mover:Destroy()
		pull.attachment:Destroy()
		CrowdControl.End(pull.character)
	end
	local endsAt = os.clock() + move.duration
	local nextTick = 0
	while os.clock() < endsAt and alive(fight) do
		local now = os.clock()
		local ticking = now >= nextTick
		if ticking then
			nextTick = now + move.tick
		end
		for _, victim in ipairs(playersIn(center, move.radius, true)) do
			if ticking then
				hurt(fight, victim.humanoid, move.tickDamage)
			end
			if not pulled[victim.humanoid] and not victim.root.Anchored and CrowdControl.CanControl(victim.character) then
				CrowdControl.Begin(victim.character)
				local mover, attachment = push(victim.root, Vector3.zero, nil, "RaidPull")
				pulled[victim.humanoid] = { character = victim.character, root = victim.root, mover = mover, attachment = attachment }
			end
		end
		for humanoid, pull in pairs(pulled) do
			-- a dodge or CrowdControl's MaxHold lets them go
			if not pull.root.Parent or humanoid.Health <= 0 or not CrowdControl.Holding(pull.character) then
				release(humanoid)
			else
				local toward = flat(center - pull.root.Position)
				pull.mover.VectorVelocity = toward.Magnitude > 2 and toward.Unit * move.pullSpeed or Vector3.zero
			end
		end
		RunService.Heartbeat:Wait()
	end
	for humanoid in pairs(pulled) do
		release(humanoid)
	end
	if not alive(fight) then
		return
	end
	for _, victim in ipairs(playersIn(center, move.radius, true)) do
		hurt(fight, victim.humanoid, move.damage)
		fling(victim, center)
	end
	skillEffects:FireAllClients("Shockwave", center, move.radius, color(fight))
end

-- held for the QTE until it's done, they're rescued, it runs out or someone dies
local function grab(fight, victim, move)
	local root = fight.humanoid.RootPart
	local character = victim.character
	skillEffects:FireAllClients("BoneSpikes", victim.root.Position, color(fight), 0.6)
	local hold = root.CFrame * CFrame.new(0, 0, -move.holdDistance)
	victim.root.CFrame = CFrame.lookAt(hold.Position, Vector3.new(root.Position.X, hold.Position.Y, root.Position.Z))
	victim.root.Anchored = true
	-- can't fight back while held
	character:SetAttribute("HitstunUntil", workspace:GetServerTimeNow() + move.qteTime + 0.5)
	CrowdControl.Apply(character, move.qteTime)
	local count = move.keys + (fight.phase >= #fight.boss.phases and 1 or 0)
	local held = { player = victim.player, keys = RaidConfig.QteSequence(count, math.random), progress = 0, done = false, rescue = 0, lastPress = 0 }
	fight.grabbed = held
	remote:FireClient(victim.player, "Qte", held.keys, move.qteTime)
	remote:FireAllClients("Grabbed", victim.player.DisplayName, victim.player)
	local endsAt = os.clock() + move.qteTime
	while os.clock() < endsAt and not held.done and alive(fight) and stillThere(victim) do
		if held.rescue >= fight.humanoid.MaxHealth * move.rescueShare then
			held.done = true
		end
		task.wait(0.05)
	end
	fight.grabbed = nil
	if victim.root.Parent then
		victim.root.Anchored = false
	end
	character:SetAttribute("HitstunUntil", nil)
	remote:FireClient(victim.player, "QteEnd", held.done)
	if not alive(fight) then
		return
	end
	if held.done then
		-- broke free (or was freed): he reels
		fight.staggerUntil = os.clock() + move.stagger
		fight.model:SetAttribute("StaggeredUntil", workspace:GetServerTimeNow() + move.stagger)
		skillEffects:FireAllClients("PoiseBreak", fight.model)
		remote:FireAllClients("Freed", victim.player.DisplayName)
	elseif stillThere(victim) then
		skillEffects:FireAllClients("BoneSpikes", victim.root.Position, color(fight), 1.4)
		Damage.Deal(nil, victim.humanoid, victim.humanoid.MaxHealth * move.failShare, { unavoidable = true, guard = "unblockable" })
		fling(victim, fight.humanoid.RootPart.Position)
	end
end

-- the spine whips out along a line; the first player it reaches is caught
function MOVES.SpineLash(fight, target)
	local move = fight.boss.moves.SpineLash
	local root = fight.humanoid.RootPart
	local direction = flatUnit(target.root.Position - root.Position, root.CFrame.LookVector)
	face(fight, target.root.Position)
	mark("line", CFrame.lookAt(ground(root.Position), ground(root.Position) + direction), Vector3.new(move.width * 2, 0, move.length), move.windUp, color(fight))
	skillEffects:FireAllClients("Telegraph", fight.model, "heavy", move.windUp)
	task.wait(move.windUp)
	if not alive(fight) then
		return
	end
	root = fight.humanoid.RootPart
	local from = root.Position
	local victim, nearest
	local now = workspace:GetServerTimeNow()
	for _, candidate in ipairs(playersIn(from, move.length)) do
		local offset = candidate.root.Position - from
		local along = offset:Dot(direction)
		local aside = flat(offset - direction * along).Magnitude
		if along > 0 and aside <= move.width and (not nearest or along < nearest) and not candidate.character:GetAttribute("Invulnerable") then
			if CombatFeel.InDodge(candidate.character:GetAttribute("DodgeUntil"), now) then
				skillEffects:FireAllClients("Dodge", candidate.character)
			else
				victim, nearest = candidate, along
			end
		end
	end
	local reach = nearest or move.length
	local extendTime = reach / move.extendSpeed
	skillEffects:FireAllClients("SpineLash", fight.model, from, from + direction * reach, extendTime, 0.3, color(fight))
	task.wait(extendTime)
	if victim and alive(fight) and stillThere(victim) then
		grab(fight, victim, move)
	else
		task.wait(0.3)
	end
end

-- tornadoes fan out along the ground; he's free again once they're off
function MOVES.Tornado(fight, target)
	local move = fight.boss.moves.Tornado
	local root = fight.humanoid.RootPart
	local direction = flatUnit(target.root.Position - root.Position, root.CFrame.LookVector)
	face(fight, target.root.Position)
	local from = ground(root.Position)
	local directions = {}
	for i = 1, move.count do
		local angle = (i - (move.count + 1) / 2) * move.spread
		directions[i] = rotated(direction, angle)
		mark("line", CFrame.lookAt(from, from + directions[i]), Vector3.new(move.radius * 2, 0, move.length), move.windUp, color(fight))
	end
	task.wait(move.windUp)
	if not alive(fight) then
		return
	end
	-- Mandela's own tornadoes (TornadoEffect draws them along the same wobbling path)
	local duration = move.length / move.speed
	local overcharged = fight.boss.phases[fight.phase].overcharged
	local template = mandela:WaitForChild("Tornado")
	for _, each in ipairs(directions) do
		local tornado = template:Clone()
		local templateScale = tornado:GetScale()
		tornado:SetAttribute("StartedAt", workspace:GetServerTimeNow())
		tornado:SetAttribute("Duration", duration)
		tornado:SetAttribute("GrowTime", TORNADO_GROW_TIME)
		tornado:SetAttribute("StartPosition", from)
		tornado:SetAttribute("Direction", each)
		tornado:SetAttribute("Speed", move.speed)
		tornado:SetAttribute("WobbleAmplitude", TORNADO_WOBBLE)
		tornado:SetAttribute("WobbleFrequency", TORNADO_WOBBLE_FREQUENCY)
		tornado:SetAttribute("TemplateScale", templateScale)
		tornado:SetAttribute("FullScale", templateScale * TORNADO_SIZE)
		if overcharged then
			local tint = RaidConfig.Color(fight.boss.overchargeColor)
			tornado:SetAttribute("Tint", tint)
			for _, part in ipairs(tornado:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Color = part.Color:Lerp(tint, 0.35)
				end
			end
		end
		tornado:ScaleTo(templateScale * TORNADO_SIZE * 0.05)
		tornado:PivotTo(CFrame.new(from))
		tornado.Parent = workspace
		task.delay(duration + TORNADO_CLEANUP, function()
			tornado:Destroy()
		end)
	end
	task.spawn(function()
		local lastHit = {} -- humanoid -> os.clock()
		local started = os.clock()
		while os.clock() - started < duration and alive(fight) do
			local now = os.clock()
			local t = now - started
			for _, each in ipairs(directions) do
				local side = Vector3.new(each.Z, 0, -each.X)
				local position = from + each * move.speed * t + side * math.sin(t * TORNADO_WOBBLE_FREQUENCY) * TORNADO_WOBBLE
				for _, victim in ipairs(playersIn(position, move.radius, true)) do
					if now - (lastHit[victim.humanoid] or 0) >= move.tick then
						lastHit[victim.humanoid] = now
						hurt(fight, victim.humanoid, move.damage)
					end
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- Backbone Power: a blast around him as he overcharges
function MOVES.Roar(fight)
	local move = fight.boss.moves.Roar
	local center = ground(fight.humanoid.RootPart.Position)
	skillEffects:FireAllClients("Overcharge", fight.model, color(fight))
	skillEffects:FireAllClients("Telegraph", fight.model, "heavy", move.windUp)
	mark("circle", CFrame.new(center), move.radius, move.windUp, color(fight))
	task.wait(move.windUp)
	if not alive(fight) then
		return
	end
	for _, victim in ipairs(playersIn(center, move.radius, true)) do
		hurt(fight, victim.humanoid, move.damage)
		fling(victim, center)
	end
	skillEffects:FireAllClients("Shockwave", center, move.radius, color(fight))
end

-- the dome of mirror glass (Mandela's ultimate): everyone has `windUp` seconds
-- to break his shield, in `shieldParts` parts that stay broken (RaidConfig); hits
-- on it crack the glass and leave reflections of him. All parts broken, it
-- shatters and he reels; some, it shatters harmlessly; none, it rewrites
-- everyone inside.
function MOVES.Possibility(fight)
	local move = fight.boss.moves.Possibility
	fight.model:PivotTo(fight.home + fight.stand)
	local center = ground(fight.home.Position)
	local shield = RaidConfig.ShieldHealth(fight.boss, #playersIn(fight.home.Position, fight.boss.arenaRadius, true))
	fight.shield = shield
	fight.model:SetAttribute("ShieldMax", shield)
	fight.model:SetAttribute("Shield", shield)
	domeCount += 1
	local castId = "Raid" .. domeCount
	fight.dome = { castId = castId, ghosts = 0 }
	local frames, sizes = PlaceWhereDreamEnds.DomePanes(center, move.radius)
	skillEffects:FireAllClients("Rewrite", castId, fight.model, center, move.radius, move.windUp, frames, sizes, color(fight))
	remote:FireAllClients("Dome", center, move.radius, move.windUp, color(fight))
	local parts = move.shieldParts
	fight.model:SetAttribute("ShieldParts", parts)
	local broken = 0
	local endsAt = os.clock() + move.windUp
	while os.clock() < endsAt and broken < parts and alive(fight) do
		task.wait(0.1)
		local now = RaidConfig.PartsBroken(fight.shield, shield, parts)
		if now > broken then
			broken = now
			remote:FireAllClients("ShieldPart", broken, parts)
			skillEffects:FireAllClients("PoiseBreak", fight.model)
		end
	end
	local outcome = RaidConfig.DomeOutcome(broken, parts)
	fight.shield = nil
	fight.dome = nil
	fight.model:SetAttribute("Shield", nil)
	fight.model:SetAttribute("ShieldMax", nil)
	fight.model:SetAttribute("ShieldParts", nil)
	remote:FireAllClients("DomeEnd", outcome, broken, parts)
	if not alive(fight) or outcome ~= "struck" then
		-- the glass shatters on nobody
		skillEffects:FireAllClients("RewriteSnap", castId, center, move.radius, {}, {}, color(fight))
		if alive(fight) and outcome == "shattered" then
			fight.staggerUntil = os.clock() + move.stagger
			fight.model:SetAttribute("StaggeredUntil", workspace:GetServerTimeNow() + move.stagger)
			skillEffects:FireAllClients("PoiseBreak", fight.model)
		end
		return
	end
	local positions, struck = {}, {}
	for _, victim in ipairs(playersIn(center, move.radius, true)) do
		Damage.Deal(nil, victim.humanoid, victim.humanoid.MaxHealth * move.failShare, { unavoidable = true, guard = "unblockable", critical = true })
		table.insert(positions, victim.root.Position)
		table.insert(struck, victim.character)
	end
	skillEffects:FireAllClients("RewriteSnap", castId, center, move.radius, positions, struck, color(fight))
	local humanoid = fight.humanoid
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * move.heal)
end

local function cast(fight, name, target)
	fight.busy = true
	local move = fight.boss.moves[name]
	if move.cooldown then
		fight.readyAt[name] = RaidConfig.ReadyAt(fight.boss, fight.phase, name, os.clock())
	end
	fight.humanoid:MoveTo(fight.humanoid.RootPart.Position)
	task.spawn(function()
		local ok, err = pcall(MOVES[name], fight, target)
		if not ok then
			warn("[RaidBoss] " .. name .. ": " .. tostring(err))
		end
		fight.busy = false
	end)
end

-- the Mandela wearables on his body: the OverchargeOnly ones only while
-- overcharged, when the TintWhenOvercharged ones turn red
local function dress(fight, overcharged)
	local pieces = mandela:FindFirstChild("Wearables")
	if not pieces then
		return
	end
	local folder = fight.model:FindFirstChild(WEARABLES_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = WEARABLES_FOLDER
		folder:SetAttribute("SkillSet", "Mandela")
		folder.Parent = fight.model
	end
	local red = RaidConfig.Color(fight.boss.overchargeColor)
	for _, piece in ipairs(pieces:GetChildren()) do
		local primary = piece:IsA("Model") and piece.PrimaryPart or piece
		local wanted = overcharged or not (piece:GetAttribute("OverchargeOnly") or primary:GetAttribute("OverchargeOnly"))
		local worn = folder:FindFirstChild(piece.Name)
		if wanted and not worn and primary then
			local partName, extra = primary:GetAttribute("AttachTo"), CFrame.identity
			if not fight.model:FindFirstChild(partName) and R6_PARTS[partName] then
				partName, extra = R6_PARTS[partName][1], R6_PARTS[partName][2]
			end
			local bodyPart = fight.model:FindFirstChild(partName)
			if bodyPart then
				local anchorName = primary:GetAttribute("AttachAttachment")
				local anchor = anchorName and bodyPart:FindFirstChild(anchorName)
				worn = piece:Clone()
				for _, part in ipairs(worn:IsA("Model") and worn:GetDescendants() or { worn, table.unpack(worn:GetDescendants()) }) do
					if part:IsA("BasePart") then
						part.Anchored = false
						part.CanCollide = false
						part.Massless = true
					end
				end
				local weld = Instance.new("Weld")
				weld.Part0 = bodyPart
				weld.Part1 = worn:IsA("Model") and worn.PrimaryPart or worn
				weld.C0 = extra * (anchor and anchor.CFrame or CFrame.identity) * primary:GetAttribute("AttachOffset")
				weld.Parent = weld.Part1
				worn.Parent = folder
			end
		elseif worn and not wanted then
			worn:Destroy()
			worn = nil
		end
		if worn and primary:GetAttribute("TintWhenOvercharged") then
			for _, part in ipairs(worn:IsA("Model") and worn:GetDescendants() or { worn, table.unpack(worn:GetDescendants()) }) do
				if part:IsA("BasePart") then
					local base = part:GetAttribute("BaseColor") or part.Color
					part:SetAttribute("BaseColor", base)
					part.Color = overcharged and base:Lerp(red, TINT_AMOUNT) or base
				end
			end
		end
	end
end

local function setPhase(fight, index)
	local phase = fight.boss.phases[index]
	fight.phase = index
	fight.model:SetAttribute("Phase", index)
	fight.model:SetAttribute("Overcharged", phase.overcharged == true)
	fight.humanoid.WalkSpeed = fight.boss.walkSpeed * phase.speedScale
	dress(fight, phase.overcharged == true)
end

-- nobody's left in the arena: back to full and the first phase
local function reset(fight)
	setPhase(fight, 1)
	fight.readyAt = {}
	fight.damageBy = {}
	fight.humanoid.Health = fight.humanoid.MaxHealth
	fight.model:PivotTo(fight.home + fight.stand)
end

local function finish(fight)
	fight.ended = true
	if live[fight.key] == fight then
		live[fight.key] = nil
	end
	Damage.SetAbsorber(fight.humanoid, nil)
end

local function pay(fight)
	local boss = fight.boss
	local ranking = {}
	for player, damage in pairs(fight.damageBy) do
		if player.Parent then
			table.insert(ranking, { player = player, damage = damage })
		end
	end
	table.sort(ranking, function(a, b)
		return a.damage > b.damage
	end)
	local top = {}
	for _, entry in ipairs(ranking) do
		if RaidConfig.IsHelper(boss, entry.damage, fight.humanoid.MaxHealth) then
			local source = PlayerStats.Source(boss.name, "Dark")
			PlayerStats.AddXP(entry.player, boss.xp, source)
			PlayerStats.AddYen(entry.player, boss.yen, source)
		end
		if #top < 3 then
			table.insert(top, { name = entry.player.DisplayName, damage = math.floor(entry.damage) })
		end
	end
	return top
end

local function run(fight)
	local boss = fight.boss
	local humanoid = fight.humanoid
	while alive(fight) do
		task.wait(TICK)
		if not alive(fight) then
			break
		end
		local root = humanoid.RootPart
		local now = os.clock()
		if now - fight.spawnedAt > boss.lifetime then
			remote:FireAllClients("Left", fight.key)
			finish(fight)
			fight.model:Destroy()
			break
		end
		local present = playersIn(fight.home.Position, boss.arenaRadius, true)
		if #present == 0 then
			fight.emptySince = fight.emptySince or now
			if now - fight.emptySince > boss.resetAfter and humanoid.Health < humanoid.MaxHealth and not fight.busy then
				reset(fight)
			end
			if not fight.busy then
				humanoid:MoveTo(fight.home.Position)
			end
		else
			fight.emptySince = nil
			-- phases only go forward (a reset starts them over)
			local phase = RaidConfig.Phase(boss, humanoid.Health / humanoid.MaxHealth)
			if phase > fight.phase and not fight.busy and not fight.grabbed then
				setPhase(fight, phase)
				remote:FireAllClients("Phase", fight.key, phase)
				local opener = boss.phases[phase].opener
				if opener then
					cast(fight, opener, nil)
				end
			end
			if now < fight.staggerUntil then
				humanoid:MoveTo(root.Position)
			elseif not fight.busy then
				-- the nearest player, kept a few seconds
				if not stillThere(fight.target) or now >= fight.retargetAt or flat(fight.target.root.Position - fight.home.Position).Magnitude > boss.arenaRadius then
					local best, bestDistance
					for _, candidate in ipairs(present) do
						local distance = (candidate.root.Position - root.Position).Magnitude
						if not bestDistance or distance < bestDistance then
							best, bestDistance = candidate, distance
						end
					end
					fight.target = best
					fight.retargetAt = now + RETARGET
				end
				local target = fight.target
				local distance = (target.root.Position - root.Position).Magnitude
				local name = RaidConfig.PickMove(boss, fight.phase, distance, fight.readyAt, now, math.random)
				if name then
					cast(fight, name, target)
				else
					humanoid:MoveTo(target.root.Position)
				end
			end
		end
		-- the walk plays at however fast it's actually moving
		local speed = flat(root.AssemblyLinearVelocity).Magnitude
		if speed > 1 then
			if not fight.walkTrack.IsPlaying then
				fight.walkTrack:Play(0.2)
			end
			fight.walkTrack:AdjustSpeed(speed / 16)
		elseif fight.walkTrack.IsPlaying then
			fight.walkTrack:Stop(0.2)
		end
	end
end

-- his model from ServerStorage.Bosses, or an R6 stand-in in his colours
local function buildModel(key, boss)
	local folder = ServerStorage:FindFirstChild(BOSS_FOLDER)
	local template = folder and folder:FindFirstChild(key)
	if template then
		return template:Clone()
	end
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(234, 184, 146)
	local dark = Color3.fromRGB(28, 32, 30)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = dark
	description.LeftLegColor = dark
	description.RightLegColor = dark
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = RaidConfig.Color(boss.color)
	outline.Parent = model
	return model
end

local function loadAnimation(model, animator, childName, default)
	local animate = model:FindFirstChild("Animate")
	local holder = animate and animate:FindFirstChild(childName)
	local source = holder and holder:FindFirstChildOfClass("Animation")
	local animation = Instance.new("Animation")
	animation.AnimationId = source and source.AnimationId ~= "" and source.AnimationId or default
	return animator:LoadAnimation(animation)
end

function RaidBoss.IsUp(key)
	return live[key] ~= nil
end

-- puts the boss at `cframe` (its arena's middle); false and why if it can't
function RaidBoss.Spawn(key, cframe)
	local boss = RaidConfig.Get(key)
	if not boss then
		return false, "No such boss"
	end
	if live[key] then
		return false, boss.name .. " is already out"
	end
	local model = buildModel(key, boss)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		model:Destroy()
		return false, "His model has no Humanoid"
	end
	model.Name = boss.name
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	model.PrimaryPart = humanoid.RootPart
	-- the floor under the spot, and how high its root stands over a floor
	local home = CFrame.new(ground(cframe.Position))
	local stand = Vector3.new(0, humanoid.RigType == Enum.HumanoidRigType.R6 and 3 or humanoid.HipHeight + humanoid.RootPart.Size.Y / 2, 0)
	local maxHealth = RaidConfig.MaxHealth(boss, #playersIn(home.Position, boss.arenaRadius, true))
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = boss.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- RaidClient's bar instead
	model:SetAttribute("Level", boss.level)
	model:SetAttribute("EnemyType", key)
	model:SetAttribute("BossKey", key)
	model:SetAttribute("XPReward", 0)
	model:SetAttribute("YenReward", 0)
	model:SetAttribute("Rarity", "Dark")
	model:PivotTo(home + stand)
	-- RaidBoss before Enemy, so EnemyAI never picks it up
	CollectionService:AddTag(model, RaidConfig.Tag)
	model.Parent = workspace
	CollectionService:AddTag(model, "Enemy")
	pcall(humanoid.RootPart.SetNetworkOwner, humanoid.RootPart, nil)

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local walkTrack = loadAnimation(model, animator, "walk", WALK_ANIMATION)
	walkTrack.Looped = true
	walkTrack.Priority = Enum.AnimationPriority.Movement
	local slashTrack = loadAnimation(model, animator, "toolslash", SLASH_ANIMATION)
	slashTrack.Priority = Enum.AnimationPriority.Action

	local fight = {
		key = key,
		boss = boss,
		model = model,
		humanoid = humanoid,
		home = home,
		stand = stand, -- root above the floor
		phase = 1,
		readyAt = {},
		busy = false,
		staggerUntil = 0,
		retargetAt = 0,
		damageBy = {}, -- player -> damage, for the rewards
		misrememberedAt = 0, -- os.clock() its next erase is ready
		spawnedAt = os.clock(),
		walkTrack = walkTrack,
		slashTrack = slashTrack,
	}
	live[key] = fight
	setPhase(fight, 1)

	Damage.SetAbsorber(humanoid, function(amount, attacker, options)
		if attacker then
			fight.damageBy[attacker] = (fight.damageBy[attacker] or 0) + amount
			-- allies hitting him free whoever he's holding
			if fight.grabbed and fight.grabbed.player ~= attacker then
				fight.grabbed.rescue += amount
			end
		end
		if fight.shield then
			fight.shield = math.max(fight.shield - amount, 0)
			model:SetAttribute("Shield", fight.shield)
			-- the glass keeps a few reflections of him and cracks
			local dome = fight.dome
			if dome and dome.ghosts < DOME_GHOSTS and not options.dot then
				dome.ghosts += 1
				skillEffects:FireAllClients("RewriteHit", dome.castId, model, color(fight))
			end
			return 0
		end
		-- Misremembered: the next hit never happened
		if not options.dot and os.clock() >= fight.misrememberedAt then
			fight.misrememberedAt = os.clock() + boss.misremembered.cooldown
			skillEffects:FireAllClients("Misremember", model, color(fight))
			return 0
		end
		return amount
	end)

	humanoid.Died:Once(function()
		local grabbed = fight.grabbed
		finish(fight)
		if grabbed and grabbed.player.Character then
			local root = grabbed.player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = false
			end
			grabbed.player.Character:SetAttribute("HitstunUntil", nil)
			remote:FireClient(grabbed.player, "QteEnd", true)
		end
		remote:FireAllClients("Defeated", key, pay(fight))
		Debris:AddItem(model, CORPSE_TIME)
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			finish(fight)
		end
	end)

	remote:FireAllClients("Spawned", key)
	task.spawn(function()
		local ok, err = pcall(run, fight)
		if not ok then
			warn("[RaidBoss] " .. key .. ": " .. tostring(err))
		end
	end)
	return true, boss.name .. " is out"
end

-- takes the boss away without a fight's end (the admin panel)
function RaidBoss.Remove(key)
	local fight = live[key]
	if not fight then
		return false, "He isn't out"
	end
	finish(fight)
	fight.model:Destroy()
	remote:FireAllClients("Left", key)
	return true, fight.boss.name .. " removed"
end

-- a QTE key from the grabbed player
remote.OnServerEvent:Connect(function(player, kind, key)
	if kind ~= "Qte" or typeof(key) ~= "string" then
		return
	end
	for _, fight in pairs(live) do
		local held = fight.grabbed
		if held and held.player == player and not held.done and os.clock() - held.lastPress >= QTE_PRESS_SPACING then
			held.lastPress = os.clock()
			held.progress, held.done = RaidConfig.QtePress(held.keys, held.progress, key)
			remote:FireClient(player, "QteProgress", held.progress)
		end
	end
end)

return RaidBoss
