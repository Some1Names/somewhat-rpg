-- Spawns each raid boss (RaidConfig) at its arena on its timer: the first
-- `firstSpawn` seconds after the server starts, then every `interval`, warning
-- the whole server `warning` seconds before (RaidEvent "Warning"). The arena is
-- a part, workspace.BossArenas.<key>; without one the boss only comes out from
-- the admin panel. A boss still out when its next time comes is left be.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RaidBoss = require(ServerScriptService:WaitForChild("RaidBoss"))
local RaidConfig = require(ReplicatedStorage:WaitForChild("RaidConfig"))

local remote = ReplicatedStorage:WaitForChild(RaidConfig.RemoteName)

local function arenaOf(key)
	local folder = workspace:FindFirstChild(RaidConfig.ArenaFolder)
	return folder and folder:FindFirstChild(key)
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
					warn("[RaidServer] no workspace." .. RaidConfig.ArenaFolder .. "." .. key .. " part: " .. boss.name .. " only spawns from the admin panel")
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
