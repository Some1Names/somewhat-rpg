# Studio sync: Photoshop, Settings, death screen and feedback (option 3)

Everything on branch `claude/vigilant-rubin-ckqtnn` since the last Studio sync (the `studio` tag,
`e7640a5`): the Photoshop set, rebindable keys, the Settings menu with its GAMEPLAY and EFFECTS
sections, Quick respawn, the death screen, and the cast feedback.

The plan: you paste the 16 **new** scripts by hand, which uses no Claude usage. Then a local
Claude session with the Studio connection applies the 24 **changed** scripts as small edits,
checks your pastes, and compile-checks.

Get the files from your local clone (`git fetch && git checkout claude/vigilant-rubin-ckqtnn`), or
from GitHub: open the file on that branch and press **Raw**, then copy everything.

## Part A: paste the 16 new scripts (you)

In Studio, for each row: right-click the parent → Insert Object → the **class** shown. Rename it
to the **name** exactly, delete the default `print("Hello world!")`, and paste the whole file.

| # | File in the repo | Parent in Studio | Name | Class | Lines |
|---|---|---|---|---|---|
| 1 | `src/ReplicatedStorage/Keybinds.luau` | ReplicatedStorage | Keybinds | ModuleScript | 213 |
| 2 | `src/ReplicatedStorage/Preferences.luau` | ReplicatedStorage | Preferences | ModuleScript | 107 |
| 3 | `src/ServerScriptService/Framed.luau` | ServerScriptService | Framed | ModuleScript | 74 |
| 4 | `src/ServerScriptService/PhotoshopUtil.luau` | ServerScriptService | PhotoshopUtil | ModuleScript | 125 |
| 5 | `src/ServerScriptService/PhotoshopServer.server.luau` | ServerScriptService | PhotoshopServer | Script | 268 |
| 6 | `src/ServerScriptService/SettingsServer.server.luau` | ServerScriptService | SettingsServer | Script | 85 |
| 7 | `src/ServerScriptService/Skills/Shutter.luau` | ServerScriptService → Skills | Shutter | ModuleScript | 41 |
| 8 | `src/ServerScriptService/Skills/Snapshot.luau` | ServerScriptService → Skills | Snapshot | ModuleScript | 120 |
| 9 | `src/ServerScriptService/Skills/PhotoTeleport.luau` | ServerScriptService → Skills | PhotoTeleport | ModuleScript | 122 |
| 10 | `src/ServerScriptService/Skills/Desaturate.luau` | ServerScriptService → Skills | Desaturate | ModuleScript | 87 |
| 11 | `src/ServerScriptService/Skills/IrisHorizon.luau` | ServerScriptService → Skills | IrisHorizon | ModuleScript | 141 |
| 12 | `src/ServerScriptService/Skills/Kaleidoscope.luau` | ServerScriptService → Skills | Kaleidoscope | ModuleScript | 93 |
| 13 | `src/StarterPlayer/StarterPlayerScripts/PhotoGallery.client.luau` | StarterPlayer → StarterPlayerScripts | PhotoGallery | LocalScript | 210 |
| 14 | `src/StarterPlayer/StarterPlayerScripts/Settings.client.luau` | StarterPlayer → StarterPlayerScripts | Settings | LocalScript | 405 |
| 15 | `src/StarterPlayer/StarterPlayerScripts/DeathScreen.client.luau` | StarterPlayer → StarterPlayerScripts | DeathScreen | LocalScript | 129 |
| 16 | `src/StarterPlayer/StarterPlayerScripts/SkillEffects/PhotoshopEffects.luau` | StarterPlayer → StarterPlayerScripts → **SkillEffects** (the LocalScript itself) | PhotoshopEffects | ModuleScript | 590 |

Watch out for:
- **Names are case-sensitive.** The other scripts find these by name (`WaitForChild("Framed")`).
- **#16 goes inside the `SkillEffects` LocalScript**, next to `BlackHoleEffect` and `TornadoEffect`.
- **Paste the whole file**, from the first comment line to the last line. A missing last line
  breaks the script. The line counts let you check.
