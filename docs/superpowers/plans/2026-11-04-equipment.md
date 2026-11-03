# Equipment (head and body gear) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rolled Head and Body gear: a bag, two worn slots, stats read by combat, a model on the character, and a Backpack UI where materials become a category and gear gets slots.

**Architecture:** `GearConfig` (pure, Lune-tested) holds every rule; `Gear` (server module) applies them to the player's saved `GearBag`/`GearWorn` texts; `GearServer` is the `GearAction` remote; effects are read where talismans are read; the Backpack gets a Gear row and two new categories. Same shape as `TalismanConfig`/`Talismans`.

**Tech Stack:** Luau (Roblox), Lune for tests (`tests/run.sh`), Studio for the smoke test.

**Spec:** `docs/superpowers/specs/2026-11-04-equipment-design.md`

## Global Constraints

- UI is square: no `UICorner` in the Backpack additions.
- `Gear.Grant(player, slot, rarity, level, seed, affixHint) -> ok, why` is the contract `Crafting.Collect` already calls; a full bag returns `false, "Gear bag is full"` and never auto-salvages.
- Gear and talismans stack with the same clamps (`TalismanConfig.HealthMultiplier`: floor 0.25; `IncomingMultiplier`: clamp 0.25..1).
- Gear stat points raise damage and HP scaling only; never count toward `requires` or talent thresholds (`BuildCheck`, `BuildRules`).
- Saved texts are registered in `PlayerStats` `TEXT_DEFAULTS`/`TEXT_LENGTHS`: `GearBag`, `GearWorn`.
- Pure modules take no Roblox types. Match surrounding code: comment density, tabs, naming. No final VFX/art (the owner's).
- Studio is the source of truth: new scripts are applied to Studio by a local session; list instances needed (`ReplicatedStorage.GearModels`).

## Review Focus

- A tampered or corrupt `GearBag`/`GearWorn` text (junk entries, unknown slot/rarity, duplicate ids, two pieces in one slot) must parse to a safe state, not error.
- Equip must swap in place (never lose a piece when the bag is full); Unequip with a full bag must refuse, not drop the piece.
- A worn piece whose level is above the player's must not be equippable, and a level drop must not break the character.
- Double-clicking Equip/Salvage must not duplicate or lose a piece (busy flag, id-based, not index-based).
- Max HP must stay correct across equip, unequip, respawn and rejoin (health is refilled only on a fresh character, as `applyHealth` already does).

---

### Task 1: GearConfig (pure rules)

**Files:**
- Create: `src/ReplicatedStorage/GearConfig.luau`
- Test: `tests/GearConfig.spec.luau`

**Interfaces:**
- Produces (on `GearConfig`):
  - fields: `BagAttribute = "GearBag"`, `WornAttribute = "GearWorn"`, `Remote = "GearAction"`, `BagLimit = 30`, `MaxSaveLength = 2400`, `Slots = { "Head", "Body" }`, `Rarities` (ordered list of `{ key, name, color = {r,g,b}, affixes, valueScale, salvage = {{material, amount}} }`), `Bases` (list of `{ id, name, slot, minLevel, model }`), `Affixes` (list of `{ id, effect, min, max }` per rarity range; `effect` is a talisman effect name or `"stat:<Name>"`).
  - `Piece = { id: string, slot: string, rarity: string, level: number, base: string, affixes: { {id: string, value: number} } }`.
  - `Roll(slot: string, rarity: string, level: number, seed: number, affixHint: string?, id: string): Piece` deterministic per seed (small LCG, no Roblox `Random`); base stat is itself an affix entry (`maxHealthPct` for Head, `damageReduction` for Body) scaled by level and rarity; no duplicate affix; `affixHint` always included.
  - `ParseBag(text: any): { Piece }`, `EncodeBag(list): string`, `ParseWorn(text: any): { [slot]: Piece }`, `EncodeWorn(map): string` (piece format `id|slot|rarity|level|base|affix=value,affix=value`; drops junk, unknown slot/rarity, duplicate ids, and a second piece in one slot).
  - `Total(wornText: any, effect: string): number`, `HealthMultiplier`, `IncomingMultiplier`, `OutgoingMultiplier`, `YenMultiplier`, `StatBonus(wornText: any, statName: string): number` (same clamps as `TalismanConfig`).
  - `Equip(bagText, wornText, id: string, playerLevel: number): (bagText?, wornText?, why?)` (level check; swaps with the worn piece of that slot in place), `Unequip(bagText, wornText, slot: string): (bagText?, wornText?, why?)` ("Gear bag is full" when no room), `Salvage(bagText, id): (bagText?, yield?, why?)`, `CanAdd(bagText): boolean`, `Add(bagText, piece): (string?, string?)`, `NewId(bagText, wornText): string`.

- [ ] **Step 1: Write the failing test** `tests/GearConfig.spec.luau` in the `tests/TalismanConfig.spec.luau` style (`check`/`failures`, `os.exit(failures)`). Assertions:
  - every rarity has a colour, an affix count and a salvage yield; every base has an id, a slot in `Slots` and a model name; ids unique;
  - `Roll("Head", "Epic", 35, 7, nil, "g1")` equals itself for the same seed and differs for another seed (over ten seeds at least one differs); affix count equals the rarity's; no duplicate affix ids; values within the affix's range scaled by rarity; `affixHint = "regen"` always appears; the Head piece has a `maxHealthPct` affix and the Body a `damageReduction` one;
  - bag round trip: `ParseBag(EncodeBag(list))` equals the list; `ParseBag("junk|x;;g1|Nope|Epic|1|b|;")` is `{}`; duplicate ids and a bad slot/rarity drop; `ParseWorn` keeps only the first piece per slot;
  - `Total`, `HealthMultiplier` floor 0.25 with a huge negative `maxHealthPct`, `IncomingMultiplier` stays within 0.25..1, `StatBonus("Vitality")` sums `stat:Vitality` affixes;
  - `Equip` with `playerLevel` below the piece's level returns nil + "Level too low"; with a worn Head already, the old Head returns to the bag at the same bag size (full 30-piece bag still succeeds); `Unequip` with a full bag returns nil + "Gear bag is full"; `Salvage` removes the piece and returns the rarity's yield; unknown id returns nil;
  - `CanAdd` false at 30; `NewId` never collides with a bag or worn id.
- [ ] **Step 2: Run** `lune run tests/GearConfig.spec.luau`. Expected: FAIL (module missing).
- [ ] **Step 3: Implement** `src/ReplicatedStorage/GearConfig.luau` per Interfaces. Starter data (placeholders to rename and balance): rarities Common/Uncommon/Rare/Epic/Legendary with affix counts 0/1/2/3/3, `valueScale` 1.0/1.2/1.5/1.9/2.4, salvage Scrap/Scrap+Core/Core/Crystal/Essence; Head bases `Rough Helm`(1), `Reinforced Helm`(20), `Prism Helm`(60); Body bases `Rough Plate`(1), `Reinforced Plate`(20), `Prism Plate`(60); base stat Head `maxHealthPct` 0.02 + 0.0015 × level, Body `damageReduction` 0.01 + 0.0006 × level, both × `valueScale`; affixes `regen` 0.5–2, `damageReduction` 0.01–0.04, `damageDealt` 0.02–0.06, `yenPct` 0.05–0.15, `healOnKill` 0.005–0.015, `maxHealthPct` 0.02–0.06, `stat:<each of the six>` 1–3 points.
- [ ] **Step 4: Run** the spec, then `bash tests/run.sh`. Expected: all `ok`, exit code 0.
- [ ] **Step 5: Commit** `git add src/ReplicatedStorage/GearConfig.luau tests/GearConfig.spec.luau` and `git commit -m "Equipment: GearConfig rolls, saves and rules"`.

---

### Task 2: Gear module, GearServer and saving

**Files:**
- Create: `src/ServerScriptService/Gear.luau`, `src/ServerScriptService/GearServer.server.luau`
- Modify: `src/ServerScriptService/PlayerStats.luau` (`TEXT_DEFAULTS` ~line 61, `TEXT_LENGTHS` ~line 89)

**Interfaces:**
- Consumes: Task 1's `GearConfig`; `PlayerStats.RefreshHealth(player)`; `DropConfig.Fit`/`Attribute`.
- Produces: `Gear.Grant(player, slot, rarity, level, seed, affixHint): (boolean, string?)`, `Gear.GrantOrSalvage(player, slot, rarity, level, seed, affixHint): (boolean, string?)`, `Gear.Equip(player, id)`, `Gear.Unequip(player, slot)`, `Gear.Salvage(player, id)` each `(boolean, string?)`; the `GearAction` RemoteFunction: `InvokeServer("equip"|"unequip"|"salvage", idOrSlot) -> ok, why`.

- [ ] **Step 1: Register the saved texts** in `PlayerStats`: `GearBag = ""`, `GearWorn = ""` in `TEXT_DEFAULTS` (comments naming `GearConfig`, `Gear`) and `GearBag = GearConfig.MaxSaveLength`, `GearWorn = GearConfig.MaxSaveLength` in `TEXT_LENGTHS` (require `GearConfig` beside the other config requires).
- [ ] **Step 2: Implement `Gear.Grant`**: check data loaded (both attributes non-nil), `GearConfig.CanAdd`, roll with `GearConfig.Roll(..., GearConfig.NewId(bag, worn))`, `GearConfig.Add`, `SetAttribute(GearConfig.BagAttribute, text)`; return `false, "Gear bag is full"` when full. `GrantOrSalvage` salvages the rolled piece's yield into `Mat_` attributes (clamped with `DropConfig.Fit`) instead of failing.
- [ ] **Step 3: Implement `Equip`/`Unequip`/`Salvage`** calling the matching `GearConfig` function with the player's `Level` attribute, writing both attributes only on success, then `PlayerStats.RefreshHealth(player)` and the visual refresh (Task 4 hook `Gear.OnChanged`, a simple callback list).
- [ ] **Step 4: `GearServer.server.luau`** creates the `GearAction` RemoteFunction in `ReplicatedStorage` (by script, like `TalismanAction`), checks argument types, keeps a per-player busy flag so a second call during one returns `false, "Busy"`, and routes to `Gear`.
- [ ] **Step 5: Compile check** the three files with Lune's `luau.compile` (Lune path `C:\Users\Admin\tools\lune\lune.exe`). Expected: no errors. Then `bash tests/run.sh`.
- [ ] **Step 6: Commit** `git add src/ServerScriptService/Gear.luau src/ServerScriptService/GearServer.server.luau src/ServerScriptService/PlayerStats.luau` and `git commit -m "Equipment: Gear module, remote and saved texts"`.

---

### Task 3: Effects in combat and stats

**Files:**
- Modify: `src/ServerScriptService/Damage.luau` (lines ~83, ~194, ~214, ~219), `src/ServerScriptService/PlayerStats.luau` (`applyHealth`, ~line 163), `src/StarterPlayer/StarterCharacterScripts/Health.server.luau` (line ~31), `src/ServerScriptService/Chests.server.luau` (line ~60), `src/ServerScriptService/Gear.luau` (heal on kill)

**Interfaces:**
- Consumes: Task 1's `Total`, `HealthMultiplier`, `IncomingMultiplier`, `OutgoingMultiplier`, `YenMultiplier`, `StatBonus`; `Damage.OnKill`.
- Produces: nothing new for other tasks; gear changes now affect the numbers.

- [ ] **Step 1: Damage dealt/taken and kill yen**: multiply `OutgoingMultiplier` at the talisman line ~214 and `IncomingMultiplier` at ~219, and `YenMultiplier` at ~83, each reading `attacker/targetPlayer/killer:GetAttribute(GearConfig.WornAttribute)` (same shape as the talisman call beside it).
- [ ] **Step 2: Stat bonus in damage**: at line ~192 use `(attacker:GetAttribute(options.stat) or 0) + GearConfig.StatBonus(worn, options.stat)` in the `StatConfig.DamageMultiplier` call; do not touch `BuildRules`/`BuildCheck`.
- [ ] **Step 3: Max HP**: in `applyHealth`, use `vitality + GearConfig.StatBonus(worn, "Vitality")` for `StatConfig.MaxHealth`, and multiply by `GearConfig.HealthMultiplier(worn)`.
- [ ] **Step 4: Regen and chest yen**: add `GearConfig.Total(worn, "regen")` to the regen sum in `Health.server`; multiply the chest yen by `GearConfig.YenMultiplier(worn)` in `Chests`.
- [ ] **Step 5: Heal on kill**: in `Gear.luau` add a `Damage.OnKill` listener copying the `Talismans` one but reading `GearConfig.Total(worn, "healOnKill")`.
- [ ] **Step 6: Compile check** all touched files; run `bash tests/run.sh`. Expected: no errors, all specs pass.
- [ ] **Step 7: Commit** `git add` the touched files and `git commit -m "Equipment: gear effects in damage, HP, regen and yen"`.

---

### Task 4: Gear on the character

**Files:**
- Create: `src/ServerScriptService/GearVisuals.server.luau`

**Interfaces:**
- Consumes: `Gear.OnChanged(callback)` from Task 2, `GearConfig.ParseWorn`/`Bases`, `ReplicatedStorage.GearModels/<base id>` (Studio; may be missing).
- Produces: nothing used by other tasks.

- [ ] **Step 1: Implement** `GearVisuals.server.luau`: on `CharacterAdded` and on `Gear.OnChanged`, remove any previous `Accessory` tagged `GearVisual` from the character and `humanoid:AddAccessory` a clone of each worn piece's model (skip silently when the model is missing); attach through the model Handle's attachment as `CharacterLook`'s `place` does for hats; if a model has attribute `HidesHair`, set the cosmetic hair/accessory parts' `Transparency = 1` and restore when removed. Keep it small; do not edit `CharacterLook`.
- [ ] **Step 2: Compile check** the file. Expected: no errors.
- [ ] **Step 3: Commit** `git add src/ServerScriptService/GearVisuals.server.luau` and `git commit -m "Equipment: worn gear shows on the character"`.

---

### Task 5: Backpack UI

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Inventory.client.luau` (SECTIONS ~92, TABS ~99, left column ~231-290, `entries()` ~500, `showMaterials` ~1602, `refresh` ~1640, `watched` ~1740)

**Interfaces:**
- Consumes: `GearConfig`, the `GearAction` remote, `DropConfig`, `ReforgeConfig.LevelCosts`, `CraftConfig.Recipes`, the existing `makeCard`, `showDetails`, `detailRow`, `primaryAction`/`altAction` helpers.
- Produces: nothing used by other tasks.

- [ ] **Step 1: Remove the left MATERIALS block**: delete `MATERIAL_ROW`, `MATERIALS_TOP`, the MATERIALS label, `materialList`, `showMaterials` and its call in `refresh`. Verify nothing else references them (grep).
- [ ] **Step 2: GEAR row in the left column**: under the TALISMANS row add a "GEAR" label and two square slots (Head, Body) in the talisman-box style (`TALISMAN_BOX`), empty or worn, edge coloured by `GearConfig` rarity colour; clicking a worn slot selects that piece's card.
- [ ] **Step 3: New categories**: add `{ kind = "material", title = "MATERIALS" }` and `{ kind = "gear", title = "GEAR" }` to `SECTIONS` and matching `TABS` entries (shorter labels if needed). In `entries()` add one entry per held material (`kind = "material"`, `category = "material"`, `key = "material:"..key`, `rank = 9`, `order` from `DropConfig.Sorted()`) and one per bag piece (`kind = "gear"`, `key = "gear:"..id`, `equipped` when worn, `rank = 10`).
- [ ] **Step 4: Cards and details**: `makeCard` draws a material as a square card (name in the tier colour, amount) and a gear piece edged in its rarity colour; `showDetails` for a material shows tier, amount and a USED IN list built from `ReforgeConfig.LevelCosts` and `CraftConfig.Recipes` (no buttons); for a gear piece shows base, level, rarity, each stat, and sets `primaryAction` (Equip/Unequip) and `altAction` (Salvage, with the existing CONFIRM pattern) calling `GearAction:InvokeServer`.
- [ ] **Step 5: Generalize `refresh()`**: replace the `tab == "item" or tab == "talisman"` special case with "any non-all tab picks its first card when the selection isn't in it"; add `GearConfig.BagAttribute` and `GearConfig.WornAttribute` to `watched`.
- [ ] **Step 6: Compile check** the file. Expected: no errors.
- [ ] **Step 7: Commit** `git add src/StarterPlayer/StarterPlayerScripts/Inventory.client.luau` and `git commit -m "Equipment: Backpack gear row, materials and gear categories"`.

---

### Task 6: Admin helper, Studio smoke test and handoff

**Files:**
- Modify: `src/ServerScriptService/AdminServer.server.luau` (beside `actions.GiveMaterials`, ~line 95) and the admin panel's action list; `docs/superpowers/plans/README.md`; `CLAUDE.md`

**Interfaces:**
- Consumes: `Gear.Grant`, `GearConfig.Rarities`.
- Produces: admin actions `GiveGear(target)` (one random piece per slot at the target's level, random rarity) and `ClearGear(target)`.

- [ ] **Step 1: Add the two admin actions** in the style of `actions.GiveMaterials` and list them where it is listed.
- [ ] **Step 2: Studio smoke test** (a local session with the Studio MCP): add a placeholder model per base id to `ReplicatedStorage.GearModels` (a small part with a `Handle`), run the sync steps from CLAUDE.md, then in play: `GiveGear`; open the Backpack and confirm the left column has no MATERIALS block, the GEAR row, and MATERIALS/GEAR tabs (check the tab row at three screen sizes); equip a Head and a Body (max HP and damage taken change, the model shows on the character), swap in a second Head (old one returns to the bag), salvage one (materials arrive), fill the bag to 30 and confirm a craft collect says "Gear bag is full" and the job stays, rejoin and confirm bag, worn and max HP persist. Record what could not be checked.
- [ ] **Step 3: Update docs**: a row in `plans/README.md`; in CLAUDE.md add an "Equipment" bullet (what is in `GearConfig`, `Gear`, `GearServer`, `GearVisuals`, the Backpack changes) and change the Crafting bullet's "Gear outputs need ... not built yet" to say gear exists.
- [ ] **Step 4: Commit** `git add` those files and `git commit -m "Equipment: admin helpers and docs"`.
- [ ] **Step 5: List the Studio tasks for the owner**: `ReplicatedStorage.GearModels` with an Accessory per base id (optional `HidesHair`), rarity/equip icons and effects.
