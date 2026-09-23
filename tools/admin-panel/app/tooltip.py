"""Подсказка предмета «как в игре»: строки в том порядке и тех цветах, что у клиента.

Собирается здесь, а не в браузере, потому что половина подсказки - не сам
предмет: описания заклинаний («Использование: …», «Если на персонаже: …»)
лежат в клиентском Spell.dbc и русском CSV (`spelldex`), а числа в них - это
`$s1`, `$d` и ссылки на чужие заклинания, которые надо подставить из строки
заклинания. Браузеру пришлось бы тянуть для этого пол-DBC.

Ответ - список строк `{"l": левый текст, "r": правый текст, "c": цвет}`.
Цвета - имена, а не коды: `q0`..`q7` (качество), `white`, `green`, `yellow`,
`gray`, `red`. Раскраску держит кит панели, сервер только называет её.

Чего тут нет и почему: сравнения с надетым (у панели нет персонажа), бонуса
за цвет гнёзд (SpellItemEnchantment.dbc панель не читает) и цены покупки.
"""

import re
from typing import Any

from . import items, spelldex
from .db import query, query_one

# --- словари клиента 3.3.5a (ruRU) ---------------------------------------

BONDING = {
    1: "Становится персональным при получении",
    2: "Становится персональным при надевании",
    3: "Становится персональным при использовании",
    4: "Предмет, необходимый для задания",
    5: "Предмет, необходимый для задания",
}

INVENTORY_TYPE = {
    1: "Голова", 2: "Шея", 3: "Плечи", 4: "Рубашка", 5: "Грудь", 6: "Пояс",
    7: "Ноги", 8: "Ступни", 9: "Запястья", 10: "Кисти рук", 11: "Палец",
    12: "Аксессуар", 13: "Одноручное", 14: "Левая рука", 15: "Дальний бой",
    16: "Спина", 17: "Двуручное", 18: "Сумка", 19: "Гербовая накидка",
    20: "Грудь", 21: "Правая рука", 22: "Левая рука",
    23: "Удерживается в левой руке", 24: "Боеприпасы", 25: "Метательное",
    26: "Дальний бой", 27: "Колчан", 28: "Реликвия",
}

WEAPON_SUBCLASS = {
    0: "Топор", 1: "Топор", 2: "Лук", 3: "Огнестрельное", 4: "Дробящее",
    5: "Дробящее", 6: "Древковое", 7: "Меч", 8: "Меч", 10: "Посох",
    13: "Кистевое", 14: "Разное", 15: "Кинжал", 16: "Метательное",
    17: "Копье", 18: "Арбалет", 19: "Жезл", 20: "Удочка",
}

ARMOR_SUBCLASS = {
    1: "Ткань", 2: "Кожа", 3: "Кольчуга", 4: "Латы", 6: "Щит",
    7: "Манускрипт", 8: "Идол", 9: "Тотем", 10: "Печать",
}

DAMAGE_SCHOOL = {
    1: "светом", 2: "огнем", 3: "силами природы", 4: "магией льда",
    5: "темной магией", 6: "тайной магией",
}

# Базовые характеристики - белым, «+N к силе».
BASE_STATS = {
    0: "к мане", 1: "к здоровью", 3: "к ловкости", 4: "к силе",
    5: "к интеллекту", 6: "к духу", 7: "к выносливости",
}

# Рейтинги и прочее - зелёным, «Если на персонаже: …».
EQUIP_STATS = {
    12: "Рейтинг защиты +%d.",
    13: "Рейтинг уклонения +%d.",
    14: "Рейтинг парирования +%d.",
    15: "Рейтинг блокирования щитом +%d.",
    16: "Рейтинг меткости в ближнем бою +%d.",
    17: "Рейтинг меткости дальнего боя +%d.",
    18: "Рейтинг меткости заклинаний +%d.",
    19: "Рейтинг критического удара в ближнем бою +%d.",
    20: "Рейтинг критического удара дальнего боя +%d.",
    21: "Рейтинг критического удара заклинаниями +%d.",
    28: "Рейтинг скорости в ближнем бою +%d.",
    29: "Рейтинг скорости дальнего боя +%d.",
    30: "Рейтинг скорости заклинаний +%d.",
    31: "Рейтинг меткости +%d.",
    32: "Рейтинг критического удара +%d.",
    35: "Рейтинг устойчивости +%d.",
    36: "Рейтинг скорости +%d.",
    37: "Рейтинг мастерства +%d.",
    38: "Сила атаки +%d.",
    39: "Сила атаки дальнего боя +%d.",
    40: "Сила атаки +%d в облике кошки, медведя и лютого медведя.",
    41: "Увеличивает эффективность исцеления на %d ед.",
    42: "Увеличивает урон от заклинаний на %d ед.",
    43: "Восполнение %d ед. маны раз в 5 сек.",
    44: "Рейтинг пробивания брони +%d.",
    45: "Сила заклинаний +%d.",
    46: "Восполнение %d ед. здоровья раз в 5 сек.",
    47: "Проникающая способность заклинаний +%d.",
    48: "Показатель блокирования +%d.",
}

