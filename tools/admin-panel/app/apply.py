"""Что из отредактированного ещё не доехало до живого мира.

Панель пишет в базу PTR, а мир держит свои справочники в памяти и перечитывает
их либо на старте, либо по консольной команде. Между «сохранил» и «видно в
игре» стоит этот шаг, и раньше он был кнопкой на каждой странице - семь кнопок
с пятью разными надписями, причём вели они себя по-разному: в эффектах
окружения и талантах сохранение перечитывало мир само, в добыче и профессиях -
нет, а вся погода вообще доезжает командой сразу, и её кнопка ничего не делала.
Кто не нажал там, где было нужно, у того правка тихо оставалась в базе.

Отметку ставит не каждый обработчик, а та же прослойка, что ведёт журнал
(`main.audit_changes`): реестр, который нужно помнить в сорока местах - это
реестр с дырами. Область берётся из `audit.describe()`, поэтому новый
обработчик попадает сюда в день, когда его написали, и попадает в сторону
«ждёт»: лишняя перечитка стоит секунды, потерянная правка - вечера поисков.
Исключения перечислены в `LIVE` поимённо.

Состояние НЕ хранится флагом «применено»: флаг застревает. Мир, перезапущенный
после правки, прочитал её сам - поэтому отметки старше старта мира просто
выбрасываются, а ждущим считается то, что помечено позже. Ровно тот же приём,
что и в `spells.pending_restart()`.
"""

import datetime as _dt
import os
import re
import time as _time
from dataclasses import dataclass

from . import audit, soap
from .paneldb import cursor, ensure


@dataclass(frozen=True)
class Target:
    """Модуль мира и команда, которой он перечитывает свои таблицы."""

    key: str
    label: str
    note: str
    command: str          # «{detail}» подставляется, если правка адресная
    role: str = "editor"  # кому позволено применять


# Модули, чьи правки ждут перечитки. Ключ - область журнала (`audit.RULES`).
TARGETS: dict[str, Target] = {
    "envfx": Target(
        "envfx", "Эффекты окружения",
        "«reload config» - модуль перечитывает правила зон.",
        "reload config"),
    "italents": Target(
        "italents", "Таланты предметов",
        "«.itemtalent reload» - модуль перечитывает дерево и наборы.",
        ".itemtalent reload"),
    "aprof": Target(
        "aprof", "Продвинутые профессии",
        "«aprof reload» - модуль перечитывает материалы и основы.",
        "aprof reload", role="owner"),
    "loot": Target(
        "loot", "Добыча",
        "«.reload <таблица>» - мир перечитывает изменённую таблицу добычи.",
        ".reload {detail}", role="owner"),
}

# Команды, которые панель сама никогда не просит: мир их не ждёт, но человеку
# они иногда нужны. Живут на странице выкатки отдельным списком.
MANUAL: dict[str, Target] = {
    "weather": Target(
        "weather", "Перечитать конфигурацию погоды с диска",
        "«aw reload». Правки из панели доезжают до мира сразу (вся погода "
        "отдаётся консольной командой), это - на случай правки файла "
        "конфигурации руками.",
        "aw reload"),
}

# Пути, после которых перечитывать нечего:
#   - вся погода отдаётся командой прямо в мир (`aw set`, `aw cfg`, `aw
#     enable`), а связи зон перечитывают себя сами в `weather.set_links()`;
#   - подписи добычи живут в схеме панели, мир про них не знает;
#   - выгрузка пишет файл, а перечитка и есть применение.
LIVE = (
    re.compile(r"^/api/weather/"),
    re.compile(r"^/api/loot/label/"),
    re.compile(r"/reload(/|$)"),
    re.compile(r"/export(/|$)"),
    re.compile(r"^/api/apply$"),
    re.compile(r"^/api/refresh-cache$"),
)

SCHEMA = [
    """
    CREATE TABLE IF NOT EXISTS `pending_reload` (
      `target`    VARCHAR(24) NOT NULL,
      `detail`    VARCHAR(64) NOT NULL DEFAULT '',
      `marked_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `by_login`  VARCHAR(32) NOT NULL DEFAULT '',
      PRIMARY KEY (`target`, `detail`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """,
]


def ensure_schema() -> None:
    ensure("apply", SCHEMA)


# --- отметка --------------------------------------------------------------

