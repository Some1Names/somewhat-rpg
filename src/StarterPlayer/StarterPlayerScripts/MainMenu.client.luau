-- The hub's MAIN MENU entry, at the foot of the nav under Settings: press it twice and the
-- server (MenuServer) saves you and sends you back through the title menu by rejoining. A
-- refusal (in combat) shows in the entry's place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hub = require(script.Parent:WaitForChild("Hub"))

local remote = ReplicatedStorage:WaitForChild("ReturnToMenu")

Hub.Tab("MainMenu", {
	order = 8,
	title = "MAIN MENU",
	apart = true,
	confirm = "SURE? PRESS AGAIN",
	action = function()
		local ok, answer = pcall(remote.InvokeServer, remote)
		if not ok or type(answer) ~= "table" then
			return "Couldn't leave"
		end
		if not answer.ok then
			return answer.reason or "Couldn't leave"
		end
		return nil
	end,
})
