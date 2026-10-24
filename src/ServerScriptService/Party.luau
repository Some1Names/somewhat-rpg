-- Parties of up to PartyRules.MaxMembers players. The server keeps the parties
-- (PartyRules has the rules) and mirrors each to its members as attributes:
-- PartyId, PartyLeader (the leader's user id) and PartyIndex (1 = leader), all
-- cleared when you leave. An invite sits on the target as PartyInvite
-- ("<from user id>|<expires>", server time). PartyNotice carries a line for the
-- client to show. Players use these through the PartyAction remote (PartyServer).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyRules = require(ReplicatedStorage:WaitForChild("PartyRules"))

local Party = {}

local parties = {} -- id -> party
local partyOf = setmetatable({}, { __mode = "k" }) -- player -> party
local nextId = 0

local function notify(player, text)
	player:SetAttribute("PartyNotice", text .. "|" .. os.clock()) -- the client shows the text part
end

local function playersOf(party)
	local list = {}
	for _, userId in ipairs(party.members) do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			table.insert(list, member)
		end
	end
	return list
end

local function clearMember(player)
	partyOf[player] = nil
	player:SetAttribute("PartyId", nil)
	player:SetAttribute("PartyLeader", nil)
	player:SetAttribute("PartyIndex", nil)
end

local function publish(party)
	for index, userId in ipairs(party.members) do
		local member = Players:GetPlayerByUserId(userId)
		if member then
			partyOf[member] = party
			member:SetAttribute("PartyId", party.id)
			member:SetAttribute("PartyLeader", party.leader)
			member:SetAttribute("PartyIndex", index)
		end
	end
end

local function tell(party, text, except)
	for _, member in ipairs(playersOf(party)) do
		if member ~= except then
			notify(member, text)
		end
	end
end

local function openInvite(player)
	local from, expires = PartyRules.DecodeInvite(player:GetAttribute("PartyInvite"))
	if from and PartyRules.InviteOpen(expires, workspace:GetServerTimeNow()) then
		return from, expires
	end
	return nil
end

local function clearInvite(player)
	player:SetAttribute("PartyInvite", nil)
end

function Party.Of(player)
	return partyOf[player]
end

-- the other members of `player`'s party (not including them)
function Party.Mates(player)
	local party = partyOf[player]
	local list = {}
	if party then
		for _, member in ipairs(playersOf(party)) do
			if member ~= player then
				table.insert(list, member)
			end
		end
	end
	return list
end

function Party.Invite(inviter, target)
	local party = partyOf[inviter]
	local ok, reason = PartyRules.CanInvite(party, inviter.UserId, target.UserId, partyOf[target], openInvite(target) ~= nil)
	if not ok then
		return false, reason
	end
	local expires = workspace:GetServerTimeNow() + PartyRules.InviteTime
	local text = PartyRules.EncodeInvite(inviter.UserId, expires)
	target:SetAttribute("PartyInvite", text)
	notify(target, inviter.DisplayName .. " invited you to a party")
	task.delay(PartyRules.InviteTime + 1, function()
		if target.Parent and target:GetAttribute("PartyInvite") == text then
			clearInvite(target)
		end
	end)
	return true, "Invited " .. target.DisplayName
end

function Party.Accept(player)
	local fromId = openInvite(player)
	if not fromId then
		clearInvite(player)
		return false, "That invite is gone"
	end
	local inviter = Players:GetPlayerByUserId(fromId)
	if not inviter then
		clearInvite(player)
		return false, "They left the game"
	end
	local party = partyOf[inviter]
	local ok, reason = PartyRules.CanJoin(party, player.UserId, partyOf[player])
	if not ok then
		clearInvite(player)
		return false, reason
	end
	if party and party.leader ~= inviter.UserId then
		clearInvite(player)
		return false, "Only the party leader can invite"
	end
	if not party then
		nextId += 1
		party = PartyRules.New("P" .. nextId, inviter.UserId)
		parties[party.id] = party
	end
	if not PartyRules.Add(party, player.UserId) then
		clearInvite(player)
		return false, "That party is full"
	end
	clearInvite(player)
	publish(party)
	tell(party, player.DisplayName .. " joined the party", player)
	return true, "Joined the party"
end

function Party.Decline(player)
	local fromId = openInvite(player)
	clearInvite(player)
	local inviter = fromId and Players:GetPlayerByUserId(fromId)
	if inviter then
		notify(inviter, player.DisplayName .. " declined your invite")
	end
	return true, "Declined"
end

function Party.Leave(player)
	local party = partyOf[player]
	if not party then
		return false, "You aren't in a party"
	end
	clearMember(player)
	local remaining = PartyRules.Remove(party, player.UserId)
	if remaining then
		publish(remaining)
		tell(remaining, player.DisplayName .. " left the party")
	else
		parties[party.id] = nil
		for _, member in ipairs(playersOf(party)) do
			clearMember(member)
			notify(member, "The party was disbanded")
		end
	end
	return true, "You left the party"
end

function Party.Kick(leader, targetUserId)
	local party = partyOf[leader]
	if not party then
		return false, "You aren't in a party"
	end
	local ok, reason = PartyRules.CanKick(party, leader.UserId, targetUserId)
	if not ok then
		return false, reason
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		clearMember(target)
		notify(target, "You were removed from the party")
	end
	local remaining = PartyRules.Remove(party, targetUserId)
	if remaining then
		publish(remaining)
		tell(remaining, (target and target.DisplayName or "A member") .. " was removed")
	else
		parties[party.id] = nil
		for _, member in ipairs(playersOf(party)) do
			clearMember(member)
			notify(member, "The party was disbanded")
		end
	end
	return true, "Removed"
end

function Party.Promote(leader, targetUserId)
	local party = partyOf[leader]
	if not party or not PartyRules.Promote(party, leader.UserId, targetUserId) then
		return false, "Can't do that"
	end
	publish(party)
	local target = Players:GetPlayerByUserId(targetUserId)
	tell(party, (target and target.DisplayName or "Someone") .. " is now the leader")
	return true, "Leader changed"
end

Players.PlayerRemoving:Connect(function(player)
	if partyOf[player] then
		Party.Leave(player)
	end
end)

return Party
