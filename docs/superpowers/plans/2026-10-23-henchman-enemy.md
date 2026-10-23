# Henchman Enemy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Henchman its own aggro range, a jab-jab-heavy combo with a lunge, a loot table with a new Thug Badge material, and a drop-only Thug's Knuckle talisman, through a new per-`EnemyType` `EnemyConfig`.

**Architecture:** A pure `EnemyConfig` module (Lune-tested) holds per-type settings and the small rules (setting lookup, combo order, aggro, talisman roll). `EnemyAI`, `Drops`, `DropConfig` and `TalismanConfig` read it. Enemies with no entry behave exactly as today.

**Tech Stack:** Luau (Roblox), Lune for unit tests (`tests/run.sh`).

**Spec:** `docs/superpowers/specs/2026-10-23-henchman-enemy-design.md`

## Global Constraints

- Square UI, nothing visual added; cues stay placeholders (white quick / red heavy `Telegraph` via `EnemyAttackConfig`).
- All player damage still goes through the existing swing path (`Guard.Resolve`, `Passives.Absorb`, dodge and `Invulnerable` checks); `Damage.luau` is not edited.
- Pure modules in `ReplicatedStorage` use no Roblox types so Lune can load them (see `tests/TalismanConfig.spec.luau` for the `check` style). New spec files go in `tests/*.spec.luau`; `tests/run.sh` picks them up.
- Henchman placeholders: `AggroRange = 25`; combo quick, quick, heavy; heavy `lunge = 6`; `comboPause = 1.2`; talisman `ThugKnuckle` chance `0.03`; Thug Badge tier Rare.
- Lookup order for any setting: model attribute, then `EnemyConfig` entry, then `EnemyAI` `DEFAULTS`.
- Match surrounding code: comment density, tabs, naming. Commit only the files a task names (the working tree has unrelated uncommitted changes).
- No Studio connection here: say what could not be verified; the owner playtests.

## Review Focus

- A Henchman that is mid-combo when its target dies or leaves: the combo index must reset (next target starts at the first jab).
- A player standing inside `AggroRange` but outside the enemy's leash territory must not trigger a chase (it would chase, hit the leash and give up in a loop).
- A retreating enemy (`retreating = true`) must ignore aggro until it is home.
- An enemy with `EnemyType` set to a name with no entry (or none at all) is passive and swings the random quick/heavy way, as now.
- A player who already owns Thug's Knuckle must not consume a roll or get a second toast.
- `RollNew` must never hand out a `dropOnly` talisman (yen chests).
- A `dropTable` naming a table that does not exist in `DropConfig.Tables` must not error in `DropConfig.Rolls`.

---

### Task 1: `EnemyConfig` module

**Files:**
- Create: `src/ReplicatedStorage/EnemyConfig.luau`
- Create: `tests/EnemyConfig.spec.luau`
- Commit with it: `docs/superpowers/specs/2026-10-23-henchman-enemy-design.md`, `docs/superpowers/plans/2026-10-23-henchman-enemy.md`

**Interfaces:**
- Produces:
  - `EnemyConfig.Types: { [string]: Entry }` where `Entry = { AttackRange: number?, AttackCooldown: number?, LeashRange: number?, ChaseSpeed: number?, HeavyChance: number?, AggroRange: number?, dropTable: string?, talisman: { key: string, chance: number }?, attacks: { { type: "quick"|"heavy", damage: number?, lunge: number? } }?, comboPause: number? }`
  - `EnemyConfig.Get(enemyType: any) -> Entry?` (nil for non-string or unknown)
  - `EnemyConfig.Setting(attributeValue: any, enemyType: any, key: string, default: any) -> any` (attribute if not nil, else entry[key] if not nil, else default)
  - `EnemyConfig.NextAttack(entry: Entry?, index: number) -> (step, nextIndex: number, finishesCombo: boolean)?` returns nil when the entry has no `attacks`; `index` is 1-based and wraps; invalid/out-of-range index counts as 1
  - `EnemyConfig.InAggro(entry: Entry?, distance: number) -> boolean` (false when no `AggroRange`)
  - `EnemyConfig.TalismanDrop(entry: Entry?, owned: {string}, random: () -> number) -> string?` (the key on a pass; nil when no `talisman`, already owned, or the roll is at or above `chance`; does not call `random` when already owned)

