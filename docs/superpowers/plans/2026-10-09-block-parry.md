# Block, Parry and Posture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Who runs it:** Tasks 1–8 are code only: a **cloud session** can do them. Task 9 needs
> **Studio**. Branch `claude/vigilant-rubin-ckqtnn` (or a fresh branch off it). Read `CLAUDE.md`.

**Goal:** Give every player a base defence on E: a front block that cuts damage by hit kind, a 0.25 s parry that staggers the attacker, and a posture bar that guard-breaks, with the bars on the HUD and over every health bar.

**Architecture:** Shared numbers and pure rules in `GuardConfig` (Lune-tested); a server `Guard` module that owns the state (character attributes) and resolves every hit on a player through `Guard.Resolve`, called from `Damage.Deal` and EnemyAI's swing; existing skills tagged with `options.guard`; a shared `ActionLock` for "can't act right now"; a client `Block` script for E and the prompt rule; HUD bars and placeholder effects.

**Tech Stack:** Roblox Luau; Lune (`tests/run.sh`); StyLua (parse check) and selene in `~/.cargo/bin`.

**Spec:** `docs/superpowers/specs/2026-10-09-block-parry-design.md` (all numbers and names).

## Global Constraints

- Numbers live only in `GuardConfig`: cuts melee 0.6, ranged 0.5, skill 0.3, unblockable 0; front = within 90° (`dot > 0`, flat); parry window 0.25 s; parry lock 0.5 s; stagger 0.6 s; parry posture +30; posture max 100; guard-break stun 1 s; block lockout 2 s; drain 20/s after 1.5 s unblocked, 5/s while blocking unhit for 1.5 s; `CombatTime` 5 s.
- Character attributes (server-written): `Blocking` (bool), `Posture` (number), `GuardBrokenUntil`, `HitstunUntil` (server time, also used by EnemyAI already), `LastCombatAt` (server time).
- Damage still only through `Damage.Deal` (`CLAUDE.md`); `Guard.Resolve` never deals damage, it only returns the amount to deal.
- Visuals: client only; `Guard/<Name>` prefabs first (`VFX.Find`), `Shared/*` stand-ins otherwise. UI square, no `UICorner`.
- Match the surrounding style (header comments, CONFIG tables with units, tabs, existing helpers).

## Review Focus

1. **Latency:** the parry window is timed by when the press **reaches the server**; a hit the attacker's server lands 0.2 s after a press that arrived is parried. Check nothing compares client and server clocks. (Task 3 step.)
2. **Multi-hit moves and damage over time:** a parry eats every hit of one move inside its window, but Burnt/Bleeding ticks (`dot`) are never parried, blocked or counted as combat for posture. (Task 3 step.)
3. **Stuck states:** dying, respawning, unequipping or leaving while blocking, staggered or guard-broken leaves no `Blocking`/stun on the next life, and the walk speed and stamina row come back. (Tasks 3, 5 steps.)
4. **The shop prompt:** out of combat E opens the shop and doesn't block; in combat the prompt is hidden and E blocks; it reappears 5 s after the last hit. (Task 5 step.)
5. **Unblockable and behind:** ultimates, grabs and any hit from behind go straight through a block (full damage, no posture), but a parry from the front still stops an ultimate. (Task 4 step.)

---

### Task 1: GuardConfig (pure rules, TDD) and the Block keybind

**Files:**
- Create: `src/ReplicatedStorage/GuardConfig.luau`, `tests/GuardConfig.spec.luau`
- Modify: `src/ReplicatedStorage/Keybinds.luau` (add `{ id = "Block", label = "Block / Parry", default = "E" }` after Dash; header comment lists it)

**Interfaces:**
- Produces: `GuardConfig` numbers (named `Cuts = { melee, ranged, skill, unblockable }`, `ParryWindow`, `ParryLock`, `StaggerTime`, `ParryPosture`, `MaxPosture`, `BreakStun`, `BreakLockout`, `DrainDelay`, `DrainRate`, `BlockingDrainRate`, `CombatTime`, `BlockWalkShare = 0.5`), plus:
  - `GuardConfig.isFront(look: Vector3, toSource: Vector3) -> boolean` (flat; a zero `toSource` counts as front)
  - `GuardConfig.cut(kind: string, override: {[string]: number}?) -> number` (0 for unknown kinds and `"unblockable"`)
  - `GuardConfig.postureAfter(posture: number, prevented: number) -> (number, boolean)` (new posture capped at `MaxPosture`, and whether it broke)
  - `GuardConfig.drain(posture: number, sinceLast: number, blocking: boolean, dt: number) -> number`
  - The first line `local Vector3 = Vector3 or require("@lune/roblox").Vector3` (works in both, as in the Aido plan).

