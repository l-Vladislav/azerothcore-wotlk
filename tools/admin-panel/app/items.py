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
    `Item.dbc` нужна под НОВЫЙ id. Панель синхронизирует её с клиентским
    оверлеем, а отдельный сборщик собирает из него MPQ по запросу владельца.

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

import csv
import os
import re
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
    # Разворот логики ковки (2026-09-02): основа отдаёт не вычисленный предмет,
    # а готовую строку item_template. Заводит их вкладка «Основы», а правятся
    # они здесь, обычным редактором предмета - иначе результат можно было бы
    # только создать, но не подкрутить.
    #
    # Блоки панели идут вразрядку, и выгрузка ходит по ним по одному, а не
    # одним диапазоном: между ними лежат чужие id. Ленивый пул модуля профессий
    # живёт отдельно, в 1 100 000 - 3 199 999, и панель ведёт только
    # КЛИЕНТСКУЮ его половину (см. pool_ranges ниже).
    #
    # Разворот 2026-09-07 (DESIGN §2.5): добыча становится основами, и блок
    # 180000 - 184999 держит теперь не «результаты рецептов», а сами ОСНОВЫ -
    # тип x качество x полоса уровня, 582 штуки на десять типов профессии,
    # плюс поделки. Именные предметы новых id не стоят вовсе: это существующие
    # предметы игры.
    Block(id="professions", name="Основы и поделки", lo=180000, hi=184999,
          summary="Основы: тип, качество и полоса уровня. Из основы куют или "
                  "выбивают вещь, а доводка вставками достраивает её до "
                  "именной. Здесь же серые поделки. На них ссылаются вещи в "
                  "сумках игроков — удалять нельзя, только править."),
    Block(id="materials", name="Материалы", lo=185000, hi=189999,
          summary="Слитки, доски, кожа для ячеек схемы и камни для гнёзд "
                  "доводки. Своими id заводятся только те, которых в игре "
                  "нет: копии под нужное качество и полосу уровня."),
    # Свои копии призов (2026-09-15). Ванильных вещей, годных в именные призы,
    # не хватило: после запрета квестовых наград свободных на всю игру осталось
    # 135, и лежали они не там, где нужно. Недостающие заводятся копиями - той
    # же вещи, пересчитанной под свою полосу; оригинал и его задание остаются
    # нетронутыми. Их пересобирает генератор эскизов на каждом прогоне, так что
    # правки руками переживут только до следующего.
    Block(id="prizes", name="Копии призов", lo=175000, hi=179999,
          summary="Именные вещи, которых игра не дала: копия ванильного "
                  "предмета с числами своей полосы. Имя - оригинала с уровнем "
                  "в скобках. Пересобираются генератором эскизов."),
    Block(id="books", name="Книги рецептов", lo=190000, hi=199999,
          summary="Обучающие предметы: книга даёт рецепт основы, набора "
                  "вставок или объединения. Угаданный рецепт книги не "
                  "требует — она второй путь, а не единственный."),
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


# --- слайсы пула профессий -------------------------------------------------
# Заготовки ленивого пула (DESIGN §4) панель не редактирует: строки там
# служебные, их заполняет сервер в памяти при выдаче. А вот КЛИЕНТСКУЮ их
# половину вести приходится ей: без строки в Item.dbc доведённая вещь
# приезжает игроку без трёхмерного вида - знаком вопроса.
#
# Границы живут у ОСНОВЫ (`ap_recipe_result.pool_lo/pool_hi`, v25), потому что
# слайс у каждой основы свой и вид в его строках - свой: копия бронзового
# клинка обязана брать id из бронзовых.
POOL_LO = 1100000
POOL_HI = 3199999


def pool_ranges() -> list[tuple[int, int]]:
    """Что панель считает пулом при выгрузке в клиент.

    Блок целиком, а не поимённо по слайсам основ. Разница не косметическая: по
    диапазону решается, какую строку прежнего CSV ВЫБРОСИТЬ, и узкий список
    слайсов оставил бы навсегда всё, что осталось от прежней нарезки. Строк
    сверх нужного это не добавит - выгрузка берёт только те id, у которых есть
    строка `item_template`, а её заводит миграция.
    """
    return [(POOL_LO, POOL_HI)]


def in_pool(entry: int, ranges: list[tuple[int, int]]) -> bool:
    for lo, hi in ranges:
        if lo <= entry <= hi:
            return True
    return False


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

