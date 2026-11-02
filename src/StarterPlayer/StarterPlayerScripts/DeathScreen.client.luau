-- The death screen: when your character dies it closes in the way the title menu opens. Black
-- bars along the top and the bottom (Roblox's band sits in the top one) and, down the left over a
-- dark fading off the edge, CHARACTER DOWN on a red line, YOU DIED big, then who killed you on a
-- red chip and with what under it (from the KillFeed message about you; just the rule when no
-- player gets the credit). The bottom bar counts down to the respawn (Players.RespawnTime), a red
-- line along its top running out with it, and on its right says the yen the death cost
-- ("−1,240 ¥", from LastDeathYenLost, which ServerScriptService.Headhunter sets; nothing at 0).
-- While it's up the world goes grey and the rest of the UI is hidden the way the hub hides it, all
-- but the leaderboard and the kill feed (KEEP_SHOWING). It goes when your new character arrives.
-- With Quick respawn on (Preferences, set in Settings) the server respawns you at once instead, so
-- it doesn't show. Square everything.
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local Preferences = require(ReplicatedStorage:WaitForChild("Preferences"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))
local player = Players.LocalPlayer
local Style = HudConfig.Style
local Theme = HudConfig.HubTheme

local PAD = 64 -- the screen's left edge to the title (as on the title menu)
local ROBLOX_BAR_FALLBACK = 58 -- Roblox's band across the top, while GetGuiInset still says 0
local BOTTOM_BAR = 44 -- the black bar along the bottom; the top one is as tall as Roblox's band
local SHADE_SHARE = 0.62 -- how far across the screen the dark fades off the left edge
local STACK_WIDTH = 460 -- the line, the title and who killed you
local STACK_HEIGHT = 212
local OPEN_TIME = 0.5 -- the bars closing in, the title sliding in
local STAGGER = 0.06 -- s between one thing sliding in and the next
local CAUSE_WAIT = 0.5 -- seconds to wait for the kill feed's word on who did it
local TICK = 0.1 -- seconds between countdown updates
local DANGER = Color3.fromRGB(226, 75, 74) -- the accent: the lines, the chip, the yen lost
local KEEP_SHOWING = { Leaderboard = true, KillFeed = true } -- guis left up while it shows

local function tween(instance, time, props)
	local tweenObject = TweenService:Create(instance, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tweenObject:Play()
	return tweenObject
end

local function make(className, props)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function label(parent, props)
	props.Parent = parent
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Style.LabelFont
	props.TextColor3 = props.TextColor3 or Theme.NavText
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "DeathScreen",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})
-- the world goes grey while it shows (made on the client, so only for this player)
local grey = make("ColorCorrectionEffect", { Name = "DeathGrey", Enabled = false, Parent = Lighting })

-- the title menu's look: the dark fading off the left edge, and black bars along the top and the
-- bottom, each with a thin light line on its inner edge
local screen = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
local shade = make("Frame", { Parent = screen, Size = UDim2.fromScale(SHADE_SHARE, 1), BackgroundColor3 = Theme.Nav, BorderSizePixel = 0 })
make("UIGradient", {
	Parent = shade,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	}),
})
local topBar = make("Frame", { Parent = screen, Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4 })
local bottomBar = make("Frame", {
	Parent = screen,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 4,
})
for _, edge in ipairs({ { topBar, 1 }, { bottomBar, 0 } }) do
	make("Frame", {
		Parent = edge[1],
		AnchorPoint = Vector2.new(0, edge[2]),
		Position = UDim2.fromScale(0, edge[2]),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Edge,
		BackgroundTransparency = Theme.EdgeTransparency,
		BorderSizePixel = 0,
		ZIndex = 4,
	})
end

-- in the bottom bar: the respawn counting down on the left, with a red line along the bar's top
-- running out with it, and the yen the death cost on the right
local countdown = label(bottomBar, {
	Text = "",
	RichText = true,
	Font = Style.MonoFont,
	TextSize = 12,
	TextColor3 = Theme.Muted,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, PAD, 0.5, 0),
	Size = UDim2.new(0.5, -PAD, 0, 16),
	ZIndex = 5,
})
local yenLost = label(bottomBar, {
	Text = "",
	RichText = true,
	Font = Style.MonoFont,
	TextSize = 12,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -PAD, 0.5, 0),
	Size = UDim2.new(0.5, -PAD, 0, 16),
	ZIndex = 5,
})
local runOut = make("Frame", { Parent = bottomBar, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = DANGER, BorderSizePixel = 0, ZIndex = 5 })

