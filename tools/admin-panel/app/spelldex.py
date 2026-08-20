"""Spell catalogue — every spell the server knows, read-only.

The workshop (`spells.py`) edits the few hundred spells we own. This module
answers the other question: *what already exists?* It merges the three places a
spell can live, in the same order the worldserver does:

  1. `data/dbc/Spell.dbc` from the client-data volume — 49 839 stock records,
     the file `LoadDBCStores` reads first;
  2. `acore_world_ptr.spell_dbc` — rows modules and the workshop add, which
     `DBCStorage::LoadFromDB` merges on top, overriding by id;
  3. `.claude/dbc/Spell.csv` — the ruRU client export, used for text only. The
     extracted binary DBCs are enUS, so without this the catalogue would be an
     English one; with it, names and tooltips read the way they do in game.

Everything is derived and cached, never written: the catalogue has no save
path at all, which is what makes it safe to point at 49 839 Blizzard spells.

Cost: the index is built on first use (~3 s, mostly the CSV) and pinned. A
spell's full row is unpacked from the mmap on demand, so browsing stays cheap.
"""

import bisect
import csv
import os
import threading
from typing import Any, Iterable

from . import config, dbc as dbc_csv, dbcfile, spells
from .db import query

csv.field_size_limit(10 ** 9)

# Column indices in .claude/dbc/Spell.csv. The file's locale headers are
# mislabelled — the Russian string sits eight slots after enUS, at the position
# the header calls zhTW. Verified against spell 133 ("Огненный шар").
CSV_ID = 0
CSV_ICON = 131
CSV_NAME_RU = 142
CSV_RANK_RU = 159
CSV_DESC_RU = 176
CSV_AURA_RU = 193
CSV_MIN_COLS = 200

SOURCE_DBC = "dbc"          # stock, untouched
SOURCE_OVERRIDE = "override"  # stock row a module rewrote in spell_dbc
SOURCE_CUSTOM = "custom"    # exists only in spell_dbc

SOURCE_LABELS = {
    SOURCE_DBC: "клиентский DBC",
    SOURCE_OVERRIDE: "изменён в spell_dbc",
    SOURCE_CUSTOM: "добавлен в spell_dbc",
}

# Spell families are how the core groups class spells; the DBC calls the column
# SpellClassSet. Labels stay Russian because this is a filter people read.
FAMILY_LABELS = {
    0: "Общие", 1: "События и праздники", 3: "Маг", 4: "Воин", 5: "Чернокнижник",
    6: "Жрец", 7: "Друид", 8: "Разбойник", 9: "Охотник", 10: "Паладин",
    11: "Шаман", 12: "Прочее", 13: "Зелья", 15: "Рыцарь смерти", 17: "Питомцы",
}

SCHOOL_LABELS = {
    0: "Физическая", 1: "Светлая", 2: "Огонь", 3: "Природа",
    4: "Лёд", 5: "Тень", 6: "Тайная магия",
}

POWER_LABELS = {
    0: "мана", 1: "ярость", 2: "фокус", 3: "энергия", 4: "счастье",
    5: "руны", 6: "сила рун", -2: "здоровье",
}


# --- lazily opened DBC files ----------------------------------------------

class Store:
    """Every DBC the catalogue reads, opened once."""

    def __init__(self, directory: str):
        self.directory = directory
        self.spell = dbcfile.open_dbc(directory, "Spell", dbcfile.SPELL_COLUMNS)
        self.icon = dbcfile.open_dbc(directory, "SpellIcon",
                                     dbcfile.SPELL_ICON_COLUMNS)
        self.duration = dbcfile.open_dbc(directory, "SpellDuration",
                                         dbcfile.SPELL_DURATION_COLUMNS)
        self.range = dbcfile.open_dbc(directory, "SpellRange",
                                      dbcfile.SPELL_RANGE_COLUMNS)
        self.cast = dbcfile.open_dbc(directory, "SpellCastTimes",
                                     dbcfile.SPELL_CAST_TIMES_COLUMNS)
        self.radius = dbcfile.open_dbc(directory, "SpellRadius",
                                       dbcfile.SPELL_RADIUS_COLUMNS)
        self.skill = dbcfile.open_dbc(directory, "SkillLine",
                                      dbcfile.SKILL_LINE_COLUMNS)
        self.skill_ability = dbcfile.open_dbc(directory, "SkillLineAbility",
                                              dbcfile.SKILL_LINE_ABILITY_COLUMNS)

    @property
    def ok(self) -> bool:
        return self.spell is not None


_lock = threading.Lock()
_store: Store | None = None
_index: list[tuple] | None = None
_by_id: dict[int, int] | None = None
_text: dict[int, tuple[str, str, str, str]] | None = None
_custom_icon: dict[int, int] | None = None
_icons: dict[int, str] | None = None
_icon_ids: dict[str, int] | None = None
_db_rows: dict[int, dict] | None = None
_triggered_by: dict[int, list[int]] | None = None
_skills_of: dict[int, list[dict]] | None = None


