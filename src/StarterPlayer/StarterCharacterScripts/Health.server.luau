-- Replaces Roblox's default health regen: heals at the rate of the player's
-- Vitality milestone, pausing for a moment after taking damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local STEP = 0.5 -- seconds between heals
local COMBAT_PAUSE = 3 -- seconds after taking damage before healing resumes

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local player = Players:GetPlayerFromCharacter(character)

local lastHealth = humanoid.Health
local lastHurtAt = -math.huge
humanoid.HealthChanged:Connect(function(health)
	if health < lastHealth then
		lastHurtAt = os.clock()
	end
	lastHealth = health
end)

while humanoid.Health > 0 do
	task.wait(STEP)
	local vitality = player and player:GetAttribute("Vitality") or 0
	if humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth and os.clock() - lastHurtAt >= COMBAT_PAUSE then
		humanoid.Health = math.min(humanoid.Health + StatConfig.RegenPerSecond(vitality) * StatusConfig.HealMultiplier(character) * STEP, humanoid.MaxHealth)
	end
end
