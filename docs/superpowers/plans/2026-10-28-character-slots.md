# Character Slots and Customizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After PLAY, show 3 save slots; an empty slot opens a name + look customizer, a used slot continues or deletes, and each slot saves independently.

**Architecture:** A pure `SlotConfig` (Lune-tested) holds names, palettes, look text and key rules. `PlayerStats` stops loading on join and loads/saves one slot's record by key. A server `Slots` module owns the per-player meta record, migration, create/select/delete; `SlotServer` exposes it on one RemoteFunction. `CharacterLook` (shared) paints the R6 rig; `SlotMenu` + `Customizer` are the client screens, opened by `TitleMenu`'s PLAY.

**Tech Stack:** Luau (Roblox), DataStore, Lune for unit tests (`tests/run.sh`).

**Spec:** `docs/superpowers/specs/2026-10-28-character-slots-design.md`

## Global Constraints

- 3 slots; DataStore `PlayerStats_v1`; keys `<UserId>_1`..`_3`, `<UserId>_meta`; legacy `<UserId>` key is copied from, never deleted.
- Name 3-16 characters, letters/digits/space/underscore, trimmed, filtered with `TextService`. Rig is R6.
- UI is square (no `UICorner`); white text with a dark stroke; match `Hub` style. No final VFX.
- Studio playtests load saves but write nothing (`SAVE_IN_STUDIO` stays false): the menu must still work there from in-memory state.
- Pure modules in `ReplicatedStorage` use no Roblox types so Lune loads them (`check` style: see `tests/PartyRules.spec.luau`). New specs go in `tests/*.spec.luau`.
- Match surrounding code: tabs, comment density, naming. **The working tree has unrelated uncommitted changes:** commit only the files a task names, and if a named file already has uncommitted edits (`git diff --stat <file>` non-empty before you start), leave it uncommitted and say so in the report. No Luau toolchain is guaranteed; if `luau-analyze` is installed run it on each edited file, otherwise re-read your edits for syntax.
- Only scripts live in the repo. Parts (`ReplicatedStorage.CharacterParts`) are the owner's, made in Studio.

## Review Focus

- Meta read fails (DataStore error): must not migrate, create or overwrite anything; the player cannot enter a slot until a retry works.
- Legacy save present, no meta: slot 1 gets a copy, the legacy key is untouched, and a second join does not re-copy over newer progress.
- `Select`/`Create` called twice, for an empty slot, or after a slot is already chosen: refused, no second load.
- Hostile or odd input: names empty, 2 or 17 characters, symbols, only spaces, same as the player's other slot, filtered text; looks that are empty, garbled, floats, negative or out of range.
- Leaving on the menu or mid-load saves nothing; dying and respawning re-applies the look over the player's real Roblox avatar, including accessories that arrive late.

---

### Task 1: SlotConfig (pure rules)

**Files:**
- Create: `src/ReplicatedStorage/SlotConfig.luau`
- Test: `tests/SlotConfig.spec.luau`

**Interfaces:**
- Produces (all on the returned table):
  - `SlotCount: number` (3), `NameMin` (3), `NameMax` (16)
  - `SlotKey(userId: number, slot: number): string` -> `"<userId>_<slot>"`; `MetaKey(userId: number): string` -> `"<userId>_meta"`
  - `ValidSlot(slot: any): boolean` (integer 1..SlotCount)
  - `CleanName(text: any): (string?, string?)` -> cleaned name, or nil and a short reason
  - `SkinTones`, `OutfitColors`, `HairColors`: arrays of `{r, g, b}` (0-255); `HairStyles`, `FaceStyles`: arrays of display names, index 1 = "None"/"Default" (no part needed). Sizes: 8, 12, 10, 5, 4. RGB values are placeholders the owner retunes.
  - `type Look = { skin: number, hair: number, hairColor: number, face: number, top: number, bottom: number }`
  - `DefaultLook(): Look` (every field 1); `FormatLook(look: Look): string` -> `"skin;hair;hairColor;face;top;bottom"`; `ParseLook(text: any): Look` (any bad field falls back to 1)
  - `type Entry = { name: string, level: number, power: string, look: string, playedAt: number }`
  - `CleanMeta(value: any): { [number]: Entry }` (drops malformed entries and slots outside 1..SlotCount)

