# NEM-001: Nemesis Bounty Board

**Status:** Shipped (Phase 1–3). Phase 4 (red announces) pending.
**Branch:** `feat/wow-ac-nemesis-bounty-board` (fork: `l-Vladislav/mod-nemesis-system`)
**Opened:** 2026-04-17

## What ships

A per-zone, per-player "wanted poster" system. Players talk to innkeepers to pick up nemesis kill contracts, complete them for token rewards + RP flavor mail + reputation toward a hunter-title ladder.

## End-to-end flow

1. Player talks to any innkeeper → gossip has **"Доска объявлений охотника за головами"**.
2. Board shows up to 3 current nemeses in that zone, filtered by `3 - completedThisWindow_thisZone`. Empty-state has 5 RP variants ("Ты очистил наши края…").
3. Click a bounty → details shown via `SMSG_NPC_TEXT_UPDATE` as gossip header text (no extra gossip-item buttons). Accept / Back only.
4. Accept → row written to `character_nemesis_bounty` (`DirectExecute` → visible on next menu render without reopen).
5. Kill the target (any pool spawn point for rares — dedup works via creature entry) → `CheckCompletion` fires, writes history row, mails RP reward (20 flavor combos), clears active row.
6. Board re-shows `3 - completedCount` remaining slots in that zone for the 2h window.

## Data Model (final)

### `character_nemesis_bounty` (active, `acore_characters`)
```
guid            INT UNSIGNED PK
target_spawn_id INT UNSIGNED
target_title    VARCHAR(128)
zone_id         INT UNSIGNED   -- innkeeper zone at accept time (per-zone cap)
accepted_at     INT UNSIGNED
expires_at      INT UNSIGNED
```

### `character_nemesis_bounty_history`
```
id              BIGINT AUTO_INC PK
guid            INT UNSIGNED
target_spawn_id INT UNSIGNED
target_title    VARCHAR(128)
zone_id         INT UNSIGNED   -- copied from bounty row at completion
target_rank     TINYINT UNSIGNED
completed_at    INT UNSIGNED
tokens_earned   INT UNSIGNED
KEY idx_guid (guid)
KEY idx_character_nemesis_bounty_history_zone (guid, zone_id, completed_at)
```

### In-memory
- `PlayerDailyPools` — pool per `(player, zone)` — **always regenerated live** from `ActiveNemeses` (deterministic shuffle via seed). Cache only serves to hold the struct between functions, not across calls.

## Pool generation

1. Iterate `ActiveNemeses`, filter:
   - Same zone as innkeeper (strict zone match)
   - Not the player's own current-victim nemesis (no self-bounty)
   - Level range is optional (default unlimited — bounty reward is independent of gray-level gating)
   - Temp nemeses excluded
2. Sort by **(rank DESC, level DESC)**, shuffle within tier using seed `playerGuid ^ zoneId ^ 2h-window-ts`.
3. Keep top `SlotsPerDay` entries (default 3). Display loop then filters out stale (moved/cleared) and already-completed-in-window entries.
4. Special pickup: rare-mob spawns at alternate pool points resolve to the existing nemesis entry's stats + update its stored position (so the map pin follows pool rotation).

## Caps & pacing

| Rule | Value | Notes |
|---|---|---|
| Active contracts | 1 at a time | `GetActiveBounty` guards accept |
| Pool size | 3 (`SlotsPerDay`) | per-zone, per 2h |
| Window length | 2h (`PoolRefreshHours`) | aligned to global 2h clock boundaries |
| Completions cap | 3 per zone per 2h | Query filters by `zone_id` → visit multiple zones to do more |
| Contract lifetime | 24h (`DurationHours`) | natural expiry, no refund |
| Admin-clear refund | 1 token (`RefundTokensOnAdminClear`) | mailed via "Innkeeper" (entry 190002) with apology text |

## Rewards

**Token + gold** (via `MailDraft` attached to RP completion mail):
- `tokens = RewardTokens + RewardTokensPerRank * bountyRank` (default 3 + 2×r)
- `gold = RewardGold + RewardGoldPerRank * bountyRank` (default 5000cp + 5000cp×r)