# Подклассы по классу (ItemSubclass*, 3.3.5a) - для отбора в окнах выбора.
# Только классы, где подкласс что-то говорит человеку: вид оружия, материал
# брони, цвет самоцвета, род хозяйственного товара.
ITEM_SUBCLASS = {
    2: {0: "Топор (одноручный)", 1: "Топор (двуручный)", 2: "Лук",
        3: "Огнестрельное", 4: "Дробящее (одноручное)", 5: "Дробящее (двуручное)",
        6: "Древковое", 7: "Меч (одноручный)", 8: "Меч (двуручный)", 10: "Посох",
        13: "Кистевое", 14: "Разное", 15: "Кинжал", 16: "Метательное",
        17: "Копье", 18: "Арбалет", 19: "Жезл", 20: "Удочка"},
    3: {0: "Красный", 1: "Синий", 2: "Желтый", 3: "Фиолетовый", 4: "Зеленый",
        5: "Оранжевый", 6: "Особый", 7: "Простой", 8: "Радужный"},
    4: {0: "Разное", 1: "Ткань", 2: "Кожа", 3: "Кольчуга", 4: "Латы",
        6: "Щит", 7: "Манускрипт", 8: "Идол", 9: "Тотем", 10: "Печать"},
    7: {0: "Хозяйственные товары", 1: "Детали", 2: "Взрывчатка", 3: "Устройства",
        4: "Ювелирное дело", 5: "Ткань", 6: "Кожа", 7: "Металл и камень",
        8: "Мясо", 9: "Трава", 10: "Стихии", 11: "Прочее", 12: "Наложение чар",
        13: "Материалы", 14: "Улучшение доспехов", 15: "Улучшение оружия"},
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
        "itemSubclass": {str(cls): pairs(subs) for cls, subs in ITEM_SUBCLASS.items()},
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


def _fulltext_query(value: str) -> str | None:
    """Turn a human query into MySQL boolean full-text prefix terms.

    InnoDB does not index tokens below three characters by default. Those stay
    on the compatible LIKE path, while ordinary name fragments such as
    ``отме`` become ``+отме*`` and use the PTR-only catalogue indexes.
    """
    terms = re.findall(r"[^\W_]+", value, flags=re.UNICODE)
    if not terms or any(len(term) < 3 for term in terms):
        return None
    return " ".join("+%s*" % term for term in terms)


def search(q: str = "", block: str | None = None, quality: int | None = None,
           item_class: int | None = None, inventory_type: int | None = None,
           item_subclass: int | None = None,
           item_level_min: int | None = None, item_level_max: int | None = None,
           required_level_min: int | None = None, required_level_max: int | None = None,
           limit: int = 60, offset: int = 0) -> dict:
    """Поиск по имени или id.

    Русское имя ищется отдельным подзапросом по `item_template_locale`, а не
    джойном: джойн на 277 тысяч строк с LIKE по text-колонке заметно медленнее,
    а два узких запроса укладываются в сотни миллисекунд.
    """
    cols = ", ".join("`%s`" % c for c in _LIST_COLS)
    where: list[str] = []
    args: list[Any] = []
    fulltext: str | None = None
    from_clause = "`%s`" % TABLE

    needle = (q or "").strip()
    if needle:
        as_id = needle if needle.isdigit() else None
        if as_id:
            where.append("`entry` = %s")
            args.append(int(as_id))
        else:
            fulltext = _fulltext_query(needle)
            like = "%" + needle + "%"
            if fulltext:
                # An OR between MATCH expressions makes MySQL scan the item
                # table. First obtain matching IDs from each full-text index,
                # then join the small union to the catalogue rows.
                from_clause = (
                    "`%s` INNER JOIN ("
                    "SELECT `entry` AS `id` FROM `%s` "
                    "WHERE MATCH(`name`) AGAINST (%%s IN BOOLEAN MODE) "
                    "UNION "
                    "SELECT `ID` AS `id` FROM `%s` WHERE `locale` = %%s "
                    "AND MATCH(`Name`) AGAINST (%%s IN BOOLEAN MODE)"
                    ") AS `matches` ON `%s`.`entry` = `matches`.`id`"
                    % (TABLE, TABLE, LOCALE_TABLE, TABLE))
                args.extend([fulltext, RU, fulltext])
            else:
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

    if quality is not None:
        where.append("`Quality` = %s")
        args.append(quality)
    if item_class is not None:
        where.append("`class` = %s")
        args.append(item_class)
    if item_subclass is not None:
        where.append("`subclass` = %s")
        args.append(item_subclass)
    if inventory_type is not None:
        where.append("`InventoryType` = %s")
        args.append(inventory_type)
    if item_level_min is not None:
        where.append("`ItemLevel` >= %s")
        args.append(item_level_min)
    if item_level_max is not None:
        where.append("`ItemLevel` <= %s")
        args.append(item_level_max)
    if required_level_min is not None:
        where.append("`RequiredLevel` >= %s")
        args.append(required_level_min)
    if required_level_max is not None:
        where.append("`RequiredLevel` <= %s")
        args.append(required_level_max)

    clause = (" WHERE " + " AND ".join(where)) if where else ""

    total = query_one("SELECT COUNT(*) AS n FROM %s%s" % (from_clause, clause),
                      tuple(args))

    # A full-text index matches word prefixes. Keep the old substring behaviour
    # as a fallback for the uncommon case of a fragment in the middle of a word.
    if fulltext and not (total and total["n"]):
        like = "%" + needle + "%"
        where.insert(0, (
            "(`name` LIKE %s OR `entry` IN "
            "(SELECT `ID` FROM `%s` WHERE `locale` = %%s AND `Name` LIKE %%s))"
            % ("%s", LOCALE_TABLE)))
        args = [like, RU, like] + args[3:]
        from_clause = "`%s`" % TABLE
        clause = " WHERE " + " AND ".join(where)
        total = query_one("SELECT COUNT(*) AS n FROM %s%s" % (from_clause, clause),
                          tuple(args))
    rows = query(
        "SELECT %s FROM %s%s ORDER BY `entry` LIMIT %%s OFFSET %%s"
        % (cols, from_clause, clause), tuple(args + [int(limit), int(offset)]))

    return {
        "total": int(total["n"]) if total else 0,
        "offset": int(offset),
        "limit": int(limit),
        "items": _decorate(rows),
    }


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

    # Строка-результат основы, именной предмет или поделка - это обязательство
    # перед игроком, у которого вещь лежит в сумке: удалить её значит превратить
    # вещь в другую (DESIGN §4, решение 3). Импорт поздний - aprof сам берёт
    # отсюда иконки, и на уровне модуля вышел бы круг.
    from . import aprof
    used = aprof.references_to_item(entry)
    if used:
        raise ValueError(
            "Предмет %d занят крафтом: %s. Удалять нельзя - правьте строку "
            "или снимите ссылку на вкладке «Основы»." % (entry, "; ".join(used)))
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


def all_columns() -> list[str]:
    rows = query("SHOW COLUMNS FROM `%s`" % TABLE)
    return [r["Field"] for r in rows]


SQL_NAME = "admin_panel_items.sql"


def export_sql() -> dict:
    """Выгружает блок панели в отслеживаемую миграцию.

    Пишется целиком и атомарно (временный файл плюс замена): оборванная на
    середине миграция хуже отсутствующей — она применится наполовину.
    """
    cols = all_columns()
    col_list = ", ".join("`%s`" % c for c in cols)

    locales: list[dict] = []
    for blk in BLOCKS:
        locales.extend(query(
            "SELECT `ID`, `locale`, `Name`, `Description` FROM `%s` "
            "WHERE `ID` BETWEEN %%s AND %%s ORDER BY `ID`, `locale`"
            % LOCALE_TABLE, (blk.lo, blk.hi)))

    lines = [
        "-- Предметы панели — выгружено админ-панелью (Каталог предметов).",
        "-- Источник правды — acore_world_ptr.item_template, блоки %d-%d."
        % (BLOCK_LO, BLOCK_HI),
        "-- Правьте в панели, не здесь: следующая выгрузка перепишет файл.",
        "--",
        "-- Клиентская половина (Item.dbc внутри MPQ) сюда не входит:",
        "-- выгрузите её отдельно в клиентский оверлей и запустите сборку MPQ.",
        "",
    ]

    # По блоку на DELETE, а не одним диапазоном BLOCK_LO..BLOCK_HI: блоки
    # панели идут вразрядку, и общий диапазон снёс бы чужие id - в том числе
    # заготовки ленивого пула, из которых уже выданы вещи игрокам.
    for blk in BLOCKS:
        lines.append("DELETE FROM `item_template` WHERE `entry` BETWEEN "
                     "%d AND %d;" % (blk.lo, blk.hi))
        lines.append("DELETE FROM `item_template_locale` WHERE `ID` BETWEEN "
                     "%d AND %d;" % (blk.lo, blk.hi))
    lines.append("")

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
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")
    os.replace(tmp, path)

    return {"path": path, "items": len(rows), "locales": len(locales)}


CLIENT_COLUMNS = (
    "ID", "ClassID", "SubclassID", "Sound_Override_Subclassid", "Material",
    "DisplayInfoID", "InventoryType", "SheatheType",
)


def _client_row(entry: int) -> dict:
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
        "values": [str(value) for value in values],
    }


