"""Каталог предметов — копирование, переименование и правка свойств.

Четыре факта определяют устройство этого модуля:

  * `item_template` в PTR — **277 290 строк и 130 колонок**. Отдавать её целиком
    нельзя ни в каком виде, поэтому наружу уходит только узкая проекция
    (id, имя, качество, уровень, иконка), а полный набор колонок читается
    по одному предмету.
  * Русские имена живут не там же: `item_template.name` — базовое имя, а
    `item_template_locale` с `locale = 'ruRU'` — то, что увидит русский клиент.
    Редактор ведёт оба, иначе переименованный предмет остался бы с английским
    именем ровно у тех, для кого его и переименовывали.
  * Иконка не хранится в БД вовсе: `item_template.displayid` ведёт в
    `ItemDisplayInfo.dbc` (поле `InventoryIcon_1`), а уже оттуда получается имя
    текстуры для того же конвейера иконок, что и в мастерской спеллов.
  * У предмета, как и у спелла, есть **клиентская половина**. Тултип и иконку
    клиент 3.3.5a спрашивает у сервера, а вот трёхмерный вид на персонаже,
    ножны и материал берёт из `Item.dbc` внутри MPQ. Копия существующего
    предмета переиспользует его `displayid`, так что арт уже есть, но строка в
    `Item.dbc` нужна под НОВЫЙ id. Панель её выдаёт (`export_client`), сборка
    MPQ остаётся ручной — ровно как со спеллами.

Диапазон id для панели — 120000-129999. Проверено по acore_world_ptr
(2026-08-25): в нём ноль предметов, тогда как соседние заняты — 100000-119999
это кастомные предметы и фамильяры, 345841-356762 gear-ascension,
400000-1099999 worn-drops.

Внутри он разделён на два блока, и это не формальность: предмет, лежащий в
мире, живёт по другим правилам — на него ссылается размещение, его нельзя
переименовать «просто так» и уж точно нельзя удалить, пока он где-то лежит.
Держать такие вперемешку с черновыми копиями значит однажды снести не тот.
По id блок виден сразу, без похода в другую таблицу.
"""

import os
from typing import Any

from pydantic import BaseModel

from . import config, dbcfile
from .db import cursor as world_cursor
from .db import query, query_one

TABLE = "item_template"
LOCALE_TABLE = "item_template_locale"
RU = "ruRU"

# --- блоки id -------------------------------------------------------------

class Block(BaseModel):
    id: str
    name: str
    lo: int
    hi: int
    summary: str


BLOCKS: list[Block] = [
    Block(id="workshop", name="Мастерская", lo=120000, hi=124999,
          summary="Копии и правки общего назначения: примерки, тесты, "
                  "заготовки."),
    Block(id="world", name="Мировые предметы", lo=125000, hi=129999,
          summary="Те, что кладутся на карту и лутаются один раз. На них "
                  "ссылаются размещения, поэтому удалять их опаснее."),
]

BLOCK_BY_ID = {b.id: b for b in BLOCKS}

# Границы всего, чем распоряжается панель, - для выгрузки и проверок.
BLOCK_LO = min(b.lo for b in BLOCKS)
BLOCK_HI = max(b.hi for b in BLOCKS)


def block_of(entry: int) -> Block | None:
    for block in BLOCKS:
        if block.lo <= entry <= block.hi:
            return block
    return None


# --- иконки ---------------------------------------------------------------
# ItemDisplayInfo.dbc — 57 986 строк по 25 полей. Открывается один раз и
# держится открытым: mmap, поэтому в память едут только затронутые страницы.

_display: dbcfile.DBC | None = None
_display_ready = False


def _display_dbc() -> dbcfile.DBC | None:
    global _display, _display_ready
    if not _display_ready:
        _display = dbcfile.open_dbc(config.DBC_DIR, "ItemDisplayInfo",
                                    dbcfile.ITEM_DISPLAY_INFO_COLUMNS)
        _display_ready = True
    return _display


def icon_texture(display_id: int) -> str:
    """`displayid` предмета → имя текстуры иконки, как их называет CDN."""
    dbc = _display_dbc()
    if not dbc or not display_id:
        return ""
    row = dbc.row_of(int(display_id))
    if row is None:
        return ""
    return str(dbc.value(row, "InventoryIcon_1") or "").lower()


