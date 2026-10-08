-- Sunmark: Iridescent Requiem's Prism Shot and Refraction Field leave a mark
-- of sunlight on whoever they hit, for Duration seconds, and Solar Lance
-- cast near someone marked locks onto them (Skills.SolarLance). The mark is
-- kept on the target's model as SunmarkUntil (server time) and SunmarkBy
-- (the caster's UserId), like Damage.Expose; only the caster is told, so
-- only they see it (SkillEffects "Sunmark"). Everyone marked is also set
-- Burnt (StatusEffects), a stack at most every BurnInterval seconds, so
-- Refraction Field's quick beams don't max it out at once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local Sunmark = {}

Sunmark.Duration = 4 -- seconds
Sunmark.BurnInterval = 1 -- seconds between Burnt stacks on one target

local lastBurntAt = setmetatable({}, { __mode = "k" }) -- model -> os.clock() of its last stack

function Sunmark.Mark(player, model)
	if not model or model:GetAttribute("Invulnerable") then
		return
	end
	model:SetAttribute("SunmarkUntil", workspace:GetServerTimeNow() + Sunmark.Duration)
	model:SetAttribute("SunmarkBy", player.UserId)
	skillEffects:FireClient(player, "Sunmark", model, Sunmark.Duration)
	if os.clock() - (lastBurntAt[model] or -math.huge) >= Sunmark.BurnInterval - 0.05 then
		lastBurntAt[model] = os.clock()
		StatusEffects.Apply(model, "Burnt", { source = player, stat = "Superliminal", skillSet = "IridescentRequiem" })
	end
end

function Sunmark.Has(player, model)
	return model:GetAttribute("SunmarkBy") == player.UserId
		and (model:GetAttribute("SunmarkUntil") or 0) > workspace:GetServerTimeNow()
end

function Sunmark.Consume(model)
	model:SetAttribute("SunmarkUntil", nil)
	model:SetAttribute("SunmarkBy", nil)
end

-- the living target this player marked that's nearest `point` (flat),
-- within `radius` of it; nil if there's none
function Sunmark.Nearest(player, point, radius)
	local best, bestDistance
	local seen = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(point, radius + 20)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not seen[model] then
			seen[model] = true
			local distance = ((root.Position - point) * Vector3.new(1, 0, 1)).Magnitude
			if humanoid.Health > 0 and distance <= radius and Sunmark.Has(player, model) and (not best or distance < bestDistance) then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

return Sunmark
