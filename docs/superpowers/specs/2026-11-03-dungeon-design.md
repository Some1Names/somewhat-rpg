# Dungeons — design

Private, party-based dungeon runs built from hand-made rooms chained in a seeded random order.
Feeds crafting (materials, boss blueprints) and, once it exists, gear (`Gear.Grant`).
Related: `2026-11-03-crafting-design.md` (blueprints, learn routes); equipment design (paused after part 1).

## Goal

A repeatable, replayable activity for a party of 1–4: enter a portal, pick a difficulty tier, fight through
a chain of rooms to a boss, and open a completion chest. Nothing is instanced today, so a run lives in its
own area of this server, cloned for the party and deleted afterwards.

## Decisions (from the owner)

- Run model: a private instance per party, in this server (no TeleportService).
- Layout: hand-built room models in Studio, chained in a seeded random order; the boss room is last.
- Entry: a portal (a Studio model tagged `Dungeon`) with difficulty tiers; no key; a per-player cooldown. Solo allowed.
- Death: the party shares a few revives; a dead player respawns at the last checkpoint room; out of revives
  with everyone down, the run fails and players leave with what they picked up.
- Boss (v1): a strong `EnemyType` enemy (`EnemyAI` combo, big health, a `dropTable`), not a `RaidBoss`.
  `RaidBoss` is keyed by boss name (`IsUp(key)`), so two parties could not fight the same boss at once.
  A multi-instance raid-style boss is a later upgrade.

## Data: `ReplicatedStorage/DungeonConfig` (pure, Lune-tested)

- Fields: `Tag = "Dungeon"`, `Remote = "DungeonAction"`, `Cooldown` (seconds, per player, from run start),
  `MaxRuns` (concurrent), `RunTimeLimit` (seconds, e.g. 1800), `DisconnectGrace = 60`, `MaxPartySize = PartyRules.MaxMembers`.
- `Dungeons`: each `{ id, name, roomsPerRun, rooms = { combat = {names}, elite = {...}, treasure = {...}, boss = {...} }, start = name, bossType, tiers }`.
- `tiers`: each `{ name, minLevel, enemyLevel, revives, lootQuality, chestYen, chestXp }`.
- Pure rules: `BuildLayout(dungeon, seed): { roomName }` (start, then `roomsPerRun` rooms from combat/elite/treasure
  without repeats, boss last; deterministic per seed), `Revives(tier)`, `CanStart(playerState, now)`,
  `RunFailed(revivesLeft, aliveCount)`, `ChestRolls(tier, random)` (yen, XP, materials, gear request).

## Room contract (what the owner builds in Studio)

Each room is a Model under `ServerStorage.DungeonRooms/<dungeon id>/` with:
- attribute `Kind` (`start`, `combat`, `elite`, `treasure`, `boss`), a `PrimaryPart`, and parts named `In` and `Out`
  (a room's `Out` is snapped to the next room's `In`);
- parts tagged `DungeonSpawn` with an `EnemyType` attribute (and optional `Count`), where enemies appear;
- a door part named `Door` on `Out`, locked until the room is cleared (a treasure/start room has none locked);
- the boss room also holds a part named `Chest` where the completion chest appears.

## Server

- `ServerScriptService/DungeonRun` (module): creates a run: takes a free far-away slot, clones the rooms in
  `BuildLayout` order into `workspace.DungeonRuns/<runId>`, spawns each room's enemies from the `EnemyType`
  entries when the party enters it, opens its door when it is cleared, saves a checkpoint per cleared room,
  counts shared revives, and ends the run (win, fail, abandon, time limit), returning players to the portal and
  freeing the slot, even after an error.
- `ServerScriptService/DungeonServer.server`: the portal `ProximityPrompt`, and the `DungeonAction` remote
  (`"start", dungeonId, tierIndex`, `"leave"`). Start checks: the caller is the party leader (or solo), every
  member is in range of the portal, off cooldown, at least the tier's `minLevel`, no run cap reached.
  Late joiners are refused once the first room is cleared.
- Enemy levels come from the tier. Drops use the existing `Drops`/`DropConfig` tables unchanged.
- Players inside a run are in a no-PvP zone; leaving checks out-of-combat rules from `CombatState`/`CombatRules`.

## Rewards

- Per kill: materials through `Drops`. The tier raises Core/Crystal chances.
- Completion chest, once per player: yen, XP, materials and, when `ServerScriptService.Gear` exists, gear through
  `Gear.Grant` at the tier's level and quality. Until then the chest pays materials instead.
- Boss blueprint: the boss's drop table can include a crafting blueprint (`Mat_<Blueprint>`, see the crafting spec);
  `PrismHelmBlueprint` may move here from Ayato Yoji.
- Failed or abandoned run: keep pickups, no chest.

## Exploit and edge cases

- Leaving mid-run: returned to the portal, keeps pickups, loses their chest share; their revive slot stays with the party.
- Disconnect: after `DisconnectGrace` they count as left; if the whole party is gone, the run is destroyed.
- Cooldown: stored per player and started at run start, so a new party can't carry a cooldown-free player.
- Concurrency: at most `MaxRuns`; a full server answers "dungeons are busy".
- Stuck run: `RunTimeLimit` ends it as a fail.

## Client

- `StarterPlayerScripts/DungeonMenu` (tier picker at the portal, through `Menus`, in the shops' look, square UI).
- `StarterPlayerScripts/DungeonHUD` (room x of N, revives left, the current objective, run timer).

## Not in this spec

- Multi-instance raid bosses, dungeon keys, per-dungeon unique mechanics, final VFX (the owner's), more than one dungeon's rooms.

## Studio tasks for the owner

- The portal model (tag `Dungeon`), the room models per the contract, the boss model (an `EnemyType`) and chest model,
  and visuals/sounds as always from imported packs.

## Testing

- Lune: `tests/DungeonConfig.spec.luau` covers deterministic `BuildLayout` per seed, no repeats, boss last, room
  count; revives per tier; cooldown; the fail condition; chest rolls by tier.
- Studio smoke test: a portal and three stub rooms (two combat, one boss): solo run, a death and revive, a full clear,
  leaving mid-run, and the cooldown. The owner playtests the rest.

## Build order

Independent of gear (the chest pays materials until `Gear.Grant` exists). Crafting gains its main blueprint
source from this; either spec can be built first.
