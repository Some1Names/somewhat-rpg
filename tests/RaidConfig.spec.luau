-- Unit tests for ReplicatedStorage.RaidConfig (boss health, phases, move
-- picks, the QTE). Run with Lune, outside Roblox: tests/run.sh.
local R = require("../src/ReplicatedStorage/RaidConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local seto = R.Get("HideSeto")
check("Hide Seto has an entry at level 90", type(seto) == "table" and seto.level == 90)
check("unknown and non-string keys have none", R.Get("Nope") == nil and R.Get(nil) == nil)

-- every move a phase names exists, and every move with a range has a weight
local named = true
for _, phase in ipairs(seto.phases) do
	for _, name in ipairs(phase.moves) do
		local move = seto.moves[name]
		if not move or not move.range or not move.weight then
			named = false
		end
	end
	if phase.opener and not seto.moves[phase.opener] then
		named = false
	end
end
check("every phase's moves and opener exist", named)

-- health
check("one player gets the base", R.MaxHealth(seto, 1) == 30000 and R.MaxHealth(seto, 0) == 30000)
check("each more player adds health", R.MaxHealth(seto, 3) == 30000 + 2 * 12000)
check("capped at maxScaledPlayers", R.MaxHealth(seto, 50) == R.MaxHealth(seto, 8))
check("shield scales the same way", R.ShieldHealth(seto, 1) == 6000 and R.ShieldHealth(seto, 2) == 9000)

-- shield parts
check("an untouched shield has no part broken", R.PartsBroken(6000, 6000, 3) == 0)
check("just short of a third is none", R.PartsBroken(4001, 6000, 3) == 0)
check("a third is one part", R.PartsBroken(4000, 6000, 3) == 1)
check("two thirds is two", R.PartsBroken(2000, 6000, 3) == 2)
check("gone is all three", R.PartsBroken(0, 6000, 3) == 3 and R.PartsBroken(-50, 6000, 3) == 3)
check("dome outcomes", R.DomeOutcome(0, 3) == "struck" and R.DomeOutcome(1, 3) == "spared" and R.DomeOutcome(2, 3) == "spared" and R.DomeOutcome(3, 3) == "shattered")
check("Hide Seto's shield has 3 parts", seto.moves.Possibility.shieldParts == 3)

-- phases
check("full health is phase 1", R.Phase(seto, 1) == 1 and R.Phase(seto, 0.61) == 1)
check("60% is phase 2", R.Phase(seto, 0.6) == 2 and R.Phase(seto, 0.26) == 2)
check("25% and under is phase 3", R.Phase(seto, 0.25) == 3 and R.Phase(seto, 0) == 3)

-- move picks
local function fixed(value)
	return function()
		return value
	end
end
check("in melee range the first ready move can be the combo", R.PickMove(seto, 1, 3, {}, 0, fixed(0)) == "Combo")
check("nothing in phase 1 reaches past 80 studs", R.PickMove(seto, 1, 85, {}, 0, fixed(0)) == nil)
check("far off: only the knives", R.PickMove(seto, 1, 70, {}, 0, fixed(0.99)) == "KnifeFan")
check("a move on cooldown isn't picked", R.PickMove(seto, 1, 70, { KnifeFan = 5 }, 0, fixed(0)) == nil)
check("ready again once its time comes", R.PickMove(seto, 1, 70, { KnifeFan = 5 }, 5, fixed(0)) == "KnifeFan")
check("the grab only from phase 2", R.PickMove(seto, 1, 50, { AxeBoomerang = 9, KnifeFan = 9, EventHorizon = 9 }, 0, fixed(0)) == nil)
check(
	"phase 2 can grab",
	R.PickMove(seto, 2, 50, { AxeBoomerang = 9, KnifeFan = 9, EventHorizon = 9, Tornado = 9 }, 0, fixed(0)) == "SpineLash"
)
check("cooldowns shrink in later phases", R.ReadyAt(seto, 1, "Tornado", 0) == 15 and R.ReadyAt(seto, 3, "Tornado", 0) == 9)

-- QTE
local rolls = { 1, 1, 2, 3, 3, 4 }
local i = 0
local sequence = R.QteSequence(4, function()
	i += 1
	return rolls[i]
end)
check("no key twice in a row", sequence[1] == "E" and sequence[2] == "R" and sequence[3] == "T" and sequence[4] == "F")
local progress, done = R.QtePress(sequence, 0, "E")
check("the right key moves on", progress == 1 and not done)
progress, done = R.QtePress(sequence, 1, "F")
check("a wrong key starts over", progress == 0 and not done)
progress, done = R.QtePress(sequence, 3, "F")
check("the last key completes it", progress == 4 and done)

-- helpers
check("a helper dealt helperShare", R.IsHelper(seto, 900, 30000) and not R.IsHelper(seto, 899, 30000))

-- Ayato Yoji
local ayato = R.Get("AyatoYoji")
check("Ayato has an entry at level 95", type(ayato) == "table" and ayato.level == 95 and ayato.arena == "AyatoSpawn")
local ayatoNamed = true
for _, phase in ipairs(ayato.phases) do
	for _, name in ipairs(phase.moves) do
		local move = ayato.moves[name]
		if not move or not move.range or not move.weight then
			ayatoNamed = false
		end
	end
	if phase.opener and not ayato.moves[phase.opener] then
		ayatoNamed = false
	end
end
check("every Ayato phase's moves and opener exist", ayatoNamed)
check("he flies", ayato.flight and ayato.flight.every > 0 and ayato.flight.height > 0)

-- ground and air
check("a move with no `where` is ground only", R.CastableHere({}, false) and not R.CastableHere({}, true))
check("an air move only in the air", R.CastableHere({ where = "air" }, true) and not R.CastableHere({ where = "air" }, false))
check("an any move both ways", R.CastableHere({ where = "any" }, true) and R.CastableHere({ where = "any" }, false))
check("flying, no combo", R.PickMove(ayato, 1, 3, { PrismShot = 9, LightVolley = 9, RefractionField = 9 }, 0, fixed(0), true) == nil)
check("flying, the volley", R.PickMove(ayato, 1, 50, { PrismShot = 9, RefractionField = 9 }, 0, fixed(0), true) == "LightVolley")
check("on the ground, no volley", R.PickMove(ayato, 1, 50, { PrismShot = 9, RefractionField = 9 }, 0, fixed(0), false) == nil)
check("Hide Seto casts nothing in the air", R.PickMove(seto, 3, 3, {}, 0, fixed(0), true) == nil)

-- safe domes
local spots = R.SafeDomeSpots(3, 25, 70, fixed(0))
check("three spots", #spots == 3)
check("each at the least distance with a 0 roll", math.abs(math.sqrt(spots[2][1] ^ 2 + spots[2][2] ^ 2) - 25) < 1e-6)
check("spread evenly", math.abs(math.atan2(spots[2][2], spots[2][1]) - 2 * math.pi / 3) < 1e-6)
check("inside a dome", R.InAnyDome(spots[1][1] + 8, spots[1][2], spots, 9))
check("outside them all", not R.InAnyDome(0, 0, spots, 9))

if failures > 0 then
	error(failures .. " failed")
end
