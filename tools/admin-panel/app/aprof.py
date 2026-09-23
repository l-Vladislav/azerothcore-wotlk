"""mod-advanced-professions: справочники и содержание хардкорного крафта.

Что здесь редактируется (всё в acore_world, миграции v1-v15):

    ap_item_type       типы предметов и схема их ячеек (ap_type_part)
    ap_material        материалы: что кладут в ячейку и что вставляют в слот
    ap_recipe          рецепт: точный набор предметов -> готовые изделия
    ap_synergy         именные сочетания вставок -> именной предмет
    ap_quality         качество -> число слотов доводки
    ap_quality_chance  глобальные проценты качества при ковке
    ap_config          числа модуля (кривая шанса, возврат, сборка мусора)
    ap_generated_item  что уже выдано из пула доводки (только чтение)

У страницы две работы, и вторая появилась с разворотом 2026-09-02
(DESIGN §2.2). Первая прежняя: **вся числовая часть крафта живёт в базе, а не
в C++** - новый камень это строка в таблице, а не сборка worldserver. Вторая -
панель **сочиняет содержание**: основа со своим готовым изделием и именной
предмет заводятся здесь целиком, включая строки item_template в блоке
180000-184999 (§8).

Формулы, считавшей предмет из свойств материалов, больше нет. Ковка сравнивает
набор в ячейках с основой ТОЧНО и выдаёт заранее заведённую строку; вставка
складывает сырые статы камней. Поэтому `match()` не «считает предмет», а
показывает, какая основа совпала и с каким шансом она выйдет.
"""

import bisect
import math
import re
from typing import Any

from pydantic import BaseModel, Field

from . import items
from .db import cursor as world_cursor
from .db import query, query_one

T_MATERIAL = "ap_material"
T_SYNERGY = "ap_synergy"
T_QUALITY = "ap_quality"
T_CHANCE = "ap_quality_chance"
T_CONFIG = "ap_config"
# Лестница полос. Панель её пока только ЧИТАЕТ - правит её генератор сетки
# (v32), и всякая правка руками живёт до следующего прогона цепочки.
T_BAND = "ap_band"
T_TYPE = "ap_item_type"
T_MERGE = "ap_merge"
T_MERGE_ITEM = "ap_merge_item"
T_PART = "ap_type_part"
T_GENERATED = "ap_generated_item"
T_ILVL = "ap_ilvl_level"
T_PART_KIND = "ap_part_kind"
T_INSERT_TYPE = "ap_insert_type"

MAX_SLOTS = 5
# Ступеней качества пять: от обычного до легендарного. Столько же строк в
# ap_quality, и столько же гнёзд даёт верхняя ступень.
MAX_QUALITY = 5

# Разделители протокола ".aprof": двоеточие делит поля, табуляция склеивает
# строки в пачку. Текст с ними внутри разъезжается у аддона на разборе, причём
# молча - поэтому не пускаем их в тексты здесь, до записи в базу (DESIGN §7,
# решение 8).
FORBIDDEN_IN_TEXT = (":", "\t", "\n", "\r")


def _bump_static_version() -> None:
    """Сказать клиентам, что тексты справочника изменились.

    С протокола 6 подписи типов и частей, названия корзин и качеств живут в
    аддоне, а сервер шлёт числа (DESIGN §7, решение 7). Экономия эта имеет
    цену: правка отсюда расходится с тем, что знает клиент, и игрок увидит
    схему от старого справочника, ничего не заподозрив.

    Поэтому у статики есть версия. Сервер везёт её в каждом ответе, аддон
    сверяет со своей и, разойдясь, забирает тексты с сервера сам. Ждать выката
    аддона через лаунчер не нужно - нужно только не забыть поднять это число,
    чем и занимается эта функция.
    """
    with world_cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO `%s` (`name`, `value`, `comment`) "
            "VALUES ('static_version', '2', %%s) "
            "ON DUPLICATE KEY UPDATE `value` = CAST(`value` AS UNSIGNED) + 1"
            % T_CONFIG,
            ("Версия статики окна (тексты типов, частей, корзин): аддон "
             "сверяет её со своей",))


def _bump_catalog_version() -> None:
    """Сказать клиентам, что каталог окна изменился.

    Каталог - это справочники родов и типов вставки, типы предметов с ячейками,
    список материалов и фильтры вставок у основ: всё, что у игроков
    одинаково и правится только отсюда. С протокола 17 он не едет на каждое
    открытие верстака, а лежит у аддона в SavedVariables и спрашивается лишь
    при расхождении версий (DESIGN §7, «Кэш каталога»). Иначе 554 материала и
    582 основы - это под сотню чат-пакетов на каждое нажатие.

    Цена та же, что у версии текстов: не поднимешь число - игрок будет
    открывать окно со вчерашним справочником, ничего не заподозрив. Поэтому
    зовём отсюда всюду, где каталог мог сдвинуться, и лишний раз тут дешевле
    пропущенного: цена ошибки в одну сторону - один лишний ответ с полным
    справочником, в другую - молча неверное окно.
    """
    with world_cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO `%s` (`name`, `value`, `comment`) "
            "VALUES ('catalog_version', '2', %%s) "
            "ON DUPLICATE KEY UPDATE `value` = CAST(`value` AS UNSIGNED) + 1"
            % T_CONFIG,
            ("Версия каталога окна (справочники, типы, ячейки, материалы, "
             "фильтры): аддон держит его в кэше и просит при расхождении",))


def _clean_text(value: str, field: str) -> str:
    text = (value or "").strip()
    for bad in FORBIDDEN_IN_TEXT:
        if bad in text:
            name = {":": "двоеточие", "\t": "табуляция"}.get(bad, "перевод строки")
            raise ApError(
                "%s: уберите %s — этим символом протокол делит поля, и аддон "
                "покажет обрывок вместо текста." % (field, name))
    return text

# Номера статов — те же, что в item_template.stat_type* (ITEM_MOD_*). Список
# намеренно короткий: это то, что имеет смысл вешать на крафтовую вставку.
STATS = {
    0: "—",
    3: "Ловкость",
    4: "Сила",
    5: "Интеллект",
    6: "Дух",
    7: "Выносливость",
    12: "Рейтинг защиты",
    13: "Уклонение",
    14: "Парирование",
    15: "Блок",
    31: "Меткость",
    32: "Критический удар",
    36: "Скорость",
    38: "Сила атаки",
    44: "Пробивание брони",
    45: "Сила заклинаний",
}

# Род материала и тип вставки живут в базе, а не здесь: завести «кость» не
# должно стоить правки панели, модуля и пересборки worldserver (DESIGN §2.5).
# Справочника два, и разведены они нарочно - «дерево» гнезду доводки не нужно
# никогда, «самоцвет» ячейке ковки тоже:
#
#     роль «на основу» -> род         -> ap_part_kind
#     роль «в слот»    -> тип вставки -> ap_insert_type


class DictRow(BaseModel):
    """Строка любого из двух справочников: форма у них одна."""

    id: int = Field(default=0, ge=0)
    code: str = ""
    name_ru: str = ""
    sort: int = Field(default=0, ge=0, le=9999)
    enabled: bool = True


def _dict_rows(table: str) -> list[dict]:
    _require()
    return [{"id": int(r["id"]), "code": r["code"], "name_ru": r["name_ru"],
             "sort": int(r["sort"]), "enabled": bool(r["enabled"])}
            for r in query("SELECT `id`, `code`, `name_ru`, `sort`, `enabled` "
                           "FROM `%s` ORDER BY `sort`, `id`" % table)]


def part_kinds() -> list[dict]:
    return _dict_rows(T_PART_KIND)


def insert_types() -> list[dict]:
    return _dict_rows(T_INSERT_TYPE)


def _dict_names(table: str) -> dict[int, str]:
    return {r["id"]: (r["name_ru"] or r["code"] or ("строка %d" % r["id"]))
            for r in _dict_rows(table)}


def _dict_name(table: str, row_id: int) -> str:
    """Как строка справочника зовётся. Ноль и мусор не прячем: незаполненный
    род - это недоделка, и в тексте отказа она должна быть видна."""
    if not row_id:
        return "не задан"
    return _dict_names(table).get(int(row_id), "неизвестный (%d)" % row_id)


def save_dict_row(table: str, row: DictRow) -> dict:
    _require()
    row.code = _clean_text(row.code, "Код")
    row.name_ru = _clean_text(row.name_ru, "Имя")
    if not row.code or not row.code.replace("_", "").isalnum():
        raise ApError("Код - латиница, цифры и подчёркивание: он уезжает в "
                      "миграции и в логи.")
    if not row.name_ru:
        raise ApError("Имя видит владелец в панели и игрок в подсказке.")

    clash = query_one("SELECT `id` FROM `%s` WHERE `code` = %%s" % table,
                      (row.code,))
    if clash and (not row.id or int(clash["id"]) != row.id):
        raise ApError("Код «%s» уже занят строкой %d." % (row.code,
                                                          int(clash["id"])))

    with world_cursor(commit=True) as cur:
        if row.id:
            cur.execute(
                "UPDATE `%s` SET `code` = %%s, `name_ru` = %%s, `sort` = %%s, "
                "`enabled` = %%s WHERE `id` = %%s" % table,
                (row.code, row.name_ru, row.sort, int(row.enabled), row.id))
        else:
            cur.execute(
                "INSERT INTO `%s` (`code`, `name_ru`, `sort`, `enabled`) "
                "VALUES (%%s, %%s, %%s, %%s)" % table,
                (row.code, row.name_ru, row.sort, int(row.enabled)))
            row.id = int(cur.lastrowid)
    _bump_catalog_version()
    return {"id": row.id}


def delete_dict_row(table: str, row_id: int) -> None:
    """Удалять можно только то, на что никто не ссылается.

    Молча удалённый род оставил бы ячейку с несуществующим номером: материалы
    ей больше не подойдут ни один, а по таблице это не видно - там останется
    пустое поле. Отказ с именем виноватого честнее.
    """
    _require()
    if table == T_PART_KIND:
        used = [m["name_ru"] or str(m["entry"]) for m in materials()
                if m["part_kind_id"] == row_id]
        cells = query(
            "SELECT `type_id`, `idx` FROM `%s` WHERE `part_kind_id` = %%s"
            % T_PART, (row_id,))
        if cells:
            used.append("ячеек схемы: %d" % len(cells))
    else:
        used = [m["name_ru"] or str(m["entry"]) for m in materials()
                if m["insert_type_id"] == row_id]

    if used:
        raise ApError("На эту строку ссылаются: %s%s."
                      % (", ".join(used[:5]),
                         " и ещё %d" % (len(used) - 5) if len(used) > 5 else ""))

    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `id` = %%s" % table, (row_id,))
    _bump_catalog_version()

ITEM_CLASSES = {2: "Оружие", 4: "Броня"}

WEAPON_SUBCLASSES = {0: "Топор", 1: "Топор двуручный", 4: "Булава",
                     5: "Булава двуручная", 6: "Древковое", 7: "Меч",
                     8: "Меч двуручный", 10: "Посох", 13: "Кастеты",
                     15: "Кинжал"}

ARMOR_SUBCLASSES = {1: "Ткань", 2: "Кожа", 3: "Кольчуга", 4: "Латы", 6: "Щит"}

# Заготовки для кнопки «Добавить тип»: разумные класс, подкласс и внешний вид,
# чтобы новый тип сразу выглядел собой, а не мечом с чужим подклассом. Дальше
# всё правится в таблице. Урон, броня и скорость сюда не входят вовсе - это
# свойства РЕЗУЛЬТАТА, они стоят в строке изделия (DESIGN §5.4).
TYPE_PRESETS = [
    {"id": "sword1h", "label": "Меч одноручный", "item_class": 2,
     "item_subclass": 7, "displayid": 3855},
    {"id": "sword2h", "label": "Меч двуручный", "item_class": 2,
     "item_subclass": 8, "displayid": 20071},
    {"id": "axe1h", "label": "Топор одноручный", "item_class": 2,
     "item_subclass": 0, "displayid": 14035},
    {"id": "axe2h", "label": "Топор двуручный", "item_class": 2,
     "item_subclass": 1, "displayid": 14035},
    {"id": "mace1h", "label": "Булава одноручная", "item_class": 2,
     "item_subclass": 4, "displayid": 5198},
    {"id": "dagger", "label": "Кинжал", "item_class": 2,
     "item_subclass": 15, "displayid": 20221},
    {"id": "staff", "label": "Посох", "item_class": 2,
     "item_subclass": 10, "displayid": 20071},
    {"id": "shield", "label": "Щит", "item_class": 4,
     "item_subclass": 6, "displayid": 18661},
    {"id": "gloves", "label": "Перчатки", "item_class": 4,
     "item_subclass": 4, "displayid": 9406},
    {"id": "belt", "label": "Пояс", "item_class": 4,
     "item_subclass": 4, "displayid": 25852},
    {"id": "shoulders", "label": "Наплечники", "item_class": 4,
     "item_subclass": 4, "displayid": 23531},
    {"id": "bracers", "label": "Наручи", "item_class": 4,
     "item_subclass": 4, "displayid": 6966},
]


class ApError(ValueError):
    """Отказ, который надо показать человеку, а не в лог."""


# --- наличие --------------------------------------------------------------

def available() -> bool:
    """Применена ли миграция. Без неё страница честно говорит, чего не хватает."""
    row = query_one(
        "SELECT 1 AS ok FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s LIMIT 1",
        (T_MATERIAL,))
    return bool(row)


def _has_column(table: str, column: str) -> bool:
    row = query_one(
        "SELECT 1 AS ok FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s "
        "AND COLUMN_NAME = %s LIMIT 1", (table, column))
    return bool(row)


def _has_table(table: str) -> bool:
    row = query_one(
        "SELECT 1 AS ok FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s LIMIT 1", (table,))
    return bool(row)


def _require() -> None:
    if not available():
        raise ApError(
            "Таблиц модуля нет. Примените "
            "data/sql/updates/pending_db_world/mod_advanced_professions_v1.sql")
    # Разворот 2026-09-02: основы, изделия и поделка.
    if not _has_column(T_RECIPE_NEW, "quality_min"):
        raise ApError(
            "Схема старой версии. Примените data/sql/updates/pending_db_world/"
            "mod_advanced_professions_v14_recipes.sql")
    # Снос легаси: без него панель писала бы в колонки, которых больше нет в
    # замысле, а сервер протокола 11 не прочитал бы схему вовсе.
    if _has_column(T_PART, "dmg_pct"):
        raise ApError(
            "Схема старой версии. Примените data/sql/updates/pending_db_world/"
            "mod_advanced_professions_v15_legacy_drop.sql")
    # Обязательные ячейки: панель их правит, сервер по ним отказывает в ковке.
    if not _has_column(T_PART, "required"):
        raise ApError(
            "Схема старой версии. Примените data/sql/updates/pending_db_world/"
            "mod_advanced_professions_v16_required_parts.sql")


# --- предметы -------------------------------------------------------------

def _item_info(entries: list[int]) -> dict[int, dict]:
    """Имя, качество и иконка по списку entry — из мировой базы.

    Русское имя берётся из item_template_locale: именно его увидит игрок, а
    `item_template.name` остаётся английским.
    """
    entries = sorted({int(e) for e in entries if e})
    if not entries:
        return {}
    marks = ", ".join(["%s"] * len(entries))
    rows = query(
        "SELECT `entry`, `name`, `Quality`, `displayid`, `ItemLevel` "
        "FROM `item_template` "
        "WHERE `entry` IN (%s)" % marks, tuple(entries))
    locales = {
        int(r["ID"]): r["Name"] for r in
        query("SELECT `ID`, `Name` FROM `item_template_locale` "
              "WHERE `locale` = 'ruRU' AND `ID` IN (%s)" % marks,
              tuple(entries)) if r.get("Name")
    }
    out = {}
    for row in rows:
        entry = int(row["entry"])
        out[entry] = {
            "entry": entry,
            "name": locales.get(entry) or row["name"] or "?",
            "quality": int(row["Quality"] or 0),
            "ilvl": int(row["ItemLevel"] or 0),
            "icon": items.icon_texture(row["displayid"] or 0),
        }
    return out


def _item_quality(entry: int) -> int:
    """Качество строки item_template. Ноль - серое либо предмета нет вовсе."""
    return int(_item_info([entry]).get(int(entry), {}).get("quality", 0))


def _item_exists(entry: int) -> bool:
    return bool(query_one("SELECT 1 AS ok FROM `item_template` WHERE `entry` = %s",
                          (entry,)))


# --- материалы ------------------------------------------------------------

class Material(BaseModel):
    entry: int = Field(gt=0)
    role: str = "insert"
    # Занят ровно один признак - тот, которому отвечает роль (DESIGN §2.5).
    part_kind_id: int = Field(default=0, ge=0)
    insert_type_id: int = Field(default=0, ge=0)
    stat_type: int = 0
    stat_value: int = Field(default=0, ge=0, le=1000)
    name_ru: str = ""
    enabled: bool = True
    # Единственное ограничение вставки: в какой предмет её пускают (DESIGN
    # §5.7). Ноль в любой границе - «ограничения нет».
    ilvl_min: int = Field(default=0, ge=0, le=300)
    ilvl_max: int = Field(default=0, ge=0, le=300)
    # Границы КАЧЕСТВА вещи-цели. Пока обе нули, действует строгое совпадение
    # с качеством самого камня (DESIGN §2.5).
    quality_min: int = Field(default=0, ge=0, le=MAX_QUALITY)
    quality_max: int = Field(default=0, ge=0, le=MAX_QUALITY)


