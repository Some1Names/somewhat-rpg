-- Unit tests for ReplicatedStorage.PartyRules (inviting, joining, leaving, kicking,
-- promoting, invite text). Run with Lune, outside Roblox: tests/run.sh.
local R = require("../src/ReplicatedStorage/PartyRules")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

check("a party holds 4", R.MaxMembers == 4)

local party = R.New("P1", 10)
check("new party has its leader", party.leader == 10 and #party.members == 1 and R.Has(party, 10))

check("anyone alone can invite a free player", R.CanInvite(nil, 10, 20, nil, false))
check("can't invite yourself", not R.CanInvite(nil, 10, 10, nil, false))
check("can't invite someone in a party", not R.CanInvite(nil, 10, 20, party, false))
check("can't invite someone with an invite", not R.CanInvite(nil, 10, 20, nil, true))
check("only the leader invites", R.Add(party, 20) and not R.CanInvite(party, 20, 30, nil, false) and R.CanInvite(party, 10, 30, nil, false))

check("add refuses a duplicate", not R.Add(party, 20))
R.Add(party, 30)
R.Add(party, 40)
check("a full party takes no more", R.IsFull(party) and not R.Add(party, 50))
check("no invite from a full party", not R.CanInvite(party, 10, 50, nil, false))
check("can't join a full party", not R.CanJoin(party, 50, nil))
check("can't join while in a party", not R.CanJoin(nil, 50, party))
check("can join a free or new party", R.CanJoin(nil, 50, nil) and R.CanJoin(R.New("P2", 1), 50, nil))

check("kick needs the leader and a member", R.CanKick(party, 10, 20) and not R.CanKick(party, 20, 30) and not R.CanKick(party, 10, 10) and not R.CanKick(party, 10, 99))

check("promote moves the lead", R.Promote(party, 10, 30) and party.leader == 30 and party.members[1] == 30)
check("only the leader promotes", not R.Promote(party, 10, 20))

local left = R.Remove(party, 30)
check("the leader leaving hands over the lead", left == party and party.leader ~= 30 and party.leader == party.members[1] and #party.members == 3)
R.Remove(party, 20)
check("a member leaving keeps the party", #party.members == 2)
check("a party of one is gone", R.Remove(party, party.members[2]) == nil)
check("removing a stranger changes nothing", R.Remove(R.New("P3", 1), 99) ~= nil)

local from, expires = R.DecodeInvite(R.EncodeInvite(123, 45.5))
check("invite text round-trips", from == 123 and expires == 45.5)
check("bad invite text is nil", R.DecodeInvite("") == nil and R.DecodeInvite("x|1") == nil and R.DecodeInvite(nil) == nil)
check("invite open until it expires", R.InviteOpen(10, 9.9) and not R.InviteOpen(10, 10) and not R.InviteOpen(nil, 0))

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all passed")
