-- Unit tests for ReplicatedStorage.HeadhunterConfig's pure rules (dropped
-- yen, the Headhunter's bonus XP, who holds the mark, repeat kills). Run with
-- Lune, outside Roblox: tests/run.sh.
local HeadhunterConfig = require("../src/ReplicatedStorage/HeadhunterConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- dropped yen: 5%, or 20% for the Headhunter, rounded down
check("no yen drops nothing", HeadhunterConfig.dropAmount(0, false) == 0)
check("99 yen drops 4", HeadhunterConfig.dropAmount(99, false) == 4)
check("1000 yen drops 50", HeadhunterConfig.dropAmount(1000, false) == 50)
check("the Headhunter's 1000 yen drops 200", HeadhunterConfig.dropAmount(1000, true) == 200)

-- bonus XP: 20% of a level, +5% per kill above 3, at most 50%
check("bonus at 3 kills is 20%", HeadhunterConfig.bonusXP(1000, 3) == 200)
check("bonus at 5 kills is 30%", HeadhunterConfig.bonusXP(1000, 5) == 300)
check("bonus at 20 kills stops at 50%", HeadhunterConfig.bonusXP(1000, 20) == 500)

-- the mark: most kills, at least 3; a tie stays with whoever got there first
check("nobody at 3 kills: no Headhunter", HeadhunterConfig.leader({ [1] = 2, [2] = 2 }, { [1] = 1, [2] = 2 }) == nil)
check("a clear leader at 3", HeadhunterConfig.leader({ [1] = 3, [2] = 2 }, { [1] = 1, [2] = 2 }) == 1)
check("a tie goes to the first to reach it", HeadhunterConfig.leader({ [1] = 4, [2] = 4 }, { [1] = 10, [2] = 5 }) == 2)
check("passing the leader takes the mark", HeadhunterConfig.leader({ [1] = 4, [2] = 5 }, { [1] = 1, [2] = 9 }) == 2)

-- repeat kills: the same victim again within 5 minutes
check("a first kill isn't a repeat", HeadhunterConfig.isRepeat(nil, 1000) == false)
check("299 s later is a repeat", HeadhunterConfig.isRepeat(1000 - 299, 1000) == true)
check("301 s later isn't", HeadhunterConfig.isRepeat(1000 - 301, 1000) == false)

if failures > 0 then
	error(failures .. " failed")
end
