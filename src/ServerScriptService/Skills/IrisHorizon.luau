-- Photoshop V, Iris Horizon: a ring of photographs forms round the enemy
-- nearest where she aimed (within Range and Cone; the skill bar's preview
-- picks the same one) and closes in like a camera's iris over CloseTime,
-- drifting after them at FollowSpeed, a touch faster than a sprint. When it
-- shuts, reality inside collapses into a rainbow black hole that bursts:
-- TargetDamage to them and SplashDamage to everyone else within
-- SplashRadius, and anyone flying is knocked out of the air (unless
-- Mandela's Misremembered forgets it, Passives.ResistEdit). A target who
-- got out of the ring before it shut (a dash, flight) takes only
-- EscapedDamage. On someone she's Framed it starts half shut and closes in
-- FramedCloseTime. It's called off if she dies or puts the set away, and
-- bursts where it was if the target dies or goes. Clients draw it from the
-- SkillEffects "IrisHorizon", "IrisBurst" and "IrisCancel" events.
-- SkillSetServer checks the tool, mastery and cooldown before calling Cast.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Framed = require(ServerScriptService:WaitForChild("Framed"))
local Passives = require(ServerScriptService:WaitForChild("Passives"))
local PhotoshopUtil = require(ServerScriptService:WaitForChild("PhotoshopUtil"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Range = 120, -- studs, the lock's reach (SkillSetConfig's aim shows the same)
	Cone = 30, -- degrees either side of the aim it locks onto a target in
	RingRadius = 8, -- studs (16 across) when it forms
	CloseTime = 1.5, -- seconds to shut
	FramedCloseTime = 0.4, -- seconds to shut on a framed target
	FramedStartShare = 0.5, -- how far shut it already is on a framed target
	FollowSpeed = 34, -- studs per second the ring drifts after them (sprint is 32)
	TargetDamage = 45, -- before the caster's Superliminal bonus
	SplashDamage = 25,
	SplashRadius = 10, -- studs round the burst
	EscapedDamage = 10, -- to a target who got out before it shut
	EscapeMargin = 2, -- studs past the ring before they count as out (network jitter)
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Photoshop" }
local BURST_OPTIONS = { stat = "Superliminal", skillSet = "Photoshop", critical = true }

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- knocked out of the air, unless Misremembered forgets it
local function ground(model)
	if not model:GetAttribute("Flying") then
		return
	end
	local targetPlayer = PhotoshopUtil.playerOf(model)
	if targetPlayer and Passives.ResistEdit(targetPlayer) then
		return
	end
	model:SetAttribute("Flying", nil)
end

local function burst(id, player, character, center, target, caught)
	if target then
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			if caught then
				Damage.Deal(player, humanoid, CONFIG.TargetDamage, BURST_OPTIONS)
				ground(target)
			else
				Damage.Deal(player, humanoid, CONFIG.EscapedDamage, DAMAGE_OPTIONS)
			end
		end
	end
	for _, other in ipairs(PhotoshopUtil.enemiesWithin(character, center, CONFIG.SplashRadius)) do
		if other.model ~= target then
			Damage.Deal(player, other.humanoid, CONFIG.SplashDamage, DAMAGE_OPTIONS)
			ground(other.model)
		end
	end
	skillEffects:FireAllClients("IrisBurst", id, center, CONFIG.SplashRadius, caught)
end

local function run(id, player, character, humanoid, target, closeTime, startShare)
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	local center = targetHumanoid.RootPart.Position
	local startRadius = CONFIG.RingRadius * (1 - startShare)
	local escaped = false
	local started = os.clock()
	while true do
		local dt = RunService.Heartbeat:Wait()
		if not PhotoshopUtil.alive(player, character, humanoid) then
			skillEffects:FireAllClients("IrisCancel", id)
			return
		end
		local targetRoot = target.Parent and targetHumanoid.Health > 0 and targetHumanoid.RootPart
		if not targetRoot then
			-- they died or left: it bursts where it was
			burst(id, player, character, center, nil, false)
			return
		end
		local share = math.clamp((os.clock() - started) / closeTime, 0, 1)
		local radius = startRadius * (1 - share)
		local toward = flat(targetRoot.Position - center)
		local step = math.min(toward.Magnitude, CONFIG.FollowSpeed * dt)
		if step > 0 then
			center += toward.Unit * step
		end
		center = Vector3.new(center.X, targetRoot.Position.Y, center.Z)
		-- out past the shrinking ring once is out for good
		if not escaped and share < 1 and flat(targetRoot.Position - center).Magnitude > radius + CONFIG.EscapeMargin then
			escaped = true
		end
		if share >= 1 then
			burst(id, player, character, center, target, not escaped)
			return
		end
	end
end

local IrisHorizon = {}

-- returns false with nobody to lock onto, so no cooldown is spent
function IrisHorizon.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	local targetRoot = PhotoshopUtil.lockOn(character, root, aim, CONFIG.Range, CONFIG.Cone)
	if not targetRoot then
		return false
	end
	local target = targetRoot.Parent
	local framed = Framed.Has(player, target)
	local closeTime = framed and CONFIG.FramedCloseTime or CONFIG.CloseTime
	local startShare = framed and CONFIG.FramedStartShare or 0
	local id = HttpService:GenerateGUID(false)
	skillEffects:FireAllClients("IrisHorizon", id, target, CONFIG.RingRadius, closeTime, startShare, CONFIG.FollowSpeed)
	task.spawn(run, id, player, character, humanoid, target, closeTime, startShare)
	return true
end

return IrisHorizon