def materials() -> list[dict]:
    _require()
    rows = query(
        "SELECT `entry`, `role`, `part_kind_id`, `insert_type_id`, "
        "`stat_type`, `stat_value`, `name_ru`, `enabled`, `ilvl_min`, "
        "`ilvl_max`, `quality_min`, `quality_max` FROM `%s` "
        "ORDER BY `role`, `part_kind_id`, `insert_type_id`, `entry`"
        % T_MATERIAL)
    info = _item_info([r["entry"] for r in rows])
    out = []
    for row in rows:
        entry = int(row["entry"])
        item = info.get(entry)
        out.append({
            "entry": entry,
            "role": row["role"],
            "part_kind_id": int(row["part_kind_id"]),
            "insert_type_id": int(row["insert_type_id"]),
            "ilvl_min": int(row["ilvl_min"]),
            "ilvl_max": int(row["ilvl_max"]),
            "quality_min": int(row["quality_min"]),
            "quality_max": int(row["quality_max"]),
            # Качество самой строки item_template: по нему идёт строгое
            # совпадение, когда границы не заданы. Панель показывает его рядом,
            # иначе правило нечем проверить глазами.
            "quality": int((item or {}).get("quality", 0)),
            "stat_type": int(row["stat_type"]),
            "stat_value": int(row["stat_value"]),
            # name_ru — подпись владельца; если её нет, показываем имя предмета.
            "name_ru": row["name_ru"] or (item or {}).get("name", ""),
            "enabled": bool(row["enabled"]),
            "item": item,
            "missing": item is None,
        })
    return out


def save_material(mat: Material) -> dict:
    _require()
    if mat.role not in ("base", "insert"):
        raise ApError("role бывает только 'base' или 'insert'.")
    if not _item_exists(mat.entry):
        raise ApError("Предмета %d нет в item_template." % mat.entry)
    if mat.stat_type not in STATS:
        raise ApError("Стат %d панель не умеет." % mat.stat_type)

    # Признак у материала ровно один, и какой - решает роль. Проверка
    # структурная, поэтому прежнего «самоцвет - это вставка, а не материал
    # части» больше не нужно: самоцвет живёт в другом справочнике, и выбрать
    # его материалу ячейки нечем.
    if mat.role == "base":
        if mat.insert_type_id:
            raise ApError("Тип вставки - про камни: материал ячейки кладут в "
                          "схему, а не в готовый предмет.")
        if mat.part_kind_id not in _dict_names(T_PART_KIND):
            raise ApError("Материалу ячейки нужен род из справочника.")
    else:
        if mat.part_kind_id:
            raise ApError("Род - про материал ячейки: камень идёт в гнездо и "
                          "ждёт тип вставки.")
        if mat.insert_type_id not in _dict_names(T_INSERT_TYPE):
            raise ApError("Камню нужен тип вставки из справочника.")
    # Камень обязан давать числа (DESIGN §2.5). Роль «только для сочетаний»
    # была ровно этим исключением - и отменена: эскиз, не сошедшийся в именной
    # предмет, всё равно должен возвращать полезную вещь, а с ключевым камнем
    # без чисел он возвращал бы пустышку.
    if mat.role == "insert" and (mat.stat_type == 0 or mat.stat_value == 0):
        raise ApError(
            "Вставка обязана давать числа: задайте стат и величину. Камней "
            "«только ради сочетания» больше не бывает.")
    if mat.role == "base" and (mat.stat_type or mat.stat_value):
        raise ApError("Стат - про вставку: материал ячейки на числа изделия не "
                      "влияет вовсе.")
    if mat.ilvl_max and mat.ilvl_max < mat.ilvl_min:
        raise ApError("Верхняя граница уровня ниже нижней: в такой предмет "
                      "вставку не пустят никогда.")
    if mat.quality_max and mat.quality_max < mat.quality_min:
        raise ApError("Верхняя граница качества ниже нижней: в такую вещь "
                      "камень не пустят никогда.")
    if mat.role == "base" and (mat.quality_min or mat.quality_max):
        raise ApError("Границы качества — про вставку: материал ячейки кладут "
                      "в схему, а не в готовый предмет.")
    # Серый камень с пустыми границами обошёл бы правило целиком: строгое
    # совпадение берёт качество из его же строки, а ноль там значит «границы
    # нет». Такой камень идёт в любую вещь - чего никто не имел в виду.
    if (mat.role != "base" and not mat.quality_min and not mat.quality_max
            and not _item_quality(mat.entry)):
        raise ApError("У этого предмета серое качество, а строгое совпадение "
                      "берёт качество камня. Задайте границы качества явно "
                      "или возьмите камень поприличнее.")
    if mat.role == "base" and (mat.ilvl_min or mat.ilvl_max):
        raise ApError("Границы уровня — про вставку: материал части кладут "
                      "в схему, а не в готовый предмет.")

    with world_cursor(commit=True) as cur:
        cur.execute(
            # Колонок ковки в списке нет намеренно: у существующей строки
            # они сохранятся как есть (их ещё читает нынешний worldserver), а
            # у новой возьмут умолчания схемы. Обнулять их правкой подписи -
            # значит незаметно менять уже выкованное.
            "INSERT INTO `%s` (`entry`, `role`, `part_kind_id`, "
            "`insert_type_id`, `stat_type`, "
            "`stat_value`, `name_ru`, `enabled`, `ilvl_min`, `ilvl_max`, "
            "`quality_min`, `quality_max`) "
            "VALUES (%%s, %%s, %%s, %%s, %%s, %%s, %%s, %%s, %%s, %%s, %%s, "
            "%%s) "
            "ON DUPLICATE KEY UPDATE `role` = VALUES(`role`), "
            "`part_kind_id` = VALUES(`part_kind_id`), "
            "`insert_type_id` = VALUES(`insert_type_id`), "
            "`stat_type` = VALUES(`stat_type`), "
            "`stat_value` = VALUES(`stat_value`), `name_ru` = VALUES(`name_ru`), "
            "`enabled` = VALUES(`enabled`), `ilvl_min` = VALUES(`ilvl_min`), "
            "`ilvl_max` = VALUES(`ilvl_max`), "
            "`quality_min` = VALUES(`quality_min`), "
            "`quality_max` = VALUES(`quality_max`)" % T_MATERIAL,
            (mat.entry, mat.role, mat.part_kind_id, mat.insert_type_id,
             mat.stat_type,
             mat.stat_value, _clean_text(mat.name_ru, "Имя материала"),
             int(mat.enabled), mat.ilvl_min, mat.ilvl_max,
             mat.quality_min, mat.quality_max))
    _bump_catalog_version()
    return {"entry": mat.entry}


def delete_material(entry: int) -> None:
    """Убрать материал — но только если на него никто не ссылается.

    Молча удалённый материал превратил бы основу в «куётся из ничего», а
    синергию — в никогда не срабатывающую. Поэтому отказываем с объяснением.
    """
    _require()
    used_by = query(
        "SELECT DISTINCT r.`id`, r.`name_ru` FROM `%s` i JOIN `%s` r ON "
        "r.`id` = i.`recipe_id` WHERE i.`item_entry` = %%s"
        % (T_RECIPE_ITEM, T_RECIPE_NEW), (entry,))
    if used_by:
        names = ", ".join(r["name_ru"] or str(r["id"]) for r in used_by)
        raise ApError("Материал входит в наборы основ: %s." % names)

    in_parts = query(
        "SELECT DISTINCT `type_id` FROM `%s` WHERE `part_kind_id` <> 0 AND "
        "`part_kind_id` = (SELECT `part_kind_id` FROM `%s` WHERE `entry` = %%s)"
        % (T_PART, T_MATERIAL), (entry,))
    if in_parts and len(materials_of_kind(entry)) <= 1:
        raise ApError(
            "Это единственный материал своего рода, а его ждут части типов "
            "%s — без него их будет нечем ковать."
            % ", ".join(str(r["type_id"]) for r in in_parts))

    hits = [s for s in synergies() if entry in s["mats"]]
    if hits:
        names = ", ".join(s["name_ru"] or str(s["id"]) for s in hits)
        raise ApError("Материал входит в синергии: %s." % names)

    made = _generated_uses_material(entry)
    if made:
        raise ApError(
            "Материал вложен в уже собранные предметы: %d. Удалять нельзя — "
            "выключите его: выключенный не предлагается в ковке, но всё уже "
            "собранное продолжает работать." % made)

    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `entry` = %%s" % T_MATERIAL, (entry,))
    _bump_catalog_version()


def _generated_uses_material(entry: int) -> int:
    """Сколько выданных предметов держат этот материал во вставках.

    Материалы лежат строкой через запятую, поэтому спрашиваем FIND_IN_SET, а не
    LIKE: «841» иначе нашлось бы внутри «2841».
    """
    row = query_one(
        "SELECT COUNT(*) AS n FROM `%s` WHERE FIND_IN_SET(%%s, `mats`)"
        % T_GENERATED, (entry,))
    return int((row or {}).get("n", 0))


def materials_of_kind(entry: int) -> list[dict]:
    """Материалы того же рода, что и указанный, — включая его самого."""
    row = query_one("SELECT `part_kind_id` FROM `%s` WHERE `entry` = %%s"
                    % T_MATERIAL, (entry,))
    if not row or not int(row["part_kind_id"]):
        return []
    return [m for m in materials()
            if m["part_kind_id"] == int(row["part_kind_id"])
            and m["role"] == "base"]


# --- типы предметов -------------------------------------------------------

class ItemType(BaseModel):
    id: int = 0
    code: str = ""
    name_ru: str = ""
    sub_ru: str = ""
    # Класс с подклассом не про игру, а про панель: по ним ищется донор
    # внешнего вида и отсеиваются материалы, которым в типе не место. Слот
    # надевания и скорость - свойства РЕЗУЛЬТАТА, они стоят в строке изделия
    # (DESIGN §5.4).
    item_class: int = 2
    item_subclass: int = 7
    displayid: int = Field(default=0, ge=0)
    # Имя файла чертежа в textures аддона, без пути и расширения. Пусто -
    # аддон берёт своё умолчание по классу.
    sheet_art: str = Field(default="", max_length=48)
    sort: int = Field(default=100, ge=0, le=9999)
    # Серая поделка неудачной ковки: одна строка item_template на тип
    # (DESIGN §5.4.2). Заводит её кнопка «создать» на вкладке типов.
    fail_entry: int = Field(default=0, ge=0)
    enabled: bool = True


TYPE_COLS = ("code", "name_ru", "sub_ru", "item_class", "item_subclass",
             "displayid", "sheet_art", "sort", "fail_entry", "enabled")


def types() -> list[dict]:
    """Что вообще можно ковать. Тип - то, что игрок выбирает в левом списке.

    Схема частей принадлежит типу, а не основе: у меча всегда клинок, гарда,
    рукоять и навершие, из какого бы металла его ни собрали.
    """
    _require()
    rows = query("SELECT `id`, %s FROM `%s` ORDER BY `sort`, `id`"
                 % (", ".join("`%s`" % c for c in TYPE_COLS), T_TYPE))
    part_counts = {int(r["type_id"]): int(r["n"]) for r in query(
        "SELECT `type_id`, COUNT(*) AS n FROM `%s` GROUP BY `type_id`" % T_PART)}
    # Обязательные ячейки считаем отдельно: по их числу сразу видно, сколько
    # частей у типа держат само его понятие (DESIGN §5.4.1).
    need_counts = {int(r["type_id"]): int(r["n"]) for r in query(
        "SELECT `type_id`, COUNT(*) AS n FROM `%s` WHERE `required` = 1 "
        "GROUP BY `type_id`" % T_PART)}
    recipe_counts = {int(r["type_id"]): int(r["n"]) for r in query(
        "SELECT `type_id`, COUNT(*) AS n FROM `%s` GROUP BY `type_id`"
        % T_RECIPE_NEW)}
    fail_info = _item_info([r["fail_entry"] for r in rows])
    # Поделка нужна, только пока набор без основы превращается в вещь.
    mode = query_one("SELECT `value` FROM `%s` WHERE `name` = 'fail_mode'"
                     % T_CONFIG)
    fail_mode = int((mode or {}).get("value", 2) or 0)

    out = []
    for row in rows:
        item = dict(row)
        item["id"] = int(row["id"])
        item["enabled"] = bool(row["enabled"])
        item["parts"] = part_counts.get(int(row["id"]), 0)
        item["required_parts"] = need_counts.get(int(row["id"]), 0)
        item["recipes"] = recipe_counts.get(int(row["id"]), 0)
        item["fail_entry"] = int(row["fail_entry"] or 0)
        item["fail_item"] = fail_info.get(item["fail_entry"])
        item["icon"] = items.icon_texture(row["displayid"] or 0)
        item["issues"] = []
        if not item["parts"]:
            item["issues"].append("нет ни одной ячейки: ковать нечем")
        if fail_mode == 2 and not item["fail_entry"]:
            item["issues"].append(
                "нет поделки, а набор без основы сейчас превращается в вещь "
                "(fail_mode = 2)")
        elif item["fail_entry"] and not item["fail_item"]:
            item["issues"].append("поделки %d нет в item_template"
                                  % item["fail_entry"])
        out.append(item)
    return out


def save_type(item_type: ItemType) -> dict:
    _require()
    item_type.name_ru = _clean_text(item_type.name_ru, "Имя типа")
    item_type.sub_ru = _clean_text(item_type.sub_ru, "Подпись типа")
    if not item_type.name_ru:
        raise ApError("У типа должно быть имя - его видит игрок в списке.")
    if not item_type.code.strip():  # noqa: код латиницей, разделителей в нём нет
        raise ApError("Нужен код: по нему аддон подбирает схему.")
    if item_type.item_class == 2 and item_type.item_subclass not in WEAPON_SUBCLASSES:
        raise ApError("Такого подкласса оружия панель не знает.")
    if item_type.item_class == 4 and item_type.item_subclass not in ARMOR_SUBCLASSES:
        raise ApError("Такого подкласса брони панель не знает.")
    # Только имя файла: путь и расширение подставляет аддон, а разделители
    # протокола в тексте ломают разбор ответа (§7).
    item_type.sheet_art = item_type.sheet_art.strip()
    if item_type.sheet_art and not re.fullmatch(r"[A-Za-z0-9_-]+",
                                                item_type.sheet_art):
        raise ApError("Чертёж - это имя файла из textures аддона без пути и "
                      "расширения: латиница, цифры, дефис и подчёркивание.")

    values = tuple(getattr(item_type, c) if c != "enabled" else int(item_type.enabled)
                   for c in TYPE_COLS)
    with world_cursor(commit=True) as cur:
        if item_type.id:
            sets = ", ".join("`%s` = %%s" % c for c in TYPE_COLS)
            cur.execute("UPDATE `%s` SET %s WHERE `id` = %%s" % (T_TYPE, sets),
                        values + (item_type.id,))
            new_id = item_type.id
        else:
            cols = ", ".join("`%s`" % c for c in TYPE_COLS)
            marks = ", ".join(["%s"] * len(TYPE_COLS))
            cur.execute("INSERT INTO `%s` (%s) VALUES (%s)"
                        % (T_TYPE, cols, marks), values)
            new_id = cur.lastrowid
    # Имя и подпись типа игрок видит из аддона, а не из этой строки.
    _bump_static_version()
    _bump_catalog_version()
    return {"id": int(new_id)}


def delete_type(type_id: int) -> None:
    """Убрать тип - но только если на нём не висят основы.

    Основа без типа не куётся ничем: у неё пропадает и схема частей, и класс
    предмета. Молча оставлять такую в базе хуже, чем отказать.
    """
    _require()
    on_type = query("SELECT `id`, `name_ru` FROM `%s` WHERE `type_id` = %%s"
                    % T_RECIPE_NEW, (type_id,))
    if on_type:
        names = ", ".join(r["name_ru"] or str(r["id"]) for r in on_type)
        raise ApError("На типе висят основы: %s." % names)

    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `type_id` = %%s" % T_PART, (type_id,))
        cur.execute("DELETE FROM `%s` WHERE `id` = %%s" % T_TYPE, (type_id,))
    _bump_static_version()
    _bump_catalog_version()


# --- части типа -----------------------------------------------------------

class Part(BaseModel):
    """Ячейка схемы: место, куда игрок кладёт предмет.

    Состояний у неё два: пусто либо предмет с количеством (DESIGN §5.4.1).
    Материала по умолчанию нет: пустая ячейка - законная часть набора, а
    основа, которая её не называет, требует именно пустоты. Расход стоит в
    строке основы, геометрия и текстура - в аддоне.

    Исключение одно - `required`: часть, без которой предмета не существует
    (клинок у меча, древко у древкового). Её пустой не оставить, и основа,
    которая её не называет, включить нельзя - сковать её не выйдет.
    """
    type_id: int = Field(gt=0)
    idx: int = Field(ge=1, le=12)
    label_ru: str = ""
    # ap_part_kind.id: какой род ячейка принимает (DESIGN §2.5).
    part_kind_id: int = Field(default=0, ge=0)
    required: int = Field(default=0, ge=0, le=1)


