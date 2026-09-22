#Requires -Version 5.1
<#
.SYNOPSIS
    Apply: mod-gear-ascension Phase 3 (Crafted + Set items) -> live acore_world
    Package: 2026-06-21_0900-gear-ascension-phase3

.DESCRIPTION
    Human-run script. Applies gear_ascension_extra.sql to production acore_world.
    No writes occur until explicit confirmation prompts are answered.

    Apply order:
      Step 1  Pre-flight safety checks
      Step 2  Snapshot: mysqldump acore_world -> pre-deploy-snapshot.sql.gz
      Step 3  Apply gear_ascension_extra.sql via file-redirect (NOT inline -e)
      Step 4  Post-apply verification queries
      Step 5  Prompt: restart ac-worldserver-v2 now? (human decision)

    No C++ rebuild needed (pure data migration).
    No conf file changes needed.
    Item.dbc is already deployed to the shared volume.

    Safe to run while worldserver is up (Steps 1-4 are read/write to DB only).
    Step 5 is the only service interruption.

.NOTES
    Agent permission policy: this script is USER-RUN, NOT agent-run.
    The agent prepared this package but does not execute it.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Config ---
$REPO_ROOT    = "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk"
$DB_CONTAINER = "ac-database-v2"
$WS_CONTAINER = "ac-worldserver-v2"
$DB_USER      = "root"
$DB_PASS      = if ($env:DOCKER_DB_ROOT_PASSWORD) { $env:DOCKER_DB_ROOT_PASSWORD } else { "password" }
$WORLD_DB     = "acore_world"

$PKG_DIR      = "$REPO_ROOT\.claude\agent-memory\live-deployer\packages\2026-06-21_0900-gear-ascension-phase3"
$SQL_FILE     = "$REPO_ROOT\data\sql\updates\pending_db_world\gear_ascension_extra.sql"
$SNAPSHOT_GZ  = "$PKG_DIR\pre-deploy-snapshot.sql.gz"

# --- Helper functions ---
function Confirm-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $reply = Read-Host "Continue? (yes/skip/abort)"
    if ($reply -eq "abort") { Write-Host "Aborted by user." -ForegroundColor Red; exit 1 }
    return ($reply -eq "yes")
}

function Invoke-LiveQuery {
    param([string]$Database, [string]$Query)
    docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 -N -e $Query $Database 2>$null
}

# ============================================================
# STEP 1: Pre-flight checks
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 1: Pre-flight checks" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check DB container is running
$dbStatus = docker inspect --format "{{.State.Running}}" $DB_CONTAINER 2>$null
if ($dbStatus -ne "true") {
    Write-Host "FAIL: DB container '$DB_CONTAINER' is not running." -ForegroundColor Red
    exit 1
}
Write-Host "OK: DB container '$DB_CONTAINER' is running."

# Check SQL file exists
if (-not (Test-Path $SQL_FILE)) {
    Write-Host "FAIL: SQL file not found: $SQL_FILE" -ForegroundColor Red
    exit 1
}
$sqlSize = [math]::Round((Get-Item $SQL_FILE).Length / 1KB, 0)
Write-Host "OK: SQL file present ($sqlSize KB): $(Split-Path $SQL_FILE -Leaf)"

# Forbidden DDL scan (belt-and-suspenders — was clean at package generation)
$forbidden = Select-String -Path $SQL_FILE -Pattern "DROP DATABASE|TRUNCATE TABLE|DROP TABLE|mysql_install_db" -Quiet
if ($forbidden) {
    Write-Host "FAIL: Forbidden DDL pattern detected in SQL file. Manual review required." -ForegroundColor Red
    exit 1
}
Write-Host "OK: No forbidden DDL patterns found."

# Check if already applied (re-run guard)
$existingCount = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 345841 AND 356762"
if ([int]$existingCount -gt 0) {
    Write-Host "WARN: $existingCount rows already exist in item_template for entries 345841-356762." -ForegroundColor Yellow
    Write-Host "      SQL is idempotent (DELETE-before-INSERT). Re-applying will overwrite with identical values." -ForegroundColor Yellow
    Write-Host "      This is safe. Proceeding." -ForegroundColor Yellow
} else {
    Write-Host "OK: No existing rows in range 345841-356762 (clean first apply)."
}

# Report current live chain count
$currentChain = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_upgrade_chain"
Write-Host "INFO: Current item_upgrade_chain count on live: $currentChain (expected 8480 for first apply)"

