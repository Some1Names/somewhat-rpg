-- When each player's skills are ready again: SkillSetServer checks and spends
-- them, AdminServer can clear them. A reset also bumps the player's
-- CooldownsResetAt attribute so their skill bar drops its own prediction.
-- A skill with charges keeps one time too: when all its charges are back.
-- Each cast pushes that one recharge later, and a charge is ready while
-- it's less than (charges - 1) recharges away (Ready).
local Players = game:GetService("Players")

local SkillCooldowns = {}

local readyAt = {} -- player -> { ["Mandela.X"] = os.clock() it's ready again }

function SkillCooldowns.ReadyAt(player, id)
	local playerCooldowns = readyAt[player]
	return playerCooldowns and playerCooldowns[id] or 0
end

function SkillCooldowns.Start(player, id, duration)
	readyAt[player] = readyAt[player] or {}
	readyAt[player][id] = os.clock() + duration
end

-- whether a charge (or the one use, for a skill without charges) is ready,
-- give or take `tolerance` seconds
function SkillCooldowns.Ready(player, id, duration, charges, tolerance)
	return os.clock() >= SkillCooldowns.ReadyAt(player, id) - ((charges or 1) - 1) * duration - (tolerance or 0)
end

-- uses a charge: it takes `duration` more to have them all back
function SkillCooldowns.Spend(player, id, duration)
	readyAt[player] = readyAt[player] or {}
	readyAt[player][id] = math.max(SkillCooldowns.ReadyAt(player, id), os.clock()) + duration
end

function SkillCooldowns.Reset(player)
	readyAt[player] = nil
	player:SetAttribute("CooldownsResetAt", workspace:GetServerTimeNow())
end

Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)

return SkillCooldowns
