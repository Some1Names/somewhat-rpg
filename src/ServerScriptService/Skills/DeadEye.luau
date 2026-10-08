-- Revolver X, Dead Eye: he lines up the enemy nearest where he aimed (the
-- skill's "lock" aim picks them), marks them, and after WindUp puts one
-- heavy, critical bullet into them. With nobody to lock onto the bullet
-- goes where he aimed. Clients draw the mark from the SkillEffects
-- "DeadEyeMark" event and the bullet like any other.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 120, -- studs, the lock's reach (SkillSetConfig's aim shows the same)
	LockRadius = 8, -- studs from the aim point a target may be
	WindUp = 0.5, -- seconds to line it up
	Damage = 60, -- before the shooter's Firearm bonus
	Speed = 600, -- studs per second, twice his normal shots
}
local DAMAGE_OPTIONS = { stat = "Firearm", skillSet = "Revolver", melee = true, critical = true }
local FLIGHT = SkillSetConfig.Sets.Revolver.ranged.projectile

local shotCount = 0

-- the living character nearest the aim point, within reach of the shooter
local function lockOn(character, aim)
	local root = character:FindFirstChild("HumanoidRootPart")
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local best, bestDistance
	for _, part in ipairs(workspace:GetPartBoundsInRadius(aim, CONFIG.LockRadius, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local targetRoot = humanoid and humanoid.RootPart
		if targetRoot and humanoid.Health > 0 and not model:GetAttribute("Invulnerable") then
			local distance = (targetRoot.Position - aim).Magnitude
			if (targetRoot.Position - root.Position).Magnitude <= CONFIG.Range and (not bestDistance or distance < bestDistance) then
				best, bestDistance = humanoid, distance
			end
		end
	end
	return best
end

local function shoot(player, character, aim)
	local target = lockOn(character, aim)
	skillEffects:FireAllClients("DeadEyeMark", target and target.Parent or nil, aim, CONFIG.WindUp)
	task.wait(CONFIG.WindUp)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 or not character.Parent then
		return
	end
	local goal = aim
	if target and target.Health > 0 and target.RootPart then
		goal = target.RootPart.Position
	end
	-- turn to face it
	local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
	if flat.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	local origin = SkillSetConfig.ShotOrigin(character)
	local offset = goal - origin
	if offset.Magnitude < 1 then
		offset = root.CFrame.LookVector
	end
	shotCount += 1
	Projectiles.Launch({
		owner = player,
		character = character,
		id = "deadeye" .. shotCount,
		drawForOwner = true,
		model = FLIGHT.model,
		origin = origin,
		direction = offset.Unit,
		speed = CONFIG.Speed,
		range = CONFIG.Range + 20,
		radius = FLIGHT.radius,
		flash = FLIGHT.flash,
		onHit = function(struck)
			Damage.Deal(player, struck, CONFIG.Damage, DAMAGE_OPTIONS)
		end,
	})
end

local DeadEye = {}

function DeadEye.Cast(player, character, aim)
	if not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	task.spawn(function()
		local ok, err = pcall(shoot, player, character, aim)
		if not ok then
			warn("[Skills.DeadEye] " .. tostring(err))
		end
	end)
	return true
end

return DeadEye
