-- Talents: which perks each player has equipped. The equipped keys are the
-- saved, replicated `Talents` text (PlayerStats saves it); BuildRules does the
-- checking and the systems that use talents read BuildRules.PlayerModifier.
-- A talent stays only while its stat tier and the player's talent points allow
-- it, so a stat reset or a lower level takes it off again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildRules = require(ReplicatedStorage:WaitForChild("BuildRules"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local TalentConfig = require(ReplicatedStorage:WaitForChild("TalentConfig"))

local REQUEST_INTERVAL = 0.3 -- seconds between a player's equip requests

local Talents = {}

local lastRequest = setmetatable({}, { __mode = "k" })

local function statsOf(player)
	local stats = {}
	for _, stat in ipairs(StatConfig.Stats) do
		stats[stat.key] = player:GetAttribute(stat.key) or 0
	end
	return stats
end

-- drops equipped talents the player no longer qualifies for
function Talents.Refresh(player)
	local level = player:GetAttribute("Level")
	local saved = player:GetAttribute(TalentConfig.SaveAttribute)
	if level == nil or saved == nil then
		return
	end
	local text = BuildRules.Encode(BuildRules.Prune(BuildRules.Decode(saved), statsOf(player), level))
	if text ~= saved then
		player:SetAttribute(TalentConfig.SaveAttribute, text)
	end
end

local function onEquip(player, key, on)
	if typeof(key) ~= "string" or typeof(on) ~= "boolean" then
		return
	end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < REQUEST_INTERVAL then
		return
	end
	lastRequest[player] = now
	local level = player:GetAttribute("Level")
	if level == nil or player:GetAttribute(TalentConfig.SaveAttribute) == nil then
		return
	end
	local equipped = BuildRules.Equipped(player)
	if on then
		if not BuildRules.CanEquip(equipped, key, statsOf(player), level) then
			return
		end
		table.insert(equipped, key)
	else
		local index = table.find(equipped, key)
		if not index then
			return
		end
		table.remove(equipped, index)
	end
	player:SetAttribute(TalentConfig.SaveAttribute, BuildRules.Encode(equipped))
end

local function watch(player)
	local function refresh()
		Talents.Refresh(player)
	end
	player:GetAttributeChangedSignal("Level"):Connect(refresh)
	player:GetAttributeChangedSignal(TalentConfig.SaveAttribute):Connect(refresh)
	for _, stat in ipairs(StatConfig.Stats) do
		player:GetAttributeChangedSignal(stat.key):Connect(refresh)
	end
	refresh()
end

function Talents.Start()
	local remote = Instance.new("RemoteEvent")
	remote.Name = TalentConfig.Remote
	remote.OnServerEvent:Connect(onEquip)
	remote.Parent = ReplicatedStorage
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

return Talents
