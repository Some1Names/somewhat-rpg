# Quests (level quests and mastery challenges): design

Status: approved in chat 2026-10-09; waiting on review of this written spec.

## Intent

Give levelling a clear path (Blox Fruits-style level quests) and give each skill set goals that
teach its moves (mastery challenges, promised by the mastery work). Built so **daily challenges**
and **story quests** can be added later on the same tracking, without a rewrite.

Success: a player always knows what to do next for XP; each set has a handful of goals that make
them try every move; adding a quest is one config line plus a giver in Studio.

## A. Level quests

- **Givers:** NPC models tagged **`QuestGiver`** with a `GiverId` attribute and a ProximityPrompt
  (E; with the block plan built, prompts hide in combat). Placed in Studio by the owner.
- **The panel:** E opens a small square panel listing that giver's 2–3 quests: title, objective,
  level, reward, and **Accept**. Quests above your level show greyed out with "Lv. 30".
- **Objective (v1):** "Defeat N <EnemyType>". Enemies carry an **`EnemyType`** attribute set in
  Studio ("Bandit"); a kill counts when you get the kill credit (the existing NPC payout in
  `Damage`) on a model whose `EnemyType` matches.
- **One level quest at a time.** Accepting another replaces it. The quest lasts this session only
  (leaving drops it); dying keeps it. It can be abandoned from the Quests menu.
- **Completion:** the moment the count is reached, wherever you are: the reward is paid at once
  and a gold "Quest complete" popup shows.
- **Reward:** 1.5 × what those kills pay, on top of the kills themselves:
  `1.5 × count × StatConfig.EnemyXP(questLevel)` XP and `1.5 × count × StatConfig.EnemyYen(questLevel)` ¥.
- **Repeatable** without limit.
- **The tracker:** small, square, on the right edge of the screen: the quest title and
  "Bandits 3/6". Hidden with no quest.
- **The quest list** lives in config (`QuestConfig.Givers`): `GiverId → { name, quests = { { id,
  title, level, enemyType, count } } }`. The owner and a local session fill it in with the real
  enemies and areas (a cloud session can't see the map).

## B. Mastery challenges

- Per set, each **done once**, paying **mastery XP** to that set. A challenge appears once the
  move it's about is unlocked (its skill's mastery level; feature unlocks if the mastery-unlocks
  plan is built). Progress is **saved**.
- Kinds: `hits` (land N hits with a move), `kills` (get N kills with a move), and `event` (a move's
  script reports an event, optionally with an amount that must reach `min`; N of them).

| Set | # | Challenge | Kind | Reward |
|---|---|---|---|---|
| Mandela | 1 | Land 15 Axe Boomerang hits | hits Z, 15 | 150 |
| | 2 | Pull 3 enemies with one Event Horizon | event `EventHorizonPull` min 3, 1 | 400 |
| | 3 | Erase 25 hits from players with Misremembered | event `ErasedPlayerHit`, 25 | 1,200 |
| | 4 | Kill 3 enemies with one Tornado, 5 times | event `TornadoKills` min 3, 5 | 2,000 |
| | 5 | Land the axe finisher on someone Event Horizon exposed, 5 times | event `ExposedFinisher`, 5 | 1,000 |
| Iridescent Requiem | 1 | Land 20 Light Shots | hits ranged, 20 | 150 |
| | 2 | Hit 3 enemies with one Prism Shot | event `PrismShotHits` min 3, 1 | 400 |
| | 3 | Flash through 10 enemies with Lightstep | hits dash, 10 | 600 |
| | 4 | Stay in the air 90 s without landing | event `FlightTime` min 90, 1 | 1,200 |
| | 5 | Hit a Sunmarked target with Solar Lance, 5 times | event `MarkedLance`, 5 | 1,000 |
| Photoshop | 1 | Frame 10 enemies with Snapshot | event `Framed`, 10 | 150 |
| | 2 | Land all 3 punches of the Step In combo, 5 times | event `StepInCombo` min 3, 5 | 600 |
| | 3 | Cut & Paste an enemy, 5 times | event `CutPaste`, 5 | 600 |
| | 4 | Undo 10 times, healing at least 20 each time | event `UndoHeal` min 20, 10 | 400 |
| | 5 | Catch a target in Iris Horizon without them escaping, 5 times | event `IrisCaught`, 5 | 1,000 |
| Revolver | 1 | Land 30 shots | hits ranged, 30 | 150 |
| | 2 | Kill 3 enemies with Dead Eye | kills X, 3 | 400 |

Aido's list comes with Aido (its plan adds it: e.g. stick 10 Fuses on enemies; pull 3 with one
Collapse).

- "Hits" and "kills" count NPCs and players alike (PvP counts).
- Completing one: the mastery XP is added and a gold "Challenge complete" popup shows.

## The Quests menu

- **J** opens it (a fixed menu key like B, M and P; J is removed from the keys skills can be
  rebound to). Square, like the other menus.
- **Quest tab:** the current level quest (objective, progress, reward, **Abandon**).
- **Challenges tab:** the held set's challenges (and a set picker for the others you own): each
  with its progress bar, reward, and done ✓; locked ones show the move's mastery level.

## Architecture

- **`ReplicatedStorage/QuestConfig.luau`:** `RewardShare = 1.5`, `Givers`, `Challenges` (per set,
  the table above as data: `{ id, text, kind, skill?, event?, min?, count, reward }` where `skill`
  is a key, `"ranged"` or `"dash"`), and pure, Lune-tested helpers: `reward(count, level)`,
  `encode(progress) / decode(text)` (the saved text, e.g. `"Mandela.1=7;Mandela.2=done"`),
  `advance(challenge, progress, amount?) -> (newProgress, done)`.
- **Move tags:** every skill module's damage options gain `skill = "<Key>"` (Z/X/C/V/F),
  ranged handlers `skill = "ranged"`, Lightstep `skill = "dash"`. `Damage.LastHit` also keeps
  `skill`, so kills know the move.
- **`ServerScriptService/Quests.luau`** (module) + **`QuestServer.server.luau`:** the level quest
  state per player (session), the giver remote (`Quest` RemoteEvent: `"accept", giverId,
  questId` / `"abandon"`), kill counting from `Damage`'s NPC payout, and the challenges:
  `Damage.OnDealt` for `hits`, the kill credit for `kills`, and
  **`Quests.Report(player, setName, event, amount?)`** for `event` kinds, called from the move
  scripts listed above (BlackHole, Passives, Tornado, PunchCombat's exposed finisher, PrismShot,
  LuminanceServer, SolarLance, Snapshot, PhotoTeleport, PhotoshopServer, IrisHorizon).
- **Saving:** a new `PlayerStats` text field **`Challenges`**, with its own longer limit (1,000
  characters; the shared limit stays 200).
- **Client:** `QuestBoard.client.luau` (giver panel via `ProximityPromptService.PromptTriggered`
  for `QuestGiver` models), the tracker, the Quests menu (J), the popups.

## Later (not in v1)

Daily challenges (C) and story quests (D) reuse `Quests.Report` and the kinds; quests that need
hand-ins, items or areas wait for those systems. Boss mastery belongs to the boss rework.

## Testing

- Lune: `tests/QuestConfig.spec.luau`: `reward(6, 15)` against `StatConfig` maths (XP and ¥),
  encode/decode round-trips (empty, a count, done, unknown ids dropped), `advance` for each kind
  (an event below `min` doesn't count; `done` stays done).
- StyLua parse and selene.
- In-game checklist `docs/superpowers/specs/2026-10-09-quests-checklist.md`.
