# Balance pass (after the first Photoshop playtest): in-game checklist

Not run in-game. Every changed script passed the StyLua parse check and selene's
undefined-variable check.

## Mandela: overcharge from damage taken
- [ ] Holding Mandela and taking damage (from the dummy, an NPC, a fall, a burn) fills the Backbone
      Power bar: about 1 segment per 80 damage taken. Dealing damage is still 1 per 40.
- [ ] A hit Misremembered erases adds nothing (no health was lost).
- [ ] While overcharged, damage taken doesn't add stacks. Holding another set, it doesn't fill
      Mandela's bar.
- [ ] A partly filled bar doesn't fade while you keep taking damage.

## Longer reach
- [ ] Spine Lash (Mandela Z while overcharged) locks on and yanks from up to **80** studs. The aim
      preview shows the longer reach.
- [ ] Snapshot (Photoshop Z) locks on from up to **100** studs. Step In then works on that target
      (up to 110 studs).
- [ ] Iris Horizon (Photoshop V) locks on from up to **120** studs.

## Iridescent Requiem
- [ ] Solar Lance (V) aimed at a Sunmarked target still snaps on almost instantly and shows a crit,
      but deals the **same** damage as an unmarked lance (40–80 by Luminance).
- [ ] Luminance fills about 25% faster: empty to full in about 10 s of sunlight (was 12.5 s). In
      shade it rises to the cap at 0.025/s (was 0.02/s).
- [ ] Lightstep (Q) leaves its light on the path for **3 s**. A dummy that walks (or is pushed) into
      it takes the dash's hit (8, or 12 and Burnt in Prism Form), only once per trail. One already
      hit by the dash itself isn't hit again by that trail.
- [ ] Dash 4 times quickly: only **3** trails show at once (the oldest disappears), and only those 3
      still hurt. Another player sees the same.