- [ ] **Step 1: Write `tests/SlotConfig.spec.luau`** (header comment and `check` helper copied from `tests/PartyRules.spec.luau`) with these checks:
  - `SlotKey(5, 2) == "5_2"`, `MetaKey(5) == "5_meta"`, `SlotCount == 3`
  - `ValidSlot`: true for 1,2,3; false for 0, 4, 1.5, "1", nil
  - `CleanName("  Ayato Yoji ") == "Ayato Yoji"`; `CleanName("Bob_9") == "Bob_9"`
  - `CleanName` returns nil plus a non-empty reason for: `""`, `"   "`, `"ab"`, 17 `"a"`s, `"no!"`, `"a\nb"`, `nil`, `12`
  - `FormatLook({skin=2,hair=3,hairColor=4,face=1,top=5,bottom=6}) == "2;3;4;1;5;6"` and `ParseLook` of that returns the same fields
  - `ParseLook` falls back to `DefaultLook()` fields for `""`, `nil`, `"x;y"`; for `"99;1;1;1;1;1"` only `skin` falls back; for `"-1;1.5;1;1;1;1"` skin and hair fall back
  - `CleanMeta`: keeps a well-formed entry at slot 2; drops slot 4, a string-keyed entry, and an entry whose `level` is a string; `CleanMeta(nil)` is an empty table

- [ ] **Step 2: Run to verify failure**

Run: `lune run tests/SlotConfig.spec.luau`
Expected: FAIL (cannot require `SlotConfig`)

- [ ] **Step 3: Implement `src/ReplicatedStorage/SlotConfig.luau`** to the interface above. `CleanName`: reject non-strings, trim, then pattern `^[%w _]+$`, then length; reasons like "Name must be 3-16 characters" / "Letters, numbers, spaces and _ only". `ParseLook`: split on `;`, accept only integers within each palette's size.

- [ ] **Step 4: Run to verify pass**

Run: `bash tests/run.sh`
Expected: all specs `ok`, exit 0

- [ ] **Step 5: Commit**

```bash
git add src/ReplicatedStorage/SlotConfig.luau tests/SlotConfig.spec.luau
git commit -m "Slot config: names, looks, keys and meta rules"
```

---

### Task 2: PlayerStats loads and saves one slot; join no longer loads

**Files:**
- Modify: `src/ServerScriptService/PlayerStats.luau` (`TEXT_DEFAULTS` ~61, `load` ~185, `save` ~248, `onPlayerAdded` ~488, `Start` ~500)
- Modify (only if the audit finds a problem): the `PlayerAdded` handlers listed in Step 5

**Interfaces:**
- Consumes: `SlotConfig.SlotKey`, `SlotConfig.ValidSlot`.
- Produces (on `PlayerStats`):
  - `PlayerStats.Store: DataStore?` (the existing `store`)
  - `PlayerStats.WritesEnabled(): boolean` (false in Studio while `SAVE_IN_STUDIO` is false, or when `store` is nil)
  - `PlayerStats.LoadSlot(player: Player, slot: number, startFresh: boolean): boolean` -> true once the attributes are set and saving is allowed; false on a failed read (nothing set, saving stays off). `startFresh` skips the read (empty record) and allows saving if `store` exists.
  - `PlayerStats.CurrentSlot(player: Player): number?`
  - `PlayerStats.ClearSlot(player: Player)` -> forgets the current slot and turns saving off (used when a just-started slot fails its first save)
  - `PlayerStats.OnSaved(callback: (player: Player) -> ())` -> called after each successful `save`
  - `PlayerStats.Summary(player: Player): (number, string)` -> `Level`, `CurrentPower` ("" if none)
