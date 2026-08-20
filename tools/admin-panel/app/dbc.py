"""Read-only reference data: zone names and env-effect spell metadata.

Both files are small and change rarely, so they are parsed once at first use and
cached in memory. Nothing here writes.
"""

import csv
import functools

from . import config

# --- AreaTable.csv --------------------------------------------------------
# The locale columns in the exported DBC CSVs are SHIFTED relative to their
# headers: the ruRU string sits at (enUS index + 8), while the column actually
# labelled AreaName_ruRU is empty. Verified against .claude/dbc/AreaTable.csv —
# row 1 has "Дун Морог" at index 19, and index 22 (AreaName_ruRU) is blank.
# Same quirk as Spell_custom.csv. Do not "fix" this by using the header name.
_AREA_ID = 0
_AREA_PARENT = 2
_AREA_NAME_ENUS = 11
_AREA_NAME_RURU = _AREA_NAME_ENUS + 8


@functools.lru_cache(maxsize=1)
def zone_names() -> dict[int, str]:
    """zone_id -> display name. Only top-level zones (ParentAreaID == 0).

    Sub-areas are excluded because `mod_environmental_effects.zone_id` is matched
    against `Player::GetZoneId()`, which never returns a sub-area id.
    """
    out: dict[int, str] = {}
    try:
        with open(config.AREATABLE_CSV, encoding="utf-8", newline="") as f:
            reader = csv.reader(f)
            next(reader, None)  # header
            for row in reader:
                if len(row) <= _AREA_NAME_RURU:
                    continue
                if (row[_AREA_PARENT] or "0") != "0":
                    continue
                name = row[_AREA_NAME_RURU].strip() or row[_AREA_NAME_ENUS].strip()
                if not name:
                    continue
                try:
                    out[int(row[_AREA_ID])] = name
                except ValueError:
                    continue
    except FileNotFoundError:
        pass
    return out


def zone_name(zone_id: int) -> str:
    return zone_names().get(zone_id, f"Зона {zone_id}")


# --- client_manifest.csv --------------------------------------------------
# spell_id,spell_icon_id,icon_texture,name_ru,description_ru — authored by
# scripts/gen_client.py from docs/ZONES.md + docs/DEBUFFS.md. It is the only
# server-side record of which icon a spell actually shows in game: the real
# SpellIconID lives in the client's Spell.dbc (MPQ), while the server-side
# spell_dbc keeps a harmless placeholder 1 that nothing reads.

BUFF_RANGE = (107000, 107499)
DEBUFF_RANGE = (107500, 107799)
NIGHT_SPELL = 108500


@functools.lru_cache(maxsize=1)
def spell_meta() -> dict[int, dict]:
    out: dict[int, dict] = {}
    try:
        with open(config.MANIFEST_CSV, encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                try:
                    sid = int(row["spell_id"])
                except (KeyError, ValueError):
                    continue
                out[sid] = {
                    "spell_id": sid,
                    "icon_texture": (row.get("icon_texture") or "").strip(),
                    "name_ru": (row.get("name_ru") or "").strip(),
                    "description_ru": (row.get("description_ru") or "").strip(),
                }
    except FileNotFoundError:
        pass
    return out


def kind_of(spell_id: int) -> int | None:
    """0 = buff block, 1 = debuff block, None = outside the module's ranges."""
    if BUFF_RANGE[0] <= spell_id <= BUFF_RANGE[1]:
        return 0
    if DEBUFF_RANGE[0] <= spell_id <= DEBUFF_RANGE[1] or spell_id == NIGHT_SPELL:
        return 1
    return None


def describe(spell_id: int) -> dict:
    meta = spell_meta().get(spell_id)
    if meta:
        return dict(meta, kind=kind_of(spell_id))
    return {
        "spell_id": spell_id,
        "icon_texture": "",
        "name_ru": "",
        "description_ru": "",
        "kind": kind_of(spell_id),
    }


def reload_cache() -> None:
    zone_names.cache_clear()
    spell_meta.cache_clear()
