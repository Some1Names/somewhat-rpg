# Daylight cycle: playtest checklist

Spec `2026-10-13-daylight-cycle-design.md`, plan `../plans/2026-10-13-daylight-cycle.md`. Open the
admin panel (`) and use the WORLD section: **Set** an hour, **Freeze time** / **Resume time**.

## Look

- [ ] Freeze at **6:00, 12:00, 18:00 and 0:00** and screenshot each. Noon (12:00) should look like the
      place did before the cycle.
- [ ] Resume and watch a minute: the sun and sky move smoothly, with no stepping or flicker.
- [ ] Stars show at night and fade out by day; the moon is up at night.
- [ ] A new server starts at about 7:00.
- [ ] A full day takes about 20 minutes.

## Time

- [ ] Two players see the same time (freeze and compare the sky).
- [ ] Freeze, wait, resume: the time doesn't jump either way.
- [ ] **Set** with `abc`, an empty box, `-3`, `30.5`, `24`: bad input shows a message and breaks
      nothing; the numbers wrap into 0–24 (`-3` is 21:00, `30.5` is 06:30).
- [ ] In the Explorer, `ReplicatedStorage` has the attribute `Phase`: Dawn 5–7, Day 7–17,
      Dusk 17–19, Night 19–5.

## Sky changes (needs `ReplicatedStorage.Skies` with Dawn, Day, Dusk, Night)

- [ ] Joining at any hour shows that phase's sky at once, with no fade.
- [ ] Letting time pass through 5:00, 7:00, 17:00 and 19:00 fades the screen to black and back (about
      1.6 s), swapping the sky textures in the dark; the HUD and menus stay visible above the fade.
- [ ] Setting the time with the admin panel to another phase fades once and lands on the right sky.
- [ ] A phase whose Sky is missing from `Skies` keeps the current sky, with no fade.

## Powers (Iridescent Requiem)

- [ ] Outside by day: Luminance fills as before.
- [ ] In shade by day: it holds at the shade cap (the shaded warning shows).
- [ ] Outside at night: it fills **slowly** (about a quarter of the daytime rate), and no shaded warning.
- [ ] Under a roof at night: shaded, as in the day.
- [ ] Dawn and dusk (5:00–7:00, 17:00–19:00): no flicker between charging and shade at the horizon.
- [ ] Flying: night doesn't ground you any faster than before (it drains as ever; flight gathers none).
- [ ] Solar Lance outside by day versus outside at night with the same Luminance: at night it's half
      the size and damage.
- [ ] Solar Lance aimed through a glass part (transparency 0.5 or more) by day: not weakened.

## Other effects

- [ ] Skill colour grades (Prism Form, Desaturate, Rewrite, impact pops) still show on top of the
      night look.