def export_client(entry: int) -> dict:
    """Return one Item.dbc row for inspection or copying."""
    row = _client_row(entry)
    if not row:
        return {}
    return {
        "entry": row["entry"],
        "header": ",".join('"%s"' % column for column in CLIENT_COLUMNS),
        "line": ",".join('"%s"' % value for value in row["values"]),
    }


def _client_wanted(pool: list[tuple[int, int]]) -> list[list[str]]:
    """Строки клиентского CSV, какими их видит база прямо сейчас."""
    # Заготовки пула идут в выгрузку наравне с блоками панели: клиентская
    # половина нужна и им, иначе доведённая вещь приезжает без вида.
    spans = [(b.lo, b.hi) for b in BLOCKS] + pool
    conditions = " OR ".join("`entry` BETWEEN %s AND %s" for _ in spans)
    args = tuple(value for span in spans for value in span)
    rows = query(
        "SELECT `entry`, `class`, `subclass`, `SoundOverrideSubclass`, "
        "`Material`, `displayid`, `InventoryType`, `sheath` FROM `%s` "
        "WHERE %s ORDER BY `entry`" % (TABLE, conditions),
        args,
    )
    return [[
        str(row["entry"]), str(row["class"]), str(row["subclass"]),
        str(row["SoundOverrideSubclass"]), str(row["Material"]),
        str(row["displayid"]), str(row["InventoryType"]), str(row["sheath"]),
    ] for row in rows]


