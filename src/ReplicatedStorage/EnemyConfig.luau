-- Per-type enemy settings (tests/EnemyConfig.spec.luau). An enemy model's
-- EnemyType attribute names an entry here; EnemyAI reads its settings and combo,
-- Drops its loot table and talisman. A model's own attribute beats the entry,
-- the entry beats EnemyAI's defaults, and an enemy with no entry behaves as it
-- always has (passive until hit, a random quick or heavy swing).
--   AggroRange: studs; a player closer than this (inside its leash) gets chased
--   GiveUpDistance: studs between it and its target before it gives up the chase
--   attacks: the combo, in order: { type = "quick"|"heavy", damage = multiplier?, lunge = studs? }
--   comboPause: seconds of rest after the last step, instead of AttackCooldown
--   dropTable: a key of DropConfig.Tables (the model's DropTable attribute wins)
--   talisman: { key, chance }, rolled once per helper on a kill (TalismanConfig.dropOnly)
local EnemyConfig = {}

EnemyConfig.Types = {
	Henchman = {
		AggroRange = 50,
		GiveUpDistance = 140,
		attacks = {
			{ type = "quick" },
			{ type = "quick" },
			{ type = "heavy", lunge = 6 },
		},
		comboPause = 1.2,
		dropTable = "Henchman",
		talisman = { key = "ThugKnuckle", chance = 0.03 },
	},
}

function EnemyConfig.Get(enemyType)
	if typeof(enemyType) ~= "string" then
		return nil
	end
	return EnemyConfig.Types[enemyType]
end

-- the model's attribute if it has one, else the type's entry, else `default`
function EnemyConfig.Setting(attributeValue, enemyType, key, default)
	if attributeValue ~= nil then
		return attributeValue
	end
	local entry = EnemyConfig.Get(enemyType)
	if entry and entry[key] ~= nil then
		return entry[key]
	end
	return default
end

-- the combo step at `index` (1-based; anything out of range counts as 1), the
-- index after it, and whether it ends the combo; nil when the entry has no combo
function EnemyConfig.NextAttack(entry, index)
	local attacks = entry and entry.attacks
	if not attacks or #attacks == 0 then
		return nil
	end
	if typeof(index) ~= "number" or index < 1 or index > #attacks then
		index = 1
	end
	index = math.floor(index)
	local last = index >= #attacks
	return attacks[index], last and 1 or index + 1, last
end

function EnemyConfig.InAggro(entry, distance)
	return entry ~= nil and entry.AggroRange ~= nil and distance <= entry.AggroRange
end

-- the talisman key a kill drops, or nil; `owned` is the player's owned keys and
-- `random()` gives [0, 1). Someone who owns it doesn't use up a roll.
function EnemyConfig.TalismanDrop(entry, owned, random)
	local talisman = entry and entry.talisman
	if not talisman or table.find(owned, talisman.key) then
		return nil
	end
	if random() < talisman.chance then
		return talisman.key
	end
	return nil
end

return EnemyConfig
