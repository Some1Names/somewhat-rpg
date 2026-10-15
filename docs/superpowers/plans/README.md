# Plan menu

Pick one, open the session it needs, and paste its line. Each plan carries its own design, so the
session doesn't need old chats. Branch: `claude/vigilant-rubin-ckqtnn` unless the plan says
otherwise.

- **Cloud** = a Claude Code cloud session (claude.ai/code) on this repo. Code only; it can't open
  Studio. It commits and pushes, then a Studio sync applies the change.
- **Studio** = Claude Code on your computer, in your local clone, with Studio open and the Studio
  MCP connected.

## Ready to run

| Plan | What it builds | Where | Paste this |
|---|---|---|---|
| [Aido](2026-10-09-aido.md) | **Tasks 1–10 built (code only, untested in-game, checklist `specs/2026-10-09-aido-checklist.md`); task 11 (Studio) left.** Aido's whole kit: Half-Life, Chain Reaction, Fuse, Catastrophe, Collapse, Total Destruction, Ground Zero, Final Cut (dragon form, works without the model). Placeholder visuals. Spec: `specs/2026-10-09-aido-design.md`. | Studio for task 11 | `Run task 11 of docs/superpowers/plans/2026-10-09-aido.md.` |
| [HUD layout pass](2026-10-09-hud-layout.md) | **Tasks 1–5 built and applied to Studio** (task 6 left: screenshots at three sizes, icon images, playtest). A minimal top-right icon row (Settings, Inventory, Stats, Quests, Admin, yen) replacing the left buttons, key hints at the bottom left (with a setting), a less crowded bottom centre, one menu at a time. Spec: `specs/2026-10-09-hud-layout-design.md`. | Cloud for tasks 1–5, then Studio for task 6 (screen sizes; icon images with you) | `Run docs/superpowers/plans/2026-10-09-hud-layout.md with superpowers:executing-plans, tasks 1–5. Read the spec first.` Then, in Studio: `Run task 6 of docs/superpowers/plans/2026-10-09-hud-layout.md with me.` |
| [Getting powers](2026-10-09-power-acquisition.md) | **Tasks 1–6 built and in Studio, gacha roll panel included** (untested in-game; task 7 is partly done, check what's left; checklist `specs/2026-10-09-power-acquisition-checklist.md`), task 7 left. One saved power + 2 storage slots + lifetime Robux powers; new powers come as briefcases from the Power Dealer (S ¥500,000), map drops and a ¥25,000 gacha; selling; death drops; no starter power. Spec: `specs/2026-10-09-power-acquisition-design.md`. | Studio, a live server and **you** for task 7 (Robux products, spawn points, briefcase model) | `Run task 7 of docs/superpowers/plans/2026-10-09-power-acquisition.md with me.` |
| Studio sync | Brings everything pushed since the last sync into Studio. **Nothing waiting now** (the `studio` tag is at HEAD, 2026-10-15: power aura, sound effects, melee hitboxes, Prism Form trail all in). Last sync before that: 2026-10-14, enemy drops. | Studio | `Sync branch claude/vigilant-rubin-ckqtnn to Studio, following "Repo → Studio" in CLAUDE.md. Apply only what changed since the studio tag, as targeted edits, then compile-check and move the tag.` |

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
- [Block and posture](2026-10-09-block-parry.md): built and in Studio (parry dropped for now, 2026-10-13); compile-checked,
  and the server rules smoke-tested. Left: the playtest with `specs/2026-10-09-block-parry-checklist.md`
  (two players).
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
- **The katana weapon kind** (a katana combo and the MELEE inventory slot), needed before Daemon's
  katana and Monotwister.
- **Aido's looks:** the dragon model, `AidoAnimations`, and a VFX pack pass like Photoshop's. Do
  these after the Aido plan, once you have a model.
- **Iridescent Requiem's remaining revisual:** Z Prism Shot, C Refraction Field, Q Lightstep. This
  is Studio work where you pick the look, so a session can work through it with you directly
  (see `ROADMAP.md`).
