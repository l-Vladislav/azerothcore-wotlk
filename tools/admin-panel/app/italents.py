"""mod-item-talents: «Пробуждение снаряжения» — чтение и запись данных.

Что редактируется (все таблицы в acore_world_ptr, миграция
data/sql/updates/pending_db_world/mod_item_talents_v3_admin.sql):

    item_talent_category       категории (бывшие захардкоженные пулы A..H)
    item_talent_category_rule  правила «какой предмет в какую категорию»
    item_talent_def            меню вариантов ряда для категории
    item_talent_row_cfg        сколько вариантов меню роллится (1..3) и
                               катается ли качество
    item_talent_item_def       ПЕРСОНАЛЬНЫЙ пул конкретного предмета (эпики+)
    item_talent_item_cfg       то же самое для персонального пула
    item_talent_kill_curve     пороги убийств по (качество, ilvl)
    item_talent_perk_library   библиотека готовых перков (её ядро не читает)

Семантика повторяет modules/mod-item-talents/src/ItemTalentsMgr.cpp:
  * предмет матчится правилами по (class, subclass, InvType, качество, entry),
    побеждает наибольший priority — это и есть его категория;
  * меню ряда = персональный пул предмета, если он задан, иначе меню категории
    (точный subclass сильнее subclass = -1);
  * из меню роллится roll_count вариантов в 3 слота UI: 10 вариантов и
    roll_count 3 = «3 случайных из 10», ровно 3 варианта = «всегда эти три»;
  * качество ролла (обычный/отличный/совершенный) катается, если
    quality_enabled = 1; для проков ряда 5 его выключают.

Записанное применяется на живом сервере командой `.itemtalent reload`
(POST /api/italents/reload) — рестарт не нужен.
"""

from pydantic import BaseModel, Field

from . import soap
from .db import cursor, query

T_CATEGORY = "item_talent_category"
T_RULE = "item_talent_category_rule"
T_DEF = "item_talent_def"
T_ROW_CFG = "item_talent_row_cfg"
T_ITEM_DEF = "item_talent_item_def"
T_ITEM_CFG = "item_talent_item_cfg"
T_PROCS = "item_talent_procs"
T_CURVE = "item_talent_kill_curve"
T_LIBRARY = "item_talent_perk_library"

MAX_ROWS = 5
MAX_SLOTS = 3          # столько слотов рисует аддон ItemTalentUI
MAX_CHOICES = 30       # ItemTalents::MAX_MENU_CHOICES

# Имена рядов — ровно те, что модуль показывает в госсипе (RowName()
# в ItemTalentsScripts.cpp). Расхождение читалось бы как другой ряд.
ROW_NAMES = {1: "Заточка", 2: "Закалка", 3: "Гравировка",
             4: "Насыщение", 5: "Пробуждение"}

QUALITY_NAMES = {0: "Серое", 1: "Белое", 2: "Зелёное", 3: "Синее",
                 4: "Эпическое", 5: "Легендарное", 6: "Артефакт",
                 7: "Наследие"}

# Ряды, открытые предмету по качеству (ItemTalentsMgr::RowsOpenForQuality).
# Пока это единственное, что осталось в C++ жёстко.
ROWS_BY_QUALITY = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 5, 7: 0}

ITEM_CLASSES = {2: "Оружие", 4: "Броня"}

ARMOR_SUBCLASSES = {0: "Разное", 1: "Ткань", 2: "Кожа", 3: "Кольчуга",
                    4: "Латы", 6: "Щит", 7: "Знак", 8: "Идол",
                    9: "Тотем", 10: "Печать"}

WEAPON_SUBCLASSES = {0: "Топор", 1: "Топор двуручный", 2: "Лук", 3: "Ружьё",
                     4: "Булава", 5: "Булава двуручная", 6: "Древковое",
                     7: "Меч", 8: "Меч двуручный", 10: "Посох",
                     13: "Кастеты", 15: "Кинжал", 16: "Метательное",
                     18: "Арбалет", 19: "Жезл", 20: "Удочка"}

