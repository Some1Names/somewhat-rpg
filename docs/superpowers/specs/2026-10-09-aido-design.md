# Aido skill set: design

Status: approved in chat 2026-10-09 (the kit, the names, no "No Rebirth", the full-dragon form),
and this written spec approved by the owner the same day.

## Intent

Furukiwa Aido, **The Director**: once a big-brother figure and companion to Himaru, revealed at
the end of Level 0 as the opposing force. He wants to **end the cycle of rebirth**, out of his own
philosophy about the cycle, existence, suffering, identity and freedom. He isn't evil for the
sake of it. His power is atomic annihilation: destruction so total nothing is left to be reborn.

**Playstyle:** staged destruction. He sets up the stage (fused warheads, a pull, a marching line
of blasts, a countdown everyone can see) and calls the detonations. Enemies who stay put get
punished. **Every move hurts on its own**; setting up only makes it hurt more (the lesson of
Photoshop's first playtest, where setup moves felt weak).

**Matchups:** outside the Mandela > Photoshop > Iridescent Requiem > Mandela triangle. No special
counters either way. He's the rare, expensive "boss" power: strong but slow and readable.

**Look:** red, atomic. Final visuals come from imported VFX packs (`CLAUDE.md`); until those
prefabs exist the code uses placeholders. Success: an Aido player feels like he's directing a
disaster; his enemies can always see it coming and get out if they react.

## The set

`SkillSetConfig.Sets.Aido`: `tool = "Aido"`, `kind = "power"`, `tier = "S"`,
`color = SkillSetConfig.AidoRed` (`Color3.fromRGB(255, 64, 48)`). New shared colour:
`SkillSetConfig.AidoCore = Color3.fromRGB(255, 196, 120)` (the hot core of a blast).

All damage goes through `Damage.Deal` with `{ stat = "Superliminal", skillSet = "Aido" }`; none
of his moves are physical (`melee`). Numbers below are before the Superliminal bonus. His own
blasts never hurt him.

### Passive: Half-Life

`passive = { name = "Half-Life", mastery = 10, burntBonus = 0.25, falloutRadius = 6, falloutDuration = 3 }`
(unlocks at mastery 10, per `2026-10-09-mastery-unlocks-design.md`; the overcharge at 25)

- Every **skill blast** (Z, X's final blast, each C blast, V, F's roar; not Fuse, not aftershocks,
  not Atomic Breath) leaves a **Fallout** patch: `falloutRadius` studs, `falloutDuration`
  seconds. Each second, everyone standing in it gets **1 Burnt stack**.
- A blast on someone **already Burnt** deals `1 + burntBonus` times its damage.
- The passive's Passives behaviour also carries Final Cut's damage cut (below).

### G: Chain Reaction (overcharge)

`overcharge = { name = "Chain Reaction", color = AidoRed, maxStacks = 10, damagePerStack = 40,
meleeShare = 0.35, duration = 15, cooldown = 30, killRefill = 1.5, decayDelay = 6,
decayPerSecond = 0.5 }`. **No `takenShare`**: it fills only from damage he deals.

- While it's on, every skill blast sets off **3 aftershocks** 0.25 s later at random points within
  60% of its radius: **30%** of the blast's damage each, 6-stud radius. Aftershocks don't make
  Fallout, don't set off more aftershocks, and don't get the Burnt bonus.
- `aftershock = { count = 3, delay = 0.25, share = 0.3, radius = 6, spread = 0.6 }` in the set.

### Click: Fuse (ranged)

`ranged = { name = "Fuse", handler = "Fuse", aims = true, charges = 3, recharge = 3,
interval = 0.3, animation = "CastZ", projectile = { model = "FissionSeed", speed = 90,
range = 80, radius = 1 } }`

- Throws a fission seed where the mouse points. It **sticks**: to the first person it hits (it
  follows them) or where it stops (a wall, the floor, or at max range).
- **1 s** later it pops: **12 damage**, 6-stud radius. A pop on someone Burnt gets the Half-Life
  bonus, but it leaves no Fallout, applies no Burnt and never sets off aftershocks (that keeps
  the click from snowballing).
- `ReplicatedStorage.ProjectileModels.FissionSeed` doesn't exist yet. Without it the client
  draws nothing in flight (`effects.Projectile` returns when the model is missing) and nothing
  errors; the seed shows once it sticks (`FuseStick`). It needs adding in Studio for looks only.

### Z: Catastrophe (mastery 1)

`cooldown = 7`, `aim = { kind = "circle", range = 70, radius = 14 }`, `recast = "Detonate"`,
`form = true`.

- Places a warhead at the aim point (on the ground there). It goes off by itself after **1 s**,
  or **Z again** sets it off at once.
- Blast: **40 damage**, 14-stud radius, **1 Burnt stack**. Fallout. Aftershocks while Chain
  Reaction is on.

### X: Collapse (mastery 5)

`cooldown = 10`, `aim = { kind = "circle", range = 60, radius = 20 }`, `form = true`.

- An implosion at the aim point: everyone within 20 studs is **pulled to the centre for 0.6 s**,
  taking **4 damage three times** on the way in (0.2 s apart), then a **25-damage** compression
  blast (10-stud radius) at the centre. Fallout. Aftershocks.
- The pull follows `CrowdControl`: players only when `CanControl`, held with `Begin`/`End` like
  Event Horizon; flying characters aren't pulled. The damage lands either way.

### C: Total Destruction (mastery 20)

`cooldown = 14`, `aim = { kind = "path", length = 80 }`,
`overchargedAim = { kind = "path", length = 80, count = 3, spread = 25 }`, `overcharged = true`,
`form = true`.

- **6 blasts** march forward along his look direction, evenly spaced over 80 studs, **0.15 s**
  apart, each **14 damage** in an 8-stud radius, on the ground under each point. Each blast leaves
  Fallout; aftershocks while Chain Reaction is on.
- No one takes more than **3** of one cast's blasts (aftershocks don't count towards that).
- **Chain Reaction on:** 3 lines, 25° apart (the same cap of 3 per person across all lines).

