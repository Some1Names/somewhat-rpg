-- Iridescent Requiem Z, Prism Shot: light from Ayato's hand splits into a
-- fan of orange and cyan beams toward where he aimed, tilted up or down to it. Each beam goes through
-- everyone along it and stops at walls; in Prism Form the fan is wider.
-- Whoever it hits gets a Sunmark, which Solar Lance locks onto.
-- Clients draw it from the SkillEffects "PrismShot" event.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Sunmark = require(ServerScriptService:WaitForChild("Sunmark"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Length = 45, -- studs
	Count = 5, -- beams
	Spread = 10, -- degrees between neighbouring beams
	FormCount = 7, -- in Prism Form (SkillSetConfig's formAim shows the same)
	FormSpread = 8,
	Width = 2.5, -- studs either side of a beam that it catches
	Damage = 9, -- per beam, before the caster's Superliminal bonus
	ReleaseDelay = 0.12, -- lines the beams up with the cast animation
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "IridescentRequiem" }

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- first thing in the way that isn't a character (the light goes through those)
local function firstWall(from, offset, character)
	local ignore = { character }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, offset, params)
		if not hit then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			return hit.Position
		end
		table.insert(ignore, model)
	end
	return nil
end

-- everyone a beam from `from` to `tip` passes through
local function along(character, from, tip)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local length = (tip - from).Magnitude
	local box = CFrame.lookAt(from + (tip - from) / 2, tip)
	local struck = {}
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(CONFIG.Width * 2, CONFIG.Width * 2, length), overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			struck[humanoid] = true
		end
	end
	return struck
end

local function fire(player, character, aim, inForm)
	task.wait(CONFIG.ReleaseDelay)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return
	end
	local hand = character:FindFirstChild("RightHand") or root
	local origin = hand.Position
	local ahead = aim - origin
	if flat(ahead).Magnitude < 1 then
		ahead = flat(root.CFrame.LookVector)
	end
	ahead = ahead.Unit
	-- the fan opens sideways around the aim, whatever its tilt
	local aimFrame = CFrame.lookAt(Vector3.zero, ahead)
	local count = inForm and CONFIG.FormCount or CONFIG.Count
	local spread = inForm and CONFIG.FormSpread or CONFIG.Spread
	local tips = {}
	for i = 1, count do
		local turn = math.rad((i - (count + 1) / 2) * spread)
		local direction = (aimFrame * CFrame.Angles(0, turn, 0)).LookVector
		local wall = firstWall(origin, direction * CONFIG.Length, character)
		local tip = wall or origin + direction * CONFIG.Length
		tips[i] = tip
		for struck in pairs(along(character, origin, tip)) do
			Damage.Deal(player, struck, CONFIG.Damage, DAMAGE_OPTIONS)
			if struck.Health > 0 then
				Sunmark.Mark(player, struck.Parent)
			end
		end
	end
	skillEffects:FireAllClients("PrismShot", origin, tips)
end

local PrismShot = {}

function PrismShot.Cast(player, character, aim)
	if not (character:FindFirstChildOfClass("Humanoid") and character:FindFirstChild("HumanoidRootPart")) then
		return false
	end
	task.spawn(function()
		local ok, err = pcall(fire, player, character, aim, SkillSetConfig.InForm(character, "IridescentRequiem"))
		if not ok then
			warn("[Skills.PrismShot] " .. tostring(err))
		end
	end)
	return true
end

return PrismShot