def available() -> bool:
    """Смонтирован ли client-data. Без него каталог живёт, но без иконок."""
    return _display_dbc() is not None


# --- справочники ----------------------------------------------------------
# Названия к числовым колонкам. Ровно те, что видит глаз в тултипе; полный
# список классов предметов сюда не тащим - он огромный и в редакторе не нужен.

QUALITY = {0: "Серый", 1: "Белый", 2: "Зелёный", 3: "Синий", 4: "Фиолетовый",
           5: "Оранжевый", 6: "Артефакт", 7: "Наследуемый"}

BONDING = {0: "Не привязывается", 1: "При получении", 2: "При надевании",
           3: "При использовании", 4: "Квестовый", 5: "Кошелёк"}

INVENTORY_TYPE = {
    0: "Не надевается", 1: "Голова", 2: "Шея", 3: "Плечи", 4: "Рубаха",
    5: "Грудь", 6: "Пояс", 7: "Ноги", 8: "Ступни", 9: "Запястья", 10: "Кисти",
    11: "Палец", 12: "Аксессуар", 13: "Одноручное", 14: "Щит", 15: "Лук",
    16: "Плащ", 17: "Двуручное", 18: "Сумка", 19: "Гербовая накидка",
    20: "Грудь (роба)", 21: "Правая рука", 22: "Левая рука", 23: "Держится в руке",
    24: "Снаряды", 25: "Метательное", 26: "Стрелковое", 27: "Колчан",
    28: "Реликвия",
}

ITEM_CLASS = {
    0: "Расходуемое", 1: "Контейнер", 2: "Оружие", 3: "Самоцвет", 4: "Броня",
    5: "Реагент", 6: "Снаряды", 7: "Хозяйственные товары", 8: "Обычное",
    9: "Рецепт", 10: "Деньги", 11: "Колчан", 12: "Задание", 13: "Ключ",
    14: "Разное", 15: "Разное", 16: "Символ",
}

# Типы характеристик (ItemModType). Список тот же, что в StatBooster.
STAT_TYPE = {
    0: "-", 3: "Ловкость", 4: "Сила", 5: "Интеллект", 6: "Дух",
    7: "Выносливость", 12: "Рейтинг защиты", 13: "Уклонение",
    14: "Парирование", 15: "Блок", 31: "Меткость", 32: "Крит. удар",
    35: "Устойчивость", 36: "Скорость", 37: "Крит. урон", 38: "Крит. заклин.",
    43: "Восст. маны", 44: "Пробивание брони", 45: "Сила заклинаний",
    46: "Восст. здоровья", 47: "Пробивание закл.", 48: "Мощность блока",
}


def _f(col: str, kind: str = "int", label: str = "", **extra) -> dict:
    """Одно поле редактора. Каталог полей - данные, а не код: фронтенд рисует
    то, что ему прислали, и добавить поле - это одна строка здесь."""
    field = {"col": col, "kind": kind, "label": label or col}
    field.update(extra)
    return field


