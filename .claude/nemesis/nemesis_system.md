# Nemesis System - Customizations & Addon

## Overview
The Nemesis System (`modules/mod-nemesis-system/`) promotes creatures to "nemesis" status when they kill players. Nemeses gain ranks, affixes, scaled stats, and unique generated Russian titles. A companion WoW addon provides world map integration, portrait icons, and tooltips. All UI is in Russian.

## Server-Side Changes (NemesisSystem.cpp)

### Damage Multiplier (decoupled from health)
Health and damage scale independently. Health scales aggressively, damage more gently:

| Rank | Health | Damage |
|------|--------|--------|
| 1    | 1.50x  | 1.25x  |
| 2    | 2.00x  | 1.50x  |
| 3    | 3.00x  | 1.75x  |
| 4    | 4.50x  | 2.00x  |
| 5+   | 6.00x  | 2.50x  |

### Token Reward - Gray Level Gating
Token (item 100017) is awarded on every nemesis kill where the creature is **not gray** to the player.
Uses WoW's standard gray-level formula (`Acore::XP::GetGrayLevel` from `Formulas.h`):
- **Green or higher** → guaranteed token(s): `baseCount + perRankBonus * (rank - 1)`, bonus drop rolls normally
- **Gray (trivial)** → no tokens AND no bonus drops, even at max rank

This replaces the old overlevel-scaling system that used `GetRewardMultiplier` to scale item count
by level difference (which made tokens probabilistic and often zero even for green mobs).

The `rewardMultiplier > 0.0f` guard was removed from `OnPlayerCreatureKill` so that `GrantReward`
is always called — the gray check is now inside `GrantReward` itself.

### Gold Reward - Level Multiplier
Gold still scales by creature level: `level / 80` (capped 0.05-1.0) AND by the overlevel multiplier.
Balanced around **1g per rank at level 60** for revenge kills.
- `GetLevelMultiplier(creatureLevel)` in GrantReward
- `GetRewardMultiplier` still applies to gold (reduces gold for overleveled kills)

### Mail Fallback for Full Inventory
`AddItemOrMail()` helper: tries `player->AddItem()` first, sends via in-game mail if bags full.
- Requires `#include "Mail.h"`
- Mail subject: "[Немезида] Reward"

### Runtime GUID in Addon Messages
`NemesisAddonView::runtimeGuid` sends the creature's exact runtime GUID (`0x` + 16 hex) to the client.
- Set from `liveCreature->GetGUID().GetRawValue()` in `BuildAddonView`
- Empty string if creature is dead/unloaded
- Client compares against `UnitGUID("target")` for exact matching

### Russian Nemesis Title Generator
`GenerateNemesisTitle(spawnId, creatureEntry)` creates unique Russian names deterministically:
- 40 prefixes x 40 suffixes x 25 titles = **40,000 combinations**
- Hash: `spawnId XOR (creatureEntry * 2654435761)` for distribution
- Prefixes: Кровo, Тене, Мрако, Смерто, Гнило, Косто, Пламе, Ледо, Ядо, Громо, etc.
- Suffixes: зуб, коготь, шкур, клык, рог, глаз, пасть, жор, пук, шлёп, etc.
- Titles: Ненасытный, Безжалостный, Свирепый, Вонючий, Пухлый, Буйный, etc.
- Examples: "Кровозуб Ненасытный", "Гнилопасть Свирепый", "Смрадопук Вонючий"
- `NemesisAddonView::nemesisTitle` — sent as last field in addon payload
- No DB column needed — generated on-the-fly from deterministic hash

### Creature Rename (SetName)
- `ApplyNemesisState()` calls `creature->SetName(title)` with the generated Russian title
- `ResetCreatureToBaseState()` restores original name from `creature_template`
- The renamed creature shows the Russian title on client nameplates
- Note: WoW 3.3.5 caches creature names by entry ID — name shows correctly for players who encounter the nemesis after it's promoted. Players who cached the entry before promotion may need to relog.

