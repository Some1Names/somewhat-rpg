-- Ayato Yoji's raid moves (RaidConfig.Bosses.AyatoYoji), built from RaidBoss's
-- `kit` (its helpers: who's where, the floor, warnings, hits, flight). Each move
-- is called as move(fight, target) by RaidBoss, which picks and times them.
-- They use the Iridescent Requiem set's own visuals (SkillEffects: PrismShot,
-- LightShot, Lightstep, RefractionField/Beams, PrismBreak, SolarLanceWarning,
-- SolarLance, SolarPool, Sunmark, SkyVeil, SunBurst; Prism Form from the
-- model's PrismForm attribute). His Sunmark is his own here: Prism Shot and
-- Refraction Field mark who they hit for `sunmark` seconds, and Solar Lance
-- locks onto a marked player with little warning, then spends the mark.
-- The safe domes of his ultimate are RaidClient's ("SafeDomes"), placeholders
-- until the owner's VFX.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local RaidConfig = require(ReplicatedStorage:WaitForChild("RaidConfig"))

local BEAM_HEIGHT = 2 -- studs over the floor a beam is aimed at someone's middle from
local FIELD_HOVER = 4 -- studs over the floor the crystals float

return function(kit)
	local MOVES = {}
	local skillEffects, remote = kit.skillEffects, kit.remote
	local marks = setmetatable({}, { __mode = "k" }) -- humanoid -> os.clock() its Sunmark ends
	local idCount = 0

	local function nextId()
		idCount += 1
		return "Raid" .. idCount
	end

	local function hand(fight)
		local part = fight.model:FindFirstChild("Right Arm") or fight.model:FindFirstChild("RightHand") or fight.humanoid.RootPart
		return part.Position
	end

	local function sunmark(fight, victim)
		marks[victim.humanoid] = os.clock() + fight.boss.sunmark
		skillEffects:FireAllClients("Sunmark", victim.character, fight.boss.sunmark)
	end

	local function marked(victim)
		return (marks[victim.humanoid] or 0) > os.clock()
	end

	-- how far `point` is from the segment `from`..`to`
	local function fromSegment(point, from, to)
		local line = to - from
		local along = line.Magnitude > 0 and math.clamp((point - from):Dot(line) / line.Magnitude ^ 2, 0, 1) or 0
		return (point - (from + line * along)).Magnitude
	end

	-- where a beam from `from` along `direction` stops: the first solid thing
	-- that isn't a character, or its full `length`
	local function beamEnd(fight, from, direction, length)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { fight.model }
		for _, player in ipairs(Players:GetPlayers()) do
			table.insert(ignore, player.Character)
		end
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = true
		local hit = workspace:Raycast(from, direction * length, params)
		return hit and hit.Position or from + direction * length
	end

	-- a fan of beams from his hand at the target; each marks whoever it goes through
	function MOVES.PrismShot(fight, target)
		local move = fight.boss.moves.PrismShot
		local phase = fight.boss.phases[fight.phase]
		local count = phase.prismForm and move.formCount or move.count
		kit.face(fight, target.root.Position)
		local aimAt = target.root.Position
		local from = hand(fight)
		local flatAim = kit.flatUnit(aimAt - from, fight.humanoid.RootPart.CFrame.LookVector)
		local floor = kit.ground(fight.humanoid.RootPart.Position)
		for i = 1, count do
			local angle = (i - (count + 1) / 2) * move.spread / math.max(count - 1, 1)
			local along = kit.rotated(flatAim, angle)
			kit.mark("line", CFrame.lookAt(floor, floor + along), Vector3.new(move.width * 2, 0, move.length), move.windUp, kit.color(fight))
		end
		skillEffects:FireAllClients("Telegraph", fight.model, "quick", move.windUp)
		task.wait(move.windUp)
		if not kit.alive(fight) then
			return
		end
		from = hand(fight)
		-- tilted down from the air to the height they stood at
		local drop = (aimAt.Y - BEAM_HEIGHT) - from.Y
		local tips, struck = {}, {}
		for i = 1, count do
			local angle = (i - (count + 1) / 2) * move.spread / math.max(count - 1, 1)
			local along = kit.rotated(flatAim, angle)
			local reach = kit.flat(aimAt - from).Magnitude
			local direction = (along * math.max(reach, 1) + Vector3.new(0, math.min(drop, 0), 0)).Unit
			local tip = beamEnd(fight, from, direction, move.length)
			tips[i] = tip
			for _, victim in ipairs(kit.playersIn(from, move.length + 2)) do
				if not struck[victim.humanoid] and fromSegment(victim.root.Position, from, tip) <= move.width then
					struck[victim.humanoid] = true
					if kit.hurt(fight, victim.humanoid, move.damage) > 0 then
						sunmark(fight, victim)
					end
				end
			end
		end
		skillEffects:FireAllClients("PrismShot", from, tips)
		task.wait(0.2)
	end

	-- from the air: a few bolts, each at someone's spot, marked on the ground first
	function MOVES.LightVolley(fight)
		local move = fight.boss.moves.LightVolley
		local present = kit.playersIn(fight.home.Position, fight.boss.arenaRadius, true)
		for shot = 1, move.shots do
			if not kit.alive(fight) or #present == 0 then
				return
			end
			local victim = present[(shot - 1) % #present + 1]
			if kit.stillThere(victim) then
				local spot = kit.ground(victim.root.Position)
				kit.face(fight, spot)
				kit.mark("circle", CFrame.new(spot), move.radius, move.windUp, kit.color(fight))
				task.delay(move.windUp, function()
					if not kit.alive(fight) then
						return
					end
					local struck = false
					for _, other in ipairs(kit.playersIn(spot, move.radius, true)) do
						if math.abs(other.root.Position.Y - spot.Y) < 8 and kit.hurt(fight, other.humanoid, move.damage, { guard = "ranged" }) > 0 then
							struck = true
						end
					end
					skillEffects:FireAllClients("LightShot", hand(fight), spot + Vector3.new(0, 1, 0), struck)
				end)
			end
			task.wait(move.spacing)
		end
		task.wait(move.windUp)
	end

	-- a flash of light through the target and past them; the path burns a while
	function MOVES.Lightstep(fight, target)
		local move = fight.boss.moves.Lightstep
		local root = fight.humanoid.RootPart
		local direction = kit.flatUnit(target.root.Position - root.Position, root.CFrame.LookVector)
		local distance = kit.flat(target.root.Position - root.Position).Magnitude + move.past
		local from = root.Position
		local to = beamEnd(fight, from, direction, distance)
		to -= direction * 2 -- stops short of a wall
		kit.face(fight, to)
		kit.mark("line", CFrame.lookAt(kit.ground(from), kit.ground(from) + direction), Vector3.new(move.width * 2, 0, (to - from).Magnitude), move.windUp, kit.color(fight))
		task.wait(move.windUp)
		if not kit.alive(fight) then
			return
		end
		skillEffects:FireAllClients("Lightstep", fight.model, from, to, 0.12)
		fight.model:PivotTo(CFrame.lookAt(to, to + direction))
		for _, victim in ipairs(kit.playersIn(from, (to - from).Magnitude + move.width)) do
			if fromSegment(victim.root.Position, from, to) <= move.width then
				kit.hurt(fight, victim.humanoid, move.damage)
			end
		end
		-- the light lingers on the path
		task.spawn(function()
			local endsAt = os.clock() + move.trailTime
			while os.clock() < endsAt and kit.alive(fight) do
				task.wait(move.trailTick)
				for _, victim in ipairs(kit.playersIn(from, (to - from).Magnitude + move.width)) do
					if fromSegment(victim.root.Position, from, to) <= move.width * 0.75 then
						kit.hurt(fight, victim.humanoid, move.trailDamage)
					end
				end
			end
		end)
	end

	-- crystals on the target: a beam jumps through everyone near, nearest first
	function MOVES.RefractionField(fight, target)
		local move = fight.boss.moves.RefractionField
		local floor = kit.ground(target.root.Position)
		kit.face(fight, floor)
		kit.mark("circle", CFrame.new(floor), move.radius, move.windUp, kit.color(fight))
		task.wait(move.windUp)
		if not kit.alive(fight) then
			return
		end
		local center = floor + Vector3.new(0, FIELD_HOVER, 0)
		local id = nextId()
		local formScale = fight.boss.phases[fight.phase].prismForm and 1.4 or 1
		skillEffects:FireAllClients("RefractionField", id, center, move.radius, formScale, move.duration)
		-- he's free while it works
		task.spawn(function()
			local endsAt = os.clock() + move.duration
			while os.clock() < endsAt and kit.alive(fight) do
				local inReach = kit.playersIn(center, move.radius)
				table.sort(inReach, function(a, b)
					return (a.root.Position - center).Magnitude < (b.root.Position - center).Magnitude
				end)
				local chain = {}
				for i, victim in ipairs(inReach) do
					if i > move.maxChain then
						break
					end
					if kit.hurt(fight, victim.humanoid, move.damage) > 0 then
						sunmark(fight, victim)
					end
					table.insert(chain, victim.root.Position)
				end
				if #chain > 0 then
					skillEffects:FireAllClients("RefractionBeams", center, chain)
				end
				task.wait(move.interval)
			end
			skillEffects:FireAllClients("PrismBreak", center, kit.color(fight), id)
		end)
	end

	-- a column of sunlight: on someone carrying his Sunmark it locks on (short
	-- warning, follows them) and spends the mark; in Prism Form it leaves a burning pool
	function MOVES.SolarLance(fight, target)
		local move = fight.boss.moves.SolarLance
		local victim = target
		for _, other in ipairs(kit.playersIn(fight.home.Position, fight.boss.arenaRadius, true)) do
			if marked(other) then
				victim = other
				break
			end
		end
		local locked = marked(victim)
		local windUp = locked and move.lockedWindUp or move.windUp
		local point = kit.ground(victim.root.Position)
		kit.face(fight, point)
		skillEffects:FireAllClients("SolarLanceWarning", point, move.radius, windUp)
		kit.mark("circle", CFrame.new(point), move.radius, windUp, kit.color(fight))
		task.wait(windUp)
		if not kit.alive(fight) then
			return
		end
		if locked then
			marks[victim.humanoid] = nil
			if kit.stillThere(victim) then
				point = kit.ground(victim.root.Position)
			end
		end
		skillEffects:FireAllClients("SolarLance", point, move.radius, locked)
		for _, other in ipairs(kit.playersIn(point, move.radius, true)) do
			kit.hurt(fight, other.humanoid, move.damage)
		end
		if fight.boss.phases[fight.phase].prismForm then
			skillEffects:FireAllClients("SolarPool", point, move.radius, move.poolTime)
			task.spawn(function()
				local endsAt = os.clock() + move.poolTime
				while os.clock() < endsAt and kit.alive(fight) do
					task.wait(move.poolTick)
					for _, other in ipairs(kit.playersIn(point, move.radius, true)) do
						kit.hurt(fight, other.humanoid, move.poolDamage)
					end
				end
			end)
		end
	end

	-- Prism Form's opener: a burst of light around him as he turns to light
	function MOVES.PrismForm(fight)
		local move = fight.boss.moves.PrismForm
		local center = kit.ground(fight.humanoid.RootPart.Position)
		skillEffects:FireAllClients("Telegraph", fight.model, "heavy", move.windUp)
		kit.mark("circle", CFrame.new(center), move.radius, move.windUp, kit.color(fight))
		task.wait(move.windUp)
		if not kit.alive(fight) then
			return
		end
		for _, victim in ipairs(kit.playersIn(center, move.radius, true)) do
			kit.hurt(fight, victim.humanoid, move.damage)
			kit.fling(victim, center)
		end
		skillEffects:FireAllClients("Shockwave", center, move.radius, kit.color(fight))
	end

	-- Above the Cumulonimbus: he rises over the arena's middle into the storm,
	-- safe domes of light come up around it, and when the sun bursts out of him
	-- everyone outside them is struck
	function MOVES.Cumulonimbus(fight)
		local move = fight.boss.moves.Cumulonimbus
		local center = kit.ground(fight.home.Position)
		if fight.flying then
			kit.land(fight)
		end
		kit.takeOff(fight, move.height, fight.home.Position)
		fight.flightEndsAt = math.huge -- it comes down when this is over
		skillEffects:FireAllClients("SkyVeil", center + Vector3.new(0, 3, 0), move.height, fight.boss.arenaRadius, "cumulonimbus", move.windUp)
		local spots = RaidConfig.SafeDomeSpots(move.domes, move.domeMin, move.domeMax, math.random)
		local domes = {}
		for i, spot in ipairs(spots) do
			domes[i] = kit.ground(center + Vector3.new(spot[1], 0, spot[2]))
		end
		remote:FireAllClients("SafeDomes", domes, move.domeRadius, move.windUp)
		task.wait(move.windUp)
		if kit.alive(fight) then
			local struck = {}
			for _, victim in ipairs(kit.playersIn(fight.home.Position, fight.boss.arenaRadius + 20, true)) do
				local offset = victim.root.Position - center
				if not RaidConfig.InAnyDome(offset.X, offset.Z, spots, move.domeRadius) then
					Damage.Deal(nil, victim.humanoid, victim.humanoid.MaxHealth * move.burstShare, { unavoidable = true, guard = "unblockable", critical = true })
					table.insert(struck, victim.root.Position)
				end
			end
			skillEffects:FireAllClients("SunBurst", fight.humanoid.RootPart.Position, center, fight.boss.arenaRadius, struck, fight.model)
		end
		remote:FireAllClients("SafeDomesEnd")
		if kit.alive(fight) then
			task.wait(0.8)
			kit.land(fight)
		end
	end

	return MOVES
end