# Эффекты, которые умеет применять ItemTalentsMgr::ApplyEffect. Чего здесь
# нет — модуль молча проигнорирует, поэтому панель ограничивает выбор.
# Формат значения: flat = ceil(base + per_ilvl * ilvl); pct = процент в base.
EFFECTS = [
    ("STAT_STA", "Выносливость", "flat"),
    ("STAT_STR", "Сила", "flat"),
    ("STAT_AGI", "Ловкость", "flat"),
    ("STAT_INT", "Интеллект", "flat"),
    ("STAT_SPI", "Дух", "flat"),
    ("ATTACK_POWER", "Сила атаки", "flat"),
    ("SPELL_POWER", "Сила заклинаний", "flat"),
    ("MANA_FLAT", "Мана", "flat"),
    ("MP5", "Мана в 5 сек", "flat"),
    ("RESIST_ALL", "Сопротивление всем школам", "flat"),
    ("SPELL_PEN", "Пробивание закл.", "flat"),
    ("BLOCK_VALUE", "Величина блока", "flat"),
    ("RATING_CRIT", "Рейтинг крит. удара", "flat"),
    ("RATING_HIT", "Рейтинг меткости", "flat"),
    ("RATING_HASTE", "Рейтинг скорости", "flat"),
    ("RATING_DEFENSE", "Рейтинг защиты", "flat"),
    ("RATING_DODGE", "Рейтинг уклонения", "flat"),
    ("RATING_PARRY", "Рейтинг парирования", "flat"),
    ("RATING_BLOCK", "Рейтинг блока", "flat"),
    ("RATING_ARMOR_PEN", "Пробивание брони", "flat"),
    ("DURA_SAVE", "Экономия прочности, %", "pct"),
    ("MOVE_SPEED_PCT", "Скорость бега, %", "pct"),
    ("HEAL_TAKEN_PCT", "Получаемое лечение, %", "pct"),
    ("PHYS_TAKEN_PCT", "Получаемый физ. урон, -%", "pct"),
    ("NEMESIS_DMG_PCT", "Урон по немезидам, %", "pct"),
    ("GOLD_XP_PCT", "Золото и опыт, %", "pct"),
    ("FAMILIAR_ALL_STATS", "Все статы при фамильяре", "flat"),
    ("PROC", "Прок ряда 5 (base = триггер-спелл)", "proc"),
]


# Диапазон spell id, который модуль считает «своим» (ItemTalents.h:
# TRIGGER_SPELL_FIRST..VISIBLE_SPELL_LAST). Каст из этого диапазона не
# порождает новых проков — иначе прок бил бы сам себя рекурсией. Спелл вне
# диапазона будет работать, но потеряет эту защиту.
SPELL_RANGE = (108000, 108092)

# Триггеры проков — строки, которые парсит ParseTrigger() в ItemTalentsProcs.cpp.
# Пометка «оценка» = у ядра нет хука с исходом удара, модуль роллит
# шанс события × шанс исхода (частота верная, момент не совпадает с боевым логом).
PROC_TRIGGERS = [
    ("MELEE_HIT", "Удар в ближнем бою"),
    ("MELEE_CRIT", "Крит в ближнем бою (оценка)"),
    ("ANY_CRIT", "Любой крит (оценка)"),
    ("RANGED_HIT", "Выстрел"),
    ("RANGED_CRIT", "Крит выстрелом (оценка)"),
    ("SPELL_CRIT", "Крит заклинанием (оценка)"),
    ("CAST_HARMFUL", "Боевой каст по врагу"),
    ("KILL", "Убийство"),
    ("TAKEN_HIT", "Получен урон"),
    ("TAKEN_CRIT", "Получен крит (оценка)"),
    ("DODGE", "Уклонение (оценка)"),
    ("PARRY", "Парирование (оценка)"),
    ("BLOCK", "Блок (оценка)"),
    ("LOW_HP", "Здоровье упало ниже порога"),
    ("BIG_HIT", "Тяжёлый удар (доля макс. HP)"),
]

# Эффекты проков — строки ParseEffect(). visible_spell задаёт визуал/школу/
# длительность, значение = ceil(coef * ilvl) подставляется как basepoints.
PROC_EFFECTS = [
    ("DAMAGE", "Урон цели"),
    ("DOT", "Периодический урон"),
    ("HEAL", "Лечение себя"),
    ("BUFF_SELF", "Бафф на себя"),
    ("DEBUFF_TARGET", "Дебафф цели (значение отрицательное)"),
    ("ABSORB", "Щит-поглощение"),
    ("EXTRA_ATTACK", "Дополнительные удары"),
    ("INTERRUPT", "Прерывание каста"),
    ("STUN", "Оглушение (боссы иммунны)"),
    ("AOE_DAMAGE", "Урон вокруг игрока"),
    ("CLEAVE", "Урон цели и соседям"),
    ("ENERGIZE", "Восстановление маны"),
    ("SUMMON", "Призыв фамильяра-фантома"),
    ("NEXT_HIT_BONUS", "Следующий удар сильнее"),
]

# Триггеры, которым нужен hp_threshold, и единственный, где важна school.
HP_TRIGGERS = {"LOW_HP", "BIG_HIT"}
SCHOOL_TRIGGER = "TAKEN_HIT"


# --- модели ---------------------------------------------------------------

class Category(BaseModel):
    code: str = Field(min_length=1, max_length=1)
    name_ru: str = ""
    comment: str = ""
    enabled: bool = True
    sort: int = 0


class Rule(BaseModel):
    code: str = Field(min_length=1, max_length=1)
    item_class: int = -1
    subclass: int = -1
    inv_type: int = -1
    quality_min: int = Field(default=0, ge=0, le=7)
    quality_max: int = Field(default=7, ge=0, le=7)
    entry_lo: int = 0
    entry_hi: int = 0
    priority: int = 0
    comment: str = ""


class Choice(BaseModel):
    """Один вариант в меню ряда (строка item_talent_def / item_talent_item_def)."""
    choice: int = Field(ge=1, le=MAX_CHOICES)
    name_ru: str = ""
    desc_ru: str = ""
    effect: str = "STAT_STA"
    base: float = 0
    per_ilvl: float = 0
    subclass: int = -1          # только для меню категории