### Server Announcements — Russian
All `[Nemesis]` prefixes were first changed to `[Немезида]`, then the prefix
was REMOVED entirely from chat announcements and system replies (owner request
2026-06-07) — messages now start with the content («Кровозуб достиг ранга 3!»).
The only place keeping the tag is the full-inventory fallback mail subject
(«[Немезида] Reward»).

### Addon Payload Format (25 fields after V2: prefix)
```
V2:OPCODE:spawnId:creatureEntry:name:mapId:zoneId:zoneName:x:y:z:mapX:mapY:
level:rank:rankTier:affixMask:affixText:targetGuid:targetName:relation:
rewardClass:threatClass:lastSeenAt:runtimeGuid:nemesisTitle
```

Client parsing in `UpsertNemesisFromFields(fields, startIndex, source)`:
- startIndex+0 = spawnId ... startIndex+21 = lastSeenAt
- startIndex+22 = runtimeGuid
- startIndex+23 = nemesisTitle

### Ambient Nemesis Generation (2026-06-07, PTR)
Nemeses no longer require a player death to be born. A `WorldScript` tick
(`NemesisAmbientWorldScript` → `RunAmbientGenerationTick()`):
- collects open-world zones holding at least one REAL player (playerbots
  excluded via `IsPlayerbotVictim`; config `RequireRealPlayers`);