- [ ] **Step 1: Write `tests/GuardConfig.spec.luau`** (the `tests/Preferences.spec.luau` style). Assertions: `isFront` true at 0° and 89°, false at 91° and 180°, ignoring height; `cut("melee") == 0.6`, `cut("ranged") == 0.5`, `cut("skill") == 0.3`, `cut("unblockable") == 0`, `cut("melee", { melee = 0.9 }) == 0.9`, `cut("skill", { melee = 0.9 }) == 0.3`; `postureAfter(90, 18)` returns `100, true`; `postureAfter(10, 18)` returns `28, false`; `drain(50, 1, false, 1) == 50` (too soon), `drain(50, 2, false, 1) == 30`, `drain(50, 2, true, 1) == 45`, `drain(3, 2, false, 1) == 0`.
- [ ] **Step 2:** `tests/run.sh`: the new spec FAILS (module missing); Keybinds' still passes.
- [ ] **Step 3:** Write `GuardConfig.luau`; add the keybind.
- [ ] **Step 4:** `tests/run.sh`: all pass.
- [ ] **Step 5:** StyLua and selene; commit `"Block: GuardConfig rules and the E keybind"`.

### Task 2: ActionLock

**Files:**
- Create: `src/ReplicatedStorage/ActionLock.luau`
- Modify: the six `Rewinding` checks (`grep -rn Rewinding src`): SkillSetServer, RangedServer, PunchCombat, SkillBar (`activeSet`), Ranged (`heldSet`), Punch (`tryAttack`)

**Interfaces:**
- Produces: `ActionLock.Locked(character: Model?) -> boolean`: true while `Rewinding`, `Blocking`, or `HitstunUntil > workspace:GetServerTimeNow()`. (Players gain `HitstunUntil` from Task 3; NPCs already have it.)

- [ ] **Step 1:** Write it; replace each `character:GetAttribute("Rewinding")` with `ActionLock.Locked(character)` (update their comments).
- [ ] **Step 2:** StyLua and selene; commit `"ActionLock: one check for rewinding, blocking and stuns"`.

### Task 3: Guard (server) and the Damage / EnemyAI hooks

**Files:**
- Create: `src/ServerScriptService/Guard.luau`
- Modify: `src/ServerScriptService/Damage.luau` (`options.guard` documented with the others ~85; call `Guard.Resolve` for player targets before `Passives.Absorb`; stamp `LastCombatAt` on the target's and attacker's characters, not for `dot`), `src/ServerScriptService/EnemyAI.server.luau` (~186: `Guard.Resolve(victim.Character, amount, "melee", ownRoot.Position, model)` before `Passives.Absorb`; `LastCombatAt` on the victim)

**Interfaces:**
- Produces: `Guard.Resolve(target: Model, amount: number, kind: string, source: Vector3?, attacker: Model?) -> number`; the RemoteEvent `ReplicatedStorage.Block` (made here; client sends `true` on press, `false` on release); SkillEffects `"Block"(character, point)`, `"Parry"(character, attacker)`, `"GuardBreak"(character)`.
- Consumes: `GuardConfig`, `SkillSetConfig.Equipped` and `PunchConfig.WeaponFor` (for a `block` override).