class RowPayload(BaseModel):
    row: int = Field(ge=1, le=MAX_ROWS)
    roll_count: int = Field(default=MAX_SLOTS, ge=1, le=MAX_SLOTS)
    quality_enabled: bool = True
    choices: list[Choice] = Field(default_factory=list)


class Proc(BaseModel):
    """Строка item_talent_procs: механика прока ряда 5."""
    trigger_spell: int = Field(ge=1)     # ключ; на него ссылается base перка
    visible_spell: int = 0               # что реально кастуется (визуал/школа)
    trigger_type: str = "MELEE_HIT"
    effect_type: str = "DAMAGE"
    school: int = Field(default=0, ge=0, le=127)
    chance: int = Field(default=10, ge=0, le=100)
    icd_secs: int = Field(default=0, ge=0)
    coef: float = 0
    duration_secs: int = Field(default=0, ge=0)
    hp_threshold: int = Field(default=0, ge=0, le=100)


class Curve(BaseModel):
    id: int = 0
    name: str = ""
    quality_min: int = Field(default=0, ge=0, le=7)
    quality_max: int = Field(default=7, ge=0, le=7)
    ilvl_min: int = Field(default=0, ge=0, le=999)
    ilvl_max: int = Field(default=999, ge=0, le=999)
    lvl1: int = 50
    lvl2: int = 150
    lvl3: int = 400
    lvl4: int = 1000
    lvl5: int = 2500
    priority: int = 0


class Perk(BaseModel):
    id: int = 0
    name_ru: str = ""
    desc_ru: str = ""
    effect: str = "STAT_STA"
    base: float = 0
    per_ilvl: float = 0
    tags: str = ""


class Problem(BaseModel):
    level: str  # "error" | "warning"
    message: str


# --- служебное ------------------------------------------------------------

def _table_exists(name: str) -> bool:
    row = query(
        "SELECT COUNT(*) AS n FROM information_schema.tables"
        " WHERE table_schema = DATABASE() AND table_name = %s", (name,))
    return bool(row and int(row[0]["n"]))


def installed() -> bool:
    """Применена ли миграция V3. Без неё редактор бесполезен."""
    return _table_exists(T_CATEGORY) and _table_exists(T_RULE)


def meta() -> dict:
    return {
        "installed": installed(),
        "max_rows": MAX_ROWS,
        "max_slots": MAX_SLOTS,
        "max_choices": MAX_CHOICES,
        "row_names": ROW_NAMES,
        "quality_names": QUALITY_NAMES,
        "rows_by_quality": ROWS_BY_QUALITY,
        "item_classes": ITEM_CLASSES,
        "armor_subclasses": ARMOR_SUBCLASSES,
        "weapon_subclasses": WEAPON_SUBCLASSES,
        "effects": [{"code": c, "label": l, "kind": k} for c, l, k in EFFECTS],
        "proc_triggers": [{"code": c, "label": l} for c, l in PROC_TRIGGERS],
        "proc_effects": [{"code": c, "label": l} for c, l in PROC_EFFECTS],
        "spell_range": list(SPELL_RANGE),
        "hp_triggers": sorted(HP_TRIGGERS),
        "school_trigger": SCHOOL_TRIGGER,
        "procs_installed": _table_exists(T_PROCS),
    }


def _effect_codes() -> set[str]:
    return {c for c, _, _ in EFFECTS}


# --- категории и правила --------------------------------------------------

def categories() -> list[dict]:
    rows = query(
        f"SELECT code, name_ru, comment, enabled, sort FROM `{T_CATEGORY}`"
        f" ORDER BY sort, code")
    used = {r["pool"]: int(r["n"]) for r in query(
        f"SELECT pool, COUNT(*) AS n FROM `{T_DEF}` GROUP BY pool")}
    try:
        matched = category_counts()
    except Exception:          # кривое правило не должно ронять список
        matched = {}
    return [{
        "code": r["code"],
        "name_ru": r["name_ru"],
        "comment": r["comment"],
        "enabled": bool(r["enabled"]),
        "sort": int(r["sort"]),
        "choices": used.get(r["code"], 0),
        "items": matched.get(r["code"], 0),
    } for r in rows]


def rules() -> list[dict]:
    rows = query(
        f"SELECT id, code, item_class, subclass, inv_type, quality_min,"
        f" quality_max, entry_lo, entry_hi, priority, comment FROM `{T_RULE}`"
        f" ORDER BY priority DESC, id")
    return [dict(r) for r in rows]


