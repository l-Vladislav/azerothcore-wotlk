"""People who may use the panel: profiles, invite links, sessions.

The panel used to be one shared token for one operator. It is now reachable
over the tailnet by several people, so "who is calling" has to be a real
answer — the board signs cards with it and `audit.py` signs every change with
it.

Three roles, ordered. A check is always "at least this much":

    viewer  — reads everything, and works the board (cards are the point of
              inviting anyone in the first place)
    editor  — plus the module editors: weather, environment effects, item
              talents
    owner   — plus the things that are hard to undo or that hand out access:
              the spell workshop, SQL/client exports, cache reloads, and
              people management

Joining is by invite only; there is no public sign-up form. The owner mints a
link, hands it over, and whoever opens it picks a login and a password and
lands in the role the link carries. The link secret is never stored — only its
SHA-256 — so a leaked database row cannot be replayed as an invitation, and
the same holds for session cookies.

Passwords use `hashlib.scrypt` from the standard library rather than argon2 or
bcrypt: adding a native dependency to this image to protect a handful of
tailnet-only accounts is a worse trade than the stdlib KDF, which is a real
memory-hard KDF and needs no wheel.
"""

import datetime as _dt
import hashlib
import hmac
import os
import re
import secrets
from typing import Any, Literal

from pydantic import BaseModel, Field

from .paneldb import cursor, ensure

Role = Literal["viewer", "editor", "owner"]
ROLES: tuple[str, ...] = ("viewer", "editor", "owner")
ROLE_RANK = {name: i for i, name in enumerate(ROLES)}
ROLE_LABEL = {"viewer": "смотрящий", "editor": "редактор", "owner": "владелец"}

SESSION_COOKIE = "ac_admin_sid"
SESSION_DAYS = 30
LOGIN_RE = re.compile(r"^[a-z0-9][a-z0-9_.-]{1,31}$")

MIN_PASSWORD = 8


class UserError(RuntimeError):
    """Something the caller did wrong; surfaced as 400 by main.py."""


SCHEMA = [
    """
    CREATE TABLE IF NOT EXISTS `admin_user` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `login`      VARCHAR(32) NOT NULL,
      `name`       VARCHAR(64) NOT NULL DEFAULT '',
      `role`       ENUM('viewer','editor','owner') NOT NULL DEFAULT 'viewer',
      `pass_hash`  VARCHAR(255) NOT NULL,
      `disabled`   TINYINT(1) NOT NULL DEFAULT 0,
      `invited_by` VARCHAR(64) NOT NULL DEFAULT '',
      `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `last_seen`  DATETIME NULL DEFAULT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uq_login` (`login`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """,
    """
    CREATE TABLE IF NOT EXISTS `admin_invite` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `token_hash` CHAR(64) NOT NULL,
      `role`       ENUM('viewer','editor','owner') NOT NULL DEFAULT 'viewer',
      `note`       VARCHAR(120) NOT NULL DEFAULT '',
      `created_by` VARCHAR(64) NOT NULL DEFAULT '',
      `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `expires_at` DATETIME NULL DEFAULT NULL,
      `max_uses`   SMALLINT UNSIGNED NOT NULL DEFAULT 1,
      `uses`       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      `revoked`    TINYINT(1) NOT NULL DEFAULT 0,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uq_invite_token` (`token_hash`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """,
    """
    CREATE TABLE IF NOT EXISTS `admin_session` (
      `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
      `token_hash` CHAR(64) NOT NULL,
      `user_id`    INT UNSIGNED NOT NULL,
      `agent`      VARCHAR(200) NOT NULL DEFAULT '',
      `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `expires_at` DATETIME NOT NULL,
      `last_seen`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      UNIQUE KEY `uq_session_token` (`token_hash`),
      KEY `idx_session_user` (`user_id`),
      CONSTRAINT `fk_session_user` FOREIGN KEY (`user_id`)
        REFERENCES `admin_user` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    """,
]


def ensure_schema() -> None:
    ensure("users", SCHEMA)


# --- secrets --------------------------------------------------------------

def _now() -> _dt.datetime:
    return _dt.datetime.now().replace(microsecond=0)


