"""Добыча: кто что роняет и где что падает.

Заход первый — только ЧТЕНИЕ (решение владельца 2026-09-08). Правка и выгрузка
придут вторым; сейчас страница отвечает на два вопроса, ради которых её и
затевали: «что роняет вот этот моб» и «где падает вот этот предмет».

Четыре факта об устройстве добычи в AzerothCore, из которых растёт весь модуль:

  * **Таблиц тринадцать, а схема у них одна.** `Entry, Item, Reference, Chance,
    QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment`. Различаются
    они только тем, кто владелец `Entry`: у `creature_loot_template` это
    `creature_template.lootid`, у `gameobject_loot_template` — `Data1` объекта
    типа сундук, у `milling_loot_template` — сам предмет-трава. Поэтому таблица
    в коде описана строкой, а не классом на каждую.

  * **Ключ — `lootid`, а не entry моба.** В acore_world_ptr 8 763 существа с
    добычей, но различных `lootid` — 7 849: **930 мобов делят чужую таблицу**.
    Правка «добычи вот этого волка» тихо меняет её ещё у пятерых, и страница
    обязана называть всех.

  * **Ссылки вложены.** 19 578 строк добычи существ ведут в
    `reference_loot_template`, и 4 716 её строк ссылаются дальше. Ответ на
    «где падает предмет» — не `WHERE Item = X`, а обход ВВЕРХ: предмет →
    ссылки → кто на них ссылается → какие существа носят этот `lootid`.

  * **Строку добычи может запирать `condition`.** 2 543 строки добычи существ и
    1 291 у объектов закрыты условиями. Показывать строку, не показывая
    условия, значит врать: предмет в таблице есть, а выпасть не может.

Чего этот модуль не увидит и увидеть не может: **mod-worn-drops раздаёт добычу
кодом** (§ project_worn_armor_drop), таблиц не трогая. Об этом честная строка в
интерфейсе, а не молчание.
"""

import re
from dataclasses import dataclass
from typing import Any

from pydantic import BaseModel, Field

from . import paneldb, soap
from .db import cursor as world_cursor
from .db import query, query_one

RU = "ruRU"

# Глубина обхода ссылок. Настоящая вложенность в базе — два уровня; четыре
# берём с запасом, а не «пока не кончится», чтобы кольцо в данных не увело
# обход в бесконечность.
MAX_DEPTH = 4


class LootError(ValueError):
    """Отказ, который стоит показать человеку, а не в лог."""


@dataclass(frozen=True)
class LootTable:
    id: str          # короткое имя для API и вкладок
    table: str       # имя таблицы в acore_world
    name: str        # как называется по-русски
    owner: str       # род владельца Entry — см. owners_of()
    hint: str        # чем этот вид добычи берут


# Порядок важен: в этом виде таблицы показываются в интерфейсе, и первым идёт
# то, ради чего страницу и открывают.
LOOT_TABLES: tuple[LootTable, ...] = (
    LootTable("creature", "creature_loot_template", "Существа",
              "creature:lootid", "Падает с трупа"),
    LootTable("reference", "reference_loot_template", "Ссылки",
              "reference", "Общий кусок, который включают в себя другие"),
    LootTable("gameobject", "gameobject_loot_template", "Объекты",
              "gameobject", "Сундуки, руда, травы, рыбные места"),
    LootTable("pickpocketing", "pickpocketing_loot_template", "Карманы",
              "creature:pickpocketloot", "Достаётся разбойнику за кражу"),
    LootTable("skinning", "skinning_loot_template", "Освежевание",
              "creature:skinloot", "Снимается с трупа скорняком"),
    LootTable("item", "item_loot_template", "Предметы-контейнеры",
              "item", "Что внутри сумки, шкатулки, мешка"),
    LootTable("disenchant", "disenchant_loot_template", "Распыление",
              "item:DisenchantID", "Во что распыляется вещь"),
    LootTable("prospecting", "prospecting_loot_template", "Просеивание",
              "item", "Что даёт руда при просеивании"),
    LootTable("milling", "milling_loot_template", "Измельчение",
              "item", "Что даёт трава при измельчении"),
    LootTable("fishing", "fishing_loot_template", "Рыбалка",
              "zone", "Что ловится в этой зоне"),
    LootTable("mail", "mail_loot_template", "Почта",
              "mail", "Вложение письма от игры"),
    LootTable("spell", "spell_loot_template", "Заклинания",
              "spell", "Что создаёт заклинание"),
    LootTable("player", "player_loot_template", "Игроки",
              "player", "Что падает с игрока"),
)

BY_ID = {t.id: t for t in LOOT_TABLES}
BY_TABLE = {t.table: t for t in LOOT_TABLES}

REFERENCE = BY_ID["reference"]

# Колонки строки добычи — одни и те же у всех тринадцати.
COLUMNS = ("Entry", "Item", "Reference", "Chance", "QuestRequired",
           "LootMode", "GroupId", "MinCount", "MaxCount", "Comment")
COL_LIST = ", ".join("`%s`" % c for c in COLUMNS)

# Режимы добычи — битовая маска сложности. Обычный режим единица, дальше по
# биту на сложность; строка с маской 2 не выпадет в обычном подземелье вовсе.
LOOT_MODES = {
    1: "обычный", 2: "героический", 4: "25 обычный", 8: "25 героический",
    16: "режим 5", 32: "режим 6", 64: "режим 7", 128: "режим 8",
}

RANKS = {0: "обычный", 1: "элита", 2: "редкая элита", 3: "босс",
         4: "редкий"}

# Типы источника условий (`conditions.SourceTypeOrReferenceId`), которые
# относятся к добыче. Остальные страница не показывает - они не про неё.
CONDITION_SOURCES = {
    1: "creature",
    4: "item",
    5: "fishing",
    7: "reference",
    10: "gameobject",
    13: "spell",
    14: "disenchant",
}
SOURCE_BY_TABLE = {v: k for k, v in CONDITION_SOURCES.items()}


def available() -> bool:
    """Есть ли таблицы добычи. Без них страница честно говорит, что пуста."""
    row = query_one(
        "SELECT COUNT(*) AS n FROM information_schema.tables "
        "WHERE table_schema = DATABASE() AND table_name = %s",
        (REFERENCE.table,))
    return bool(row and int(row["n"]))


def _table(table_id: str) -> LootTable:
    found = BY_ID.get(table_id)
    if not found:
        raise LootError("Неизвестная таблица добычи: %s" % table_id)
    return found


# --- имена --------------------------------------------------------------
# Имена предметов и существ живут в двух местах: базовое в самой таблице,
# русское — в *_locale. Клиент русского игрока видит второе, поэтому и панель
# показывает его, а базовое оставляет для поиска.

def _item_info(entries: list[int]) -> dict[int, dict]:
    ids = sorted({int(e) for e in entries if e})
    if not ids:
        return {}
    marks = ", ".join(["%s"] * len(ids))
    rows = query(
        "SELECT i.`entry`, i.`name`, i.`Quality`, i.`ItemLevel`, "
        "i.`RequiredLevel`, i.`class`, i.`subclass`, i.`displayid`, "
        "l.`Name` AS name_ru "
        "FROM `item_template` i "
        "LEFT JOIN `item_template_locale` l "
        "  ON l.`ID` = i.`entry` AND l.`locale` = %%s "
        "WHERE i.`entry` IN (%s)" % marks, tuple([RU] + ids))
    return {int(r["entry"]): r for r in rows}


