# Nemesis Familiar Gacha — Status & Phases

Phase tracking and high-level project status for the **10-семейств × 10-питомцев** gacha system. Full design at [familiar_gacha_design.md](familiar_gacha_design.md), catalog at [familiar_gacha_catalog.md](familiar_gacha_catalog.md), IDs at [familiar_gacha_id_reservations.md](familiar_gacha_id_reservations.md).

## What this replaces

The previous **3 roles × 5 tiers** familiar system (`familiar_system_design.md`, `familiar_system_implementation.md`). Only T1 (3 pets) was shipped. The gacha replaces the unshipped T2-T5 plan and re-integrates the 3 T1 pets as Common starters (slot 1 of their family) in the new pool.

`familiar_system_design.md` and `familiar_system_implementation.md` are kept on disk for **rollback reference and bug-history**, not as the live design.

## Concept (current — 10×10)

- 100 collectible familiars organised as **10 elemental families × 10 pets** (6 Common + 3 Rare + 1 Epic per family).
- Common внутри семейства — **3 базовых питомца × 2 варианта качества**: «чистый» (1 положительный эффект) и «побитый» (тот же бафф + маленький −1% дебафф, идентичная модель / DisplayID). Это даёт натуральный пул («тот же тип, но похуже») и сохраняет коллекционную ценность дубликатов.
- 3 Rare и 1 Epic в каждом семействе — уникальные питомцы без вариантов.
- Pulled exclusively from chests purchased with «Жетон таверны» (1 per daily quest from innkeeper — Фаза 7, deferred).
- Each pet is a summonable companion that applies a passive owner-aura while active. Аура **неотменяема** (`SPELL_ATTR0_NO_AURA_CANCEL`) и **бессрочна** (`DurationIndex=21` → permanent в SpellDuration.dbc), снимается только C++-хуком при де-спауне.

## Chest economy

- **Универсальный сундук** (item 110120) — 1 жетон → roll any of 100 (89% C / 10% R / 1% E)
- **10 стихийных сундуков** (110100–110109) — 3 жетона → roll 10 pets of that family (70% C / 20% R / 10% E)
- → Element chest is **100× more likely** to give you that family's specific Epic, for 3× cost
- No duplicate protection — duplicate scrolls sell to vendor for **100g** (`SellPrice = 1000000`)

## Phases

| # | Phase | Status |
|---|---|---|
| 1 | Design docs + ID reservations + memory updates | ✓ done 2026-05-18, перестроено под 10×10 (2026-05-22) |
| 2 | DisplayID / SpellIconID verification (docker required) | pending |
| 3 | SQL migration in 5 parts: spells / creatures / items / chests / t1-migrate | pending |
| 4 | C++ — extended aura map + chest `ItemScript` | pending |
| 5 | Optional: `nemesis_familiar_pool` DB-driven weight table | pending |
| 6 | MPQ rebuild — only when explicit "prepare MPQ" per memory rule | deferred |
| 7 | Tavern daily quest granting coin | deferred |

## Recent activity (newest on top)

