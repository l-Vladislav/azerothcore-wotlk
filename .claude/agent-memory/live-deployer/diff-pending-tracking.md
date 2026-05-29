# How to find what's pending promotion to live

## AC's built-in `updates` table

AzerothCore writes a row to `<database>.updates` every time a SQL file from `data/sql/updates/` is applied via the import loader. This is the canonical source of truth for "has this file been applied to this database".

Schema:
| Field | Type | Purpose |
|---|---|---|
| `name` | varchar(200) PK | SQL filename (e.g. `statbooster_pool1_base.sql`) |
| `hash` | char(40) | SHA-1 of the SQL file contents at apply time |
| `state` | enum | `RELEASED`, `CUSTOM`, `MODULE`, `ARCHIVED`, `PENDING` |
| `timestamp` | timestamp | when it was applied |
| `speed` | int | apply duration in ms |

The `updates` table exists in `acore_world`, `acore_world_ptr`, `acore_characters`, `acore_characters_ptr`, `acore_auth`, etc.

## The diff query

```sql
SELECT
    ptr.name        AS name,
    ptr.hash        AS ptr_hash,
    IFNULL(live.hash, '<absent>') AS live_hash,
    FROM_UNIXTIME(ptr.timestamp) AS ptr_applied,
    IFNULL(FROM_UNIXTIME(live.timestamp), '<never>') AS live_applied,
    CASE
        WHEN live.name IS NULL THEN 'NEW'
        WHEN ptr.hash != live.hash THEN 'MODIFIED'
        ELSE 'IN_SYNC'
    END AS status
FROM acore_world_ptr.updates ptr
LEFT JOIN acore_world.updates live ON ptr.name = live.name
ORDER BY ptr.timestamp DESC;
```

Wrapped in `scripts/live-diff-pending.ps1` for quick CLI use.

## Status meanings

- **`NEW`** — file in PTR but NOT in live → needs promotion
- **`MODIFIED`** — file in both, but PTR has different hash → the SQL was edited after live apply, needs re-promotion
- **`IN_SYNC`** — same hash on both → no action needed

## ⚠️ Critical limitation: ad-hoc applies bypass `updates`

The AC `updates` table is populated by AC's own **worldserver-import** process (runs on startup if configured). It is **NOT** populated by:
- `scripts/ptr-sql-apply.ps1` — applies SQL directly via `mysql < file.sql`
- Manual `docker exec ac-database-v2 mysql ... < file.sql`
- Ad-hoc `UPDATE`/`INSERT` in console

So if you ran an SQL via `ptr-sql-apply.ps1`, the change IS in the DB but NOT recorded in `updates`. The diff query will miss it.

**Implication:** `updates` table tracks only "AC-imported" SQL files, which is typically just the initial batch loaded at worldserver startup. For ad-hoc changes (most of our work), use `deployments.log` as the canonical record.

## Two complementary tracking sources

| Source | Records what | Reliability |
|---|---|---|
| `<db>.updates` table | SQL files AC's import loaded | Authoritative for AC's own migration set |
| `.claude/agent-memory/live-deployer/deployments.log` | Files agent helped promote to live | Authoritative for ad-hoc agent-managed deployments |
| `data/sql/updates/pending_db_*/` filesystem | Files that EXIST as deployable units | Just what's on disk — doesn't indicate deploy status |

**Recommended check for "is X deployed to live?":**
1. Search `deployments.log` for the filename + "success" status → most reliable
2. If not in log, query `acore_world.updates WHERE name = '<file>'` → may catch AC-imported case
3. If neither — manually inspect DB (`SELECT * FROM <table> WHERE <key>=<expected_row>`)

## Common confusions

### "Live and PTR both show the same file applied"

That doesn't mean they were applied at the same time or with the same content. **Always compare hashes**, not just names. The `live-diff-pending.ps1` script handles this.

### "File is in `pending_db_world/` but not in `updates`"

That means it has never been applied anywhere. Apply to PTR first via `ptr-sql-apply.ps1`, then run the diff.

### "AC moves merged updates from `pending_db_world/` to `db_world/`"

Yes — AzerothCore upstream convention is that merged PRs cause SQL files to move from `pending_db_*/` to `db_*/`. In **this fork**, the user reportedly keeps files in `pending_db_*/` indefinitely for hot-reload convenience. Don't move files just to follow upstream convention.

## Backward direction (live → PTR)

`scripts/sync-prod-to-ptr.ps1` does a full DROP+CREATE+mysqldump-restore of `acore_world_ptr` from `acore_world`. It is **USER-RUN ONLY** — do not invoke it as agent.

## Useful one-liners

```powershell
# Total updates count, per DB
docker exec ac-database-v2 mysql -uroot -ppassword -e `
  "SELECT 'world_live' AS db, COUNT(*) FROM acore_world.updates UNION ALL `
   SELECT 'world_ptr', COUNT(*) FROM acore_world_ptr.updates UNION ALL `
   SELECT 'chars_live', COUNT(*) FROM acore_characters.updates UNION ALL `
   SELECT 'chars_ptr', COUNT(*) FROM acore_characters_ptr.updates"

# Files in live but somehow missing from PTR (unusual — investigate)
docker exec ac-database-v2 mysql -uroot -ppassword -e `
  "SELECT live.name FROM acore_world.updates live `
   LEFT JOIN acore_world_ptr.updates ptr ON live.name = ptr.name `
   WHERE ptr.name IS NULL"
```
