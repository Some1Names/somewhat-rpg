# Block and posture: design

Status: approved in chat 2026-10-09. **2026-10-13: parry dropped for now** (owner's call: a 0.25 s
window is hard on Roblox ping and the extra rules aren't worth it for a first version). Block,
posture and guard break stay; parry can be added later as a layer in `Guard.Resolve`. The parry
rules were removed below; the filename keeps "parry" only for continuity.

## Intent

The first step of making the game's systems "deeper than Blox Fruits, simpler than Deepwoken".
Today nobody can defend, so fights come down to who hits first. This adds a **base** defence every
player has: a front block that cuts damage, and a posture
bar so blocking isn't free. Powers, movesets and weapons can bring **their own block** later
(this spec only adds the hook).

Success: holding block buys time but runs out; flanking
and unblockable moves stay real threats; nothing about it is frustrating on normal Roblox ping.

## Controls

- **Block is E**, a new rebindable Keybinds action `{ id = "Block", label = "Block",
  default = "E" }` (E is free and Allowed).
- **Hold E**: block.
- **E and interaction prompts:** while a ProximityPrompt is on screen (the Power Dealer's shop,
  and any later interactable), E is the prompt's and doesn't block. Prompts **hide while you're in
  combat** (you dealt or took damage in the last `CombatTime` = 5 s), so E always blocks mid-fight.
  Clicking a prompt still works.

## Blocking

- **Front only:** a hit counts as from the front when it comes from within 90° either side of the
  way the blocker faces (`dot(look, toSource) > 0`, flat). The source is the attacker's root (an
  NPC's root for its swing).
- **It reduces damage** by the hit's kind:

  | Kind (`options.guard`) | Cut while blocking (from the front) |
  |---|---|
  | `"melee"`: punches, weapon combos, NPC swings | 60% |
  | `"ranged"`: Knife, Light Shot, Shutter, Revolver shots | 50% |
  | `"skill"`: everything else | 30% |
  | `"unblockable"`: ultimates (F) and grabs/pulls | 0% |
  | damage over time (`options.dot`) | not affected |

  From behind: 0% for everything.
- **While blocking:** walk at half speed, no sprint; no punches, ranged shots or skills (the
  skill bar refuses them, like while rewinding). Dashing drops the block.
- **Per-set hook:** a skill set (`SkillSetConfig.Sets.X.block`) or a melee weapon
  (`PunchConfig.Weapons.X.block`) may carry `{ melee = , ranged = , skill = }` cuts that replace
  the base ones while it's equipped. No set uses it yet.

## Posture and guard break

- **Posture** runs 0 to **100** (`Posture` attribute on the character, server-written, so every
  client can draw it). The damage a block **prevents** adds the same amount of posture.
- **Full posture = guard break:** the block drops, he's **stunned for 1 s** (can't act, can't
  move), and can't block again for **2 s** (`GuardBrokenUntil`). Posture resets to 0 after.
- **Draining:** 20/s once he hasn't blocked for 1.5 s; 5/s while blocking but not being hit
  (for 1.5 s).
- NPCs carry the same `Posture` / `HitstunUntil` attributes (they don't block yet, so nothing fills
  their posture today; the bars and rules are ready for when they do).

## What you see

- **Your posture:** while you hold E, the white posture bar **replaces your stamina row**
  (StatusHUD, the same spot by your character, the stamina row's width). Stamina returns when you
  let go. After a guard break the bar flashes red and cracks, then hides.
- **Everyone else's:** a thin white posture bar **under every overhead HP bar** (OverheadHealth,
  players and NPCs) while their posture is above 0. It **flashes red** while they're
  guard-broken.
- **Effects** (placeholders until pack prefabs exist, `CLAUDE.md`): a small spark where a block
  takes a hit (`"Block"`), a crack burst for a
  guard break (`"GuardBreak"`); `Guard/*` prefabs first, `Shared/Sparks`/`Impact` otherwise. A
  **block pose** plays from `ReplicatedStorage.CombatAnimations.Block` if it exists (it needs
  uploading in Studio, with the owner's OK); without it, no pose.

## Not in scope

Parry; NPCs blocking; feints; per-set blocks (only the hook); block sounds.

## Architecture

- **`ReplicatedStorage/GuardConfig.luau`:** every number above, and the pure rules (Lune-tested):
  `isFront(look, toSource)`, `cut(kind, blockTable)`, `postureAfter(posture, prevented)`,
  `drain(posture, sinceBlock, blocking, dt)`. Shared, so the HUDs read the same numbers.
- **`ServerScriptService/Guard.luau`:** the state (attributes on the character: `Blocking`,
  `Posture`, `GuardBrokenUntil`, `HitstunUntil` for guard breaks, `LastCombatAt`), the
  `Block` RemoteEvent (`true`/`false`), the
  drain loop, and `Guard.Resolve(targetCharacter, amount, kind, sourcePosition, attackerModel)
  -> amount` (block cut, posture, guard break, the effects).
- **`Damage.Deal`:** a new `options.guard` (`"melee"`, `"ranged"`, `"skill"`, `"unblockable"`;
  default `"melee"` when `melee`, else `"skill"`; skipped for `dot`). For player targets it calls
  `Guard.Resolve` before `Passives.Absorb`. It also stamps `LastCombatAt` on both characters.
  **EnemyAI's swing** (which doesn't use `Damage.Deal`) calls `Guard.Resolve` with `"melee"` too.
- **Tags in existing skills:** `guard = "ranged"` in KnifeThrow, LightShot, Shutter, RevolverShot;
  `guard = "unblockable"` in the ultimates (PlaceWhereDreamEnds, AboveTheClouds, Kaleidoscope) and
  the grabs/pulls (SpineLash, BlackHole, Tornado). Aido's plan gets the same rule (Fuse and Atomic
  Breath ranged; Final Cut's roar and Collapse unblockable) noted in its Global Constraints.
- **`ReplicatedStorage/ActionLock.luau`:** `ActionLock.Locked(character) -> bool`: true while
  `Rewinding`, `Blocking`, or `HitstunUntil` is in the future. It replaces the `Rewinding` checks
  added for Undo (SkillSetServer, RangedServer, PunchCombat, SkillBar, Ranged, Punch).
- **Client `Block.client.luau`:** E (Keybinds "Block") → the remote; the prompt rule (tracks
  shown prompts with `ProximityPromptService.PromptShown/PromptHidden`, and locally disables every
  ProximityPrompt while `LastCombatAt` is within `CombatTime`); drops the block on dash and death;
  plays the block pose if it exists.
- **Sprint:** walk speed halves while `Blocking` or stunned, is 0 while guard-broken, and
  sprinting is off meanwhile.
- **StatusHUD / OverheadHealth:** the bars above. **SkillEffects:** `Block`,
  `GuardBreak`.
- **Settings:** the new action appears automatically (it lists `Keybinds.Actions`).

## Testing

- Lune: `tests/GuardConfig.spec.luau` (front/behind at 0°, 89°, 91°, 180°; each kind's cut and
  the per-set override; posture adds and caps at 100; drain timing) and the Keybinds spec still
  passing with the new action.
- StyLua parse and selene on every changed script.
- In-game checklist `docs/superpowers/specs/2026-10-09-block-parry-checklist.md` (needs two
  players for the overhead bars).
