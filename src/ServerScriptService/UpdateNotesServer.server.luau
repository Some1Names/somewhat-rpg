-- Server side of the What's new modal: the client fires the SeenUpdateNotes
-- remote (made here) with the version it just showed, and it's kept as the
-- player's SeenUpdate attribute, which PlayerStats saves. Only the current
-- version is taken, so a player can't write anything else into their save.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpdateNotes = require(ReplicatedStorage:WaitForChild("UpdateNotes"))

local remote = Instance.new("RemoteEvent")
remote.Name = "SeenUpdateNotes"
remote.Parent = ReplicatedStorage

remote.OnServerEvent:Connect(function(player, version)
	if version == UpdateNotes.Version then
		player:SetAttribute("SeenUpdate", version)
	end
end)
