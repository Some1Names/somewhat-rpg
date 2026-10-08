-- Levels, XP, stat points, yen and shop purchases for each player. The values
-- live as attributes on the Player (Level, XP, StatPoints, one per stat in
-- StatConfig, Yen, Owns<item>) so their client can show them, and are saved
-- to a DataStore.
--
-- Unspent StatPoints are never saved: they're always worked out as the points
-- the level has earned (plus any BonusPoints from admins) minus the points in
-- stats. So changing PointsPerLevel or raising MaxLevel later updates
-- everyone on their next join, and XP earned at the cap is banked so a raised
-- cap carries max-level players straight on.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local allocateEvent = ReplicatedStorage:WaitForChild("AllocateStat")
local masteryEvent = ReplicatedStorage:WaitForChild("MasteryUp")
local progressEvent = ReplicatedStorage:WaitForChild("Progress")

local STORE_NAME = "PlayerStats_v1"
local AUTOSAVE_INTERVAL = 120 -- seconds
local LOAD_ATTEMPTS = 3
local SAVE_IN_STUDIO = false -- Studio playtests load saves but never write them

-- saved fields; BonusPoints may go below 0 when an admin takes points away
local DEFAULTS = { Level = 0, XP = 0, BonusPoints = 0, Yen = 0 }
for _, stat in ipairs(StatConfig.Stats) do
	DEFAULTS[stat.key] = 0
end
-- every skill set's mastery starts at level 1
for setName in pairs(SkillSetConfig.Sets) do
	DEFAULTS[SkillSetConfig.MasteryAttribute(setName)] = 1
	DEFAULTS[SkillSetConfig.MasteryXPAttribute(setName)] = 0
end
-- shop items: 1 once bought (services, starters and placeholders aren't owned)
for _, item in ipairs(ShopConfig.Items) do
	if ShopConfig.Ownable(item) then
		DEFAULTS[ShopConfig.OwnedAttribute(item.id)] = 0
	end
end

-- saved text fields, with their defaults and longest allowed length
local TEXT_DEFAULTS = {
	AdminKeybinds = "", -- an admin's own keys for panel actions (AdminPanel, AdminServer)
}
local TEXT_MAX_LENGTH = 200

local PlayerStats = {}

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerStats] no DataStore, progress won't be saved: " .. tostring(result))
	end
end

-- only players whose save loaded are saved, so a failed load never wipes a save
local canSave = {}

-- Sets MaxHealth from Vitality. A fresh character starts full; otherwise the
-- missing health stays missing.
local function applyHealth(player, refill)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local vitality = player:GetAttribute("Vitality")
	if not humanoid or not vitality or humanoid.Health <= 0 then
		return
	end
	local maxHealth = StatConfig.MaxHealth(vitality)
	local missing = humanoid.MaxHealth - humanoid.Health
	humanoid.MaxHealth = maxHealth
	humanoid.Health = refill and maxHealth or math.clamp(maxHealth - missing, 1, maxHealth)
end

local function spentPoints(player)
	local spent = 0
	for _, stat in ipairs(StatConfig.Stats) do
		spent += player:GetAttribute(stat.key) or 0
	end
	return spent
end

local function earnedPoints(player)
	return player:GetAttribute("Level") * StatConfig.PointsPerLevel + player:GetAttribute("BonusPoints")
end

-- Works out StatPoints. If a config change leaves someone with more points in
-- stats than they've earned, every point is refunded to spend again.
local function updatePoints(player)
	local spent = spentPoints(player)
	local earned = earnedPoints(player)
	if spent > earned then
		for _, stat in ipairs(StatConfig.Stats) do
			player:SetAttribute(stat.key, 0)
		end
		spent = 0
		applyHealth(player, false)
	end
	player:SetAttribute("StatPoints", math.max(earned - spent, 0))
end

-- Turns XP into levels. At the cap, XP is banked up to one level's worth, so
-- raising MaxLevel lets max-level players level up on their next join.
local function levelUp(player)
	local level = player:GetAttribute("Level")
	local xp = player:GetAttribute("XP")
	local gained = 0
	while level < StatConfig.MaxLevel and xp >= StatConfig.XPToLevelUp(level) do
		xp -= StatConfig.XPToLevelUp(level)
		level += 1
		gained += 1
	end
	if level >= StatConfig.MaxLevel then
		xp = math.min(xp, StatConfig.XPToLevelUp(level))
	end
	player:SetAttribute("XP", xp)
	player:SetAttribute("Level", level)
	if gained > 0 then
		updatePoints(player)
	end
	return gained
