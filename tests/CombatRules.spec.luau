-- Unit tests for ReplicatedStorage.CombatRules (the out-of-combat timer, who a
-- shockwave marks, the most-used skill and the erased list's text). Run with
-- Lune, outside Roblox: tests/run.sh.
local CombatRules = require("../src/ReplicatedStorage/CombatRules")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- the timer
check("never in combat counts as out of combat", CombatRules.OutOfCombat(nil, 100))
check("just hit is in combat", not CombatRules.OutOfCombat(100, 100))
check("29 s after is still in combat", not CombatRules.OutOfCombat(100, 129))
check("30 s after is out of combat", CombatRules.OutOfCombat(100, 130))
check("seconds left counts down from 30", CombatRules.SecondsLeft(100, 100) == 30 and CombatRules.SecondsLeft(100, 125) == 5)
check("seconds left is nil once out", CombatRules.SecondsLeft(100, 131) == nil)
check("the countdown is hidden above 10 s", not CombatRules.ShowCountdown(CombatRules.SecondsLeft(100, 119)))
check("the countdown shows at 10 s", CombatRules.ShowCountdown(CombatRules.SecondsLeft(100, 120)))
check("the countdown is hidden when out", not CombatRules.ShowCountdown(nil))

-- marks
local near, mid, far = { id = "near", distance = 5 }, { id = "mid", distance = 20 }, { id = "far", distance = 40 }
local picked = CombatRules.PickMarks({ far, near, mid }, 0)
check("two marks at most, the nearest", #picked == 2 and picked[1] == "near" and picked[2] == "mid")
picked = CombatRules.PickMarks({ far, near, mid }, 1)
check("one already marked leaves one slot", #picked == 1 and picked[1] == "near")
check("two already marked leaves none", #CombatRules.PickMarks({ near }, 2) == 0)
check("nobody caught marks nobody", #CombatRules.PickMarks({}, 0) == 0)
local input = { far, near }
CombatRules.PickMarks(input, 0)
check("the candidate list is not reordered", input[1] == far)

-- the most-used skill
local usage = {
	["Mandela.Z"] = { count = 5, last = 10 },
	["Mandela.X"] = { count = 3, last = 30 },
	["Mandela.C"] = { count = 5, last = 20 },
}
check("most used wins, the later of a tie", CombatRules.MostUsed(usage, {}) == "Mandela.C")
check("erased skills are skipped", CombatRules.MostUsed(usage, { ["Mandela.C"] = true }) == "Mandela.Z")
check("nothing left gives nil", CombatRules.MostUsed(usage, { ["Mandela.C"] = true, ["Mandela.Z"] = true, ["Mandela.X"] = true }) == nil)
check("no usage gives nil", CombatRules.MostUsed({}, {}) == nil)

-- the erased list's text
local text = CombatRules.EncodeErased({ "Mandela.Z", "Iridescent.X" })
local set = CombatRules.DecodeErased(text)
check("erased ids survive the round trip", set["Mandela.Z"] and set["Iridescent.X"] and not set["Mandela.C"])
check("empty and missing text decode to nothing", next(CombatRules.DecodeErased("")) == nil and next(CombatRules.DecodeErased(nil)) == nil)

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all CombatRules checks passed")