PART_COLS = ("label_ru", "part_kind_id", "required")


def parts(type_id: int) -> list[dict]:
    """Части типа по порядку. Это и есть реагенты: чем заполняется схема."""
    _require()
    rows = query(
        "SELECT `type_id`, `idx`, %s FROM `%s` WHERE `type_id` = %%s "
        "ORDER BY `idx`" % (", ".join("`%s`" % c for c in PART_COLS), T_PART),
        (type_id,))
    out = []
    for row in rows:
        item = dict(row)
        item["type_id"] = int(row["type_id"])
        item["idx"] = int(row["idx"])
        item["required"] = int(row["required"])
        # Сколько материалов этого рода вообще есть — часть, для которой в игре
        # нечего взять, делает основу некуемой, и заметить это в игре трудно.
        item["part_kind_id"] = int(row["part_kind_id"])
        item["choices"] = len([m for m in materials()
                               if m["role"] == "base" and m["enabled"]
                               and m["part_kind_id"] == item["part_kind_id"]])
        out.append(item)
    return out


def save_part(part: Part) -> dict:
    _require()
    if not query_one("SELECT 1 AS ok FROM `%s` WHERE `id` = %%s" % T_TYPE,
                     (part.type_id,)):
        raise ApError("Типа %d нет." % part.type_id)
    if part.part_kind_id not in _dict_names(T_PART_KIND):
        raise ApError("Ячейка ждёт род из справочника. Самоцветы сюда не "
                      "попадают вовсе - они живут в справочнике типов вставки.")
    part.label_ru = _clean_text(part.label_ru, "Подпись части")
    if not part.label_ru:
        raise ApError("У части должна быть подпись — её видит игрок на схеме.")

    available = [m for m in materials()
                 if m["role"] == "base" and m["enabled"]
                 and m["part_kind_id"] == part.part_kind_id]
    if not available:
        raise ApError(
            "Нет ни одного материала рода «%s» — такую часть будет нечем "
            "заполнить." % _dict_name(T_PART_KIND, part.part_kind_id))

    # Ставить галочку «обязательна» поверх включённых основ, которые эту
    # ячейку не называют, значит молча сделать их некуемыми: в игре ковка будет
    # отказывать, а в панели они останутся зелёными. Поэтому отказываем и
    # называем виноватых - порядок работ тут «сначала набор, потом галочка».
    if part.required:
        broken = [r["name_ru"] for r in recipes()
                  if r["enabled"] and int(r["type_id"]) == part.type_id
                  and not any(int(c["part_idx"]) == part.idx
                              and int(c["item_entry"]) for c in r["cells"])]
        if broken:
            raise ApError(
                "Ячейку нельзя сделать обязательной: её не называют включённые "
                "основы (%s%s). Допишите им эту ячейку или выключите их, "
                "иначе они станут некуемыми."
                % (", ".join("«%s»" % n for n in broken[:3]),
                   " и ещё %d" % (len(broken) - 3) if len(broken) > 3 else ""))

    values = tuple(getattr(part, c) for c in PART_COLS)
    sets = ", ".join("`%s` = VALUES(`%s`)" % (c, c) for c in PART_COLS)
    cols = ", ".join("`%s`" % c for c in PART_COLS)
    marks = ", ".join(["%s"] * len(PART_COLS))
    with world_cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO `%s` (`type_id`, `idx`, %s) VALUES (%%s, %%s, %s) "
            "ON DUPLICATE KEY UPDATE %s" % (T_PART, cols, marks, sets),
            (part.type_id, part.idx) + values)
    # Подпись части живёт в аддоне: без этого он подпишет гнездо по-старому.
    _bump_static_version()
    _bump_catalog_version()
    return {"type_id": part.type_id, "idx": part.idx}


def delete_part(type_id: int, idx: int) -> None:
    """Убрать ячейку схемы вместе со строками основ, которые её называли."""
    _require()
    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `type_id` = %%s AND `idx` = %%s"
                    % T_PART, (type_id, idx))
        # Основы ссылались на эту ячейку - без неё набор не сойдётся никогда.
        cur.execute("DELETE FROM `%s` WHERE `part_idx` = %%s AND `recipe_id` IN "
                    "(SELECT `id` FROM `%s` WHERE `type_id` = %%s)"
                    % (T_RECIPE_ITEM, T_RECIPE_NEW), (idx, type_id))
    _bump_static_version()
    _bump_catalog_version()


# --- основы: точный набор -> готовое изделие -------------------------------
# Разворот 2026-09-02 (DESIGN §2.2, §5.4, §5.4.5, §5.6). Прежняя пара
# ap_base/ap_base_recipe была набором УСЛОВИЙ («в части 1 лежит мифрил»), и из
# них вычислялся предмет. Здесь наоборот: основа - это точный набор предметов
# по ячейкам, а его результат - готовая строка item_template, заведённая
# заранее. Ничего не считается, поэтому и панель занимается не числами, а
# содержанием: она эти строки создаёт.

T_RECIPE_NEW = "ap_recipe"
T_RECIPE_ITEM = "ap_recipe_item"
T_RECIPE_RESULT = "ap_recipe_result"
# Чем основе дают себя украшать. Обе таблицы пустые по умолчанию: строк нет -
# ограничения нет (DESIGN §2.5).
T_RECIPE_INS = "ap_recipe_insert_type"
T_RECIPE_MAT = "ap_recipe_material"

# Блок id, в котором панель заводит изделия. Он же зарегистрирован в
# items.BLOCKS - чтобы созданную строку можно было потом править обычным
# редактором предмета, а не только создать.
RESULT_BLOCK = "professions"

# Прилагательное качества. Русское - то же, что в модуле
# (AdvancedProfessionsNames.cpp): имя изделия должно совпадать с тем, что
# посчитает сервер, иначе одна и та же вещь называется по-разному в панели и в
# игре. Английское идёт в item_template.name - его видит нерусский клиент.
QUALITY_ADJECTIVE = {0: "Испорченный", 2: "Добротный", 3: "Отменный",
                     4: "Мастерский", 5: "Безупречный"}
QUALITY_ADJECTIVE_EN = {0: "Botched", 2: "Fine", 3: "Superior",
                        4: "Masterwork", 5: "Flawless"}

# Слова на -ь мужского рода: список короткий и намеренно неполный, ровно как в
# модуле. Всё прочее на -ь считается женским.
_MASCULINE_SOFT = ("камень", "коготь", "гвоздь", "клинок", "меч", "ремень",
                   "уголь", "янтарь", "хрусталь", "огонь", "зверь", "лось")


def _guess_gender(phrase: str) -> str:
    """Род по последнему слову. Порт GuessGender из модуля."""
    word = (phrase or "").strip().split(" ")[-1].lower()
    if not word:
        return "m"
    if word.endswith(("ые", "ие")):
        return "p"
    if word.endswith(("ая", "яя")):
        return "f"
    if word.endswith(("ое", "ее")):
        return "n"
    if word.endswith(("ый", "ой", "ий")):
        return "m"
    if word.endswith("ь"):
        return "m" if (word.endswith(_MASCULINE_SOFT)
                       or word.endswith("тель")) else "f"
    if word.endswith(("а", "я")):
        return "f"
    if word.endswith(("о", "е", "ё")):
        return "n"
    if word.endswith(("и", "ы")):
        return "p"
    return "m"


def _decline_adjective(masculine: str, gender: str) -> str:
    """Прилагательное из мужского рода в нужный. Порт DeclineAdjective."""
    if gender == "m" or not masculine:
        return masculine

    soft = False
    if masculine.endswith(("ый", "ой")):
        stem = masculine[:-2]
    elif masculine.endswith("ий"):
        stem, soft = masculine[:-2], True
    else:
        return masculine                      # не прилагательное - не трогаем

    # После заднеязычных и шипящих мягкое -ий ведёт себя как твёрдое:
    # «рунический» -> «руническая», а не «рунячая».
    velar = stem.endswith(("г", "к", "х", "ж", "ч", "ш", "щ"))
    if soft and not velar:
        return stem + {"f": "яя", "n": "ее"}.get(gender, "ие")
    return stem + {"f": "ая", "n": "ое"}.get(gender, "ие" if velar else "ые")


def _lower_first(text: str) -> str:
    return text[:1].lower() + text[1:] if text else text


def result_name_ru(base_name: str, quality: int) -> str:
    """«Стальной клинок» + качество -> «Отменный стальной клинок».

    Обычное качество (1) идёт без прилагательного: обычный стальной клинок так
    и называется стальным клинком.
    """
    base_name = (base_name or "").strip()
    adjective = QUALITY_ADJECTIVE.get(int(quality), "")
    if not adjective:
        return base_name
    adjective = _decline_adjective(adjective, _guess_gender(base_name))
    return "%s %s" % (adjective, _lower_first(base_name))


def _result_name_en(base_name: str, quality: int) -> str:
    adjective = QUALITY_ADJECTIVE_EN.get(int(quality), "")
    base_name = (base_name or "").strip() or "Crafted Item"
    return ("%s %s" % (adjective, base_name)).strip()[:255]


def _qualities() -> dict[int, dict]:
    return {int(r["quality"]): dict(r) for r in
            query("SELECT `quality`, `name_ru`, `slots` FROM `%s`" % T_QUALITY)}


def references_to_item(entry: int) -> list[str]:
    """Чем предмет занят в крафте. Пусто - значит ничем.

    Спрашивает items.delete перед удалением: строка-результат, именной предмет
    и поделка живут в сумках игроков, и освободить их id значит превратить
    чужую вещь в другую вещь (DESIGN §4, решение 3).
    """
    if not available() or not _has_column(T_RECIPE_NEW, "quality_min"):
        return []
    out: list[str] = []
    for row in query(
            "SELECT r.`name_ru` AS recipe, s.`quality` AS quality FROM `%s` s "
            "JOIN `%s` r ON r.`id` = s.`recipe_id` WHERE s.`result_entry` = %%s"
            % (T_RECIPE_RESULT, T_RECIPE_NEW), (entry,)):
        out.append("изделие основы «%s» (качество %d)"
                   % (row["recipe"], int(row["quality"])))
    for row in query("SELECT `name_ru` FROM `%s` WHERE `teach_item` = %%s"
                     % T_RECIPE_NEW, (entry,)):
        out.append("обучающий предмет основы «%s»" % row["name_ru"])
    for row in query("SELECT `name_ru` FROM `%s` WHERE `result_entry` = %%s"
                     % T_SYNERGY, (entry,)):
        out.append("именной предмет сочетания «%s»" % row["name_ru"])
    if _has_column(T_SYNERGY, "teach_item"):
        for row in query("SELECT `name_ru` FROM `%s` WHERE `teach_item` = %%s"
                         % T_SYNERGY, (entry,)):
            out.append("обучающий предмет сочетания «%s»" % row["name_ru"])
    # Третий род рецепта - объединение (§5.8). Его строки тут не значились
    # вовсе, и предмет, на котором держится рецепт объединения, панель давала
    # удалить молча.
    if _has_table(T_MERGE):
        for row in query("SELECT `name_ru` FROM `%s` WHERE `result_entry` = %%s"
                         % T_MERGE, (entry,)):
            out.append("результат объединения «%s»" % row["name_ru"])
        if _has_column(T_MERGE, "teach_item"):
            for row in query("SELECT `name_ru` FROM `%s` "
                             "WHERE `teach_item` = %%s" % T_MERGE, (entry,)):
                out.append("обучающий предмет объединения «%s»" % row["name_ru"])
        if _has_table(T_MERGE_ITEM):
            for row in query(
                    "SELECT m.`name_ru` AS name FROM `%s` i "
                    "JOIN `%s` m ON m.`id` = i.`merge_id` "
                    "WHERE i.`item_entry` = %%s"
                    % (T_MERGE_ITEM, T_MERGE), (entry,)):
                out.append("часть набора объединения «%s»" % row["name"])
    for row in query("SELECT `name_ru` FROM `%s` WHERE `fail_entry` = %%s"
                     % T_TYPE, (entry,)):
        out.append("поделка типа «%s»" % row["name_ru"])
    return out


def _check_teach_item(entry: int, kind: str, row_id: int) -> None:
    """Одна книга учит одному - и это правило общее на все три рода рецепта.

    Сервер ищет владельца книги перебором и берёт ПЕРВОГО, причём порядок у
    него жёсткий: рецепт основы, потом именное сочетание, потом объединение
    (`OnPlayerCanCastItemUseSpell`). Значит второй владелец не получит ни
    отказа, ни ошибки - его просто никогда не изучат. Молчаливая пропажа, и
    заметить её можно только в игре.

    Проверка сквозная, а не по своей таблице: раньше сочетание смотрело на
    рецепты, рецепт не смотрел никуда, а объединение - только на себя, и
    книгу можно было увести у соседа с другой вкладки.
    """
    if not entry:
        return

    where = [("recipe", T_RECIPE_NEW, "рецепту основы"),
             ("synergy", T_SYNERGY, "именному сочетанию"),
             ("merge", T_MERGE, "рецепту объединения")]
    for owner_kind, table, said in where:
        if not _has_table(table) or not _has_column(table, "teach_item"):
            continue
        for row in query("SELECT `id`, `name_ru` FROM `%s` "
                         "WHERE `teach_item` = %%s" % table, (entry,)):
            if owner_kind == kind and int(row["id"]) == row_id:
                continue
            raise ApError("Предмет %d уже учит %s «%s»."
                          % (entry, said, row["name_ru"]))


class Recipe(BaseModel):
    id: int = 0
    type_id: int = Field(default=0, ge=0)
    name_ru: str = ""
    req_skill: int = Field(default=1, ge=0, le=500)
    # Обучающий предмет: 0 - основу только угадывают (DESIGN §5.4.4).
    teach_item: int = Field(default=0, ge=0)
    # Границы качества изделия у ОСНОВЫ, проценты остаются глобальными
    # (DESIGN §5.4.5). Ноль - это поделка, основой её не задают.
    quality_min: int = Field(default=1, ge=1, le=5)
    quality_max: int = Field(default=1, ge=1, le=5)
    # Способ получения: 'forge' куётся на верстаке, 'drop' приходит только
    # добычей (DESIGN §2.5). У дроп-основы ковочной половины нет вовсе.
    acquire: str = "forge"
    enabled: bool = False


RECIPE_COLS = ("type_id", "name_ru", "req_skill", "teach_item",
               "quality_min", "quality_max", "acquire", "enabled")


class RecipeCell(BaseModel):
    part_idx: int = Field(ge=1, le=12)
    # Что должно лежать в ячейке. Ноль означает «не задано»: строка удаляется, а
    # основа начинает требовать, чтобы ячейка была ПУСТОЙ (DESIGN §5.4).
    item_entry: int = Field(default=0, ge=0)
    count: int = Field(default=1, ge=1, le=50)


class RecipeResult(BaseModel):
    quality: int = Field(ge=1, le=5)
    # Ноль - отвязать изделие от ступени.
    result_entry: int = Field(default=0, ge=0)


def _schemes() -> dict[int, list[dict]]:
    """Схемы ячеек всех типов разом: {type_id: [часть, ...]}."""
    out: dict[int, list[dict]] = {}
    for row in query("SELECT `type_id`, `idx`, `label_ru`, `part_kind_id`, "
                     "`required` FROM `%s` ORDER BY `type_id`, `idx`" % T_PART):
        item = dict(row)
        item["idx"] = int(row["idx"])
        item["required"] = int(row["required"])
        item["part_kind_id"] = int(row["part_kind_id"])
        out.setdefault(int(row["type_id"]), []).append(item)
    return out


def _cell_signature(cells: dict[int, dict]) -> tuple:
    """Отпечаток набора, чтобы сравнивать основы между собой.

    Расход в него не входит: две основы с одним набором предметов, но разным
    расходом, всё равно неразличимы в момент ковки.
    """
    return tuple(sorted(
        (idx, int(cell["item_entry"]))
        for idx, cell in cells.items() if int(cell["item_entry"])))


def gem_fits(mat: dict, ilvl: int, quality: int, rec: dict) -> bool:
    """Пустят ли этот камень в такую вещь. Правило то же, что на сервере.

    Повторять его приходится в трёх местах - `Insert()`, аддон и здесь, - и
    расхождение стоит дорого: панель обещала бы эскиз, которого игрок не соберёт.
    Порядок отсева тот же, что в DESIGN §2.5:

        роль «в слот» -> качество -> уровень -> список ЛИБО набор типов
    """
    if mat["role"] == "base" or not mat["enabled"]:
        return False

    if mat["ilvl_min"] and ilvl < mat["ilvl_min"]:
        return False
    if mat["ilvl_max"] and ilvl > mat["ilvl_max"]:
        return False

    # Пустая пара границ - не «ограничения нет», а строгое совпадение с
    # качеством самого камня (§2.5, v22).
    lo, hi = mat["quality_min"], mat["quality_max"]
    if not lo and not hi:
        lo = hi = mat["quality"]
    if lo and quality < lo:
        return False
    if hi and quality > hi:
        return False

    # Поимённый список старше набора типов.
    if rec.get("materials"):
        return mat["entry"] in rec["materials"]
    if rec.get("insert_types"):
        return mat["insert_type_id"] in rec["insert_types"]
    return True


