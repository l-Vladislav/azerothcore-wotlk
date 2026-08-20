"""Environment-backed settings for the admin panel.

Everything is read once at import. The PTR guard in `check_ptr_only()` is the
single place that keeps this tool away from the live database.
"""

import os


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


# --- database -------------------------------------------------------------
DB_HOST = _env("ADMIN_DB_HOST", "ac-database-v2")
DB_PORT = int(_env("ADMIN_DB_PORT", "3306"))
DB_USER = _env("ADMIN_DB_USER", "root")
DB_PASS = _env("ADMIN_DB_PASS", "password")
DB_NAME = _env("ADMIN_DB_NAME", "acore_world_ptr")

# Escape hatch, deliberately awkward. Without it the panel refuses any schema
# whose name does not end in "_ptr", so a misconfigured env cannot touch live.
ALLOW_NON_PTR = _env("ADMIN_ALLOW_NON_PTR", "0") == "1"

# --- panel-owned schema ---------------------------------------------------
# The board (bugs / ideas) is panel data, not game data: it must survive PTR
# snapshot restores and must never live in a *_ptr schema that gets rolled
# back. It gets its own database, created on first start.
BOARD_DB_NAME = _env("ADMIN_BOARD_DB_NAME", "acore_admin")

# --- worldserver SOAP -----------------------------------------------------
SOAP_HOST = _env("ADMIN_SOAP_HOST", "ac-worldserver-ptr")
SOAP_PORT = int(_env("ADMIN_SOAP_PORT", "7878"))
SOAP_USER = _env("ADMIN_SOAP_USER", "")
SOAP_PASS = _env("ADMIN_SOAP_PASS", "")

# --- repo paths (mounted read-write for the SQL export) -------------------
REPO_ROOT = _env("ADMIN_REPO_ROOT", "/repo")
MODULE_DIR = os.path.join(REPO_ROOT, "modules", "mod-environmental-effects")
MANIFEST_CSV = os.path.join(MODULE_DIR, "docs", "client_manifest.csv")
AREATABLE_CSV = os.path.join(REPO_ROOT, ".claude", "dbc", "AreaTable.csv")
# Client-side Spell.dbc source that the spell workshop patches; the MPQ rebuild
# which consumes it stays a manual step.
SPELL_CUSTOM_CSV = os.path.join(REPO_ROOT, ".claude", "dbc", "Spell_custom.csv")
# The ruRU client's Spell.dbc as CSV. The binary DBCs the server reads were
# extracted from an enUS client, so Russian names and descriptions for the
# catalogue come from here.
SPELL_CSV = os.path.join(REPO_ROOT, ".claude", "dbc", "Spell.csv")
# Icons the MPQ adds beyond the stock SpellIcon.dbc.
SPELL_ICON_CUSTOM_CSV = os.path.join(REPO_ROOT, ".claude", "dbc",
                                     "SpellIcon_custom.csv")

# --- client data volume (read-only) ---------------------------------------
# The same `ac-client-data-v2` volume the worldserver mounts: these are the
# exact bytes it loads at startup, which makes them the only complete answer
# to "what spells exist". Absent mount = the catalogue reports itself as
# unavailable, nothing else breaks.
DBC_DIR = _env("ADMIN_DBC_DIR", "/client-data/dbc")
SEED_SQL = os.path.join(
    REPO_ROOT, "data", "sql", "updates", "pending_db_world",
    "mod_env_effects_v2_seed.sql")

# --- auth -----------------------------------------------------------------
# Single shared token for now (single-operator tool). Roles land here later:
# this is the one place that decides *who* is calling.
ADMIN_TOKEN = _env("ADMIN_TOKEN", "")

# --- icons ----------------------------------------------------------------
# Icon textures are stock Blizzard names (e.g. achievement_zone_alteracmountains_01).
# A local PNG in app/static/icons/<name>.png wins; otherwise the panel falls back
# to this base URL. Set it empty to disable remote icons entirely.
ICON_BASE_URL = _env(
    "ADMIN_ICON_BASE_URL", "https://wow.zamimg.com/images/wow/icons/large")


class ConfigError(RuntimeError):
    pass


def check_ptr_only() -> None:
    """Refuse to run against anything that is not a *_ptr schema."""
    if ALLOW_NON_PTR:
        return
    if not DB_NAME.endswith("_ptr"):
        raise ConfigError(
            f"ADMIN_DB_NAME={DB_NAME!r} is not a *_ptr schema. This panel only "
            f"edits PTR. Set ADMIN_ALLOW_NON_PTR=1 if you really mean it.")
