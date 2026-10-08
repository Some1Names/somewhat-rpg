-- Status effects: what each one does and how it looks. The server
-- (ServerScriptService.StatusEffects) applies them; a live effect is two
-- attributes on the character model, Status_<Name> (when it ends, in
-- workspace:GetServerTimeNow() time) and Status_<Name>Stacks, so every client
-- can draw it (StatusIcons over names and under your stamina, StatusVFX on
-- the body) and anything can check it with StatusConfig.Stacks.
--   duration   seconds; applying it again refreshes this and adds stacks
--   maxStacks  stacks it can build up to
--   damage     per tick per stack, before the attacker's stat bonus
--   tick       seconds between damage ticks
--   movingMultiplier  damage multiplier while the target moves or dashes
--   outgoing   multiplier on all damage the target deals
--   healing    multiplier on all healing the target gets
--   color, glyph  the icon
local StatusConfig = {}

StatusConfig.Effects = {
	Burnt = {
		duration = 4,
		maxStacks = 3,
		damage = 3,
		tick = 1,
		color = Color3.fromRGB(255, 110, 40),
		glyph = "\u{1F525}",
	},
	Bleeding = {
		duration = 5,
		maxStacks = 2,
		damage = 2,
		tick = 1,
		movingMultiplier = 2,
		color = Color3.fromRGB(170, 20, 35),
		glyph = "\u{1FA78}",
	},
	Poisoned = {
		duration = 8,
		maxStacks = 1,
		damage = 1.5,
		tick = 1,
		healing = 0.5,
		color = Color3.fromRGB(110, 200, 60),
		glyph = "\u{2620}",
	},
	Weakened = {
		duration = 5,
		maxStacks = 1,
		outgoing = 0.75,
		color = Color3.fromRGB(130, 120, 150),
		glyph = "\u{2B07}",
	},
	-- Photoshop's Desaturate drained the colour out of them: no Luminance
	-- gathers (it drains instead), no flight and no Prism Form
	-- (LuminanceServer, Skills.PrismForm). Refreshed while they stay in it.
	Desaturated = {
		duration = 1,
		maxStacks = 1,
		color = Color3.fromRGB(150, 150, 160),
		glyph = "\u{25D0}",
	},
}
-- the order icons are drawn in
StatusConfig.Order = { "Burnt", "Bleeding", "Poisoned", "Weakened", "Desaturated" }
StatusConfig.MovingSpeed = 4 -- studs per second along the ground that counts as moving

function StatusConfig.EndsAttribute(name)
	return "Status_" .. name
end

function StatusConfig.StacksAttribute(name)
	return "Status_" .. name .. "Stacks"
end

-- seconds this model has left of the effect (0 when it doesn't have it)
function StatusConfig.TimeLeft(model, name)
	local endsAt = model and model:GetAttribute(StatusConfig.EndsAttribute(name))
	if typeof(endsAt) ~= "number" then
		return 0
	end
	return math.max(0, endsAt - workspace:GetServerTimeNow())
end

-- stacks of the effect this model has (0 when it doesn't have it)
function StatusConfig.Stacks(model, name)
	if StatusConfig.TimeLeft(model, name) <= 0 then
		return 0
	end
	return model:GetAttribute(StatusConfig.StacksAttribute(name)) or 1
end

-- what all damage this model deals is multiplied by (Weakened)
function StatusConfig.OutgoingMultiplier(model)
	local multiplier = 1
	for name, effect in pairs(StatusConfig.Effects) do
		if effect.outgoing and StatusConfig.Stacks(model, name) > 0 then
			multiplier *= effect.outgoing
		end
	end
	return multiplier
end

-- what all healing this model gets is multiplied by (Poisoned)
function StatusConfig.HealMultiplier(model)
	local multiplier = 1
	for name, effect in pairs(StatusConfig.Effects) do
		if effect.healing and StatusConfig.Stacks(model, name) > 0 then
			multiplier *= effect.healing
		end
	end
	return multiplier
end

return StatusConfig