- [ ] **Step 1: Write the failing spec `tests/EnemyConfig.spec.luau`** (same `check`/`failures` harness as `tests/TalismanConfig.spec.luau`, ending with `if failures > 0 then error(...)`-style exit as that file does). Cases, with exact assertions:
  - `Get("Henchman")` is a table; `Get("Nope")`, `Get(nil)`, `Get(5)` are nil.
  - Henchman entry: `AggroRange == 25`, `comboPause == 1.2`, `#attacks == 3`, types `quick, quick, heavy`, `attacks[3].lunge == 6`, `talisman.key == "ThugKnuckle"`, `talisman.chance == 0.03`, `dropTable == "Henchman"`.
  - `Setting(30, "Henchman", "AggroRange", 0) == 30`; `Setting(nil, "Henchman", "AggroRange", 0) == 25`; `Setting(nil, "Nope", "AggroRange", 7) == 7`; `Setting(nil, nil, "AttackRange", 5) == 5`.
  - `NextAttack(Henchman, 1)` returns type quick, next 2, finishes false; `(…, 3)` returns heavy, next 1, finishes true; `(…, 4)` and `(…, 0)` and `(…, nil)` behave as index 1; `NextAttack(nil, 1) == nil`; `NextAttack({}, 1) == nil`.
  - `InAggro(Henchman, 25) == true`, `InAggro(Henchman, 25.01) == false`, `InAggro({}, 1) == false`, `InAggro(nil, 1) == false`.
  - `TalismanDrop(Henchman, {}, function() return 0.029 end) == "ThugKnuckle"`; with `0.03` returns nil; with `owned = {"ThugKnuckle"}` returns nil and a `random` that errors if called is never called; `TalismanDrop({}, {}, …) == nil`.

- [ ] **Step 2: Run it to see it fail**

