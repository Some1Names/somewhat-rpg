-- Iridescent Requiem C, Refraction Field: a cluster of floating crystals is
-- planted where Ayato aimed (up to Range away). For Duration seconds it
-- splits light into a beam that jumps from it through everyone within
-- Radius, nearest first, hurting each of them every Interval; planted in
-- Prism Form, it's bigger and reaches FormRadius. It has charges
-- (SkillSetConfig), so several can be out at once. Clients draw the crystals
-- from the SkillEffects "RefractionField" event (until "PrismBreak" with
-- the same id) and the beams from "RefractionBeams". Whoever the beam
-- hits gets a Sunmark, which Solar Lance locks onto, and is Weakened
-- (blinded by the split light) while it keeps hitting them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))
local Sunmark = require(ServerScriptService:WaitForChild("Sunmark"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 50, -- studs from the caster
	Radius = 18, -- studs around the prism it reaches
	FormRadius = 36, -- planted in Prism Form (SkillSetConfig's formAim shows the same)
	FormSizeMultiplier = 1.5,
	Duration = 5, -- seconds
	Interval = 0.5, -- seconds between beams
	Damage = 6, -- per target per beam, before the caster's Superliminal bonus
	MaxChain = 6, -- targets one beam can jump through
	Hover = 4, -- studs above the ground
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "IridescentRequiem" }
local COLOR = SkillSetConfig.Sets.IridescentRequiem.color

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function groundAt(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -200, 0), params)
	return hit and hit.Position
end

local fieldCount = 0

-- everyone within reach of the prism, nearest first
local function inReach(character, center, radius)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local found, seen = {}, {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not seen[humanoid] and humanoid.Health > 0 and (root.Position - center).Magnitude <= radius then
			seen[humanoid] = true
			table.insert(found, { humanoid = humanoid, root = root, distance = (root.Position - center).Magnitude })
		end
	end
	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)
	return found
end

local function run(player, character, center, inForm)
	local radius = inForm and CONFIG.FormRadius or CONFIG.Radius
	fieldCount += 1
	local id = fieldCount
	skillEffects:FireAllClients("RefractionField", id, center, radius, inForm and CONFIG.FormSizeMultiplier or 1, CONFIG.Duration)
	local startedAt = os.clock()
	local ok, err = pcall(function()
		while os.clock() - startedAt < CONFIG.Duration do
			local chain = {}
			for i, target in ipairs(inReach(character, center, radius)) do
				if i > CONFIG.MaxChain then
					break
				end
				local dealt = Damage.Deal(player, target.humanoid, CONFIG.Damage, DAMAGE_OPTIONS)
				if target.humanoid.Health > 0 then
					Sunmark.Mark(player, target.humanoid.Parent)
					if dealt > 0 then
						StatusEffects.Apply(target.humanoid, "Weakened", { source = player, stat = "Superliminal", skillSet = "IridescentRequiem" })
					end
				end
				table.insert(chain, target.root.Position)
			end
			if #chain > 0 then
				skillEffects:FireAllClients("RefractionBeams", center, chain)
			end
			task.wait(CONFIG.Interval)
		end
	end)
	skillEffects:FireAllClients("PrismBreak", center, COLOR, id)
	if not ok then
		warn("[Skills.RefractionField] " .. tostring(err))
	end
end

local RefractionField = {}

-- returns false when there's no ground to plant it on, so no cooldown is spent
function RefractionField.Cast(player, character, aim)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local reach = flat(aim - root.Position)
	if reach.Magnitude > CONFIG.Range then
		reach = reach.Unit * CONFIG.Range
	end
	local ground = groundAt(root.Position + reach, { character })
	if not ground then
		return false
	end
	task.spawn(run, player, character, ground + Vector3.new(0, CONFIG.Hover, 0), SkillSetConfig.InForm(character, "IridescentRequiem"))
	return true
end

return RefractionField