- **2026-05-30 (поздно)** — **Семейство 1 переименовано Камень → Механический + переделан пул + реальные иконки**. Концепт семейства 1 сменён со «stone/Камень» (танк-камни) на «mech/Механический» (роботы, гномьи гизмо): `01_stone.json` → `01_mech.json` (key `mech`, name «Механический»), SQL → `nemesis_familiars_gacha_mech.sql`. Метки «Камень»→«Механический» обновлены в catalog / id_reservations / design / README / agent-memory (id-ranges, common-variants, json-workflow). Новый пул 10 петомцев (Механокурица/Ржавая Механокурица 29060, Механобелка/Треснувшая Механобелка 7937, Бронзовый/Ржавый Щитоносец 32031, Ржавый Механодракон 12489, Железнолоб 22776, Хрустальный Страж 29060, Механостраж 32670), эффекты тем же танк-набором. **Реальные SpellIconID** проставлены из клиентского `SpellIcon.dbc` (экспорт в `.claude/dbc/SpellIcon.csv`): 318 (polymorph chicken), 353 (gear_01, замена отсутствующей gear_02), 3811 (xt002), 1701 (dragon_bronze), 2552 (gizmo_06), 4375 (t_roboticon). Добавлено поле `nameAcc` (винительный падеж для «Призывает …»). Применено на PTR, worldserver перезапущен.

  **Финальные правки текста/предмета (owner-confirmed, протестировано в игре 2026-05-30):**
  - Формат эффектов — **компактный, родительный падеж**, полные названия (без «AP»/«крит»): `+5% брони, +5% выносливости, +5% уворота; -10% силы атаки, -5% шанса критического удара`. Флэт-резист без `%`.
  - **Сплит тултипов:** бафф-аура (103xxx) = только баффы, дебафф-аура (104xxx) = только дебаффы; **полный** список (баффы+дебаффы) — только в призыве (меню «Спутники») и описании предмета.
  - Предмет: имя **«Клетка с: <Name>»** (было «Свиток призыва:»), иконка **20629** (`INV_Box_PetCarrier_01`).
  - Модель 1.1/1.2 Механокурица → **7920** (Mechanical Chicken, npc 8376).
  - Генератор `familiar-gen-sql.ps1` строит весь текст из `code` через генитивную карту `StatRu`; правила в [agent-memory/familiars-dev/russian-text.md](../agent-memory/familiars-dev/russian-text.md) и [json-workflow.md](../agent-memory/familiars-dev/json-workflow.md).
  - Семейство 1 (Механический) **подтверждено рабочим в игре**. Клиентские визуалы — после пересборки MPQ из текущего `Spell_custom.csv` + очистки `WDB/` (владелец собирает сам).
- **2026-05-30** — **JSON migration + generator + Stone family on PTR**. Источник правды для семейства переведён с `.md`-таблиц на структурированный `.claude/familiars/0X_<key>.json` (формульные ID, status draft/confirmed, icon{spellIconId,name,sourceSpell}, effects.positive/negative). Семейство **1 (Камень)** полностью ревизовано владельцем (новые модели/scale/иконки/имена; 1.7→Ржавый Механодракон, 1.10→Механостраж) и записано в `01_stone.json`; `01_stone.md` удалён, ссылки в каталоге/README переведены на JSON. Новый генератор `scripts/familiar-gen-sql.ps1` (`-Csv` для клиентских DBC-строк) — JSON→SQL+CSV, кодировки сверены с 5pets. Stone SQL (`nemesis_familiars_gacha_stone.sql`, 10 summon/10 buff/4 debuff/10 creature+model/10 scroll) применён на `acore_world_ptr`, worldserver перезапущен, проверено: поля аур, attrs, HEX-кириллица, displayId. **Pending: ручная MPQ-сборка** (Spell_custom.csv→Spell.dbc→patch-ruRU-X.MPQ) для клиентских визуалов; иконки 1.3–1.10 пока placeholder 1582 (имена записаны, реальные SpellIconID — на этапе MPQ/SpellIcon.dbc). Память: [agent-memory/familiars-dev/json-workflow.md](../agent-memory/familiars-dev/json-workflow.md).
- **2026-05-29 (вечер)** — **Login orphan-aura cleanup + AURA_IS_DEBUFF**. Два бага из тестового прогона на PTR:
  - Дебафф рендерился на бафф-баре. Причина: серверный `SpellInfo::_IsPositiveEffect()` распознаёт негативность по знаку basepoints только для фиксированного списка аур (`MOD_STAT` 29, `MOD_DAMAGE_PERCENT_DONE` 79, `MOD_DODGE_PERCENT` 49…), но НЕ для `MOD_TOTAL_STAT_PERCENTAGE` (137) и `MOD_RESISTANCE` (22), которые мы используем. Фикс: 104xxx Attributes = `0x84000000` (`NO_AURA_CANCEL | AURA_IS_DEBUFF`). Принудительный флаг `AURA_IS_DEBUFF` (`0x04000000`) → `_IsPositiveEffect=false` → `AFLAG_NEGATIVE` в `SMSG_AURA_UPDATE` → дебафф-бар. **Серверный фикс**, MPQ не обязателен (но CSV обновлён для консистентности).
  - На relog ауры оставались, а пет не был вызван. Причина: `Player::SaveToDB()` пишет permanent + `NO_AURA_CANCEL` ауры в `character_aura` ДО despawn пета (логика логаута), поэтому in-memory removal в `OnCreatureRemoveWorld` не доходит до диска. Фикс: `NemesisSystemPlayerScript::OnPlayerLogin` стрипает все familiar-ауры (103000–103099, 104000–104099, T1 fallback 101100/01/02) на каждом логине. Если пет нужен — игрок ре-саммонит, `OnCreatureAddWorld` повесит обратно. Новый sub-doc в памяти: [agent-memory/familiars-dev/lifecycle.md](../agent-memory/familiars-dev/lifecycle.md).
