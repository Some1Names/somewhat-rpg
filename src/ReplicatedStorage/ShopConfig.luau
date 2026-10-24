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

-- what the shopkeeper says, by moment: greet (menu opens), buy (a purchase went through), poor (can't
-- afford it), full (can't carry more), fail (the server said no), sell (a briefcase bought back).
-- "{item}" becomes the item's name. A shop with no lines of its own uses General's.
ShopConfig.Dialogue = {
	General = {
		greet = { "Welcome! Take a look around.", "Oh, a customer. Browse all you like.", "Come in, come in. Prices are fair, I promise." },
		buy = { "{item}? Good pick. Pleasure doing business.", "Sold! Don't lose it.", "Thank you kindly." },
		poor = { "Hm, you're a little short on yen.", "Come back when your pockets are heavier.", "I don't do credit, sorry." },
		full = { "You can't carry any more of that.", "Your hands are full. Use some first." },
		fail = { "That's not going to work.", "Sorry, I can't do that right now." },
		sell = { "I'll take that off your hands.", "A fair price. Here you go." },
	},
	Powers = {
		greet = { "So you want power. Everything here has a price.", "Looking for something dangerous? Good, I sell it.", "Mind the briefcases. They bite." },
		buy = { "{item}. Try not to get yourself killed.", "A fine choice. Use it well.", "It's yours now. Don't make me regret it." },
		poor = { "Power isn't free. Come back with more yen.", "Not enough. Power costs, kid.", "Your wallet can't hold that power." },
		full = { "You can't hold any more. Make some room.", "Your storage is full. Sort yourself out first." },
		fail = { "No deal.", "That's not something I can hand over." },
		sell = { "I'll buy it back. A little less than you paid, of course.", "Another one returned. Business is business." },
	},
	Supplies = {
		greet = { "Stocking up? Smart.", "Supplies for every fight. What do you need?", "Hey there. Don't go out unprepared." },
		buy = { "{item}, coming right up.", "Good call. That one saves lives.", "Here you go. Use it wisely." },
		poor = { "Not enough yen for that one.", "Short on cash? Come back after a few fights." },
		full = { "You're carrying all you can already.", "No room left in your bag for that." },
		fail = { "I can't sell you that right now.", "Something's off. Try again in a moment." },
		sell = { "I'll take it.", "Thanks. It'll go back on the shelf." },
	},
}

-- a random line for a moment in a shop's dialogue ("" if there is none)
function ShopConfig.Line(shopId, kind, itemName)
	local shop = ShopConfig.Dialogue[shopId] or ShopConfig.Dialogue[ShopConfig.DefaultShop]
	local lines = shop[kind] or ShopConfig.Dialogue[ShopConfig.DefaultShop][kind]
	if not lines or #lines == 0 then
		return ""
	end
	return (string.gsub(lines[math.random(#lines)], "{item}", function()
		return itemName or "That"
	end))
end

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
		id = "Katana",
		name = "Katana",
		price = 1200,
		set = "Katana",
		description = "B-tier melee weapon. Left click swings a four-hit combo. Needs 5 Strength.",
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
