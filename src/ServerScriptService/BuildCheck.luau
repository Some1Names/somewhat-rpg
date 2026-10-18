-- Stat requirements on skill sets and weapons (a set's `requires` in
-- SkillSetConfig, like { Superliminal = 10 }). A player below one can't use the
-- set: SkillSetServer, RangedServer, PunchCombat and Loadout ask here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildRules = require(ReplicatedStorage:WaitForChild("BuildRules"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))

local BuildCheck = {}

-- the player's points per stat
function BuildCheck.Stats(player)
	local stats = {}
	for _, stat in ipairs(StatConfig.Stats) do
		stats[stat.key] = player:GetAttribute(stat.key) or 0
	end
	return stats
end

-- whether the player meets this set's requirement; if not, false and a line like "Needs Strength 10"
function BuildCheck.SetMeets(player, setName)
	local set = SkillSetConfig.Sets[setName]
	local requires = set and set.requires
	local ok, missing = BuildRules.Meets(BuildCheck.Stats(player), requires)
	if ok then
		return true
	end
	return false, string.format("Needs %s %d", missing, requires[missing])
end

return BuildCheck
