-- Unit tests for ReplicatedStorage.DayCycleConfig's pure rules (the hour from
-- the server's time anchor, the phase, cleaning an admin's hour, and the
-- interpolated lighting look). Run with Lune, outside Roblox: tests/run.sh.
local DayCycleConfig = require("../src/ReplicatedStorage/DayCycleConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

-- the hour from the anchor
check("hour at the anchor", DayCycleConfig.HourAt(7, 100, 100, false) == 7)
check("a day is 1200s: 50s is one hour", DayCycleConfig.HourAt(7, 100, 150, false) == 8)
check("frozen ignores the time passed", DayCycleConfig.HourAt(7, 100, 150, true) == 7)
check("the hour wraps past midnight", DayCycleConfig.HourAt(23, 0, 100, false) == 1)
check("a clock slightly behind the anchor", near(DayCycleConfig.HourAt(7, 100, 90, false), 6.8))
check("an anchor of 24 is midnight", DayCycleConfig.HourAt(24, 0, 0, false) == 0)
check("a frozen anchor above 24 wraps", DayCycleConfig.HourAt(30, 0, 0, true) == 6)

-- phases: start inclusive, end exclusive
check("4.99 is Night", DayCycleConfig.PhaseAt(4.99) == "Night")
check("5 is Dawn", DayCycleConfig.PhaseAt(5) == "Dawn")
check("6.99 is Dawn", DayCycleConfig.PhaseAt(6.99) == "Dawn")
check("7 is Day", DayCycleConfig.PhaseAt(7) == "Day")
check("16.99 is Day", DayCycleConfig.PhaseAt(16.99) == "Day")
check("17 is Dusk", DayCycleConfig.PhaseAt(17) == "Dusk")
check("18.99 is Dusk", DayCycleConfig.PhaseAt(18.99) == "Dusk")
check("19 is Night", DayCycleConfig.PhaseAt(19) == "Night")
check("0 is Night", DayCycleConfig.PhaseAt(0) == "Night")
check("23.99 is Night", DayCycleConfig.PhaseAt(23.99) == "Night")

-- an admin's hour
check("6.5 stays 6.5", DayCycleConfig.CleanHour(6.5) == 6.5)
check("24 wraps to 0", DayCycleConfig.CleanHour(24) == 0)
check("30.5 wraps to 6.5", DayCycleConfig.CleanHour(30.5) == 6.5)
check("-1 wraps to 23", DayCycleConfig.CleanHour(-1) == 23)
check("NaN is refused", DayCycleConfig.CleanHour(0 / 0) == nil)
check("infinity is refused", DayCycleConfig.CleanHour(math.huge) == nil)
check("negative infinity is refused", DayCycleConfig.CleanHour(-math.huge) == nil)
check("a string is refused", DayCycleConfig.CleanHour("7") == nil)
check("nil is refused", DayCycleConfig.CleanHour(nil) == nil)
check("a table is refused", DayCycleConfig.CleanHour({}) == nil)
check("a boolean is refused", DayCycleConfig.CleanHour(true) == nil)
check("1e34 is refused", DayCycleConfig.CleanHour(1e34) == nil)
check("9e24 is refused", DayCycleConfig.CleanHour(9e24) == nil)
check("a million and one hours is refused", DayCycleConfig.CleanHour(1e6 + 1) == nil)
check("a million hours is fine", DayCycleConfig.CleanHour(1e6) == 1e6 % 24)
check("a tiny negative stays below 24", DayCycleConfig.CleanHour(-1e-20) < 24)

-- the keyframes themselves
local keyframes = DayCycleConfig.Keyframes
check("at least 6 keyframes", #keyframes >= 6)
check("the first keyframe is midnight", keyframes[1].hour == 0)
check("the last keyframe is before 24", keyframes[#keyframes].hour < 24)
local ascending, hasNoon = true, false
for i = 2, #keyframes do
	if keyframes[i].hour <= keyframes[i - 1].hour then
		ascending = false
	end
end
for _, keyframe in ipairs(keyframes) do
	hasNoon = hasNoon or keyframe.hour == 12
end
check("hours strictly ascend", ascending)
check("there is a noon keyframe", hasNoon)
local sameShape = true
for _, keyframe in ipairs(keyframes) do
	for group, properties in pairs(keyframes[1]) do
		if group ~= "hour" then
			for property in pairs(properties) do
				if keyframe[group] == nil or keyframe[group][property] == nil then
					sameShape = false
				end
			end
		end
	end
	for group, properties in pairs(keyframe) do
		if group ~= "hour" then
			for property in pairs(properties) do
				if keyframes[1][group] == nil or keyframes[1][group][property] == nil then
					sameShape = false
				end
			end
		end
	end
end
check("every keyframe has the same properties", sameShape)

-- sampling between them
local function at(hour)
	for _, keyframe in ipairs(keyframes) do
		if keyframe.hour == hour then
			return keyframe
		end
	end
end
local noon = DayCycleConfig.Sample(12)
check("noon keeps today's Brightness", noon.Lighting.Brightness == 3)
check("noon keeps today's Saturation", noon.ColorCorrection.Saturation == 0.25)
check("sampling a keyframe's hour gives its values", DayCycleConfig.Sample(0).Lighting.Brightness == at(0).Lighting.Brightness)
check("24 is the same as 0", DayCycleConfig.Sample(24).Lighting.Brightness == DayCycleConfig.Sample(0).Lighting.Brightness)

local a, b = at(5), at(7)
local mid = DayCycleConfig.Sample(6)
check("midway number is the mean", near(mid.Lighting.Brightness, (a.Lighting.Brightness + b.Lighting.Brightness) / 2))
local channelsMean = true
for i = 1, 3 do
	if not near(mid.Lighting.Ambient[i], (a.Lighting.Ambient[i] + b.Lighting.Ambient[i]) / 2) then
		channelsMean = false
	end
end
check("midway colour is the mean per channel", channelsMean)

local last, first = keyframes[#keyframes], keyframes[1]
local wrap = DayCycleConfig.Sample((last.hour + 24) / 2)
check("midway across midnight is the mean", near(wrap.Lighting.Brightness, (last.Lighting.Brightness + first.Lighting.Brightness) / 2))
check("-1 is the same as 23", near(DayCycleConfig.Sample(-1).Lighting.Brightness, DayCycleConfig.Sample(23).Lighting.Brightness))

if failures > 0 then
	error(failures .. " failed")
end
