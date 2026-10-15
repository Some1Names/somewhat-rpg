-- Aido's ranged move, Fuse: a fission seed thrown where he aimed. It sticks to
-- the first person it hits (and follows them) or to where it stops (a wall, the
-- floor, the end of its range), then pops a second later: a small blast with
-- the Half-Life bonus on someone Burnt, but no Fallout, no Burnt and no
-- aftershocks, so clicking never snowballs. A target that dies or leaves in
-- that second doesn't matter: it pops where it last was and hurts whoever is
-- there then. RangedServer has already checked the throw and spent a charge.
-- Clients draw the seed in flight (Projectile), stuck (FuseStick) and the pop
-- (FusePop, then the FuseBlast ring).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local AidoUtil = require(ServerScriptService:WaitForChild("AidoUtil"))
local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	FuseTime = 1, -- seconds from sticking to popping
	Radius = 6, -- studs
	Damage = 18, -- before the thrower's Superliminal bonus
}
local FLIGHT = SkillSetConfig.Sets.Aido.ranged.projectile

-- sticks at `position` (or to `struck`, following them), pops after FuseTime
local function stick(player, character, id, position, struck)
	local root = struck and struck.RootPart
	skillEffects:FireAllClients("FuseStick", id, root, position)
	local last = root and root.Position or position
	local startedAt = os.clock()
	while os.clock() - startedAt < CONFIG.FuseTime do
		RunService.Heartbeat:Wait()
		if root and root.Parent and struck.Health > 0 then
			last = root.Position
		else
			root = nil -- gone or dead: it stays where it was
		end
	end
	skillEffects:FireAllClients("FusePop", id, last)
	AidoUtil.blast(player, character, last, {
		radius = CONFIG.Radius,
		damage = CONFIG.Damage,
		fallout = false,
		aftershocks = false,
		guard = "ranged",
		skill = "ranged",
		kind = "FuseBlast",
	})
end

local Fuse = {}

function Fuse.Fire(player, character, origin, direction, id, target)
	Projectiles.Launch({
		owner = player,
		character = character,
		id = id,
		model = FLIGHT.model,
		origin = origin,
		direction = direction,
		speed = FLIGHT.speed,
		range = FLIGHT.range,
		radius = FLIGHT.radius,
		homing = target and target.RootPart,
		onStop = function(position, _, struck)
			task.spawn(stick, player, character, id, position, struck)
		end,
	})
end

return Fuse
