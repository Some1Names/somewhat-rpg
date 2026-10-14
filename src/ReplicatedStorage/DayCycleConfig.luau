-- The daylight cycle (ServerScriptService.DayClock and the DayCycleClient
-- script): the numbers and the pure rules, kept free of Roblox types so Lune
-- can test them (tests/DayCycleConfig.spec.luau).
-- The server keeps a time anchor (the hour at one moment of server time); the
-- hour now is worked out from it, so every client agrees. A full day is
-- DayLength real seconds. Keyframes are the lighting look at certain hours;
-- Sample blends the two around an hour. Property names are real Roblox
-- property names, colours are {r, g, b} in 0 to 255 (the client makes Color3s).
local MAX_HOUR_INPUT = 1e6 -- hours: bigger and the % 24 below loses its precision

local DayCycleConfig = {
	DayLength = 1200, -- real seconds for one 24 hour day
	StartHour = 7, -- the hour a new server starts at
	MoonShare = 0.25, -- of the sun's Luminance charge, under open sky at night
	-- the sky change when the phase changes (DayCycleClient): the screen fades to
	-- black over `out` seconds, the textures swap while it's dark for `hold`, then
	-- it fades back over `back`
	SkyFade = { out = 0.6, hold = 0.15, back = 0.9 },
	-- start (inclusive) and end (exclusive) hours; any other hour is Night
	Phases = {
		Dawn = { 5, 7 },
		Day = { 7, 17 },
		Dusk = { 17, 19 },
	},
	-- hours ascending, the first at 0. The 12 keyframe is the look the place had
	-- before the cycle; the rest are a first pass to tune in Studio.
	Keyframes = {
		{
			hour = 0,
			Lighting = { Brightness = 1.2, Ambient = { 70, 82, 135 }, OutdoorAmbient = { 75, 88, 145 }, ExposureCompensation = 0 },
			ColorCorrection = { TintColor = { 170, 190, 255 }, Brightness = 0, Saturation = 0 },
			Atmosphere = { Color = { 40, 60, 110 }, Decay = { 20, 30, 70 }, Density = 0.34, Haze = 0.5, Glare = 0 },
			Bloom = { Intensity = 1 },
			SunRays = { Intensity = 0 },
			Sky = { StarCount = 3000 },
		},
		{
			hour = 5,
			Lighting = { Brightness = 1.4, Ambient = { 78, 78, 132 }, OutdoorAmbient = { 72, 72, 112 }, ExposureCompensation = 0 },
			ColorCorrection = { TintColor = { 200, 200, 255 }, Brightness = 0, Saturation = 0.1 },
			Atmosphere = { Color = { 120, 120, 170 }, Decay = { 110, 100, 150 }, Density = 0.34, Haze = 0.7, Glare = 0.2 },
			Bloom = { Intensity = 1 },
			SunRays = { Intensity = 0.05 },
			Sky = { StarCount = 1500 },
		},
		{
			hour = 7,
			Lighting = { Brightness = 2.5, Ambient = { 80, 75, 150 }, OutdoorAmbient = { 70, 65, 90 }, ExposureCompensation = 0 },
			ColorCorrection = { TintColor = { 255, 215, 185 }, Brightness = 0, Saturation = 0.2 },
			Atmosphere = { Color = { 235, 185, 140 }, Decay = { 200, 140, 110 }, Density = 0.34, Haze = 0.8, Glare = 0.9 },
			Bloom = { Intensity = 1 },
			SunRays = { Intensity = 0.3 },
			Sky = { StarCount = 0 },
		},
		{
			hour = 12,
			Lighting = { Brightness = 3, Ambient = { 88, 82, 176 }, OutdoorAmbient = { 70, 70, 70 }, ExposureCompensation = 0 },
			ColorCorrection = { TintColor = { 242, 245, 255 }, Brightness = 0, Saturation = 0.25 },
			Atmosphere = { Color = { 95, 249, 203 }, Decay = { 143, 155, 222 }, Density = 0.34, Haze = 0.75, Glare = 0.75 },
			Bloom = { Intensity = 1 },
			SunRays = { Intensity = 0.15 },
			Sky = { StarCount = 0 },
		},
		{
			hour = 17,
			Lighting = { Brightness = 2.5, Ambient = { 90, 75, 140 }, OutdoorAmbient = { 75, 65, 85 }, ExposureCompensation = 0 },
			ColorCorrection = { TintColor = { 255, 205, 170 }, Brightness = 0, Saturation = 0.2 },
			Atmosphere = { Color = { 240, 170, 120 }, Decay = { 210, 120, 90 }, Density = 0.34, Haze = 0.8, Glare = 0.9 },
			Bloom = { Intensity = 1 },
			SunRays = { Intensity = 0.3 },
			Sky = { StarCount = 0 },
		},
		{
			hour = 19,
			Lighting = { Brightness = 1.4, Ambient = { 76, 64, 120 }, OutdoorAmbient = { 70, 62, 102 }, ExposureCompensation = 0 },
			ColorCorrection = { TintColor = { 230, 190, 220 }, Brightness = 0, Saturation = 0.1 },
			Atmosphere = { Color = { 110, 90, 140 }, Decay = { 90, 70, 120 }, Density = 0.34, Haze = 0.7, Glare = 0.2 },
			Bloom = { Intensity = 1 },
			SunRays = { Intensity = 0.05 },
			Sky = { StarCount = 1500 },
		},
		{
			hour = 21,
			Lighting = { Brightness = 1.2, Ambient = { 65, 76, 128 }, OutdoorAmbient = { 70, 82, 138 }, ExposureCompensation = 0 },
			ColorCorrection = { TintColor = { 180, 195, 255 }, Brightness = 0, Saturation = 0 },
			Atmosphere = { Color = { 50, 65, 115 }, Decay = { 30, 40, 80 }, Density = 0.34, Haze = 0.55, Glare = 0 },
			Bloom = { Intensity = 1 },
			SunRays = { Intensity = 0 },
			Sky = { StarCount = 3000 },
		},
	},
}

