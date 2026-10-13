# Block and posture: in-game test checklist

Not run in-game. `tests/run.sh` (Lune) passes GuardConfig's rules (front/behind, cuts, posture,
draining); everything else needs Studio. Parry was dropped from this version (see the spec's status
line), so there is nothing to test for it. Two players are needed for the overhead bars and PvP
hits; a Studio 2-player server (Test → Clients and Servers) does.

## E and the controls
- [ ] Settings → KEYBINDS shows 10 rows, with **Block** (E) after Dash. Rebinding it works; the old
      key stops blocking.
- [ ] Hold E: your character walks at half speed, can't sprint, and can't punch, shoot or cast
      (the skill bar refuses). Let go: everything works again at once.
- [ ] Dash while blocking drops the block and dashes.
- [ ] Typing in chat, or Settings waiting for a key, never blocks.
- [ ] If `ReplicatedStorage.CombatAnimations.Block` exists, it plays while blocking and stops after.

## The shop prompt (Review Focus 3)
- [ ] Out of combat, next to the Power Dealer, E opens the shop and does **not** block.
- [ ] Hit a dummy (or get hit): within 0.25 s the shop prompt disappears; pressing E blocks.
- [ ] 5 s after the last hit the prompt is back, and E opens the shop again.
- [ ] Clicking the prompt still works when it's visible.

## Blocking (the front, the cuts)
Use a second player, or an enemy with `FightsBack`, to hit you.
- [ ] A melee hit from the front while blocking does about 40% of normal damage.
- [ ] A Knife / Light Shot / Shutter / Revolver shot from the front does about 50%.
- [ ] A skill (e.g. Refraction Field, Solar Lance, Axe Boomerang) from the front does about 70%.
- [ ] From behind, or from the side past 90°, everything does full damage, with no spark.
- [ ] **Unblockable (Review Focus 4):** the ultimates (Place Where the Dream Ends, Above the
      Cumulonimbus, Kaleidoscope) and the grabs (Spine Lash, Black Hole, Tornado) do full damage
      through a front block and add no posture.
- [ ] **Damage over time (Review Focus 1):** Burnt / Bleeding ticks while blocking are not cut, add no
      posture and don't hide the shop prompt.
- [ ] A small white spark shows where a block takes a hit.
- [ ] An enemy's swing is cut like a melee hit.

## Posture and guard break
- [ ] While blocking, your stamina row is replaced by a white posture bar that fills as blocked
      hits add up; stamina boxes come back when you let go.
- [ ] Keep blocking hits until it's full: the block drops, the bar flashes red and shakes, you can't
      move or act for about 1 s, and you can't block again for 2 s after that (pressing E does
      nothing). A crack burst and light shake play.
- [ ] After the stun the bar is gone and posture is back to 0.
- [ ] Posture drains by itself: about 20 per second after you let go and 1.5 s pass, about 5 per
      second while you keep holding without being hit.
- [ ] The second player sees a thin white bar under your HP boxes while posture is above 0 (it shows
      even at full health), and red while you're guard-broken.

## Stuck states (Review Focus 2)
- [ ] Die while blocking (or guard-broken): the next life isn't blocking, walks at full speed, and
      the stamina row is back.
- [ ] Switch tools, unequip, or reset while blocking: no stuck block or half speed.
- [ ] Release E while Alt-tabbed or with the window unfocused: the block is off on return.
- [ ] A player leaving mid-block leaves nothing in the output window.
- [ ] **Guard-broken stun holds everyone still:** an Iridescent Requiem player hovers in place (no
      flying), nobody can jump or double-jump, and Photoshop's Undo does nothing while she is
      blocking or stunned.
- [ ] A save with an action on E from before Block existed keeps all its keybinds (Block takes that
      action's old key).
- [ ] Photoshop's Undo still stops her acting; Lightstep's untouchable moment takes no posture.

## Output window
- [ ] No errors from Guard, Block, Damage, EnemyAI, Sprint, Dash, StatusHUD, OverheadHealth or
      SkillEffects.
