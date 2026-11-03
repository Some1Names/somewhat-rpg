# Equipment (head and body gear) — design

Rolled defensive/stat gear worn in two slots, **Head** and **Body**. Crafting and dungeons already
call `Gear.Grant`; this spec builds the system behind it.
Related: `2026-11-03-crafting-design.md`, `2026-11-03-dungeon-design.md`.

## Goal

Give players stat gear that drops, crafts and upgrades their build: rolled pieces with a rarity, a base stat
and affixes, kept in a bag, worn one per slot, shown on the character, and read by the existing combat/stat code.

## Decisions (from the owner)

- Role: defense and stat gear (not cosmetic, not set-themed).
- Rolled items with rarity (each piece is its own instance), base + affixes.
- Never lost on death. Bag cap 30; extras can be salvaged into materials.
- Sources: the dungeon and crafting systems (this spec only provides the entry point); enemy/raid drops may use `GrantOrSalvage`.
- Backpack UI: materials leave the left column and become a middle-column category; the left column gets Head/Body gear slots.

## Data: `ReplicatedStorage/GearConfig` (pure, Lune-tested)

- Fields: `BagAttribute = "GearBag"`, `WornAttribute = "GearWorn"`, `Remote = "GearAction"`, `BagLimit = 30`,
  `MaxSaveLength` (raised in `PlayerStats`, about 1.5 KB for 30 pieces + 2 worn), `Slots = { "Head", "Body" }`
  (data, so Legs/Hands can be added later), `Rarities` in order Common, Uncommon, Rare, Epic, Legendary
  (colour, affix count 0/1/2/3/3, value range multiplier, salvage yield), `Bases` (several per slot and level band,
  each with `id`, `name`, `model` name), `Affixes` (the talisman effect names `regen`, `damageReduction`,
  `damageDealt`, `yenPct`, `healOnKill`, `maxHealthPct`, plus `stat:<Name>` points for the six stats; each with a
  min/max per rarity), base stat formulas (Head: max HP; Body: damage reduction; scaled by level and rarity).
- Saved piece: `id|slot|rarity|level|baseId|affix=value,...` (rolled values are stored, not seeds, so a rebalance
  never changes owned pieces). Bag and worn are two texts; worn holds at most one piece per slot.
- Pure rules:
  - `Roll(slot, rarity, level, seed, affixHint?): Piece` is deterministic per seed, picks the base, the base stat and the
    affixes (no duplicate affix on one piece; a themed `affixHint` is always included).
  - `ParseBag(text)`, `ParseWorn(text)`, `Encode*`; junk or unknown entries drop out safely.
  - `Total(wornText, effect)` and `HealthMultiplier`, `IncomingMultiplier`, `OutgoingMultiplier`, `YenMultiplier`,
    `StatBonus(wornText, statName)`, using the same clamps as `TalismanConfig` (max HP floor 0.25×, damage taken floor 0.25×)
    so gear and talismans stack.
  - `Equip(bag, worn, id, playerLevel)`: needs the piece's level ≤ yours; swaps in place, so it never needs a free bag
    slot. `Unequip(bag, worn, slot)`: needs a free bag slot. `Salvage(bag, id)`: returns the new bag and the material yield.
  - `CanAdd(bag)` against `BagLimit`.

## Server

- `ServerScriptService/Gear` (module): `Gear.Grant(player, slot, rarity, level, seed, affixHint) -> ok, why`
  (the contract `Crafting` and the dungeon chest already use). A full bag returns `false, "Gear bag is full"` and
  never auto-salvages. `Gear.GrantOrSalvage(...)` salvages into materials when the bag is full, for enemy/raid drops.
  Also `Equip`, `Unequip`, `Salvage` (checked, saved, and calling `PlayerStats.RefreshHealth` afterwards).
- `ServerScriptService/GearServer.server`: the `GearAction` RemoteFunction (`"equip" | "unequip" | "salvage", id`),
  argument types checked, a per-player busy flag, data-loaded check.
- Effects are read where talismans are read: `Damage` (dealt and taken), `PlayerStats.RefreshHealth` (max HP), `Health`
  (regen), `Chests` (yen), plus a heal-on-kill listener beside the Talismans one. Gear stat points raise damage and HP
  scaling only; they do **not** count toward `requires` or talent thresholds (`BuildCheck`, `BuildRules`).
- `PlayerStats`: register `GearBag` and `GearWorn` in `TEXT_DEFAULTS` and `TEXT_LENGTHS`.
- On the character: when worn gear changes or the character spawns, `Gear` attaches an `Accessory` cloned from
  `ReplicatedStorage.GearModels/<base id>` (a missing model shows nothing). A model's `HidesHair` attribute hides the
  cosmetic hair/accessory painted by `CharacterLook`.

## Backpack UI (`Inventory.client.luau`)

- Left column (EQUIPPED): remove the MATERIALS block (`MATERIALS_TOP`, `materialList`, `showMaterials`, `MATERIAL_ROW`).
  Add a **GEAR** row under TALISMANS: two square slots (Head, Body) in the talisman-box style, empty or worn, the edge in the
  piece's rarity colour.
- Middle column: two new categories with a tab and an ALL-tab section each.
  - `material` (tab MATERIALS): one square card per material you **hold** (name in the tier colour, amount), entry
    `category = "material"`, `key = "material:<key>"`, ordered by `DropConfig.Sorted()`. Unheld materials are not shown.
  - `gear` (tab GEAR): one card per bag piece, edged in the rarity colour, `key = "gear:<id>"`.
- Right column (INFO): a material shows tier, amount held and a **USED IN** list built from `ReforgeConfig.LevelCosts`
  and the `CraftConfig` recipes that name it; no buttons. A gear piece shows its base, level, rarity and stats, and uses
  the existing button row for Equip, Unequip and Salvage (the `GearAction` remote).
- `refresh()`: the tab-selection rule that special-cases `item` and `talisman` becomes "a tab picks its first card when the
  selection isn't in it". `GearBag` and `GearWorn` join the `watched` attributes (`Mat_*` already are).
- Risk: the tab row grows from 6 to 8 tabs and may not fit the middle column; verify at three screen sizes in Studio;
  fallback is shorter labels or a scrolling tab row.

## Not in this spec

- Drop tables and recipes for gear (dungeons and crafting), more slots, set bonuses, reforging gear, gear visuals beyond
  attaching a model (the owner's), PvP-specific scaling of gear effects.

## Studio tasks for the owner

- `ReplicatedStorage.GearModels`: an Accessory per base id, fitted to R15 attachments (optional `HidesHair`).
- Final icons/VFX for rarity and equip, as always from imported packs.

## Testing

- Lune: `tests/GearConfig.spec.luau` covers deterministic rolls, affix counts and value ranges per rarity, no duplicate
  affixes, the hint always included, save round trips, junk text, totals and clamps, equip/swap/unequip/salvage rules, the
  level requirement and the bag cap.
- Studio smoke test: an admin "grant random gear" action, then equip, swap, salvage, rejoin to check saving, a damage and
  HP check, and the Backpack at three screen sizes (tabs, gear row, material cards). The owner playtests the rest.

## Build order

After or alongside dungeons/crafting; both already call `Gear.Grant` and degrade without it. Once built, gear recipes and
the dungeon chest's gear roll switch on automatically.
