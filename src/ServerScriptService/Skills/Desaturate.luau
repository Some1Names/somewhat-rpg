-- Photoshop C, Desaturate: the colour drains out of a circle where she aimed
-- (up to Range away) for Duration seconds. Every TickInterval everyone in
-- it, at any height, takes TickDamage and is Desaturated (StatusConfig) for
-- Linger seconds, so it holds while they stay in and wears off just after
-- they leave: no Luminance gathers, no flight, no Prism Form
-- (LuminanceServer, Skills.PrismForm). Mandela's Misremembered forgets the
-- edit for the rest of that zone (Passives.ResistEdit); the damage still
-- lands. The zone ends early if she dies or puts the set away. Clients draw
-- it from the SkillEffects "Desaturate" event ("DesaturateEnd" if it ends early). SkillSetServer checks the
-- tool, mastery and charges before calling Cast.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Passives = require(ServerScriptService:WaitForChild("Passives"))
local PhotoshopUtil = require(ServerScriptService:WaitForChild("PhotoshopUtil"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 50, -- studs from her the centre can be (SkillSetConfig's aim shows the same)
	Radius = 18, -- studs
	Duration = 4, -- seconds
	TickInterval = 0.5, -- seconds
	TickDamage = 4, -- per tick, before the caster's Superliminal bonus
	Linger = 1, -- seconds Desaturated lasts after the last tick on them
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Photoshop" }
local STATUS_OPTIONS = { stat = "Superliminal", skillSet = "Photoshop", duration = CONFIG.Linger }

local function run(id, player, character, humanoid, center)
	local resisted = {} -- models whose Misremembered forgot this zone
	local options = table.clone(STATUS_OPTIONS)
	options.source = player
	local endsAt = os.clock() + CONFIG.Duration
	while os.clock() < endsAt and PhotoshopUtil.alive(player, character, humanoid) do
		for _, target in ipairs(PhotoshopUtil.enemiesWithin(character, center, CONFIG.Radius)) do
			Damage.Deal(player, target.humanoid, CONFIG.TickDamage, DAMAGE_OPTIONS)
			local targetPlayer = PhotoshopUtil.playerOf(target.model)
			if not resisted[target.model] and targetPlayer and Passives.ResistEdit(targetPlayer) then
				resisted[target.model] = true
			end
			if not resisted[target.model] then
				StatusEffects.Apply(target.model, "Desaturated", options)
			end
		end
		task.wait(CONFIG.TickInterval)
	end
	if os.clock() < endsAt then
		skillEffects:FireAllClients("DesaturateEnd", id)
	end
end

local Desaturate = {}

function Desaturate.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	local spot = PhotoshopUtil.clampFlat(root.Position, aim, CONFIG.Range)
	local ground = PhotoshopUtil.groundAt(spot, { character })
	local center = ground and ground - Vector3.new(0, 3, 0) or spot -- groundAt stands a root 3 up
	local id = HttpService:GenerateGUID(false)
	skillEffects:FireAllClients("Desaturate", id, center, CONFIG.Radius, CONFIG.Duration)
	task.spawn(run, id, player, character, humanoid, center)
	return true
end

return Desaturate
