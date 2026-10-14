-- Reforge: every number and name. The smith (a model tagged "Smith") lets a
-- player spend drop materials and yen to level up a weapon or power they own
-- and to reroll its modifiers. State is per skill set (ReforgeRules has the
-- rules, ServerScriptService.Reforge the actions). Materials are the saved
-- player attributes Mat_<key> from enemy drops (DropConfig); keys here are
-- those materials' keys. Modifier values are whole tenths of a percent
-- (55 = 5.5%).
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

-- the cost of a reroll, by modifier slot
ReforgeConfig.RerollCosts = {
	{ material = "Core", amount = 3, yen = 500 },
	{ material = "Crystal", amount = 3, yen = 2500 },
}

-- the modifiers a slot can roll, in menu order
--   kind    damage: +damage; cooldown: shorter skill cooldowns; status: a
--           chance on a hit to apply `status`; lifesteal: share of damage
--           dealt healed back
--   min, max  the value rolled, in tenths of a percent
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
