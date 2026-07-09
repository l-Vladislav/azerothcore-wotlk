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

## Gotchas discovered in later deployments

### Sandbox denies `DROP DATABASE` even for throwaway scratch DBs

The agent's permission policy has `"Bash(*DROP DATABASE*)"` as a blanket deny (see
`.claude/settings.local.json`) — it matches on substring, not target DB name, so you cannot
create-then-drop a disposable `xyz_dryrun` database to test-import a package's SQL before shipping
it (the technique the mod-worn-drops package used). When this blocks you, substitute: (a) a full
pre-flight comparison of every touched ID/row against the real live schema (read-only `SELECT`s are
fine), and (b) diffing content against PTR for any row ranges that might already overlap. Document
in the manifest that a scratch-DB dry-run wasn't possible and why (2026-07-04, mod-transmog-full
package).

### `MODULES=static` bakes in EVERY module under `modules/`, not just the one you meant to ship

A `docker compose build ac-worldserver` compiles every module directory present in `modules/` into
the live binary — there is no way to build "just worn-drops" or "just transmog". If a new module's
source has already been added to the tree (e.g. for PTR dev) at the time an unrelated deploy
triggers a live rebuild, that new module's code goes live too, silently, with no SQL and no config
ever having been deployed for it. Discovered 2026-07-04: the 2026-07-02 rebuild done for the
mod-worn-drops deploy incidentally activated mod-transmog-ui's appearance-collection hook (which
needs no config/DB row to do *something*) against real players for ~1 day before anyone noticed via
`docker logs | grep -i <module>`. Lesson: **before any live rebuild, grep the boot log afterward for
every module under `modules/`**, not just the one you intended to ship — a "surprise" module may
have come along for the ride. This is a variant of the worn-drops "verify ALL module load lines"
lesson, but for *unintended inclusions* rather than *missed hooks after an abort*.

### Unlogged live rebuilds are now a recurring pattern — verify ground truth EVERY time, never trust the task brief or memory

Third occurrence as of 2026-07-07 (after mod-transmog-full and mod-ollama-chat-phase3, both
"discovered retroactively"): a live rebuild happened (this time 2026-07-07 ~08:22 UTC, for
mod-item-talents) with no corresponding `deployments.log` entry and no package ever generated for
it. The task brief that triggered this package's generation was itself written assuming an OLDER,
already-stale state (it referenced yesterday's 13:14 rebuild as the most recent one, and assumed the
feature was still pre-deployment). **Do not trust any brief's framing of "first-time promotion" or
"not yet live" — always independently verify via**:
1. `docker inspect <container> --format "{{.Image}}"` then `docker inspect <image> --format
   "{{.Created}}"` — compare against every commit/file mtime you think matters, don't assume the
   logged rebuild is the current one.
2. Direct `SELECT COUNT(*)` / `CHECKSUM TABLE` against the live tables the feature would touch — row
   counts AND content checksums against PTR, not just "does the table exist".
3. `docker logs <container> | grep <module-name>` for the module's own self-reported boot line —
   this is the single fastest way to learn a feature is already active with real numbers (definition
   counts, cached entry counts, etc.) that you can then cross-check against the SQL files.

If ground truth contradicts the brief, the package must document reality, not the brief's
assumption — including flipping "apply" from a real deploy into an idempotent no-op reconcile when
appropriate (see the 2026-07-07 mod-item-talents-live-reconcile package for the pattern).
