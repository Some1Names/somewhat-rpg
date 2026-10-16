-- Reforge on the server: each player's reforge level, chosen affinities and
-- awakening per skill set, kept as the saved text attribute "Reforge"
-- (ReforgeRules has the format) and mirrored as Reforge_<Set> attributes for
-- the client. The actions (level up, choose an affinity, awaken a power) check
-- everything and spend materials and yen; ReforgeServer calls them for the
-- smith's menu. Damage and SkillSetServer read the bonuses through the
-- getters below, which return a neutral value for anyone with nothing reforged.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local ReforgeConfig = require(ReplicatedStorage:WaitForChild("ReforgeConfig"))
local ReforgeRules = require(ReplicatedStorage:WaitForChild("ReforgeRules"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local Reforge = {}

local decoded = setmetatable({}, { __mode = "k" }) -- player -> { text, states }

local function isSet(name)
	return SkillSetConfig.Sets[name] ~= nil
end

-- every set the player has reforged, decoded again only when the text changes
-- (the tables are shared: copy before changing)
local function statesOf(player)
	local text = player:GetAttribute(ReforgeConfig.Attribute)
	if typeof(text) ~= "string" then
		text = ""
	end
	local entry = decoded[player]
	if not entry or entry.text ~= text then
		entry = { text = text, states = ReforgeRules.Decode(text, isSet) }
		decoded[player] = entry
	end
	return entry.states
end

-- the set's state (level 0 and no modifiers when never reforged)
function Reforge.Get(player, setName)
	return statesOf(player)[setName] or ReforgeRules.NewState()
end

local function stateOrNil(player, setName)
	return player and setName and statesOf(player)[setName]
end

function Reforge.DamageMultiplier(player, setName, vsPlayer)
	local state = stateOrNil(player, setName)
	return state and ReforgeRules.DamageMultiplier(state, vsPlayer) or 1
end

function Reforge.CooldownMultiplier(player, setName)
	local state = stateOrNil(player, setName)
	return state and ReforgeRules.CooldownMultiplier(state) or 1
end

function Reforge.StatusChance(player, setName, status)
	local state = stateOrNil(player, setName)
	return state and ReforgeRules.StatusChance(state, status) or 0
end

function Reforge.Lifesteal(player, setName)
	local state = stateOrNil(player, setName)
	return state and ReforgeRules.Lifesteal(state) or 0
end

-- the Reforge_<Set> attributes the menu and skill bar read
local function mirror(player)
	local states = statesOf(player)
	for setName in pairs(SkillSetConfig.Sets) do
		local state = states[setName]
		player:SetAttribute(ReforgeConfig.SetAttribute(setName), state and ReforgeRules.EncodeState(state) or nil)
	end
end

function Reforge.Start()
	local function onPlayerAdded(player)
		player:GetAttributeChangedSignal(ReforgeConfig.Attribute):Connect(function()
			mirror(player)
		end)
		mirror(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

-- the materials a player carries, read when asked for
local function bagOf(player)
	return setmetatable({}, {
		__index = function(_, key)
			return player:GetAttribute(ReforgeConfig.MaterialAttribute(key)) or 0
		end,
	})
end

-- whether this is a real set the player owns and their save has loaded
local function checkTarget(player, setName)
	if typeof(setName) ~= "string" or not SkillSetConfig.Sets[setName] then
		return false, "That can't be reforged"
	end
	-- (required here: Loadout reaches for the tool folder, which Damage shouldn't wait on)
	local Loadout = require(script.Parent:WaitForChild("Loadout"))
	if not Loadout.Owns(player, setName) then
		return false, "You don't own that"
	end
	if player:GetAttribute("Yen") == nil then
		return false, "Still loading"
	end
	return true
end

-- takes the cost; the plan has already shown it's affordable
local function spend(player, cost)
	if not PlayerStats.SpendYen(player, cost.yen) then
		return false
	end
	local attribute = ReforgeConfig.MaterialAttribute(cost.material)
	player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) - cost.amount)
	return true
end

-- the saved text with one set's state swapped in; nil if it would be too long
local function textWith(player, setName, state)
	local states = table.clone(statesOf(player))
	states[setName] = state
	local text = ReforgeRules.Encode(states)
	return #text <= ReforgeConfig.MaxSaveLength and text or nil
end

-- one more level for the set
function Reforge.LevelUp(player, setName)
	local ok, reason = checkTarget(player, setName)
	if not ok then
		return false, reason
	end
	local state = Reforge.Get(player, setName)
	local can, costOrReason = ReforgeRules.PlanLevelUp(state, bagOf(player), player:GetAttribute("Yen"))
	if not can then
		return false, costOrReason
	end
	local nextState = { level = state.level + 1, mods = table.clone(state.mods), awakening = state.awakening }
	-- (checked before spending: a refusal costs nothing)
	local text = textWith(player, setName, nextState)
	if not text then
		return false, "Too many reforged sets to save"
	end
	if not spend(player, costOrReason) then
		return false, "Still loading"
	end
	player:SetAttribute(ReforgeConfig.Attribute, text)
	return true, string.format("%s is now level %d", setName, nextState.level)
end

-- puts an affinity in one slot (paid for: the cost of that slot, even when the slot was empty)
function Reforge.Choose(player, setName, slot, id)
	local ok, reason = checkTarget(player, setName)
	if not ok then
		return false, reason
	end
	local state = Reforge.Get(player, setName)
	local can, costOrReason = ReforgeRules.PlanChoose(state, slot, id, bagOf(player), player:GetAttribute("Yen"))
	if not can then
		return false, costOrReason
	end
	local mods = table.clone(state.mods)
	mods[slot] = { id = id }
	local text = textWith(player, setName, { level = state.level, mods = mods, awakening = state.awakening })
	if not text then
		return false, "Too many reforged sets to save"
	end
	if not spend(player, costOrReason) then
		return false, "Still loading"
	end
	player:SetAttribute(ReforgeConfig.Attribute, text)
	return true, string.format("%s: %s in slot %d", setName, id, slot)
end

-- one more awakening stage for a power at the top level
function Reforge.Awaken(player, setName)
	local ok, reason = checkTarget(player, setName)
	if not ok then
		return false, reason
	end
	local state = Reforge.Get(player, setName)
	local isPower = SkillSetConfig.Sets[setName].kind == "power"
	local can, costOrReason = ReforgeRules.PlanAwaken(state, isPower, bagOf(player), player:GetAttribute("Yen"))
	if not can then
		return false, costOrReason
	end
	local nextState = { level = state.level, mods = table.clone(state.mods), awakening = state.awakening + 1 }
	local text = textWith(player, setName, nextState)
	if not text then
		return false, "Too many reforged sets to save"
	end
	if not spend(player, costOrReason) then
		return false, "Still loading"
	end
	player:SetAttribute(ReforgeConfig.Attribute, text)
	return true, string.format("%s awakened to stage %d", setName, nextState.awakening)
end

return Reforge