def _creature_info(entries: list[int]) -> dict[int, dict]:
    ids = sorted({int(e) for e in entries if e})
    if not ids:
        return {}
    marks = ", ".join(["%s"] * len(ids))
    rows = query(
        "SELECT c.`entry`, c.`name`, c.`subname`, c.`minlevel`, c.`maxlevel`, "
        "c.`rank`, c.`lootid`, c.`pickpocketloot`, c.`skinloot`, "
        "l.`Name` AS name_ru, l.`Title` AS subname_ru "
        "FROM `creature_template` c "
        "LEFT JOIN `creature_template_locale` l "
        "  ON l.`entry` = c.`entry` AND l.`locale` = %%s "
        "WHERE c.`entry` IN (%s)" % marks, tuple([RU] + ids))
    return {int(r["entry"]): r for r in rows}


def _decorate_item(row: dict | None, entry: int) -> dict:
    """Предмет для показа: имя, качество, уровень. Нет строки — так и скажем."""
    if not row:
        return {"entry": entry, "name": "", "name_ru": "",
                "missing": True, "quality": 0}
    return {
        "entry": entry,
        "name": row["name"],
        "name_ru": row["name_ru"] or row["name"],
        "quality": int(row["Quality"]),
        "ilvl": int(row["ItemLevel"]),
        "req_level": int(row["RequiredLevel"]),
        "class": int(row["class"]),
        "subclass": int(row["subclass"]),
        "displayid": int(row["displayid"]),
        "missing": False,
    }


def _creature_brief(row: dict) -> dict:
    level = (str(row["minlevel"]) if row["minlevel"] == row["maxlevel"]
             else "%d-%d" % (row["minlevel"], row["maxlevel"]))
    return {
        "entry": int(row["entry"]),
        "name": row["name"],
        "name_ru": row.get("name_ru") or row["name"],
        "subname": row.get("subname_ru") or row.get("subname") or "",
        "level": level,
        "rank": int(row["rank"]),
        "rank_name": RANKS.get(int(row["rank"]), str(row["rank"])),
        "lootid": int(row["lootid"]),
        "pickpocketloot": int(row["pickpocketloot"]),
        "skinloot": int(row["skinloot"]),
    }


# --- шансы --------------------------------------------------------------

def _group_chances(rows: list[dict]) -> dict[int, float]:
    """Действительный шанс строки с оглядкой на её группу.

    Правила ядра (`LootTemplate::LootGroup::Roll`), а не догадки:

      * `GroupId = 0` — строка катится сама по себе, шанс её собственный;
      * `GroupId > 0` — из группы выпадает НЕ БОЛЕЕ ОДНОЙ строки. Строки с
        заданным шансом катятся первыми, а строки с нулём делят остаток
        поровну: четыре нуля при сумме явных 20 % дают каждой по 20 %.

    Без этого шанс строки в группе читался бы как «0 %», и половина боссов
    выглядела бы не роняющей ничего.
    """
    by_group: dict[int, list[dict]] = {}
    for row in rows:
        by_group.setdefault(int(row["GroupId"]), []).append(row)

    out: dict[int, float] = {}
    for group, members in by_group.items():
        if not group:
            for idx, row in enumerate(members):
                out[id(row)] = float(row["Chance"])
            continue

        explicit = sum(float(r["Chance"]) for r in members
                       if float(r["Chance"]) > 0)
        equal = [r for r in members if float(r["Chance"]) <= 0]
        share = max(0.0, 100.0 - explicit) / len(equal) if equal else 0.0
        for row in members:
            chance = float(row["Chance"])
            out[id(row)] = chance if chance > 0 else share
    return out


# --- условия ------------------------------------------------------------

def _conditions(source_type: int, entries: list[int]) -> dict[tuple, list[dict]]:
    """Условия строк добычи: ключ — (SourceGroup, SourceEntry).

    Сама расшифровка условия (класс, раса, квест, аура) в первом заходе не
    разбирается: показываем тип, значения и комментарий. Врать красивым
    переводом хуже, чем показать числа - типов условий в ядре под сотню.
    """
    ids = sorted({int(e) for e in entries if e})
    if not ids:
        return {}
    marks = ", ".join(["%s"] * len(ids))
    rows = query(
        "SELECT `SourceGroup`, `SourceEntry`, `ElseGroup`, `ConditionTypeOrReference`, "
        "`ConditionValue1`, `ConditionValue2`, `ConditionValue3`, "
        "`NegativeCondition`, `Comment` "
        "FROM `conditions` WHERE `SourceTypeOrReferenceId` = %%s "
        "AND `SourceGroup` IN (%s)" % marks, tuple([source_type] + ids))
    out: dict[tuple, list[dict]] = {}
    for row in rows:
        key = (int(row["SourceGroup"]), int(row["SourceEntry"]))
        out.setdefault(key, []).append(row)
    return out



# --- имена записей и групп ------------------------------------------------
#
# «Запись 16507» и «Группа 1» не говорят человеку ничего, а таких записей в
# базе почти восемь тысяч. Имя решает это дважды:
#
#   * АВТОИМЯ считается из самих данных и появляется само - без единой правки.
#     У добычи существа это имя владельца, у ссылки - комментарий тех строк,
#     что на неё ссылаются («Sartharion (1)»), у предмета-контейнера - имя
#     предмета. Восемь тысяч записей руками не подпишет никто, и автоимя
#     закрывает почти все;
#   * СВОЁ ИМЯ перебивает автоимя там, где оно врёт или не сложилось. Группе
#     автоимени взять неоткуда вовсе - только своё.
#
# Живёт это в схеме панели (`acore_admin`), а не в игровой базе, и по той же
# причине, что доска и журнал: восстановление снимка PTR не должно стирать
# подписи. Игровых таблиц имена не касаются - ядро о них не знает.

SCHEMA = [
    """
    CREATE TABLE IF NOT EXISTS `loot_label` (
      `table_id`   VARCHAR(24) NOT NULL,
      `entry`      INT UNSIGNED NOT NULL,
      `kind`       ENUM('entry','group') NOT NULL DEFAULT 'entry',
      `group_id`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      `name`       VARCHAR(120) NOT NULL DEFAULT '',
      `note`       TEXT,
      `author`     VARCHAR(64) NOT NULL DEFAULT '',
      `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                   ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (`table_id`, `entry`, `kind`, `group_id`),
      KEY `idx_named` (`table_id`, `name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """,
]


def ensure_schema() -> None:
    paneldb.ensure("loot", SCHEMA)


# Хвост, которым игра метит строки-ссылки. В имени он лишний: «Sartharion (1) -
# (ReferenceTable)» короче и понятнее без него.
_REF_TAIL = re.compile(r"\s*[-–—]?\s*\(?ReferenceTable\)?\s*$", re.I)


