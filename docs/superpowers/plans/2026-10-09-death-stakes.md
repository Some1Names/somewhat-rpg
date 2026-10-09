# Death Stakes and the Headhunter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Who runs it:** Tasks 1–5 are code only: a **cloud session** can do them. Task 6 needs
> **Studio** (and a live server for saving). Branch `claude/vigilant-rubin-ckqtnn` (or a fresh
> branch off it). Read `CLAUDE.md`.

**Goal:** Dying drops 5% of your yen to your killer; the server's kill leader (3+ player kills) becomes the Headhunter, who drops 20% and pays bonus XP to whoever takes their head, which resets everyone's count.

**Architecture:** Numbers and pure rules in `HeadhunterConfig` (Lune-tested); one server script, `Headhunter`, that credits kills (the KillFeed rule), moves yen through two new `PlayerStats` functions, keeps counts and the mark (attributes), and sends extra kill-feed lines; client pieces for the head tag, the red name and the death screen's yen line.

**Tech Stack:** Roblox Luau; Lune (`tests/run.sh`); StyLua (parse) and selene in `~/.cargo/bin`.

**Spec:** `docs/superpowers/specs/2026-10-09-death-stakes-design.md` (every number and rule).

## Global Constraints

- Numbers only in `HeadhunterConfig`: DropShare 0.05, HeadhunterDropShare 0.2, MinKills 3, RepeatWindow 300 s, CreditTime 15 s, LeaveCombatWindow 600 s, BonusBase 0.2, BonusPerKill 0.05, BonusMax 0.5.
- Yen and XP only through `PlayerStats` (`TakeYen`, `AddYen`, `AddXP`); nothing writes `Yen` directly.
- Attributes: player `HeadhunterKills` (number, not saved), player `LastDeathYenLost` (number), `ReplicatedStorage` `Headhunter` (UserId or nil).
- UI square, no `UICorner`; match the KillFeed/StatusHUD look (dark square panels, Gotham).
- Match the surrounding style (header comments, CONFIG tables with units, tabs).

## Review Focus

1. **Order on leaving:** the Headhunter's leave penalty must land before `PlayerStats` saves, and never during a server shutdown. (Task 2 step.)
2. **Repeat kills:** a repeat kill gives no yen, no XP, no count, but the victim still loses yen and a Headhunter's mark still ends. (Task 1 test + Task 3 step.)
3. **Self and no-killer deaths:** a reset, a fall, an NPC, or the victim being their own last attacker give nobody anything; a Headhunter dying that way still ends the mark. (Task 3 step.)
4. **Players leaving mid-race:** a leaving non-Headhunter's count disappears and, if they were the only one ahead, the mark is re-picked correctly; a leaving killer doesn't error. (Task 3 step.)
5. **Death screen timing:** `LastDeathYenLost` is set before the client's death screen reads it (the screen already waits `CAUSE_WAIT` for the feed). (Task 4 step.)

---

### Task 1: HeadhunterConfig (pure rules, TDD)

**Files:** Create `src/ReplicatedStorage/HeadhunterConfig.luau`, `tests/HeadhunterConfig.spec.luau`.

**Interfaces:**
- Produces: the numbers above, plus `dropAmount(yen: number, isHeadhunter: boolean) -> number` (floored); `bonusXP(xpToLevel: number, headhunterKills: number) -> number` (floored); `leader(counts: {[number]: number}, reachedAt: {[number]: number}) -> number?` (userIds → kills, and the time each reached its current count; most kills ≥ MinKills, a tie goes to the earliest to reach it, which is always the current holder when there is one); `isRepeat(lastKillAt: number?, now: number) -> boolean`.

- [ ] **Step 1: Write the spec** (the `tests/Preferences.spec.luau` style): `dropAmount(0,false)==0`, `dropAmount(99,false)==4`, `dropAmount(1000,false)==50`, `dropAmount(1000,true)==200`; `bonusXP(1000,3)==200`, `bonusXP(1000,5)==300`, `bonusXP(1000,20)==500`; `leader({[1]=2,[2]=2},{[1]=1,[2]=2})==nil`; `leader({[1]=3,[2]=2},{[1]=1,[2]=2})==1`; a tie `{[1]=4,[2]=4}` with `reachedAt {[1]=10,[2]=5}` → `2`; a pass `{[1]=4,[2]=5}` with `reachedAt {[1]=1,[2]=9}` → `2`; `isRepeat(nil,1000)==false`, `isRepeat(1000-299,1000)==true`, `isRepeat(1000-301,1000)==false`.
- [ ] **Step 2:** `tests/run.sh`: FAIL (module missing).
- [ ] **Step 3:** Write the module.
- [ ] **Step 4:** `tests/run.sh`: all pass.
- [ ] **Step 5:** StyLua and selene; commit `"Headhunter: config and pure rules"`.

### Task 2: PlayerStats hooks

