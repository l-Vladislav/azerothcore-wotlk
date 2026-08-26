"""Мировые предметы — присмотр за тем, что уже разложено по карте.

Расставляют **не отсюда**. Координаты ставятся в игре, аддоном: по карте в
браузере точку не выбрать — нет ни высоты, ни геометрии помещений, а объект
надо ещё и посадить на землю и развернуть. Панель отвечает за всё остальное:
видеть список, менять привязанный предмет и количество, включать и выключать
размещение, знать, кто его поставил и сколько человек уже забрало.

Строка здесь — **размещение**, а не предмет. Один шаблон лежит в десятке мест,
и «кто что забрал» считается по размещению; иначе, подобрав меч в одной точке,
игрок потерял бы его во всех.

Счётчик подобравших живёт в базе персонажей (`mod_world_items_loot`), а сами
размещения — в базе мира. Это две разные базы, поэтому счётчик читается
отдельным запросом и приклеивается к строкам уже здесь.
"""

import logging
from typing import Any

from . import items
from .db import cursor as world_cursor
from .db import query, query_one

_LOG = logging.getLogger(__name__)

TABLE = "mod_world_items"
LOOT_TABLE = "mod_world_items_loot"

# Колонки, которые панель разрешает менять. Координаты сюда не входят
# намеренно: их источник — игра, и правка «на глаз» в вебе означала бы предмет,
# висящий в воздухе или утонувший в текстурах.
EDITABLE = ("item_entry", "item_count", "one_per_char", "respawn_secs",
            "enabled", "comment")


def available() -> bool:
    """Есть ли таблица. Модуль могли не собрать, миграцию — не применить."""
    row = query_one(
        "SELECT 1 AS ok FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s LIMIT 1", (TABLE,))
    return bool(row)


def _loot_counts(ids: list[int]) -> dict[int, int]:
    """Сколько персонажей забрало каждое размещение.

    Отдельным подключением к базе персонажей: `db.cursor` ходит в мир, а эти
    строки живут вместе с персонажами и умирают вместе с ними.
    """
    if not ids:
        return {}

    # Имя базы персонажей выводим из мировой: панель уже привязана к PTR, и
    # заводить ради одного счётчика вторую пару настроек подключения незачем.
    marks = ", ".join(["%s"] * len(ids))
    # _loot_ref() уже возвращает имя с обратными кавычками — оборачивать его
    # ещё раз означает синтаксическую ошибку.
    rows = query(
        "SELECT `placement_id` AS id, COUNT(*) AS n FROM %s "
        "WHERE `placement_id` IN (%s) GROUP BY `placement_id`"
        % (_loot_ref(), marks), tuple(ids))
    return {int(r["id"]): int(r["n"]) for r in rows}


def _loot_ref() -> str:
    """`characters.mod_world_items_loot` — с именем базы, выведенным из мировой.

    acore_world_ptr → acore_characters_ptr, acore_world → acore_characters.
    Правило простое и держится на одном соглашении об именах, поэтому если оно
    вдруг перестанет выполняться, счётчик просто не покажется, а не соврёт.
    """
    row = query_one("SELECT DATABASE() AS db")
    world = (row or {}).get("db") or ""
    chars = world.replace("world", "characters", 1)
    return "`%s`.`%s`" % (chars, LOOT_TABLE)


