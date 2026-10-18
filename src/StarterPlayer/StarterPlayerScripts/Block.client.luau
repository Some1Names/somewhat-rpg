-- Hold Alt (Keybinds "Block") to block: sends true on the Block remote when the
-- key goes down and false when it comes up (ServerScriptService.Guard decides
-- whether the block takes; GuardConfig has the rules). Letting go also
-- happens on death, a respawn and the window losing focus, and Dash lets go
-- itself. A press while a ProximityPrompt is on screen is the prompt's, not a
-- block. Prompts use E, so this only matters when Block is rebound to E: then,
-- so E always blocks in a fight, every prompt in the world is switched off on
-- this client while you're in combat (you dealt or took damage within
-- GuardConfig.CombatTime, the LastCombatAt attribute) and comes back after.
-- Plays the block pose in ReplicatedStorage.CombatAnimations.Block while the
-- character's Blocking attribute is on, once that animation exists.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GuardConfig = require(ReplicatedStorage:WaitForChild("GuardConfig"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local blockRemote = ReplicatedStorage:WaitForChild("Block")

local player = Players.LocalPlayer

local COMBAT_CHECK = 0.25 -- seconds between looks at whether the fight is over
local BLEND = 0.1 -- seconds to blend the block pose in and out

local pressed = false -- we sent true and haven't sent false
local promptsShown = 0
local inCombat = false
local switchedOff = setmetatable({}, { __mode = "k" }) -- prompts we disabled -> true

-- prompts are triggered with E
local function sharesPromptKey()
	return Keybinds.Key("Block") == Enum.KeyCode.E
end

local function release()
	if pressed then
		pressed = false
		blockRemote:FireServer(false)
	end
end

-- Block key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not GuardConfig.Enabled or gameProcessed or Menus.Blocks() or Keybinds.Capturing() or input.KeyCode ~= Keybinds.Key("Block") then
		return
	end
	-- E is the prompt's while one is on screen
	if (sharesPromptKey() and promptsShown > 0) or pressed then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	pressed = true
	blockRemote:FireServer(true)
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Keybinds.Key("Block") then
		release()
	end
end)
UserInputService.WindowFocusReleased:Connect(release)

-- prompts on screen
ProximityPromptService.PromptShown:Connect(function()
	promptsShown += 1
end)
ProximityPromptService.PromptHidden:Connect(function()
	promptsShown = math.max(promptsShown - 1, 0)
end)

-- prompts hide while in combat
local function setPrompt(prompt, combat)
	if combat then
		if prompt.Enabled then
			switchedOff[prompt] = true
			prompt.Enabled = false
		end
	elseif switchedOff[prompt] then
		switchedOff[prompt] = nil
		prompt.Enabled = true
	end
end

local function combatNow()
	local character = player.Character
	local at = character and character:GetAttribute("LastCombatAt")
	return at ~= nil and workspace:GetServerTimeNow() - at < GuardConfig.CombatTime
end

local function refreshCombat()
	local combat = sharesPromptKey() and combatNow()
	if combat == inCombat then
		return
	end
	inCombat = combat
	if combat then
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				setPrompt(descendant, true)
			end
		end
	else
		for prompt in pairs(switchedOff) do
			setPrompt(prompt, false)
		end
	end
end

Keybinds.Changed(refreshCombat)

workspace.DescendantAdded:Connect(function(descendant)
	if inCombat and descendant:IsA("ProximityPrompt") then
		setPrompt(descendant, true)
	end
end)

task.spawn(function()
	while true do
		task.wait(COMBAT_CHECK)
		refreshCombat()
	end
end)

-- the block pose, if the animation has been made
local function watchPose(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local animator = humanoid and humanoid:WaitForChild("Animator", 10)
	local folder = ReplicatedStorage:FindFirstChild("CombatAnimations")
	local animation = folder and folder:FindFirstChild("Block")
	if not animator or not animation or animation.AnimationId == "" then
		return
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	local function update()
		if character:GetAttribute("Blocking") == true then
			if not track.IsPlaying then
				track:Play(BLEND)
			end
		elseif track.IsPlaying then
			track:Stop(BLEND)
		end
	end
	character:GetAttributeChangedSignal("Blocking"):Connect(update)
	update()
end

local function onCharacter(character)
	pressed = false
	-- the server clears the block on death; this just lets go of the key state
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Once(release)
	end
	character:GetAttributeChangedSignal("LastCombatAt"):Connect(refreshCombat)
	task.spawn(watchPose, character)
end

if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)
