# Getting powers: in-game test checklist

Code is written (`PowerConfig`, `Powers`, `PowerSources`, Loadout/Shop/Inventory changes). Not played yet.
`tests/PowerConfig.spec.luau` logic passed in Studio on 2026-10-14 (Lune isn't installed here).
Before the first run, in Studio:
- `ServerStorage.TestBriefcase` (a Tool made from the Workspace `TestBriefcase` part) is the briefcase for now; a final
  Tool named `Briefcase` can replace it later (TestBriefcase is looked up first);
- parts tagged **`BriefcaseSpawn`** around the map (none yet: no map drops until then);
- the **`Power Gacha`** NPC (Workspace, next to the Power Dealer, tagged `PowerGacha`, prompt "Roll a power"); its panel
  and reel are `Gacha.client.luau`;
- a Power Dealer: a model tagged `Shop` with attribute `ShopId = Powers` (as before);
- Developer Products (Creator Dashboard) and their ids in `PowerConfig.RobuxProducts`, `{ Mandela = 123, ... }`.
For testing set `SkillSetConfig.OwnAllSets = false`, otherwise every power is lifetime. Saving needs a live server.

## Holding and no power
- [ ] A new player (clear their data) spawns with no power: no skill tool, the skill bar hidden, punches work, no errors.
- [ ] Inventory (B) shows nothing under POWER ("Empty") and the briefcase warning only while carrying one.

## Dealer, selling
- [ ] The dealer lists Mandela, Iridescent Requiem, Photoshop at ¥500,000 (S); Himaru etc. stay COMING SOON.
- [ ] Buying with enough yen puts "<Power> Briefcase" in the hotbar and takes the yen; short on yen refuses.
- [ ] SELL BRIEFCASE pays ¥150,000 (30%) and removes the briefcase; with none carried it refuses. Far from the dealer refuses.

## Inventory actions
- [ ] Briefcase card: USE makes it the held power (tool appears, mastery kept per power). With a held power
      that isn't lifetime it first asks CONFIRM ("You'll lose X"), CANCEL leaves everything.
- [ ] STORE moves it to storage (2 slots); a third is refused "Storage is full".
- [ ] Stored card: SWAP WITH HELD trades places (nothing lost); TAKE OUT gives a briefcase again.
- [ ] Lifetime card: SWITCH TO IT sends the old power to a free slot; with storage full it asks CONFIRM.
- [ ] A briefcase of a power you already own can't be used or stored (sell it).
- [ ] Clicking USE/STORE fast twice never gives two powers (one briefcase, one use).

## Death and leaving
- [ ] Dying drops each carried briefcase as a "Pick up" pickup at the death spot; the dead player can't re-take
      it in the first second; anyone else can; it vanishes after 60 s.
- [ ] Leaving with a briefcase loses it; stored and lifetime powers stay (rejoin: held power, storage and
      lifetime come back, with a power's tool handed out).

## Gacha and map drops
- [ ] The panel (E at the NPC): the first roll every 2 hours is FREE (button says FREE ROLL, countdown otherwise); any
      extra roll costs ¥25,000 any time and doesn't touch the free-roll timer. The reel stops on the result.
- [ ] Holding a briefcase: punches and skills do nothing. Left click it: a box "Use <Power>?" with USE POWER / CANCEL;
      a power you already own shows a red error; a held power that would be lost asks CONFIRM.
- [ ] After 30 rolls without an S the next is S (use the admin tools / `GachaPity` to skip ahead).
- [ ] Every 20 minutes (shorten `PowerConfig.Drop.interval` to test) a pickup appears at a `BriefcaseSpawn` part, the
      kill feed says "A briefcase has appeared somewhere...", only one at a time, gone after 20 minutes.

## Robux (live server, owner's test purchases)
- [ ] The dealer shows LIFETIME R$ only for powers with a product; buying grants the power for life and it shows in
      the Inventory with a LIFETIME tag; the button then says LIFETIME OWNED and a second prompt isn't sent.
- [ ] Buying right as you join (data still loading) or leaving immediately: the purchase is granted on your next join, never lost, never twice.
