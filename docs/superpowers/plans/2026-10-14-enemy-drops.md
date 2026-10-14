# Enemy Drops Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enemies drop materials as glowing per-player orbs that go into a saved bag, ready to be spent in Reforge.

**Architecture:** `DropConfig` (ReplicatedStorage) holds every number and the pure rules (rolls, who counts as a helper, bag cap, pickup rules), Lune-tested. `Drops` (ServerScriptService) tracks damage per enemy from `Damage.OnDealt`, rolls and spawns orbs on `Damage.OnKill`, and runs the pickup/expiry loop. `DropClient` hides orbs that aren't yours during the owner window and pops up "+N Name". The bag is saved player attributes `Mat_<key>`, added to `PlayerStats` defaults.

**Tech Stack:** Luau (Roblox), Lune for the pure-module tests (`tests/run.sh`).

**Spec:** `docs/superpowers/specs/2026-10-14-enemy-drops-design.md`

## Global Constraints

- All drop logic is server-side; a client can't ask for anything (no remotes in this feature).
- Pickup is atomic: the orb is removed before the bag is credited.
- Bag: saved player attribute `Mat_<key>`, a whole number 0 to `MaxPerMaterial = 999`; materials are not lost on death or leaving.
- Helpers: players who dealt >= `ContributionShare = 0.1` of the enemy's max health; each rolls independently and gets their own orbs.
- Only NPCs tagged `Enemy` drop anything. Player kills and untagged NPCs (training dummies) drop nothing.
- Orb: `HoverHeight = 2`, `ScatterRadius = 4`, `OwnerWindow = 30`, `PublicWindow = 30`, `MaxDrops = 200` (oldest go first), `PickupRange = 6` flat and 8 up or down, check every `0.2` s.
- A missing prefab, tier part or material key logs one warning and skips the drop; it never errors a kill.
- Square UI (no `UICorner`). Pop-ups are plain text, white with a dark stroke, no boxes.
- The orbs are the owner's real effects (`ReplicatedStorage.VFXPrefabs.DroppedItemOrb`, moved in Studio). The only visuals this plan adds are the text label and pop-up.
- Damage still goes through `Damage.Deal`; this feature only listens (`OnDealt`, `OnKill`).
- Match surrounding code: comment density, tabs, naming.

## Review Focus