FIELD_GROUPS: list[dict] = [
    {
        "id": "identity", "name": "Основное",
        "fields": [
            _f("name", "text", "Имя (базовое)", width="wide"),
            _f("name_ru", "text", "Имя (русское)", width="wide",
               hint="Уходит в item_template_locale; именно его видит "
                    "русский клиент."),
            _f("description", "text", "Описание", width="wide"),
            _f("Quality", "enum", "Качество", options="quality"),
            _f("displayid", "int", "Внешний вид (displayid)",
               hint="Ключ в ItemDisplayInfo.dbc. Менять осмысленно только на "
                    "displayid другого предмета — иначе клиент не найдёт арт."),
            _f("class", "enum", "Класс", options="itemClass"),
            _f("subclass", "int", "Подкласс"),
            _f("InventoryType", "enum", "Слот", options="inventoryType"),
            _f("bonding", "enum", "Привязка", options="bonding"),
            _f("Material", "int", "Материал"),
            _f("sheath", "int", "Ножны"),
        ],
    },
    {
        "id": "limits", "name": "Требования и лимиты",
        "fields": [
            _f("ItemLevel", "int", "Уровень предмета"),
            _f("RequiredLevel", "int", "Требуемый уровень"),
            _f("AllowableClass", "int", "Маска классов", hint="-1 = все"),
            _f("AllowableRace", "int", "Маска рас", hint="-1 = все"),
            _f("maxcount", "int", "Максимум в сумке", hint="0 = без предела"),
            _f("stackable", "int", "Размер стопки"),
            _f("MaxDurability", "int", "Прочность"),
            _f("duration", "int", "Время жизни, с", hint="0 = вечный"),
            _f("BuyPrice", "int", "Цена покупки"),
            _f("SellPrice", "int", "Цена продажи"),
            _f("Flags", "int", "Флаги"),
            _f("FlagsExtra", "int", "Доп. флаги"),
        ],
    },
    {
        "id": "combat", "name": "Бой",
        "fields": [
            _f("dmg_min1", "float", "Урон, мин"),
            _f("dmg_max1", "float", "Урон, макс"),
            _f("dmg_type1", "int", "Школа урона"),
            _f("delay", "int", "Скорость, мс"),
            _f("armor", "int", "Броня"),
            _f("block", "int", "Блок"),
            _f("holy_res", "int", "Свет"),
            _f("fire_res", "int", "Огонь"),
            _f("nature_res", "int", "Природа"),
            _f("frost_res", "int", "Лёд"),
            _f("shadow_res", "int", "Тьма"),
            _f("arcane_res", "int", "Тайная магия"),
        ],
    },
]

# Характеристики и спеллы - повторяющиеся блоки, поэтому строятся циклом:
# писать 10 одинаковых пятёрок руками означает однажды ошибиться в индексе.
FIELD_GROUPS.append({
    "id": "stats", "name": "Характеристики",
    "repeat": 10, "repeat_label": "Слот %d",
    "fields": [
        _f("stat_type%d", "enum", "Тип", options="statType"),
        _f("stat_value%d", "int", "Значение"),
    ],
})

FIELD_GROUPS.append({
    "id": "spells", "name": "Спеллы",
    "repeat": 5, "repeat_label": "Спелл %d",
    "fields": [
        _f("spellid_%d", "int", "Спелл"),
        _f("spelltrigger_%d", "int", "Триггер",
           hint="0 при использовании, 1 постоянно, 2 при попадании"),
        _f("spellcharges_%d", "int", "Заряды"),
        _f("spellcooldown_%d", "int", "Откат, мс"),
        _f("spellppmRate_%d", "float", "PPM"),
        _f("spellcategory_%d", "int", "Категория"),
        _f("spellcategorycooldown_%d", "int", "Откат категории, мс"),
    ],
})


def enums() -> dict:
    """Справочники для выпадающих списков — одним ответом, как в мастерской."""
    def pairs(src: dict) -> list[dict]:
        return [{"value": k, "label": v} for k, v in sorted(src.items())]

    return {
        "quality": pairs(QUALITY),
        "bonding": pairs(BONDING),
        "inventoryType": pairs(INVENTORY_TYPE),
        "itemClass": pairs(ITEM_CLASS),
        "statType": pairs(STAT_TYPE),
    }


def editable_columns() -> list[str]:
    """Колонки item_template, которыми распоряжается редактор."""
    out: list[str] = []
    for group in FIELD_GROUPS:
        repeat = group.get("repeat", 0)
        for field in group["fields"]:
            col = field["col"]
            if col == "name_ru":            # живёт в другой таблице
                continue
            if repeat:
                out.extend(col % n for n in range(1, repeat + 1))
            else:
                out.append(col)
    return out


def field_catalogue() -> list[dict]:
    """FIELD_GROUPS с уже развёрнутыми повторами — фронтенду так проще."""
    out = []
    for group in FIELD_GROUPS:
        repeat = group.get("repeat", 0)
        if not repeat:
            out.append({"id": group["id"], "name": group["name"],
                        "rows": [{"label": "", "fields": group["fields"]}]})
            continue

        rows = []
        for n in range(1, repeat + 1):
            rows.append({
                "label": group["repeat_label"] % n,
                "fields": [dict(f, col=f["col"] % n) for f in group["fields"]],
            })
        out.append({"id": group["id"], "name": group["name"], "rows": rows})
    return out


# --- чтение ---------------------------------------------------------------

_LIST_COLS = ("entry", "name", "Quality", "ItemLevel", "RequiredLevel",
              "class", "subclass", "InventoryType", "displayid")


