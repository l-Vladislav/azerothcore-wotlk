# Гача-сумки — реализация (СДЕЛАНО на PTR 2026-06-07)

Статус: **применено на PTR и верифицировано запросами** (см. «Верификация»).
Названия + иконки прислал владелец 2026-06-07. Осталось владельцу: WDBX-мерж
`Item_custom.csv` (11 новых строк) → Item.dbc → MPQ → очистка WDB → in-game
тест открытий.

## Что построено

11 предметов-сумок (`Flags=4` HAS_LOOT), правый клик → стандартное лут-окно с
одной клеткой (110000–110099). **Повторы разрешены** (дубли продаются за 100г,
у клеток SellPrice=1000000).

| Item | Название (owner-confirmed) | Иконка | DisplayID | Пул | Шансы C/R/E |
|---|---|---|---|---|---|
| 110120 | Сумка Авантюриста | inv_misc_bag_19 | 19595 | все 100 | 89 / 10 / 1 |
| 110100 | Механический сундук | inv_box_01 | 12333 | семейство 1 | 70 / 20 / 10 |
| 110101 | Огненная сумка | inv_misc_bag_13 | 20342 | 2 | 70 / 20 / 10 |
| 110102 | Ледяная сумка | inv_misc_bag_enchantedmageweave | 34780 | 3 | 70 / 20 / 10 |
| 110103 | Природная сумка | inv_misc_bag_18 | 20503 | 4 | 70 / 20 / 10 |
| 110104 | Светлая сумка | inv_misc_bag_08 | 6430 | 5 | 70 / 20 / 10 |
| 110105 | Теневая сумка | inv_misc_bag_corefelclothbag | 33942 | 6 | 70 / 20 / 10 |
| 110106 | Тайная сумка | inv_misc_bag_21 | 31783 | 7 | 70 / 20 / 10 |
| 110107 | Демоническая сумка | inv_misc_bag_soulbag | 33940 | 8 | 70 / 20 / 10 |
| 110108 | Звериная сумка | inv_misc_bag_26_spellfire | 39459 | 9 | 70 / 20 / 10 |
| 110109 | Странная сумка | inv_misc_bag_17 | 21202 | 10 (Общий) | 70 / 20 / 10 |

Примечания:
- Владелец прислал «Странная Сумка» — нормализовано до «Странная сумка»
  (остальные стихийные — со строчной «сумка»); владелец поправит, если не согласен.
- 110100 намеренно «сундук» с иконкой коробки (механическое семейство).
- DisplayID = чистые строки ItemDisplayInfo (без 3D-моделей, стандартный звук
  сумки) — резолв по `.claude/dbc/ItemDisplayInfo.csv`.

## Механика — data-driven, БЕЗ C++

`item_template.Flags = 4` (HAS_LOOT) + `item_loot_template` с одной loot-группой
(GroupId=1) на сумку.

Семантика группы (проверено: `src/server/game/Loot/LootMgr.cpp`,
`LootTemplate::LootGroup::Roll`, ~строка 1292):
- явные шансы роллятся кумулятивно против одного rand(0..100);
- если никто не выпал — равновероятный выбор среди записей с `Chance=0`
  → дроп ГАРАНТИРОВАН, пустых открытий нет;
- групповые шансы НЕ масштабируются `Rate.Drop.*`.

Кодировка (сумма ровно 100):
- **Универсальная** (Entry=110120): 60 строк Common-клеток `Chance=1.4833`
  + 30 Rare `Chance=0.3333` + 10 Epic `Chance=0` (остаток ~1.003% →
  ~0.1003% каждому эпику — соответствует дизайну 0.1%).
- **Стихийная** (Entry=1101xx): 6 Common `Chance=11.6667` + 3 Rare
  `Chance=6.6667` + 1 Epic `Chance=0` (остаток ≈ 10%).

Итого loot-строк: 100 (универсальная) + 10×10 (стихийные) = **200**.

