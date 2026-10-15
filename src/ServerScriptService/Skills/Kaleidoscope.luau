-- Photoshop F, Kaleidoscope (the ultimate): reality round where she stands
-- shatters into mirrored fragments, Radius studs out, for Duration seconds.
-- Every TickInterval every enemy inside, at any height, is struck by their
-- own mirror images for HitDamage each. The mirrors multiply as it turns: one
-- image strikes at first, then two after StageTime seconds, then three, and
-- someone she'd Framed before it began takes FramedExtraHits more every tick.
-- Everyone it strikes is Framed (and kept framed while it holds), so Step In
-- (Snapshot's recast, on Z) is ready to warp her behind the nearest of them
-- until the frame wears off, a few seconds after it ends (Mandela's
-- Misremembered still forgets it, as with any frame). When it runs
-- its course the mirrors shatter, and everyone still inside takes
-- FinaleDamage. While it holds, light fired at her from inside it bounces
-- back: Light Shot and Prism Shot call Kaleidoscope.Reflect, and the beam
-- hits the one who fired it instead, as her hit. It ends early (no finale) if
-- she dies or puts the set away.
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
local Snapshot = require(ServerScriptService:WaitForChild("Skills"):WaitForChild("Snapshot"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Radius = 60, -- studs (SkillSetConfig's aim shows the same)
	Duration = 6, -- seconds
	TickInterval = 0.5, -- seconds
	HitDamage = 5, -- per mirror hit, before the caster's Superliminal bonus
	StageTime = 2, -- seconds per stage: that many mirror hits per tick (1, 2, 3)
	FramedExtraHits = 1, -- more mirror hits per tick on someone she's Framed
	HitSpacing = 0.08, -- seconds between one tick's hits landing, so the images strike in turn
	FinaleDamage = 30, -- to everyone inside when the mirrors shatter, before the caster's Superliminal bonus
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Photoshop", guard = "unblockable", skill = "F" }

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

-- one mirror image striking `target`, `delay` seconds from now (the damage lands now)
local function strike(id, player, target, damage, delay)
	Damage.Deal(player, target.humanoid, damage, DAMAGE_OPTIONS)
	task.delay(delay, function()
		skillEffects:FireAllClients("KaleidoscopeHit", id, target.model)
	end)
end

-- Frames everyone in `targets` (or keeps their frame going) and readies Step In
-- on the one nearest her, unless she has Stepped In since `since` (one warp
-- per ultimate). `resisted` holds those whose frame was forgotten
-- (Mandela's Misremembered): they aren't tried again.
local function frameThem(player, root, targets, resisted, since)
	local nearest, nearestDistance
	for _, target in ipairs(targets) do
		if not resisted[target.model] then
			if not Framed.Mark(player, target.model) then
				resisted[target.model] = true
			else
				local distance = (target.root.Position - root.Position).Magnitude
				if not nearest or distance < nearestDistance then
					nearest, nearestDistance = target.model, distance
				end
			end
		end
	end
	if nearest and not Snapshot.SteppedInSince(player, since) then
		Snapshot.Arm(player, nearest)
	end
end

local function run(id, player, character, humanoid, zone)
	local startedAt = os.clock()
	local stages = math.max(1, math.floor(CONFIG.Duration / CONFIG.StageTime))
	local root = humanoid.RootPart
	local framedBefore = {} -- models she'd Framed before the first strike on them
	local resisted = {}
	while os.clock() < zone.endsAt and PhotoshopUtil.alive(player, character, humanoid) do
		local stage = math.min(math.floor((os.clock() - startedAt) / CONFIG.StageTime) + 1, stages)
		local targets = PhotoshopUtil.enemiesWithin(character, zone.center, CONFIG.Radius)
		for _, target in ipairs(targets) do
			if framedBefore[target.model] == nil then
				framedBefore[target.model] = Framed.Has(player, target.model)
			end
			local hits = stage + (framedBefore[target.model] and CONFIG.FramedExtraHits or 0)
			for i = 1, hits do
				strike(id, player, target, CONFIG.HitDamage, (i - 1) * CONFIG.HitSpacing)
			end
		end
		frameThem(player, root, targets, resisted, startedAt)
		task.wait(CONFIG.TickInterval)
	end
	if os.clock() < zone.endsAt then
		skillEffects:FireAllClients("KaleidoscopeEnd", id)
	elseif PhotoshopUtil.alive(player, character, humanoid) then
		-- it ran its course: the mirrors shatter on everyone still inside
		local targets = PhotoshopUtil.enemiesWithin(character, zone.center, CONFIG.Radius)
		for _, target in ipairs(targets) do
			strike(id, player, target, CONFIG.FinaleDamage, 0)
		end
		frameThem(player, root, targets, resisted, startedAt)
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
	skillEffects:FireAllClients("Kaleidoscope", id, character, zone.center, CONFIG.Radius, CONFIG.Duration, CONFIG.StageTime)
	task.spawn(run, id, player, character, humanoid, zone)
	return true
end

return Kaleidoscope