def _detail(area: str, path: str) -> str:
    """Для добычи - имя таблицы, которую правили; остальным адрес не нужен.

    Таблицы добычи носят имя вида `creature_loot_template`, а в пути стоит
    короткий ключ: /api/loot/row/creature/1234.
    """
    if area != "loot":
        return ""
    parts = [p for p in path.split("/") if p]
    return parts[3] + "_loot_template" if len(parts) > 3 else ""


def mark(*, method: str, path: str, status: int, actor) -> None:
    """Пометить модуль «мир не в курсе». Никогда не бросает исключений."""
    if method == "GET" or status >= 400:
        return
    try:
        if any(p.search(path) for p in LIVE):
            return
        described = audit.describe(method, path)
        if described is None:
            return
        area = described[0]
        if area not in TARGETS:
            return
        detail = _detail(area, path)
        if area == "loot" and not detail:
            return
        ensure_schema()
        with cursor(commit=True) as cur:
            cur.execute(
                "INSERT INTO `pending_reload` (target, detail, by_login) "
                "VALUES (%s, %s, %s) ON DUPLICATE KEY UPDATE "
                "marked_at = CURRENT_TIMESTAMP, by_login = VALUES(by_login)",
                (area, detail, str(getattr(actor, "login", "—"))[:32]))
    except Exception:
        pass


def clear(target: str, detail: str = "") -> None:
    """Снять отметку: модуль только что перечитал сам (сохранение с reload)."""
    try:
        ensure_schema()
        with cursor(commit=True) as cur:
            if detail:
                cur.execute("DELETE FROM `pending_reload` WHERE target = %s "
                            "AND detail = %s", (target, detail))
            else:
                cur.execute("DELETE FROM `pending_reload` WHERE target = %s",
                            (target,))
    except Exception:
        pass


# --- состояние ------------------------------------------------------------

def _iso(value: _dt.datetime | None) -> str | None:
    return value.isoformat(sep=" ", timespec="seconds") if value else None


def _rows() -> list[dict]:
    ensure_schema()
    with cursor() as cur:
        cur.execute("SELECT target, detail, marked_at, by_login "
                    "FROM `pending_reload` ORDER BY marked_at")
        return list(cur.fetchall())


def _describe(target: Target) -> dict:
    # `note` остаётся в `Target` - но как объяснение тому, кто правит код.
    # Страница показывает саму команду: это факт, а не пересказ.
    return {"key": target.key, "label": target.label,
            "role": target.role, "command": target.command}


# Старт мира меняется только при его перезапуске, а `.server info` - это
# полный круг по SOAP. Значок в шапке спрашивает состояние часто, поэтому
# ответ живёт минуту, и пустой реестр вообще не спрашивает мир ни о чём.
_START_TTL = 60.0
_start_cache: tuple[float, _dt.datetime | None] | None = None


def _started_at() -> _dt.datetime | None:
    global _start_cache
    now = _time.monotonic()
    if _start_cache and now - _start_cache[0] < _START_TTL:
        return _start_cache[1]
    started = soap.started_at()
    _start_cache = (now, started)
    return started


def state() -> dict:
    """Что ждёт мира прямо сейчас.

    Отметки старше старта мира выбрасываются: перезапуск прочитал таблицы сам.
    Если аптайм неизвестен (SOAP молчит), не выбрасываем ничего - лучше лишняя
    метка, чем потерянная правка.
    """
    rows = [r for r in _rows() if r["target"] in TARGETS]
    started = _started_at() if rows else None

    stale = [r for r in rows if started and r["marked_at"] < started]
    if stale:
        with cursor(commit=True) as cur:
            cur.executemany("DELETE FROM `pending_reload` WHERE target = %s "
                            "AND detail = %s",
                            [(r["target"], r["detail"]) for r in stale])
        rows = [r for r in rows if r not in stale]

    waiting: dict[str, dict] = {}
    for row in rows:
        target = TARGETS[row["target"]]
        entry = waiting.setdefault(target.key, dict(
            _describe(target), details=[], by=row["by_login"],
            since=_iso(row["marked_at"])))
        if row["detail"] and row["detail"] not in entry["details"]:
            entry["details"].append(row["detail"])

    return {
        "soap": None if not rows else started is not None,
        "started_at": _iso(started),
        "waiting": list(waiting.values()),
        "targets": [_describe(t) for t in TARGETS.values()],
        "manual": [_describe(t) for t in MANUAL.values()],
    }


