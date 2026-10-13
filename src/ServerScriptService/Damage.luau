-- Damage from players' attacks goes through here. Each attack says which stat
-- it scales with (Strength for melee, Superliminal for skills) and this applies the
-- attacker's points in it. It also marks critical hits for the hit numbers,
-- remembers which player hit each target last, gives that player XP and yen
-- when an NPC dies, tops up their overcharge on any kill (players too), and
-- turns damage dealt with a skill set into its mastery
-- XP (MasteryRules: NPCs, players at half rate with a cap per victim, training
-- dummies up to mastery 10, and a bonus for finishing kills) and overcharge
-- stacks. Models with the Invulnerable attribute (like the
-- shopkeeper) can't be hurt, and a hit on a player goes past their set's
-- passive first (Passives), after a block has cut it (Guard). Also keeps the
-- combo-link marks (Expose).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(script.Parent:WaitForChild("Guard"))
local HeadhunterConfig = require(ReplicatedStorage:WaitForChild("HeadhunterConfig"))
local KillRecords = require(script.Parent:WaitForChild("KillRecords"))
local MasteryRules = require(ReplicatedStorage:WaitForChild("MasteryRules"))
local Overcharge = require(script.Parent:WaitForChild("Overcharge"))
local Passives = require(script.Parent:WaitForChild("Passives"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local Damage = {}

local lastAttacker = setmetatable({}, { __mode = "k" })
local lastHit = setmetatable({}, { __mode = "k" }) -- humanoid -> { at, skillSet, skill }

-- mastery XP each player earned from damaging each other player, by UserId
-- (MasteryRules.newLedger: the cap holds across a rejoin)
local pvpLedger = MasteryRules.newLedger()

-- Functions told about every kill someone gets credit for, as (killer, the
-- victim's character, that last hit (Damage.LastHit), whether the victim was
-- a player). An NPC's killer is whoever hit it last, like its payout; a
-- player's only if that hit was within the kill feed's credit time.
local killListeners = {}
function Damage.OnKill(listener)
	table.insert(killListeners, listener)
	return function()
		local index = table.find(killListeners, listener)
		if index then
			table.remove(killListeners, index)
		end
	end
end

local function payOutOnDeath(humanoid)
	humanoid.Died:Once(function()
		local killer = lastAttacker[humanoid]
		local character = humanoid.Parent
		if not killer or not killer.Parent or not character or character == killer.Character then
			return
		end
		Overcharge.AddKill(killer)
		local hit = lastHit[humanoid]
		local victimIsPlayer = Players:GetPlayerFromCharacter(character) ~= nil
		if not victimIsPlayer or (hit and os.clock() - hit.at <= HeadhunterConfig.CreditTime) then
			for _, listener in ipairs(table.clone(killListeners)) do
				task.spawn(listener, killer, character, hit, victimIsPlayer)
			end
		end
		-- only NPC kills pay, so players can't farm each other
		if not Players:GetPlayerFromCharacter(character) then
			-- its own reward if it has one, else what its level pays
			local level = character:GetAttribute("Level")
			local rewardXP = character:GetAttribute("XPReward") or (level and StatConfig.EnemyXP(level)) or StatConfig.KillXP
			PlayerStats.AddXP(killer, rewardXP)
			PlayerStats.AddYen(killer, character:GetAttribute("YenReward") or (level and StatConfig.EnemyYen(level)) or StatConfig.KillYen)
			-- finishing it is worth mastery to the set of the killing hit (a training
			-- dummy only up to mastery DummyCap); none for a bare-handed kill
			if hit and hit.skillSet then
				local cap = CollectionService:HasTag(character, MasteryRules.DummyTag) and MasteryRules.DummyCap or nil
				PlayerStats.AddMasteryXP(killer, hit.skillSet, MasteryRules.killXP(rewardXP), cap)
			end
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
-- one the attacker was holding), if any, skill = its options.skill } (KillFeed,
-- Quests)
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
-- options.dot: a status effect's damage over time tick (StatusEffects): never
--   blocked, and not combat
-- options.skill: the move it came from, for quests (Quests): a skill key
--   ("Z".."F"), "ranged", "dash" or "melee"; left out, it counts for no
--   hits or kills challenge
-- options.guard: how a block treats it, "melee", "ranged", "skill" or
--   "unblockable" (ultimates, grabs); default "melee" with options.melee, else "skill"
-- Returns the health it actually took.
function Damage.Deal(attacker, humanoid, baseAmount, options)
	options = options or {}
	if humanoid.Health <= 0 or (humanoid.Parent and humanoid.Parent:GetAttribute("Invulnerable")) then
		return 0
	end
	-- (a status effect's tick is neither combat nor blockable)
	local targetPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
	if not options.dot then
		Guard.MarkCombat(attacker and attacker.Character)
		Guard.MarkCombat(targetPlayer and humanoid.Parent)
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
	if targetPlayer then
		-- a block cuts it first
		if not options.dot then
			local kind = options.guard or (options.melee and "melee" or "skill")
			local source = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
			amount = Guard.Resolve(humanoid.Parent, amount, kind, source and source.Position, attacker and attacker.Character)
		end
		-- a player's passive may erase the hit
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
		lastHit[humanoid] = { at = os.clock(), skillSet = options.skillSet or holding, skill = options.skill }
	end
	if options.critical then
		-- HitFeedback shows the health drop that follows as a critical hit
		humanoid:SetAttribute("CriticalHitAt", workspace:GetServerTimeNow())
	end
	local healthBefore = humanoid.Health
	humanoid:TakeDamage(amount)
	local dealt = healthBefore - humanoid.Health
	-- an infinite-health dummy takes the hit without losing any health (inf - inf)
	if dealt ~= dealt then
		dealt = amount
	end
	if attacker and options.skillSet then
		Overcharge.AddDamage(attacker, options.skillSet, dealt, options.melee)
		local perDamage = SkillSetConfig.MasteryXPPerDamage
		local victim = Players:GetPlayerFromCharacter(humanoid.Parent)
		if victim then
			-- a player: half the rate, at most PvPCap from one victim per PvPWindow, and
			-- nothing from someone this attacker killed within the repeat window
			if victim ~= attacker and not KillRecords.IsRepeat(attacker, victim) then
				local now = os.clock()
				local xp = MasteryRules.pvpXP(dealt, perDamage, pvpLedger.earned(attacker.UserId, victim.UserId, now))
				if xp > 0 then
					pvpLedger.add(attacker.UserId, victim.UserId, xp, now)
					PlayerStats.AddMasteryXP(attacker, options.skillSet, xp)
				end
			end
		elseif CollectionService:HasTag(humanoid.Parent, MasteryRules.DummyTag) then
			-- a training dummy teaches the basics: the hit's damage, not the health it took
			local mastery = attacker:GetAttribute(SkillSetConfig.MasteryAttribute(options.skillSet)) or 1
			PlayerStats.AddMasteryXP(attacker, options.skillSet, MasteryRules.dummyXP(amount, perDamage, mastery), MasteryRules.DummyCap)
		else
			PlayerStats.AddMasteryXP(attacker, options.skillSet, dealt * perDamage)
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
