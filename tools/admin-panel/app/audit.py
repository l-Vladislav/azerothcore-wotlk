"""Who changed what, in which module, and when.

Written by one middleware in `main.py` rather than by a call inside each
endpoint. That is the whole design decision: there are ~40 mutating endpoints
across five editors and more arrive with every module, and a log that has to be
remembered at each of them is a log with holes in it. Anything that is not a
GET and lives under `/api/` is recorded, so a new endpoint is audited the day
it is written, without its author doing anything.

What a row holds is the *submitted state*, not a diff against what was there
before: the editors PUT whole objects, so the payload answers "what did he set
it to" but not "what was it before". Reconstructing the previous value would
mean a read-before-write on every endpoint — the exact per-endpoint coupling
this design avoids. The previous value is one row up in the same log.

Secrets never land here. Passwords and invite tokens are replaced by a marker
before the payload is stored, because this table is readable by every owner and
exportable from the page.
"""

import datetime as _dt
import json
import re
from typing import Any

from .paneldb import cursor, ensure

# How much of a payload to keep. The item-talents library PUT is the big one
# (the whole perk pool in one body); past this it is truncated with a marker
# rather than dropped, so the row still says what happened.
MAX_PAYLOAD = 8000

SECRET_KEYS = {"password", "current", "token", "pass", "new_password"}
REDACTED = "«скрыто»"

AREA_LABEL = {
    "envfx": "Эффекты окружения",
    "weather": "Погода",
    "italents": "Таланты предметов",
    "spells": "Мастерская спеллов",
    "board": "Доска",
    "users": "Люди и доступ",
    "system": "Система",
}

SCHEMA = [
    """
    CREATE TABLE IF NOT EXISTS `admin_audit` (
      `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `at`          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `actor_id`    INT UNSIGNED NOT NULL DEFAULT 0,
      `actor_login` VARCHAR(32) NOT NULL DEFAULT '',
      `actor_name`  VARCHAR(64) NOT NULL DEFAULT '',
      `actor_role`  VARCHAR(16) NOT NULL DEFAULT '',
      `area`        VARCHAR(24) NOT NULL DEFAULT 'system',
      `target`      VARCHAR(120) NOT NULL DEFAULT '',
      `summary`     VARCHAR(255) NOT NULL DEFAULT '',
      `method`      VARCHAR(8) NOT NULL DEFAULT '',
      `path`        VARCHAR(200) NOT NULL DEFAULT '',
      `payload`     MEDIUMTEXT NULL,
      `status`      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      `ok`          TINYINT(1) NOT NULL DEFAULT 1,
      PRIMARY KEY (`id`),
      KEY `idx_at` (`at`),
      KEY `idx_area` (`area`, `at`),
      KEY `idx_actor` (`actor_login`, `at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """,
]


def ensure_schema() -> None:
    ensure("audit", SCHEMA)


# --- what the request did -------------------------------------------------

