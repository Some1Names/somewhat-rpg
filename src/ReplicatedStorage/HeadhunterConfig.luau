-- Death stakes and the Headhunter (ServerScriptService.Headhunter): the
-- numbers and the pure rules, kept free of Roblox types so Lune can test
-- them (tests/HeadhunterConfig.spec.luau).
-- Dying drops DropShare of your yen to whoever got the kill (CreditTime, the
-- kill feed's rule); killing the same player again within RepeatWindow gets
-- nothing. The server's kill leader, at MinKills player kills or more, is
-- the Headhunter: they drop HeadhunterDropShare instead, and whoever takes
-- their head also gets bonus XP. Leaving within LeaveCombatWindow of a fight
-- costs the Headhunter their share too.
local HeadhunterConfig = {
	DropShare = 0.05, -- of the yen a player carries, lost on death
	HeadhunterDropShare = 0.2, -- the same, for the Headhunter
	MinKills = 3, -- player kills before anyone can be the Headhunter
	RepeatWindow = 300, -- seconds: the same killer and victim again pays nothing
	CreditTime = 15, -- seconds a player's last hit still counts as the kill
	LeaveCombatWindow = 600, -- seconds after a fight that leaving costs the Headhunter
	BonusBase = 0.2, -- of the killer's XP to the next level, for the Headhunter's head
	BonusPerKill = 0.05, -- more for each of the Headhunter's kills above MinKills
	BonusMax = 0.5, -- at most this share
}

-- a little slack so a share like 0.29 × 100 isn't floored to 28
local EPSILON = 1e-9

-- the yen a death drops
function HeadhunterConfig.dropAmount(yen, isHeadhunter)
	local share = isHeadhunter and HeadhunterConfig.HeadhunterDropShare or HeadhunterConfig.DropShare
	return math.max(math.floor(yen * share + EPSILON), 0)
end

-- the XP for taking the head of a Headhunter with `headhunterKills` kills,
-- out of the killer's `xpToLevel` (their XP to the next level)
function HeadhunterConfig.bonusXP(xpToLevel, headhunterKills)
	local above = math.max(headhunterKills - HeadhunterConfig.MinKills, 0)
	local share = math.min(HeadhunterConfig.BonusBase + HeadhunterConfig.BonusPerKill * above, HeadhunterConfig.BonusMax)
	return math.floor(xpToLevel * share + EPSILON)
end

-- who holds the mark: the most kills, at least MinKills; a tie goes to the
-- one who reached that count first (the holder, when there is one).
-- `counts`: id -> kills; `reachedAt`: id -> when they reached that count
function HeadhunterConfig.leader(counts, reachedAt)
	local best, bestKills, bestAt
	for id, kills in pairs(counts) do
		if kills >= HeadhunterConfig.MinKills then
			local at = reachedAt[id] or math.huge
			if
				best == nil
				or kills > bestKills
				or (kills == bestKills and (at < bestAt or (at == bestAt and id < best)))
			then
				best, bestKills, bestAt = id, kills, at
			end
		end
	end
	return best
end

-- whether a kill is a repeat: the same killer got this victim within RepeatWindow
-- (`lastKillAt`: when, or nil if never)
function HeadhunterConfig.isRepeat(lastKillAt, now)
	return lastKillAt ~= nil and now - lastKillAt < HeadhunterConfig.RepeatWindow
end

return HeadhunterConfig
