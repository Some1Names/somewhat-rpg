-- Whether light from the sky reaches a point (the daylight cycle, see
-- ReplicatedStorage.DayCycleConfig): "sun" while the sun's up and nothing
-- covers the point, "moon" at night under open sky, nil in the dark or
-- under cover. Iridescent Requiem's Luminance (LuminanceServer) and Solar
-- Lance (Skills.SolarLance) ask it. Characters don't count as cover, and a
-- part at least SEE_THROUGH transparent lets the light past (up to
-- MAX_SEE_THROUGH of them in a row).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local RAY_LENGTH = 1000 -- studs
local SEE_THROUGH = 0.5
local MAX_SEE_THROUGH = 4

local SkyLight = {}

-- `position` is where the ray starts (callers add a little height)
function SkyLight.Exposure(position)
	local kind, direction
	local sun = Lighting:GetSunDirection()
	if sun.Y > 0 then
		kind, direction = "sun", sun
	else
		local moon = Lighting:GetMoonDirection()
		if moon.Y <= 0 then
			return nil -- both below the horizon
		end
		kind, direction = "moon", moon
	end
	local ignore = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, MAX_SEE_THROUGH do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(position, direction * RAY_LENGTH, params)
		if not hit then
			return kind
		end
		if hit.Instance.Transparency < SEE_THROUGH then
			return nil
		end
		table.insert(ignore, hit.Instance)
	end
	return nil
end

return SkyLight
