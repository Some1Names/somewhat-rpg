-- The death screen: when your character dies, a dark square band across the
-- middle of the screen says YOU DIED, who killed you and with what (from the
-- KillFeed message about you, or "You died" when no player gets the credit),
-- the yen the death cost ("−1,240 ¥", from LastDeathYenLost, which
-- ServerScriptService.Headhunter sets; nothing at 0), and counts down to the
-- respawn (Players.RespawnTime). It goes when your
-- new character arrives. With Quick respawn on (Preferences, set in
-- Settings) the server respawns you at once instead, so it doesn't show.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local player = Players.LocalPlayer

local BAND_HEIGHT = 120
local YEN_ROW = 22 -- pixels the yen line adds to the band
local CAUSE_WAIT = 0.5 -- seconds to wait for the kill feed's word on who did it
local TICK = 0.1 -- seconds between countdown updates
local BACKGROUND = Color3.fromRGB(12, 10, 16)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local DANGER = Color3.fromRGB(226, 75, 74)

local gui = Instance.new("ScreenGui")
gui.Name = "DeathScreen"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local band = Instance.new("Frame")
band.AnchorPoint = Vector2.new(0.5, 0.5)
band.Position = UDim2.fromScale(0.5, 0.5)
band.Size = UDim2.new(1, 0, 0, BAND_HEIGHT)
band.BackgroundColor3 = BACKGROUND
band.BackgroundTransparency = 0.25
band.BorderSizePixel = 0
band.Parent = gui

local function line(text, font, size, color, y, height)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, y)
	label.Size = UDim2.new(1, -40, 0, height)
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	label.Parent = band
	return label
end

line("YOU DIED", Enum.Font.GothamBold, 36, DANGER, 14, 40)
local cause = line("", Enum.Font.GothamMedium, 16, TEXT, 58, 20)
local yenLost = line("", Enum.Font.GothamBold, 15, DANGER, 82, 18)
local countdown = line("", Enum.Font.GothamMedium, 13, MUTED, 84, 18)

-- 12345 -> "12,345"
local function withCommas(number)
	local text = tostring(math.floor(number))
	local formatted
	repeat
		text, formatted = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
	until formatted == 0
	return text
end

-- the yen line under the cause, and room for it, only when the death cost some
local function showYen(visible)
	local lost = visible and player:GetAttribute("LastDeathYenLost") or 0
	local shown = lost > 0
	yenLost.Visible = shown
	yenLost.Text = shown and ("−" .. withCommas(lost) .. " ¥") or ""
	countdown.Position = UDim2.new(0.5, 0, 0, shown and 84 + YEN_ROW or 84)
	band.Size = UDim2.new(1, 0, 0, shown and BAND_HEIGHT + YEN_ROW or BAND_HEIGHT)
end

-- the latest kill feed message about this player: { at, killerName, setName }
local lastKill
ReplicatedStorage:WaitForChild("KillFeed").OnClientEvent:Connect(function(victimId, _victimName, _killerId, killerName, setName)
	if victimId == player.UserId then
		lastKill = { at = os.clock(), killerName = killerName, setName = setName }
	end
end)

local function causeText(kill)
	if not kill or not kill.killerName then
		return "You died"
	end
	local set = kill.setName and SkillSetConfig.Sets[kill.setName]
	if set then
		return string.format("Killed by %s with %s", kill.killerName, set.tool)
	end
	return string.format("Killed by %s", kill.killerName)
end

local showing -- the death being shown (a token), or nil

local function show(diedAt)
	local token = {}
	showing = token
	gui.Enabled = true
	cause.Text = ""
	showYen(false)
	local respawnAt = diedAt + Players.RespawnTime
	-- the kill feed message may come just before the death or just after it
	task.spawn(function()
		local waitUntil = diedAt + CAUSE_WAIT
		while showing == token and os.clock() < waitUntil and not (lastKill and lastKill.at >= diedAt - CAUSE_WAIT) do
			task.wait(TICK)
		end
		if showing == token then
			local recent = lastKill and lastKill.at >= diedAt - CAUSE_WAIT and lastKill or nil
			cause.Text = causeText(recent)
			showYen(true)
		end
	end)
	while showing == token do
		local left = respawnAt - os.clock()
		if left <= 0 then
			break
		end
		countdown.Text = string.format("Respawning in %d…", math.ceil(left))
		task.wait(TICK)
	end
	if showing == token then
		showing = nil
		gui.Enabled = false
	end
end

local function watchCharacter(character)
	-- a new character: whatever death was showing is over
	showing = nil
	gui.Enabled = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Once(function()
		-- Quick respawn: the server brings them straight back, no screen
		if Preferences.Get("QuickRespawn") then
			return
		end
		show(os.clock())
	end)
end

-- the server may set the loss just after the cause shows
player:GetAttributeChangedSignal("LastDeathYenLost"):Connect(function()
	if showing and cause.Text ~= "" then
		showYen(true)
	end
end)

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
