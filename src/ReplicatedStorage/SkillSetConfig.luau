-- Skill sets, like Mandela: a hotbar tool that, while equipped, turns on its
-- skills (Z/X/C/V, and F for S-tier sets). Each set has its own mastery level,
-- earned by dealing damage with the set, and each skill unlocks at a mastery
-- level. Shared by the server (the rules) and clients (the skill bar).
local SkillSetConfig = {}

-- every key a set can use, in skill-bar order; a set has skills on some of them
SkillSetConfig.Keys = { "Z", "X", "C", "V", "F" }
SkillSetConfig.OverchargeKey = "G"
SkillSetConfig.FlightKey = "G" -- the same key: a set has an overcharge or flight, not both

-- Kinds: every set is a `power` (a character's abilities, like Mandela, or a
-- power like Kintsugi) or a `weapon` (a sword like Monotwister). A player
-- carries at most CarryLimit of each kind at once.
SkillSetConfig.CarryLimit = { power = 1, weapon = 1 }

-- Owning: the inventory (client Inventory, B) lists the sets a player owns
-- and lets them pick which to carry. They own the starting power and the sets
-- they've bought (Loadout.Owns). OwnAllSets is for testing: while it's on,
-- everyone owns every set. Turn it off once sets are earned for real.
SkillSetConfig.OwnAllSets = true
-- the player attribute listing the sets they own, comma separated (Loadout keeps it)
SkillSetConfig.OwnedSetsAttribute = "OwnedSets"

-- Tiers: how many moves a set gets for its kind (`powerSlots`,
-- `weaponSlots`) and how hard it hits. All of a set's damage, skills and
-- weapon alike, is multiplied by its tier's damageScale, so a B set is weaker
-- than an A set with the same numbers. C-tier sets are meant to be the easy
-- ones to find. `color` outlines the set's tool in the hotbar; tools that
-- aren't skill sets get NoTierColor.
SkillSetConfig.Tiers = {
	S = { powerSlots = 5, weaponSlots = 4, damageScale = 1, color = Color3.fromRGB(175, 90, 255) },
	A = { powerSlots = 4, weaponSlots = 3, damageScale = 0.9, color = Color3.fromRGB(226, 75, 74) },
	B = { powerSlots = 4, weaponSlots = 2, damageScale = 0.75, color = Color3.fromRGB(90, 165, 255) },
	C = { powerSlots = 3, weaponSlots = 1, damageScale = 0.65, color = Color3.fromRGB(90, 210, 110) },
}
SkillSetConfig.NoTierColor = Color3.fromRGB(165, 165, 180)
SkillSetConfig.AimAssistRadius = 4 -- studs, the circle round a target while aiming a ranged move
SkillSetConfig.MaxMastery = 100
-- mastery XP earned per point of damage dealt to NPCs with the set
SkillSetConfig.MasteryXPPerDamage = 0.25

-- mastery XP to go from this level to the next
function SkillSetConfig.MasteryToLevelUp(level)
	return 40 + 20 * (level - 1)
end

