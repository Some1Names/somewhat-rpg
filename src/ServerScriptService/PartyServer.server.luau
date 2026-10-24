-- The PartyAction remote: the Party tab's buttons. Every action is checked in Party
-- (PartyRules); this only checks the arguments and spaces a player's requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Party = require(script.Parent:WaitForChild("Party"))
local PartyRules = require(ReplicatedStorage:WaitForChild("PartyRules"))

local action = Instance.new("RemoteFunction")
action.Name = "PartyAction"
action.Parent = ReplicatedStorage

local lastRequest = setmetatable({}, { __mode = "k" })

action.OnServerInvoke = function(player, kind, userId)
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < PartyRules.ActionInterval then
		return false, "Slow down"
	end
	lastRequest[player] = now
	if kind == "accept" then
		return Party.Accept(player)
	elseif kind == "decline" then
		return Party.Decline(player)
	elseif kind == "leave" then
		return Party.Leave(player)
	end
	if typeof(userId) ~= "number" then
		return false, "Bad request"
	end
	if kind == "invite" then
		local target = Players:GetPlayerByUserId(userId)
		if not target then
			return false, "They left the game"
		end
		return Party.Invite(player, target)
	elseif kind == "kick" then
		return Party.Kick(player, userId)
	elseif kind == "promote" then
		return Party.Promote(player, userId)
	end
	return false, "Bad request"
end
