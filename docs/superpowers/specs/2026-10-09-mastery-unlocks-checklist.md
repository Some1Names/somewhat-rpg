# Mastery unlocks: in-game test checklist

Not run in-game yet; nothing here was compiled (no Luau toolchain on the machine that wrote it).
Use the Admin panel's mastery setter to step each set through its levels. Numbers are in
`SkillSetConfig` (spec: `2026-10-09-mastery-unlocks-design.md`).

## Every set
- [ ] No errors in the output on joining, equipping, levelling and unequipping any set.
- [ ] Inventory: a locked feature row (passive, dash, special, gallery) is dimmed with "Mastery N";
      it turns normal at that level. Locked skills still say "Mastery N" too.
- [ ] Reaching a feature's level shows a gold "<name> unlocked" popup (and the skills' as before).

## Mandela (Z 1, X 5, C 15, V 40, F 100; Misremembered 10; Backbone Power 25)
- [ ] Mastery 9: a hit on you isn't erased (Misremembered off); at 10 it is.
- [ ] Below 25 no stacks build from dealing or taking damage; the meter reads "MASTERY 25"; G refuses
      "Backbone Power: needs mastery 25". At 25 stacks build and G works.
- [ ] C unlocks at 15, V at 40.

## Iridescent Requiem (Z 1, X 10, C 20, V 50, F 100; Luminance 1; Lightstep 15; flight 30)
- [ ] At mastery 1 Luminance still gathers and Light Shot works; X (Prism Form) is locked until 10.
- [ ] Below 15 the dash key does the normal dash (stamina, no light trail); at 15 it's Lightstep.
- [ ] Below 30 G refuses "Flight: needs mastery 30" and she can't take off (try with the admin
      panel's mastery lowered mid-flight: no errors); at 30 she flies.

## Photoshop (Z 1, X 5, C 20, V 40, F 100; History and Undo 15; Gallery 30)
- [ ] Below 15 G refuses "Undo: needs mastery 15", the meter reads "MASTERY 15", and nothing is
      recorded (set 15, then Undo right away: nothing to rewind to).
- [ ] Below 30 T does nothing and the Gallery's waypoints don't show; at 30 both work.

## Revolver
- [ ] Z at 1, X (Dead Eye) at 10, as before.