- **2026-05-29 (день)** — **Aura scheme split positive/negative**. 103xxx теперь только positive эффекты (бафф-бар), 104xxx — только negative эффекты (дебафф-бар). Причина: клиент 3.3.5a классифицирует spell как positive/negative целиком, а не по эффектам, поэтому смешанная строка рендерится одной иконкой на бафф-баре. Split = честный UI: бафф сверху + дебафф снизу одновременно. Design / catalog / id_reservations / aura-template / common-variants синхронизированы. Test SQL `nemesis_familiars_gacha_test_5pets.sql`: 103003 распилен на 103003 (+2% Sta) + 104003 (-1% Spi). Skript `dbc-add-familiar-test-spells.ps1` тоже под split. C++ `GetFamiliarOwnerAuraSpells` теперь всегда возвращает 104xxx (cast-site guard через `sSpellMgr` подавляет лог для отсутствующих rows). Phase 4 C++ hook'и переименованы primary/overflow → buff/debuff.
- **2026-05-22** — Реорг 20×5 → **10×10**. Common развёрнут в 3 базовых × 2 варианта. Каталог переписан, design / id_reservations / status синхронизированы. Старые файлы `.claude/familiars/01_stone.md … 20_star.md` удалены (несовместимы с 10×10). T1 SQL обновлён на PTR: `Attributes=2147483648` (NO_AURA_CANCEL), комментарий «30 min» исправлен на «permanent». Память: `feedback_familiar_aura_uncancellable`.
- **2026-05-18** — первичный дизайн 20×5 с раскладкой пулов, ID reservations, drop-rates.

## Why

- Long collection arc gives the rank/bounty system a meaningful endgame sink.
- Many pets keep individual power gains small (no power creep) while the *set* becomes the reward.
- "Чистый + побитый" пары делают пул натуральнее: даже дубликат-вариант ощущается как отдельный сбор. Дубликаты сверх обоих вариантов уходят в золото — wasted rolls нет.
- Element chests give players agency: "I want a Fire pet" is targetable for 3× cost.

## Rules to follow when extending

- Always read both `familiar_gacha_design.md` and `familiar_gacha_catalog.md` before adding new content.
- ID ranges in `familiar_gacha_id_reservations.md` — stay inside them (new formula: ×10 на семейство).
- Never bypass the displayid-verification rule — даже с 100 петомцами, каждая выбранная модель получает `SELECT … FROM creature_template_model` confirmation.
- All `spell_dbc` aura rows MUST set `Attributes=0x80000000` (NO_AURA_CANCEL), `DurationIndex=21` (permanent), `ProcChance=101`, `EffectDieSides_N=1` — иначе аура молча no-op-ит или применяется amount=0 или снимается игроком.
- Парные варианты Common: «чистый» и «побитый» делят одну и ту же модель / `CreatureDisplayID`. Имена различаются, эффекты — почти идентичны (тот же положительный + маленький −1% дебафф).
- SQL migrations live in `data/sql/updates/pending_db_world/` (module-local paths are NOT scanned by ac-db-import and get wiped on rebuild).
- CSV (DBC) updates only when explicitly preparing an MPQ build — not on every server-DB tweak.
