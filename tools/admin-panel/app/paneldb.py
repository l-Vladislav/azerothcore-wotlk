"""Connection to the panel's own schema (`config.BOARD_DB_NAME`).

Three things live in that schema and none of them are game data: the board of
bugs and ideas, the people who may use the panel, and the audit log of what
they changed. All three must survive a PTR snapshot restore, which is why they
are not in `acore_world_ptr` — and why this connector deliberately does not go
through `db.connect()`, whose PTR guard would reject `acore_admin` by design.

`ensure()` is the schema bootstrap: every module hands over its CREATE TABLE
statements under a key and gets a no-op on every call after the first.
"""

import contextlib
from typing import Iterator

import pymysql
from pymysql.cursors import DictCursor

from . import config


def connect(database: str | None) -> pymysql.connections.Connection:
    return pymysql.connect(
        host=config.DB_HOST, port=config.DB_PORT,
        user=config.DB_USER, password=config.DB_PASS,
        database=database, charset="utf8mb4",
        cursorclass=DictCursor, autocommit=False,
    )


@contextlib.contextmanager
def cursor(commit: bool = False) -> Iterator[DictCursor]:
    conn = connect(config.BOARD_DB_NAME)
    try:
        with conn.cursor() as cur:
            yield cur
        if commit:
            conn.commit()
        else:
            conn.rollback()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


_ready: set[str] = set()


def ensure(key: str, statements: list[str]) -> None:
    """Create the schema and `statements`' tables once per process."""
    if key in _ready:
        return
    conn = connect(None)
    try:
        with conn.cursor() as cur:
            cur.execute(
                "CREATE DATABASE IF NOT EXISTS `%s` DEFAULT CHARACTER SET "
                "utf8mb4 COLLATE utf8mb4_unicode_ci" % config.BOARD_DB_NAME)
            cur.execute("USE `%s`" % config.BOARD_DB_NAME)
            for stmt in statements:
                cur.execute(stmt)
        conn.commit()
    finally:
        conn.close()
    _ready.add(key)