def _digest(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def hash_password(password: str) -> str:
    """scrypt with a per-password salt, stored as one self-describing string."""
    if len(password) < MIN_PASSWORD:
        raise UserError(f"Пароль короче {MIN_PASSWORD} символов.")
    salt = os.urandom(16)
    n, r, p = 2 ** 14, 8, 1
    key = hashlib.scrypt(password.encode("utf-8"), salt=salt, n=n, r=r, p=p,
                         dklen=32)
    return f"scrypt${n}${r}${p}${salt.hex()}${key.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        kind, n, r, p, salt, key = stored.split("$")
        if kind != "scrypt":
            return False
        got = hashlib.scrypt(password.encode("utf-8"), salt=bytes.fromhex(salt),
                             n=int(n), r=int(r), p=int(p), dklen=len(key) // 2)
    except Exception:
        return False
    return hmac.compare_digest(got.hex(), key)


# --- the caller -----------------------------------------------------------

class Actor(BaseModel):
    """Who is making the current request."""

    id: int = 0
    login: str
    name: str
    role: Role
    # "token" is the shared ADMIN_TOKEN break-glass, "session" a real profile.
    source: Literal["session", "token"] = "session"

    def can(self, need: Role) -> bool:
        return ROLE_RANK[self.role] >= ROLE_RANK[need]


# The shared token predates profiles and stays as the bootstrap: without it
# nobody could mint the first invite, and a broken session table would lock
# everyone out of their own server.
ROOT = Actor(id=0, login="root", name="root (общий токен)", role="owner",
             source="token")


def _row_to_actor(row: dict) -> Actor:
    return Actor(id=int(row["id"]), login=row["login"],
                 name=row["name"] or row["login"], role=row["role"],
                 source="session")


def actor_for_session(token: str) -> Actor | None:
    """Resolve a session cookie, sliding its expiry forward on every use."""
    if not token:
        return None
    ensure_schema()
    with cursor(commit=True) as cur:
        cur.execute(
            "SELECT u.id, u.login, u.name, u.role, u.disabled, s.id AS sid "
            "FROM `admin_session` s JOIN `admin_user` u ON u.id = s.user_id "
            "WHERE s.token_hash = %s AND s.expires_at > NOW()",
            (_digest(token),))
        row = cur.fetchone()
        if not row or row["disabled"]:
            return None
        cur.execute(
            "UPDATE `admin_session` SET last_seen = NOW(), expires_at = %s "
            "WHERE id = %s",
            (_now() + _dt.timedelta(days=SESSION_DAYS), row["sid"]))
        cur.execute("UPDATE `admin_user` SET last_seen = NOW() WHERE id = %s",
                    (row["id"],))
    return _row_to_actor(row)


# --- sessions -------------------------------------------------------------

def open_session(user_id: int, agent: str = "") -> str:
    token = secrets.token_urlsafe(32)
    ensure_schema()
    with cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO `admin_session` (token_hash, user_id, agent, "
            "expires_at) VALUES (%s, %s, %s, %s)",
            (_digest(token), user_id, agent[:200],
             _now() + _dt.timedelta(days=SESSION_DAYS)))
    return token


def close_session(token: str) -> None:
    if not token:
        return
    ensure_schema()
    with cursor(commit=True) as cur:
        cur.execute("DELETE FROM `admin_session` WHERE token_hash = %s",
                    (_digest(token),))


def close_all_sessions(user_id: int) -> int:
    ensure_schema()
    with cursor(commit=True) as cur:
        return cur.execute("DELETE FROM `admin_session` WHERE user_id = %s",
                           (user_id,))


def sign_in(login: str, password: str, agent: str = "") -> tuple[Actor, str]:
    ensure_schema()
    with cursor() as cur:
        cur.execute(
            "SELECT id, login, name, role, pass_hash, disabled "
            "FROM `admin_user` WHERE login = %s", (login.strip().lower(),))
        row = cur.fetchone()
    # One message for both cases: a distinct "no such user" would let anyone on
    # the tailnet enumerate who has an account here.
    wrong = UserError("Неверный логин или пароль.")
    if not row or not verify_password(password, row["pass_hash"]):
        raise wrong
    if row["disabled"]:
        raise UserError("Профиль отключён — обратись к владельцу панели.")
    return _row_to_actor(row), open_session(int(row["id"]), agent)


# --- invitations ----------------------------------------------------------

class InviteIn(BaseModel):
    role: Role = "viewer"
    note: str = Field("", max_length=120)
    # Both bounded on purpose: an invite that never expires and never runs out
    # is a second shared token, which is the thing profiles exist to replace.
    expires_hours: int = Field(72, ge=1, le=24 * 30)
    max_uses: int = Field(1, ge=1, le=20)


def create_invite(payload: InviteIn, by: str) -> dict:
    ensure_schema()
    token = secrets.token_urlsafe(24)
    expires = _now() + _dt.timedelta(hours=payload.expires_hours)
    with cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO `admin_invite` (token_hash, role, note, created_by, "
            "expires_at, max_uses) VALUES (%s, %s, %s, %s, %s, %s)",
            (_digest(token), payload.role, payload.note.strip(), by, expires,
             payload.max_uses))
        invite_id = cur.lastrowid
    # The secret is returned exactly once, here. Nothing stores it.
    return {"id": invite_id, "token": token, "role": payload.role,
            "note": payload.note.strip(), "expires_at": expires.isoformat(),
            "max_uses": payload.max_uses}


def list_invites() -> list[dict]:
    ensure_schema()
    with cursor() as cur:
        cur.execute(
            "SELECT id, role, note, created_by, created_at, expires_at, "
            "max_uses, uses, revoked FROM `admin_invite` ORDER BY id DESC")
        rows = cur.fetchall()
    now = _now()
    out = []
    for row in rows:
        expired = bool(row["expires_at"] and row["expires_at"] <= now)
        spent = row["uses"] >= row["max_uses"]
        row["state"] = ("revoked" if row["revoked"] else
                        "expired" if expired else
                        "spent" if spent else "live")
        out.append(_isoformat(row))
    return out


def revoke_invite(invite_id: int) -> None:
    ensure_schema()
    with cursor(commit=True) as cur:
        touched = cur.execute(
            "UPDATE `admin_invite` SET revoked = 1 WHERE id = %s", (invite_id,))
        if not touched:
            raise UserError("Приглашение не найдено.")


def _live_invite(token: str) -> dict:
    ensure_schema()
    with cursor() as cur:
        cur.execute(
            "SELECT id, role, note, created_by, expires_at, max_uses, uses, "
            "revoked FROM `admin_invite` WHERE token_hash = %s",
            (_digest(token or ""),))
        row = cur.fetchone()
    if not row or row["revoked"]:
        raise UserError("Ссылка недействительна — попроси новую.")
    if row["expires_at"] and row["expires_at"] <= _now():
        raise UserError("Срок ссылки истёк — попроси новую.")
    if row["uses"] >= row["max_uses"]:
        raise UserError("Ссылка уже использована — попроси новую.")
    return row


def peek_invite(token: str) -> dict:
    """What the join page shows before anyone types anything."""
    row = _live_invite(token)
    return {"role": row["role"], "note": row["note"],
            "role_label": ROLE_LABEL[row["role"]]}


class JoinIn(BaseModel):
    token: str
    login: str = Field(min_length=2, max_length=32)
    name: str = Field("", max_length=64)
    password: str = Field(min_length=MIN_PASSWORD, max_length=200)


def redeem_invite(payload: JoinIn, agent: str = "") -> tuple[Actor, str]:
    """Turn a valid link into a profile plus a signed-in session."""
    login = payload.login.strip().lower()
    if not LOGIN_RE.match(login):
        raise UserError(
            "Логин: латиница, цифры, точка, дефис и подчёркивание, "
            "от 2 до 32 символов, начинается с буквы или цифры.")
    pass_hash = hash_password(payload.password)
    invite = _live_invite(payload.token)
    name = (payload.name or login).strip()[:64]
    ensure_schema()
    with cursor(commit=True) as cur:
        # Re-check the invite inside the transaction and consume it with a
        # conditional UPDATE: two people opening the same one-use link at the
        # same moment must not both get in.
        taken = cur.execute(
            "UPDATE `admin_invite` SET uses = uses + 1 WHERE id = %s "
            "AND revoked = 0 AND uses < max_uses "
            "AND (expires_at IS NULL OR expires_at > NOW())", (invite["id"],))
        if not taken:
            raise UserError("Ссылка уже использована — попроси новую.")
        cur.execute("SELECT id FROM `admin_user` WHERE login = %s", (login,))
        if cur.fetchone():
            raise UserError(f"Логин «{login}» уже занят — выбери другой.")
        cur.execute(
            "INSERT INTO `admin_user` (login, name, role, pass_hash, "
            "invited_by) VALUES (%s, %s, %s, %s, %s)",
            (login, name, invite["role"], pass_hash, invite["created_by"]))
        user_id = cur.lastrowid
    actor = Actor(id=user_id, login=login, name=name, role=invite["role"],
                  source="session")
    return actor, open_session(user_id, agent)


# --- profiles -------------------------------------------------------------

def _isoformat(row: dict) -> dict:
    for key, value in list(row.items()):
        if isinstance(value, _dt.datetime):
            row[key] = value.isoformat(sep=" ")
    return row


def list_users() -> list[dict]:
    ensure_schema()
    with cursor() as cur:
        cur.execute(
            "SELECT u.id, u.login, u.name, u.role, u.disabled, u.invited_by, "
            "u.created_at, u.last_seen, "
            "(SELECT COUNT(*) FROM `admin_session` s "
            " WHERE s.user_id = u.id AND s.expires_at > NOW()) AS sessions "
            "FROM `admin_user` u ORDER BY u.id")
        rows = cur.fetchall()
    return [_isoformat(row) for row in rows]


def count_owners(exclude: int = 0) -> int:
    with cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) AS n FROM `admin_user` WHERE role = 'owner' "
            "AND disabled = 0 AND id <> %s", (exclude,))
        return int(cur.fetchone()["n"])


