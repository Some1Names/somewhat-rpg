# Photoshop: in-game test checklist

Nothing here has been run: the cloud session can't playtest. Every script passed a Luau parse
check (StyLua) and a lint for undefined variables (selene). Tick each line in a playtest after the
diff is applied to Studio.

**Setup**
- Add the `Photoshop` Tool to `ServerStorage.SkillSetTools` with the attribute
  `SkillSet = "Photoshop"`.
- Admin panel: set your Photoshop mastery to 100 (SetMastery), so V and F unlock.
- Use the `Player Dummy` for single-player checks. A second player (a Studio 2-player test) is
  needed for the counters.
- The admin cooldown reset doesn't reset Undo (it has its own timer).

## Equip and UI
- [ ] Equipping Photoshop shows the bar: SNAPSHOT / PHOTO TELEPORT / DESATURATE / IRIS HORIZON /
      KALEIDOSCOPE, the passive "HISTORY", and the meter row "UNDO [G]".
- [ ] Inventory (B) details list PASSIVE History, RMB+LMB Shutter, G Undo, T Gallery.
- [ ] The Power Dealer sells Photoshop for ¥25,000 (with `OwnAllSets` on, it already shows as owned).
- [ ] The output window shows no errors from any Photoshop script, SkillSetServer or SkillEffects.

## Moves
- [ ] **Shutter**: hold right click, then left click fires a pink/blue flash beam. 3 charges, with
      the ammo slot showing them.
- [ ] **Z Snapshot**: locks onto the target nearest the mouse, deals damage, and the camera flash
      shows. You (only you) see four pink corners round the target for about 4 s.
- [ ] **Z again (Step In)**: while the corners show, you land behind the target, facing them.
- [ ] Step In with the target's back against a wall: you land in front of them instead, not in
      the wall.
- [ ] Step In on a target standing at a cliff edge (drop behind them): you land in front of them,
      or beside them at their height. Never at the bottom of the cliff.
- [ ] Step In on a flying player: you appear in the air behind them and fall. You don't land on the
      ground far below them.
- [ ] Shutter hits on a Framed target keep the corners up longer (each hit adds 1.5 s, never more
      than 4 s left).
- [ ] **X Photo Teleport**: a photo card stands where you aimed (up to 60 studs). X again pastes
      you into it. Unused, it fades after 8 s.
- [ ] Aiming X at the sky: the photo lands on the ground the aim circle showed, not nowhere.
- [ ] Aiming X off a cliff: the photo lands at the cliff bottom (within 200 studs). Over the void
      nothing happens and no cooldown is spent.
- [ ] **Z → X → X (Cut & Paste)**: Frame the dummy, pin a photo, press X again: the **dummy** is
      moved into the photo and frozen for half a second. You stay where you are.
- [ ] **C Desaturate**: a grey column (18 studs across) where you aimed. Enemies inside take ticks
      of damage and show a grey highlight and the Desaturated icon. 3 charges.
- [ ] Desaturate aimed at the sky still lands on the ground where the circle showed.
- [ ] Two Desaturates on the same spot: the grey highlight stays on, with no flicker, until the
      target leaves both or both end.
- [ ] **V Iris Horizon**: a ring of 8 photo cards round the target closes in about 1.5 s, then a
      rainbow black hole bursts (shake, crater). Big damage to the target, less to anyone near.
- [ ] Iris Horizon on a **Framed** target: the ring starts half closed and shuts almost at once.
- [ ] Iris Horizon escape: as the target (second player), dash (Q) out of the ring before it
      shuts. You take only a small hit. Walking or sprinting shouldn't escape. Re-check sprinting
      in a **live** server: lag doesn't show in Studio.
- [ ] **F Kaleidoscope**: a dome of pink/blue mirror shards around you for 5 s, with mirror hits
      on everyone inside every half second (Framed targets take two).
- [ ] **G Undo**: walk away for a few seconds, take some damage, press G. You snap back to where
      you were about 3 s ago and get half that damage back. The meter shows the 18 s recharge.
- [ ] Undo while caught in Event Horizon's pull or a knife pin: nothing happens.
- [ ] **T Gallery**: T opens a square 3-slot panel. SAVE fills a slot with your position. GO
      (after 8 s without fighting) shows a photo developing over your head for 2 s, then you're
      there.
- [ ] GO, then get hit during the 2 s: the photo spoils and you stay put.
- [ ] GO right after dealing or taking damage: nothing happens.
- [ ] SAVE while jumping or falling: nothing is saved.
- [ ] Unequip with the panel open: it closes.

## The triangle (needs two players)
- [ ] **Photoshop vs Iridescent Requiem**:
  - Desaturate on a flying Iridescent player lands him. He can't take off again or enter Prism
    Form while greyed.
  - An active Prism Form ends when the zone hits him.
  - His Luminance meter drains while he's inside.
- [ ] Iris Horizon on a flying Iridescent player knocks him down.
- [ ] Kaleidoscope: an Iridescent player inside the dome firing Light Shot or Prism Shot at you
      gets hit by his own beam instead.
- [ ] Cut & Paste a Framed flying Iridescent player into a photo on the ground: he lands there and
      is no longer flying.
- [ ] **Mandela vs Photoshop**:
  - Snapshot on a Mandela player whose Misremembered is ready: the damage lands but no Frame
    appears, and their Misremembered goes on cooldown (its effect plays).
  - A second Snapshot (passive now cooling) does frame them.
- [ ] Desaturate on a Mandela player does **not** use up his Misremembered (Desaturated takes
      nothing from him). A Snapshot right after is still forgotten.
- [ ] Take damage from Mandela, then Undo: none of Mandela's damage comes back (other damage
      still does).
- [ ] **Iridescent Requiem vs Mandela**:
  - A flying Iridescent player inside Event Horizon takes damage but isn't pulled.
  - A Tornado doesn't carry him while flying.
  - Taking off while caught drops him out of the pull or carry.

## Things that might break (from the plan's Review Focus)
- [ ] Die (or reset) while Iris Horizon is closing: the ring disappears and no burst follows.
- [ ] Die mid-Kaleidoscope or mid-Desaturate: the dome or column goes away early.
- [ ] The target dies or respawns while the ring is closing: it bursts where they were, with no
      errors.
- [ ] Die with a photo pinned: the photo goes. After respawning, X casts a new one.
- [ ] Undo just after falling off a ledge puts you back on the ledge.
- [ ] Spamming SAVE/GO causes no errors, and only one travel happens at a time.
- [ ] The gallery is kept after leaving and rejoining **in a live server** (Studio doesn't save).
- [ ] SAVE works while standing still or walking, on flat ground and on a slope, both in Studio and
      in a live server.

## Tuning notes
Iris Horizon's ring drifts after its target at 34 studs/s, just faster than a sprint (32), so
only a dash (100) or flight (40–52) gets out. All numbers are in each skill's `CONFIG` and in
`SkillSetConfig.Sets.Photoshop`.
