-- What the shopkeepers sell, for yen. Shared by the ShopServer script (which
-- checks and charges) and the shop menu (which lists). Each shopkeeper runs
-- one of the Shops (its ShopId attribute; General when it has none) and an
-- item is sold in its `shop` (General when it has none). An item a player
-- owns is kept as the player attribute "Owns<id>" (1 once bought) and
-- saved; one with a `set` hands over that skill set (Loadout) once it's
-- owned. A `service` is something the shopkeeper does rather than sells:
-- nothing is owned and it can be bought again (ShopServer has what each one
-- does). A `starter` item is one everyone already has (shown as owned), and
-- a `comingSoon` one is a placeholder for a set not made yet: listed with
-- its `tier`, never sold. Give it a `set` and a price and drop `comingSoon`
-- once the set exists.
local ShopConfig = {}

ShopConfig.Range = 14 -- studs from a shopkeeper that buying works
ShopConfig.Tag = "Shop" -- CollectionService tag on shopkeeper models
ShopConfig.ShopAttribute = "ShopId" -- on a shopkeeper model: which shop it runs
ShopConfig.DefaultShop = "General"

-- the shops: the menu's title and accent colour
ShopConfig.Shops = {
	General = { title = "SHOP", color = Color3.fromRGB(255, 205, 60) },
	Powers = { title = "POWERS", color = Color3.fromRGB(175, 90, 255) },
}

-- in the order the menu lists them
ShopConfig.Items = {
	{
		id = "DoubleJump",
		name = "Double Jump",
		price = 500,
		description = "Jump again in midair while you have dodge charges. Each jump uses one and half a stamina box.",
	},
	{
		id = "Revolver",
		name = "Revolver",
		price = 1500,
		set = "Revolver",
		description = "B-tier weapon. Left click shoots, right click aims, R reloads. Moves: Fan the Hammer, Dead Eye.",
	},
	{
		id = "ResetStats",
		name = "Reset Stats",
		price = 0,
		service = true,
		description = "Refund every stat point you've spent, to put them somewhere else.",
	},

	-- the Power Dealer: every power, made or still to come (prices to be decided)
	{
		id = "Mandela",
		name = "Mandela",
		shop = "Powers",
		set = "Mandela",
		price = 0,
		starter = true,
		description = "Everyone's first power. Axe Boomerang, Event Horizon, Tornado. Passive: Misremembered.",
	},
	{
		id = "IridescentRequiem",
		name = "Iridescent Requiem",
		shop = "Powers",
		set = "IridescentRequiem",
		price = 25000,
		description = "Ayato Yoji's light. Flight, Lightstep, Prism Form, Solar Lance. Passive: Luminance.",
	},
	{
		id = "Photoshop",
		name = "Photoshop",
		shop = "Powers",
		tier = "S",
		comingSoon = true,
		description = "Nozomi's power. ???",
	},
	{
		id = "HimaruPower",
		name = "Himaru — ???",
		shop = "Powers",
		tier = "S",
		comingSoon = true,
		description = "Himaru's power. ???",
	},
	{
		id = "AidoPower",
		name = "Aido — ???",
		shop = "Powers",
		tier = "S",
		comingSoon = true,
		description = "Aido's power. ???",
	},
	{
		id = "Daemon",
		name = "Daemon",
		shop = "Powers",
		tier = "A",
		comingSoon = true,
		description = "Daemon's power. ???",
	},
	{
		id = "Kintsugi",
		name = "Kintsugi",
		shop = "Powers",
		tier = "B",
		comingSoon = true,
		description = "???",
	},
}

function ShopConfig.Get(id)
	for _, item in ipairs(ShopConfig.Items) do
		if item.id == id then
			return item
		end
	end
	return nil
end

function ShopConfig.OwnedAttribute(id)
	return "Owns" .. id
end

-- which shop sells the item
function ShopConfig.ShopOf(item)
	return item.shop or ShopConfig.DefaultShop
end

-- which shop a shopkeeper model runs
function ShopConfig.ShopIdOf(model)
	return model:GetAttribute(ShopConfig.ShopAttribute) or ShopConfig.DefaultShop
end

-- whether buying the item gives the player something to own (and save)
function ShopConfig.Ownable(item)
	return not item.service and not item.starter and not item.comingSoon
end

return ShopConfig
