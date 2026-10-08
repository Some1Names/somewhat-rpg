-- Unit tests for ReplicatedStorage.Keybinds' pure logic (parsing, saving,
-- binding with swaps, short key names). Run with Lune, outside Roblox:
-- tests/run.sh. The client half of the module needs the game and isn't
-- tested here.
local Keybinds = require("../src/ReplicatedStorage/Keybinds")

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

local defaults = Keybinds.Defaults()

check("parse_empty_is_defaults", same(Keybinds.Parse(""), defaults)
	and defaults.SkillZ == "Z" and defaults.Special == "G" and defaults.Dash == "Q"
	and defaults.Reload == "R" and defaults.Gallery == "T")

local swapped = Keybinds.Parse("SkillZ=Q,Dash=Z")
check("parse_swapped", swapped.SkillZ == "Q" and swapped.Dash == "Z" and swapped.SkillX == "X")

check("parse_reserved_ignored", Keybinds.Parse("SkillZ=W").SkillZ == "Z")

local unknown = Keybinds.Parse("Bogus=K,SkillZ=K")
check("parse_unknown_ignored", unknown.SkillZ == "K" and unknown.Bogus == nil)

check("parse_double_falls_back", same(Keybinds.Parse("SkillZ=Q"), defaults))

check("parse_non_string_and_long", same(Keybinds.Parse(nil), defaults)
	and same(Keybinds.Parse(42), defaults)
	and same(Keybinds.Parse(string.rep("SkillZ=K,", 30)), defaults))

check("serialize_defaults_empty", Keybinds.Serialize(defaults) == "")

check("serialize_round_trip", Keybinds.Serialize(Keybinds.Parse("Dash=Z,SkillZ=Q")) == "SkillZ=Q,Dash=Z")

local before = Keybinds.Defaults()
local bound = Keybinds.Bind(before, "SkillZ", "Q")
check("bind_swaps", bound ~= nil and bound.SkillZ == "Q" and bound.Dash == "Z" and before.SkillZ == "Z" and before.Dash == "Q")

local function refused(key)
	local map, reason = Keybinds.Bind(Keybinds.Defaults(), "SkillZ", key)
	return map == nil and reason == "reserved"
end
check("bind_reserved", refused("W") and refused("P") and refused("One"))

local noMap, why = Keybinds.Bind(Keybinds.Defaults(), "Nope", "K")
check("bind_unknown_action", noMap == nil and why == "unknown")

local double = Keybinds.Defaults()
double.SkillZ = "Q"
local missing = Keybinds.Defaults()
missing.Reload = nil
local spaced = Keybinds.Defaults()
spaced.SkillZ = "Space"
check("valid", Keybinds.Valid(Keybinds.Defaults()) and not Keybinds.Valid(double)
	and not Keybinds.Valid(missing) and not Keybinds.Valid(spaced))

check("short_names", Keybinds.ShortName("Q") == "Q" and Keybinds.ShortName("F5") == "F5"
	and Keybinds.ShortName("Keypad1") == "N1" and Keybinds.ShortName("Semicolon") == ";"
	and Keybinds.ShortName("LeftAlt") == "LAlt")

if failures > 0 then
	error(string.format("%d check(s) failed", failures))
end
print("all checks passed")
