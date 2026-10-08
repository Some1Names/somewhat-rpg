-- Framed: Photoshop's mark. Snapshot frames whoever it flashes for Duration
-- seconds, and her other skills build on it: Step In (Snapshot's recast)
-- needs someone framed, Paste (Photo Teleport's recast) moves them into her
-- photo, Shutter keeps the frame going, Iris Horizon closes almost at once
-- on them and Kaleidoscope hits them twice. Like Sunmark, the mark is kept
-- on the target's model as FramedUntil (server time) and FramedBy (the
-- caster's UserId), and only the caster is told, so only they see it
-- (SkillEffects "Framed"). A player holding Mandela with Misremembered
-- ready forgets the frame instead (Passives.ResistEdit).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Passives = require(ServerScriptService:WaitForChild("Passives"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local Framed = {}

Framed.Duration = 4 -- seconds

-- returns whether the frame took
function Framed.Mark(player, model)
	if not model or model:GetAttribute("Invulnerable") then
		return false
	end
	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if targetPlayer and Passives.ResistEdit(targetPlayer) then
		return false
	end
	model:SetAttribute("FramedUntil", workspace:GetServerTimeNow() + Framed.Duration)
	model:SetAttribute("FramedBy", player.UserId)
	skillEffects:FireClient(player, "Framed", model, Framed.Duration)
	return true
end

function Framed.Has(player, model)
	return model ~= nil
		and model:GetAttribute("FramedBy") == player.UserId
		and (model:GetAttribute("FramedUntil") or 0) > workspace:GetServerTimeNow()
end

-- keeps a frame going `seconds` longer, up to a fresh frame's Duration
function Framed.Extend(player, model, seconds)
	if not Framed.Has(player, model) then
		return
	end
	local now = workspace:GetServerTimeNow()
	local untilTime = math.min(model:GetAttribute("FramedUntil") + seconds, now + Framed.Duration)
	model:SetAttribute("FramedUntil", untilTime)
	skillEffects:FireClient(player, "Framed", model, untilTime - now)
end

-- the living target this player framed that's nearest `point` (flat),
-- within `radius` of it; nil if there's none
function Framed.Nearest(player, point, radius)
	local best, bestDistance
	local seen = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(point, radius + 20)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if root and not seen[model] then
			seen[model] = true
			local distance = ((root.Position - point) * Vector3.new(1, 0, 1)).Magnitude
			if humanoid.Health > 0 and distance <= radius and Framed.Has(player, model) and (not best or distance < bestDistance) then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

return Framed
