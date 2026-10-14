-- Quests: the data and the pure helpers (tests/QuestConfig.spec.luau runs
-- them outside Roblox). Two kinds, both tracked by ServerScriptService.Quests:
-- bounties (level quests: "Defeat N <EnemyType>", given by NPCs tagged
-- QuestGiver, one at a time, paid on the spot) and mastery challenges (per
-- skill set, each done once, paying mastery XP, saved as text).
-- Givers: id (the NPC's GiverId attribute) -> { name, quests = { { id,
-- title, level, enemyType, plural?, count } } }. A kill counts for a bounty
-- when the model's EnemyType attribute matches; `plural` is how the texts
-- name them ("Henchmen"; otherwise the type with an s).
-- Challenges: set name -> list of { id, text, kind, skill / event, min,
-- count, reward, gate }. `kind`: "hits" (land `count` hits with `skill`:
-- a skill key, "ranged" or "dash"), "kills" (the same, kills), "event"
-- (a move's script reports `event` through Quests.Report, with an amount
-- that must reach `min` when there is one; it takes `count` of them) or
-- "total" (the amounts reported for `event` add up to `count`).
-- `gate`: the skill key whose mastery unlocks it (nil: always available).
-- Saved text: "Mandela.1=7;Mandela.2=done" (see encode/decode).
local StatConfig = if script then require(script.Parent:WaitForChild("StatConfig")) else require("./StatConfig")

local QuestConfig = {}

QuestConfig.RewardShare = 1.5 -- a bounty pays this times what its kills pay
QuestConfig.GiverTag = "QuestGiver"
QuestConfig.MaxSaveLength = 1000 -- the saved Challenges text (PlayerStats)
QuestConfig.GiverRange = 15 -- studs from the giver's model you must be within to accept

-- The Bounty Hunters on the map's QuestSpawn parts. A bounty's level is the
-- level you need and what its reward is worked out from; enemyType is the
-- EnemyType attribute set on the enemy models in Studio (Dummy, StrongDummy,
-- Worker, Henchman, Bodyguard, EvilBoss).
QuestConfig.Givers = {
	-- near the start: the training dummies
	Training = {
		name = "Bounty Hunter",
		quests = {
			{ id = "dummies", title = "Dummy Practice", level = 0, enemyType = "Dummy", plural = "Dummies", count = 8 },
			{ id = "strong", title = "Tougher Dummies", level = 5, enemyType = "StrongDummy", plural = "Strong Dummies", count = 8 },
		},
	},
	Frontier = {
		name = "Bounty Hunter",
		quests = {
			{ id = "workers", title = "Clear the Workers", level = 5, enemyType = "Worker", count = 8 },
			{ id = "henchmen", title = "Henchmen Trouble", level = 10, enemyType = "Henchman", plural = "Henchmen", count = 8 },
		},
	},
	Outpost = {
		name = "Bounty Hunter",
		quests = {
			{ id = "bodyguards", title = "Break the Guard", level = 15, enemyType = "Bodyguard", count = 8 },
			{ id = "evilboss", title = "The Evil Boss", level = 40, enemyType = "EvilBoss", plural = "Evil Bosses", count = 1 },
		},
	},
}