### V: Ground Zero (mastery 50)

`cooldown = 45`, `aim = { kind = "circle", range = 80, radius = 40 }`, `form = true`.

- Marks a 40-stud circle at the aim point with a **3 s countdown everyone can see** (a ring on the
  ground and a big number, square UI), then the nuke.
- Damage falls off from **110 at the centre** to **40 at the edge**, linearly with distance.
  **2 Burnt stacks**. Leaves a **Fallout field of 30 studs for 6 s** (its own size, not the
  passive's 6/3). Aftershocks while Chain Reaction is on (from the blast's centre damage).

### F: Final Cut (mastery 100)

`cooldown = 90`, `overchargedOnly = true`, `overcharged = true`, `handler = "FinalCut"`,
`recast = "Revert"`, `aim = { kind = "self", radius = 20 }`.

The set's `form`:

```
form = {
	name = "Final Cut", key = "F", attribute = "FinalCut", duration = 12,
	damageReduction = 0.2, blastScale = 1.5, camera = 22,
	ranged = { name = "Atomic Breath", handler = "AtomicBreath", aims = true, primary = true,
		interval = 0.2, beam = { range = 60, effect = "AtomicBreath" } },
}
```

- Needs Chain Reaction on (`overchargedOnly`). Entering: a **40-damage roar blast** in a 20-stud
  radius around him (Fallout, aftershocks).
- Lasts **12 s** (even if Chain Reaction runs out first). **F again** (Revert), death, or putting
  the set away ends it early.
- While it lasts:
  - **Atomic Breath:** left click (held, no right click needed) breathes a 60-stud beam, **8 damage
    every 0.2 s** to the first one it hits, **1 Burnt stack** each hit. Free (no ammo). It
    replaces Fuse until the form ends.
  - He takes **20% less damage** from everything (`damageReduction`).
  - Skills marked `form` blast **1.5×** wider (`blastScale`).
  - The camera can't zoom in closer than `camera` studs, so he sees around the dragon.

