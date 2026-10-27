-- Unit tests for ReplicatedStorage.SlotConfig (slot keys, character names, look text,
-- the saved slot summaries). Run with Lune, outside Roblox: tests/run.sh.
local S = require("../src/ReplicatedStorage/SlotConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

check("three slots", S.SlotCount == 3)
check("slot keys", S.SlotKey(5, 2) == "5_2" and S.MetaKey(5) == "5_meta")
check("palette sizes", #S.SkinTones == 8 and #S.OutfitColors == 12 and #S.HairColors == 10)
check("style list sizes", #S.HairStyles == 9 and #S.FaceStyles == 10 and #S.AccessoryStyles == 7 and #S.TeeStyles == 3 and #S.ShirtStyles == 1 and #S.PantsStyles == 1)
check("every style list starts with its none/default", S.HairStyles[1] == "None" and S.FaceStyles[1] == "Default" and S.AccessoryStyles[1] == "None" and S.TeeStyles[1] == "None")

check("valid slots", S.ValidSlot(1) and S.ValidSlot(2) and S.ValidSlot(3))
check("invalid slots", not S.ValidSlot(0) and not S.ValidSlot(4) and not S.ValidSlot(1.5) and not S.ValidSlot("1") and not S.ValidSlot(nil))

check("names are trimmed", S.CleanName("  Ayato Yoji ") == "Ayato Yoji")
check("underscore and digits", S.CleanName("Bob_9") == "Bob_9")
check("repeated spaces collapse", S.CleanName("A          B") == "A B")
check("single spaces are kept", S.CleanName(string.rep("a ", 8)) == string.rep("a ", 7) .. "a")
for _, bad in ipairs({ "", "   ", "ab", string.rep("a", 17), "no!", "a\nb", "___", "_ _ _", "1  " }) do
	local name, reason = S.CleanName(bad)
	check("refuses " .. string.format("%q", bad), name == nil and type(reason) == "string" and #reason > 0)
end
check("refuses nil", S.CleanName(nil) == nil)
check("refuses a number", S.CleanName(12) == nil)

local function same(a, b)
	return a ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- colours are free RGB (a colour wheel picks them), saved as six hex digits
check("format colour", S.FormatColor({ 255, 224, 189 }) == "FFE0BD" and S.FormatColor({ 0, 0, 0 }) == "000000")
check("format colour rounds and clamps", S.FormatColor({ 254.6, -5, 300 }) == "FF00FF")
check("parse colour", same(S.ParseColor("FFE0BD"), { 255, 224, 189 }) and same(S.ParseColor("abcdef"), { 171, 205, 239 }))
for _, bad in ipairs({ "", "FFF", "FFE0BDFF", "GGGGGG", "#FFE0BD", "FFE0B" }) do
	check("refuses colour " .. string.format("%q", bad), S.ParseColor(bad) == nil)
end
check("refuses a colour that isn't text", S.ParseColor(nil) == nil and S.ParseColor(123456) == nil)

local look = { skin = { 255, 224, 189 }, hair = 3, hairColor = { 30, 25, 25 }, face = 1, top = { 40, 40, 40 }, bottom = { 171, 205, 239 } }
-- a look with no shirt, tee, pants or accessory fields formats them as 1 (none)
check("format look", S.FormatLook(look) == "FFE0BD;3;1E1919;1;282828;ABCDEF;1;1;1;1")
local back = S.ParseLook("FFE0BD;3;1E1919;1;282828;ABCDEF")
check("look round trip", same(back.skin, look.skin) and back.hair == 3 and same(back.hairColor, look.hairColor) and back.face == 1 and same(back.top, look.top) and same(back.bottom, look.bottom))
check("a six-field look (made before clothes and accessories) gets none of them", back.shirt == 1 and back.tee == 1 and back.pants == 1 and back.accessory == 1)
check("a look formats the same after a round trip", S.FormatLook(S.ParseLook("FFE0BD;3;1E1919;1;282828;ABCDEF;1;2;1;4")) == "FFE0BD;3;1E1919;1;282828;ABCDEF;1;2;1;4")
local full = S.ParseLook("FFE0BD;3;1E1919;2;282828;ABCDEF;1;2;1;4")
check("tee and accessory parse", full.tee == 2 and full.accessory == 4 and full.shirt == 1 and full.pants == 1 and full.face == 2)
local tooFar = S.ParseLook("FFE0BD;3;1E1919;2;282828;ABCDEF;5;9;5;99")
check("shirt, tee, pants and accessory out of range fall back to none", tooFar.shirt == 1 and tooFar.tee == 1 and tooFar.pants == 1 and tooFar.accessory == 1 and tooFar.hair == 3)

local default = S.DefaultLook()
check("default look is each list's first", same(default.skin, S.SkinTones[1]) and default.hair == 1 and same(default.hairColor, S.HairColors[1]) and default.face == 1 and same(default.top, S.OutfitColors[1]) and same(default.bottom, S.OutfitColors[1]))
for _, junk in ipairs({ "", "x;y" }) do
	local parsed = S.ParseLook(junk)
	check("junk look " .. string.format("%q", junk), same(parsed.skin, S.SkinTones[1]) and parsed.hair == 1 and same(parsed.top, S.OutfitColors[1]))
end
local nothing = S.ParseLook(nil)
check("nil look", same(nothing.skin, S.SkinTones[1]) and same(nothing.bottom, S.OutfitColors[1]))
-- looks saved before the colour wheel counted colours as numbers into the palettes
local legacy = S.ParseLook("99;2;3;2;4;5")
check("an older look's numbers still mean palette colours", same(legacy.skin, S.SkinTones[1]) and legacy.hair == 2 and same(legacy.hairColor, S.HairColors[3]) and legacy.face == 2 and same(legacy.top, S.OutfitColors[4]) and same(legacy.bottom, S.OutfitColors[5]))
local odd = S.ParseLook("-1;1.5;3;2;4;5")
check("negative and fractional fall back", same(odd.skin, S.SkinTones[1]) and odd.hair == 1 and same(odd.hairColor, S.HairColors[3]) and odd.face == 2)
local badStyle = S.ParseLook("FFFFFF;99;000000;99;FFFFFF;FFFFFF")
check("a style out of range falls back and the colours stay", badStyle.hair == 1 and badStyle.face == 1 and same(badStyle.skin, { 255, 255, 255 }) and same(badStyle.hairColor, { 0, 0, 0 }))

local entry = { name = "Aido", level = 12, power = "Mandela", look = "1;1;1;1;1;1", playedAt = 100 }
local meta = S.CleanMeta({ [2] = entry, [4] = entry, extra = entry, [3] = { name = "X", level = "5", power = "", look = "", playedAt = 1 } })
check("meta keeps a good entry", meta[2] ~= nil and meta[2].name == "Aido" and meta[2].level == 12 and meta[2].playedAt == 100)
check("a summary without yen (saved before it was kept) has 0", meta[2].yen == 0)
local withYen = S.CleanMeta({ ["1"] = { name = "A", level = 1, power = "", look = "", playedAt = 1, yen = 250 } })
check("a summary keeps its yen", withYen[1] ~= nil and withYen[1].yen == 250)
check("yen that isn't a number is 0", S.CleanMeta({ ["1"] = { name = "A", level = 1, power = "", look = "", playedAt = 1, yen = "lots" } })[1].yen == 0)
check("meta drops slot 4, string keys and bad entries", meta[4] == nil and meta.extra == nil and meta[3] == nil and meta[1] == nil)
check("meta from nothing is empty", next(S.CleanMeta(nil)) == nil)

-- the DataStore can't keep a table with gaps in its integer keys ({ [1] = a, [3] = c }),
-- so the saved summaries use string keys
local gapped = S.EncodeMeta({ [1] = entry, [3] = entry })
check("encoded meta has string keys only", gapped["1"] ~= nil and gapped["3"] ~= nil and gapped[1] == nil and gapped[3] == nil and gapped["2"] == nil)
local decoded = S.CleanMeta(gapped)
check("encoded meta round trips with a gap", decoded[1] ~= nil and decoded[2] == nil and decoded[3] ~= nil and decoded[3].name == "Aido")
local lonely = S.CleanMeta(S.EncodeMeta({ [2] = entry }))
check("a lone slot 2 survives", lonely[2] ~= nil and lonely[1] == nil and lonely[3] == nil)
check("encoding nothing is empty", next(S.EncodeMeta({})) == nil)
check("account key", S.AccountKey(5) == "5_account")

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all passed")