- **Don't playtest yet.** The new scripts need the Part B edits to run.

Also add, in Studio, a **Tool** named `Photoshop` in `ServerStorage.SkillSetTools`, with the string
attribute `SkillSet` = `Photoshop`. You can copy the Iridescent Requiem tool there and change its
name and attribute.

## Part B: the 24 changed scripts (a local Claude session)

Open Claude Code on your computer in your local clone, with Studio open and the Studio MCP
connected, and paste this prompt:

> Sync branch `claude/vigilant-rubin-ckqtnn` to Studio, following "Repo → Studio" in CLAUDE.md,
> but **only the modified files**. I've already pasted the 16 new scripts and the Photoshop Tool
> by hand.
>
> 1. `git fetch`, check out the branch, and list
>    `git diff --name-status studio..HEAD -- src/`.
> 2. For each file marked **A** (new): don't rewrite it. Check that it exists in Studio at its
>    `studio-manifest.json` path with the right class, and that its source length matches the
>    repo file. Report any that are missing or differ.
> 3. For each file marked **M** (24 files): apply the diff hunks as targeted edits to the
>    existing script. Don't paste whole files.
> 4. Compile-check in a playtest (the output window shows no script errors), then
>    `git tag -f studio HEAD` and push the tag.
>
> Keep it lean: read one file's diff at a time, and don't re-read files you've already applied.

The 24 changed scripts, for reference:

| Script (Studio path) | What changed |
|---|---|
| ReplicatedStorage.ShopConfig | Photoshop sold for ¥25,000 |
| ReplicatedStorage.SkillSetConfig | the Photoshop set, `undo`/`gallery`, `needsTarget`, `weaponName`, `takenShare`, longer reaches, faster Luminance, Lightstep's trail |
| ReplicatedStorage.StatusConfig | the Desaturated status |
| ReplicatedStorage.VFX | shake, impact frames and speed lines obey Settings |
| ServerScriptService.CrowdControl | `Held` |
| ServerScriptService.Overcharge | Mandela's bar also fills from damage taken |
| ServerScriptService.LuminanceServer | Desaturated drains light and grounds flight |
| ServerScriptService.Passives | `ResistEdit` (Mandela forgets Photoshop's edits) |
| ServerScriptService.PlayerStats | saved `PhotoGallery`, `Keybinds`, `Preferences` |
| ServerScriptService.StatusEffects | comment only |
| ServerScriptService.Skills.BlackHole | flying characters aren't pulled |
| ServerScriptService.Skills.Tornado | flying characters aren't carried |
| ServerScriptService.Skills.SpineLash | reach 40 → 80 |
| ServerScriptService.Skills.SolarLance | no extra damage when locked onto a Sunmark |
| ServerScriptService.Skills.Lightstep | the trail lingers 3 s and hurts, 3 trails at most |
| ServerScriptService.Skills.LightShot | bounces off Kaleidoscope |
| ServerScriptService.Skills.PrismShot | bounces off Kaleidoscope |
| ServerScriptService.Skills.PrismForm | Desaturated ends or blocks it |
| StarterPlayerScripts.Dash | the dash key from Keybinds |
| StarterPlayerScripts.HitFeedback | damage numbers can be turned off |
| StarterPlayerScripts.Ranged | the reload key from Keybinds; Shutter's own beam |
| StarterPlayerScripts.Inventory | key labels from Keybinds; Undo and Gallery rows |
| StarterPlayerScripts.SkillBar | keys from Keybinds; Undo on G; why-it-didn't-cast messages |
| StarterPlayerScripts.SkillEffects (LocalScript) | loads PhotoshopEffects; shake obeys Settings; Lightstep's lingering trail |

## Part C: test

Playtest with:
- `docs/superpowers/specs/2026-10-08-photoshop-checklist.md`
- `docs/superpowers/specs/2026-10-09-settings-keybinds-checklist.md`
- `docs/superpowers/specs/2026-10-09-settings-death-feedback-checklist.md`
- `docs/superpowers/specs/2026-10-09-balance-pass-checklist.md`

Saving (gallery photos, keybinds and settings) only works in a live server.
