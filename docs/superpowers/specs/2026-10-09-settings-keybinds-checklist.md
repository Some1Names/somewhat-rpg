# Settings and keybinds: in-game test checklist

Not run in-game; this cloud session can't playtest. The Keybinds logic passed 13 unit tests in
Lune (`tests/run.sh`). Every script passed the StyLua parse check and selene's undefined-variable
check. Nothing needs adding in Studio: the new scripts make their own remote.

## The menu
- [ ] A square gear button sits at the right edge, centred vertically. Clicking it opens the
      Settings panel, and clicking it again closes it.
- [ ] P opens and closes the panel. P while typing in chat does nothing.
- [ ] × and Esc close it. The mouse is free while it's open, even in shift lock.
- [ ] The KEYBINDS list shows 9 rows: Skill 1–5, Overcharge / Flight / Undo, Dash, Reload,
      Photo Gallery. On a fresh account they read Z X C V F G Q R T.
- [ ] The output window shows no errors from Settings, SettingsServer or Keybinds.

## Rebinding
- [ ] Click Skill 1's key, press **E**. The row shows E and the status says "Skill 1 → E". Then,
      with Mandela, E casts Axe Boomerang and Z does nothing.
- [ ] Holding E shows the aim, and letting go of E casts (the aimed-skill path).
- [ ] The skill bar's first keycap shows E, and Inventory (B) lists E for Axe Boomerang.
- [ ] **Swap:** set Skill 1 to Q. Dash moves to the old key and the status says so. The Q mini
      slot (Iridescent Requiem) shows the new dash key, and both work.
- [ ] **Reserved:** while it waits, press W, P, B, Space or 1. It says "That key is reserved"
      and keeps waiting. Esc cancels, and the old key stays.
- [ ] **No accidental casts:** while a row waits for a key, pressing a key that's currently a
      skill key (e.g. X) binds it and does **not** cast that skill, dash or reload.
- [ ] Waiting for 6 s without pressing anything gives up quietly.
- [ ] Rebind Special to H: H overcharges (Mandela), flies (Iridescent) and undoes (Photoshop). The
      meter says "READY [H]" or "UNDO [H]".
- [ ] Rebind Reload to E: E reloads the Revolver. Rebind Gallery to Y: Y opens the Photoshop
      gallery.
- [ ] Long key names fit: bind something to F5, the number pad (N1) or ";". The keycap widens and
      Inventory shows it.
- [ ] RESET TO DEFAULTS: every row is back to Z X C V F G Q R T, and the keys work again.

## Saving and safety
- [ ] Rebind something, leave, and rejoin **in a live server** (Studio doesn't save). It's kept.
- [ ] Right after joining, keys work on the defaults (or the saved ones once loaded). Labels
      change to the saved keys without needing to reopen anything.
- [ ] Two rebinds within half a second: the second may be dropped by the server's throttle, and
      the rows then show what was really saved (no mismatch).