def labels(table_id: str, entries: list[int]) -> dict[tuple[int, str, int], dict]:
    """Свои имена записей и групп: ключ - (entry, kind, group_id)."""
    ids = sorted({int(e) for e in entries if e})
    if not ids:
        return {}
    ensure_schema()
    marks = ", ".join(["%s"] * len(ids))
    with paneldb.cursor() as cur:
        cur.execute(
            "SELECT `entry`, `kind`, `group_id`, `name`, `note`, `author`, "
            "`updated_at` FROM `loot_label` WHERE `table_id` = %%s "
            "AND `entry` IN (%s)" % marks, tuple([table_id] + ids))
        rows = cur.fetchall()
    return {(int(r["entry"]), r["kind"], int(r["group_id"])): r for r in rows}


def _pick_owner_name(rows: list[dict], key: str) -> dict[int, str]:
    """Имя владельца записи; их бывает много - тогда «первый и ещё N»."""
    seen: dict[int, list[str]] = {}
    for row in rows:
        seen.setdefault(int(row[key]), []).append(
            row.get("name_ru") or row.get("name") or "")
    return {entry: (names[0] if len(names) == 1
                    else "%s и ещё %d" % (names[0], len(names) - 1))
            for entry, names in seen.items() if names}


def auto_names(table_id: str, entries: list[int]) -> dict[int, str]:
    """Имя, которое видно из самих данных. Пусто - значит взять неоткуда."""
    table = _table(table_id)
    ids = sorted({int(e) for e in entries if e})
    if not ids:
        return {}
    marks = ", ".join(["%s"] * len(ids))

    if table.owner.startswith("creature:"):
        column = table.owner.split(":", 1)[1]
        return _pick_owner_name(query(
            "SELECT c.`%s` AS loot, c.`name`, l.`Name` AS name_ru "
            "FROM `creature_template` c "
            "LEFT JOIN `creature_template_locale` l "
            "  ON l.`entry` = c.`entry` AND l.`locale` = %%s "
            "WHERE c.`%s` IN (%s) ORDER BY c.`entry`"
            % (column, column, marks), tuple([RU] + ids)), "loot")

    if table.id == "gameobject":
        return _pick_owner_name(query(
            "SELECT g.`Data1` AS loot, g.`name`, l.`name` AS name_ru "
            "FROM `gameobject_template` g "
            "LEFT JOIN `gameobject_template_locale` l "
            "  ON l.`entry` = g.`entry` AND l.`locale` = %%s "
            "WHERE g.`type` IN (3, 25) AND g.`Data1` IN (%s) "
            "ORDER BY g.`entry`" % marks, tuple([RU] + ids)), "loot")

    if table.id == "disenchant":
        return _pick_owner_name(query(
            "SELECT i.`DisenchantID` AS loot, i.`name`, l.`Name` AS name_ru "
            "FROM `item_template` i "
            "LEFT JOIN `item_template_locale` l "
            "  ON l.`ID` = i.`entry` AND l.`locale` = %%s "
            "WHERE i.`DisenchantID` IN (%s) ORDER BY i.`entry`" % marks,
            tuple([RU] + ids)), "loot")

    if table.id in ("item", "prospecting", "milling"):
        return {entry: (info["name_ru"] or info["name"])
                for entry, info in _item_info(ids).items()}

    if table.id == REFERENCE.id:
        # У самой ссылки владельца нет, зато есть тот, кто на неё ссылается, и
        # его строка обычно подписана: «Sartharion (1) - (ReferenceTable)».
        # Берём самый частый комментарий - он и есть смысл этой ссылки.
        counts: dict[int, dict[str, int]] = {}
        for other in LOOT_TABLES:
            for row in query(
                    "SELECT ABS(`Reference`) AS loot, `Comment` FROM `%s` "
                    "WHERE ABS(`Reference`) IN (%s) AND `Comment` IS NOT NULL "
                    "AND `Comment` <> ''" % (other.table, marks), tuple(ids)):
                text = _REF_TAIL.sub("", row["Comment"]).strip()
                if text:
                    bag = counts.setdefault(int(row["loot"]), {})
                    bag[text] = bag.get(text, 0) + 1
        return {entry: max(bag.items(), key=lambda kv: (kv[1], -len(kv[0])))[0]
                for entry, bag in counts.items()}

    return {}


def _label_of(store: dict, autos: dict, entry: int) -> dict:
    """Что показать вместо номера записи."""
    own = store.get((int(entry), "entry", 0)) or {}
    return {
        "name": own.get("name") or "",
        "note": own.get("note") or "",
        "auto": autos.get(int(entry), ""),
    }


def _group_labels(store: dict, entry: int, groups) -> list[dict]:
    out = []
    for group in sorted(groups):
        own = store.get((int(entry), "group", int(group))) or {}
        out.append({
            "id": int(group),
            "name": own.get("name") or "",
            "note": own.get("note") or "",
        })
    return out


def save_label(table_id: str, entry: int, kind: str, group_id: int,
               name: str, note: str, author: str) -> dict:
    """Завести или переписать имя. Пустое имя без пояснения - снять подпись."""
    _table(table_id)
    if kind not in ("entry", "group"):
        raise LootError("Имя бывает у записи или у группы, не у чего-то ещё.")
    text = (name or "").strip()[:120]
    body = (note or "").strip()
    ensure_schema()
    with paneldb.cursor(commit=True) as cur:
        if not text and not body:
            cur.execute(
                "DELETE FROM `loot_label` WHERE `table_id` = %s AND "
                "`entry` = %s AND `kind` = %s AND `group_id` = %s",
                (table_id, entry, kind, group_id))
            return {"name": "", "note": ""}
        cur.execute(
            "INSERT INTO `loot_label` (`table_id`, `entry`, `kind`, "
            "`group_id`, `name`, `note`, `author`) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s) "
            "ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), "
            "`note` = VALUES(`note`), `author` = VALUES(`author`)",
            (table_id, entry, kind, group_id, text, body, author or ""))
    return {"name": text, "note": body}


def named(table_id: str = "", q: str = "", limit: int = 200) -> list[dict]:
    """Все подписанные записи - чтобы найти своё среди восьми тысяч чужих."""
    ensure_schema()
    where, args = ["`name` <> ''"], []
    if table_id:
        _table(table_id)
        where.append("`table_id` = %s")
        args.append(table_id)
    text = (q or "").strip()
    if text:
        where.append("(`name` LIKE %s OR `note` LIKE %s)")
        args += ["%" + text + "%"] * 2
    with paneldb.cursor() as cur:
        cur.execute(
            "SELECT `table_id`, `entry`, `kind`, `group_id`, `name`, `note`, "
            "`updated_at` FROM `loot_label` WHERE %s "
            "ORDER BY `table_id`, `entry`, `kind`, `group_id` LIMIT %%s"
            % " AND ".join(where), tuple(args + [max(1, min(int(limit), 500))]))
        return list(cur.fetchall())


# --- дерево добычи одной таблицы ----------------------------------------

def _rows_of(table: LootTable, entry: int) -> list[dict]:
    return query(
        "SELECT %s FROM `%s` WHERE `Entry` = %%s ORDER BY `GroupId`, `Item`"
        % (COL_LIST, table.table), (entry,))


