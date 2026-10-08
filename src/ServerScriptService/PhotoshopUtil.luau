-- Small helpers the Photoshop skills share (ServerScriptService.Skills:
-- Snapshot, PhotoTeleport, Desaturate, IrisHorizon, Kaleidoscope, and
-- PhotoshopServer): where the ground is under a spot she'd teleport to, who
-- a "lock" aim picks, who stands in a zone, and whether the caster is still
-- casting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local SET_NAME = "Photoshop"
local GROUND_RAY = 200 -- studs down from a spot to look for ground
local STAND_HEIGHT = 3 -- studs above the ground a teleported root lands

local PhotoshopUtil = {}

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

function PhotoshopUtil.playerOf(model)
	return model and Players:GetPlayerFromCharacter(model)
end

-- the player is still in the game, on that character, alive and holding Photoshop
function PhotoshopUtil.alive(player, character, humanoid)
	if not player.Parent or player.Character ~= character or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local _, setName = SkillSetConfig.Equipped(character)
	return setName == SET_NAME
end

-- where a root should stand over `position`: the ground beneath it (past
-- characters), looked for from `rise` studs above it (4 by default),
-- STAND_HEIGHT up; nil over the void
function PhotoshopUtil.groundAt(position, ignore, rise)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local skip = table.clone(ignore or {})
	local effects = workspace:FindFirstChild("SkillEffects")
	if effects then
		table.insert(skip, effects)
	end
	local from = position + Vector3.new(0, rise or 4, 0)
	for _ = 1, 6 do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(from, Vector3.new(0, -GROUND_RAY, 0), params)
		if not hit then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			return hit.Position + Vector3.new(0, STAND_HEIGHT, 0)
		end
		table.insert(skip, model)
	end
	return nil
end

-- the spot a circle aim points at, at `origin`'s height (the client's aim
-- height isn't trusted, and is far off when the mouse is on the sky), at
-- most `range` studs out (flat); look for the ground under it from
-- AIM_RISE up, as SolarLance and the aim preview do
PhotoshopUtil.AIM_RISE = 20
function PhotoshopUtil.clampFlat(origin, aim, range)
	local offset = flat(aim - origin)
	if offset.Magnitude > range then
		offset = offset.Unit * range
	end
	return origin + offset
end

-- the root part of the character nearest the direction of `aim`, within
-- range and the cone (the same pick as AimIndicator.LockTarget on the client)
function PhotoshopUtil.lockOn(character, root, aim, range, cone)
	local wanted = flat(aim - root.Position)
	if wanted.Magnitude < 0.1 then
		wanted = flat(root.CFrame.LookVector)
	end
	wanted = wanted.Unit
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local best, bestAngle
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, range, overlap)) do
		local model = part.Parent
		local humanoid = part.Name == "HumanoidRootPart" and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not model:GetAttribute("Invulnerable") then
			local toward = flat(part.Position - root.Position)
			if toward.Magnitude > 0.1 then
				local angle = math.deg(math.acos(math.clamp(toward.Unit:Dot(wanted), -1, 1)))
				if angle <= cone and (not bestAngle or angle < bestAngle) then
					best, bestAngle = part, angle
				end
			end
		end
	end
	return best
end

-- everyone alive but `character` whose root is within `radius` (flat) of
-- `center`, at any height (zones are columns): { { model, humanoid, root } }
function PhotoshopUtil.enemiesWithin(character, center, radius)
	local found, seen = {}, {}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local size = Vector3.new(radius * 2, 400, radius * 2)
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(center), size, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not seen[model] then
			seen[model] = true
			if humanoid.Health > 0 and not model:GetAttribute("Invulnerable") and flat(root.Position - center).Magnitude <= radius then
				table.insert(found, { model = model, humanoid = humanoid, root = root })
			end
		end
	end
	return found
end

return PhotoshopUtil
