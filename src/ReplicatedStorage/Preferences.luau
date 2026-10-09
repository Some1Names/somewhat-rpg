-- Each player's ON/OFF settings from the Settings menu: Quick respawn
-- (SettingsServer respawns them the moment they die, skipping the death
-- screen), Camera shake and Flashes & impact frames (VFX and SkillEffects
-- skip them when off), and Damage numbers (HitFeedback). They're the saved
-- Preferences attribute, "QuickRespawn=1,CameraShake=0", holding only the
-- ones off their default; Settings changes it and SettingsServer checks and
-- stores it, as with Keybinds.
-- The first half is plain logic (tests/Preferences.spec.luau runs it outside
-- Roblox); the functions below it reach the game only when called.
local Preferences = {}

Preferences.Attribute = "Preferences" -- on the player, saved by PlayerStats
Preferences.MaxLength = 200 -- PlayerStats' longest saved text

-- in menu order, under their section headings
Preferences.Options = {
	{ id = "QuickRespawn", label = "Quick respawn", section = "GAMEPLAY", default = false },
	{ id = "CameraShake", label = "Camera shake", section = "EFFECTS", default = true },
	{ id = "Flashes", label = "Flashes & impact frames", section = "EFFECTS", default = true },
	{ id = "DamageNumbers", label = "Damage numbers", section = "EFFECTS", default = true },
}

local byId = {}
for _, option in ipairs(Preferences.Options) do
	byId[option.id] = option
end

-- every setting at its default
function Preferences.Defaults()
	local map = {}
	for _, option in ipairs(Preferences.Options) do
		map[option.id] = option.default
	end
	return map
end

-- a saved string as a full map; anything wrong in it is left at its default
function Preferences.Parse(text)
	local map = Preferences.Defaults()
	if typeof(text) ~= "string" or #text > Preferences.MaxLength then
		return map
	end
	for id, value in string.gmatch(text, "(%w+)=(%w+)") do
		if byId[id] and (value == "0" or value == "1") then
			map[id] = value == "1"
		end
	end
	return map
end

-- the string to save: only the settings off their default, in Options order
function Preferences.Serialize(map)
	local parts = {}
	for _, option in ipairs(Preferences.Options) do
		local value = map[option.id]
		if value ~= nil and value ~= option.default then
			table.insert(parts, option.id .. "=" .. (value and "1" or "0"))
		end
	end
	return table.concat(parts, ",")
end

-- every setting present as true or false, nothing else in it
function Preferences.Valid(map)
	if typeof(map) ~= "table" then
		return false
	end
	for id in pairs(map) do
		if not byId[id] then
			return false
		end
	end
	for _, option in ipairs(Preferences.Options) do
		if typeof(map[option.id]) ~= "boolean" then
			return false
		end
	end
	return true
end

-- a player's setting (the server asks this for Quick respawn)
function Preferences.For(player, id)
	return Preferences.Parse(player:GetAttribute(Preferences.Attribute))[id] == true
end

-- Client side: the local player's settings, parsed once per change
local cachedText, cachedMap

local function localPlayer()
	return game:GetService("Players").LocalPlayer
end

function Preferences.Get(id)
	local text = localPlayer():GetAttribute(Preferences.Attribute) or ""
	if text ~= cachedText then
		cachedText = text
		cachedMap = Preferences.Parse(text)
	end
	return cachedMap[id] == true
end

-- calls `callback` whenever the local player's settings change
function Preferences.Changed(callback)
	return localPlayer():GetAttributeChangedSignal(Preferences.Attribute):Connect(callback)
end

return Preferences
