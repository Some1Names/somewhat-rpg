# HUD layout pass: in-game test checklist

Not run in-game yet; nothing here was compiled (no Luau toolchain on the machine that wrote it).
Spec: `2026-10-09-hud-layout-design.md`.

## Top bar
- [ ] No errors in the output on joining.
- [ ] A row of plain icons at the top right (letters or ⚙ until images are picked): Settings at the far
      right, then Inventory, Stats, Quests. No boxes or borders; readable on a bright sky.
- [ ] The yen total is gold text at the row's left end and updates when you earn or spend.
- [ ] Hovering an icon shows "Inventory  [B]" etc. under it, ending at the icon's right edge (never off screen).
- [ ] Admin icon only for admins; for a non-admin there's no gap where it would be.
- [ ] Each icon opens its menu, and again closes it; the open menu's icon is slightly larger.
- [ ] A gold number on Stats counts unspent points and disappears at 0.
- [ ] The kill feed sits under the row and doesn't overlap it.
- [ ] The left-edge buttons (STATS, INFO, INVENTORY, ADMIN, QUESTS) and the yen box are gone.

## One menu at a time
- [ ] B, M, P, J and ` each open their menu and close any other open one (try every pair).
- [ ] Opening a shop (prompt) closes an open menu; opening a menu closes the shop. Same for the
      Photoshop gallery (T).
- [ ] Closing with × or the key, then opening another, works every time (no menu stuck "open").
- [ ] Esc (Roblox menu) closes Stats, Inventory and Settings.
- [ ] Admin opens in the middle, not at the right edge.

## Stats
- [ ] Tabs STATS and MILESTONES in the header switch the content; Milestones looks the same as the old INFO.
- [ ] The Stats menu opens centred. M / the icon / × work from either tab.
- [ ] +XP appears at 62% height and +¥ at 66%, 120 px right of centre, clear of the refusal text.

## Key hints
- [ ] Bottom left: Q Dash, E Block / Parry, Space Double jump, Shift Sprint, Ctrl Shift lock.
- [ ] Rebind Dash or Block in Settings: the hint's key follows.
- [ ] With Iridescent Requiem in hand at mastery 15+, the dash line reads "Lightstep"; below 15, "Dash".
- [ ] "RMB Aim" appears only holding a set with a ranged move (Revolver, Mandela, ...).
- [ ] Settings > INTERFACE > Key hints OFF hides the panel; it stays off after rejoining.

## Screen sizes (Studio Device emulator)
- [ ] 1920×1080, 1280×720 and a phone view: icon row, kill feed, key hints, hotbar, skill bar (with its Q
      and click mini slots) and the quest tracker don't overlap; the Inventory still shrinks to fit.
- [ ] Skill bar sits 16 px higher than before, 48 px above the hotbar.
