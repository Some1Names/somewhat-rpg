# Aido: in-game test checklist

Nothing here has been run: the cloud/code session can't playtest, and no Luau toolchain (Lune,
StyLua, selene) was available when it was written, so scripts were read, not parsed. Apply the diff
to Studio, then tick each line in a playtest. All visuals are placeholders (red parts and Shared
prefabs) until your VFX pass. Numbers are before the Superliminal bonus. **Glass-cannon update:
the damage numbers below are the old ones; see the last section for the current ones.**

**Setup**
- Add a Tool `Deus Ex Machina` to `ServerStorage.SkillSetTools` with the attribute `SkillSet = "Aido"` (copy
  the Photoshop tool).
- Admin panel: set your Aido mastery to 100 (SetMastery) so every move and the passive unlock.
- Use the `Player Dummy` for single checks; a second player for Block, CrowdControl and PvP.
- Optional: `ReplicatedStorage.ProjectileModels.FissionSeed` (looks only), `ServerStorage.SkillSets.Aido.AidoDragon`
  and `ReplicatedStorage.AidoAnimations` (DragonIdle/DragonWalk/DragonBreath). Everything works without them.

## Equip and UI
- [ ] Equipping Aido shows CATASTROPHE / COLLAPSE / TOTAL DESTRUCTION / GROUND ZERO / FINAL CUT, the
      passive HALF-LIFE, and the overcharge meter CHAIN REACTION in **red** (Mandela's is still green).
- [ ] The ammo slot shows Fuse `x3`; F with no overcharge refuses with "Final Cut: needs overcharge"
      (no Luminance error).
- [ ] Inventory (B) lists Aido; the Power Dealer shows it (sell-only, gacha/drops give it).
- [ ] No errors from any Aido script, SkillSetServer, RangedServer or SkillEffects in the output.

## Moves
- [ ] **Fuse** (right click readies, left click fires; 3 charges, 3 s each): the seed sticks to the first
      person hit (follows them) or the wall/floor/max range (80); 1 s later it pops for **12**, 6 studs.
      No Fallout, no Burnt, no aftershocks, even with Chain Reaction on.
- [ ] **Z Catastrophe** (7 s): a warhead and a closing ring at the aim point (max 70 away); it goes off
      after 1 s, or **Z again** sets it off now. **40** damage, 14 studs, 1 Burnt stack, Fallout.
- [ ] Z twice quickly: the first warhead goes off when the second is cast.
- [ ] **X Collapse** (10 s): everyone within 20 is pulled to the centre over 0.6 s (3 ticks of **4**), then
      a **25** blast, 10 studs, Fallout. Flying Iridescent players aren't pulled but are hurt.
- [ ] **C Total Destruction** (14 s): 6 blasts march 80 studs, 0.15 s apart, **14** each, 8 studs, Fallout.
      Nobody takes more than 3 of one cast. With Chain Reaction: 3 lines 25 degrees apart.
- [ ] **V Ground Zero** (45 s): a 40-stud circle with a 3-2-1 everyone can see, then **110** at the centre
      falling to **40** at the edge, 2 Burnt stacks, a 30-stud Fallout field for 6 s.
- [ ] **F Final Cut** (90 s, needs Chain Reaction): a roar (**40**, 20 studs); then the form, until F again. See
      Review Focus 1 below.
- [ ] **Atomic Breath** (in Final Cut, hold left click, no right click): a 60-stud beam, **8** every 0.2 s,
      1 Burnt per hit, no ammo; the Fuse slot shows Atomic Breath with no count.

## Passive and overcharge
- [ ] **Half-Life**: after one blast, a red patch stays 3 s (6 studs); a blast on someone already Burnt
      deals 25% more. Below mastery 10 there is no Fallout and no bonus.
- [ ] **Chain Reaction** (G, mastery 25): fills from damage he deals only (not damage he takes). While on,
      every skill blast sets off 3 aftershocks 0.25 s later (30% damage, 6 studs).

## Review Focus
1. **Final Cut ends cleanly**, each way (F again, dying, putting the set away, leaving the game):
      the `FinalCut` attribute on the character, the `FinalCutDragon` folder, the hidden body,
      the camera limit and the Fuse/Atomic Breath swap all go back. Respawn: nothing carries over.
- [ ] **A target dying, respawning or leaving mid-move**: Fuse stuck on them, Collapse pulling them, Ground
      Zero's countdown: no errors, and nothing hits the new body wrongly.
- [ ] **Aftershocks don't snowball**: aftershocks never leave Fallout or make more aftershocks; Fuse and
      Atomic Breath never make aftershocks.
- [ ] **Fallout stacking**: stand in several overlapping patches (Total Destruction, Ground Zero): at most
      1 Burnt stack per second per patch, and Burnt's own cap of 3.
- [ ] **SkillBar**: with Mandela and Aido equipped one after the other, the overcharge meter is green,
      then red; no error in a non-Luminance form.

## In Final Cut
- [ ] **20% less damage** from everything (hit yourself with a dummy and compare).
- [ ] `form` moves blast **1.5x** wider (Z, X, C, V show the bigger aim circle).
- [ ] The camera can't zoom in closer than 22 studs.
- [ ] With no dragon model: your body stays and a red aura shows. With the model: the body is hidden and
      the dragon plays idle/walk (and breath while you hold left click).

## Challenges (Quests, J)
- [ ] Aido's five mastery challenges show and count: Fuse pops, a 3-enemy Collapse pull, Catastrophe kills,
      Total Destruction kills, and a 3-enemy Ground Zero.

## Glass cannon and Meltdown (current numbers)
He hits harder and is easier to kill. New numbers: Fuse **18**; Catastrophe **60**, 16 studs, 5 s;
Collapse ticks **6**, blast **40**, 7 s; Total Destruction **22**, 9 studs, 10 s; Ground Zero **180**
to **70**, 35 s; Final Cut roar **60**; Atomic Breath **12**. Chain Reaction fills 40% faster
(25 per stack).
- [ ] Every hit on him is **35% harder** (Half-Life); in Final Cut that is cut by 20%, so he is still
      slightly softer than normal.
- [ ] **Meltdown**: the passive label on the bar shows `MELTDOWN n%`. Each skill blast (not Fuse, not
      aftershocks) adds 10%, and it drains 4% a second after 4 s of no blasts.
- [ ] At 100% he melts down for 8 s: red glow and aura, blasts **2x damage** and **1.4x wider**.
- [ ] While melting down he burns himself 5% of max health a second, **never below 1 HP**.
- [ ] Meltdown ends on its time, death, respawn or putting the set away, and the meter resets to 0.
