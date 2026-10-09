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
| [Block, parry and posture](2026-10-09-block-parry.md) | Everyone's base defence on **E**: a front block that cuts damage by hit type, a 0.25 s parry that staggers, a posture bar that guard-breaks, bars on your HUD and over every health bar, and the shop prompt hiding in combat. Spec: `specs/2026-10-09-block-parry-design.md`. | Cloud for tasks 1–8, then Studio for task 9 (two-player playtest) | `Run docs/superpowers/plans/2026-10-09-block-parry.md with superpowers:executing-plans, tasks 1–8. Read the spec first.` Then, in Studio: `Run task 9 of docs/superpowers/plans/2026-10-09-block-parry.md.` |
| [Death stakes and the Headhunter](2026-10-09-death-stakes.md) | Dying drops 5% of your yen to your killer; the server's kill leader (3+ player kills) becomes the Headhunter, drops 20% and pays bonus XP to whoever takes their head. Head tag and feed lines. Spec: `specs/2026-10-09-death-stakes-design.md`. | Cloud for tasks 1–5, then Studio and a live server for task 6 | `Run docs/superpowers/plans/2026-10-09-death-stakes.md with superpowers:executing-plans, tasks 1–5. Read the spec first.` Then, in Studio: `Run task 6 of docs/superpowers/plans/2026-10-09-death-stakes.md.` |
| [More ways to earn mastery](2026-10-09-mastery-sources.md) | Mastery from damaging players (half rate, 500 per victim per 10 min, no repeat-kill farming), a kill bonus (half the kill XP), and training dummies up to mastery 10. Spec: `specs/2026-10-09-mastery-sources-design.md`. | Cloud for tasks 1–3, then Studio for task 4 (tag the dummies `TrainingDummy`) | `Run docs/superpowers/plans/2026-10-09-mastery-sources.md with superpowers:executing-plans, tasks 1–3. Read the spec first.` Then, in Studio: `Run task 4 of docs/superpowers/plans/2026-10-09-mastery-sources.md.` |
| [Mastery unlocks per power](2026-10-09-mastery-unlocks.md) | Each power's own skill unlock levels, plus passives, G features, Lightstep and the Gallery unlocking through mastery, with "Mastery N" locks and unlock popups. Spec: `specs/2026-10-09-mastery-unlocks-design.md`. | Cloud for tasks 1–4, then Studio for task 5 | `Run docs/superpowers/plans/2026-10-09-mastery-unlocks.md with superpowers:executing-plans, tasks 1–4. Read the spec first.` Then, in Studio: `Run task 5 of docs/superpowers/plans/2026-10-09-mastery-unlocks.md.` |
| [Quests: level quests and mastery challenges](2026-10-09-quests.md) | Repeatable "Defeat N enemies" bounties from Bounty Hunter NPCs (one at a time, paid on the spot at 1.5×), saved once-only mastery challenges per set, a tracker and a Quests menu on J. Spec: `specs/2026-10-09-quests-design.md`. | Cloud for tasks 1–6, then Studio **with you** for task 7 (real quests, givers, enemy types) | `Run docs/superpowers/plans/2026-10-09-quests.md with superpowers:executing-plans, tasks 1–6. Read the spec first.` Then, in Studio: `Run task 7 of docs/superpowers/plans/2026-10-09-quests.md with me.` |
| [HUD layout pass](2026-10-09-hud-layout.md) | A minimal top-right icon row (Settings, Inventory, Stats, Quests, Admin, yen) replacing the left buttons, key hints at the bottom left (with a setting), a less crowded bottom centre, one menu at a time. Spec: `specs/2026-10-09-hud-layout-design.md`. | Cloud for tasks 1–5, then Studio for task 6 (screen sizes; icon images with you) | `Run docs/superpowers/plans/2026-10-09-hud-layout.md with superpowers:executing-plans, tasks 1–5. Read the spec first.` Then, in Studio: `Run task 6 of docs/superpowers/plans/2026-10-09-hud-layout.md with me.` |
| [Photoshop revisual](2026-10-09-photoshop-revisual.md) | Photoshop's code-built looks replaced by imported VFX packs, one move at a time. You approve every pack before it's imported. | Studio | `Run docs/superpowers/plans/2026-10-09-photoshop-revisual.md with superpowers:executing-plans. Do one move per task, and stop for my OK on the packs and on the screenshots.` |
| Studio sync | Brings everything pushed since the last sync into Studio. Right now that's **Lightstep's lingering trail** (`Skills/Lightstep`, `SkillSetConfig`, the `SkillEffects` LocalScript; test with the last two lines of `specs/2026-10-09-balance-pass-checklist.md`) **the Gallery waypoints** (`PhotoGallery` LocalScript; test with the "Waypoints" lines of `specs/2026-10-08-photoshop-checklist.md`) and **Undo's rewind** (`PhotoshopServer`, `PhotoshopEffects`, `SkillSetConfig`, plus a one-line "Rewinding" check in `SkillSetServer`, `RangedServer`, `PunchCombat`, `SkillBar`, `Ranged`, `Punch`; test with the "G Undo" lines of the same checklist). | Studio | `Sync branch claude/vigilant-rubin-ckqtnn to Studio, following "Repo → Studio" in CLAUDE.md. Apply only what changed since the studio tag, as targeted edits, then compile-check and move the tag.` |

## Done

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
- **Saving owned sets and the loadout** (`Loadout` only lasts one session today). Needed before
  release, for every set.
- **Aido's looks:** the dragon model, `AidoAnimations`, and a VFX pack pass like Photoshop's. Do
  these after the Aido plan, once you have a model.
- **Iridescent Requiem's remaining revisual:** Z Prism Shot, C Refraction Field, Q Lightstep. This
  is Studio work where you pick the look, so a session can work through it with you directly
  (see `ROADMAP.md`).