**Files:** Modify `src/ServerScriptService/PlayerStats.luau` (~248 next to `SpendYen`; ~393 PlayerRemoving; ~397 BindToClose).

**Interfaces:**
- Produces: `PlayerStats.TakeYen(player, share: number) -> number` (takes `math.floor(yen × share)`, never below 0, returns it; 0 while still loading); `PlayerStats.BeforeLeave(callback: (player) -> ())` (each runs, wrapped in `pcall`, in PlayerRemoving before `save(player)`, and not at all once `BindToClose` has started).

- [ ] **Step 1:** Write both; read through Review Focus 1.
- [ ] **Step 2:** StyLua and selene; commit `"PlayerStats: TakeYen and BeforeLeave"`.

### Task 3: The Headhunter server

**Files:** Create `src/ServerScriptService/Headhunter.server.luau`. Modify `src/ServerScriptService/KillFeed.server.luau` only to move its `CREDIT_TIME` to `HeadhunterConfig.CreditTime` (one source).

**Interfaces:**
- Consumes: `HeadhunterConfig`, `PlayerStats.TakeYen/AddYen/AddXP/BeforeLeave`, `Damage.LastAttacker/LastHit/OnDealt`, `StatConfig.XPToLevelUp`.
- Produces: the attributes in Global Constraints; feed messages on the existing `KillFeed` remote as `("Headhunter", kind, nameA, nameB, xp, yen)` with `kind` one of `"crowned"` (A is the Headhunter), `"taken"` (B took A's head), `"fell"` (A's mark ended another way).

- [ ] **Step 1:** Death handling per player character (the KillFeed `watchCharacter` pattern): credit, repeat check (per killer→victim last-kill time), `TakeYen` (Headhunter share if the victim holds the mark), set `LastDeathYenLost`, pay the killer unless repeat or none, count the kill, then the mark: if the victim was the Headhunter → the bonus XP (credited, non-repeat only), the feed line, end the mark and reset every `HeadhunterKills`; else re-pick with `leader` and send `"crowned"` when it starts or moves.
- [ ] **Step 2:** Studio dummies: in `RunService:IsStudio()` only, a `KillFeedDummy` killed by a player counts as a kill (no yen).
- [ ] **Step 3:** Combat times via `Damage.OnDealt` (attacker and victim's player). `BeforeLeave`: the Headhunter in combat within `LeaveCombatWindow` loses the 20% (`TakeYen`); then end the mark (`"fell"`) and reset. Any leaving player's count and repeat records are dropped; re-pick the leader.
- [ ] **Step 4:** Read through Review Focus 2–4 and name the line that handles each in the commit message.
- [ ] **Step 5:** StyLua and selene; commit `"Headhunter: dropped yen, kill counts and the mark"`.

### Task 4: The client

**Files:** Create `src/StarterPlayer/StarterPlayerScripts/Headhunter.client.luau`. Modify `KillFeed.client.luau` (draw the `"Headhunter"` messages), `OverheadHealth.client.luau` (the Headhunter's name red), `DeathScreen.client.luau` (the "−N ¥" line from `LastDeathYenLost`, hidden at 0).

- [ ] **Step 1:** Headhunter client: a red square **HEADHUNTER** BillboardGui (`AlwaysOnTop`, no max distance) on the Headhunter's head, following respawns. **No banner or kill counter on screen** (the owner turned it down).
- [ ] **Step 2:** KillFeed lines in its existing row style ("is the Headhunter", "took …'s head  +XP  +¥", "The Headhunter fell"); OverheadHealth red name; DeathScreen yen line. Read through Review Focus 5.
- [ ] **Step 3:** StyLua and selene; commit `"Headhunter: head tag, feed lines and the death screen's yen"`.

### Task 5: Docs and review

**Files:** Create `docs/superpowers/specs/2026-10-09-death-stakes-checklist.md` (each rule and Review Focus line as things to try; which need a live server); modify `ROADMAP.md`, `docs/superpowers/plans/README.md` (done; the Studio sync row lists the new scripts).

- [ ] **Step 1:** Write them; `tests/run.sh`; commit `"Headhunter: checklist and roadmap"` and push.
- [ ] **Step 2:** Dispatch a reviewer subagent over the whole diff with the spec and this Review Focus; fix what it confirms; push.

### Task 6 (Studio, local session): apply and playtest

- [ ] **Step 1:** Repo → Studio per `CLAUDE.md` (new: HeadhunterConfig, Headhunter server and client; edits to the rest).
- [ ] **Step 2:** Solo in Studio with the Player Dummy: three dummy kills give the mark and the head tag; a reset ends it ("fell").
- [ ] **Step 3:** In a live server with 2–3 players: yen moves on kills, repeat kills pay nothing, the Headhunter pays 20% and the XP bonus, leaving in and out of combat. Move the `studio` tag; re-export; push.
