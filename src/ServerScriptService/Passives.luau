-- Skill-set passives, working while the set is equipped. Mandela's
-- Misremembered: the next hit that would hurt you is erased, unless it's
-- one that scales with Superliminal (skill-set skills and ranged moves);
-- then it recharges (faster while overcharged). Iridescent Requiem's Luminance:
-- physical hits (melee and weapons) are cut in proportion to the light held
-- (see LuminanceServer), and pass straight through him in Prism Form, where
-- an enemy's hit trains the set's mastery as dealing one would. Every hit on
-- a player goes through Passives.Absorb first: Damage.Deal for players'
-- attacks, EnemyAI for enemies' swings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerStats = require(ServerScriptService:WaitForChild("PlayerStats"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local Passives = {}

-- what each passive (by name) does to a hit about to land; returns the damage to take
local behaviours = {}

function behaviours.Luminance(player, character, setName, set, amount, physical, fromPlayer)
	if not physical then
		return amount
	end
	if SkillSetConfig.InForm(character, setName) then
		skillEffects:FireAllClients("Refract", character)
		-- mastery comes from NPCs only, as it does for damage dealt
		if not fromPlayer then
			PlayerStats.AddMasteryXP(player, setName, amount * SkillSetConfig.MasteryXPPerDamage)
		end
		return amount * (1 - set.form.physicalReduction)
	end
	local luminance = player:GetAttribute(SkillSetConfig.LuminanceAttribute(setName)) or 0
	return amount * (1 - set.passive.physicalReduction * luminance)
end

function behaviours.Misremembered(player, character, setName, set, amount, physical, fromPlayer, superliminal)
	if superliminal then
		return amount
	end
	local readyKey = SkillSetConfig.PassiveReadyAttribute(setName)
	local now = workspace:GetServerTimeNow()
	if (player:GetAttribute(readyKey) or 0) > now then
		return amount
	end
	local passive = set.passive
	local cooldown = SkillSetConfig.IsOvercharged(player, setName) and passive.overchargedCooldown or passive.cooldown
	player:SetAttribute(readyKey, now + cooldown)
	skillEffects:FireAllClients("Misremember", character, set.color)
	return 0
end

-- `amount` damage is about to hit `player` (`physical`: a melee or weapon
-- hit; `fromPlayer`: another player's, not an enemy's; `superliminal`: it
-- scales with the Superliminal stat); returns how much should
function Passives.Absorb(player, amount, physical, fromPlayer, superliminal)
	local character = player.Character
	local _, setName = SkillSetConfig.Equipped(character)
	local set = setName and SkillSetConfig.Sets[setName]
	local behaviour = set and set.passive and behaviours[set.passive.name]
	if not behaviour or amount <= 0 then
		return amount
	end
	return behaviour(player, character, setName, set, amount, physical, fromPlayer, superliminal)
end

return Passives