- New saved text fields in `TEXT_DEFAULTS`: `CharName = ""` (the slot's name), `Look = ""` (`SlotConfig.FormatLook` text)

- [ ] **Step 1: Add `CharName` and `Look` to `TEXT_DEFAULTS`** with `-- ` notes in the existing style; confirm both stay under `TEXT_MAX_LENGTH`.
- [ ] **Step 2: Turn `load(player)` into `PlayerStats.LoadSlot(player, slot, startFresh)`.** Read key `SlotConfig.SlotKey(player.UserId, slot)` with the existing retry loop and Studio-API early-out; keep all the post-read normalisation unchanged; record `currentSlot[player] = slot` only on success; set `canSave[player]` exactly as today (read success, or `startFresh` with a store).
- [ ] **Step 3: `save(player)` writes to the current slot's key** and returns false when `currentSlot[player]` is nil. After a successful write call every `OnSaved` callback in a `pcall`. `PlayerRemoving` also clears `currentSlot[player]`.
- [ ] **Step 4: Stop loading on join.** `onPlayerAdded` keeps the `CharacterAdded` health hook and the talent listener but no longer calls `load`. Add the new accessors from Interfaces.
- [ ] **Step 5: Join-order audit.** Slot attributes now appear after join, when a slot is chosen. Read each `PlayerAdded` handler in `src/ServerScriptService` that touches saved attributes: `Consumables.luau` (~378), `Reforge.luau` (~78), `Factions.luau` (~74), `Overcharge.luau` (~194), `Headhunter.server.luau` (~162), `Guard.luau` (~187), `CombatState.luau` (~158), `Powers.luau` (~550) and `Loadout.luau` (~187; both already react to attribute changes, confirm `syncTool` and `refreshOwned` are nil-safe). For each `GetAttribute` of a saved field read at join without a nil guard, make it nil-safe or defer it to the attribute's `GetAttributeChangedSignal`. Record the list of handlers checked and changed in the commit message body.
- [ ] **Step 6: Verify (read-only for now):** `grep -n "load(" src/ServerScriptService/PlayerStats.luau` shows no remaining call to the old `load`; `AdminServer`'s `ResetProgress` path still compiles (`ResetProgress` is unchanged and must not clear `CharName`/`Look`).
- [ ] **Step 7: Commit** `PlayerStats.luau` plus any audit fixes (named in the message): `git commit -m "PlayerStats: load and save one slot, no load on join"`. In-game behaviour is checked in Task 6.

---

### Task 3: Slots module and SlotServer

**Files:**
- Create: `src/ServerScriptService/Slots.luau`
- Create: `src/ServerScriptService/SlotServer.server.luau`

**Interfaces:**
- Consumes: Task 1 `SlotConfig`; Task 2 `PlayerStats.Store`, `WritesEnabled`, `LoadSlot`, `CurrentSlot`, `OnSaved`, `Summary`, `SaveNow`.
- Produces (on `Slots`):
  - `Slots.Start()` (hooks `PlayerAdded`/`PlayerRemoving`, `PlayerStats.OnSaved(Slots.WriteMeta)`)
  - `Slots.List(player): ({ [number]: SlotConfig.Entry }?, string?)` -> meta table, or nil and `"load"`; loads the meta once per player and caches it; runs migration (below) the first time
  - `Slots.Create(player, slot: number, name: string, lookText: string): (boolean, string?)` -> validates, then starts a fresh record in that slot and enters it
  - `Slots.Select(player, slot: number): (boolean, string?)` -> loads the slot's record and enters it
  - `Slots.Delete(player, slot: number, typedName: string): (boolean, string?)`
  - `Slots.Current(player): number?`; `Slots.WriteMeta(player)`; `Slots.OnEntered(callback: (player, slot) -> ())` (used by Task 4)
- `SlotServer` creates `ReplicatedStorage.SlotAction` (RemoteFunction) with `OnServerInvoke = function(player, action, ...)` returning `{ ok: boolean, reason: string?, slots: {...}? }` for actions `"List"`, `"Create"`, `"Select"`, `"Delete"`.

- [ ] **Step 1: `Slots.List` and migration.** Read `MetaKey` with 3 attempts (`pcall` GetAsync, same wait as `PlayerStats`). On failure return `nil, "load"` and touch nothing. If the meta is nil: read the legacy key `tostring(UserId)`; if that read fails return `nil, "load"`; if it has data, build slot 1's record (legacy fields + `CharName = player.DisplayName` trimmed to `NameMax`, `Look = FormatLook(DefaultLook())`), write it to `_1`, then write the meta (`Entry` from the record's `Level`, `CurrentPower`, `playedAt = os.time()`); write the slot before the meta so a crash between them re-runs the copy safely. Skip every write when `not PlayerStats.WritesEnabled()` (keep the result in memory only). Always pass the loaded value through `SlotConfig.CleanMeta`.
- [ ] **Step 2: Hold state.** `Slots.Start` marks each new player `SetAttribute("SlotPending", true)` and, on each `CharacterAdded` while pending, waits for `HumanoidRootPart`, sets it `Anchored = true` and adds a `ForceField`. Entering clears the attribute, unanchors and removes the ForceField from the current character.
- [ ] **Step 3: `Create`.** Reject (with a reason string) when: any slot is already current, `not ValidSlot(slot)`, the meta slot is occupied, `CleanName` fails, the name equals (case-insensitive) another slot's name, `FilterStringAsync(name, userId):GetNonChatStringForBroadcastAsync()` differs from the name or throws, or `ParseLook(lookText)` reformatted differs from `lookText`. On success: `PlayerStats.LoadSlot(player, slot, true)`, set `CharName` and `Look` attributes, `PlayerStats.SaveNow(player)` (when `WritesEnabled()` and it returns false, reply `"save"`, call `PlayerStats.ClearSlot`, and stay on the menu), then write the meta and enter.
- [ ] **Step 4: `Select`.** Reject when a slot is current or an enter is in flight for this player (`entering[player]`), `not ValidSlot`, or the meta slot is empty. `PlayerStats.LoadSlot(player, slot, false)`; on false reply `"load"` and release `entering`. Enter on success.
- [ ] **Step 5: `Delete`.** Reject when a slot is current, the slot is empty, or `typedName` (trimmed, case-insensitive) differs from the meta entry's name. `RemoveAsync` the slot key (skip when not `WritesEnabled`), clear the meta entry, write the meta.
- [ ] **Step 6: `WriteMeta(player)`** updates the current slot's entry from `PlayerStats.Summary` and `playedAt = os.time()`, then writes `MetaKey` (skipped when writes are off). Never writes when the meta failed to load.
- [ ] **Step 7: `SlotServer`** validates the action name and argument types, allows one call per 0.5 s per player (extra calls return `{ ok = false, reason = "busy" }`), and forwards to `Slots`. It calls `Slots.Start()`.
- [ ] **Step 8: Commit** both files: `git commit -m "Slots: meta, migration, create, select, delete and the SlotAction remote"`.