- if the zone has fewer nemeses than `FillPercent` (50%) of
  `NemesisSystem.MaxPerZone` — promotes ONE random eligible mob per tick
  (reservoir sampling over the map's spawned creatures);
- with `RankUpChance` (10%) the zone's action instead RANKS UP a random
  existing live nemesis of the zone (`AmbientRankUpNemesis`: +1 rank,
  re-roll affixes, full heal; honors RankUpCooldownSeconds; skips rares;
  falls back to a birth when no candidate) — announcement
  «…набирает силу и достигает ранга N!»;
- eligibility (`IsEligibleAmbientCandidate`): alive, persistent spawn,
  hostile to players, not pet/critter/totem/trigger/civilian/npcflag,
  allowed rank but NOT rare (rare dedup is keyed to player targets), not a
  boss, level within Min/MaxCreatureLevel, not already a nemesis;
- promotion (`PromoteAmbientNemesis`): same path as kill-driven promotion
  (state → affixes → save → scaling → Russian title) with
  `nemesis_target_guid = 0` (ambient-born marker);
- birth announcement with creature-type flavor (`AmbientBirthFlavor`,
  2 variants per type: beast/dragonkin/demon/elemental/giant/undead/
  humanoid/mechanical + fallback), zone-local by default;
- GM command `.nemesis ambient` forces one pass (reports birth count);
- config block `NemesisSystem.AmbientGeneration.*` (Enable,
  IntervalMinSeconds 300 / IntervalMaxSeconds 600 — пауза между проходами
  ре-роллится случайно в этом диапазоне, FillPercent 50, RankUpChance 10,
  RequireRealPlayers, Announce, AnnounceZoneOnly).
- The promote path is map-agnostic on purpose — planned reuse: dungeon
  nemesis generation on player enter, then gossip "особые поручения"
  daily quests rewarding «Монета авантюриста» (speed-kill, other-continent,
  dungeon nemesis, revenge, rank hunt — см. обсуждение 2026-06-07).

### Dungeon Nemeses (2026-06-07, PTR)
Creatures spawning in dungeon maps (`OnCreatureAddWorld` → `TryRollDungeonNemesis`)
roll `DungeonNemesis.Chance` (3%) to become a **TEMPORARY** nemesis:
- weighted random rank 50/30/15/4/1 (clipped to MaxRank); trash + elites only
  (bosses/rares excluded), hostile-to-players, npcflag 0;
- temp-keyed by **ObjectGuid** in `ActiveTemporaryNemeses` — NEVER persisted
  (spawnIds collide across instances of the same dungeon); dies with the
  instance/creature;
- core temp-machinery hardened for spawnId-carrying temps: `TryGetNemesisState`
  / `DeleteNemesisState` / regen accumulators / `OnCreatureRemoveWorld` now
  check the temp store FIRST; `BroadcastRankFiveNemesisIfPersistent` skips temps;
- addon: `UPSERT_VALIDATED` pushed to everyone in the instance at creation;
  late joiners get the map's temps via `NemesisDungeonMapScript`
  (`OnPlayerEnterAll`); kill rewards/rep flow through the regular kill hook
  because state resolution now sees temps;
- announcement (owner 2026-06-07): single atmospheric message «Вы чувствуете
  присутствие сильного врага в этом месте.» — no names/ranks, MAP-LOCAL and
  DEBOUNCED per instance (`PresenceCooldownSeconds`, 120s) so trickle spawns
  deeper in the dungeon don't re-spam it;
- kill announcements for dungeon nemeses are SILENT — neither global nor
  map feed (the titled corpse is announcement enough);
- **HP self-heal** (`OnAllCreatureUpdate`): a freshly entered instance's
  creatures hit JUST_RESPAWNED→SelectLevel→InitStatsForLevel on their first
  Update, which resets `UNIT_MOD_HEALTH` BASE_VALUE and wipes our scaled max
  health (scale survives — "model big, HP normal"). When a nemesis's live
  max drifts BELOW target, re-apply the state preserving current health %
  (no combat heal-loop; fires once per drift). Open-world nemeses never
  respawn post-promotion so this is dungeon-specific in practice;
- addon zone tab: the server pushes `V2:DUNGEON:<mapId>` on map enter
  (0 = open world); `isNemesisInCurrentZone` (WorldMap.lua) matches dungeon
  entries by `nemesis.mapId == currentDungeonMapId` (instances have no
  world-map file and zone-name matching is unreliable across subzones);
- config `NemesisSystem.DungeonNemesis.*` (Enable, Chance 3.0, IncludeRaids 0,
  RequireRealPlayers 1).

### Special Daily Tasks — «Особое поручение» (2026-06-07, PTR)
Innkeeper gossip item (after the bounty board). **One completion per day**,
the day's task choice is FINAL (abandon allowed; re-accept the same type only —
fresh timer for speed). Reward: 1× «Монета авантюриста» (110150) — **always by
MAIL** (owner request) from the virtual Innkeeper 190002 with randomized RP
flavor: 4 subjects × 3 bodies per task type (`SendTaskRewardMail`).
State: `character_nemesis_special_task` (characters DB),
day window aligned to the server daily-quest reset. Types
(`NemesisSpecialTask` namespace; completion checked per reward recipient →
group credit works):
1. **SPEED** — kill any nemesis within `SpeedKillMinutes` (30) of accepting;
   timer expiry on a late kill auto-abandons with a retry hint.
2. **CONTINENT** — kill a non-gray nemesis on the opposite classic continent
   (EK↔Kalimdor; accept only while on map 0/1; param = target mapId).
3. **DUNGEON** — kill a (temporary) nemesis inside a dungeon, solo or group.
Config `NemesisSpecialTask.*` (Enable, SpeedKillMinutes, RewardItem/Count).
Gossip actions 9010–9014; UI header via `SendCustomNpcText` (0x7E… ids).

## Client Addon (ClientAddon/NemesisTracker/)

### Files
- `NemesisTracker.toc` — addon manifest
- `Core.lua` — data management, server communication, event handling
- `UI.lua` — standalone tracker window
- `MapData.lua` — zone ID to map file mappings
- `WorldMap.lua` — world map integration, minimap button, portrait icons, tooltips

### WorldMap.lua Features

#### World Map Integration
- Skull pins on the world map for nemeses in the viewed zone
- Fixed 16x16 size, selected pin gets 2x (32x32) + yellow glow
- `WorldMapTooltip` used for fullscreen map compatibility
- Pin hit area expanded +8px for easier hovering, `FULLSCREEN` strata level 20

