#Requires -Version 5.1
<#
.SYNOPSIS
    Rollback: mod-environmental-effects v2 -> revert live server to pre-deploy state.
    Package: 2026-06-22_1200-mod-env-effects-v2

.DESCRIPTION
    Human-run script. Reverts the env-effects v2 deploy from production.

    This script:
      1  Reads the snapshot path written by apply.ps1 (snapshot_path.txt in package dir)
      2  Stops live worldserver
      3  Restores acore_world from pre-deploy snapshot
      4  Removes env-effects rows surgically (if snapshot restore is skipped)
      5  Removes TZ from docker-compose.override.yml (restores from .bak)
      6  Removes mod_environmental_effects.conf from live etc/modules/
      7  Reverts the git merge on custom
      8  Rebuilds live worldserver image (now without the module)
      9  Restarts live worldserver

    acore_auth and acore_characters are NOT touched (unchanged by this deploy).

    IMPORTANT: Snapshot restore (Step 3) is the safest rollback. The surgical DB
    removal in Step 4 is offered only if you skip the snapshot restore — it removes
    only env-effects data and leaves all other live data intact.

.NOTES
    Agent permission policy: this script is USER-RUN, NOT agent-run.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$REPO_ROOT       = "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk"
$DB_CONTAINER    = "ac-database-v2"
$WS_CONTAINER    = "ac-worldserver-v2"
$DB_USER         = "root"
$DB_PASS         = if ($env:DOCKER_DB_ROOT_PASSWORD) { $env:DOCKER_DB_ROOT_PASSWORD } else { "password" }
$WORLD_DB        = "acore_world"

$PKG_DIR         = "$REPO_ROOT\.claude\agent-memory\live-deployer\packages\2026-06-22_1200-mod-env-effects-v2"
$CONF_LIVE       = "$REPO_ROOT\env\dist\etc\modules\mod_environmental_effects.conf"
$COMPOSE_OVERRIDE = "$REPO_ROOT\docker-compose.override.yml"
$COMPOSE_BAK     = "$PKG_DIR\docker-compose.override.yml.bak"
$SNAPSHOT_PATH_FILE = "$PKG_DIR\snapshot_path.txt"
$FEATURE_BRANCH  = "feat/wow-ak-1-env-effects"

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
function Confirm-Step {
    param([string]$Message, [switch]$SkipAllowed)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    if ($SkipAllowed) {
        $reply = Read-Host "Continue? (yes/skip/abort)"
    } else {
        $reply = Read-Host "Continue? (yes/abort)"
    }
    if ($reply -eq "abort") { Write-Host "Aborted." -ForegroundColor Red; exit 1 }
    return ($reply -eq "yes")
}

