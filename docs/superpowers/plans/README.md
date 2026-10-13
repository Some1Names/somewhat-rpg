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
| [Aido](2026-10-09-aido.md) | Aido's whole kit: Half-Life, Chain Reaction, Fuse, Catastrophe, Collapse, Total Destruction, Ground Zero, Final Cut (dragon form, works without the model). Placeholder visuals. Spec: `specs/2026-10-09-aido-design.md`. | Cloud for tasks 1–10, then Studio for task 11 | `Run docs/superpowers/plans/2026-10-09-aido.md with superpowers:executing-plans, tasks 1–10. Read the spec first.` Then, in Studio: `Run task 11 of docs/superpowers/plans/2026-10-09-aido.md.` |
| [Mastery unlocks per power](2026-10-09-mastery-unlocks.md) | Each power's own skill unlock levels, plus passives, G features, Lightstep and the Gallery unlocking through mastery, with "Mastery N" locks and unlock popups. Spec: `specs/2026-10-09-mastery-unlocks-design.md`. | Cloud for tasks 1–4, then Studio for task 5 | `Run docs/superpowers/plans/2026-10-09-mastery-unlocks.md with superpowers:executing-plans, tasks 1–4. Read the spec first.` Then, in Studio: `Run task 5 of docs/superpowers/plans/2026-10-09-mastery-unlocks.md.` |
| [HUD layout pass](2026-10-09-hud-layout.md) | A minimal top-right icon row (Settings, Inventory, Stats, Quests, Admin, yen) replacing the left buttons, key hints at the bottom left (with a setting), a less crowded bottom centre, one menu at a time. Spec: `specs/2026-10-09-hud-layout-design.md`. | Cloud for tasks 1–5, then Studio for task 6 (screen sizes; icon images with you) | `Run docs/superpowers/plans/2026-10-09-hud-layout.md with superpowers:executing-plans, tasks 1–5. Read the spec first.` Then, in Studio: `Run task 6 of docs/superpowers/plans/2026-10-09-hud-layout.md with me.` |
| [Getting powers](2026-10-09-power-acquisition.md) | One saved power + 2 storage slots + lifetime Robux powers; new powers come as briefcases from the Power Dealer (S ¥500,000), map drops and a ¥25,000 gacha; selling; death drops; no starter power. Spec: `specs/2026-10-09-power-acquisition-design.md`. | Cloud for tasks 1–6, then Studio, a live server and **you** for task 7 (Robux products, spawn points, briefcase model) | `Run docs/superpowers/plans/2026-10-09-power-acquisition.md with superpowers:executing-plans, tasks 1–6. Read the spec first.` Then, in Studio: `Run task 7 of docs/superpowers/plans/2026-10-09-power-acquisition.md with me.` |
| [Swimmable water parts](2026-10-10-swimmable-water.md) | The map's water parts (kept as parts) become swimmable: float at the surface, swim where the camera points, Space to rise and climb out, swim animation. Parts tagged `Water`. | Cloud for tasks 1–3, then Studio for task 4 (tag the parts, tune the feel) | `Run docs/superpowers/plans/2026-10-10-swimmable-water.md with superpowers:executing-plans, tasks 1–3.` Then, in Studio: `Run task 4 of docs/superpowers/plans/2026-10-10-swimmable-water.md with me.` |
| [Photoshop revisual](2026-10-09-photoshop-revisual.md) | Photoshop's code-built looks replaced by imported VFX packs, one move at a time. You approve every pack before it's imported. | Studio | `Run docs/superpowers/plans/2026-10-09-photoshop-revisual.md with superpowers:executing-plans. Do one move per task, and stop for my OK on the packs and on the screenshots.` |
| Studio sync | Brings everything pushed since the last sync into Studio. Nothing is waiting right now (last sync 2026-10-14: Mastery sources). | Studio | `Sync branch claude/vigilant-rubin-ckqtnn to Studio, following "Repo → Studio" in CLAUDE.md. Apply only what changed since the studio tag, as targeted edits, then compile-check and move the tag.` |

## Done

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