---

### Task 4: CharacterLook (paint the R6 rig)

**Files:**
- Create: `src/ReplicatedStorage/CharacterLook.luau`
- Modify: `src/ServerScriptService/Slots.luau` (apply on enter and on respawn)

**Interfaces:**
- Consumes: Task 1 `SlotConfig` palettes and `ParseLook`; `Slots.OnEntered`.
- Produces: `CharacterLook.Apply(character: Model, look: SlotConfig.Look, parts: Instance?)` -> `parts` is `ReplicatedStorage.CharacterParts` (nil = colours only); `CharacterLook.HasHair(parts, index): boolean`, `CharacterLook.HasFace(parts, index): boolean` (used by the Customizer to hide options with no part).

- [ ] **Step 1: Implement `Apply`.** Remove the rig's `Accessory`, `Shirt`, `Pants`, `ShirtGraphic` and `CharacterMesh` children (the real Roblox avatar). Head, arms = skin tone; Torso = top colour; legs = bottom colour; also set the same values on the character's `BodyColors`. Hair: if index > 1 and `parts:FindFirstChild("Hair_" .. index)` exists, clone it, tint its `Handle` to the hair colour and `Humanoid:AddAccessory`. Face: if index > 1 and `Face_<index>` (a `Decal`) exists, set the Head `face` decal's `Texture` from it.
- [ ] **Step 2: Hook in `Slots`.** Entering applies `ParseLook(player:GetAttribute("Look"))` to the current character; connect `CharacterAdded` once entered so every respawn re-applies it. Before applying, wait for the avatar: if `not player:HasAppearanceLoaded()` then `player.CharacterAppearanceLoaded:Wait()` (cap at 10 s), then apply, then apply again after one `task.wait(1)` to catch late accessories.
- [ ] **Step 3: Commit:** `git add src/ReplicatedStorage/CharacterLook.luau src/ServerScriptService/Slots.luau` and `git commit -m "CharacterLook: paint the rig from a slot's look"`.

---