-- `handler` names the ModuleScript in ServerScriptService.Skills that casts
-- the skill; a skill without one is shown as coming soon. `overcharged`
-- marks a skill that changes form while the set is overcharged; one with an
-- `overchargedHandler` becomes a different skill then (`overchargedName`),
-- sharing the cooldown. `needsWeapon`: the normal form throws the set's
-- weapon, so it can't be cast while the weapon is still out. `recast`:
-- pressing the key again while the skill is still out does this instead
-- (its handler's Recast), shown on the slot while it's possible.
-- `needsTarget`: a "lock" skill that does nothing without someone to lock
-- onto, so the skill bar refuses it then ("no target") instead of sending it.
-- `overchargedOnly`: it can only be cast while the set is overcharged (an
-- ultimate). `charges`: it can be cast that many times in a row, each
-- charge coming back `cooldown` seconds after the last one did.
-- `fullName`/`fullAim`: cast with full Luminance (FullLuminance) it's a
-- bigger version under another name (Iridescent Requiem's F).
--
-- `aim`: what holding the key shows before letting go casts it
-- (`overchargedAim` for the overcharged form). Kinds: "line" (`length`
-- studs ahead), "lock" (locks onto the enemy nearest the mouse within
-- `range` studs and `cone` degrees), "circle" (`radius`, placed at the mouse
-- up to `range` away), "path" (`length` ahead; `count` paths `spread`
-- degrees apart, plus a `radius` blast around you), "fan" (`count` beams
-- `spread` degrees apart, `length` long), "dash" (to the mouse, up to
-- `range`), "self" (`radius` around you). The numbers mirror the skill
-- modules' own CONFIG.
--
-- `passive`: works while the set is equipped. `links`: how its skills set
-- each other up (see the Mandela entries). `flight`: FlightKey toggles
-- flying; `dash`: the dash key does the set's own dash instead of the
-- normal one; `form`: one of its skills transforms the character, and
-- skills marked `form` are empowered meanwhile (`formAim` for their bigger
-- reach). See the Iridescent Requiem entry for all three. `undo`: the G key
-- rewinds the character instead (Photoshop's Undo, PhotoshopServer); a set
-- has one of overcharge, flight or undo.
--
-- `ranged`: the right-click/left-click move (client Ranged, RangedServer):
-- holding right click readies it and left click fires, through `handler`
-- (a module in ServerScriptService.Skills with Fire). `aims`: it goes where
-- the mouse points (otherwise straight ahead of the character); `primary`:
-- left click fires it even unreadied, in place of punches. What a shot
-- costs: one of `charges` (refilling one per `recharge` seconds), or
-- `luminanceCost`, or a round of `rounds` (reloading for `reload` seconds).
-- `projectile` flies a ReplicatedStorage.ProjectileModels piece; `beam` is
-- instant (its `effect` names how SkillEffects draws it; LightShot if none). `animation`: a <Set>Animations one to play per shot.
-- Aim assist: while a move that `aims` is readied (right click held),
-- everyone within its reach and in sight gets a circle AimAssistRadius studs
-- around them; a shot fired with the crosshair inside one is locked onto
-- them and steers in, so it lands unless a wall gets in the way.
--
-- `overcharge`: damage dealt with the set builds stacks (melee hits only count
-- for meleeShare of their damage; damage taken while holding it counts
-- takenShare); at maxStacks it's ready, and pressing
-- OverchargeKey with the set equipped
-- overcharges for `duration` seconds (its OverchargeOnly wearables appear and
-- skills cast their overcharged forms), then the stacks are spent and it
-- can't be used again for `cooldown` seconds (stacks still build). Each kill
-- while overcharged adds `killRefill` seconds back, up to a full bar. Stacks
-- short of full fade after `decayDelay` seconds without dealing damage.
SkillSetConfig.Sets = {
	Mandela = {
		tool = "Mandela",
		kind = "power",
		tier = "S",
		color = Color3.fromRGB(170, 255, 200),
		-- Misremembered: the next hit you'd take is erased, unless it scales
		-- with Superliminal (skills and ranged moves), then it recharges
		passive = { name = "Misremembered", cooldown = 25, overchargedCooldown = 15 },
		links = {
			exposedDuration = 3, -- seconds someone stays exposed after Z pulls them in
			exposedFinisherBonus = 0.5, -- extra share of damage on your next axe finisher against them
			snapInHoleBonus = 0.3, -- extra share of Overcome the Possibility's snap inside your Event Horizon
		},
		overcharge = {
			name = "Backbone Power",
			color = Color3.fromRGB(255, 70, 80),
			maxStacks = 10,
			damagePerStack = 40,
			meleeShare = 0.35,
			takenShare = 0.5, -- damage he takes counts half as much as damage he deals
			duration = 15,
			cooldown = 30,
			killRefill = 1.5,
			decayDelay = 6,
			decayPerSecond = 0.5,
		},
		-- a knife thrown where the mouse points, from 3 charges
		ranged = {
			name = "Knife",
			handler = "KnifeThrow",
			aims = true,
			charges = 3,
			recharge = 3, -- seconds per charge
			interval = 0.3, -- seconds between throws
			animation = "CastZ",
			projectile = { model = "Knife", speed = 110, range = 90, radius = 1, spin = 900 },
		},
		skills = {
			Z = {
				name = "Axe Boomerang",
				mastery = 1,
				cooldown = 6,
				handler = "AxeBoomerang",
				needsWeapon = true,
				weaponName = "axe", -- for the skill bar's "axe still thrown"
				recast = "Recall",
				overcharged = true,
				overchargedName = "Spine Lash",
				overchargedHandler = "SpineLash",
				aim = { kind = "line", length = 42 },
				overchargedAim = { kind = "lock", range = 80, cone = 30 },
			},
			X = {
				name = "Event Horizon",
				mastery = 5,
				cooldown = 8,
				handler = "BlackHole",
				overcharged = true,
				recast = "Detonate",
				aim = { kind = "circle", range = 60, radius = 30 },
				overchargedAim = { kind = "circle", range = 60, radius = 48 },
			},
			C = {
				name = "Tornado",
				mastery = 20,
				cooldown = 14,
				handler = "Tornado",
				overcharged = true,
				aim = { kind = "path", length = 89 },
				overchargedAim = { kind = "path", length = 89, count = 3, spread = 35, radius = 20 },
			},
			V = {
				name = "Overcome the Possibility",
				mastery = 50,
				cooldown = 60,
				handler = "OvercomeThePossibility",
				overcharged = true,
				aim = { kind = "self", radius = 34 },
			},
			-- the S-tier fifth move, the ultimate: a huge dome of mirror glass
			-- records every hit you land inside it, then they all happen again
			-- (Skills.PlaceWhereDreamEnds). Only while overcharged.
			F = {
				name = "Place Where Dream Ends",
				mastery = 100,
				cooldown = 90,
				handler = "PlaceWhereDreamEnds",
				overchargedOnly = true,
				overcharged = true,
				aim = { kind = "self", radius = 87.5 },
			},
		},
	},

	-- Ayato Yoji's iridescent light. No overcharge: its passive, Luminance, is
	-- light he soaks up, which blunts physical hits and feeds his flight,
	-- Prism Form and Solar Lance.
	IridescentRequiem = {
		tool = "Iridescent Requiem",
		kind = "power",
		tier = "S",
		color = Color3.fromRGB(60, 224, 230), -- the cyan of its palette (IridescentColor)
		-- Luminance runs 0 to 1: it fills in sunlight (cloudMultiplier times as
		-- fast above cloudHeight). In shade it can only hold shadeCap: above
		-- that it drains down to it, below it slowly gathers up to it. While
		-- it's equipped melee and weapon hits on him are cut by up to
		-- physicalReduction, in proportion to it
		passive = {
			name = "Luminance",
			physicalReduction = 0.15,
			chargePerSecond = 0.1,
			shadeDrainPerSecond = 0.06,
			shadeCap = 0.5,
			shadeChargePerSecond = 0.025,
			cloudHeight = 250, -- studs; the map tops out around 126
			cloudMultiplier = 3,
		},
		-- flying burns Luminance (it needs minimumToStart to take off; sunlight
		-- doesn't refill it in the air) and ends when it runs out; sprint flies
		-- boostMultiplier times faster
		flight = { speed = 40, boostMultiplier = 1.3, drainPerSecond = 0.15, minimumToStart = 0.2 },
		-- Q is Lightstep instead of the normal dash: a flash of light `range`
		-- studs, untouchable for `travelTime`, hurting everyone it passes through
		-- (Skills.Lightstep). It spends a dodge charge like the normal dash, but
		-- no stamina. The light it leaves lingers for trailDuration seconds,
		-- hurting anyone who walks into it once per trail; only maxTrails of his
		-- trails last at a time (a new one ends the oldest).
		dash = { name = "Lightstep", handler = "Lightstep", range = 28, travelTime = 0.1, trailDuration = 3, maxTrails = 3 },
		-- Prism Form, on X: it needs minimumToStart Luminance and costs entryCost,
		-- then burns drainPerSecond (sunlight stops refilling it meanwhile) until
		-- X is pressed again or the light runs out. Physical hits are cut by
		-- physicalReduction (1: they pass straight through him), and skills
		-- marked `form` are empowered.
		-- shots of light at the mouse, 10% of the Luminance each (10 from full)
		ranged = {
			name = "Light Shot",
			handler = "LightShot",
			aims = true,
			luminanceCost = 0.1,
			interval = 0.2,
			animation = "CastZ",
			beam = { range = 150 },
		},
		form = {
			name = "Prism Form",
			key = "X",
			attribute = "PrismForm", -- on the character while it lasts
			minimumToStart = 0.3,
			entryCost = 0.1,
			drainPerSecond = 0.08,
			physicalReduction = 1,
		},
		skills = {
			Z = {
				name = "Prism Shot",
				mastery = 1,
				cooldown = 5,
				handler = "PrismShot",
				aim = { kind = "fan", length = 45, count = 5, spread = 10 },
				form = true, -- 7 beams
				formAim = { kind = "fan", length = 45, count = 7, spread = 8 },
			},
			X = { name = "Prism Form", mastery = 5, cooldown = 10, handler = "PrismForm", recast = "Revert" },
			C = {
				name = "Refraction Field",
				mastery = 20,
				cooldown = 14, -- per charge
				charges = 3,
				handler = "RefractionField",
				aim = { kind = "circle", range = 50, radius = 18 },
				form = true, -- twice the reach
				formAim = { kind = "circle", range = 50, radius = 36 },
			},
			V = {
				name = "Solar Lance",
				mastery = 50,
				cooldown = 35,
				handler = "SolarLance",
				aim = { kind = "circle", range = 70, radius = 18 },
				form = true, -- leaves a pool of burning light
			},
			-- two sizes of one move (Skills.AboveTheClouds): any Luminance, or full
			F = {
				name = "Below the Stratus",
				fullName = "Above the Cumulonimbus",
				mastery = 100,
				cooldown = 90,
				handler = "AboveTheClouds",
				aim = { kind = "self", radius = 30 },
				fullAim = { kind = "self", radius = 60 },
			},
		},
	},

	-- Nozomi Yume's Photoshop: she edits reality like a photo. She can
	-- collapse it (cut it, paste it, crush it into a black hole) but not
	-- change it, which is why Mandela's rewrites win against her. Her edits
	-- shut down light: Desaturate grounds Iridescent Requiem's flight, Prism
	-- Form and Luminance. Snapshot and Shutter leave her Framed mark (Framed),
	-- which her other skills build on.
	Photoshop = {
		tool = "Photoshop",
		kind = "power",
		tier = "S",
		color = Color3.fromRGB(255, 126, 200), -- the pink of its palette (PhotoshopPink)
		-- History: where she's been and the damage she's taken lately is kept,
		-- so Undo can take it back (PhotoshopServer). Mandela's damage can't be
		-- undone.
		passive = { name = "History" },
		-- G, Undo: back to where she stood `rewind` seconds ago, healing
		-- healShare of the damage taken since
		undo = { name = "Undo", cooldown = 18, rewind = 3, healShare = 0.5 },
		-- `key` opens her saved photos of places, `slots` of them, to step
		-- back into out of combat (PhotoshopServer, the PhotoGallery script)
		gallery = { name = "Gallery", key = "T", slots = 3 },
		-- camera flashes at the mouse, from 3 charges; one on someone she's
		-- Framed keeps the frame going
		ranged = {
			name = "Shutter",
			handler = "Shutter",
			aims = true,
			charges = 3,
			recharge = 3, -- seconds per charge
			interval = 0.25,
			animation = "CastZ",
			beam = { range = 120, effect = "Shutter" },
		},
		skills = {
			Z = {
				name = "Snapshot",
				mastery = 1,
				cooldown = 6,
				handler = "Snapshot",
				needsTarget = true,
				recast = "Step In", -- behind whoever she's Framed
				aim = { kind = "lock", range = 100, cone = 30 },
			},
			X = {
				name = "Photo Teleport",
				mastery = 5,
				cooldown = 10,
				handler = "PhotoTeleport",
				recast = "Paste", -- her, or someone she's Framed, into the photo
				aim = { kind = "circle", range = 60, radius = 4 },
			},
			C = {
				name = "Desaturate",
				mastery = 20,
				cooldown = 14, -- per charge
				charges = 3,
				handler = "Desaturate",
				aim = { kind = "circle", range = 50, radius = 18 },
			},
			V = {
				name = "Iris Horizon",
				mastery = 50,
				cooldown = 35,
				handler = "IrisHorizon",
				needsTarget = true,
				aim = { kind = "lock", range = 120, cone = 30 },
			},
			-- the ultimate; she has no overcharge, so it needs only the mastery
			F = {
				name = "Kaleidoscope",
				mastery = 100,
				cooldown = 90,
				handler = "Kaleidoscope",
				aim = { kind = "self", radius = 60 },
			},
		},
	},

	-- The shop's revolver, a B-tier weapon. Left click shoots (no punches
	-- with it out), right click steadies the aim and zooms in, R reloads.
	Revolver = {
		tool = "Revolver",
		kind = "weapon",
		tier = "B",
		color = Color3.fromRGB(230, 70, 80),
		ranged = {
			name = "Revolver",
			handler = "RevolverShot",
			aims = true,
			primary = true,
			rounds = 6,
			reload = 1.6, -- seconds
			interval = 0.28,
			hipSpread = 4, -- degrees a shot may stray without aiming
			zoom = 50, -- camera field of view while aiming
			projectile = { model = "Bullet", speed = 320, range = 160, radius = 0.5, flash = Color3.fromRGB(255, 190, 90) },
		},
		skills = {
			Z = {
				name = "Fan the Hammer",
				mastery = 1,
				cooldown = 7,
				handler = "FanTheHammer",
				aim = { kind = "line", length = 60 },
			},
			X = {
				name = "Dead Eye",
				mastery = 10,
				cooldown = 14,
				handler = "DeadEye",
				aim = { kind = "lock", range = 120, cone = 25 },
			},
		},
	},
}

-- the attribute names a player's mastery in a set is kept under
function SkillSetConfig.MasteryAttribute(setName)
	return setName .. "Mastery"
end

function SkillSetConfig.MasteryXPAttribute(setName)
	return setName .. "MasteryXP"
end

function SkillSetConfig.StacksAttribute(setName)
	return setName .. "Stacks"
end

-- true while that skill is still out and pressing its key again recasts it
function SkillSetConfig.RecastAttribute(setName, key)
	return setName .. key .. "Recast"
end

-- server time the set's passive is ready again
function SkillSetConfig.PassiveReadyAttribute(setName)
	return setName .. "PassiveReadyAt"
end

-- a Luminance passive's level, 0 to 1, on the player
function SkillSetConfig.LuminanceAttribute(setName)
	return setName .. "Luminance"
end

-- Iridescent Requiem's light shifts between orange and cyan, like oil on
-- water, through a pale sheen in the middle: `share` 0 is the orange, 1 the
-- cyan. (A straight blend of the two would go a muddy green halfway.)
SkillSetConfig.IridescentOrange = Color3.fromRGB(255, 154, 60)
SkillSetConfig.IridescentCyan = Color3.fromRGB(60, 224, 230)
local IRIDESCENT_SHEEN = Color3.fromRGB(255, 236, 214)
function SkillSetConfig.IridescentColor(share)
	share = math.clamp(share, 0, 1)
	if share < 0.5 then
		return SkillSetConfig.IridescentOrange:Lerp(IRIDESCENT_SHEEN, share * 2)
	end
	return IRIDESCENT_SHEEN:Lerp(SkillSetConfig.IridescentCyan, share * 2 - 1)
end

-- Photoshop's pink and light blue
SkillSetConfig.PhotoshopPink = Color3.fromRGB(255, 126, 200)
SkillSetConfig.PhotoshopBlue = Color3.fromRGB(140, 210, 255)

-- server time an undo set's Undo is ready again
function SkillSetConfig.UndoReadyAttribute(setName)
	return setName .. "UndoReadyAt"
end

-- the player attribute that's true while a Luminance set's holder stands in shade
SkillSetConfig.ShadedAttribute = "LuminanceShaded"
-- Luminance from here up counts as full (for a skill's `fullName` version)
SkillSetConfig.FullLuminance = 0.999

function SkillSetConfig.TierOf(setName)
	return SkillSetConfig.Tiers[SkillSetConfig.Sets[setName].tier]
end

-- how many moves a set may have, by its tier and kind
function SkillSetConfig.SlotLimit(setName)
	local set = SkillSetConfig.Sets[setName]
	return SkillSetConfig.Tiers[set.tier][set.kind .. "Slots"]
end

-- server time the overcharge ends; 0 while not overcharged
function SkillSetConfig.OverchargeEndAttribute(setName)
	return setName .. "OverchargeEnd"
end

-- server time the overcharge can be used again; 0 or past when it's not cooling down
function SkillSetConfig.OverchargeCooldownAttribute(setName)
	return setName .. "OverchargeCooldownEnd"
end

function SkillSetConfig.IsOvercharged(player, setName)
	return (player:GetAttribute(SkillSetConfig.OverchargeEndAttribute(setName)) or 0) > workspace:GetServerTimeNow()
end

-- whether the character is in its set's form (Iridescent Requiem's Prism Form)
function SkillSetConfig.InForm(character, setName)
	local form = setName and SkillSetConfig.Sets[setName] and SkillSetConfig.Sets[setName].form
	return form ~= nil and character ~= nil and character:GetAttribute(form.attribute) == true
end

-- A ranged move's ammo lives on the player so the skill bar can show it:
-- charges as of a server time (they refill from there), and a revolver's
-- rounds with the server time its reload finishes.
function SkillSetConfig.RangedChargesAttribute(setName)
	return setName .. "RangedCharges"
end

function SkillSetConfig.RangedChargedAtAttribute(setName)
	return setName .. "RangedChargedAt"
end

function SkillSetConfig.RoundsAttribute(setName)
	return setName .. "Rounds"
end

function SkillSetConfig.ReloadUntilAttribute(setName)
	return setName .. "ReloadUntil"
end

-- charges ready now, fractional while the next one refills
function SkillSetConfig.RangedCharges(player, setName)
	local ranged = SkillSetConfig.Sets[setName].ranged
	local stored = player:GetAttribute(SkillSetConfig.RangedChargesAttribute(setName))
	if stored == nil then
		return ranged.charges
	end
	local at = player:GetAttribute(SkillSetConfig.RangedChargedAtAttribute(setName)) or 0
	return math.min(ranged.charges, stored + (workspace:GetServerTimeNow() - at) / ranged.recharge)
end

-- how far a ranged move reaches: its projectile's range or its beam's
function SkillSetConfig.RangedReach(ranged)
	return (ranged.projectile and ranged.projectile.range) or (ranged.beam and ranged.beam.range) or 0
end

-- rounds ready to fire, and the seconds of reloading left (0 when not)
function SkillSetConfig.Rounds(player, setName)
	local ranged = SkillSetConfig.Sets[setName].ranged
	local reloadUntil = player:GetAttribute(SkillSetConfig.ReloadUntilAttribute(setName))
	if reloadUntil then
		local left = reloadUntil - workspace:GetServerTimeNow()
		if left > 0 then
			return 0, left
		end
		return ranged.rounds, 0
	end
	return player:GetAttribute(SkillSetConfig.RoundsAttribute(setName)) or ranged.rounds, 0
end

-- where a shot leaves from: the far end of a held gun along the way the
-- character faces, or the right hand
function SkillSetConfig.ShotOrigin(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local tool = character:FindFirstChildOfClass("Tool")
	local best, bestReach
	if root and tool then
		for _, part in ipairs(tool:GetDescendants()) do
			if part:IsA("BasePart") then
				local reach = (part.Position - root.Position):Dot(root.CFrame.LookVector)
				if not bestReach or reach > bestReach then
					best, bestReach = part, reach
				end
			end
		end
	end
	if best then
		return best.Position
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or root
	return hand and hand.Position
end

-- the skill set tool a character is holding, and its set's name
function SkillSetConfig.Equipped(character)
	local tool = character and character:FindFirstChildOfClass("Tool")
	local setName = tool and tool:GetAttribute("SkillSet")
	if setName and SkillSetConfig.Sets[setName] then
		return tool, setName
	end
	return nil, nil
end

return SkillSetConfig
