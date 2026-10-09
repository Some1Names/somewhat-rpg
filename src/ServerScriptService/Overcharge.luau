-- Overcharge for skill sets that have one (Mandela's Backbone Power). Damage
-- dealt with the set builds stacks, and so does damage taken while holding
-- it, counting the set's takenShare of it (any source: players, enemies,
-- falls, burns); once they're full (full stacks don't
-- fade) the player presses the overcharge key to overcharge for a while.
-- When that ends the stacks are spent and it cools down before it can be used
-- again; stacks still build meanwhile. Dying loses the stacks and any
-- overcharge. Kept as player attributes (<Set>Stacks, <Set>OverchargeEnd,
-- <Set>OverchargeCooldownEnd) so SkillSetServer and the skill bar can react.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local TICK = 0.25 -- seconds between decay and expiry checks

local Overcharge = {}

local lastGainAt = {} -- player -> { [setName] = os.clock() }

local function settingsFor(setName)
	local set = SkillSetConfig.Sets[setName]
	return set and set.overcharge
end

function Overcharge.IsActive(player, setName)
	return SkillSetConfig.IsOvercharged(player, setName)
end

function Overcharge.IsCoolingDown(player, setName)
	return (player:GetAttribute(SkillSetConfig.OverchargeCooldownAttribute(setName)) or 0) > workspace:GetServerTimeNow()
end

-- full stacks, not already overcharged and not cooling down
function Overcharge.IsReady(player, setName)
	local settings = settingsFor(setName)
	return settings ~= nil
		and (player:GetAttribute(SkillSetConfig.StacksAttribute(setName)) or 0) >= settings.maxStacks
		and not Overcharge.IsActive(player, setName)
		and not Overcharge.IsCoolingDown(player, setName)
end

local function start(player, setName)
	player:SetAttribute(SkillSetConfig.OverchargeEndAttribute(setName), workspace:GetServerTimeNow() + settingsFor(setName).duration)
end

-- the overcharge is over (it ran out or a skill spent it): the stacks are
-- gone and the cooldown starts
local function finish(player, setName)
	player:SetAttribute(SkillSetConfig.StacksAttribute(setName), 0)
	player:SetAttribute(SkillSetConfig.OverchargeEndAttribute(setName), 0)
	player:SetAttribute(SkillSetConfig.OverchargeCooldownAttribute(setName), workspace:GetServerTimeNow() + settingsFor(setName).cooldown)
end

-- the player pressed the overcharge key; returns whether it went off
function Overcharge.Activate(player, setName)
	if not Overcharge.IsReady(player, setName) then
		return false
	end
	start(player, setName)
	return true
end

-- damage dealt with the set (melee only counts for part of it); stacks don't
-- build while it's already overcharged
function Overcharge.AddDamage(player, setName, damage, melee)
	local settings = settingsFor(setName)
	if not settings or damage <= 0 or Overcharge.IsActive(player, setName) then
		return
	end
	if melee then
		damage *= settings.meleeShare or 1
	end
	local key = SkillSetConfig.StacksAttribute(setName)
	local stacks = math.min((player:GetAttribute(key) or 0) + damage / settings.damagePerStack, settings.maxStacks)
	player:SetAttribute(key, stacks)
	lastGainAt[player] = lastGainAt[player] or {}
	lastGainAt[player][setName] = os.clock()
end

-- damage taken while holding the set counts its takenShare towards the stacks
function Overcharge.AddTaken(player, setName, damage)
	local settings = settingsFor(setName)
	if settings and settings.takenShare then
		Overcharge.AddDamage(player, setName, damage * settings.takenShare)
	end
end

-- a kill while overcharged buys back some time, never past a full bar
function Overcharge.AddKill(player)
	local now = workspace:GetServerTimeNow()
	for setName, set in pairs(SkillSetConfig.Sets) do
		local settings = set.overcharge
		if settings and settings.killRefill and Overcharge.IsActive(player, setName) then
			local key = SkillSetConfig.OverchargeEndAttribute(setName)
			player:SetAttribute(key, math.min(player:GetAttribute(key) + settings.killRefill, now + settings.duration))
		end
	end
end

-- ends the overcharge early for a skill that spends it; returns the seconds
-- it had left (0 if it wasn't overcharged)
function Overcharge.Spend(player, setName)
	if not Overcharge.IsActive(player, setName) then
		return 0
	end
	local left = player:GetAttribute(SkillSetConfig.OverchargeEndAttribute(setName)) - workspace:GetServerTimeNow()
	finish(player, setName)
	return math.max(left, 0)
end

-- admin tool: fills the stacks and overcharges straight away, cooldown or not
function Overcharge.Fill(player, setName)
	local settings = settingsFor(setName)
	if not settings then
		return false
	end
	player:SetAttribute(SkillSetConfig.StacksAttribute(setName), settings.maxStacks)
	player:SetAttribute(SkillSetConfig.OverchargeCooldownAttribute(setName), 0)
	start(player, setName)
	return true
end

-- admin tool: every set's overcharge usable again
function Overcharge.ResetCooldowns(player)
	for setName, set in pairs(SkillSetConfig.Sets) do
		if set.overcharge then
			player:SetAttribute(SkillSetConfig.OverchargeCooldownAttribute(setName), 0)
		end
	end
end

task.spawn(function()
	while true do
		task.wait(TICK)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			for setName, set in pairs(SkillSetConfig.Sets) do
				local settings = set.overcharge
				local endKey = SkillSetConfig.OverchargeEndAttribute(setName)
				local stacksKey = SkillSetConfig.StacksAttribute(setName)
				local ends = player:GetAttribute(endKey) or 0
				if settings and ends > 0 and ends <= workspace:GetServerTimeNow() then
					finish(player, setName)
				elseif settings and ends == 0 then
					local stacks = player:GetAttribute(stacksKey) or 0
					local last = lastGainAt[player] and lastGainAt[player][setName] or 0
					-- a full meter waits for the key instead of fading
					if stacks > 0 and stacks < settings.maxStacks and now - last >= settings.decayDelay then
						player:SetAttribute(stacksKey, math.max(stacks - settings.decayPerSecond * TICK, 0))
					end
				end
			end
		end
	end
end)

-- dying empties every set's stacks and ends any overcharge
local function resetAll(player)
	for setName, set in pairs(SkillSetConfig.Sets) do
		if set.overcharge then
			player:SetAttribute(SkillSetConfig.StacksAttribute(setName), 0)
			player:SetAttribute(SkillSetConfig.OverchargeEndAttribute(setName), 0)
		end
	end
	lastGainAt[player] = nil
end

local function watchCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			resetAll(player)
		end)
		-- every bit of health lost while holding a set with an overcharge
		local health = humanoid.Health
		humanoid.HealthChanged:Connect(function(newHealth)
			local lost = health - newHealth
			health = newHealth
			if lost > 0 and newHealth > 0 then
				local _, setName = SkillSetConfig.Equipped(character)
				if setName then
					Overcharge.AddTaken(player, setName, lost)
				end
			end
		end)
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastGainAt[player] = nil
end)

return Overcharge