Run: `lune run tests/EnemyConfig.spec.luau`
Expected: error that `src/ReplicatedStorage/EnemyConfig` cannot be required. (If `lune` is not installed, install it first: `cargo install lune`; say so in the report if it can't be.)

- [ ] **Step 3: Implement `src/ReplicatedStorage/EnemyConfig.luau`** with the signatures above and a header comment in the style of `EnemyAttackConfig.luau` (what the module is, who reads it, "an enemy with no entry behaves as the defaults"). Henchman entry has the exact placeholder values from Global Constraints plus `dropTable = "Henchman"`.

- [ ] **Step 4: Run it to see it pass**

Run: `lune run tests/EnemyConfig.spec.luau`
Expected: every line `ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/EnemyConfig.luau tests/EnemyConfig.spec.luau docs/superpowers/specs/2026-10-23-henchman-enemy-design.md docs/superpowers/plans/2026-10-23-henchman-enemy.md
git commit -m "Henchman: EnemyConfig (per-type settings, combo, aggro, talisman roll)"
```

---

### Task 2: Thug Badge material and Henchman drop table

**Files:**
- Modify: `src/ReplicatedStorage/DropConfig.luau` (`Materials` ~line 66, `Tables` ~line 84, `Rolls` ~line 111)
- Modify: `tests/DropConfig.spec.luau`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: material `ThugBadge` (`tier = "Rare"`, `display = "Thug Badge"`); `DropConfig.Tables.Henchman` (additive): Scrap `chance 0.6, min 1, max 3`; ThugBadge `chance 0.15, min 1, max 1`; Core `chance 0.1, min 1, max 1`. `DropConfig.Rolls` ignores an unknown `tableName` instead of erroring.

- [ ] **Step 1: Add failing cases to `tests/DropConfig.spec.luau`** in its existing style:
  - `Materials.ThugBadge.tier == "Rare"`.
  - Every `material` named by every entry of every table in `DropConfig.Tables` exists in `DropConfig.Materials`.
  - With `random = function() return 0 end` and level 10, `Rolls(10, "Henchman", random)` contains `ThugBadge` x1 and contains Scrap twice (generic + table) and Core twice; with `random = function() return 0.99 end` it is empty.
  - `Rolls(10, "NoSuchTable", function() return 0 end)` does not error and equals `Rolls(10, nil, …)`.
- [ ] **Step 2: Run** `lune run tests/DropConfig.spec.luau` — Expected: the new cases FAIL (the unknown-table case may already pass; fine).
- [ ] **Step 3: Implement** the material, the table, and (if the unknown-table case fails) nothing more: `Rolls` already does `tableName and Tables[tableName] or {}`, so only confirm that. Add a one-line comment above the `Henchman` table.
- [ ] **Step 4: Run** `lune run tests/DropConfig.spec.luau` — Expected: all `ok`.
- [ ] **Step 5: Commit** `git add src/ReplicatedStorage/DropConfig.luau tests/DropConfig.spec.luau` then `git commit -m "Henchman: Thug Badge material and drop table"`

---

### Task 3: Thug's Knuckle talisman (drop-only)

**Files:**
- Modify: `src/ReplicatedStorage/TalismanConfig.luau` (`Items` after Glass Charm; `RollNew`; header comment line 9)
- Modify: `tests/TalismanConfig.spec.luau`

**Interfaces:**
- Produces: item `{ key = "ThugKnuckle", name = "Thug's Knuckle Talisman", color = { 150, 80, 60 }, effects = { damageDealt = 0.1, healOnKill = 0.02 }, dropOnly = true, description = "+10% damage dealt. Heal 2% max HP on every kill." }`; `RollNew` skips items with `dropOnly`.

- [ ] **Step 1: Add failing cases to `tests/TalismanConfig.spec.luau`** (it sets `T.OwnAll = false`):
  - `T.Get("ThugKnuckle").dropOnly == true` and `T.Get("Vigor").dropOnly == nil`.
  - `near(T.Total("ThugKnuckle,Vigor", "damageDealt"), 0.1)` and `near(T.Total("ThugKnuckle", "healOnKill"), 0.02)`.
  - Owning every non-dropOnly talisman (`"Vigor,Regrowth,Bulwark,Magnate,SecondWind,GlassCharm"`): `T.RollNew(that, function(n) return 1 end) == nil`.
  - Owning nothing, for `roll = function(n) return n end` (the last missing): result is `"GlassCharm"`, never `"ThugKnuckle"`.
  - `T.Grant("Vigor", "ThugKnuckle") == "Vigor,ThugKnuckle"`; granting it again returns nil.
  - Also update the existing "items are well formed" count only if it breaks (`#T.Items >= 6` still holds).
- [ ] **Step 2: Run** `lune run tests/TalismanConfig.spec.luau` — Expected: new cases FAIL.
- [ ] **Step 3: Implement** the item and change `RollNew`'s missing-list loop to skip `item.dropOnly`. Update the header comment ("They drop from yen chests (ChestChance) and, for `dropOnly` ones, from the enemy that names them in `EnemyConfig`").
- [ ] **Step 4: Run** `lune run tests/TalismanConfig.spec.luau` — Expected: all `ok`.
- [ ] **Step 5: Commit** `git add src/ReplicatedStorage/TalismanConfig.luau tests/TalismanConfig.spec.luau` then `git commit -m "Henchman: drop-only Thug's Knuckle talisman"`

---

### Task 4: `Drops` reads the type's table and rolls the talisman

**Files:**
- Modify: `src/ServerScriptService/Drops.luau` (requires at top; `onKill`, ~lines 160-175)

**Interfaces:**
- Consumes: `EnemyConfig.Get`, `EnemyConfig.TalismanDrop` (Task 1); `Talismans.Grant(player, key) -> string?` (existing, `ServerScriptService.Talismans`); `TalismanConfig.Owned(text) -> {string}` and `TalismanConfig.OwnedAttribute` (existing).
- Produces: nothing new for other tasks.

- [ ] **Step 1: Implement in `onKill`:** next to the `tableName` read, also read `local entry = EnemyConfig.Get(character:GetAttribute("EnemyType"))` and set `tableName = character:GetAttribute(DropConfig.TableAttribute) or (entry and entry.dropTable)`. Inside the per-helper block, after the orb loop, add: `local key = EnemyConfig.TalismanDrop(entry, TalismanConfig.Owned(player:GetAttribute(TalismanConfig.OwnedAttribute)), math.random)` and `if key then Talismans.Grant(player, key) end`. Add the three `require`s in the file's existing style (`WaitForChild` for ReplicatedStorage modules, `script.Parent:WaitForChild("Talismans")` for the sibling). Update the file's header comment by one line.
- [ ] **Step 2: Read the edit back** and check by eye: `entry` is captured before the `task.defer` (the model may be gone), `Talismans.Grant` is only called with a non-nil key, and no `require` cycle exists (`Talismans` must not require `Drops`: `grep -n "Drops" src/ServerScriptService/Talismans.luau` returns nothing).
- [ ] **Step 3: Run the whole suite** `bash tests/run.sh` — Expected: all specs pass (this task adds no spec; the game-side wiring is checked in Studio).
- [ ] **Step 4: Commit** `git add src/ServerScriptService/Drops.luau` then `git commit -m "Henchman: Drops uses the enemy type's table and talisman"`

---

### Task 5: `EnemyAI` — type settings, aggro range, combo and lunge

**Files:**
- Modify: `src/ServerScriptService/EnemyAI.server.luau` (header comment; `setting` ~line 65; `swingAt` ~170-211; the attack branch ~284-294; the idle/returning tick ~308-319)

**Interfaces:**
- Consumes: `EnemyConfig.Get`, `Setting`, `NextAttack`, `InAggro` (Task 1); `EnemyAttackConfig.Get(name)`; the existing `dashAt(direction, distance)` and `goHome`/`arrive`.
- Produces: nothing for later tasks.

- [ ] **Step 1: Type-aware settings.** Add `local EnemyConfig = require(ReplicatedStorage:WaitForChild("EnemyConfig"))`. Change `setting(model, key)` to `return EnemyConfig.Setting(model:GetAttribute(key), model:GetAttribute("EnemyType"), key, DEFAULTS[key])`. Inside `run`, `local entry = EnemyConfig.Get(model:GetAttribute("EnemyType"))` once, and use `EnemyConfig.Setting(model:GetAttribute("HeavyChance"), model:GetAttribute("EnemyType"), "HeavyChance", nil)` where `swingAt` reads `HeavyChance` (so `EnemyAttackConfig.Chance(nil)` still gives the default).
- [ ] **Step 2: Combo in `swingAt`.** Add `local comboIndex = 1`. In `swingAt`, `local step, nextIndex, finishes = EnemyConfig.NextAttack(entry, comboIndex)`: when `step` is non-nil, set `comboIndex = nextIndex`, `attackType = step.type`, multiply the swing's damage by `step.damage or 1`, and return `finishes` to the caller; when `step` is nil, keep today's `EnemyAttackConfig.Choose` roll and return false. If `step.lunge` is set, call `dashAt(direction to the target, step.lunge + setting(model, "AttackRange") - 1)` at the start of the wind-up (so the burst is the existing 0.1 s minimum, about 8 studs, clamped by `dashAt`). In the attack branch, set `nextAttackAt = now + (finishes and (entry.comboPause or cooldown) or cooldown)`. Reset `comboIndex = 1` in `goHome` and whenever `target` changes (in the `HealthChanged` handler and the aggro start).
- [ ] **Step 3: Aggro scan.** In the tick, in the `else` branches for `state == "idle"` (and `"returning"` when `not retreating`), if `EnemyConfig.Setting(nil, model:GetAttribute("EnemyType"), "AggroRange", nil)` is set and `not busy`: loop `Players:GetPlayers()`, take the nearest with a living `Humanoid`, a `HumanoidRootPart`, `(rootPos - root.Position).Magnitude` passing `EnemyConfig.InAggro(entry, distance)`, **and** `flat(theirRoot.Position - home.Position).Magnitude <= setting(model, "LeashRange")`; on a hit set `target`, `state = "chasing"`, `humanoid.WalkSpeed = setting(model, "ChaseSpeed")`, `lastProgressAt = now`, `regenerating = false`, `comboIndex = 1`. Skip players with `Invulnerable` set on the character. Put the scan in a local function `findAggroTarget()` above the loop.
- [ ] **Step 4: Update the header comment** (aggro range, types, combo) in the file's existing voice, and mention `EnemyType` in the optional-attributes list.
- [ ] **Step 5: Verify what can be verified.** Read the file top to bottom for syntax (no Luau toolchain: if `luau-analyze` or `selene` is installed, run it on the file and report the output; if not, say syntax was only read by eye). Run `bash tests/run.sh` — Expected: all specs pass.
- [ ] **Step 6: Commit** `git add src/ServerScriptService/EnemyAI.server.luau` then `git commit -m "Henchman: aggro range, jab-jab-heavy combo with lunge in EnemyAI"`

---

### Task 6: Docs and the Studio apply list

**Files:**
- Modify: `CLAUDE.md` (Architecture: one line for `EnemyConfig`, `EnemyType` and the Henchman)
- Modify: `ROADMAP.md` (a "Henchman enemy" entry under Combat depth or World: built in repo, waiting on Studio and a playtest)
- Create: `docs/superpowers/specs/2026-10-23-henchman-enemy-checklist.md` (playtest checklist)

**Interfaces:** none.

- [ ] **Step 1: CLAUDE.md** — these two files have uncommitted edits already; read them first and add only the new lines, do not touch the rest. One bullet: `EnemyConfig` (per-`EnemyType` settings, combo, aggro range, loot table and talisman; Lune-tested), Henchman first.
- [ ] **Step 2: ROADMAP.md** — add the entry (spec, plan, checklist paths; "code built, waiting on Studio and a playtest"; follow-ups: bounties, squads, a thrown weapon, final VFX/animations, Thug Badge in a Reforge recipe, `TalismanConfig.OwnAll` off before release).
- [ ] **Step 3: Write the checklist** from the spec's Testing section, plus a "Studio apply" section: create ModuleScript `ReplicatedStorage.EnemyConfig` from `src/ReplicatedStorage/EnemyConfig.luau`; apply the diffs of `DropConfig`, `TalismanConfig`, `Drops`, `EnemyAI`; re-export to refresh `studio-manifest.json`. Playtest items: walk toward a Henchman (aggro near 25 studs, none outside the leash); jab, jab, heavy rhythm and lunge; Q-dodge the finisher; the pause after it; leash and give-up; an untyped enemy still passive until hit; kills drop Scrap/Thug Badge/Core orbs; with `TalismanConfig.OwnAll = false` locally the Knuckle drops (3%, so raise `chance` to 1 for the test), the Found toast shows, a repeat does not.
- [ ] **Step 4: Commit only the checklist** (`git add docs/superpowers/specs/2026-10-23-henchman-enemy-checklist.md`, `git commit -m "Henchman: playtest checklist"`). `CLAUDE.md` and `ROADMAP.md` already carry the owner's other uncommitted edits and interactive staging isn't available, so leave them modified and unstaged, and tell the owner they hold the Henchman lines too.
