-- Sound effects for weapons and powers: which clips exist (Sounds) and which
-- SkillEffects event plays which one (Effects). The clips come from the
-- Creator Store; the owner swaps a clip by changing its id here. The
-- SkillEffects/Sfx module plays them, 3D, where the effect happens. Pure rules
-- only, so Lune can test them (tests/SoundConfig.spec.luau).
--   id / ids   one clip, or a list to pick from at random each time
--   volume     0..1 (default 0.6)
--   pitch      random speed range, { low, high } (default 0.95 to 1.05)
--   range      studs it can be heard from (default 120)
--   loop       for sounds that last as long as a model does (Sfx.Attach)
local SoundConfig = {}

-- every clip's volume is multiplied by this (1 = as set below)
SoundConfig.MasterVolume = 0.5

SoundConfig.Sounds = {
	-- melee
	swing = { id = 87075337487332, volume = 0.5, pitch = { 0.9, 1.15 }, range = 70 },
	swingHeavy = { id = 87075337487332, volume = 0.65, pitch = { 0.7, 0.85 }, range = 80 },
	punchHit = { ids = { 74041775202019, 126976659766267 }, volume = 0.6, range = 90 },
	heavyHit = { ids = { 101232234433592, 79476956608476 }, volume = 0.75, range = 110 },
	-- the revolver
	revolver = { id = 120771468205926, volume = 0.55, pitch = { 0.95, 1.1 }, range = 160 },
	-- powers
	beam = { id = 92846408037360, volume = 0.6, range = 140 },
	beamSmall = { id = 118389711660079, volume = 0.45, pitch = { 0.9, 1.2 }, range = 110 },
	teleport = { ids = { 113381279319015, 113186934265156 }, volume = 0.6, range = 110 },
	presence = { ids = { 9118807638, 9118807475 }, volume = 0.55, range = 130 },
	holeLoop = { id = 9118807475, volume = 0.5, range = 140, loop = true },
	windLoop = { id = 130796038173607, volume = 0.55, range = 140, loop = true },
	glassShatter = { ids = { 139826391278483, 132349765576039 }, volume = 0.7, range = 150 },
	charge = { id = 72706642917206, volume = 0.65, range = 130 },
	shock = { id = 115006783735743, volume = 0.65, range = 150 },
}

-- Sounds that start with a model rather than an event: the model's
-- ClientEffect attribute (see SkillEffects) names the clip that loops on it.
SoundConfig.ModelLoops = {
	BlackHole = "holeLoop",
	Tornado = "windLoop",
}

local function crit(index, normal, heavy)
	return function(...)
		return (select(index, ...)) and heavy or normal
	end
end

-- SkillEffects event kind -> clip name, or a function of the event's
-- arguments that returns one (nil plays nothing)
SoundConfig.Effects = {
	-- melee: a swing from the server (character, armed), then what each hit lands as
	MeleeSwing = function(_, armed)
		return armed and "swingHeavy" or "swing"
	end,
	FistHit = crit(3, "punchHit", "heavyHit"),
	Slash = crit(3, "punchHit", "heavyHit"),
	PhotoshopPunchHit = crit(2, "punchHit", "heavyHit"),
	-- thrown and fired things: the revolver's bullet, Mandela's knife
	Projectile = function(_, model)
		if model == "Bullet" then
			return "revolver"
		elseif model == "Knife" then
			return "swing"
		end
		return nil
	end,
	-- Mandela
	AxeThrow = "swingHeavy",
	SpineLash = "swingHeavy",
	Overcharge = "charge",
	PossibilityWave = "shock",
	PossibilityErase = "glassShatter",
	Rewrite = "presence",
	RewriteSnap = "glassShatter",
	-- Iridescent Requiem
	PrismShot = "beam",
	LightShot = "beamSmall",
	Lightstep = "teleport",
	SolarLance = "beam",
	SunBurst = "beam",
	-- Photoshop
	StepIn = "teleport",
	PhotoPaste = "teleport",
	Undo = "teleport",
	GalleryTravel = "teleport",
	Desaturate = "presence",
	IrisBurst = "heavyHit",
	Kaleidoscope = "presence",
}

-- the clip name the event `kind` plays with these arguments, or nil
function SoundConfig.KeyFor(kind, ...)
	local entry = SoundConfig.Effects[kind]
	if type(entry) == "function" then
		return entry(...)
	end
	return entry
end

-- one clip id of `sound` (a SoundConfig.Sounds entry): its id, or a random one of its ids
function SoundConfig.PickId(sound, random)
	if sound.ids then
		return sound.ids[random(1, #sound.ids)]
	end
	return sound.id
end

return SoundConfig