#### Side Panel (Nemesis List)
- Scrollable list of all nemeses grouped by zone
- Player's current zone listed first (cached via `updatePlayerZoneCache()`)
- "This Zone" / "All Zones" toggle (defaults to "This Zone")
- Coordinates shown as `(X.X, Y.Y)` percentage format
- Click navigates map to that nemesis's zone via `SetMapZoom()`
- Selected row highlighted with blue background
- Shows nemesisTitle instead of creature name (falls back to name if no title)

#### Icon Buttons (top-right of world map)
- Skull icon: toggle map pins on/off
- Scroll icon: toggle list panel on/off
- Both use desaturated/alpha states when off

#### Minimap Button
- Skull icon on minimap edge, draggable
- Left-click: toggle world map (no tracker window)
- Right-click: force sync
- Position saved in `NT.db.minimapButtonAngle`

#### Portrait Icon
- Skull on target frame portrait (top center, -6 offset) when targeting a nemesis
- Colored by rank (blue->yellow->orange->red), glow colored to match
- No rank text — color alone indicates rank
- Also on focus frame

#### Creature Matching (findNemesisByUnit)
Two-pass matching:
1. **Primary:** exact `runtimeGuid` match (from server addon messages)
2. **Secondary:** match `UnitName("target")` against `nemesis.nemesisTitle` (works because creatures are renamed server-side to unique Russian titles)

Zero false positives — each nemesis has a unique name.

#### Unit Tooltip
- `[Немезида]` title + rank info appended to creature tooltip on hover
- Same two-pass matching as portrait icon

### Locale Handling (Russian Client)
- Zone matching uses `GetMapInfo()` (returns locale-independent file names like "Silverpine")
- `MapData.lua` maps nemesis zoneId -> file name
- Creature matching by nemesisTitle (Russian name set on creature server-side)
- All UI text in Russian: `[Немезида]`, `Немезиды` panel title

### Key Client Functions
- `isNemesisInCurrentZone(nemesis)` — compares map file names via `getCurrentMapFile()`
- `isNemesisInPlayerZone(nemesis, playerFile)` — uses cached player zone
- `findNemesisByUnit(unit)` — runtimeGuid match, then nemesisTitle match
- `navigateToNemesisZone(nemesis)` — SetMapZoom to nemesis zone
- `getCreatureEntryFromGuid(guid)` — extracts entry from 3.3.5 GUID format
- `updatePlayerZoneCache()` — caches player zone file; called on map open, zone change, entering world. Avoids infinite loop with SetMapToCurrentZone.

### Client Data Flow
1. Server pushes UPSERT_VALIDATED/BOOTSTRAP_ENTRY/REMOVE via addon messages
2. Core.lua parses and stores in `NT.data.nemeses[spawnId]`
3. Core.lua calls `WorldMap:RefreshWorldMap()` on upsert/remove for live updates
4. `ShouldHideNemesis` always returns false (never hide active nemeses)
5. Staleness alpha: fresh=1.0, fading=0.7, stale=0.5 (visual only, never hidden)

## Config (mod_nemesis_system.conf)

### Key Non-Default Values
- `MaxRank = 6`
- `PromotionLevelDiffMax = 9`
- `AddonBootstrapMaxEntries = 1000`
- `RevengeRewardGold = 13333` (balanced for 1g/rank at lvl 60)
- `RevengeRewardGoldPerRankBonus = 13333`
- `BountyRewardGold = 3333`
- `BountyRewardGoldPerRankBonus = 3333`
- `RevengeRewardItem = 100017` (Nemesis Bounty Token)
- `RevengeRewardItemPerRankBonus = 1`
- `BountyRewardItem = 100017` (Nemesis Bounty Token)
- `BountyRewardItemPerRankBonus = 1`
- `BonusDrop.Item = 41605` (Dalaran Cooking Award)
- `BonusDrop.ChancePerRank = 20.0`
- `VisualAuraSpell = 0` (disabled)

### Config synced to PTR
`env/dist/etc-ptr/modules/mod_nemesis_system.conf` is a copy of the main config.
