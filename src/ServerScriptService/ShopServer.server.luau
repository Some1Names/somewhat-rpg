-- Server side of the shop: a purchase only goes through for a real item,
-- with the buyer standing next to a shopkeeper (a model tagged "Shop") that
-- runs the item's shop, and PlayerStats checks the yen and that it isn't
-- already owned. Starter items and coming-soon placeholders aren't sold. A service
-- (like Reset Stats) is only paid for when it actually does something.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local StatConfig = require(ReplicatedStorage:WaitForChild("StatConfig"))
local buyItem = ReplicatedStorage:WaitForChild("BuyItem")

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
	if item.comingSoon then
		return false, item.name .. " isn't out yet"
	end
	if item.starter then
		return false, "Everyone starts with " .. item.name
	end
	if not nearShop(player.Character, ShopConfig.ShopOf(item)) then
		return false, "Too far from the shopkeeper"
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
