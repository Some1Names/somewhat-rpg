# HUD Layout Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Who runs it:** Tasks 1–5 are code only: a **cloud session** can do them. Task 6 needs
> **Studio** (screenshots at several sizes; icon images with the owner). Branch
> `claude/vigilant-rubin-ckqtnn` (or a fresh branch off it). Read `CLAUDE.md`.

**Goal:** A minimal top-right icon row (Settings, Inventory, Stats, Quests, Admin, yen) replacing the left button column, key hints at the bottom left (with a setting), more room at the bottom centre, and one menu open at a time.

**Architecture:** Shared numbers and icon ids in `HudConfig`; a `Menus` module for the one-menu rule; two new client scripts (`TopBar`, `KeyHints`); the existing menus lose their own buttons and register with `Menus`; a `KeyHints` preference.

**Tech Stack:** Roblox Luau; Lune (`tests/run.sh`); StyLua (parse) and selene in `~/.cargo/bin`.

**Spec:** `docs/superpowers/specs/2026-10-09-hud-layout-design.md` (every position and rule).

## Global Constraints

- **Unchanged:** StatusHUD and OverheadHealth (and damage numbers).
- Top-of-screen UI: no background, no border, no `UICorner`; white with a dark stroke. Other UI stays square.
- Positions and sizes from the spec, kept in `HudConfig` when more than one script uses them.
- Icon images: placeholder text glyphs until the owner picks assets; **no uploads without the owner's OK**.
- Every menu keeps its key (B, M, P, J, `, T) and its close button.
- Match the surrounding style (header comments, tabs, `make`/`label` helpers as each script has them).

## Review Focus

1. **One menu at a time across every way in:** keys, icons, the shop's prompt, the gallery's T, Esc; closing via × or Esc leaves `Menus` consistent so the next open works. (Task 1 + Task 3 steps.)
2. **Small screens:** at 1280×720 and a phone emulator, the icon row, kill feed, key hints, hotbar, skill bar (with its Q/click mini slots) and tracker don't overlap; the Inventory still shrinks to fit. (Task 6.)
3. **Admins vs not:** the Admin icon shows only with `IsAdmin`, and non-admins see no gap where it would be. (Task 2 step.)
4. **Key hints follow rebinds and the set in hand** (RMB Aim only with a ranged move; the set's own dash name; E only once a "Block" action exists in `Keybinds`). (Task 4 step.)
5. **The Milestones content** is unchanged, just reached as a Stats tab. (Task 3 step.)

---

### Task 1: HudConfig, Menus and the KeyHints preference

**Files:** Create `src/ReplicatedStorage/HudConfig.luau`, `src/StarterPlayer/StarterPlayerScripts/Menus.luau`; modify `src/ReplicatedStorage/Preferences.luau` (the option, header comment) and `tests/Preferences.spec.luau` (the option defaults on, parses, serializes).

**Interfaces:**
- Produces: `HudConfig.Icons = { Settings, Inventory, Stats, Quests, Admin }` (each `{ image = "" , glyph = "⚙" / "B" / ... }`), `HudConfig.TopMargin = 12`, `HudConfig.EdgeMargin = 16`, `HudConfig.IconSize = 28`, `HudConfig.KillFeedTop = 56`; `Menus.Open(name: string, close: () -> ())` (closes the open one first), `Menus.Close(name)`, `Menus.IsOpen(name) -> boolean`.

- [ ] **Step 1:** Preferences test first (FAIL), then the option (PASS) with `tests/run.sh`.
- [ ] **Step 2:** `HudConfig`, `Menus`.
- [ ] **Step 3:** StyLua and selene; commit `"HUD: HudConfig, Menus and the Key hints setting"`.

### Task 2: The top bar

**Files:** Create `src/StarterPlayer/StarterPlayerScripts/TopBar.client.luau`; modify `Settings.client.luau` (remove its gear button; expose opening through a BindableEvent or `Menus` so TopBar can toggle it), `KillFeed.client.luau` (top at `HudConfig.KillFeedTop`).

- [ ] **Step 1:** The row (right to left: Settings, Inventory, Stats, Quests if `ReplicatedStorage:FindFirstChild("Quest")` exists, Admin if `IsAdmin`), the gold yen text at its left end (from the `Yen` attribute), hover labels, the larger icon for the open menu. Each icon toggles its menu the same way its key does.
- [ ] **Step 2:** Read through Review Focus 3.
- [ ] **Step 3:** StyLua and selene; commit `"HUD: the top-right icon row and yen"`.

### Task 3: The menus

**Files:** `StatsMenu.client.luau` (remove the STATS/INFO buttons and yen box; Milestones as a tab in the Stats panel; the +XP/+¥ popups to 62%/66% height, 120 px right of centre), `Inventory.client.luau` and `AdminPanel.client.luau` (remove side buttons; Admin opens centred), `ShopMenu.client.luau`, `PhotoGallery.client.luau`, `Settings.client.luau` (all: `Menus.Open/Close`).

- [ ] **Step 1:** The edits. For a menu that toggles itself (keys, ×, Esc), call `Menus.Close(name)` when it closes so the state stays right.
- [ ] **Step 2:** Read through Review Focus 1 and 5.
- [ ] **Step 3:** StyLua and selene; commit `"HUD: menus open one at a time; no side buttons; Milestones in Stats"`.

### Task 4: Key hints and the bottom centre

**Files:** Create `src/StarterPlayer/StarterPlayerScripts/KeyHints.client.luau`; modify `SkillBar.client.luau` (the bar up 16 px).

- [ ] **Step 1:** KeyHints per the spec's table: `Keybinds.Text("Dash")` and the set's `dash.name` when it has one; "Block / Parry" only if `Keybinds` has a `Block` action; RMB Aim only with a ranged move in hand; fixed keys as text. Updates on `Keybinds` changes, equip/unequip, and the `KeyHints` preference.
- [ ] **Step 2:** Read through Review Focus 4.
- [ ] **Step 3:** StyLua and selene; commit `"HUD: key hints and a less crowded bottom centre"`.

### Task 5: Docs, other plans, review

**Files:** Create `docs/superpowers/specs/2026-10-09-hud-layout-checklist.md`; modify `ROADMAP.md`, `docs/superpowers/plans/README.md`, `CLAUDE.md` (Client UI list: TopBar, KeyHints, Menus; the "top-of-screen UI is plain icons" rule under the owner's preferences), and point the other plans at the new homes: `2026-10-09-quests.md` (tracker at the right edge, vertically centred; the J menu registers with `Menus`; its icon in the top bar), `2026-10-09-block-parry.md` (no layout change needed; the shop prompt still uses E).

- [ ] **Step 1:** Write them; `tests/run.sh`; commit `"HUD: checklist, docs and the other plans"`; push.
- [ ] **Step 2:** Dispatch a reviewer subagent over the diff with the spec and this Review Focus; fix what it confirms; push.

### Task 6 (Studio, local session)

- [ ] **Step 1:** Repo → Studio per `CLAUDE.md`.
- [ ] **Step 2:** Screenshots at 1920×1080, 1280×720 and a phone emulator (Studio's Device emulator); fix overlaps found (Review Focus 2).
- [ ] **Step 3:** With the owner: pick icon images (Creator Store, or uploads **with their OK**) and put the ids in `HudConfig.Icons`.
- [ ] **Step 4:** Playtest with the checklist. Move the `studio` tag; re-export; push.
