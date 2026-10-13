-- Whether a character can't act right now: Photoshop's Undo is carrying her
-- back (Rewinding), they're holding a block (Blocking, Guard) or stunned
-- (HitstunUntil, a guard break or an NPC's hitstun). The server's cast
-- checks and the client's input scripts both ask here, so a new reason to
-- be locked goes in one place.
local ActionLock = {}

function ActionLock.Locked(character)
	if not character then
		return false
	end
	return character:GetAttribute("Rewinding") == true
		or character:GetAttribute("Blocking") == true
		or (character:GetAttribute("HitstunUntil") or 0) > workspace:GetServerTimeNow()
end

return ActionLock
