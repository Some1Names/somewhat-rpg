-- The kill feed: when a player dies, every client is told who did it on the
-- KillFeed remote, as (victim's UserId, victim's name, killer's UserId,
-- killer's name, the skill set the killing hit came from). The killer
-- parts are nil when no other player hit them in the last CreditTime
-- seconds (an NPC, a fall long after a fight, a reset), and the set is nil
-- for a bare-handed hit. StarterPlayerScripts.KillFeed draws it.
-- Models tagged KillFeedDummy (the "Player Dummy" by the training dummies)
-- count as players here, so the feed can be tried out alone; their UserId
-- is 0 and their name is the model's.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Damage = require(ServerScriptService:WaitForChild("Damage"))
local HeadhunterConfig = require(ReplicatedStorage:WaitForChild("HeadhunterConfig"))

local CREDIT_TIME = HeadhunterConfig.CreditTime -- seconds a player's hit still counts as the kill (one rule, shared with Headhunter)
local DUMMY_TAG = "KillFeedDummy"

local remote = Instance.new("RemoteEvent")
remote.Name = "KillFeed"
remote.Parent = ReplicatedStorage

-- announces the death of `character` (a player's, or a KillFeedDummy when
-- `player` is nil)
local function watchCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local victimId = player and player.UserId or 0
	local victimName = player and player.DisplayName or character.Name
	humanoid.Died:Once(function()
		local killer = Damage.LastAttacker(humanoid)
		local hit = Damage.LastHit(humanoid)
		if killer and killer ~= player and killer.Parent and hit and os.clock() - hit.at <= CREDIT_TIME then
			remote:FireAllClients(victimId, victimName, killer.UserId, killer.DisplayName, hit.skillSet)
		else
			remote:FireAllClients(victimId, victimName, nil, nil, nil)
		end
	end)
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

-- the test dummies (a respawned one is a fresh tagged copy)
local function watchDummy(model)
	if model:IsA("Model") and model:IsDescendantOf(workspace) then
		task.spawn(watchCharacter, nil, model)
	end
end
CollectionService:GetInstanceAddedSignal(DUMMY_TAG):Connect(watchDummy)
for _, model in ipairs(CollectionService:GetTagged(DUMMY_TAG)) do
	watchDummy(model)
end
