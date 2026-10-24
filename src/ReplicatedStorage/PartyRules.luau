-- Parties: the numbers and the pure rules, free of Roblox types so Lune can test
-- them (tests/PartyRules.spec.luau). A party is { id, leader, members } with user
-- ids, the leader first; the server module Party keeps them and mirrors them to
-- each member as the PartyId / PartyLeader / PartyIndex attributes. An invite is
-- the target's PartyInvite attribute, "<from user id>|<expires, server time>".
local PartyRules = {}

PartyRules.MaxMembers = 4
PartyRules.InviteTime = 30 -- seconds an invite stays open
PartyRules.ActionInterval = 0.3 -- least seconds between one player's party actions

function PartyRules.New(id, leaderId)
	return { id = id, leader = leaderId, members = { leaderId } }
end

function PartyRules.IsFull(party)
	return #party.members >= PartyRules.MaxMembers
end

function PartyRules.Has(party, userId)
	return party ~= nil and table.find(party.members, userId) ~= nil
end

-- can `inviterId` (in `party`, or nil when alone) invite `targetId`?
-- `targetParty` is the target's party, `targetHasInvite` whether they hold an open invite.
-- Returns ok, reason.
function PartyRules.CanInvite(party, inviterId, targetId, targetParty, targetHasInvite)
	if inviterId == targetId then
		return false, "You can't invite yourself"
	end
	if party and party.leader ~= inviterId then
		return false, "Only the party leader can invite"
	end
	if party and PartyRules.IsFull(party) then
		return false, "Your party is full"
	end
	if targetParty then
		return false, "They are already in a party"
	end
	if targetHasInvite then
		return false, "They already have an invite"
	end
	return true, ""
end

-- can `userId`, in no party, join `party` (nil: the inviter's party hasn't been made yet)?
function PartyRules.CanJoin(party, userId, ownParty)
	if ownParty then
		return false, "Leave your party first"
	end
	if party and PartyRules.IsFull(party) then
		return false, "That party is full"
	end
	return true, ""
end

function PartyRules.Add(party, userId)
	if PartyRules.IsFull(party) or PartyRules.Has(party, userId) then
		return false
	end
	table.insert(party.members, userId)
	return true
end

-- takes `userId` out. Returns the party, or nil once fewer than 2 remain (it is gone).
-- The leader leaving hands the lead to the next member.
function PartyRules.Remove(party, userId)
	local index = table.find(party.members, userId)
	if not index then
		return party
	end
	table.remove(party.members, index)
	if #party.members < 2 then
		return nil
	end
	if party.leader == userId then
		party.leader = party.members[1]
	end
	return party
end

function PartyRules.CanKick(party, byId, targetId)
	if party.leader ~= byId then
		return false, "Only the party leader can kick"
	end
	if byId == targetId or not PartyRules.Has(party, targetId) then
		return false, "Not a member"
	end
	return true, ""
end

-- makes `targetId` the leader and moves them to the front; false if not allowed
function PartyRules.Promote(party, byId, targetId)
	if party.leader ~= byId or byId == targetId or not PartyRules.Has(party, targetId) then
		return false
	end
	table.remove(party.members, table.find(party.members, targetId))
	table.insert(party.members, 1, targetId)
	party.leader = targetId
	return true
end

function PartyRules.EncodeInvite(fromId, expires)
	return string.format("%d|%.2f", fromId, expires)
end

-- "from|expires" -> fromId, expires (nil if it isn't one)
function PartyRules.DecodeInvite(text)
	local from, expires = string.match(text or "", "^(%d+)|([%d%.]+)$")
	if not from then
		return nil
	end
	return tonumber(from), tonumber(expires)
end

function PartyRules.InviteOpen(expires, now)
	return expires ~= nil and now < expires
end

return PartyRules
