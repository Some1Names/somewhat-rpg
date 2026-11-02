-- Character slots: how many, the DataStore keys, what a character may be called, the
-- look options (palettes) and the saved look text, and the slot summaries the slot
-- screen shows. Pure rules with no Roblox types, so Lune can test them
-- (tests/SlotConfig.spec.luau). The server side is Slots, the paint is CharacterLook.
local SlotConfig = {}

SlotConfig.SlotCount = 3
SlotConfig.NameMin = 3
SlotConfig.NameMax = 16

-- palettes, {r, g, b} 0-255 (placeholder colours); index 1 is each list's default
SlotConfig.SkinTones = {
	{ 255, 224, 189 }, { 241, 194, 125 }, { 224, 172, 105 }, { 198, 134, 66 },
	{ 141, 85, 36 }, { 103, 64, 36 }, { 255, 205, 178 }, { 74, 48, 32 },
}
SlotConfig.OutfitColors = {
	{ 40, 40, 40 }, { 235, 235, 235 }, { 180, 40, 40 }, { 40, 80, 170 },
	{ 40, 130, 70 }, { 230, 190, 50 }, { 120, 60, 160 }, { 230, 120, 40 },
	{ 90, 90, 100 }, { 30, 110, 120 }, { 170, 90, 110 }, { 110, 75, 45 },
}
SlotConfig.HairColors = {
	{ 30, 25, 25 }, { 90, 55, 30 }, { 160, 110, 60 }, { 230, 200, 120 }, { 200, 200, 205 },
	{ 170, 40, 40 }, { 40, 80, 170 }, { 40, 150, 90 }, { 150, 70, 190 }, { 240, 140, 190 },
}
-- display names; the part for style n is ReplicatedStorage.CharacterParts.Hair_<n> (a style
-- with no part is hidden in the customizer), and Face_<n> for faces
SlotConfig.HairStyles = { "None", "Messy", "Spiky", "Ponytail", "Side Part", "Swoop", "Neat", "Long", "Bangs" }
SlotConfig.FaceStyles = { "Default", "Calm", "Fierce", "Kawaii", "Gentleman", "Glow", "Shades", "Smirk", "Grin", "Braces" }
-- clothes and accessories: the part for style n is CharacterParts.Shirt_<n> / Tee_<n> /
-- Pants_<n> / Acc_<n>. A shirt or pants is a picture that keeps its own colours (it hides the
-- colour wheel for its piece); a tee is a graphic over the top colour. A list with only "None"
-- has nothing to pick yet (no free shirt or pants worth shipping): add names here and the
-- parts in Studio.
SlotConfig.ShirtStyles = { "None" }
SlotConfig.TeeStyles = { "None", "Spiral", "VIP" }
SlotConfig.PantsStyles = { "None" }
SlotConfig.AccessoryStyles = { "None", "Fedora", "Top Hat", "Cowboy", "Witch", "Reading Glasses", "Sunglasses" }

-- the keys in the DataStore: one record per slot, one for the summaries
function SlotConfig.SlotKey(userId, slot)
	return userId .. "_" .. slot
end

function SlotConfig.MetaKey(userId)
	return userId .. "_meta"
end

-- the settings that belong to the player, not to a character (keybinds, preferences...)
function SlotConfig.AccountKey(userId)
	return userId .. "_account"
end

local function isInteger(value, low, high)
	return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end

function SlotConfig.ValidSlot(slot)
	return isInteger(slot, 1, SlotConfig.SlotCount)
end

-- the trimmed name, or nil and the reason it was refused
function SlotConfig.CleanName(text)
	if type(text) ~= "string" then
		return nil, "Enter a codename"
	end
	local name = text:match("^%s*(.-)%s*$"):gsub(" +", " ") -- trimmed, runs of spaces made one
	if #name < SlotConfig.NameMin or #name > SlotConfig.NameMax then
		return nil, string.format("Codename must be %d-%d characters", SlotConfig.NameMin, SlotConfig.NameMax)
	end
	if not name:match("^[%w _]+$") then
		return nil, "English letters, numbers, spaces and _ only"
	end
	if not name:match("%w") then
		return nil, "Use at least one letter or number"
	end
	return name
end

