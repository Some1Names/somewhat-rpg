# Settings sections, death screen, cast feedback: in-game test checklist

Not run in-game; this cloud session can't playtest. The `Preferences` logic passed 8 unit tests in
Lune (`tests/run.sh`, run together with the 16 keybind tests). Every script passed the StyLua
parse check and selene's undefined-variable check. Nothing needs adding in Studio.

## Settings
- [ ] Settings shows GAMEPLAY (Quick respawn: OFF) and EFFECTS (Camera shake, Flashes & impact
      frames, Damage numbers: ON) under the keybinds and RESET TO DEFAULTS.
- [ ] Clicking a toggle flips it to ON or OFF at once. Quick clicks all stick.
- [ ] **Camera shake OFF:** Event Horizon, Tornado, Iris Horizon and Solar Lance don't shake your
      screen. Turning it back ON brings the shake back.
- [ ] **Flashes OFF:** no black/white impact frames or speed lines (Mandela's V and F, Iridescent's
      F). The skills still work.
- [ ] **Damage numbers OFF:** no floating numbers on hits. The red flash and sparks still show.
- [ ] Each setting is kept after rejoining **a live server** (Studio doesn't save).
- [ ] Right after joining, effects follow the defaults, then your saved settings once loaded.

## Death screen
- [ ] Killed by another player using a set: "YOU DIED", "Killed by <Name> with <Set>", and
      "Respawning in N…" counting down to 0. It goes when you respawn.
- [ ] Killed bare-handed (punches): "Killed by <Name>".
- [ ] Killed by an NPC, a fall, or a reset with **no player hitting you in the last 15 s**: "You
      died". (A fall or reset soon after a fight credits that player, as the kill feed does.)
- [ ] The countdown matches Studio's Players.RespawnTime (5 by default). If it shows 0 or
      something odd, RespawnTime isn't reaching the client: tell me.

## Quick respawn
- [ ] With Quick respawn ON, dying respawns you almost at once: no death screen, no ragdoll.
- [ ] The killer still gets the kill feed line, the XP from an NPC kill counts as before, and
      their overcharge still refills on the kill.
- [ ] Turning Quick respawn ON while already dead changes nothing for this death (the screen and
      the normal respawn stay). The next death is instant.
- [ ] With Quick respawn ON, die, then wait about 6 s: Roblox must **not** respawn you a second
      time (only checkable in-game).

## Cast feedback
- [ ] Press a skill on cooldown: a red line above the bar says "<Skill>: Ns cooldown".
- [ ] A locked skill: "<Skill>: needs mastery N". An ultimate without overcharge (Mandela F):
      "Place Where Dream Ends: needs overcharge".
- [ ] Mandela Z while the axe is out **recalls** it, as before (no message). "axe still thrown"
      only shows in the brief moment before the recall becomes available, so don't expect to see
      it often.
- [ ] While overcharged, refusals name the slot's current form (e.g. "Spine Lash: 3s cooldown",
      not "Axe Boomerang").
- [ ] Iridescent X without enough light: "Prism Form: not enough Luminance".
- [ ] Photoshop Z or V aimed at nobody: "Snapshot: no target" / "Iris Horizon: no target", and
      nothing is cast (no cooldown spent). Dead Eye and Spine Lash still fire without a target.
- [ ] G: "Overcharge not full", "Overcharge ready in Ns", "Not enough light to fly", "Undo ready in
      Ns".
- [ ] Mashing a refused key shows one line that refreshes, not a stack. It fades after about 1 s.
- [ ] Press a refused key again just as the line is fading (about 1.3 s after the last): the new
      message shows in full and doesn't vanish at once.
