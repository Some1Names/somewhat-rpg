# Settings menu and rebindable keys: design

Status: design approved in chat, waiting on review of this written spec.

## Intent

Players can open a **Settings** menu, and its first feature lets them **rebind the fighting keys**.
More settings can be added to the same menu later.

- **Who:** every player. Rebinding is per player and saved with their data, so it carries over
  between servers and sessions.
- **Success:** a player who prefers, say, 1-2-3-4 style keys or a dash on E can set that up once
  and every part of the game follows it: casting, the key letters on the skill bar, the Inventory
  details and the Gallery.

## Opening the menu

- A small **square gear button** on screen, at the right edge, out of the way of the hotbar and
  skill bar.
- The **P** key toggles the menu too. Esc or the close button shuts it.
- UI is square everywhere (no `UICorner`), styled like the Shop and Gallery panels.

## Rebindable actions

| Action id | Label | Default | Read by |
|---|---|---|---|
| `SkillZ` | Skill 1 | Z | SkillBar |
| `SkillX` | Skill 2 | X | SkillBar |
| `SkillC` | Skill 3 | C | SkillBar |
| `SkillV` | Skill 4 | V | SkillBar |
| `SkillF` | Skill 5 (ultimate) | F | SkillBar |
| `Special` | Overcharge / Flight / Undo | G | SkillBar |
| `Dash` | Dash | Q | Dash |
| `Reload` | Reload | R | Ranged |
| `Gallery` | Photo Gallery | T | PhotoGallery |

**Reserved keys:** these can never be picked, so movement and the other menus keep working: W, A,
S, D, Space, LeftShift, RightShift, LeftControl, RightControl, B, M, P, Backquote (`), Escape,
Backspace, Tab, Return, Slash (chat), One through Nine and Zero, and any mouse button. Only keyboard keys can
be bound.

**Conflicts swap:** binding an action to a key another action already uses gives that other
action this action's old key. Nothing is ever left unbound or doubled.

**Reset to defaults** puts every action back on its default key.

## How it works

### `ReplicatedStorage/Keybinds.luau` (new, shared)

- `Keybinds.Actions`: the ordered list above (`id`, `label`, `default` as a key name).
- `Keybinds.Reserved`: the reserved key names.
- `Keybinds.Attribute = "Keybinds"`: the saved player attribute, in the form `"SkillZ=Q,Dash=Z"`.
  Only actions that differ from their default are stored.
- `Keybinds.Parse(text) -> { [actionId] = keyName }` gives the full map. Unknown actions, unknown
  or reserved keys and doubles fall back to the defaults, so bad saved data never breaks
  anything.
- `Keybinds.Serialize(map) -> string` is the reverse, and `Keybinds.Valid(map) -> boolean` is used
  by the server.
- Client side:
  - `Keybinds.Key(actionId) -> Enum.KeyCode`: the player's current key.
  - `Keybinds.ActionFor(keyCode) -> actionId?`: which action a key belongs to.
  - `Keybinds.Text(actionId) -> string`: the key's short name for labels, e.g. "Q".
  - `Keybinds.Changed(callback)`: called whenever the player's bindings change, so labels refresh.

### The skills keep their slot names internally

`SkillSetConfig.Keys` (Z/X/C/V/F) stays as the **slot** names. The skill bar maps the pressed key
to its slot through `Keybinds`, and still sends the slot ("Z") to the server. **No server-side
skill code changes.** `SkillSetConfig.OverchargeKey`, `FlightKey` and the set's `gallery.key`
become the defaults for the `Special` and `Gallery` actions, with labels read from `Keybinds`.

### Scripts that change

- `SkillBar.client.luau`:
  - Casting looks up the action with `Keybinds.ActionFor`, both on press and on release.
  - G uses `Special`.
  - The key letters on the slots, the "READY [G]" and "UNDO [G]" labels, and the Q mini slot show
    the bound keys and refresh on `Changed`.
- `Dash.client.luau`: `DASH_KEY` becomes `Keybinds.Key("Dash")`, read on each press.
- `Ranged.client.luau`: `RELOAD_KEY` becomes `Keybinds.Key("Reload")`.
- `PhotoGallery.client.luau`: T becomes `Keybinds.Key("Gallery")`.
- `Inventory.client.luau`: the key column of set details shows the bound keys.
- `Settings.client.luau` (new):
  - The gear button, P, and the panel.
  - A **KEYBINDS** section with one row per action: its label and a key button.
  - Clicking the key button shows "Press a key…". The next keyboard key binds it. Esc cancels. A
    reserved key shows "That key is reserved" and keeps waiting.
  - **Reset to defaults** sits at the bottom.
  - Every change is sent to the server at once.
- `SettingsServer.server.luau` (new):
  - Makes a `SetKeybinds` RemoteEvent.
  - Takes the client's string (up to 200 chars), checks it with `Keybinds.Parse` and
    `Keybinds.Valid`, and sets the player's `Keybinds` attribute.
  - Throttled to one save per 0.5 s per player.
- `PlayerStats.luau`: `Keybinds = ""` joins the saved text fields (next to `AdminKeybinds` and
  `PhotoGallery`).

### Out of scope

- Rebinding menus (B, M), sprint, jump, shift lock, the hotbar keys and mouse buttons.
- Gamepad bindings.
- Other settings such as camera, audio and graphics. The menu is laid out with sections so they
  can be added later.

## Testing

No Roblox runtime here. Every script must pass the StyLua parse check and the selene check for
undefined variables. The owner's in-game checklist covers:

- Opening and closing the menu (gear, P, Esc).
- Rebinding each action and casting with the new key.
- A swap.
- A reserved key being refused.
- Reset to defaults.
- Labels updating (skill bar, Undo/overcharge label, Inventory, Q mini slot).
- Bindings kept after rejoining a live server.
- A Gallery opened by its new key.
