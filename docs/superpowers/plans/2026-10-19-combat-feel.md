# Combat Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodge i-frames on the Q dash, quick/heavy enemy attacks with telegraphs, stamina-costed and slowing M1 swings, and block only on sets/weapons that define it.

**Architecture:** Numbers and pure rules in two new `ReplicatedStorage` modules (`CombatFeel`, `EnemyAttackConfig`), Lune-tested. Small hooks in `DashRelay`, `Damage`, `EnemyAI`, `Guard`, `Punch.client`, `Sprint.client`, `Dash.client`, `Block.client` and `SkillEffects`. Same shape as the build-depth work.

**Tech Stack:** Luau (Roblox); Lune for tests (`tests/run.sh`; Lune is not installed in the dev environment, see Global Constraints).

**Spec:** `docs/superpowers/specs/2026-10-19-combat-feel-design.md`

## Global Constraints

- Dodge window `0.15 + 0.002 * Agility` s; `DodgeGrace` 0.1 s; `DodgeRecovery` 0.35 s. Server time for `DodgeUntil` (`workspace:GetServerTimeNow()`), like `HitstunUntil`.
- Enemy attacks: quick wind-up 0.35 s, damage ×1; heavy wind-up 0.8 s, damage ×1.8, uninterruptible; `HeavyChance` 0.25, never two heavies in a row.
- Swing stamina 6 per hit, 12 for the finisher; `SwingWalkShare` 0.5. Dashing is always allowed during a swing.
- `Damage.Deal` is the only player damage path, except `EnemyAI.swingAt` which calls `TakeDamage` directly (it must check the dodge itself). `options.dot` and `options.unavoidable` ignore i-frames.
- `GuardConfig.Enabled` stays `false`; do not change `GuardConfig.cut` (its spec depends on it).
- Visual cues are placeholders only (owner makes final VFX). UI/cue code: square, no `UICorner`; match surrounding style and comment density.
- No Luau toolchain here: pure modules are verified by running the spec's checks in Studio via `execute_luau`; every edit is reread for syntax.
- New instances needed in Studio: `ReplicatedStorage.CombatFeel`, `ReplicatedStorage.EnemyAttackConfig` (ModuleScripts). No remotes are added (the `Telegraph` and `Dodge` cues go through the existing `SkillEffects`).

## Review Focus

- A dash spammed faster than the recovery must not renew i-frames or spend a charge. `CanDodge` test in Task 1, wired in Task 2.
- DoT ticks and `unavoidable` hits land during i-frames; enemy swings (which skip `Damage.Deal`) are still dodged. Task 2 checklist.
- `Choose` never returns heavy twice in a row; chance 0 never heavy; chance 1 heavy only after a quick. Task 1 tests.
- Missing or bad `HeavyChance` attribute (nil, string, negative, >1) falls back / clamps. Task 1 test.
- A character with no `block` source cannot block even if the client sends the Block remote. Task 5.

---

### Task 1: CombatFeel and EnemyAttackConfig

**Files:**
- Create: `src/ReplicatedStorage/CombatFeel.luau`, `src/ReplicatedStorage/EnemyAttackConfig.luau`, `tests/CombatFeel.spec.luau` (copy the `check`/`near` helpers and the final failure summary from `tests/BuildRules.spec.luau`; require the modules by relative path)

