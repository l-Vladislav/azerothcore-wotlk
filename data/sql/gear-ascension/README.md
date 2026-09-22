# Gear Ascension: миграции, которые НЕ применяются сами

Здесь лежат шесть SQL-файлов, которыми собран Gear Ascension. Они уже
накачены на живой сервер и на PTR — **вручную**, пакетами live-deployer от 20
и 21 июня 2026 (`.claude/agent-memory/live-deployer/packages/*gear-ascension*`).
В репозитории их до 22.09.2026 не было вовсе: ветка `feat/wow-ak-1-gear-ascension`
так и не получила PR.

## Почему не в `pending_db_world`

Мир применяет обновления сам. В `updates_include` четыре папки —
`data/sql/archive/db_world`, `data/sql/custom/db_world`,
`data/sql/updates/db_world`, `data/sql/updates/pending_db_world` — и
`DatabaseLoader` при каждой загрузке выполняет из них всё, чьё имя и хэш не
записаны в таблице `updates`. Записей `gear_ascension*` там нет ни на live, ни
на PTR: файлы накатывали мимо апдейтера.

Положи их в любую из этих четырёх папок — и при ближайшей пересборке образа
мир выполнит их на боевой базе. `gear_ascension_proto.sql` начинается с
`DELETE FROM item_template WHERE entry BETWEEN 300001 AND 399999`, то есть
снесёт и пересоберёт весь блок (10 206 предметов на сегодня) поверх живых
данных. Поэтому папка вне `updates_include` — ни одна из них сюда не смотрит.

## Как применить на чистую базу

Порядок важен — цепочка улучшений ссылается на предметы:

1. `gear_ascension_proto.sql` — копии по ступеням качества (Q2+Q3), таблица
   `item_upgrade_chain`;
2. `gear_ascension_white_bases.sql` — белые основы (Q1);
3. `gear_ascension_extra.sql` — фаза 3: изготовленные вещи и наборы (append-only);
4. `gear_ascension_kits.sql` — 21 набор (7 категорий × 3 ступени), спелл 105000;
5. `gear_ascension_kit_vendor.sql` — торговец наборами, цена через
   `itemextendedcost_dbc` 100008;
6. `gear_ascension_polish_a.sql` — правки после обкатки.

После применения запишите их в `updates` (имя + хэш), иначе при следующей
загрузке мир сочтёт их новыми — если к тому времени они окажутся в
сканируемой папке.

## Чего здесь нет

**`gear_ascension_cleanup_1m_block.sql` не перенесён намеренно.** Он удаляет
`item_template` в диапазоне 1 000 000 – 1 099 999: в июне там лежали старые
копии Gear Ascension, переехавшие затем в блок 300 000. Сегодня в этом
диапазоне **20 728 единиц оружия mod-worn-drops** — и на PTR, и на live.
Запускать его больше нельзя никогда; свою работу он сделал в июне.

Оригинал файла остаётся в истории ветки `feat/wow-ak-1-gear-ascension`.
