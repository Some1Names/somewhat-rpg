-- Character slots on the server. Each player has up to SlotCount characters; a slot's
-- progress is its own DataStore record (PlayerStats loads and saves the one the player
-- chose) and the slot screen's summaries live in one small "meta" record per player.
-- Nobody has a slot on join: they are held (anchored, ForceField, SlotPending) until they
-- pick one on the slot screen (SlotServer's SlotAction remote), which loads it and lets
-- them in. An older single save becomes slot 1 the first time the meta is read (a copy:
-- the old key is never deleted or changed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local CharacterLook = require(ReplicatedStorage:WaitForChild("CharacterLook"))
local SlotConfig = require(ReplicatedStorage:WaitForChild("SlotConfig"))

local Slots = {}

-- weak keys: the leave-time save of PlayerStats may still need a leaving player's meta
local metas = setmetatable({}, { __mode = "k" }) -- player -> { [slot] = Entry }, once read
local loadingMeta = setmetatable({}, { __mode = "k" })
local entering = setmetatable({}, { __mode = "k" }) -- busy creating, choosing or deleting
local enteredCallbacks = {}

-- a DataStore read with retries: (true, value), or false when it kept failing
local readKey = PlayerStats.ReadKey

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

-- the summaries are saved with string keys (SlotConfig.EncodeMeta)
local function writeMeta(userId, meta)
	return writeKey(SlotConfig.MetaKey(userId), SlotConfig.EncodeMeta(meta))
end

local function entryOf(player)
	local level, power = PlayerStats.Summary(player)
	return {
		name = player:GetAttribute("CharName") or "",
		level = level,
		yen = player:GetAttribute("Yen") or 0,
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
			yen = type(legacy.Yen) == "number" and legacy.Yen or 0,
			power = type(legacy.CurrentPower) == "string" and legacy.CurrentPower or "",
			look = record.Look,
			playedAt = os.time(),
		},
	}
	if not writeMeta(userId, meta) then
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
	return writeMeta(player.UserId, meta)
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

-- the character wears the slot's look instead of the player's Roblox avatar, on every
-- spawn. The avatar's accessories arrive a little after the character, so wait for them
-- and paint once more a second later.
local function applyLook(player, character)
	local parts = ReplicatedStorage:FindFirstChild("CharacterParts")
	local look = SlotConfig.ParseLook(player:GetAttribute("Look"))
	-- the avatar can still be arriving on a slow server: for this life, its hats and clothes
	-- are removed as they appear (the hair CharacterLook adds is marked SlotLook), and the
	-- look is painted again once the avatar says it has finished
	-- LookRev counts the paints, so the client's models of the character (the profile's) redraw
	local function paint()
		CharacterLook.Apply(character, look, parts)
		character:SetAttribute("LookRev", (character:GetAttribute("LookRev") or 0) + 1)
	end
	local added = character.ChildAdded:Connect(function(child)
		local avatarItem = child:IsA("Accoutrement") or child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("CharacterMesh")
		if avatarItem and not child:GetAttribute("SlotLook") then
			task.defer(child.Destroy, child)
		end
	end)
	local loaded = player.CharacterAppearanceLoaded:Connect(function(loadedCharacter)
		if loadedCharacter == character then
			paint()
		end
	end)
	character.Destroying:Once(function()
		added:Disconnect()
		loaded:Disconnect()
	end)
	-- at once: a rig that isn't the player's avatar (StarterCharacter) never reports its
	-- appearance as loaded, and waiting for it would leave a default rig on screen
	if character:WaitForChild("Head", 5) then
		paint()
	end
	local deadline = os.clock() + 10
	while not player:HasAppearanceLoaded() and os.clock() < deadline do
		task.wait(0.2)
	end
	for pass = 1, 2 do
		if player.Character ~= character or not character.Parent then
			return
		end
		paint()
		if pass == 1 then
			task.wait(1)
		end
	end
end

local function watchLook(player)
	local function onCharacter(character)
		task.spawn(applyLook, player, character)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

local function enter(player, slot)
	player:SetAttribute("SlotPending", nil)
	watchLook(player)
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
				return false, "You already have a character with that codename"
			end
		end
		if type(lookText) ~= "string" or SlotConfig.FormatLook(SlotConfig.ParseLook(lookText)) ~= lookText then
			return false, "Invalid look"
		end
		local filtered, result = pcall(function()
			return TextService:FilterStringAsync(clean, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		if not filtered then
			return false, "Couldn't check the codename, try again"
		end
		if result ~= clean then
			return false, "That codename isn't allowed"
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
		-- the summary is what makes the slot show up next time, so it must be written too
		meta[slot] = entryOf(player)
		if not writeMeta(player.UserId, meta) then
			meta[slot] = nil
			PlayerStats.ClearSlot(player)
			return false, "save"
		end
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

-- a saved character gets a new look (the customizer's SAVE on an existing slot): its record
-- and its summary both change, nothing else. Done from the slot screen, before a slot is chosen.
function Slots.Recustomize(player, slot, lookText)
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
		if type(lookText) ~= "string" or SlotConfig.FormatLook(SlotConfig.ParseLook(lookText)) ~= lookText then
			return false, "Invalid look"
		end
		if PlayerStats.WritesEnabled() then
			local key = SlotConfig.SlotKey(player.UserId, slot)
			local ok, record = readKey(key)
			if not ok or type(record) ~= "table" then
				return false, "load" -- never write over a record that couldn't be read
			end
			record.Look = lookText
			if not writeKey(key, record) then
				return false, "save"
			end
		end
		entry.look = lookText
		writeMeta(player.UserId, meta)
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
			return false, "Type the character's codename to delete it"
		end
		-- the summary goes first: if it can't be written the character simply stays
		meta[slot] = nil
		if not writeMeta(player.UserId, meta) then
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