-- the hour of day (0 up to 24) given the anchor: the hour at `anchorServerTime`.
-- A frozen clock stays at the anchor's hour.
function DayCycleConfig.HourAt(anchorHour, anchorServerTime, now, frozen)
	if frozen then
		return anchorHour % 24
	end
	return (anchorHour + (now - anchorServerTime) * 24 / DayCycleConfig.DayLength) % 24
end

-- "Dawn", "Day", "Dusk" or "Night"
function DayCycleConfig.PhaseAt(hour)
	for name, range in pairs(DayCycleConfig.Phases) do
		if hour >= range[1] and hour < range[2] then
			return name
		end
	end
	return "Night"
end

-- an hour typed by an admin, wrapped into 0 up to 24; nil if it isn't a real
-- number, or so big that the wrapping would lose its precision
function DayCycleConfig.CleanHour(value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) > MAX_HOUR_INPUT then
		return nil
	end
	local hour = value % 24
	if hour >= 24 then
		hour = 0 -- a tiny negative rounds up to exactly 24
	end
	return hour
end

-- how dark the fade is (0 clear, 1 black) `elapsed` seconds after it started,
-- and whether it has finished. The textures swap when `elapsed` reaches `out`.
function DayCycleConfig.FadeAt(elapsed)
	local fade = DayCycleConfig.SkyFade
	if elapsed <= 0 then
		return 0, false
	elseif elapsed < fade.out then
		return elapsed / fade.out, false
	elseif elapsed < fade.out + fade.hold then
		return 1, false
	elseif elapsed < fade.out + fade.hold + fade.back then
		return 1 - (elapsed - fade.out - fade.hold) / fade.back, false
	end
	return 0, true
end

local function blend(from, to, t)
	if type(from) == "table" then
		local mixed = {}
		for i, channel in ipairs(from) do
			mixed[i] = channel + (to[i] - channel) * t
		end
		return mixed
	end
	return from + (to - from) * t
end

-- the lighting look at this hour: the two keyframes around it blended
-- (after the last one it blends back round to the first). Same shape as a
-- keyframe, without `hour`.
function DayCycleConfig.Sample(hour)
	local keyframes = DayCycleConfig.Keyframes
	hour = hour % 24
	local fromIndex = 1
	for i, keyframe in ipairs(keyframes) do
		if keyframe.hour <= hour then
			fromIndex = i
		end
	end
	local from = keyframes[fromIndex]
	local to = keyframes[fromIndex % #keyframes + 1]
	local span = (to.hour - from.hour) % 24
	local t = if span == 0 then 0 else (hour - from.hour) / span
	local result = {}
	for group, properties in pairs(from) do
		if group ~= "hour" then
			result[group] = {}
			for property, value in pairs(properties) do
				result[group][property] = blend(value, to[group][property], t)
			end
		end
	end
	return result
end

return DayCycleConfig