def _patterns(gems: int, slots: int) -> int:
    """Сколько разных наборов можно сложить из `gems` камней в `slots` гнёзд.

    Набор - это мультимножество: порядок не важен (ключ пула сортируется), а
    повторы законны, «малахит + малахит» - тоже эскиз. Длина от одного камня до
    числа гнёзд, поэтому C(M + S, S) - 1: единица вычитает пустой набор,
    который эскизом не считается (DESIGN §2.5, «Эскизы»).
    """
    if gems <= 0 or slots <= 0:
        return 0
    return math.comb(gems + slots, slots) - 1


def _recipe_inlay(rec: dict, quals: dict[int, dict],
                  mats: list[dict]) -> list[dict]:
    """Что выйдет из гнёзд на каждой ступени качества основы."""
    out = []
    for row in rec["results"]:
        quality = int(row["quality"])
        if not (rec["quality_min"] <= quality <= rec["quality_max"]):
            continue
        item = row.get("item") or {}
        if not item:
            continue
        slots = int(quals.get(quality, {}).get("slots", 0) or 0)
        gems = [m for m in mats
                if gem_fits(m, int(item.get("ilvl", 0)),
                            int(item.get("quality", 0)), rec)]
        out.append({
            "quality": quality,
            "slots": slots,
            "gems": len(gems),
            # Сами камни, а не только их число: из них собирается меню гнезда
            # на вкладке «Именные». Иначе набор пришлось бы выбирать из всех
            # вставок подряд и узнавать об отказе только от сервера.
            "gem_entries": [int(m["entry"]) for m in gems],
            "patterns": _patterns(len(gems), slots),
        })
    return out


def _recipe_issues(rec: dict, scheme: list[dict], quals: dict[int, dict],
                   twins: list[str]) -> list[str]:
    """Что мешает включить основу. Пустой список - можно включать.

    Проверки из DESIGN §8: набор обязан покрывать обязательные ячейки, на
    каждую ступень диапазона нужно существующее изделие, диапазон не должен
    быть пустым, а набор - повторять чужой.
    """
    issues: list[str] = []
    # У дроп-основы ковочной половины нет вовсе: её не куют, а выбивают, и в
    # сравнении наборов она не участвует (DESIGN §2.5). Проверять ей нечего -
    # ни схемы, ни набора, ни обязательных ячеек, ни двойников: двойник это
    # «две основы на один набор», а набора у неё нет.
    drop = rec.get("acquire") == "drop"

    cells = rec["cells"]
    if not drop and not scheme:
        issues.append("у типа нет ни одной ячейки — задайте части на вкладке "
                      "«Типы предметов»")
    if not drop and not _cell_signature(cells):
        issues.append("набор пуст: основа не совпадёт ни с чем")
    for idx, cell in cells.items():
        if not any(p["idx"] == idx for p in scheme):
            issues.append("ячейка %d осталась от прежней схемы типа" % idx)
        elif int(cell["item_entry"]) and not cell["item"]:
            issues.append("в ячейке %d предмет %d, которого нет в item_template"
                          % (idx, int(cell["item_entry"])))
    # Обязательную ячейку основа обязана назвать: «не задано» означает «должна
    # быть пустой», а пустой она быть не может - ковка откажет до расхода
    # материалов, и основа окажется недостижимой (DESIGN §5.4.1).
    for part in scheme:
        if drop or not int(part.get("required", 0)):
            continue
        cell = cells.get(part["idx"])
        if not cell or not int(cell["item_entry"]):
            issues.append("ячейка «%s» обязательная, а набор её не называет — "
                          "такую основу не сковать" % part["label_ru"])

    if rec["quality_min"] > rec["quality_max"]:
        issues.append("нижняя граница качества выше верхней")
    else:
        for quality in range(rec["quality_min"], rec["quality_max"] + 1):
            if quality not in quals:
                issues.append("ступени качества %d нет в справочнике" % quality)
                continue
            row = next((r for r in rec["results"]
                        if int(r["quality"]) == quality), None)
            if not row or not int(row["result_entry"]):
                issues.append("нет изделия для качества «%s»"
                              % quals[quality]["name_ru"])
            elif not row["item"]:
                issues.append("изделие %d для качества «%s» отсутствует в "
                              "item_template" % (int(row["result_entry"]),
                                                 quals[quality]["name_ru"]))
            elif not int(row.get("pool_lo") or 0):
                # Слайс режет панель при заведении изделия; ноль остаётся у
                # строк, заведённых до этого, и у тех, кому не хватило блока.
                # Ковка у такой основы работает, а доводка отвечает игроку
                # «кончились свободные id» - на вид беспричинно.
                issues.append(
                    "у изделия для качества «%s» нет слайса пула — ковка "
                    "пойдёт, а доводка ответит отказом; нарежьте его кнопкой "
                    "на вкладке «Пул id»" % quals[quality]["name_ru"])

    if int(rec["teach_item"]) and not rec["teach"]:
        issues.append("обучающего предмета %d нет в item_template"
                      % int(rec["teach_item"]))
    # Гнёзда, в которые нечего положить. Четыре сужающих условия подряд легко
    # дают ноль подходящих камней («костяная эпическая основа полосы 20-29», а
    # костей такого качества в той полосе никто не завёл), и в игре это выглядит
    # как «гнёзда есть, а список пуст» - без объяснений (DESIGN §2.5).
    for step in rec.get("inlay", []):
        if step["slots"] and not step["gems"]:
            issues.append(
                "на ступени «%s» у изделия %d гнёзд, а подходящих вставок нет "
                "— игрок получит гнёзда, в которые нечего положить"
                % (quals.get(step["quality"], {}).get("name_ru",
                                                      step["quality"]),
                   step["slots"]))

    for twin in (twins if not drop else []):
        issues.append("тот же набор уже у основы «%s» — совпадение точное, и "
                      "какой из двух сработает, решал бы случай" % twin)
    return issues


def recipes() -> list[dict]:
    _require()
    rows = query("SELECT `id`, %s FROM `%s` ORDER BY `type_id`, `req_skill`, `id`"
                 % (", ".join("`%s`" % c for c in RECIPE_COLS), T_RECIPE_NEW))

    cells: dict[int, dict[int, dict]] = {}
    for row in query("SELECT `recipe_id`, `part_idx`, `item_entry`, `count` "
                     "FROM `%s` ORDER BY `recipe_id`, `part_idx`"
                     % T_RECIPE_ITEM):
        cells.setdefault(int(row["recipe_id"]), {})[int(row["part_idx"])] = {
            "part_idx": int(row["part_idx"]),
            "item_entry": int(row["item_entry"]),
            "count": int(row["count"]),

        }
    results: dict[int, list[dict]] = {}
    for row in query("SELECT `recipe_id`, `quality`, `result_entry`, "
                     "`pool_lo`, `pool_hi` FROM `%s` "
                     "ORDER BY `recipe_id`, `quality`" % T_RECIPE_RESULT):
        results.setdefault(int(row["recipe_id"]), []).append(
            {"quality": int(row["quality"]),
             "result_entry": int(row["result_entry"]),
             "pool_lo": int(row["pool_lo"] or 0),
             "pool_hi": int(row["pool_hi"] or 0)})

    # Фильтры вставок. Множествами, а не списками: их проверяют на вхождение.
    ins: dict[int, set[int]] = {}
    for row in query("SELECT `recipe_id`, `insert_type_id` FROM `%s`"
                     % T_RECIPE_INS):
        ins.setdefault(int(row["recipe_id"]), set()).add(
            int(row["insert_type_id"]))
    named: dict[int, set[int]] = {}
    for row in query("SELECT `recipe_id`, `item_entry` FROM `%s`"
                     % T_RECIPE_MAT):
        named.setdefault(int(row["recipe_id"]), set()).add(int(row["item_entry"]))

    # Материалы читаем один раз на всю выборку: gem_fits зовётся на каждый
    # камень каждой ступени каждой основы, и запрос внутри стоил бы сотен.
    mats = materials()

    wanted = [r["teach_item"] for r in rows]
    wanted += [c["item_entry"] for by_id in cells.values()
               for c in by_id.values()]
    wanted += [r["result_entry"] for by_id in results.values() for r in by_id]
    info = _item_info(wanted)

    schemes = _schemes()
    quals = _qualities()
    type_names = {t["id"]: t["name_ru"] for t in types()}

    out = []
    for row in rows:
        rec = dict(row)
        rec["id"] = int(row["id"])
        rec["type_id"] = int(row["type_id"])
        rec["enabled"] = bool(row["enabled"])
        rec["type_name"] = type_names.get(rec["type_id"], "—")
        rec["teach"] = info.get(int(row["teach_item"]))
        scheme = schemes.get(rec["type_id"], [])
        by_idx: dict[int, dict] = {}
        for part in scheme:
            cell = dict(cells.get(rec["id"], {}).get(part["idx"], {
                "part_idx": part["idx"], "item_entry": 0, "count": 1}))
            cell["label_ru"] = part["label_ru"]
            cell["part_kind_id"] = part["part_kind_id"]
            cell["required"] = int(part["required"])
            cell["item"] = info.get(int(cell["item_entry"]))
            by_idx[part["idx"]] = cell
        # Ячейки, которых в схеме типа уже нет: схему могли перекроить после
        # того, как основу написали. Прятать их нельзя - из-за них основа не
        # совпадёт ни с чем, а по таблице этого не видно.
        for idx, cell in cells.get(rec["id"], {}).items():
            if idx not in by_idx:
                cell = dict(cell)
                cell["label_ru"] = "ячейка %d" % idx
                cell["part_kind_id"] = 0
                cell["required"] = 0
                cell["item"] = info.get(int(cell["item_entry"]))
                cell["orphan"] = True
                by_idx[idx] = cell
        rec["results"] = [
            {**r, "item": info.get(int(r["result_entry"]))}
            for r in results.get(rec["id"], [])]
        rec["insert_types"] = ins.get(rec["id"], set())
        rec["materials"] = named.get(rec["id"], set())
        rec["steps"] = max(0, rec["quality_max"] - rec["quality_min"] + 1)
        rec["ready_steps"] = len([
            r for r in rec["results"]
            if rec["quality_min"] <= int(r["quality"]) <= rec["quality_max"]
            and int(r["result_entry"]) and r["item"]])
        rec["_by_idx"] = by_idx
        out.append(rec)

    # Двойники ищем, когда собраны наборы всех основ, и только внутри
    # одного типа: разные типы и так не спутать.
    signatures = {rec["id"]: _cell_signature(rec["_by_idx"]) for rec in out}
    for rec in out:
        # Дроп-основа в сравнении наборов не участвует: сковать её нельзя, и
        # совпасть с чужим набором она не может.
        twins = [other["name_ru"] for other in out
                 if other["id"] != rec["id"]
                 and other["acquire"] != "drop"
                 and other["type_id"] == rec["type_id"]
                 and signatures[other["id"]]
                 and signatures[other["id"]] == signatures[rec["id"]]]
        rec["cells"] = rec.pop("_by_idx")
        # Гнёзда считаем ПОСЛЕ изделий: их качество и уровень решают, какие
        # камни подойдут, а без изделия ступень и не существует.
        rec["inlay"] = _recipe_inlay(rec, quals, mats)
        rec["issues"] = _recipe_issues(
            rec, schemes.get(rec["type_id"], []), quals, twins)
        # Наружу множества уезжают списками: JSON множеств не знает.
        rec["insert_types"] = sorted(rec["insert_types"])
        rec["materials"] = sorted(rec["materials"])
        # Наружу отдаём списком: словарь по индексу ячейки в JSON стал бы
        # словарём со строковыми ключами, и порядок бы поехал.
        rec["cells"] = [rec["cells"][idx] for idx in sorted(rec["cells"])]
    return out


def save_recipe(rec: Recipe) -> dict:
    _require()
    rec.name_ru = _clean_text(rec.name_ru, "Имя основы")
    if not rec.name_ru:
        raise ApError("У основы должно быть имя — по нему его видно в панели.")
    if not query_one("SELECT 1 AS ok FROM `%s` WHERE `id` = %%s" % T_TYPE,
                     (rec.type_id,)):
        raise ApError("Выберите тип предмета: он задаёт схему ячеек.")
    if rec.quality_min > rec.quality_max:
        raise ApError("Нижняя граница качества выше верхней — такой диапазон "
                      "нечем разрешить.")
    quals = _qualities()
    for quality in (rec.quality_min, rec.quality_max):
        if quality not in quals:
            raise ApError("Ступени качества %d нет в справочнике «Баланс»."
                          % quality)
    if rec.acquire not in ("forge", "drop"):
        raise ApError("Способ получения бывает только 'forge' или 'drop'.")
    if rec.teach_item and not _item_exists(rec.teach_item):
        raise ApError("Обучающего предмета %d нет в item_template."
                      % rec.teach_item)
    _check_teach_item(rec.teach_item, "recipe", rec.id)

    # Ковочная половина у дроп-основы не то что не нужна - она обманывает.
    # Книга обещала бы основу, которую не сковать; требуемый навык обещал бы
    # ковку по навыку, а навык растёт только на ковке (DESIGN §2.5).
    if rec.acquire == "drop":
        if rec.teach_item:
            raise ApError("Дроп-основу не куют: обучающая книга ей ничего не "
                          "даст. Именные эскизы учатся своими книгами.")
        if rec.req_skill:
            raise ApError("Дроп-основа навыка не требует и навыку не учит: "
                          "навык растёт на ковке, а ковки у неё нет.")

    # Включать основу можно только целой: без изделия на каждую ступень
    # диапазона ковка удастся, а выдать будет нечего.
    #
    # Проверка стоит на ПЕРЕХОДЕ «выключен -> включён», а не на каждом
    # сохранении включённой строки. Иначе выходило вот что: у включённого
    # основы появлялось замечание (например, камни его качества кто-то убрал
    # с другой вкладки), и после этого ЛЮБАЯ правка строки - имя, книга, тип -
    # отвечала «пока нельзя включить», хотя никто ничего не включал. Чинить
    # основу правкой становилось нельзя, пока её не выключишь; замечание при
    # этом и так висит в строке красным.
    if rec.enabled and rec.id:
        current = next((r for r in recipes() if r["id"] == rec.id), None)
        if current and not current["enabled"]:
            probe = dict(current)
            probe["quality_min"] = rec.quality_min
            probe["quality_max"] = rec.quality_max
            probe["teach_item"] = rec.teach_item
            # Способ получения берём НОВЫЙ: он решает, какие проверки вообще
            # применимы, и на старой основа-дроп упиралась бы в «набор пуст».
            probe["acquire"] = rec.acquire
            probe["cells"] = {c["part_idx"]: c for c in current["cells"]}
            issues = _recipe_issues(
                probe, _schemes().get(rec.type_id, []), quals, [])
            if issues:
                raise ApError("Основу «%s» пока нельзя включить: %s."
                              % (rec.name_ru, issues[0]))

    note = ""
    if not rec.id and rec.enabled:
        rec.enabled = False
        note = ("Основа создана выключенной: у неё ещё нет ни набора, ни "
                "изделий. Включите её, когда заведёте и то и другое.")

    values = tuple(getattr(rec, c) if c != "enabled" else int(rec.enabled)
                   for c in RECIPE_COLS)
    with world_cursor(commit=True) as cur:
        if rec.id:
            sets = ", ".join("`%s` = %%s" % c for c in RECIPE_COLS)
            cur.execute("UPDATE `%s` SET %s WHERE `id` = %%s"
                        % (T_RECIPE_NEW, sets), values + (rec.id,))
            new_id = rec.id
        else:
            cols = ", ".join("`%s`" % c for c in RECIPE_COLS)
            marks = ", ".join(["%s"] * len(RECIPE_COLS))
            cur.execute("INSERT INTO `%s` (%s) VALUES (%s)"
                        % (T_RECIPE_NEW, cols, marks), values)
            new_id = cur.lastrowid
    # Фильтры вставок уезжают на клиент у ВСЕХ включённых основ, изучена она
    # или нет, поэтому каталог сдвигает и обычная правка строки.
    _bump_catalog_version()
    return {"id": int(new_id), "note": note}


