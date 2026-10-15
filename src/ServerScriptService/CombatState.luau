-- Skill locks from Mandela's Place Where Dream Ends, and how a fight ends.
-- A skill can be muted (every skill, for a few seconds: SkillsMutedUntil on
-- the player) or erased (the one they use the most this fight, until the
-- fight is over: the ErasedSkills attribute, skill ids like "Mandela.Z"). A
-- player can also be marked (PossibilityMarkedBy on them, the marker's
-- UserId; a caster keeps at most CombatRules.MaxMarks), and hit by the skill
-- again, a marked player has their most-used skill erased. The fight is over
-- once they are out of combat (CombatRules: Guard's LastCombatAt on the
-- character, OutOfCombatTime ago): marks, erased skills and the use counts
-- all clear, and so do they when the player dies or leaves. Nothing here is
-- saved. SkillSetServer asks Blocked before a cast and tells RecordCast
-- about every cast that went off. Visuals: SkillEffects
-- "PossibilityMark", "PossibilityUnmark" and "PossibilityErase".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local MUTED_ATTRIBUTE = "SkillsMutedUntil"
local ERASED_ATTRIBUTE = "ErasedSkills"
local MARKED_ATTRIBUTE = "PossibilityMarkedBy"
local CHECK_INTERVAL = 1 -- seconds between looks for fights that are over

local CombatState = {}

local usage = {} -- player -> { [skill id] = { count =, last = } }
local marks = {} -- caster -> { target player, ... }

local function erasedSet(player)
	return CombatRules.DecodeErased(player:GetAttribute(ERASED_ATTRIBUTE))
end

-- a skill went off: it counts towards the one they use the most
function CombatState.RecordCast(player, id)
	usage[player] = usage[player] or {}
	local entry = usage[player][id] or { count = 0, last = 0 }
	entry.count += 1
	entry.last = os.clock()
	usage[player][id] = entry
end

-- every skill is muted for `seconds` (a longer mute is never cut short)
function CombatState.Mute(player, seconds)
	local until_ = workspace:GetServerTimeNow() + seconds
	if until_ > (player:GetAttribute(MUTED_ATTRIBUTE) or 0) then
		player:SetAttribute(MUTED_ATTRIBUTE, until_)
	end
end

-- why `player` can't cast skill `id` ("muted" or "erased"), or nil if they can
function CombatState.Blocked(player, id)
	if (player:GetAttribute(MUTED_ATTRIBUTE) or 0) > workspace:GetServerTimeNow() then
		return "muted"
	end
	if erasedSet(player)[id] then
		return "erased"
	end
	return nil
end

function CombatState.IsMarked(player)
	return player:GetAttribute(MARKED_ATTRIBUTE) ~= nil
end

-- how many people `caster` has marked right now
function CombatState.MarkCount(caster)
	return marks[caster] and #marks[caster] or 0
end

local function unmark(target)
	local casterId = target:GetAttribute(MARKED_ATTRIBUTE)
	if not casterId then
		return
	end
	target:SetAttribute(MARKED_ATTRIBUTE, nil)
	for caster, list in pairs(marks) do
		local index = table.find(list, target)
		if index then
			table.remove(list, index)
			if #list == 0 then
				marks[caster] = nil
			end
		end
	end
	if target.Character then
		skillEffects:FireAllClients("PossibilityUnmark", target.Character)
	end
end

-- marks `target` for `caster`; false if they already are marked or the caster has no slot
function CombatState.Mark(caster, target, color)
	if CombatState.IsMarked(target) or CombatState.MarkCount(caster) >= CombatRules.MaxMarks then
		return false
	end
	marks[caster] = marks[caster] or {}
	table.insert(marks[caster], target)
	target:SetAttribute(MARKED_ATTRIBUTE, caster.UserId)
	if target.Character then
		skillEffects:FireAllClients("PossibilityMark", target.Character, color)
	end
	return true
end

-- Erases the skill `target` uses the most this fight (and takes their mark
-- off, spent). Returns its id, or nil if they hadn't used any skill.
function CombatState.EraseMostUsed(target, color)
	local erased = erasedSet(target)
	local id = CombatRules.MostUsed(usage[target] or {}, erased)
	unmark(target)
	if not id then
		return nil
	end
	erased[id] = true
	local ids = {}
	for erasedId in pairs(erased) do
		table.insert(ids, erasedId)
	end
	table.sort(ids)
	target:SetAttribute(ERASED_ATTRIBUTE, CombatRules.EncodeErased(ids))
	if target.Character then
		skillEffects:FireAllClients("PossibilityErase", target.Character, color)
	end
	return id
end

-- the fight is over for them: everything clears
local function endFight(player)
	usage[player] = nil
	if player:GetAttribute(ERASED_ATTRIBUTE) ~= nil then
		player:SetAttribute(ERASED_ATTRIBUTE, nil)
	end
	unmark(player)
	player:SetAttribute(MUTED_ATTRIBUTE, nil)
end

local function hasFightState(player)
	return usage[player] ~= nil
		or player:GetAttribute(ERASED_ATTRIBUTE) ~= nil
		or player:GetAttribute(MARKED_ATTRIBUTE) ~= nil
end

task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)
		local now = workspace:GetServerTimeNow()
		for _, player in ipairs(Players:GetPlayers()) do
			if hasFightState(player) then
				local character = player.Character
				if CombatRules.OutOfCombat(character and character:GetAttribute("LastCombatAt"), now) then
					endFight(player)
				end
			end
		end
	end
end)

local function onPlayerAdded(player)
	-- (a new character starts out of combat: the fight ended with the old one)
	player.CharacterAdded:Connect(function()
		endFight(player)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	-- what they had marked is let go
	for _, target in ipairs(table.clone(marks[player] or {})) do
		unmark(target)
	end
	marks[player] = nil
	usage[player] = nil
end)

return CombatState
