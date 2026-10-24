-- Factions: three groups a player can join at a recruiter (a model tagged
-- "FactionRecruiter" with a FactionId attribute). Numbers and pure rules live
-- here, free of Roblox types so Lune can test them (tests/FactionConfig.spec.luau);
-- the server module Factions runs joining and the standing gain.
-- A player's standing is the saved `FactionData` text, "<key>:<standing>:<joinedAt>"
-- (joinedAt is os.time()), replicated as the Faction / FactionStanding / FactionRank
-- / FactionDiscount attributes. Umbra Noctis is the owner's name; the other two names are placeholders.
local FactionConfig = {}

FactionConfig.SaveAttribute = "FactionData" -- on the player, saved (PlayerStats)
FactionConfig.MaxSaveLength = 40
FactionConfig.SwitchCooldown = 3600 -- seconds after joining before you can leave for another faction
FactionConfig.EnemyKillStanding = 1 -- standing for killing an NPC enemy
FactionConfig.RivalKillStanding = 5 -- standing for killing a player of another faction
FactionConfig.RecruiterRange = 14 -- studs from the recruiter the player must be within

-- rankNames: the faction's own name for each rank (same order as Ranks; the generic
-- Ranks names are the fallback).
-- palette: the faction's colour at each rank (same order as Ranks), dull at Recruit and
-- brighter with every rank; `color` is its base. Lumen is blue, Umbra Noctis purple,
-- the Headhunter Clan red.
-- shopDiscount: the share off shop prices at each rank (same order as Ranks); no
-- field means no discount. Other perks can be added the same way.
FactionConfig.Factions = {
	{
		key = "Lumen",
		name = "The Lumen Order",
		theme = "good",
		color = { 60, 150, 255 },
		rankNames = { "Initiate", "Guardian", "Sentinel", "Paladin", "Archon" },
		palette = { { 110, 140, 190 }, { 80, 130, 220 }, { 60, 150, 255 }, { 70, 190, 255 }, { 150, 230, 255 } },
		description = "Protectors who keep the city safe.",
		shopDiscount = { 0, 0.05, 0.1, 0.15, 0.2 },
	},
	{
		key = "UmbraNoctis",
		name = "Umbra Noctis",
		theme = "bad",
		color = { 170, 80, 240 },
		rankNames = { "Shade", "Whisper", "Wraith", "Nightblade", "Umbra Lord" },
		palette = { { 130, 100, 170 }, { 150, 90, 210 }, { 170, 80, 240 }, { 200, 110, 255 }, { 235, 170, 255 } },
		description = "A criminal power working from the dark.",
	},
	{
		key = "Headhunters",
		name = "The Headhunter Clan",
		theme = "headhunter",
		color = { 230, 50, 50 },
		rankNames = { "Hound", "Tracker", "Hunter", "Slayer", "Warlord" },
		palette = { { 170, 90, 90 }, { 200, 70, 70 }, { 230, 50, 50 }, { 255, 70, 60 }, { 255, 140, 120 } },
		description = "A clan that lives off bounties and heads.",
		shopDiscount = { 0, 0, 0.05, 0.05, 0.1 },
	},
}

-- standing needed for each rank, lowest first
FactionConfig.Ranks = {
	{ name = "Recruit", standing = 0 },
	{ name = "Member", standing = 25 },
	{ name = "Veteran", standing = 100 },
	{ name = "Elite", standing = 300 },
	{ name = "Champion", standing = 800 },
}

local byKey = {}
for _, faction in ipairs(FactionConfig.Factions) do
	byKey[faction.key] = faction
end

function FactionConfig.Get(key)
	return byKey[key]
end

-- "key:standing:joinedAt" -> key, standing, joinedAt (nil key if empty or unknown)
function FactionConfig.Parse(text)
	local key, standing, joinedAt = string.match(text or "", "^(%a+):(%d+):(%d+)$")
	if not key or not byKey[key] then
		return nil, 0, 0
	end
	return key, tonumber(standing), tonumber(joinedAt)
end

function FactionConfig.Encode(key, standing, joinedAt)
	if not byKey[key] then
		return ""
	end
	return string.format("%s:%d:%d", key, math.max(0, math.floor(standing)), math.max(0, math.floor(joinedAt)))
end

-- index into Ranks for a standing
function FactionConfig.RankIndex(standing)
	local index = 1
	for i, rank in ipairs(FactionConfig.Ranks) do
		if standing >= rank.standing then
			index = i
		end
	end
	return index
end

function FactionConfig.RankName(standing, key)
	local index = FactionConfig.RankIndex(standing)
	local faction = byKey[key]
	return faction and faction.rankNames and faction.rankNames[index] or FactionConfig.Ranks[index].name
end

-- the standing the next rank needs (nil at the top rank)
function FactionConfig.NextRankStanding(standing)
	local upcoming = FactionConfig.Ranks[FactionConfig.RankIndex(standing) + 1]
	return upcoming and upcoming.standing
end

-- can a player in `currentKey` (joined at `joinedAt`) join `newKey` at time `now`?
-- Returns ok, reason.
function FactionConfig.CanJoin(currentKey, joinedAt, newKey, now)
	if not byKey[newKey] then
		return false, "Unknown faction"
	end
	if currentKey == newKey then
		return false, "Already a member"
	end
	if currentKey and now - joinedAt < FactionConfig.SwitchCooldown then
		return false, "You joined too recently to switch"
	end
	return true, ""
end

-- the faction's colour for a standing, as {r, g, b} (nil with no faction)
function FactionConfig.RankColor(key, standing)
	local faction = byKey[key]
	return faction and faction.palette[FactionConfig.RankIndex(standing)]
end

-- the title shown with a name: "[Veteran]" (empty with no faction)
function FactionConfig.Title(key, standing)
	if not byKey[key] then
		return ""
	end
	return "[" .. FactionConfig.RankName(standing, key) .. "]"
end

-- the share off shop prices for a faction member (0 with no faction or no perk)
function FactionConfig.ShopDiscount(key, standing)
	local faction = byKey[key]
	local list = faction and faction.shopDiscount
	return list and list[FactionConfig.RankIndex(standing)] or 0
end

-- a price with the discount taken off, rounded to a whole yen (never below 1 for a paid item)
function FactionConfig.DiscountedPrice(price, discount)
	if price <= 0 or discount <= 0 then
		return price
	end
	return math.max(1, math.floor(price * (1 - discount) + 0.5))
end

-- standing earned for a kill; nil if the kill earns none
function FactionConfig.KillStanding(victimIsPlayer, killerKey, victimKey)
	if not killerKey then
		return 0
	end
	if not victimIsPlayer then
		return FactionConfig.EnemyKillStanding
	end
	if victimKey and victimKey ~= killerKey then
		return FactionConfig.RivalKillStanding
	end
	return 0
end

return FactionConfig