def delete_recipe(recipe_id: int) -> None:
    _require()
    rec = query_one("SELECT `name_ru` FROM `%s` WHERE `id` = %%s"
                    % T_RECIPE_NEW, (recipe_id,))
    if not rec:
        raise ApError("Основы %d нет." % recipe_id)

    # Колонка в снимке зовётся `recipe_id`; `base_id` осталась от прежней
    # модели и роняла удаление любой основы ошибкой MySQL - то есть проверка
    # не срабатывала ни разу, а вместо отказа приходила пятисотка.
    made = query_one("SELECT COUNT(*) AS n FROM `%s` WHERE `recipe_id` = %%s"
                     % T_GENERATED, (recipe_id,))
    if made and int(made["n"]):
        raise ApError(
            "По этой основе уже собрано предметов: %d. Удалять нельзя — "
            "выключите её: выключенная не предлагается в ковке, а собранное "
            "продолжает работать." % int(made["n"]))
    named = query("SELECT `name_ru` FROM `%s` WHERE `recipe_id` = %%s"
                  % T_SYNERGY, (recipe_id,))
    if named:
        raise ApError("На основе висят именные сочетания: %s. Сначала уберите "
                      "их." % ", ".join(r["name_ru"] for r in named))

    # Заготовки слайсов уходят вместе с основой: выданных по нему нет (это
    # проверено выше), а незанятые строки без хозяина только висели бы в
    # памяти каждого старта. Границы за основой при этом не освобождаются -
    # новая основа получит слайс за верхней границей, а не чужой.
    slices = query("SELECT `pool_lo`, `pool_hi` FROM `%s` WHERE "
                   "`recipe_id` = %%s" % T_RECIPE_RESULT, (recipe_id,))

    # Сами изделия остаются жить: строка item_template переживает свою основу,
    # потому что такая вещь может лежать в сумке игрока (DESIGN §8).
    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `recipe_id` = %%s"
                    % T_RECIPE_ITEM, (recipe_id,))
        cur.execute("DELETE FROM `%s` WHERE `recipe_id` = %%s"
                    % T_RECIPE_RESULT, (recipe_id,))
        cur.execute("DELETE FROM `%s` WHERE `recipe_id` = %%s"
                    % T_RECIPE_INS, (recipe_id,))
        cur.execute("DELETE FROM `%s` WHERE `recipe_id` = %%s"
                    % T_RECIPE_MAT, (recipe_id,))
        cur.execute("DELETE FROM `%s` WHERE `id` = %%s"
                    % T_RECIPE_NEW, (recipe_id,))

    for row in slices:
        _drop_slice(int(row["pool_lo"] or 0), int(row["pool_hi"] or 0))

    _bump_catalog_version()


class RecipeFilters(BaseModel):
    """Чем основе дают себя украшать (DESIGN §2.5).

    Оба списка необязательные и оба только СУЖАЮТ. Пустые - основа принимает
    любой камень, прошедший качество и границы уровня; так система работала до
    v23, и большинство основ такими и остаются.
    """

    insert_types: list[int] = []
    materials: list[int] = []


def save_recipe_filters(recipe_id: int, filters: RecipeFilters) -> dict:
    _require()
    if not query_one("SELECT 1 AS ok FROM `%s` WHERE `id` = %%s"
                     % T_RECIPE_NEW, (recipe_id,)):
        raise ApError("Основы %d нет." % recipe_id)

    types = sorted({int(t) for t in filters.insert_types if int(t) > 0})
    entries = sorted({int(e) for e in filters.materials if int(e) > 0})

    known_types = _dict_names(T_INSERT_TYPE)
    for type_id in types:
        if type_id not in known_types:
            raise ApError("Типа вставки %d нет в справочнике." % type_id)

    by_entry = {int(m["entry"]): m for m in materials()}
    for entry in entries:
        mat = by_entry.get(entry)
        if not mat:
            raise ApError("Материала %d нет в списке." % entry)
        if mat["role"] == "base":
            raise ApError("«%s» - материал ячейки, в гнездо он не идёт."
                          % (mat["name_ru"] or entry))

    # Список старше набора типов, и когда стоят оба, набор просто не работает.
    # Молча оставлять его лежать - значит обещать правило, которого нет.
    if types and entries:
        raise ApError("Поимённый список старше набора типов: пока он задан, "
                      "типы не проверяются. Оставьте что-то одно.")

    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `recipe_id` = %%s"
                    % T_RECIPE_INS, (recipe_id,))
        cur.execute("DELETE FROM `%s` WHERE `recipe_id` = %%s"
                    % T_RECIPE_MAT, (recipe_id,))
        for type_id in types:
            cur.execute("INSERT INTO `%s` (`recipe_id`, `insert_type_id`) "
                        "VALUES (%%s, %%s)" % T_RECIPE_INS,
                        (recipe_id, type_id))
        for entry in entries:
            cur.execute("INSERT INTO `%s` (`recipe_id`, `item_entry`) "
                        "VALUES (%%s, %%s)" % T_RECIPE_MAT,
                        (recipe_id, entry))
    _bump_catalog_version()
    return {"id": recipe_id, "insert_types": types, "materials": entries}


def recipe_cells(recipe_id: int) -> dict:
    """Набор основы по ячейкам схемы плюс то, что вообще можно в них класть."""
    _require()
    rec = query_one("SELECT `type_id`, `name_ru` FROM `%s` WHERE `id` = %%s"
                    % T_RECIPE_NEW, (recipe_id,))
    if not rec:
        raise ApError("Основы %d нет." % recipe_id)

    have = {int(r["part_idx"]): r for r in query(
        "SELECT `part_idx`, `item_entry`, `count` FROM `%s` "
        "WHERE `recipe_id` = %%s" % T_RECIPE_ITEM, (recipe_id,))}

    rows = []
    for part in parts(int(rec["type_id"])):
        own = have.get(part["idx"])
        # Предлагаем материалы своего рода: ячейка «лезвие» ждёт металл, и
        # ткань в ней сделала бы основу несобираемой.
        options = [m for m in materials()
                   if m["role"] == "base"
                   and m["part_kind_id"] == part["part_kind_id"]]
        rows.append({
            "part_idx": part["idx"],
            "label_ru": part["label_ru"],
            "part_kind_id": part["part_kind_id"],
            # Обязательную ячейку основа обязана назвать: пустой она быть не
            # может, и оставить её «не заданной» значит сделать основу
            # недостижимой (DESIGN §5.4.1).
            "required": int(part["required"]),
            "item_entry": int(own["item_entry"]) if own else 0,
            # Расход - часть набора, а не настройка ячейки: «те же предметы, но
            # по три» это другая основа (DESIGN §5.4.2).
            "count": int(own["count"]) if own else 1,
            "options": [{"entry": m["entry"], "name": m["name_ru"]}
                        for m in options],
        })
    return {"recipe_id": recipe_id, "name_ru": rec["name_ru"],
            "type_id": int(rec["type_id"]), "rows": rows}


def save_recipe_cell(recipe_id: int, cell: RecipeCell) -> dict:
    _require()
    rec = query_one("SELECT `type_id`, `name_ru`, `acquire` FROM `%s` "
                    "WHERE `id` = %%s" % T_RECIPE_NEW, (recipe_id,))
    if not rec:
        raise ApError("Основы %d нет." % recipe_id)
    # Набор у дроп-основы был бы мёртвой записью: в сравнении она не участвует,
    # и ни на что этот набор не влияет (DESIGN §2.5).
    if rec["acquire"] == "drop":
        raise ApError("Дроп-основу не куют: набор ячеек ей не нужен.")

    part = next((p for p in parts(int(rec["type_id"]))
                 if p["idx"] == cell.part_idx), None)
    if not part:
        raise ApError("У типа нет ячейки %d." % cell.part_idx)

    if cell.item_entry:
        mat = query_one("SELECT `part_kind_id`, `role` FROM `%s` "
                        "WHERE `entry` = %%s"
                        % T_MATERIAL, (cell.item_entry,))
        if not mat:
            raise ApError("Материала %d нет в списке — заведите его на вкладке "
                          "«Материалы»." % cell.item_entry)
        if mat["role"] != "base":
            raise ApError("В ячейку схемы идут материалы роли «на основу», а "
                          "не вставки.")
        if int(mat["part_kind_id"]) != part["part_kind_id"]:
            raise ApError("«%s» ждёт род «%s»."
                          % (part["label_ru"],
                             _dict_name(T_PART_KIND, part["part_kind_id"])))

    with world_cursor(commit=True) as cur:
        # «Не задано» - это отсутствие строки, а не ноль в ней: основа начнёт
        # требовать, чтобы ячейка была пустой (DESIGN §5.4).
        if not cell.item_entry:
            cur.execute("DELETE FROM `%s` WHERE `recipe_id` = %%s AND "
                        "`part_idx` = %%s" % T_RECIPE_ITEM,
                        (recipe_id, cell.part_idx))
            return {"recipe_id": recipe_id, "part_idx": cell.part_idx,
                    "cleared": True}
        cur.execute(
            "INSERT INTO `%s` (`recipe_id`, `part_idx`, `item_entry`, `count`) "
            "VALUES (%%s, %%s, %%s, %%s) ON DUPLICATE KEY "
            "UPDATE `item_entry` = VALUES(`item_entry`), "
            "`count` = VALUES(`count`)" % T_RECIPE_ITEM,
            (recipe_id, cell.part_idx, cell.item_entry, cell.count))
    _bump_catalog_version()
    return {"recipe_id": recipe_id, "part_idx": cell.part_idx}


# --- изделия: строки item_template, которые заводит панель -----------------

def _next_result_id() -> int:
    entry = items.next_free_id(RESULT_BLOCK)
    if entry is None:
        block = items.BLOCK_BY_ID[RESULT_BLOCK]
        raise ApError("В блоке изделий (%d-%d) не осталось свободных id."
                      % (block.lo, block.hi))
    return int(entry)


def _copy_item_row(sample: int, entry: int, quality: int, name_en: str,
                   name_ru: str) -> None:
    """Копия строки item_template с новым id, качеством и именем.

    Копируется ВСЯ строка, а не выбранные поля: образец подбирает владелец, и
    смысл кнопки именно в том, что изделие наследует у него всё - урон, слот,
    вид, звук, флаги. Число слотов доводки в item_template не пишется: его
    даёт ap_quality по качеству изделия, поэтому здесь только Quality.
    """
    cols = items.all_columns()
    overrides = {"entry": entry, "Quality": quality, "name": name_en}
    exprs, args = [], []
    for col in cols:
        if col in overrides:
            exprs.append("%s")
            args.append(overrides[col])
        else:
            exprs.append("`%s`" % col)

    loc = query_one(
        "SELECT `Description` FROM `item_template_locale` WHERE `ID` = %s "
        "AND `locale` = 'ruRU'", (sample,))
    with world_cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO `item_template` (%s) SELECT %s FROM `item_template` "
            "WHERE `entry` = %%s"
            % (", ".join("`%s`" % c for c in cols), ", ".join(exprs)),
            tuple(args) + (sample,))
        cur.execute(
            "REPLACE INTO `item_template_locale` (`ID`, `locale`, `Name`, "
            "`Description`) VALUES (%s, 'ruRU', %s, %s)",
            (entry, name_ru[:255], (loc or {}).get("Description") or ""))


# --- слайсы пула доводки ---------------------------------------------------
# Пул нарезан ПО ОСНОВАМ (v25): у каждой ступени основы свой слайс, потому что
# строка клиентской Item.dbc статична и одному слайсу двух моделей не показать.
# Миграция раздала слайсы тем основам, что были на тот день, а дальше основы
# заводит панель - значит и резать слайс ей. Без этого новая основа выглядит
# готовой, а доводка у неё молча не работает: worldserver пишет в лог «нет
# слайса пула», в игре вставка отвечает POOL, и понять, за что, нельзя.

POOL_STRIDE = 2048
POOL_SEED = 256

# Чем заготовка повторяет свою основу. Всё прочее у неё пустое: содержимое
# строки модуль перепишет при выдаче, а до неё заготовка обязана быть мусором
# в сумке (Flags 16 = ITEM_FLAG_DEPRECATED), а не работающим предметом.
BLANK_COLS = ("class", "subclass", "SoundOverrideSubclass", "InventoryType",
              "Material", "Sheath", "displayid")


def _next_slice() -> tuple[int, int]:
    """Следующий свободный слайс. Выданные границы не двигаются никогда.

    Идём от верхней занятой границы, а не от числа основ: слайс закреплён за
    основой навсегда, и сдвиг переназначил бы уже выданные игрокам id другой
    основе (DESIGN §2.5).
    """
    row = query_one("SELECT MAX(`pool_hi`) AS hi FROM `%s`" % T_RECIPE_RESULT)
    top = int((row or {}).get("hi") or 0)
    lo = max(items.POOL_LO, top + 1)
    hi = lo + POOL_STRIDE - 1
    if hi > items.POOL_HI:
        raise ApError(
            "Блок пула (%d-%d) кончился: слайсов больше не нарезать."
            % (items.POOL_LO, items.POOL_HI))
    return lo, hi


def _seed_slice(lo: int, hi: int, base_entry: int) -> int:
    """Засеять начало слайса заготовками по строке основы.

    Засевается первая четверть тысячи, остальное - резерв под уплотнение полос
    уровня: пустой промежуток в нумерации не стоит ни байта, потому что ядро
    растягивает хранилище шаблонов по максимальному СУЩЕСТВУЮЩЕМУ entry.
    """
    cols = ", ".join("`%s`" % c for c in BLANK_COLS)
    base = query_one("SELECT %s FROM `item_template` WHERE `entry` = %%s"
                     % cols, (base_entry,))
    if not base:
        raise ApError("Изделия %d нет в item_template." % base_entry)

    top = min(lo + POOL_SEED - 1, hi)
    # Выданное не трогаем ни при каких условиях: у игрока в сумке лежит вещь с
    # этим entry, и REPLACE подменил бы её заготовкой.
    issued = {int(r["entry"]) for r in query(
        "SELECT `entry` FROM `%s` WHERE `entry` BETWEEN %%s AND %%s"
        % T_GENERATED, (lo, top))}

    rows, args = [], []
    for entry in range(lo, top + 1):
        if entry in issued:
            continue
        rows.append("(%s, %s, %s, %s, %s, %s, %s, %s, %s, 0, 16, 1, 0)")
        args += [entry] + [base[c] for c in BLANK_COLS]
        args.append("[заготовка верстака %d]" % entry)
    if not rows:
        return 0

    with world_cursor(commit=True) as cur:
        cur.execute(
            "REPLACE INTO `item_template` (`entry`, %s, `name`, `Quality`, "
            "`Flags`, `Stackable`, `MaxCount`) VALUES %s"
            % (cols, ", ".join(rows)), tuple(args))
    return len(rows)


def _ensure_slice(recipe_id: int, quality: int, base_entry: int) -> dict:
    """Слайс у ступени: выделить, если его нет, и засеять по виду основы."""
    row = query_one(
        "SELECT `pool_lo`, `pool_hi` FROM `%s` WHERE `recipe_id` = %%s AND "
        "`quality` = %%s" % T_RECIPE_RESULT, (recipe_id, quality))
    lo = int((row or {}).get("pool_lo") or 0)
    hi = int((row or {}).get("pool_hi") or 0)
    if not lo or hi < lo:
        lo, hi = _next_slice()
        with world_cursor(commit=True) as cur:
            cur.execute(
                "UPDATE `%s` SET `pool_lo` = %%s, `pool_hi` = %%s WHERE "
                "`recipe_id` = %%s AND `quality` = %%s" % T_RECIPE_RESULT,
                (lo, hi, recipe_id, quality))
    seeded = _seed_slice(lo, hi, base_entry)
    return {"lo": lo, "hi": hi, "seeded": seeded}


def _drop_slice(lo: int, hi: int) -> int:
    """Убрать заготовки отвязанного слайса, кроме выданных.

    Сам слайс за основой остаётся: границы не переиспользуются, чтобы id
    никогда не сменил хозяина. А вот держать в памяти на каждом старте четверть
    тысячи строк, которые больше никому не принадлежат, незачем.
    """
    if not lo or hi < lo:
        return 0
    with world_cursor(commit=True) as cur:
        cur.execute(
            "DELETE t FROM `item_template` t WHERE t.`entry` BETWEEN %%s AND "
            "%%s AND NOT EXISTS (SELECT 1 FROM `%s` g WHERE g.`entry` = "
            "t.`entry`)" % T_GENERATED, (lo, hi))
        return cur.rowcount


def reseed_slice(recipe_id: int, quality: int) -> dict:
    """«Обновить вид заготовок» - после правки внешности самой основы.

    Вид основы менять задним числом можно и нужно, но копия это основа с
    камнями, и выглядеть иначе она не вправе: заготовки перечитывают строку
    основы, а в клиент новый вид уезжает следующей выгрузкой Item.dbc.
    """
    _require()
    row = query_one(
        "SELECT `result_entry`, `pool_lo`, `pool_hi` FROM `%s` WHERE "
        "`recipe_id` = %%s AND `quality` = %%s" % T_RECIPE_RESULT,
        (recipe_id, quality))
    if not row or not int(row["result_entry"]):
        raise ApError("У ступени %d основы %d нет изделия."
                      % (quality, recipe_id))
    return _ensure_slice(recipe_id, quality, int(row["result_entry"]))


