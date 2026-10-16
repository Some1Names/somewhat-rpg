-- Reforge's rules, with no game services so they can be tested outside Roblox
-- (tests/ReforgeRules.spec.luau): what a level, an affinity or an awakening costs
-- and whether a player can pay, which affinity slots are open, an affinity's
-- value at a level, the combat multipliers, and the saved text. A state is
-- { level = 0..MaxLevel, mods = { [slot] = { id } }, awakening = 0..MaxAwakening }
-- (slots 1-2, may be sparse). An affinity's value isn't stored: it comes from the
-- level and the awakening (AffinityValue). Saved text: sets joined by ";", each
-- "Set=level:slot1,slot2" or "Set=level:slot1,slot2:awakening", a slot an
-- affinity's id or "-" (Revolver=7:Might,-  Mandela=10:Might,Swift:2). Older saves
-- wrote "Might=55": the value after "=" is ignored.
local ReforgeConfig = if script then require(script.Parent:WaitForChild("ReforgeConfig")) else require("./ReforgeConfig")

local ReforgeRules = {}

local SLOTS = #ReforgeConfig.SlotUnlockLevels

function ReforgeRules.NewState()
	return { level = 0, mods = {}, awakening = 0 }
end

-- how many affinity slots a level has open
function ReforgeRules.SlotsUnlocked(level)
	local count = 0
	for _, unlockLevel in ipairs(ReforgeConfig.SlotUnlockLevels) do
		if level >= unlockLevel then
			count += 1
		end
	end
	return count
end

-- whether the bag and yen cover a cost; false and what's missing if not
local function afford(cost, bag, yen)
	local have = bag[cost.material] or 0
	if have < cost.amount then
		return false, string.format("You need %d more %s", cost.amount - have, cost.material)
	end
	if yen < cost.yen then
		return false, string.format("You need ¥%d more", cost.yen - yen)
	end
	return true
end

-- the next level's cost if the player can pay it: true, cost; else false, why
function ReforgeRules.PlanLevelUp(state, bag, yen)
	local cost = ReforgeConfig.LevelCosts[state.level + 1]
	if not cost then
		return false, "Already at the highest level"
	end
	local ok, reason = afford(cost, bag, yen)
	if not ok then
		return false, reason
	end
	return true, cost
end

-- an affinity's value (tenths of a percent) at a level: its minimum at +0 up to its maximum at the top
-- level, and stronger for each awakening stage
function ReforgeRules.AffinityValue(id, level, awakening)
	local config = ReforgeConfig.Modifier(id)
	if not config then
		return 0
	end
	local progress = math.clamp(level / ReforgeConfig.MaxLevel, 0, 1)
	local base = config.min + (config.max - config.min) * progress
	return math.floor(base * (1 + ReforgeConfig.AwakenAffinityBonus * (awakening or 0)) + 0.5)
end

-- choosing `id` for a slot: its cost if the slot is open, the affinity is real and not already
-- there or in the other slot, and the player can pay; else false, why
function ReforgeRules.PlanChoose(state, slot, id, bag, yen)
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > SLOTS then
		return false, "No such slot"
	end
	if slot > ReforgeRules.SlotsUnlocked(state.level) then
		return false, "That slot is still locked"
	end
	if typeof(id) ~= "string" or not ReforgeConfig.Modifier(id) then
		return false, "No such affinity"
	end
	if state.mods[slot] and state.mods[slot].id == id then
		return false, "It already has that affinity"
	end
	for otherSlot, mod in pairs(state.mods) do
		if otherSlot ~= slot and mod.id == id then
			return false, "The other slot already has that affinity"
		end
	end
	local cost = ReforgeConfig.ChangeCosts[slot]
	local ok, reason = afford(cost, bag, yen)
	if not ok then
		return false, reason
	end
	return true, cost
end

-- the next awakening stage's cost: only a power at the top level that isn't fully awakened,
-- and only if the player can pay; else false, why
function ReforgeRules.PlanAwaken(state, isPower, bag, yen)
	if not isPower then
		return false, "Only a power can awaken"
	end
	if state.level < ReforgeConfig.MaxLevel then
		return false, string.format("Reach +%d first", ReforgeConfig.MaxLevel)
	end
	local cost = ReforgeConfig.AwakenCosts[state.awakening + 1]
	if not cost then
		return false, "Fully awakened"
	end
	local ok, reason = afford(cost, bag, yen)
	if not ok then
		return false, reason
	end
	return true, cost
