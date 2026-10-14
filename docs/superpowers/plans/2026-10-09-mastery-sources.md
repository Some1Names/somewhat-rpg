# More Ways to Earn Mastery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Who runs it:** Tasks 1–3 are code only: a **cloud session** can do them. Task 4 needs
> **Studio** (the `TrainingDummy` tag, a two-player test). Branch `claude/vigilant-rubin-ckqtnn`
> (or a fresh branch off it). Read `CLAUDE.md`.

**Goal:** Mastery also comes from damaging players (half rate, capped per victim, no repeat-kill farming), from finishing kills (half the kill XP), and from training dummies (only up to mastery 10).

**Architecture:** Pure numbers and formulas in `MasteryRules` (Lune-tested); a shared `KillRecords` for repeat kills; a cap option on `PlayerStats.AddMasteryXP`; the three sources wired into `Damage` (the hit's mastery block and the death payout) plus a player-death watch.

**Tech Stack:** Roblox Luau; Lune (`tests/run.sh`); StyLua (parse) and selene in `~/.cargo/bin`.

**Spec:** `docs/superpowers/specs/2026-10-09-mastery-sources-design.md`.

## Global Constraints

- Numbers only in `MasteryRules`: PvPShare 0.5, PvPCap 500, PvPWindow 600 s, KillShare 0.5, DummyCap 10, DummyTag "TrainingDummy"; `KillRecords.RepeatWindow` 300 s. The base rate stays `SkillSetConfig.MasteryXPPerDamage` (0.25).
- Mastery only through `PlayerStats.AddMasteryXP`.
- **`KillRecords` is shared with `2026-10-09-death-stakes.md`:** if it already exists, use it as is; if not, create it here, and that plan will use it.
- Match the surrounding style (header comments, CONFIG/constants with units, tabs).

## Review Focus

1. **Friends farming:** two players trading hits for 10 minutes earn at most 500 each from the other. After a kill, only the killer is blocked from that victim for 5 minutes (the victim can still earn from the killer). (Task 2 step.)
2. **Infinite health:** a `TrainingDummy` with `MaxHealth = math.huge` still gives mastery below 10 (counted from damage, not health lost), and `dealt` maths elsewhere doesn't produce NaN. (Task 2 step.)
3. **The cap boundary:** a big hit at mastery 9 levels to 10 and stops there, with 0 XP into 10; nothing more from dummies after. (Task 1 test + Task 2 step.)
4. **Kill credit:** the kill bonus goes to the set of the killing hit (or the held set), not whatever is held at the moment of death; no bonus with no set. (Task 2 step.)
5. **Iridescent Requiem's Prism Form XP** (`Passives.luau:31`: mastery from NPC hits passing through him) is untouched. (Task 2 step.)

---

### Task 1: MasteryRules (TDD), KillRecords and the AddMasteryXP cap

**Files:**
- Create: `src/ReplicatedStorage/MasteryRules.luau`, `tests/MasteryRules.spec.luau`
- Create if missing: `src/ServerScriptService/KillRecords.luau`
- Modify: `src/ServerScriptService/PlayerStats.luau` (~259 `AddMasteryXP`)

**Interfaces:**
- Produces: `MasteryRules.pvpXP(damage, perDamage, earnedInWindow) -> number`, `MasteryRules.killXP(killXP) -> number`, `MasteryRules.dummyXP(damage, perDamage, mastery) -> number`, and the constants; `KillRecords.Record(killer: Player, victim: Player)`, `KillRecords.IsRepeat(killer, victim) -> boolean`; `PlayerStats.AddMasteryXP(player, setName, amount, capLevel?)`.

- [ ] **Step 1:** Write `tests/MasteryRules.spec.luau` with the spec's assertions (Testing section).
- [ ] **Step 2:** `tests/run.sh`: FAIL (module missing).
- [ ] **Step 3:** Write `MasteryRules` (no Roblox types, so plain Lune runs it); `KillRecords` (weak-keyed by player, `os.clock()` times); the `capLevel` option (stop levelling at it, XP 0 there).
- [ ] **Step 4:** `tests/run.sh`: all pass.
- [ ] **Step 5:** StyLua and selene; commit `"Mastery: rules, kill records and a level cap option"`.

### Task 2: The three sources

**Files:** Modify `src/ServerScriptService/Damage.luau` (the mastery block ~133; `payOutOnDeath` ~26); create or extend a player-death watch (if `Headhunter.server.luau` exists, add it there; otherwise a short `MasteryKills.server.luau` using the KillFeed `watchCharacter` pattern and a 15 s credit).

- [ ] **Step 1:** In `Damage.Deal`: if the target is a player and the attacker has a set → A: skip if `KillRecords.IsRepeat(attacker, victim)`; add `pvpXP` given the attacker→victim total in the last `PvPWindow` (a list of `{at, xp}` per pair, trimmed). If the target's model has `DummyTag` → C: `AddMasteryXP(..., dummyXP(amount, ...), DummyCap)` using the scaled `amount`, not `dealt`. Else unchanged. Check `dealt` for an infinite-health target isn't NaN (Review Focus 2).
- [ ] **Step 2:** `payOutOnDeath`: an NPC kill (not a dummy past the cap) → B on `lastHit[humanoid].skillSet`. The player-death watch: a credited, non-repeat player kill → B from the victim's level, then `KillRecords.Record`.
- [ ] **Step 3:** Read through Review Focus 1–5 and name the line for each in the commit message.
- [ ] **Step 4:** StyLua and selene; commit `"Mastery: from PvP, kills and training dummies"`.

### Task 3: Docs and review

**Files:** Create `docs/superpowers/specs/2026-10-09-mastery-sources-checklist.md`; modify `ROADMAP.md`, `docs/superpowers/plans/README.md` (done; Studio sync lists the scripts), and `CLAUDE.md`'s Architecture line on mastery if it mentions only NPC damage.

- [ ] **Step 1:** Write them; `tests/run.sh`; commit `"Mastery sources: checklist and roadmap"`; push.
- [ ] **Step 2:** Dispatch a reviewer subagent over the diff with the spec and this Review Focus; fix what it confirms; push.

### Task 4 (Studio, local session): tag and playtest

- [ ] **Step 1:** Repo → Studio per `CLAUDE.md`.
- [ ] **Step 2:** In Studio: add the `TrainingDummy` tag (CollectionService / Tag Editor) to every training dummy and to the infinite-health dummy when it exists. **Not** to the "Player Dummy" (`KillFeedDummy`) or enemies.
- [ ] **Step 3:** Playtest with the checklist (two players for PvP). Move the `studio` tag; re-export; push.
