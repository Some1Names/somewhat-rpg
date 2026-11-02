-- Footstep sounds (Footsteps client): which clips play for a step on which ground. A set is
--   materials   Enum.Material names the set is for (what the ground under the foot is)
--   walk        clip ids, one picked at random each step (never the same twice in a row)
--   volume      0..1 (default 0.5), multiplied by SoundConfig.MasterVolume
--   pitch       random speed range, { low, high } (default 0.95 to 1.05)
-- Ground with no set keeps Roblox's own footsteps; ground with one has them muted while it's
-- under the feet. The owner swaps a clip by changing its id here.
local FootstepConfig = {}

FootstepConfig.Range = 70 -- studs a step can be heard from (and the farthest a walker is watched)
FootstepConfig.MinSpeed = 3 -- studs per second along the ground below which nothing steps
FootstepConfig.Deadband = 0.04 -- studs the feet must differ in height before one counts as the higher
FootstepConfig.MinPeak = 0.12 -- studs one foot must have been above the other before a landing counts

FootstepConfig.Sets = {
	Grass = {
		materials = { "Grass", "LeafyGrass" },
		walk = { 126776384329498, 135446324303740, 126338692345740, 126496437419671 },
		volume = 0.5,
	},
}

local byMaterial = {}
for name, set in pairs(FootstepConfig.Sets) do
	for _, material in ipairs(set.materials) do
		byMaterial[material] = set
	end
	set.name = name
end

-- the set for a material name ("Grass"), or nil
function FootstepConfig.ForMaterial(material)
	return byMaterial[material]
end

-- the clip id for a step: a random one of the set's, not `last` unless it's the only one
function FootstepConfig.Pick(set, last, random)
	local ids = set.walk
	if #ids == 1 then
		return ids[1]
	end
	local index = random(1, #ids)
	if ids[index] == last then
		index = index % #ids + 1
	end
	return ids[index]
end

-- A step is the higher foot coming down level with the other: `walker` holds the side that was
-- higher ({ side = 1 left, -1 right, 0 none yet, peak }) and `diff` is the left foot's height
-- minus the right's. Returns "Left" or "Right" for the foot that just landed, or nil. It judges
-- the feet against each other, so a slope or the walk animation's own height doesn't matter.
function FootstepConfig.Step(walker, diff)
	local side = walker.side or 0
	walker.peak = math.max(walker.peak or 0, math.abs(diff))
	local now = diff > FootstepConfig.Deadband and 1 or diff < -FootstepConfig.Deadband and -1 or 0
	if now == 0 or now == side then
		return nil
	end
	walker.side = now
	local peak = walker.peak
	walker.peak = 0
	if side ~= 0 and peak >= FootstepConfig.MinPeak then
		return side == 1 and "Left" or "Right"
	end
	return nil
end

return FootstepConfig