def list_all(only_enabled: bool = False) -> list[dict]:
    where = " WHERE `enabled` = 1" if only_enabled else ""
    rows = query(
        "SELECT `id`, `item_entry`, `item_count`, `go_entry`, `go_guid`, "
        "`map`, `zone`, `x`, `y`, `z`, `o`, `scale`, `one_per_char`, "
        "`respawn_secs`, `enabled`, `comment`, `created_by`, `created_at` "
        "FROM `%s`%s ORDER BY `id`" % (TABLE, where))
    if not rows:
        return []

    # Имя и иконка предмета — из того же места, что и в каталоге предметов.
    entries = sorted({int(r["item_entry"]) for r in rows})
    marks = ", ".join(["%s"] * len(entries))
    tmpl = {
        int(r["entry"]): r for r in
        query("SELECT `entry`, `name`, `Quality`, `displayid` FROM "
              "`item_template` WHERE `entry` IN (%s)" % marks, tuple(entries))
    }
    locales = {
        int(r["ID"]): r["Name"] for r in
        query("SELECT `ID`, `Name` FROM `item_template_locale` "
              "WHERE `locale` = 'ruRU' AND `ID` IN (%s)" % marks, tuple(entries))
        if r.get("Name")
    }

    # База персонажей может быть недоступна, и список тогда важнее счётчика.
    # Но «не сосчитали» отдаётся как None, а не как 0: уверенный ноль на месте
    # неизвестного значения — это ложь, которую никто не заметит.
    counts: dict[int, int] | None
    try:
        counts = _loot_counts([int(r["id"]) for r in rows])
    except Exception as exc:
        _LOG.warning("mod_world_items: счётчик подобравших недоступен: %s", exc)
        counts = None

    out = []
    for row in rows:
        entry = int(row["item_entry"])
        info = tmpl.get(entry) or {}
        out.append({
            "id": int(row["id"]),
            "item_entry": entry,
            "item_name": locales.get(entry) or info.get("name") or "?",
            "item_quality": int(info.get("Quality") or 0),
            "item_icon": items.icon_texture(info.get("displayid") or 0),
            "item_missing": entry not in tmpl,
            "item_block": (items.block_of(entry).id
                           if items.block_of(entry) else None),
            "item_count": int(row["item_count"]),
            "go_entry": int(row["go_entry"]),
            "go_guid": row["go_guid"],
            "map": int(row["map"]),
            "zone": int(row["zone"]),
            "pos": [float(row["x"]), float(row["y"]), float(row["z"])],
            "scale": float(row["scale"]),
            "one_per_char": bool(row["one_per_char"]),
            "respawn_secs": int(row["respawn_secs"]),
            "enabled": bool(row["enabled"]),
            "comment": row["comment"] or "",
            "created_by": row["created_by"] or "",
            "created_at": str(row["created_at"]),
            "looted_by": (counts.get(int(row["id"]), 0)
                          if counts is not None else None),
        })
    return out


def update(placement_id: int, fields: dict[str, Any]) -> dict | None:
    clean = {c: fields[c] for c in EDITABLE if c in fields}
    if not clean:
        return get(placement_id)

    if "item_entry" in clean:
        entry = int(clean["item_entry"])
        if not query_one("SELECT 1 AS ok FROM `item_template` WHERE `entry` = %s",
                         (entry,)):
            raise ValueError("Предмета %d не существует." % entry)

    sets = ", ".join("`%s` = %%s" % c for c in clean)
    with world_cursor(commit=True) as cur:
        cur.execute("UPDATE `%s` SET %s WHERE `id` = %%s" % (TABLE, sets),
                    tuple(clean.values()) + (placement_id,))
    return get(placement_id)


def get(placement_id: int) -> dict | None:
    for row in list_all():
        if row["id"] == placement_id:
            return row
    return None


def delete(placement_id: int) -> bool:
    """Убирает размещение из таблицы модуля.

    Спавн в таблице `gameobject` при этом остаётся: им распоряжается ядро, и
    сносить его отсюда значило бы оставить в мире объект, про который уже никто
    не знает. Убирать его надо из игры — там же, где ставили.
    """
    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `id` = %%s" % TABLE, (placement_id,))
        return cur.rowcount > 0


def reset_loot(placement_id: int) -> int:
    """Забыть, кто это подобрал — предмет снова станет виден всем.

    Нужно после правки: если размещению поменяли предмет, старые подобравшие
    иначе никогда не увидят новый.
    """
    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM %s WHERE `placement_id` = %%s" % _loot_ref(),
                    (placement_id,))
        return cur.rowcount
