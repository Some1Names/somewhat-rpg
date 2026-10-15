-- Iridescent Requiem X, Prism Form: Ayato becomes living light. It needs the
-- set's form.minimumToStart Luminance and costs entryCost; while it lasts the
-- character's PrismForm attribute is on, LuminanceServer burns the light
-- instead of gathering it, physical hits pass through him (Passives), and the
-- skills marked `form` in SkillSetConfig are empowered. It ends when X is
-- pressed again (Revert), the light runs out, the set is put away, he
-- dies, or Photoshop's Desaturate drains the colour out of him (Desaturated,
-- which also keeps him from entering it). The light he leaves behind as he
-- moves lingers (form.trail) and burns anyone who stands in it, like
-- Lightstep's; it keeps burning until it fades after the form ends. Clients
-- draw the form from the attribute (SkillEffects).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local StatusEffects = require(ServerScriptService:WaitForChild("StatusEffects"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local SET_NAME = "IridescentRequiem"
local FORM = SkillSetConfig.Sets[SET_NAME].form
local LUMINANCE = SkillSetConfig.LuminanceAttribute(SET_NAME)
local RECAST = SkillSetConfig.RecastAttribute(SET_NAME, FORM.key)
local CHECK_INTERVAL = 0.1 -- seconds
local TRAIL = FORM.trail
local TRAIL_OPTIONS = { stat = "Superliminal", skillSet = SET_NAME, skill = "X" }
local JOIN_TIME = 0.4 -- seconds between two points that still count as one stretch of path
local JOIN_DISTANCE = 40 -- studs, the same (a Lightstep is 28)
local TRAIL_HEIGHT = 6 -- studs tall that the light burns

local function finish(player, character)
	character:SetAttribute(FORM.attribute, nil)
	player:SetAttribute(RECAST, nil)
end

-- adds a point to the path when he has moved far enough from the last one
local function layTrail(points, root)
	local now = os.clock()
	local last = points[#points]
	if last and (root.Position - last.position).Magnitude < TRAIL.minStep then
		return
	end
	local joined = last ~= nil and now - last.at <= JOIN_TIME and (root.Position - last.position).Magnitude <= JOIN_DISTANCE
	table.insert(points, { position = root.Position, at = now, joined = joined })
end

-- burns everyone in the path, the same person at most once per hitInterval
-- (`lastHurt`: humanoid -> when); points past the trail's duration are dropped
local function burnTrail(player, character, points, lastHurt)
	local now = os.clock()
	while points[1] and now - points[1].at > TRAIL.duration do
		table.remove(points, 1)
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	for i = 2, #points do
		local from, to = points[i - 1].position, points[i].position
		local distance = (to - from).Magnitude
		if points[i].joined and distance >= 0.5 then
			local box = CFrame.lookAt(from + (to - from) / 2, to)
			for _, part in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(TRAIL.width * 2, TRAIL_HEIGHT, distance), overlap)) do
				local model = part:FindFirstAncestorOfClass("Model")
				local target = model and model:FindFirstChildOfClass("Humanoid")
				if target and target.Health > 0 and now - (lastHurt[target] or -math.huge) >= TRAIL.hitInterval then
					lastHurt[target] = now
					if Damage.Deal(player, target, TRAIL.damage, TRAIL_OPTIONS) > 0 then
						StatusEffects.Apply(target, "Burnt", { source = player, stat = "Superliminal", skillSet = SET_NAME })
					end
				end
			end
		end
	end
end

-- keeps the form going until something ends it
local function watch(player, character, humanoid)
	local points = {}
	local lastHurt = setmetatable({}, { __mode = "k" })
	local root = humanoid.RootPart
	while character:GetAttribute(FORM.attribute) do
		task.wait(CHECK_INTERVAL)
		if root and root.Parent then
			layTrail(points, root)
			burnTrail(player, character, points, lastHurt)
		end
		local _, setName = SkillSetConfig.Equipped(character)
		if
			not player.Parent
			or player.Character ~= character
			or humanoid.Health <= 0
			or setName ~= SET_NAME
			or (player:GetAttribute(LUMINANCE) or 0) <= 0
			or StatusConfig.Stacks(character, "Desaturated") > 0
		then
			break
		end
	end
	finish(player, character)
	-- what he left behind keeps burning until it fades
	while #points > 0 and player.Parent do
		task.wait(CHECK_INTERVAL)
		burnTrail(player, character, points, lastHurt)
	end
end

local PrismForm = {}

-- returns false without enough light, so no cooldown is spent
function PrismForm.Cast(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute(FORM.attribute) then
		return false
	end
	if StatusConfig.Stacks(character, "Desaturated") > 0 then
		return false
	end
	local luminance = player:GetAttribute(LUMINANCE) or 0
	if luminance < FORM.minimumToStart then
		return false
	end
	player:SetAttribute(LUMINANCE, luminance - FORM.entryCost)
	character:SetAttribute(FORM.attribute, true)
	player:SetAttribute(RECAST, true)
	task.spawn(watch, player, character, humanoid)
	return true
end

-- X again: back to normal
function PrismForm.Recast(player, character)
	finish(player, character)
end

return PrismForm
