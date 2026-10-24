-- Each player's settings from the Settings menu: ON/OFF ones and sliders. Quick respawn
-- (SettingsServer respawns them the moment they die, skipping the death screen), Camera
-- shake and Flashes & impact frames (VFX and SkillEffects skip them when off), Damage
-- numbers (HitFeedback), the Vignette's strength (Vignette), the Low health warning
-- (LowHealth), Key hints (KeyHints), HUD sway and HP bar sway, how far each drifts
-- (HudSway), the Combo counter (ComboCounter) and Area names (ZoneName). They're the
-- saved Preferences attribute, "QuickRespawn=1,HudSway=50", holding only the ones off
-- their default (an ON/OFF one as 1 or 0, a slider as its number); Settings changes it
-- and SettingsServer checks and stores it, as with Keybinds. A slider that was an ON/OFF
-- setting before reads an old "=0" as 0, off.
-- The first half is plain logic (tests/Preferences.spec.luau runs it outside
-- Roblox); the functions below it reach the game only when called.
local Preferences = {}

Preferences.Attribute = "Preferences" -- on the player, saved by PlayerStats
Preferences.MaxLength = 200 -- PlayerStats' longest saved text

-- in menu order, under their section headings. An option is ON/OFF unless it's a
-- `slider`: whole numbers from `min` to `max` in `step`s, shown with `suffix`.
-- `description` is what the menu says about it.
Preferences.Options = {
	{
		id = "QuickRespawn",
		label = "Quick respawn",
		section = "GAMEPLAY",
		default = false,
		description = "Come back the moment you die, skipping the death screen.",
	},
	{
		id = "CameraShake",
		label = "Camera shake",
		section = "EFFECTS",
		default = true,
		description = "The camera shakes on heavy hits and big skills.",
	},
	{
		id = "Flashes",
		label = "Flashes & impact frames",
		section = "EFFECTS",
		default = true,
		description = "Full-screen flashes and frozen impact frames on heavy hits. Turn it off if bright flashes bother you.",
	},
	{
		id = "DamageNumbers",
		label = "Damage numbers",
		section = "EFFECTS",
		default = true,
		description = "Numbers pop up over whatever you hit.",
	},
	{
		id = "Vignette",
		label = "Vignette",
		section = "EFFECTS",
		kind = "slider",
		min = 0,
		max = 100,
		step = 10,
		suffix = "%",
		default = 100,
		description = "How dark the screen's edges are. 0 turns it off.",
	},
	{
		id = "LowHealthEdges",
		label = "Low health warning",
		section = "EFFECTS",
		default = true,
		description = "The screen's edges turn red, then pulse, as your health runs low.",
	},
	{
		id = "KeyHints",
		label = "Key hints",
		section = "INTERFACE",
		default = true,
		description = "The line of keys for your basic moves along the bottom right.",
	},
	{
		id = "HudSway",
		label = "HUD sway",
		section = "INTERFACE",
		kind = "slider",
		min = 0,
		max = 200,
		step = 10,
		suffix = "%",
		default = 100,
		description = "How far the HUD drifts as you move and turn the camera. 0 holds it still.",
	},
	{
		id = "StatusSway",
		label = "HP bar sway",
		section = "INTERFACE",
		kind = "slider",
		min = 0,
		max = 200,
		step = 10,
		suffix = "%",
		default = 100,
		description = "How far the HP and stamina bar beside your character drifts. 0 holds it still.",
	},
	{
		id = "ComboCounter",
		label = "Combo counter",
		section = "INTERFACE",
		default = true,
		description = "The count of hits in a row on the right of the screen.",
	},
	{
		id = "ZoneNames",
		label = "Area names",
		section = "INTERFACE",
		default = true,
		description = "An area's name fades in at the top of the screen as you walk into it.",
	},
}

local byId = {}
for _, option in ipairs(Preferences.Options) do
	byId[option.id] = option
end

function Preferences.Option(id)
	return byId[id]
end

-- whether `value` is one `option` can hold
local function fits(option, value)
	if option.kind == "slider" then
		return typeof(value) == "number"
			and value >= option.min
			and value <= option.max
			and (value - option.min) % option.step == 0
	end
	return typeof(value) == "boolean"
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
		local option = byId[id]
		if option and option.kind == "slider" then
			local number = string.match(value, "^%d+$") and tonumber(value)
			if number and fits(option, number) then
				map[id] = number
			end
		elseif option and (value == "0" or value == "1") then
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
			local text = option.kind == "slider" and tostring(value) or (value and "1" or "0")
			table.insert(parts, option.id .. "=" .. text)
		end
	end
	return table.concat(parts, ",")
end

-- every setting present with a value it can hold, nothing else in it
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
		if not fits(option, map[option.id]) then
			return false
		end
	end
	return true
end

-- `value` moved `steps` along `option`: an ON/OFF one flips, a slider moves by its step,
-- held within its ends
function Preferences.Nudge(option, value, steps)
	if option.kind == "slider" then
		return math.clamp(value + steps * option.step, option.min, option.max)
	end
	return not value
end

-- the slider value nearest `fraction` (0 to 1) of the way along it, on a step
function Preferences.SliderAt(option, fraction)
	local steps = math.floor((option.max - option.min) / option.step * math.clamp(fraction, 0, 1) + 0.5)
	return option.min + steps * option.step
end

-- a player's setting (the server asks this for Quick respawn)
function Preferences.For(player, id)
	return Preferences.Parse(player:GetAttribute(Preferences.Attribute))[id] == true
end

-- Client side: the local player's settings, parsed once per change. While the menu has a
-- change on its way to the server, that map is previewed instead, so a slider shows at once.
local cachedText, cachedMap
local previewMap
local previewChanged -- a BindableEvent, made on first use (not in Lune tests)

local function previewSignal()
	previewChanged = previewChanged or Instance.new("BindableEvent")
	return previewChanged
end

-- shows `map` (a full map, or nil for what's saved) until it's replaced
function Preferences.Preview(map)
	if map ~= previewMap then
		previewMap = map
		previewSignal():Fire()
	end
end

local function localPlayer()
	return game:GetService("Players").LocalPlayer
end

-- an ON/OFF setting as true or false; a slider's number
function Preferences.Get(id)
	local text = localPlayer():GetAttribute(Preferences.Attribute) or ""
	if text ~= cachedText then
		cachedText = text
		cachedMap = Preferences.Parse(text)
	end
	local map = previewMap or cachedMap
	local option = byId[id]
	if option and option.kind == "slider" then
		return map[id]
	end
	return map[id] == true
end

-- a slider as a share of its default (HUD sway at 150% is 1.5)
function Preferences.Scale(id)
	return Preferences.Get(id) / byId[id].default
end

-- calls `callback` whenever the local player's settings change (or the preview does)
function Preferences.Changed(callback)
	previewSignal().Event:Connect(callback)
	return localPlayer():GetAttributeChangedSignal(Preferences.Attribute):Connect(callback)
end

return Preferences
