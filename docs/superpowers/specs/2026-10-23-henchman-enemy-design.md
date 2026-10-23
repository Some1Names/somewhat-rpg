# Henchman enemy: per-type enemy config, combo and aggro range

Date: 2026-10-23. Status: design, waiting on the owner's review.

## Goal

Enemies are all the same today (`EnemyAI.server.luau`): passive until hurt, one quick/heavy
random swing, no types. Make the **Henchman** (four models in Studio, tagged `Enemy` + `Respawns`,
`EnemyType=Henchman`, `Level=10`, `FightsBack=true`, R6) the first enemy with its own
behaviour, through a per-type config that bosses and other enemies can reuse later.

Success: a Henchman notices a player who walks near it, chases them, and fights with a readable
3-step combo whose finisher has to be dodged. Every other enemy behaves exactly as before.

## Out of scope

Bounties and faction hooks; squads; thrown weapons or guns; new animations (it reuses the
default slash); final VFX (owner's). Placeholder cues only.

## Design

### `EnemyConfig` (new, `ReplicatedStorage`, pure, Lune-tested)

Keyed by the model's `EnemyType` attribute. An entry may set any of: `AttackRange`,
`AttackCooldown`, `LeashRange`, `ChaseSpeed`, `HeavyChance`, `AggroRange`, `attacks`.

- `EnemyConfig.Get(enemyType)` returns the entry, or nil for no type / an unknown type.
- Lookup order for a setting: the model's own attribute, then the type's entry, then the
  `EnemyAI` `DEFAULTS`. An enemy with no entry behaves as it does today.
- `AggroRange` (studs, default none = passive). A player inside it, alive, and inside the
  enemy's leash territory, becomes its target as if they had hurt it.
- `attacks`: an ordered combo. Each step is `{ type = "quick"|"heavy", damage?, lunge? }`
  and a `comboPause` (seconds) after the last step. `EnemyConfig.NextAttack(entry, index)`
  returns the step and the next index (wrapping).

### Henchman entry (placeholder numbers)

- `AggroRange = 50`, `GiveUpDistance = 140` (the give-up distance becomes a per-type setting; default 70)
- Combo: quick, quick, heavy. The heavy finisher has `lunge = 6` studs toward the target
  during its wind-up. `comboPause = 1.2` s after the finisher (a window to hit back).
- Damage multipliers come from `EnemyAttackConfig` (quick 1, heavy 1.8). Telegraph cues
  are the existing ones (white quick, red heavy). The heavy can't be staggered out of, so it
  has to be dodged with Q.

### `EnemyAI` changes

1. `setting(model, key)` falls back to the type entry before `DEFAULTS`.
2. Idle/returning enemies with an `AggroRange` scan players each tick (distance check on
   `HumanoidRootPart`, no raycast); the nearest valid one sets `target`/`state = "chasing"`
   with the same `lastProgressAt` bookkeeping the hurt-trigger uses. A retreating
   (`retreating`) enemy ignores aggro until it is home.
3. `swingAt` takes the next step from the type's `attacks` when there is one; otherwise it
   keeps today's random quick/heavy roll. The combo index resets when the target changes or
   it goes home. The lunge uses the existing dash velocity code, shortened.
4. Damage still goes through the same `Guard.Resolve`, `Passives.Absorb`, dodge and
   `Invulnerable` checks. Nothing changes in `Damage.luau`.

### Loot table

Materials already drop through `DropConfig` (`Generic` rolls by level, plus a named table from the
model's `DropTable` attribute); yen already comes from `Damage` (`StatConfig.EnemyYen(level)`, or a
model's `YenReward`). The Henchman plugs into both with no new drop system.

- `EnemyConfig` entry gets `dropTable` (a key of `DropConfig.Tables`). `Drops` reads the model's
  `DropTable` attribute first, then the type's entry. (No `yenReward` field: yen stays as is.)
- New material **Thug Badge** (`ThugBadge`, tier Rare, display name a placeholder), added to
  `DropConfig.Materials`, so it shows in the Backpack and Reforge can use it later.
- `DropConfig.Tables.Henchman` (additive, so the Level 10 generic rolls still apply: Scrap 40%
  and Core 12%):
  - Scrap: 60%, 1-3 (a thug carries junk)
  - Thug Badge: 15%, 1
  - Core: 10%, 1 (on top of the generic roll)
- Yen: the level-based reward, unchanged (no `yenReward` set).
- Not added: a guaranteed drop, or a rare "leader" drop.

### Special talisman: Thug's Knuckle

A talisman only the Henchman drops (the first enemy source for talismans).

- New `TalismanConfig.Items` entry: key `ThugKnuckle`, name "Thug's Knuckle Talisman" (placeholder),
  colour red-brown, effects `damageDealt = 0.1` and `healOnKill = 0.02`, description "+10% damage
  dealt. Heal 2% max HP on every kill." Both effects already exist, so no new stat code. Numbers
  are placeholders.
- The item gets `dropOnly = true`. `TalismanConfig.RollNew` skips `dropOnly` items, so yen chests
  never give it. It is listed in the Backpack like the others (in item order, after Glass Charm).
- `EnemyConfig` Henchman entry: `talisman = { key = "ThugKnuckle", chance = 0.03 }`.
  `Drops` rolls it once per helper (same 10% contribution rule) on a kill; a pass calls
  `Talismans.Grant(player, key)`, which already shows the "Found" toast. A player who already
  owns it is skipped (the roll is not made), so it never repeats.
- Rolls use the same injected `random` as `DropConfig.Rolls`; the pure part is
  `EnemyConfig.TalismanDrop(entry, owned, random)` (returns the key or nil), so Lune can test it.
- **Known gap:** `TalismanConfig.OwnAll` is `true` for testing, so every player already owns
  every talisman and `Grant` does nothing. Until `OwnAll` is turned off (a "Before release" item),
  the Thug's Knuckle is equippable by everyone and the drop does nothing. To test the drop, set
  `OwnAll = false` locally.
- Every helper who dealt 10% of its health rolls separately, per the existing rules.
- Reforge does not use Thug Badge yet; it's collectable only. Say so when a recipe wants it.

### Studio

No instance changes: all four Henchman models already carry `EnemyType=Henchman`.
The `DroppedItemOrb` prefab already has Common/Rare/Gold/Dark orb parts; Thug Badge uses the Rare one.

## Testing

- Lune: `tests/EnemyConfig.spec.luau` — `Get` for known/unknown/nil types; attribute > entry >
  default ordering; `NextAttack` order and wrap-around; `AggroRange` absent = passive.
  `tests/DropConfig.spec.luau` (extend) — the Henchman table rolls on top of the generic ones
  (fixed `random`), and every material a table names exists in `DropConfig.Materials`.
  `tests/TalismanConfig.spec.luau` (extend) — `RollNew` never returns a `dropOnly` talisman;
  `ThugKnuckle` effects add into `Total`. `EnemyConfig.TalismanDrop` passes below the chance,
  fails above it, and is skipped when already owned.
- Owner playtest (the code can't be checked in-game here): walk toward a Henchman and see it
  aggro at about 50 studs; the jab, jab, heavy rhythm and the lunge; dodging the finisher with
  Q; the pause after the finisher; leash and give-up still work; an untyped enemy still sits
  passive until hit.
