#Requires -Version 5.1
<#
.SYNOPSIS
    Rollback: Gear Ascension deploy -> restore acore_world from snapshot
    Package: 2026-06-20_1200-gear-ascension

.DESCRIPTION
    Restores acore_world to the state captured in pre-deploy-snapshot.sql.gz.
    This removes ALL Gear Ascension rows (item_template, item_upgrade_chain,
    spell_dbc, spell_script_names, itemextendedcost_dbc, npc_vendor kit rows,
    item_template_locale) atomically.

    The item_upgrade_chain table will be absent after rollback (it did not exist
    before the deploy). This is correct.

    IMPORTANT: This script does NOT revert:
      - The live worldserver image rebuild (C++ mod-gear-ascension baked in)
      - AHBot conf edits
      - Client MPQ distribution

    After rollback, the old worldserver image must be redeployed to avoid
    the C++ module attempting to read a table that no longer exists.

    Type 'rollback' at the confirmation prompt to proceed. Any other input aborts.

.NOTES
    Agent permission policy: this script is USER-RUN, NOT agent-run.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Config ---
$REPO_ROOT      = "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk"
$DB_CONTAINER   = "ac-database-v2"
$WS_CONTAINER   = "ac-worldserver-v2"
$DB_USER        = "root"
$DB_PASS        = if ($env:DOCKER_DB_ROOT_PASSWORD) { $env:DOCKER_DB_ROOT_PASSWORD } else { "password" }
$WORLD_DB       = "acore_world"

$PKG_DIR        = "$REPO_ROOT\.claude\agent-memory\live-deployer\packages\2026-06-20_1200-gear-ascension"
$SNAPSHOT_FILE  = "$PKG_DIR\pre-deploy-snapshot.sql.gz"

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host " GEAR ASCENSION ROLLBACK" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "This will restore acore_world to the pre-deploy snapshot." -ForegroundColor Red
Write-Host "ALL writes to acore_world since the snapshot was taken will be LOST." -ForegroundColor Red
Write-Host ""
Write-Host "Snapshot: $SNAPSHOT_FILE"
Write-Host ""

# ============================================================
# Guard: snapshot must exist
# ============================================================
if (-not (Test-Path $SNAPSHOT_FILE)) {
    Write-Host "FAIL: Snapshot file not found: $SNAPSHOT_FILE" -ForegroundColor Red
    Write-Host "      Without the snapshot, this rollback script cannot proceed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual rollback option: apply the reverse-SQL below to acore_world:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  -- Remove tier copies"
    Write-Host "  DELETE FROM item_template_locale WHERE ID BETWEEN 300001 AND 345833 AND locale='ruRU';"
    Write-Host "  DELETE FROM item_template WHERE entry BETWEEN 300001 AND 345833;"
    Write-Host "  -- Remove kit items"
    Write-Host "  DELETE FROM item_template_locale WHERE ID BETWEEN 200000 AND 200020 AND locale='ruRU';"
    Write-Host "  DELETE FROM item_template WHERE entry BETWEEN 200000 AND 200020;"
    Write-Host "  -- Remove chain table (WARNING: drops entire table)"
    Write-Host "  DROP TABLE IF EXISTS item_upgrade_chain;"
    Write-Host "  -- Remove spell"
    Write-Host "  DELETE FROM spell_dbc WHERE ID = 105000;"
    Write-Host "  DELETE FROM spell_script_names WHERE spell_id = 105000;"
    Write-Host "  -- Remove IEC"
    Write-Host "  DELETE FROM itemextendedcost_dbc WHERE ID = 100008;"
    Write-Host "  -- Remove kit vendor rows"
    Write-Host "  DELETE FROM npc_vendor WHERE entry IN (190101,190102,190103)"
    Write-Host "    AND item BETWEEN 200000 AND 200020;"
    exit 1
}

$snapSizeMB = (Get-Item $SNAPSHOT_FILE).Length / 1MB
Write-Host ("Snapshot size: {0:F1} MB" -f $snapSizeMB)
Write-Host ""

# ============================================================
# Hard confirmation
# ============================================================
Write-Host "Type 'rollback' to confirm and proceed. Any other input aborts." -ForegroundColor Red
$confirm = Read-Host "Confirm rollback"
if ($confirm -ne "rollback") {
    Write-Host "Aborted — no changes made." -ForegroundColor Yellow
    exit 0
}