## Принятые решения (поля item_template)

- class 15 / subclass 0 / SoundOverrideSubclass -1 / Material 4 /
  InventoryType 0 / ItemLevel 1 / lockid 0 — по образцу Bag of Fishing
  Treasures 44663 (сверено на PTR).
- **stackable=1 — ОБЯЗАТЕЛЬНО, не вопрос вкуса**: `LootHandler.cpp`
  `DoLootRelease` после полного забора лута уничтожает ВЕСЬ слот
  (`DestroyItem`, не `DestroyItemCount`) — стак из 20 сумок исчез бы после
  открытия одной. Поэтому у Blizzard все лутбоксы stackable=1.
- bonding=1 (BoP), BuyPrice=0, SellPrice=0 (до жетона таверны — GM-only).
- Quality: универсальная 3 (синяя), стихийные 4 (фиолетовые).
- Описание: «Содержит клетку со случайным фамильяром … Шансы: обычный N%,
  редкий N%, эпический N%.» — в item_template.description + locale ruRU.

## Артефакты

- Генератор: `scripts/familiar-gen-chests.ps1` (UTF-8 BOM! `-Csv` для
  Item_custom.csv; названия/иконки/displayid — в `$chestCfg` внутри скрипта;
  валидирует 6C/3R/1E на семейство и chestItem против формулы 110100+(F-1)).
- SQL: `data/sql/updates/pending_db_world/nemesis_familiars_gacha_chests.sql`
  (item_template 11 + item_template_locale 11 + item_loot_template 200).
- CSV: 11 строк сумок упсертнуты в `.claude/dbc/Item_custom.csv`
  (итого 131 строка: 20 StatBooster + 100 клеток + 11 сумок).

## Верификация (выполнено 2026-06-07, всё чисто)

- `SELECT Entry, COUNT(*), ROUND(SUM(Chance),4), SUM(Chance=0) FROM
  item_loot_template WHERE Entry IN (110100..110109,110120) GROUP BY Entry;`
  → стихийные: 10 строк / 90.0003 / 1 нулевая; универсальная: 100 / 98.997 / 10.
- item_template: displayid/Quality/Flags=4/stackable=1/bonding=1/lockid=0,
  HEX(name) — корректный UTF-8.
- Violation-чек: loot-строки на несуществующие клетки → 0 строк.
- Лог worldserver: «Loaded 3478 item loot templates», ошибок нет.

## Осталось

1. **Владелец**: WDBX-мерж `Item_custom.csv` → Item.dbc (11 новых строк
   110100–110109, 110120) → MPQ → очистка WDB → `.additem 110120`,
   `.additem 110100` … `.additem 110109`, открыть пачку, проверить
   распределение и иконки.
2. После подтверждения — коммит финального статуса.

## Дальше по дизайну (после сумок)

- **Жетон таверны (110150) + дейли-квест** у трактирщика (Фаза 7) — валюта
  покупки сумок (универсальная 1 жетон, стихийная 3). До этого сумки GM-only.
- **Миграция T1**: `character_spell` 100120/121/122 → 102000/102070/102050,
  retire старых ID (190010-12, 100120-22, 101100-02, 100030-32). План в
  familiar_gacha_id_reservations.md «Retired ranges».

## Ключевые правила (НЕ нарушать)

- Читать `agent-memory/familiars-dev/INDEX.md` перед стартом. Критичные доки:
  json-workflow.md (пайплайн, BOM-ловушки), model-sounds.md (звуки, том
  `azerothcore-wotlk_ac-client-data-v2`), russian-text.md (тексты), ptr-only.md.
- SQL только в `data/sql/updates/pending_db_world/`, применение только
  `ptr-sql-apply.ps1`, БД только `*_ptr`.
- Русские тексты: компактный родительный падеж, полные названия характеристик.
- Кастомные предметы обязаны попасть в Item.dbc клиента (Item_custom.csv).
