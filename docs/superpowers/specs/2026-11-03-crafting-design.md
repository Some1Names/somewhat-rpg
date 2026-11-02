# Crafting (3D printer) — design

Spec 1 of 2 for crafting. This one is the crafting engine, producing **gear pieces** and **talismans**.
Spec 2 (later) adds consumables as one more recipe output. A consumable system already exists
(`ConsumableConfig` / `Consumables`: hotbar Tools, shop-sold, Backpack storage), so spec 2 is only a new
`output.kind = "consumable"` that grants through it, not a new system.
Note: `TalismanConfig.OwnAll = true` today (every player owns every talisman), so talisman recipes do nothing
until that switch is turned off; the recipes are built and tested with `OwnAll = false`.
Depends on the equipment design (head/body gear, rolled pieces, `Gear.Grant`); talisman recipes work without it.

## Goal

Give materials a second use and make gear craftable: the player spends drop materials and yen at a
**3D printer** to start a timed print, and collects the result later. Gear is rolled; talismans are fixed.

## Decisions (from the owner)

- Outputs: gear (Head, Body) and talismans. Consumables are spec 2.
- Fixed recipes, rolled result (gear rolls rarity and affixes; a talisman is a fixed item).
- Station: a new object, the 3D printer (a Studio model tagged `Printer`).
- Timed jobs: a print finishes after a duration, even while offline; the player collects it at a printer.
- Some recipes are known from the start; the others must be learned (buy, blueprint drop, quest, faction rank).

## Data: `ReplicatedStorage/CraftConfig` (pure, Lune-tested)

- `Tag = "Printer"`, `Range` (studs), `Remote = "CraftAction"`, saved attributes `PrintJobs` and `RecipesKnown`,
  `MaxSaveLength`s.
- `JobSlotLevels = { 0, 20, 50 }` (level that opens job slot 1, 2, 3), like `TalismanConfig.SlotLevels`.
- `CancelRefund = 0.5` (share of materials returned; no yen).
- `Recipes`, in menu order. Each:
  - `id`, `name`, `tier` (Common..Essence, the material grade), `materials = { {material, amount}, ... }`, `yen`,
    `seconds` (print time), `output` (`{ kind = "gear", slot = "Head" | "Body" }` or `{ kind = "talisman", key }`).
  - `access = "known"` or `"learn"`. A `learn` recipe has `routes`: any of
    `{ kind = "buy", yen }`, `{ kind = "drop", blueprint }`, `{ kind = "quest", id }`, `{ kind = "faction", faction, rank }`.
    An empty `routes` means it is only given by a script (an event reward).
  - gear recipes: `rarityWeights` (the tier sets the range: Scrap-tier Common/Uncommon, Core up to Rare,
    Crystal up to Epic, Essence and boss-material recipes reach Legendary), optional `affix` (a boss material adds its themed affix),
    `maxLevel` (piece level = player level at print start, capped by this).
- Pure rules: `CanAfford`, `JobSlots(level)`, `NextSlotLevel`, `IsKnown(knownText, recipe)`, `Learn`, `Start`
  (returns the new jobs list or nil + why), `Cancel` (refund amounts), `IsReady(job, now)`, `Parse`/`Encode` of
  both saved texts, `RollRarity(weights, random)`. No Roblox types, so Lune can test them.

## Job state

`PrintJobs` is one saved text: `recipeId|seed|finishAt` per job (`finishAt` is a Unix time from the server clock,
so offline time counts). The result is **not rolled until collect**, from the saved `seed`, so rejoining cannot reroll it.

## Server

- `ServerScriptService/Crafting` (module): per-player checked actions: `Start`, `Collect`, `Cancel`, `Learn`.
- `ServerScriptService/CraftServer.server` makes the `CraftAction` RemoteFunction (by script) and routes calls;
  debounced per player. Every action checks the player is within `Range` of a model tagged `Printer`.
- `Start` is all-or-nothing: recipe known, in range, free job slot, materials and yen present (talisman not already
  owned), then the cost is taken and the job saved in one step.
- `Collect`: job must be ready. Gear: rolled from the seed and given with `Gear.Grant`; talisman: `Talismans.Grant`.
  - Gear bag full: the collect is refused ("bag full") and the job stays waiting. A paid craft is never auto-salvaged.
  - Talisman already owned by collect time (granted another way): materials refunded, job cleared.
- `Cancel`: only a running job; returns `CancelRefund` of the materials, no yen.
- `Learn(recipeId, route)`: idempotent. A known recipe is refused; a blueprint is consumed only on success.
  Routes: buy (yen taken), blueprint item (a `Mat_`-style counter, consumed), quest and faction (the server reads
  `Quests` / `FactionConfig` standing itself; the client is never trusted).
- Hooks in existing systems, kept small: a blueprint entry type in `DropConfig` (drop tables may name one), a
  `teaches` list on `QuestConfig` entries, a rank check against `FactionConfig`.

## Client

- `StarterPlayerScripts/PrinterMenu` (opened by a `ProximityPrompt` on the `Printer` model, through `Menus`):
  recipe list (locked recipes greyed with how to get them), your materials, active jobs with a countdown and
  Collect / Cancel buttons, and the learn options. Square UI in the shops' look, no `UICorner`.

## Not in this spec

- Consumables, drop tables for gear (dungeons), gear stats and the bag (equipment spec), real VFX (the owner's).

## Studio tasks for the owner

- The `Printer` model (tag `Printer`) and its print animation; blueprint orb visuals; an optional recipe-seller NPC.
- Prefabs and effects for the print, as always from imported packs.

## Testing

- Lune: `tests/CraftConfig.spec.luau` covers affordability, rarity weights per tier, job slots, job timing and
  readiness, cancel refunds, learn rules (including idempotence), and save text round trips.
- Studio smoke test: place a `Printer`, grant materials from the admin panel, override `seconds` to 5, run a print,
  collect, cancel, learn. The owner playtests the rest.

## Build order

Equipment spec first (gear and `Gear.Grant`). The engine and talisman recipes do not need it, so they can ship first.