def store() -> Store:
    global _store
    if _store is None:
        _store = Store(config.DBC_DIR)
    return _store


def available() -> bool:
    return store().ok


def invalidate() -> None:
    """Drop the cached merge. Called after the workshop writes `spell_dbc`.

    Deliberately keeps the parsed CSV text: re-reading a 54 MB file on every
    spell save would make saving take three seconds. Text is refreshed by
    `reload_files()` instead, which is what the "обновить справочники" action
    calls.
    """
    global _index, _by_id, _db_rows, _triggered_by
    with _lock:
        _index = None
        _by_id = None
        _db_rows = None
        _triggered_by = None


def reload_files() -> None:
    """Re-read everything from disk — after Spell_custom.csv is regenerated."""
    global _store, _text, _custom_icon, _icons, _icon_ids, _skills_of
    with _lock:
        _store = None
        _text = None
        _custom_icon = None
        _icons = None
        _icon_ids = None
        _skills_of = None
    invalidate()


# --- text overlay ---------------------------------------------------------

def _read_text_csv(path: str, into: dict, icon_into: dict | None = None) -> int:
    if not os.path.isfile(path):
        return 0
    read = 0
    with open(path, encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        next(reader, None)
        for row in reader:
            if len(row) < CSV_MIN_COLS or not row[CSV_ID].isdigit():
                continue
            spell_id = int(row[CSV_ID])
            into[spell_id] = (row[CSV_NAME_RU], row[CSV_RANK_RU],
                              row[CSV_DESC_RU], row[CSV_AURA_RU])
            if icon_into is not None and row[CSV_ICON].isdigit():
                icon_into[spell_id] = int(row[CSV_ICON])
            read += 1
    return read


def text() -> dict[int, tuple[str, str, str, str]]:
    """id → (name, rank, description, aura description), all Russian."""
    global _text, _custom_icon
    if _text is None:
        out: dict[int, tuple[str, str, str, str]] = {}
        custom_icons: dict[int, int] = {}
        _read_text_csv(config.SPELL_CSV, out)
        # Custom spells are appended to their own CSV; later wins. That file is
        # also the only place a custom spell's *real* icon id is recorded —
        # `spell_dbc.SpellIconID` is a placeholder the client never reads.
        _read_text_csv(config.SPELL_CUSTOM_CSV, out, custom_icons)
        _text = out
        _custom_icon = custom_icons
    return _text


def custom_icon_ids() -> dict[int, int]:
    text()
    return _custom_icon or {}


def _basename(path: str) -> str:
    return path.replace("/", "\\").rsplit("\\", 1)[-1].lower()


def icons() -> dict[int, str]:
    """SpellIconID → texture base name, lowercased the way icon CDNs want."""
    global _icons
    if _icons is None:
        out: dict[int, str] = {}
        icon_dbc = store().icon
        if icon_dbc is not None:
            for row in range(icon_dbc.count):
                path = icon_dbc.value(row, "TextureFilename") or ""
                if path:
                    out[icon_dbc.int_at(row, 0)] = _basename(path)
        # Icons the client-side MPQ adds on top of the stock file.
        if os.path.isfile(config.SPELL_ICON_CUSTOM_CSV):
            with open(config.SPELL_ICON_CUSTOM_CSV, encoding="utf-8",
                      newline="") as handle:
                reader = csv.reader(handle)
                next(reader, None)
                for row in reader:
                    if len(row) >= 2 and row[0].isdigit() and row[1]:
                        out[int(row[0])] = _basename(row[1])
        _icons = out
    return _icons


# `spell_dbc.SpellIconID` is 1 ("trade_engineering") for every spell a module
# adds — a stub nothing reads. Showing it would put an engineering wrench on a
# hundred custom auras, so a stub is treated as "no icon" and the real texture
# is looked up where it is actually recorded.
STUB_ICON_IDS = (0, 1)


def icon_id_of(texture: str) -> int:
    """Texture base name → `SpellIconID`, or 0 if the client has no such icon.

    The reverse of `icons()`. The workshop needs it because the operator picks
    a *picture*, while the row the client reads stores an *id*.
    """
    global _icon_ids
    if _icon_ids is None:
        # Several ids can share a texture; the lowest is the stock one.
        mapping: dict[str, int] = {}
        for icon_id, name in sorted(icons().items()):
            mapping.setdefault(name, icon_id)
        _icon_ids = mapping
    return _icon_ids.get(_basename(texture or ""), 0)


def resolved_icon(spell_id: int, row: dict, source: str) -> tuple[int, str]:
    """(icon id, texture) as the client actually draws them.

    A module rewriting a stock spell leaves `SpellIconID` at the placeholder 1,
    so the merged row cannot be trusted for an override — the id to use is the
    one still sitting in the client's own Spell.dbc.
    """
    icon_id = int(row.get("SpellIconID") or 0)
    if source == SOURCE_OVERRIDE and icon_id in STUB_ICON_IDS:
        dbc = store().spell
        dbc_row = dbc.row_of(spell_id) if dbc is not None else None
        if dbc_row is not None:
            icon_id = int(dbc.value(dbc_row, "SpellIconID"))
    return icon_id, icon_texture(spell_id, icon_id, source)


def workshop_icon(spell_id: int, icon_id: int) -> str:
    """The texture a spell of ours actually draws with, for the workshop.

    The workshop knows only `spell_meta.icon_texture`, which exists solely for
    spells authored in the panel — a module's own spells record their picture in
    `Spell_custom.csv` or leave it in `SpellIconID`, and showed up here as a
    blank square while the catalogue drew them fine. This is the catalogue's
    resolution, minus the index: `row_of` is a dict lookup, so nothing pays for
    building the 50 000-row catalogue just to draw one icon.
    """
    dbc = store().spell
    in_client = dbc is not None and dbc.row_of(spell_id) is not None
    source = SOURCE_OVERRIDE if in_client else SOURCE_CUSTOM
    return resolved_icon(spell_id, {"SpellIconID": icon_id}, source)[1]


def icon_texture(spell_id: int, icon_id: int, source: str) -> str:
    """The texture the client really draws for this spell, or "" if unknown."""
    manifest = dbc_csv.spell_meta().get(spell_id)
    if manifest and manifest.get("icon_texture"):
        return _basename(manifest["icon_texture"])

    custom = custom_icon_ids().get(spell_id)
    if custom:
        texture = icons().get(custom, "")
        if texture:
            return texture

    if source == SOURCE_CUSTOM and icon_id in STUB_ICON_IDS:
        return ""
    return icons().get(icon_id, "")


# --- database overlay -----------------------------------------------------

DB_INDEX_COLUMNS = [
    "ID", "Name_Lang_ruRU", "Name_Lang_enUS", "NameSubtext_Lang_ruRU",
    "SchoolMask", "SpellLevel", "SpellClassSet", "SpellIconID", "Mechanic",
    "Effect_1", "Effect_2", "Effect_3",
    "EffectAura_1", "EffectAura_2", "EffectAura_3",
]


def db_rows() -> dict[int, dict]:
    """The `spell_dbc` rows, light columns only — enough to index and label."""
    global _db_rows
    if _db_rows is None:
        try:
            rows = query("SELECT %s FROM `spell_dbc`"
                         % ", ".join("`%s`" % c for c in DB_INDEX_COLUMNS))
        except Exception:
            rows = []
        _db_rows = {int(r["ID"]): r for r in rows}
    return _db_rows


def db_full_row(spell_id: int) -> dict | None:
    rows = query("SELECT * FROM `spell_dbc` WHERE `ID` = %s", (spell_id,))
    return dict(rows[0]) if rows else None


# --- index ----------------------------------------------------------------
# One tuple per spell, in id order. Everything the list view and the filters
# need is in here, so a search never touches the mmap or the database.

IDX_ID, IDX_NAME, IDX_HAY, IDX_RANK, IDX_ICON, IDX_SCHOOL, IDX_LEVEL, \
    IDX_FAMILY, IDX_EFFECTS, IDX_AURAS, IDX_SOURCE = range(11)


def _light_from_dbc(dbc: dbcfile.DBC, row: int) -> tuple:
    value = dbc.value
    effects = tuple(value(row, "Effect_%d" % i) for i in (1, 2, 3))
    auras = tuple(value(row, "EffectAura_%d" % i) for i in (1, 2, 3))
    return (value(row, "Name", dbcfile.LOCALE_ENUS),
            value(row, "NameSubtext", dbcfile.LOCALE_ENUS),
            value(row, "SpellIconID"), value(row, "SchoolMask"),
            value(row, "SpellLevel"), value(row, "SpellClassSet"),
            effects, auras)


def _light_from_db(row: dict) -> tuple:
    def num(col):
        return int(row.get(col) or 0)

    effects = tuple(num("Effect_%d" % i) for i in (1, 2, 3))
    auras = tuple(num("EffectAura_%d" % i) for i in (1, 2, 3))
    return (row.get("Name_Lang_ruRU") or row.get("Name_Lang_enUS") or "",
            row.get("NameSubtext_Lang_ruRU") or "",
            num("SpellIconID"), num("SchoolMask"), num("SpellLevel"),
            num("SpellClassSet"), effects, auras)


def index() -> list[tuple]:
    global _index, _by_id, _triggered_by
    if _index is not None:
        return _index
    with _lock:
        if _index is not None:
            return _index

        dbc = store().spell
        ru = text()
        overlay = db_rows()
        rows: list[tuple] = []

        ids: Iterable[int]
        if dbc is not None:
            ids = sorted(set(dbc.index) | set(overlay))
        else:
            ids = sorted(overlay)

        for spell_id in ids:
            dbc_row = dbc.row_of(spell_id) if dbc is not None else None
            db_row = overlay.get(spell_id)

            if db_row is not None:
                light = _light_from_db(db_row)
                source = SOURCE_OVERRIDE if dbc_row is not None else SOURCE_CUSTOM
                # A module rewriting a stock spell leaves SpellIconID at the
                # placeholder 1; the client still draws the icon from its own
                # Spell.dbc, so that is the id to show.
                if source == SOURCE_OVERRIDE and light[2] in STUB_ICON_IDS:
                    light = light[:2] + (dbc.value(dbc_row, "SpellIconID"),) \
                        + light[3:]
            else:
                light = _light_from_dbc(dbc, dbc_row)
                source = SOURCE_DBC

            name_en, rank_en, icon, school, level, family, effects, auras = light
            ru_text = ru.get(spell_id)
            name = (ru_text[0] if ru_text and ru_text[0] else "") or name_en
            rank = (ru_text[1] if ru_text and ru_text[1] else "") or rank_en

            haystack = ("%s %s %s" % (name, name_en, rank)).lower()
            rows.append((spell_id, name, haystack, rank, icon, school, level,
                         family, effects, auras, source))

        _index = rows
        _by_id = {row[IDX_ID]: position for position, row in enumerate(rows)}
        _triggered_by = None
        return _index


def by_id() -> dict[int, int]:
    index()
    return _by_id or {}


def triggered_by() -> dict[int, list[int]]:
    """Reverse EffectTriggerSpell map: "who casts this spell?".

    Built from the mmap in one pass and cached; it is the cheapest way to make
    a triggered aura traceable back to the ability that applies it.
    """
    global _triggered_by
    if _triggered_by is not None:
        return _triggered_by
    out: dict[int, list[int]] = {}
    dbc = store().spell
    if dbc is not None:
        columns = [dbc.by_name["EffectTriggerSpell_%d" % i] for i in (1, 2, 3)]
        for row in range(dbc.count):
            caster = dbc.int_at(row, 0)
            for column in columns:
                target = dbc.int_at(row, column.index)
                if target:
                    out.setdefault(target, []).append(caster)
    _triggered_by = out
    return out


def skills_of(spell_id: int) -> list[dict]:
    """Skill lines that grant this spell — the closest thing to "who gets it"."""
    global _skills_of
    if _skills_of is None:
        mapping: dict[int, list[dict]] = {}
        ability, lines = store().skill_ability, store().skill
        if ability is not None:
            for row in range(ability.count):
                spell = ability.value(row, "Spell")
                skill_id = ability.value(row, "SkillLine")
                name = ""
                if lines is not None:
                    line_row = lines.row_of(skill_id)
                    if line_row is not None:
                        name = lines.value(line_row, "DisplayName",
                                           dbcfile.LOCALE_ENUS)
                mapping.setdefault(spell, []).append({
                    "skill_id": skill_id, "skill": name,
                    "class_mask": ability.value(row, "ClassMask"),
                    "race_mask": ability.value(row, "RaceMask"),
                    "min_rank": ability.value(row, "MinSkillLineRank"),
                })
        _skills_of = mapping
    return _skills_of.get(spell_id, [])


# --- reference lookups ----------------------------------------------------

def duration_text(index_id: int) -> str:
    dbc = store().duration
    row = dbc.row_of(index_id) if dbc is not None else None
    if row is None:
        return "#%d" % index_id if index_id else "нет"
    base = dbc.value(row, "Duration")
    if base < 0:
        return "постоянная"
    if base == 0:
        return "нет"
    top = dbc.value(row, "MaxDuration")
    text_ = _ms(base)
    if top and top != base:
        text_ += " (до %s)" % _ms(top)
    return text_


def cast_text(index_id: int) -> str:
    dbc = store().cast
    row = dbc.row_of(index_id) if dbc is not None else None
    if row is None:
        return "#%d" % index_id if index_id else "мгновенно"
    return _ms(dbc.value(row, "Base")) if dbc.value(row, "Base") else "мгновенно"


def range_text(index_id: int) -> str:
    dbc = store().range
    row = dbc.row_of(index_id) if dbc is not None else None
    if row is None:
        return "#%d" % index_id
    low = dbc.value(row, "RangeMin_1")
    high = dbc.value(row, "RangeMax_1")
    if not high:
        return "на себя"
    if low:
        return "%g–%g м" % (low, high)
    return "%g м" % high


def radius_text(index_id: int) -> str:
    dbc = store().radius
    row = dbc.row_of(index_id) if dbc is not None else None
    if row is None:
        return "#%d" % index_id if index_id else ""
    return "%g м" % dbc.value(row, "Radius")


def _ms(value: int) -> str:
    if value >= 60000 and value % 60000 == 0:
        return "%g мин" % (value / 60000.0)
    if value >= 1000:
        return "%g с" % (value / 1000.0)
    return "%d мс" % value


# --- search ---------------------------------------------------------------

def _school_names(mask: int) -> list[str]:
    return [SCHOOL_LABELS[bit] for bit in range(7) if mask & (1 << bit)]


def brief(row: tuple) -> dict:
    icon_id = row[IDX_ICON]
    return {
        "id": row[IDX_ID],
        "name": row[IDX_NAME] or "(без названия)",
        "rank": row[IDX_RANK],
        "icon": icon_texture(row[IDX_ID], icon_id, row[IDX_SOURCE]),
        "icon_id": icon_id,
        "school": row[IDX_SCHOOL],
        "schools": _school_names(row[IDX_SCHOOL]),
        "level": row[IDX_LEVEL],
        "family": row[IDX_FAMILY],
        "family_name": FAMILY_LABELS.get(row[IDX_FAMILY], "семейство %d"
                                         % row[IDX_FAMILY]),
        "effects": [e for e in row[IDX_EFFECTS] if e],
        "auras": [a for a in row[IDX_AURAS] if a],
        "source": row[IDX_SOURCE],
    }


ANY_BLOCK = "*"      # «любой кастомный блок» — всё, что мы завели сами


def id_ranges(block: str | None = None,
              module: str | None = None) -> list[tuple[int, int]] | None:
    """The id ranges a block/module filter allows, or None for "no filter".

    The workshop hands every module a range of spell ids (`spells.BLOCKS`), so
    "покажи спеллы фамильяров" is answerable here without a join: it is the
    union of that module's ranges. An empty list means the filter matched no
    range at all, and the caller should return nothing rather than everything.
    """
    if block == ANY_BLOCK:
        return [(b.lo, b.hi) for b in spells.BLOCKS]
    if block:
        blk = spells.BLOCK_BY_ID.get(block)
        return [(blk.lo, blk.hi)] if blk else []
    if module:
        return [(b.lo, b.hi) for b in spells.BLOCKS if b.module == module]
    return None


def search(q: str = "", school: int | None = None, family: int | None = None,
           effect: int | None = None, aura: int | None = None,
           source: str | None = None, level_min: int | None = None,
           level_max: int | None = None, block: str | None = None,
           module: str | None = None, unnamed: bool = False,
           offset: int = 0, limit: int = 100) -> dict:
    needle = (q or "").strip().lower()
    exact_id = int(needle) if needle.isdigit() else None
    ranges = id_ranges(block, module)

    hits: list[tuple] = []
    for row in index():
        if ranges is not None and not any(lo <= row[IDX_ID] <= hi
                                          for lo, hi in ranges):
            continue
        if not unnamed and not row[IDX_NAME]:
            continue
        if needle:
            if exact_id is not None:
                if row[IDX_ID] != exact_id and needle not in row[IDX_HAY]:
                    continue
            elif needle not in row[IDX_HAY]:
                continue
        if school is not None and not (row[IDX_SCHOOL] & school):
            continue
        if family is not None and row[IDX_FAMILY] != family:
            continue
        if effect is not None and effect not in row[IDX_EFFECTS]:
            continue
        if aura is not None and aura not in row[IDX_AURAS]:
            continue
        if source and row[IDX_SOURCE] != source:
            continue
        if level_min is not None and row[IDX_LEVEL] < level_min:
            continue
        if level_max is not None and row[IDX_LEVEL] > level_max:
            continue
        hits.append(row)

    # An id typed in full is what the operator meant — float it to the top.
    if exact_id is not None:
        hits.sort(key=lambda r: (r[IDX_ID] != exact_id, r[IDX_ID]))

    page = hits[offset:offset + limit]
    return {
        "total": len(hits),
        "offset": offset,
        "limit": limit,
        "items": [brief(row) for row in page],
    }


# --- detail ---------------------------------------------------------------

def _enum_label(name: str, value: int) -> str:
    for entry in spells.enums().get(name, []):
        if entry["id"] == value:
            return entry["label"]
    return str(value)


def _flag_labels(name: str, mask: int) -> list[dict]:
    out = []
    for entry in spells.enums().get(name, []):
        if mask & entry["id"]:
            out.append({"bit": entry["id"], "const": entry["const"],
                        "label": entry["label"]})
    return out


def merged_row(spell_id: int) -> tuple[dict, dict | None, str] | None:
    """The row as the server sees it: DBC first, `spell_dbc` values on top."""
    dbc = store().spell
    dbc_row = dbc.row_of(spell_id) if dbc is not None else None
    base = dbc.row_dict(dbc_row, dbcfile.LOCALE_ENUS) if dbc_row is not None else None
    db_row = db_full_row(spell_id)

    if base is None and db_row is None:
        return None
    if base is None:
        base = {}
        source = SOURCE_CUSTOM
    else:
        source = SOURCE_OVERRIDE if db_row else SOURCE_DBC

    merged = dict(base)
    if db_row:
        merged.update(db_row)
    return merged, db_row, source


def _overridden_columns(base: dict, db_row: dict | None) -> list[dict]:
    """Which columns `spell_dbc` actually changes — the module's fingerprint."""
    if not db_row or not base:
        return []
    out = []
    for column, value in db_row.items():
        if column not in base:
            continue
        old, new = base[column], value
        if isinstance(old, float) or isinstance(new, float):
            same = abs(float(old or 0) - float(new or 0)) < 1e-6
        elif isinstance(old, str) or isinstance(new, str):
            same = str(old or "") == str(new or "")
        else:
            same = int(old or 0) == int(new or 0)
        if not same:
            out.append({"column": column, "dbc": old, "db": new})
    return out


def _amount(base_points: int, die_sides: int, per_level: float) -> str:
    """How the core reads base points: value+1, or a range when dice are rolled."""
    low = base_points + 1
    if die_sides > 1:
        text_ = "%d–%d" % (low, base_points + die_sides)
    else:
        text_ = str(low)
    if per_level:
        text_ += " (+%g за уровень)" % per_level
    return text_


def _effects(row: dict) -> list[dict]:
    out = []
    for index_ in (1, 2, 3):
        effect = int(row.get("Effect_%d" % index_) or 0)
        if not effect:
            continue
        aura = int(row.get("EffectAura_%d" % index_) or 0)
        period = int(row.get("EffectAuraPeriod_%d" % index_) or 0)
        trigger = int(row.get("EffectTriggerSpell_%d" % index_) or 0)
        radius = int(row.get("EffectRadiusIndex_%d" % index_) or 0)
        out.append({
            "index": index_,
            "effect": effect,
            "effect_name": _enum_label("effects", effect),
            "aura": aura,
            "aura_name": _enum_label("auras", aura) if aura else "",
            "amount": _amount(int(row.get("EffectBasePoints_%d" % index_) or 0),
                              int(row.get("EffectDieSides_%d" % index_) or 0),
                              float(row.get("EffectRealPointsPerLevel_%d"
                                            % index_) or 0)),
            "period": _ms(period) if period else "",
            "target_a": _enum_label("targets",
                                    int(row.get("ImplicitTargetA_%d" % index_) or 0)),
            "target_b": _enum_label("targets",
                                    int(row.get("ImplicitTargetB_%d" % index_) or 0)),
            "radius": radius_text(radius) if radius else "",
            "mechanic": _enum_label("mechanics",
                                    int(row.get("EffectMechanic_%d" % index_) or 0)),
            "misc": int(row.get("EffectMiscValue_%d" % index_) or 0),
            "misc_b": int(row.get("EffectMiscValueB_%d" % index_) or 0),
            "chain": int(row.get("EffectChainTargets_%d" % index_) or 0),
            "item_type": int(row.get("EffectItemType_%d" % index_) or 0),
            "trigger": trigger,
            "trigger_name": name_of(trigger) if trigger else "",
        })
    return out


def name_of(spell_id: int) -> str:
    position = by_id().get(spell_id)
    if position is None:
        return ""
    row = index()[position]
    return row[IDX_NAME] or ""


def _kv(label: str, value: Any, raw: Any = None) -> dict:
    return {"label": label, "value": value, "raw": raw}


def _summary(row: dict) -> list[dict]:
    def num(column):
        return int(row.get(column) or 0)

    power = num("PowerType")
    cost = []
    if num("ManaCost"):
        cost.append("%d %s" % (num("ManaCost"), POWER_LABELS.get(power, "?")))
    if num("ManaCostPct"):
        cost.append("%d%% от базового запаса" % num("ManaCostPct"))
    if num("ManaPerSecond"):
        cost.append("%d/сек" % num("ManaPerSecond"))

    out = [
        _kv("Школа", ", ".join(_school_names(num("SchoolMask"))) or "—",
            num("SchoolMask")),
        _kv("Семейство", FAMILY_LABELS.get(num("SpellClassSet"),
                                           str(num("SpellClassSet"))),
            num("SpellClassSet")),
        _kv("Уровень спелла", num("SpellLevel") or "—"),
        _kv("Уровень персонажа", num("BaseLevel") or "—"),
        _kv("Время применения", cast_text(num("CastingTimeIndex")),
            num("CastingTimeIndex")),
        _kv("Дальность", range_text(num("RangeIndex")), num("RangeIndex")),
        _kv("Длительность", duration_text(num("DurationIndex")),
            num("DurationIndex")),
        _kv("Восстановление", _ms(num("RecoveryTime")) if num("RecoveryTime")
            else "нет"),
        _kv("КД категории", _ms(num("CategoryRecoveryTime"))
            if num("CategoryRecoveryTime") else "нет"),
        _kv("Общий КД", _ms(num("StartRecoveryTime")) if num("StartRecoveryTime")
            else "нет"),
        _kv("Стоимость", ", ".join(cost) or "бесплатно"),
        _kv("Тип рассеивания", _enum_label("dispel", num("DispelType")),
            num("DispelType")),
        _kv("Механика", _enum_label("mechanics", num("Mechanic")),
            num("Mechanic")),
        _kv("Класс урона", _enum_label("dmg_class", num("DefenseType")),
            num("DefenseType")),
        _kv("Блокируется", _enum_label("prevention", num("PreventionType")),
            num("PreventionType")),
        _kv("Шанс прока", "%d%%" % num("ProcChance") if num("ProcChance")
            else "—"),
        _kv("Зарядов", num("ProcCharges") or "—"),
        _kv("Стеков", num("CumulativeAura") or "—"),
        _kv("Макс. целей", num("MaxTargets") or "—"),
        _kv("Скорость снаряда", "%g" % float(row.get("Speed") or 0)
            if float(row.get("Speed") or 0) else "—"),
    ]
    return out


# Column ↔ enum pairing for the eight attribute bitfields. `Attributes` is
# attr0 and `AttributesEx` is attr1 — the one place where the column name and
# the enum name do not line up numerically.
ATTR_COLUMNS = [("Attributes", "attr0"), ("AttributesEx", "attr1")] + \
    [("AttributesEx%d" % n, "attr%d" % n) for n in range(2, 8)]


def detail(spell_id: int) -> dict | None:
    merged = merged_row(spell_id)
    if merged is None:
        return None
    row, db_row, source = merged

    dbc = store().spell
    dbc_row = dbc.row_of(spell_id) if dbc is not None else None
    base = dbc.row_dict(dbc_row, dbcfile.LOCALE_ENUS) if dbc_row is not None else {}

    ru = text().get(spell_id, ("", "", "", ""))
    icon_id, derived_icon = resolved_icon(spell_id, row, source)
    meta = spells.meta_for([spell_id]).get(spell_id, {})
    # The workshop's own note about the icon is the most specific record there
    # is, so it wins over every derived source.
    icon = _basename(meta["icon_texture"]) if meta.get("icon_texture") \
        else derived_icon

    name_ru = ru[0] or (db_row or {}).get("Name_Lang_ruRU") or ""
    name_en = base.get("Name") or (db_row or {}).get("Name_Lang_enUS") or ""
    desc_ru = ru[2] or (db_row or {}).get("Description_Lang_ruRU") or ""
    aura_ru = ru[3] or (db_row or {}).get("AuraDescription_Lang_ruRU") or ""

    attributes = []
    for column, enum_name in ATTR_COLUMNS:
        mask = int(row.get(column) or 0) & 0xFFFFFFFF
        if not mask:
            continue
        attributes.append({"column": column, "mask": mask,
                           "hex": "0x%08X" % mask,
                           "flags": _flag_labels(enum_name, mask)})

    block = spells.block_of(spell_id)
    return {
        "id": spell_id,
        "name": name_ru or name_en or "(без названия)",
        "name_en": name_en,
        "rank": ru[1] or base.get("NameSubtext") or "",
        "description": desc_ru or base.get("Description") or "",
        "description_en": base.get("Description") or "",
        "aura_description": aura_ru or base.get("AuraDescription") or "",
        "icon": icon,
        "icon_id": icon_id,
        "source": source,
        "source_label": SOURCE_LABELS[source],
        "block": block.id if block else None,
        "block_name": block.name if block else "",
        "editable": block is not None and db_row is not None,
        "notes": meta.get("notes", ""),
        "module": meta.get("module", "") or (block.module if block else ""),
        "summary": _summary(row),
        "effects": _effects(row),
        "attributes": attributes,
        "overrides": _overridden_columns(base, db_row),
        "skills": skills_of(spell_id),
        "triggered_by": [{"id": caster, "name": name_of(caster)}
                         for caster in triggered_by().get(spell_id, [])[:20]],
        "raw": {key: (round(value, 4) if isinstance(value, float) else value)
                for key, value in row.items()},
    }


# --- reference tables for the workshop ------------------------------------
# The workshop's index fields (duration, cast time, range, radius) are indexes
# into these DBCs. The matching `*_dbc` tables in the game database are empty —
# the server reads the files — so a dropdown built from SQL alone offers only
# the value the spell already has. These are the same files, read once.

REF_DBC = {
    "spellduration_dbc": "duration",
    "spellcasttimes_dbc": "cast",
    "spellrange_dbc": "range",
    "spellradius_dbc": "radius",
}


def icon_list(q: str = "") -> list[dict]:
    """Every icon texture the client knows — for the workshop's icon picker.

    3 226 rows from SpellIcon.dbc plus whatever the MPQ adds, so the operator
    picks a picture instead of typing `spell_frost_frostward` from memory.
    """
    needle = (q or "").strip().lower()
    out = []
    for icon_id, texture in icons().items():
        if needle and needle not in texture:
            continue
        out.append({"id": icon_id, "texture": texture})
    out.sort(key=lambda item: item["texture"])
    return out


def ref_entries() -> dict[str, list[dict]]:
    """{table: [{id, label}]} for the index dropdowns, straight from the DBCs."""
    out: dict[str, list[dict]] = {}
    for table, attribute in REF_DBC.items():
        dbc = getattr(store(), attribute)
        if dbc is None:
            out[table] = []
            continue
        label = spells.REF_TABLES[table][2]
        items = []
        for row in range(dbc.count):
            data = dbc.row_dict(row, dbcfile.LOCALE_ENUS)
            try:
                text = label(data)
            except Exception:
                text = ""
            items.append({"id": int(data["ID"]), "label": text})
        out[table] = items
    return out


# --- catalogue meta -------------------------------------------------------

def _used_values(position: int) -> set[int]:
    used = set()
    for row in index():
        for value in row[position]:
            if value:
                used.add(value)
    return used


def block_facets() -> list[dict]:
    """The workshop's id blocks, counted over the catalogue itself.

    The count is deliberately not `SELECT COUNT(*) FROM spell_dbc`: what the
    filter will actually show is rows of *this* index, which also holds stock
    spells a module rewrote inside its range.
    """
    ids = sorted(row[IDX_ID] for row in index())
    out = []
    for blk in spells.BLOCKS:
        lo = bisect.bisect_left(ids, blk.lo)
        hi = bisect.bisect_right(ids, blk.hi)
        out.append({**blk.model_dump(), "used": hi - lo,
                    "size": blk.hi - blk.lo + 1})
    return out


def module_facets(blocks: list[dict]) -> list[dict]:
    """Modules that own at least one id range, with their total.

    Only those: here "модуль" is a filter over ids, so a module without a range
    of its own has nothing to select and would be a dead entry in the dropdown.
    """
    names = {m["id"]: m["name"] for m in spells.module_choices()}
    out: list[dict] = []
    for blk in blocks:
        if not blk["module"]:
            continue
        hit = next((m for m in out if m["id"] == blk["module"]), None)
        if hit is None:
            out.append({"id": blk["module"],
                        "label": names.get(blk["module"], blk["module"]),
                        "count": blk["used"], "blocks": [blk["id"]]})
        else:
            hit["count"] += blk["used"]
            hit["blocks"].append(blk["id"])
    return out


def meta() -> dict:
    """Filter contents. Effects and auras are narrowed to the ones actually
    used by some spell, so the dropdowns list 60 entries instead of 318."""
    if not available():
        return {"available": False, "reason":
                "Не примонтирован %s — каталог недоступен." % config.DBC_DIR}

    rows = index()
    counts: dict[str, int] = {}
    for row in rows:
        counts[row[IDX_SOURCE]] = counts.get(row[IDX_SOURCE], 0) + 1

    used_effects = _used_values(IDX_EFFECTS)
    used_auras = _used_values(IDX_AURAS)
    families = sorted({row[IDX_FAMILY] for row in rows})
    blocks = block_facets()

    return {
        "blocks": blocks,
        "modules": module_facets(blocks),
        "any_block": ANY_BLOCK,
        "block_total": sum(b["used"] for b in blocks),
        "available": True,
        "total": len(rows),
        "named": sum(1 for row in rows if row[IDX_NAME]),
        "counts": counts,
        "sources": [{"id": key, "label": label, "count": counts.get(key, 0)}
                    for key, label in SOURCE_LABELS.items()],
        "schools": [{"id": 1 << bit, "label": label}
                    for bit, label in SCHOOL_LABELS.items()],
        "families": [{"id": family,
                      "label": FAMILY_LABELS.get(family, "семейство %d" % family)}
                     for family in families],
        "effects": [entry for entry in spells.enums()["effects"]
                    if entry["id"] in used_effects],
        "auras": [entry for entry in spells.enums()["auras"]
                  if entry["id"] in used_auras],
        "icon_base_url": config.ICON_BASE_URL,
        # A page showing a hundred icons at a time cannot afford to probe for a
        # local PNG and fall back per image, so the answer is given once here.
        "local_icons": os.path.isdir(os.path.join(
            os.path.dirname(__file__), "static", "icons")),
        "dbc_dir": config.DBC_DIR,
    }
