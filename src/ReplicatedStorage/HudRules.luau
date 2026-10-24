-- Pure rules for the smaller HUD pieces (Compass, XPBar, ComboCounter, LowHealth,
-- ZoneName): compass headings and where a bearing lands on the strip, the XP bar's
-- fill, the combo's colour step, how red the screen edges get and which zone a point
-- is in. Lune-tested (tests/HudRules.spec.luau).
local HudRules = {}

-- the compass heading of a flat direction, degrees clockwise from north (-Z, up on
-- the map tab), 0..360
function HudRules.Heading(dx, dz)
	return math.deg(math.atan2(dx, -dz)) % 360
end

-- how far a bearing is from the heading you look along, -180..180 (negative: to the left)
function HudRules.Offset(heading, bearing)
	return (bearing - heading + 180) % 360 - 180
end

-- x on a strip `width` wide that shows `span` degrees around its middle; nil when off it
function HudRules.StripX(offset, span, width)
	if math.abs(offset) > span / 2 then
		return nil
	end
	return width / 2 + offset / span * width
end

-- transparency toward the strip's ends: solid in the middle, fading out over the
-- outer `share` of each half
function HudRules.EdgeFade(offset, span, share)
	local edge = math.abs(offset) / (span / 2) -- 0 in the middle, 1 at the end
	local start = 1 - share
	if edge <= start then
		return 0
	end
	return math.clamp((edge - start) / share, 0, 1)
end

local POINTS = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }
-- the letters at the eight compass points; nil between them
function HudRules.PointName(angle)
	return POINTS[angle % 360]
end

-- the XP bar's fill, 0..1; full at the level cap
function HudRules.XPFraction(xp, need, capped)
	if capped or not need or need <= 0 then
		return 1
	end
	return math.clamp((xp or 0) / need, 0, 1)
end

-- which of `tiers` ({ from = hits }, lowest first) a combo count has reached
function HudRules.ComboTier(tiers, count)
	local index = 1
	for i, tier in ipairs(tiers) do
		if count >= tier.from then
			index = i
		end
	end
	return index
end

-- how red the screen edges are, 0..1: none from `start` (a share of max health) up,
-- full near 0; none once dead, where the death screen takes over
function HudRules.LowHealthIntensity(fraction, start)
	if fraction <= 0 or fraction >= start then
		return 0
	end
	return (start - fraction) / start
end

-- the name of the first zone (ZoneConfig: { name, min = { x, z }, max = { x, z } })
-- holding the point, or nil
function HudRules.ZoneAt(zones, x, z)
	for _, zone in ipairs(zones) do
		if x >= zone.min[1] and x <= zone.max[1] and z >= zone.min[2] and z <= zone.max[2] then
			return zone.name
		end
	end
	return nil
end

return HudRules