end

-- the summed value (tenths of a percent) of the state's affinities that match
local function total(state, matches)
	local sum = 0
	for slot = 1, SLOTS do
		local mod = state.mods[slot]
		local config = mod and ReforgeConfig.Modifier(mod.id)
		if config and matches(config) then
			sum += ReforgeRules.AffinityValue(mod.id, state.level, state.awakening)
		end
	end
	return sum
end

-- the bonus (0.12 = +12%) a state adds to damage before the PvP halving: levels, awakening and Might
function ReforgeRules.DamageBonus(state)
	return state.level * ReforgeConfig.DamagePerLevel
		+ (state.awakening or 0) * ReforgeConfig.DamagePerAwakening
		+ total(state, function(config)
				return config.kind == "damage"
			end)
			/ 1000
end

-- the factor on a hit's damage: levels, awakening and Might, the bonus halved against a player
function ReforgeRules.DamageMultiplier(state, vsPlayer)
	local bonus = ReforgeRules.DamageBonus(state)
	if vsPlayer then
		bonus *= ReforgeConfig.PvPFactor
	end
	return 1 + bonus
end

-- the factor on a skill's cooldown (Swift)
function ReforgeRules.CooldownMultiplier(state)
	return 1
		- total(state, function(config)
				return config.kind == "cooldown"
			end)
			/ 1000
end

-- the chance (0-1) a hit applies a status
function ReforgeRules.StatusChance(state, status)
	return total(state, function(config)
		return config.kind == "status" and config.status == status
	end) / 1000
end

-- the share (0-1) of damage dealt healed back
function ReforgeRules.Lifesteal(state)
	return total(state, function(config)
		return config.kind == "lifesteal"
	end) / 1000
end

-- "level:slot1,slot2" (and ":awakening" once awakened)
function ReforgeRules.EncodeState(state)
	local slots = {}
	for slot = 1, SLOTS do
		local mod = state.mods[slot]
		slots[slot] = mod and mod.id or "-"
	end
	local text = state.level .. ":" .. table.concat(slots, ",")
	if (state.awakening or 0) > 0 then
		text ..= ":" .. state.awakening
	end
	return text
end

-- the state of one set's text; anything unreadable is dropped or clamped
function ReforgeRules.DecodeState(text)
	local state = ReforgeRules.NewState()
	if typeof(text) ~= "string" then
		return state
	end
	local levelText, slotText, awakeningText = string.match(text, "^(%d+):([^:]*):?(%d*)$")
	if not levelText then
		return state
	end
	state.level = math.min(tonumber(levelText), ReforgeConfig.MaxLevel)
	-- an awakening only counts at the top level
	if awakeningText ~= "" and state.level >= ReforgeConfig.MaxLevel then
		state.awakening = math.min(tonumber(awakeningText), ReforgeConfig.MaxAwakening)
	end
	local open = ReforgeRules.SlotsUnlocked(state.level)
	local used = {}
	local slot = 0
	for part in string.gmatch(slotText .. ",", "([^,]*),") do
		slot += 1
		if slot > open then
			break
		end
		local id = string.match(part, "^(%a+)")
		local config = id and ReforgeConfig.Modifier(id)
		if config and not used[id] then
			used[id] = true
			state.mods[slot] = { id = id }
		end
	end
	return state
end

-- every set with a level, sorted by name
function ReforgeRules.Encode(states)
	local names = {}
	for name, state in pairs(states) do
		if state.level > 0 then
			table.insert(names, name)
		end
	end
	table.sort(names)
	local parts = {}
	for _, name in ipairs(names) do
		table.insert(parts, name .. "=" .. ReforgeRules.EncodeState(states[name]))
	end
	return table.concat(parts, ";")
end

-- { [set] = state } from saved text; isSet(name) says which names are real sets
function ReforgeRules.Decode(text, isSet)
	local states = {}
	if typeof(text) ~= "string" then
		return states
	end
	for part in string.gmatch(text, "[^;]+") do
		local name, stateText = string.match(part, "^([%w_]+)=(.+)$")
		if name and isSet(name) then
			local state = ReforgeRules.DecodeState(stateText)
			if state.level > 0 then
				states[name] = state
			end
		end
	end
	return states
end

return ReforgeRules
