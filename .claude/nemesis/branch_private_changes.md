# Branch: `chore/wow-ac-nemesis-init-private-changes`

**Fork:** `l-Vladislav/mod-nemesis-system` (private)
**Upstream:** `scarecr0w12/mod-nemesis-system` (original)
**Purpose:** Bundle all private customizations of the Nemesis module for the v2 server.

Future feature branches (like `feat/wow-ac-nemesis-bounty-board`) should be branched off this.

## What's in this branch

This is a cumulative private fork with many customizations layered on top of upstream. All changes are in the nemesis module repo, not the core azerothcore-wotlk repo.

### Gameplay / Rewards

- **Damage multiplier decoupled from health** (health 1.5x–6.0x, damage 1.25x–2.50x)
- **Gold level scaling** — `level / 80`, balanced at 1g/rank at lvl 60
- **Mail fallback** for full inventory (`AddItemOrMail` helper)
- **Token reward reworked (2026-04-17)** — uses gray-level gating from `Acore::XP::GetGrayLevel`:
  - Green or higher → guaranteed token(s)
  - Gray (trivial) → no tokens AND no bonus drops
  - `rewardMultiplier > 0.0f` guard removed — gate is now inside `GrantReward`
  - Gold still scales by the overlevel multiplier

### Russian localization

- `[Немезида]` prefix on all announcements
- **Russian title generator** — 40×40×25 = 40,000 deterministic combos (`GenerateNemesisTitle`)
- `creature->SetName(title)` in `ApplyNemesisState`; restored in `ResetCreatureToBaseState`

### Addon / client integration

- Runtime GUID in addon payload (24th field)
- Nemesis title in addon payload (25th field)
- `FindBaseNonInstanceMap` — searches creature's actual map, not just the player's
- Chunk ID uses static counter (fixes duplicate IDs causing lost data)
- Chunk size bumped to 450 bytes
- `HandleAddonBootstrap` sends ALL nemeses (`includeAll = true`)
- Performance: removed `DoForAllPlayers` loop on creation; creation push only to the killed player
- `BroadcastNemesisMessage` always server-wide

### Client addon (`ClientAddon/NemesisTracker/`)

- **WorldMap.lua**: world map pins, side panel with zone grouping, icon toggles, minimap button, portrait skull
- Strict matching: `runtimeGuid` then `nemesisTitle`
- Loose matching (entry+zone) for tooltip hook only
- All UI text in Russian
- Locale-independent zone matching via `GetMapInfo()`
- Player zone cached via `updatePlayerZoneCache()`
- Defaults to "This Zone"; click navigates via `SetMapZoom`
- **Core.lua**: always-visible nemeses, `runtimeGuid`/`nemesisTitle` parsing, peer sync includes both fields, auto-sync every 300s, chat trigger on Russian or English `[Немезида]`/`[Nemesis]` keyword, zone-change bootstrap after 3s

### Bounty Vendor (2026-04-06)

- `NemesisBountyVendorScript` — AllCreatureScript on all innkeepers
- Injects "Награды охотника за головами" gossip option
- Opens shared vendor entry 190000 via SendListInventory with temp VENDOR flag
- SQL: `data/sql/db-world/base/nemesis_bounty_vendor.sql` (token item 100017, extended costs 100001–100005)
- Config flags: `NemesisSystem.BountyVendor.Enable`, `NemesisSystem.BountyVendor.Entry`

### Config (`conf/mod_nemesis_system.conf.dist`)

- `MaxRank = 6`
- `PromotionLevelDiffMax = 9`
- `RevengeRewardItem = 100017`, `RevengeRewardItemPerRankBonus = 1`
- `BountyRewardItem = 100017`, `BountyRewardItemPerRankBonus = 1`
- `RevengeRewardGold = 13333`, `RevengeRewardGoldPerRankBonus = 13333`
- `BountyRewardGold = 3333`, `BountyRewardGoldPerRankBonus = 3333`
- `BonusDrop.Item = 41605`, `BonusDrop.ChancePerRank = 20.0`
- `AddonBootstrapMaxEntries = 1000`
- `VisualAuraSpell = 0`

### Known issues (documented in [pending_changes.md](pending_changes.md))

1. Tooltip hook requires full WoW restart (HookScript persists across `/reload`)
2. `runtimeGuid` empty for nemeses whose map isn't loaded
3. 3.3.5 client caches creature names by entry — `SetName` may not appear until relog
4. Portrait matching not 100% reliable (depends on #2 and #3)
5. Tooltip loose matching may false-positive on same-entry creatures in same zone

## How to push to your fork

This branch has no upstream set yet. First push:

```bash
cd modules/mod-nemesis-system
git push -u origin chore/wow-ac-nemesis-init-private-changes
```

Subsequent pushes: `git push`.

## Next planned branches

- `feat/wow-ac-nemesis-bounty-board` → see [ticket_bounty_board.md](ticket_bounty_board.md)
