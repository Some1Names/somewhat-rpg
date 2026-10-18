-- Unit tests for ReplicatedStorage.SoundConfig (which clip an effect plays, the
-- random pick, and that every name used is a clip that exists). Run with Lune,
-- outside Roblox: tests/run.sh.
local SoundConfig = require("../src/ReplicatedStorage/SoundConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- every clip has an id, or a list of them
local allHaveIds = true
for _, sound in pairs(SoundConfig.Sounds) do
	local plain = type(sound.id) == "number"
	local list = type(sound.ids) == "table" and #sound.ids > 0
	if not (plain or list) then
		allHaveIds = false
	end
end
check("every clip has an id or ids", allHaveIds)

-- every event and model loop names a clip that exists (functions are tried with each argument shape)
local namesExist = true
for kind, entry in pairs(SoundConfig.Effects) do
	if type(entry) == "string" and not SoundConfig.Sounds[entry] then
		namesExist = false
		print("  unknown clip for " .. kind .. ": " .. entry)
	end
end
for effect, key in pairs(SoundConfig.ModelLoops) do
	if not SoundConfig.Sounds[key] or not SoundConfig.Sounds[key].loop then
		namesExist = false
		print("  model loop " .. effect .. " needs a looping clip: " .. key)
	end
end
check("every event and model loop names a clip, loops loop", namesExist)

-- hits: a finisher is heavier
check("fist hit", SoundConfig.KeyFor("FistHit", "p", "d", false, "c") == "punchHit")
check("fist finisher", SoundConfig.KeyFor("FistHit", "p", "d", true, "c") == "heavyHit")
check("slash with no critical flag", SoundConfig.KeyFor("Slash", "p", "d", nil, "c") == "punchHit")
check("Photoshop punch finisher", SoundConfig.KeyFor("PhotoshopPunchHit", "p", true) == "photoshopMelee2")
check("Photoshop punch", SoundConfig.KeyFor("PhotoshopPunchHit", "p", false) == "photoshopMelee1")

-- swings: a weapon's is heavier than fists'
check("armed swing", SoundConfig.KeyFor("MeleeSwing", "character", true) == "swingHeavy")
check("fist swing", SoundConfig.KeyFor("MeleeSwing", "character", false) == "swing")

-- projectiles depend on what flies
check("bullet", SoundConfig.KeyFor("Projectile", 1, "Bullet") == "revolver")
check("knife", SoundConfig.KeyFor("Projectile", 1, "Knife") == "swing")
check("unknown projectile is silent", SoundConfig.KeyFor("Projectile", 1, "Orb") == nil)

-- plain events, and ones with no sound
check("Solar Lance", SoundConfig.KeyFor("SolarLance", "point") == "beam")
check("an event with no sound", SoundConfig.KeyFor("Framed", "model") == nil)

-- the random pick
check("one id", SoundConfig.PickId({ id = 7 }, function()
	return 1
end) == 7)
check("one of several, by the pick", SoundConfig.PickId({ ids = { 5, 6, 8 } }, function(low, high)
	return high
end) == 8)

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all SoundConfig checks passed")
