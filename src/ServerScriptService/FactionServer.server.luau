-- The faction recruiters: NPCs (models tagged "FactionRecruiter", with an optional
-- FactionId attribute naming one FactionConfig key; with none, the NPC offers all three).
-- Each has one prompt that opens the faction menu on the client (FactionMenu); its JOIN
-- buttons call the FactionAction remote (made here), which checks the recruiter, its
-- range and what it offers, then Factions.Join (the switch cooldown). The result goes
-- back to the menu and to the FactionNotice attribute, like the Spawn Keeper's notice.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Factions = require(script.Parent:WaitForChild("Factions"))
local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))

local TAG = FactionConfig.RecruiterTag
local PROMPT = "FactionPrompt"

local remote = ReplicatedStorage:FindFirstChild(FactionConfig.Remote)
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = FactionConfig.Remote
	remote.Parent = ReplicatedStorage
end

local function notify(player, text)
	player:SetAttribute("FactionNotice", text .. "|" .. os.clock()) -- the client shows the text part
end

local function offered(npc)
	return FactionConfig.Offered(npc:GetAttribute("FactionId"))
end

local function offers(npc, key)
	for _, faction in ipairs(offered(npc)) do
		if faction.key == key then
			return faction
		end
	end
	return nil
end

remote.OnServerInvoke = function(player, action, npc, key)
	if action ~= "join" or typeof(npc) ~= "Instance" or not CollectionService:HasTag(npc, TAG) or typeof(key) ~= "string" then
		return false, "Can't do that"
	end
	local faction = offers(npc, key)
	if not faction then
		return false, "This recruiter doesn't take that faction"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, "Can't do that now"
	end
	if (npc:GetPivot().Position - root.Position).Magnitude > FactionConfig.RecruiterRange then
		return false, "Too far from the recruiter"
	end
	local ok, reason = Factions.Join(player, faction.key)
	local text = ok and ("Joined " .. faction.name) or reason
	notify(player, text)
	return ok, text
end

local function bind(npc)
	if not npc:IsA("Model") then
		return
	end
	local root = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
	if #offered(npc) == 0 or not root then
		warn("[FactionServer] " .. npc:GetFullName() .. " needs a valid FactionId attribute (or none, for all) and a root part")
		return
	end
	if root:FindFirstChild(PROMPT) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT
	prompt.ActionText = "Choose a faction"
	prompt.ObjectText = npc.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
end

for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
	bind(npc)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)
