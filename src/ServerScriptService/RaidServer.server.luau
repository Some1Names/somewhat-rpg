-- Spawns each raid boss (RaidConfig) at its arena on its timer: the first
-- `firstSpawn` seconds after the server starts, then every `interval`, warning
-- the whole server `warning` seconds before (RaidEvent "Warning"). The arena is
-- the workspace part its `arena` names; without it the boss only comes out from
-- the admin panel. A boss still out when its next time comes is left be.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RaidBoss = require(ServerScriptService:WaitForChild("RaidBoss"))
local RaidConfig = require(ReplicatedStorage:WaitForChild("RaidConfig"))

local remote = ReplicatedStorage:WaitForChild(RaidConfig.RemoteName)

local function arenaOf(key)
	return workspace:FindFirstChild(RaidConfig.Bosses[key].arena)
end

for key, boss in pairs(RaidConfig.Bosses) do
	task.spawn(function()
		local warned = false
		local nextSpawn = boss.firstSpawn
		while true do
			task.wait(math.max(nextSpawn - boss.warning, 0))
			nextSpawn = boss.interval
			local arena = arenaOf(key)
			if not arena then
				if not warned then
					warned = true
					warn("[RaidServer] no workspace." .. boss.arena .. " part: " .. boss.name .. " only spawns from the admin panel")
				end
			elseif not RaidBoss.IsUp(key) then
				remote:FireAllClients("Warning", key, boss.warning)
				task.wait(boss.warning)
				arena = arenaOf(key)
				if arena and not RaidBoss.IsUp(key) then
					RaidBoss.Spawn(key, arena.CFrame)
				end
			end
		end
	end)
end
