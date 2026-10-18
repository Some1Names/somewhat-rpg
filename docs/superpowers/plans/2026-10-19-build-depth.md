# Build Depth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stat caps, two new stats, stat requirements on weapons/skill sets, and threshold-gated equippable talents.

**Architecture:** Numbers and pure rules live in `ReplicatedStorage` (`StatConfig`, `TalentConfig`, `BuildRules`) and are Lune-tested. A server `Talents` module owns per-player state (saved text + `Talent_<key>` attributes) and the equip remote. Existing systems (`PlayerStats`, `Damage`, `Guard`, `StatusEffects`, `Stamina`, `SkillSetServer`, `PunchCombat`, `Loadout`) read modifiers; no per-talent scripts.

**Tech Stack:** Luau (Roblox), Lune for tests (`tests/run.sh`).

**Spec:** `docs/superpowers/specs/2026-10-19-build-depth-design.md`

## Global Constraints

- Stat cap 50 per stat; `PointsPerLevel` stays 3. New stats: `Agility`, `Willpower`.
- Talent tiers unlock at 15 / 30 / 50 points in the talent's stat; talent points = `floor(level / 5)` (20 at level 100).
- Requirement failure = item unusable, enforced server-side.
- UI is square (no `UICorner`), HUD colours; match surrounding code style and comment density.
- Unspent points are derived (`PlayerStats.updatePoints`), so clamping a stat to the cap refunds automatically (already done at load, `PlayerStats.luau:215`).
- Studio can't be reached from here: new scripts go into `studio-manifest.json` via the next Studio export; say what couldn't be verified.

## Review Focus

- Corrupt or hostile `Talents` text (unknown keys, duplicates, huge string): `Decode` returns only valid unique keys. Test in Task 2.
- Spoofed equip request (non-string, unknown key, locked tier, over budget): rejected. Test in Task 2, remote handler in Task 3.
- Stat points removed (`ResetStats`, admin `Set`) or level lowered while talents are equipped: `Prune` drops locked talents, then trailing ones until within budget. Test in Task 2; wired in Task 3.
- Old saves with stats above 50: clamped and refunded at load. Test `StatCap` in Task 1.
- Item with no `requires`, or player attributes missing: `Meets` is true. Test in Task 2.

---

### Task 1: New stats, cap 50, stat effects

**Files:**
- Modify: `src/ReplicatedStorage/StatConfig.luau` (`Stats` list ~line 60, `StatCap` ~line 97, new functions)
- Create: `tests/BuildRules.spec.luau` (starts here, extended in Task 2; copy the `check` helper from `tests/ReforgeRules.spec.luau`)
- Check: `src/StarterPlayer/StarterPlayerScripts/StatsMenu.client.luau`, `AdminPanel.client.luau`, `ShopServer.server.luau` (they loop over `StatConfig.Stats`; confirm six rows fit, and fix any per-key hardcoding you find)

**Interfaces:**
- Produces: `StatConfig.MaxStatPoints = 50`; `StatConfig.StatCap(key)` = `math.min(stat.max or MaxStatPoints, MaxLevel)`; `StatConfig.AgilityStamina(points: number) -> number` (= points, extra max stamina); `StatConfig.WillpowerPostureMultiplier(points) -> number` and `StatConfig.WillpowerStatusMultiplier(points) -> number`, both `1 - 0.01 * points`.

- [ ] **Step 1: Write failing tests** in `tests/BuildRules.spec.luau`: `StatCap("Vitality") == 50` and `StatCap("Agility") == 50`; `StatConfig.Get("Willpower") ~= nil`; `AgilityStamina(50) == 50`; `WillpowerPostureMultiplier(0) == 1`, `(50) == 0.5`; `WillpowerStatusMultiplier(20) == 0.8`.
- [ ] **Step 2:** `lune run tests/BuildRules.spec.luau` → FAIL.
- [ ] **Step 3:** Add `Agility` and `Willpower` entries (no milestones, no `damageBonus`; comments say what each buys), the cap constant, and the three functions.
- [ ] **Step 4:** Run the spec → all `ok`. Run `tests/run.sh` to confirm no other spec broke.
- [ ] **Step 5:** Commit `Stats: Agility, Willpower and a cap of 50`.

