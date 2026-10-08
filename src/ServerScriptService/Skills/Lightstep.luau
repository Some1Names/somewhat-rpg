-- Iridescent Requiem's dash, Lightstep (the dash key while the set is
-- equipped): Ayato turns to light and flashes up to the set's dash.range
-- away. The client moves him (Dash) and DashRelay, after checking the dash's
-- cooldown, hands the move here to check it: he can't be hurt for the travel
-- time (the Invulnerable attribute Damage respects), and the light hurts
-- everyone along the path, harder in Prism Form, where it also leaves them
-- Burnt. Other clients draw the
-- streak from the SkillEffects "Lightstep" event (the dasher already drew
-- his own).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local SET_NAME = "IridescentRequiem"
local DASH = SkillSetConfig.Sets[SET_NAME].dash
local CONFIG = {
	Tolerance = 12, -- studs the server's copy of him may be from where the client says
	Grace = 0.1, -- extra seconds untouchable after arriving
	Damage = 8, -- to each target along the path, before the caster's Superliminal bonus
	FormDamage = 12, -- the same in Prism Form
	Width = 4, -- studs either side of the path that it burns
}
local DAMAGE_OPTIONS = { stat = "Superliminal", skillSet = SET_NAME }

local untouchableUntil = setmetatable({}, { __mode = "k" }) -- character -> os.clock()

local function burnPath(player, character, from, to, damage, burns)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local box = CFrame.lookAt(from + (to - from) / 2, to)
	local struck = {}
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(CONFIG.Width * 2, CONFIG.Width * 2, distance), overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local target = model and model:FindFirstChildOfClass("Humanoid")
		if target and not struck[target] and target.Health > 0 then
			struck[target] = true
			if Damage.Deal(player, target, damage, DAMAGE_OPTIONS) > 0 and burns then
				StatusEffects.Apply(target, "Burnt", { source = player, stat = "Superliminal", skillSet = SET_NAME })
			end
		end
	end
end

local Lightstep = {}

-- `from` and `to`: where the client says he left and arrived
function Lightstep.Dash(player, character, from, to)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 or (to - from).Magnitude > DASH.range + 1 then
		return
	end
	-- the server sees him either still at the start or already there
	local here = root.Position
	if (here - from).Magnitude > CONFIG.Tolerance and (here - to).Magnitude > CONFIG.Tolerance then
		return
	end

	-- untouchable while he's light; a second dash straight after extends it
	local untilTime = os.clock() + DASH.travelTime + CONFIG.Grace
	untouchableUntil[character] = untilTime
	character:SetAttribute("Invulnerable", true)
	task.delay(DASH.travelTime + CONFIG.Grace, function()
		if untouchableUntil[character] == untilTime then
			untouchableUntil[character] = nil
			character:SetAttribute("Invulnerable", nil)
		end
	end)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			skillEffects:FireClient(other, "Lightstep", character, from, to, DASH.travelTime)
		end
	end
	local inForm = SkillSetConfig.InForm(character, SET_NAME)
	burnPath(player, character, from, to, inForm and CONFIG.FormDamage or CONFIG.Damage, inForm)
end

return Lightstep