# (method, path pattern) -> (area, target template, summary template).
# Templates interpolate the pattern's named groups plus `body`, so a rule can
# say "зона 1519" without the endpoint knowing anything about the log.
RULES: list[tuple[str, re.Pattern, str, str, str]] = [
    # env effects
    ("PUT", re.compile(r"^/api/zones/(?P<id>\d+)$"), "envfx",
     "зона {id}", "сохранены правила зоны"),
    ("DELETE", re.compile(r"^/api/zones/(?P<id>\d+)$"), "envfx",
     "зона {id}", "удалены все правила зоны"),
    ("POST", re.compile(r"^/api/reload$"), "envfx",
     "", "перезагружены правила на PTR"),
    ("POST", re.compile(r"^/api/export$"), "envfx",
     "", "правила выгружены в SQL-миграцию"),
    ("POST", re.compile(r"^/api/refresh-cache$"), "system",
     "", "сброшен кэш справочников"),
    # weather
    ("PUT", re.compile(r"^/api/weather/zones/(?P<id>\d+)$"), "weather",
     "зона {id}", "выставлена погода вручную"),
    ("POST", re.compile(r"^/api/weather/zones/(?P<id>\d+)/pin$"), "weather",
     "зона {id}", "погода закреплена"),
    ("POST", re.compile(r"^/api/weather/zones/(?P<id>\d+)/release$"), "weather",
     "зона {id}", "погода отпущена режиссёру"),
    ("PUT", re.compile(r"^/api/weather/zones/(?P<id>\d+)/links$"), "weather",
     "зона {id}", "изменены связи зоны"),
    ("PUT", re.compile(r"^/api/weather/director$"), "weather",
     "режиссёр", "изменён режиссёр погоды"),
    ("PUT", re.compile(r"^/api/weather/settings/(?P<name>[\w.]+)$"), "weather",
     "{name}", "изменена настройка модуля"),
    ("POST", re.compile(r"^/api/weather/cyclones/reset$"), "weather",
     "циклоны", "перезапущены фронты"),
    ("POST", re.compile(r"^/api/weather/links/reload$"), "weather",
     "связи", "перечитаны связи зон"),
    ("POST", re.compile(r"^/api/weather/reload$"), "weather",
     "", "перечитан конфиг модуля"),
    # item talents
    ("PUT", re.compile(r"^/api/italents/categories$"), "italents",
     "категории", "изменён список категорий"),
    ("PUT", re.compile(r"^/api/italents/categories/(?P<code>[\w-]+)/rows/"
                       r"(?P<row>\d+)$"), "italents",
     "категория {code}, ряд {row}", "изменён ряд категории"),
    ("PUT", re.compile(r"^/api/italents/items/(?P<entry>\d+)/rows/"
                       r"(?P<row>\d+)$"), "italents",
     "предмет {entry}, ряд {row}", "изменён персональный ряд"),
    ("PUT", re.compile(r"^/api/italents/procs$"), "italents",
     "проки", "изменены проки ряда 5"),
    ("PUT", re.compile(r"^/api/italents/curves$"), "italents",
     "пороги", "изменены пороги убийств"),
    ("PUT", re.compile(r"^/api/italents/library$"), "italents",
     "библиотека", "изменена библиотека перков"),
    ("POST", re.compile(r"^/api/italents/reload$"), "italents",
     "", "перечитаны таланты на PTR"),
    # spells
    ("POST", re.compile(r"^/api/spells$"), "spells",
     "", "создан спелл"),
    ("PUT", re.compile(r"^/api/spells/(?P<id>\d+)$"), "spells",
     "спелл {id}", "изменён спелл"),
    ("DELETE", re.compile(r"^/api/spells/(?P<id>\d+)$"), "spells",
     "спелл {id}", "удалён спелл"),
    ("POST", re.compile(r"^/api/spells/export/sql$"), "spells",
     "", "спеллы выгружены в SQL"),
    ("POST", re.compile(r"^/api/spells/export/client$"), "spells",
     "", "спеллы выгружены в клиентский CSV"),
    # board
    ("POST", re.compile(r"^/api/board/cards$"), "board",
     "", "заведена карточка"),
    ("PATCH", re.compile(r"^/api/board/cards/(?P<id>\d+)$"), "board",
     "карточка #{id}", "изменена карточка"),
    ("POST", re.compile(r"^/api/board/cards/(?P<id>\d+)/move$"), "board",
     "карточка #{id}", "карточка перемещена"),
    ("POST", re.compile(r"^/api/board/cards/(?P<id>\d+)/comments$"), "board",
     "карточка #{id}", "добавлен комментарий"),
    ("POST", re.compile(r"^/api/board/cards/(?P<id>\d+)/restore$"), "board",
     "карточка #{id}", "карточка возвращена из архива"),
    ("DELETE", re.compile(r"^/api/board/cards/(?P<id>\d+)$"), "board",
     "карточка #{id}", "карточка удалена"),
    # people
    ("POST", re.compile(r"^/api/invites$"), "users",
     "", "выдано приглашение"),
    ("POST", re.compile(r"^/api/invites/(?P<id>\d+)/revoke$"), "users",
     "приглашение #{id}", "приглашение отозвано"),
    ("POST", re.compile(r"^/api/auth/join$"), "users",
     "", "создан профиль по приглашению"),
    ("PATCH", re.compile(r"^/api/users/(?P<id>\d+)$"), "users",
     "профиль #{id}", "изменён профиль"),
    ("DELETE", re.compile(r"^/api/users/(?P<id>\d+)$"), "users",
     "профиль #{id}", "удалён профиль"),
    ("POST", re.compile(r"^/api/users/(?P<id>\d+)/sessions/close$"), "users",
     "профиль #{id}", "закрыты все сессии профиля"),
    ("POST", re.compile(r"^/api/auth/password$"), "users",
     "", "сменён собственный пароль"),
]

# Signing in and out is not a change to anything and would bury the log.
IGNORE = (re.compile(r"^/api/auth/(login|logout)$"),)