def validate_categories(cats: list[Category], rule_rows: list[Rule]) -> list[Problem]:
    problems: list[Problem] = []
    codes = [c.code for c in cats]
    for code in set(codes):
        if codes.count(code) > 1:
            problems.append(Problem(level="error", message=f"Код «{code}» повторяется."))
    known = set(codes)
    for r in rule_rows:
        if r.code not in known:
            problems.append(Problem(
                level="error",
                message=f"Правило ссылается на несуществующую категорию «{r.code}»."))
        if r.quality_min > r.quality_max:
            problems.append(Problem(
                level="error",
                message=f"Категория «{r.code}»: качество от {r.quality_min} "
                        f"до {r.quality_max} — пустой диапазон."))
        if r.entry_hi and r.entry_lo > r.entry_hi:
            problems.append(Problem(
                level="error",
                message=f"Категория «{r.code}»: entry {r.entry_lo}-{r.entry_hi} пуст."))
    if not rule_rows:
        problems.append(Problem(
            level="warning",
            message="Правил нет — модуль вернётся к встроенной карте классов."))
    for c in cats:
        if c.enabled and not any(r.code == c.code for r in rule_rows):
            problems.append(Problem(
                level="warning",
                message=f"Категория «{c.name_ru or c.code}» включена, но ни одно "
                        f"правило её не выбирает."))
    return problems


def save_categories(cats: list[Category], rule_rows: list[Rule]) -> dict:
    with cursor(commit=True) as cur:
        cur.execute(f"DELETE FROM `{T_CATEGORY}`")
        if cats:
            cur.executemany(
                f"INSERT INTO `{T_CATEGORY}` (code, name_ru, comment, enabled, sort)"
                f" VALUES (%s, %s, %s, %s, %s)",
                [(c.code, c.name_ru, c.comment, int(c.enabled), c.sort) for c in cats])
        cur.execute(f"DELETE FROM `{T_RULE}`")
        if rule_rows:
            cur.executemany(
                f"INSERT INTO `{T_RULE}` (code, item_class, subclass, inv_type,"
                f" quality_min, quality_max, entry_lo, entry_hi, priority, comment)"
                f" VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                [(r.code, r.item_class, r.subclass, r.inv_type, r.quality_min,
                  r.quality_max, r.entry_lo, r.entry_hi, r.priority, r.comment)
                 for r in rule_rows])
    return {"categories": len(cats), "rules": len(rule_rows)}


def _rule_condition(r: dict) -> str:
    parts = []
    if int(r["item_class"]) >= 0:
        parts.append(f"it.class = {int(r['item_class'])}")
    if int(r["subclass"]) >= 0:
        parts.append(f"it.subclass = {int(r['subclass'])}")
    if int(r["inv_type"]) >= 0:
        parts.append(f"it.InventoryType = {int(r['inv_type'])}")
    parts.append(f"it.Quality BETWEEN {int(r['quality_min'])} "
                 f"AND {int(r['quality_max'])}")
    if int(r["entry_hi"]):
        parts.append(f"it.entry BETWEEN {int(r['entry_lo'])} "
                     f"AND {int(r['entry_hi'])}")
    return "(" + " AND ".join(parts) + ")"


def category_counts() -> dict[str, int]:
    """Сколько предметов item_template достаётся каждой категории.

    Считается ровно тем же порядком, что в модуле: правила перебираются по
    убыванию priority, побеждает первое совпавшее. В SQL это CASE — один
    проход по item_template вместо перебора 60k строк в питоне.
    """
    rule_rows = rules()
    if not rule_rows:
        return {}
    branches = " ".join(
        f"WHEN {_rule_condition(r)} THEN '{r['code']}'" for r in rule_rows)
    rows = query(
        f"SELECT CASE {branches} END AS code, COUNT(*) AS n"
        f" FROM item_template it GROUP BY code")
    return {r["code"]: int(r["n"]) for r in rows if r["code"]}


# --- меню категории -------------------------------------------------------

def category_rows(code: str) -> list[dict]:
    defs = query(
        f"SELECT `row`, choice, name_ru, desc_ru, effect, base, per_ilvl, subclass"
        f" FROM `{T_DEF}` WHERE pool = %s ORDER BY `row`, subclass, choice", (code,))
    cfg = {int(r["row"]): r for r in query(
        f"SELECT `row`, roll_count, quality_enabled FROM `{T_ROW_CFG}`"
        f" WHERE code = %s", (code,))}
    out = []
    for row in range(1, MAX_ROWS + 1):
        c = cfg.get(row)
        out.append({
            "row": row,
            "name": ROW_NAMES.get(row, str(row)),
            "roll_count": int(c["roll_count"]) if c else MAX_SLOTS,
            "quality_enabled": bool(int(c["quality_enabled"])) if c else row != MAX_ROWS,
            "choices": [{
                "choice": int(d["choice"]),
                "name_ru": d["name_ru"],
                "desc_ru": d["desc_ru"],
                "effect": d["effect"],
                "base": float(d["base"]),
                "per_ilvl": float(d["per_ilvl"]),
                "subclass": int(d["subclass"]),
            } for d in defs if int(d["row"]) == row],
        })
    return out


def _proc_trigger_ids() -> set[int]:
    """trigger_spell из item_talent_procs — единственные валидные base у PROC."""
    if not _table_exists(T_PROCS):
        return set()
    return {int(r["trigger_spell"]) for r in query(
        f"SELECT trigger_spell FROM `{T_PROCS}`")}


