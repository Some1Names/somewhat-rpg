-- Photoshop's ranged move, Shutter: a camera flash straight to where she
-- aimed (or at whoever aim assist locked onto), there at once, stopped by
-- the first person or wall. A flash on someone she's Framed keeps the frame
-- going FrameExtend seconds longer (Framed.Extend). RangedServer has already
-- checked it, pointed it and spent a charge. Other clients draw it from the
-- SkillEffects "Shutter" event (the shooter drew her own).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local Framed = require(ServerScriptService:WaitForChild("Framed"))
local Projectiles = require(ServerScriptService:WaitForChild("Projectiles"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local CONFIG = {
	Damage = 9, -- before the shooter's Superliminal bonus
	FrameExtend = 1.5, -- seconds a flash adds to her frame on them
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = "Photoshop" }
local RANGE = SkillSetConfig.Sets.Photoshop.ranged.beam.range

local Shutter = {}

function Shutter.Fire(player, character, origin, direction)
	local hit, humanoid = Projectiles.Cast(origin, direction * RANGE, { character })
	local finish = hit and hit.Position or origin + direction * RANGE
	if humanoid then
		Damage.Deal(player, humanoid, CONFIG.Damage, DAMAGE_OPTIONS)
		Framed.Extend(player, humanoid.Parent, CONFIG.FrameExtend)
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			skillEffects:FireClient(other, "Shutter", origin, finish, humanoid ~= nil)
		end
	end
end

return Shutter