def generate_results(recipe_id: int, sample_entry: int) -> dict:
    """«Создать варианты»: по изделию на каждую ступень диапазона качества.

    Заводить их руками владелец не должен: диапазон из четырёх ступеней - это
    четыре почти одинаковых предмета на каждую основу (DESIGN §5.4.5). Уже
    заведённые ступени не трогаем: сгенерированное правится дальше руками, и
    перезапись стёрла бы правку.
    """
    _require()
    rec = query_one("SELECT `name_ru`, `quality_min`, `quality_max` FROM `%s` "
                    "WHERE `id` = %%s" % T_RECIPE_NEW, (recipe_id,))
    if not rec:
        raise ApError("Основы %d нет." % recipe_id)
    if not _item_exists(sample_entry):
        raise ApError("Образца %d нет в item_template." % sample_entry)

    sample = query_one("SELECT `name` FROM `item_template` WHERE `entry` = %s",
                       (sample_entry,))
    have = {int(r["quality"]) for r in
            query("SELECT `quality` FROM `%s` WHERE `recipe_id` = %%s AND "
                  "`result_entry` <> 0" % T_RECIPE_RESULT, (recipe_id,))}

    created, skipped = [], []
    for quality in range(int(rec["quality_min"]), int(rec["quality_max"]) + 1):
        if quality in have:
            skipped.append(quality)
            continue
        entry = _next_result_id()
        _copy_item_row(sample_entry, entry, quality,
                       _result_name_en(sample["name"], quality),
                       result_name_ru(rec["name_ru"], quality))
        with world_cursor(commit=True) as cur:
            cur.execute(
                "INSERT INTO `%s` (`recipe_id`, `quality`, `result_entry`) "
                "VALUES (%%s, %%s, %%s) ON DUPLICATE KEY UPDATE "
                "`result_entry` = VALUES(`result_entry`)" % T_RECIPE_RESULT,
                (recipe_id, quality, entry))
        # Слайс режется тут же: изделие без него выглядит готовым, а доводка у
        # него не работает - и узнать об этом можно только из лога worldserver.
        slice_ = _ensure_slice(recipe_id, quality, entry)
        created.append({"quality": quality, "entry": entry, **slice_})

    return {"created": created, "skipped": skipped}


def save_recipe_result(recipe_id: int, row: RecipeResult) -> dict:
    """Руками привязать (или отвязать) готовое изделие к ступени качества."""
    _require()
    rec = query_one("SELECT `quality_min`, `quality_max` FROM `%s` "
                    "WHERE `id` = %%s" % T_RECIPE_NEW, (recipe_id,))
    if not rec:
        raise ApError("Основы %d нет." % recipe_id)
    if not (int(rec["quality_min"]) <= row.quality <= int(rec["quality_max"])):
        raise ApError("Качество %d вне диапазона основы." % row.quality)
    if row.result_entry and not _item_exists(row.result_entry):
        raise ApError("Предмета %d нет в item_template." % row.result_entry)

    # Границы прежнего слайса нужны на обоих путях: при отвязке по ним
    # убираются осиротевшие заготовки, при подмене изделия слайс остаётся тот
    # же, но засевается заново - иначе заготовки показывали бы вид прошлой
    # основы (DESIGN §2.5, «вид основы = вид её слайса»).
    old = query_one(
        "SELECT `pool_lo`, `pool_hi` FROM `%s` WHERE `recipe_id` = %%s AND "
        "`quality` = %%s" % T_RECIPE_RESULT, (recipe_id, row.quality))

    with world_cursor(commit=True) as cur:
        if not row.result_entry:
            cur.execute("DELETE FROM `%s` WHERE `recipe_id` = %%s AND "
                        "`quality` = %%s" % T_RECIPE_RESULT,
                        (recipe_id, row.quality))
        else:
            cur.execute(
                "INSERT INTO `%s` (`recipe_id`, `quality`, `result_entry`) "
                "VALUES (%%s, %%s, %%s) ON DUPLICATE KEY UPDATE "
                "`result_entry` = VALUES(`result_entry`)" % T_RECIPE_RESULT,
                (recipe_id, row.quality, row.result_entry))

    out = {"recipe_id": recipe_id, "quality": row.quality}
    if not row.result_entry:
        out["dropped"] = _drop_slice(int((old or {}).get("pool_lo") or 0),
                                     int((old or {}).get("pool_hi") or 0))
    else:
        out.update(_ensure_slice(recipe_id, row.quality, row.result_entry))
    return out


def generate_fail_item(type_id: int, sample_entry: int) -> dict:
    """Серая поделка типа: одна строка на тип (DESIGN §5.4.2).

    Нужна, пока fail_mode = 2: набор без основы тогда не отказ, а испорченная
    вещь, и выдать её не из чего, если строки нет.
    """
    _require()
    item_type = query_one("SELECT `name_ru`, `fail_entry` FROM `%s` "
                          "WHERE `id` = %%s" % T_TYPE, (type_id,))
    if not item_type:
        raise ApError("Типа %d нет." % type_id)
    if int(item_type["fail_entry"] or 0):
        raise ApError("У типа «%s» поделка уже заведена (%d). Правьте её в "
                      "каталоге предметов." % (item_type["name_ru"],
                                               int(item_type["fail_entry"])))
    if not _item_exists(sample_entry):
        raise ApError("Образца %d нет в item_template." % sample_entry)

    sample = query_one("SELECT `name` FROM `item_template` WHERE `entry` = %s",
                       (sample_entry,))
    entry = _next_result_id()
    _copy_item_row(sample_entry, entry, 0,
                   _result_name_en(sample["name"], 0),
                   result_name_ru(item_type["name_ru"], 0))
    with world_cursor(commit=True) as cur:
        cur.execute("UPDATE `%s` SET `fail_entry` = %%s WHERE `id` = %%s"
                    % T_TYPE, (entry, type_id))
    return {"type_id": type_id, "entry": entry}


# --- именные предметы за сочетание вставок --------------------------------

class Synergy(BaseModel):
    id: int = 0
    name_ru: str = ""
    # Сочетание принадлежит ОСНОВЕ (DESIGN §5.6). Этим закрыт
    # старый вопрос «Клинок ловчего на щите»: те же два камня в щите либо дадут
    # собственное сочетание щита, либо не дадут ничего.
    recipe_id: int = Field(default=0, ge=0)
    mats: list[int] = []
    # Именной предмет: своя строка item_template со своим видом, уровнем и
    # умениями. Ноль - ещё не заведён, сочетание нерабочее.
    result_entry: int = Field(default=0, ge=0)
    # Обучающий предмет, как у рецепта основы: сочетание стало вторым родом
    # рецепта и изучается книгой (DESIGN §5.6, решение владельца 2026-09-05).
    # Ноль - книги нет, и сочетание остаётся находкой для того, кто угадает.
    teach_item: int = Field(default=0, ge=0)
    order_matters: bool = False
    enabled: bool = True


def _parse_pattern(pattern: str) -> list[int]:
    out = []
    for part in (pattern or "").split(","):
        part = part.strip()
        if part.isdigit():
            out.append(int(part))
    return out


def _same_set(left: list[int], right: list[int], ordered: bool) -> bool:
    """Совпадают ли два набора вставок.

    Порядок значим не всегда: у строки есть флаг. Если хотя бы одна из двух
    сравниваемых порядок не различает, сравнивать надо как мультимножества -
    иначе «красный, зелёный» и «зелёный, красный» разошлись бы, хотя одна из
    строк ловит оба.
    """
    if ordered:
        return list(left) == list(right)
    return sorted(left) == sorted(right)


def synergies() -> list[dict]:
    _require()
    teaches = _has_column(T_SYNERGY, "teach_item")
    rows = query("SELECT `id`, `name_ru`, `pattern`, `recipe_id`, "
                 "`result_entry`, `order_matters`, `enabled`%s FROM `%s` "
                 "ORDER BY `recipe_id`, `id`"
                 % (", `teach_item`" if teaches else "", T_SYNERGY))
    wanted = [m for r in rows for m in _parse_pattern(r["pattern"])]
    wanted += [r["result_entry"] for r in rows]
    wanted += [r.get("teach_item") or 0 for r in rows]
    info = _item_info(wanted)

    quals = _qualities()
    owners = {int(r["id"]): r for r in query(
        "SELECT `id`, `name_ru`, `type_id`, `quality_max` FROM `%s`"
        % T_RECIPE_NEW)}

    out = []
    for row in rows:
        pattern = _parse_pattern(row["pattern"])
        owner = owners.get(int(row["recipe_id"]))
        # Сколько вставок влезет в лучший вариант основы: длиннее набор - и
        # сочетание не соберёт никто (DESIGN §5.6).
        best = 0
        if owner:
            best = int((quals.get(int(owner["quality_max"])) or {})
                       .get("slots", 0))
        item = info.get(int(row["result_entry"]))

        issues = []
        if not owner:
            issues.append("сочетание не привязано к основе")
        if not pattern:
            issues.append("набор пуст")
        elif best and len(pattern) > best:
            issues.append("в наборе %d вставки, а лучший вариант основы даёт "
                          "%d слота — собрать его не сможет никто"
                          % (len(pattern), best))
        if not int(row["result_entry"]):
            issues.append("нет именного предмета: сочетание ничего не выдаст")
        elif not item:
            issues.append("именного предмета %d нет в item_template"
                          % int(row["result_entry"]))
        teach_item = int(row.get("teach_item") or 0)
        teach = info.get(teach_item)
        if teach_item and not teach:
            issues.append("обучающего предмета %d нет в item_template"
                          % teach_item)

        out.append({
            "id": int(row["id"]),
            "name_ru": row["name_ru"],
            "recipe_id": int(row["recipe_id"]),
            "recipe_name": owner["name_ru"] if owner else "",
            "recipe_slots": best,
            "mats": pattern,
            "items": [info.get(m) for m in pattern],
            "result_entry": int(row["result_entry"]),
            "result": item,
            "teach_item": teach_item,
            "teach": teach,
            "order_matters": bool(row["order_matters"]),
            "enabled": bool(row["enabled"]),
            "issues": issues,
        })
    return out


def save_synergy(syn: Synergy) -> dict:
    _require()
    syn.name_ru = _clean_text(syn.name_ru, "Имя сочетания")
    if not syn.name_ru:
        raise ApError("У сочетания должно быть имя — по нему его видно в "
                      "панели; настоящее имя вещи живёт в её строке.")
    owner = query_one("SELECT `name_ru`, `quality_max` FROM `%s` "
                      "WHERE `id` = %%s" % T_RECIPE_NEW, (syn.recipe_id,))
    if not owner:
        raise ApError("Выберите основу: сочетание принадлежит основе, а не "
                      "всему модулю — иначе те же камни сработают и на щите.")
    # Один материал - законная длина: у основы может быть своё сочетание на
    # один, на два и на три (DESIGN §5.6).
    if not 1 <= len(syn.mats) <= MAX_SLOTS:
        raise ApError("Сочетание — это от 1 до %d вставок." % MAX_SLOTS)

    known = {int(m["entry"]): m for m in materials()}
    for entry in syn.mats:
        mat = known.get(entry)
        if not mat:
            raise ApError("Материала %d нет в списке." % entry)
        if mat["role"] != "insert":
            raise ApError("В сочетание входят только вставки, а %d — материал "
                          "основы." % entry)

    if syn.result_entry and not _item_exists(syn.result_entry):
        raise ApError("Именного предмета %d нет в item_template."
                      % syn.result_entry)
    if syn.teach_item and not _item_exists(syn.teach_item):
        raise ApError("Обучающего предмета %d нет в item_template."
                      % syn.teach_item)
    _check_teach_item(syn.teach_item, "synergy", syn.id)
    if syn.enabled and not syn.result_entry:
        raise ApError("Сочетание без именного предмета включать нечему: "
                      "заведите его кнопкой «создать» или укажите готовый.")

    # Двойник ищется в пределах своей основы: у разных основ наборы совпадать
    # не только можно, но и нужно.
    for other in synergies():
        if other["id"] == syn.id or other["recipe_id"] != syn.recipe_id:
            continue
        if _same_set(other["mats"], syn.mats,
                     other["order_matters"] and syn.order_matters):
            raise ApError("У основы «%s» такой набор уже занят сочетанием "
                          "«%s»." % (owner["name_ru"], other["name_ru"]))

    note = ""
    quals = _qualities()
    best = int((quals.get(int(owner["quality_max"])) or {}).get("slots", 0))
    if best and len(syn.mats) > best:
        note = ("Предупреждение: в наборе %d вставки, а лучший вариант основы "
                "«%s» даёт %d слота. Такое сочетание не соберёт никто."
                % (len(syn.mats), owner["name_ru"], best))

    pattern = ",".join(str(m) for m in syn.mats)
    with world_cursor(commit=True) as cur:
        # Числовые поля прежней модели (stat_type, stat_value, displayid) в
        # запросах не перечислены намеренно: их всё ещё читает собранный
        # worldserver, а сносит их миграция v15. Панель их больше не трогает -
        # именной предмет несёт и статы, и вид сам (DESIGN §5.6).
        if syn.id:
            cur.execute(
                "UPDATE `%s` SET `name_ru` = %%s, `pattern` = %%s, "
                "`recipe_id` = %%s, `result_entry` = %%s, `teach_item` = %%s, "
                "`order_matters` = %%s, `enabled` = %%s WHERE `id` = %%s"
                % T_SYNERGY,
                (syn.name_ru, pattern, syn.recipe_id, syn.result_entry,
                 syn.teach_item, int(syn.order_matters), int(syn.enabled),
                 syn.id))
            new_id = syn.id
        else:
            cur.execute(
                "INSERT INTO `%s` (`name_ru`, `pattern`, `recipe_id`, "
                "`result_entry`, `teach_item`, `order_matters`, `enabled`) "
                "VALUES (%%s, %%s, %%s, %%s, %%s, %%s, %%s)" % T_SYNERGY,
                (syn.name_ru, pattern, syn.recipe_id, syn.result_entry,
                 syn.teach_item, int(syn.order_matters), int(syn.enabled)))
            new_id = cur.lastrowid
    return {"id": int(new_id), "note": note}


def generate_named_item(syn_id: int, sample_entry: int) -> dict:
    """Завести именной предмет по образцу.

    Качество берётся у образца, а не у основы: именная вещь имеет право быть
    и лучше, и хуже той, из которой вышла (DESIGN §5.6). Дальше строка
    правится в каталоге предметов - там и вид, и умения.
    """
    _require()
    syn = query_one("SELECT `name_ru`, `result_entry` FROM `%s` "
                    "WHERE `id` = %%s" % T_SYNERGY, (syn_id,))
    if not syn:
        raise ApError("Сочетания %d нет." % syn_id)
    if int(syn["result_entry"] or 0):
        raise ApError("У сочетания «%s» именной предмет уже заведён (%d). "
                      "Правьте его в каталоге предметов."
                      % (syn["name_ru"], int(syn["result_entry"])))
    if not _item_exists(sample_entry):
        raise ApError("Образца %d нет в item_template." % sample_entry)

    sample = query_one("SELECT `name`, `Quality` FROM `item_template` "
                       "WHERE `entry` = %s", (sample_entry,))
    entry = _next_result_id()
    _copy_item_row(sample_entry, entry, int(sample["Quality"] or 0),
                   sample["name"] or "Named Item", syn["name_ru"])
    with world_cursor(commit=True) as cur:
        cur.execute("UPDATE `%s` SET `result_entry` = %%s WHERE `id` = %%s"
                    % T_SYNERGY, (entry, syn_id))
    return {"id": syn_id, "entry": entry}


def delete_synergy(syn_id: int) -> None:
    _require()
    # Именной предмет остаётся жить: он может лежать в сумке игрока, и
    # освободить его id значит превратить чужую вещь в другую (DESIGN §4).
    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `id` = %%s" % T_SYNERGY, (syn_id,))


# --- баланс: качества, корзины, веса --------------------------------------

class Quality(BaseModel):
    quality: int = Field(ge=1, le=5)
    name_ru: str = ""
    slots: int = Field(ge=1, le=MAX_SLOTS)


class Balance(BaseModel):
    qualities: list[Quality]
    # {"quality": вес}. Проценты качества ГЛОБАЛЬНЫЕ - одна таблица на модуль:
    # подкрутка «стало слишком много эпиков» правится в одном месте, а не по
    # всем основам разом (DESIGN §5.4.5).
    chances: dict[str, int] = {}


# --- объединение ----------------------------------------------------------
# Третий род рецепта (DESIGN §5.8): в середину стола кладут ЛЮБУЮ вещь
# подходящего типа - выбитую, купленную, скованную здесь, - в пять ячеек что
# угодно, и выходит готовый предмет. Навыка стол не требует, броска не делает,
# а несовпавший набор не тратит ничего.

MAX_MERGE_CELLS = 5


class Merge(BaseModel):
    id: int = 0
    name_ru: str = ""
    # Тип центральной вещи. Не рецепт, как у именных сочетаний: в середину идёт
    # что угодно подходящего рода, в том числе не наше изделие.
    type_id: int = Field(default=0, ge=0)
    items: list[int] = []
    result_entry: int = Field(default=0, ge=0)
    teach_item: int = Field(default=0, ge=0)
    enabled: bool = False