# Check worldserver status (informational)
$wsRunning = docker inspect --format "{{.State.Running}}" $WS_CONTAINER 2>$null
if ($wsRunning -eq "true") {
    Write-Host "INFO: Live worldserver '$WS_CONTAINER' is running. SQL apply is safe while it is up."
} else {
    Write-Host "INFO: Live worldserver '$WS_CONTAINER' is stopped."
}

Write-Host ""
Write-Host "Pre-flight checks passed." -ForegroundColor Green

# ============================================================
# STEP 2: Snapshot live acore_world
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 2: Snapshot acore_world" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Output: $SNAPSHOT_GZ"
Write-Host "  This dumps the full acore_world database (may take 3-8 minutes)."
Write-Host "  The snapshot is used by rollback.ps1 if needed."
Write-Host ""

if (Test-Path $SNAPSHOT_GZ) {
    $snapAge = (Get-Date) - (Get-Item $SNAPSHOT_GZ).LastWriteTime
    Write-Host "WARN: Snapshot already exists (age: $([math]::Round($snapAge.TotalMinutes, 0)) minutes)." -ForegroundColor Yellow
    Write-Host "      It will be overwritten with a fresh dump." -ForegroundColor Yellow
}

if (Confirm-Step "Take pre-deploy snapshot of acore_world now?") {
    Write-Host "Dumping acore_world to $SNAPSHOT_GZ ..." -ForegroundColor Yellow
    $dumpCmd = "docker exec $DB_CONTAINER mysqldump -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 --single-transaction --quick $WORLD_DB"
    Invoke-Expression "$dumpCmd" | gzip > $SNAPSHOT_GZ
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $SNAPSHOT_GZ)) {
        Write-Host "FAIL: Snapshot failed (exit $LASTEXITCODE). Do not proceed without a snapshot." -ForegroundColor Red
        exit 1
    }
    $snapSizeMB = [math]::Round((Get-Item $SNAPSHOT_GZ).Length / 1MB, 1)
    Write-Host "OK: Snapshot written ($snapSizeMB MB)." -ForegroundColor Green
} else {
    Write-Host "WARN: Snapshot skipped by user. Rollback via rollback.ps1 will use surgical DELETE instead of snapshot restore." -ForegroundColor Yellow
}

# ============================================================
# STEP 3: Apply gear_ascension_extra.sql
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 3: Apply gear_ascension_extra.sql" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  File:     $(Split-Path $SQL_FILE -Leaf)"
Write-Host "  Target:   $WORLD_DB on $DB_CONTAINER"
Write-Host "  Size:     $sqlSize KB (52792 lines)"
Write-Host "  Content:  1726 item_template copies + 1726 item_upgrade_chain rows + 1726 locale rows"
Write-Host "  Entries:  345841-356762 (CRAFT 639 bases + SET 454 bases)"
Write-Host "  Method:   file-redirect (docker exec -i), NOT inline -e"
Write-Host "  Time est: 2-5 minutes"
Write-Host ""

if (Confirm-Step "Apply gear_ascension_extra.sql to $WORLD_DB?") {
    Write-Host "Applying... (this may take several minutes)" -ForegroundColor Yellow
    $startTime = Get-Date
    docker exec -i $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 $WORLD_DB 2>$null < $SQL_FILE
    $exitCode = $LASTEXITCODE
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)

    if ($exitCode -ne 0) {
        Write-Host "FAIL: SQL apply exited with code $exitCode (elapsed: ${elapsed}s)." -ForegroundColor Red
        Write-Host "      Check MySQL error output. The DB may be in a partial state." -ForegroundColor Red
        Write-Host "      Run rollback.ps1 to restore from snapshot." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: SQL apply completed in ${elapsed}s." -ForegroundColor Green
} else {
    Write-Host "SQL apply skipped by user. Exiting." -ForegroundColor Yellow
    exit 0
}

# ============================================================
# STEP 4: Post-apply verification queries
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 4: Post-apply verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$chainCount  = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_upgrade_chain"
$newCopies   = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 345841 AND 356762"
$newLocales  = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_template_locale WHERE ID BETWEEN 345841 AND 356762"
$brokenChain = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_upgrade_chain iuc WHERE iuc.next_entry != 0 AND NOT EXISTS (SELECT 1 FROM item_template it WHERE it.entry = iuc.next_entry)"
$spot1       = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT CONCAT(entry,'|',name,'|Q',Quality) FROM item_template WHERE entry = 345841"
$spot2       = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT CONCAT(entry,'|',name,'|Q',Quality) FROM item_template WHERE entry = 356762"