def _decorate(rows: list[dict]) -> list[dict]:
    """Добавляет к строкам списка русское имя и текстуру иконки."""
    if not rows:
        return []

    ids = [int(r["entry"]) for r in rows]
    marks = ", ".join(["%s"] * len(ids))
    locales = {
        int(r["ID"]): r["Name"]
        for r in query("SELECT `ID`, `Name` FROM `%s` WHERE `locale` = %%s "
                       "AND `ID` IN (%s)" % (LOCALE_TABLE, marks),
                       tuple([RU] + ids))
        if r.get("Name")
    }

    out = []
    for row in rows:
        entry = int(row["entry"])
        out.append({
            "entry": entry,
            "name": row["name"],
            "name_ru": locales.get(entry, ""),
            "quality": int(row["Quality"] or 0),
            "item_level": int(row["ItemLevel"] or 0),
            "required_level": int(row["RequiredLevel"] or 0),
            "class": int(row["class"] or 0),
            "subclass": int(row["subclass"] or 0),
            "inventory_type": int(row["InventoryType"] or 0),
            "display_id": int(row["displayid"] or 0),
            "icon": icon_texture(row["displayid"]),
            "block": (block_of(entry).id if block_of(entry) else None),
        })
    return out


def search(q: str = "", block: str | None = None, limit: int = 60,
           offset: int = 0) -> dict:
    """Поиск по имени или id.

    Русское имя ищется отдельным подзапросом по `item_template_locale`, а не
    джойном: джойн на 277 тысяч строк с LIKE по text-колонке заметно медленнее,
    а два узких запроса укладываются в сотни миллисекунд.
    """
    cols = ", ".join("`%s`" % c for c in _LIST_COLS)
    where: list[str] = []
    args: list[Any] = []

    needle = (q or "").strip()
    if needle:
        as_id = needle if needle.isdigit() else None
        if as_id:
            where.append("`entry` = %s")
            args.append(int(as_id))
        else:
            like = "%" + needle + "%"
            where.append(
                "(`name` LIKE %s OR `entry` IN "
                "(SELECT `ID` FROM `%s` WHERE `locale` = %%s AND `Name` LIKE %%s))"
                % ("%s", LOCALE_TABLE))
            args.extend([like, RU, like])

    if block == "custom":                     # всё, чем владеет панель
        where.append("`entry` BETWEEN %s AND %s")
        args.extend([BLOCK_LO, BLOCK_HI])
    elif block in BLOCK_BY_ID:
        blk = BLOCK_BY_ID[block]
        where.append("`entry` BETWEEN %s AND %s")
        args.extend([blk.lo, blk.hi])

    clause = (" WHERE " + " AND ".join(where)) if where else ""

    total = query_one("SELECT COUNT(*) AS n FROM `%s`%s" % (TABLE, clause),
                      tuple(args))
    rows = query(
        "SELECT %s FROM `%s`%s ORDER BY `entry` LIMIT %%s OFFSET %%s"
        % (cols, TABLE, clause), tuple(args + [int(limit), int(offset)]))

    return {"total": int(total["n"]) if total else 0, "items": _decorate(rows)}


def get(entry: int) -> dict | None:
    """Полная строка предмета плюс русское имя и иконка."""
    row = query_one("SELECT * FROM `%s` WHERE `entry` = %%s" % TABLE, (entry,))
    if not row:
        return None

    loc = query_one("SELECT `Name`, `Description` FROM `%s` WHERE `ID` = %%s "
                    "AND `locale` = %%s" % LOCALE_TABLE, (entry, RU))

    fields = {c: row.get(c) for c in editable_columns()}
    fields["name_ru"] = (loc or {}).get("Name") or ""

    entry_id = int(row["entry"])
    blk = block_of(entry_id)
    return {
        "entry": entry_id,
        "block": blk.id if blk else None,
        "icon": icon_texture(row.get("displayid")),
        "fields": fields,
    }


def next_free_id(block_id: str = "workshop") -> int | None:
    """Первый свободный id в указанном блоке."""
    blk = BLOCK_BY_ID.get(block_id)
    if not blk:
        return None

    used = {int(r["entry"]) for r in
            query("SELECT `entry` FROM `%s` WHERE `entry` BETWEEN %%s AND %%s"
                  % TABLE, (blk.lo, blk.hi))}
    for candidate in range(blk.lo, blk.hi + 1):
        if candidate not in used:
            return candidate
    return None


