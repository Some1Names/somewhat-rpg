-- Raid bosses on the client (RaidConfig; the fight is the server's RaidBoss):
-- the boss bar near the top of the screen while you're near one (health, the
-- dome's shield in white, the phase, STAGGERED), banners for the raid's moments
-- (it's coming, it's out, a new phase, someone's caught, it's beaten), the
-- ground markings for its wind-ups, and the grab's QTE: press the keys shown, in
-- order, before the bar runs out (a wrong key starts over; the boxes can be
-- tapped too). Plain white text with a dark stroke, square.
-- His moves use the Mandela set's own visuals (RaidBoss).
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudConfig = require(ReplicatedStorage:WaitForChild("HudConfig"))
local RaidConfig = require(ReplicatedStorage:WaitForChild("RaidConfig"))
local UIScale = require(script.Parent:WaitForChild("UIScale"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild(RaidConfig.RemoteName)

local BAR_WIDTH = 520
local BAR_SHOW_EXTRA = 40 -- studs past its arena radius the bar still shows
local BANNER_HOLD = 3
local FADE_TIME = 0.4
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "RaidEffects"
effectsFolder.Parent = workspace

local gui = Instance.new("ScreenGui")
gui.Name = "RaidHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")
local root = UIScale.Root(gui)

local function label(parent, size, font, textSize)
	local text = Instance.new("TextLabel")
	text.Size = size
	text.BackgroundTransparency = 1
	text.Font = font
	text.TextSize = textSize
	text.TextColor3 = WHITE
	text.TextStrokeColor3 = BLACK
	text.TextStrokeTransparency = 0.3
	text.Parent = parent
	return text
end

-- the boss bar
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 70)
bar.Size = UDim2.fromOffset(BAR_WIDTH, 52)
bar.BackgroundTransparency = 1
bar.Visible = false
bar.Parent = root
local bossName = label(bar, UDim2.new(1, 0, 0, 24), HudConfig.Style.TitleFont, 24)
bossName.TextXAlignment = Enum.TextXAlignment.Left
local bossLevel = label(bar, UDim2.new(1, 0, 0, 24), HudConfig.Style.TitleFont, 20)
bossLevel.TextXAlignment = Enum.TextXAlignment.Right
local back = Instance.new("Frame")
back.Position = UDim2.fromOffset(0, 28)
back.Size = UDim2.new(1, 0, 0, 10)
back.BackgroundColor3 = BLACK
back.BackgroundTransparency = 0.45
back.BorderSizePixel = 0
back.Parent = bar
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(1, 1)
fill.BorderSizePixel = 0
fill.Parent = back
local shieldFill = Instance.new("Frame")
shieldFill.Size = UDim2.fromScale(0, 1)
shieldFill.BackgroundColor3 = WHITE
shieldFill.BorderSizePixel = 0
shieldFill.Parent = back
local edge = Instance.new("UIStroke")
edge.Color = WHITE
edge.Transparency = HudConfig.Style.EdgeTransparency
edge.Parent = back
local phaseLabel = label(bar, UDim2.new(1, 0, 0, 16), HudConfig.Style.LabelFont, 15)
phaseLabel.Position = UDim2.fromOffset(0, 40)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
local stateLabel = label(bar, UDim2.new(1, 0, 0, 16), HudConfig.Style.LabelFont, 15)
stateLabel.Position = UDim2.fromOffset(0, 40)
stateLabel.TextXAlignment = Enum.TextXAlignment.Right

local function nearestBoss()
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not myRoot then
		return nil
	end
	for _, model in ipairs(CollectionService:GetTagged(RaidConfig.Tag)) do
		local boss = RaidConfig.Get(model:GetAttribute("BossKey"))
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local bossRoot = humanoid and humanoid.RootPart
		if boss and bossRoot and humanoid.Health > 0 and (bossRoot.Position - myRoot.Position).Magnitude <= boss.arenaRadius + BAR_SHOW_EXTRA then
			return model, boss, humanoid
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local model, boss, humanoid = nearestBoss()
	bar.Visible = model ~= nil
	if not model then
		return
	end
	local phaseIndex = model:GetAttribute("Phase") or 1
	local phase = boss.phases[phaseIndex]
	bossName.Text = string.upper(boss.name) .. "  ·  " .. boss.title
	bossLevel.Text = "LV. " .. boss.level
	fill.BackgroundColor3 = RaidConfig.Color(model:GetAttribute("Overcharged") and boss.overchargeColor or boss.color)
	fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
	local shield, shieldMax = model:GetAttribute("Shield"), model:GetAttribute("ShieldMax")
	shieldFill.Size = UDim2.fromScale(shield and shieldMax and math.clamp(shield / shieldMax, 0, 1) or 0, 1)
	phaseLabel.Text = string.upper(phase.name)
	if shield then
		stateLabel.Text = "BREAK HIS SHIELD"
	elseif (model:GetAttribute("StaggeredUntil") or 0) > workspace:GetServerTimeNow() then
		stateLabel.Text = "STAGGERED"
	else
		stateLabel.Text = ""
	end
end)

