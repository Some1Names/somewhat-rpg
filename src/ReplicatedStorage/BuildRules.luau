-- Pure build rules, shared by the server (Talents, BuildCheck) and the menus:
-- stat requirements, talent points, tiers, equipping, the saved text and the
-- combined talent modifiers. Tested with Lune (tests/BuildRules.spec.luau).
local TalentConfig = if script then require(script.Parent:WaitForChild("TalentConfig")) else require("./TalentConfig")

local BuildRules = {}

-- whether `stats` ({[stat]: points}) reach `requires`; if not, the first stat (alphabetically) that falls short
function BuildRules.Meets(stats, requires)
	if not requires then
		return true
	end
	local keys = {}
	for key in pairs(requires) do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		if (stats[key] or 0) < requires[key] then
			return false, key
		end
	end
	return true
end

function BuildRules.TalentPoints(level)
	return math.floor(level / TalentConfig.LevelsPerPoint)
end

function BuildRules.TierUnlocked(points, tier)
	return points >= tier
end

function BuildRules.Spent(equipped)
	local total = 0
	for _, key in ipairs(equipped) do
		local talent = TalentConfig.Get(key)
		if talent then
			total += talent.cost
		end
	end
	return total
end

-- true, or false plus "unknown", "already", "locked" or "budget"
function BuildRules.CanEquip(equipped, key, stats, level)
	local talent = TalentConfig.Get(key)
	if not talent then
		return false, "unknown"
	end
	if table.find(equipped, key) then
		return false, "already"
	end
	if not BuildRules.TierUnlocked(stats[talent.stat] or 0, talent.tier) then
		return false, "locked"
	end
	if BuildRules.Spent(equipped) + talent.cost > BuildRules.TalentPoints(level) then
		return false, "budget"
	end
	return true
end

-- the equipped list with locked talents dropped, then trailing ones until it fits the talent points
function BuildRules.Prune(equipped, stats, level)
	local kept = {}
	for _, key in ipairs(equipped) do
		local talent = TalentConfig.Get(key)
		if talent and BuildRules.TierUnlocked(stats[talent.stat] or 0, talent.tier) then
			table.insert(kept, key)
		end
	end
	local budget = BuildRules.TalentPoints(level)
	while #kept > 0 and BuildRules.Spent(kept) > budget do
		table.remove(kept)
	end
	return kept
end

function BuildRules.Encode(equipped)
	return table.concat(equipped, ",")
end

-- the valid, unique talent keys in saved text; anything else gives {}
function BuildRules.Decode(text)
	local equipped = {}
	if typeof(text) ~= "string" or #text > TalentConfig.MaxSaveLength then
		return equipped
	end
	for key in string.gmatch(text, "[^,]+") do
		if TalentConfig.Get(key) and not table.find(equipped, key) then
			table.insert(equipped, key)
		end
	end
	return equipped
end

-- the equipped talents of one kind combined: the product for "mult" kinds (1 when
-- none), the sum for "add" kinds (0 when none). "damage" counts only talents for `damageStat`.
function BuildRules.Modifier(equipped, kind, damageStat)
	local isMult = TalentConfig.Kinds[kind] == "mult"
	local total = isMult and 1 or 0
	for _, key in ipairs(equipped) do
		local talent = TalentConfig.Get(key)
		if talent and talent.kind == kind and (kind ~= "damage" or talent.damageStat == damageStat) then
			if isMult then
				total *= talent.amount
			else
				total += talent.amount
			end
		end
	end
	return total
end

return BuildRules
