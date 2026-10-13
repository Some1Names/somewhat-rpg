# More ways to earn mastery: in-game test checklist

Not run in-game yet. `tests/run.sh` (Lune) passes MasteryRules: the PvP cap, the kill bonus, the
dummy cap, and the level maths with a cap. Everything below needs Studio; PvP needs two players (a
Studio 2-player server: Test → Clients and Servers). The base rate is unchanged: 0.25 mastery XP
per point of damage to an NPC. You can watch a set's mastery in the Inventory (B) or its
`<Set>MasteryXP` attribute.

## Damage to players (PvP)
- [ ] Hit the other player with a set equipped: you earn mastery at half the NPC rate (0.125 per
      point of damage).
- [ ] Trade hits for a long time: from any one victim you earn at most **500** mastery XP in 10
      minutes, then nothing until old gains age out of the window.
- [ ] Burnt / Bleeding ticks on a player count like any other damage.
- [ ] Hitting yourself (or a hit with no set, bare hands) earns nothing.
- [ ] **Repeat kill:** kill the same player and keep hitting them after they respawn: for the next 5
      minutes you earn no mastery from them. They can still earn from you (only the killer is
      blocked).

## Kill bonus
- [ ] Kill an NPC with a set: you get half its kill XP as mastery for the set of the **killing hit**
      (about 25 for a level-1 NPC, 270 at level 50) in addition to the damage mastery.
- [ ] Kill a player (the last player to hit them within 15 s): half of `EnemyXP(their level)` as mastery
      for the killing hit's set, unless it's a repeat kill. No bonus for a Studio KillFeedDummy.
- [ ] A bare-handed kill gives no mastery bonus.
- [ ] Changing the held set right before the kill doesn't move the bonus to the new set.

## Training dummies (tag `TrainingDummy`)
- [ ] At mastery below 10, hitting a tagged dummy earns at the normal rate; one big hit at mastery 9
      carries you to 10 and stops there with 0 XP into 10.
- [ ] At mastery 10 or more, a tagged dummy gives nothing at all (hits and the kill bonus).
- [ ] A dummy with infinite health (`MaxHealth = math.huge`) still teaches below 10, and nothing
      breaks (no NaN in the Overcharge stacks or the output).
- [ ] An untagged NPC still gives full mastery at any level.

## Unchanged
- [ ] Iridescent Requiem's Prism Form still trains the set when an enemy's hit passes through him.
- [ ] The skill bar's mastery level-up popups and the Inventory show every new gain.
- [ ] No errors in the output from Damage, Headhunter, PlayerStats or MasteryRules.
