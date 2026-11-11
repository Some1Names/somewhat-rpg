# Plan menu

Pick one, open the session it needs, and paste its line. Each plan carries its own design, so the
session doesn't need old chats. Branch: `claude/vigilant-rubin-ckqtnn` unless the plan says
otherwise. The order to run them in is the Master plan at the top of `ROADMAP.md`.
To playtest what is already built, use the one merged run-through, [docs/playtest-checklist.md](../../playtest-checklist.md), instead of the per-system checklists in `specs/`.

- **Cloud** = a Claude Code cloud session (claude.ai/code) on this repo. Code only; it can't open
  Studio. It commits and pushes, then a Studio sync applies the change.
- **Studio** = Claude Code on your computer, in your local clone, with Studio open and the Studio
  MCP connected.

## Ready to run

| Plan | What it builds | Where | Paste this |
|---|---|---|---|
| [Equipment](2026-11-04-equipment.md) | **Tasks 1-6 built (code only, untested in-game); the Studio smoke test and the gear models are left.** Rolled Head and Body gear: `GearConfig`, `Gear`, the `GearAction` remote, effects in combat and HP, worn models, a Backpack GEAR row and MATERIAL/GEAR tabs, admin Give/Clear gear. Spec: `specs/2026-11-04-equipment-design.md`. | Studio and **you** (`ReplicatedStorage.GearModels`) | `Run the Studio smoke test in task 6 of docs/superpowers/plans/2026-11-04-equipment.md with me.` |
| [Aido](2026-10-09-aido.md) | **Tasks 1–10 built (code only, untested in-game, checklist `specs/2026-10-09-aido-checklist.md`); task 11 (Studio) left.** Aido's whole kit: Half-Life, Chain Reaction, Fuse, Catastrophe, Collapse, Total Destruction, Ground Zero, Final Cut (dragon form, works without the model). Placeholder visuals. Spec: `specs/2026-10-09-aido-design.md`. | Studio for task 11 | `Run task 11 of docs/superpowers/plans/2026-10-09-aido.md.` |
| [HUD layout pass](2026-10-09-hud-layout.md) | **Tasks 1–5 built and applied to Studio** (task 6 left: screenshots at three sizes, icon images, playtest). A minimal top-right icon row (Settings, Inventory, Stats, Quests, Admin, yen) replacing the left buttons, key hints at the bottom left (with a setting), a less crowded bottom centre, one menu at a time. Spec: `specs/2026-10-09-hud-layout-design.md`. | Cloud for tasks 1–5, then Studio for task 6 (screen sizes; icon images with you) | `Run docs/superpowers/plans/2026-10-09-hud-layout.md with superpowers:executing-plans, tasks 1–5. Read the spec first.` Then, in Studio: `Run task 6 of docs/superpowers/plans/2026-10-09-hud-layout.md with me.` |
| [Getting powers](2026-10-09-power-acquisition.md) | **Tasks 1–6 built and in Studio, gacha roll panel included** (untested in-game; task 7 is partly done, check what's left; checklist `specs/2026-10-09-power-acquisition-checklist.md`), task 7 left. One saved power + 2 storage slots + lifetime Robux powers; new powers come as briefcases from the Power Dealer (S ¥500,000), map drops and a ¥25,000 gacha; selling; death drops; no starter power. Spec: `specs/2026-10-09-power-acquisition-design.md`. | Studio, a live server and **you** for task 7 (Robux products, spawn points, briefcase model) | `Run task 7 of docs/superpowers/plans/2026-10-09-power-acquisition.md with me.` |
| [Crafting](2026-11-03-crafting.md) | **Built and in Studio (2026-11-03), untested in-game.** The 3D printer (`workspace.Printer`, a part tagged `Printer` for now): timed prints from materials and yen, recipes known or learned (yen, blueprint, bounty, faction rank), collect/cancel. Gear recipes wait for the equipment system (`ServerScriptService.Gear`); talisman recipes only matter once `TalismanConfig.OwnAll` is off. Spec: `specs/2026-11-03-crafting-design.md`. | You, in Studio | Playtest: admin Materials +50, yen, Learn all recipes, print, Finish prints, collect, cancel. |
| [Dungeons](2026-11-03-dungeon.md) | **Not built (plan written 2026-11-03).** Private party runs: a portal, difficulty tiers, hand-built rooms chained in a seeded order to a boss, shared revives, a completion chest. Five tasks: `DungeonConfig`, `DungeonRun`, `DungeonServer`, the menu and HUD, admin helpers and the smoke test. Spec: `specs/2026-11-03-dungeon-design.md`. | Cloud for tasks 1–4; Studio and **you** for task 5 (the portal, room models, the boss) | `Run docs/superpowers/plans/2026-11-03-dungeon.md, tasks 1-4. Read the spec first.` |
| [VIP perks](2026-11-02-vip-perks.md) | **Not built; four open questions for you first** (recustomize for VIPs only, the +25%, a lost third slot, pass or product). A game pass with no combat power: a tee and title, +25% XP and yen, half the fast travel cooldown, a third power storage slot. Nine small tasks. | Cloud, then **you** (the game pass and its id) | `Let's settle the open questions in docs/superpowers/plans/2026-11-02-vip-perks.md, then build it.` |
| Studio sync | Brings everything pushed since the last sync into Studio. **Nothing waiting (2026-11-10):** every script in the repo matches Studio byte for byte (253, all in `studio-manifest.json`) and the `studio` tag is at that sync. Only Studio has the baked `MapLayout` and the rigs' `Animate` and free-model scripts; leave those out. Before the next apply, compare `#Source` sizes again if Studio may have been edited since. | Studio | `Sync branch claude/vigilant-rubin-ckqtnn to Studio, following "Repo → Studio" in CLAUDE.md. Apply only what changed since the studio tag, as targeted edits, then compile-check and move the tag.` |

## Next up (listed 2026-10-27, no spec or plan yet)

Both are small. Start each with "Let's design ___" so the open questions get answered first.

- **Ragdoll when dashing.** The Q dash would end in (or pass through) a ragdoll. Hooks: `Ragdoll`
  (server), `DashRelay` (accepts a dash, sets `DodgeUntil`), `CrowdControl.CanControl`, `ActionLock`.
  Open: ragdoll *the dasher* (a tumble or roll while dashing, getting up after) or *whoever the dash
  hits*? Does it still dodge hits while ragdolled? Same for every power's dash (Lightstep,
  Step In) or only the basic one? Length and a cooldown?
