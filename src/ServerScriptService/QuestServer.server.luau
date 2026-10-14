-- Wires the Quests module to the game (the rules are in Quests): the Quest
-- remote from the Bounty Hunter's panel and the Quests menu ("accept",
-- giverId, questId / "abandon"), and Damage's hits and kills, which count
-- for challenges and bounties.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Quests = require(ServerScriptService:WaitForChild("Quests"))

local THROTTLE = 0.25 -- seconds between requests a player may make
local lastRequest = setmetatable({}, { __mode = "k" })

Quests.Remote.OnServerEvent:Connect(function(player, action, giverId, questId)
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < THROTTLE then
		return
	end
	lastRequest[player] = now
	if action == "accept" then
		Quests.Accept(player, giverId, questId)
	elseif action == "abandon" then
		Quests.Abandon(player)
	end
end)

Damage.OnDealt(Quests.OnHit)
Damage.OnKill(Quests.OnKill)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
	Quests.Forget(player)
end)
