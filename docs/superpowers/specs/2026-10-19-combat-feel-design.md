# Combat feel (Deepwoken-like, sub-project 2)

## Goal
Combat should reward reading and reacting: enemies telegraph their attacks, a dodge can
dodge a hit, and melee swings carry weight. Block and parry are **not** basekit.
Out of scope: parry, perfect-dodge rewards, full per-enemy move sets, world and death work.

## Decisions (agreed in chat)
- Block exists only on a skill set or weapon that defines its own `block` table. Fists never block.
- The existing Q dash is the dodge. No separate roll.
- Enemies get two attack types, quick and heavy.
- Melee swings cost stamina and slow movement while they last.
- Visual cues are placeholders; final VFX is the owner's.
- Numbers and pure rules live in a Lune-tested module, like `GuardConfig` / `BuildRules`.

## Current state (read from the code)
- The dash (`Dash.client`) runs on the client; `DashRelay` only counts dodge charges and calls
  `CrowdControl.Dodge`. It spends a dodge charge and half a stamina box. No invulnerability.
- `EnemyAI.swingAt`: fixed `WIND_UP = 0.35`, reach check at impact, `HitstunUntil` cancels a wind-up.
- `PunchCombat` / `Punch.client`: combos, enemy hitstun, rest after the finisher; no stamina cost.
- `GuardConfig.Enabled = false`; no set defines a `block` table today.

## Design
1. **Dodge i-frames.** New `ReplicatedStorage/CombatFeel` (pure):
   `DodgeWindow(agility) = 0.15 + 0.002 * agility` seconds, `DodgeGrace = 0.1`, `DodgeRecovery = 0.35`,
   `InDodge(untilTime, now) -> boolean`. `DashRelay`, once it accepts a dash, sets the character
   attribute `DodgeUntil = server time + DodgeWindow(Agility) + DodgeGrace` and refuses a new dash before
   `DodgeRecovery` has passed since the last accepted one (attacking is still allowed during recovery).
   `Damage.Deal` returns 0 damage to a player target with `InDodge(DodgeUntil, now)`, unless
   `options.dot` or `options.unavoidable`. Set dashes (Lightstep etc.) get the same window.
   A "Dodge" placeholder cue plays when a hit is negated.
2. **Enemy attack types.** New `ReplicatedStorage/EnemyAttackConfig` (pure): `quick = { windUp = 0.35, damage = 1 }`,
   `heavy = { windUp = 0.8, damage = 1.8, uninterruptible = true }`, `HeavyChance = 0.25`
   (a model's `HeavyChance` attribute overrides), `Choose(roll, chance, lastWasHeavy) -> "quick"|"heavy"`
   (never two heavies in a row). `EnemyAI.swingAt(targetHumanoid, targetRoot, attackType)`: wind-up and damage
   from the type; a heavy wind-up ignores `HitstunUntil` cancellation. Each wind-up fires
   `SkillEffects:FireAllClients("Telegraph", model, attackType, windUp)`; the client draws a placeholder
   flash (quick: white, heavy: red). The reach check at impact stays.
3. **M1 weight.** `PunchConfig`: `swingStamina` per hit and `finisherStamina` (fists 6 / 12; weapons inherit
   unless they set their own). `Punch.client` spends it through `Stamina.TryConsume` before sending the swing
   and does nothing if it can't pay. Walk speed is multiplied by `CombatFeel.SwingWalkShare = 0.5` for the
   swing's length (client, like `BlockWalkShare`). Dashing during a swing is always allowed.
4. **Block off basekit.** `Guard`'s block source (`ownBlock`) returning nil means the character cannot
   block (no base `Cuts` fallback); `Block.client` does nothing without a block source. `GuardConfig.Enabled`
   stays `false`.
5. **Testing.** `tests/CombatFeel.spec.luau`: dodge window at Agility 0 / 50, `InDodge` edges, attack
   choice including no double heavy and a chance of 0 / 1, swing costs. In-game checklist supplied; no
   claim of in-game verification without a playtest.

## Open items for the plan
- Exact `SkillEffects` Telegraph visuals (placeholder only).
- Which `PunchConfig` weapons get their own stamina numbers (start with none; all inherit).
- New Studio instances: `CombatFeel`, `EnemyAttackConfig` (ModuleScripts); no other instances expected.
