-- Revolver Z, Fan the Hammer: six shots as fast as the hammer can be
-- slapped back, sprayed around where he aimed (up, down or level, wherever
-- the mouse points). Clients draw each bullet from the SkillEffects
-- "Projectile" event.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local CONFIG = {
	Shots = 6,
	Gap = 0.07, -- seconds between shots
	Spread = 7, -- degrees either side a shot may stray
	Damage = 10, -- per bullet, before the shooter's Firearm bonus
}
local DAMAGE_OPTIONS = { stat = "Firearm", skillSet = "Revolver", melee = true }
local FLIGHT = SkillSetConfig.Sets.Revolver.ranged.projectile

local shotCount = 0

-- `direction` turned up to `degrees` either way (less up and down)
local function stray(direction, degrees)
	local yaw = math.rad((math.random() * 2 - 1) * degrees)
	local pitch = math.rad((math.random() * 2 - 1) * degrees * 0.3)
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(pitch, yaw, 0)).LookVector
end

local function fan(player, character, aim)
	for _ = 1, CONFIG.Shots do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if not root or humanoid.Health <= 0 or not character.Parent then
			return
		end
		local origin = SkillSetConfig.ShotOrigin(character)
		local offset = aim - origin
		if offset.Magnitude < 1 then
			offset = root.CFrame.LookVector
		end
		shotCount += 1
		Projectiles.Launch({
			owner = player,
			character = character,
			id = "fan" .. shotCount,
			drawForOwner = true,
			model = FLIGHT.model,
			origin = origin,
			direction = stray(offset.Unit, CONFIG.Spread),
			speed = FLIGHT.speed,
			range = FLIGHT.range,
			radius = FLIGHT.radius,
			flash = FLIGHT.flash,
			onHit = function(target)
				Damage.Deal(player, target, CONFIG.Damage, DAMAGE_OPTIONS)
			end,
		})
		task.wait(CONFIG.Gap)
	end
end

local FanTheHammer = {}

function FanTheHammer.Cast(player, character, aim)
	if not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	task.spawn(function()
		local ok, err = pcall(fan, player, character, aim)
		if not ok then
			warn("[Skills.FanTheHammer] " .. tostring(err))
		end
	end)
	return true
end

return FanTheHammer
