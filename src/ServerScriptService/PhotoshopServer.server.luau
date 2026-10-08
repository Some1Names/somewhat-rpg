-- Photoshop's passive, History, its G key, Undo, and its photo Gallery
-- (fast travel on T). While the set is equipped, where she stands is
-- recorded every SampleInterval and kept for the set's undo.rewind seconds,
-- along with every bit of health she loses. Undo (the Undo remote, sent by
-- the skill bar) puts her back where she stood that long ago and heals
-- undo.healShare of what she lost since, less anything Mandela dealt
-- (reality he rewrote can't be undone) and cut by healing cuts like
-- Poisoned. It can't slip a hold (CrowdControl.Held) and recharges for
-- undo.cooldown (the player's UndoReadyAttribute, server time, for the bar).
-- The Gallery keeps the set's gallery.slots photos of places (the saved
-- PhotoGallery text attribute, "x,y,z;x,y,z;" with empty entries for empty
-- slots). The
-- PhotoGallery remote takes ("save", slot): the spot she stands on, and
-- ("travel", slot): out of combat only (no damage taken or dealt for
-- CombatLock seconds), the photo develops for DevelopTime and she steps
-- into it, unless she's hurt meanwhile. Clients draw it from the
-- SkillEffects "Undo", "GalleryDevelop", "GalleryTravel" and
-- "GalleryCancel" events. Both remotes are made here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CrowdControl = require(ServerScriptService:WaitForChild("CrowdControl"))
local Damage = require(ServerScriptService:WaitForChild("Damage"))
local PhotoshopUtil = require(ServerScriptService:WaitForChild("PhotoshopUtil"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("StatusConfig"))

local skillEffects = ReplicatedStorage:WaitForChild("SkillEffects")

local SET_NAME = "Photoshop"
local UNDO = SkillSetConfig.Sets[SET_NAME].undo
local UNDO_READY = SkillSetConfig.UndoReadyAttribute(SET_NAME)
local GALLERY = "PhotoGallery" -- saved by PlayerStats
local CONFIG = {
	SampleInterval = 0.25, -- seconds between History samples
	GallerySlots = SkillSetConfig.Sets[SET_NAME].gallery.slots,
	CombatLock = 8, -- seconds without dealing or taking damage before travelling
	DevelopTime = 2, -- seconds the photo develops before she steps in
}

local undoRemote = Instance.new("RemoteEvent")
undoRemote.Name = "Undo"
undoRemote.Parent = ReplicatedStorage

local galleryRemote = Instance.new("RemoteEvent")
galleryRemote.Name = "PhotoGallery"
galleryRemote.Parent = ReplicatedStorage

local samples = {} -- player -> { { at, pivot } }, oldest first
local losses = {} -- player -> { { at, amount } }: health lost
local rewritten = {} -- player -> { { at, amount } }: what Mandela dealt her
local lastCombat = {} -- player -> os.clock() of the last damage dealt or taken
local lastHurt = {} -- player -> os.clock() of the last damage taken
local developing = {} -- player -> the travel waiting on its photo

local function holding(character)
	local _, setName = SkillSetConfig.Equipped(character)
	return setName == SET_NAME
end

local function forget(player)
	samples[player] = nil
	losses[player] = nil
	rewritten[player] = nil
end

-- drops entries older than `since` from the front of a list
local function trim(list, since)
	while list and list[1] and list[1].at < since do
		table.remove(list, 1)
	end
end

local function total(list, since)
	local sum = 0
	for _, entry in ipairs(list or {}) do
		if entry.at >= since then
			sum += entry.amount
		end
	end
	return sum
end

-- History: every health drop she takes, from anyone
local function watchCharacter(player, character)
	forget(player)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local health = humanoid.Health
	humanoid.HealthChanged:Connect(function(newHealth)
		local lost = health - newHealth
		health = newHealth
		if lost > 0 then
			local now = os.clock()
			lastCombat[player] = now
			lastHurt[player] = now
			if holding(character) then
				losses[player] = losses[player] or {}
				table.insert(losses[player], { at = now, amount = lost })
			end
		end
	end)
	humanoid.Died:Connect(function()
		forget(player)
	end)
end

-- what Mandela dealt her can't be undone; dealing damage counts as combat
Damage.OnDealt(function(attacker, humanoid, dealt, options)
	local now = os.clock()
	if attacker then
		lastCombat[attacker] = now
	end
	local victim = Players:GetPlayerFromCharacter(humanoid.Parent)
	if victim and options.skillSet == "Mandela" and holding(humanoid.Parent) then
		rewritten[victim] = rewritten[victim] or {}
		table.insert(rewritten[victim], { at = now, amount = dealt })
	end
end)

task.spawn(function()
	while true do
		task.wait(CONFIG.SampleInterval)
		local now = os.clock()
		local since = now - UNDO.rewind - CONFIG.SampleInterval
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and humanoid.RootPart and holding(character) then
				samples[player] = samples[player] or {}
				table.insert(samples[player], { at = now, pivot = character:GetPivot() })
				trim(samples[player], since)
				trim(losses[player], since)
				trim(rewritten[player], since)
			elseif samples[player] then
				forget(player) -- put away: History starts over next time
			end
		end
	end
end)

undoRemote.OnServerEvent:Connect(function(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 or not holding(character) or CrowdControl.Held(character) then
		return
	end
	if (player:GetAttribute(UNDO_READY) or 0) > workspace:GetServerTimeNow() then
		return
	end
	local oldest = samples[player] and samples[player][1]
	if not oldest then
		return
	end
	local lost = total(losses[player], oldest.at) - total(rewritten[player], oldest.at)
	local heal = math.max(lost, 0) * UNDO.healShare * StatusConfig.HealMultiplier(character)
	local from = root.Position
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(oldest.pivot)
	if heal > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
	end
	forget(player)
	player:SetAttribute(UNDO_READY, workspace:GetServerTimeNow() + UNDO.cooldown)
	skillEffects:FireAllClients("Undo", character, from, oldest.pivot.Position)
end)

-- the saved photos: a Vector3 or false per slot (a bad entry is an empty slot)
local function readGallery(player)
	local slots = {}
	local text = player:GetAttribute(GALLERY)
	local entries = typeof(text) == "string" and string.split(text, ";") or {}
	for slot = 1, CONFIG.GallerySlots do
		local parts = string.split(entries[slot] or "", ",")
		local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
		if x and y and z and x == x and y == y and z == z and math.abs(x) < 1e5 and math.abs(y) < 1e5 and math.abs(z) < 1e5 then
			slots[slot] = Vector3.new(x, y, z)
		else
			slots[slot] = false
		end
	end
	return slots
end

local function writeGallery(player, slots)
	local entries = {}
	for slot = 1, CONFIG.GallerySlots do
		local point = slots[slot]
		entries[slot] = point and string.format("%.1f,%.1f,%.1f", point.X, point.Y, point.Z) or ""
	end
	player:SetAttribute(GALLERY, table.concat(entries, ";"))
end

local function travel(player, character, humanoid, point)
	local token = {}
	developing[player] = token
	local started = os.clock()
	skillEffects:FireAllClients("GalleryDevelop", character, CONFIG.DevelopTime)
	task.wait(CONFIG.DevelopTime)
	local stillHere = developing[player] == token and PhotoshopUtil.alive(player, character, humanoid)
	if developing[player] == token then
		developing[player] = nil
	end
	if not stillHere or (lastHurt[player] or -math.huge) > started then
		skillEffects:FireAllClients("GalleryCancel", character)
		return
	end
	local root = humanoid.RootPart
	local from = root.Position
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.new(point) * root.CFrame.Rotation)
	skillEffects:FireAllClients("GalleryTravel", character, from, point)
end

galleryRemote.OnServerEvent:Connect(function(player, action, slot)
	if typeof(action) ~= "string" or typeof(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > CONFIG.GallerySlots then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.Health <= 0 or not holding(character) then
		return
	end
	local slots = readGallery(player)
	if action == "save" then
		-- only a spot she's standing on, so travel never drops her into the air
		if humanoid.FloorMaterial == Enum.Material.Air then
			return
		end
		slots[slot] = root.Position
		writeGallery(player, slots)
	elseif action == "travel" then
		local point = slots[slot]
		if not point or developing[player] or CrowdControl.Held(character) then
			return
		end
		if os.clock() - (lastCombat[player] or -math.huge) < CONFIG.CombatLock then
			return
		end
		task.spawn(travel, player, character, humanoid, point)
	end
end)

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	forget(player)
	lastCombat[player] = nil
	lastHurt[player] = nil
	developing[player] = nil
end)