def merges() -> list[dict]:
    _require()
    # Таблицы приезжают миграцией v19: пока её нет, вкладка честно пуста.
    if not _has_column(T_MERGE, "type_id"):
        return []

    rows = query("SELECT `id`, `name_ru`, `type_id`, `result_entry`, "
                 "`teach_item`, `enabled` FROM `%s` ORDER BY `type_id`, `id`"
                 % T_MERGE)
    cells: dict[int, list[int]] = {}
    for row in query("SELECT `merge_id`, `item_entry` FROM `%s` "
                     "ORDER BY `merge_id`, `idx`" % T_MERGE_ITEM):
        cells.setdefault(int(row["merge_id"]), []).append(int(row["item_entry"]))

    wanted = [e for group in cells.values() for e in group]
    wanted += [r["result_entry"] for r in rows]
    wanted += [r["teach_item"] for r in rows]
    info = _item_info(wanted)
    known = {int(t["id"]): t for t in types()}

    out = []
    for row in rows:
        items = cells.get(int(row["id"]), [])
        item_type = known.get(int(row["type_id"]))
        result = info.get(int(row["result_entry"]))
        teach = info.get(int(row["teach_item"]))

        issues = []
        if not item_type:
            issues.append("тип центральной вещи не выбран")
        if not items:
            issues.append("набор пуст: класть в ячейки нечего")
        if not int(row["result_entry"]):
            issues.append("нет предмета-результата: рецепт ничего не выдаст")
        elif not result:
            issues.append("предмета %d нет в item_template"
                          % int(row["result_entry"]))
        if int(row["teach_item"]) and not teach:
            issues.append("обучающего предмета %d нет в item_template"
                          % int(row["teach_item"]))

        out.append({
            "id": int(row["id"]),
            "name_ru": row["name_ru"],
            "type_id": int(row["type_id"]),
            "type_name": item_type["name_ru"] if item_type else "",
            "items": items,
            "item_rows": [info.get(e) for e in items],
            "result_entry": int(row["result_entry"]),
            "result": result,
            "teach_item": int(row["teach_item"]),
            "teach": teach,
            "enabled": bool(row["enabled"]),
            "issues": issues,
        })
    return out


def save_merge(merge: Merge) -> dict:
    _require()
    merge.name_ru = _clean_text(merge.name_ru, "Имя рецепта")
    if not merge.name_ru:
        raise ApError("У рецепта должно быть имя — по нему его видно в "
                      "панели; игрок видит имя предмета-результата.")
    if not any(int(t["id"]) == merge.type_id for t in types()):
        raise ApError("Выберите тип центральной вещи: рецепт работает только "
                      "с вещами своего рода.")
    if not 1 <= len(merge.items) <= MAX_MERGE_CELLS:
        raise ApError("В наборе от 1 до %d предметов." % MAX_MERGE_CELLS)

    for entry in merge.items:
        if not _item_exists(entry):
            raise ApError("Предмета %d нет в item_template." % entry)
    if merge.result_entry and not _item_exists(merge.result_entry):
        raise ApError("Предмета-результата %d нет в item_template."
                      % merge.result_entry)
    if merge.enabled and not merge.result_entry:
        raise ApError("Рецепт без предмета-результата включать нечему: "
                      "заведите его кнопкой «создать» или укажите готовый.")
    if merge.teach_item and not _item_exists(merge.teach_item):
        raise ApError("Обучающего предмета %d нет в item_template."
                      % merge.teach_item)

    _check_teach_item(merge.teach_item, "merge", merge.id)

    # Двойник ищется в пределах своего типа: сервер сравнивает набор как
    # множество, и два рецепта с одинаковым набором сделали бы второй
    # недостижимым.
    for other in merges():
        if other["id"] == merge.id or other["type_id"] != merge.type_id:
            continue
        if sorted(other["items"]) == sorted(merge.items):
            raise ApError("У типа «%s» такой набор уже занят рецептом «%s»."
                          % (other["type_name"], other["name_ru"]))

    with world_cursor(commit=True) as cur:
        if merge.id:
            cur.execute(
                "UPDATE `%s` SET `name_ru` = %%s, `type_id` = %%s, "
                "`result_entry` = %%s, `teach_item` = %%s, `enabled` = %%s "
                "WHERE `id` = %%s" % T_MERGE,
                (merge.name_ru, merge.type_id, merge.result_entry,
                 merge.teach_item, int(merge.enabled), merge.id))
            new_id = merge.id
        else:
            cur.execute(
                "INSERT INTO `%s` (`name_ru`, `type_id`, `result_entry`, "
                "`teach_item`, `enabled`) VALUES (%%s, %%s, %%s, %%s, %%s)"
                % T_MERGE,
                (merge.name_ru, merge.type_id, merge.result_entry,
                 merge.teach_item, int(merge.enabled)))
            new_id = cur.lastrowid

        # Набор переписывается целиком: ячейки равноправны, и вести их по
        # одной значило бы держать в панели порядок, которого нет в игре.
        cur.execute("DELETE FROM `%s` WHERE `merge_id` = %%s" % T_MERGE_ITEM,
                    (new_id,))
        for idx, entry in enumerate(merge.items, start=1):
            cur.execute(
                "INSERT INTO `%s` (`merge_id`, `idx`, `item_entry`) "
                "VALUES (%%s, %%s, %%s)" % T_MERGE_ITEM, (new_id, idx, entry))

    return {"id": int(new_id)}


def generate_merge_item(merge_id: int, sample_entry: int) -> dict:
    """Завести предмет-результат по образцу — как у именных сочетаний."""
    _require()
    row = query_one("SELECT `name_ru`, `result_entry` FROM `%s` "
                    "WHERE `id` = %%s" % T_MERGE, (merge_id,))
    if not row:
        raise ApError("Рецепта объединения %d нет." % merge_id)
    if int(row["result_entry"] or 0):
        raise ApError("У рецепта «%s» результат уже заведён (%d). Правьте его "
                      "в каталоге предметов."
                      % (row["name_ru"], int(row["result_entry"])))
    if not _item_exists(sample_entry):
        raise ApError("Образца %d нет в item_template." % sample_entry)

    sample = query_one("SELECT `name`, `Quality` FROM `item_template` "
                       "WHERE `entry` = %s", (sample_entry,))
    entry = _next_result_id()
    _copy_item_row(sample_entry, entry, int(sample["Quality"] or 0),
                   sample["name"] or "Merged Item", row["name_ru"])
    with world_cursor(commit=True) as cur:
        cur.execute("UPDATE `%s` SET `result_entry` = %%s WHERE `id` = %%s"
                    % T_MERGE, (entry, merge_id))
    return {"id": merge_id, "entry": entry}


def delete_merge(merge_id: int) -> None:
    _require()
    # Предмет-результат остаётся жить: он может лежать у игрока в сумке.
    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `merge_id` = %%s" % T_MERGE_ITEM,
                    (merge_id,))
        cur.execute("DELETE FROM `%s` WHERE `id` = %%s" % T_MERGE, (merge_id,))


def balance() -> dict:
    _require()
    return {
        "qualities": query(
            "SELECT `quality`, `name_ru`, `slots` FROM `%s` "
            "ORDER BY `quality`" % T_QUALITY),
        "chances": {
            str(int(r["quality"])): int(r["weight"])
            for r in query("SELECT `quality`, `weight` FROM `%s`" % T_CHANCE)
        },
    }


def save_balance(payload: Balance) -> dict:
    _require()
    if sum(max(0, int(w)) for w in payload.chances.values()) <= 0:
        raise ApError("Все веса качества нулевые — ковка не даст ничего.")

    with world_cursor(commit=True) as cur:
        for q in payload.qualities:
            cur.execute(
                "INSERT INTO `%s` (`quality`, `name_ru`, `slots`) "
                "VALUES (%%s, %%s, %%s) ON DUPLICATE KEY UPDATE "
                "`name_ru` = VALUES(`name_ru`), `slots` = VALUES(`slots`)"
                % T_QUALITY,
                (q.quality, _clean_text(q.name_ru, "Имя качества"), q.slots))
        for key, weight in payload.chances.items():
            if not str(key).isdigit():
                continue
            cur.execute(
                "INSERT INTO `%s` (`quality`, `weight`) VALUES (%%s, %%s) "
                "ON DUPLICATE KEY UPDATE `weight` = VALUES(`weight`)" % T_CHANCE,
                (int(key), max(0, int(weight))))
    # Имена качеств игрок читает из аддона.
    _bump_static_version()
    _bump_catalog_version()
    return balance()


# --- уровень предмета -> уровень персонажа --------------------------------
# В ковке НЕ УЧАСТВУЕТ: и числа, и уровень надевания стоят в одной строке
# item_template - той, что прописана результатом основы, и разойтись им негде
# (DESIGN §5.5). Таблица оставлена в схеме на случай, если вставки поедут в
# сторону «материал поднимает уровень предмета» (§5.7): тогда пересчёт
# понадобится именно здесь.

class IlvlRow(BaseModel):
    ilvl_max: int = Field(ge=1, le=300)
    req_level: int = Field(ge=1, le=80)


def ilvl_levels() -> list[dict]:
    _require()
    return [{"ilvl_max": int(r["ilvl_max"]), "req_level": int(r["req_level"])}
            for r in query("SELECT `ilvl_max`, `req_level` FROM `%s` "
                           "ORDER BY `ilvl_max`" % T_ILVL)]