RESISTANCES = [
    ("holy_res", "к сопротивлению светлой магии"),
    ("fire_res", "к сопротивлению огню"),
    ("nature_res", "к сопротивлению силам природы"),
    ("frost_res", "к сопротивлению магии льда"),
    ("shadow_res", "к сопротивлению темной магии"),
    ("arcane_res", "к сопротивлению тайной магии"),
]

SOCKETS = {1: "Особое гнездо", 2: "Красное гнездо", 4: "Желтое гнездо",
           8: "Синее гнездо"}

CLASSES = [(1, "Воин"), (2, "Паладин"), (4, "Охотник"), (8, "Разбойник"),
           (16, "Жрец"), (32, "Рыцарь смерти"), (64, "Шаман"), (128, "Маг"),
           (256, "Чернокнижник"), (1024, "Друид")]
ALL_CLASSES = sum(bit for bit, _ in CLASSES)

TRIGGER = {0: "Использование:", 1: "Если на персонаже:",
           2: "Вероятность при попадании:", 5: "Использование:",
           6: "Использование:"}

FLAG_HEROIC = 0x8
FLAG_UNIQUE_EQUIPPED = 0x80000
FLAG_ACCOUNT_BOUND = 0x8000000


# --- описание заклинания -------------------------------------------------

def _num(row: dict, col: str, index_: int) -> int:
    return int(row.get("%s_%d" % (col, index_)) or 0)


def _points(row: dict, index_: int) -> str:
    """$s1: как ядро читает базу - значение+1, или вилка при костях."""
    base = _num(row, "EffectBasePoints", index_)
    dice = _num(row, "EffectDieSides", index_)
    low = abs(base + 1)
    return "%d - %d" % (low, abs(base + dice)) if dice > 1 else str(low)


def _duration_ms(row: dict) -> int:
    dbc = spelldex.store().duration
    idx = int(row.get("DurationIndex") or 0)
    if dbc is None or not idx:
        return 0
    at = dbc.row_of(idx)
    return max(0, int(dbc.value(at, "Duration"))) if at is not None else 0


