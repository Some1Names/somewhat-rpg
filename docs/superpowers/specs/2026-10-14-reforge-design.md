# Reforge: design

Status: design agreed in chat 2026-10-14; waiting on review of this written spec. Second of two designs:
it spends the materials from [enemy drops](2026-10-14-enemy-drops-design.md) (branch `enemy-drops`, on which
this one is based). Gear (armor, accessories) is a later, separate design.

## Intent

Players spend drop materials at a smith to make a weapon or power they own stronger (**levels**) and to
gamble on extra perks (**modifiers**). It gives the materials a purpose and gives a set you already own a
reason to keep using.

Success: a steady, predictable climb from levels; a risk-free way to chase a better roll (nothing is lost
by trying); and no balance surprise, since the largest possible bonus is small and halved against players.

## What is reforged

Weapons and powers are both skill sets (`SkillSetConfig.Sets`), so reforge state is **per skill set**, keyed
by set name (`Revolver`, `Mandela`, ...). One shared core, no item instances. Only sets the player owns
(`Loadout.Owns`) can be reforged; Fists are not a set and can't be. The state belongs to the player and
the set, whether or not the set is currently carried.

## Rules (all numbers live in `ReforgeConfig`, placeholders to tune)

**Levels.** Cap `MaxLevel = 10`. Each level gives `+4%` damage (+40% at the cap). Going up one level costs
materials, always succeeds, and never loses a level. The material tier rises with the level:

| Level reached | Material (tier) | Amount (first pass) | Yen |
|---|---|---|---|
| 1-3 | Scrap (Common) | 10 / 15 / 20 | 200 each |
| 4-6 | Core (Rare) | 5 / 8 / 12 | 1000 each |
| 7-9 | Crystal (Gold) | 3 / 5 / 8 | 5000 each |
| 10 | Essence (Dark) | 3 | 20000 |

