-- Combat feel numbers and pure rules (tests/CombatFeel.spec.luau): the dodge's
-- i-frames, which the dash grants (DashRelay sets the DodgeUntil attribute, Damage
-- and EnemyAI read it), and what a melee swing costs and does to your walk.
local CombatFeel = {}

CombatFeel.BaseDodgeWindow = 0.15 -- seconds a dash can't be hurt, with no Agility
CombatFeel.DodgePerAgility = 0.002 -- extra seconds per point of Agility
CombatFeel.DodgeGrace = 0.1 -- extra seconds for the network lag between the dash and the server hearing of it
CombatFeel.DodgeRecovery = 0.35 -- least seconds between two dashes
CombatFeel.SwingStamina = 6 -- per melee hit
CombatFeel.FinisherStamina = 12 -- for the combo's last hit
CombatFeel.SwingWalkShare = 0.5 -- share of walk speed kept while a swing lasts

-- seconds of invulnerability a dash gives
function CombatFeel.DodgeWindow(agility)
	return CombatFeel.BaseDodgeWindow + CombatFeel.DodgePerAgility * math.max(agility or 0, 0)
end

-- the server time the dodge ends, for a dash the server heard of at `now`
function CombatFeel.DodgeUntil(now, agility)
	return now + CombatFeel.DodgeWindow(agility) + CombatFeel.DodgeGrace
end

-- whether `now` is still inside a dodge that ends at `untilTime`
function CombatFeel.InDodge(untilTime, now)
	return untilTime ~= nil and now < untilTime
end

-- whether a dash may start `now`, the last accepted one having started at `lastAcceptedAt`
function CombatFeel.CanDodge(now, lastAcceptedAt)
	return lastAcceptedAt == nil or now - lastAcceptedAt >= CombatFeel.DodgeRecovery
end

-- stamina a swing costs; a weapon can set its own swingStamina / finisherStamina
function CombatFeel.SwingCost(weapon, finisher)
	if finisher then
		return weapon.finisherStamina or CombatFeel.FinisherStamina
	end
	return weapon.swingStamina or CombatFeel.SwingStamina
end

return CombatFeel