def entry_tree(table_id: str, entry: int, _depth: int = 0,
               _seen: set | None = None) -> dict:
    """Строки одной записи добычи с раскрытыми ссылками.

    Возвращает не плоский список, а дерево: ссылка — это узел, внутри которого
    лежит вся своя таблица. Иначе «шанс 15 %» у ссылки и «шанс 40 %» у предмета
    внутри неё стояли бы рядом в одном списке, и прочесть их как 6 % было бы
    неоткуда.
    """
    table = _table(table_id)
    seen = _seen if _seen is not None else set()
    key = (table.id, int(entry))
    if key in seen or _depth > MAX_DEPTH:
        return {"table": table.id, "entry": int(entry), "rows": [],
                "truncated": True}
    seen = seen | {key}

    rows = _rows_of(table, entry)
    chances = _group_chances(rows)
    items = _item_info([r["Item"] for r in rows])

    source = SOURCE_BY_TABLE.get(table.id)
    conds = _conditions(source, [entry]) if source else {}

    out_rows = []
    for row in rows:
        # Знак у ссылки ничего не значит: ядро берёт её по модулю
        # (`std::abs(item->reference)` в LootMgr.cpp). В базе такая строка одна,
        # и без abs она выглядела бы ссылкой в никуда.
        ref = abs(int(row["Reference"]))
        item_entry = int(row["Item"])
        node: dict[str, Any] = {
            "item": _decorate_item(items.get(item_entry), item_entry)
                    if item_entry else None,
            "reference": ref,
            "chance": round(chances.get(id(row), 0.0), 4),
            "raw_chance": float(row["Chance"]),
            "group": int(row["GroupId"]),
            "quest": bool(row["QuestRequired"]),
            "mode": int(row["LootMode"]),
            "mode_name": _mode_name(int(row["LootMode"])),
            "min": int(row["MinCount"]),
            "max": int(row["MaxCount"]),
            "comment": row["Comment"] or "",
            "conditions": conds.get((int(entry), item_entry or ref), []),
        }
        if ref:
            child = entry_tree(REFERENCE.id, ref, _depth + 1, seen)
            node["child"] = child
            # Ссылка в никуда - настоящая беда, а не мелочь: в базе такая уже
            # есть одна. Строка выглядит рабочей, а не даёт ничего.
            node["broken"] = not child["rows"] and not child.get("truncated")
        out_rows.append(node)

    groups = {r["group"] for r in out_rows}
    store = labels(table.id, [entry])
    return {
        "table": table.id,
        "table_name": table.name,
        "entry": int(entry),
        "rows": out_rows,
        # Имя записи и имена групп едут вместе с деревом: без них «Запись
        # 16507» и «Группа 1» не говорят человеку ничего.
        "label": _label_of(store, auto_names(table.id, [entry]), entry),
        "groups": _group_labels(store, entry, groups),
        "truncated": False,
    }


def _mode_name(mode: int) -> str:
    if mode in LOOT_MODES:
        return LOOT_MODES[mode]
    parts = [name for bit, name in LOOT_MODES.items() if mode & bit]
    return " + ".join(parts) if parts else "маска %d" % mode


# --- владельцы записи ----------------------------------------------------

def owners_of(table_id: str, entry: int) -> list[dict]:
    """Кто пользуется этой записью добычи.

    Главный ответ страницы на вопрос «кого я задену правкой»: у 930 существ
    `lootid` не совпадает с их entry, и одна запись добычи бывает общей.
    """
    table = _table(table_id)
    kind = table.owner

    if kind.startswith("creature:"):
        column = kind.split(":", 1)[1]
        rows = query(
            "SELECT c.`entry`, c.`name`, c.`subname`, c.`minlevel`, "
            "c.`maxlevel`, c.`rank`, c.`lootid`, c.`pickpocketloot`, "
            "c.`skinloot`, l.`Name` AS name_ru, l.`Title` AS subname_ru "
            "FROM `creature_template` c "
            "LEFT JOIN `creature_template_locale` l "
            "  ON l.`entry` = c.`entry` AND l.`locale` = %%s "
            "WHERE c.`%s` = %%s ORDER BY c.`entry`" % column, (RU, entry))
        return [dict(_creature_brief(r), kind="creature") for r in rows]

    if kind == "gameobject":
        # У сундука (тип 3) и рыбного места (тип 25) номер добычи лежит в
        # Data1. У прочих типов это поле значит другое, поэтому тип в условии.
        rows = query(
            "SELECT g.`entry`, g.`name`, g.`type`, l.`name` AS name_ru "
            "FROM `gameobject_template` g "
            "LEFT JOIN `gameobject_template_locale` l "
            "  ON l.`entry` = g.`entry` AND l.`locale` = %s "
            "WHERE g.`type` IN (3, 25) AND g.`Data1` = %s ORDER BY g.`entry`",
            (RU, entry))
        return [{"kind": "gameobject", "entry": int(r["entry"]),
                 "name": r["name"], "name_ru": r["name_ru"] or r["name"],
                 "type": int(r["type"])} for r in rows]

    if kind == "item":
        info = _item_info([entry]).get(int(entry))
        return [dict(_decorate_item(info, int(entry)), kind="item")] if info \
            else []

    if kind == "item:DisenchantID":
        rows = query(
            "SELECT i.`entry`, i.`name`, i.`Quality`, i.`ItemLevel`, "
            "i.`RequiredLevel`, i.`class`, i.`subclass`, i.`displayid`, "
            "l.`Name` AS name_ru FROM `item_template` i "
            "LEFT JOIN `item_template_locale` l "
            "  ON l.`ID` = i.`entry` AND l.`locale` = %s "
            "WHERE i.`DisenchantID` = %s ORDER BY i.`entry` LIMIT 200",
            (RU, entry))
        return [dict(_decorate_item(r, int(r["entry"])), kind="item")
                for r in rows]

    if kind == "zone":
        return [{"kind": "zone", "entry": int(entry),
                 "name_ru": "зона %d" % int(entry)}]
    if kind == "spell":
        return [{"kind": "spell", "entry": int(entry),
                 "name_ru": "заклинание %d" % int(entry)}]
    if kind == "mail":
        return [{"kind": "mail", "entry": int(entry),
                 "name_ru": "шаблон письма %d" % int(entry)}]
    if kind == "player":
        return [{"kind": "player", "entry": int(entry),
                 "name_ru": "игрок (сторона %d)" % int(entry)}]
    # reference: владельца нет, на неё ссылаются
    return []


# --- поиск ---------------------------------------------------------------

