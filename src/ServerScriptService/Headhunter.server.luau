-- Death stakes and the Headhunter (numbers and rules in
-- ReplicatedStorage.HeadhunterConfig).
-- Every player death drops DropShare of the victim's yen
-- (PlayerStats.TakeYen); the player who gets the kill (the kill feed's rule:
-- the last player to hit them within CreditTime, not themselves) receives
-- it, unless they already killed that player within RepeatWindow
-- (KillRecords): then it's gone, and the kill earns nothing else either.
-- The victim's LastDeathYenLost attribute tells their death screen.
-- Paid kills of players count towards HeadhunterKills (a player attribute,
-- this server only). The kill leader, at MinKills or more, is the Headhunter
-- (ReplicatedStorage's Headhunter attribute, their UserId): a tie stays with
-- the holder, passing them moves the mark. The Headhunter drops
-- HeadhunterDropShare instead; whoever takes their head (a paid kill) also
-- gets bonus XP. However the Headhunter dies, the mark ends and every count
-- goes back to 0. Leaving ends it too, and a Headhunter who fought within
-- LeaveCombatWindow loses their share as they go (PlayerStats.BeforeLeave,
-- before the save; not when the server shuts down).
-- Clients hear about it on the KillFeed remote as ("Headhunter", kind,
-- nameA, nameB, xp, yen): "crowned" (A is the Headhunter), "taken" (B took
-- A's head) or "fell" (A's mark ended any other way).
-- In Studio, killing a KillFeedDummy counts as a player kill (no yen), so the
-- mark can be tried alone.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local HeadhunterConfig = require(ReplicatedStorage:WaitForChild("HeadhunterConfig"))
local KillRecords = require(ServerScriptService:WaitForChild("KillRecords"))
local PlayerStats = require(ServerScriptService:WaitForChild("PlayerStats"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))

local feed = ReplicatedStorage:WaitForChild("KillFeed")

local MARK = "Headhunter" -- on ReplicatedStorage: the Headhunter's UserId, or nil
local KILLS = "HeadhunterKills" -- on each player
local YEN_LOST = "LastDeathYenLost" -- on each player, for their death screen
local DUMMY_TAG = "KillFeedDummy"

local reachedAt = {} -- UserId -> os.clock() when they reached their current count
local lastCombatAt = setmetatable({}, { __mode = "k" }) -- player -> os.clock() of their last hit dealt or taken

local function isHeadhunter(player)
	return player ~= nil and ReplicatedStorage:GetAttribute(MARK) == player.UserId
end

-- the mark ends: nobody holds it and every count starts again
local function endMark()
	ReplicatedStorage:SetAttribute(MARK, nil)
	table.clear(reachedAt)
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute(KILLS, 0)
	end
end

-- after a count changed: the leader takes the mark (or keeps it)
local function repick()
	local counts = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local kills = player:GetAttribute(KILLS) or 0
		if kills > 0 then
			counts[player.UserId] = kills
		end
	end
	local id = HeadhunterConfig.leader(counts, reachedAt)
	if id == ReplicatedStorage:GetAttribute(MARK) then
		return
	end
	ReplicatedStorage:SetAttribute(MARK, id)
	local holder = id and Players:GetPlayerByUserId(id)
	if holder then
		feed:FireAllClients("Headhunter", "crowned", holder.DisplayName, nil, 0, 0)
	end
end

-- the player who gets the kill, as the kill feed decides it, or nil
local function killerOf(victim, humanoid)
	local killer = Damage.LastAttacker(humanoid)
	local hit = Damage.LastHit(humanoid)
	if killer and killer ~= victim and killer.Parent and hit and os.clock() - hit.at <= HeadhunterConfig.CreditTime then
		return killer
	end
	return nil
end

-- `victim` (a player, or nil for a Studio dummy) has died
local function onDeath(victim, humanoid)
	local killer = killerOf(victim, humanoid)
	-- a repeat kill pays nothing, but the victim still loses their yen
	local repeatKill = false
	if killer and victim then
		repeatKill = KillRecords.IsRepeat(killer, victim)
		KillRecords.Record(killer, victim)
	end
	local paid = killer ~= nil and not repeatKill
	local wasHeadhunter = isHeadhunter(victim)

	local yen = 0
	if victim then
		local lost = PlayerStats.TakeYen(victim, wasHeadhunter and HeadhunterConfig.HeadhunterDropShare or HeadhunterConfig.DropShare)
		victim:SetAttribute(YEN_LOST, lost)
		if paid and lost > 0 then
			PlayerStats.AddYen(killer, lost)
			yen = lost
		end
	end
	if paid then
		killer:SetAttribute(KILLS, (killer:GetAttribute(KILLS) or 0) + 1)
		reachedAt[killer.UserId] = os.clock()
	end

	if wasHeadhunter then
		if paid then
			local xp = HeadhunterConfig.bonusXP(StatConfig.XPToLevelUp(killer:GetAttribute("Level") or 0), victim:GetAttribute(KILLS) or 0)
			PlayerStats.AddXP(killer, xp)
			feed:FireAllClients("Headhunter", "taken", victim.DisplayName, killer.DisplayName, xp, yen)
		else
			-- an NPC, a fall, a reset or a repeat kill: nobody takes the head
			feed:FireAllClients("Headhunter", "fell", victim.DisplayName, nil, 0, 0)
		end
		endMark()
	elseif paid then
		repick()
	end
end

local function watchCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	if player then
		player:SetAttribute(YEN_LOST, nil) -- a new life: the last death's loss is old news
	end
	humanoid.Died:Once(function()
		onDeath(player, humanoid)
	end)
end

local function watchPlayer(player)
	player:SetAttribute(KILLS, 0)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(watchPlayer, player)
end

-- fighting: anyone who deals or takes a hit, against anything
Damage.OnDealt(function(attacker, humanoid, dealt)
	if dealt <= 0 then
		return
	end
	local now = os.clock()
	if attacker then
		lastCombatAt[attacker] = now
	end
	local victim = humanoid.Parent and Players:GetPlayerFromCharacter(humanoid.Parent)
	if victim then
		lastCombatAt[victim] = now
	end
end)

-- leaving mid-fight costs the Headhunter their share, before PlayerStats saves
PlayerStats.BeforeLeave(function(player)
	local foughtAt = lastCombatAt[player]
	if isHeadhunter(player) and foughtAt and os.clock() - foughtAt <= HeadhunterConfig.LeaveCombatWindow then
		PlayerStats.TakeYen(player, HeadhunterConfig.HeadhunterDropShare)
	end
end)

-- anyone leaving takes their count with them; the Headhunter takes the mark.
-- Deferred, so the leave penalty above has run first (it checks the mark)
Players.PlayerRemoving:Connect(function(player)
	task.defer(function()
		reachedAt[player.UserId] = nil
		if isHeadhunter(player) then
			feed:FireAllClients("Headhunter", "fell", player.DisplayName, nil, 0, 0)
			endMark()
		else
			repick()
		end
	end)
end)

-- Studio only: the kill feed's test dummies count as players to kill
if RunService:IsStudio() then
	local function watchDummy(model)
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			task.spawn(watchCharacter, nil, model)
		end
	end
	CollectionService:GetInstanceAddedSignal(DUMMY_TAG):Connect(watchDummy)
	for _, model in ipairs(CollectionService:GetTagged(DUMMY_TAG)) do
		watchDummy(model)
	end
end
