# Getting Powers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Who runs it:** Tasks 1–6 are code only: a **cloud session** can do them. Task 7 needs
> **Studio, a live server and the owner** (Developer Products, spawn points, the briefcase model).
> Branch `claude/vigilant-rubin-ckqtnn` (or a fresh branch off it). Read `CLAUDE.md`.

**Goal:** Hold one saved power, keep 2 in saved storage, own lifetime powers bought with Robux, and get new powers as briefcases from the Power Dealer (yen), map drops and a yen gacha, with selling, death drops and no starter power.

**Architecture:** Numbers and pure rules in `PowerConfig` (Lune-tested); one `Powers` module owning the state (saved player attributes), briefcase tools and inventory actions, replacing `Loadout`'s power half; a `PowerSources` script for the dealer, gacha, map drops and Robux receipts; Inventory and ShopMenu UI.

**Tech Stack:** Roblox Luau; Lune (`tests/run.sh`); StyLua (parse) and selene in `~/.cargo/bin`.

**Spec:** `docs/superpowers/specs/2026-10-09-power-acquisition-design.md` (every rule and number).

## Global Constraints

- Numbers only in `PowerConfig`: tier prices S 500,000 / A 150,000 / B 50,000 / C 15,000; weights 5/15/30/50; StorageSlots 2; gacha ¥25,000, cooldown 7,200 s real time, pity 30; drop every 1,200 s, lifetime 1,200 s; death drop 60 s; sell share 0.3; Aido not for sale, sell ¥200,000.
- **The server decides everything** (ownership, prices, cooldowns, odds); clients only ask. Every remote validates its arguments and the player's distance to the NPC involved.
- Yen only through `PlayerStats` (`SpendYen`, `AddYen`); powers only through `Powers`.
- **Robux:** `MarketplaceService.ProcessReceipt` grants once per receipt (record granted receipt ids in the player's saved data, or return `PurchaseGranted` only after the save succeeds); never grant a lifetime power twice.
- Studio-only instances (`ServerStorage.Briefcase`, `BriefcaseSpawn` parts, the `PowerGacha` NPC, product ids) fail quietly when missing and are listed for Task 7.
- `OwnAllSets = true` still makes every power lifetime (testing).
- UI square; match the surrounding style.

## Review Focus

1. **Duplication:** a briefcase can't be used, stored, sold and dropped twice by racing remotes (one server-side state per briefcase tool; it's destroyed the moment it's consumed). (Task 2 step.)
2. **Robux safety:** a purchase made while the player's data is still loading, or right before they leave, is granted exactly once (or deferred to their next join), and never lost. (Task 4 step.)
3. **Losing a power only when confirmed:** Use/Switch with no free slot needs the client's confirm flag; the server re-checks it would really be lost and refuses otherwise. (Task 2 step.)
4. **Death drops:** briefcases drop at the death spot, can't be picked up by the dead player's new character within the first second (so a respawn doesn't instantly re-grab), and despawn after 60 s; leaving loses carried briefcases, stored ones stay. (Task 2 step.)
5. **No power:** a player with no power gets no skill tool, the skill bar hides, punches work, and nothing errors (SkillBar, Inventory, StatusHUD). (Task 5 step.)

---

### Task 1: PowerConfig (pure, TDD) and saved fields

**Files:** Create `src/ReplicatedStorage/PowerConfig.luau`, `tests/PowerConfig.spec.luau`; modify `src/ServerScriptService/PlayerStats.luau` (`TEXT_DEFAULTS`: `CurrentPower`, `PowerStorage`, `LifetimePowers`; numeric `DEFAULTS`: `GachaReadyAt = 0`, `GachaPity = 0`).

**Interfaces:**
- Produces: `PowerConfig.price(setName) -> number?` (nil = not for sale), `sellPrice(setName) -> number`, `roll(rng: () -> number, pity: number, available: {[tier]: {setName}}) -> tier`, `pick(rng, list) -> setName`, `encodeList({setName}) -> string`, `decodeList(text) -> {setName}`, and the constants. Pure: tiers and set names passed in, no requires of Roblox-only modules (SkillSetConfig has `Color3`; pass tier info in).

- [ ] **Step 1:** Spec first (the spec's Testing list) → FAIL → module → PASS (`tests/run.sh`).
- [ ] **Step 2:** The PlayerStats fields (they load/save like the others).
- [ ] **Step 3:** StyLua and selene; commit `"Powers: config, rules and saved fields"`.

### Task 2: Powers (state, briefcases, inventory actions, death drops)

**Files:** Create `src/ServerScriptService/Powers.luau`; modify `src/ServerScriptService/Loadout.luau` (power half → `Powers`: the spawn hand-out uses `CurrentPower`; remove `DEFAULT_POWER`; weapons unchanged; header comment) and `LoadoutServer.server.luau` if it handles power swaps.

**Interfaces:**
- Produces: `Powers.GiveBriefcase(player, setName)`, `Powers.Current(player) -> setName?`, `Powers.IsLifetime(player, setName)`, `Powers.GrantLifetime(player, setName)`; RemoteFunction `PowerAction(action, args)` with actions `use`, `store`, `takeOut`, `swap`, `switch` (each returns `ok, message`); briefcase Tools with `PowerBriefcase`.

- [ ] **Step 1:** State from the saved attributes (decode/encode via `PowerConfig`), the hand-out of the current power's tool each spawn, briefcase tools (clone `ServerStorage.Briefcase`, else a placeholder part Tool).
- [ ] **Step 2:** The actions per the spec's table, with confirm flags for losing a power.
- [ ] **Step 3:** Death drops (pickup parts with a ProximityPrompt "Pick up"; 60 s; not the dead player's new character in the first 1 s) and losing carried briefcases on leave.
- [ ] **Step 4:** Read through Review Focus 1, 3, 4; name the line for each in the commit message.
- [ ] **Step 5:** StyLua and selene; commit `"Powers: one held power, storage, lifetime and briefcases"`.

### Task 3: The dealer and the gacha

**Files:** Create `src/ServerScriptService/PowerSources.server.luau`; modify `src/ReplicatedStorage/ShopConfig.luau` (the Powers shop's items become briefcase sales per `PowerConfig.price`; header comment), `src/ServerScriptService/ShopServer.server.luau` (briefcase purchase → `Powers.GiveBriefcase`; a `sell` action for a carried briefcase near the dealer).

- [ ] **Step 1:** Dealer: buy (price, yen, near the dealer), sell (30% / set price; destroys the briefcase first, then pays).
- [ ] **Step 2:** Gacha: `PowerGacha` NPC prompt → a RemoteFunction `RollGacha`: checks cooldown (`os.time()` vs `GachaReadyAt`), yen, rolls with pity, gives the briefcase, saves pity and cooldown.
- [ ] **Step 3:** StyLua and selene; commit `"Powers: dealer briefcases, selling and the gacha"`.

### Task 4: Map drops and Robux

**Files:** `PowerSources.server.luau`.

- [ ] **Step 1:** Map drops: every 20 minutes one briefcase pickup at a random `BriefcaseSpawn` part (none → skip), a kill-feed line (the `KillFeed` remote's message style), despawn after 20 minutes, one at a time.
- [ ] **Step 2:** Robux: `ProcessReceipt` for `PowerConfig.RobuxProducts`: grant `Powers.GrantLifetime`, save, then `PurchaseGranted`; if the player isn't loaded or isn't in the server, `NotProcessedYet`. A RemoteEvent the dealer UI uses to `PromptProductPurchase` (refused if already lifetime). Read through Review Focus 2.
- [ ] **Step 3:** StyLua and selene; commit `"Powers: map drops and lifetime Robux purchases"`.

### Task 5: UI

**Files:** `Inventory.client.luau` (Current / Storage / Lifetime / Briefcases rows and actions, the confirm dialog, the leave warning), `ShopMenu.client.luau` (briefcase prices, "Lifetime R$" buttons, Sell), a small gacha panel (in `ShopMenu` or a new `Gacha.client.luau`: price, cooldown left, pity count, Roll), `SkillBar.client.luau` and others only as needed for Review Focus 5.

- [ ] **Step 1:** The UI. Read through Review Focus 5.
- [ ] **Step 2:** StyLua and selene; commit `"Powers: inventory, dealer and gacha UI"`.

### Task 6: Docs and review

**Files:** Create `docs/superpowers/specs/2026-10-09-power-acquisition-checklist.md`; modify `ROADMAP.md` (remove "saved ownership + loadout" from the to-do; add enemy briefcase drops and the stat rework as later), `docs/superpowers/plans/README.md`, `CLAUDE.md` (Player data: Powers; the Robux rule: products are the owner's to create), `docs/patch-notes/update-1-th.md` only if the owner asks.

- [ ] **Step 1:** Write them; `tests/run.sh`; commit; push.
- [ ] **Step 2:** Dispatch a reviewer subagent over the diff with the spec and this Review Focus; fix what it confirms; push.

### Task 7 (Studio, live server, with the owner)

- [ ] **Step 1:** Repo → Studio per `CLAUDE.md`.
- [ ] **Step 2:** With the owner: a `ServerStorage.Briefcase` Tool model; `BriefcaseSpawn` parts around the map; a `PowerGacha` NPC with a prompt; Developer Products created by the owner (Creator Dashboard) and their ids in `PowerConfig.RobuxProducts`.
- [ ] **Step 3:** Playtest with the checklist (saving and Robux in a live server). Move the `studio` tag; re-export; push.