def creatures(q: str = "", only_loot: bool = True, limit: int = 60,
              rank: int = -1, level_min: int = 0, level_max: int = 0,
              offset: int = 0) -> dict:
    """Поиск существа по имени (русскому или базовому) либо по номеру.

    Отбор идёт в базе, а не в браузере: существ тридцать тысяч, и фильтровать
    восемьдесят присланных строк - значит фильтровать не то, что искали.

    Возвращает и СКОЛЬКО ВСЕГО нашлось, а не только страницу: без этого
    таблица не может ни показать «1-50 из 3184», ни листать - она бы знала
    лишь то, что ей прислали. Счёт идёт отдельным запросом по тем же
    условиям; лишний он только на первый взгляд - без него пришлось бы тянуть
    все строки, чтобы их сосчитать.
    """
    where = []
    args: list[Any] = [RU]
    text = (q or "").strip()
    if text.isdigit():
        where.append("c.`entry` = %s")
        args.append(int(text))
    elif text:
        where.append("(c.`name` LIKE %s OR l.`Name` LIKE %s)")
        args += ["%" + text + "%"] * 2
    if only_loot:
        where.append("(c.`lootid` <> 0 OR c.`pickpocketloot` <> 0 "
                     "OR c.`skinloot` <> 0)")
    if rank >= 0:
        where.append("c.`rank` = %s")
        args.append(int(rank))
    # Полоса уровней сравнивается с полосой существа, а не с одним числом: у
    # моба уровень бывает диапазоном, и «от 70 до 80» должно ловить моба 68-72.
    if level_min:
        where.append("c.`maxlevel` >= %s")
        args.append(int(level_min))
    if level_max:
        where.append("c.`minlevel` <= %s")
        args.append(int(level_max))

    # Соединение с локалью нужно и счёту: по русскому имени тоже ищут.
    source = ("FROM `creature_template` c "
              "LEFT JOIN `creature_template_locale` l "
              "  ON l.`entry` = c.`entry` AND l.`locale` = %s "
              + ("WHERE " + " AND ".join(where) if where else ""))
    total = query("SELECT COUNT(*) AS n " + source, tuple(args))[0]["n"]

    sql = (
        "SELECT c.`entry`, c.`name`, c.`subname`, c.`minlevel`, c.`maxlevel`, "
        "c.`rank`, c.`lootid`, c.`pickpocketloot`, c.`skinloot`, "
        "l.`Name` AS name_ru, l.`Title` AS subname_ru "
        + source
        + " ORDER BY c.`rank` DESC, c.`maxlevel` DESC, c.`entry` "
          "LIMIT %s OFFSET %s")
    page = list(args)
    page.append(max(1, min(int(limit), 200)))
    page.append(max(0, int(offset)))
    return {"rows": [_creature_brief(r) for r in query(sql, tuple(page))],
            "total": int(total)}


def creature(entry: int) -> dict:
    """Полная картина по существу: три вида добычи и кто их с ним делит."""
    info = _creature_info([entry]).get(int(entry))
    if not info:
        raise LootError("Существа %d нет в creature_template." % entry)

    brief = _creature_brief(info)
    kinds = [("creature", brief["lootid"], "С трупа"),
             ("pickpocketing", brief["pickpocketloot"], "Из карманов"),
             ("skinning", brief["skinloot"], "Освежеванием")]

    out = []
    for table_id, loot_entry, label in kinds:
        if not loot_entry:
            continue
        tree = entry_tree(table_id, loot_entry)
        shared = [o for o in owners_of(table_id, loot_entry)
                  if o["entry"] != brief["entry"]]
        out.append({
            "table": table_id, "label": label, "entry": loot_entry,
            "own_entry": loot_entry == brief["entry"],
            "tree": tree, "shared": shared,
        })
    return {"creature": brief, "loot": out}

# --- где падает предмет --------------------------------------------------
#
# Обход идёт ВВЕРХ: сперва все строки со ссылкой на предмет, потом - для строк
# в таблице ссылок - все, кто ссылается на ту запись, и так до таблицы с
# настоящим владельцем. Без этого 19 578 строк добычи существ не нашлись бы
# вовсе: предмет в них лежит не напрямую.
#
# Обход ПОУРОВНЕВЫЙ и пакетный, и это не преждевременная забота о скорости.
# Первая версия ходила по одному пути за раз и спрашивала базу на каждом шаге;
# на предмете 11, который лежит в 201 разной ссылке, это разворачивалось в
# десятки тысяч запросов, и ручка просто не отвечала. Теперь уровень целиком
# берётся одним запросом на таблицу, а строки записи и её владельцы читаются
# по разу за весь ответ.


class _Ctx:
    """Кэши на один ответ: одна и та же запись встречается в сотне путей."""

    def __init__(self) -> None:
        self.rows: dict[tuple[str, int], list[dict]] = {}
        self.chances: dict[tuple[str, int], dict[int, float]] = {}
        self.owners: dict[tuple[str, int], list[dict]] = {}

    def rows_of(self, table: LootTable, entry: int) -> list[dict]:
        key = (table.id, int(entry))
        if key not in self.rows:
            self.rows[key] = _rows_of(table, entry)
            self.chances[key] = _group_chances(self.rows[key])
        return self.rows[key]

    def preload(self, table: LootTable, entries) -> None:
        """Строки целого уровня обхода - одним запросом на таблицу.

        Читать их по записи значило бы тысячу запросов на тяжёлом предмете:
        так первая версия и отвечала двенадцать секунд вместо полутора.
        """
        want = sorted({int(e) for e in entries
                       if (table.id, int(e)) not in self.rows})
        for start in range(0, len(want), 500):
            chunk = want[start:start + 500]
            marks = ", ".join(["%s"] * len(chunk))
            rows = query(
                "SELECT %s FROM `%s` WHERE `Entry` IN (%s) "
                "ORDER BY `Entry`, `GroupId`, `Item`"
                % (COL_LIST, table.table, marks), tuple(chunk))
            grouped: dict[int, list[dict]] = {e: [] for e in chunk}
            for row in rows:
                grouped[int(row["Entry"])].append(row)
            for entry, part in grouped.items():
                key = (table.id, entry)
                self.rows[key] = part
                self.chances[key] = _group_chances(part)

    def preload_owners(self, table: LootTable, entries) -> None:
        """Владельцы целого уровня. Пакетно умеем существ - их и большинство."""
        if not table.owner.startswith("creature:"):
            return
        column = table.owner.split(":", 1)[1]
        want = sorted({int(e) for e in entries
                       if (table.id, int(e)) not in self.owners})
        if not want:
            return
        for start in range(0, len(want), 500):
            chunk = want[start:start + 500]
            marks = ", ".join(["%s"] * len(chunk))
            rows = query(
                "SELECT c.`entry`, c.`name`, c.`subname`, c.`minlevel`, "
                "c.`maxlevel`, c.`rank`, c.`lootid`, c.`pickpocketloot`, "
                "c.`skinloot`, l.`Name` AS name_ru, l.`Title` AS subname_ru "
                "FROM `creature_template` c "
                "LEFT JOIN `creature_template_locale` l "
                "  ON l.`entry` = c.`entry` AND l.`locale` = %%s "
                "WHERE c.`%s` IN (%s) ORDER BY c.`entry`"
                % (column, marks), tuple([RU] + chunk))
            found: dict[int, list[dict]] = {e: [] for e in chunk}
            for row in rows:
                found[int(row[column])].append(
                    dict(_creature_brief(row), kind="creature"))
            for entry, owners in found.items():
                self.owners[(table.id, entry)] = owners

    def chance_of(self, table: LootTable, row: dict) -> float:
        """Шанс строки с оглядкой на её группу - из кэша сестёр."""
        key = (table.id, int(row["Entry"]))
        self.rows_of(table, int(row["Entry"]))
        for sibling in self.rows[key]:
            if (int(sibling["Item"]) == int(row["Item"])
                    and abs(int(sibling["Reference"])) == abs(int(row["Reference"]))
                    and int(sibling["GroupId"]) == int(row["GroupId"])):
                return self.chances[key][id(sibling)]
        return float(row["Chance"])

    def owners_of(self, table_id: str, entry: int) -> list[dict]:
        key = (table_id, int(entry))
        if key not in self.owners:
            self.owners[key] = owners_of(table_id, entry)
        return self.owners[key]