**Mail sender**: creature_template entry 190002 "Innkeeper" (ASCII-only — the Russian 3.3.5a client's mail window renders creature names via a cp1251 path and mojibakes UTF-8 Cyrillic, so sender stays English while body/subject stay Russian).

**Reputation** (`character_nemesis_reputation`, separate system, consumed here):
- Bounty completion: `BountyCompletionBonus + BountyCompletionPerRank * bountyRank` (currently `0 + 15×r`)
- Regular nemesis kill (gray-gated): `BasePerKill + PerRankBonus * creatureRank` (currently `0 + 1×r`)
- Rank thresholds (doubled from defaults): 1000 / 5000 / 16000 / 40000
- Titles: Послушник / Охотник / Следопыт / Ветеран Охоты / Легенда Охоты

## Rare-mob dedup

Rare / rare-elite creatures (rank 2 or 4 in creature_template) have multiple pool spawn points. System collapses them:
- `PromoteNemesis` uses `FindRareNemesisSpawnId(entry, target)` → rank up the existing row instead of creating per-spawn rows.
- `GenerateNemesisTitle` for rares seeds from entry only → same Russian title at all spawn points.
- `OnCreatureAddWorld` for rares: `FindAnyRareNemesisSpawnId(entry)` → applies nemesis state to the new spawn and updates the stored position so the map pin follows.
- `CheckCompletion` for a rare-target bounty matches by entry (not just spawnId) so killing the rare at any pool spawn point counts.
- `.nemesis merge-rares` admin command cleans up pre-existing duplicates if needed.

## UI

**Gossip submenus** use `SendCustomNpcText` (SMSG_NPC_TEXT_UPDATE with a per-player textId) so details render as header text, not button rows. Gossip menu itself has only actionable buttons (Accept / Abandon / Back).

**Empty-state variants** (shown when `shown == 0`):
- Zone has no nemeses: `"Нет доступных контрактов."`
- All slots used or everything cleared/completed: 5 random RP variants ("Ты оказался полезен. Возвращайся позже…" etc., with hint to try other taverns).

**When active contract exists**, board hides the pool entirely and shows only the active bounty row + refuses new accepts with *"Сначала разберись с прошлым делом, путник."*

## Addon integration (ClientAddon/NemesisTracker)

- Chat parser: listens to private `[Немезида]` chat lines for accept / complete / abandon → updates `NT.db.activeBountyTitle` in SavedVariables (survives `/reload` and login).
- World map pin for active bounty target: **normal skull + gold glow ring + yellow `!` badge** (centered on skull's top-right corner, 16×16, `AvailableQuestIcon` texture).
- Portrait skull icon: gold glow + `!` badge to the right of skull when targeting active bounty.
- Side-panel list row: gold `!` prefix + gold-tinted name + muted gold background for active bounty.
- Tooltip "Награда: охота за головой" line shows **only** on active bounty target.
- Glow uses `SetBlendMode("ADD")` to strip the dark halo from `UI-Minimap-Background`.

## Admin commands

- `.nemesis clear <spawnId>` — removes a nemesis; triggers refund to any holder of a bounty on it (RefundBountiesForTarget).
- `.nemesis mapclear` — removes all nemeses on a map; triggers refunds per-target.
- `.nemesis clearall` — bulk wipe. Explicitly refunds all active bounties via `RefundBountiesForTarget`, calls `DeleteNemesisState` per nemesis (fires `BroadcastNemesisRemove` so addons drop pins), invalidates all cached pools.
- `.nemesis merge-rares` — collapses pre-existing duplicate rare-mob nemesis rows per (target, entry), keeps highest rank.

## Config (`mod_nemesis_system.conf`)

```
# Board behavior
NemesisSystem.BountyBoard.Enable = 1
NemesisSystem.BountyBoard.SlotsPerDay = 3
NemesisSystem.BountyBoard.DurationHours = 24
NemesisSystem.BountyBoard.PoolRefreshHours = 2
NemesisSystem.BountyBoard.LevelRangeDown = 0        # 0 = unlimited
NemesisSystem.BountyBoard.LevelRangeUp = 0          # 0 = unlimited

# Rewards
NemesisSystem.BountyBoard.RewardTokens = 3
NemesisSystem.BountyBoard.RewardTokensPerRank = 2
NemesisSystem.BountyBoard.RewardGold = 5000
NemesisSystem.BountyBoard.RewardGoldPerRank = 5000
NemesisSystem.BountyBoard.RefundTokensOnAdminClear = 1

# Announces
NemesisSystem.BountyBoard.AnnounceAccept = 1        # (Phase 4 — not yet implemented)
NemesisSystem.BountyBoard.AnnounceCompletion = 1

# Reputation (separate system, but interacts here)
NemesisRep.Enable = 1
NemesisRep.BountyCompletionBonus = 0
NemesisRep.BountyCompletionPerRank = 15
NemesisRep.BasePerKill = 0
NemesisRep.PerRankBonus = 1
NemesisRep.Threshold.Rank2 = 1000
NemesisRep.Threshold.Rank3 = 5000
NemesisRep.Threshold.Rank4 = 16000
NemesisRep.Threshold.Rank5 = 40000
```

## Progression math (current tuning)

Bounty rep formula: `15 × bountyRank` per completion. 3 completions per zone per 2h window.

| Rep Rank | Pts | R3-bounties | @ 1 zone/win | @ 3 zones/win |
|---|---|---|---|---|
| R2 Охотник | 1000 | 22 | ~16h | ~6h |
| R3 Следопыт | 5000 | 111 | ~74h | ~26h |
| R4 Ветеран Охоты | 16000 | 356 | ~10d | ~80h |
| R5 Легенда Охоты | 40000 | 889 | ~25d | ~8d |

## Files touched

- `src/NemesisSystem.cpp` — all C++ logic (single module file)
- `conf/mod_nemesis_system.conf.dist` — new config options
- `data/sql/db-characters/updates/2026_04_17_00_nemesis_bounty_board.sql` — initial tables
- `data/sql/db-characters/updates/2026_04_18_01_bounty_zone_cap.sql` — zone_id migration
- `data/sql/db-world/base/nemesis_bounty_vendor.sql` — token item 100017, ExtendedCost entries, vendor 190000, mail sender creature 190002
- `ClientAddon/NemesisTracker/Core.lua` — chat-event bounty tracking, SavedVariables persistence
- `ClientAddon/NemesisTracker/WorldMap.lua` — pin/portrait/list highlighting, tooltip filter

## Remaining (Phase 4)

- Red server-wide announces on accept / completion via `BroadcastNemesisMessage` with `|cffff0000…|r` prefix. Config flags already reserved.

## Known client-side caveats

- **Mail sender name must be ASCII** on Russian client (cp1251/UTF-8 mismatch in MailFrame).
- **Gossip header text** requires custom `SMSG_NPC_TEXT_UPDATE` trick; regular gossip items can't be "labels" in 3.3.5.
- **Live refresh**: gossip window is snapshot at open — close + reopen to see new nemeses. Addon map pins do auto-update via addon messages.
