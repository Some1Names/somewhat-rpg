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
	and Keybinds.ShortName("KeypadOne") == "N1" and Keybinds.ShortName("KeypadZero") == "N0"
	and Keybinds.ShortName("Semicolon") == ";" and Keybinds.ShortName("LeftAlt") == "LAlt")

-- Roblox names the number pad KeypadZero..KeypadNine; "Keypad1" isn't a KeyCode
check("keypad_names_are_real", Keybinds.Allowed.KeypadOne and Keybinds.Allowed.KeypadNine
	and Keybinds.Allowed.KeypadZero and not Keybinds.Allowed.Keypad1)

-- keys Roblox's own controls use: I and O zoom the camera, . opens emotes, , turns the camera
check("roblox_keys_not_allowed", not Keybinds.Allowed.I and not Keybinds.Allowed.O
	and not Keybinds.Allowed.Period and not Keybinds.Allowed.Comma)

-- every allowed key is a real Enum.KeyCode name (checked against Roblox's list)
local REAL = {}
for name in string.gmatch("A B C D E F G H I J K L M N O P Q R S T U V W X Y Z F1 F2 F3 F4 F5 F6 F7 F8 "
	.. "KeypadZero KeypadOne KeypadTwo KeypadThree KeypadFour KeypadFive KeypadSix KeypadSeven KeypadEight KeypadNine "
	.. "Comma Period Semicolon Quote LeftBracket RightBracket Minus Equals BackSlash LeftAlt RightAlt CapsLock", "%S+") do
	REAL[name] = true
end
local allReal = true
for name in pairs(Keybinds.Allowed) do
	if not REAL[name] then
		allReal = false
		print("  not a KeyCode name: " .. name)
	end
end
check("allowed_are_keycode_names", allReal)

if failures > 0 then
	error(string.format("%d check(s) failed", failures))
end
print("all checks passed")