Write-Host ""
Write-Host "  item_upgrade_chain total:       $chainCount  (expected: 10206)"
Write-Host "  item_template new copies:       $newCopies  (expected: 1726)"
Write-Host "  item_template_locale new rows:  $newLocales  (expected: 1726)"
Write-Host "  Broken chain pointers:          $brokenChain  (expected: 0)"
Write-Host "  Spot entry 345841:              $spot1"
Write-Host "  Spot entry 356762:              $spot2"
Write-Host ""

$ok = $true
if ([int]$chainCount  -ne 10206) { Write-Host "  WARN: chain count mismatch (got $chainCount, expected 10206)" -ForegroundColor Yellow; $ok = $false }
if ([int]$newCopies   -ne 1726)  { Write-Host "  WARN: copy count mismatch (got $newCopies, expected 1726)"   -ForegroundColor Yellow; $ok = $false }
if ([int]$newLocales  -ne 1726)  { Write-Host "  WARN: locale count mismatch (got $newLocales, expected 1726)" -ForegroundColor Yellow; $ok = $false }
if ([int]$brokenChain -ne 0)     { Write-Host "  WARN: broken chain pointers detected ($brokenChain rows)"      -ForegroundColor Red;    $ok = $false }

if ($ok) {
    Write-Host "  All verification checks passed." -ForegroundColor Green
} else {
    Write-Host "  One or more checks did not match expected values." -ForegroundColor Yellow
    Write-Host "  Review the warnings above before proceeding to restart." -ForegroundColor Yellow
}

# ============================================================
# STEP 5: Restart live worldserver (HUMAN DECISION)
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 5: Restart live worldserver" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Container: $WS_CONTAINER"
Write-Host "  Command:   docker compose up -d ac-worldserver (in $REPO_ROOT)"
Write-Host ""
Write-Host "  The worldserver must restart to reload item_template from DB." -ForegroundColor White
Write-Host "  The patched Item.dbc (56465 records) is already on the shared volume." -ForegroundColor White
Write-Host "  After restart, log should show 'Loaded 56410 Item Templates' and 0 Item.dbc errors." -ForegroundColor White
Write-Host ""
Write-Host "  NOTE: This is the only player-visible interruption. Schedule for low-traffic window." -ForegroundColor Yellow
Write-Host ""

if (Confirm-Step "Restart ac-worldserver-v2 now? (yes to restart, skip to defer)") {
    Set-Location $REPO_ROOT
    docker compose up -d ac-worldserver
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: docker compose up -d ac-worldserver failed (exit $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "      DB changes are in place. Try manual restart:" -ForegroundColor Red
        Write-Host "      docker restart $WS_CONTAINER" -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: ac-worldserver-v2 restarted." -ForegroundColor Green
    Write-Host ""
    Write-Host "Waiting 15 seconds for startup..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    $wsStatus = docker inspect --format "{{.State.Running}}" $WS_CONTAINER 2>$null
    Write-Host "  Container running: $wsStatus"
    if ($wsStatus -ne "true") {
        Write-Host "WARN: Container does not appear to be running. Check docker logs $WS_CONTAINER" -ForegroundColor Red
    }
} else {
    Write-Host "Restart deferred. DB changes are live; worldserver will pick them up on next restart." -ForegroundColor Yellow
    Write-Host "Run when ready:  docker compose -f $REPO_ROOT\docker-compose.yml up -d ac-worldserver" -ForegroundColor Cyan
}

# ============================================================
# Done
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Apply complete." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Post-restart smoke checks:"
Write-Host "  1. Check docker logs $WS_CONTAINER for 'Loaded 56410 Item Templates'"
Write-Host "  2. Check docker logs $WS_CONTAINER for 0 Item.dbc errors"
Write-Host "  3. Run smoke queries from manifest.md"
Write-Host "  4. In-game: .reload all items  (GM command, forces a hot-reload if needed)"
Write-Host ""
Write-Host "If smoke tests pass, report success to the agent for deployment log update."
Write-Host "If anything fails: pwsh $PKG_DIR\rollback.ps1"