- The killing blow's `OnDealt` can run after `OnKill` (both are `task.spawn`ed from `Damage`), so a one-hit kill by the only attacker would find an empty ledger and drop nothing; expected: the lethal hit counts.
- A player who leaves between the kill and the roll (or whose stats haven't loaded) must not error the kill; expected: skipped.
- A full bag (`Mat_x` at 999) must leave the orb on the ground until it expires, not delete it; a partly full bag takes what fits and the orb keeps the rest.
- Two players standing on one public orb in the same 0.2 s tick: exactly one gets it.
- An enemy killed with no `Level`, an unknown `DropTable`, or a `Humanoid` with zero `MaxHealth` must neither error nor divide by zero.
- Orbs destroyed by something else (a cleared `Workspace.Drops`) must drop out of the server's list, not leak or error the loop.

---

## File Structure

**New**
- `src/ReplicatedStorage/DropConfig.luau`: numbers, `Tiers`, `Materials`, `Generic`, `Tables`, and the pure rules.
- `tests/DropConfig.spec.luau`: Lune tests.
- `src/ServerScriptService/Drops.luau`: the server logic as a module with `Drops.Start()`.
- `src/ServerScriptService/Drops.server.luau`: starts it (like `DayCycle.server.luau`).
- `src/StarterPlayer/StarterPlayerScripts/DropClient.client.luau`: hiding others' orbs, "+N" pop-ups.
- `docs/superpowers/specs/2026-10-14-enemy-drops-checklist.md`: the playtest list.

**Changed**
- `src/ServerScriptService/PlayerStats.luau`: saved defaults for every `Mat_<key>`.
- `src/ServerScriptService/AdminServer.server.luau`, `src/StarterPlayer/StarterPlayerScripts/AdminPanel.client.luau`: `GiveMaterials`.
- `src/StarterPlayer/StarterPlayerScripts/Inventory.client.luau`: the Materials list.
- `CLAUDE.md`, `ROADMAP.md`, `docs/superpowers/plans/README.md`.

---

### Task 1: DropConfig and its pure rules

**Files:**
- Create: `src/ReplicatedStorage/DropConfig.luau`
- Test: `tests/DropConfig.spec.luau` (same `check(name, condition)` style as `tests/DayCycleConfig.spec.luau`; require with `require("../src/ReplicatedStorage/DropConfig")` and `require("../src/ReplicatedStorage/ReforgeConfig")`)

**Interfaces:**
- Produces (`DropConfig`):
  - numbers: `ContributionShare = 0.1`, `HoverHeight = 2`, `ScatterRadius = 4`, `OwnerWindow = 30`, `PublicWindow = 30`, `MaxDrops = 200`, `PickupRange = 6`, `PickupHeight = 8`, `PickupInterval = 0.2`, `MaxPerMaterial = 999`
  - names: `PrefabPath = "DroppedItemOrb"` (under `ReplicatedStorage.VFXPrefabs`), `FolderName = "Drops"` (in `workspace`), `EnemyTag = "Enemy"`, `TableAttribute = "DropTable"`
  - `Tiers: { [tier]: { order: number, orb: string, rgb: { number } } }` for `Common` (1, `"CommonOrb"`, grey), `Rare` (2, `"RareOrb"`, blue), `Gold` (3, `"GoldOrb"`, yellow), `Dark` (4, `"DarkOrb"`, a purple light enough to read on dark UI). Colours are stored as `{ r, g, b }` arrays because `Color3` doesn't exist under Lune; `DropConfig.TierColor(tier: string): Color3` converts with `Color3.fromRGB` at call time (the tests never call it).
  - `Materials: { [key]: { tier: string, display: string } }`: `Scrap`/Common, `Core`/Rare, `Crystal`/Gold, `Essence`/Dark (display = key), plus `WolfFang` (Rare, display `"Wolf Fang"`).
  - `Generic: { { material, minLevel, chance, min, max } }` in tier order: Scrap 1/0.8/1-3, Core 10/0.25/1-2, Crystal 30/0.06/1-1, Essence 50/0.01/1-1.
  - `Tables: { [name]: { { material, chance, min, max } } }`: one example, `Wolf = { { material = "WolfFang", chance = 0.1, min = 1, max = 1 } }`.
  - `Attribute(key: string): string` returns `"Mat_" .. key` (same string as `ReforgeConfig.MaterialAttribute`).
  - `Rolls(level: number?, tableName: string?, random: () -> number): { { material: string, amount: number } }`
  - `IsHelper(damage: number, maxHealth: number): boolean`
  - `Fit(current: number, amount: number): (number, number)` returns `(taken, left)`
  - `CanPickUp(ownerUserId: number, playerUserId: number, now: number, publicAt: number): boolean`
  - `InRange(flatDistance: number, heightDifference: number): boolean`
  - `Sorted(): { string }` returns every material key ordered by tier order, then display name (for the Inventory).

- [ ] **Step 1: Write the failing tests** in `tests/DropConfig.spec.luau`. Use a scripted `random` (a closure over a list of values, popped in order). Assertions:
  - `Rolls(1, nil, seq{0.5, 0.0})` is exactly `{ {material="Scrap", amount=1} }`: only Scrap is reachable at level 1; chance draw 0.5 < 0.8 passes; amount draw 0.0 gives `min`.
  - Amount draw 0.999 with Scrap (1-3) gives 3; draw 0.34 gives 2 (`min + floor(r * (max - min + 1))`).
  - Chance draw exactly 0.8 fails (`random() < chance`), 0.79 passes.
  - Order of draws: per entry one chance draw, then one amount draw only if the chance passed.
  - A level-50 enemy with all draws 0 gets all four generic materials in tier order; level 9 gets only Scrap; level 10 gets Scrap and Core.
  - `Rolls(nil, ...)` behaves as level 1; `Rolls(0, ...)` also.
  - `Rolls(1, "Wolf", ...)` adds `WolfFang` after the generic entries; `Rolls(1, "NoSuchTable", ...)` returns the generic result only (no error).
  - `IsHelper(10, 100) == true`, `IsHelper(9.99, 100) == false`, `IsHelper(5, 0) == false`, `IsHelper(0, 100) == false`.
  - `Fit(0, 5)` is `5, 0`; `Fit(997, 5)` is `2, 3`; `Fit(999, 5)` is `0, 5`; `Fit(1500, 5)` is `0, 5` (an over-cap bag takes nothing).
  - `CanPickUp(1, 1, 0, 100) == true` (owner, window still private); `CanPickUp(1, 2, 99.9, 100) == false`; `CanPickUp(1, 2, 100, 100) == true`.
  - `InRange(6, 8) == true`, `InRange(6.1, 0) == false`, `InRange(0, 8.1) == false`, `InRange(0, -8) == true`.
  - Every `Generic` and `Tables` entry names a key present in `Materials`, and every `Materials[k].tier` is a key of `Tiers`.
  - Every `material` in `ReforgeConfig.LevelCosts` and `ReforgeConfig.RerollCosts` is a key of `Materials` (Reforge must stay payable).
  - `DropConfig.Attribute("Scrap") == ReforgeConfig.MaterialAttribute("Scrap")`.
  - `Sorted()` starts `Scrap, Core, Crystal, Essence`... with ties inside a tier broken by display (`WolfFang` follows `Core` in Rare: `Core` before `Wolf Fang`), and has all five keys.
  - End the file the same way the other specs do (exit non-zero on failures).
- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/DropConfig.spec.luau`
Expected: error that `src/ReplicatedStorage/DropConfig` can't be found.
- [ ] **Step 3: Implement `DropConfig.luau`** with the interface above. Header comment in the style of `ReforgeConfig.luau` (what it is, who reads it). `Rolls` loops `Generic` (skip entries whose `minLevel` exceeds `level or 1`), then the named table if it exists; `random` is the only source of randomness.
- [ ] **Step 4: Run to verify it passes**

Run: `bash tests/run.sh`
Expected: every spec prints `ok`, `DropConfig` included, exit 0.
- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/DropConfig.luau tests/DropConfig.spec.luau
git commit -m "Enemy drops: DropConfig with tested roll, helper, bag and pickup rules"
```

---

### Task 2: Saved bag and the admin button

**Files:**
- Modify: `src/ServerScriptService/PlayerStats.luau` (defaults near line 32-45; `ReforgeConfig` is already required at line 18, follow that for `DropConfig`)
- Modify: `src/ServerScriptService/AdminServer.server.luau` (add after `actions.GiveYen`, ~line 90)
- Modify: `src/StarterPlayer/StarterPlayerScripts/AdminPanel.client.luau` (the PROGRESS section, ~line 263-276)

**Interfaces:**
- Consumes: `DropConfig.Materials`, `DropConfig.Attribute`, `DropConfig.MaxPerMaterial` (Task 1).
- Produces: every material has a saved attribute `Mat_<key>` defaulting to 0 after load; admin action `GiveMaterials(target)` returns `(true, "Gave <name> 50 of each material")` or `(false, loadingMessage(target))`.

- [ ] **Step 1: In `PlayerStats.luau`**, require `DropConfig` like `ReforgeConfig`, and after the shop-items loop add `DEFAULTS[DropConfig.Attribute(key)] = 0` for every key in `DropConfig.Materials`. The existing load code floors and clamps `>= 0`; also clamp each material to `DropConfig.MaxPerMaterial` where the other post-load clamps are (after `player:SetAttribute("Level", ...)`), so a lowered cap fixes old saves.
- [ ] **Step 2: In `AdminServer.server.luau`** add `actions.GiveMaterials(target)`: if the target's `Level` attribute is nil return `false, loadingMessage(target)`; otherwise for every material set the attribute to `math.min(current + 50, DropConfig.MaxPerMaterial)`.
- [ ] **Step 3: In `AdminPanel.client.luau`** add a full-width `button(section(ROW_HEIGHT), "Materials +50 each", { Size = UDim2.fromScale(1, 1) })` under the PROGRESS rows, calling `run("GiveMaterials")` on `Activated` (same shape as the "Reset cooldowns" button at ~line 384).
- [ ] **Step 4: Verify by reading**: no Luau toolchain, so re-read the three edits for syntax; run `bash tests/run.sh` (expect all `ok`).
- [ ] **Step 5: Commit**

```bash
git add src/ServerScriptService/PlayerStats.luau src/ServerScriptService/AdminServer.server.luau src/StarterPlayer/StarterPlayerScripts/AdminPanel.client.luau
git commit -m "Enemy drops: saved Mat_ bag and an admin Materials +50 button"
```

---

### Task 3: Drops server (tracking, rolling, orbs, pickup)

**Files:**
- Create: `src/ServerScriptService/Drops.luau`
- Create: `src/ServerScriptService/Drops.server.luau`

**Interfaces:**
- Consumes: `DropConfig` (all of it), `Damage.OnDealt(listener(attacker, humanoid, dealt, options))`, `Damage.OnKill(listener(killer, character, hit, victimIsPlayer))` from `ServerScriptService/Damage.luau`.
- Produces: `Drops.Start()` (idempotent). Orbs are parts in `workspace.Drops` with attributes `OwnerUserId: number`, `Material: string`, `Amount: number`, `PublicAt: number`, `ExpiresAt: number` (both `workspace:GetServerTimeNow()` values), all set before the orb is parented, plus a `BillboardGui` child named `Label`. `Drops.server.luau` is just `require(script.Parent:WaitForChild("Drops")).Start()` with the header comment style of `DayCycle.server.luau`.
- The client (Task 4) relies on exactly those attribute names and on the `Label` child.

Internal functions (all local, in `Drops.luau`), with the decisions each needs:

- `track(attacker, humanoid, dealt)`: if `attacker` is a `Player`, the humanoid's parent is tagged `DropConfig.EnemyTag` and not a player character, add `dealt` to `damageBy[model][attacker]`. `damageBy` is a weak-keyed table (model -> { [Player] = number }), also weak on the inner player keys.
- `onKill(killer, character, hit, victimIsPlayer)`: ignore player victims and untagged models. Capture `character:GetPivot().Position` and the humanoid's `MaxHealth` and `Level` immediately (the model may be gone later). Then `task.defer` the rest (the killing blow's `OnDealt` may not have run yet; see Review Focus). In the deferred part: helpers are players in `damageBy[character]` that are still in game and pass `DropConfig.IsHelper(damage, maxHealth)`; clear the ledger entry; for each helper call `DropConfig.Rolls(level, character:GetAttribute(DropConfig.TableAttribute), math.random)` and `spawnOrb(helper, material, amount, position)` for each result.
- `spawnOrb(player, material, amount, position)`: look up `Materials[material]`; the prefab at `ReplicatedStorage.VFXPrefabs.DroppedItemOrb` via `FindFirstChild`; the tier's part by the tier's `orb` name (for `Dark`, pick randomly among all children with that name). If any is missing, `warn` once per distinct reason (a `warned` set) and return. Clone, set `Anchored = true`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`. Place at a random point within `ScatterRadius` (uniform over the disc: `radius = ScatterRadius * math.sqrt(random)`), ground found by `workspace:Raycast` straight down (start 5 studs above the enemy position, length 60) with a `RaycastParams` excluding `workspace.Drops`, the enemy's model and every player character; ground Y + `HoverHeight`, or the enemy position's Y if nothing was hit. Add the `Label` (a `BillboardGui`, `AlwaysOnTop`, `StudsOffset = Vector3.new(0, 2, 0)`, containing a `TextLabel` with transparent background, `GothamBold`, `TextStrokeTransparency = 0`, the tier colour, text `"<display> x<amount>"`, no `UICorner`). Append to the ordered `orbs` list; while `#orbs > DropConfig.MaxDrops`, destroy `orbs[1]` and remove it.
- `tick()`: runs every `DropConfig.PickupInterval` in a `task.spawn`ed loop. Drop entries from `orbs` whose `Parent == nil`; destroy and drop those past `ExpiresAt`. For each player with a living character and root part, whose `Mat_` attributes are numbers (stats loaded), and each remaining orb: skip unless `DropConfig.CanPickUp(OwnerUserId, player.UserId, now, PublicAt)` and `DropConfig.InRange(flat distance, abs height difference)`. Then `taken, left = DropConfig.Fit(current, Amount)`; if `taken == 0` skip; if `left == 0` remove the orb from `orbs` and `Destroy` it first, otherwise set its `Amount` to `left` and update its label text; only then `SetAttribute(DropConfig.Attribute(material), current + taken)`. Re-check `orb.Parent` before each credit so a second player in the same tick can't take a destroyed orb.
- `Start()`: create `workspace.Drops` (`Folder`, named `DropConfig.FolderName`) if missing, connect the two `Damage` listeners, start the loop. Expiry time: `PublicAt = now + OwnerWindow`, `ExpiresAt = PublicAt + PublicWindow`.