end

local function load(player)
	local saved
	if store then
		for attempt = 1, LOAD_ATTEMPTS do
			local ok, result = pcall(store.GetAsync, store, tostring(player.UserId))
			if ok then
				saved = result or {}
				canSave[player] = true
				break
			end
			warn(string.format("[PlayerStats] load %d/%d failed for %s: %s", attempt, LOAD_ATTEMPTS, player.Name, tostring(result)))
			-- retrying won't help when the place has Studio API access turned off
			if tostring(result):find("Studio access to APIs is not allowed", 1, true) then
				break
			end
			if attempt < LOAD_ATTEMPTS then
				task.wait(2)
			end
		end
	end
	if not player.Parent then
		return
	end
	saved = typeof(saved) == "table" and saved or {}
	-- older saves called Superliminal "Mastery" or "Skill" (points in the old
	-- Endurance stat simply aren't counted as spent any more, so they come
	-- back to spend)
	if saved.Superliminal == nil then
		saved.Superliminal = saved.Mastery or saved.Skill
	end
	for field, default in pairs(DEFAULTS) do
		local value = saved[field]
		if typeof(value) ~= "number" or value ~= value then
			value = default
		end
		value = math.floor(value)
		player:SetAttribute(field, field == "BonusPoints" and value or math.max(value, 0))
	end
	for field, default in pairs(TEXT_DEFAULTS) do
		local value = saved[field]
		if typeof(value) ~= "string" or #value > TEXT_MAX_LENGTH then
			value = default
		end
		player:SetAttribute(field, value)
	end
	player:SetAttribute("Level", math.clamp(player:GetAttribute("Level"), 0, StatConfig.MaxLevel))
	-- points over a stat's cap come back to spend
	for _, stat in ipairs(StatConfig.Stats) do
		player:SetAttribute(stat.key, math.min(player:GetAttribute(stat.key), StatConfig.StatCap(stat.key)))
	end
	for setName in pairs(SkillSetConfig.Sets) do
		local key = SkillSetConfig.MasteryAttribute(setName)
		player:SetAttribute(key, math.clamp(player:GetAttribute(key), 1, SkillSetConfig.MaxMastery))
	end
	levelUp(player)
	updatePoints(player)
	applyHealth(player, true)
end

