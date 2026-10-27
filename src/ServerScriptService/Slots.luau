-- Character slots on the server. Each player has up to SlotCount characters; a slot's
-- progress is its own DataStore record (PlayerStats loads and saves the one the player
-- chose) and the slot screen's summaries live in one small "meta" record per player.
-- Nobody has a slot on join: they are held (anchored, ForceField, SlotPending) until they
-- pick one on the slot screen (SlotServer's SlotAction remote), which loads it and lets
-- them in. An older single save becomes slot 1 the first time the meta is read (a copy:
-- the old key is never deleted or changed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local SlotConfig = require(ReplicatedStorage:WaitForChild("SlotConfig"))

local Slots = {}

local READ_ATTEMPTS = 3

-- weak keys: the leave-time save of PlayerStats may still need a leaving player's meta
local metas = setmetatable({}, { __mode = "k" }) -- player -> { [slot] = Entry }, once read
local loadingMeta = setmetatable({}, { __mode = "k" })
local entering = setmetatable({}, { __mode = "k" }) -- busy creating, choosing or deleting
local enteredCallbacks = {}

-- a DataStore read with retries. (true, value) or false when it kept failing; in Studio a
-- failing read (API access off) counts as "nothing there", as PlayerStats does
local function readKey(key)
	local store = PlayerStats.Store
	if not store then
		return true, nil
	end
	for attempt = 1, READ_ATTEMPTS do
		local ok, result = pcall(store.GetAsync, store, key)
		if ok then
			return true, result
		end
		warn(string.format("[Slots] read %d/%d of %s failed: %s", attempt, READ_ATTEMPTS, key, tostring(result)))
		if tostring(result):find("Studio access to APIs is not allowed", 1, true) then
			break
		end
		if attempt < READ_ATTEMPTS then
			task.wait(2)
		end
	end
	return RunService:IsStudio(), nil
end

-- true when written, or when nothing is written at all (Studio)
local function writeKey(key, value)
	if not PlayerStats.WritesEnabled() then
		return true
	end
	local ok, err = pcall(PlayerStats.Store.SetAsync, PlayerStats.Store, key, value)
	if not ok then
		warn("[Slots] write of " .. key .. " failed: " .. tostring(err))
	end
	return ok
end

local function entryOf(player)
	local level, power = PlayerStats.Summary(player)
	return {
		name = player:GetAttribute("CharName") or "",
		level = level,
		power = power,
		look = player:GetAttribute("Look") or "",
		playedAt = os.time(),
	}
end

-- a name for a copied older save: the display name with the characters names can't have
-- stripped
local function legacyName(player)
	for _, raw in ipairs({ player.DisplayName, player.Name }) do
		local name = SlotConfig.CleanName((raw:gsub("[^%w _]", "")):sub(1, SlotConfig.NameMax))
		if name then
			return name
		end
	end
	return "Hero"
end

-- the player's summaries: (meta) or (nil, "load"). Nothing is migrated, created or
-- overwritten unless every read worked.
local function loadMeta(player)
	local userId = player.UserId
	local ok, value = readKey(SlotConfig.MetaKey(userId))
	if not ok then
		return nil, "load"
	end
	if value ~= nil then
		return SlotConfig.CleanMeta(value)
	end
	local legacyOk, legacy = readKey(tostring(userId))
	if not legacyOk then
		return nil, "load"
	end
	if type(legacy) ~= "table" then
		return {}
	end
	-- an older single save becomes slot 1; the slot is written before its summary, so a
	-- crash in between just runs the copy again
	local record = table.clone(legacy)
	record.CharName = legacyName(player)
	record.Look = SlotConfig.FormatLook(SlotConfig.DefaultLook())
	if not writeKey(SlotConfig.SlotKey(userId, 1), record) then
		return nil, "load"
	end
	local meta = {
		[1] = {
			name = record.CharName,
			level = type(legacy.Level) == "number" and legacy.Level or 0,
			power = type(legacy.CurrentPower) == "string" and legacy.CurrentPower or "",
			look = record.Look,
			playedAt = os.time(),
		},
	}
	if not writeKey(SlotConfig.MetaKey(userId), meta) then
		return nil, "load"
	end
	return meta
end

-- the slot summaries, read once per player: ({ [slot] = Entry }) or (nil, reason)
function Slots.List(player)
	if metas[player] then
		return metas[player]
	end
	if loadingMeta[player] then
		return nil, "busy"
	end
	loadingMeta[player] = true
	local meta, reason = loadMeta(player)
	loadingMeta[player] = nil
	if not meta or not player.Parent then
		return nil, reason or "left"
	end
	metas[player] = meta
	return meta
end

function Slots.Current(player)
	return PlayerStats.CurrentSlot(player)
end

-- keeps the chosen slot's summary current; PlayerStats calls it after every save
function Slots.WriteMeta(player)
	local slot = PlayerStats.CurrentSlot(player)
	local meta = metas[player]
	if not slot or not meta then
		return
	end
	meta[slot] = entryOf(player)
	writeKey(SlotConfig.MetaKey(player.UserId), meta)
end

-- callback(player, slot) once a player is let in
function Slots.OnEntered(callback)
	table.insert(enteredCallbacks, callback)
end

-- held until a slot is chosen: nothing can hit them, and they can't walk off the menu
local function hold(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not player:GetAttribute("SlotPending") then
		return
	end
	root.Anchored = true
	if not character:FindFirstChildOfClass("ForceField") then
		Instance.new("ForceField").Parent = character
	end
end

local function enter(player, slot)
	player:SetAttribute("SlotPending", nil)
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = false
		end
		local shield = character:FindFirstChildOfClass("ForceField")
		if shield then
			shield:Destroy()
		end
	end
	for _, callback in ipairs(enteredCallbacks) do
		task.spawn(callback, player, slot)
	end
end

-- creating, choosing and deleting run one at a time per player, and not at all once in
local function exclusive(player, work)
	if PlayerStats.CurrentSlot(player) or entering[player] then
		return false, "busy"
	end
	entering[player] = true
	local ok, success, reason = pcall(work)
	entering[player] = nil
	if not ok then
		warn("[Slots] " .. tostring(success))
		return false, "error"
	end
	return success, reason
end

-- a brand-new character in an empty slot, then in
function Slots.Create(player, slot, name, lookText)
	return exclusive(player, function()
		if not SlotConfig.ValidSlot(slot) then
			return false, "No such slot"
		end
		local meta, reason = Slots.List(player)
		if not meta then
			return false, reason
		end
		if meta[slot] then
			return false, "That slot is taken"
		end
		local clean, why = SlotConfig.CleanName(name)
		if not clean then
			return false, why
		end
		for _, entry in pairs(meta) do
			if entry.name:lower() == clean:lower() then
				return false, "You already have a character with that name"
			end
		end
		if type(lookText) ~= "string" or SlotConfig.FormatLook(SlotConfig.ParseLook(lookText)) ~= lookText then
			return false, "Invalid look"
		end
		local filtered, result = pcall(function()
			return TextService:FilterStringAsync(clean, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		if not filtered then
			return false, "Couldn't check the name, try again"
		end
		if result ~= clean then
			return false, "That name isn't allowed"
		end
		if not PlayerStats.LoadSlot(player, slot, true) then
			return false, "load"
		end
		player:SetAttribute("CharName", clean)
		player:SetAttribute("Look", lookText)
		if PlayerStats.WritesEnabled() and not PlayerStats.SaveNow(player) then
			PlayerStats.ClearSlot(player)
			return false, "save"
		end
		meta[slot] = entryOf(player)
		enter(player, slot)
		return true
	end)
end

-- a character that already exists
function Slots.Select(player, slot)
	return exclusive(player, function()
		if not SlotConfig.ValidSlot(slot) then
			return false, "No such slot"
		end
		local meta, reason = Slots.List(player)
		if not meta then
			return false, reason
		end
		if not meta[slot] then
			return false, "That slot is empty"
		end
		if not PlayerStats.LoadSlot(player, slot, false) then
			return false, "load"
		end
		enter(player, slot)
		return true
	end)
end

-- deletes a character; the player types its name to confirm
function Slots.Delete(player, slot, typedName)
	return exclusive(player, function()
		if not SlotConfig.ValidSlot(slot) then
			return false, "No such slot"
		end
		local meta, reason = Slots.List(player)
		if not meta then
			return false, reason
		end
		local entry = meta[slot]
		if not entry then
			return false, "That slot is empty"
		end
		local typed = type(typedName) == "string" and typedName:match("^%s*(.-)%s*$"):lower() or ""
		if typed ~= entry.name:lower() then
			return false, "Type the character's name to delete it"
		end
		-- the summary goes first: if it can't be written the character simply stays
		meta[slot] = nil
		if not writeKey(SlotConfig.MetaKey(player.UserId), meta) then
			meta[slot] = entry
			return false, "save"
		end
		if PlayerStats.WritesEnabled() then
			local ok, err = pcall(PlayerStats.Store.RemoveAsync, PlayerStats.Store, SlotConfig.SlotKey(player.UserId, slot))
			if not ok then
				warn("[Slots] couldn't remove the record of slot " .. slot .. ": " .. tostring(err)) -- an orphan, overwritten by the next character there
			end
		end
		return true
	end)
end

function Slots.Start()
	PlayerStats.OnSaved(Slots.WriteMeta)
	local function onPlayerAdded(player)
		player:SetAttribute("SlotPending", true)
		local function onCharacter(character)
			task.spawn(hold, player, character)
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
end

return Slots