- [ ] **Step 1:** The remote: a press sets `Blocking` (unless `GuardBrokenUntil` is ahead or he's dead/`ActionLock`ed by a stun) and, unless parry-locked, records `parryUntil = now + ParryWindow` for that character; when that time passes with no parry, set `parryLockedUntil = now + ParryLock`. A release clears `Blocking`. Throttle like SettingsServer's remotes (ignore presses closer than 0.05 s).
- [ ] **Step 2:** `Resolve`: `kind == nil` (dot) → `amount`. Front check with `source` (none → front). Parry if front and `now <= parryUntil` → mark parried (no lock), fire `Parry`, stagger the attacker (`HitstunUntil = now + StaggerTime`, posture + `ParryPosture` with its own break check) → 0. Else if `Blocking` and front → `cut` with the equipped override, add the prevented amount as posture, fire `Block`, break if full (`Blocking` off, `HitstunUntil = now + BreakStun`, `GuardBrokenUntil = now + BreakStun + BreakLockout`, posture 0, `GuardBreak`) → reduced amount. Else → `amount`.
- [ ] **Step 3:** The drain loop (0.1 s): `GuardConfig.drain` per character with posture, tracking the last block-hit time. Clear everything on `Humanoid.Died` and character removal.
- [ ] **Step 4:** Damage and EnemyAI hooks. Read through Review Focus 1–3 and write down, in the commit message, the line that handles each.
- [ ] **Step 5:** StyLua and selene; commit `"Guard: block, parry, posture and guard break on the server"`.

### Task 4: Tag existing moves

**Files:** `Skills/KnifeThrow`, `LightShot`, `Shutter`, `RevolverShot` (`guard = "ranged"` in their DAMAGE_OPTIONS); `Skills/PlaceWhereDreamEnds`, `AboveTheClouds`, `Kaleidoscope`, `SpineLash`, `BlackHole`, `Tornado` (`guard = "unblockable"`); `docs/superpowers/plans/2026-10-09-aido.md` (Global Constraints: Fuse and Atomic Breath `"ranged"`, Final Cut's roar and Collapse `"unblockable"`).

- [ ] **Step 1:** Add the tags to every options table the module passes to `Damage.Deal`. Leave the `StatusEffects.Apply` options alone: their ticks arrive as `dot` and skip the guard.
- [ ] **Step 2:** `grep -rn "Damage.Deal" src/ServerScriptService` and list any caller left on the default, to confirm each default is right (melee → "melee", else "skill"). Note them in the commit message.
- [ ] **Step 3:** StyLua and selene; commit `"Block: tag ranged, ultimate and grab damage"`.

### Task 5: The client: E, the prompt rule and walk speed

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/Block.client.luau`
- Modify: `src/StarterPlayer/StarterPlayerScripts/Sprint.client.luau` (~62: half speed and no sprint while `Blocking` or staggered, 0 while guard-broken), `src/StarterPlayer/StarterPlayerScripts/Dash.client.luau` (a dash sends `Block false` first)

- [ ] **Step 1:** Block: `Keybinds.Key("Block")` down → `Block:FireServer(true)`, up → `false`; skip when `gameProcessed`, `Keybinds.Capturing()`, or a prompt is shown (`ProximityPromptService.PromptShown`/`PromptHidden` count). Release on death and respawn.
- [ ] **Step 2:** Prompts: every ProximityPrompt in workspace (and added later) gets `Enabled = false` locally while `LastCombatAt` on your character is within `CombatTime`, and back afterwards. Read through Review Focus 4.
- [ ] **Step 3:** The block pose: if `ReplicatedStorage.CombatAnimations.Block` exists, play it (looped, Action priority) while `Blocking`.
- [ ] **Step 4:** StyLua and selene; commit `"Block: E on the client, prompts hide in combat, walk speed"`.

### Task 6: The bars

**Files:** `src/StarterPlayer/StarterPlayerScripts/StatusHUD.client.luau` (the stamina row ~157), `src/StarterPlayer/StarterPlayerScripts/OverheadHealth.client.luau`

- [ ] **Step 1:** StatusHUD: while your character's `Blocking` is on (and for 1 s after a guard break), hide the stamina boxes and show one white bar the stamina row's width filled by `Posture / MaxPosture`; red flash and a quick shake of the bar on `GuardBrokenUntil` changing. Update the header comment.
- [ ] **Step 2:** OverheadHealth: a thin white bar (3 px) under the HP boxes, shown while `Posture > 0`, red while `HitstunUntil` or `GuardBrokenUntil` is ahead. Update the header comment.
- [ ] **Step 3:** StyLua and selene; commit `"Block: posture bars on the HUD and over health bars"`.

### Task 7: Effects

**Files:** `src/StarterPlayer/StarterPlayerScripts/SkillEffects/init.client.luau` (`effects.Block`, `effects.Parry`, `effects.GuardBreak`)

- [ ] **Step 1:** `Block`: `Guard/Block` else `Shared/Sparks` (small, white) at the point. `Parry`: `Guard/Parry` else a white `flash` + `ring` at the parrier and `Shared/Impact` on the attacker; `VFX.ImpactFrameNear` for the two involved (respects Flashes). `GuardBreak`: `Guard/GuardBreak` else `Shared/BigImpact` tinted red and `VFX.Shake` "Light" near it.
- [ ] **Step 2:** StyLua and selene; commit `"Block: placeholder effects"`.

### Task 8: Docs and review

**Files:** Create `docs/superpowers/specs/2026-10-09-block-parry-checklist.md` (every rule in the spec and each Review Focus line, as things to try, with two players where needed); modify `ROADMAP.md`, `docs/superpowers/plans/README.md` (this plan done, Studio sync row lists the new scripts).

- [ ] **Step 1:** Write them; `tests/run.sh`; commit `"Block: checklist and roadmap"` and push.
- [ ] **Step 2:** Dispatch a reviewer subagent over the whole diff with the spec and this Review Focus; fix what it confirms; push.

### Task 9 (Studio, local session): apply and playtest

- [ ] **Step 1:** Repo → Studio per `CLAUDE.md` (new: GuardConfig, ActionLock, Guard, Block; edits to the rest).
- [ ] **Step 2:** Optional, **with the owner's OK** before uploading: a `Block` pose animation in `ReplicatedStorage.CombatAnimations`.
- [ ] **Step 3:** Playtest with the checklist; two-player tests in a Studio 2-player server (Test → Clients and Servers). Move the `studio` tag; re-export; push.