- **Walk and run VFX.** Dust and footstep puffs while walking and sprinting, a speed trail when
  sprinting. Hooks: `Sprint`, `VFX.Play`, `ReplicatedStorage.VFXPrefabs`. Final looks are your VFX
  work (pack prefabs); a session only makes a placeholder client script with a clear spot for the
  prefab. Open: ground-dependent dust (grass, stone, water) or one effect? Show on other players
  too, and does the Settings "others' effects" slider hide theirs?

## Done

- [Hub menu](2026-10-14-hub-menu.md): built and in Studio (2026-10-14). Left: play
  `specs/2026-10-14-hub-menu-checklist.md` and tune the poses in `HubPoses` by eye.
- [Reforge](2026-10-14-reforge.md): built, merged and in Studio (synced 2026-10-14). Left: the checklist
  `specs/2026-10-14-reforge-checklist.md`, and [enemy drops](2026-10-14-enemy-drops.md) for the materials: built and in Studio (synced 2026-10-14;
  `DroppedItemOrb` moved to `VFXPrefabs`). Left: play `specs/2026-10-14-enemy-drops-checklist.md` (two players, UI by eye).
- Photoshop revisual (VFX packs): now **owner work** (you do the VFX; Claude only mocks up placeholders).
- [Daylight cycle](2026-10-13-daylight-cycle.md): built and in Studio (2026-10-14). Left: task 7's keyframe
  tuning by eye and the playtest (two players for "same time"); spec `specs/2026-10-13-daylight-cycle-design.md`.
