# Nemesis System — Deployment Status

Last updated: 2026-06-16. Branch `feat/wow-ak-1-nemesis-familiars`.

## На LIVE: сервер собран+поднят 2026-06-16 — ждёт только редеплой аддона

### Ранговые пороги: единый источник + экран ранга + back-button (2026-06-16)
СЕРВЕР: инкрементальная пересборка (ccache) + поднят на live (ac-worldserver-v2,
rev 85f0c9a0+). КЛИЕНТ: аддон NemesisTracker ещё НЕ скопирован игроку — бар
покажет 558/1000 только после копирования ClientAddon в Interface/AddOns +
`/reload` (старый аддон безопасно игнорирует новые поля payload).

- Баг: аддон показывал «558/500». ЗАХАРДКОЖЕННЫЙ устаревший
  `RANK_THRESHOLDS = {0,500,2500,8000,20000}`, а live-conf давно
  1000/5000/16000/40000. Сервер считал ранг верно (558/1000), врал только бар.
- Выровнены ВСЕ копии порогов на 1000/5000/16000/40000: live conf (была),
  C++ `DefaultThresholds` (NemesisSystem.cpp), `.dist`-шаблон.
- Аддон сделан server-authoritative: сервер шлёт `repTierFloor`/`repTierNext`
  в каждом payload (поля 28/29 после expiresAt в BuildAddonEntryPayload), аддон
  удалил `RANK_THRESHOLDS` и рисует бар по серверным границам — дрейфа больше
  быть не может. НЕ возвращать хардкод-таблицу в аддон.
- Госсип трактирщика: строка «Ранг: «<имя>» - <очки>/<next>» + экран
  `RANK_INFO_ACTION` (ShowRankInfo) с прогрессом до след. ранга.
- Fix back-button: активный вид доски (ShowBoard, ветка hasActive) не имел
  кнопки «Назад» — поток после принятия контракта/активной награды был тупиком
  (только строка [АКТИВНО]). Добавлена «Назад» → SHOP_BACK_ACTION, как в
  no-active ветке.

## PTR-only (NOT yet on live)

- **Образ PTR ОТСТАЁТ от live**: live собран с финальной логикой именованных
  целей (модуль b10b129), PTR — со старым образом до неё. Догнать:
  `scripts/ptr-build.ps1` (НЕ собирать при поднятом live-мире — WSL2 OOM).
- PTR-conf тумблеры `NemesisSpecialTask.FreeChoice=1` / `NoDailyLimit=1`
  оставлены для тестов (прод = 0).

## Currently deployed on live + PTR

### Охотничий контур v2 (задеплоен на live 2026-06-12)
Полный дизайн: [nemesis_hunting_loop.md](nemesis_hunting_loop.md). Деплой-пакет
с манифестом/откатом: `.claude/agent-memory/live-deployer/packages/`
`2026-06-12_1900-nemesis-hunting-loop/`; бэкапы live —
`backups/live/2026-06-12_175354_pre-hunting-loop-deploy/`. Состав сверх
описанного ниже: поручение дня НАЗНАЧАЕТСЯ (ролл guid⊕день, без выбора);
награды поручений всегда 1 монета почтой + репутация 100+ранг; **именованная
цель** для мировых поручений — выбор/тихое рождение в пределах ±3 уровней
игрока (`TargetLevelBand`), фолбэк на ближайшего по уровню (принятие не
отказывает), **зачёт ТОЛЬКО по именованной цели**, промахи тихие; пуш цели
принявшему в аддон прямо при принятии; зачистка данжа с порогом 3/4/5 (по
рангу охотника) и прогрессом; элитная подкормка эмбиента (25%); скейлинг
стартового ранга немезид от ранга охотника (+0/+1/+2); магазин 4 ранговых
меню (T1→T4, вендоры 190100-03, ранг 5 пуст); RP-тотал — слово «немезида»
убрано из всех строк; данж-анонсы: одно сообщение присутствия с дебаунсом,
убийства тихие; HP-самохил данж-немезид; ruRU AreaTable/Map.dbc на серверном
томе; аддон: панель поручения, V2:DUNGEON mapId-матч, триггеры бутстрапа.

### Dungeon nemeses + особые поручения (2026-06-07)
- Данж-немезиды: 3% на спавн трэша/элиток (без боссов), временные
  (ObjectGuid-keyed, не в БД), взвешенный ранг 50/30/15/4/1. Анонс — ОДНО
  атмосферное сообщение в карту («Вы чувствуете присутствие сильного
  врага в этом месте», без имён/рангов), дебаунс 120с на инстанс. Убийства
  данж-немезид — БЕЗ анонса вовсе. **HP-самохил** в OnAllCreatureUpdate:
  свежий инстанс на первом апдейте делает respawn-init и сбрасывает наш
  scaled max HP (scale остаётся → «модель большая, HP обычный»); при
  дрейфе max вниз — переприменяем state, сохраняя % здоровья. Аддон-пуш
  при создании/входе/бутстрапе; вкладка «Немезиды в этой зоне» матчит
  данжи по mapId (сервер шлёт V2:DUNGEON:<mapId> на входе).
  Temp-механика укреплена: guid-first lookup/delete/regen для существ со
  spawnId. Конфиг `NemesisSystem.DungeonNemesis.*`.
