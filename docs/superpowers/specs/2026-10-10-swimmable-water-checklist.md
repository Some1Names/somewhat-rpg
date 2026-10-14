# Swimmable water parts: in-game test checklist

Not run in-game yet. `tests/run.sh` (Lune) passes `Water.inside` and `Water.surfaceY` (rotated, tilted
and touching parts). Everything else needs Studio. Water parts must be tagged **`Water`** and have
`CanCollide`, `CanQuery` and `CanTouch` off; the tuning numbers are `Water.SwimSpeed` (16),
`Water.SurfaceOffset` (1.2) and `Water.RiseSpeed` (10).

## Swimming
- [ ] Walk or jump into a water part: you sink in, then float at the surface with your head just
      above it when you stop moving. Roblox's swim animation plays (the rig's Animate script reacts to the
      Swimming state).
- [ ] The movement keys swim where the camera points; looking down and moving dives; Space rises.
      Speed is about 16 studs/s and Shift doesn't sprint in water.
- [ ] Idle deep down: you hover there (no sinking, no drifting); idle near the top: you settle back to the
      surface.
- [ ] You can't swim up out of the water into the air: holding Space at the surface keeps you floating.
- [ ] Leaving the water (swimming out over the edge, a skill throwing you out) gives normal physics at
      once: you walk or fall as usual, no floating on land.
- [ ] Another player sees you swim (their client sees your movement).

## Getting out (Review Focus 4)
- [ ] At the surface beside a ledge up to about 4 studs high, hold Space (facing it): you climb onto
      it. Try a shore with a gentle slope, a dock, and a wall about 4 studs high.
- [ ] With no ledge ahead, Space doesn't hop you in and out of the water.
- [ ] You can always get out of a pool or lake edge one way or another.

## Stuck states (Review Focus 1)
- [ ] Die in the water: the next life walks normally (no leftover swim force, states back).
- [ ] Reset in the water, and respawn: same.
- [ ] Being pulled out by a skill (Event Horizon's pull, Step In, Paste) leaves no stuck state.
- [ ] Dying while climbing out leaves nothing behind.

## Skills and other systems
- [ ] **Skill movers (Review Focus 2):** an Event Horizon pull or a Tornado still moves a swimmer; a
      knockback or Paste still moves them; they swim normally again afterwards.
- [ ] Dash (Q) and Lightstep work in water.
- [ ] Double jump doesn't work underwater (or at the surface).
- [ ] Flying (Iridescent Requiem) ignores the water: fly low over a lake without swimming.
- [ ] A guard break's stun holds a swimmer still.
- [ ] Photoshop: saving a Gallery photo in water is refused (T menu), saving on the shore still works.
- [ ] No drowning and no swim stamina.

## Rotated, tilted and touching water parts (Review Focus 3)
- [ ] A water part turned at an angle: you swim in it only inside its edges.
- [ ] Two touching water parts: swimming across the seam doesn't flicker or drop you.
- [ ] A water part whose top is lower than the shore: the float height follows its surface.

## NPCs (Review Focus 5)
- [ ] Enemies don't swim; they walk along the bottom under water parts. If that looks wrong or gets them
      stuck, note it for the enemy rework.

## Output window
- [ ] No errors from Swim, Water, DoubleJump, Sprint or PhotoshopServer.