### Task 2: TalentConfig and BuildRules

**Files:**
- Create: `src/ReplicatedStorage/TalentConfig.luau`, `src/ReplicatedStorage/BuildRules.luau`
- Modify: `tests/BuildRules.spec.luau`

**Interfaces:**
- Produces `TalentConfig`: `Tiers = {15, 30, 50}`, `LevelsPerPoint = 5`, `Attribute(key) -> "Talent_"..key`, `SaveAttribute = "Talents"`, `MaxSaveLength = 400`, `Kinds = { maxHealth="mult", regen="add", damage="mult", staminaMax="add", postureTaken="mult", statusDuration="mult" }`, `Get(key)`, and `List`, ordered, each `{ key, name, stat, tier, cost, kind, amount, damageStat? }`:

| stat | tier 15 (cost 1) | tier 30 (cost 2) | tier 50 (cost 3) |
|---|---|---|---|
| Vitality | Hardy: maxHealth ×1.05 | Second Wind: regen +2 | Unyielding: maxHealth ×1.10 |
| Strength | Heavy Hands: damage ×1.05 | Brutal: damage ×1.10 | Crusher: damage ×1.15 |
| Superliminal | Focus: damage ×1.05 | Overflow: damage ×1.10 | Apex: damage ×1.15 |
| Firearm | Steady Aim: damage ×1.05 | Marksman: damage ×1.10 | Deadeye: damage ×1.15 |
| Agility | Quick Lungs: staminaMax +10 | Light Feet: staminaMax +15 | Windrunner: staminaMax +25 |
| Willpower | Steady: postureTaken ×0.95 | Resolute: statusDuration ×0.85 | Iron Mind: postureTaken ×0.85 |

  `damage` talents set `damageStat` to their stat. Keys are the names without spaces.
- Produces `BuildRules` (all pure):
  - `Meets(stats: {[string]: number}, requires: {[string]: number}?) -> (boolean, string?)`: true if `requires` is nil/empty; otherwise false plus the first missing stat key in alphabetical order.
  - `TalentPoints(level: number) -> number`; `TierUnlocked(points: number, tier: number) -> boolean`; `Spent(equipped: {string}) -> number`.
  - `CanEquip(equipped, key, stats, level) -> (boolean, string?)`; reasons `"unknown"`, `"already"`, `"locked"`, `"budget"`.
  - `Prune(equipped, stats, level) -> {string}`: drop talents whose tier is locked, then drop from the end until `Spent <= TalentPoints(level)`; order kept.
  - `Encode(equipped) -> string` (comma-joined); `Decode(text: any) -> {string}` (non-string or over `MaxSaveLength` gives `{}`; unknown and duplicate keys are skipped).
  - `Modifier(equipped, kind: string, damageStat: string?) -> number`: product for `mult` kinds (1 when none), sum for `add` kinds (0 when none); `damage` only counts talents whose `damageStat` equals the argument.

- [ ] **Step 1: Write failing tests** (add to the spec): `Meets({Strength=20},{Strength=20})` true; `Meets({},{Strength=1,Firearm=1})` returns `false, "Firearm"`; `Meets({}, nil)` true; `TalentPoints(0)==0`, `(4)==0`, `(5)==1`, `(100)==20`; `TierUnlocked(14,15)` false, `(15,15)` true; `CanEquip({}, "Hardy", {Vitality=14}, 100)` → `false,"locked"`; with `Vitality=15` and level 0 → `false,"budget"`; with level 5 → true; again with `{"Hardy"}` → `false,"already"`; `"Nope"` → `false,"unknown"`; `Prune({"Hardy","Brutal"}, {Vitality=15, Strength=30}, 5)` → `{"Hardy"}` (budget 1 drops the trailing one); `Prune({"Hardy"}, {Vitality=3}, 100)` → `{}`; `Decode("Hardy,Hardy,Bogus,Brutal")` → `{"Hardy","Brutal"}`; `Decode(nil)` and `Decode(string.rep("a", 500))` → `{}`; `Encode(Decode(x))` round-trips; `Modifier({"Hardy","Unyielding"}, "maxHealth")` ≈ 1.155; `Modifier({"Heavy Hands"→"HeavyHands"}, "damage", "Firearm")` == 1; `Modifier({}, "regen") == 0`.
- [ ] **Step 2:** Run the spec → FAIL (modules missing).
- [ ] **Step 3:** Implement both modules with the interfaces above. `Prune` and `CanEquip` use `StatConfig.Get`-free logic: stat points come from the `stats` table.
- [ ] **Step 4:** Run the spec and `tests/run.sh` → all `ok`.
- [ ] **Step 5:** Commit `Talents: config and BuildRules`.

