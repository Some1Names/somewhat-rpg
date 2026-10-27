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
SlotConfig.HairStyles = { "None", "Short", "Spiky", "Long", "Tied" }
SlotConfig.FaceStyles = { "Default", "Calm", "Fierce", "Smile" }

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
		return nil, "Letters, numbers, spaces and _ only"
	end
	if not name:match("%w") then
		return nil, "Use at least one letter or number"
	end
	return name
end

-- a look is an index into each palette
local LOOK_FIELDS = {
	{ "skin", SlotConfig.SkinTones },
	{ "hair", SlotConfig.HairStyles },
	{ "hairColor", SlotConfig.HairColors },
	{ "face", SlotConfig.FaceStyles },
	{ "top", SlotConfig.OutfitColors },
	{ "bottom", SlotConfig.OutfitColors },
}

function SlotConfig.DefaultLook()
	local look = {}
	for _, field in ipairs(LOOK_FIELDS) do
		look[field[1]] = 1
	end
	return look
end

function SlotConfig.FormatLook(look)
	local parts = {}
	for _, field in ipairs(LOOK_FIELDS) do
		table.insert(parts, tostring(look[field[1]]))
	end
	return table.concat(parts, ";")
end

-- any field that is missing or isn't a whole number inside its palette falls back to 1
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
		local value = tonumber(piece)
		if isInteger(value, 1, #field[2]) then
			look[field[1]] = value
		end
	end
	return look
end

-- the saved summaries ({ [slot] = { name, level, power, look, playedAt } }) with anything
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
