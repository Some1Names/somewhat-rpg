-- Crowd-control protection for players (PvP). A pull, yank, knockback, stun
-- or snap only takes a player who isn't already under one, and once it wears
-- off they can't be controlled again for IMMUNITY seconds. Damage still
-- lands either way. NPCs can always be controlled. The player's character
-- carries the CCImmuneUntil attribute (server time).
-- A player can always get out: a hold with no set length (a black hole's
-- pull, a tornado) lets them go after MaxHold seconds, and a dodge (Q, see
-- DashRelay) breaks it at once and also slips a mark waiting to snap them
-- (Overcome the Possibility).
local Players = game:GetService("Players")

local IMMUNITY = 2.5 -- seconds after a hold on a player ends
local HELD = 1e9 -- far-off time standing in for "until End is called"
local ATTRIBUTE = "CCImmuneUntil"

local CrowdControl = {}
CrowdControl.MaxHold = 1.5 -- seconds a hold with no set length keeps a player

local holdEnds = setmetatable({}, { __mode = "k" }) -- player character -> os.clock() its hold lets go
local lastDodge = setmetatable({}, { __mode = "k" }) -- player character -> os.clock() of their last dodge

local function isPlayer(model)
	return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
end

-- may this character be moved or stunned right now?
function CrowdControl.CanControl(model)
	if not isPlayer(model) then
		return true
	end
	return (model:GetAttribute(ATTRIBUTE) or 0) <= workspace:GetServerTimeNow()
end

-- a hold lasting `duration` seconds starts now (a knockback, yank, stun)
function CrowdControl.Apply(model, duration)
	if isPlayer(model) then
		model:SetAttribute(ATTRIBUTE, workspace:GetServerTimeNow() + duration + IMMUNITY)
	end
end

-- a hold with no set length (dragged by a black hole or carried by a
-- tornado): nothing else can take them meanwhile, and End starts the immunity
function CrowdControl.Begin(model)
	if isPlayer(model) then
		model:SetAttribute(ATTRIBUTE, workspace:GetServerTimeNow() + HELD)
		holdEnds[model] = os.clock() + CrowdControl.MaxHold
	end
end

-- whether a Begun hold should keep going; once it's false the skill lets go
-- and calls End (always true for NPCs)
function CrowdControl.Holding(model)
	if not isPlayer(model) then
		return true
	end
	return os.clock() < (holdEnds[model] or 0)
end

function CrowdControl.End(model)
	-- the character may be gone already (died, or a dummy respawned)
	if model == nil then
		return
	end
	holdEnds[model] = nil
	if isPlayer(model) then
		model:SetAttribute(ATTRIBUTE, workspace:GetServerTimeNow() + IMMUNITY)
	end
end

-- the player dodged: any hold on them lets go
function CrowdControl.Dodge(model)
	lastDodge[model] = os.clock()
	if holdEnds[model] then
		holdEnds[model] = 0
	end
end

-- whether they've dodged since the os.clock() time `since`
function CrowdControl.DodgedSince(model, since)
	return (lastDodge[model] or -math.huge) >= since
end

return CrowdControl
