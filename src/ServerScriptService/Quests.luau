-- Quests (rules and data: ReplicatedStorage.QuestConfig), two kinds:
-- Bounties: a player takes one level quest at a time from a Bounty Hunter
-- (an NPC tagged QuestGiver with a GiverId attribute; Accept checks their
-- level and that they stand near that giver). Each kill of a model whose
-- EnemyType matches counts, and the moment the count is reached the reward
-- is paid. It lives in the player's QuestId ("giverId/questId") and
-- QuestProgress attributes, so the client can draw the tracker; leaving
-- drops it, dying doesn't.
-- Challenges: per skill set, done once, paying mastery XP. Hits and kills
-- come from Damage (OnHit / OnKill, wired by QuestServer) using the move
-- each damage call is tagged with (options.skill); events come from the
-- moves themselves through Quests.Report. Progress is kept in the saved
-- Challenges attribute (QuestConfig.encode / decode) and only counts once
-- the move's mastery is unlocked (`gate`).
-- The QuestDone remote tells the client to show a popup: (kind "bounty" or
-- "challenge", title, reward table { xp, yen } or { mastery, set }).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local Quests = {}

local questRemote = Instance.new("RemoteEvent")
questRemote.Name = "Quest"
questRemote.Parent = ReplicatedStorage
Quests.Remote = questRemote -- "accept", giverId, questId / "abandon" (QuestServer connects it)

local doneRemote = Instance.new("RemoteEvent")
doneRemote.Name = "QuestDone"
doneRemote.Parent = ReplicatedStorage

local ID_ATTRIBUTE = "QuestId"
local PROGRESS_ATTRIBUTE = "QuestProgress"
local SAVED_ATTRIBUTE = "Challenges"

-- Bounties

-- the giver and quest the player has taken, if any
function Quests.Current(player)
	local id = player:GetAttribute(ID_ATTRIBUTE)
	if typeof(id) ~= "string" then
		return nil
	end
	local giverId, questId = string.match(id, "^(.-)/(.+)$")
	local giver = giverId and QuestConfig.Givers[giverId]
	if not giver then
		return nil
	end
	for _, quest in ipairs(giver.quests) do
		if quest.id == questId then
			return giverId, quest
		end
	end
	return nil
end

local function clear(player)
	player:SetAttribute(ID_ATTRIBUTE, nil)
	player:SetAttribute(PROGRESS_ATTRIBUTE, nil)
end

-- whether the player is within reach of a model tagged QuestGiver with this GiverId
local function nearGiver(player, giverId)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, model in ipairs(CollectionService:GetTagged(QuestConfig.GiverTag)) do
		if model:GetAttribute("GiverId") == giverId and model:IsDescendantOf(workspace) then
			if (model:GetPivot().Position - root.Position).Magnitude <= QuestConfig.GiverRange then
				return true
			end
		end
	end
	return false
end

-- takes a bounty from a giver, replacing the one they had; returns whether
-- it worked and why not
function Quests.Accept(player, giverId, questId)
	if typeof(giverId) ~= "string" or typeof(questId) ~= "string" then
		return false, "Unknown bounty"
	end
	local giver = QuestConfig.Givers[giverId]
	local quest
	for _, candidate in ipairs(giver and giver.quests or {}) do
		if candidate.id == questId then
			quest = candidate
		end
	end
	local level = player:GetAttribute("Level")
	if not quest or not level then
		return false, "Unknown bounty"
	end
	if level < quest.level then
		return false, "Level " .. quest.level .. " needed"
	end
	if not nearGiver(player, giverId) then
		return false, "Too far from the Bounty Hunter"
	end
	player:SetAttribute(ID_ATTRIBUTE, giverId .. "/" .. questId)
	player:SetAttribute(PROGRESS_ATTRIBUTE, 0)
	return true
end

function Quests.Abandon(player)
	clear(player)
end