- [Mastery unlocks per power](2026-10-09-mastery-unlocks.md): built and in Studio (2026-10-14). Left: the playtest with
  `specs/2026-10-09-mastery-unlocks-checklist.md`.
- [Swimmable water parts](2026-10-10-swimmable-water.md): built and in Studio (2026-10-14): the `Water` module, the `Swim`
  client script, no Gallery saves in water. Tried on a temporary pool (swim, float, buoyancy, climb a
  ledge, a pull, Dash, dying in water). **The map has no water parts yet:** build them as parts, tag each
  `Water` and turn off CanCollide/CanQuery/CanTouch, then run `specs/2026-10-10-swimmable-water-checklist.md`.
- [More ways to earn mastery](2026-10-09-mastery-sources.md): built and in Studio (2026-10-14): PvP at half rate with a
  cap, a kill bonus, training dummies to mastery 10 (the Dummy, both Strong Dummies and the Boss Dummy are
  tagged `TrainingDummy`). Checked solo: dummy rate, infinite health, the cap at 10, the NPC kill bonus.
  Left: PvP and the kill bonus on players, which need two players
  (`specs/2026-10-09-mastery-sources-checklist.md`).
- [Quests](2026-10-09-quests.md): built and in Studio (2026-10-14): three Bounty Hunters on the
  `QuestSpawn` parts (Training, Frontier, Outpost), `EnemyType` on the enemies. The quest flow was
  checked in a solo playtest (accept, 3 kills, payout, a challenge). Left: the UI by eye and the rest
  of `specs/2026-10-09-quests-checklist.md`.
- [Block and posture](2026-10-09-block-parry.md): built and in Studio, then **switched off** (owner: too much,
  `GuardConfig.Enabled = false`, applied to Studio 2026-10-16; code kept). Its two-player playtest is
  parked until it's turned back on.
- [Death stakes and the Headhunter](2026-10-09-death-stakes.md): built and in Studio, checked
  solo. Left: the live-server half of `specs/2026-10-09-death-stakes-checklist.md` (2–3 players).
- [Photoshop](2026-10-08-photoshop.md): built and in Studio. Playtest left:
  `specs/2026-10-08-photoshop-checklist.md`.
- [Photoshop punches and the Step In combo](2026-10-09-photoshop-punches.md): done and checked in
  Studio.
- [Settings: keybinds](2026-10-09-settings-keybinds.md) and
  [Settings, death screen, feedback](2026-10-09-settings-death-feedback.md): code built. Playtest
  with their checklists in `specs/`.

## Not planned yet (needs a design first)

Start any of these in a cloud session with "Let's design ___". It asks you questions, writes a
spec, then a plan that lands in this menu.

- **Himaru** (S power), **Daemon** (A power) and **Daemon's katana** (A weapon), **Kintsugi**
  (B power), **Monotwister** (Aido's katana, S weapon). Each needs its canon from you.
- **Katana moves.** The melee kind, the MELEE slot and the Katana's combo are built; its skills are
  not designed. Daemon's katana and Monotwister build on it.
- **Release safety, the tutorial quests, more enemy types, daily rewards, codes, badges, global
  leaderboards, analytics:** new on 2026-11-10, see phases 2 to 4 of the Master plan in `ROADMAP.md`.
- **Aido's looks:** the dragon model, `AidoAnimations`, and a VFX pack pass like Photoshop's. Do
  these after the Aido plan, once you have a model.
- **Iridescent Requiem's remaining revisual:** Z Prism Shot, C Refraction Field, Q Lightstep. This
  is Studio work where you pick the look, so a session can work through it with you directly
  (see `ROADMAP.md`).
