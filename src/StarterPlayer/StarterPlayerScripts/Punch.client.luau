-- Click (or hold) the left mouse button to attack: punches, or axe swings
-- while Mandela is equipped. Hits chain into a combo whose last hit is a
-- critical that knocks the target back. The PunchCombat server script
-- decides what each hit lands on; this script handles input and plays the
-- attack animations, plus the weapon's hold pose while it's equipped. Left
-- click is left to the Ranged script while it has the RangedReady attribute
-- set (a ranged move readied with right click, or a gun in hand).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PunchConfig = require(ReplicatedStorage:WaitForChild("PunchConfig"))
local punchEvent = ReplicatedStorage:WaitForChild("Punch")
local player = Players.LocalPlayer

local BLEND_IN = 0.06 -- seconds to blend into a hit
local BLEND_OUT = 0.15 -- seconds to blend back to walking or idle afterwards
local HOLD_BLEND = 0.2 -- seconds to raise or lower a held weapon
-- swings play over the hold pose
local SWING_PRIORITY = Enum.AnimationPriority.Action2
local HOLD_PRIORITY = Enum.AnimationPriority.Action

local holding = false
local weaponName = "Fists"
local count = 0
local lastHitAt = -math.huge
local holdTrack
local trackSets = setmetatable({}, { __mode = "k" })

local function loadTrack(humanoid, weapon, animationName, priority)
	local folder = ReplicatedStorage:FindFirstChild(weapon.animationFolder)
	local animation = folder and folder:FindFirstChild(animationName)
	-- attacking still works before the animations have been published
	if not animation or animation.AnimationId == "" then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local set = trackSets[animator]
	if not set then
		set = {}
		trackSets[animator] = set
	end
	if not set[animation] then
		local track = animator:LoadAnimation(animation)
		track.Priority = priority
		set[animation] = track
	end
	return set[animation], set
end

local function playHit(humanoid, weapon, index)
	local track, set = loadTrack(humanoid, weapon, weapon.animationPrefix .. index, SWING_PRIORITY)
	if not track then
		return
	end
	for _, other in pairs(set) do
		if other ~= track and other.IsPlaying and other.Priority == SWING_PRIORITY then
			other:Stop(BLEND_IN)
		end
	end
	track:Play(BLEND_IN)
	local startedAt = lastHitAt
	task.delay(weapon.hits[index].length - BLEND_OUT, function()
		-- unless another hit has already taken over
		if lastHitAt == startedAt and track.IsPlaying then
			track:Stop(BLEND_OUT)
		end
	end)
end

-- keeps the equipped weapon's hold pose playing, or stops it
local function updateHold(humanoid, weapon)
	local wanted = weapon.holdAnimation and loadTrack(humanoid, weapon, weapon.holdAnimation, HOLD_PRIORITY) or nil
	if holdTrack and holdTrack ~= wanted then
		holdTrack:Stop(HOLD_BLEND)
	end
	if wanted and not wanted.IsPlaying then
		wanted.Looped = true
		wanted:Play(HOLD_BLEND)
	end
	holdTrack = wanted
end

local function tryAttack()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
		or player:GetAttribute("Dashing")
		or player:GetAttribute("RangedReady")
		or character:GetAttribute("Rewinding") -- Photoshop's Undo carrying her back
	then
		return
	end
	local name, weapon = PunchConfig.WeaponFor(character)
	if weapon.skillSet and character:GetAttribute("WeaponThrown") then
		return -- still in the air (Axe Boomerang)
	end
	if name ~= weaponName then
		-- switching weapons starts a fresh combo, same as the server
		weaponName = name
		count = 0
	end
	local now = os.clock()
	local since = now - lastHitAt
	local rest = count == PunchConfig.ComboLength and weapon.finisherCooldown or 0
	if since < weapon.minInterval + rest then
		return
	end
	if count < PunchConfig.ComboLength and since <= PunchConfig.ComboWindow then
		count += 1
	else
		count = 1
	end
	lastHitAt = now
	playHit(humanoid, weapon, count)
	punchEvent:FireServer(count)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = true
		tryAttack()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = false
	end
end)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local _, weapon = PunchConfig.WeaponFor(character)
	updateHold(humanoid, weapon)
	-- holding the button keeps the combo going
	if holding then
		tryAttack()
	end
end)