### Task 3: Server talent state, saving and equip remote

**Files:**
- Create: `src/ServerScriptService/Talents.luau` (module), `src/ServerScriptService/TalentsServer.server.luau` (starts it, like `StatsServer.server.luau`)
- Modify: `src/ServerScriptService/PlayerStats.luau` (`TEXT_DEFAULTS` ~line 61: add `Talents = ""`; `TEXT_LENGTHS` ~line 76: `Talents = TalentConfig.MaxSaveLength`; `ResetStats` ~line 401 and `ResetProgress` ~line 414: call `Talents.Refresh`)

**Interfaces:**
- Consumes: `BuildRules.CanEquip/Prune/Encode/Decode/Modifier`, `TalentConfig`.
- Produces `Talents`: `Start()`; `Equipped(player) -> {string}`; `Refresh(player)` (decode, `Prune`, write back text, set `Talent_<key>` attributes 1/0); `Modifier(player, kind, damageStat?) -> number` (reads `Equipped`). `Talents.Refresh` also runs on the player's `Level` and each stat attribute change. A `RemoteEvent` named `EquipTalent` is created in `ReplicatedStorage` by `Talents.Start`; the server handler takes `(player, key: any, on: any)`, ignores non-string key / non-boolean `on`, rate-limits to one request per 0.3 s per player (as `ReforgeServer` does), then equips (`CanEquip`) or unequips and calls `Refresh`.

- [ ] **Step 1:** Implement `Talents` and `TalentsServer` per the interface; `PlayerStats` requires `Talents` lazily only if there is a require cycle (check; `Talents` itself must not require `PlayerStats`).
- [ ] **Step 2:** Add the `PlayerStats` text field and the `Refresh` calls on reset. `Refresh` after load happens via the attribute listeners.
- [ ] **Step 3:** Read the edits for syntax (no Luau toolchain in repo; use `luau-analyze` if installed). Commit `Talents: server state, saving and equip remote`.

### Task 4: Wire talent and stat effects