def _hop(ctx: _Ctx, table: LootTable, row: dict) -> dict:
    """Один шаг цепочки: строка в таблице, с её действительным шансом."""
    return {
        "table": table.id,
        "table_name": table.name,
        "entry": int(row["Entry"]),
        "chance": round(ctx.chance_of(table, row), 4),
        "group": int(row["GroupId"]),
        "quest": bool(row["QuestRequired"]),
        "mode": int(row["LootMode"]),
        "mode_name": _mode_name(int(row["LootMode"])),
        "min": int(row["MinCount"]),
        "max": int(row["MaxCount"]),
        "comment": row["Comment"] or "",
    }


def _referrers(entries: list[int]) -> dict[int, list[tuple[LootTable, dict]]]:
    """Кто ссылается на эти записи - один запрос на таблицу, а не на запись.

    ABS по той же причине, что и при раскрытии дерева: ядро читает ссылку по
    модулю (`std::abs(item->reference)`), и отрицательная запись ведёт туда же,
    куда положительная.
    """
    ids = sorted({int(e) for e in entries})
    if not ids:
        return {}
    marks = ", ".join(["%s"] * len(ids))
    out: dict[int, list[tuple[LootTable, dict]]] = {i: [] for i in ids}
    for table in LOOT_TABLES:
        for row in query(
                "SELECT %s FROM `%s` WHERE ABS(`Reference`) IN (%s) "
                "ORDER BY `Entry`" % (COL_LIST, table.table, marks),
                tuple(ids)):
            out[abs(int(row["Reference"]))].append((table, row))
    return out


def where_drops(item_entry: int, limit: int = 400) -> dict:
    """Все пути, которыми предмет попадает к игроку.

    Путь возвращается вместе с цепочкой шагов, чтобы человек видел, ЧЕРЕЗ ЧТО
    предмет падает, а не только «с этого моба». Шансы по цепочке
    перемножаются: попасть в ссылку и выпасть внутри неё - два независимых
    броска.
    """
    ctx = _Ctx()
    item = _item_info([item_entry]).get(int(item_entry))
    paths: list[dict] = []
    truncated = False

    # Уровень 0: прямые упоминания во всех тринадцати таблицах.
    frontier: list[tuple[LootTable, int, list[dict]]] = []
    for table in LOOT_TABLES:
        for row in query(
                "SELECT %s FROM `%s` WHERE `Item` = %%s ORDER BY `Entry`"
                % (COL_LIST, table.table), (item_entry,)):
            frontier.append((table, int(row["Entry"]), [_hop(ctx, table, row)]))

    seen: set[tuple[str, int]] = set()
    for _ in range(MAX_DEPTH + 1):
        if not frontier or truncated:
            break

        # Владельцев всего уровня берём пакетом, до перебора путей.
        by_table: dict[str, set[int]] = {}
        for table, entry, _chain in frontier:
            by_table.setdefault(table.id, set()).add(entry)
        for table_id, entries in by_table.items():
            ctx.preload_owners(BY_ID[table_id], entries)

        # Терминальные записи: у них есть настоящий владелец, путь окончен.
        pending: list[tuple[LootTable, int, list[dict]]] = []
        for table, entry, chain in frontier:
            key = (table.id, entry)
            if table.id != REFERENCE.id:
                for owner in ctx.owners_of(table.id, entry) or [None]:
                    paths.append(_finish(chain, table, entry, owner))
                    if len(paths) >= limit:
                        truncated = True
                        break
            elif key in seen:
                continue
            else:
                seen.add(key)
                pending.append((table, entry, chain))
            if truncated:
                break

        if truncated or not pending:
            break

        # Ссылки: весь уровень одним запросом на таблицу.
        found = _referrers([e for _, e, _ in pending])

        # Строки записей, куда сейчас шагнём: их читает _hop, и без пакета
        # это запрос на каждую.
        nxt: dict[str, set[int]] = {}
        for rows in found.values():
            for other, row in rows:
                nxt.setdefault(other.id, set()).add(int(row["Entry"]))
        for table_id, entries in nxt.items():
            ctx.preload(BY_ID[table_id], entries)

        frontier = []
        for table, entry, chain in pending:
            rows = found.get(entry, [])
            if not rows:
                # Ссылка, на которую никто не ссылается: сирота. Показываем как
                # есть - это находка, а не ошибка чтения.
                paths.append(_finish(chain, table, entry, None))
                continue
            for other, row in rows:
                frontier.append((other, int(row["Entry"]),
                                 [_hop(ctx, other, row)] + chain))

    # Подписи шагов - пакетом по таблицам: «Ссылки 34166» читается вдвое хуже,
    # чем «Ссылки · Sartharion (1)», а запросов на это уходит по два на
    # таблицу, а не по два на шаг.
    wanted: dict[str, set[int]] = {}
    for path in paths:
        for hop in path["chain"]:
            wanted.setdefault(hop["table"], set()).add(hop["entry"])
    marks: dict[str, tuple[dict, dict]] = {}
    for table_id, entries in wanted.items():
        marks[table_id] = (labels(table_id, sorted(entries)),
                           auto_names(table_id, sorted(entries)))

    for path in paths:
        chance = 100.0
        for hop in path["chain"]:
            chance *= hop["chance"] / 100.0
            store, autos = marks.get(hop["table"], ({}, {}))
            hop["label"] = _label_of(store, autos, hop["entry"])
        path["chance"] = round(chance, 4)

    paths.sort(key=lambda p: (-p["chance"], p["owner_kind"], p["owner_name"]))
    return {
        "item": _decorate_item(item, int(item_entry)),
        "paths": paths,
        "truncated": truncated,
        "limit": limit,
        "worn_drops_note": True,
    }


def _finish(chain: list[dict], table: LootTable, entry: int,
            owner: dict | None) -> dict:
    name = "—"
    if owner:
        name = owner.get("name_ru") or owner.get("name") or str(entry)
    elif table.id == REFERENCE.id:
        name = "ничья ссылка %d" % entry
    return {
        "owner_kind": owner["kind"] if owner else table.owner,
        "owner_entry": owner["entry"] if owner else entry,
        "owner_name": name,
        "owner": owner,
        "table": table.id,
        "table_name": table.name,
        "entry": entry,
        "chain": chain,
        "chance": 0.0,
    }


# --- сырой доступ --------------------------------------------------------