- [ ] **Step 1: Write `Drops.luau` and `Drops.server.luau`** from the decisions above; keep each function short and comment only what isn't obvious (the defer, the destroy-before-credit order).
- [ ] **Step 2: Re-read for syntax and the Review Focus items** (the defer on kill; `Fit` returning `taken == 0` leaves the orb; the `Parent` re-check; the weak ledger; `warn` once). No toolchain exists, so read the whole file once, top to bottom.
- [ ] **Step 3: Run the unit tests** (nothing in this file is testable under Lune)

Run: `bash tests/run.sh`
Expected: all `ok`.
- [ ] **Step 4: Commit**

```bash
git add src/ServerScriptService/Drops.luau src/ServerScriptService/Drops.server.luau
git commit -m "Enemy drops: per-helper rolls, orbs in workspace.Drops, pickup and expiry"
```

---

### Task 4: DropClient (hide others' orbs, +N pop-ups)

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/DropClient.client.luau`

**Interfaces:**
- Consumes: orb attributes `OwnerUserId`, `PublicAt`, `Material` and the `Label` child (Task 3); `DropConfig.Materials`, `DropConfig.Attribute`, `DropConfig.TierColor`, `DropConfig.Tiers` (Task 1). The server clock is `workspace:GetServerTimeNow()`.
- Produces: nothing other scripts use.

- [ ] **Step 1: Hiding.** Wait for `workspace.Drops`. For each existing and each added child (`ChildAdded`), call `apply(orb)`: if `OwnerUserId ~= player.UserId` and `workspace:GetServerTimeNow() < PublicAt`, hide it locally (`LocalTransparencyModifier = 1` on the part, `Enabled = false` on every descendant `ParticleEmitter` and on the `Label`), and `task.delay(PublicAt - now, ...)` to show it again (guard that the orb is still parented). Hiding is cosmetic only; the server enforces the rule.
- [ ] **Step 2: Pop-ups.** A `ScreenGui` (`ResetOnSpawn = false`, `Name = "DropPopups"`) holding a transparent frame with a bottom-aligned `UIListLayout`, placed at the lower middle of the screen (clear of the skill bar and hotbar). For each material key in `DropConfig.Materials`, watch `player:GetAttributeChangedSignal(DropConfig.Attribute(key))`. Remember the last value per key; the first non-nil value is a baseline and shows nothing (this is the load from the save). When a later value is higher, add a `TextLabel` `"+<difference> <display>"`: white text, dark stroke (`TextStrokeTransparency = 0`), `GothamBold`, no background, no corners; fade out and destroy it after about 2 seconds. A lower value (Reforge spending, admin reset) shows nothing.
- [ ] **Step 3: Re-read for syntax**, then run the unit tests

Run: `bash tests/run.sh`
Expected: all `ok`.
- [ ] **Step 4: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/DropClient.client.luau
git commit -m "Enemy drops: client hides others' orbs and pops up +N materials"
```