def _validate_row(payload: RowPayload, where: str) -> list[Problem]:
    problems: list[Problem] = []
    codes = _effect_codes()
    seen: set[tuple[int, int]] = set()
    for ch in payload.choices:
        key = (ch.choice, ch.subclass)
        if key in seen:
            problems.append(Problem(
                level="error",
                message=f"{where}: вариант {ch.choice} повторяется."))
        seen.add(key)
        if ch.effect not in codes:
            problems.append(Problem(
                level="error",
                message=f"{where}: эффект «{ch.effect}» модулю неизвестен."))
        if not ch.name_ru.strip():
            problems.append(Problem(
                level="error", message=f"{where}: вариант {ch.choice} без названия."))
        if ch.effect == "PROC":
            if not ch.base:
                problems.append(Problem(
                    level="error",
                    message=f"{where}: у прока base должен быть id триггер-спелла."))
            elif int(ch.base) not in _proc_trigger_ids():
                # Самая частая ошибка: в base подставляют id обычного спелла.
                # Модуль ищет base в item_talent_procs и, не найдя строки,
                # пишет в лог "perk is inert" и просто ничего не делает.
                problems.append(Problem(
                    level="error",
                    message=f"{where}: для триггера {int(ch.base)} нет строки в "
                            f"item_talent_procs — перк будет мёртвым. Заведите прок "
                            f"на вкладке «Проки ряда 5» или укажите существующий id."))
    if payload.choices and len(payload.choices) < payload.roll_count:
        problems.append(Problem(
            level="warning",
            message=f"{where}: вариантов {len(payload.choices)}, а роллится "
                    f"{payload.roll_count} — часть слотов останется пустой."))
    if payload.row == MAX_ROWS and payload.quality_enabled:
        problems.append(Problem(
            level="warning",
            message=f"{where}: ряд 5 — проки, качество ролла на них не влияет."))
    return problems


def validate_category_row(code: str, payload: RowPayload) -> list[Problem]:
    return _validate_row(payload, f"Категория {code}, ряд {payload.row}")


def save_category_row(code: str, payload: RowPayload) -> dict:
    with cursor(commit=True) as cur:
        cur.execute(f"DELETE FROM `{T_DEF}` WHERE pool = %s AND `row` = %s",
                    (code, payload.row))
        if payload.choices:
            cur.executemany(
                f"INSERT INTO `{T_DEF}` (pool, `row`, choice, name_ru, desc_ru,"
                f" effect, base, per_ilvl, subclass)"
                f" VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                [(code, payload.row, ch.choice, ch.name_ru, ch.desc_ru, ch.effect,
                  ch.base, ch.per_ilvl, ch.subclass) for ch in payload.choices])
        cur.execute(f"DELETE FROM `{T_ROW_CFG}` WHERE code = %s AND `row` = %s",
                    (code, payload.row))
        cur.execute(
            f"INSERT INTO `{T_ROW_CFG}` (code, `row`, roll_count, quality_enabled)"
            f" VALUES (%s, %s, %s, %s)",
            (code, payload.row, payload.roll_count, int(payload.quality_enabled)))
    return {"choices": len(payload.choices)}


# --- предметы (персональные пулы) ----------------------------------------

# Русские имена предметов лежат не в item_template, а в
# item_template_locale (locale = 'ruRU') — именно оттуда их берёт клиент с
# русской локалью. Панель показывает то же самое, что игрок видит в игре;
# английское имя остаётся рядом как `name_en` (у ~7.6k предметов, в основном
# устаревших и тестовых, ruRU-строки нет — тогда показываем enUS).
LOCALE = "ruRU"


def item_search(term: str = "", quality_min: int = 4, item_class: int = -1,
                only_custom: bool = False, limit: int = 200) -> list[dict]:
    """Поиск по item_template. По умолчанию — эпики и выше."""
    where = ["it.Quality >= %s"]
    args: list = [LOCALE, quality_min]
    if item_class >= 0:
        where.append("it.class = %s")
        args.append(item_class)
    if term.strip():
        # Ищем и по русскому, и по английскому имени: половина каталога
        # заведена нами по-русски, стоковые предметы удобнее искать по enUS.
        if term.strip().isdigit():
            where.append("(it.entry = %s OR it.name LIKE %s OR loc.Name LIKE %s)")
            args += [int(term.strip()), f"%{term.strip()}%", f"%{term.strip()}%"]
        else:
            where.append("(it.name LIKE %s OR loc.Name LIKE %s)")
            args += [f"%{term.strip()}%", f"%{term.strip()}%"]
    sql = (f"SELECT it.entry, COALESCE(loc.Name, it.name) AS name, it.name AS name_en,"
           f" it.Quality, it.ItemLevel, it.class,"
           f" it.subclass, it.InventoryType,"
           f" (SELECT COUNT(*) FROM `{T_ITEM_DEF}` d WHERE d.item_entry = it.entry)"
           f" AS own_choices"
           f" FROM item_template it"
           f" LEFT JOIN item_template_locale loc"
           f" ON loc.ID = it.entry AND loc.locale = %s"
           f" WHERE {' AND '.join(where)}")
    if only_custom:
        sql += (f" AND EXISTS (SELECT 1 FROM `{T_ITEM_DEF}` d2"
                f" WHERE d2.item_entry = it.entry)")
    sql += " ORDER BY it.ItemLevel DESC, it.entry LIMIT %s"
    args.append(int(limit))
    rows = query(sql, tuple(args))
    return [{
        "entry": int(r["entry"]),
        "name": r["name"],
        "name_en": r["name_en"],
        "quality": int(r["Quality"]),
        "ilvl": int(r["ItemLevel"]),
        "class": int(r["class"]),
        "subclass": int(r["subclass"]),
        "inv_type": int(r["InventoryType"]),
        "own_choices": int(r["own_choices"]),
    } for r in rows]


