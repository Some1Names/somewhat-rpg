-- Block and posture (ServerScriptService.Guard): the numbers and the pure
-- rules, kept free of Roblox types so Lune can test them
-- (tests/GuardConfig.spec.luau). The HUDs read the same numbers.
-- Holding E blocks hits from the front (within 90° of where you face): the
-- hit's kind decides how much is cut (Cuts), and the damage a block prevented
-- is added to the blocker's posture. A full bar is a guard break: stunned for
-- BreakStun, no blocking for BreakLockout after that. Posture drains back down
-- once you stop being hit. A skill set or melee weapon can bring its own cuts
-- (`block = { melee =, ranged =, skill = }`) that replace the base ones.
local Vector3 = Vector3 or require("@lune/roblox").Vector3

local GuardConfig = {
	-- Block is switched off for now (too much). Everything stays in place: set this back
	-- to true and the key, the cuts, posture, the HUD bars and the hint all come back.
	Enabled = false,
	-- share of the damage a block cuts, by the hit's `options.guard` kind
	Cuts = { melee = 0.6, ranged = 0.5, skill = 0.3, unblockable = 0 },
	MaxPosture = 100,
	BreakStun = 1, -- seconds a guard break stuns (can't act, can't move)
	BreakLockout = 2, -- seconds after the stun that blocking stays off
	DrainDelay = 1.5, -- seconds without a block (or a hit, while blocking) before posture drains
	DrainRate = 20, -- posture per second, once you've stopped blocking
	BlockingDrainRate = 5, -- the same, while holding the block unhit
	CombatTime = 5, -- seconds after dealing or taking damage that you count as in combat
	BlockWalkShare = 0.5, -- share of walk speed kept while blocking
}

-- whether a hit coming from `toSource` (the way to the attacker) is from the
-- front of someone looking along `look`. Flat: height doesn't count, and a
-- hit from right on top of the blocker counts as front.
function GuardConfig.isFront(look, toSource)
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local flatSource = Vector3.new(toSource.X, 0, toSource.Z)
	if flatSource.Magnitude < 1e-4 then
		return true
	end
	return flatLook:Dot(flatSource) > 0
end

-- the share of damage a block cuts for a hit of `kind`; `override` is the
-- equipped set's or weapon's own block table, if it has one. Unblockable and
-- unknown kinds cut nothing.
function GuardConfig.cut(kind, override)
	if kind == "unblockable" then
		return 0
	end
	local cut = override and override[kind] or GuardConfig.Cuts[kind]
	return cut or 0
end

-- posture after a block prevented `prevented` damage, capped at MaxPosture,
-- and whether that broke the guard
function GuardConfig.postureAfter(posture, prevented)
	local after = math.min(posture + prevented, GuardConfig.MaxPosture)
	return after, after >= GuardConfig.MaxPosture
end

-- posture after `dt` seconds. `sinceLast`: seconds since the last block (when
-- not blocking) or the last hit taken while blocking (when blocking).
function GuardConfig.drain(posture, sinceLast, blocking, dt)
	if sinceLast < GuardConfig.DrainDelay then
		return posture
	end
	local rate = blocking and GuardConfig.BlockingDrainRate or GuardConfig.DrainRate
	return math.max(posture - rate * dt, 0)
end

return GuardConfig
