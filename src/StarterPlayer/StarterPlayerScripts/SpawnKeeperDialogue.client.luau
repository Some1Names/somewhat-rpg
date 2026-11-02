-- Talking to the Spawn Keeper: its prompt opens the conversation (DialogueConfig.Trees.SpawnKeeper);
-- the replies that set or clear the spawn go to SpawnServer through the SpawnKeeperAction remote,
-- and the travel reply opens the travel map (FastTravelMenu).
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueConfig = require(ReplicatedStorage:WaitForChild("DialogueConfig"))
local Dialogue = require(script.Parent:WaitForChild("Dialogue"))
local FastTravelMenu = require(script.Parent:WaitForChild("FastTravelMenu"))

local remote = ReplicatedStorage:WaitForChild("SpawnKeeperAction")

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local npc = prompt.Name == "SpawnPrompt" and prompt:FindFirstAncestorOfClass("Model")
	if not npc then
		return
	end
	Dialogue.Open(DialogueConfig.Trees.SpawnKeeper, {
		npc = npc,
		range = 12, -- inside SpawnServer's reach, so a pick is never refused
		speaker = npc:GetAttribute("ShopTitle"),
		onAction = function(action)
			if action == "travel" then
				FastTravelMenu.Open(npc)
			else
				remote:FireServer(npc, action)
			end
		end,
	})
end)
