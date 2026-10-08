-- Swaps Roblox's default walk, run, idle, jump and fall (the character's
-- Animate script) for ours in ReplicatedStorage.MovementAnimations. One with
-- an empty AnimationId (not published yet) leaves the default. Walk serves
-- for both walking and running; sprinting has its own (Sprint).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ours = ReplicatedStorage:WaitForChild("MovementAnimations")
local animate = script.Parent:WaitForChild("Animate", 10)
if not animate then
	return
end

-- the Animate values each of ours stands in for
local SLOTS = {
	Walk = { "walk", "run" },
	Idle = { "idle" },
	Jump = { "jump" },
	Fall = { "fall" },
}

-- Animate notices the change and reloads that set
for name, slots in pairs(SLOTS) do
	local animation = ours:FindFirstChild(name)
	if animation and animation.AnimationId ~= "" then
		for _, slot in ipairs(slots) do
			local value = animate:WaitForChild(slot, 5)
			if value then
				for _, child in ipairs(value:GetChildren()) do
					if child:IsA("Animation") then
						child.AnimationId = animation.AnimationId
					end
				end
			end
		end
	end
end
