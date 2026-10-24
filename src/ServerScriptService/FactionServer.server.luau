-- The faction recruiters: NPCs (models tagged "FactionRecruiter", with an optional
-- FactionId attribute naming one FactionConfig key; with none, the NPC offers all three).
-- Holding a prompt joins that faction (Factions.Join checks the switch cooldown); the
-- result is shown by the client from the FactionNotice attribute, like the Spawn Keeper's notice.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Factions = require(script.Parent:WaitForChild("Factions"))
local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))

local TAG = "FactionRecruiter"
local PROMPT = "FactionPrompt"

local function notify(player, text)
	player:SetAttribute("FactionNotice", text .. "|" .. os.clock()) -- the client shows the text part
end

local function onPrompt(npc, player, faction)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if (npc:GetPivot().Position - root.Position).Magnitude > FactionConfig.RecruiterRange then
		return
	end
	local ok, reason = Factions.Join(player, faction.key)
	notify(player, ok and ("Joined " .. faction.name) or reason)
end

-- the factions a recruiter offers: the one named by its FactionId attribute, or all
-- of them when it has none (or "All"), each with its own key (E, F, R) side by side
local PROMPT_KEYS = { Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.R }
local PROMPT_SPACING = 190 -- pixels between the side-by-side prompts

local function offered(npc)
	local id = npc:GetAttribute("FactionId")
	if id == nil or id == "" or id == "All" then
		return FactionConfig.Factions
	end
	local faction = FactionConfig.Get(id)
	return faction and { faction } or {}
end

local function bind(npc)
	if not npc:IsA("Model") then
		return
	end
	local root = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
	local list = offered(npc)
	if #list == 0 or not root then
		warn("[FactionServer] " .. npc:GetFullName() .. " needs a valid FactionId attribute (or none, for all) and a root part")
		return
	end
	for i, faction in ipairs(list) do
		local name = PROMPT .. "_" .. faction.key
		local prompt = root:FindFirstChild(name)
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = name
			prompt.ActionText = "Join " .. faction.name
			prompt.ObjectText = npc.Name
			prompt.HoldDuration = 0.8
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			if #list > 1 then
				prompt.KeyboardKeyCode = PROMPT_KEYS[i] or Enum.KeyCode.E
				prompt.UIOffset = Vector2.new((i - (#list + 1) / 2) * PROMPT_SPACING, 0)
				prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
			end
			prompt.Parent = root
		end
		prompt.Triggered:Connect(function(player)
			onPrompt(npc, player, faction)
		end)
	end
end

for _, npc in ipairs(CollectionService:GetTagged(TAG)) do
	bind(npc)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)
