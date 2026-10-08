-- The rebindable keys: the fighting actions (a skill set's five skill slots,
-- its Special on G, the dash, reload, Photoshop's gallery), the key each is
-- on by default, and which keys a player may move them to (Allowed: never
-- movement, menus, chat or the hotbar). A player's own bindings are the
-- saved Keybinds attribute, "SkillZ=Q,Dash=Z", holding only the actions
-- they've moved; Settings changes them and SettingsServer checks and stores
-- them. SkillBar, Dash, Ranged, PhotoGallery and Inventory ask here which
-- key an action is on (Key, ActionFor, Text). The skill slots keep their
-- own names (SkillSetConfig.Keys): the bar sends "Z" for Skill 1 whatever
-- key cast it. Binding a key another action has swaps the two (Bind).
-- The first half is plain logic (tests/Keybinds.spec.luau runs it outside
-- Roblox); the client half below reaches the game only when called.
local Keybinds = {}

Keybinds.Attribute = "Keybinds" -- on the player, saved by PlayerStats
Keybinds.MaxLength = 200 -- PlayerStats' longest saved text

Keybinds.Actions = {
	{ id = "SkillZ", label = "Skill 1", default = "Z" },
	{ id = "SkillX", label = "Skill 2", default = "X" },
	{ id = "SkillC", label = "Skill 3", default = "C" },
	{ id = "SkillV", label = "Skill 4", default = "V" },
	{ id = "SkillF", label = "Skill 5 (ultimate)", default = "F" },
	{ id = "Special", label = "Overcharge / Flight / Undo", default = "G" },
	{ id = "Dash", label = "Dash", default = "Q" },
	{ id = "Reload", label = "Reload", default = "R" },
	{ id = "Gallery", label = "Photo Gallery", default = "T" },
}

local byId = {}
for _, action in ipairs(Keybinds.Actions) do
	byId[action.id] = action
end

-- every key an action may be put on (Enum.KeyCode names). Letters but
-- W A S D (movement), B and M (Inventory, Stats) and P (Settings); F1-F8
-- (F9 is the console, F11 fullscreen); the number pad; some punctuation
Keybinds.Allowed = {}
for letter in string.gmatch("CEFGHIJKLNOQRTUVXYZ", ".") do
	Keybinds.Allowed[letter] = true
end
for i = 1, 8 do
	Keybinds.Allowed["F" .. i] = true
end
for i = 0, 9 do
	Keybinds.Allowed["Keypad" .. i] = true
end
local SHORT = {
	Comma = ",",
	Period = ".",
	Semicolon = ";",
	Quote = "'",
	LeftBracket = "[",
	RightBracket = "]",
	Minus = "-",
	Equals = "=",
	BackSlash = "\\",
	LeftAlt = "LAlt",
	RightAlt = "RAlt",
	CapsLock = "Caps",
}
for name in pairs(SHORT) do
	Keybinds.Allowed[name] = true
end

-- a key's label for a small keycap: "Q", "F5", "N1" for the number pad, ";"
function Keybinds.ShortName(keyName)
	local digit = string.match(keyName, "^Keypad(%d)$")
	return SHORT[keyName] or (digit and "N" .. digit) or keyName
end

-- every action on its default key
function Keybinds.Defaults()
	local map = {}
	for _, action in ipairs(Keybinds.Actions) do
		map[action.id] = action.default
	end
	return map
end

local function hasDouble(map)
	local seen = {}
	for _, key in pairs(map) do
		if seen[key] then
			return true
		end
		seen[key] = true
	end
	return false
end

-- a saved string as a full map; anything wrong in it falls back to the defaults
function Keybinds.Parse(text)
	local map = Keybinds.Defaults()
	if typeof(text) ~= "string" or #text > Keybinds.MaxLength then
		return map
	end
	for id, key in string.gmatch(text, "(%w+)=(%w+)") do
		if byId[id] and Keybinds.Allowed[key] then
			map[id] = key
		end
	end
	if hasDouble(map) then
		return Keybinds.Defaults()
	end
	return map
end

-- the string to save: only the actions off their default, in Actions order
function Keybinds.Serialize(map)
	local parts = {}
	for _, action in ipairs(Keybinds.Actions) do
		local key = map[action.id]
		if key and key ~= action.default then
			table.insert(parts, action.id .. "=" .. key)
		end
	end
	return table.concat(parts, ",")
end

-- every action on an allowed key, no key twice, nothing else in it
function Keybinds.Valid(map)
	if typeof(map) ~= "table" then
		return false
	end
	for id in pairs(map) do
		if not byId[id] then
			return false
		end
	end
	for _, action in ipairs(Keybinds.Actions) do
		if not Keybinds.Allowed[map[action.id]] then
			return false
		end
	end
	return not hasDouble(map)
end

-- a new map with `actionId` on `keyName`; whichever action had that key
-- takes this one's old key. nil and "unknown" or "reserved" when it can't
function Keybinds.Bind(map, actionId, keyName)
	if not byId[actionId] then
		return nil, "unknown"
	end
	if not Keybinds.Allowed[keyName] then
		return nil, "reserved"
	end
	local bound = table.clone(map)
	local old = bound[actionId]
	for id, key in pairs(bound) do
		if id ~= actionId and key == keyName then
			bound[id] = old
		end
	end
	bound[actionId] = keyName
	return bound
end

-- Client side: the local player's bindings. Parsed once per change of the
-- attribute, so the input handlers can ask on every key press.
local cachedText, cachedMap, cachedActionFor
local capturing = false

local function localPlayer()
	return game:GetService("Players").LocalPlayer
end

function Keybinds.Current()
	local text = localPlayer():GetAttribute(Keybinds.Attribute) or ""
	if text ~= cachedText then
		cachedText = text
		cachedMap = Keybinds.Parse(text)
		cachedActionFor = {}
		for id, key in pairs(cachedMap) do
			cachedActionFor[Enum.KeyCode[key]] = id
		end
	end
	return cachedMap
end

function Keybinds.Key(actionId)
	return Enum.KeyCode[Keybinds.Current()[actionId]]
end

-- the action a pressed key belongs to, if any
function Keybinds.ActionFor(keyCode)
	Keybinds.Current()
	return cachedActionFor[keyCode]
end

-- the action's key, short enough for a keycap
function Keybinds.Text(actionId)
	return Keybinds.ShortName(Keybinds.Current()[actionId])
end

-- calls `callback` whenever the player's bindings change
function Keybinds.Changed(callback)
	return localPlayer():GetAttributeChangedSignal(Keybinds.Attribute):Connect(callback)
end

-- while Settings waits for a key to bind, nothing else acts on key presses
function Keybinds.SetCapturing(on)
	capturing = on == true
end

function Keybinds.Capturing()
	return capturing
end

return Keybinds
