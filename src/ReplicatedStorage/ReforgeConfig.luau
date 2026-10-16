-- Reforge: every number and name. The smith (a model tagged "Smith") lets a
-- player spend drop materials and yen to level up a weapon or power they own
-- (+1 to +10, each step with the material of its grade, like Smithing Stones),
-- to choose the affinity in each of its two slots, and, for a power at the top
-- level, to awaken it with Essence. State is per skill set (ReforgeRules has
-- the rules, ServerScriptService.Reforge the actions). Materials are the saved
-- player attributes Mat_<key> from enemy drops (DropConfig); keys here are
-- those materials' keys. Affinity values are whole tenths of a percent
-- (55 = 5.5%), from `min` at +0 to `max` at the top level.
local ReforgeConfig = {}

ReforgeConfig.MaxLevel = 10
ReforgeConfig.DamagePerLevel = 0.04 -- +4% damage per level
ReforgeConfig.SlotUnlockLevels = { 3, 7 } -- the level that opens modifier slot 1, 2
ReforgeConfig.PvPFactor = 0.5 -- against players the bonus above x1 is halved
ReforgeConfig.ProcCooldown = 1 -- seconds between one status proc on one victim
ReforgeConfig.Range = 14 -- studs from a smith that reforging works
ReforgeConfig.Tag = "Smith" -- CollectionService tag on smith models
ReforgeConfig.Remote = "ReforgeAction" -- RemoteFunction in ReplicatedStorage
ReforgeConfig.Attribute = "Reforge" -- the saved text on the player
ReforgeConfig.MaxSaveLength = 800 -- longest the saved text may be (about 17 maxed sets)

-- what the player carries for one set, for the menu: Reforge_<set>
function ReforgeConfig.SetAttribute(setName)
	return "Reforge_" .. setName
end

-- the player attribute holding a material (enemy drops)
function ReforgeConfig.MaterialAttribute(key)
	return "Mat_" .. key
end

-- the cost of reaching each level: materials of one kind, and yen
ReforgeConfig.LevelCosts = {
	{ material = "Scrap", amount = 10, yen = 200 },
	{ material = "Scrap", amount = 15, yen = 200 },
	{ material = "Scrap", amount = 20, yen = 200 },
	{ material = "Core", amount = 5, yen = 1000 },
	{ material = "Core", amount = 8, yen = 1000 },
	{ material = "Core", amount = 12, yen = 1000 },
	{ material = "Crystal", amount = 3, yen = 5000 },
	{ material = "Crystal", amount = 5, yen = 5000 },
	{ material = "Crystal", amount = 8, yen = 5000 },
	{ material = "Essence", amount = 3, yen = 20000 },
}

-- the cost of choosing (or changing) an affinity, by slot
ReforgeConfig.ChangeCosts = {
	{ material = "Core", amount = 3, yen = 500 },
	{ material = "Crystal", amount = 3, yen = 2500 },
}

-- Awakening: a power at the top level can be awakened up to MaxAwakening times, each
-- with Essence (the rare drop) and yen. Each stage adds damage and makes the
-- affinities stronger. Weapons can't awaken.
ReforgeConfig.MaxAwakening = 3
ReforgeConfig.DamagePerAwakening = 0.06 -- +6% damage per stage
ReforgeConfig.AwakenAffinityBonus = 0.1 -- affinities 10% stronger per stage
ReforgeConfig.AwakenCosts = {
	{ material = "Essence", amount = 5, yen = 50000 },
	{ material = "Essence", amount = 8, yen = 100000 },
	{ material = "Essence", amount = 12, yen = 200000 },
}

-- the affinities a slot can hold, in menu order
--   kind    damage: +damage; cooldown: shorter skill cooldowns; status: a
--           chance on a hit to apply `status`; lifesteal: share of damage
--           dealt healed back
--   min, max  the value at +0 and at the top level, in tenths of a percent
ReforgeConfig.Modifiers = {
	{ id = "Might", name = "Might", kind = "damage", min = 30, max = 100 },
	{ id = "Swift", name = "Swift", kind = "cooldown", min = 30, max = 100 },
	{ id = "Searing", name = "Searing", kind = "status", status = "Burnt", min = 80, max = 200 },
	{ id = "Rending", name = "Rending", kind = "status", status = "Bleeding", min = 80, max = 200 },
	{ id = "Venom", name = "Venom", kind = "status", status = "Poisoned", min = 80, max = 200 },
	{ id = "Sapping", name = "Sapping", kind = "status", status = "Weakened", min = 80, max = 200 },
	{ id = "Vampiric", name = "Vampiric", kind = "lifesteal", min = 20, max = 60 },
}

function ReforgeConfig.Modifier(id)
	for _, modifier in ipairs(ReforgeConfig.Modifiers) do
		if modifier.id == id then
			return modifier
		end
	end
	return nil
end

return ReforgeConfig
