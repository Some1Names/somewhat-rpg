-- Hit feedback for any character that loses health: a floating damage
-- number, a short red flash and a small burst of sparks. Critical hits get a
-- bigger gold number and more sparks.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local LIFETIME = 0.8 -- seconds a number stays on screen
local RISE_STUDS = 3
local START_HEIGHT = 3 -- studs above the head, clear of the OverheadHealth boxes
local SPREAD_STUDS = 2 -- random sideways offset so quick hits don't overlap
local TEXT_COLOR = Color3.fromRGB(255, 90, 60)
local OUTLINE_COLOR = Color3.fromRGB(40, 0, 0)
local CRIT_TEXT_COLOR = Color3.fromRGB(255, 205, 60)
local CRIT_OUTLINE_COLOR = Color3.fromRGB(60, 30, 0)
local CRIT_SIZE = 1.5 -- times the normal number size
local CRIT_SPARK_COUNT = 18
-- the server marks a critical just before its damage, so a mark seen this
-- recently belongs to the health drop that follows
local CRIT_WINDOW = 0.1

local FLASH_COLOR = Color3.fromRGB(255, 40, 40)
local FLASH_TIME = 0.2
local SPARK_COUNT = 8
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function formatAmount(amount)
	local rounded = math.round(amount)
	if math.abs(amount - rounded) < 0.05 then
		return tostring(rounded)
	end
	return string.format("%.1f", amount)
end

local function showNumber(anchor, amount, critical)
	local scale = critical and CRIT_SIZE or 1
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumber"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.ResetOnSpawn = false
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(120 * scale, 48 * scale)
	billboard.StudsOffset = Vector3.new((math.random() - 0.5) * SPREAD_STUDS, START_HEIGHT, 0)

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = formatAmount(amount) .. (critical and "!" or "")
	label.TextColor3 = critical and CRIT_TEXT_COLOR or TEXT_COLOR
	label.TextScaled = true
	label.Parent = billboard

	local outline = Instance.new("UIStroke")
	outline.Color = critical and CRIT_OUTLINE_COLOR or OUTLINE_COLOR
	outline.Thickness = 2
	outline.Parent = label

	billboard.Parent = playerGui

	TweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1, 1),
	}):Play()
	TweenService:Create(billboard, TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = billboard.StudsOffset + Vector3.new(0, RISE_STUDS, 0),
	}):Play()
	local fade = TweenInfo.new(LIFETIME / 2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, LIFETIME / 2)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(outline, fade, { Transparency = 1 }):Play()
	Debris:AddItem(billboard, LIFETIME)
end

local function flash(character)
	local highlight = Instance.new("Highlight")
	highlight.Name = "HitFlash"
	highlight.FillColor = FLASH_COLOR
	highlight.FillTransparency = 0.25
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = character
	TweenService:Create(highlight, TweenInfo.new(FLASH_TIME), { FillTransparency = 1 }):Play()
	Debris:AddItem(highlight, FLASH_TIME)
end

local function sparks(root, count)
	local attachment = Instance.new("Attachment")
	attachment.Name = "HitSparks"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARK_TEXTURE
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 160), Color3.fromRGB(255, 80, 40))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.25, 0.45)
	emitter.Speed = NumberRange.new(12, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = attachment
	attachment.Parent = root
	emitter:Emit(count)
	Debris:AddItem(attachment, 1)
end

local function onHit(humanoid, amount, critical)
	local character = humanoid.Parent
	if not character then
		return
	end
	local root = humanoid.RootPart
	local head = character:FindFirstChild("Head") or root
	if head then
		showNumber(head, amount, critical)
	end
	flash(character)
	if root then
		sparks(root, critical and CRIT_SPARK_COUNT or SPARK_COUNT)
	end
end

local function track(humanoid)
	local lastHealth = humanoid.Health
	local critMarkedAt = -math.huge
	humanoid:GetAttributeChangedSignal("CriticalHitAt"):Connect(function()
		critMarkedAt = os.clock()
	end)
	humanoid.HealthChanged:Connect(function(health)
		-- the killing hit can briefly replicate below zero
		health = math.max(health, 0)
		local lost = lastHealth - health
		lastHealth = health
		if lost >= 0.05 then
			onHit(humanoid, lost, os.clock() - critMarkedAt < CRIT_WINDOW)
		end
	end)
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("Humanoid") then
		track(descendant)
	end
end
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Humanoid") then
		track(descendant)
	end
end)