-- down the left between the bars, shrunk to fit a short screen: CHARACTER DOWN on a red line,
-- YOU DIED big, then who killed you on a red chip with a rule running on and with what under it.
-- Each of the three is a layer the size of the stack that slides in from the left
local stack = make("Frame", {
	Parent = screen,
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(STACK_WIDTH, STACK_HEIGHT),
	BackgroundTransparency = 1,
	ZIndex = 5,
})
local fit = make("UIScale", { Parent = stack })
local function layer()
	return make("Frame", { Parent = stack, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 })
end

local kicker = layer()
make("Frame", { Parent = kicker, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = DANGER, BorderSizePixel = 0, ZIndex = 5 })
label(kicker, {
	Text = "CHARACTER DOWN",
	Font = Style.MonoFont,
	TextSize = 12,
	TextColor3 = Theme.Muted,
	Position = UDim2.fromOffset(34, 0),
	Size = UDim2.new(1, -34, 0, 14),
	ZIndex = 5,
})

local headline = layer()
local title = label(headline, {
	Text = "YOU DIED",
	Font = Style.TitleFont,
	TextSize = 100,
	Position = UDim2.fromOffset(-3, 20),
	Size = UDim2.fromOffset(330, 100),
	ZIndex = 5,
})
make("UIScale", { Parent = title, Scale = 1.3 }) -- text stops growing at 100 pixels; this takes it past

local cause = layer()
local chip = label(cause, {
	Text = "",
	Font = Style.TitleFont,
	TextSize = 22,
	TextColor3 = Theme.Nav,
	BackgroundColor3 = DANGER,
	BackgroundTransparency = 0,
	Position = UDim2.fromOffset(2, 158),
	Size = UDim2.fromOffset(0, 26),
	AutomaticSize = Enum.AutomaticSize.X,
	ZIndex = 5,
})
local rule = make("Frame", { Parent = cause, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Muted, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 5 })
local weapon = label(cause, {
	Text = "",
	RichText = true,
	Font = Style.MonoFont,
	TextSize = 12,
	TextColor3 = Theme.Muted,
	Position = UDim2.fromOffset(2, 196),
	Size = UDim2.new(1, -2, 0, 14),
	ZIndex = 5,
})

-- the top bar is as tall as Roblox's band; the stack sits in the middle of the room between the
-- bars, shrunk to fit a short screen
local band = ROBLOX_BAR_FALLBACK
local function place()
	band = GuiService:GetGuiInset().Y / UIScale.Get() -- Roblox's band is in real pixels
	band = band > 0 and band or ROBLOX_BAR_FALLBACK / UIScale.Get()
	local view = workspace.CurrentCamera
	local room = (view and view.ViewportSize.Y or 771) / UIScale.Get() - band - BOTTOM_BAR
	fit.Scale = math.clamp((room - 40) / STACK_HEIGHT, 0.3, 1)
	stack.Position = UDim2.fromOffset(PAD, band + room / 2)
	if topBar.Size.Y.Offset > 0 then
		topBar.Size = UDim2.new(1, 0, 0, band)
	end
end
place()
UIScale.OnChange(place)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
end

-- a layer of the stack slides in from the left, `delay` seconds from now
local function slideIn(item, delay)
	item.Position = UDim2.fromOffset(-(PAD + STACK_WIDTH), 0)
	task.delay(delay, function()
		tween(item, OPEN_TIME, { Position = UDim2.new() })
	end)
end

-- the bars close in and the dark comes up, then the line and the title slide in from the left one
-- after the other (who killed you follows once the kill feed has said)
local openedAt = 0
local function intro()
	openedAt = os.clock()
	topBar.Size = UDim2.fromScale(1, 0)
	bottomBar.Size = UDim2.fromScale(1, 0)
	tween(topBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, band) })
	tween(bottomBar, OPEN_TIME, { Size = UDim2.new(1, 0, 0, BOTTOM_BAR) })
	shade.BackgroundTransparency = 1
	tween(shade, OPEN_TIME, { BackgroundTransparency = 0 })
	slideIn(kicker, STAGGER)
	slideIn(headline, 2 * STAGGER)
	cause.Visible = false
end

-- 12345 -> "12,345"
local function withCommas(number)
	local text = tostring(math.floor(number))
	local formatted
	repeat
		text, formatted = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
	until formatted == 0
	return text
end

-- the yen the death cost, on the right of the bottom bar, once the cause has shown (nothing at 0)
local function showYen(visible)
	local lost = visible and player:GetAttribute("LastDeathYenLost") or 0
	yenLost.Text = lost > 0 and string.format('YEN LOST  <font color="#%s">−%s ¥</font>', DANGER:ToHex(), withCommas(lost)) or ""