### Task 5: SlotMenu, Customizer and the PLAY hook

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/SlotMenu.luau` (ModuleScript)
- Create: `src/StarterPlayer/StarterPlayerScripts/Customizer.luau` (ModuleScript)
- Modify: `src/StarterPlayer/StarterPlayerScripts/TitleMenu.client.luau` (`play`, ~449, and the PLAY `button`, ~473)

**Interfaces:**
- Consumes: `SlotAction` remote (Task 3), `SlotConfig`, `CharacterLook` (Task 4), `UiSfx`, `Menus`, and `HubPose.client.luau` for how it clones and poses the character into a ViewportFrame (reuse an exposed helper, else copy the minimal clone).
- Produces: `SlotMenu.Open(onEntered: () -> (), onBack: () -> ())` -> shows the 3 cards over the title shot; calls `onEntered` after a `Create`/`Select` reply with `ok`; `onBack` for the Back button. `Customizer.Open(slot: number, onDone: (ok: boolean) -> ())` -> the customizer for an empty slot.

- [ ] **Step 1: `SlotMenu`.** On open call `SlotAction:InvokeServer("List")`. `ok == false` shows "Could not load your characters" and a Retry button (re-invokes). Otherwise three square cards: empty -> "NEW CHARACTER"; used -> name, "Lv N", power name, relative last-played; used cards have CONTINUE and DELETE. CONTINUE invokes `"Select"`. DELETE opens a small confirm with a text box that must equal the name before its button enables, then invokes `"Delete"` and redraws. Show server reasons in a red-edged line; disable buttons while a call is in flight.
- [ ] **Step 2: `Customizer`.** Name box (live `SlotConfig.CleanName` hint), option rows for skin, hair style, hair colour, face, top, bottom (swatches for colours; buttons for styles; hide styles where `CharacterLook.HasHair/HasFace` is false), a ViewportFrame preview of a clone of the local character updated through `CharacterLook.Apply` on each change, and CREATE / BACK. CREATE invokes `"Create"` with `SlotConfig.FormatLook`, shows any reason, calls `onDone(true)` on success.
- [ ] **Step 3: `TitleMenu`.** PLAY no longer runs the fade directly: it opens `SlotMenu` (hide the title column meanwhile, keep the camera drift). Rename the current `play` body to `enterWorld` and pass it as `onEntered`; `onBack` re-shows the column. `playing` flips to true only when `enterWorld` starts.
- [ ] **Step 4: Style check.** No `UICorner` anywhere in the new scripts: `grep -n UICorner src/StarterPlayer/StarterPlayerScripts/SlotMenu.luau src/StarterPlayer/StarterPlayerScripts/Customizer.luau` returns nothing.
- [ ] **Step 5: Commit** the two new files; commit `TitleMenu.client.luau` only if it had no uncommitted edits before this task (see Global Constraints). Message: `git commit -m "Slot screen and customizer after PLAY"`.

---

### Task 6: Docs and the Studio checklist

**Files:**
- Create: `docs/superpowers/specs/2026-10-28-character-slots-checklist.md`
- Modify: `CLAUDE.md` (Architecture, "Player data" bullet and "Client UI" `TitleMenu` mention), `docs/superpowers/plans/README.md` (a row; commit only if the file had no uncommitted edits)

- [ ] **Step 1: Write the checklist** (owner's playtest list, from the spec's Testing section plus): old save appears in slot 1 intact; slots 2 and 3 independent (level, yen, power); delete needs the typed name; rejoin keeps looks and names; each bad-name case from Review Focus is refused; avatar accessories gone and look re-applied after dying; the character cannot be hurt or move on the menu; in a Studio playtest the menu works and nothing is written; turn the DataStore API off and confirm the "Could not load" Retry path.
- [ ] **Step 2: List what Studio needs** at the top of the checklist: new scripts with class and path (`SlotConfig`, `CharacterLook`: ModuleScripts in `ReplicatedStorage`; `Slots`: ModuleScript and `SlotServer`: Script in `ServerScriptService`; `SlotMenu`, `Customizer`: ModuleScripts in `StarterPlayerScripts`), changed `PlayerStats`/`TitleMenu` (and any audit fixes), and the owner's `ReplicatedStorage.CharacterParts` (`Hair_<n>` accessories, `Face_<n>` decals; options without a part are hidden).
- [ ] **Step 3: Update `CLAUDE.md`** with a short "Character slots" line in the architecture list: `SlotConfig`, `Slots`/`SlotServer`, `CharacterLook`, `SlotMenu`/`Customizer`, keys, and that `PlayerStats` loads on `Slots` select, not on join.
- [ ] **Step 4: Run `bash tests/run.sh`** (Expected: all `ok`), then commit the checklist and `CLAUDE.md`: `git commit -m "Character slots: checklist and docs"`.

Nothing in Tasks 2-5 can be run outside Studio. The owner (or a local Studio session, following "Repo -> Studio" in `CLAUDE.md`) applies the diff and plays through the checklist; do not claim it works in-game until then.
