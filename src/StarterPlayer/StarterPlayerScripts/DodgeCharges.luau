-- Dodge charges for the local player, shared by Dash, DoubleJump and
-- StatusHUD so they always agree. Levelling up unlocks more charges
-- (StatConfig.DodgeChargeLevels); a spent charge refills after RECHARGE_TIME,
-- one at a time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))

local player = Players.LocalPlayer

local RECHARGE_TIME = 1 -- seconds per charge; DashRelay on the server uses the same value
local MIN_GAP = 0.3 -- seconds between two uses, so one quick double press can't spend both

local function maxFromLevel()
	return StatConfig.DodgeCharges(player:GetAttribute("Level") or 0)
end

local DodgeCharges = { Max = maxFromLevel(), RechargeTime = RECHARGE_TIME }

local charges = DodgeCharges.Max
local lastUsedAt = -math.huge

-- fractional: 1.4 means one charge ready and the next 40% refilled
function DodgeCharges.Get()
	return charges
end

function DodgeCharges.CanUse()
	return charges >= 1 and os.clock() - lastUsedAt >= MIN_GAP
end

function DodgeCharges.TryUse()
	if not DodgeCharges.CanUse() then
		return false
	end
	charges -= 1
	lastUsedAt = os.clock()
	return true
end

RunService.Heartbeat:Connect(function(dt)
	if charges < DodgeCharges.Max then
		charges = math.min(charges + dt / RECHARGE_TIME, DodgeCharges.Max)
	end
end)

-- a newly unlocked charge arrives full
player:GetAttributeChangedSignal("Level"):Connect(function()
	local newMax = maxFromLevel()
	charges = math.clamp(charges + newMax - DodgeCharges.Max, 0, newMax)
	DodgeCharges.Max = newMax
end)

player.CharacterAdded:Connect(function()
	charges = DodgeCharges.Max
end)

return DodgeCharges
