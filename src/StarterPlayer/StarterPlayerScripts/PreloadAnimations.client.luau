-- Loads every animation as a player enters, so the first punch, cast or dash
-- doesn't wait on a download. Runs in the background: nothing waits for it.
-- Takes every Animation in ReplicatedStorage (the skill sets' folders, and any
-- added later) and Workspace (the NPC rigs' Animate scripts), plus the walk and
-- slash EnemyAI falls back on when a rig has none. Animations in ServerStorage
-- (tools not yet handed out) can't be reached from here.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- EnemyAI's defaults (R6 walk, R15 walk, R6 slash, R15 slash)
local EXTRA_IDS = {
	"rbxassetid://180426354",
	"rbxassetid://507777826",
	"rbxassetid://129967390",
	"rbxassetid://522635514",
}

local requested = {} -- AnimationId -> true, so each is asked for once

local function preload(animations)
	local fresh = {}
	for _, animation in ipairs(animations) do
		if animation.AnimationId ~= "" and not requested[animation.AnimationId] then
			requested[animation.AnimationId] = true
			table.insert(fresh, animation)
		end
	end
	if #fresh > 0 then
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, fresh)
		end)
	end
end

local function collect(root)
	local found = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Animation") then
			table.insert(found, descendant)
		end
	end
	return found
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local extras = {}
for _, id in ipairs(EXTRA_IDS) do
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	table.insert(extras, animation)
end

preload(collect(ReplicatedStorage))
preload(collect(workspace))
preload(extras)

-- an animation added to ReplicatedStorage later is loaded as it arrives
ReplicatedStorage.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Animation") then
		preload({ descendant })
	end
end)
