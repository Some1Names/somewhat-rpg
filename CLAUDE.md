# Somewhat RPG Game

A Roblox RPG (place 18888856538, owner xNagitox) with anime-style powers ("skill sets") from the
owner's manga. The game itself lives in Roblox Studio. This repo holds **a copy of every script**,
so the code can be worked on outside Studio, for example from a Claude Code cloud session.

## What this repo is, and isn't

- `src/` mirrors the scripts in Studio, in Rojo-style names (`.server.luau` = Script,
  `.client.luau` = LocalScript, `.luau` = ModuleScript, `init.*` = a script that has scripts
  inside it). `studio-manifest.json` maps each file to its exact instance path and class in Studio.
- **Only scripts are here.** Parts, models, UI that scripts build at runtime aside, prefabs
  (`ReplicatedStorage.VFXPrefabs`), animations, sounds, the map and Workspace scripts (free-model
  and rig `Animate` scripts) exist only in Studio. Don't invent instances: if code needs one that
  isn't created by a script, say so in your summary so it can be added in Studio.
- **Studio is the source of truth.** Nothing here runs by itself; a change counts once it's in
  Studio (see "Syncing with Studio").

## Working from a cloud session

A cloud session has no Roblox Studio connection. It can read and edit `src/`, but it cannot
playtest, take screenshots, inspect or move instances, publish animations or upload images.

- Keep changes reviewable and say clearly what you could not verify. The owner playtests
  themselves; list exactly what to try in-game.
- Commit with clear messages and push your branch. A local session with the Studio connection
  applies the diff to Studio.
- Luau syntax: there's no Luau toolchain installed by default. If you can, install `luau` /
  `luau-analyze` or `selene` to check syntax; otherwise read your edits carefully, since a syntax
  error breaks the whole script in-game.

## Owner's standing preferences

- UI is square everywhere: no rounded corners (`UICorner`). Two exceptions: the buttons up in
  Roblox's top bar (`TopBar`), which are dressed as Roblox's own rounded pills, and the small round
  dot a proximity prompt shows before you're in range (`PromptUI`).
- The owner playtests; don't claim something works in-game unless it was actually tested.
- All player damage goes through `ServerScriptService/Damage.luau` (`Damage.Deal`).
- Any upload to the owner's Roblox account (images, animations) needs their OK first.
- Match the surrounding code: comment density, naming, and the existing helpers.
- Top-of-screen UI: buttons in Roblox's top bar look like Roblox's own (dark see-through pills, white
  icons); other top-of-screen UI is plain icons and text, white with a dark stroke.
- Real VFX come from imported effect/particle packs (or assets from VFX websites), set up as
  prefabs in `ReplicatedStorage.VFXPrefabs` and played with `VFX.Play`. Don't design final
  visuals from Roblox's stock particles or parts built in code; those are placeholders only,
  until the pack prefab exists.

## Architecture (where things live)

- **Config modules** (`src/ReplicatedStorage`): `SkillSetConfig` (every skill set: tier, keys,
  cooldowns, aim specs, `handler` names, passives, flight, forms), `StatConfig` (levels, stats, HP
  per Vitality, enemy scaling), `PunchConfig` (melee weapons/combos), `ShopConfig`,
  `StatusConfig` (Burnt/Bleeding/Poisoned/Weakened), `QuestConfig` (bounties, mastery challenges,
  their saved text), `GuardConfig` (block and posture numbers), `Water` (is a point inside a part tagged `Water`;
  the water is parts, so `Swim` scripts the swimming), `VFX` (client effects toolkit).
- **Skills**: each skill's server logic is a ModuleScript in `ServerScriptService/Skills` with
  `Cast(player, character, aim)` (and optional `Recast`), named by `handler` in SkillSetConfig.
  `SkillSetServer` validates casts (mastery, cooldowns via `SkillCooldowns`, `overchargedOnly`,
  `charges`) and calls the handler.