---

### Task 5: Materials list in the Inventory

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Inventory.client.luau` (requires near line 14-18; the left column is `leftColumn`/`slotList` at ~line 196-212; `refresh()` ~line 810; the `watched` table ~line 886)

**Interfaces:**
- Consumes: `DropConfig.Sorted()`, `DropConfig.Materials`, `DropConfig.Attribute`, `DropConfig.TierColor`, `DropConfig.Tiers` (Task 1).
- Produces: nothing used elsewhere.

- [ ] **Step 1: Add the list.** In the left column, under the carry slots, a `MATERIALS` heading (same style as the column title) and a `scroller` (the existing helper) with one row per material in `DropConfig.Sorted()` whose attribute value on the player is above 0: name on the left in the tier's colour, amount on the right in white. Nothing for materials the player has none of; if none, a muted `"None yet"`. The column is 428 px tall minus padding and the three slots take about 292, so give the list the remaining height (about 90 px) and let it scroll rather than resizing the slots; check by reading the numbers, and say in the summary that it needs a visual check at the smallest panel size (the panel shrinks to `SCREEN_MARGIN`).
- [ ] **Step 2: Keep it fresh.** Rebuild the rows in `refresh()` (use `clear`) and add every `DropConfig.Attribute(key)` to the `watched` table so the open menu updates when a drop is picked up.
- [ ] **Step 3: Re-read for syntax**, then run the unit tests

Run: `bash tests/run.sh`
Expected: all `ok`.
- [ ] **Step 4: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Inventory.client.luau
git commit -m "Enemy drops: a Materials list in the Inventory"
```

