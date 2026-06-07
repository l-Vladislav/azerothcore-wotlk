# Nemesis System — Deployment Status

Last updated: 2026-06-07. Branch `feat/wow-ak-1-nemesis-familiars`.

## PTR-only (NOT yet on live)

### Ambient nemesis generation (2026-06-07)
- `NemesisAmbientWorldScript` (WorldScript::OnUpdate, случайный тик
  300-600с, ре-ролл после каждого прохода): зоны с реальными игроками ниже
  50% от `MaxPerZone` получают 1 рождение немезиды за тик — случайный
  подходящий моб из ЛЮБОГО загруженного грида зоны (гриды держат и боты,
  так что пул — вся обжитая зона), `nemesis_target_guid=0`.
- Анонс рождения с текстом по типу существа (2 варианта/тип), только в зоне.
- `RankUpChance` 10%: вместо рождения — ранк-ап случайной живой немезиды
  зоны (+1 ранг, ре-ролл аффиксов, фулл-хил; уважает RankUpCooldown,
  rare пропускаются; фолбэк на рождение).
- GM `.nemesis ambient` — форс-проход (печатает births / rank-ups).
- Конфиг `NemesisSystem.AmbientGeneration.*`. Детали в nemesis_system.md.
- Задел: переиспользовать промоут для генерации немезид в подземельях
  (хук входа) и «особых поручений» за «Монету авантюриста».

### Rank-gated tavern shop (2026-06-07)
- `NemesisBountyVendorScript`: «Награды охотника за головами» теперь открывает
  ПОДМЕНЮ вместо плоского вендора 190000: «Общие товары» (ранг 1),
  «Печати и нашивки» (StatBooster, ранг 2), «Сумки с фамильярами» (ранг 3).
  Залоченные пункты видны с пометкой «(требуется ранг: …)».
