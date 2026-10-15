-- Aido C, Total Destruction: a line of blasts marching away from him over
-- Length studs, one every StepTime, each on the ground under its point. While
-- Chain Reaction is on it's three lines Spread degrees apart. Nobody takes
-- more than MaxHits blasts of one cast (aftershocks don't count). Each blast
-- leaves Fallout and, with Chain Reaction, aftershocks. SkillSetServer checks
-- the tool, mastery and cooldown before calling Cast.
local ServerScriptService = game:GetService("ServerScriptService")

local AidoMath = require(ServerScriptService:WaitForChild("AidoMath"))
local AidoUtil = require(ServerScriptService:WaitForChild("AidoUtil"))
local Overcharge = require(ServerScriptService:WaitForChild("Overcharge"))

local CONFIG = {
	Length = 80, -- studs
	Blasts = 6, -- per line
	StepTime = 0.15, -- seconds between blasts down a line
	Radius = 8, -- studs
	Damage = 14, -- before the caster's Superliminal bonus
	MaxHits = 3, -- blasts one person takes from one cast
	Lines = 3, -- while Chain Reaction is on
	Spread = 25, -- degrees between lines
}

local TotalDestruction = {}

function TotalDestruction.Cast(player, character, aim)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 then
		return false
	end
	-- toward where they aimed, or straight ahead if that's right underfoot
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	if flat.Magnitude < 2 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	local lines = Overcharge.IsActive(player, "Aido") and CONFIG.Lines or 1
	local struck = {}
	for _, direction in ipairs(AidoMath.fan(flat, lines, CONFIG.Spread)) do
		for i, point in ipairs(AidoMath.linePoints(root.Position, direction, CONFIG.Length, CONFIG.Blasts)) do
			local ground = AidoUtil.groundAt(point, { character })
			task.delay((i - 1) * CONFIG.StepTime, function()
				AidoUtil.blast(player, character, ground, {
					radius = CONFIG.Radius,
					damage = CONFIG.Damage,
					form = true,
					aftershocks = true,
					struck = struck,
					maxHits = CONFIG.MaxHits,
					skill = "C",
					kind = "TotalDestructionBlast",
				})
			end)
		end
	end
	return true
end

return TotalDestruction
