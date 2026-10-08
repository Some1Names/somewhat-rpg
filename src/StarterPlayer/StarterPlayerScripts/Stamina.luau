-- Shared stamina for the local player. Dash, Sprint and StatusHUD all use this
-- one module, so they always agree on the value and the rules. Max stamina
-- grows with player level, one box at a time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))

local player = Players.LocalPlayer

local REGEN_PER_SECOND = 25
local REGEN_DELAY = 0.8 -- seconds after the last spend before regen starts
local RECOVER_AT = 25 -- after running dry, sprinting waits until stamina is back to this

local function maxFromLevel()
	return StatConfig.StaminaBoxes(player:GetAttribute("Level") or 0) * StatConfig.StaminaPerBox
end

local Stamina = { Max = maxFromLevel() }

local value = Stamina.Max
local lastSpentAt = -math.huge
local exhausted = false

local function spend(amount)
	value = math.max(value - amount, 0)
	lastSpentAt = os.clock()
	if value == 0 then
		exhausted = true
	end
end

function Stamina.Get()
	return value
end

function Stamina.IsExhausted()
	return exhausted
end

-- All-or-nothing spend for actions with a fixed cost, like a dash.
function Stamina.TryConsume(amount)
	if value < amount then
		return false
	end
	spend(amount)
	return true
end

-- Continuous spend for sprinting; returns false once stamina runs out.
function Stamina.Drain(amount)
	if exhausted then
		return false
	end
	spend(amount)
	return not exhausted
end

RunService.Heartbeat:Connect(function(dt)
	if value < Stamina.Max and os.clock() - lastSpentAt >= REGEN_DELAY then
		value = math.min(value + REGEN_PER_SECOND * dt, Stamina.Max)
		if exhausted and value >= RECOVER_AT then
			exhausted = false
		end
	end
end)

-- a new box arrives full
player:GetAttributeChangedSignal("Level"):Connect(function()
	local newMax = maxFromLevel()
	value = math.clamp(value + newMax - Stamina.Max, 0, newMax)
	Stamina.Max = newMax
end)

player.CharacterAdded:Connect(function()
	value = Stamina.Max
	exhausted = false
end)

return Stamina