- «Особое поручение» у трактирщика: 1 выполнение/день, выбор финален
  (бросить можно, перевзять только тот же тип). Типы: на скорость (30 мин),
  противоположный классический континент (EK<->Калимдор, не серая),
  немезида в подземелье (соло/группа — кредит всем получателям награды).
  Награда 1×110150 — ВСЕГДА почтой от трактирщика 190002 с RP-вариациями
  (4 темы × 3 тела на тип поручения). Таблица `character_nemesis_special_task`
  (pending_db_characters/nemesis_special_task.sql, применена на PTR).
  Конфиг `NemesisSpecialTask.*`. Госсип-экшены 9010-9014.

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
  ПОДМЕНЮ вместо плоского вендора 190000. Имена по рангу разблокировки
  (тест-батч): «Награды послушника» (ранг 1), «Награды охотника»
  (StatBooster, ранг 2), «Награды следопыта» (сумки фамильяров, ранг 3).
  Залоченные пункты видны с пометкой «(недоступно)».
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

## Fixed (2026-07-05): map pins missing in Wetlands/Darkshore — two passes

- **Symptom**: nemesis icons didn't render on the world map (or the
  BountyBoard "Немезиды в этой зоне" tab) while standing in Wetlands or
  Darkshore; all other zones worked.
- **Root cause**: `WorldMap.lua`'s `isNemesisInCurrentZone` matched zones by
  comparing `GetMapInfo()`'s internal map-folder name (lowercased) against
  a hand-maintained `MapData.lua` `byZoneId` table of Blizzard folder names.
  That table already had correct entries for zoneId 11 (`Wetlands`) and 148
  (`Darkshore`) with no key collisions, so the most likely remaining
  explanation is a Blizzard internal-map-folder-name quirk we haven't
  pinned down precisely — the same *class* of bug already found once before
  for Azshara (folder is actually `Aszhara`, s/z swapped; see commit
  `a2280ef`).
- **First attempted fix (SHIPPED A REGRESSION, reverted)**: made
  `isNemesisInCurrentZone` / `isNemesisInPlayerZone` match primarily on
  `GetCurrentMapAreaID()` vs `nemesis.zoneId`, on the assumption both are
  AreaTable IDs. **That assumption was wrong** — `GetCurrentMapAreaID()`
  returns a `WorldMapArea.dbc` row ID, a different numbering space than
  AreaTable's zone ID. This wasn't caught before shipping (no live 3.3.5a
  client available in-session to verify the API), and it broke the addon
  more broadly per user report. See
  `.claude/agent-memory/nemesis-dev/worldmap-zone-matching.md` for the full
  writeup — **do not reintroduce `GetCurrentMapAreaID()` for zone matching.**
