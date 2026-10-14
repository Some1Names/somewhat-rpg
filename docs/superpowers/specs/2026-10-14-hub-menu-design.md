# Hub menu: design

One full-screen menu that holds Profile, Backpack (Inventory), Quests, Stats and Update Notes, with
locked slots for later features. Style follows the owner's references (LEGACY MEDIA / Arknights
"operator file"): grey paper, one accent colour, big black type, `#TITLE` headings, small data
microtext, square everything.

## Agreed

- Full screen: dark nav column on the left, content on the right, editorial header and footer.
- Accent = held power's colour (`SkillSetConfig` set `color`); no power = white.
- Tabs now: Profile (new home page), Backpack, Quests, Stats, Updates. Settings, Gallery, Shop,
  Reforge, Quest Board, Admin stay their own menus.
- The player's own character, posed, overlaps the layout like the illustrated characters in the
  references.

## Pieces

- **`Hub` (ModuleScript, StarterPlayerScripts)**: owns the ScreenGui (full screen, `IgnoreGuiInset`),
  the nav column, header (`#TITLE`, accent bar, `(01)` tab number, level, yen, ×), footer strip, and
  open/close. API:
  - `Hub.Tab(name, { order, title, key, locked })` → content Frame (nil for locked). Locked tabs show
    `[LOCKED]` in the nav and can't be picked.
  - `Hub.Open(name)`, `Hub.Toggle(name)`, `Hub.Close()`, `Hub.IsOpen(name)`.
  - `Hub.OnShown(name, fn)`: a tab refreshes when it's shown (the old menus refreshed on open).
  - `Hub.Accent()` / `Hub.OnAccent(fn)`: the held power's colour; `Hub.Ink(color)` gives the colour
    to draw on the paper (near-black when the accent is near-white, so white never vanishes).
  - `Hub.Badge(name, text)`: a small nav badge (Stats' unspent points, Updates' NEW).
  - To `Menus` the hub is one menu named `"Hub"`: opening Settings/Shop/etc. closes it and vice versa.
- **Keys**: B/J/M open the hub on Backpack/Quests/Stats; the open tab's key or Esc closes it; another
  tab's key switches tabs. Keys stay in each tab script (it passes `key` to `Hub.Tab`), the hub
  handles input.
- **`HubTheme` (in `HudConfig`)**: paper `#E4E4E2`, panel `#D2D2D0`, ink `#141414`, muted `#777`,
  nav `#2A2A2A`, white accent fallback; GothamBlack titles, Gotham labels, letter-spaced caps
  microtext. Decorations: thin black rules, `■■■□` swatches (accent, grey, black, light), `↖` marker
  on the selected tab, black label chips, "FILE NO." microtext. No `UICorner`.
- **Pose overlay (`HubPose` module)**: a ViewportFrame on the hub's right side, behind the content
  cards but over the paper, showing a clone of the local character (Archivable on, scripts and tools
  stripped, anchored). Poses are tables of R6 joint rotations (`Neck`, `Left/Right Shoulder`,
  `Left/Right Hip`, `RootJoint`) applied to each `Motor6D.C0`, five to start (from the owner's
  screenshots: two-arm guard, lean, wide stance, arms crossed, idle). Each tab has its pose; Profile
  picks one at random per open. Re-clones on respawn and when appearance changes; if there is no
  character yet, the frame stays empty. No animation uploads.
- **Tab scripts**: `Inventory`, `StatsMenu`, `Quests`, `UpdateNotes` keep their logic but drop their
  own ScreenGui/panel/×/key/Menus code and build into their `Hub.Tab` frame, restyled to the theme
  (dark panels → paper/panel, white text → ink, their accent colours → `Hub.Accent`/`Hub.Ink`).
  Stats' XP/level popups stay in their own ScreenGui. UpdateNotes still auto-opens once per version
  via `Hub.Open("Updates")` and still fires `SeenUpdateNotes` on close.
- **`HubProfile.client.luau` (new tab)**: held power name (big), tier chip, mastery bar, reforge
  level, level + XP, yen, unspent points, active bounty, player name chip. Reads existing attributes
  only; no server changes.
- **TopBar**: remove the Stats/Inventory/Quests icons; one Menu icon by the yen opens the hub on
  Profile and keeps the gold unspent-points number.

## Out of scope

Settings/Gallery/Shop/Reforge restyles, new features in the locked slots, animated pose transitions.

## Risks

- Inventory (985 lines) and StatsMenu (635) restyle is the bulk of the work; behaviour must stay the
  same (equip/store/drop, stat allocation, milestones).
- Panels that used `Menus.Fit` sized themselves to the screen; inside the hub they fill the content
  frame instead, so their scroll frames need a fresh look on short screens.

## Testing

Pure UI, no Lune tests. Compile check plus one smoke playtest in Studio: open each tab from its key
and the Menu icon, switch tabs, Esc, open Settings over the hub, check the accent with and without a
power, check the pose overlay appears. Owner does the full playtest.
