-- Out of combat and Mandela's Place Where Dream Ends marks: the numbers and
-- the pure rules, kept free of Roblox types so Lune can test them
-- (tests/CombatRules.spec.luau). ServerScriptService.CombatState keeps the
-- state, the CombatTimer HUD and the skill bar read the same numbers.
-- Being in combat is Guard's LastCombatAt on the character (the last time they
-- dealt or took damage, server time); OutOfCombatTime seconds after it they
-- are out of combat, and the last CountdownTime of those are counted down on
-- screen.
local CombatRules = {
	OutOfCombatTime = 30, -- seconds without dealing or taking damage
	CountdownTime = 10, -- the last seconds of it that are shown
	MaxMarks = 2, -- people one caster can have marked at a time
}

-- seconds until they count as out of combat; nil when they already are
function CombatRules.SecondsLeft(lastCombatAt, now)
	if type(lastCombatAt) ~= "number" then
		return nil
	end
	local left = lastCombatAt + CombatRules.OutOfCombatTime - now
	return left > 0 and left or nil
end

function CombatRules.OutOfCombat(lastCombatAt, now)
	return CombatRules.SecondsLeft(lastCombatAt, now) == nil
end

-- whether the countdown shows at `left` seconds (from SecondsLeft)
function CombatRules.ShowCountdown(left)
	return left ~= nil and left <= CombatRules.CountdownTime
end

-- Who a shockwave newly marks. `candidates`: { { id =, distance = }, ... } of
-- the people it caught that aren't marked yet; `marked`: how many the caster
-- already has marked. The nearest fill the free slots.
function CombatRules.PickMarks(candidates, marked)
	local free = math.max(CombatRules.MaxMarks - marked, 0)
	local sorted = table.clone(candidates)
	table.sort(sorted, function(a, b)
		return a.distance < b.distance
	end)
	local picked = {}
	for i = 1, math.min(free, #sorted) do
		table.insert(picked, sorted[i].id)
	end
	return picked
end

-- The skill they use the most this fight: `usage` is { [skill id] = { count =,
-- last = } } (last: when it was last used, larger is later), `erased` a set of
-- ids already gone. A tie goes to the one used most recently; nil if there's
-- nothing left to erase.
function CombatRules.MostUsed(usage, erased)
	local best, bestEntry
	for id, entry in pairs(usage) do
		if not erased[id] and (not bestEntry or entry.count > bestEntry.count or (entry.count == bestEntry.count and entry.last > bestEntry.last)) then
			best, bestEntry = id, entry
		end
	end
	return best
end

-- erased skills are kept as one comma-separated string (the ErasedSkills attribute)
function CombatRules.EncodeErased(ids)
	return table.concat(ids, ",")
end

function CombatRules.DecodeErased(text)
	local set = {}
	if type(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

return CombatRules
