-- Unit tests for ReplicatedStorage.ConsumableConfig's pure rules (spending a
-- limited item's charges, lifetime items never spending, the cooldown, the
-- carry cap, Overclock's multipliers, heals). Run with Lune: tests/run.sh.
local ConsumableConfig = require("../src/ReplicatedStorage/ConsumableConfig")

local failures = 0
local function check(name, condition)
	if condition then
		print("ok    " .. name)
	else
		failures += 1
		print("FAIL  " .. name)
	end
end

local syringe = ConsumableConfig.Get("NanoSyringe")
local suture = ConsumableConfig.Get("RiftSuture")

check("items are found by key", syringe ~= nil and suture ~= nil and ConsumableConfig.Get("Nope") == nil)
check("limited item spends one charge", ConsumableConfig.Spend(syringe, 5) == 4)
check("limited item is spent at 0", ConsumableConfig.Spent(syringe, 0) and not ConsumableConfig.Spent(syringe, 1))
check("lifetime item never spends", ConsumableConfig.Spend(suture, 1) == nil and not ConsumableConfig.Spent(suture, 0))
check("limited label shows the charges", ConsumableConfig.Label(syringe, 3) == "Nano-Syringe (3/5)")
check("lifetime label is the plain name", ConsumableConfig.Label(suture, 1) == "Rift Suture")

check("never used means ready", ConsumableConfig.CooldownLeft(nil, 100) == 0)
check("cooldown counts down", ConsumableConfig.CooldownLeft(110, 100) == 10)
check("cooldown over means ready", ConsumableConfig.CooldownLeft(100, 100) == 0 and ConsumableConfig.CooldownLeft(90, 100) == 0)

check("can carry up to the limit", ConsumableConfig.CanCarryMore(2) and not ConsumableConfig.CanCarryMore(3))

check("overclock boosts while running", ConsumableConfig.OutgoingMultiplier(120, 100) == 1.25)
check("overclock boost ends", ConsumableConfig.OutgoingMultiplier(120, 120) == 1 and ConsumableConfig.OutgoingMultiplier(nil, 100) == 1)
check("no extra damage taken during the boost", ConsumableConfig.IncomingMultiplier(120, 130, 100) == 1)
check("crash makes you take more", ConsumableConfig.IncomingMultiplier(120, 130, 125) == 1.15)
check("crash ends", ConsumableConfig.IncomingMultiplier(120, 130, 130) == 1 and ConsumableConfig.IncomingMultiplier(nil, nil, 5) == 1)

check("heal is a fraction of max HP", ConsumableConfig.HealAmount(0.3, 100, 10) == 30)
check("heal never overfills", ConsumableConfig.HealAmount(0.3, 100, 90) == 10)
check("heal at full HP is 0", ConsumableConfig.HealAmount(0.3, 100, 100) == 0)

local stored = ConsumableConfig.ParseStorage("NanoSyringe:5,RiftSuture:-,NanoSyringe:2")
check("storage parses limited and lifetime", #stored == 3 and stored[1].uses == 5 and stored[2].key == "RiftSuture" and stored[2].uses == nil and stored[3].uses == 2)
check("storage round trips", ConsumableConfig.SerializeStorage(stored) == "NanoSyringe:5,RiftSuture:-,NanoSyringe:2")
local junk = ConsumableConfig.ParseStorage("Nope:3,NanoSyringe:9,NanoSyringe:0,NanoSyringe:x,RiftSuture:4,RiftSuture:-,RiftSuture:-,PurgeAmpoule:3")
check("storage drops bad entries and a repeated lifetime item", #junk == 2 and junk[1].key == "RiftSuture" and junk[2].key == "PurgeAmpoule" and junk[2].uses == 3)
check("storage ignores bad text", #ConsumableConfig.ParseStorage(nil) == 0 and #ConsumableConfig.ParseStorage(string.rep("NanoSyringe:5,", 100)) == 0)
local many = {}
for _ = 1, 40 do
	table.insert(many, "PurgeAmpoule:3")
end
check("storage is capped", #ConsumableConfig.ParseStorage(table.concat(many, ",")) <= ConsumableConfig.StorageLimit)
check("stored count per item", ConsumableConfig.StoredCount(stored, "NanoSyringe") == 2 and ConsumableConfig.StoredCount(stored, "PurgeAmpoule") == 0)
check("hotbar room", ConsumableConfig.CanEquip(5) and not ConsumableConfig.CanEquip(6))
check("storage room", ConsumableConfig.CanStore(29) and not ConsumableConfig.CanStore(30))

local keys, ok = {}, true
for _, item in ipairs(ConsumableConfig.Items) do
	ok = ok and not keys[item.key] and item.cooldown > 0 and item.price > 0 and (item.kind == "limited" and item.maxUses > 0 or item.kind == "lifetime")
	keys[item.key] = true
end
check("every item has a unique key, a cooldown, a price and a valid kind", ok)

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("all ConsumableConfig checks passed")