# --- применение -----------------------------------------------------------

def _run_command(target: Target, detail: str, done: list, failed: list) -> None:
    command = target.command.format(detail=detail)
    try:
        output = soap.execute(command, timeout=30.0)
    except soap.SoapError as exc:
        failed.append({"label": target.label, "command": command,
                       "error": str(exc)})
        return
    clear(target.key, detail)
    done.append({"label": target.label, "command": command,
                 "output": output.strip()[:400]})


def run(only: str = "") -> dict:
    """Прогнать команды для всех ждущих модулей (или для одного).

    Не останавливается на первой ошибке: если профессии не отозвались, добыча
    всё равно должна доехать. Отметку снимаем только с того, что прошло.
    """
    done: list[dict] = []
    failed: list[dict] = []

    if only in MANUAL:
        _run_command(MANUAL[only], "", done, failed)
        return {"ok": not failed, "applied": done, "failed": failed,
                "state": state()}

    for entry in state()["waiting"]:
        if only and entry["key"] != only:
            continue
        target = TARGETS[entry["key"]]
        for detail in entry["details"] or [""]:
            _run_command(target, detail, done, failed)

    return {"ok": not failed, "applied": done, "failed": failed,
            "state": state()}


# --- выгрузки -------------------------------------------------------------
# Файлы, которые панель пишет на диск. Живого мира они не касаются вовсе, и
# именно поэтому их кнопки так путались с перечиткой: «Выгрузить SQL» на
# странице эффектов стояло рядом с «Перечитать PTR» и выглядело её роднёй.
#
# Миграция в репозитории - то, что переживёт снос базы PTR снапшотом и уедет
# на живой сервер. CSV - сырьё для сборщика клиентского патча: без него новый
# предмет у игрока будет безымянным и без иконки.


def _edits_since(area: str, moment: _dt.datetime | None) -> dict:
    """Сколько правок этой области легло в журнал после записи файла.

    Файла нет вовсе - считаем всё: не выгружали ни разу, значит ждёт всё.
    """
    try:
        audit.ensure_schema()
        with cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) AS n, MAX(at) AS last FROM `admin_audit` "
                "WHERE area = %s AND ok = 1 AND at > %s AND path NOT LIKE "
                "'%%/export%%'",
                (area, moment or _dt.datetime(1970, 1, 1)))
            row = cur.fetchone() or {}
        return {"count": int(row.get("n") or 0), "last": _iso(row.get("last"))}
    except Exception:
        return {"count": 0, "last": None}


def artefacts(kind: str = "") -> list[dict]:
    """Что и куда выгружается, когда это делали и что с тех пор изменилось."""
    # Лениво: `items` и `spells` тянут за собой базу и справочники, а этот
    # модуль зовётся из прослойки на каждом запросе.
    from . import config, items, spells

    sql_dir = os.path.dirname(config.SEED_SQL)
    rows = [
        ("envfx-sql", "Эффекты окружения", "sql", "/api/export",
         config.SEED_SQL, "envfx", None),
        ("items-sql", "Каталог предметов", "sql", "/api/items/export/sql",
         os.path.join(sql_dir, items.SQL_NAME), "items", None),
        ("spells-sql", "Мастерская спеллов", "sql", "/api/spells/export/sql",
         os.path.join(sql_dir, "admin_panel_spells.sql"), "spells", None),
        ("items-client", "Каталог предметов", "client",
         "/api/items/export/client", config.ITEM_CUSTOM_CSV, "items",
         items.client_pending),
        ("spells-client", "Мастерская спеллов", "client",
         "/api/spells/export/client", config.SPELL_CUSTOM_CSV, "spells",
         spells.client_pending),
    ]

    out = []
    for key, label, row_kind, endpoint, path, area, pending in rows:
        if kind and row_kind != kind:
            continue
        try:
            stat = os.stat(path)
            moment = _dt.datetime.fromtimestamp(stat.st_mtime)
            size = stat.st_size
        except OSError:
            moment, size = None, 0

        item = {"key": key, "label": label, "kind": row_kind,
                "endpoint": endpoint, "path": path,
                "written_at": _iso(moment), "size": size}
        if pending is None:
            item["edits"] = _edits_since(area, moment)
        else:
            try:
                item["pending"] = pending()
            except Exception as exc:
                item["pending"] = {"known": False, "reason": str(exc)}
        out.append(item)
    return out