**Files:**
- Modify: `src/ServerScriptService/PlayerStats.luau` (`applyHealth` ~line 106 and the regen read: multiply max HP by `Talents.Modifier(player, "maxHealth")`, add `Talents.Modifier(player, "regen")` to `StatConfig.RegenPerSecond`; re-apply health when `Talents` change)
- Modify: `src/ServerScriptService/Damage.luau:164` (multiply by `Talents.Modifier(attacker, "damage", options.stat)` next to the stat multiplier)
- Modify: `src/ServerScriptService/Guard.luau` (`Guard.Resolve`, the `prevented` amount fed to `GuardConfig.postureAfter` ~line 104: multiply by `Talents.Modifier(target player, "postureTaken") * StatConfig.WillpowerPostureMultiplier(Willpower)` when the target is a player)
- Modify: `src/ServerScriptService/StatusEffects.luau` (the duration at ~line 61: multiply `opts.duration or effect.duration` by `Talents.Modifier(player,"statusDuration") * StatConfig.WillpowerStatusMultiplier(Willpower)` when the status lands on a player)
- Modify: `src/StarterPlayer/StarterPlayerScripts/Stamina.luau:17` (`maxFromLevel` adds `StatConfig.AgilityStamina(Agility)` plus the `Talent_<key>` sum for `staminaMax`; the client can't call the server `Talents` module, so compute from `Talent_<key>` attributes with `BuildRules`/`TalentConfig`, and refresh `Stamina.Max` when those attributes change)

**Interfaces:** Consumes `Talents.Modifier`, `StatConfig` effect functions, `BuildRules.Modifier` (client, via an `equippedFromAttributes(player)` helper local to `Stamina.luau`).

- [ ] **Step 1:** Make each edit. Keep each to a few lines; nothing may change when no talent is equipped and Agility/Willpower are 0 (every multiplier is exactly 1, adds exactly 0).
- [ ] **Step 2:** Reread each edit for syntax and nil-safety (attributes can be nil before load). Commit `Build: apply talent and Agility/Willpower effects`.

### Task 5: Stat requirements

**Files:**
- Modify: `src/ReplicatedStorage/SkillSetConfig.luau` (set entries: add `requires`), `src/ReplicatedStorage/PunchConfig.luau` (weapon entries: add `requires`), `src/ServerScriptService/SkillSetServer.server.luau` (after the mastery check ~line 269), `src/ServerScriptService/PunchCombat.server.luau` (before a swing lands/starts), `src/ServerScriptService/Loadout.luau` (`onEquip`, line 132)
- Create: `src/ServerScriptService/BuildCheck.luau` — `BuildCheck.Meets(player, requires) -> (boolean, string?)` reading the player's stat attributes into a table for `BuildRules.Meets`.

**Interfaces:** Consumes `BuildRules.Meets`. Produces `BuildCheck.Meets`. Starting values (tunable): Mandela `{ Superliminal = 10 }`, Iridescent Requiem `{ Superliminal = 20 }`, Revolver `{ Firearm = 10 }`, MandelaAxe `{ Strength = 10 }`; Fists none.

- [ ] **Step 1:** Add `requires` fields with a comment line in each config header explaining the field.
- [ ] **Step 2:** Add `BuildCheck`; in `useSkill`, `PunchCombat`, and `Loadout.onEquip`, return early when `BuildCheck.Meets` fails (equip returns the same value shape a refusal already returns; read `onEquip` first).
- [ ] **Step 3:** Reread for syntax. Commit `Stat requirements on skill sets and weapons`.

### Task 6: Stats menu UI

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/StatsMenu.client.luau` (add a Talents sub-tab beside Milestones, following how Milestones is built; list talents by stat with tier lock state, cost, equipped state, and a "Talent points: spent/total" line; clicking fires `EquipTalent:FireServer(key, not equipped)`)
- Modify: the Backpack tab (`Inventory`) or `ShopMenu` item display only where a weapon/set is shown, to show a "Needs Strength 10" badge when `requires` isn't met (text, white with dark stroke, no corners)

**Interfaces:** Consumes `TalentConfig`, `BuildRules.TierUnlocked/TalentPoints/Spent`, `Talent_<key>` attributes, `EquipTalent` remote (wait for it with `WaitForChild`).

- [ ] **Step 1:** Build the Talents sub-tab and badge; read `Hub`/`HubRules` conventions first and use `HudConfig` colours; all frames square.
- [ ] **Step 2:** Reread for syntax. Commit `Stats menu: talents and requirement badges`.

### Task 7: Docs and verification

**Files:**
- Modify: `CLAUDE.md` (Architecture: add a "Build depth" bullet naming `TalentConfig`, `BuildRules` (Lune-tested), `Talents`, `BuildCheck`, and the stat list), `docs/patch-notes/` (one entry matching the existing format)

- [ ] **Step 1:** Run `tests/run.sh` → every spec ok, exit 0.
- [ ] **Step 2:** Update the docs. Commit `Docs: build depth`.
- [ ] **Step 3:** Final message lists: new scripts needing Studio instances (`TalentConfig`, `BuildRules`, `Talents`, `TalentsServer`, `BuildCheck`), that `EquipTalent` is created by script, and this in-game checklist: stats menu shows six stats capped at 50; an old save over 50 gets points back; equip/unequip a talent at its threshold; locked tier and over-budget clicks do nothing; Reset Stats unequips locked talents; max HP, damage, posture, status duration and stamina change with talents/stats; Mandela/Revolver/axe refuse use below their requirement; badges show in menus.

## Notes for the owner

- Agility only raises max stamina for now. The spec's dodge/parry window and move speed need combat-feel changes, which belong to the next sub-project.
- Requirement numbers and the 18 talents are starting values in `TalentConfig`/the configs; tune after playtesting.
