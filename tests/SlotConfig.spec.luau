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
check("palette sizes", #S.SkinTones == 8 and #S.OutfitColors == 12 and #S.HairColors == 10 and #S.HairStyles == 5 and #S.FaceStyles == 4)

check("valid slots", S.ValidSlot(1) and S.ValidSlot(2) and S.ValidSlot(3))
check("invalid slots", not S.ValidSlot(0) and not S.ValidSlot(4) and not S.ValidSlot(1.5) and not S.ValidSlot("1") and not S.ValidSlot(nil))

check("names are trimmed", S.CleanName("  Ayato Yoji ") == "Ayato Yoji")
check("underscore and digits", S.CleanName("Bob_9") == "Bob_9")
for _, bad in ipairs({ "", "   ", "ab", string.rep("a", 17), "no!", "a\nb" }) do
	local name, reason = S.CleanName(bad)
	check("refuses " .. string.format("%q", bad), name == nil and type(reason) == "string" and #reason > 0)
end
check("refuses nil", S.CleanName(nil) == nil)
check("refuses a number", S.CleanName(12) == nil)

local look = { skin = 2, hair = 3, hairColor = 4, face = 1, top = 5, bottom = 6 }
check("format look", S.FormatLook(look) == "2;3;4;1;5;6")
local back = S.ParseLook("2;3;4;1;5;6")
check("look round trip", back.skin == 2 and back.hair == 3 and back.hairColor == 4 and back.face == 1 and back.top == 5 and back.bottom == 6)

local default = S.DefaultLook()
check("default look is all 1", default.skin == 1 and default.hair == 1 and default.hairColor == 1 and default.face == 1 and default.top == 1 and default.bottom == 1)
for _, junk in ipairs({ "", "x;y" }) do
	local parsed = S.ParseLook(junk)
	check("junk look " .. string.format("%q", junk), parsed.skin == 1 and parsed.hair == 1 and parsed.top == 1)
end
local nothing = S.ParseLook(nil)
check("nil look", nothing.skin == 1 and nothing.bottom == 1)
local outOfRange = S.ParseLook("99;2;3;2;4;5")
check("out of range falls back alone", outOfRange.skin == 1 and outOfRange.hair == 2 and outOfRange.hairColor == 3 and outOfRange.face == 2 and outOfRange.top == 4 and outOfRange.bottom == 5)
local odd = S.ParseLook("-1;1.5;3;2;4;5")
check("negative and fractional fall back", odd.skin == 1 and odd.hair == 1 and odd.hairColor == 3 and odd.face == 2 and odd.top == 4 and odd.bottom == 5)

local entry = { name = "Aido", level = 12, power = "Mandela", look = "1;1;1;1;1;1", playedAt = 100 }
local meta = S.CleanMeta({ [2] = entry, [4] = entry, extra = entry, [3] = { name = "X", level = "5", power = "", look = "", playedAt = 1 } })
check("meta keeps a good entry", meta[2] ~= nil and meta[2].name == "Aido" and meta[2].level == 12 and meta[2].playedAt == 100)
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
