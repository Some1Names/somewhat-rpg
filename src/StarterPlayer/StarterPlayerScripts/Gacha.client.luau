-- The power gacha: the prompt on a model tagged "PowerGacha" opens this panel
-- (the free roll or its countdown, the price of extra rolls, your pity count,
-- the odds and ROLL).
-- ROLL asks the RollGacha remote (PowerSources decides everything); the reply
-- plays a reel: a strip of tier cards that rushes past and slows onto the
-- power you got, then names it. The reel only shows what the server already
-- decided. The briefcase reaches your inventory when the reel ends (the
-- ClaimGacha remote; the server hands it over anyway after a few seconds).
-- Closes when you walk away or another menu opens (Menus).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Menus = require(script.Parent:WaitForChild("Menus"))
local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local rollRemote = ReplicatedStorage:WaitForChild("RollGacha")
local claimRemote = ReplicatedStorage:WaitForChild("ClaimGacha")
local player = Players.LocalPlayer

local PANEL_WIDTH = 380
local PADDING = 14
local CELL_WIDTH = 84 -- one card of the reel
local CELL_GAP = 6
local REEL_HEIGHT = 96
local REEL_CELLS = 46 -- cards in a spin; the result sits near the end
local RESULT_CELL = 40
local NEAR_MISS_CHANCE = 0.6 -- how often the card before the result is a better tier
local BACKGROUND = Color3.fromRGB(20, 20, 28)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(165, 165, 180)
local ACCENT = Color3.fromRGB(175, 90, 255)
local DANGER = Color3.fromRGB(226, 75, 74)
local GOLD = Color3.fromRGB(255, 205, 60)

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
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function formatNumber(amount)
	local digits = tostring(math.floor(amount))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return grouped
end

local function tierColor(tier)
	local info = SkillSetConfig.Tiers[tier]
	return info and info.color or SkillSetConfig.NoTierColor
end

