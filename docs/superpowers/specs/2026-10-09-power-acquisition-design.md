# Getting powers (briefcases, storage, lifetime, drops, gacha, selling): design

Status: approved in chat 2026-10-09; waiting on review of this written spec.

## Intent

Today everyone owns every power (`SkillSetConfig.OwnAllSets`, for testing) and nothing about
powers is saved (`Loadout` is session-only). This designs how powers are **held, kept and
found**, Blox Fruits style: you hold one power, keep a few spares in storage, and find new ones as
briefcases from the dealer, map drops and a yen gacha, or buy a lifetime copy with Robux. Powers
are rare and valuable (S-tier ≈ ¥500,000), and losing an unstored one is a real risk.

Success: getting an S-tier power feels like an event; nobody ever loses a power they paid Robux
for; storage decisions matter; nothing about it can be duplicated or exploited.

Later, not here: enemies dropping briefcases, the stat rework, trading, storage upgrades.

## Holding and keeping powers

- **No starter power.** A new player starts with no power (fists only). Mandela becomes a normal
  S-tier power.
- **Current power:** the one power you hold (its tool in your hotbar, as now). Saved.
- **Storage: 2 slots** of spare powers. Saved.
- **Lifetime powers:** bought with Robux; yours forever; never use a storage slot; can't be lost.
  Saved.
- **Mastery is kept per power** (already saved per set), so switching back keeps your levels.
- **Weapons are unchanged** (bought in the shop, `Owns<id>`, carried alongside a power).

## Briefcases

- Every new power arrives as a **briefcase** item ("Photoshop Briefcase"): a Tool in your hotbar,
  from `ServerStorage.Briefcase` (a model the owner adds in Studio; a plain placeholder box until
  then), with attribute `PowerBriefcase = "<SetName>"`.
- **Carried briefcases aren't saved:**
  - **On death**, each drops where you died as a pickup; anyone can grab it for **60 s**, then it
    despawns.
  - **On leaving**, they're lost. The Inventory warns: "Unstored briefcases are lost when you
    leave."

## The Inventory (B): managing powers

Rows: **Current power**, **Storage (2)**, **Lifetime**, **Briefcases** (carried). Actions:

| Action | Effect |
|---|---|
| **Use** a briefcase | It becomes your current power. Your old current power is **lost** unless it's lifetime (confirm dialog: "Use Photoshop? You'll lose Mandela."). |
| **Store** a briefcase | Into a free storage slot. |
| **Take out** a stored power | Back into a briefcase in your hotbar (frees the slot). |
| **Swap** with a stored power | Current ↔ that slot. Nothing lost. |
| **Switch** to a lifetime power | It becomes current; your previous current power goes to a free storage slot, or, if storage is full, is lost (confirm) unless it's lifetime. |

All checked by the server.

## Where briefcases come from

**Prices and odds** (config, per power and per tier):

| | S | A | B | C |
|---|---|---|---|---|
| Dealer price (yen) | ¥500,000 | ¥150,000 | ¥50,000 | ¥15,000 |
| Gacha / drop weight | 5% | 15% | 30% | 50% |

(Tiers with no powers yet are skipped and the rest re-weighted, so today every roll and drop is
one of the four S-tier powers.)

- **Power Dealer (yen):** sells briefcases at its tier price, for powers marked for sale: Mandela,
  Iridescent Requiem, Photoshop. **Aido isn't sold for yen.**
- **Robux (lifetime):** each power can have a Developer Product id (`PowerConfig.RobuxProducts`).
  **The owner creates the products** (Creator Dashboard → Developer Products) and sets the prices;
  the dealer shows a "Lifetime  R$" button for powers that have one. Buying grants the lifetime
  power, saved at once; `ProcessReceipt` is idempotent (a receipt never grants twice), and a power
  already owned for life can't be bought again.
- **Map drops:** every **20 minutes** a briefcase spawns at a random part tagged
  **`BriefcaseSpawn`** (placed by the owner in Studio), by the tier weights. The kill feed says
  "A briefcase has appeared somewhere…". Unclaimed after 20 minutes, it despawns. At most one map
  briefcase at a time.
- **Gacha (yen):** an NPC tagged **`PowerGacha`** with a prompt. **¥25,000 per roll**, **one roll
  every 2 hours** (per player, saved, real time). Tier weights as above; **pity:** after 30 rolls
  without an S-tier, the next is S (saved count). The briefcase goes to your hotbar.
- **Selling:** the Power Dealer buys a carried briefcase for **30% of its price** (¥150,000 for an
  S-tier); powers with no yen price have a set sell price (Aido **¥200,000**).

## Testing mode

`SkillSetConfig.OwnAllSets = true` (as now) makes every power lifetime for everyone, so testing
keeps working; turn it off at release.

## Architecture

- **`ReplicatedStorage/PowerConfig.luau`:** tier prices and weights, per-power overrides
  (`forSale`, `sellPrice`), `StorageSlots = 2`, gacha (price, cooldown, pity), drop (interval,
  lifetime, tag), death-drop time, `RobuxProducts`; pure, Lune-tested helpers: `price(set)`,
  `sellPrice(set)`, `roll(rng, pityCount) -> tier` and `pick(rng, tier) -> setName`, and the saved
  text encode/decode for storage and lifetime lists.
- **`ServerScriptService/Powers.luau`:** the state (player attributes `CurrentPower`,
  `PowerStorage`, `LifetimePowers`, `GachaReadyAt`, `GachaPity`), briefcase tools, the inventory
  actions (a `PowerAction` RemoteFunction), death drops and pickups, and `GiveBriefcase(player,
  setName)` for every source. **Replaces Loadout's power half:** `Loadout` keeps weapons; the
  power tool handed out each spawn is `CurrentPower`'s; `DEFAULT_POWER` goes.
- **`ServerScriptService/PowerSources.server.luau`:** map drops, the gacha NPC, the dealer's
  briefcase sales and buy-back, Robux `ProcessReceipt`.
- **`PlayerStats`:** new saved fields `CurrentPower`, `PowerStorage`, `LifetimePowers`,
  `GachaReadyAt`, `GachaPity`.
- **`ShopConfig` / `ShopMenu`:** the Powers shop lists briefcases (yen), Lifetime (R$), and
  **Sell** for carried briefcases.
- **`Inventory.client`:** the power rows and actions above (square, its current style).
- **Pre-release:** no migration of old `Owns<power>` flags; they're ignored.

## Testing

- Lune: `tests/PowerConfig.spec.luau`: prices by tier and overrides, sell price, roll weights
  with a seeded rng over many rolls (S ≈ 5%), skipped empty tiers, pity at 30, encode/decode.
- StyLua parse and selene.
- In-game checklist `docs/superpowers/specs/2026-10-09-power-acquisition-checklist.md` (saving and
  Robux need a live server; Robux test purchases are free in Studio's test mode for the owner).
