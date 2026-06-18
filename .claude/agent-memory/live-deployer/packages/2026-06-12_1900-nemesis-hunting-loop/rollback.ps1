#Requires -Version 5.1
<#
.SYNOPSIS
    Rollback: Nemesis Hunting Loop v2 -> revert live server to pre-deploy state.
    Package: 2026-06-12_1900-nemesis-hunting-loop

.DESCRIPTION
    Human-run script. Restores live databases from the pre-deploy backup taken at
    2026-06-12_175354, reverts the module to commit a49fde7, and removes the
    appended conf block.

    Steps:
      1  Stop live worldserver (ac-worldserver-v2)
      2  Restore acore_world and acore_characters from backup dumps
      3  Rebuild live image from previous module commit (a49fde7)
      4  Remove appended HUNTING LOOP v2 conf block from mod_nemesis_system.conf
      5  Restart live worldserver

    acore_auth is NOT restored (auth DB was unchanged by this deploy).

.NOTES
    Agent permission policy: this script is USER-RUN, NOT agent-run.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$REPO_ROOT    = "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk"
$DB_CONTAINER = "ac-database-v2"
$WS_CONTAINER = "ac-worldserver-v2"
$DB_USER      = "root"
$DB_PASS      = if ($env:DOCKER_DB_ROOT_PASSWORD) { $env:DOCKER_DB_ROOT_PASSWORD } else { "password" }
$BACKUP_DIR   = "$REPO_ROOT\backups\live\2026-06-12_175354_pre-hunting-loop-deploy"
$CONF_FILE    = "$REPO_ROOT\env\dist\etc\modules\mod_nemesis_system.conf"
$PREV_COMMIT  = "a49fde7"
$MODULE_DIR   = "$REPO_ROOT\modules\mod-nemesis-system"

function Confirm-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $reply = Read-Host "Continue? (yes/abort)"
    if ($reply -ne "yes") { Write-Host "Aborted." -ForegroundColor Red; exit 1 }
}

Write-Host "========================================" -ForegroundColor Red
Write-Host " ROLLBACK: Nemesis Hunting Loop v2" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host "  This will restore live DBs to pre-deploy state."
Write-Host "  All DB changes from this deploy will be LOST."
Write-Host "  Character data (special task rows) in acore_characters will be LOST."
Write-Host ""

# Verify backup exists
if (-not (Test-Path "$BACKUP_DIR\acore_world.sql")) {
    Write-Host "FAIL: Backup not found at $BACKUP_DIR" -ForegroundColor Red
    Write-Host "      Cannot proceed with rollback." -ForegroundColor Red
    exit 1
}
Write-Host "Backup found: $BACKUP_DIR"
$worldSize  = [math]::Round((Get-Item "$BACKUP_DIR\acore_world.sql").Length / 1MB, 1)
$charsSize  = [math]::Round((Get-Item "$BACKUP_DIR\acore_characters.sql").Length / 1MB, 1)
Write-Host "  acore_world.sql: $worldSize MB"
Write-Host "  acore_characters.sql: $charsSize MB"

# ============================================================
# STEP 1: Stop live worldserver
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 1: Stop live worldserver" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Confirm-Step "Stop ac-worldserver-v2 now?"
docker stop $WS_CONTAINER 2>$null
Write-Host "OK: $WS_CONTAINER stopped." -ForegroundColor Green

# ============================================================
# STEP 2: Restore acore_world from backup
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 2: Restore acore_world ($worldSize MB)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Confirm-Step "Restore acore_world from $BACKUP_DIR\acore_world.sql? ALL hunting-loop data will be REMOVED."
Write-Host "Restoring acore_world... (this may take several minutes)" -ForegroundColor Yellow
docker exec -i $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 acore_world 2>$null < "$BACKUP_DIR\acore_world.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: acore_world restore failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: acore_world restored." -ForegroundColor Green