def block_status() -> list[dict]:
    """Занятость каждого блока — панель показывает её рядом с выбором блока."""
    out = []
    for blk in BLOCKS:
        row = query_one("SELECT COUNT(*) AS n FROM `%s` WHERE `entry` BETWEEN "
                        "%%s AND %%s" % TABLE, (blk.lo, blk.hi))
        used = int(row["n"]) if row else 0
        out.append({
            "id": blk.id, "name": blk.name, "summary": blk.summary,
            "lo": blk.lo, "hi": blk.hi, "used": used,
            "free": blk.hi - blk.lo + 1 - used,
            "next": next_free_id(blk.id),
        })
    return out


def clone_draft(source_id: int, block_id: str = "workshop") -> dict:
    """Черновик копии: все поля исходника, новый id, имя с пометкой."""
    src = get(source_id)
    if not src:
        return {}

    blk = BLOCK_BY_ID.get(block_id)
    if not blk:
        raise ValueError("Неизвестный блок id: %s" % block_id)

    entry = next_free_id(block_id)
    if entry is None:
        raise ValueError("В блоке «%s» (%d-%d) не осталось свободных id."
                         % (blk.name, blk.lo, blk.hi))

    fields = dict(src["fields"])
    base_ru = fields.get("name_ru") or ""
    fields["name"] = ("%s (копия)" % (fields.get("name") or ""))[:255]
    if base_ru:
        fields["name_ru"] = ("%s (копия)" % base_ru)[:255]

    return {"entry": entry, "source": source_id, "block": blk.id,
            "icon": src["icon"], "fields": fields}


# --- запись ---------------------------------------------------------------

def _guard(entry: int) -> None:
    """Панель правит только свой блок.

    Разрешать правку стоковых предметов означало бы разойтись с базой ядра
    молча и навсегда: следующий импорт мира затрёт правку, а откуда взялось
    расхождение - уже не вспомнить. Копия в своём блоке от этого свободна.
    """
    if block_of(entry) is None:
        raise ValueError(
            "Предмет %d вне блоков панели (%d-%d). Стоковые предметы не "
            "правятся — сделайте копию." % (entry, BLOCK_LO, BLOCK_HI))


def save(entry: int, fields: dict[str, Any]) -> dict:
    """Создаёт или обновляет предмет в блоке панели."""
    _guard(entry)

    name_ru = str(fields.pop("name_ru", "") or "").strip()
    clean = {c: fields[c] for c in editable_columns() if c in fields}

    if not str(clean.get("name") or "").strip():
        raise ValueError("У предмета должно быть базовое имя.")

    exists = query_one("SELECT `entry` FROM `%s` WHERE `entry` = %%s" % TABLE,
                       (entry,))

    with world_cursor(commit=True) as cur:
        if exists:
            sets = ", ".join("`%s` = %%s" % c for c in clean)
            cur.execute("UPDATE `%s` SET %s WHERE `entry` = %%s"
                        % (TABLE, sets), tuple(clean.values()) + (entry,))
        else:
            cols = ", ".join("`%s`" % c for c in ["entry"] + list(clean))
            marks = ", ".join(["%s"] * (len(clean) + 1))
            cur.execute("INSERT INTO `%s` (%s) VALUES (%s)"
                        % (TABLE, cols, marks),
                        (entry,) + tuple(clean.values()))

        # Русское имя: пустое - убираем строку локали совсем, иначе клиент
        # показал бы пустое имя вместо базового.
        if name_ru:
            cur.execute(
                "REPLACE INTO `%s` (`ID`, `locale`, `Name`, `Description`) "
                "VALUES (%%s, %%s, %%s, %%s)" % LOCALE_TABLE,
                (entry, RU, name_ru, str(clean.get("description") or "")))
        else:
            cur.execute("DELETE FROM `%s` WHERE `ID` = %%s AND `locale` = %%s"
                        % LOCALE_TABLE, (entry, RU))

    return get(entry) or {}


def delete(entry: int) -> None:
    _guard(entry)
    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `entry` = %%s" % TABLE, (entry,))
        cur.execute("DELETE FROM `%s` WHERE `ID` = %%s" % LOCALE_TABLE, (entry,))