def item_detail(entry: int) -> dict:
    row = query(
        "SELECT it.entry, COALESCE(loc.Name, it.name) AS name, it.name AS name_en,"
        " it.Quality, it.ItemLevel, it.class, it.subclass, it.InventoryType"
        " FROM item_template it"
        " LEFT JOIN item_template_locale loc"
        " ON loc.ID = it.entry AND loc.locale = %s"
        " WHERE it.entry = %s", (LOCALE, entry))
    if not row:
        return {}
    it = row[0]
    quality = int(it["Quality"])

    # Категория предмета — тем же порядком правил, что в модуле
    category = None
    for r in rules():
        if int(r["item_class"]) >= 0 and int(r["item_class"]) != int(it["class"]):
            continue
        if int(r["subclass"]) >= 0 and int(r["subclass"]) != int(it["subclass"]):
            continue
        if int(r["inv_type"]) >= 0 and int(r["inv_type"]) != int(it["InventoryType"]):
            continue
        if not (int(r["quality_min"]) <= quality <= int(r["quality_max"])):
            continue
        if int(r["entry_hi"]) and not (int(r["entry_lo"]) <= entry <= int(r["entry_hi"])):
            continue
        category = r["code"]
        break

    defs = query(
        f"SELECT `row`, choice, name_ru, desc_ru, effect, base, per_ilvl"
        f" FROM `{T_ITEM_DEF}` WHERE item_entry = %s ORDER BY `row`, choice", (entry,))
    cfg = {int(r["row"]): r for r in query(
        f"SELECT `row`, roll_count, quality_enabled FROM `{T_ITEM_CFG}`"
        f" WHERE item_entry = %s", (entry,))}

    rows_out = []
    for row in range(1, MAX_ROWS + 1):
        c = cfg.get(row)
        own = [d for d in defs if int(d["row"]) == row]
        rows_out.append({
            "row": row,
            "name": ROW_NAMES.get(row, str(row)),
            "own": bool(own),
            "roll_count": int(c["roll_count"]) if c else MAX_SLOTS,
            "quality_enabled": bool(int(c["quality_enabled"])) if c else row != MAX_ROWS,
            "choices": [{
                "choice": int(d["choice"]),
                "name_ru": d["name_ru"],
                "desc_ru": d["desc_ru"],
                "effect": d["effect"],
                "base": float(d["base"]),
                "per_ilvl": float(d["per_ilvl"]),
                "subclass": -1,
            } for d in own],
        })

    return {
        "entry": entry,
        "name": it["name"],
        "name_en": it["name_en"],
        "quality": quality,
        "ilvl": int(it["ItemLevel"]),
        "class": int(it["class"]),
        "subclass": int(it["subclass"]),
        "inv_type": int(it["InventoryType"]),
        "category": category,
        "rows_open": ROWS_BY_QUALITY.get(quality, 0),
        "rows": rows_out,
    }


def validate_item_row(entry: int, payload: RowPayload) -> list[Problem]:
    problems = _validate_row(payload, f"Предмет {entry}, ряд {payload.row}")
    row = query("SELECT Quality FROM item_template WHERE entry = %s", (entry,))
    if not row:
        problems.append(Problem(level="error",
                                message=f"Предмета {entry} нет в item_template."))
        return problems
    quality = int(row[0]["Quality"])
    open_rows = ROWS_BY_QUALITY.get(quality, 0)
    if payload.choices and payload.row > open_rows and payload.row != MAX_ROWS:
        problems.append(Problem(
            level="warning",
            message=f"Качество «{QUALITY_NAMES.get(quality, quality)}» открывает "
                    f"только {open_rows} рядов — ряд {payload.row} игроку не виден."))
    return problems


def save_item_row(entry: int, payload: RowPayload) -> dict:
    with cursor(commit=True) as cur:
        cur.execute(f"DELETE FROM `{T_ITEM_DEF}` WHERE item_entry = %s AND `row` = %s",
                    (entry, payload.row))
        cur.execute(f"DELETE FROM `{T_ITEM_CFG}` WHERE item_entry = %s AND `row` = %s",
                    (entry, payload.row))
        if payload.choices:
            cur.executemany(
                f"INSERT INTO `{T_ITEM_DEF}` (item_entry, `row`, choice, name_ru,"
                f" desc_ru, effect, base, per_ilvl)"
                f" VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                [(entry, payload.row, ch.choice, ch.name_ru, ch.desc_ru, ch.effect,
                  ch.base, ch.per_ilvl) for ch in payload.choices])
            cur.execute(
                f"INSERT INTO `{T_ITEM_CFG}` (item_entry, `row`, roll_count,"
                f" quality_enabled) VALUES (%s, %s, %s, %s)",
                (entry, payload.row, payload.roll_count, int(payload.quality_enabled)))
    return {"choices": len(payload.choices), "own": bool(payload.choices)}