end

-- the latest kill feed message about this player: { at, killerName, setName }
local lastKill
ReplicatedStorage:WaitForChild("KillFeed").OnClientEvent:Connect(function(victimId, _victimName, _killerId, killerName, setName)
	if victimId == player.UserId then
		lastKill = { at = os.clock(), killerName = killerName, setName = setName }
	end
end)

-- who killed you on the chip and with what under it, or just the rule when no player gets the
-- credit; it slides in under the title
local function showCause(kill)
	local killerName = kill and kill.killerName
	local set = killerName and kill.setName and SkillSetConfig.Sets[kill.setName]
	chip.Visible = killerName ~= nil
	chip.Text = killerName and (" KILLED BY " .. string.upper(killerName) .. " ") or ""
	local ruleAt = killerName and TextService:GetTextSize(chip.Text, chip.TextSize, chip.Font, Vector2.new(1000, 100)).X + 14 or 0
	rule.Position = UDim2.fromOffset(ruleAt, 171)
	rule.Size = UDim2.new(1, -ruleAt, 0, 1)
	weapon.Text = set and set.tool and string.format('WITH  <font color="#%s">%s</font>', Theme.NavText:ToHex(), string.upper(set.tool)) or ""
	cause.Visible = true
	slideIn(cause, math.max(openedAt + 3 * STAGGER - os.clock(), 0))
end

-- the rest of the UI (every other ScreenGui but KEEP_SHOWING's, and the billboards over
-- characters) is hidden while it shows: each gui's scale-root frame is turned invisible, as the
-- hub does it
local hiddenHud = {} -- { instance, property } pairs to turn back on
local hudWatch
local function hideHudGui(other)
	if other == gui or KEEP_SHOWING[other.Name] then
		return
	end
	if other:IsA("BillboardGui") then
		if other.Enabled then
			other.Enabled = false
			table.insert(hiddenHud, { other, "Enabled" })
		end
	elseif other:IsA("ScreenGui") then
		UIScale.Root(other) -- makes sure the gui has its root frame
		for _, child in ipairs(other:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible and (child.Name == "UIScaleRoot" or UIScale.SkipChild[child.Name]) then
				child.Visible = false
				table.insert(hiddenHud, { child, "Visible" })
			end
		end
	end
end
local function hideHud()
	if hudWatch then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	for _, other in ipairs(playerGui:GetChildren()) do
		hideHudGui(other)
	end
	-- a gui that appears meanwhile goes too
	hudWatch = playerGui.ChildAdded:Connect(function(other)
		task.defer(function()
			if hudWatch then
				hideHudGui(other)
			end
		end)
	end)
end
local function showHud()
	if hudWatch then
		hudWatch:Disconnect()
		hudWatch = nil
	end
	for _, entry in ipairs(hiddenHud) do
		if entry[1].Parent then
			entry[1][entry[2]] = true
		end
	end
	hiddenHud = {}
end

local showing -- the death being shown (a token), or nil

-- the screen goes, and the world's colour and the rest of the UI come back
local function close()
	showing = nil
	gui.Enabled = false
	grey.Enabled = false
	showHud()
end

local function show(diedAt)
	local token = {}
	showing = token
	gui.Enabled = true
	hideHud()
	grey.Saturation = 0
	grey.Enabled = true
	tween(grey, OPEN_TIME, { Saturation = -1 })
	showYen(false)
	intro()
	local respawnAt = diedAt + Players.RespawnTime
	runOut.Size = UDim2.new(1, 0, 0, 2)
	TweenService:Create(runOut, TweenInfo.new(math.max(respawnAt - os.clock(), 0), Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
	-- the kill feed message may come just before the death or just after it
	task.spawn(function()
		local waitUntil = diedAt + CAUSE_WAIT
		while showing == token and os.clock() < waitUntil and not (lastKill and lastKill.at >= diedAt - CAUSE_WAIT) do
			task.wait(TICK)
		end
		if showing == token then
			local recent = lastKill and lastKill.at >= diedAt - CAUSE_WAIT and lastKill or nil
			showCause(recent)
			showYen(true)
		end
	end)
	while showing == token do
		local left = respawnAt - os.clock()
		if left <= 0 then
			break
		end
		countdown.Text = string.format('RESPAWNING IN  <font color="#%s">%.1f</font>', Theme.NavText:ToHex(), left)
		task.wait(TICK)
	end
	if showing == token then
		close()
	end
end

local function watchCharacter(character)
	-- a new character: whatever death was showing is over
	close()
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
	if showing and cause.Visible then
		showYen(true)
	end
end)

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
