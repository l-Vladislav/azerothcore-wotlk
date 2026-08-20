"""Thin MySQL access layer.

No ORM on purpose: the panel touches exactly one writable table, and the queries
are short enough that raw SQL is the clearest thing to review.
"""

import contextlib
from typing import Any, Iterator

import pymysql
from pymysql.cursors import DictCursor

from . import config


def connect() -> pymysql.connections.Connection:
    config.check_ptr_only()
    return pymysql.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        user=config.DB_USER,
        password=config.DB_PASS,
        database=config.DB_NAME,
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=False,
    )


@contextlib.contextmanager
def cursor(commit: bool = False) -> Iterator[DictCursor]:
    conn = connect()
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


def query(sql: str, args: tuple = ()) -> list[dict[str, Any]]:
    with cursor() as cur:
        cur.execute(sql, args)
        return list(cur.fetchall())


def query_one(sql: str, args: tuple = ()) -> dict[str, Any] | None:
    rows = query(sql, args)
    return rows[0] if rows else None