function Invoke-LiveQuery {
    param([string]$Query)
    docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 -N -e $Query $WORLD_DB 2>$null
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Host "========================================" -ForegroundColor Red
Write-Host " ROLLBACK: mod-environmental-effects v2" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "This will revert the env-effects v2 deploy from production."
Write-Host "acore_world will be restored to pre-deploy state."
Write-Host "The git merge of $FEATURE_BRANCH into custom will be reverted."
Write-Host ""

# Read snapshot path
$SNAPSHOT_DIR = $null
if (Test-Path $SNAPSHOT_PATH_FILE) {
    $SNAPSHOT_DIR = (Get-Content $SNAPSHOT_PATH_FILE -Raw).Trim()
    Write-Host "Snapshot path (from apply.ps1): $SNAPSHOT_DIR"
    if (-not (Test-Path "$SNAPSHOT_DIR\acore_world.sql")) {
        Write-Host "WARN: Snapshot file not found at expected path ($SNAPSHOT_DIR\acore_world.sql)." -ForegroundColor Yellow
        Write-Host "      Snapshot restore will not be available. Surgical removal will be offered instead." -ForegroundColor Yellow
        $SNAPSHOT_DIR = $null
    } else {
        $snapSize = [math]::Round((Get-Item "$SNAPSHOT_DIR\acore_world.sql").Length / 1MB, 1)
        Write-Host "Snapshot size: $snapSize MB"
    }
} else {
    Write-Host "WARN: snapshot_path.txt not found. Snapshot was not taken by apply.ps1 or was skipped." -ForegroundColor Yellow
    Write-Host "      Surgical DB removal will be offered instead of full restore." -ForegroundColor Yellow
}
Write-Host ""

# ============================================================
# STEP 1: Stop live worldserver
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 1: Stop live worldserver" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Confirm-Step "Stop $WS_CONTAINER now?"
docker stop $WS_CONTAINER 2>$null
Write-Host "OK: $WS_CONTAINER stopped." -ForegroundColor Green

# ============================================================
# STEP 2: Restore acore_world (snapshot) OR surgical removal
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 2: Revert acore_world DB changes" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($SNAPSHOT_DIR) {
    Write-Host "  Option A (RECOMMENDED): Restore full acore_world from snapshot."
    Write-Host "  Snapshot: $SNAPSHOT_DIR\acore_world.sql"
    Write-Host "  This is the safest rollback — guaranteed to return to pre-deploy state."
    Write-Host ""
    Write-Host "  Option B: Surgical removal only (skip snapshot restore, type 'skip')."
    Write-Host "  Removes only env-effects rows; leaves all other live data intact."
    Write-Host "  Use if a full restore would also lose other changes applied AFTER this deploy."
    Write-Host ""

    $choice = Confirm-Step "Restore full acore_world snapshot? (yes = full restore, skip = surgical only)" -SkipAllowed

    if ($choice) {
        Write-Host "Restoring acore_world... (this may take several minutes)" -ForegroundColor Yellow
        docker exec -i $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 $WORLD_DB 2>$null < "$SNAPSHOT_DIR\acore_world.sql"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAIL: acore_world restore failed." -ForegroundColor Red
            exit 1
        }
        Write-Host "OK: acore_world restored from snapshot." -ForegroundColor Green
        $SURGICAL = $false
    } else {
        Write-Host "Skipped snapshot restore. Proceeding with surgical removal." -ForegroundColor Yellow
        $SURGICAL = $true
    }
} else {
    Write-Host "No snapshot available. Performing surgical DB removal." -ForegroundColor Yellow
    $SURGICAL = $true
}

if ($SURGICAL) {
    Write-Host ""
    Write-Host "Surgical removal:"
    Write-Host "  DELETE spell_dbc WHERE ID BETWEEN 107000 AND 107199"
    Write-Host "  DELETE spell_dbc WHERE ID BETWEEN 107500 AND 107599"
    Write-Host "  DELETE spell_dbc WHERE ID = 108500"
    Write-Host "  DROP TABLE IF EXISTS mod_environmental_effects"
    Write-Host "  DELETE game_weather WHERE zone IN (8,40,130,331,3519,495)"
    Write-Host ""

    Confirm-Step "Execute surgical removal of env-effects data from $WORLD_DB?"

    $queries = @(
        "DELETE FROM spell_dbc WHERE ID BETWEEN 107000 AND 107199",
        "DELETE FROM spell_dbc WHERE ID BETWEEN 107500 AND 107599",
        "DELETE FROM spell_dbc WHERE ID = 108500",
        "DROP TABLE IF EXISTS mod_environmental_effects",
        "DELETE FROM game_weather WHERE zone IN (8,40,130,331,3519,495)"
    )
    foreach ($q in $queries) {
        Write-Host "  Executing: $q" -NoNewline
        docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 -e $q $WORLD_DB 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host " FAILED" -ForegroundColor Red
            throw "Query failed: $q"
        }
        Write-Host " OK" -ForegroundColor Green
    }

    # Verify
    $spellsRemain = Invoke-LiveQuery -Query "SELECT COUNT(*) FROM spell_dbc WHERE ID BETWEEN 107000 AND 107199"
    Write-Host "  spell_dbc 107000-107199 remaining: $spellsRemain (expected: 0)"
    $tableExists = Invoke-LiveQuery -Query "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='acore_world' AND TABLE_NAME='mod_environmental_effects'"
    Write-Host "  mod_environmental_effects table: $tableExists (expected: 0)"
    Write-Host "OK: Surgical removal complete." -ForegroundColor Green
}