# --- выгрузка -------------------------------------------------------------

def _sql_literal(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, (int, float)):
        return repr(value)
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def _all_columns() -> list[str]:
    rows = query("SHOW COLUMNS FROM `%s`" % TABLE)
    return [r["Field"] for r in rows]


SQL_NAME = "admin_panel_items.sql"


def export_sql() -> dict:
    """Выгружает блок панели в отслеживаемую миграцию.

    Пишется целиком и атомарно (временный файл плюс замена): оборванная на
    середине миграция хуже отсутствующей — она применится наполовину.
    """
    cols = _all_columns()
    col_list = ", ".join("`%s`" % c for c in cols)

    locales = query("SELECT `ID`, `locale`, `Name`, `Description` FROM `%s` "
                    "WHERE `ID` BETWEEN %%s AND %%s ORDER BY `ID`, `locale`"
                    % LOCALE_TABLE, (BLOCK_LO, BLOCK_HI))

    lines = [
        "-- Предметы панели — выгружено админ-панелью (Каталог предметов).",
        "-- Источник правды — acore_world_ptr.item_template, блоки %d-%d."
        % (BLOCK_LO, BLOCK_HI),
        "-- Правьте в панели, не здесь: следующая выгрузка перепишет файл.",
        "--",
        "-- Клиентская половина (Item.dbc внутри MPQ) сюда не входит: её",
        "-- выдаёт кнопка «Строка для Item.dbc», сборка MPQ ручная.",
        "",
        "DELETE FROM `item_template` WHERE `entry` BETWEEN %d AND %d;"
        % (BLOCK_LO, BLOCK_HI),
        "DELETE FROM `item_template_locale` WHERE `ID` BETWEEN %d AND %d;"
        % (BLOCK_LO, BLOCK_HI),
        "",
    ]

    rows: list[dict] = []
    for blk in BLOCKS:
        part = query("SELECT %s FROM `%s` WHERE `entry` BETWEEN %%s AND %%s "
                     "ORDER BY `entry`" % (col_list, TABLE), (blk.lo, blk.hi))
        if not part:
            continue

        lines.append("-- %s (%d): %d-%d — %s"
                     % (blk.name, len(part), blk.lo, blk.hi, blk.summary))
        for row in part:
            values = ", ".join(_sql_literal(row[c]) for c in cols)
            lines.append("INSERT INTO `item_template` (%s)\n  VALUES (%s);"
                         % (col_list, values))
        lines.append("")
        rows.extend(part)

    if locales:
        lines.append("")
        for row in locales:
            lines.append(
                "INSERT INTO `item_template_locale` "
                "(`ID`, `locale`, `Name`, `Description`)\n  "
                "VALUES (%s, %s, %s, %s);"
                % (_sql_literal(row["ID"]), _sql_literal(row["locale"]),
                   _sql_literal(row["Name"]), _sql_literal(row["Description"])))

    path = os.path.join(os.path.dirname(config.SEED_SQL), SQL_NAME)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")
    os.replace(tmp, path)

    return {"path": path, "items": len(rows), "locales": len(locales)}


def export_client(entry: int) -> dict:
    """Строка для клиентского `Item.dbc` — восемь полей, как в Item.csv.

    Без неё предмет остаётся без трёхмерного вида на персонаже и без ножен:
    тултип и иконку клиент спрашивает у сервера, а вот эти три вещи берёт
    из своей DBC.
    """
    row = query_one(
        "SELECT `entry`, `class`, `subclass`, `SoundOverrideSubclass`, "
        "`Material`, `displayid`, `InventoryType`, `sheath` FROM `%s` "
        "WHERE `entry` = %%s" % TABLE, (entry,))
    if not row:
        return {}

    values = [row["entry"], row["class"], row["subclass"],
              row["SoundOverrideSubclass"], row["Material"], row["displayid"],
              row["InventoryType"], row["sheath"]]

    return {
        "entry": int(row["entry"]),
        "header": ('"ID","ClassID","SubclassID","Sound_Override_Subclassid",'
                   '"Material","DisplayInfoID","InventoryType","SheatheType"'),
        "line": ",".join('"%s"' % v for v in values),
    }
