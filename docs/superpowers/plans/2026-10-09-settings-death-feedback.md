# More Settings, Death Screen and Cast Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Quick respawn, Camera shake, Flashes & impact frames and Damage numbers settings; a death screen; and messages saying why a skill press was refused.

**Architecture:** A pure shared `Preferences` module (Lune-tested, like `Keybinds`) holds the toggles and their saved string. `SettingsServer` saves it and handles Quick respawn. The effect helpers (`VFX`, SkillEffects' local shake, `HitFeedback`) check it at the source. A new `DeathScreen` LocalScript uses the existing KillFeed message. `SkillBar`'s `readyToCast` returns a reason, which a new feedback line shows.

**Tech Stack:** Roblox Luau; Lune for `tests/*.spec.luau`; StyLua parse + selene undefined-variable gate.

**Spec:** `docs/superpowers/specs/2026-10-09-settings-death-feedback-design.md`

## Global Constraints

- Options, in order: `QuickRespawn` "Quick respawn" (GAMEPLAY, default false); `CameraShake` "Camera shake" (EFFECTS, true); `Flashes` "Flashes & impact frames" (EFFECTS, true); `DamageNumbers` "Damage numbers" (EFFECTS, true).
- Saved attribute `Preferences`, form `"QuickRespawn=1,CameraShake=0"`, only non-defaults, at most 200 chars; values only `0`/`1`.
- Server: `SetPreferences` RemoteEvent, the same checks and throttle (0.5 s) as `SetKeybinds`.
- `QUICK_RESPAWN_DELAY = 0.1` s; `FEEDBACK_TIME = 1.2` s.
- Message copy exactly as in the spec's tables (e.g. `Snapshot: 3s cooldown`, `Overcharge ready in 12s`, `Undo ready in 5s`, `Not enough light to fly`).
- UI square (no `UICorner`), house style.
- `Preferences` must not touch `game` when required (Lune).

## Review Focus

1. **Quick respawn racing something else** (the player leaves, an admin respawns them, or they die again within 0.1 s): `LoadCharacter` only runs if the player is still in the game and `player.Character` is still the dead character (Task 2).
2. **The KillFeed message and the client's Died event arriving in either order**: the death screen keeps the newest KillFeed entry for the local UserId (with `os.clock()`) and, on death, waits up to 0.5 s for one newer than the death (Task 5).
3. **Preferences read on the server or before they load**: `VFX` checks only run on the client; `Get` falls back to defaults while the attribute is nil (Task 1 test `parse_nil_is_defaults`; Task 3).
4. **Mashing a refused key**: one feedback line, replaced and its timer restarted, never stacked (Task 6).
5. **Quick respawn toggled on while already dead**: the death screen stays and the normal respawn happens. Only deaths after the toggle are instant (Tasks 2 and 5 check the value at death time).

---

### Task 1: The Preferences module (TDD with Lune)

**Files:**
- Create: `src/ReplicatedStorage/Preferences.luau`, `tests/Preferences.spec.luau`
- Modify: `tests/run.sh` (run every `tests/*.spec.luau`; fail if any fails)

**Interfaces:**
- Produces (pure): `Preferences.Attribute = "Preferences"`, `Preferences.MaxLength = 200`, `Preferences.Options` (`{ id, label, section, default }` in the order above), `Preferences.Defaults() -> { [id]: boolean }`, `Preferences.Parse(text: any) -> map`, `Preferences.Serialize(map) -> string`, `Preferences.Valid(map) -> boolean`.
- Produces (game, lazy): `Preferences.For(player, id) -> boolean` (parses that player's attribute), `Preferences.Get(id) -> boolean` (the local player's; cached per attribute text), `Preferences.Changed(callback) -> RBXScriptConnection`.

- [ ] **Step 1: Write the failing tests** (`tests/Preferences.spec.luau`, same `check` harness as `Keybinds.spec.luau`):
  - `defaults`: `QuickRespawn == false`, `CameraShake == true`, `Flashes == true`, `DamageNumbers == true`
  - `parse_nil_is_defaults`: `Parse(nil)`, `Parse("")`, `Parse(5)` equal `Defaults()`
  - `parse_values`: `Parse("QuickRespawn=1,CameraShake=0")` → `QuickRespawn == true`, `CameraShake == false`, `Flashes == true`
  - `parse_bad_values_ignored`: `Parse("CameraShake=2,Flashes=yes,Bogus=1").CameraShake == true`, `.Flashes == true`, no `Bogus`
  - `parse_too_long`: `Parse(string.rep("Flashes=0,", 25))` equals `Defaults()`
  - `serialize`: `Serialize(Defaults()) == ""`; `Serialize(Parse("CameraShake=0,QuickRespawn=1")) == "QuickRespawn=1,CameraShake=0"`
  - `valid`: `Valid(Defaults())` true; a map missing `Flashes` false; a map with `Flashes = "yes"` false; a map with an extra `Bogus = true` false
- [ ] **Step 2:** Make `tests/run.sh` run each spec in `tests/`. Run it; expected: FAIL (Preferences module not found); the Keybinds spec still passes.
- [ ] **Step 3:** Implement `src/ReplicatedStorage/Preferences.luau` to the interface (header comment in house style).
- [ ] **Step 4:** `tests/run.sh` → both specs pass; gate the module.
- [ ] **Step 5:** Commit `"Add the Preferences module with tests"`.

### Task 2: Saving preferences and Quick respawn (server)

**Files:**
- Modify: `src/ServerScriptService/SettingsServer.server.luau`, `src/ServerScriptService/PlayerStats.luau` (`TEXT_DEFAULTS`: `Preferences = ""`)

**Interfaces:**
- Consumes: `Preferences.Parse/Valid/Serialize/MaxLength/Attribute/For`.
- Produces: RemoteEvent `ReplicatedStorage.SetPreferences` (one string).

- [ ] **Step 1:** Factor SettingsServer's checks into one local `accept(remoteName, module)` that creates a remote and applies: string, at most `module.MaxLength`, `Valid(Parse(text))`, `Serialize(Parse(text)) == text`, throttle 0.5 s **per player per remote**, then `player:SetAttribute(module.Attribute, text)`. Use it for `SetKeybinds` (unchanged behaviour) and `SetPreferences`.
- [ ] **Step 2:** Quick respawn: on each player's `CharacterAdded`, watch the Humanoid's `Died` once; if `Preferences.For(player, "QuickRespawn")`, after `QUICK_RESPAWN_DELAY` call `player:LoadCharacter()` when `player.Parent` and `player.Character == character` (Review Focus 1). Update the header comment.
- [ ] **Step 3:** Gate both files; commit `"Save preferences; quick respawn"`.

### Task 3: Effects honour the settings

**Files:**
- Modify: `src/ReplicatedStorage/VFX.luau` (`VFX.Shake` ~268, `VFX.ScreenSpeedLines` ~295, `VFX.ImpactFrame` ~355, `VFX.ImpactFrameNear` ~411)
- Modify: `src/StarterPlayer/StarterPlayerScripts/SkillEffects/init.client.luau` (local `shake` ~93)
- Modify: `src/StarterPlayer/StarterPlayerScripts/HitFeedback.client.luau` (`showNumber` ~37)

**Interfaces:**
- Consumes: `Preferences.Get`.

- [ ] **Step 1:** In VFX add a local `allowed(id)`: true on the server (`not RunService:IsClient()`), else `Preferences.Get(id)`. `Shake` returns early unless `allowed("CameraShake")`; `ScreenSpeedLines`, `ImpactFrame`, `ImpactFrameNear` return early unless `allowed("Flashes")`. The return value matches what each returns when it does nothing today (read each function's existing early returns).
- [ ] **Step 2:** SkillEffects' `shake` returns early unless `Preferences.Get("CameraShake")`. HitFeedback's `showNumber` returns early unless `Preferences.Get("DamageNumbers")` (flash and sparks untouched).
- [ ] **Step 3:** Update the three files' header comments; gate; commit `"Effects honour camera shake, flashes and damage-number settings"`.

### Task 4: Settings menu sections

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Settings.client.luau`

**Interfaces:**
- Consumes: `Preferences.Options/Get/Parse/Serialize/Changed/Attribute`, `SetPreferences`.

- [ ] **Step 1:** After the KEYBINDS rows (before RESET TO DEFAULTS), add a section label per distinct `section` in `Preferences.Options` order (GAMEPLAY, EFFECTS) and one row per option: its label, and a toggle button the width of the key buttons showing `ON` (accent colour) or `OFF` (muted).
- [ ] **Step 2:** Generalise the pending/spaced save already used for keybinds into a small local `saver(remote, module)` returning `{ save(map), shown() }`, so preferences get the same "newest wins, 0.6 s apart, pending shown until echoed, 3 s timeout" behaviour. Clicking a toggle flips it in `shown()` and saves. RESET TO DEFAULTS stays keybinds-only (its label unchanged).
- [ ] **Step 3:** Rows refresh on `Preferences.Changed`. Gate; commit `"Settings: gameplay and effects sections"`.

### Task 5: Death screen

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/DeathScreen.client.luau`

**Interfaces:**
- Consumes: `ReplicatedStorage:WaitForChild("KillFeed")` client event `(victimUserId, victimName, killerUserId?, killerName?, setName?)`; `SkillSetConfig.Sets[setName].tool` for the set's display name; `Preferences.Get("QuickRespawn")`; `Players.RespawnTime`.

- [ ] **Step 1:** Keep the latest KillFeed entry whose `victimUserId == LocalPlayer.UserId` as `{ at = os.clock(), killerName, setName }`.
- [ ] **Step 2:** On each local character's Humanoid `Died`: if `Preferences.Get("QuickRespawn")`, do nothing. Otherwise show the band (full width, ~120 px tall, centred, square, dark at 0.25 transparency): "YOU DIED" (GothamBold 36), the cause line, and "Respawning in N…" counting down from `Players.RespawnTime` (ceil, updated each 0.1 s). The cause line waits up to 0.5 s for an entry newer than the death (Review Focus 2): "Killed by <Name> with <Set tool name>", "Killed by <Name>", or "You died".
- [ ] **Step 3:** Hide on `CharacterAdded` or when the countdown reaches 0. Gate; commit `"Add the death screen"`.

### Task 6: Cast feedback

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/SkillBar.client.luau` (`readyToCast` ~420, its callers ~449 and ~478, `tryOvercharge` refusals ~499/510/523, `cast` for no-target)

**Interfaces:**
- Consumes: `AimIndicator.LockTarget` (already used for the lock preview: check its exact signature in `AimIndicator.luau` before use).
- Produces: `readyToCast(setName, key, skill) -> (boolean, string?)`, the reason string in the spec's order and copy.

- [ ] **Step 1:** A feedback `TextLabel` just above the bar (red `DENIED`, TextSize 13, centred, transparent background) and `refuse(text)`: sets the text, shows it, restarts a `FEEDBACK_TIME` timer that fades it (a token, so mashing replaces rather than stacks, per Review Focus 4).
- [ ] **Step 2:** `readyToCast` returns `false, reason` per the spec table, in its order; seconds are `math.ceil` of the time left. Callers pass the reason to `refuse` next to their existing red pulse. A lock-aim skill whose `cast` finds no `LockTarget` refuses with `"<Skill>: no target"` and doesn't send the cast.
- [ ] **Step 3:** `tryOvercharge`'s three refusals call `refuse` with "Not enough light to fly", "Undo ready in <s>s", and "Overcharge ready in <s>s" (cooling) or "Overcharge not full".
- [ ] **Step 4:** Gate; commit `"Say why a skill press was refused"`.

### Task 7: Manifest, checklist, roadmap

**Files:**
- Modify: `studio-manifest.json` (Preferences ModuleScript, DeathScreen LocalScript)
- Create: `docs/superpowers/specs/2026-10-09-settings-death-feedback-checklist.md`
- Modify: `ROADMAP.md` (Settings line: the new sections, death screen, feedback)

- [ ] **Step 1:** Manifest entries; every `src/` file listed and present.
- [ ] **Step 2:** Checklist: the spec's Testing items plus one line per Review Focus item.
- [ ] **Step 3:** `tests/run.sh` and the gate over all of `src/` pass; commit `"Settings, death screen, feedback: manifest, checklist, roadmap"`; push.
