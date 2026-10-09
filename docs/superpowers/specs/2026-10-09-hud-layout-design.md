# HUD layout pass: design

Status: approved in chat 2026-10-09; waiting on review of this written spec. Not the final visual
design, but meant to be the final **layout**.

## Intent

Give every on-screen element a clear home, end the crowding at the bottom centre and in the left
button column, stop menus stacking, make room for the UI that's coming (bounty tracker, Quests
menu, posture bar, Headhunter tag), and move the top of the screen to a minimal look. Add key
hints for the basic moves.

**Unchanged:** the HUD beside your character (StatusHUD) and everything over heads
(OverheadHealth, damage numbers).

## Top right: a row of plain icons

- One row, right-aligned, 16 px from the right and 12 px from the top: **⚙ Settings (P),
  Inventory (B), Stats (M), Quests (J)**, plus **Admin (`)** for admins. Right to left in that order
  (Settings at the far right, where the gear is now).
- **Minimal:** no background, no border; white icons (28 px) with a soft dark text stroke/shadow
  so they read on a bright sky. Hover (or touch-hold) shows a small label "Inventory  [B]" under
  the icon. All icons are full white; the one whose menu is open is slightly larger (32 px).
- **Icons:** `ImageLabel`s with asset ids from a config table (`HudConfig.Icons`). Until the
  owner picks images (Creator Store icons, or uploads with the owner's OK), each shows a text
  glyph placeholder (⚙ and short letters).
- **Yen:** plain gold text "¥12,345" (GothamBold 16, stroke) at the left end of the row, no box.
- **Rule for later UI:** anything that sits along the top of the screen follows this style
  (plain icons/text, no boxes).
- The Quests icon appears only once the quests plan is built (it opens the J menu).
- **Milestones** (the INFO button today) becomes a tab inside the Stats menu.
- **The left-middle button column is removed** (STATS, INFO, INVENTORY, ADMIN buttons and the
  yen box).
- **Kill feed:** stays top right, under the icon row (its top at 56 px), unchanged otherwise.

## Bottom left: key hints

- Plain text, no box, 16 px from the left and bottom: one line per basic move, a small white
  key cap then the move's name (GothamMedium 13, stroke):

  | Key (the player's own binding) | Move | Shown when |
  |---|---|---|
  | Q | Dash (or the set's dash name, e.g. Lightstep) | always |
  | E | Block / Parry | once the block system exists (`Keybinds` has a "Block" action) |
  | RMB | Aim | holding a set with a `ranged` move |
  | Space | Double jump | always |
  | Shift | Sprint | always |
  | Ctrl | Shift lock | always |

- Keys come from `Keybinds` (rebinds update it live); fixed keys (Space, Shift, Ctrl, RMB) are
  shown as they are.
- **Setting:** a new Preferences option `{ id = "KeyHints", label = "Key hints", section =
  "INTERFACE", default = true }`; off hides the panel.

## Bottom centre: less crowded

- The skill bar moves up **16 px** (its bottom at 116 px instead of 100), so 48 px separate it
  from the hotbar.
- The **+XP / +¥ popups** move up and right: centred at 62% / 66% height and offset 120 px right
  of centre, so they no longer share a column with the refusal text.
- Hotbar unchanged.

## Right edge

- The **bounty tracker** (quests plan) sits at the right edge, vertically centred (a home it
  gets from this pass; the quests plan places it here). The Admin panel moves to open centred
  (one-menu rule) instead of right-middle.

## Menus: one at a time

- Inventory, Stats (with Milestones), Settings, Shop, Gallery, Quests, Admin: opening one closes
  whichever is open. A shared client module **`Menus`** (`Menus.Open(name, closeFn)`,
  `Menus.Close(name)`) does it; each menu registers its close function.
- The death screen is not a menu (it shows over everything as now).

## Architecture

- **`ReplicatedStorage/HudConfig.luau`:** icon asset ids (placeholders until chosen), sizes,
  offsets used by more than one script.
- **`StarterPlayerScripts/Menus.luau`** (ModuleScript): the one-menu rule.
- **`StarterPlayerScripts/TopBar.client.luau`:** the icon row and yen; replaces the left column.
  StatsMenu, Inventory, AdminPanel lose their side buttons; Settings loses its own gear (TopBar
  draws it); each keeps its key and registers with `Menus`.
- **`StarterPlayerScripts/KeyHints.client.luau`:** the bottom-left panel.
- **Edits:** `StatsMenu` (Milestones as a tab; popups moved; no buttons/yen box),
  `Inventory`, `AdminPanel` (no side button; centred; `Menus`), `Settings` (no gear; `Menus`;
  the INTERFACE section appears from Preferences), `ShopMenu`, `PhotoGallery` (`Menus`),
  `KillFeed` (top 56 px), `SkillBar` (up 16 px), `Preferences` (KeyHints).
- The bounty tracker and the J menu (quests plan) and the posture bar (block plan) use these
  homes; those plans are updated to point here.

## Testing

- `tests/Preferences.spec.luau` passes with the new option (and covers it in Parse/Serialize).
- StyLua parse and selene.
- In-game checklist `docs/superpowers/specs/2026-10-09-hud-layout-checklist.md`: screenshots at
  1920×1080 and a small window (1280×720), plus a phone-sized emulator view in Studio, checking
  nothing overlaps.
