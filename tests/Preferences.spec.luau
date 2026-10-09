-- Unit tests for ReplicatedStorage.Preferences' pure logic (the saved
-- ON/OFF settings). Run with Lune, outside Roblox: tests/run.sh.
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
	and defaults.Flashes == true and defaults.DamageNumbers == true)

check("parse_nil_is_defaults", same(Preferences.Parse(nil), defaults)
	and same(Preferences.Parse(""), defaults) and same(Preferences.Parse(5), defaults))

local parsed = Preferences.Parse("QuickRespawn=1,CameraShake=0")
check("parse_values", parsed.QuickRespawn == true and parsed.CameraShake == false and parsed.Flashes == true)

local bad = Preferences.Parse("CameraShake=2,Flashes=yes,Bogus=1")
check("parse_bad_values_ignored", bad.CameraShake == true and bad.Flashes == true and bad.Bogus == nil)

check("parse_too_long", same(Preferences.Parse(string.rep("Flashes=0,", 25)), defaults))

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
	and Preferences.Options[4].id == "DamageNumbers" and Preferences.Options[4].section == "EFFECTS")

if failures > 0 then
	error(string.format("%d check(s) failed", failures))
end
print("all checks passed")
