-- Where new powers come from besides the Power Dealer's yen shop (ShopServer):
--  * the gacha: an NPC (a model tagged "PowerGacha") rolls a briefcase for
--    PowerConfig.Gacha.price yen, once per cooldown per player, with pity;
--    the RollGacha remote asks, the server decides everything and returns
--    ok, message, the power's name.
--  * map drops: every PowerConfig.Drop.interval seconds a briefcase appears at
--    a random part tagged "BriefcaseSpawn" (none placed = no drops), one at a
--    time, gone after PowerConfig.Drop.lifetime seconds; the kill feed says so.
--  * Robux: a lifetime copy of a power is a Developer Product
--    (PowerConfig.RobuxProducts). ProcessReceipt grants it once the player's
--    data is loaded and saved, else tries again later; the BuyLifetime remote
--    is the dealer asking to prompt the purchase.
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local Powers = require(script.Parent:WaitForChild("Powers"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))

local RANGE_TOLERANCE = 4 -- studs, for movement while a request travels
local rng = Random.new()

local function remote(className, name)
	local found = ReplicatedStorage:FindFirstChild(name)
	if found then
		return found
	end
	found = Instance.new(className)
	found.Name = name
	found.Parent = ReplicatedStorage
	return found
end

local rollGacha = remote("RemoteFunction", "RollGacha")
local buyLifetime = remote("RemoteEvent", "BuyLifetime")
local killFeed = ReplicatedStorage:WaitForChild("KillFeed")

-- the powers available to rolls and drops, by tier
local function available()
	local byTier = {}
	for setName, set in pairs(SkillSetConfig.Sets) do
		if set.kind == "power" then
			byTier[set.tier] = byTier[set.tier] or {}
			table.insert(byTier[set.tier], setName)
		end
	end
	for _, list in pairs(byTier) do
		table.sort(list)
	end
	return byTier
end

local function near(character, tag, range)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, npc in ipairs(CollectionService:GetTagged(tag)) do
		if npc:IsDescendantOf(workspace) and (npc:GetPivot().Position - root.Position).Magnitude <= range + RANGE_TOLERANCE then
			return true
		end
	end
	return false
end

-- the gacha -------------------------------------------------------------------

rollGacha.OnServerInvoke = function(player)
	local gacha = PowerConfig.Gacha
	local readyAt = player:GetAttribute("GachaReadyAt")
	local pity = player:GetAttribute("GachaPity")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not readyAt or not pity or not player:GetAttribute("Yen") then
		return false, "Still loading"
	end
	if not humanoid or humanoid.Health <= 0 or not player:FindFirstChildOfClass("Backpack") then
		return false, "Not now"
	end
	if not near(player.Character, gacha.tag, gacha.range) then
		return false, "Too far from the gacha"
	end
	if os.time() < readyAt then
		return false, "Not ready yet"
	end
	if not PlayerStats.SpendYen(player, gacha.price) then
		return false, string.format("You need ¥%d more", gacha.price - player:GetAttribute("Yen"))
	end
	local pool = available()
	local tier = PowerConfig.roll(function()
		return rng:NextNumber()
	end, pity, pool)
	local setName = tier and PowerConfig.pick(function()
		return rng:NextNumber()
	end, pool[tier])
	if not setName then
		PlayerStats.AddYen(player, gacha.price)
		return false, "Nothing to roll"
	end
	Powers.GiveBriefcase(player, setName)
	player:SetAttribute("GachaPity", PowerConfig.nextPity(pity, tier))
	player:SetAttribute("GachaReadyAt", os.time() + gacha.cooldown)
	task.spawn(PlayerStats.SaveNow, player) -- the cooldown and pity stick even if they leave
	return true, "You got a " .. Powers.DisplayName(setName) .. " briefcase", setName
end

-- map drops -------------------------------------------------------------------------

local currentDrop

local function dropOne()
	if currentDrop and currentDrop.Parent then
		return -- one at a time
	end
	local spots = {}
	for _, part in ipairs(CollectionService:GetTagged(PowerConfig.Drop.tag)) do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			table.insert(spots, part)
		end
	end
	if #spots == 0 then
		return
	end
	local pool = available()
	local tier = PowerConfig.roll(function()
		return rng:NextNumber()
	end, 0, pool)
	local setName = tier and PowerConfig.pick(function()
		return rng:NextNumber()
	end, pool[tier])
	if not setName then
		return
	end
	local spot = spots[rng:NextInteger(1, #spots)]
	currentDrop = Powers.DropPickup(setName, spot.Position + Vector3.new(0, spot.Size.Y / 2, 0), nil, PowerConfig.Drop.lifetime)
	killFeed:FireAllClients("Briefcase", "A briefcase has appeared somewhere...")
end

task.spawn(function()
	while true do
		task.wait(PowerConfig.Drop.interval)
		dropOne()
	end
end)

-- Robux -------------------------------------------------------------------------------

local setOfProduct = {}
for setName, productId in pairs(PowerConfig.RobuxProducts) do
	setOfProduct[productId] = setName
end

-- the dealer asking to prompt a lifetime purchase
buyLifetime.OnServerEvent:Connect(function(player, setName)
	local productId = typeof(setName) == "string" and PowerConfig.RobuxProducts[setName]
	if not productId then
		return
	end
	if Powers.IsLifetime(player, setName) then
		return -- already yours for life
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end)

-- Grants the lifetime power and saves it before saying the purchase went
-- through. A player whose data hasn't loaded, or who has left, or a save that
-- fails, gets "not yet" and Roblox asks again (on their next join too), so a
-- purchase is never lost; granting is idempotent, so asking twice never gives two.
MarketplaceService.ProcessReceipt = function(receipt)
	local setName = setOfProduct[receipt.ProductId]
	if not setName then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not player.Parent or not PlayerStats.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not Powers.GrantLifetime(player, setName) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Studio never writes saves (PlayerStats), so there the grant stands as is
	if not PlayerStats.SaveNow(player) and not RunService:IsStudio() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
