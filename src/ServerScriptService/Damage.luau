-- Damage from players' attacks goes through here. Each attack says which stat
-- it scales with (Strength for melee, Superliminal for skills) and this applies the
-- attacker's points in it. It also marks critical hits for the hit numbers,
-- remembers which player hit each target last, gives that player XP and yen
-- when an NPC dies, tops up their overcharge on any kill (players too), and
-- turns damage dealt with a skill set into its mastery
-- XP and overcharge stacks. Models with the Invulnerable attribute (like the
-- shopkeeper) can't be hurt, and a hit on a player goes past their set's
-- passive first (Passives). Also keeps the combo-link marks (Expose).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Overcharge = require(script.Parent:WaitForChild("Overcharge"))
local Passives = require(script.Parent:WaitForChild("Passives"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local Damage = {}

local lastAttacker = setmetatable({}, { __mode = "k" })
local lastHit = setmetatable({}, { __mode = "k" }) -- humanoid -> { at, skillSet }

local function payOutOnDeath(humanoid)
	humanoid.Died:Once(function()
		local killer = lastAttacker[humanoid]
		local character = humanoid.Parent
		if not killer or not killer.Parent or not character or character == killer.Character then
			return
		end
		Overcharge.AddKill(killer)
		-- only NPC kills pay, so players can't farm each other
		if not Players:GetPlayerFromCharacter(character) then
			-- its own reward if it has one, else what its level pays
			local level = character:GetAttribute("Level")
			PlayerStats.AddXP(killer, character:GetAttribute("XPReward") or (level and StatConfig.EnemyXP(level)) or StatConfig.KillXP)
			PlayerStats.AddYen(killer, character:GetAttribute("YenReward") or (level and StatConfig.EnemyYen(level)) or StatConfig.KillYen)
		end
	end)
end

-- Functions told about every hit that lands, as (attacker, humanoid, dealt,
-- options), like Mandela's ultimate recording hits. Returns a function that
-- stops telling it.
local dealtListeners = {}
function Damage.OnDealt(listener)
	table.insert(dealtListeners, listener)
	return function()
		local index = table.find(dealtListeners, listener)
		if index then
			table.remove(dealtListeners, index)
		end
	end
end

-- the player who last hit this humanoid, if any (EnemyAI turns on them)
function Damage.LastAttacker(humanoid)
	return lastAttacker[humanoid]
end

-- that last hit: { at = os.clock(), skillSet = the set it came from (or the
-- one the attacker was holding), if any } (KillFeed)
function Damage.LastHit(humanoid)
	return lastHit[humanoid]
end

-- Combo links: a skill that pulls someone in leaves them exposed to that
-- player for a few seconds (ExposedUntil / ExposedBy on their model), and
-- that player's next finisher on them uses it up for extra damage.
function Damage.Expose(attacker, model, seconds)
	model:SetAttribute("ExposedUntil", workspace:GetServerTimeNow() + seconds)
	model:SetAttribute("ExposedBy", attacker.UserId)
end

function Damage.ConsumeExposed(attacker, model)
	if (model:GetAttribute("ExposedUntil") or 0) <= workspace:GetServerTimeNow() or model:GetAttribute("ExposedBy") ~= attacker.UserId then
		return false
	end
	model:SetAttribute("ExposedUntil", nil)
	model:SetAttribute("ExposedBy", nil)
	return true
end

-- options.stat: the stat key that scales this attack ("Strength", "Superliminal", "Firearm")
-- options.critical: show the hit as a critical
-- options.skillSet: the skill set this attack belongs to, for mastery XP
-- options.melee: a weapon hit, which builds overcharge more slowly than skills
-- options.unerasable: no passive can erase it, like a Superliminal hit
-- options.dot: a status effect's damage over time tick (StatusEffects)
-- Returns the health it actually took.
function Damage.Deal(attacker, humanoid, baseAmount, options)
	options = options or {}
	if humanoid.Health <= 0 or (humanoid.Parent and humanoid.Parent:GetAttribute("Invulnerable")) then
		return 0
	end
	local amount = baseAmount
	if attacker and options.stat then
		amount *= StatConfig.DamageMultiplier(options.stat, attacker:GetAttribute(options.stat) or 0)
	end
	-- lower-tier skill sets hit softer
	if options.skillSet then
		amount *= SkillSetConfig.TierOf(options.skillSet).damageScale
	end
	-- a Weakened attacker hits softer
	if attacker and attacker.Character then
		amount *= StatusConfig.OutgoingMultiplier(attacker.Character)
	end
	-- a player's passive may erase the hit
	local targetPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
	if targetPlayer then
		amount = Passives.Absorb(targetPlayer, amount, options.melee == true, attacker ~= nil, options.stat == "Superliminal" or options.unerasable == true)
		if amount <= 0 then
			return 0
		end
	end
	if attacker then
		if lastAttacker[humanoid] == nil then
			payOutOnDeath(humanoid)
		end
		lastAttacker[humanoid] = attacker
		local _, holding = SkillSetConfig.Equipped(attacker.Character)
		lastHit[humanoid] = { at = os.clock(), skillSet = options.skillSet or holding }
	end
	if options.critical then
		-- HitFeedback shows the health drop that follows as a critical hit
		humanoid:SetAttribute("CriticalHitAt", workspace:GetServerTimeNow())
	end
	local healthBefore = humanoid.Health
	humanoid:TakeDamage(amount)
	local dealt = healthBefore - humanoid.Health
	if attacker and options.skillSet then
		Overcharge.AddDamage(attacker, options.skillSet, dealt, options.melee)
		-- mastery comes from NPCs only, like kill XP
		if not Players:GetPlayerFromCharacter(humanoid.Parent) then
			PlayerStats.AddMasteryXP(attacker, options.skillSet, dealt * SkillSetConfig.MasteryXPPerDamage)
		end
	end
	if dealt > 0 then
		for _, listener in ipairs(table.clone(dealtListeners)) do
			task.spawn(listener, attacker, humanoid, dealt, options)
		end
	end
	return dealt
end

return Damage
