-- Melee combos, shared by the Punch LocalScript and the PunchCombat server
-- script so both count combos the same way. Fists are the default; a weapon
-- with a `tool` is used instead while that tool is equipped.
local PunchConfig = {
	ComboLength = 4, -- the last hit is the critical finisher
	ComboWindow = 0.8, -- seconds after a hit that the next one still continues the combo
	CritMultiplier = 2.5, -- finisher damage
	Hitstun = 0.45, -- seconds an enemy can't move or swing after a melee hit
	-- Staggered nonstop for StaggerLimit seconds, an enemy shrugs it off and
	-- can't be staggered for StaggerImmunity seconds, so it can swing back
	-- mid-combo. A model's own StaggerLimit attribute overrides it (bosses).
	StaggerLimit = 1.6,
	StaggerImmunity = 2,
}

-- Per weapon: damage before its stat bonus, timing, reach and animations (in
-- the ReplicatedStorage folder `animationFolder`, named `animationPrefix` plus
-- the hit number). Per hit: seconds from the start of the swing to the impact,
-- and the length of its animation. `stat`: the stat its damage scales with
-- (Strength if none). `hitEffect`: the SkillEffects kind each landed hit
-- plays, (point, critical), in place of the usual slash or fist burst.
-- `overcharged`: extras while its skill set is overcharged (lifesteal: share
-- of damage dealt healed back; the finisher bursts spikes out around the
-- first target it hits).
PunchConfig.Weapons = {
	Fists = {
		baseDamage = 10,
		minInterval = 0.3, -- seconds between hits
		finisherCooldown = 0.6, -- extra rest after the finisher before a new combo
		hitboxSize = Vector3.new(5, 5, 5),
		hitboxForward = 3, -- studs from the root to the hitbox center
		animationFolder = "PunchAnimations",
		animationPrefix = "Punch",
		-- timed to the Combat Animations pack's Hit 1-4 (converted to R15): when
		-- the striking arm is furthest forward, and each animation's length
		hits = {
			{ impact = 0.05, length = 0.38 },
			{ impact = 0.05, length = 0.4 },
			{ impact = 0.23, length = 0.37 },
			{ impact = 0.15, length = 0.52 }, -- finisher
		},
	},
	MandelaAxe = {
		tool = "Mandela",
		skillSet = "Mandela", -- axe hits earn Mandela mastery
		baseDamage = 14,
		minInterval = 0.38,
		finisherCooldown = 0.7,
		hitboxSize = Vector3.new(8, 6, 7),
		hitboxForward = 4,
		animationFolder = "MandelaAnimations",
		animationPrefix = "Axe",
		holdAnimation = "AxeHold", -- loops while the tool is equipped
		overcharged = {
			lifesteal = 0.05,
			spikeRadius = 9, -- studs around the target
			spikeDamage = 21, -- before Strength, to everyone in the burst
		},
		hits = {
			{ impact = 0.14, length = 0.38 }, -- diagonal slash down
			{ impact = 0.12, length = 0.38 }, -- rising backhand
			{ impact = 0.14, length = 0.4 }, -- wide horizontal sweep
			{ impact = 0.28, length = 0.6 }, -- overhead chop
		},
	},
	-- Photoshop's punches: her fists with Photoshop out, scaling with
	-- Superliminal. Right click held still readies Shutter instead (Ranged).
	PhotoshopPunch = {
		tool = "Photoshop",
		skillSet = "Photoshop", -- punches earn Photoshop mastery
		stat = "Superliminal",
		hitEffect = "PhotoshopPunchHit",
		baseDamage = 12,
		minInterval = 0.3,
		finisherCooldown = 0.6,
		hitboxSize = Vector3.new(6, 6, 6),
		hitboxForward = 3.5,
		-- the fists' animations until Photoshop has her own
		animationFolder = "PunchAnimations",
		animationPrefix = "Punch",
		hits = {
			{ impact = 0.05, length = 0.38 },
			{ impact = 0.05, length = 0.4 },
			{ impact = 0.23, length = 0.37 },
			{ impact = 0.15, length = 0.52 }, -- finisher
		},
	},
}

-- the weapon a character fights with right now, and its name
function PunchConfig.WeaponFor(character)
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool then
		for name, weapon in pairs(PunchConfig.Weapons) do
			if weapon.tool == tool.Name then
				return name, weapon
			end
		end
	end
	return "Fists", PunchConfig.Weapons.Fists
end

return PunchConfig