def table_entries(table_id: str, q: str = "", limit: int = 100) -> dict:
    """Список записей одной таблицы: номер, сколько строк, что внутри."""
    table = _table(table_id)
    where, args = "", []
    text = (q or "").strip()
    if text.isdigit():
        where = "WHERE `Entry` = %s"
        args.append(int(text))
    elif text:
        # Слова ищем среди ПОДПИСЕЙ: номера записей не гуглятся, а имена - да.
        # Автоимена сюда не попадают: они считаются из данных на лету, и
        # искать по ним значило бы посчитать их для всех восьми тысяч.
        ensure_schema()
        with paneldb.cursor() as cur:
            cur.execute(
                "SELECT DISTINCT `entry` FROM `loot_label` WHERE "
                "`table_id` = %s AND (`name` LIKE %s OR `note` LIKE %s)",
                (table.id, "%" + text + "%", "%" + text + "%"))
            hits = [int(r["entry"]) for r in cur.fetchall()]
        if not hits:
            return {"table": table.id, "name": table.name, "hint": table.hint,
                    "total": 0, "entries": [],
                    "note": "Среди подписанных записей ничего не нашлось. "
                            "Номер записи ищется числом."}
        where = "WHERE `Entry` IN (%s)" % ", ".join(["%s"] * len(hits))
        args.extend(hits)

    rows = query(
        "SELECT `Entry`, COUNT(*) AS rows_n, "
        "SUM(`Reference` <> 0) AS refs, SUM(`GroupId` <> 0) AS grouped "
        "FROM `%s` %s GROUP BY `Entry` ORDER BY `Entry` LIMIT %%s"
        % (table.table, where), tuple(args + [max(1, min(int(limit), 500))]))
    total = query_one("SELECT COUNT(DISTINCT `Entry`) AS n FROM `%s`"
                      % table.table)
    ids = [int(r["Entry"]) for r in rows]
    store = labels(table.id, ids)
    autos = auto_names(table.id, ids)
    return {
        "table": table.id, "name": table.name, "hint": table.hint,
        "total": int(total["n"]) if total else 0,
        "entries": [{"entry": int(r["Entry"]), "rows": int(r["rows_n"]),
                     "refs": int(r["refs"] or 0),
                     "grouped": int(r["grouped"] or 0),
                     "label": _label_of(store, autos, int(r["Entry"]))}
                    for r in rows],
    }


def meta() -> dict:
    counts = {}
    for table in LOOT_TABLES:
        row = query_one("SELECT COUNT(*) AS n FROM `%s`" % table.table)
        counts[table.id] = int(row["n"]) if row else 0
    return {
        "tables": [{"id": t.id, "name": t.name, "table": t.table,
                    "owner": t.owner, "hint": t.hint, "rows": counts[t.id]}
                   for t in LOOT_TABLES],
        "modes": LOOT_MODES,
        "ranks": RANKS,
        "max_depth": MAX_DEPTH,
    }


# --- правка строк ---------------------------------------------------------
#
# Пишем прямо в `acore_world_ptr` и никуда больше: выгрузки на live у этой
# страницы нет по решению владельца (2026-09-08), на боевой сервер правки
# уезжают снимком через live-deployer. Само соединение к тому же не умеет
# ходить в базу без суффикса `_ptr` - `config.check_ptr_only()` в `db.connect`.
#
# Ключ строки - (Entry, Item, Reference, GroupId), то есть смена группы или
# предмета МЕНЯЕТ КЛЮЧ. Поэтому правка приходит вместе со старым ключом и в
# таком случае выполняется как «удалить прежнюю, вставить новую», а не как
# UPDATE: иначе строка бы раздвоилась.


class Row(BaseModel):
    """Строка добычи. Ровно одно из двух: предмет ЛИБО ссылка."""

    item: int = Field(default=0, ge=0)
    reference: int = Field(default=0, ge=0)
    chance: float = Field(default=100, ge=0, le=100)
    quest: bool = False
    mode: int = Field(default=1, ge=1, le=65535)
    group: int = Field(default=0, ge=0, le=255)
    min: int = Field(default=1, ge=0, le=255)
    max: int = Field(default=1, ge=0, le=255)
    comment: str = ""
    # Прежний ключ - только при правке. Ноль в was_item и was_reference значит
    # «строка новая».
    was_item: int = Field(default=-1)
    was_reference: int = Field(default=-1)
    was_group: int = Field(default=-1)


def _row_exists(table: LootTable, entry: int, item: int, reference: int,
                group: int) -> bool:
    return bool(query_one(
        "SELECT 1 AS ok FROM `%s` WHERE `Entry` = %%s AND `Item` = %%s "
        "AND `Reference` = %%s AND `GroupId` = %%s" % table.table,
        (entry, item, reference, group)))


def _check_row(table: LootTable, entry: int, row: Row) -> list[str]:
    """Что не так со строкой. Пустой список - можно писать."""
    problems: list[str] = []

    if bool(row.item) == bool(row.reference):
        problems.append(
            "В строке или предмет, или ссылка - ровно одно из двух. "
            "При непустой ссылке ядро поле предмета не читает вовсе.")
        return problems

    if row.item and not query_one(
            "SELECT 1 AS ok FROM `item_template` WHERE `entry` = %s",
            (row.item,)):
        problems.append("Предмета %d нет в item_template." % row.item)

    if row.reference:
        if not query_one("SELECT 1 AS ok FROM `%s` WHERE `Entry` = %%s"
                         % REFERENCE.table, (row.reference,)):
            problems.append(
                "Ссылки %d нет в reference_loot_template: строка выглядела бы "
                "рабочей, а не давала бы ничего." % row.reference)
        if table.id == REFERENCE.id and row.reference == int(entry):
            problems.append("Ссылка на саму себя закольцует выдачу добычи.")

    if row.item:
        if row.min < 1:
            problems.append("Предмета выпадает хотя бы один: минимум от 1.")
        if row.max < row.min:
            problems.append("Максимум меньше минимума.")

    # Ноль вне группы значит «никогда»: в группе это законно (такие строки
    # делят остаток), а вне её - строка, которая не выпадет ни разу.
    if not row.group and row.chance <= 0:
        problems.append(
            "Шанс 0 вне группы значит «никогда». В группе ноль законен - там "
            "такие строки делят остаток поровну.")
    return problems


def _group_note(table: LootTable, entry: int, group: int) -> str:
    """Предупреждение про перебор шансов в группе. Не отказ - замечание."""
    if not group:
        return ""
    rows = query(
        "SELECT `Chance` FROM `%s` WHERE `Entry` = %%s AND `GroupId` = %%s"
        % table.table, (entry, group))
    explicit = sum(float(r["Chance"]) for r in rows if float(r["Chance"]) > 0)
    if explicit > 100:
        return ("В группе %d сумма заданных шансов %.1f %% - больше сотни. "
                "Ядро катит их по очереди, и до последних строк очередь не "
                "дойдёт." % (group, explicit))
    return ""


def save_row(table_id: str, entry: int, row: Row) -> dict:
    """Завести строку или переписать существующую."""
    table = _table(table_id)
    problems = _check_row(table, entry, row)
    if problems:
        raise LootError(problems[0])

    editing = row.was_item >= 0 and row.was_reference >= 0
    key_changed = editing and (
        row.was_item != row.item or row.was_reference != row.reference
        or row.was_group != row.group)

    if (not editing or key_changed) and _row_exists(
            table, entry, row.item, row.reference, row.group):
        raise LootError(
            "Такая строка в записи уже есть: ключ - это предмет, ссылка и "
            "группа вместе. Правьте её, а не заводите вторую.")

    with world_cursor(commit=True) as cur:
        if editing:
            cur.execute(
                "DELETE FROM `%s` WHERE `Entry` = %%s AND `Item` = %%s "
                "AND `Reference` = %%s AND `GroupId` = %%s" % table.table,
                (entry, row.was_item, row.was_reference, row.was_group))
        cur.execute(
            "INSERT INTO `%s` (`Entry`, `Item`, `Reference`, `Chance`, "
            "`QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, "
            "`Comment`) VALUES (%%s, %%s, %%s, %%s, %%s, %%s, %%s, %%s, %%s, "
            "%%s)" % table.table,
            (entry, row.item, row.reference, row.chance, int(row.quest),
             row.mode, row.group, row.min, row.max,
             (row.comment or "").strip()[:255] or None))

    return {"ok": True, "note": _group_note(table, entry, row.group)}


