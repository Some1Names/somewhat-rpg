-- Whether a character can't act right now: Photoshop's Undo is carrying her
-- back (Rewinding), they're holding a block (Blocking, Guard) or stunned
-- (HitstunUntil, a guard break or an NPC's hitstun). The server's cast
-- checks and the client's input scripts both ask here, so a new reason to
-- be locked goes in one place. Holding a power briefcase (a Tool with the
-- PowerBriefcase attribute) locks too: you can't fight with an item in hand. InWater is its own question (you can still
-- block while swimming) and Busy asks both: skills, punches and shots ask
-- that.
local Water = require(script.Parent:WaitForChild("Water"))

local ActionLock = {}

-- whether the character has a power briefcase in hand
function ActionLock.HoldingBriefcase(character)
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("PowerBriefcase") ~= nil
end

function ActionLock.Locked(character)
	if not character then
		return false
	end
	return ActionLock.HoldingBriefcase(character)
		or character:GetAttribute("Rewinding") == true
		or character:GetAttribute("Blocking") == true
		or (character:GetAttribute("HitstunUntil") or 0) > workspace:GetServerTimeNow()
end

-- whether the character is in the map's water (you can't fight or dash there)
function ActionLock.InWater(character)
	return Water.IsIn(character)
end

-- Locked, or in the water
function ActionLock.Busy(character)
	return ActionLock.Locked(character) or ActionLock.InWater(character)
end

return ActionLock
