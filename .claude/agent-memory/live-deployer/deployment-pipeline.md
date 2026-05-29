# Deployment pipeline: PTR-tested → live

## Roles

- **You (agent):** read live state, prepare package, write apply/rollback scripts
- **Human:** review package, execute `apply.ps1`, confirm success, optionally execute `rollback.ps1`

## Infrastructure map

| Component | Live | PTR |
|---|---|---|
| Worldserver container | `ac-worldserver-v2` | `ac-worldserver-ptr` |
| Database (shared MySQL container) | `acore_world`, `acore_characters`, `acore_auth`, `acore_playerbots` | `acore_world_ptr`, `acore_characters_ptr` |
| Auth server | `ac-authserver-v2` | (shared with live) |
| Update tracking | each DB has its own `updates` table (AC built-in) | same |
| SQL source files | `data/sql/updates/pending_db_world|characters|auth/` (shared between live + PTR) | same |
| Sync script (live→PTR, USER ONLY) | `scripts/sync-prod-to-ptr.ps1` | — |

## Standard deployment flow

### 1. Diff: what's pending?

```powershell
pwsh scripts/live-diff-pending.ps1
```
Outputs files with status `NEW` (never applied to live) or `MODIFIED` (applied with different hash).

### 2. Generate deployment package

```powershell
pwsh scripts/live-deploy-package.ps1 -SqlFile data/sql/updates/pending_db_world/<filename>.sql
```

The script:
1. Validates the SQL (no DROP DATABASE etc.)
2. Confirms the file was applied to PTR
3. Checks if already on live (warns)
4. Creates `.claude/agent-memory/live-deployer/packages/<timestamp>-<basename>/`
5. Writes:
   - `manifest.md` — human-readable summary
   - `original.sql` — copy of the SQL
   - `apply.ps1` — what the human runs
   - `rollback.ps1` — restore-from-snapshot if needed

### 3. Human reviews + runs apply

User opens `manifest.md`, glances at `original.sql`, then:
```powershell
pwsh .claude/agent-memory/live-deployer/packages/<timestamp>-<basename>/apply.ps1
```

`apply.ps1` does:
1. `mysqldump | gzip > pre-deploy-snapshot.sql.gz` (live DB snapshot)
2. Apply the SQL to live DB
3. Read back from `updates` table to verify
4. Ask "restart worldserver-v2 now? (yes/skip)"
5. If yes → `docker restart ac-worldserver-v2`

### 4. Smoke test (manual)

Operator checks in-game that the change works. If not — `rollback.ps1`.

### 5. Agent updates log

Once human confirms apply success, the agent appends to `deployments.log`:
```
2026-05-29 14:30 | statbooster_X.sql | acore_world | success | package: <path>
```

## Pre-flight checks the agent enforces

Before generating any package:

| Check | Action if fails |
|---|---|
| File exists | refuse |
| Forbidden DDL (`DROP DATABASE`, `TRUNCATE TABLE`, `DROP TABLE`, `mysql_install_db`) | refuse |
| File applied to PTR (in `acore_world_ptr.updates`) | refuse unless `-SkipPtrCheck` |
| File hash on PTR matches file content | warn (file was changed after PTR apply — needs re-test) |
| File already on live with same hash | warn ("already applied"), still allow re-package (idempotent SQL is OK to re-run) |

## What's NOT in this pipeline (manual / out-of-scope)

- **Client MPQ deployment** — when SQL is paired with new client-side DBCs (Spell.dbc, SpellItemEnchantment.dbc, etc.), the operator must also deploy the MPQ to player clients. Mention in manifest.md if SQL touches `spell_dbc`, `spellitemenchantment_dbc`, `item_template` with new IDs, etc.
- **EnchantDB.lua** addon update — when SQL touches StatBooster enchant IDs, the addon's `EnchantDB.lua` must also be deployed to live clients (see [[text-localization-rules]] in statbooster-dev memory). Flag in manifest.
- **Coordinated multi-file deploys** — if changes span multiple SQL files that must apply together, current pipeline does one at a time. Generate packages in dependency order; mention in manifest that this is part of a sequence.
- **Player announcement / maintenance window** — operator's call. Pipeline doesn't post Discord messages or similar.

## After-deploy verification

The `apply.ps1` already verifies via `updates.name` lookup. For deeper verification, the operator can run task-specific smoke queries — these belong in the SQL file's header comment (e.g. "verify with: SELECT ID FROM spell_dbc WHERE ID = 100037").
