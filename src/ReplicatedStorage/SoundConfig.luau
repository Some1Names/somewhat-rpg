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
	-- a body dissolving
	deathFade = { id = 138498992667102, volume = 0.6, range = 90 },
	-- Photoshop's punches: the first hits of the combo, then the last
	photoshopMelee1 = { id = 110277370513474, volume = 0.6, range = 90 },
	photoshopMelee2 = { id = 71903225173502, volume = 0.6, range = 100 },
}

-- Plain 2D clips for the interface and the feel of the game (UiSfx.Play).
-- They are multiplied by MasterVolume too.
local function ui(id, volume)
	return { id = id, volume = volume or 0.6 }
end
SoundConfig.UI = {
	menuSelect = ui(113194405128446), -- a side bar entry of the hub, or a section picked inside a tab
	menuOpen = ui(132442985525251), -- the hub opening (once per opening, not per tab)
	statUp = ui(3428115723),
	equip = ui(79711108594022),
	unequip = ui(90465624010385),
	collectOrb = ui(93964427782359),
	rareDrop = ui(108443140007873),
	itemSelect = ui(542332175),
	purchaseFail = ui(18453214291),
	shopEnter = ui(131268007007000, 0.3),
	shopLeave = ui(134221055367800),
	crit = ui(367453005),
	denied = ui(137710618443593), -- a refused action or an error
	getYen = ui(94433663716765), -- a yen chest collected
	buy = ui(98648158271351), -- a purchase going through
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
	PhotoshopPunchHit = crit(2, "photoshopMelee1", "photoshopMelee2"),
	-- thrown and fired things: the revolver's bullet, Mandela's knife
	Projectile = function(_, model)
		if model == "Bullet" then
			return "revolver"
		elseif model == "Knife" then
			return "swing"
		end
		return nil
	end,
	DeathFade = "deathFade",
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

-- Background music (the Music client script): `menuTheme` loops on the title menu; while
-- fighting another player the `combat` tracks play in turn, back to back; otherwise `tracks`,
-- shuffled, with a quiet stretch between them. All through the Music volume setting. The ids
-- are Creator Store audio the owner picked.
--   volume  0..1 before the setting;  fade  seconds in and out;  combatFade  seconds the
--   music takes to fade out as combat cuts in;  gap  { min, max } seconds of quiet between
--   explore tracks (and after the menu theme or a fight)
SoundConfig.Music = {
	volume = 0.08, -- quiet: 100% on the Music setting is a soft background
	fade = 2,
	combatFade = 0.75,
	gap = { 25, 50 },
	menuTheme = { id = 119540755571209, name = "Menu theme" },
	tracks = {
		{ id = 80310690201416, name = "Track 1" },
		{ id = 72501922894463, name = "Track 2" },
		{ id = 78866602003326, name = "Track 3" },
	},
	combat = {
		{ id = 1836019934, name = "Combat 1" },
		{ id = 119869321896015, name = "Combat 2" },
		{ id = 140658568629873, name = "Combat 3" },
	},
	-- looping while you're near a raid boss (Music's "boss" mood, before combat)
	bossTheme = { id = 134787761105966, name = "Boss theme" },
}

-- Background ambience (Ambience), by area: ZoneConfig zones with `ambience = "nature"`
-- play nature, everywhere else plays city. A kind's tracks play in turn, back to back.
SoundConfig.Ambience = {
	volume = 0.25,
	fade = 2.5, -- seconds to cross-fade between areas
	city = {
		{ id = 9112757705, name = "City 1" },
		{ id = 9112757815, name = "City 2" },
	},
	nature = {
		{ id = 9112781689, name = "Nature" },
	},
}

-- one clip id of `sound` (a SoundConfig.Sounds entry): its id, or a random one of its ids
function SoundConfig.PickId(sound, random)
	if sound.ids then
		return sound.ids[random(1, #sound.ids)]
	end
	return sound.id
end

return SoundConfig
