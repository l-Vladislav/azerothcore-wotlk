# =============================================================================
# rollback.ps1 — Restore acore_characters from pre-deploy snapshot
# =============================================================================
# USE WHEN:  apply.ps1 failed, or smoke test reveals a breaking issue.
# EFFECT:    Drops and restores acore_characters from the gz snapshot taken
#            by apply.ps1 before any SQL was applied.
# NOTE:      The two new tables (mod_ollama_chat_memory, mod_ollama_chat_bot_journal)
#            are empty at deploy time. Rolling back incurs zero data loss for those.
#            The personality_templates REPLACE INTO is also reversible; the prior
#            rows were identical anyway (guarded column already existed).
# RUN AS:    Human operator from anywhere.
#            pwsh .claude/agent-memory/live-deployer/packages/2026-06-25_1200-mod-ollama-chat-phase3/rollback.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

$PackageDir   = "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk\.claude\agent-memory\live-deployer\packages\2026-06-25_1200-mod-ollama-chat-phase3"
$Container    = "ac-database-v2"
$DB           = "acore_characters"
$MySQLRoot    = "root"
$MySQLPass    = "password"
$SnapshotFile = "$PackageDir\pre-deploy-snapshot.sql.gz"

Write-Host ""
Write-Host "============================================================"
Write-Host "  ROLLBACK — Restoring $DB from pre-deploy snapshot"
Write-Host "============================================================"
Write-Host ""

# Confirm snapshot exists
if (-not (Test-Path $SnapshotFile)) {
    Write-Error "Snapshot not found: $SnapshotFile"
    Write-Host "Cannot rollback without snapshot. Manual intervention required."
    exit 1
}
$sizeKB = [math]::Round((Get-Item $SnapshotFile).Length / 1KB, 1)
Write-Host "Snapshot found: $sizeKB KB"
Write-Host ""

# Confirm container running
$status = docker inspect --format "{{.State.Status}}" $Container 2>$null
if ($status -ne "running") {
    Write-Error "Container $Container is not running (status: $status). Cannot rollback."
    exit 1
}

# Confirmation prompt
Write-Host "WARNING: This will DROP and recreate $DB from snapshot."
Write-Host "All changes made after the snapshot will be LOST."
Write-Host ""
$confirm = Read-Host "Type YES to proceed with rollback"
if ($confirm -ne "YES") {
    Write-Host "Rollback cancelled."
    exit 0
}

Write-Host ""
Write-Host "[STEP 1] Stopping ac-worldserver-v2 if running..."
$wsStatus = docker inspect --format "{{.State.Status}}" ac-worldserver-v2 2>$null
if ($wsStatus -eq "running") {
    Write-Host "  Stopping ac-worldserver-v2..."
    docker stop ac-worldserver-v2
    Write-Host "  OK  Stopped."
} else {
    Write-Host "  INFO  ac-worldserver-v2 is not running, skipping stop."
}

Write-Host ""
Write-Host "[STEP 2] Dropping and recreating $DB..."
docker exec $Container mysql -u$MySQLRoot -p$MySQLPass -e "DROP DATABASE IF EXISTS ``$DB``; CREATE DATABASE ``$DB`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to drop/create database. Manual intervention required."
    exit 1
}
Write-Host "  OK  Database recreated."

Write-Host ""
Write-Host "[STEP 3] Restoring from snapshot (this may take a minute)..."
# Decompress snapshot to a temp SQL file, copy into container, apply
$tempSql = "$PackageDir\rollback-restore-temp.sql"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$inStream  = [System.IO.File]::OpenRead($SnapshotFile)
$gzStream  = [System.IO.Compression.GZipStream]::new($inStream, [System.IO.Compression.CompressionMode]::Decompress)
$outStream = [System.IO.File]::Create($tempSql)
$gzStream.CopyTo($outStream)
$outStream.Close(); $gzStream.Close(); $inStream.Close()

docker cp $tempSql "${Container}:/tmp/rollback-restore.sql" 2>&1 | Out-Null
docker exec $Container bash -c "mysql -u$MySQLRoot -p$MySQLPass --default-character-set=utf8mb4 $DB < /tmp/rollback-restore.sql && rm -f /tmp/rollback-restore.sql" 2>&1 | Out-Null
Remove-Item $tempSql -Force -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Error "Restore failed. Database may be in partial state. Inspect manually."
    exit 1
}
Write-Host "  OK  Restore complete."

Write-Host ""
Write-Host "[STEP 4] Verify row count sanity check..."
$count = docker exec $Container mysql -u$MySQLRoot -p$MySQLPass $DB -se "SELECT COUNT(*) FROM characters;" 2>&1
Write-Host "  characters table row count: $count"

Write-Host ""
Write-Host "============================================================"
Write-Host "  ROLLBACK COMPLETE"
Write-Host "============================================================"
Write-Host ""
Write-Host "acore_characters has been restored to pre-deploy state."
Write-Host "The new tables (mod_ollama_chat_memory, mod_ollama_chat_bot_journal)"
Write-Host "will not be present. Revert the config edit manually if needed."
Write-Host ""
Write-Host "To restart the worldserver after rollback:"
Write-Host "  docker compose up -d ac-worldserver"
Write-Host ""