# ============================================================
# Stop live worldserver to prevent in-flight writes
# ============================================================
Write-Host ""
Write-Host "Stopping $WS_CONTAINER ..." -ForegroundColor Yellow
$wsRunning = docker inspect --format "{{.State.Running}}" $WS_CONTAINER 2>$null
if ($wsRunning -eq "true") {
    docker stop $WS_CONTAINER
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARN: Could not stop $WS_CONTAINER. Proceeding anyway — risk of in-flight write loss." -ForegroundColor Yellow
    } else {
        Write-Host "OK: $WS_CONTAINER stopped."
    }
} else {
    Write-Host "OK: $WS_CONTAINER is already stopped."
}

# ============================================================
# Drop and recreate acore_world, then restore snapshot
# ============================================================
Write-Host ""
Write-Host "Restoring $WORLD_DB from snapshot ..." -ForegroundColor Yellow
Write-Host "  This may take several minutes for a large database."

# Drop and recreate the DB to ensure a clean slate
docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS -e "DROP DATABASE IF EXISTS ``$WORLD_DB``; CREATE DATABASE ``$WORLD_DB`` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: Could not drop/recreate $WORLD_DB. Snapshot restore aborted." -ForegroundColor Red
    exit 1
}
Write-Host "  $WORLD_DB dropped and recreated."

# Stream gunzip -> mysql
$restoreCmd = "gzip -dc `"$SNAPSHOT_FILE`" | docker exec -i $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 $WORLD_DB"
$proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $restoreCmd" -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0) {
    Write-Host "FAIL: Snapshot restore command returned exit code $($proc.ExitCode)." -ForegroundColor Red
    Write-Host "      The database may be in an inconsistent state. Do not restart the worldserver." -ForegroundColor Red
    Write-Host "      Contact the DBA / check Docker logs for details." -ForegroundColor Red
    exit 1
}
Write-Host "OK: Snapshot restored." -ForegroundColor Green

# ============================================================
# Quick verification
# ============================================================
Write-Host ""
Write-Host "Verification (should all be 0 after rollback):"
$r1 = docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 -N -e "SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 300001 AND 345833" $WORLD_DB 2>$null
Write-Host "  item_template 300001-345833: $r1  (expected: 0)"
$r2 = docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 -N -e "SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 200000 AND 200020" $WORLD_DB 2>$null
Write-Host "  item_template 200000-200020: $r2  (expected: 0)"
$r3 = docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$WORLD_DB' AND table_name='item_upgrade_chain'" $WORLD_DB 2>$null
Write-Host "  item_upgrade_chain table:    $r3  (expected: 0)"
$r4 = docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 -N -e "SELECT COUNT(*) FROM spell_dbc WHERE ID = 105000" $WORLD_DB 2>$null
Write-Host "  spell_dbc 105000:            $r4  (expected: 0)"

# ============================================================
# Restart worldserver
# ============================================================
Write-Host ""
Write-Host "Restarting $WS_CONTAINER ..." -ForegroundColor Yellow
Write-Host "NOTE: If the new image has mod-gear-ascension compiled in, it will look for"
Write-Host "      item_upgrade_chain which no longer exists. Deploy the OLD worldserver image"
Write-Host "      before restarting, or the server may crash on startup." -ForegroundColor Yellow
Write-Host ""

$restartReply = Read-Host "Start $WS_CONTAINER now? (yes/no)"
if ($restartReply -eq "yes") {
    Set-Location $REPO_ROOT
    docker compose up -d ac-worldserver
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARN: docker compose up failed. Start the container manually." -ForegroundColor Yellow
    } else {
        Start-Sleep -Seconds 8
        $wsStatus = docker inspect --format "{{.State.Running}}" $WS_CONTAINER 2>$null
        Write-Host "  Container running: $wsStatus"
        Write-Host "OK: $WS_CONTAINER started." -ForegroundColor Green
    }
} else {
    Write-Host "Skipped worldserver start — start it manually when the image issue is resolved."
}

# ============================================================
# Done
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Rollback complete." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  acore_world restored to pre-Gear-Ascension state."
Write-Host "  Please update the manifest.md in this package with the rollback reason:"
Write-Host "    $PKG_DIR\manifest.md"
Write-Host ""
Write-Host "  Do NOT reapply the same SQL until the root cause is understood."
Write-Host "  Report the rollback to the agent so deployments.log can be updated."