-- colours are any RGB (the customizer's colour wheel picks them), {r, g, b} 0-255, saved as
-- six hex digits ("FFE0BD"); they start from the first colour of their palette above
function SlotConfig.FormatColor(rgb)
	local function channel(value)
		return math.clamp(math.floor(value + 0.5), 0, 255)
	end
	return string.format("%02X%02X%02X", channel(rgb[1]), channel(rgb[2]), channel(rgb[3]))
end

-- the colour of six hex digits, or nil
function SlotConfig.ParseColor(text)
	if type(text) ~= "string" or not text:match("^%x%x%x%x%x%x$") then
		return nil
	end
	return { tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16), tonumber(text:sub(5, 6), 16) }
end

local function copyColor(rgb)
	return { rgb[1], rgb[2], rgb[3] }
end

-- a look: skin, hairColor, top and bottom are colours; hair and face are a style number
-- (an index into HairStyles / FaceStyles)
local LOOK_FIELDS = {
	{ "skin", "color", SlotConfig.SkinTones },
	{ "hair", "style", SlotConfig.HairStyles },
	{ "hairColor", "color", SlotConfig.HairColors },
	{ "face", "style", SlotConfig.FaceStyles },
	{ "top", "color", SlotConfig.OutfitColors },
	{ "bottom", "color", SlotConfig.OutfitColors },
	{ "shirt", "style", SlotConfig.ShirtStyles },
	{ "tee", "style", SlotConfig.TeeStyles },
	{ "pants", "style", SlotConfig.PantsStyles },
	{ "accessory", "style", SlotConfig.AccessoryStyles },
}

function SlotConfig.DefaultLook()
	local look = {}
	for _, field in ipairs(LOOK_FIELDS) do
		look[field[1]] = field[2] == "color" and copyColor(field[3][1]) or 1
	end
	return look
end

-- "skin;hair;hairColor;face;top;bottom;shirt;tee;pants;accessory", e.g.
-- "FFE0BD;1;1E1919;1;282828;282828;1;1;1;1" (an older look with fewer fields still reads)
function SlotConfig.FormatLook(look)
	local parts = {}
	for _, field in ipairs(LOOK_FIELDS) do
		local value = look[field[1]]
		table.insert(parts, field[2] == "color" and SlotConfig.FormatColor(value) or tostring(value or 1))
	end
	return table.concat(parts, ";")
end

-- any field that is missing or isn't valid falls back to its default. A colour may also be
-- a whole number into its palette (looks saved before the colour wheel).
function SlotConfig.ParseLook(text)
	local look = SlotConfig.DefaultLook()
	if type(text) ~= "string" then
		return look
	end
	local index = 0
	for piece in (text .. ";"):gmatch("([^;]*);") do
		index += 1
		local field = LOOK_FIELDS[index]
		if not field then
			break
		end
		if field[2] == "color" then
			local color = SlotConfig.ParseColor(piece)
			local number = tonumber(piece)
			if color then
				look[field[1]] = color
			elseif isInteger(number, 1, #field[3]) then
				look[field[1]] = copyColor(field[3][number])
			end
		else
			local number = tonumber(piece)
			if isInteger(number, 1, #field[3]) then
				look[field[1]] = number
			end
		end
	end
	return look
end

-- the saved summaries ({ [slot] = { name, level, yen, power, look, playedAt } }) with anything
-- malformed dropped
function SlotConfig.CleanMeta(value)
	local clean = {}
	if type(value) ~= "table" then
		return clean
	end
	for slot = 1, SlotConfig.SlotCount do
		local entry = value[tostring(slot)]
		if entry == nil then
			entry = value[slot]
		end
		if
			type(entry) == "table"
			and type(entry.name) == "string"
			and type(entry.level) == "number"
			and type(entry.power) == "string"
			and type(entry.look) == "string"
			and type(entry.playedAt) == "number"
		then
			clean[slot] = {
				name = entry.name,
				level = entry.level,
				power = entry.power,
				look = entry.look,
				playedAt = entry.playedAt,
				yen = type(entry.yen) == "number" and entry.yen or 0, -- not in summaries saved before it was kept
			}
		end
	end
	return clean
end

-- the summaries as saved: string keys ("1".."3"), because a DataStore can't keep a table
-- whose integer keys have gaps
function SlotConfig.EncodeMeta(meta)
	local saved = {}
	for slot = 1, SlotConfig.SlotCount do
		if meta[slot] then
			saved[tostring(slot)] = meta[slot]
		end
	end
	return saved
end

return SlotConfig