# --- проки ряда 5 (item_talent_procs) -------------------------------------

def _known_spell_ids(ids: set[int]) -> set[int]:
    """Какие из этих spell id реально есть в spell_dbc.

    Спелла нет — прок молча ничего не сделает: модуль кастует visible_spell
    через CastCustomSpell, а ядро без SpellInfo просто ничего не находит.
    """
    if not ids:
        return set()
    marks = ",".join(["%s"] * len(ids))
    rows = query(f"SELECT ID FROM spell_dbc WHERE ID IN ({marks})", tuple(sorted(ids)))
    return {int(r["ID"]) for r in rows}


def procs() -> list[dict]:
    if not _table_exists(T_PROCS):
        return []
    rows = query(
        f"SELECT trigger_spell, visible_spell, trigger_type, effect_type, school,"
        f" chance, icd_secs, coef, duration_secs, hp_threshold FROM `{T_PROCS}`"
        f" ORDER BY trigger_spell")

    # Кто ссылается на прок: перки с effect='PROC' и base = trigger_spell —
    # и в меню категорий, и в персональных пулах предметов.
    used: dict[int, list[str]] = {}
    for r in query(f"SELECT base, name_ru FROM `{T_DEF}` WHERE effect = 'PROC'"):
        used.setdefault(int(r["base"]), []).append(r["name_ru"])
    if _table_exists(T_ITEM_DEF):
        for r in query(f"SELECT base, name_ru FROM `{T_ITEM_DEF}` WHERE effect = 'PROC'"):
            used.setdefault(int(r["base"]), []).append(r["name_ru"])

    ids = {int(r["trigger_spell"]) for r in rows} | {int(r["visible_spell"]) for r in rows}
    known = _known_spell_ids(ids)

    out = []
    for r in rows:
        trigger = int(r["trigger_spell"])
        visible = int(r["visible_spell"])
        names = sorted(set(used.get(trigger, [])))
        out.append({
            "trigger_spell": trigger,
            "visible_spell": visible,
            "trigger_type": r["trigger_type"],
            "effect_type": r["effect_type"],
            "school": int(r["school"]),
            "chance": int(r["chance"]),
            "icd_secs": int(r["icd_secs"]),
            "coef": float(r["coef"]),
            "duration_secs": int(r["duration_secs"]),
            "hp_threshold": int(r["hp_threshold"]),
            "perks": names,
            "trigger_in_dbc": trigger in known,
            "visible_in_dbc": visible in known,
        })
    return out


def free_proc_spells() -> dict:
    """Свободные id внутри «своего» диапазона модуля.

    Триггеры и видимые спеллы живут в одном диапазоне 108000-108092: занятое
    показываем, чтобы новый прок не сел на чужой id и не вышел за границу,
    где перестаёт работать защита от рекурсии.
    """
    lo, hi = SPELL_RANGE
    taken: set[int] = set()
    if _table_exists(T_PROCS):
        for r in query(f"SELECT trigger_spell, visible_spell FROM `{T_PROCS}`"):
            taken.add(int(r["trigger_spell"]))
            taken.add(int(r["visible_spell"]))
    in_dbc = {int(r["ID"]) for r in query(
        "SELECT ID FROM spell_dbc WHERE ID BETWEEN %s AND %s", (lo, hi))}
    free = [i for i in range(lo, hi + 1) if i not in taken]
    return {
        "range": [lo, hi],
        "free": free,
        "free_with_spell_row": [i for i in free if i in in_dbc],
        "used": sorted(taken),
    }


def validate_procs(rows: list[Proc]) -> list[Problem]:
    problems: list[Problem] = []
    triggers = {c for c, _ in PROC_TRIGGERS}
    effects = {c for c, _ in PROC_EFFECTS}
    lo, hi = SPELL_RANGE

    seen: set[int] = set()
    for p in rows:
        tag = f"Прок {p.trigger_spell}"
        if p.trigger_spell in seen:
            problems.append(Problem(level="error", message=f"{tag}: id повторяется."))
        seen.add(p.trigger_spell)

        if p.trigger_type not in triggers:
            problems.append(Problem(
                level="error", message=f"{tag}: триггер «{p.trigger_type}» модулю неизвестен."))
        if p.effect_type not in effects:
            problems.append(Problem(
                level="error", message=f"{tag}: эффект «{p.effect_type}» модулю неизвестен."))
        if not p.chance:
            problems.append(Problem(
                level="warning", message=f"{tag}: шанс 0 — прок никогда не сработает."))
        if p.trigger_type in HP_TRIGGERS and not p.hp_threshold:
            problems.append(Problem(
                level="warning",
                message=f"{tag}: триггеру {p.trigger_type} нужен порог здоровья "
                        f"(hp_threshold), иначе условие всегда ложно."))
        if p.school and p.trigger_type != SCHOOL_TRIGGER:
            problems.append(Problem(
                level="warning",
                message=f"{tag}: school читается только у {SCHOOL_TRIGGER}, "
                        f"здесь он ни на что не влияет."))
        if not (lo <= p.trigger_spell <= hi) or not (lo <= p.visible_spell <= hi):
            problems.append(Problem(
                level="warning",
                message=f"{tag}: id вне диапазона {lo}-{hi}. Прок сработает, но каст "
                        f"перестанет считаться «своим» — возможна рекурсия проков."))

    ids = {p.trigger_spell for p in rows} | {p.visible_spell for p in rows if p.visible_spell}
    known = _known_spell_ids(ids)
    for p in rows:
        if p.visible_spell and p.visible_spell not in known:
            problems.append(Problem(
                level="error",
                message=f"Прок {p.trigger_spell}: спелла {p.visible_spell} нет в spell_dbc — "
                        f"эффект будет пустым. Заведите строку в мастерской спеллов."))
        if p.trigger_spell not in known:
            problems.append(Problem(
                level="warning",
                message=f"Прок {p.trigger_spell}: триггер-спелла нет в spell_dbc. "
                        f"Сам прок работает (это лишь ключ), но маркера на игроке не будет."))

    problems.append(Problem(
        level="warning",
        message="Новые строки spell_dbc подхватываются только при РЕСТАРТЕ "
                "worldserver — .itemtalent reload их не перечитывает."))
    return problems


