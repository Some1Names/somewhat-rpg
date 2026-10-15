-- Unit tests for ReplicatedStorage.QuestConfig's pure helpers (what a bounty
-- pays, the saved challenge text, how a challenge advances). Run with Lune,
-- outside Roblox: tests/run.sh.
local QuestConfig = require("../src/ReplicatedStorage/QuestConfig")
local StatConfig = require("../src/ReplicatedStorage/StatConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

-- what a bounty pays: 1.5 x what its kills pay, rounded down
local xp, yen = QuestConfig.reward(6, 15)
check("reward xp", xp == math.floor(1.5 * 6 * StatConfig.EnemyXP(15)))
check("reward yen", yen == math.floor(1.5 * 6 * StatConfig.EnemyYen(15)))
check("reward numbers", xp == 1710 and yen == 855)
local xp0, yen0 = QuestConfig.reward(3, 0)
check("level 0 reward", xp0 == math.floor(1.5 * 3 * StatConfig.EnemyXP(0)) and yen0 == math.floor(1.5 * 3 * StatConfig.EnemyYen(0)))

-- a taken bounty's id, "giver/quest", as the player attribute holds it
local giverId, quest = QuestConfig.parseQuestId("Training/dummies")
check("parse a bounty id", giverId == "Training" and quest ~= nil and quest.id == "dummies" and quest.enemyType == "Dummy")
check("parse bad bounty ids", QuestConfig.parseQuestId("Training/nope") == nil and QuestConfig.parseQuestId("Nobody/x") == nil
	and QuestConfig.parseQuestId("nonsense") == nil and QuestConfig.parseQuestId(nil) == nil and QuestConfig.parseQuestId(42) == nil)

-- what a bounty calls its enemies: its own plural, else the type with an s
check("plural field wins", QuestConfig.plural({ enemyType = "Henchman", plural = "Henchmen" }) == "Henchmen")
check("plural defaults to adding s", QuestConfig.plural({ enemyType = "Worker" }) == "Workers")
check("the first bounty says Dummies", QuestConfig.plural(QuestConfig.Givers.Training.quests[1]) == "Dummies")

-- the saved text
check("encode empty", QuestConfig.encode({}) == "")
local sample = { ["Mandela.1"] = 7, ["Mandela.2"] = "done" }
local round = QuestConfig.decode(QuestConfig.encode(sample))
check("round trip", round["Mandela.1"] == 7 and round["Mandela.2"] == "done")
check("encode is stable", QuestConfig.encode(sample) == "Mandela.1=7;Mandela.2=done")
local empty = QuestConfig.decode("")
check("decode empty", next(empty) == nil)
local ok, garbage = pcall(QuestConfig.decode, "garbage;;=;Mandela.1=x;=5;Mandela.1")
check("decode garbage doesn't error", ok and next(garbage) == nil)
local unknown = QuestConfig.decode("Nobody.1=3;Mandela.99=2;Mandela.1=4")
check("decode drops unknown ids", unknown["Nobody.1"] == nil and unknown["Mandela.99"] == nil and unknown["Mandela.1"] == 4)
check("decode non-string", next(QuestConfig.decode(nil)) == nil and next(QuestConfig.decode(42)) == nil)
check("decode too long is empty", next(QuestConfig.decode(string.rep("Mandela.1=1;", 200))) == nil)

-- every challenge done still fits the saved text's limit
local all = {}
for setName, list in pairs(QuestConfig.Challenges) do
	for _, challenge in ipairs(list) do
		all[setName .. "." .. challenge.id] = "done"
	end
end
check("all done fits the limit", #QuestConfig.encode(all) <= QuestConfig.MaxSaveLength)
check("all done survives decode", QuestConfig.decode(QuestConfig.encode(all))["Mandela.1"] == "done")

-- advancing a challenge
local hits = { kind = "hits", skill = "Z", count = 15 }
local value, done = QuestConfig.advance(hits, 7)
check("hits add one", value == 8 and done == false)
value, done = QuestConfig.advance(hits, nil)
check("nil starts at zero", value == 1 and done == false)
value, done = QuestConfig.advance(hits, 14)
check("reaching the count is done", value == "done" and done == true)
value, done = QuestConfig.advance(hits, "done")
check("done stays done and pays nothing more", value == "done" and done == false)

local pull = { kind = "event", event = "EventHorizonPull", min = 3, count = 1 }
value, done = QuestConfig.advance(pull, nil, 2)
check("an event below min doesn't count", value == 0 and done == false)
value, done = QuestConfig.advance(pull, 0, 3)
check("an event at min counts", value == "done" and done == true)
local plain = { kind = "event", event = "Framed", count = 10 }
value, done = QuestConfig.advance(plain, 4)
check("an event without min counts on its own", value == 5 and done == false)
value, done = QuestConfig.advance(plain, "done", 99)
check("done ignores events too", value == "done" and done == false)

-- a total adds up the sizes of what's reported (the flight challenge: seconds in the air)
local fly = { kind = "total", event = "FlightTime", count = 60 }
value, done = QuestConfig.advance(fly, nil, 6.4)
check("a total adds the amount, rounded", value == 6 and done == false)
value, done = QuestConfig.advance(fly, 55, 6)
check("a total reaching the count is done", value == "done" and done == true)
value, done = QuestConfig.advance(fly, 10, 0.3)
check("a tiny amount adds nothing", value == 10 and done == false)
value, done = QuestConfig.advance(fly, 10, nil)
check("a total without an amount adds nothing", value == 10 and done == false)
value, done = QuestConfig.advance(fly, 10, -5)
check("a negative amount adds nothing", value == 10 and done == false)
value, done = QuestConfig.advance(fly, "done", 30)
check("a done total stays done", value == "done" and done == false)
check("the flight challenge is a total", QuestConfig.Challenges.IridescentRequiem[4].kind == "total"
	and QuestConfig.Challenges.IridescentRequiem[4].count == 60)

-- the data
check("every challenge has an id, kind, count and reward", (function()
	for _, list in pairs(QuestConfig.Challenges) do
		for i, challenge in ipairs(list) do
			if challenge.id ~= i or not challenge.kind or not challenge.count or not challenge.reward or not challenge.text then
				return false
			end
			if (challenge.kind == "event" or challenge.kind == "total") and not challenge.event then
				return false
			end
			if (challenge.kind == "hits" or challenge.kind == "kills") and not challenge.skill then
				return false
			end
		end
	end
	return true
end)())
check("the spec's challenge counts", #QuestConfig.Challenges.Mandela == 5 and #QuestConfig.Challenges.IridescentRequiem == 5
	and #QuestConfig.Challenges.Photoshop == 5 and #QuestConfig.Challenges.Aido == 5 and #QuestConfig.Challenges.Revolver == 2)
check("the three givers exist", QuestConfig.Givers.Training ~= nil and QuestConfig.Givers.Frontier ~= nil and QuestConfig.Givers.Outpost ~= nil)
check("every bounty has what the panel needs", (function()
	local seen = {}
	for _, giver in pairs(QuestConfig.Givers) do
		for _, quest in ipairs(giver.quests) do
			if seen[quest.id] or not quest.title or not quest.level or not quest.enemyType or not quest.count or quest.count < 1 then
				return false
			end
			seen[quest.id] = true
		end
	end
	return true
end)())
check("constants", QuestConfig.RewardShare == 1.5 and QuestConfig.GiverTag == "QuestGiver" and QuestConfig.MaxSaveLength == 1000)

if failures > 0 then
	error(failures .. " failed")
end
