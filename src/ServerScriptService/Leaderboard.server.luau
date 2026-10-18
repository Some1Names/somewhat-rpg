-- The player list's extra column: each player's yen, mirrored from the Yen
-- attribute PlayerStats keeps (Roblox shows every IntValue in a folder named
-- "leaderstats" on the player).
local Players = game:GetService("Players")

local function setUp(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local yen = Instance.new("IntValue")
	yen.Name = "Yen"
	yen.Value = player:GetAttribute("Yen") or 0
	yen.Parent = stats
	stats.Parent = player
	player:GetAttributeChangedSignal("Yen"):Connect(function()
		yen.Value = player:GetAttribute("Yen") or 0
	end)
end

Players.PlayerAdded:Connect(setUp)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setUp, player)
end
