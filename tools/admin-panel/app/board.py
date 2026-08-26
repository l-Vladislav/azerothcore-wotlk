"""Kanban board: bug tickets and feature ideas.

Lives in the panel's own schema (`paneldb`, default `acore_admin`) rather than
in `acore_world_ptr`: PTR snapshots get rolled back, and this is panel data,
not game content. See `paneldb.py` for why that connector is separate.

Ordering: cards carry an explicit `position` inside their column. A move
renumbers only the columns it touched, so drag-and-drop is one small
transaction.
"""

import datetime as _dt
from typing import Any, Literal

from pydantic import BaseModel, Field

from .paneldb import cursor, ensure

KINDS = ("bug", "feature", "task")
STATUSES = ("backlog", "todo", "doing", "review", "done")

Kind = Literal["bug", "feature", "task"]
Status = Literal["backlog", "todo", "doing", "review", "done"]


SCHEMA = [
    """
    CREATE TABLE IF NOT EXISTS `board_card` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `kind`       ENUM('bug','feature','task') NOT NULL DEFAULT 'bug',
      `status`     ENUM('backlog','todo','doing','review','done')
                   NOT NULL DEFAULT 'backlog',
      `priority`   TINYINT UNSIGNED NOT NULL DEFAULT 1,
      `title`      VARCHAR(200) NOT NULL,
      `body`       TEXT NOT NULL,
      `module`     VARCHAR(64) NOT NULL DEFAULT '',
      `tags`       VARCHAR(255) NOT NULL DEFAULT '',
      `author`     VARCHAR(64) NOT NULL DEFAULT '',
      `assignee`   VARCHAR(64) NOT NULL DEFAULT '',
      `position`   INT NOT NULL DEFAULT 0,
      `archived`   TINYINT(1) NOT NULL DEFAULT 0,
      `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                   ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      KEY `idx_board` (`archived`, `status`, `position`),
      KEY `idx_module` (`module`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """,
    """
    CREATE TABLE IF NOT EXISTS `board_comment` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `card_id`    INT UNSIGNED NOT NULL,
      `author`     VARCHAR(64) NOT NULL DEFAULT '',
      `body`       TEXT NOT NULL,
      `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      KEY `idx_card` (`card_id`, `id`),
      CONSTRAINT `fk_comment_card` FOREIGN KEY (`card_id`)
        REFERENCES `board_card` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """,
]


def ensure_schema() -> None:
    """Create the panel schema and the board tables on first use."""
    ensure("board", SCHEMA)


# --- models ---------------------------------------------------------------

class CardIn(BaseModel):
    kind: Kind = "bug"
    status: Status = "backlog"
    priority: int = Field(1, ge=0, le=3)
    title: str = Field(min_length=1, max_length=200)
    body: str = ""
    module: str = ""
    tags: list[str] = []
    author: str = ""
    assignee: str = ""


class CardPatch(BaseModel):
    kind: Kind | None = None
    status: Status | None = None
    priority: int | None = Field(None, ge=0, le=3)
    title: str | None = Field(None, min_length=1, max_length=200)
    body: str | None = None
    module: str | None = None
    tags: list[str] | None = None
    author: str | None = None
    assignee: str | None = None
    archived: bool | None = None


class Move(BaseModel):
    status: Status
    position: int = Field(0, ge=0)


class CommentIn(BaseModel):
    body: str = Field(min_length=1)
    author: str = ""


# --- helpers --------------------------------------------------------------

def _row_to_card(row: dict[str, Any]) -> dict[str, Any]:
    out = dict(row)
    out["tags"] = [t for t in (row.get("tags") or "").split(",") if t]
    out["archived"] = bool(row["archived"])
    for field in ("created_at", "updated_at"):
        value = row.get(field)
        if isinstance(value, _dt.datetime):
            out[field] = value.isoformat(sep=" ", timespec="minutes")
    return out


def _tags_str(tags: list[str]) -> str:
    clean: list[str] = []
    for tag in tags:
        tag = tag.strip().lower().replace(",", " ")[:32]
        if tag and tag not in clean:
            clean.append(tag)
    return ",".join(clean[:8])


def _stamp(value: Any) -> Any:
    if isinstance(value, _dt.datetime):
        return value.isoformat(sep=" ", timespec="minutes")
    return value


# --- queries --------------------------------------------------------------

def list_cards(status: str | None = None, module: str | None = None,
               kind: str | None = None, q: str | None = None,
               archived: bool = False) -> list[dict]:
    ensure_schema()
    where = ["archived = %s"]
    args: list[Any] = [1 if archived else 0]
    if status:
        where.append("status = %s")
        args.append(status)
    if module:
        where.append("module = %s")
        args.append(module)
    if kind:
        where.append("kind = %s")
        args.append(kind)
    if q:
        where.append("(title LIKE %s OR body LIKE %s OR tags LIKE %s)")
        args += ["%" + q + "%"] * 3
    sql = ("SELECT c.*, (SELECT COUNT(*) FROM board_comment b "
           "WHERE b.card_id = c.id) AS comments FROM board_card c WHERE "
           + " AND ".join(where) + " ORDER BY position ASC, id DESC")
    with cursor() as cur:
        cur.execute(sql, tuple(args))
        return [_row_to_card(r) for r in cur.fetchall()]


