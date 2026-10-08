-- Photoshop F, Kaleidoscope (the ultimate): reality round where she stands
-- shatters into mirrored fragments, Radius studs out, for Duration seconds.
-- Every TickInterval every enemy inside, at any height, is struck by one of
-- its own mirror images for HitDamage (twice if she's Framed them). While it
-- holds, light fired at her from inside it bounces back: Light Shot and
-- Prism Shot call Kaleidoscope.Reflect, and the beam hits the one who fired
-- it instead, as her hit. It ends early if she dies or puts the set away.
-- Clients draw it from the SkillEffects "Kaleidoscope", "KaleidoscopeHit",
-- "KaleidoscopeEnd" and "Reflect" events. SkillSetServer checks the tool,
-- mastery and cooldown before calling Cast.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Framed = require(ServerScriptService:WaitForChild("Framed"))
local PhotoshopUtil = require(ServerScriptService:WaitForChild("PhotoshopUtil"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Radius = 60, -- studs (SkillSetConfig's aim shows the same)
	Duration = 5, -- seconds
	TickInterval = 0.5, -- seconds
	HitDamage = 7, -- per mirror hit, before the caster's Superliminal bonus
	FramedHits = 2, -- mirror hits per tick on someone she's Framed
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Photoshop" }

local active = setmetatable({}, { __mode = "k" }) -- player -> { character, center, endsAt }

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local Kaleidoscope = {}

-- A beam worth `amount` (before the shooter's bonus) is about to hit
-- `humanoid`. If that's a Photoshop player inside her own running
-- Kaleidoscope and `shooter` fired from inside it too, it bounces back:
-- the shooter takes it as her hit, and this returns true (skip the hit).
function Kaleidoscope.Reflect(humanoid, shooter, amount)
	local reflector = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
	local zone = reflector and active[reflector]
	local shooterHumanoid = shooter and shooter:FindFirstChildOfClass("Humanoid")
	local shooterRoot = shooterHumanoid and shooterHumanoid.RootPart
	if not zone or zone.character ~= humanoid.Parent or os.clock() >= zone.endsAt or not shooterRoot then
		return false
	end
	if flat(shooterRoot.Position - zone.center).Magnitude > CONFIG.Radius then
		return false
	end
	local from = humanoid.RootPart and humanoid.RootPart.Position or zone.center
	Damage.Deal(reflector, shooterHumanoid, amount, DAMAGE_OPTIONS)
	skillEffects:FireAllClients("Reflect", from, shooterRoot.Position)
	return true
end

local function run(id, player, character, humanoid, zone)
	while os.clock() < zone.endsAt and PhotoshopUtil.alive(player, character, humanoid) do
		for _, target in ipairs(PhotoshopUtil.enemiesWithin(character, zone.center, CONFIG.Radius)) do
			local hits = Framed.Has(player, target.model) and CONFIG.FramedHits or 1
			for _ = 1, hits do
				Damage.Deal(player, target.humanoid, CONFIG.HitDamage, DAMAGE_OPTIONS)
			end
			skillEffects:FireAllClients("KaleidoscopeHit", id, target.model)
		end
		task.wait(CONFIG.TickInterval)
	end
	if os.clock() < zone.endsAt then
		skillEffects:FireAllClients("KaleidoscopeEnd", id)
	end
	if active[player] == zone then
		active[player] = nil
	end
end

function Kaleidoscope.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	local zone = { character = character, center = root.Position, endsAt = os.clock() + CONFIG.Duration }
	active[player] = zone
	local id = HttpService:GenerateGUID(false)
	skillEffects:FireAllClients("Kaleidoscope", id, character, zone.center, CONFIG.Radius, CONFIG.Duration)
	task.spawn(run, id, player, character, humanoid, zone)
	return true
end

return Kaleidoscope