local gui = make("ScreenGui", {
	Name = "Gacha",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local panel = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = BACKGROUND,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
})
local panelStroke = make("UIStroke", { Parent = panel, Color = ACCENT, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
make("UIPadding", {
	Parent = panel,
	PaddingTop = UDim.new(0, PADDING),
	PaddingBottom = UDim.new(0, PADDING),
	PaddingLeft = UDim.new(0, PADDING),
	PaddingRight = UDim.new(0, PADDING),
})
make("UIListLayout", { Parent = panel, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })
Menus.Fit(panel)
-- a glow round the panel for the better tiers, behind it
local screenFlash = make("Frame", {
	Parent = gui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = TEXT,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 0,
})

local order = 0
local function section(height)
	order += 1
	return make("Frame", { Parent = panel, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1 })
end

-- header: title, your yen, close
local header = section(22)
label(header, { Text = "POWER GACHA", Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.fromScale(0.5, 1) })
local balance = label(header, {
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -30, 0, 0),
	Size = UDim2.new(0.5, -30, 1, 0),
})
-- Modal frees the mouse while the panel is open, even in shift lock
local closeButton = make("TextButton", {
	Parent = header,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "×",
	TextSize = 20,
	TextColor3 = MUTED,
	Modal = true,
})

-- the reel: a window with the cards sliding behind a marker in the middle
local reel = section(REEL_HEIGHT)
reel.BackgroundColor3 = Color3.new(0, 0, 0)
reel.BackgroundTransparency = 0.6
reel.ClipsDescendants = true
local strip = make("Frame", {
	Parent = reel,
	Size = UDim2.new(0, REEL_CELLS * (CELL_WIDTH + CELL_GAP), 1, 0),
	BackgroundTransparency = 1,
})
local marker = make("Frame", { -- the marker
	Parent = reel,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(0, 2, 1, 0),
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
	ZIndex = 5,
})
local reelFlash = make("Frame", {
	Parent = reel,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = TEXT,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 6,
})
local reelHint = label(reel, {
	Text = "Roll for a power briefcase",
	TextSize = 12,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 4,
})

local resultSection = section(22)
local resultLabel = label(resultSection, {
	Text = "",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
})

local infoLabel = label(section(74), {
	Text = "",
	TextSize = 12,
	TextColor3 = MUTED,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Size = UDim2.fromScale(1, 1),
})

local rollButton = make("TextButton", {
	Parent = section(36),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = ACCENT,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = TEXT,
	Text = "ROLL",
})
local status = label(section(14), { Text = "", TextSize = 11, TextColor3 = MUTED, Size = UDim2.fromScale(1, 1) })

local spinning = false
local openAt -- the gacha NPC whose panel is open

local function setStatus(text, failed)
	status.Text = text
	status.TextColor3 = failed and DANGER or GOLD
end

local function clock(seconds)
	seconds = math.max(math.floor(seconds), 0)
	return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

local function refresh()
	local gacha = PowerConfig.Gacha
	local yen = player:GetAttribute("Yen") or 0
	local readyAt = player:GetAttribute("GachaReadyAt") or 0
	local pity = player:GetAttribute("GachaPity") or 0
	local wait = readyAt - os.time()
	local free = wait <= 0
	balance.Text = "¥" .. formatNumber(yen)
	local lines = {}
	table.insert(lines, string.format("One free roll every %d hours  ·  extra rolls ¥%s", gacha.cooldown // 3600, formatNumber(gacha.price)))
	table.insert(lines, free and "Your free roll is ready" or ("Free roll in " .. clock(wait)))
	table.insert(lines, string.format("Pity %d / %d  ·  S guaranteed at %d rolls without one", pity, gacha.pity, gacha.pity))
	local odds = {}
	for _, tier in ipairs(PowerConfig.Tiers) do
		table.insert(odds, string.format("%s %d%%", tier, PowerConfig.TierWeight[tier]))
	end
	table.insert(lines, "Odds  " .. table.concat(odds, "  ·  "))
	infoLabel.Text = table.concat(lines, "\n")
	local ready = (free or yen >= gacha.price) and not spinning
	if spinning then
		rollButton.Text = "..."
	elseif free then
		rollButton.Text = "FREE ROLL"
	else
		rollButton.Text = "ROLL  ¥" .. formatNumber(gacha.price)
	end
	rollButton.AutoButtonColor = ready
	rollButton.BackgroundTransparency = ready and 0 or 0.6
end

-- fills the reel with random tier cards (the result's among them, and more often than not a
-- better tier right before it: a near miss), then plays the spin: it speeds up, rushes past
-- and slows to a stop on the result.
-- The marker and the panel's outline take the colour of whichever card is under the marker.
local function spin(setName)
	local resultTier = SkillSetConfig.Sets[setName].tier
	local random = Random.new()
	-- the other cards follow the real odds, so the reel looks like the gacha
	local totalWeight = 0
	for _, tier in ipairs(PowerConfig.Tiers) do
		totalWeight += PowerConfig.TierWeight[tier]
	end
	local function randomTier()
		local target = random:NextNumber() * totalWeight
		for _, tier in ipairs(PowerConfig.Tiers) do
			target -= PowerConfig.TierWeight[tier]
			if target < 0 then
				return tier
			end
		end
		return PowerConfig.Tiers[#PowerConfig.Tiers]
	end
	local tiers = {}
	for index = 1, REEL_CELLS do
		tiers[index] = index == RESULT_CELL and resultTier or randomTier()
	end
	local better = {}
	for _, tier in ipairs(PowerConfig.Tiers) do
		if table.find(PowerConfig.Tiers, tier) < table.find(PowerConfig.Tiers, resultTier) then
			table.insert(better, tier)
		end
	end
	if #better > 0 and random:NextNumber() < NEAR_MISS_CHANCE then
		tiers[RESULT_CELL - 1] = better[random:NextInteger(1, #better)]
	end
	for _, child in ipairs(strip:GetChildren()) do
		child:Destroy()
	end
	for index = 1, REEL_CELLS do
		local color = tierColor(tiers[index])
		local cell = make("Frame", {
			Parent = strip,
			Position = UDim2.fromOffset((index - 1) * (CELL_WIDTH + CELL_GAP) + CELL_GAP, 8),
			Size = UDim2.new(0, CELL_WIDTH, 1, -16),
			BackgroundColor3 = BACKGROUND,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
		})
		make("UIStroke", { Parent = cell, Color = color, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		label(cell, {
			Text = tiers[index],
			Font = Enum.Font.GothamBlack,
			TextSize = 34,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
		make("Frame", {
			Parent = cell,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		})
	end
	reelHint.Visible = false
	resultLabel.Text = ""
	local window = reel.AbsoluteSize.X
	-- the strip's offset that puts a card's centre under the marker
	local function positionFor(index)
		return -((index - 1) * (CELL_WIDTH + CELL_GAP) + CELL_GAP + CELL_WIDTH / 2 - window / 2)
	end
	-- the marker and the outline follow the card under the marker, ticking as each passes
	local lastIndex
	local follow = RunService.Heartbeat:Connect(function()
		local centre = window / 2 - strip.Position.X.Offset
		local index = math.clamp(math.floor((centre - CELL_GAP) / (CELL_WIDTH + CELL_GAP)) + 1, 1, REEL_CELLS)
		if index ~= lastIndex then
			lastIndex = index
			local color = tierColor(tiers[index])
			marker.BackgroundColor3 = color
			panelStroke.Color = color
			marker.Size = UDim2.new(0, 6, 1, 0)
			TweenService:Create(marker, TweenInfo.new(0.1), { Size = UDim2.new(0, 2, 1, 0) }):Play()
		end
	end)
	local function slide(position, time, style, direction)
		local tween = TweenService:Create(strip, TweenInfo.new(time, style, direction), { Position = UDim2.fromOffset(position, 0) })
		tween:Play()
		tween.Completed:Wait()
	end
	strip.Position = UDim2.fromOffset(0, 0)
	slide(positionFor(14), 1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In) -- picks up speed
	-- rushes, then slows to a stop a few pixels off the card's centre so it never lands dead centre
	local jitter = Random.new():NextInteger(-CELL_WIDTH // 4, CELL_WIDTH // 4)
	slide(positionFor(RESULT_CELL) + jitter, 5.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	follow:Disconnect()
	marker.Size = UDim2.new(0, 2, 1, 0)
end

-- squares thrown out from the result card, in its tier colour
local function burst(card, color, count)
	local x = card.AbsolutePosition.X + card.AbsoluteSize.X / 2 - resultSection.AbsolutePosition.X
	local y = -(10 + REEL_HEIGHT / 2) -- the reel's middle, above the result line
	local random = Random.new()
	for _ = 1, count do
		local size = random:NextInteger(5, 10)
		local angle = random:NextNumber() * math.pi * 2
		local distance = random:NextInteger(50, 150)
		local piece = make("Frame", {
			Parent = resultSection,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = random:NextInteger(0, 90),
			ZIndex = 8,
		})
		local tween = TweenService:Create(piece, TweenInfo.new(0.7 + random:NextNumber() * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(x + math.cos(angle) * distance, y + math.sin(angle) * distance),
			BackgroundTransparency = 1,
			Rotation = piece.Rotation + random:NextInteger(-180, 180),
		})
		tween.Completed:Once(function()
			piece:Destroy()
		end)
		tween:Play()
	end
end

-- the panel jolts for a moment
local function shake(strength)
	local base = panel.Position
	local random = Random.new()
	for step = 1, 14 do
		local fade = 1 - step / 14
		panel.Position = base + UDim2.fromOffset(random:NextInteger(-strength, strength) * fade, random:NextInteger(-strength, strength) * fade)
		task.wait(0.03)
	end
	panel.Position = base
end

-- the result: a flash, a pop of the name in its tier colour, and for the better tiers a
-- harder flash, a jolt and more squares
local function reveal(setName)
	local tier = SkillSetConfig.Sets[setName].tier
	local color = tierColor(tier)
	local rank = table.find(PowerConfig.Tiers, tier) -- 1 is the best
	local name = string.gsub(setName, "(%l)(%u)", "%1 %2")
	marker.BackgroundColor3 = color
	panelStroke.Color = color
	resultLabel.TextColor3 = color
	resultLabel.Text = string.format("%s-tier  ·  %s", tier, name)
	resultLabel.TextTransparency = 1
	resultLabel.TextSize = 10
	TweenService:Create(resultLabel, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	TweenService:Create(resultLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 18 }):Play()
	local card = strip:GetChildren()[RESULT_CELL]
	if card then
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = 3
			stroke.Transparency = 0
		end
		card.BackgroundColor3 = color
		TweenService:Create(card, TweenInfo.new(0.8), { BackgroundColor3 = BACKGROUND }):Play()
		burst(card, color, ({ 28, 16, 8, 4 })[rank] or 4)
	end
	task.spawn(function()
		local flashes = ({ 3, 2, 1, 1 })[rank] or 1
		for _ = 1, flashes do
			reelFlash.BackgroundColor3 = color
			reelFlash.BackgroundTransparency = 0.35
			TweenService:Create(reelFlash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			if rank <= 2 then
				screenFlash.BackgroundColor3 = color
				screenFlash.BackgroundTransparency = rank == 1 and 0.6 or 0.8
				TweenService:Create(screenFlash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			end
			task.wait(0.25)
		end
	end)
	if rank <= 2 then
		task.spawn(shake, rank == 1 and 7 or 3)
	end
end

local function roll()
	if spinning then
		return
	end
	spinning = true
	setStatus("")
	refresh()
	local ok, success, message, setName = pcall(rollRemote.InvokeServer, rollRemote)
	if not ok then
		spinning = false
		setStatus("Couldn't reach the gacha", true)
		refresh()
		return
	end
	if not success or not SkillSetConfig.Sets[setName] then
		spinning = false
		setStatus(message or "Couldn't roll", true)
		refresh()
		return
	end
	spin(setName)
	claimRemote:FireServer() -- the reel is done: the briefcase goes in the hotbar
	reveal(setName)
	setStatus(message)
	spinning = false
	refresh()
end
rollButton.Activated:Connect(roll)

local function close()
	gui.Enabled = false
	openAt = nil
	Menus.Close("Gacha")
end
closeButton.Activated:Connect(close)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local npc = prompt:FindFirstAncestorOfClass("Model")
	if npc and CollectionService:HasTag(npc, PowerConfig.Gacha.tag) then
		openAt = npc
		panelStroke.Color = ACCENT
		marker.BackgroundColor3 = TEXT
		setStatus("")
		resultLabel.Text = ""
		reelHint.Visible = true
		for _, child in ipairs(strip:GetChildren()) do
			child:Destroy()
		end
		strip.Position = UDim2.new()
		refresh()
		Menus.Open("Gacha", close)
		gui.Enabled = true
	end
end)

-- keeps the countdown and your yen current, and closes when you walk away
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	if not openAt then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not openAt.Parent or (openAt:GetPivot().Position - root.Position).Magnitude > PowerConfig.Gacha.range then
		close()
		return
	end
	elapsed += dt
	if elapsed >= 0.5 then
		elapsed = 0
		refresh()
	end
end)