# ============================================================
# STEP 3: Restore docker-compose.override.yml
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 3: Restore docker-compose.override.yml" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (Test-Path $COMPOSE_BAK) {
    Confirm-Step "Restore docker-compose.override.yml from backup ($COMPOSE_BAK)?"
    Copy-Item $COMPOSE_BAK $COMPOSE_OVERRIDE -Force
    Write-Host "OK: docker-compose.override.yml restored from backup." -ForegroundColor Green
} else {
    Write-Host "WARN: Backup $COMPOSE_BAK not found." -ForegroundColor Yellow
    Write-Host "      TZ: Europe/Moscow may not have been added (apply.ps1 skipped that step)," -ForegroundColor Yellow
    Write-Host "      or the backup was not created. Skipping." -ForegroundColor Yellow
}

# ============================================================
# STEP 4: Remove live module conf
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 4: Remove live module conf" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (Test-Path $CONF_LIVE) {
    Confirm-Step "Delete $CONF_LIVE?"
    Remove-Item $CONF_LIVE -Force
    Write-Host "OK: $CONF_LIVE removed." -ForegroundColor Green
} else {
    Write-Host "OK: $CONF_LIVE does not exist (already removed or was never created)." -ForegroundColor Green
}

# ============================================================
# STEP 5: Revert git merge
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 5: Revert git merge of $FEATURE_BRANCH" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Find the merge commit (first commit on custom after the merge)
$mergeCommit = git -C $REPO_ROOT log --merges --oneline -1 custom 2>$null
Write-Host "  Most recent merge commit on custom: $mergeCommit"
Write-Host ""
Write-Host "  If that merge commit is the env-effects merge, run:"
Write-Host "    git -C $REPO_ROOT revert -m 1 <merge-commit-hash>"
Write-Host ""
Write-Host "  Alternatively, if the merge was the last operation on custom and you"
Write-Host "  want a hard reset:"
Write-Host "    git -C $REPO_ROOT reset --hard custom@{1}"
Write-Host "  WARNING: git reset --hard discards history. Use revert for safety."
Write-Host ""
Write-Host "  This step is NOT automated because the correct action depends on"
Write-Host "  whether other commits have landed on custom after the merge."
Write-Host "  Please perform it manually, then proceed with the rebuild."
Write-Host ""
Write-Host "  After reverting, verify:"
Write-Host "    git -C $REPO_ROOT log --oneline custom | head -5"
Write-Host "    (The env-effects merge commit should not appear at the top)"

Read-Host "Press Enter when git revert/reset is complete (or to continue without it)"

# ============================================================
# STEP 6: Rebuild live worldserver image (without the module)
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 6: Rebuild live worldserver image" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  This rebuilds without mod-environmental-effects (module is gone from custom)."
Write-Host "  GetWeatherState() will return to private after the revert."

if (Confirm-Step "Run: docker compose build ac-worldserver?") {
    Set-Location $REPO_ROOT
    docker compose build ac-worldserver
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: docker compose build ac-worldserver failed." -ForegroundColor Red
        Write-Host "      Fix the build issue before restarting the server." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: Image rebuilt (env-effects module removed)." -ForegroundColor Green
}

# ============================================================
# STEP 7: Restart live worldserver
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 7: Restart live worldserver" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Confirm-Step "Start $WS_CONTAINER with rolled-back image?"
Set-Location $REPO_ROOT
docker compose up -d ac-worldserver
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: docker compose up -d ac-worldserver failed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: $WS_CONTAINER started." -ForegroundColor Green

# ============================================================
# Done
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Rollback complete." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "POST-ROLLBACK CHECKLIST:" -ForegroundColor Yellow
Write-Host "  1. Verify server log shows no mod-environmental-effects references."
Write-Host "     docker logs $WS_CONTAINER 2>&1 | Select-String 'environmental'"
Write-Host ""
Write-Host "  2. Verify env-effects rules are gone from DB:"
Write-Host "     docker exec $DB_CONTAINER mysql -u$DB_USER -p$DB_PASS -N -e 'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=``acore_world`` AND TABLE_NAME=``mod_environmental_effects``' acore_world"
Write-Host "     Expected: 0"
Write-Host ""
Write-Host "  3. Document the failure reason in the manifest:"
Write-Host "     $PKG_DIR\manifest.md"
Write-Host ""
Write-Host "  4. Report findings to the agent so lessons can be captured."