# ============================================================
# STEP 3: Restore acore_characters from backup
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 3: Restore acore_characters ($charsSize MB)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Confirm-Step "Restore acore_characters from backup? character_nemesis_special_task data will be LOST."
Write-Host "Restoring acore_characters... (this may take several minutes)" -ForegroundColor Yellow
docker exec -i $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 acore_characters 2>$null < "$BACKUP_DIR\acore_characters.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: acore_characters restore failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: acore_characters restored." -ForegroundColor Green

# ============================================================
# STEP 4: Rebuild live image from previous module commit
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 4: Rebuild live image from commit $PREV_COMMIT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  This checks out the previous module commit and rebuilds the image."
Write-Host "  Previous commit: $PREV_COMMIT (fix(Dungeon): HP self-heal, presence debounce...)"
Write-Host ""
Write-Host "  IMPORTANT: After rollback completes, restore the module to the feature branch:"
Write-Host "    git -C modules/mod-nemesis-system checkout feat/wow-ak-1-nemesis-familiars"

Confirm-Step "Checkout $PREV_COMMIT in mod-nemesis-system and rebuild image?"
git -C $MODULE_DIR checkout $PREV_COMMIT
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: git checkout $PREV_COMMIT failed." -ForegroundColor Red
    exit 1
}
Write-Host "Module checked out at $PREV_COMMIT"

Set-Location $REPO_ROOT
docker compose build ac-worldserver
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: docker compose build ac-worldserver failed." -ForegroundColor Red
    Write-Host "Module is checked out at $PREV_COMMIT. Fix the build issue before restarting." -ForegroundColor Red
    exit 1
}
Write-Host "OK: Image rebuilt from $PREV_COMMIT." -ForegroundColor Green

# ============================================================
# STEP 5: Remove appended conf block
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 5: Remove hunting-loop conf block" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$confContent = Get-Content $CONF_FILE -Raw
if ($confContent -match "HUNTING LOOP v2") {
    Confirm-Step "Remove '# --- HUNTING LOOP v2 ...' block from mod_nemesis_system.conf?"
    # Find the line index of the marker and keep everything before it
    $lines = Get-Content $CONF_FILE
    $cutIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "HUNTING LOOP v2") {
            # Remove the blank line immediately before the marker too
            $cutIndex = if ($i -gt 0 -and $lines[$i-1].Trim() -eq "") { $i - 1 } else { $i }
            break
        }
    }
    if ($cutIndex -ge 0) {
        $trimmed = $lines[0..($cutIndex-1)]
        $trimmed | Set-Content $CONF_FILE -Encoding UTF8
        Write-Host "OK: Conf block removed ($($lines.Count - $cutIndex) lines removed)." -ForegroundColor Green
    } else {
        Write-Host "WARN: Could not find cut point. Edit $CONF_FILE manually." -ForegroundColor Yellow
    }
} else {
    Write-Host "Conf block not found — already clean or was never applied." -ForegroundColor Yellow
}

# ============================================================
# STEP 6: Restart live worldserver
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 6: Restart live worldserver" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Confirm-Step "Start ac-worldserver-v2 with rolled-back image?"
Set-Location $REPO_ROOT
docker compose up -d ac-worldserver
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: docker compose up -d ac-worldserver failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: ac-worldserver-v2 started." -ForegroundColor Green

# ============================================================
# Cleanup reminder
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Rollback complete." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT POST-ROLLBACK STEPS:" -ForegroundColor Yellow
Write-Host "  1. Restore module branch:"
Write-Host "     git -C modules/mod-nemesis-system checkout feat/wow-ak-1-nemesis-familiars"
Write-Host ""
Write-Host "  2. Verify live is healthy (check Server.log for startup errors)"
Write-Host ""
Write-Host "  3. Document the failure reason in the package manifest:"
Write-Host "     $REPO_ROOT\.claude\agent-memory\live-deployer\packages\2026-06-12_1900-nemesis-hunting-loop\manifest.md"
Write-Host ""
Write-Host "  4. Report findings to the agent so it can capture lessons."
