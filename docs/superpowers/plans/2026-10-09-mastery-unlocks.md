# Mastery Unlocks per Power Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Who runs it:** Tasks 1–4 are code only: a **cloud session** can do them. Task 5 needs
> **Studio**. Branch `claude/vigilant-rubin-ckqtnn` (or a fresh branch off it). Read `CLAUDE.md`.

**Goal:** Each power gets its own skill unlock levels, and its passive, G feature, dash and gallery unlock through mastery too, with the same locked/unlocked feedback skills already have.

**Architecture:** `mastery` fields on the feature tables in `SkillSetConfig` plus one helper, `FeatureUnlocked`; every server system that runs a feature checks it (the authority), and the client scripts mirror it for refusals, the meter, the inventory and level-up popups.

**Tech Stack:** Roblox Luau; StyLua (parse) and selene in `~/.cargo/bin`; `tests/run.sh` must still pass.

**Spec:** `docs/superpowers/specs/2026-10-09-mastery-unlocks-design.md` (the unlock table and every locked behaviour).

## Global Constraints

- The numbers live only in `SkillSetConfig` (the spec's table). A feature table without `mastery` is on from 1. The `ranged` table and `form` tables never get a `mastery` field.
- One check everywhere: `SkillSetConfig.FeatureUnlocked(player, setName, feature)`. No script compares mastery numbers itself.
- Server checks decide; client checks only give feedback (a hacked client can't use a locked feature).
- Match the surrounding style; update header comments where behaviour changes.

## Review Focus

1. **Locked dash falls back to the normal dash**, on both Dash.client and DashRelay; a locked Lightstep never leaves a player with no dash. (Task 3 step.)
2. **Overcharge locked mid-fight can't happen backwards:** mastery only rises, but the admin mastery setter can lower it; a player overcharged when their mastery is set below the unlock keeps the current overcharge until it ends, and nothing errors. (Task 2 step.)
3. **History and Undo:** below 15, PhotoshopServer records no samples, Undo refuses, and the skill bar's Undo meter shows the lock, not a ready Undo. (Task 2 step.)
4. **Luminance at 1:** Iridescent Requiem at mastery 1 still gathers light, uses Light Shot and (at 10) Prism Form; only flight and Lightstep wait. (Task 2 step.)
5. **The gallery waypoints** hide below 30, and T does nothing. (Task 3 step.)

---

### Task 1: Config and the helper

**Files:** Modify `src/ReplicatedStorage/SkillSetConfig.luau` (header comment ~48–105: document `mastery` on features; the numbers in each set; the helpers after `MasteryXPAttribute` ~422).

**Interfaces:**
- Produces: `SkillSetConfig.FeatureMastery(set, feature: string) -> number` (`set[feature] and set[feature].mastery or 1`), `SkillSetConfig.FeatureUnlocked(player, setName, feature) -> boolean` (false with no such table).

- [ ] **Step 1:** Add the fields and new skill levels from the spec's table (Mandela, IridescentRequiem, Photoshop, Revolver; Aido's go in the Aido plan's config step, Step 2 below).
- [ ] **Step 2:** If Aido is already built (`SkillSetConfig.Sets.Aido` exists): give Half-Life `mastery = 10` and its overcharge `mastery = 25`, and make `AidoUtil` skip Fallout and the Burnt bonus while `FeatureUnlocked(player, "Aido", "passive")` is false. If it isn't built, skip this: the Aido plan does it.
- [ ] **Step 3:** StyLua and selene; commit `"Mastery unlocks: per-power levels and feature fields"`.

### Task 2: Server gates

**Files:** `Passives.luau` (`Absorb` ~78), `Overcharge.luau` (`AddDamage` ~66, `AddTaken` ~82, `Activate` ~56), `LuminanceServer.server.luau` (take-off ~84), `PhotoshopServer.server.luau` (sampling loop, Undo remote, Gallery remote).

- [ ] **Step 1:** Each gate returns early when `FeatureUnlocked` is false (Absorb returns `amount`; AddDamage/AddTaken add nothing; Activate returns false; take-off refuses; sampling skips the player; the remotes ignore the request).
- [ ] **Step 2:** Read through Review Focus 2–4 and name the line for each in the commit message.
- [ ] **Step 3:** StyLua and selene; commit `"Mastery unlocks: server gates"`.

### Task 3: Client gates and the dash fallback

**Files:** `Dash.client.luau` (~279: the set's dash only when unlocked), `DashRelay.server.luau` (~47: a set dash request when locked is refused; the normal dash path is unchanged), `Flight.client.luau` (~28), `PhotoGallery.client.luau` (`gallerySet`: nil when locked, so the panel and waypoints hide).

- [ ] **Step 1:** The four changes. Read through Review Focus 1 and 5.
- [ ] **Step 2:** StyLua and selene; commit `"Mastery unlocks: dash, flight and gallery on the client"`.

### Task 4: Feedback and docs

**Files:** `SkillBar.client.luau` (`tryOvercharge` ~552: refusal "<name>: needs mastery N" for overcharge, flight and undo; the meter ~665: a "MASTERY N" label in place of the stacks/Luminance/Undo when locked; the level-up popups ~928: also for features that unlock at the new level), `Inventory.client.luau` (the feature rows ~548: "Mastery N" when locked). Create `docs/superpowers/specs/2026-10-09-mastery-unlocks-checklist.md`; update `ROADMAP.md`, `docs/superpowers/plans/README.md`.

- [ ] **Step 1:** The UI changes; the checklist (step each set through its levels with the admin mastery setter; each locked behaviour from the spec).
- [ ] **Step 2:** StyLua and selene; `tests/run.sh`; commit `"Mastery unlocks: feedback, checklist and roadmap"`; push.
- [ ] **Step 3:** Dispatch a reviewer subagent over the diff with the spec and this Review Focus; fix what it confirms; push.

### Task 5 (Studio, local session): apply and playtest

- [ ] **Step 1:** Repo → Studio per `CLAUDE.md`.
- [ ] **Step 2:** Playtest with the checklist (the admin panel's mastery setter makes it quick). Move the `studio` tag; re-export; push.