-- banners
local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.3)
banner.Size = UDim2.fromOffset(700, 70)
banner.BackgroundTransparency = 1
banner.Parent = root
local bannerTitle = label(banner, UDim2.new(1, 0, 0, 44), HudConfig.Style.TitleFont, 44)
local bannerSub = label(banner, UDim2.new(1, 0, 0, 20), HudConfig.Style.LabelFont, 18)
bannerSub.Position = UDim2.fromOffset(0, 48)
for _, text in ipairs({ bannerTitle, bannerSub }) do
	text.TextTransparency = 1
	text.TextStrokeTransparency = 1
end

local shown = 0
local function showBanner(title, subtitle, hold)
	shown += 1
	local mine = shown
	bannerTitle.Text = title
	bannerSub.Text = subtitle or ""
	for _, text in ipairs({ bannerTitle, bannerSub }) do
		TweenService:Create(text, TweenInfo.new(FADE_TIME), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	end
	task.delay(FADE_TIME + (hold or BANNER_HOLD), function()
		if shown ~= mine then
			return
		end
		for _, text in ipairs({ bannerTitle, bannerSub }) do
			TweenService:Create(text, TweenInfo.new(FADE_TIME), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- placeholder parts
local function effectPart(shape, color, size, cframe, life)
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = effectsFolder
	Debris:AddItem(part, life)
	return part
end

-- a ground marking: its outline shows at once and it fills in over the wind-up
local function groundWarning(shape, cframe, size, time, color)
	local lift = CFrame.new(0, 0.15, 0)
	if shape == "circle" then
		local flatDisc = cframe * lift * CFrame.Angles(0, 0, math.rad(90))
		local outline = effectPart(Enum.PartType.Cylinder, color, Vector3.new(0.1, size * 2, size * 2), flatDisc, time + 0.1)
		outline.Transparency = 0.8
		local inner = effectPart(Enum.PartType.Cylinder, color, Vector3.new(0.12, 0.1, 0.1), flatDisc, time + 0.1)
		inner.Transparency = 0.55
		TweenService:Create(inner, TweenInfo.new(time, Enum.EasingStyle.Linear), { Size = Vector3.new(0.12, size * 2, size * 2) }):Play()
	else
		local length, width = size.Z, size.X
		local outline = effectPart(Enum.PartType.Block, color, Vector3.new(width, 0.1, length), cframe * lift * CFrame.new(0, 0, -length / 2), time + 0.1)
		outline.Transparency = 0.8
		local inner = effectPart(Enum.PartType.Block, color, Vector3.new(width, 0.12, 0.1), cframe * lift, time + 0.1)
		inner.Transparency = 0.55
		TweenService:Create(inner, TweenInfo.new(time, Enum.EasingStyle.Linear), {
			Size = Vector3.new(width, 0.12, length),
			CFrame = cframe * lift * CFrame.new(0, 0, -length / 2),
		}):Play()
	end
end

-- the QTE
local qte = Instance.new("Frame")
qte.AnchorPoint = Vector2.new(0.5, 0.5)
qte.Position = UDim2.fromScale(0.5, 0.62)
qte.Size = UDim2.fromOffset(360, 100)
qte.BackgroundTransparency = 1
qte.Visible = false
qte.Parent = root
local qteTitle = label(qte, UDim2.new(1, 0, 0, 24), HudConfig.Style.TitleFont, 24)
qteTitle.Text = "BREAK FREE"
local keyRow = Instance.new("Frame")
keyRow.Position = UDim2.fromOffset(0, 30)
keyRow.Size = UDim2.new(1, 0, 0, 50)
keyRow.BackgroundTransparency = 1
keyRow.Parent = qte
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = keyRow
local timer = Instance.new("Frame")
timer.Position = UDim2.fromOffset(0, 90)
timer.Size = UDim2.new(1, 0, 0, 4)
timer.BackgroundColor3 = WHITE
timer.BorderSizePixel = 0
timer.Parent = qte

local qteKeys, qteBoxes, qteProgress = nil, {}, 0
local qteRun = 0

local function paintQte()
	for i, box in ipairs(qteBoxes) do
		local done, current = i <= qteProgress, i == qteProgress + 1
		box.BackgroundColor3 = current and WHITE or BLACK
		box.BackgroundTransparency = done and 0.85 or current and 0 or 0.45
		box.TextColor3 = current and BLACK or WHITE
		box.TextTransparency = done and 0.6 or 0
	end
end

local function send(key)
	if qteKeys then
		remote:FireServer("Qte", key)
	end
end

local function endQte()
	qteRun += 1
	qteKeys = nil
	qte.Visible = false
	for _, box in ipairs(qteBoxes) do
		box:Destroy()
	end
	qteBoxes = {}
end

local function startQte(keys, time)
	endQte()
	local run = qteRun
	qteKeys, qteProgress = keys, 0
	for i, key in ipairs(keys) do
		local box = Instance.new("TextButton")
		box.LayoutOrder = i
		box.Size = UDim2.fromOffset(50, 50)
		box.BorderSizePixel = 0
		box.AutoButtonColor = false
		box.Font = HudConfig.Style.TitleFont
		box.TextSize = 28
		box.Text = key
		local stroke = Instance.new("UIStroke")
		stroke.Color = WHITE
		stroke.Transparency = 0.4
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = box
		box.Activated:Connect(function()
			send(key)
		end)
		box.Parent = keyRow
		qteBoxes[i] = box
	end
	paintQte()
	timer.Size = UDim2.new(1, 0, 0, 4)
	TweenService:Create(timer, TweenInfo.new(time, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 4) }):Play()
	qte.Visible = true
	-- in case the server's end never arrives
	task.delay(time + 1, function()
		if qteRun == run then
			endQte()
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not qteKeys or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local name = input.KeyCode.Name
	if table.find(RaidConfig.QteKeys, name) then
		send(name)
	end
end)

local events = {}

function events.Warning(key, seconds)
	local boss = RaidConfig.Get(key)
	if boss then
		showBanner(string.upper(boss.name) .. " APPROACHES", "He appears at his arena in " .. seconds .. " seconds", 5)
	end
end

function events.Spawned(key)
	local boss = RaidConfig.Get(key)
	if boss then
		showBanner(string.upper(boss.name), boss.title .. "  ·  LV. " .. boss.level, 4)
	end
end

function events.Phase(key, index)
	local boss = RaidConfig.Get(key)
	if boss and boss.phases[index] then
		showBanner(string.upper(boss.phases[index].name), boss.name)
	end
end

function events.Grabbed(name, who)
	if who ~= player then
		showBanner(string.upper(name) .. " IS CAUGHT", "Hit him hard to set them free", 2)
	end
end

function events.Freed(name)
	showBanner("BROKE FREE", name .. " got loose. He's open!", 2)
end

function events.Defeated(key, top)
	local boss = RaidConfig.Get(key)
	if not boss then
		return
	end
	local names = {}
	for i, entry in ipairs(top) do
		table.insert(names, i .. ". " .. entry.name .. " (" .. entry.damage .. ")")
	end
	showBanner(string.upper(boss.name) .. " DEFEATED", table.concat(names, "   "), 6)
end

function events.Left(key)
	local boss = RaidConfig.Get(key)
	if boss then
		showBanner(string.upper(boss.name) .. " IS GONE", "", 3)
	end
end

function events.Warn(shape, cframe, size, time, color)
	groundWarning(shape, cframe, size, time, color)
end

-- the dome (its glass is SkillEffects' Rewrite, Mandela's ultimate)
function events.Dome()
	showBanner("OVERCOME THE POSSIBILITY", "Break his shield before the dome closes", 3)
end

function events.DomeEnd(broken)
	if broken then
		showBanner("POSSIBILITY BROKEN", "He's staggered!", 2)
	end
end

function events.Qte(keys, time)
	startQte(keys, time)
end

function events.QteProgress(progress)
	qteProgress = progress
	paintQte()
end

-- (breaking free shows as "Freed" for everyone)
function events.QteEnd()
	endQte()
end

remote.OnClientEvent:Connect(function(kind, ...)
	local handler = events[kind]
	if handler then
		handler(...)
	end
end)
