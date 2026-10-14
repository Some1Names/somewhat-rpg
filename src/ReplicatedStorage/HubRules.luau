-- The hub menu's plain rules (Hub uses them): which colour an accent is drawn
-- in on the hub's light paper (a light accent would vanish there: a light
-- colour is darkened, a near-white or grey one, like no power's white, becomes
-- ink), what a tab's key does, and the order of the nav. tests/HubRules.spec.luau runs it outside Roblox.
local HubRules = {}

HubRules.InkLevel = 0.08 -- the ink's r, g and b
HubRules.LightLuminance = 0.8 -- above this an accent is too light for the paper
HubRules.GreyRange = 0.15 -- a light accent whose channels differ by less than this is grey: ink
HubRules.DarkenedLuminance = 0.45 -- a light colour is scaled down to this

-- r, g, b from 0 to 1: the colour to draw that accent with on the paper
function HubRules.Ink(r, g, b)
	local luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
	if luminance <= HubRules.LightLuminance then
		return r, g, b
	elseif math.max(r, g, b) - math.min(r, g, b) < HubRules.GreyRange then
		return HubRules.InkLevel, HubRules.InkLevel, HubRules.InkLevel
	end
	local scale = HubRules.DarkenedLuminance / luminance
	return r * scale, g * scale, b * scale
end

-- a tab's key with `openTab` showing (nil = hub closed): "open", "switch" or "close"
function HubRules.KeyAction(openTab, pressedTab)
	if openTab == nil then
		return "open"
	elseif openTab == pressedTab then
		return "close"
	end
	return "switch"
end

-- `tabs` = { { name, order, locked } }: the names in nav order (by order, then name), locked ones too
function HubRules.Order(tabs)
	local sorted = table.clone(tabs)
	table.sort(sorted, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.name < b.name
	end)
	local names = {}
	for _, tab in ipairs(sorted) do
		table.insert(names, tab.name)
	end
	return names
end

-- the first tab in nav order that isn't locked, or nil
function HubRules.FirstOpen(tabs)
	local locked = {}
	for _, tab in ipairs(tabs) do
		locked[tab.name] = tab.locked == true
	end
	for _, name in ipairs(HubRules.Order(tabs)) do
		if not locked[name] then
			return name
		end
	end
	return nil
end

return HubRules
