-- Who killed whom, and when, so that killing the same player again soon can
-- be told apart (HeadhunterConfig.isRepeat, within RepeatWindow): the
-- Headhunter script pays nothing for a repeat kill. Kept for this server
-- only; the records go with a player who leaves (a rejoin starts fresh).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeadhunterConfig = require(ReplicatedStorage:WaitForChild("HeadhunterConfig"))

local KillRecords = {
	RepeatWindow = HeadhunterConfig.RepeatWindow, -- seconds
}

local lastKills = setmetatable({}, { __mode = "k" }) -- killer -> { victim -> os.clock() }

-- `killer` just killed `victim` (both players)
function KillRecords.Record(killer, victim)
	local victims = lastKills[killer]
	if not victims then
		victims = setmetatable({}, { __mode = "k" })
		lastKills[killer] = victims
	end
	victims[victim] = os.clock()
end

-- whether `killer` already killed `victim` within RepeatWindow
function KillRecords.IsRepeat(killer, victim)
	local victims = lastKills[killer]
	return HeadhunterConfig.isRepeat(victims and victims[victim], os.clock())
end

return KillRecords
