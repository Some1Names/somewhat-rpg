# More ways to earn mastery: design

Status: approved in chat 2026-10-09; waiting on review of this written spec.

## Intent

Mastery (per skill set, 1 to 100) only comes from damaging NPCs today (0.25 XP per point of
damage; about 400,000 damage to reach 100). PvP players earn nothing, finishing a kill is worth no
more than chip damage, and training dummies give full mastery forever. This adds three sources and
keeps the base rate as it is:

- **A. PvP:** damaging players earns mastery at half the NPC rate, with limits so friends can't
  farm each other.
- **B. Kill bonus:** finishing an NPC or a player with the set earns a lump.
- **C. Training dummies:** they teach the basics only, up to mastery 10.

Not here: mastery challenges (the quest system), bosses (the boss and enemy rework), buying
mastery (dropped).

## A. PvP mastery

- Damage dealt to another **player** with a set earns `0.5 × MasteryXPPerDamage` per point
  (0.125).
- **Per-victim cap:** at most **500** mastery XP from any one victim in a rolling **10 minutes**
  (per attacker, per victim, all sets together).
- **Repeat rule:** nothing from a victim the attacker killed in the last **5 minutes** (the same
  window as the Headhunter's repeat kills).
- Damage over time (Burnt, Bleeding) counts like any other damage, as it already does on NPCs.

## B. Kill bonus

- Killing an **NPC** credits the set of the killing hit (`Damage.LastHit(humanoid).skillSet`)
  with **half the NPC's kill XP** as mastery: `0.5 × (XPReward or StatConfig.EnemyXP(level) or
  StatConfig.KillXP)` (about 25 at level 1, 270 at level 50).
- Killing a **player** (credited like the kill feed: their last attacker within 15 s) gives the
  same from the victim's level, `0.5 × StatConfig.EnemyXP(victimLevel)`, unless it's a repeat
  kill (5 minutes).
- No set (a bare-handed or non-set kill): no bonus.

## C. Training dummies

- A model tagged **`TrainingDummy`** (set in Studio; the owner's coming infinite-health dummy and
  the current training dummies) gives mastery at the normal rate, **only while that set's mastery
  is below 10**, and never past level 10 (XP stops at 0 into level 10).
- Mastery from a dummy hit counts the hit's **damage** (after scaling), not the health it took,
  so an infinite-health dummy still teaches.
- Dummies give no kill bonus (B) beyond the same cap.
- Untagged models keep counting as normal NPCs.

## Architecture

- **`ReplicatedStorage/MasteryRules.luau`** (pure, Lune-tested): `PvPShare = 0.5`,
  `PvPCap = 500`, `PvPWindow = 600`, `KillShare = 0.5`, `DummyCap = 10`, `DummyTag =
  "TrainingDummy"`, and `pvpXP(damage, perDamage, earnedInWindow) -> number` (clamped to what's
  left of the cap), `killXP(killXP) -> number`, `dummyXP(damage, perDamage, mastery) -> number`
  (0 at or past `DummyCap`).
- **`ServerScriptService/KillRecords.luau`:** `Record(killer, victim)`, `IsRepeat(killer, victim)
  -> boolean` (5 minutes; `RepeatWindow = 300` lives here). Shared with the Headhunter plan:
  whichever plan runs first creates it, the other uses it.
- **`PlayerStats.AddMasteryXP(player, setName, amount, capLevel?)`:** with `capLevel`, it never
  levels past it and keeps no XP at it.
- **`Damage.Deal`** (the mastery block ~133): players → A (tracked per attacker/victim with
  timestamps); `TrainingDummy` → C; other NPCs → unchanged. **`payOutOnDeath`** → B for NPC kills;
  a player-death watch (the KillFeed pattern, in `Damage` or a small server script) → B for player
  kills and `KillRecords.Record`.
- No UI changes: the skill bar's mastery popups and the inventory already show gains.

## Testing

- Lune: `tests/MasteryRules.spec.luau`: `pvpXP(100, 0.25, 0) == 12.5`, `pvpXP(100, 0.25, 495)
  == 5`, `pvpXP(100, 0.25, 500) == 0`; `killXP(50) == 25`; `dummyXP(100, 0.25, 9) == 25`,
  `dummyXP(100, 0.25, 10) == 0`.
- StyLua parse and selene.
- In-game checklist `docs/superpowers/specs/2026-10-09-mastery-sources-checklist.md` (PvP needs
  two players; dummies need the `TrainingDummy` tag set in Studio).