**Interfaces:**
- Produces `CombatFeel`: `DodgeGrace = 0.1`, `DodgeRecovery = 0.35`, `SwingWalkShare = 0.5`, `SwingStamina = 6`, `FinisherStamina = 12`;
  `DodgeWindow(agility: number?) -> number` (`0.15 + 0.002 * max(agility or 0, 0)`);
  `DodgeUntil(now: number, agility: number?) -> number` (`now + DodgeWindow + DodgeGrace`);
  `InDodge(untilTime: number?, now: number) -> boolean` (`untilTime ~= nil and now < untilTime`);
  `CanDodge(now: number, lastAcceptedAt: number?) -> boolean` (true when nil or `now - last >= DodgeRecovery`);
  `SwingCost(weapon: {swingStamina: number?, finisherStamina: number?}, finisher: boolean) -> number` (the weapon's own number, else the default).
- Produces `EnemyAttackConfig`: `Types = { quick = { windUp = 0.35, damage = 1, uninterruptible = false, color = Color3.new(1,1,1) }, heavy = { windUp = 0.8, damage = 1.8, uninterruptible = true, color = Color3.fromRGB(255, 60, 50) } }`, `HeavyChance = 0.25`, `Get(name: string) -> table?`;
  `Chance(value: any) -> number` (a number clamped to 0–1, else `HeavyChance`);
  `Choose(roll: number, chance: number, lastWasHeavy: boolean) -> "quick" | "heavy"` (heavy only when `not lastWasHeavy and roll < chance`).
  Guard `Color3` like `GuardConfig` guards `Vector3` if the spec requires it under Lune (`Color3 or require("@lune/roblox").Color3`).

- [ ] **Step 1: Write failing tests** in `tests/CombatFeel.spec.luau`: `DodgeWindow(0)` near 0.15, `(50)` near 0.25, `(nil)` near 0.15, `(-5)` near 0.15; `DodgeUntil(100, 0)` near 100.25; `InDodge(nil, 5)` false, `InDodge(10, 9.99)` true, `InDodge(10, 10)` false; `CanDodge(5, nil)` true, `CanDodge(5.2, 5)` false, `CanDodge(5.35, 5)` true; `SwingCost({}, false) == 6`, `SwingCost({}, true) == 12`, `SwingCost({swingStamina = 3}, false) == 3`; `Choose(0.1, 0.25, false) == "heavy"`, `Choose(0.1, 0.25, true) == "quick"`, `Choose(0.9, 0.25, false) == "quick"`, `Choose(0, 0, false) == "quick"`, `Choose(0.99, 1, false) == "heavy"`, `Choose(0.99, 1, true) == "quick"`; `Chance(nil) == 0.25`, `Chance("x") == 0.25`, `Chance(-1) == 0`, `Chance(5) == 1`, `Chance(0.5) == 0.5`; `Get("heavy").windUp == 0.8`, `Get("quick").uninterruptible == false`, `Get("nope") == nil`.
- [ ] **Step 2:** Run it (Lune if present; otherwise it fails by construction because the modules don't exist). Expected: FAIL.
- [ ] **Step 3:** Implement both modules per the interfaces.
- [ ] **Step 4:** Run the checks (Lune, or paste the spec's checks into a Studio `execute_luau` after the modules exist there). Expected: all `ok`.
- [ ] **Step 5:** Commit `Combat feel: CombatFeel and EnemyAttackConfig`.

### Task 2: Dodge i-frames

**Files:**
- Modify: `src/ServerScriptService/DashRelay.server.luau` (the `dashEffect.OnServerEvent` handler, after the charge checks), `src/ServerScriptService/Damage.luau` (`Damage.Deal`, next to the `Invulnerable` early-out at the top), `src/ServerScriptService/EnemyAI.server.luau` (`swingAt`, next to its `Invulnerable` check), `src/StarterPlayer/StarterPlayerScripts/Dash.client.luau` (the two places a dash starts: ~line 354 set dash, ~line 415 normal dash), `src/StarterPlayer/StarterPlayerScripts/SkillEffects/init.client.luau` (new `effects.Dodge`)

**Interfaces:**
- Consumes: `CombatFeel.CanDodge/DodgeUntil/InDodge/DodgeRecovery`.
- Produces: character attribute `DodgeUntil` (server time); `SkillEffects` kind `"Dodge"` with args `(character: Model)`.

- [ ] **Step 1:** In `DashRelay`, keep a `bucket.lastDodgeAt` (os.clock). After the charge check and before spending: if `not CombatFeel.CanDodge(now, bucket.lastDodgeAt)` return (nothing spent). On accept set `bucket.lastDodgeAt = now` and `character:SetAttribute("DodgeUntil", CombatFeel.DodgeUntil(workspace:GetServerTimeNow(), player:GetAttribute("Agility")))` (also for set dashes).
- [ ] **Step 2:** In `Damage.Deal`, return 0 when the target is a player's character with `CombatFeel.InDodge(character:GetAttribute("DodgeUntil"), workspace:GetServerTimeNow())` and neither `options.dot` nor `options.unavoidable` is set; fire `SkillEffects` `"Dodge"` for the character (first time only per window is not needed; a cue per negated hit is fine).
- [ ] **Step 3:** In `EnemyAI.swingAt`, treat a dodging target like the existing `Invulnerable` check: return without damage (also fire the `"Dodge"` cue).
- [ ] **Step 4:** In `Dash.client`, add a local `lastDashAt` and refuse to start a dash when `os.clock() - lastDashAt < CombatFeel.DodgeRecovery` (both start places), setting it when one starts. Read each place first; keep the existing charge/stamina logic untouched.
- [ ] **Step 5:** `effects.Dodge(character)`: placeholder only, like `effects.Block` (a short cyan `Shared/Sparks` burst at the character's root, `VFX.Play("Shared/Sparks", position, { color = Color3.fromRGB(120, 220, 255), scale = 0.6 })`).
- [ ] **Step 6:** Reread all edits for syntax and nil-safety. Commit `Combat feel: dodge i-frames on the dash`.

### Task 3: Enemy quick/heavy attacks and telegraphs

**Files:**
- Modify: `src/ServerScriptService/EnemyAI.server.luau` (`swingAt`, its constants block: remove `WIND_UP` once unused), `src/StarterPlayer/StarterPlayerScripts/SkillEffects/init.client.luau` (new `effects.Telegraph`)

**Interfaces:**
- Consumes: `EnemyAttackConfig.Choose/Chance/Get`.
- Produces: `SkillEffects` kind `"Telegraph"` with args `(model: Model, attackType: string, windUp: number)`.

- [ ] **Step 1:** In the per-enemy closure add `local lastWasHeavy = false`. In `swingAt`: `local attackType = EnemyAttackConfig.Choose(math.random(), EnemyAttackConfig.Chance(model:GetAttribute("HeavyChance")), lastWasHeavy)`; `lastWasHeavy = attackType == "heavy"`; `local attack = EnemyAttackConfig.Get(attackType)`; use `attack.windUp` in `task.delay`; multiply `amount` by `attack.damage`; the `staggered()` cancel only applies when `not attack.uninterruptible`.
- [ ] **Step 2:** Fire `skillEffects:FireAllClients("Telegraph", model, attackType, attack.windUp)` as the wind-up starts (next to `slashTrack:Play(0.1)`).
- [ ] **Step 3:** `effects.Telegraph(model, attackType, windUp)`: a `Highlight` parented to the model with `FillColor` from `EnemyAttackConfig.Get(attackType).color`, `FillTransparency` tweening from 0.6 to 1 over `windUp` (heavy starts at 0.35), `OutlineTransparency` 1; destroyed after `windUp`. Placeholder only; keep it within one small block.
- [ ] **Step 4:** Reread for syntax. Commit `Combat feel: quick and heavy enemy attacks with telegraphs`.

### Task 4: M1 weight

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Punch.client.luau` (`tryAttack`), `src/StarterPlayer/StarterPlayerScripts/Sprint.client.luau` (walk speed block ~line 80)

**Interfaces:**
- Consumes: `CombatFeel.SwingCost/SwingWalkShare`, `Stamina.TryConsume(amount: number) -> boolean`.
- Produces: player attribute `SwingUntil` (client clock `os.clock()`, client-only).

- [ ] **Step 1:** In `tryAttack`, once the combo count for this swing is known and before the body turns or the event fires: `if not Stamina.TryConsume(CombatFeel.SwingCost(weapon, count == PunchConfig.ComboLength)) then return end`. This must come after `count`/`lastHitAt` are computed only if a refused swing leaves them unchanged: compute the would-be count into a local first, consume, then commit `count` and `lastHitAt`. Require `Stamina` and `CombatFeel` at the top.
- [ ] **Step 2:** After a swing starts, `player:SetAttribute("SwingUntil", os.clock() + weapon.hits[count].length)`.
- [ ] **Step 3:** In `Sprint.client`, in the walk-speed block add a branch after `blocking`: when `os.clock() < (player:GetAttribute("SwingUntil") or 0)` use `WALK_SPEED * CombatFeel.SwingWalkShare` and no sprinting. A dash is unaffected (it sets its own velocity).
- [ ] **Step 4:** Reread for syntax. Commit `Combat feel: swings cost stamina and slow you`.

### Task 5: Block only with a block source

**Files:**
- Modify: `src/ServerScriptService/Guard.luau` (`Guard.Resolve`, the `blockRemote` handler, a new `Guard.CanBlock`), `src/StarterPlayer/StarterPlayerScripts/Block.client.luau` (the key-down handler), `src/ReplicatedStorage/GuardConfig.luau` (header comment only)

**Interfaces:**
- Produces: `Guard.CanBlock(character: Model) -> boolean` (`ownBlock(character) ~= nil`).

- [ ] **Step 1:** In `Guard.Resolve`, after the `Blocking` check, `if not ownBlock(target) then return amount end` (no base `Cuts` fallback). In the `blockRemote` handler, `down == true` is ignored unless `Guard.CanBlock(character)`.
- [ ] **Step 2:** In `Block.client`, before firing `blockRemote:FireServer(true)`, return unless the held set or weapon has a `block` table: `SkillSetConfig.Equipped(character)` then `SkillSetConfig.Sets[setName].block`, else `PunchConfig.WeaponFor(character)` then `weapon.block` (mirror `Guard`'s `ownBlock`).
- [ ] **Step 3:** Update `GuardConfig`'s header comment: block belongs only to a set or weapon with its own `block` table; fists and the base kit cannot block; `Enabled` is still off.
- [ ] **Step 4:** Reread for syntax; `GuardConfig.cut` unchanged. Commit `Block only with a set or weapon block table`.

### Task 6: Docs and verification

**Files:**
- Modify: `CLAUDE.md` (Architecture: a "Combat feel" bullet naming `CombatFeel`, `EnemyAttackConfig`, the dodge attribute, and that block needs a `block` table)

- [ ] **Step 1:** Run all pure checks (Lune `tests/run.sh` if available; otherwise in Studio via `execute_luau` for `CombatFeel.spec`, plus the earlier `BuildRules` checks). Expected: all `ok`.
- [ ] **Step 2:** Update `CLAUDE.md`. Commit `Docs: combat feel`.
- [ ] **Step 3:** Final message lists the new Studio modules and this in-game checklist: a dash negates a hit (enemy swing and a skill) during its first moments and a hit just after still lands; spamming Q is capped by the recovery; Agility makes the window longer; DoT still ticks during a dash; enemies sometimes wind up slowly with a red flash and hit harder, never twice in a row; a heavy cannot be staggered out of, a quick can; swings cost stamina and stop when you are out; walking slows during a swing; dashing mid-swing works; E/Alt does nothing with fists; a set with a `block` table (none yet) is the only way to block.

## Notes for the owner

- Block is inert until a set or weapon gets a `block = { melee =, ranged =, skill = }` table and `GuardConfig.Enabled` is turned back on.
- Telegraph and dodge cues are placeholders; swap `effects.Telegraph` / `effects.Dodge` for your VFX.
- Numbers (window, wind-ups, damage, stamina) are starting values for you to tune after playtesting.