local function save(player)
	if not canSave[player] or (RunService:IsStudio() and not SAVE_IN_STUDIO) then
		return
	end
	local data = {}
	for field in pairs(DEFAULTS) do
		data[field] = player:GetAttribute(field)
	end
	for field in pairs(TEXT_DEFAULTS) do
		data[field] = player:GetAttribute(field)
	end
	local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), data)
	if not ok then
		warn("[PlayerStats] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function PlayerStats.AddXP(player, amount)
	if player:GetAttribute("Level") == nil or amount <= 0 then
		return -- still loading
	end
	player:SetAttribute("XP", player:GetAttribute("XP") + amount)
	progressEvent:FireClient(player, amount, levelUp(player), 0)
end

function PlayerStats.AddYen(player, amount)
	local yen = player:GetAttribute("Yen")
	amount = math.floor(amount)
	if not yen or amount <= 0 then
		return
	end
	player:SetAttribute("Yen", yen + amount)
	progressEvent:FireClient(player, 0, 0, amount)
end

-- spends yen on a shop item; returns whether it worked and why not
function PlayerStats.Buy(player, item)
	local yen = player:GetAttribute("Yen")
	local ownedKey = ShopConfig.OwnedAttribute(item.id)
	if not yen then
		return false, "Still loading"
	end
	if player:GetAttribute(ownedKey) == 1 then
		return false, "You already own " .. item.name
	end
	if yen < item.price then
		return false, string.format("You need ¥%d more", item.price - yen)
	end
	player:SetAttribute("Yen", yen - item.price)
	player:SetAttribute(ownedKey, 1)
	return true, "Bought " .. item.name
end

-- takes yen for something that isn't owned (a shop service); false if it's
-- short or still loading
function PlayerStats.SpendYen(player, amount)
	local yen = player:GetAttribute("Yen")
	if not yen or yen < amount then
		return false
	end
	player:SetAttribute("Yen", yen - amount)
	return true
end

-- Skill-set mastery, earned by dealing damage with the set. Like levels, XP
-- past the top mastery is banked up to one level's worth.
function PlayerStats.AddMasteryXP(player, setName, amount)
	local levelKey = SkillSetConfig.MasteryAttribute(setName)
	local xpKey = SkillSetConfig.MasteryXPAttribute(setName)
	local level = player:GetAttribute(levelKey)
	local xp = player:GetAttribute(xpKey)
	-- kept fractional: small hits earn a fraction of a point
	if not level or not xp or amount <= 0 then
		return
	end
	xp += amount
	local startLevel = level
	while level < SkillSetConfig.MaxMastery and xp >= SkillSetConfig.MasteryToLevelUp(level) do
		xp -= SkillSetConfig.MasteryToLevelUp(level)
		level += 1
	end
	if level >= SkillSetConfig.MaxMastery then
		xp = math.min(xp, SkillSetConfig.MasteryToLevelUp(level))
	end
	player:SetAttribute(xpKey, xp)
	if level > startLevel then
		player:SetAttribute(levelKey, level)
		masteryEvent:FireClient(player, setName, startLevel, level)
	end
end

-- admin tool: sets a skill set's mastery level, with no XP toward the next
function PlayerStats.SetMastery(player, setName, level)
	local levelKey = SkillSetConfig.MasteryAttribute(setName)
	if player:GetAttribute(levelKey) == nil then
		return false
	end
	player:SetAttribute(levelKey, math.clamp(math.floor(level), 1, SkillSetConfig.MaxMastery))
	player:SetAttribute(SkillSetConfig.MasteryXPAttribute(setName), 0)
	return true
end

-- Admin tools. Each returns false while the player's save is still loading.

-- Sets Level, XP, StatPoints or a stat directly, clamped to what's valid.
-- Unspent points and stats an admin hands out are covered by BonusPoints;
-- lowering a level below what's been spent refunds the stats.
function PlayerStats.Set(player, field, value)
	if player:GetAttribute("Level") == nil then
		return false
	end
	value = math.max(math.floor(value), 0)
	local stat = StatConfig.Get(field)
	if field == "StatPoints" then
		local bonus = player:GetAttribute("BonusPoints")
		player:SetAttribute("BonusPoints", bonus + value - (earnedPoints(player) - spentPoints(player)))
	elseif field == "Level" then
		player:SetAttribute("Level", math.clamp(value, 0, StatConfig.MaxLevel))
	elseif field == "XP" then
		player:SetAttribute("XP", value)
		levelUp(player)
	elseif stat then
		value = math.min(value, StatConfig.StatCap(field))
		player:SetAttribute(field, value)
		local shortfall = spentPoints(player) - earnedPoints(player)
		if shortfall > 0 then
			player:SetAttribute("BonusPoints", player:GetAttribute("BonusPoints") + shortfall)
		end
		if field == "Vitality" then
			applyHealth(player, false)
		end
	else
		return false
	end
	updatePoints(player)
	return true
end

-- puts every spent point back into StatPoints
function PlayerStats.ResetStats(player)
	if player:GetAttribute("Level") == nil then
		return false
	end
	for _, stat in ipairs(StatConfig.Stats) do
		player:SetAttribute(stat.key, 0)
	end
	updatePoints(player)
	applyHealth(player, false)
	return true
end

-- back to a brand-new character: level 0, nothing earned or spent
function PlayerStats.ResetProgress(player)
	if player:GetAttribute("Level") == nil then
		return false
	end
	for field, default in pairs(DEFAULTS) do
		player:SetAttribute(field, default)
	end
	updatePoints(player)
	applyHealth(player, false)
	return true
end

-- the stats menu asks to put `amount` points into a stat
local function allocate(player, key, amount)
	local stat = typeof(key) == "string" and StatConfig.Get(key)
	if not stat or typeof(amount) ~= "number" or amount ~= amount then
		return
	end
	local points = player:GetAttribute("StatPoints")
	local current = player:GetAttribute(key)
	if not points or not current then
		return
	end
	amount = math.min(math.clamp(math.floor(amount), 0, points), StatConfig.StatCap(key) - current)
	if amount <= 0 then
		return
	end
	player:SetAttribute(key, current + amount)
	updatePoints(player)
	if key == "Vitality" then
		applyHealth(player, false)
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applyHealth(player, true)
	end)
	load(player)
end

function PlayerStats.Start()
	allocateEvent.OnServerEvent:Connect(allocate)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		canSave[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(save, player)
			end
		end
	end)
end

return PlayerStats