- **Actual fix (current)**: `isNemesisInCurrentZone` (used for world-map pin
  rendering) was reverted to the original file-name-only logic, unchanged
  from before this bug was ever touched. A NEW, separate function/semantic,
  `isNemesisInPlayerZone` / public `WM.IsNemesisInPlayerZone` (used by the
  side-panel "This Zone" filter and by BountyBoard's zone tab, which was
  previously wired to the wrong function), now additionally matches via
  `GetRealZoneText()` (a basic, verified-safe, Vanilla-era API that always
  reflects the player's own physical zone) compared against the server's
  `nemesis.zoneName`, ё/Ё-normalized. This check can only ADD matches — a
  miss always falls through to the original file-name check, so it cannot
  regress anything. `isNemesisInCurrentZone` deliberately does NOT get this
  treatment, since it means "zone the map is scrolled to" (can legitimately
  differ from the player's own zone) rather than "zone I'm standing in".
  **Net effect**: the BountyBoard journal's "Немезиды в этой зоне" tab and
  the world-map side panel's "This Zone" filter are now fixed for
  Wetlands/Darkshore. The raw world-map PIN rendering for those two zones
  specifically may still be affected if the underlying Blizzard
  folder-name quirk is real — needs a live-client check to confirm/fix
  `byZoneId`, not attempted this session.
- Also fixed independently: server-side `GetZoneName()` in
  `NemesisSystem.cpp` had a `zoneNameOverrides` map added for known DBC
  typos — the deployed ruRU `AreaTable.dbc` string for zone 148 is "Темные
  берега" (missing ё); overridden to "Тёмные берега". This is primarily a
  **display text** fix, but the addon's new `GetRealZoneText()` string
  match (above) normalizes ё/Ё → е/Е on both sides specifically so this
  override (server sends "Тёмные", client's own unpatched DBC via
  `GetRealZoneText()` still says "Темные") can't cause a false-negative
  zone mismatch. Add further zoneId entries there if more DBC typos
  surface — don't hack around them in addon Lua.
- Added the missing `["Darkshore"]` entry to `MapData.lua`'s `byZoneName`
  for symmetry (Wetlands had one, Darkshore didn't) — this table is legacy
  and only matters if the server ever sends an English zone name (chunked
  payload edge case); it is **not** the mechanism that fixed the bug.
- Files: `modules/mod-nemesis-system/ClientAddon/NemesisTracker/WorldMap.lua`,
  `modules/mod-nemesis-system/ClientAddon/NemesisTracker/MapData.lua`,
  `modules/mod-nemesis-system/ClientAddon/NemesisTracker/BountyBoard.lua`,
  `modules/mod-nemesis-system/src/NemesisSystem.cpp`.
- **Verify in-game**: requires both a worldserver rebuild+restart (C++
  change) AND the player re-copying the WHOLE `ClientAddon/NemesisTracker`
  folder into `Interface/AddOns` + `/reload` (Lua changes are not
  hot-reloadable — this is also why the first, broken pass needed a
  redistribution to reach the user, and why the fix does too). No DB
  migration needed — this is not a DBC/SQL fix.
- **Expected user-visible change after this fix**: the addon should no
  longer be broadly "broken" (whatever the exact symptom of the bad
  `GetCurrentMapAreaID()` pass was — false/missing pins in unrelated
  zones, most likely). Additionally, opening the Journal (minimap button,
  left-click) while standing in Wetlands or Darkshore should now correctly
  list nemeses under the "Немезиды в этой зоне" tab, and the world map's
  side-panel "This Zone" filter should include them too. The world-map PIN
  icons specifically (the dots drawn directly on the zoomed zone map) may
  still be missing for those two zones — that part of the original report
  is not conclusively fixed (see above).
- Unverified side note for whoever owns the DBC pipeline: `.claude/dbc/AreaTable.csv`'s
  header is **misaligned** — the real ruRU zone-name string lands under the
  column labeled `AreaName_zhTW`, not `AreaName_ruRU` (the header has 16
  name-locale columns; the true 3.3.5a `AreaTable.dbc` LocalizedString block
  only has 9 + a mask). Same bug class as the already-documented
  `feedback_spell_csv_locale_offset` issue for `Spell_custom.csv`. Doesn't
  affect the running server (which parses the real binary DBC via the
  correct `DBCStructure.h` layout), only misleads anyone reading that CSV
  by hand.

## Fixed (2026-07-09): ~190ms main-thread block on `.nemesis addon bootstrap`

- **Symptom**: the main thread measured a stable ~190ms block on every
  `.nemesis addon bootstrap`/`.nemesis addon sync` invocation on live (1596
  bots), independent of bot count. Root cause + full writeup:
  `.claude/agent-memory/nemesis-dev/bootstrap-perf-pacing.md`.
- **Server**: `SendNemesisBootstrap` (`includeAll=true` walks every active
  nemesis world-wide by design — the world map/journal are meant to show
  everything, this was NOT changed) now only computes the work list
  synchronously; the expensive per-entry build+send is drained a bounded
  number of entries per world tick (`NemesisSystem.AddonBootstrapEntriesPerTick`,
  default 50, shared budget across all in-flight players that tick) by a new
  `ProcessPendingBootstraps()`, called every tick from the existing
  `NemesisAmbientWorldScript::OnUpdate`. Wire protocol unchanged.
- **Addon**: `RequestBootstrap()` gained a 45s cooldown guard + in-flight
  check (`force=true` bypass reserved for `PLAYER_ENTERING_WORLD` only, so
  cold start/login/reload/loading-screens are unaffected). The chat-keyword
  trigger in `CHAT_MSG_SYSTEM` — previously scheduling one independent,
  non-cancelling 2s timer per matching chat line (the actual spam
  mechanism, given how often bot-combat produces matching lines) — now
  coalesces to at most one pending call via `ScheduleChatTriggeredBootstrap()`.
  `NemesisTracker.toc` bumped 0.2.1 -> 0.2.2 (requires re-copy + `/reload`
  to reach players, same as prior Lua-only fixes).
- Files: `modules/mod-nemesis-system/src/NemesisSystem.cpp`,
  `modules/mod-nemesis-system/conf/mod_nemesis_system.conf.dist`,
  `modules/mod-nemesis-system/ClientAddon/NemesisTracker/Core.lua`,
  `modules/mod-nemesis-system/ClientAddon/NemesisTracker/NemesisTracker.toc`.
- Not yet built/deployed by this agent — worldserver rebuild, addon
  redistribution via launcher CDN, and any live restart are owned by the
  requesting/main thread per this task's constraints.

## Known limitations

1. **Mail sender name must be ASCII** on Russian 3.3.5a client (cp1251/UTF-8 mismatch in MailFrame's creature-query rendering path). Mail sender stays "Innkeeper" in English; body/subject are Russian and render correctly.
2. **Gossip live refresh** — WoW 3.3.5a has no push mechanism for open gossip menus. Close and reopen the innkeeper to see new nemeses. Addon map pins and portrait icons DO auto-update.
3. **Russian zone names in bounty details** require a Russian client-side `AreaTable.dbc` locale file (`data/dbc/ruRU/AreaTable.dbc`). Without it, zone names fall back to English. Code is locale-aware via `GetSessionDbcLocale()`.
