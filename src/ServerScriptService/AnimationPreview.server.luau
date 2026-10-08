-- Studio only: copies the unpublished animations in ServerStorage.NewAnimations
-- (each with a Target attribute: the Animation under ReplicatedStorage it's
-- meant for) to ReplicatedStorage.AnimationPreviews, so the client can play
-- them in playtests before they're published (StarterPlayerScripts.
-- AnimationPreview). Live servers skip this.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end
local source = ServerStorage:FindFirstChild("NewAnimations")
if source then
	local copy = source:Clone()
	copy.Name = "AnimationPreviews"
	copy.Parent = ReplicatedStorage
end