class UserPatch(BaseModel):
    name: str | None = Field(None, max_length=64)
    role: Role | None = None
    disabled: bool | None = None


def patch_user(user_id: int, patch: UserPatch) -> dict:
    ensure_schema()
    fields: dict[str, Any] = {}
    if patch.name is not None:
        fields["name"] = patch.name.strip()[:64]
    if patch.role is not None:
        fields["role"] = patch.role
    if patch.disabled is not None:
        fields["disabled"] = int(patch.disabled)
    if not fields:
        raise UserError("Нечего менять.")
    # Locking yourself out of your own panel is the one mistake here with no
    # in-panel remedy, so the last active owner cannot be demoted or switched
    # off. The shared token would still let you back in, but it is a
    # break-glass and should not be the thing that routinely saves you.
    demoted = patch.role is not None and patch.role != "owner"
    if (demoted or patch.disabled) and not count_owners(exclude=user_id):
        raise UserError("Это последний владелец — панель осталась бы без "
                        "администратора.")
    sets = ", ".join(f"`{k}` = %s" for k in fields)
    with cursor(commit=True) as cur:
        if not cur.execute(f"UPDATE `admin_user` SET {sets} WHERE id = %s",
                           (*fields.values(), user_id)):
            raise UserError("Профиль не найден.")
        cur.execute("SELECT id, login, name, role, disabled FROM `admin_user` "
                    "WHERE id = %s", (user_id,))
        row = cur.fetchone()
    # A demoted or disabled profile must lose its open tabs too, otherwise the
    # change only lands whenever they happen to sign in again.
    if patch.role is not None or patch.disabled:
        close_all_sessions(user_id)
    return row


