-- Hide HUD: the Hide HUD key (Keybinds, H to start with) turns the HUD off for a clean
-- screen, and again on. Every ScreenGui and BillboardGui in PlayerGui is switched off
-- (Enabled) except the menus and screens that aren't HUD and the crosshairs, which turn
-- themselves on and off every frame (SKIP), and any that appear
-- meanwhile go too. The hub hides the HUD its own way (a root frame's Visible), so the two
-- don't undo each other; a billboard the hub turns back on as it closes is caught by the
-- check every RECHECK seconds. Not while a menu is open or a key is being bound.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Keybinds = require(ReplicatedStorage:WaitForChild("Keybinds"))
local Menus = require(script.Parent:WaitForChild("Menus"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local SKIP = {
	Hub = true,
	MenuButton = true,
	TitleMenu = true,
	LoadingScreen = true,
	DeathScreen = true,
	ShiftLockCrosshair = true,
	RangedCrosshair = true,
}
local RECHECK = 0.5 -- seconds between looks for a gui that came back on

local hidden = false
local switchedOff = {} -- gui -> true: the ones this turned off, to turn back on

local function hide(gui)
	if (gui:IsA("ScreenGui") or gui:IsA("BillboardGui")) and gui.Enabled and not SKIP[gui.Name] then
		gui.Enabled = false
		switchedOff[gui] = true
	end
end

local function setHidden(on)
	hidden = on
	if on then
		for _, gui in ipairs(playerGui:GetChildren()) do
			hide(gui)
		end
	else
		for gui in pairs(switchedOff) do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		table.clear(switchedOff)
	end
end

playerGui.ChildAdded:Connect(function(gui)
	if hidden then
		task.defer(hide, gui)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or Keybinds.Capturing() or input.KeyCode ~= Keybinds.Key("HideHud") then
		return
	end
	if Menus.AnyOpen() and not hidden then
		return
	end
	setHidden(not hidden)
end)

while true do
	task.wait(RECHECK)
	if hidden then
		for _, gui in ipairs(playerGui:GetChildren()) do
			hide(gui)
		end
	end
end
