-- Aido Z, Catastrophe: a warhead set down where he aimed (on the ground, up to
-- Range studs away). It goes off by itself after FuseTime, or Z again sets it
-- off at once (Detonate). The blast burns, leaves Fallout, and sets off
-- aftershocks while Chain Reaction is on. Casting again while one is still
-- armed sets the old one off first. SkillSetServer checks the tool, mastery and
-- cooldown before calling Cast.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AidoUtil = require(ServerScriptService:WaitForChild("AidoUtil"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 70, -- studs from the caster
	FuseTime = 1, -- seconds before it goes off by itself
	Radius = 14, -- studs
	Damage = 40, -- before the caster's Superliminal bonus
	Burnt = 1, -- stacks
}
local RECAST = SkillSetConfig.RecastAttribute("Aido", "Z") -- on the player, for the skill bar

local armed = {} -- caster -> entry, while their warhead is waiting

local Catastrophe = {}

function Catastrophe.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	if armed[player] then
		armed[player].detonate()
	end
	local position = AidoUtil.groundAt(AidoUtil.clampFlat(root.Position, aim, CONFIG.Range), { character })
	local id = HttpService:GenerateGUID(false)
	local entry = { done = false }
	function entry.detonate()
		if entry.done then
			return
		end
		entry.done = true
		if armed[player] == entry then
			armed[player] = nil
			if player.Parent then
				player:SetAttribute(RECAST, nil)
			end
		end
		AidoUtil.blast(player, character, position, {
			radius = CONFIG.Radius,
			damage = CONFIG.Damage,
			burnt = CONFIG.Burnt,
			form = true,
			aftershocks = true,
			skill = "Z",
			kind = "CatastropheBlast",
		})
	end
	armed[player] = entry
	player:SetAttribute(RECAST, true)
	skillEffects:FireAllClients("CatastropheArm", id, position, CONFIG.FuseTime)
	task.delay(CONFIG.FuseTime, entry.detonate)
	return true
end

-- Z again while it's armed
function Catastrophe.Recast(player)
	local entry = armed[player]
	if entry then
		entry.detonate()
	end
end

return Catastrophe