def delete_user(user_id: int) -> dict:
    ensure_schema()
    with cursor() as cur:
        cur.execute("SELECT id, login, name, role FROM `admin_user` "
                    "WHERE id = %s", (user_id,))
        row = cur.fetchone()
    if not row:
        raise UserError("Профиль не найден.")
    if row["role"] == "owner" and not count_owners(exclude=user_id):
        raise UserError("Это последний владелец — удалять его некому на смену.")
    with cursor(commit=True) as cur:
        cur.execute("DELETE FROM `admin_user` WHERE id = %s", (user_id,))
    return row


class PasswordIn(BaseModel):
    current: str = ""
    password: str = Field(min_length=MIN_PASSWORD, max_length=200)


def set_password(user_id: int, payload: PasswordIn,
                 verify_current: bool) -> None:
    ensure_schema()
    with cursor() as cur:
        cur.execute("SELECT pass_hash FROM `admin_user` WHERE id = %s",
                    (user_id,))
        row = cur.fetchone()
    if not row:
        raise UserError("Профиль не найден.")
    if verify_current and not verify_password(payload.current,
                                              row["pass_hash"]):
        raise UserError("Текущий пароль неверен.")
    new_hash = hash_password(payload.password)
    with cursor(commit=True) as cur:
        cur.execute("UPDATE `admin_user` SET pass_hash = %s WHERE id = %s",
                    (new_hash, user_id))
    close_all_sessions(user_id)


def bootstrap_needed() -> bool:
    """True while nobody has a profile — the login page says so."""
    ensure_schema()
    with cursor() as cur:
        cur.execute("SELECT COUNT(*) AS n FROM `admin_user`")
        return int(cur.fetchone()["n"]) == 0
