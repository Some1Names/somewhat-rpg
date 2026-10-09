# Settings Menu and Keybinds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Settings menu (gear button + P) whose first section rebinds the fighting keys, saved per player.

**Architecture:** One shared module, `ReplicatedStorage/Keybinds.luau`, owns the actions, defaults, allowed keys and the pure parse/serialize/bind logic (unit-tested with Lune), plus a small client API over the player's saved `Keybinds` attribute. A new server script validates and stores bindings. SkillBar, Dash, Ranged, PhotoGallery and Inventory ask the module for keys instead of hard-coding them; skills still reach the server by slot name, so no skill code changes.

**Tech Stack:** Roblox Luau. Lune (a standalone Luau runtime) for the module's unit tests; StyLua parse + selene undefined-variable gate for every script.

**Spec:** `docs/superpowers/specs/2026-10-09-settings-keybinds-design.md`

## Global Constraints

- Actions, labels and defaults exactly as the spec's table: `SkillZ` Skill 1 Z, `SkillX` Skill 2 X, `SkillC` Skill 3 C, `SkillV` Skill 4 V, `SkillF` Skill 5 (ultimate) F, `Special` Overcharge / Flight / Undo G, `Dash` Dash Q, `Reload` Reload R, `Gallery` Photo Gallery T.
- Saved attribute `Keybinds`, format `"SkillZ=Q,Dash=Z"`, only non-default actions, at most 200 chars (PlayerStats' text limit).
- Conflicts swap; reserved keys are refused; bad saved data falls back to defaults.
- Server: `SetKeybinds` RemoteEvent made in code; at most one save per 0.5 s per player.
- UI square (no `UICorner`), styled like ShopMenu / PhotoGallery. Menu opens with a gear button at the right edge and P; Esc or × closes.
- `SkillSetConfig.Keys` stays the slot names sent to the server.
- The `Keybinds` module must not touch `game` when required (Lune has no `game`); client functions reach services lazily.

## Review Focus

1. **Pressing a key while the menu waits for one** must not also cast a skill, dash or reload. Keybinds exposes `Capturing()`; every consumer ignores input while it's true (Task 3 checks it in each input handler; Task 4 sets it).
2. **Bindings arriving late** (PlayerStats loads the attribute after the client starts): everything starts on defaults and refreshes on `Changed` (Task 3's label refresh; checklist line).
3. **A forged or spammed `SetKeybinds`**: the server re-parses, rejects anything `Valid` refuses or longer than 200 chars, and throttles (Task 2; covered by the `Valid` tests in Task 1).
4. **A swap while labels show the old key**: skill-bar keycaps, the Q mini slot, "[G]" labels and Inventory rows all refresh on `Changed` (Task 3).
5. **Long key names** (F5, Keypad keys, punctuation) in an 18-px keycap: `Keybinds.Text` returns a short label (test in Task 1) and keycaps grow to fit (Task 3).

---

### Task 1: The Keybinds module (TDD with Lune)

**Files:**
- Create: `src/ReplicatedStorage/Keybinds.luau`
- Create: `tests/Keybinds.spec.luau`, `tests/run.sh`

**Interfaces:**
- Produces (pure):
  - `Keybinds.Attribute = "Keybinds"`, `Keybinds.MaxLength = 200`
  - `Keybinds.Actions: { { id: string, label: string, default: string } }` in the spec's order
  - `Keybinds.Allowed: { [keyName]: true }`: A–Z except W, A, S, D, B, M, P; F1–F8; Keypad0–Keypad9; Comma, Period, Semicolon, Quote, LeftBracket, RightBracket, Minus, Equals, BackSlash; LeftAlt, RightAlt, CapsLock. (A whitelist, so the spec's reserved keys and anything odd like F9 console / F11 fullscreen are never allowed.)
  - `Keybinds.Defaults() -> { [actionId]: keyName }`
  - `Keybinds.Parse(text: any) -> map`: the full map; non-string, over MaxLength, unknown actions and non-allowed keys are ignored; if the result has any key used twice, returns `Defaults()`
  - `Keybinds.Serialize(map) -> string`: non-default entries only, in `Actions` order, joined by ","
  - `Keybinds.Valid(map) -> boolean`: every action present with an allowed key, no key twice, no unknown actions
  - `Keybinds.Bind(map, actionId, keyName) -> (map?, string?)`: a new map with the action on that key, swapping with whichever action had it; `nil, "reserved"` for a non-allowed key, `nil, "unknown"` for an unknown action
  - `Keybinds.ShortName(keyName) -> string`: "Q" for letters, "F5", "N1" for Keypad1, ";" "'" "[" "]" "-" "=" "\\" "," "." for punctuation, "LAlt"/"RAlt", "Caps"
- Produces (client; lazy `game` access): `Keybinds.Current() -> map` (parsed from the local player's attribute, cached until it changes), `Keybinds.Key(actionId) -> Enum.KeyCode`, `Keybinds.ActionFor(keyCode: Enum.KeyCode) -> actionId?`, `Keybinds.Text(actionId) -> string` (ShortName of the current key), `Keybinds.Changed(callback) -> RBXScriptConnection`, `Keybinds.SetCapturing(on: boolean)`, `Keybinds.Capturing() -> boolean`.

- [ ] **Step 1: Write the failing tests** in `tests/Keybinds.spec.luau` (a tiny `check(name, condition)` harness that counts failures and `error`s at the end if any failed), requiring `../src/ReplicatedStorage/Keybinds`:
  - `parse_empty_is_defaults`: `Parse("")` equals `Defaults()`, and `Defaults().SkillZ == "Z"`, `.Special == "G"`, `.Dash == "Q"`, `.Reload == "R"`, `.Gallery == "T"`
  - `parse_swapped`: `Parse("SkillZ=Q,Dash=Z")` gives `SkillZ == "Q"`, `Dash == "Z"`, `SkillX == "X"`
  - `parse_reserved_ignored`: `Parse("SkillZ=W").SkillZ == "Z"`
  - `parse_unknown_ignored`: `Parse("Bogus=K,SkillZ=K").SkillZ == "K"` and no `Bogus` key
  - `parse_double_falls_back`: `Parse("SkillZ=Q")` (Dash still Q) equals `Defaults()`
  - `parse_non_string_and_long`: `Parse(nil)`, `Parse(42)` and `Parse(string.rep("SkillZ=K,", 30))` all equal `Defaults()`
  - `serialize_defaults_empty`: `Serialize(Defaults()) == ""`
  - `serialize_round_trip`: `Serialize(Parse("Dash=Z,SkillZ=Q")) == "SkillZ=Q,Dash=Z"`
  - `bind_swaps`: `Bind(Defaults(), "SkillZ", "Q")` gives `SkillZ == "Q"`, `Dash == "Z"`, and the input map is unchanged
  - `bind_reserved`: `Bind(Defaults(), "SkillZ", "W")` returns `nil, "reserved"`; `"P"` and `"One"` too
  - `bind_unknown_action`: `Bind(Defaults(), "Nope", "K")` returns `nil, "unknown"`
  - `valid`: `Valid(Defaults())` true; a map with two actions on "Q" false; a map missing `Reload` false; a map with `SkillZ = "Space"` false
  - `short_names`: `ShortName("Q") == "Q"`, `ShortName("F5") == "F5"`, `ShortName("Keypad1") == "N1"`, `ShortName("Semicolon") == ";"`, `ShortName("LeftAlt") == "LAlt"`
- [ ] **Step 2:** `tests/run.sh` runs `lune run tests/Keybinds.spec.luau`. Run it; expected: FAIL (module not found).
- [ ] **Step 3:** Implement `src/ReplicatedStorage/Keybinds.luau` to the interface above (header comment in the house style).
- [ ] **Step 4:** Run `tests/run.sh`; expected: all checks pass, exit 0. Gate the module (StyLua + selene).
- [ ] **Step 5:** Commit: `git commit -m "Add the Keybinds module with tests"`

### Task 2: Saving bindings (server)

**Files:**
- Create: `src/ServerScriptService/SettingsServer.server.luau`
- Modify: `src/ServerScriptService/PlayerStats.luau` (`TEXT_DEFAULTS`: `Keybinds = ""`)

**Interfaces:**
- Consumes: `Keybinds.Parse/Valid/Serialize/MaxLength/Attribute`.
- Produces: RemoteEvent `ReplicatedStorage.SetKeybinds` (client → server, one string). Server sets `player:SetAttribute("Keybinds", Keybinds.Serialize(map))` (normalized, so stored text is always canonical).

- [ ] **Step 1:** Implement: reject non-strings and strings over `MaxLength`; `map = Parse(text)`; require `Valid(map)` and that `Serialize(map) == text` (rejects anything Parse had to clean up); throttle 0.5 s per player (`os.clock()` table cleared on PlayerRemoving).
- [ ] **Step 2:** Gate both files; commit: `git commit -m "Save players' keybinds"`

### Task 3: Consumers read their keys from Keybinds

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/SkillBar.client.luau` (keycaps ~188, `miniSlot("Q")` ~263, `tryOvercharge`/`OVERCHARGE_KEYCODE` ~475, `keyForCode` + InputBegan/InputEnded ~516-545, the "[G]" labels, the mastery popup's "(Z)" ~844)
- Modify: `src/StarterPlayer/StarterPlayerScripts/Dash.client.luau:48,504`
- Modify: `src/StarterPlayer/StarterPlayerScripts/Ranged.client.luau:24,389`
- Modify: `src/StarterPlayer/StarterPlayerScripts/PhotoGallery.client.luau` (the T check)
- Modify: `src/StarterPlayer/StarterPlayerScripts/Inventory.client.luau:555-582` (key column)

**Interfaces:**
- Consumes: `Keybinds.ActionFor/Key/Text/Changed/Capturing`.
- Slot ↔ action: slot "Z" ↔ `"Skill" .. "Z"`; Special ↔ the G key; the label for a slot is `Keybinds.Text("Skill" .. slot)`.

- [ ] **Step 1: SkillBar.** Input: `local action = Keybinds.ActionFor(input.KeyCode)`; `"SkillZ"`..`"SkillF"` → `pressSkill(slot)` on press and the cast on release (release matches `aiming`'s action); `"Special"` → `tryOvercharge()`. Ignore input while `Keybinds.Capturing()`. Labels: keycaps get `AutomaticSize = X` and a `refreshKeys()` that sets each keycap, the dash mini slot (`Keybinds.Text("Dash")`) and is called at start and on `Keybinds.Changed`; the "READY [G]" / "UNDO [G]" texts and the mastery popup use `Keybinds.Text(...)`.
- [ ] **Step 2: Dash, Ranged, PhotoGallery.** Compare `input.KeyCode` with `Keybinds.Key("Dash" | "Reload" | "Gallery")` at press time; ignore input while capturing.
- [ ] **Step 3: Inventory.** Rows show `Keybinds.Text` for Dash, Special (overcharge, flight and undo rows) and Gallery, and `Keybinds.Text("Skill" .. key)` for skills; rebuild the open details on `Keybinds.Changed`.
- [ ] **Step 4:** Gate all five files; commit: `git commit -m "Read skill and ability keys from Keybinds"`

### Task 4: The Settings menu

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/Settings.client.luau`

**Interfaces:**
- Consumes: `Keybinds.Actions/Current/Bind/Serialize/ShortName/Text/Changed/SetCapturing/Capturing`, `ReplicatedStorage:WaitForChild("SetKeybinds")`.

- [ ] **Step 1:** Gear: a 36-px square `TextButton` ("⚙") at the right edge, vertically centred, `ScreenGui` `ResetOnSpawn = false`. P toggles the panel (not while capturing, not when `gameProcessed`); × and Esc close it (Esc while capturing only cancels the capture).
- [ ] **Step 2:** Panel: title SETTINGS, section label KEYBINDS, one row per `Keybinds.Actions` entry (label left, key button right showing `Keybinds.Text(id)`), then RESET TO DEFAULTS, then a one-line status label. Same colours, stroke and padding as PhotoGallery.
- [ ] **Step 3:** Capture: clicking a key button sets `Keybinds.SetCapturing(true)`, shows "Press a key…"; the next keyboard `InputBegan` (ignoring `gameProcessed` so it works even over the panel) either cancels (Esc), refuses (`Bind` returns "reserved": status "That key is reserved", keep waiting), or binds: `SetKeybinds:FireServer(Keybinds.Serialize(newMap))`, status "Skill 1 → Q" (and "Dash moved to Z" when it swapped). Capture ends on bind, Esc, closing the panel, or 6 s idle. Reset fires `""`.
- [ ] **Step 4:** Rows refresh on `Keybinds.Changed` (the server's echo is the truth).
- [ ] **Step 5:** Gate; commit: `git commit -m "Add the Settings menu with keybinds"`

### Task 5: Manifest, checklist, roadmap

**Files:**
- Modify: `studio-manifest.json` (Keybinds ModuleScript, SettingsServer Script, Settings LocalScript; same shapes as the existing entries)
- Create: `docs/superpowers/specs/2026-10-09-settings-keybinds-checklist.md`
- Modify: `ROADMAP.md` (a "Settings" line: keybinds built, waiting on Studio)

- [ ] **Step 1:** Manifest entries; check every `src/` file is listed and every listed file exists.
- [ ] **Step 2:** Checklist: one line per spec Testing item and per Review Focus item (capture doesn't cast; late load; labels refresh after a swap; long key names fit; spam/forged saves refused, via the admin panel or a second rebind inside 0.5 s).
- [ ] **Step 3:** Run `tests/run.sh` and the gate over all of `src/`; commit: `git commit -m "Settings: manifest, checklist and roadmap"`; push.