(Material keys are the `DropConfig.Materials` keys; the names above are the drops spec's placeholders.)

**Modifier slots.** A set has 2 slots, unlocked at levels 3 and 7. An unlocked, empty slot is filled by its
first roll (paying the reroll cost); a filled slot is rerolled the same way. Two slots can't hold the same
modifier.

**Modifiers.** Each rolls an integer value uniformly in its range (stored in tenths of a percent). They only
use mechanics that already exist:

| id | Effect | Range |
|---|---|---|
| `Might` | +damage % | 3-10% |
| `Swift` | -cooldown % on the set's skills | 3-10% |
| `Searing` | chance to apply Burnt on a hit | 8-20% |
| `Rending` | chance to apply Bleeding on a hit | 8-20% |
| `Venom` | chance to apply Poisoned on a hit | 8-20% |
| `Sapping` | chance to apply Weakened on a hit | 8-20% |
| `Vampiric` | heal this share of damage dealt | 2-6% |

A status modifier that procs is limited to once per `ProcCooldown = 1` s per victim, so multi-hit skills
don't stack it every tick. Damage-over-time ticks (`options.dot`) never proc anything.

**Reroll.** The player picks one slot and pays the reroll cost (placeholder: slot 1 = 3 Core + 500 yen,
slot 2 = 3 Crystal + 2500 yen). The server rolls a candidate (modifier id and value; it may be a different
modifier than the current one) and holds it as **pending**. The menu shows old versus new; the player
chooses **Keep** (swap in) or **Take old** (discard). The cost is paid when the candidate is rolled, so the
choice is free and a good roll is never lost by accident. A new reroll on the same set replaces its pending
candidate (and costs again). Pending candidates live only in server memory and are dropped when the player
leaves. On an empty slot, "Take old" leaves it empty.

**Bonuses in combat.**
- Damage multiplier for a hit by set `S`: `1 + level*0.04 + Might%`. Against **players** the bonus part
  (everything above 1) is halved, so reforge doesn't distort PvP. Largest possible: x1.50 against
  enemies, x1.25 against players.
- Cooldown: a skill's cooldown is multiplied by `1 - Swift%`.
- Statuses and Vampiric: only for hits that carry `options.skillSet == S`, not `options.dot`.

## Architecture

New files (Rojo-style names):

| File | Kind | Does |
|---|---|---|
| `ReplicatedStorage/ReforgeConfig` | Module | All numbers and the modifier table. |
| `ReplicatedStorage/ReforgeRules` | Module | **Pure** rules, no Roblox services: `CostFor(level)`, `SlotsUnlocked(level)`, `Roll(rng, slot, taken)`, `DamageMultiplier(state, vsPlayer)`, `CooldownMultiplier(state)`, `Encode/Decode(text)`. This is what the tests cover. |
| `ServerScriptService/Reforge` | Module | Per-player state: `Reforge.Get(player, setName)` returns `{ level, mods }` (a cached decode of the player's `Reforge` field), `Reforge.Level/Roll/Resolve` actions with all checks, pending candidates, spending materials and yen. |
| `ServerScriptService/ReforgeServer.server.luau` | Script | Remote handling for the smith: range check against `Smith`-tagged models (`ReforgeConfig.Range = 14`, same idea as `ShopConfig.Range`), debounce per player, then calls `Reforge`. |
| `StarterPlayerScripts/ReforgeMenu.client.luau` | LocalScript | The smith UI: owned sets, level and modifier display, level-up and reroll buttons, the old-versus-new compare. Opens the way `ShopMenu` does. Square UI, no `UICorner`. |

Remote: `ReplicatedStorage.ReforgeAction` (RemoteFunction, created in Studio like the other remotes),
called as `("level", set)`, `("reroll", set, slot)`, `("resolve", set, keep)`; it returns `ok, message,
candidate`.

Changes to existing files (small):
- `PlayerStats`: new saved text field `Reforge` (in `TEXT_DEFAULTS`, longer `TEXT_LENGTHS` entry, 400).
  Per set `Set:level:id=value,id=value`, sets joined by `;`. Also mirrored for the client as per-set player
  attributes `Reforge_<Set>` (`level:id=value,id=value`), so the menu and any UI can read it.
- `Damage.Deal`: next to the `damageScale` line, multiply by `Reforge.DamageMultiplier` when `attacker` and
  `options.skillSet` are set and the hit isn't a `dot` tick. After `dealt` is known, roll the status
  procs and Vampiric heal (`StatusEffects.Apply(..., { source, skillSet, stat })`; healing multiplied by
  `StatusConfig.HealMultiplier`, as in `PunchCombat`).
- `SkillSetServer`: scale `skill.cooldown` by `Reforge.CooldownMultiplier(player, setName)` where it checks
  and spends cooldowns (`SkillCooldowns.Ready`/`Spend`), so the check and the spend agree.

Skill handlers, `PunchCombat`, quests and mastery are unchanged. Mastery XP uses `dealt`, so a reforged
hit earns slightly more; that's accepted, since levels are the progression and the cap is small.

## Server checks (a request is refused with a message when any fails)

The player owns the set; they're within `Range` of a living `Smith` model; the level is below the cap, or
the slot is unlocked; they have the materials and yen (checked and spent in one step, no partial spend);
`keep` only resolves a pending candidate that this player rolled for this set; arguments are the right
types; requests are rate-limited. Materials and yen are never negative, and a save can't hold a level above
the cap or a modifier outside its range (`Decode` clamps, drops unknown ids).

## Testing

`tests/ReforgeRules.spec.luau`, run like the other specs: costs by level; slots unlocked at 3 and 7; roll
stays in range and avoids a taken modifier; damage multiplier (levels, `Might`, half against players, the
x1.50 / x1.25 ceilings); cooldown multiplier; encode/decode round trip and clamping of bad text.

Playtest (the owner; a `2026-10-14-reforge-checklist.md` is written with the plan): the smith opens the
menu in range and not outside it; level-up spends the right materials; reroll shows old versus new and
Keep/Take old both work; a reforged weapon hits harder than before; Swift visibly shortens a cooldown;
status procs and Vampiric show up; the state survives a rejoin; PvP hits are only half as boosted.

## Not in this design

Gear, a new crit-chance mechanic, failing or losing levels, mastery-gain modifiers (they would bypass the
mastery balance), tradable materials, a way to undo a Keep.

## Needs doing in Studio (not creatable from a script)

- A smith NPC model tagged `Smith`.
- The `ReforgeAction` RemoteFunction in `ReplicatedStorage`.
- Optional: an anvil/forge VFX prefab in `ReplicatedStorage.VFXPrefabs`, played with `VFX.Play` on Keep.
- Depends on enemy drops being in Studio first (the `Mat_<key>` materials).