def describe(method: str, path: str) -> tuple[str, str, str] | None:
    """Map a request to (area, target, summary), or None to skip it."""
    for pattern in IGNORE:
        if pattern.match(path):
            return None
    for rule_method, pattern, area, target, summary in RULES:
        if rule_method != method:
            continue
        hit = pattern.match(path)
        if hit:
            return area, target.format(**hit.groupdict()), summary
    # Unknown mutating endpoint: still logged, just without a friendly line.
    # Better a terse row than a silent gap.
    return "system", path, f"{method} {path}"


def _redact(value: Any) -> Any:
    if isinstance(value, dict):
        return {k: (REDACTED if k.lower() in SECRET_KEYS else _redact(v))
                for k, v in value.items()}
    if isinstance(value, list):
        return [_redact(v) for v in value]
    return value


def payload_text(raw: bytes) -> str | None:
    if not raw:
        return None
    try:
        text = json.dumps(_redact(json.loads(raw.decode("utf-8"))),
                          ensure_ascii=False, sort_keys=True)
    except Exception:
        # Not JSON (or not decodable) — keep the bytes' shape, not the bytes.
        return f"<не JSON, {len(raw)} байт>"
    if len(text) > MAX_PAYLOAD:
        text = text[:MAX_PAYLOAD] + f"… (обрезано, всего {len(text)} символов)"
    return text


# --- writing --------------------------------------------------------------

def record(*, actor: Any, method: str, path: str, status: int,
           raw_body: bytes) -> None:
    """Append one row. Never raises — a broken log must not break an edit.

    `actor` is None when the request never got as far as the role check (a
    malformed body, an unknown path); the row is still written, unnamed.
    """
    try:
        described = describe(method, path)
        if described is None:
            return
        area, target, summary = described
        ensure_schema()
        with cursor(commit=True) as cur:
            cur.execute(
                "INSERT INTO `admin_audit` (actor_id, actor_login, actor_name, "
                "actor_role, area, target, summary, method, path, payload, "
                "status, ok) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, "
                "%s, %s)",
                (getattr(actor, "id", 0), getattr(actor, "login", "—"),
                 getattr(actor, "name", "неизвестно"),
                 getattr(actor, "role", ""),
                 area, target[:120], summary[:255], method, path[:200],
                 payload_text(raw_body), status, int(status < 400)))
    except Exception:
        pass


# --- reading --------------------------------------------------------------

def entries(area: str = "", actor: str = "", q: str = "",
            failures_only: bool = False, limit: int = 100,
            before_id: int = 0) -> list[dict]:
    ensure_schema()
    where = ["1"]
    args: list[Any] = []
    if area:
        where.append("area = %s")
        args.append(area)
    if actor:
        where.append("actor_login = %s")
        args.append(actor)
    if q:
        where.append("(summary LIKE %s OR target LIKE %s OR path LIKE %s)")
        args += [f"%{q}%"] * 3
    if failures_only:
        where.append("ok = 0")
    if before_id:
        where.append("id < %s")
        args.append(before_id)
    args.append(max(1, min(limit, 500)))
    with cursor() as cur:
        cur.execute(
            "SELECT id, at, actor_id, actor_login, actor_name, actor_role, "
            "area, target, summary, method, path, payload, status, ok "
            "FROM `admin_audit` WHERE " + " AND ".join(where) +
            " ORDER BY id DESC LIMIT %s", args)
        rows = cur.fetchall()
    for row in rows:
        if isinstance(row["at"], _dt.datetime):
            row["at"] = row["at"].isoformat(sep=" ")
        row["area_label"] = AREA_LABEL.get(row["area"], row["area"])
    return rows


def actors() -> list[dict]:
    """Everyone who appears in the log, for the filter dropdown."""
    ensure_schema()
    with cursor() as cur:
        cur.execute(
            "SELECT actor_login, MAX(actor_name) AS actor_name, "
            "COUNT(*) AS n FROM `admin_audit` GROUP BY actor_login "
            "ORDER BY n DESC")
        return cur.fetchall()


def stats() -> dict:
    ensure_schema()
    with cursor() as cur:
        cur.execute("SELECT COUNT(*) AS n FROM `admin_audit`")
        total = int(cur.fetchone()["n"])
        cur.execute("SELECT COUNT(*) AS n FROM `admin_audit` "
                    "WHERE at > NOW() - INTERVAL 1 DAY")
        day = int(cur.fetchone()["n"])
    return {"total": total, "last_day": day}
