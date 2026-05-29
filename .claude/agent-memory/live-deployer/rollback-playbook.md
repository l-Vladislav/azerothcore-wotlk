# Rollback playbook

## When to rollback

- Smoke test fails immediately after apply
- Operator notices a regression in game (broken NPC, missing item, server crash)
- Apply itself succeeded but later analysis shows the change was wrong

## When NOT to rollback (use forward-fix instead)

- Time has passed and other writes happened to the DB (rollback would lose them)
- The bad change is in a single row that can be corrected with a follow-up UPDATE/DELETE
- Players are mid-raid/battleground — coordinate a forward-fix during low-traffic

## How rollback works (in `rollback.ps1`)

1. Verifies snapshot file exists (`pre-deploy-snapshot.sql.gz` in the package dir)
2. Asks operator to type literal `rollback` to confirm
3. Stops `ac-worldserver-v2` (prevent in-flight writes)
4. Restores the snapshot via `gunzip | mysql -uroot -ppassword <db>`
5. Starts `ac-worldserver-v2`

## Snapshot semantics

The snapshot taken at apply-time is a **full mysqldump of the target DB**. Rollback restores the ENTIRE DB to that point.

**This means:** any writes to `acore_world` (or whichever DB) between apply-time and rollback-time are LOST. For `acore_world` this is usually safe (it changes infrequently outside deployments). For `acore_characters` (every player action writes) this is dangerous — coordinate with operators before restoring.

## Edge cases

### "Snapshot file is missing or corrupt"

The package's `apply.ps1` always takes a snapshot before applying. If the file is missing:
- Maybe `apply.ps1` was edited and the snapshot step removed (don't do this)
- Maybe disk space ran out during dump (check `apply.ps1` exit code)
- Without snapshot, rollback is impossible from this package. Use a manual reverse-SQL (DELETE for INSERT, restore old value for UPDATE).

### "Rollback restored DB but worldserver still broken"

Worldserver caches some data in memory. After rollback, restart `ac-worldserver-v2` (the rollback script does this).

If still broken — check for:
- Cached DBC values not refreshed (rare; usually needs full container restart)
- Background worker stuck in a loop based on a row that's now gone (kill the worker via console command, or full restart)

### "I need to rollback just ONE change, not the whole DB"

Manually craft reverse SQL based on the original file's INSERT/UPDATE/DELETE statements:
- `INSERT INTO X (a,b,c) VALUES (1,2,3)` → `DELETE FROM X WHERE a=1 AND b=2 AND c=3`
- `UPDATE X SET col = 'new' WHERE id = 5` → need to know old value (check the snapshot)
- `DELETE FROM X WHERE …` → cannot reconstruct without snapshot

For complex changes, restore from snapshot to a temp DB (`acore_world_rollback_tmp`), pluck the rows you need, then UPDATE live with them.

## After a rollback

1. Capture the reason in the package's `manifest.md` — append a `## Rollback notes` section
2. Don't reapply the same SQL until the bug is understood
3. If the bug is in the SQL itself — fix the source file in `pending_db_world/`, apply to PTR, retest, regenerate a new deployment package (do NOT reuse the rolled-back one)
4. Update `deployments.log` with the rollback event:
   ```
   2026-05-29 15:00 | statbooster_X.sql | acore_world | ROLLED BACK | reason: smoke test failed (NPC spawn broken) | package: <path>
   ```

## Disaster recovery (full DB loss)

Not covered by this playbook — this is operations/SRE territory. Project's `scripts/sync-prod-to-ptr.ps1` shows the snapshot/restore pattern but not the recovery flow.
