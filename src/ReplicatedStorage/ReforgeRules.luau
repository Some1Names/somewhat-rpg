-- Reforge's rules, with no game services so they can be tested outside Roblox
-- (tests/ReforgeRules.spec.luau): what a level or reroll costs and whether a
-- player can pay, which modifier slots are open, rolling a modifier, the
-- combat multipliers, and the saved text. A state is
-- { level = 0..MaxLevel, mods = { [slot] = { id, value } } } (slots 1-2, may
-- be sparse). Saved text: sets joined by ";", each "Set=level:slot1,slot2",
-- a slot "id=value" or "-" (Revolver=7:Might=55,-).
local ReforgeConfig = if script then require(script.Parent:WaitForChild("ReforgeConfig")) else require("./ReforgeConfig")

local ReforgeRules = {}

local SLOTS = #ReforgeConfig.SlotUnlockLevels

function ReforgeRules.NewState()
	return { level = 0, mods = {} }
end

-- how many modifier slots a level has open
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

-- a reroll of one slot's cost if it's open and the player can pay it
function ReforgeRules.PlanReroll(state, slot, bag, yen)
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > SLOTS then
		return false, "No such slot"
	end
	if slot > ReforgeRules.SlotsUnlocked(state.level) then
		return false, "That slot is still locked"
	end
	local cost = ReforgeConfig.RerollCosts[slot]
	local ok, reason = afford(cost, bag, yen)
	if not ok then
		return false, reason
	end
	return true, cost
end

-- a modifier not in `taken` (id -> true) and its value; random(lo, hi) returns
-- an integer in lo..hi (math.random)
function ReforgeRules.Roll(random, taken)
	local choices = {}
	for _, modifier in ipairs(ReforgeConfig.Modifiers) do
		if not taken[modifier.id] then
			table.insert(choices, modifier)
		end
	end
	local modifier = choices[random(1, #choices)]
	return { id = modifier.id, value = random(modifier.min, modifier.max) }
end

-- the summed value (tenths of a percent) of the state's modifiers that match
local function total(state, matches)
	local sum = 0
	for slot = 1, SLOTS do
		local mod = state.mods[slot]
		local config = mod and ReforgeConfig.Modifier(mod.id)
		if config and matches(config) then
			sum += mod.value
		end
	end
	return sum
end

-- the factor on a hit's damage: levels and Might, the bonus halved against a player
function ReforgeRules.DamageMultiplier(state, vsPlayer)
	local bonus = state.level * ReforgeConfig.DamagePerLevel
		+ total(state, function(config)
				return config.kind == "damage"
			end)
			/ 1000
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

-- "level:slot1,slot2"
function ReforgeRules.EncodeState(state)
	local slots = {}
	for slot = 1, SLOTS do
		local mod = state.mods[slot]
		slots[slot] = mod and (mod.id .. "=" .. mod.value) or "-"
	end
	return state.level .. ":" .. table.concat(slots, ",")
end

-- the state of one set's text; anything unreadable is dropped or clamped
function ReforgeRules.DecodeState(text)
	local state = ReforgeRules.NewState()
	if typeof(text) ~= "string" then
		return state
	end
	local levelText, slotText = string.match(text, "^(%d+):(.*)$")
	if not levelText then
		return state
	end
	state.level = math.min(tonumber(levelText), ReforgeConfig.MaxLevel)
	local open = ReforgeRules.SlotsUnlocked(state.level)
	local used = {}
	local slot = 0
	for part in string.gmatch(slotText .. ",", "([^,]*),") do
		slot += 1
		if slot > open then
			break
		end
		local id, valueText = string.match(part, "^(%a+)=(%d+)$")
		local config = id and ReforgeConfig.Modifier(id)
		if config and not used[id] then
			used[id] = true
			state.mods[slot] = { id = id, value = math.clamp(tonumber(valueText), config.min, config.max) }
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