- Новые conf-опции: `BountyVendor.RankMenus.Enable` (1), `.GeneralEntry`
  (190100), `.StatBoosterEntry` (190101), `.FamiliarEntry` (190102),
  `.StatBoosterRank` (2), `.FamiliarRank` (3). Гейт — по
  `NemesisReputation::GetRank` (Hunter's Covenant 1-5).
- SQL `pending_db_world/nemesis_familiars_gacha_vendor.sql`: IEC 100006
  (1×110150) / 100007 (5×110150) + npc_vendor 190100/190101/190102.
  Легаси-вендор 190000 не тронут (фолбэк при RankMenus=0).
- Клиенту нужны IEC 100006/07 в ItemExtendedCost.dbc
  (`.claude/dbc/ItemExtendedCost_custom.csv`) для отрисовки цен.
- Деплой на live: см. familiar gacha доки в `.claude/familiars/` — сумки
  110100-09/110120, монета 110150, клетки 110000-99 идут одним пакетом.

## Currently deployed on live + PTR

### Base system (pre-bounty-board)
- Damage multiplier decoupled from health (1.25x–2.50x vs. health 1.5x–6.0x)
- Gold level multiplier (`level / 80`)
- Mail fallback for full inventory (`AddItemOrMail`)
- Runtime GUID in addon messages
- Russian title generator (40 × 40 × 25 = 40,000 combos)
- `creature->SetName(title)` applies Russian title to nameplate; restored on clear
- Russian `[Немезида]` prefix on all announcements
- HandleAddonBootstrap sends ALL nemeses (`includeAll = true`)
- Chunk ID uses static counter, chunk size 450 bytes
- Gray-level gating for token + bonus-drop rewards
- `FindBaseNonInstanceMap` cross-map runtime-GUID resolution

### Bounty Vendor
- `NemesisBountyVendorScript` — AllCreatureScript hook on innkeepers
- Token item 100017 "Жетон немезиды" (Quest, BoP, stack 200)
- Shared vendor entry 190000
- ExtendedCost 100001–100005 (10/15/20/25/50 tokens — 100005 reserved)
- Prices: T1 10, T2 15, T3 20 + Reroll, T4 25

### Bounty Board (NEM-001 Phases 1–3)
- Zone-filtered pool, regenerated live on each open (no persistent cache)
- 3 slots per zone per 2h window (seeded shuffle for determinism within window)
- Rank-primary sort, max-level tier preference within rank
- Rare-mob dedup + pool-rotation position tracking (entry-based matching)
- Blizzlike gossip UI: details as header text via `SMSG_NPC_TEXT_UPDATE`, only action buttons in the gossip menu
- 5 RP variants for "cleared zone" empty state, plus flat "no contracts" for truly empty zones
- Accept → RP-flavored confirmation chat line
- Kill completion → history row + RP mail (20 flavor combos) with tokens + gold from "Innkeeper" (creature 190002)
- Admin-clear refund: any `DeleteNemesisState` (single, map, clearall, merge-rares) refunds active bounty holders with 1 consolation token + apology mail
- `.nemesis clearall` now explicitly refunds + broadcasts remove per-nemesis + invalidates all pools
- `.nemesis merge-rares` admin command for backfill

### Reputation (`character_nemesis_reputation`)
- 5 tiers with Russian titles: Послушник → Охотник → Следопыт → Ветеран Охоты → Легенда Охоты
- Thresholds (tuned 2×): 1000 / 5000 / 16000 / 40000
- Bounty completion: `0 + 15 × bountyRank` points (tuned down from 200 + 50×r)
- Regular kill (gray-gated): `0 + 1 × creatureRank` (tuned down from 50 + 10×r)
- Titles granted cumulatively, announced in chat on rank-up

### Addon (ClientAddon/NemesisTracker)
- Chat-event bounty tracking: parses private `[Немезида] Контракт принят/выполнен/отменён` lines
- SavedVariables persistence (`NT.db.activeBountyTitle`) survives /reload + login
- World map pin for active bounty: gold glow ring (ADD blend — no black halo) + 16×16 `!` badge centered on skull's top-right
- Portrait icon: gold glow + `!` badge flush with right side of skull
- Side panel: gold `!` prefix + gold-tinted name + muted-gold background row
- Tooltip "Награда: охота за головой" renders **only** for active bounty target
- All chat, map, and UI text in Russian

## Schema migrations (applied)

- `2026_03_22_00_nemesis_last_seen.sql` — existing nemesis table additions
- `2026_04_17_00_nemesis_bounty_board.sql` — bounty + history tables
- `2026_04_18_00_nemesis_reputation.sql` — reputation table
- `2026_04_18_01_bounty_zone_cap.sql` — `zone_id` on bounty + history for per-zone cap

## Config (live + PTR)

See `nemesis_system.md` or `ticket_bounty_board.md` for full list. Notable tuned values:
- `RankUpCooldownSeconds = 900` (3× default)
- `SameVictimCooldownSeconds = 2700` (3× default)
- `NemesisSystem.BountyBoard.PoolRefreshHours = 2`
- `NemesisSystem.BountyBoard.LevelRangeDown/Up = 0` (unlimited)
- `NemesisRep.BountyCompletionPerRank = 15`
- `NemesisRep.Threshold.Rank2/3/4/5 = 1000/5000/16000/40000`

## Pending

- **Phase 4 (server-wide red announces)**: when a player accepts / completes a bounty, broadcast `|cffff0000[Немезида]: {player} принял(а)/выполнил(а) контракт на {title}!|r` server-wide. Config flags `AnnounceAccept` / `AnnounceCompletion` already reserved but don't fire yet.

## Known limitations

1. **Mail sender name must be ASCII** on Russian 3.3.5a client (cp1251/UTF-8 mismatch in MailFrame's creature-query rendering path). Mail sender stays "Innkeeper" in English; body/subject are Russian and render correctly.
2. **Gossip live refresh** — WoW 3.3.5a has no push mechanism for open gossip menus. Close and reopen the innkeeper to see new nemeses. Addon map pins and portrait icons DO auto-update.
3. **Russian zone names in bounty details** require a Russian client-side `AreaTable.dbc` locale file (`data/dbc/ruRU/AreaTable.dbc`). Without it, zone names fall back to English. Code is locale-aware via `GetSessionDbcLocale()`.
