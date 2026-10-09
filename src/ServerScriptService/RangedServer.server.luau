-- The ranged move of every skill set with a `ranged` spec (SkillSetConfig).
-- The client's Ranged script fires FireRanged: "fire" with where the shot
-- left from, its direction, the id it drew the shot under and, when aim
-- assist locked it, the character it's locked onto; or "reload".
-- Every shot is checked here (the set in hand, the gap since the last shot,
-- the shot starting at the shooter) and paid for: a charge, some Luminance,
-- or a round from the cylinder, which reloads by itself once it's empty.
-- Then the set's handler in ServerScriptService.Skills fires it, steering it
-- into the locked-on character if the lock checks out (alive, in reach, in
-- front of the shot and not behind a wall).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local fireRanged = ReplicatedStorage:WaitForChild("FireRanged")
local skillModules = ServerScriptService:WaitForChild("Skills")

local TOLERANCE = 0.08 -- seconds of network jitter between two shots
local CHARGE_TOLERANCE = 0.05 -- of a charge, for the same jitter
local ORIGIN_TOLERANCE = 10 -- studs a shot may start from the shooter
local MAX_ID_LENGTH = 40
local LOCK_MAX_ANGLE = 35 -- degrees a locked shot may point away from its target (they moved meanwhile)
local LOCK_CLOSE = 8 -- studs; closer than this the angle isn't checked
local LOCK_RANGE_SLACK = 12 -- studs past the move's reach the target may have moved

local lastShotAt = {} -- player -> os.clock()
local handlers = {}

local function handlerFor(name)
	if not handlers[name] then
		handlers[name] = require(skillModules:WaitForChild(name))
	end
	return handlers[name]
end

local function isVector(value)
	return typeof(value) == "Vector3"
		and value == value
		and math.abs(value.X) < 1e5
		and math.abs(value.Y) < 1e5
		and math.abs(value.Z) < 1e5
end

-- the Humanoid of the character a shot is locked onto, if the lock holds up
local function lockedTarget(character, ranged, origin, direction, target)
	if typeof(target) ~= "Instance" or not target:IsA("Model") or target == character or not target:IsDescendantOf(workspace) then
		return nil
	end
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 or target:GetAttribute("Invulnerable") then
		return nil
	end
	local offset = root.Position - origin
	if offset.Magnitude > SkillSetConfig.RangedReach(ranged) + LOCK_RANGE_SLACK then
		return nil
	end
	if offset.Magnitude > LOCK_CLOSE and math.deg(math.acos(math.clamp(offset.Unit:Dot(direction.Unit), -1, 1))) > LOCK_MAX_ANGLE then
		return nil
	end
	-- the first thing in the way has to be them
	local hit, struck = Projectiles.Cast(origin, offset, { character })
	if hit and struck ~= humanoid then
		return nil
	end
	return humanoid
end

local function startReload(player, setName, ranged)
	local rounds, reloading = SkillSetConfig.Rounds(player, setName)
	if reloading > 0 or rounds >= ranged.rounds then
		return
	end
	player:SetAttribute(SkillSetConfig.ReloadUntilAttribute(setName), workspace:GetServerTimeNow() + ranged.reload)
end

-- takes what one shot costs; false if it can't be paid
local function pay(player, setName, ranged)
	local now = workspace:GetServerTimeNow()
	if ranged.charges then
		local charges = SkillSetConfig.RangedCharges(player, setName)
		if charges < 1 - CHARGE_TOLERANCE then
			return false
		end
		player:SetAttribute(SkillSetConfig.RangedChargesAttribute(setName), charges - 1)
		player:SetAttribute(SkillSetConfig.RangedChargedAtAttribute(setName), now)
	elseif ranged.luminanceCost then
		local key = SkillSetConfig.LuminanceAttribute(setName)
		local luminance = player:GetAttribute(key) or 0
		if luminance < ranged.luminanceCost - 1e-6 then
			return false
		end
		player:SetAttribute(key, math.max(luminance - ranged.luminanceCost, 0))
	elseif ranged.rounds then
		local rounds, reloading = SkillSetConfig.Rounds(player, setName)
		if reloading > 0 then
			return false
		end
		if rounds < 1 then
			startReload(player, setName, ranged)
			return false
		end
		player:SetAttribute(SkillSetConfig.RoundsAttribute(setName), rounds - 1)
		-- the last round starts the reload
		player:SetAttribute(SkillSetConfig.ReloadUntilAttribute(setName), rounds - 1 <= 0 and now + ranged.reload or nil)
	end
	return true
end

fireRanged.OnServerEvent:Connect(function(player, action, origin, direction, id, target)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	-- (Rewinding: Photoshop's Undo is carrying her back, PhotoshopServer)
	if not root or humanoid.Health <= 0 or character:GetAttribute("Rewinding") then
		return
	end
	local _, setName = SkillSetConfig.Equipped(character)
	local ranged = setName and SkillSetConfig.Sets[setName].ranged
	if not ranged then
		return
	end
	if action == "reload" then
		if ranged.rounds then
			startReload(player, setName, ranged)
		end
		return
	end
	if action ~= "fire" or not isVector(origin) or not isVector(direction) or direction.Magnitude < 0.5 then
		return
	end
	if typeof(id) ~= "string" or #id > MAX_ID_LENGTH or (origin - root.Position).Magnitude > ORIGIN_TOLERANCE then
		return
	end
	local now = os.clock()
	if now - (lastShotAt[player] or -math.huge) < ranged.interval - TOLERANCE then
		return
	end
	if not pay(player, setName, ranged) then
		return
	end
	lastShotAt[player] = now
	local locked = ranged.aims and lockedTarget(character, ranged, origin, direction, target) or nil
	if locked and (locked.RootPart.Position - origin).Magnitude > 0.5 then
		direction = locked.RootPart.Position - origin
	end
	handlerFor(ranged.handler).Fire(player, character, origin, direction.Unit, id, locked)
end)

Players.PlayerRemoving:Connect(function(player)
	lastShotAt[player] = nil
end)