- **Visuals** are client-side: the server fires `ReplicatedStorage.SkillEffects`
  (`FireAllClients(kind, ...)`), and `StarterPlayerScripts/SkillEffects/init.client.luau` draws
  `effects[kind](...)`. A player's own instant visuals go through the `LocalSkillEffect` bindable.
  `VFX.Play(path, where, { scale, color, ... })` plays prefabs from `VFXPrefabs` (they exist only
  in Studio; attributes EmitCount/EmitDuration/Tint on their emitters drive them).
- **Combat systems**: `Damage` (stat scaling, kill credit, `LastAttacker`/`LastHit`, `OnDealt`,
  `OnKill`, and skill-set mastery from hits, kills and training dummies via `MasteryRules`),
  `CrowdControl` (PvP hold protection and immunity; ask `CanControl` before moving or stunning a
  player), `Guard` (block and posture: every hit on a player goes through `Guard.Resolve`; tag a
  damage call's `options.guard`), `ActionLock` (can't act: rewinding, blocking, stunned),
  `StatusEffects`, `Passives`, `Overcharge`, `Projectiles`, `Sunmark`, `Ragdoll`.
  `CombatState` (Mandela V's mutes, marks and erased skills; the 30 s out-of-combat rule and numbers are
  in `CombatRules`, Lune-tested; `CombatTimer` shows the last 10 s; `SkillSetServer` asks `Blocked`).
