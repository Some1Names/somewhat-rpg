# Hub menu: playtest checklist

Checked in Studio already: no console errors on load; Updates gets a NEW badge on join (no auto-open);
M switches tabs, M again closes, B opens Backpack; the R15 clone is posed (AnimationConstraint joints).

Try in-game:

- [ ] The Menu icon (bottom left, by the yen) opens the hub on Profile; it shows the gold
      unspent-points number.
- [ ] B / J / M open Backpack / Quests / Stats; the same key closes; another switches; Esc, × and
      ESC / CLOSE close. Typing b, j or m in chat does nothing.
- [ ] Opening Settings (P), the Shop, Gallery or Admin closes the hub, and the hub closes them.
- [ ] Accent: no power = white in the nav, black bars on the paper; Mandela = mint in the nav, a
      darker green on the paper; Iridescent = orange. Changes as soon as you swap powers.
- [ ] The posed character (a faded one-colour silhouette in the accent) shows on Profile, Quests and Stats on a wide screen (Profile picks
      one at random each open), and the strip hides on a narrow window (under 1100 px). Respawn and
      reopen: it's your current look, not a dead body.
- [ ] Poses: tune the numbers in `ReplicatedStorage.HubPoses` against your screenshots (+x raises a
      limb forward, +z swings it toward the character's right, +y turns it).
- [ ] Backpack (full width, no character): equip, store, swap, take out, sell and the CONFIRM step all work as before; it shrinks
      to fit a small window.
- [ ] Stats: spending points (x1/x5/x10), the MILESTONES sub-tab, XP / level-up popups still on the
      game screen.
- [ ] Quests: BOUNTY (with Abandon) and CHALLENGES (set picker) as before.
- [ ] Updates: CONTINUE closes; the NEW badge only appears on a new version.
- [ ] Readability on the grey paper (gold numbers, set colours, the tier chip) at 1280×720 and 1920×1080.