def save_ilvl_levels(rows: list[IlvlRow]) -> list[dict]:
    _require()
    if not rows:
        raise ApError("Таблица не может быть пустой: очистить её нечем "
                      "заменить - удалите строки по одной.")

    ordered = sorted(rows, key=lambda r: r.ilvl_max)
    seen = set()
    for row in ordered:
        if row.ilvl_max in seen:
            raise ApError("Уровень предмета %d указан дважды." % row.ilvl_max)
        seen.add(row.ilvl_max)
    # Требуемый уровень обязан расти вместе с уровнем предмета: ступенька вниз
    # означает, что вещь посильнее надевается раньше, чем вещь послабее.
    for prev, nxt in zip(ordered, ordered[1:]):
        if nxt.req_level < prev.req_level:
            raise ApError(
                "Ступенька вниз: предмет %d требует %d уровня, а более слабый "
                "%d — уже %d. Требуемый уровень должен расти."
                % (nxt.ilvl_max, nxt.req_level, prev.ilvl_max, prev.req_level))

    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s`" % T_ILVL)
        for row in ordered:
            cur.execute("INSERT INTO `%s` (`ilvl_max`, `req_level`) VALUES "
                        "(%%s, %%s)" % T_ILVL, (row.ilvl_max, row.req_level))
    return ilvl_levels()


# --- настройки ------------------------------------------------------------

# Числа, которые нельзя оставлять на «как введут»: каждое из них молча ломает
# механику, а увидеть это можно только в игре.
SETTING_RANGE = {
    "base_chance": (1, 100),
    "fail_floor": (1, 100),
    "chance_step": (0, 100),
    "skill_per_ilvl": (1, 50),
    "gc_enabled": (0, 1),
    "fail_mode": (0, 2),
    "salvage_pct": (0, 100),
}


def settings() -> list[dict]:
    _require()
    return query("SELECT `name`, `value`, `comment` FROM `%s` ORDER BY `name`"
                 % T_CONFIG)


def save_settings(values: dict[str, str]) -> list[dict]:
    _require()
    known = {r["name"] for r in settings()}
    merged = {r["name"]: r["value"] for r in settings()}
    merged.update({k: str(v).strip() for k, v in values.items()})

    for name, value in values.items():
        if name not in known:
            raise ApError("Настройки «%s» нет." % name)
        lo, hi = SETTING_RANGE.get(name, (None, None))
        if lo is None:
            continue
        try:
            number = int(str(value).strip())
        except ValueError:
            raise ApError("«%s» — это число." % name) from None
        if not lo <= number <= hi:
            raise ApError("«%s»: допустимо от %d до %d." % (name, lo, hi))

    # Пол шанса выше базового означает кривую, которая растёт вниз; нулевой пол
    # означает основу, которую нельзя выковать никогда, сколько ни пробуй
    # (DESIGN §5.1.1).
    floor_, base_ = int(merged.get("fail_floor", 10)), int(merged.get("base_chance", 75))
    if floor_ > base_:
        raise ApError(
            "Нижняя граница шанса (%d %%) выше базового шанса (%d %%): кривая "
            "получится перевёрнутой." % (floor_, base_))

    with world_cursor(commit=True) as cur:
        for name, value in values.items():
            cur.execute("UPDATE `%s` SET `value` = %%s WHERE `name` = %%s"
                        % T_CONFIG, (str(value).strip(), name))
    # fail_mode решает, кэшируется ли каталог вообще, а прочие настройки в него
    # не входят - но лишний полный ответ дешевле забытого. Исключение одно:
    # саму версию каталога правят руками, чтобы поставить точное число, и
    # прибавка сверху отняла бы у этой правки смысл.
    if "catalog_version" not in values:
        _bump_catalog_version()
    return settings()


def success_chance(skill: int, req_skill: int,
                   cfg: dict[str, str] | None = None) -> dict:
    """Шанс, что ковка удастся. Формула одна на всех - сервер, аддон и панель
    считают её одинаково (DESIGN §5.1.1).

    Навык решает не «сколько получится», а «получится ли»: разрыв считается от
    требуемого навыка РЕЦЕПТА, который владелец проставил рукой. Никакой
    вычисляемой сложности работы нет - раз результат прописан рукой, проще
    прописать рукой и трудность, тогда они не разъедутся.
    """
    cfg = cfg or {r["name"]: r["value"] for r in settings()}
    gap = skill - req_skill
    raw = int(cfg.get("base_chance", 75)) + gap * int(cfg.get("chance_step", 1))
    chance = max(int(cfg.get("fail_floor", 10)), min(100, raw))
    return {"req_skill": req_skill, "gap": gap, "chance": chance,
            "floor": int(cfg.get("fail_floor", 10))}


# --- проверка -------------------------------------------------------------

def match(type_id: int, part_mats: list[int], part_counts: list[int],
          skill: int, mats: list[int] | None = None) -> dict:
    """Что выйдет из такого набора: тем же сравнением, что и сервер.

    Числа изделия здесь не считаются вовсе - их не из чего считать. Ответ на
    другой вопрос: совпал ли набор с основой, с каким шансом она выкуется при
    таком навыке, что уйдёт из сумки и что добавят вставки.
    """
    _require()
    scheme = _schemes().get(type_id, [])
    if not scheme:
        raise ApError("У типа нет ни одной ячейки - ковать нечем.")

    cfg = {r["name"]: r["value"] for r in settings()}
    known = {int(m["entry"]): m for m in materials()}

    # У ячейки два состояния: пусто либо предмет с количеством (DESIGN §5.4.1).
    cells = []
    spend: dict[int, int] = {}
    for i, part in enumerate(scheme):
        entry = int(part_mats[i]) if i < len(part_mats) else 0
        count = int(part_counts[i]) if i < len(part_counts) else 1
        mat = None
        if entry:
            mat = known.get(entry)
            if not mat:
                raise ApError("Материала %d нет в списке." % entry)
            if mat["role"] != "base":
                raise ApError("«%s» идёт в доводку, а не в ячейку схемы."
                              % (mat["name_ru"] or entry))
            if mat["part_kind_id"] != part["part_kind_id"]:
                raise ApError(
                    "«%s» ждёт род «%s», а «%s» - это «%s»."
                    % (part["label_ru"],
                       _dict_name(T_PART_KIND, part["part_kind_id"]),
                       mat["name_ru"],
                       _dict_name(T_PART_KIND, mat["part_kind_id"])))
            count = max(1, count)
            spend[entry] = spend.get(entry, 0) + count
        elif int(part["required"]):
            # Тот же отказ, что и на сервере (NEEDPART), и в том же месте - до
            # проверки «верстак пуст»: без обязательной части предмета не
            # существует, сравнивать нечего (DESIGN §5.4.1).
            raise ApError("«%s» - обязательная часть: пустой её не оставить."
                          % part["label_ru"])
        cells.append({"idx": part["idx"], "label": part["label_ru"],
                      "entry": entry, "name": mat["name_ru"] if mat else "",
                      "count": count if entry else 0})

    if not spend:
        raise ApError("Верстак пуст: положите хотя бы один материал.")

    # Сравнение точное и по всему набору: тот же предмет в том же количестве в
    # той же ячейке, а ячейка, которую основа не называет, обязана быть ПУСТОЙ
    # (DESIGN §5.4).
    hit = None
    for rec in recipes():
        if not rec["enabled"] or int(rec["type_id"]) != type_id:
            continue
        # Дроп-основа в сравнении не участвует - ровно как на сервере: ячеек у
        # неё может не быть ни одной, и пустой набор совпал бы с пустым
        # верстаком (DESIGN §2.5).
        if rec["acquire"] == "drop" or not rec["results"]:
            continue
        by_idx = {int(c["part_idx"]): c for c in rec["cells"]
                  if int(c["item_entry"])}
        ok = True
        for cell in cells:
            want = by_idx.get(cell["idx"])
            if not cell["entry"]:
                ok = want is None
            else:
                ok = (want is not None
                      and int(want["item_entry"]) == cell["entry"]
                      and int(want["count"]) == cell["count"])
            if not ok:
                break
        if ok:
            hit = rec
            break

    fail_mode = int(cfg.get("fail_mode", 2))
    type_row = next((t for t in types() if t["id"] == type_id), None)
    out: dict[str, Any] = {
        "cells": cells,
        "spend": [{"entry": e, "name": known[e]["name_ru"], "count": n}
                  for e, n in sorted(spend.items())],
        "fail_mode": fail_mode,
        "fail_entry": int((type_row or {}).get("fail_entry", 0)),
        "fail_item": (type_row or {}).get("fail_item"),
    }

    if not hit:
        # Набора нет ни в одной основе - неудачная попытка, а не ошибка ввода.
        out["recipe"] = None
        out["note"] = {
            0: "Ковка откажет: набора нет ни в одной основе, материалы целы.",
            1: "Ковка не удастся: материалы сгорят впустую.",
        }.get(fail_mode,
              "Ковка не удастся: материалы сгорят, на руках останется поделка.")
    else:
        out["recipe"] = {
            "id": hit["id"], "name_ru": hit["name_ru"],
            "req_skill": int(hit["req_skill"]),
            "quality_min": int(hit["quality_min"]),
            "quality_max": int(hit["quality_max"]),
            "results": [{"quality": int(r["quality"]),
                         "result_entry": int(r["result_entry"]),
                         "item": r["item"]} for r in hit["results"]],
            "issues": hit["issues"],
        }
        out["chance"] = success_chance(skill, int(hit["req_skill"]), cfg)
        # Любая неудача - одна цена: материалы сгорают, навык не растёт, на
        # руках поделка типа (решение владельца 2026-09-03).
        out["note"] = ("Провал броска сожжёт материалы и оставит поделку."
                       if out["chance"]["chance"] < 100 else "")

    out.update(_match_inserts(hit["id"] if hit else 0, mats or [], known))
    return out


def _match_inserts(recipe_id: int, mats: list[int],
                   known: dict[int, dict]) -> dict:
    """Вставки поверх изделия основы: сумма статов и именное сочетание.

    Общая половина обеих проверок: ковки (основа найдена набором ячеек) и
    именной (основа выбрана из списка, ячейки не нужны вовсе).
    """
    # Вставки: сырые статы складываются без множителей (DESIGN §5.7).
    totals: dict[int, int] = {}
    detail = []
    for entry in mats:
        mat = known.get(int(entry))
        if not mat:
            raise ApError("Материала %d нет в списке." % entry)
        if mat["role"] == "base":
            raise ApError("«%s» - материал ячейки, в слот он не идёт."
                          % (mat["name_ru"] or entry))
        if mat["stat_type"]:
            totals[mat["stat_type"]] = (totals.get(mat["stat_type"], 0)
                                        + int(mat["stat_value"]))
        detail.append({"entry": mat["entry"], "name": mat["name_ru"],
                       "stat_type": mat["stat_type"],
                       "value": int(mat["stat_value"])})

    # Именное сочетание принадлежит основе: те же камни в другой
    # основе дадут другое или ничего (DESIGN §5.6).
    hit_syn = None
    if recipe_id and mats:
        for syn in synergies():
            if not syn["enabled"] or int(syn["recipe_id"]) != recipe_id:
                continue
            same = (syn["mats"] == list(mats) if syn["order_matters"]
                    else sorted(syn["mats"]) == sorted(mats))
            if same:
                hit_syn = syn
                break
    return {
        "inserts": detail,
        "totals": [{"stat_type": st, "value": v}
                   for st, v in sorted(totals.items()) if v],
        "synergy": ({"id": hit_syn["id"], "name": hit_syn["name_ru"],
                     "result_entry": hit_syn["result_entry"],
                     "result": hit_syn["result"]} if hit_syn else None),
        # Несовпавший набор при завершении доводки портит вещь, как поделка -
        # поэтому аддон обязан показать это ДО нажатия (DESIGN §5.6).
        "finish_warning": bool(mats) and hit_syn is None,
    }


def match_named(recipe_id: int, mats: list[int]) -> dict:
    """Проверка именного: какое сочетание дадут эти вставки в этой основе.

    Основа выбирается прямо, а не находится набором ячеек: для вопроса «что
    выйдет из камней» ковать саму основу незачем. Ответ - те же вставки,
    сумма статов и сочетание, что и во второй половине `match`, плюс
    сочетания основы, чтобы было с чем сверяться.
    """
    _require()
    rec = next((r for r in recipes() if int(r["id"]) == int(recipe_id)), None)
    if rec is None:
        raise ApError("Основы %d нет." % recipe_id)
    if not mats:
        raise ApError("Слоты пусты: положите хотя бы одну вставку.")
    known = {int(m["entry"]): m for m in materials()}
    out = _match_inserts(int(rec["id"]), list(mats), known)
    out["recipe"] = {"id": rec["id"], "name_ru": rec["name_ru"],
                     "enabled": bool(rec["enabled"]),
                     "inlay": rec.get("inlay", [])}
    out["known"] = [{"id": syn["id"], "name": syn["name_ru"],
                     "mats": syn["mats"], "enabled": bool(syn["enabled"])}
                    for syn in synergies()
                    if int(syn["recipe_id"]) == int(rec["id"])]
    return out


# --- внешний вид ----------------------------------------------------------

# Выше этой границы живут сгенерированные предметы (worn-drops, gear-ascension,
# наш пул): арт у них заимствованный, и в выборе внешнего вида они дали бы
# десятки тысяч дублей одного и того же вида.
DISPLAY_SEARCH_MAX_ENTRY = 200000


def displays(q: str = "", item_class: int = -1, item_subclass: int = -1,
             limit: int = 60, offset: int = 0) -> dict:
    """Внешние виды для выбора иконки основы.

    Иконка не отдельное поле: она лежит в ItemDisplayInfo.dbc вместе с 3D-моделью,
    поэтому «выбрать иконку» - это выбрать `displayid` существующего предмета.
    Отсюда и способ искать: по предметам нужного класса, а не по текстурам.

    Одинаковые виды схлопываются: у сотни мечей может быть один и тот же арт, и
    сотня одинаковых картинок в выборе - это шум. Представителем становится
    предмет с наименьшим entry, а `n` показывает, насколько вид расхожий.
    """
    _require()

    # Класс необязателен: у основы он известен и сужает выбор, а синергия
    # может сработать на чём угодно, и там ограничивать нечем.
    where = ["`t`.`displayid` > 0", "`t`.`entry` < %s"]
    args: list[Any] = [DISPLAY_SEARCH_MAX_ENTRY]

    if int(item_class) >= 0:
        where.append("`t`.`class` = %s")
        args.append(int(item_class))

    if int(item_subclass) >= 0:
        where.append("`t`.`subclass` = %s")
        args.append(int(item_subclass))

    needle = (q or "").strip()
    if needle:
        # Ищем и по английскому имени, и по русскому: владелец думает
        # по-русски, а половина базы названа по-английски.
        where.append("(`t`.`name` LIKE %s OR EXISTS (SELECT 1 FROM "
                     "`item_template_locale` `l` WHERE `l`.`ID` = `t`.`entry` "
                     "AND `l`.`locale` = 'ruRU' AND `l`.`Name` LIKE %s))")
        args.extend(["%%%s%%" % needle, "%%%s%%" % needle])

    # Сколько видов всего: без этого числа выбор врёт молча - показанные 120
    # выглядят как «это всё», хотя одних мечей в базе под тысячу.
    total = query_one(
        "SELECT COUNT(DISTINCT `t`.`displayid`) AS n FROM `item_template` `t` "
        "WHERE %s" % " AND ".join(where), tuple(args))

    page = max(1, min(int(limit), 200))
    skip = max(0, int(offset))
    rows = query(
        "SELECT `t`.`displayid` AS display_id, MIN(`t`.`entry`) AS entry, "
        "COUNT(*) AS n FROM `item_template` `t` WHERE %s "
        "GROUP BY `t`.`displayid` ORDER BY `n` DESC, `entry` "
        "LIMIT %d OFFSET %d" % (" AND ".join(where), page, skip),
        tuple(args))

    info = _item_info([r["entry"] for r in rows])
    out = []
    for row in rows:
        entry = int(row["entry"])
        sample = info.get(entry) or {}
        out.append({
            "display_id": int(row["display_id"]),
            "entry": entry,
            "name": sample.get("name") or "?",
            "quality": sample.get("quality", 1),
            "icon": items.icon_texture(row["display_id"]),
            "used_by": int(row["n"]),
        })
    return {"displays": out, "total": int((total or {}).get("n", 0)),
            "offset": skip, "limit": page}


# --- выданные id ----------------------------------------------------------

def generated(limit: int = 200) -> dict:
    """Что уже выдано из пула. Только чтение: строки пишет модуль."""
    _require()
    rows = query(
        "SELECT `entry`, `source_entry`, `recipe_id`, `mats`, `created_at` "
        "FROM `%s` ORDER BY `entry` DESC LIMIT %%s"
        % T_GENERATED, (max(1, min(limit, 1000)),))
    total = query_one("SELECT COUNT(*) AS n FROM `%s`" % T_GENERATED)
    cfg = {r["name"]: r["value"] for r in settings()}

    # Пул нарезан ПО ОСНОВАМ - по строкам ap_recipe_result (DESIGN §2.5).
    # Основы различаются видом между собой, а строка клиентской Item.dbc
    # статична: одному слайсу двух моделей не показать. Показываем крайние
    # границы всех слайсов - по ним видно, какой блок занят модулем, - а
    # считаем по слайсам поимённо.
    slices = query(
        "SELECT r.`recipe_id`, r.`quality`, r.`result_entry`, r.`pool_lo`, "
        "r.`pool_hi`, c.`name_ru` FROM `%s` r "
        "JOIN `%s` c ON c.`id` = r.`recipe_id` "
        "WHERE r.`pool_lo` > 0 AND r.`pool_hi` >= r.`pool_lo` "
        "ORDER BY r.`pool_lo`" % (T_RECIPE_RESULT, T_RECIPE_NEW))
    lo = min((int(s["pool_lo"]) for s in slices), default=0)
    hi = max((int(s["pool_hi"]) for s in slices), default=0)

    quals = _qualities()
    # Свободные заготовки считаем по самим шаблонам предметов, а не по границам
    # слайса: засеяна у него только первая четверть тысячи, остальное резерв под
    # уплотнение полос, и строк там нет вовсе. Годится лишь тот id, который ядро
    # реально загрузит на старте.
    #
    # Оба числа берём ОДНИМ проходом на всю таблицу, а не запросом на слайс:
    # слайсов шесть сотен, и тысяча двести обращений к базе стоили вкладке
    # почти три секунды на каждое открытие - при том, что данных там на
    # семьдесят тысяч чисел. Забираем крайние границы целиком и режем список
    # по слайсам двоичным поиском: он отсортирован.
    #
    # Соединением это не делается: `JOIN ... ON entry BETWEEN lo AND hi`
    # MySQL считает больше трёх минут - диапазонное условие в соединении
    # индекс не спасает.
    blanks_all = [int(r["entry"]) for r in query(
        "SELECT `entry` FROM `item_template` WHERE `entry` BETWEEN %s AND %s "
        "ORDER BY `entry`", (lo, hi))] if lo else []
    taken_all = [int(r["entry"]) for r in query(
        "SELECT `entry` FROM `%s` WHERE `entry` BETWEEN %%s AND %%s "
        "ORDER BY `entry`" % T_GENERATED, (lo, hi))] if lo else []

    def _between(sorted_ids: list[int], low: int, high: int) -> int:
        return (bisect.bisect_right(sorted_ids, high)
                - bisect.bisect_left(sorted_ids, low))

    ready = 0
    per_type = []
    for row in slices:
        blank_count = _between(blanks_all, int(row["pool_lo"]),
                               int(row["pool_hi"]))
        taken_count = _between(taken_all, int(row["pool_lo"]),
                               int(row["pool_hi"]))
        ready += blank_count
        per_type.append({
            "recipe_id": int(row["recipe_id"]),
            "quality": int(row["quality"]),
            "result_entry": int(row["result_entry"]),
            "name_ru": "%s, %s" % (
                row["name_ru"],
                quals.get(int(row["quality"]), {}).get("name_ru",
                                                       row["quality"])),
            "lo": int(row["pool_lo"]),
            "hi": int(row["pool_hi"]),
            "blanks": blank_count,
            "used": taken_count,
            "free": max(0, blank_count - taken_count),
        })
    used = int((total or {}).get("n", 0))

    # Основы, которым слайса не досталось. Панель режет его сама при заведении
    # изделия, так что сюда попадают строки старше этой правки - и они опаснее
    # пустого списка: основа выглядит готовой, а доводка у неё отвечает
    # отказом.
    missing = [{
        "recipe_id": int(r["recipe_id"]),
        "quality": int(r["quality"]),
        "result_entry": int(r["result_entry"]),
        "name_ru": "%s, %s" % (
            r["name_ru"],
            quals.get(int(r["quality"]), {}).get("name_ru", r["quality"])),
    } for r in query(
        "SELECT r.`recipe_id`, r.`quality`, r.`result_entry`, c.`name_ru` "
        "FROM `%s` r JOIN `%s` c ON c.`id` = r.`recipe_id` "
        "WHERE r.`result_entry` <> 0 AND (r.`pool_lo` = 0 OR "
        "r.`pool_hi` < r.`pool_lo`) ORDER BY r.`recipe_id`, r.`quality`"
        % (T_RECIPE_RESULT, T_RECIPE_NEW))]

    # Строки, чьё изделие исчезло из item_template. Их entry модуль обязан
    # зарезервировать, а не вернуть в пул: иначе id уйдёт под другую комбинацию
    # и вещь в сумке игрока молча станет другой вещью (DESIGN §4, решение 3).
    orphans = query_one(
        "SELECT COUNT(*) AS n FROM `%s` g LEFT JOIN `item_template` t ON "
        "t.`entry` = g.`source_entry` WHERE t.`entry` IS NULL" % T_GENERATED)

    return {
        "rows": [dict(r, created_at=str(r["created_at"])) for r in rows],
        "total": used,
        "pool": {"lo": lo, "hi": hi, "size": max(0, hi - lo + 1),
                 # Заготовок в item_template, из них занято и свободно. Это
                 # единственное место, где видно приближение к PoolExhausted.
                 # Считать надо ПО ОСНОВАМ: кончиться может слайс одной
                 # основы, пока у остальных полно свободного.
                 "blanks": ready, "free": max(0, ready - used),
                 "types": per_type, "missing": missing,
                 "stride": POOL_STRIDE, "seed": POOL_SEED,
                 "orphans": int((orphans or {}).get("n", 0)),
                 "gc_enabled": cfg.get("gc_enabled", "1") == "1"},
    }


# --- мета -----------------------------------------------------------------

def bands() -> list[dict]:
    """Полосы лестницы: номер, границы уровня предмета, металл и навык.

    Нужны отбору на диаграмме: лестница из тринадцати полос - главная ось
    модуля, а узлы сгруппированы по типам предметов, и связать одно с другим
    можно только через требуемый навык основы.

    Таблицы может не быть вовсе (база без v32) - тогда отбор просто не
    покажется, а страница останется живой.
    """
    if not available() or not _has_table(T_BAND):
        return []
    return [
        {"idx": int(r["idx"]), "lo": int(r["lo"]), "hi": int(r["hi"]),
         "skill": int(r["skill"]), "name_ru": r["adj_m"]}
        for r in query("SELECT `idx`, `lo`, `hi`, `skill`, `adj_m` "
                       "FROM `%s` ORDER BY `idx`" % T_BAND)
    ]


def meta() -> dict[str, Any]:
    from . import config as panel_config
    return {
        "available": available(),
        "stats": STATS,
        "item_classes": ITEM_CLASSES,
        "weapon_subclasses": WEAPON_SUBCLASSES,
        "armor_subclasses": ARMOR_SUBCLASSES,
        "part_kinds": part_kinds(),
        "insert_types": insert_types(),
        "type_presets": TYPE_PRESETS,
        "max_slots": MAX_SLOTS,
        # Панель говорит на схеме v25 (пул нарезан по основам). Проверяем след
        # САМОЙ СВЕЖЕЙ миграции - той же колонки, что и worldserver. Если её
        # нет, страница честно скажет об этом, а не упадёт на первом SELECT.
        "revision": 25,
        "has_revision": _has_column(T_RECIPE_RESULT, "pool_lo"),
        # Ступени качества: их выбирают границами у основы, и по ним же
        # считается, сколько изделий он обязан иметь.
        "qualities": [
            {"quality": q, "name_ru": row["name_ru"], "slots": int(row["slots"])}
            for q, row in sorted(_qualities().items()) if q
        ] if available() and _has_column(T_RECIPE_NEW, "quality_min") else [],
        "result_block": {"lo": items.BLOCK_BY_ID[RESULT_BLOCK].lo,
                         "hi": items.BLOCK_BY_ID[RESULT_BLOCK].hi},
        "bands": bands(),
        "icon_base_url": panel_config.ICON_BASE_URL,
    }
