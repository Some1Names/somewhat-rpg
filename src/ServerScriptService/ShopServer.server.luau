-- Server side of the shop: a purchase only goes through for a real item,
-- with the buyer standing next to a shopkeeper (a model tagged "Shop") that
-- runs the item's shop, and PlayerStats checks the yen and that it isn't
-- already owned. Starter items and coming-soon placeholders aren't sold. A service
-- (like Reset Stats) is only paid for when it actually does something. A
-- briefcase (the Power Dealer's powers) is paid for in yen and handed over
-- as a Tool (Powers); the dealer also buys carried briefcases back (SellItem).
-- A limited consumable (a `stack` item) is paid for and handed over as a Tool
-- (Consumables: into the Backpack's storage, never straight onto the hotbar), up to the carry cap; a lifetime one is bought once like any
-- owned item and Consumables gives its Tool. Nothing is bought or sold while the
-- buyer is in combat (CombatRules). A faction rank can take a share off every yen price (Factions).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatRules = require(ReplicatedStorage:WaitForChild("CombatRules"))
local Consumables = require(script.Parent:WaitForChild("Consumables"))
local Factions = require(script.Parent:WaitForChild("Factions"))
local FactionConfig = require(ReplicatedStorage:WaitForChild("FactionConfig"))
local ConsumableConfig = require(ReplicatedStorage:WaitForChild("ConsumableConfig"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local Powers = require(script.Parent:WaitForChild("Powers"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local SkillSetConfig = require(ReplicatedStorage:WaitForChild("SkillSetConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local buyItem = ReplicatedStorage:WaitForChild("BuyItem")
local sellItem = ReplicatedStorage:FindFirstChild("SellItem")
if not sellItem then
	sellItem = Instance.new("RemoteFunction")
	sellItem.Name = "SellItem"
	sellItem.Parent = ReplicatedStorage
end

-- what each service does; returns whether it went through and what to say
local services = {}

function services.ResetStats(player)
	local spent = 0
	for _, stat in ipairs(StatConfig.Stats) do
		spent += player:GetAttribute(stat.key) or 0
	end
	if spent == 0 then
		return false, "No stat points to refund"
	end
	if not PlayerStats.ResetStats(player) then
		return false, "Still loading"
	end
	return true, string.format("Refunded %d stat point%s", spent, spent == 1 and "" or "s")
end

-- a little more than the menu's range, for movement while the request travels
local RANGE_TOLERANCE = 4

local function nearShop(character, shopId)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, shop in ipairs(CollectionService:GetTagged(ShopConfig.Tag)) do
		if shop:IsA("Model") and shop:IsDescendantOf(workspace) and ShopConfig.ShopIdOf(shop) == shopId then
			if (shop:GetPivot().Position - root.Position).Magnitude <= ShopConfig.Range + RANGE_TOLERANCE then
				return true
			end
		end
	end
	return false
end

buyItem.OnServerInvoke = function(player, id)
	local item = typeof(id) == "string" and ShopConfig.Get(id)
	if not item then
		return false, "That isn't for sale"
	end
	if not CombatRules.OutOfCombat(player.Character and player.Character:GetAttribute(CombatRules.PvPAttribute), workspace:GetServerTimeNow()) then
		return false, "You can't shop while in combat"
	end
	if item.comingSoon then
		return false, item.name .. " isn't out yet"
	end
	if item.starter then
		return false, "Everyone starts with " .. item.name
	end
	if not nearShop(player.Character, ShopConfig.ShopOf(item)) then
		return false, "Too far from the shopkeeper"
	end
	-- a faction rank's discount comes off every yen price
	local discount = Factions.ShopDiscount(player)
	if discount > 0 and item.price then
		item = table.clone(item)
		item.price = FactionConfig.DiscountedPrice(item.price, discount)
	end
	if item.briefcase then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or not player:FindFirstChildOfClass("Backpack") then
			return false, "Not now"
		end
		if not PlayerStats.SpendYen(player, item.price) then
			local yen = player:GetAttribute("Yen")
			return false, yen and string.format("You need ¥%d more", item.price - yen) or "Still loading"
		end
		if not Powers.GiveBriefcase(player, item.set) then
			PlayerStats.AddYen(player, item.price)
			return false, "Your Backpack storage is full"
		end
		print(string.format("[Shop] %s bought %s for ¥%d", player.Name, item.name, item.price))
		return true, "Bought " .. item.name .. " Briefcase (in your Backpack)"
	end
	if item.stack then
		-- a limited consumable: bought again and again, up to the carry cap
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or not player:FindFirstChildOfClass("Backpack") then
			return false, "Not now"
		end
		if not ConsumableConfig.CanCarryMore(Consumables.Carried(player, item.consumable)) then
			return false, "You can't carry more " .. item.name
		end
		if not PlayerStats.SpendYen(player, item.price) then
			local yen = player:GetAttribute("Yen")
			return false, yen and string.format("You need ¥%d more", item.price - yen) or "Still loading"
		end
		-- it goes into the Backpack's storage; the player equips it onto a hotbar slot from there
		if not Consumables.Grant(player, item.consumable) then
			PlayerStats.AddYen(player, item.price)
			return false, "Your Backpack storage is full"
		end
		print(string.format("[Shop] %s bought %s for ¥%d", player.Name, item.name, item.price))
		return true, "Bought " .. item.name .. " (in your Backpack)"
	end
	if item.service then
		local run = services[item.id]
		local yen = player:GetAttribute("Yen")
		if not run then
			return false, "That isn't for sale"
		end
		if not yen then
			return false, "Still loading"
		end
		if yen < item.price then
			return false, string.format("You need ¥%d more", item.price - yen)
		end
		local ok, message = run(player)
		if ok and item.price > 0 then
			PlayerStats.SpendYen(player, item.price)
		end
		return ok, message
	end
	local ok, message = PlayerStats.Buy(player, item)
	if ok then
		print(string.format("[Shop] %s bought %s for ¥%d", player.Name, item.name, item.price))
	end
	return ok, message
end

-- sells a carried briefcase back to the Power Dealer: the briefcase is
-- destroyed first, then the yen paid, so one can't be sold twice
sellItem.OnServerInvoke = function(player, setName)
	local set = typeof(setName) == "string" and SkillSetConfig.Sets[setName]
	if not set or set.kind ~= "power" then
		return false, "That can't be sold"
	end
	if not CombatRules.OutOfCombat(player.Character and player.Character:GetAttribute(CombatRules.PvPAttribute), workspace:GetServerTimeNow()) then
		return false, "You can't shop while in combat"
	end
	if not nearShop(player.Character, "Powers") then
		return false, "Too far from the Power Dealer"
	end
	if not player:GetAttribute("Yen") then
		return false, "Still loading"
	end
	if not Powers.TakeBriefcase(player, setName) then
		return false, "You aren't carrying that briefcase"
	end
	local price = PowerConfig.sellPrice(setName, set.tier)
	PlayerStats.AddYen(player, price)
	print(string.format("[Shop] %s sold a %s briefcase for ¥%d", player.Name, setName, price))
	return true, string.format("Sold for ¥%d", price)
end