def _client_split(pool: list[tuple[int, int]]) -> tuple[list, dict]:
    """Прочитать CSV: чужие строки отдельно, наши - по номеру предмета.

    Чужие сохраняются как есть: в файле живут строки других генераторов, и
    выгрузка предмета не имеет права их выбросить.
    """
    foreign: list[list[str]] = []
    ours: dict[str, list[str]] = {}
    path = config.ITEM_CUSTOM_CSV
    if not os.path.isfile(path):
        return foreign, ours
    with open(path, encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader, None)
        if header != list(CLIENT_COLUMNS):
            raise ValueError("Item_custom.csv имеет неизвестный заголовок.")
        for line in reader:
            try:
                entry = int(line[0])
            except (IndexError, ValueError):
                foreign.append(line)
                continue
            if block_of(entry) is None and not in_pool(entry, pool):
                foreign.append(line)
            else:
                ours[str(entry)] = line
    return foreign, ours


def client_pending() -> dict:
    """Чего из панели ещё нет в клиентском CSV или что там устарело.

    Счёт разделён: блоки панели правят руками и их единицы, а пул профессий
    наполняет генератор и его сотни тысяч. В общем числе второе полностью
    скрывает первое.
    """
    pool = pool_ranges()
    try:
        _, ours = _client_split(pool)
    except (OSError, ValueError) as exc:
        return {"known": False, "reason": str(exc)}

    groups = {
        "blocks": {"name": "Блоки панели", "missing": 0, "changed": 0, "total": 0},
        "pool": {"name": "Пул профессий", "missing": 0, "changed": 0, "total": 0},
    }
    for row in _client_wanted(pool):
        group = groups["blocks" if block_of(int(row[0])) else "pool"]
        group["total"] += 1
        if row[0] not in ours:
            group["missing"] += 1
        elif ours[row[0]] != row:
            group["changed"] += 1

    live = [g for g in groups.values() if g["total"]]
    return {
        "known": True,
        "missing": sum(g["missing"] for g in live),
        "changed": sum(g["changed"] for g in live),
        "total": sum(g["total"] for g in live),
        "groups": live,
    }


def export_client_csv() -> dict:
    """Synchronise panel-owned items into the Item.dbc overlay.

    The CSV can contain rows maintained by other generators. Only IDs belonging
    to a panel block are replaced, so saving a workshop item cannot discard
    unrelated client customisations. Removed panel items are omitted as well.
    """
    pool = pool_ranges()
    path = config.ITEM_CUSTOM_CSV
    existing, _ = _client_split(pool)
    generated = _client_wanted(pool)

    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(CLIENT_COLUMNS)
        writer.writerows(existing)
        writer.writerows(generated)
    os.replace(tmp, path)
    return {
        "path": path,
        "written": len(generated),
        "total": len(existing) + len(generated),
    }