QuestConfig.Challenges = {
	Mandela = {
		{ id = 1, text = "Land 15 Axe Boomerang hits", kind = "hits", skill = "Z", count = 15, reward = 150, gate = "Z" },
		{ id = 2, text = "Pull 3 enemies with one Event Horizon", kind = "event", event = "EventHorizonPull", min = 3, count = 1, reward = 400, gate = "X" },
		{ id = 3, text = "Erase 25 hits from players with Misremembered", kind = "event", event = "ErasedPlayerHit", count = 25, reward = 1200 },
		{ id = 4, text = "Kill 3 enemies with one Tornado, 5 times", kind = "event", event = "TornadoKills", min = 3, count = 5, reward = 2000, gate = "C" },
		{ id = 5, text = "Land the axe finisher on someone Event Horizon exposed, 5 times", kind = "event", event = "ExposedFinisher", count = 5, reward = 1000, gate = "X" },
	},
	IridescentRequiem = {
		{ id = 1, text = "Land 20 Light Shots", kind = "hits", skill = "ranged", count = 20, reward = 150 },
		{ id = 2, text = "Hit 3 enemies with one Prism Shot", kind = "event", event = "PrismShotHits", min = 3, count = 1, reward = 400, gate = "Z" },
		{ id = 3, text = "Flash through 10 enemies with Lightstep", kind = "hits", skill = "dash", count = 10, reward = 600 },
		{ id = 4, text = "Fly for 60 s in total", kind = "total", event = "FlightTime", count = 60, reward = 1200 },
		{ id = 5, text = "Hit a Sunmarked target with Solar Lance, 5 times", kind = "event", event = "MarkedLance", count = 5, reward = 1000, gate = "V" },
	},
	Photoshop = {
		{ id = 1, text = "Frame 10 enemies with Snapshot", kind = "event", event = "Framed", count = 10, reward = 150, gate = "Z" },
		{ id = 2, text = "Land all 3 punches of the Step In combo, 5 times", kind = "event", event = "StepInCombo", min = 3, count = 5, reward = 600, gate = "Z" },
		{ id = 3, text = "Cut & Paste an enemy, 5 times", kind = "event", event = "CutPaste", count = 5, reward = 600, gate = "X" },
		{ id = 4, text = "Undo 10 times, healing at least 20 each time", kind = "event", event = "UndoHeal", min = 20, count = 10, reward = 400 },
		{ id = 5, text = "Catch a target in Iris Horizon without them escaping, 5 times", kind = "event", event = "IrisCaught", count = 5, reward = 1000, gate = "V" },
	},
	Revolver = {
		{ id = 1, text = "Land 30 shots", kind = "hits", skill = "ranged", count = 30, reward = 150 },
		{ id = 2, text = "Kill 3 enemies with Dead Eye", kind = "kills", skill = "X", count = 3, reward = 400, gate = "X" },
	},
}

-- what a bounty's texts call its enemies ("Henchmen", "Workers")
function QuestConfig.plural(quest)
	return quest.plural or quest.enemyType .. "s"
end

-- the giver id and quest a taken bounty's id ("giverId/questId", the
-- player's QuestId attribute) names; nil if it names nothing
function QuestConfig.parseQuestId(id)
	if typeof(id) ~= "string" then
		return nil
	end
	local giverId, questId = string.match(id, "^(.-)/(.+)$")
	local giver = giverId and QuestConfig.Givers[giverId]
	for _, quest in ipairs(giver and giver.quests or {}) do
		if quest.id == questId then
			return giverId, quest
		end
	end
	return nil
end

-- the saved id of a challenge: "Mandela.1"
local known = {}
for setName, list in pairs(QuestConfig.Challenges) do
	for _, challenge in ipairs(list) do
		known[setName .. "." .. challenge.id] = true
	end
end

-- the XP and yen a bounty of `count` kills at `level` pays on completion
function QuestConfig.reward(count, level)
	local xp = math.floor(QuestConfig.RewardShare * count * StatConfig.EnemyXP(level))
	local yen = math.floor(QuestConfig.RewardShare * count * StatConfig.EnemyYen(level))
	return xp, yen
end

-- progress (id -> a count, or "done") as the text PlayerStats saves, in a
-- stable order
function QuestConfig.encode(progress)
	local ids = {}
	for id in pairs(progress) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts = {}
	for _, id in ipairs(ids) do
		table.insert(parts, id .. "=" .. tostring(progress[id]))
	end
	return table.concat(parts, ";")
end

-- saved text back to progress; anything wrong in it (a bad entry, an id that
-- isn't a challenge any more, text over the limit) is dropped
function QuestConfig.decode(text)
	local progress = {}
	if typeof(text) ~= "string" or #text > QuestConfig.MaxSaveLength then
		return progress
	end
	for piece in string.gmatch(text, "[^;]+") do
		local id, value = string.match(piece, "^(%w+%.%d+)=(%w+)$")
		if id and known[id] then
			if value == "done" then
				progress[id] = "done"
			else
				local number = tonumber(value)
				if number and number >= 0 then
					progress[id] = math.floor(number)
				end
			end
		end
	end
	return progress
end

-- A challenge's progress after one more of it. `current` is a count, "done"
-- or nil; `amount` is the size of an event (a hit or a kill is always one;
-- a total adds it up, rounded to a whole number).
-- Returns the new progress and whether this is the moment it was completed.
function QuestConfig.advance(challenge, current, amount)
	if current == "done" then
		return "done", false
	end
	if challenge.kind == "total" then
		local add = type(amount) == "number" and amount == amount and math.floor(amount + 0.5) or 0
		if add <= 0 then
			return current or 0, false
		end
		current = (current or 0) + add
		if current >= challenge.count then
			return "done", true
		end
		return current, false
	end
	current = current or 0
	if challenge.kind == "event" and challenge.min and (amount or 1) < challenge.min then
		return current, false
	end
	current += 1
	if current >= challenge.count then
		return "done", true
	end
	return current, false
end

return QuestConfig
