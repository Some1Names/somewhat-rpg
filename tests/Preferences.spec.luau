-- Unit tests for ReplicatedStorage.Preferences' pure logic (the saved
-- ON/OFF settings, sliders and choices). Run with Lune, outside Roblox: tests/run.sh.
local Preferences = require("../src/ReplicatedStorage/Preferences")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local function same(a, b)
	for k, v in pairs(a) do
		if b[k] ~= v then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local defaults = Preferences.Defaults()

check("defaults", defaults.QuickRespawn == false and defaults.CameraShake == true
	and defaults.Flashes == true and defaults.DamageNumbers == true and defaults.KeyHints == true)

check("key_hints_parse_serialize", Preferences.Parse("KeyHints=0").KeyHints == false
	and Preferences.Serialize(Preferences.Parse("KeyHints=0")) == "KeyHints=0"
	and Preferences.Serialize(Preferences.Parse("KeyHints=1")) == "")

check("parse_nil_is_defaults", same(Preferences.Parse(nil), defaults)
	and same(Preferences.Parse(""), defaults) and same(Preferences.Parse(5), defaults))

local parsed = Preferences.Parse("QuickRespawn=1,CameraShake=0")
check("parse_values", parsed.QuickRespawn == true and parsed.CameraShake == false and parsed.Flashes == true)

local bad = Preferences.Parse("CameraShake=2,Flashes=yes,Bogus=1")
check("parse_bad_values_ignored", bad.CameraShake == true and bad.Flashes == true and bad.Bogus == nil)

check("parse_too_long", same(Preferences.Parse(string.rep("Flashes=0,", 41)), defaults))

check("serialize", Preferences.Serialize(Preferences.Defaults()) == ""
	and Preferences.Serialize(Preferences.Parse("CameraShake=0,QuickRespawn=1")) == "QuickRespawn=1,CameraShake=0")

local missing = Preferences.Defaults()
missing.Flashes = nil
local wrongType = Preferences.Defaults()
wrongType.Flashes = "yes"
local extra = Preferences.Defaults()
extra.Bogus = true
check("valid", Preferences.Valid(Preferences.Defaults()) and not Preferences.Valid(missing)
	and not Preferences.Valid(wrongType) and not Preferences.Valid(extra))

check("options_order", Preferences.Options[1].id == "QuickRespawn" and Preferences.Options[1].section == "GAMEPLAY"
	and Preferences.Options[2].id == "Fov" and Preferences.Options[2].section == "GAMEPLAY"
	and Preferences.Options[5].id == "Vignette" and Preferences.Options[5].section == "EFFECTS"
	and Preferences.Options[9].id == "DamageNumbers" and Preferences.Options[9].section == "INTERFACE"
	and Preferences.Options[#Preferences.Options].section == "SOUND")

-- sliders
check("slider_defaults", defaults.HudSway == 100 and defaults.StatusSway == 100 and defaults.Vignette == 50)

local slid = Preferences.Parse("Vignette=30,HudSway=150")
check("slider_parse", slid.Vignette == 30 and slid.HudSway == 150 and slid.StatusSway == 100)

local offStep = Preferences.Parse("Vignette=35,HudSway=250,StatusSway=-10,Vignette=x")
check("slider_bad_values_ignored", offStep.Vignette == 50 and offStep.HudSway == 100 and offStep.StatusSway == 100)

check("slider_old_off_reads_zero", Preferences.Parse("HudSway=0").HudSway == 0
	and Preferences.Serialize(Preferences.Parse("HudSway=0")) == "HudSway=0")

check("slider_serialize", Preferences.Serialize(Preferences.Parse("HudSway=150,QuickRespawn=1")) == "QuickRespawn=1,HudSway=150"
	and Preferences.Serialize(Preferences.Parse("HudSway=100")) == "")

local badSlider = Preferences.Defaults()
badSlider.HudSway = 155
local boolSlider = Preferences.Defaults()
boolSlider.Vignette = true
check("slider_valid", not Preferences.Valid(badSlider) and not Preferences.Valid(boolSlider)
	and Preferences.Valid(Preferences.Parse("Vignette=0,HudSway=200")))

local sway = Preferences.Option("HudSway")
check("nudge", Preferences.Nudge(sway, 100, 1) == 110 and Preferences.Nudge(sway, 200, 1) == 200
	and Preferences.Nudge(sway, 0, -1) == 0 and Preferences.Nudge(Preferences.Option("KeyHints"), true, 1) == false)

check("slider_at", Preferences.SliderAt(sway, 0) == 0 and Preferences.SliderAt(sway, 1) == 200
	and Preferences.SliderAt(sway, 0.52) == 100 and Preferences.SliderAt(sway, 1.5) == 200)

-- choices
local crosshair = Preferences.Option("Xhair")
check("choice_parse", Preferences.Parse("Xhair=2").Xhair == 2 and Preferences.Parse("Xhair=9").Xhair == 1
	and Preferences.Parse("Xhair=0").Xhair == 1 and Preferences.Parse("Filter=3").Filter == 3)
check("choice_serialize", Preferences.Serialize(Preferences.Parse("Xhair=4")) == "Xhair=4"
	and Preferences.Serialize(Preferences.Parse("Xhair=1")) == "")
local badChoice = Preferences.Defaults()
badChoice.Xhair = 1.5
check("choice_valid", not Preferences.Valid(badChoice) and Preferences.Valid(Preferences.Parse("Xhair=3,DmgColor=4")))
check("choice_nudge_wraps", Preferences.Nudge(crosshair, 4, 1) == 1 and Preferences.Nudge(crosshair, 1, -1) == 4
	and Preferences.Nudge(crosshair, 2, 1) == 3)
check("text", Preferences.Text(crosshair, 2) == "DOT" and Preferences.Text(sway, 150) == "150%"
	and Preferences.Text(Preferences.Option("KeyHints"), false) == "OFF")

local everything = {}
for _, option in ipairs(Preferences.Options) do
	if option.kind == "slider" then
		everything[option.id] = option.default == option.max and option.min or option.max
	elseif option.kind == "choice" then
		everything[option.id] = #option.choices
	else
		everything[option.id] = not option.default
	end
end
check("longest_fits", Preferences.Valid(everything) and #Preferences.Serialize(everything) <= Preferences.MaxLength)

if failures > 0 then
	error(string.format("%d check(s) failed", failures))
end
print("all checks passed")