def _seconds(ms: int) -> str:
    if ms % 60000 == 0 and ms >= 60000:
        return "%d мин." % (ms // 60000)
    value = ms / 1000
    return ("%d сек." % value) if value == int(value) else ("%.1f сек." % value)


def _plural(number: float, forms: list[str]) -> str:
    """$lединицу:единицы:единиц; - по русским правилам, как клиент."""
    if len(forms) < 3:
        return forms[-1] if number != 1 else forms[0]
    n = abs(int(number)) % 100
    if 11 <= n <= 19:
        return forms[2]
    n %= 10
    return forms[0] if n == 1 else forms[1] if 2 <= n <= 4 else forms[2]


_TOKEN = re.compile(r"\$(\d+)?([smotdhxnuaz])(\d)?", re.I)


def _value(spell_id: int, kind: str, index_: int, own: dict) -> str:
    row = own
    if spell_id:
        merged = spelldex.merged_row(spell_id)
        if not merged:
            return "?"
        row = merged[0]
    kind = kind.lower()
    index_ = index_ or 1
    if kind in ("s", "m"):
        return _points(row, index_)
    if kind == "d":
        ms = _duration_ms(row)
        return _seconds(ms) if ms else ""
    if kind == "t":
        period = _num(row, "EffectAuraPeriod", index_)
        return ("%g" % (period / 1000)) if period else "?"
    if kind == "o":
        period = _num(row, "EffectAuraPeriod", index_)
        ticks = (_duration_ms(row) // period) if period else 0
        return str(abs(_num(row, "EffectBasePoints", index_) + 1) * max(1, ticks))
    if kind == "h":
        return str(int(row.get("ProcChance") or 0))
    if kind == "x":
        return str(_num(row, "EffectChainTargets", index_))
    if kind == "u":
        return str(int(row.get("StackAmount") or 0))
    if kind == "n":
        return str(int(row.get("ProcCharges") or 0))
    return "?"


def describe(spell_id: int) -> str:
    """Русское описание заклинания с подставленными числами."""
    text = spelldex.text().get(spell_id)
    desc = (text[2] if text else "") or ""
    if not desc:
        return ""
    merged = spelldex.merged_row(spell_id)
    own = merged[0] if merged else {}

    # ${...}: выражение. Сначала подставим числа, потом попробуем посчитать;
    # не вышло - оставляем как есть, без скобок.
    def expr(match: re.Match) -> str:
        inner = _TOKEN.sub(
            lambda m: _value(int(m.group(1) or 0), m.group(2), int(m.group(3) or 0),
                             own).split(" - ")[0], match.group(1))
        try:
            if re.fullmatch(r"[\d\s.+\-*/()]+", inner):
                value = eval(inner, {"__builtins__": {}}, {})  # noqa: S307
                return ("%d" % value) if float(value).is_integer() else ("%.1f" % value)
        except Exception:
            pass
        return inner

    desc = re.sub(r"\$\{([^}]*)\}", expr, desc)
    desc = _TOKEN.sub(lambda m: _value(int(m.group(1) or 0), m.group(2),
                                       int(m.group(3) or 0), own), desc)
    # $lform:form:form; - склонение по числу перед ним.
    def plural(match: re.Match) -> str:
        before = re.findall(r"(\d+)", desc[: match.start()])
        number = float(before[-1]) if before else 2
        return _plural(number, match.group(1).split(":"))
    desc = re.sub(r"\$[lL]([^;]*);", plural, desc)
    desc = re.sub(r"\$[gG]([^:;]*):[^;]*;", r"\1", desc)
    # «на 10 сек.» в конце фразы: точка сокращения и точка предложения
    # сливаются в одну, как у клиента.
    desc = re.sub(r"\.\.(?!\.)", ".", desc)
    return desc.replace("\r", "").strip()


# --- предмет -------------------------------------------------------------

def _ru(number: str) -> str:
    """Дробная часть через запятую - так пишет русский клиент."""
    return number.replace(".", ",")


def _money(copper: int) -> str:
    gold, rest = divmod(copper, 10000)
    silver, copper = divmod(rest, 100)
    parts = []
    if gold:
        parts.append("%d з." % gold)
    if silver:
        parts.append("%d с." % silver)
    if copper or not parts:
        parts.append("%d м." % copper)
    return " ".join(parts)


def _set_name(set_id: int) -> str:
    try:
        row = query_one("SELECT `name` FROM `item_set_names` WHERE `entry` = %s",
                        (set_id,))
        loc = query_one("SELECT `Name` FROM `item_set_names_locale` "
                        "WHERE `ID` = %s AND `locale` = %s", (set_id, items.RU))
    except Exception:
        return ""
    return ((loc or {}).get("Name") or (row or {}).get("name") or "")


def build(entry: int) -> dict | None:
    row = query_one("SELECT * FROM `item_template` WHERE `entry` = %s", (entry,))
    if not row:
        return None
    loc = query_one("SELECT `Name`, `Description` FROM `item_template_locale` "
                    "WHERE `ID` = %s AND `locale` = %s", (entry, items.RU)) or {}

    def num(col: str) -> int:
        value: Any = row.get(col)
        try:
            return int(value or 0)
        except (TypeError, ValueError):
            return 0

    lines: list[dict] = []

    def add(left: str, color: str = "white", right: str = "") -> None:
        lines.append({"l": left, "r": right, "c": color})

    quality = num("Quality")
    flags = num("Flags")
    add(loc.get("Name") or row.get("name") or "предмет %d" % entry, "q%d" % quality)
    if flags & FLAG_HEROIC:
        add("Героический", "green")
    if flags & FLAG_ACCOUNT_BOUND:
        add("Привязано к учетной записи")
    elif num("bonding") in BONDING:
        add(BONDING[num("bonding")])
    if num("maxcount") == 1:
        add("Уникальный")
    elif num("maxcount") > 1:
        add("Уникальный (%d)" % num("maxcount"))
    elif flags & FLAG_UNIQUE_EQUIPPED:
        add("Уникальный использующийся")

    item_class, subclass = num("class"), num("subclass")
    inv = num("InventoryType")
    if item_class == 1 and num("ContainerSlots"):
        add("Сумка на %d ячеек" % num("ContainerSlots"))
    elif inv in INVENTORY_TYPE:
        right = ""
        if item_class == 2:
            right = WEAPON_SUBCLASS.get(subclass, "")
        elif item_class == 4:
            right = ARMOR_SUBCLASS.get(subclass, "")
        add(INVENTORY_TYPE[inv], "white", right)

    # Оружие: урон, скорость, УВС.
    delay = num("delay")
    if item_class == 2 and delay:
        low, high = num("dmg_min1"), num("dmg_max1")
        if high:
            school = DAMAGE_SCHOOL.get(num("dmg_type1"))
            text_ = "Урон: %d - %d" % (low, high)
            if school:
                text_ += " (%s)" % school
            add(text_, "white", "Скорость " + _ru("%.2f" % (delay / 1000)))
        low2, high2 = num("dmg_min2"), num("dmg_max2")
        if high2:
            add("+ %d - %d ед. урона (%s)"
                % (low2, high2, DAMAGE_SCHOOL.get(num("dmg_type2"), "физ.")))
        if high or high2:
            dps = ((low + high) / 2 + (low2 + high2) / 2) / (delay / 1000)
            add("(%s ед. урона в секунду)" % _ru("%.1f" % dps))

    if num("armor"):
        add("Броня: %d" % num("armor"))
    if num("block"):
        add("Блок: %d" % num("block"))

    equip: list[str] = []
    for i in range(1, 11):
        stat, value = num("stat_type%d" % i), num("stat_value%d" % i)
        if not value:
            continue
        if stat in BASE_STATS:
            add("%+d %s" % (value, BASE_STATS[stat]))
        elif stat in EQUIP_STATS:
            equip.append(EQUIP_STATS[stat] % value)
    for col, label in RESISTANCES:
        if num(col):
            add("%+d %s" % (num(col), label))

    for i in (1, 2, 3):
        color = num("socketColor_%d" % i)
        if color:
            add(SOCKETS.get(color, "Гнездо"), "gray")

    if num("MaxDurability"):
        add("Прочность %d / %d" % (num("MaxDurability"), num("MaxDurability")))

    allowed = num("AllowableClass")
    if allowed > 0 and (allowed & ALL_CLASSES) != ALL_CLASSES:
        names = [name for bit, name in CLASSES if allowed & bit]
        if names:
            add("Классы: " + ", ".join(names))

    if num("RequiredLevel") > 1:
        add("Требуется уровень: %d" % num("RequiredLevel"))
    if num("ItemLevel"):
        add("Уровень предмета: %d" % num("ItemLevel"))

    for text_ in equip:
        add("Если на персонаже: " + text_, "green")

    for i in range(1, 6):
        spell_id = num("spellid_%d" % i)
        if not spell_id:
            continue
        trigger = num("spelltrigger_%d" % i)
        # Обучающий предмет: описание берётся у изучаемого заклинания.
        desc = describe(spell_id) if trigger != 6 else ""
        if trigger == 6:
            merged = spelldex.merged_row(spell_id)
            taught = int((merged[0] if merged else {}).get("EffectTriggerSpell_1") or 0)
            desc = describe(taught) if taught else describe(spell_id)
        if not desc:
            desc = spelldex.name_of(spell_id) or "заклинание %d" % spell_id
        add("%s %s" % (TRIGGER.get(trigger, "Использование:"), desc), "green")

    if num("itemset"):
        name = _set_name(num("itemset"))
        add(name or "Комплект %d" % num("itemset"), "yellow")

    desc = (loc.get("Description") or row.get("description") or "").strip()
    if desc:
        add("«%s»" % desc, "yellow")

    if num("SellPrice") and num("bonding") != 4:
        add("Цена продажи: %s" % _money(num("SellPrice")))

    return {"entry": entry, "quality": quality,
            "icon": items.icon_texture(row.get("displayid")), "lines": lines}