def delete_row(table_id: str, entry: int, item: int, reference: int,
               group: int) -> dict:
    table = _table(table_id)
    with world_cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM `%s` WHERE `Entry` = %%s AND `Item` = %%s "
            "AND `Reference` = %%s AND `GroupId` = %%s" % table.table,
            (entry, item, reference, group))
        gone = cur.rowcount
    if not gone:
        raise LootError("Такой строки в записи нет - обновите страницу.")
    _drop_empty_group_labels(table, entry)
    return {"ok": True, "deleted": gone}


def move_group(table_id: str, entry: int, source: int, target: int) -> dict:
    """Перенести все строки одной группы в другую.

    Собирать группу построчно - десяток правок и столько же шансов ошибиться;
    а «сделать группу» в добыче это и есть «поставить строкам общий номер».
    Перенос идёт одним запросом, но с проверкой: в целевой группе не должно
    оказаться двойника по предмету, иначе UPDATE упрётся в ключ.
    """
    table = _table(table_id)
    if source == target:
        raise LootError("Группа и так эта же.")
    if not 0 <= target <= 255:
        raise LootError("Номер группы бывает от 0 до 255.")

    clash = query(
        "SELECT a.`Item`, a.`Reference` FROM `%s` a JOIN `%s` b "
        "ON b.`Entry` = a.`Entry` AND b.`Item` = a.`Item` "
        "AND b.`Reference` = a.`Reference` "
        "WHERE a.`Entry` = %%s AND a.`GroupId` = %%s AND b.`GroupId` = %%s"
        % (table.table, table.table), (entry, source, target))
    if clash:
        raise LootError(
            "В группе %d уже есть та же строка (предмет %d): ключ совпадёт."
            % (target, int(clash[0]["Item"]) or int(clash[0]["Reference"])))

    with world_cursor(commit=True) as cur:
        cur.execute(
            "UPDATE `%s` SET `GroupId` = %%s WHERE `Entry` = %%s "
            "AND `GroupId` = %%s" % table.table, (target, entry, source))
        moved = cur.rowcount

    # Подпись группы переезжает вместе со строками, иначе имя осталось бы у
    # пустого номера.
    ensure_schema()
    with paneldb.cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM `loot_label` WHERE `table_id` = %s AND `entry` = %s "
            "AND `kind` = 'group' AND `group_id` = %s",
            (table.id, entry, target))
        cur.execute(
            "UPDATE `loot_label` SET `group_id` = %s WHERE `table_id` = %s "
            "AND `entry` = %s AND `kind` = 'group' AND `group_id` = %s",
            (target, table.id, entry, source))

    if not moved:
        raise LootError("В группе %d нет ни одной строки." % source)
    _drop_empty_group_labels(table, entry)
    return {"ok": True, "moved": moved, "note": _group_note(table, entry, target)}


def _drop_empty_group_labels(table: LootTable, entry: int) -> None:
    """Снять подписи с групп, в которых не осталось ни строки.

    Группы как таблицы не существует - она живёт ровно до тех пор, пока хоть у
    одной строки стоит её номер. Имя, пережившее последнюю строку, всплыло бы
    на чужой группе, когда номер займут заново.
    """
    alive = {int(r["GroupId"]) for r in query(
        "SELECT DISTINCT `GroupId` FROM `%s` WHERE `Entry` = %%s"
        % table.table, (entry,))}
    ensure_schema()
    with paneldb.cursor(commit=True) as cur:
        cur.execute(
            "SELECT `group_id` FROM `loot_label` WHERE `table_id` = %s "
            "AND `entry` = %s AND `kind` = 'group'", (table.id, entry))
        for row in cur.fetchall():
            if int(row["group_id"]) not in alive:
                cur.execute(
                    "DELETE FROM `loot_label` WHERE `table_id` = %s AND "
                    "`entry` = %s AND `kind` = 'group' AND `group_id` = %s",
                    (table.id, entry, int(row["group_id"])))


class RowKey(BaseModel):
    """Ссылка на строку внутри записи: ключ без самой записи."""

    item: int = Field(default=0, ge=0)
    reference: int = Field(default=0, ge=0)
    group: int = Field(default=0, ge=0, le=255)


def collect_rows(table_id: str, entry: int, rows: list[RowKey],
                 target: int = 0, name: str = "", author: str = "") -> dict:
    """Собрать выбранные строки в группу - новую или указанную.

    Это и есть «сделать группу»: своей таблицы у групп нет, группа - это общий
    номер у нескольких строк. Ноль в `target` значит «первый свободный номер»,
    чтобы не заставлять человека помнить, какие заняты.
    """
    table = _table(table_id)
    if not rows:
        raise LootError("Не выбрано ни одной строки.")
    if target and not 1 <= target <= 255:
        raise LootError("Номер группы бывает от 1 до 255.")
    group = target or free_group(table_id, entry)

    # Ключ - предмет, ссылка и группа вместе, поэтому в целевой группе не
    # должно оказаться той же пары «предмет/ссылка»: UPDATE упрётся в ключ.
    for row in rows:
        if row.group == group:
            continue
        if _row_exists(table, entry, row.item, row.reference, group):
            raise LootError(
                "В группе %d уже есть эта же строка (предмет %d): ключ совпадёт."
                % (group, row.item or row.reference))

    moved = 0
    with world_cursor(commit=True) as cur:
        for row in rows:
            if row.group == group:
                continue
            cur.execute(
                "UPDATE `%s` SET `GroupId` = %%s WHERE `Entry` = %%s AND "
                "`Item` = %%s AND `Reference` = %%s AND `GroupId` = %%s"
                % table.table,
                (group, entry, row.item, row.reference, row.group))
            moved += cur.rowcount

    _drop_empty_group_labels(table, entry)
    if name.strip():
        save_label(table.id, entry, "group", group, name, "", author)

    return {"ok": True, "group": group, "moved": moved,
            "note": _group_note(table, entry, group)}


def free_group(table_id: str, entry: int) -> int:
    """Первый свободный номер группы в записи - для кнопки «новая группа»."""
    table = _table(table_id)
    used = {int(r["GroupId"]) for r in query(
        "SELECT DISTINCT `GroupId` FROM `%s` WHERE `Entry` = %%s"
        % table.table, (entry,))}
    for candidate in range(1, 256):
        if candidate not in used:
            return candidate
    raise LootError("В записи заняты все 255 групп.")


def reload_table(table_id: str) -> str:
    """Сказать миру перечитать таблицу: без этого правка ждёт рестарта."""
    table = _table(table_id)
    return soap.execute(".reload %s" % table.table)