def save_procs(rows: list[Proc]) -> dict:
    with cursor(commit=True) as cur:
        cur.execute(f"DELETE FROM `{T_PROCS}`")
        if rows:
            cur.executemany(
                f"INSERT INTO `{T_PROCS}` (trigger_spell, visible_spell, trigger_type,"
                f" effect_type, school, chance, icd_secs, coef, duration_secs, hp_threshold)"
                f" VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                [(p.trigger_spell, p.visible_spell, p.trigger_type, p.effect_type,
                  p.school, p.chance, p.icd_secs, p.coef, p.duration_secs,
                  p.hp_threshold) for p in rows])
    return {"procs": len(rows)}


# --- пороги убийств -------------------------------------------------------

def curves() -> list[dict]:
    rows = query(
        f"SELECT id, name, quality_min, quality_max, ilvl_min, ilvl_max,"
        f" lvl1, lvl2, lvl3, lvl4, lvl5, priority FROM `{T_CURVE}`"
        f" ORDER BY priority DESC, ilvl_min, id")
    return [dict(r) for r in rows]


def validate_curves(rows: list[Curve]) -> list[Problem]:
    problems: list[Problem] = []
    for c in rows:
        if c.ilvl_min > c.ilvl_max:
            problems.append(Problem(
                level="error",
                message=f"«{c.name or c.id}»: ilvl {c.ilvl_min}-{c.ilvl_max} пуст."))
        if c.quality_min > c.quality_max:
            problems.append(Problem(
                level="error",
                message=f"«{c.name or c.id}»: качество {c.quality_min}-"
                        f"{c.quality_max} пусто."))
        segments = [c.lvl1, c.lvl2, c.lvl3, c.lvl4, c.lvl5]
        if any(s < 1 for s in segments):
            problems.append(Problem(
                level="warning",
                message=f"«{c.name or c.id}»: сегмент 0 = уровень недостижим."))
    if not rows:
        problems.append(Problem(
            level="warning",
            message="Кривых нет — модуль вернётся к ItemTalents.PointThresholds "
                    "из конфига (одинаково для любого ilvl)."))
    return problems


def save_curves(rows: list[Curve]) -> dict:
    with cursor(commit=True) as cur:
        cur.execute(f"DELETE FROM `{T_CURVE}`")
        if rows:
            cur.executemany(
                f"INSERT INTO `{T_CURVE}` (name, quality_min, quality_max, ilvl_min,"
                f" ilvl_max, lvl1, lvl2, lvl3, lvl4, lvl5, priority)"
                f" VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                [(c.name, c.quality_min, c.quality_max, c.ilvl_min, c.ilvl_max,
                  c.lvl1, c.lvl2, c.lvl3, c.lvl4, c.lvl5, c.priority) for c in rows])
    return {"curves": len(rows)}


# --- библиотека перков ----------------------------------------------------

def library() -> list[dict]:
    rows = query(
        f"SELECT id, name_ru, desc_ru, effect, base, per_ilvl, tags"
        f" FROM `{T_LIBRARY}` ORDER BY effect, name_ru")
    return [dict(r) for r in rows]


def save_library(rows: list[Perk]) -> dict:
    with cursor(commit=True) as cur:
        cur.execute(f"DELETE FROM `{T_LIBRARY}`")
        if rows:
            cur.executemany(
                f"INSERT INTO `{T_LIBRARY}` (name_ru, desc_ru, effect, base,"
                f" per_ilvl, tags) VALUES (%s, %s, %s, %s, %s, %s)",
                [(p.name_ru, p.desc_ru, p.effect, p.base, p.per_ilvl, p.tags)
                 for p in rows])
    return {"perks": len(rows)}


# --- применение на живом сервере ------------------------------------------

def reload_engine() -> str:
    """`.itemtalent reload` — модуль перечитывает все таблицы без рестарта."""
    return soap.execute(".itemtalent reload")
