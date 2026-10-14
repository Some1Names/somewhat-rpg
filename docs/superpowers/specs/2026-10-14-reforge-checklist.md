# Reforge: in-game test checklist

`tests/ReforgeRules.spec.luau` passes (costs, slots, rolls, the multipliers, the saved text and its clamping;
run in Studio on 2026-10-14 because Lune isn't installed on this machine). The scripts and the
`ReforgeAction` RemoteFunction were synced to Studio the same day; one playtest only checked that it loads
with no errors and that a server-side level-up spends 10 Scrap and ¥200 and mirrors `Reforge_Mandela`.
The menu, the smith and everything below have not been played.
Still needed in Studio: a **smith** model tagged **`Smith`** with a ProximityPrompt (like a shopkeeper).
Materials come from enemy drops; until that's in, give yourself some **on the server** (server command
bar; from a client it doesn't replicate): `player:SetAttribute("Mat_Scrap", 100)` (also `Mat_Core`,
`Mat_Crystal`, `Mat_Essence`) and yen from the admin panel. The numbers are in `ReforgeConfig`.

## The smith
- [ ] Press the smith's prompt: the SMITH menu opens, lists the powers and weapons you own (best tier
      first) and your yen. Walking away more than 14 studs closes it.
- [ ] With nothing owned the list says "You own nothing to reforge".
- [ ] Picking a set shows its level, "+N% damage", the next level's cost, and two slots (slot 1 locked
      until level 3, slot 2 until level 7).

## Levels
- [ ] LEVEL UP spends exactly the listed materials and yen (level 1: 10 Scrap + ¥200) and the level goes up.
      Short of either, the button is grey and the server refuses it with a message that costs nothing.
- [ ] Levels 4-6 want Core, 7-9 Crystal, level 10 Essence. At level 10 the menu says "Highest level".
- [ ] Reaching level 3 opens slot 1, level 7 opens slot 2.

## Modifiers
- [ ] REROLL on an open slot costs its listed price (slot 1: 3 Core + ¥500, slot 2: 3 Crystal + ¥2,500) and
      shows the old roll beside the new one. KEEP NEW swaps it in; KEEP OLD leaves it. Both cost the same.
- [ ] While a roll waits, LEVEL UP and REROLL are grey. Closing the menu and reopening it (pick the set
      again) still shows the waiting roll.
- [ ] A second modifier never repeats the first.

## In combat
- [ ] Might or a high level makes a hit land harder on a dummy than before. The same set hits a player for
      only about half the bonus.
- [ ] Swift shortens the set's skill cooldowns, and the skill bar's fill and countdown match the real wait.
- [ ] Searing, Rending, Venom and Sapping apply Burnt, Bleeding, Poisoned and Weakened now and then, never
      more than once a second on the same target, and never from a damage-over-time tick.
- [ ] Vampiric heals you a little on each hit.

## Saving and the server checks
- [ ] Rejoin: every set's level and modifiers are still there (needs a live server; Studio doesn't save).
- [ ] A set you don't own can't be reforged; from outside 14 studs of the smith nothing works.
- [ ] Admin "Reset progress" clears all reforge levels.
