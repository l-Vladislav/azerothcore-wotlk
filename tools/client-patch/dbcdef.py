"""Раскладки DBC из определений WDBX Editor (WotLK 3.3.5, билд 12340).

Файл defs/WotLK-3.3.5-12340.xml взят из WDBX Editor. Он же используется
редактором при экспорте и импорте CSV, поэтому колонки нашего CSV-оверлея
совпадают с тем, что владелец видит в WDBX, один в один.

Термины, которые дальше путаются, если их не развести:
  * колонка - то, что видно в CSV: "Effect_1", "Name_Lang_ruRU".
  * поле    - четыре байта в записи DBC. Колонка типа loc занимает 17 полей
              (16 локалей + маска), ulong - два, остальные - одно.
"""

import os
import xml.etree.ElementTree as ET

_HERE = os.path.dirname(os.path.abspath(__file__))
DEFS_PATH = os.path.join(_HERE, "defs", "WotLK-3.3.5-12340.xml")
# Поправки поверх WDBX - см. комментарий в самом файле.
OVERRIDES_PATH = os.path.join(_HERE, "defs", "overrides.xml")

LOCALE_SLOTS = 16
LOCALE_FIELDS = LOCALE_SLOTS + 1

# Порядок локалей в 3.3.5a. Русский клиент пишет строку в слот 8 - тот, что
# WDBX подписывает как zhTW. Отсюда известная ловушка "ruRU = enUS + 8".
LOCALE_NAMES = ["enUS", "enGB", "koKR", "frFR", "deDE", "enCN", "zhCN",
                "enTW", "zhTW", "esES", "esMX", "ruRU", "ptPT", "ptBR",
                "itIT", "Unk"]
LOCALE_RURU_SLOT = 8

_FIELDS_PER_TYPE = {
    "int": 1, "uint": 1, "float": 1, "string": 1, "bool": 1, "byte": 1,
    "loc": LOCALE_FIELDS, "ulong": 2,
}


class DefError(RuntimeError):
    pass


class Column:
    """Одна колонка CSV и её место в записи DBC."""

    __slots__ = ("name", "type", "field", "fields", "is_index")

    def __init__(self, name, type_, field, fields, is_index):
        self.name = name
        self.type = type_
        self.field = field        # индекс первого поля записи
        self.fields = fields      # сколько полей занимает
        self.is_index = is_index

    def __repr__(self):
        return "<%s %s @%d>" % (self.name, self.type, self.field)


class Table:
    """Раскладка одного .dbc."""

    def __init__(self, name, columns, field_count):
        self.name = name
        self.columns = columns
        self.field_count = field_count
        self.by_name = {c.name: c for c in columns}

    @property
    def record_size(self):
        return self.field_count * 4


def _expand(table_el):
    columns = []
    field = 0
    for el in table_el.findall("Field"):
        name = el.get("Name")
        type_ = el.get("Type")
        if type_ not in _FIELDS_PER_TYPE:
            raise DefError("%s.%s: неизвестный тип %r"
                           % (table_el.get("Name"), name, type_))
        width = _FIELDS_PER_TYPE[type_]
        count = int(el.get("ArraySize") or 1)
        is_index = (el.get("IsIndex") == "true")
        for n in range(count):
            label = name if count == 1 else "%s_%d" % (name, n + 1)
            if type_ == "loc":
                # loc разворачивается в 17 колонок CSV, как это делает WDBX.
                for slot, loc in enumerate(LOCALE_NAMES):
                    columns.append(Column("%s_%s" % (label, loc), "locslot",
                                          field + slot, 1, False))
                columns.append(Column("%s_Mask" % label, "uint",
                                      field + LOCALE_SLOTS, 1, False))
            else:
                columns.append(Column(label, type_, field, width, is_index))
            field += width
    return columns, field


_cache = {}


def table(name):
    """Раскладка по имени таблицы ("Spell", "Item", ...)."""
    if not _cache:
        for path in (DEFS_PATH, OVERRIDES_PATH):
            if not os.path.isfile(path):
                continue
            for el in ET.parse(path).getroot().findall("Table"):
                columns, field_count = _expand(el)
                _cache[el.get("Name").lower()] = Table(
                    el.get("Name"), columns, field_count)
    found = _cache.get(name.lower())
    if found is None:
        raise DefError("нет определения таблицы %r в %s" % (name, DEFS_PATH))
    return found


def tables():
    table("Spell")          # прогреть кэш
    return sorted(t.name for t in _cache.values())
