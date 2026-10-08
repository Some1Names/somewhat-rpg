-- Iridescent Requiem X, Prism Form: Ayato becomes living light. It needs the
-- set's form.minimumToStart Luminance and costs entryCost; while it lasts the
-- character's PrismForm attribute is on, LuminanceServer burns the light
-- instead of gathering it, physical hits pass through him (Passives), and the
-- skills marked `form` in SkillSetConfig are empowered. It ends when X is
-- pressed again (Revert), the light runs out, the set is put away, he
-- dies, or Photoshop's Desaturate drains the colour out of him (Desaturated,
-- which also keeps him from entering it). Clients draw it from the
-- attribute (SkillEffects).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local SET_NAME = "IridescentRequiem"
local FORM = SkillSetConfig.Sets[SET_NAME].form
local LUMINANCE = SkillSetConfig.LuminanceAttribute(SET_NAME)
local RECAST = SkillSetConfig.RecastAttribute(SET_NAME, FORM.key)
local CHECK_INTERVAL = 0.1 -- seconds

local function finish(player, character)
	character:SetAttribute(FORM.attribute, nil)
	player:SetAttribute(RECAST, nil)
end

-- keeps the form going until something ends it
local function watch(player, character, humanoid)
	while character:GetAttribute(FORM.attribute) do
		task.wait(CHECK_INTERVAL)
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
