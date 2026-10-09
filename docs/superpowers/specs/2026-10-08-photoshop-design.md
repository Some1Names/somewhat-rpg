# Photoshop skill set: design

Status: approved in chat 2026-10-08, waiting on review of this written spec.

## Intent

Nozomi Yume's power from Sanctuary / the Complex Arc: she edits reality like a photo. She can
**collapse** reality (cut it, paste it, crush it into a black hole) but she can't **change** it.
Mandela (Hide Seto, Rank 3 Reality Alteration) changes it, which is why Mandela beats her, and
in canon that conflict is where she dies.

Photoshop is the third S power, and with it the S powers form a rock-paper-scissors triangle:

- **Photoshop beats Iridescent Requiem**: her edits shut down light (Luminance, Prism Form, flight).
- **Mandela beats Photoshop**: Misremembered forgets her edits, and Undo can't undo his damage.
- **Iridescent Requiem beats Mandela**: in flight he slips Event Horizon and Tornado.

Each counter is an edge from how moves interact, not a flat damage bonus, and not a guaranteed
win. Success: an Iridescent player feels Nozomi shut their tricks down, a Nozomi player feels
Mandela is hard to pin down, and every set is still fun on its own.

**Playstyle:** a fragile, slippery assassin. Frame a target, dive in with a cut-and-paste, burst,
then Undo out.

**Look:** pink and light blue (exact colours picked while building the visuals). The names may
change later; the mechanics are what this spec fixes.

## The set

`SkillSetConfig.Sets.Photoshop`: `tool = "Photoshop"`, `kind = "power"`, `tier = "S"`. No
overcharge and no flight: G is Undo. Damage numbers are before the caster's Superliminal bonus;
every hit uses `{ stat = "Superliminal", skillSet = "Photoshop" }` through `Damage.Deal`.

### Passive: History, and G: Undo

- The server records each Photoshop holder's position and health every 0.25 s, keeping the
  last 3 s (History).
- **G, Undo** (cooldown 18 s): she snaps back to where she stood 3 s ago (or the oldest point
  kept, if less) and heals 50% of the damage she took since then.
- Damage from Mandela (`options.skillSet == "Mandela"`) is not counted, so Undo never heals it.
- Healing goes through the normal humanoid health, so Poisoned's healing cut still applies.
- Undo can't be used while held by crowd control (`CrowdControl.CanControl` is false on her)
  or while dead.
- Config: a new `undo` field on the set (`{ name = "Undo", cooldown = 18, rewind = 3,
  healShare = 0.5 }`), read by the SkillBar's G key alongside `overcharge` and `flight`.

### Click: Shutter (ranged)

- A `ranged` move like Light Shot: right click readies it, left click fires; `aims = true`.
- An instant flash beam, 120 studs, 9 damage. 3 charges, refilling one per 3 s, 0.25 s
  between shots.
- Hitting a target Framed by her adds 1.5 s to the frame, up to the frame's full 4 s.

### Z: Snapshot (mastery 1, cooldown 6 s)

- Aim `lock`, range 50, cone 30.
- A camera flash hits the target for 12 damage and **Frames** them for 4 s.
- **Recast, Step In**: while a target she Framed is still Framed and within 60 studs, Z again
  teleports her 4 studs behind them, facing them.

### X: Photo Teleport (mastery 5, cooldown 10 s)

- Aim `circle`, range 60, radius 4: pins a photo of that spot. The photo lasts 8 s.
- **Recast, Paste**: if a target she Framed is within 60 studs of the photo, the target is
  pasted into it (moved there, then held 0.5 s, following `CrowdControl` rules). Otherwise
  she pastes herself into it.
- The paste works on players and NPCs; for a player it needs `CrowdControl.CanControl`.

### T: Gallery (fast travel; the waypoint option)

- T opens a small picker (square UI) with 3 photo slots. A slot can **save** the spot she's
  standing on, or **travel** to the saved spot.
- Travel only works out of combat: she hasn't taken or dealt damage for 8 s. It needs a 2 s
  "developing" cast that any damage taken cancels.
- Only works with Photoshop equipped.
- The 3 photos are saved with the player's data (`PlayerStats` text field `PhotoGallery`).
- A "named areas" tab (Blox Fruits Door style) is **out of scope** for now. It needs marker
  parts for each area placed in Studio first, and can be added to this picker later.

### C: Desaturate (mastery 20, 3 charges, 14 s per charge)

- Aim `circle`, range 50, radius 18. The colour drains from that area for 4 s.
- Enemies inside take 4 damage every 0.5 s and get the **Desaturated** status, refreshed
  while they stay inside and lasting 1 s after they leave.
- **Desaturated** (new in `StatusConfig`, grey icon, no damage of its own):
  - Luminance doesn't fill and drains 0.15 per second.
  - No flight: anyone flying lands, and can't take off again until it wears off.
  - No Prism Form: an active one ends at once, and it can't be entered.
- No slow: the client's sprint script owns walk speed, and a server slow would fight it.

### V: Iris Horizon (mastery 50, cooldown 35 s)

- Aim `lock`, range 60, cone 30.
- A ring of photographs, 16 studs across, forms around the target and follows them while it
  closes toward the middle over 1.5 s, like a camera's iris blades.
- When it shuts, reality inside collapses into a **rainbow black hole** that bursts: 45 damage
  to the target and 25 to everyone else within 10 studs. Anyone flying is grounded.