**The dragon (Studio model, doesn't exist yet):** `ServerStorage.SkillSets.Aido.Dragon`, a
`Model` with a `PrimaryPart` named `RootPart` and an `AnimationController` with an `Animator`.
While the form lasts the server welds a copy to his `HumanoidRootPart` (in a folder in his
character), with every part `Massless`, `CanCollide`/`CanTouch`/`CanQuery` off. Clients hide
his own body (`LocalTransparencyModifier`) while a dragon is attached and play
`ReplicatedStorage.AidoAnimations.DragonIdle`/`DragonWalk` on it by his speed, and `DragonBreath`
while breathing. **His hitbox stays his own body**: every skill finds targets through the part's
`Model` ancestor and a `Humanoid`, so dragon parts can't be hit without changing them all. That's
why the damage cut is **20%**, not the 30% first discussed (he isn't a bigger target).
**Without the model** he keeps his body and gets a red atomic aura instead; everything else works.

### Shop

`ShopConfig`'s `AidoPower` placeholder becomes the real item: `set = "Aido"`, `price = 40000`,
no `comingSoon`, `name = "Aido"`, `description = "Furukiwa Aido, The Director. Fuse, Catastrophe,
Collapse, Total Destruction, Ground Zero, Final Cut. G: Chain Reaction. Passive: Half-Life."`

## Changes to shared systems

- **`SkillSetConfig.RangedFor(character, setName)`**: the form's `ranged` while `InForm`, else
  the set's. Used by RangedServer, the Ranged client and the SkillBar ammo slot instead of
  `set.ranged` directly.
- **A ranged move with no cost field is free:** RangedServer's `pay` accepts a ranged table with
  none of `charges`, `luminanceCost`, `rounds` (Atomic Breath). The SkillBar ammo slot shows no
  count for it.
- **`Projectiles.Launch` gets `onStop(position, hitPart, struckHumanoid)`**, called once whenever
  the projectile ends (a person, a wall, max range), next to the existing `onHit`.
- **`Passives`:** a `"Half-Life"` behaviour: in Final Cut, all damage is cut by
  `form.damageReduction` (physical or not); otherwise unchanged.
- **SkillBar:**
  - the form key check (`form.key == key and Luminance < form.minimumToStart`) only applies when
    the form has `minimumToStart` (it would error for Aido);
  - `ACCENT` (Mandela green) becomes the equipped set's `color` where it colours the overcharge
    meter and READY label.
- **SkillEffects:** an `AidoEffects` module loaded like `PhotoshopEffects`.

Nothing else in the framework is Mandela- or Iridescent-specific for what Aido uses (overcharge,
`overchargedOnly`, recasts and `form` all read config).

## Visuals (placeholders now, packs later)

Every effect goes through `AidoEffects` and asks for `Aido/<Name>` first (`VFX.Find`); missing, it
plays a red-tinted `Shared/*` prefab (`BigImpact`, `Shockwave`, `Impact`, `AuraBurst`, `Sparks`)
plus `VFX.Crater` / `VFX.Shake`. Effects: `FuseStick`, `FusePop`, `CatastropheArm`,
`CatastropheBlast`, `CollapsePull`, `CollapseBlast`, `TotalDestructionBlast`, `GroundZeroCountdown`,
`GroundZeroBlast`, `Fallout` (a zone, ended by `FalloutEnd`), `Aftershock`, `FinalCutRoar`,
`AtomicBreath`, and the dragon/aura from the character's `FinalCut` attribute. Screen-wide flashes
respect the Flashes setting (`VFX.ImpactFrame*`). Picking packs is a later local-session plan,
with the owner's OK before any import.

## Not in scope

No Rebirth (dropped), flying as a dragon, Monotwister (his katana, a later S weapon), the pack
VFX themselves, animations (`AidoAnimations` CastZ–CastF, Dragon*), the dragon model.

## Testing

- Lune unit tests for a pure `AidoMath` module (`src/ServerScriptService/AidoMath.luau`):
  Ground Zero's falloff, aftershock points, the line points and fan directions.
- StyLua parse and selene on every changed script.
- In-game checklist `docs/superpowers/specs/2026-10-09-aido-checklist.md` for the owner.