- **Player data**: `PlayerStats` (attributes, DataStore save/load; Studio can't reach DataStores),
  `Powers` (the one held power, 2 storage slots, Robux lifetime powers, briefcase Tools, death drops; saved
  as `CurrentPower`/`PowerStorage`/`LifetimePowers`; numbers and pure rules in `PowerConfig`, Lune-tested;
  `PowerSources` has the gacha, map drops and Robux receipts; Developer Products are the owner's to create),
  `Loadout` (weapons, and who owns what), `ShopServer`, `KillFeed`.
- **Character slots**: 3 per player, each its own DataStore key (`<UserId>_<slot>`, plus `<UserId>_meta` for the
  slot screen's summaries; an older single save is copied into slot 1). `PlayerStats` loads nothing on join: it
  loads the slot the player picks (`LoadSlot`); keybinds, preferences and the seen-update flag are the
  player's own (`<UserId>_account`, read on join). `SlotConfig` (names, look palettes/text, keys; pure, Lune-tested),
  `Slots` (server: meta, create/select/delete, holds the player anchored and shielded until they pick) +
  `SlotServer` (the `SlotAction` remote), `CharacterLook` (paints the R15 rig; hair/face parts in
  `ReplicatedStorage.CharacterParts`, the owner's), client `SlotMenu` (the 3 cards PLAY opens) and `Customizer`
  (tabs, square hair/face tiles, one colour wheel; a look's colours are free RGB, saved as hex). The hub
  slot cards show level, yen and take their colour from the held power; the player is R15 only (every published
  animation is R15), enforced by an R15 `StarterPlayer.StarterCharacter` rig that exists only in Studio (no script
  makes it; the old R6 one is `ServerStorage.StarterCharacterR6`); NPC and boss models are still R6. The hub
  Profile names the character by its codename (`CharName`) with the real `@username` under it; `Slots` bumps the
  character's `LookRev` after each paint so `HubPose` redraws its model.
- **Quests**: `Quests` (module) + `QuestServer`: bounties from NPCs tagged `QuestGiver` (a `GiverId`
  attribute; enemies carry an `EnemyType`), and per-set mastery challenges saved in the `Challenges`
  text. Every `Damage.Deal` options table carries `skill = "<key>"|"ranged"|"dash"|"melee"` so
  hits and kills know their move; moves report other things with `Quests.Report(player, set,
  event, amount)`. New givers/quests/challenges are data in `QuestConfig`.
- **Reforge**: a smith (a model tagged `Smith`) takes drop materials (`Mat_<key>`) and yen to level
  up (to 10) and reroll the two modifier slots of any owned skill set. Numbers in `ReforgeConfig`,
  pure rules in `ReforgeRules` (Lune-tested), per-player state and checked actions in the `Reforge`
  module (saved as the `Reforge` text, mirrored as `Reforge_<Set>` attributes), the smith's remote in
  `ReforgeServer`. `Damage.Deal` and `SkillSetServer` read the bonuses; status procs and lifesteal
  run from a `Damage.OnDealt` listener in `ReforgeServer`.
- **Fast travel**: every model tagged `SpawnSetter` (the Spawn Keepers) is a travel point; their talk's "travel" reply
  opens `FastTravelMenu` (client: a full-screen map in the shops' look over `MapModel`, the map blocks it shares with
  `MapMenu`). `FastTravelServer` (the `FastTravel` RemoteFunction, made by script) decides every trip: at a keeper, a
  real and unlocked point, out of PvP combat, off cooldown; it streams the destination in and lands the player in front
  of its keeper. Numbers and pure rules in `FastTravelConfig` (Lune-tested): `Tag` moves it to another NPC, `IsUnlocked`
  is the one unlock rule (every point until `RequireUnlock`). A keeper's map name is its `PlaceName` attribute, else its
  `ZoneConfig` area.
- **Enemy drops**: enemies tagged `Enemy` drop materials as orbs. `DropConfig` has the numbers and pure rules
  (Lune-tested); `Drops` tracks damage per enemy (`Damage.OnDealt`), rolls for each player who dealt 10% on
  `Damage.OnKill`, and runs the pickup loop; orbs are parts in `workspace.Drops` cloned from
  `VFXPrefabs.DroppedItemOrb`, owner-only for 30 s. The bag is the saved `Mat_<key>` attributes (Reforge spends
  them). `DropClient` hides others' orbs and pops up "+N".
- **Enemy types**: a model's `EnemyType` attribute picks an entry in `EnemyConfig` (pure, Lune-tested): per-type settings, an
  `AggroRange` (it goes for players who walk close, inside its leash), a `attacks` combo with an optional lunge, a `dropTable` and a
  drop-only `talisman` roll. Order: the model's attribute, then the entry, then `EnemyAI`'s defaults. The Henchman is the first
  (jab, jab, lunging heavy; Thug Badge material; Thug's Knuckle talisman). `TalismanConfig` items with `dropOnly` stay out of the chests.
- **Client UI**: `Hub` (module: the full-screen hub menu, LEGACY/Arknights editorial style; tabs
  are scripts that call `Hub.Tab(name, opts)` and build in the frame it returns; pure rules in
  `HubRules`, Lune-tested; the accent is the held power's colour), its tabs `HubProfile` (Profile),
  `Inventory` (Backpack, B), `Quests` (J), `StatsMenu` (Stats, with a Milestones sub-tab), `MapMenu` (Map, M: a 3D model in a ViewportFrame, opens on the player, right-drag tilts it, built from `MapLayout`, which
  `tools/bake_map.luau` bakes from the parts, re-bake after map changes; NPC and far party-mate
  positions from `MapServer`, since streaming is on; grey until a player has been near, then painted in the parts' colours, saved as the
  `Explored` text) and
  `UpdateNotes` (Updates), `HubPose` (the player's posed character over the hub; poses in
  `HubPoses`), `SkillBar`, `AdminPanel`, `ShopMenu`,
  `StatusHUD`, `OverheadHealth`, `Hotbar`, `KillFeed`, `QuestBoard` (Bounty Hunter panel, tracker,
  popups), `Block` (E), `ReforgeMenu` (the smith), `TopBar` (the top-right icon row, the yen and the
  Menu icon), `KeyHints` (bottom-left move hints), `Leaderboard` (Tab: the player list in place of Roblox's own), `Compass` (a strip in the middle of Roblox's top bar: points,
  the Headhunter, party mates and the bounty's nearest target, far ones from `MapServer`'s `MapPosition`/`QuestTarget`), `XPBar` (bottom left, under the cards), `PickupFeed` (above the yen: XP and yen per source, from `PlayerStats.Source`, and materials picked up, edged in the rarity colour), the combo counter (the last row of `StatusHUD`:
  hits landed, `Damage.Deal` bumps the player's `HitsLanded` attribute), `LowHealth` (red screen edges), `ZoneName`
  (area names from `ZoneConfig`, a mockup until the map is done; their numbers in `HudConfig`, pure rules in `HudRules`,
  Lune-tested), `PreloadAnimations` (loads every animation on join), `LoadingScreen` (in `ReplicatedFirst`; fades once `TitleMenu` is Ready), `TitleMenu` (on join: PLAY / SETTINGS / UPDATES over a camera drifting through the `workspace.MenuCameras` parts, a Persistent model, or circling the spawn), and `Menus` (module: one menu open at a time;
  every menu calls `Menus.Open/Close` and `Menus.Register`; shared HUD numbers and icon ids are in
  `HudConfig`).
- **Build depth**: six stats (Vitality, Strength, Superliminal, Firearm, Agility, Willpower), each capped at a quarter of the
  level points (`StatConfig.MaxStatPoints`, 75 at level 100; it rises with `MaxLevel`, so four stats can max, not six). A set can have `requires = { Stat = points }` in `SkillSetConfig`; `BuildCheck` (server)
  refuses its skills, shots, swings and equip below it. Talents (`TalentConfig`: a tier opens at 15/30/50 points in its
  stat, equipping costs talent points, 1 per 5 levels) are the saved, replicated `Talents` text; the pure rules are in
  `BuildRules` (Lune-tested), `Talents` validates equips (`EquipTalent` remote, created by script) and prunes talents a
  player no longer qualifies for. Effects are read with `BuildRules.PlayerModifier(player, kind, damageStat)` in
  `Damage`, `Guard`, `StatusEffects`, `PlayerStats` (max HP), `Health` (regen) and `Stamina`.
- **Combat feel**: the Q dash is the dodge. `DashRelay` accepts a dash (least `CombatFeel.DodgeRecovery` between two)
  and sets the character's `DodgeUntil`; `Damage.Deal` and `EnemyAI`'s swing miss a player inside it (status ticks and
  `options.unavoidable` still land); Agility widens the window. Enemies swing a quick or a heavy attack
  (`EnemyAttackConfig`; heavy is slow, harder and can't be staggered out of) and tell clients to draw a
  `SkillEffects` "Telegraph" for the wind-up. Melee swings cost stamina and slow your walk (`CombatFeel`, `Punch`,
  `Sprint`). Block is not basekit: only a set or weapon with its own `block` table can block (`Guard.CanBlock`);
  `GuardConfig.Enabled` is still off. Cues are placeholders until the owner's VFX.
- **Raid bosses**: `RaidConfig` (numbers, phases, moves, the QTE; pure, Lune-tested), `RaidBoss` (module: spawns and fights one;
  `Damage.SetAbsorber` gives it Misremembered and the dome's shield), `RaidServer` (spawns each on the workspace part its `arena` names, on a
  timer; admin panel WORLD page spawns/removes), `RaidClient` (boss bar, banners, ground warnings, the grab QTE). Hide Seto (Mandela,
  Lv 90) is the first: he spawns on `workspace.MandelaSpawn`, his model is `ServerStorage.Bosses.HideSeto` (R6); drops via his `EnemyConfig` entry.
  Ayato Yoji (Iridescent Requiem, Lv 95) is the second: his moves are in `RaidAyato` (built from RaidBoss's `kit`), he flies
  on a timer (`flight`), and his ultimate needs players inside the safe domes; arena `workspace.AyatoSpawn`, model `ServerStorage.Bosses.AyatoYoji`.
- **Factions and parties**: `FactionConfig` (three factions, their rank names, colours and shop discount; pure rules, Lune-tested), `Factions` + `FactionServer` (a model tagged `FactionRecruiter` opens the `FactionMenu` close-up; JOIN goes through the `FactionAction` remote; standing from kills; saved `FactionData`), the overhead title in `OverheadHealth` and a card in `HubProfile`. Parties: `PartyRules` (pure, Lune-tested), `Party` + `PartyServer` (the `PartyAction` remote), the hub tab `PartyMenu` and `PartyHUD`.
- **Crafting**: the 3D printer (anything tagged `Printer`, a part or model). The real one is the `workspace.Printer` model: its
  `ProximityPrompt` child (the console) gets the prompt, `Scanner` rides up and down and `Slot1`..`Slot3` show your prints
  (client `PrinterVisuals`: growing holograms, sparks, placeholders until the owner's VFX).
  `CraftConfig` (recipes, job slots by level, the saved `PrintJobs` "recipe|seed|finishAt" and `RecipesKnown` texts; pure,
  Lune-tested), `Crafting` (server: Start/Collect/Cancel/Learn, all-or-nothing; the result rolls from the job's seed at
  collect), `CraftServer` (the `CraftAction` RemoteFunction, made by script; range and busy checks), client `PrinterMenu`
  (adds the prompt itself). Learn routes: yen, a blueprint material (`DropConfig`), a bounty (`Quests` teaches it when
  done) or a faction rank. Gear outputs go through `Gear.Grant` (Equipment).
- **Equipment**: rolled Head and Body gear. `GearConfig` (rarities, bases, affixes, the saved `GearBag`/`GearWorn` texts and
  every pure rule; Lune-tested) rolls a piece once and saves its values, so rebalancing never changes owned pieces. `Gear`
  (server: `Grant` refuses a full bag so a craft is never thrown away, `GrantOrSalvage` for drops, `Equip` swaps in place,
  `Unequip`, `Salvage`, heal on kill) + `GearServer` (the `GearAction` remote, made by script) + `GearVisuals` (worn
  pieces show as an Accessory from `ReplicatedStorage.GearModels/<base model>`, the owner's; `HidesHair` hides painted hair).
  Effects are read beside the talismans' in `Damage`, `PlayerStats` (max HP), `Health` and `Chests`; gear stat points raise
  damage and HP only, never build requirements or talents. The Backpack (`Inventory`) has a GEAR row (Head, Body) under the
  talismans, and its MATERIALS list became a tab of cards (with a USED IN list); GEAR is a tab too.
- **Melee weapons**: a set with `kind = "melee"` fills the hotbar's MELEE slot (saved as the `MeleeSet` attribute, kept by `Loadout`
  like `WeaponSet`) and swings a combo from `PunchConfig.Weapons`. Its Tool needs a `SkillSet` attribute. Katana (B, needs 5 Strength,
  shop ¥1,200) is the first; no moves yet.
- Sets so far: Mandela (S power, green; overcharge "Backbone Power"), Iridescent Requiem (S power,
  orange #FF9A3C / cyan #3CE0E6, Luminance passive, flight, Prism Form), Revolver (B weapon).

## Syncing with Studio (done by a local session that has the Studio MCP)

The `studio` git tag marks the commit whose `src/` matches Studio.

**Repo → Studio** (after a cloud session pushes):
1. `git fetch` and review `git diff studio..origin/<branch> -- src/`.
2. Apply each changed file to its instance from `studio-manifest.json`: small hunks as targeted
   edits; new files as new scripts with the class/RunContext the suffix implies (add them to the
   manifest by re-exporting afterwards).
3. Compile-check in Studio (playtest console), then move the tag: `git tag -f studio <commit>`.

**Studio → Repo** (after edits made directly in Studio):
1. In the Edit datamodel run `tools/export_chunk.luau` with `__START_I__, __START_OFF__` set to
   `1, 0`. The output is saved to a file; read its `nextI`/`nextOff` and run again from there
   until `done` is true.
2. `python tools/assemble_export.py <slice1.json> <slice2.json> ...` rewrites `src/` and
   `studio-manifest.json` (it fails if any script's length doesn't match Studio's).
3. Commit ("Sync from Studio") and `git tag -f studio`.

Export first if Studio has changed since the last sync, so cloud work starts from current code.