def get_card(card_id: int) -> dict | None:
    ensure_schema()
    with cursor() as cur:
        cur.execute("SELECT * FROM board_card WHERE id = %s", (card_id,))
        row = cur.fetchone()
        if not row:
            return None
        card = _row_to_card(row)
        cur.execute("SELECT * FROM board_comment WHERE card_id = %s "
                    "ORDER BY id ASC", (card_id,))
        card["comments"] = [
            dict(c, created_at=_stamp(c["created_at"])) for c in cur.fetchall()]
        return card


def create_card(data: CardIn) -> dict:
    ensure_schema()
    with cursor(commit=True) as cur:
        # New cards land on top of their column, so filing one is visible
        # without scrolling.
        cur.execute("SELECT COALESCE(MIN(position), 0) - 1 AS p FROM "
                    "board_card WHERE status = %s AND archived = 0",
                    (data.status,))
        pos = int((cur.fetchone() or {}).get("p") or 0)
        cur.execute(
            "INSERT INTO board_card (kind, status, priority, title, body, "
            "module, tags, author, assignee, position) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
            (data.kind, data.status, data.priority, data.title.strip(),
             data.body, data.module, _tags_str(data.tags), data.author,
             data.assignee, pos))
        new_id = cur.lastrowid
    return get_card(new_id)


_PATCH_COLUMNS = ("kind", "status", "priority", "title", "body", "module",
                  "author", "assignee", "archived")


def update_card(card_id: int, patch: CardPatch) -> dict | None:
    ensure_schema()
    fields = patch.model_dump(exclude_none=True)
    sets, args = [], []
    for col in _PATCH_COLUMNS:
        if col in fields:
            sets.append("`" + col + "` = %s")
            args.append(int(fields[col]) if col == "archived" else fields[col])
    if "tags" in fields:
        sets.append("`tags` = %s")
        args.append(_tags_str(fields["tags"]))
    if not sets:
        return get_card(card_id)
    args.append(card_id)
    with cursor(commit=True) as cur:
        cur.execute("UPDATE board_card SET " + ", ".join(sets) +
                    " WHERE id = %s", tuple(args))
    return get_card(card_id)


def move_card(card_id: int, move: Move) -> list[dict]:
    """Put the card at `position` of `status`, then renumber both columns."""
    ensure_schema()
    with cursor(commit=True) as cur:
        cur.execute("SELECT status FROM board_card WHERE id = %s", (card_id,))
        row = cur.fetchone()
        if not row:
            return []
        touched = {row["status"], move.status}
        cur.execute("UPDATE board_card SET status = %s WHERE id = %s",
                    (move.status, card_id))
        for status in touched:
            cur.execute("SELECT id FROM board_card WHERE status = %s AND "
                        "archived = 0 ORDER BY position ASC, id DESC",
                        (status,))
            ids = [r["id"] for r in cur.fetchall()]
            if status == move.status:
                ids = [i for i in ids if i != card_id]
                ids.insert(min(move.position, len(ids)), card_id)
            for index, cid in enumerate(ids):
                cur.execute("UPDATE board_card SET position = %s WHERE id = %s",
                            (index, cid))
    return list_cards()


def delete_card(card_id: int, hard: bool = False) -> bool:
    ensure_schema()
    with cursor(commit=True) as cur:
        if hard:
            cur.execute("DELETE FROM board_card WHERE id = %s", (card_id,))
        else:
            cur.execute("UPDATE board_card SET archived = 1 WHERE id = %s",
                        (card_id,))
        return cur.rowcount > 0


def restore_card(card_id: int) -> dict | None:
    ensure_schema()
    with cursor(commit=True) as cur:
        cur.execute("UPDATE board_card SET archived = 0 WHERE id = %s",
                    (card_id,))
    return get_card(card_id)


def add_comment(card_id: int, data: CommentIn) -> dict | None:
    ensure_schema()
    with cursor(commit=True) as cur:
        cur.execute("SELECT id FROM board_card WHERE id = %s", (card_id,))
        if not cur.fetchone():
            return None
        cur.execute("INSERT INTO board_comment (card_id, author, body) "
                    "VALUES (%s,%s,%s)", (card_id, data.author, data.body))
    return get_card(card_id)


def stats() -> dict:
    """Counts for the home page: open cards by kind and by module."""
    ensure_schema()
    with cursor() as cur:
        cur.execute("SELECT kind, COUNT(*) AS n FROM board_card WHERE "
                    "archived = 0 AND status <> 'done' GROUP BY kind")
        by_kind = {r["kind"]: int(r["n"]) for r in cur.fetchall()}
        cur.execute("SELECT module, COUNT(*) AS n FROM board_card WHERE "
                    "archived = 0 AND status <> 'done' GROUP BY module")
        by_module = {r["module"]: int(r["n"]) for r in cur.fetchall()}
        cur.execute("SELECT COUNT(*) AS n FROM board_card WHERE archived = 0")
        total = int((cur.fetchone() or {"n": 0})["n"])
    return {"open": sum(by_kind.values()), "total": total,
            "by_kind": by_kind, "by_module": by_module}