local function completeBounty(player, quest)
	clear(player)
	local xp, yen = QuestConfig.reward(quest.count, quest.level)
	PlayerStats.AddXP(player, xp)
	PlayerStats.AddYen(player, yen)
	doneRemote:FireClient(player, "bounty", quest.title, { xp = xp, yen = yen })
end

-- Challenges

-- the player's challenge progress (id -> count or "done"), decoded from the
-- saved attribute and kept until the attribute changes; nil while it loads
local caches = setmetatable({}, { __mode = "k" })
local function progressOf(player)
	local text = player:GetAttribute(SAVED_ATTRIBUTE)
	if typeof(text) ~= "string" then
		return nil
	end
	local cache = caches[player]
	if not cache or cache.text ~= text then
		cache = { text = text, data = QuestConfig.decode(text) }
		caches[player] = cache
	end
	return cache
end

-- whether the move a challenge is about is unlocked for this player
local function unlocked(player, setName, challenge)
	if not challenge.gate then
		return true
	end
	local set = SkillSetConfig.Sets[setName]
	local skill = set and set.skills and set.skills[challenge.gate]
	if not skill or not skill.mastery then
		return true
	end
	return (player:GetAttribute(SkillSetConfig.MasteryAttribute(setName)) or 1) >= skill.mastery
end

-- one more of a challenge; pays its mastery XP the first time it's done
local function bump(player, setName, challenge, amount)
	local cache = progressOf(player)
	if not cache or not unlocked(player, setName, challenge) then
		return
	end
	local id = setName .. "." .. challenge.id
	local before = cache.data[id]
	local after, finished = QuestConfig.advance(challenge, before, amount)
	if after == before then
		return
	end
	cache.data[id] = after
	local text = QuestConfig.encode(cache.data)
	cache.text = text
	player:SetAttribute(SAVED_ATTRIBUTE, text)
	if finished then
		PlayerStats.AddMasteryXP(player, setName, challenge.reward)
		doneRemote:FireClient(player, "challenge", challenge.text, { mastery = challenge.reward, set = setName })
	end
end

-- a move's script says something happened (`event` names a challenge's event;
-- `amount` is its size, when it has one), after it has really happened
function Quests.Report(player, setName, event, amount)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	for _, challenge in ipairs(QuestConfig.Challenges[setName] or {}) do
		if challenge.kind == "event" and challenge.event == event then
			bump(player, setName, challenge, amount)
		end
	end
end

-- Damage.OnDealt: a hit that landed
function Quests.OnHit(attacker, humanoid, _dealt, options)
	if not attacker or options.dot or not options.skillSet or not options.skill then
		return
	end
	if Players:GetPlayerFromCharacter(humanoid.Parent) == attacker then
		return
	end
	for _, challenge in ipairs(QuestConfig.Challenges[options.skillSet] or {}) do
		if challenge.kind == "hits" and challenge.skill == options.skill then
			bump(attacker, options.skillSet, challenge)
		end
	end
end

-- Damage.OnKill: `killer` got the kill of `victim` (a character) with `hit`
-- (Damage.LastHit: its skillSet and skill)
function Quests.OnKill(killer, victim, hit, victimIsPlayer)
	if not victimIsPlayer then
		local _, quest = Quests.Current(killer)
		if quest and victim:GetAttribute("EnemyType") == quest.enemyType then
			local progress = (killer:GetAttribute(PROGRESS_ATTRIBUTE) or 0) + 1
			if progress >= quest.count then
				completeBounty(killer, quest)
			else
				killer:SetAttribute(PROGRESS_ATTRIBUTE, progress)
			end
		end
	end
	if hit and hit.skillSet and hit.skill then
		for _, challenge in ipairs(QuestConfig.Challenges[hit.skillSet] or {}) do
			if challenge.kind == "kills" and challenge.skill == hit.skill then
				bump(killer, hit.skillSet, challenge)
			end
		end
	end
end

function Quests.Forget(player)
	caches[player] = nil
end

return Quests