---

### Task 6: Docs and the playtest checklist

**Files:**
- Create: `docs/superpowers/specs/2026-10-14-enemy-drops-checklist.md`
- Modify: `CLAUDE.md` (Architecture: add a `Drops`/`DropConfig` entry beside Reforge, and `DropClient` in Client UI), `ROADMAP.md` (the Enemy drops line ~80-81: built, not yet in Studio), `docs/superpowers/plans/README.md` (add this plan; fix the Reforge line that says "no plan yet")

**Interfaces:** none.

- [ ] **Step 1: Write the checklist** (what the owner tries in Studio, in the style of `2026-10-14-reforge-checklist.md`). It must start with the Studio setup: move `Workspace.DroppedItemOrb` to `ReplicatedStorage.VFXPrefabs.DroppedItemOrb`; confirm the enemy models are tagged `Enemy`; optionally set `DropTable = "Wolf"` on one enemy. Then the checks: kill a level 1 enemy and see a grey orb that falls where it died and pops "+N Scrap"; a second player does at least 10% and gets their own orb, one doing under 10% gets none, and cannot see or take the other's during 30 s; after 30 s orbs become public; after another 30 s they vanish; a training dummy drops nothing; a one-hit kill still drops; the Inventory lists materials; Admin `Materials +50 each` works and Reforge then accepts it; rejoining keeps the bag; a bag at 999 leaves the orb on the ground; more than 200 orbs removes the oldest.
- [ ] **Step 2: Update `CLAUDE.md`, `ROADMAP.md` and the plans README** as listed above. The README's Done entry must say: built, not synced to Studio, with the Studio prerequisites and the checklist path.
- [ ] **Step 3: Verify the docs mention nothing the code doesn't do**: grep the new docs for the names `Drops`, `DropConfig`, `DropClient`, `Mat_` and confirm each exists in `src/`.

