# PTR-only writes — boundary rules

The agent **never** touches live data directly. All in-progress work lives on the PTR side; promotion to live is `live-deployer`'s job, not ours.

## SQL: always pending_db_world

- All familiar SQL lives in `data/sql/updates/pending_db_world/`.
- **Never** edit `data/sql/base/**`, `data/sql/updates/db_world/**`, or any `db_characters/db_auth` non-pending dir — those are denied in `settings.local.json` and silently rebuilt by `ac-db-import`.
- Module-local `modules/<mod>/data/sql/` is **not scanned** — files there get wiped on container rebuild. Use `pending_db_world/`.

## Direct DB queries: PTR DBs only

- Read-only: `acore_world_ptr`, `acore_characters_ptr`, `acore_auth_ptr`, `acore_playerbots_ptr`.
- Mutations on `acore_world/characters/auth` (no `_ptr` suffix) are **denied** in settings — use SQL migration files instead.
- Query helpers: `scripts/ptr-query.ps1` and `scripts/ptr-*.ps1` are pre-allowed.

## Restart scope

Allowed: `docker restart ac-worldserver-ptr`, `docker restart ac-database-v2`.
Denied: `ac-worldserver` and `ac-authserver*` (live containers).

## Idempotency

Every SQL migration must be re-runnable:
- `DELETE FROM creature_template WHERE entry IN (...)` before `INSERT INTO creature_template VALUES (...)`.
- `REPLACE INTO spell_dbc` over `INSERT`.
- `DELETE FROM item_template WHERE entry IN (...)` before `INSERT`.

This lets the same file apply cleanly on re-rebuild without `Duplicate entry` errors.

## CSV / DBC

Never touch `.claude/dbc/*_custom.csv` unless the user explicitly asks to «prepare MPQ». Server-side DB tweaks don't need a client patch — only cosmetic spell/item names do, and those come at the end.
