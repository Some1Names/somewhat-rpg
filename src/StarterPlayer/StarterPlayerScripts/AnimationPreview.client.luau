-- Studio only: plays the new animations before they're published. Each
-- KeyframeSequence in ReplicatedStorage.AnimationPreviews (copied there by
-- ServerScriptService.AnimationPreview) is registered for a temporary id,
-- which goes on the Animation its Target attribute names (a path under
-- ReplicatedStorage), unless that one already plays the published version
-- (its PublishedFrom attribute matches). Only this client sees it.
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end
local previews = ReplicatedStorage:WaitForChild("AnimationPreviews", 10)
if not previews then
	return
end

local function find(path)
	local node = ReplicatedStorage
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

for _, sequence in ipairs(previews:GetChildren()) do
	local target = sequence:IsA("KeyframeSequence") and sequence:GetAttribute("Target")
	local animation = target and find(target)
	if animation and animation:IsA("Animation") and animation:GetAttribute("PublishedFrom") ~= sequence.Name then
		local ok, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, sequence)
		if ok then
			animation.AnimationId = id
		else
			warn("[AnimationPreview] " .. sequence.Name .. ": " .. tostring(id))
		end
	end
end
