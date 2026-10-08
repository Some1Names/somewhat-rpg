-- Respawns every model tagged "Respawns" a few seconds after it dies, as a
-- fresh full-health copy in the spot it started in. (Walking back to that
-- spot while alive, and fighting, is EnemyAI's job, for models tagged "Enemy".)
local CollectionService = game:GetService("CollectionService")

local TAG = "Respawns"
local RESPAWN_DELAY = 3 -- seconds

local function watch(model, original, parent)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[DummyRespawn] " .. model:GetFullName() .. " has no Humanoid")
		return
	end

	local respawning = false
	local function respawn()
		if respawning then
			return
		end
		respawning = true
		task.wait(RESPAWN_DELAY)
		model:Destroy()
		local fresh = original:Clone()
		fresh.Parent = parent
		watch(fresh, original, parent)
	end

	humanoid.Died:Connect(respawn)
	-- also covers a dummy that is removed without dying, e.g. falling off the map
	model.AncestryChanged:Connect(function(_, newParent)
		if not newParent then
			respawn()
		end
	end)
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	if model:IsA("Model") and model:IsDescendantOf(workspace) then
		local original = model:Clone()
		if original then
			watch(model, original, model.Parent)
		else
			warn("[DummyRespawn] can't copy " .. model:GetFullName() .. " (Archivable is off)")
		end
	end
end