Run: `git grep -n "DropConfig" -- src | head`
Expected: hits in `ReplicatedStorage`, `ServerScriptService` and `StarterPlayerScripts`.
- [ ] **Step 4: Commit**

```bash
git add docs CLAUDE.md ROADMAP.md
git commit -m "Enemy drops: checklist and docs"
```

---

## Self-review

- **Spec coverage:** materials and tiers (Task 1), drop tables via `DropTable` (Tasks 1, 3), saved bag and cap (Tasks 1, 2), helpers at 10% and independent rolls (Tasks 1, 3), no PvP or dummy drops (Task 3), orb placement/windows/max/pickup (Task 3), client hiding and pop-up (Task 4), Inventory list (Task 5), admin button (Task 2), files and docs (Task 6), Studio prerequisites (Task 6 checklist). Error handling: warn-once and atomic pickup are in Task 3; bag cap in Tasks 1-2.
- **Types:** `Rolls`, `IsHelper`, `Fit`, `CanPickUp`, `InRange`, `Sorted`, `Attribute` and `TierColor` are named identically where Tasks 2 to 5 use them.
- **Differences from the spec:** none in behaviour. Additions: `PickupHeight`/`PickupInterval` constants, `Fit` and `CanPickUp` as tested helpers, the `Wolf` example table, and the post-kill `task.defer`.
