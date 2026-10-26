-- Raid bosses: every number, and the pure rules (tests/RaidConfig.spec.luau).
-- ServerScriptService.RaidBoss runs the fight, RaidServer spawns them on a
-- timer, the client RaidClient draws the boss bar, the banners, the ground
-- warnings and the grab QTE.
-- A boss spawns at its arena (workspace.BossArenas.<key>, a part) every
-- `interval` seconds, announced `warning` seconds early to the whole server.
-- Its health grows with the players in the arena when it spawns. It fights in
-- phases (by health left): each phase adds moves and casts its moves faster,
-- and entering one plays its `opener`. With nobody in the arena for `resetAfter`
-- seconds it heals up and starts over; after `lifetime` seconds it leaves.
-- Every player who dealt `helperShare` of its max health gets the XP and yen,
-- and their own drops (Drops, through its EnemyConfig entry).
--
-- Moves: `range` is { min, max } studs to its target; `cooldown` seconds before
-- that move again; `weight` how often it's picked among the ready ones; `windUp`
-- seconds of warning; `damage` a multiplier of the boss's `damage`. A move's
-- other numbers are read by its code in RaidBoss.
local RaidConfig = {}

RaidConfig.Tag = "RaidBoss" -- on the boss model (it's also tagged "Enemy")
RaidConfig.ArenaFolder = "BossArenas" -- in workspace: a part per boss, named by its key
RaidConfig.RemoteName = "RaidEvent" -- in ReplicatedStorage, created by RaidBoss
RaidConfig.QteKeys = { "E", "R", "T", "F" }

RaidConfig.Bosses = {
	-- Hide Seto, the Mandela: his axe, knives, black hole, spine and tornadoes,
	-- then Backbone Power, then the dome of Overcome the Possibility
	HideSeto = {
		name = "Hide Seto",
		title = "THE MANDELA",
		level = 90,
		color = { 170, 255, 200 }, -- Mandela's green
		overchargeColor = { 255, 70, 80 }, -- Backbone Power's red
		interval = 1200, -- seconds between spawns
		firstSpawn = 300, -- seconds after the server starts
		warning = 60,
		lifetime = 900, -- seconds before he leaves, beaten or not
		arenaRadius = 110, -- studs around the arena he fights in
		resetAfter = 20,
		baseHealth = 30000,
		healthPerPlayer = 12000, -- for each player after the first
		maxScaledPlayers = 8,
		damage = 55, -- one plain hit
		walkSpeed = 20,
		helperShare = 0.03,
		xp = 6000,
		yen = 4000,
		-- every `cooldown` seconds the next hit on him is erased
		misremembered = { cooldown = 20 },
		phases = {
			{ name = "Mandela", from = 1, cooldownScale = 1, speedScale = 1, moves = { "Combo", "AxeBoomerang", "KnifeFan", "EventHorizon" } },
			{
				name = "Backbone Power",
				from = 0.6,
				cooldownScale = 0.75,
				speedScale = 1.2,
				overcharged = true,
				opener = "Roar",
				moves = { "Combo", "AxeBoomerang", "KnifeFan", "EventHorizon", "SpineLash", "Tornado" },
			},
			{
				name = "Overcome the Possibility",
				from = 0.25,
				cooldownScale = 0.6,
				speedScale = 1.3,
				overcharged = true,
				opener = "Possibility",
				moves = { "Combo", "AxeBoomerang", "KnifeFan", "EventHorizon", "SpineLash", "Tornado", "Possibility" },
			},
		},
		moves = {
			-- quick, quick, a lunging heavy (EnemyAttackConfig's swings)
			Combo = { range = { 0, 8 }, cooldown = 2.2, weight = 3, reach = 7, lunge = 8, steps = { "quick", "quick", "heavy" } },
			-- out along a line and back, hitting on each pass
			AxeBoomerang = { range = { 8, 45 }, cooldown = 7, weight = 3, windUp = 0.8, length = 45, radius = 4, outTime = 0.5, damage = 1.2 },
			KnifeFan = { range = { 12, 80 }, cooldown = 6, weight = 2, windUp = 0.5, count = 5, spread = 40, speed = 110, length = 90, radius = 1.5, damage = 0.6 },
			-- a black hole on the target: pulls and hurts, then bursts
			EventHorizon = { range = { 0, 60 }, cooldown = 14, weight = 2, windUp = 1.2, radius = 20, duration = 3, pullSpeed = 16, tick = 0.5, tickDamage = 0.25, damage = 1.6 },
			-- the grab: the first player along the line is caught and held for the QTE
			SpineLash = {
				range = { 6, 60 },
				cooldown = 16,
				weight = 2,
				windUp = 0.9,
				length = 60,
				width = 3,
				extendSpeed = 140,
				holdDistance = 5, -- studs in front of him
				keys = 4, -- keys in the QTE
				qteTime = 3, -- seconds to press them
				rescueShare = 0.03, -- of his max health: allies who deal this free the grabbed player
				failShare = 0.45, -- of the grabbed player's max health
				stagger = 3, -- seconds he reels when they break out
			},
			Tornado = { range = { 0, 70 }, cooldown = 15, weight = 2, windUp = 1, count = 3, spread = 35, length = 80, speed = 20, radius = 7, tick = 0.4, damage = 0.4 },
			-- Backbone Power's opener: a blast around him
			Roar = { windUp = 1, radius = 28, damage = 1 },
			-- his dome: break the shield before it closes, or everyone in it is struck
			Possibility = {
				range = { 0, 999 },
				cooldown = 60,
				weight = 1,
				windUp = 8,
				radius = 90,
				shieldBase = 6000,
				shieldPerPlayer = 3000,
				failShare = 0.8, -- of each player's max health
				heal = 0.1, -- share of his max health he gets back if it lands
				stagger = 5,
			},
		},
		dropTable = "HideSeto",
	},
}

function RaidConfig.Get(key)
	if typeof(key) ~= "string" then
		return nil
	end
	return RaidConfig.Bosses[key]
end

function RaidConfig.Color(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- his max health for `players` in the arena when he spawns (at least one)
function RaidConfig.MaxHealth(boss, players)
	local extra = math.clamp(math.floor(players or 1), 1, boss.maxScaledPlayers) - 1
	return boss.baseHealth + boss.healthPerPlayer * extra
end

-- the dome's shield for `players` fighting
function RaidConfig.ShieldHealth(boss, players)
	local move = boss.moves.Possibility
	local extra = math.clamp(math.floor(players or 1), 1, boss.maxScaledPlayers) - 1
	return move.shieldBase + move.shieldPerPlayer * extra
end

-- the phase index for a share of health left (0 to 1): the last phase whose
-- `from` it's at or under
function RaidConfig.Phase(boss, fraction)
	local index = 1
	for i, phase in ipairs(boss.phases) do
		if fraction <= phase.from then
			index = i
		end
	end
	return index
end

-- the move to cast now, or nil to keep walking at the target. `readyAt` is
-- move name -> the time it's ready; `random()` gives [0, 1).
function RaidConfig.PickMove(boss, phaseIndex, distance, readyAt, now, random)
	local phase = boss.phases[phaseIndex]
	local ready, total = {}, 0
	for _, name in ipairs(phase.moves) do
		local move = boss.moves[name]
		if distance >= move.range[1] and distance <= move.range[2] and now >= (readyAt[name] or 0) then
			table.insert(ready, name)
			total += move.weight
		end
	end
	if total == 0 then
		return nil
	end
	local left = random() * total
	for _, name in ipairs(ready) do
		left -= boss.moves[name].weight
		if left < 0 then
			return name
		end
	end
	return ready[#ready]
end

-- when a move cast at `now` is ready again in this phase
function RaidConfig.ReadyAt(boss, phaseIndex, name, now)
	return now + boss.moves[name].cooldown * boss.phases[phaseIndex].cooldownScale
end

-- `count` QTE keys; `random(n)` gives 1..n. No key twice in a row.
function RaidConfig.QteSequence(count, random)
	local keys = {}
	for i = 1, count do
		local key
		repeat
			key = RaidConfig.QteKeys[random(#RaidConfig.QteKeys)]
		until i == 1 or key ~= keys[i - 1]
		keys[i] = key
	end
	return keys
end

-- a key pressed `pressed` with `progress` keys of `sequence` done: the new
-- progress and whether the sequence is complete. A wrong key starts it over.
function RaidConfig.QtePress(sequence, progress, pressed)
	if sequence[progress + 1] == pressed then
		progress += 1
		return progress, progress >= #sequence
	end
	return 0, false
end

function RaidConfig.IsHelper(boss, damage, maxHealth)
	return maxHealth > 0 and damage >= maxHealth * boss.helperShare
end

return RaidConfig
