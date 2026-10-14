-- Who killed whom, and when, so that killing the same player again soon can
-- be told apart (HeadhunterConfig.isRepeat, within RepeatWindow): the
-- Headhunter script pays nothing for a repeat kill, and Damage gives no
-- mastery from a victim the attacker just killed. Kept for this server only,
-- by UserId, so a player who leaves and rejoins is still the same victim
-- (otherwise two friends could reset the rule by rejoining).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeadhunterConfig = require(ReplicatedStorage:WaitForChild("HeadhunterConfig"))

local KillRecords = {
	RepeatWindow = HeadhunterConfig.RepeatWindow, -- seconds
}

local lastKills = {} -- killer's UserId -> { victim's UserId -> os.clock() }

-- `killer` just killed `victim` (both players)
function KillRecords.Record(killer, victim)
	local now = os.clock()
	local victims = lastKills[killer.UserId]
	if not victims then
		victims = {}
		lastKills[killer.UserId] = victims
	end
	-- forget kills too old to matter, so this doesn't grow all day
	for id, at in pairs(victims) do
		if now - at >= KillRecords.RepeatWindow then
			victims[id] = nil
		end
	end
	victims[victim.UserId] = now
end

-- whether `killer` already killed `victim` within RepeatWindow
function KillRecords.IsRepeat(killer, victim)
	local victims = lastKills[killer.UserId]
	return HeadhunterConfig.isRepeat(victims and victims[victim.UserId], os.clock())
end

return KillRecords