- A target who left the ring before it shut (dashed or flew out) takes only 10 damage instead.
- **Framed combo**: on a Framed target the ring starts half-closed and shuts in 0.4 s, like
  Solar Lance's lock onto a Sunmark.

### F: Kaleidoscope (mastery 100, cooldown 90 s; the ultimate)

- Aim `self`, radius 60. Reality around her shatters into mirrored fragments for 5 s.
- Every 0.5 s, every enemy inside takes a 7-damage mirror hit, or two if Framed.
- Light Shot and Prism Shot beams fired at her from inside the zone bounce back at the shooter
  with the same damage, as her hit.
- Not tied to overcharge (she has none): it's gated only by mastery 100 and its cooldown.

## The Framed mark

`ServerScriptService/Framed.luau`, modelled on `Sunmark.luau`: `Framed.Mark(player, model)`,
`Framed.Has(player, model)`, `Framed.Extend(player, model, seconds)`. The mark is kept on the
target model as `FramedUntil` (server time) and `FramedBy` (the caster's UserId). Only the
caster is told (`SkillEffects` "Framed"), so only they see it. Duration 4 s.

What uses it:

| Combo | Effect |
|---|---|
| Z → Z (Step In) | Step In only works on a Framed target. |
| Z → X (Paste) | Paste moves the Framed target into the photo instead of her. |
| Shutter on Framed | +1.5 s on the frame, up to 4 s. |
| Framed → V | Iris Horizon starts half-closed, shuts in 0.4 s. |
| Framed → F | Two mirror hits per tick instead of one. |

Example chain: Snapshot (Frame) → pin a photo inside Desaturate → Paste the target into it →
Iris Horizon.

## The triangle rules

### Mandela beats Photoshop

1. **Misremembered forgets edits.** New `Passives.ResistEdit(player)`: true when the player
   holds Mandela with Misremembered ready. Then the passive goes on cooldown (as when it
   erases a hit) and draws its usual "Misremember" effect. Every Photoshop module calls it
   before putting an **edit** on a player: Framed, Desaturated, the Paste move, and the
   Iris Horizon grounding. If it returns true, that edit doesn't happen. Her **damage still
   lands**.
2. **Mandela's damage can't be undone** (see Undo).

### Photoshop beats Iridescent Requiem

Desaturate (no Luminance, flight or Prism Form), Iris Horizon's grounding, Paste pulling him
out of the sky, and Kaleidoscope bouncing his beams back.

### Iridescent Requiem beats Mandela

`BlackHole` (Event Horizon) and `Tornado` don't pull or hold a character whose `Flying`
attribute is on. Their damage still lands. Mandela's answer is his Knife. Since Desaturate and
Iris Horizon ground Iridescent, this stays consistent.

## Code changes

New:

- `src/ServerScriptService/Skills/Shutter.luau`, `Snapshot.luau`, `PhotoTeleport.luau`,
  `Desaturate.luau`, `IrisHorizon.luau`, `Kaleidoscope.luau`
- `src/ServerScriptService/Framed.luau`
- `src/ServerScriptService/PhotoshopServer.server.luau`: History, Undo and the Gallery. It makes
  its own RemoteEvents in code (`Undo`, `PhotoGallery`) the way `KillFeed` does.
- `src/StarterPlayer/StarterPlayerScripts/PhotoGallery.client.luau`: the T picker.

Changed:

- `SkillSetConfig`: the Photoshop entry, its colours, and the documented `undo` field.
- `ShopConfig`: Photoshop becomes a real item (`set = "Photoshop"`, placeholder ¥25,000).
- `StatusConfig`: Desaturated.
- `SkillEffects/init.client.luau`: every Photoshop visual, built in code (no new prefabs).
- `SkillBar.client.luau`: G does Undo for a set with `undo`, with its cooldown shown.
- `Inventory.client.luau`: the G detail row for Undo.
- `PlayerStats.luau`: the `PhotoGallery` text field.
- `Passives.luau`: `ResistEdit`.
- `LuminanceServer.server.luau`, `Skills/PrismForm.luau`: respect Desaturated.
- `Skills/BlackHole.luau`, `Skills/Tornado.luau`: skip flying characters for pulls and holds.
- `Skills/LightShot.luau`, `Skills/PrismShot.luau`: a beam that would hit a Photoshop holder
  inside her own Kaleidoscope bounces back instead (they ask `Kaleidoscope.Reflects`).
- `studio-manifest.json`: the new scripts.
- `ROADMAP.md`: Photoshop moved from "new" to built, waiting on Studio.

Needed in Studio (not creatable from here):

- A `Photoshop` Tool in `ServerStorage.SkillSetTools` with the attribute `SkillSet = "Photoshop"`.
- Optional: wearables in `ServerStorage.SkillSets.Photoshop`, and a
  `ReplicatedStorage.PhotoshopAnimations` folder (CastZ, CastX, CastC, CastV, CastF). A move
  without an animation casts without a pose.
- Optional: sounds, if wanted later.

## Testing

Nothing can run in the cloud session, so the deliverable includes an in-game checklist for the
owner covering: each move against the Player Dummy, each Framed combo, the Gallery (save,
travel, combat lock, cancel on damage, kept after rejoining in a live server), Undo (position,
heal, no heal from Mandela damage), and with two players the three counters: Desaturate on
Iridescent (flight, Prism Form, Luminance), Misremembered forgetting a Frame, and Iridescent
flying through Event Horizon and Tornado.

Without a Luau toolchain here, the code is checked by careful reading; a syntax error breaks a
whole script, so the local session's compile check in Studio matters.
