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
-- once the set exists. A `briefcase` item is a power sold by the Power Dealer:
-- it can be bought again and again (the briefcase goes to the buyer's
-- hotbar, see Powers), nothing is owned or saved, and its price comes from
-- PowerConfig by the set's tier.
local ConsumableConfig = require(script.Parent:WaitForChild("ConsumableConfig"))
local PowerConfig = require(script.Parent:WaitForChild("PowerConfig"))
local SkillSetConfig = require(script.Parent:WaitForChild("SkillSetConfig"))

local ShopConfig = {}

ShopConfig.Range = 14 -- studs from a shopkeeper that buying works
ShopConfig.Tag = "Shop" -- CollectionService tag on shopkeeper models
ShopConfig.ShopAttribute = "ShopId" -- on a shopkeeper model: which shop it runs
ShopConfig.DefaultShop = "General"

-- the shops: the menu's title and accent colour
ShopConfig.Shops = {
	General = { title = "SHOP", color = Color3.fromRGB(255, 205, 60) },
	Powers = { title = "POWERS", color = Color3.fromRGB(175, 90, 255) },
	Supplies = { title = "SUPPLIES", color = Color3.fromRGB(60, 224, 230) },
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

	-- the Power Dealer: every power, made or still to come (briefcase prices by tier, PowerConfig)
	{
		id = "Mandela",
		name = "Mandela",
		shop = "Powers",
		set = "Mandela",
		briefcase = true,
		description = "S-tier power. Axe Boomerang, Event Horizon, Tornado. Passive: Misremembered.",
	},
	{
		id = "IridescentRequiem",
		name = "Iridescent Requiem",
		shop = "Powers",
		set = "IridescentRequiem",
		briefcase = true,
		description = "Ayato Yoji's light. Flight, Lightstep, Prism Form, Solar Lance. Passive: Luminance.",
	},
	{
		id = "Photoshop",
		name = "Photoshop",
		shop = "Powers",
		set = "Photoshop",
		briefcase = true,
		description = "Nozomi's power. Snapshot, Photo Teleport, Desaturate, Iris Horizon, Kaleidoscope. G: Undo. T: photo gallery.",
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
		name = "Deus Ex Machina",
		shop = "Powers",
		set = "Aido",
		briefcase = true,
		description = "Furukiwa Aido's power. Fuse, Catastrophe, Collapse, Total Destruction, Ground Zero, Final Cut. G: Chain Reaction. Passive: Half-Life. Not for sale: only the gacha and drops give it.",
	},
	{
		id = "Eventide",
		name = "Eventide",
		shop = "Powers",
		set = "Eventide",
		briefcase = true,
		description = "Daemon's power. Not made yet: the briefcase can only be sold.",
	},
	{
		id = "Mnemosyne",
		name = "Mnemosyne",
		shop = "Powers",
		set = "Mnemosyne",
		briefcase = true,
		description = "S-tier power. Not made yet: the briefcase can only be sold.",
	},
	{
		id = "Afterimage",
		name = "Afterimage",
		shop = "Powers",
		set = "Afterimage",
		briefcase = true,
		description = "A-tier power. Not made yet: the briefcase can only be sold.",
	},
	{
		id = "Blackfrost",
		name = "Blackfrost",
		shop = "Powers",
		set = "Blackfrost",
		briefcase = true,
		description = "A-tier power. Not made yet: the briefcase can only be sold.",
	},
	{
		id = "Kintsugi",
		name = "Kintsugi",
		shop = "Powers",
		set = "Kintsugi",
		briefcase = true,
		description = "B-tier power. Not made yet: the briefcase can only be sold.",
	},
}

-- the Supplies shopkeeper: every consumable (ConsumableConfig). A limited one
-- is a `stack` item: it can be bought again and again, the Tool goes to the
-- buyer's hotbar (Consumables) and nothing is owned or saved. A lifetime one
-- is owned for good like any other item and the server hands the Tool over.
for _, consumable in ipairs(ConsumableConfig.Items) do
	table.insert(ShopConfig.Items, {
		id = ConsumableConfig.ShopId(consumable),
		name = consumable.name,
		shop = "Supplies",
		price = consumable.price,
		consumable = consumable.key,
		uses = ConsumableConfig.UsesText(consumable),
		stack = consumable.kind == "limited",
		description = consumable.description,
	})
end

-- a briefcase item's yen price: its set's tier price (nil if the dealer doesn't sell it)
for _, item in ipairs(ShopConfig.Items) do
	if item.briefcase then
		local set = SkillSetConfig.Sets[item.set]
		item.price = set and PowerConfig.price(item.set, set.tier)
		if not item.price then
			item.comingSoon = true
		end
	end
end

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
	return not item.service and not item.starter and not item.comingSoon and not item.briefcase and not item.stack
end

return ShopConfig
