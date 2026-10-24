-- Unit tests for ReplicatedStorage.FactionConfig (parsing, ranks, joining, kill
-- standing). Run with Lune, outside Roblox: tests/run.sh.
local F = require("../src/ReplicatedStorage/FactionConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

check("three factions with unique keys", #F.Factions == 3 and F.Get("Lumen") ~= nil and F.Get("Nope") == nil)

local key, standing, joinedAt = F.Parse("Veil:42:1000")
check("parse reads a save", key == "UmbraNoctis" and standing == 42 and joinedAt == 1000)
check("parse rejects junk and unknown factions", F.Parse("") == nil and F.Parse("Nope:1:1") == nil and F.Parse("Veil:x:1") == nil)
check("encode round-trips", F.Encode("UmbraNoctis", 42, 1000) == "Veil:42:1000" and F.Encode("Nope", 1, 1) == "")
check("encode floors and clamps", F.Encode("UmbraNoctis", -5, 10.9) == "Veil:0:10")
check("encoded save fits the limit", #F.Encode("Headhunters", 99999999, 2000000000) <= F.MaxSaveLength)

check("rank boundaries", F.RankName(0) == "Recruit" and F.RankName(24) == "Recruit" and F.RankName(25) == "Member" and F.RankName(800) == "Champion")
check("rank index grows with standing", F.RankIndex(0) == 1 and F.RankIndex(100) == 3 and F.RankIndex(99999) == #F.Ranks)

check("first join is free", F.CanJoin(nil, 0, "UmbraNoctis", 5))
check("can't join the same faction", not F.CanJoin("UmbraNoctis", 0, "UmbraNoctis", 99999))
check("can't join an unknown faction", not F.CanJoin(nil, 0, "Nope", 5))
check("switching waits out the cooldown", not F.CanJoin("UmbraNoctis", 1000, "Lumen", 1000 + F.SwitchCooldown - 1))
check("switching works after the cooldown", F.CanJoin("UmbraNoctis", 1000, "Lumen", 1000 + F.SwitchCooldown))

check("no faction, no standing", F.KillStanding(false, nil, nil) == 0)
check("enemy kill earns standing", F.KillStanding(false, "UmbraNoctis", nil) == F.EnemyKillStanding)
check("rival player kill earns more", F.KillStanding(true, "UmbraNoctis", "Lumen") == F.RivalKillStanding)
check("same-faction or factionless player kill earns none", F.KillStanding(true, "UmbraNoctis", "UmbraNoctis") == 0 and F.KillStanding(true, "UmbraNoctis", nil) == 0)

check("discount follows rank", F.ShopDiscount("Lumen", 0) == 0 and F.ShopDiscount("Lumen", 25) == 0.05 and F.ShopDiscount("Lumen", 800) == 0.2)
check("no perk, no faction, no discount", F.ShopDiscount("UmbraNoctis", 800) == 0 and F.ShopDiscount(nil, 800) == 0)
check("discounted price rounds and keeps free free", F.DiscountedPrice(500, 0.1) == 450 and F.DiscountedPrice(0, 0.2) == 0 and F.DiscountedPrice(1, 0.2) == 1 and F.DiscountedPrice(500, 0) == 500)

local palettesOk = true
for _, faction in ipairs(F.Factions) do
	if #faction.palette ~= #F.Ranks then
		palettesOk = false
	end
end
check("every faction has a colour per rank", palettesOk)
check("rank colour follows rank", F.RankColor("Lumen", 0)[1] == 110 and F.RankColor("Lumen", 800)[1] == 150 and F.RankColor(nil, 5) == nil)
check("title shows the rank", F.Title("Lumen", 100) == "[Sentinel]" and F.Title(nil, 100) == "")

check("each faction names its own ranks", F.RankName(0, "UmbraNoctis") == "Shade" and F.RankName(800, "Headhunters") == "Warlord" and F.RankName(25, "Lumen") == "Guardian")
local namesOk = true
for _, faction in ipairs(F.Factions) do
	if #faction.rankNames ~= #F.Ranks then
		namesOk = false
	end
end
check("every faction has a name per rank", namesOk)
check("no faction falls back to the generic name", F.RankName(100) == "Veteran" and F.RankName(100, "Nope") == "Veteran")

check("next rank standing", F.NextRankStanding(0) == 25 and F.NextRankStanding(99) == 100 and F.NextRankStanding(800) == nil)

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all passed")
