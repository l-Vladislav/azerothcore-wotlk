#Requires -Version 5.1
<#
.SYNOPSIS
    Apply: mod-environmental-effects v2 -> live server
    Package: 2026-06-22_1200-mod-env-effects-v2

.DESCRIPTION
    Human-run script. Promotes mod-environmental-effects v2 to production.
    Performs no writes until explicit confirmation prompts are answered.

    Apply order:
      Step 1  Pre-flight safety checks
      Step 2  Snapshot acore_world (mysqldump)
      Step 3  Git merge feat/wow-ak-1-env-effects -> custom  (human confirms)
      Step 4  Apply 3 SQL files to acore_world
      Step 5  Add TZ: "Europe/Moscow" to live worldserver in docker-compose.override.yml
      Step 6  Create env/dist/etc/modules/mod_environmental_effects.conf
      Step 7  Rebuild live worldserver image (docker compose build ac-worldserver)
      Step 8  Restart live worldserver (docker compose up -d ac-worldserver)

    IMPORTANT:
      - Stop ac-worldserver-ptr before building to free WSL2 RAM.
      - The server can remain running during SQL Steps 4 (safe); it must stop/restart in Step 8.
      - Do NOT run while players are mid-combat in a critical encounter.

.NOTES
    Agent permission policy: this script is USER-RUN, NOT agent-run.
    The agent prepared this package but does not execute it.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
$REPO_ROOT       = "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk"
$DB_CONTAINER    = "ac-database-v2"
$WS_CONTAINER    = "ac-worldserver-v2"
$DB_USER         = "root"
$DB_PASS         = if ($env:DOCKER_DB_ROOT_PASSWORD) { $env:DOCKER_DB_ROOT_PASSWORD } else { "password" }
$WORLD_DB        = "acore_world"

$PKG_DIR         = "$REPO_ROOT\.claude\agent-memory\live-deployer\packages\2026-06-22_1200-mod-env-effects-v2"
$CONF_DIST       = "$REPO_ROOT\modules\mod-environmental-effects\conf\mod_environmental_effects.conf.dist"
$CONF_LIVE       = "$REPO_ROOT\env\dist\etc\modules\mod_environmental_effects.conf"
$COMPOSE_OVERRIDE = "$REPO_ROOT\docker-compose.override.yml"
$COMPOSE_BAK     = "$PKG_DIR\docker-compose.override.yml.bak"

$FEATURE_BRANCH  = "feat/wow-ak-1-env-effects"
$FEATURE_TIP     = "65918bc42"

# Snapshot directory (timestamped at run time)
$TS              = (Get-Date -Format "yyyy-MM-dd_HHmmss")
$SNAPSHOT_DIR    = "$REPO_ROOT\backups\live\${TS}_pre-env-effects-v2-deploy"

# SQL files in apply order (spells before seed, seed before weather)
$WORLD_SQL = @(
    "$REPO_ROOT\data\sql\updates\pending_db_world\mod_env_effects_v2_spells.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\mod_env_effects_v2_seed.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\mod_env_effects_game_weather.sql"
)

# ---------------------------------------------------------------------------
# Helper functions
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
    if ($reply -eq "abort") { Write-Host "Aborted by user." -ForegroundColor Red; exit 1 }
    return ($reply -eq "yes")
}

function Invoke-LiveQuery {
    param([string]$Database, [string]$Query)
    docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 -N -e $Query $Database 2>$null
}

function Apply-SqlFile {
    param([string]$Database, [string]$FilePath)
    $filename = Split-Path $FilePath -Leaf
    Write-Host "  Applying: $filename -> $Database ..." -NoNewline
    docker exec -i $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 $Database 2>$null < $FilePath
    if ($LASTEXITCODE -ne 0) {
        Write-Host " FAILED" -ForegroundColor Red
        throw "SQL apply failed for $filename"
    }
    Write-Host " OK" -ForegroundColor Green
}

# ============================================================
# STEP 1: Pre-flight checks
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 1: Pre-flight checks" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# DB container running?
$dbStatus = docker inspect --format "{{.State.Running}}" $DB_CONTAINER 2>$null
if ($dbStatus -ne "true") {
    Write-Host "FAIL: DB container '$DB_CONTAINER' is not running." -ForegroundColor Red
    exit 1
}
Write-Host "OK: DB container $DB_CONTAINER is running."

# All SQL files present?
foreach ($f in $WORLD_SQL) {
    if (-not (Test-Path $f)) {
        Write-Host "FAIL: SQL file missing: $f" -ForegroundColor Red
        exit 1
    }
}
Write-Host "OK: All 3 SQL files present."

# Conf dist present (needed for Step 6)?
if (-not (Test-Path $CONF_DIST)) {
    Write-Host "FAIL: Module conf.dist missing: $CONF_DIST" -ForegroundColor Red
    Write-Host "      Ensure modules/mod-environmental-effects is present and the git merge has been run." -ForegroundColor Red
    exit 1
}
Write-Host "OK: Module conf.dist present."

# Compose override file exists?
if (-not (Test-Path $COMPOSE_OVERRIDE)) {
    Write-Host "FAIL: docker-compose.override.yml not found at $COMPOSE_OVERRIDE" -ForegroundColor Red
    exit 1
}
Write-Host "OK: docker-compose.override.yml present."

# Check if TZ already set for live worldserver (re-run guard)
$overrideContent = Get-Content $COMPOSE_OVERRIDE -Raw
$tzAlreadySet = ($overrideContent -match 'TZ:\s*"Europe/Moscow"') -and
                ($overrideContent -match '(?s)ac-worldserver:.*?TZ:.*?ac-worldserver-ptr:')
if ($tzAlreadySet) {
    Write-Host "WARN: TZ: Europe/Moscow may already be set in ac-worldserver service. Will check in Step 5." -ForegroundColor Yellow
}

# Check live worldserver state
$wsRunning = docker inspect --format "{{.State.Running}}" $WS_CONTAINER 2>$null
if ($wsRunning -eq "true") {
    Write-Host "WARN: Live worldserver '$WS_CONTAINER' is currently running." -ForegroundColor Yellow
    Write-Host "      SQL applies are safe while server is up." -ForegroundColor Yellow
    Write-Host "      Steps 7-8 (build + restart) will stop it." -ForegroundColor Yellow
} else {
    Write-Host "OK: Live worldserver is stopped."
}

# Check if feature branch exists (we need it for merge)
$branchExists = git -C $REPO_ROOT rev-parse --verify $FEATURE_BRANCH 2>$null
if (-not $branchExists) {
    Write-Host "FAIL: Branch '$FEATURE_BRANCH' not found." -ForegroundColor Red
    exit 1
}
Write-Host "OK: Feature branch $FEATURE_BRANCH exists (tip: $FEATURE_TIP)."

# Warn if PTR is running (RAM pressure during build)
$ptrRunning = docker inspect --format "{{.State.Running}}" "ac-worldserver-ptr" 2>$null
if ($ptrRunning -eq "true") {
    Write-Host "WARN: ac-worldserver-ptr is running. Stop it before Step 7 to free RAM for the build." -ForegroundColor Yellow
    Write-Host "      Command: docker stop ac-worldserver-ptr" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Pre-flight checks passed." -ForegroundColor Green

# ============================================================
# STEP 2: Snapshot acore_world
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 2: Snapshot acore_world" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Destination: $SNAPSHOT_DIR"
Write-Host "  This takes a mysqldump of acore_world BEFORE any changes."
Write-Host "  Required for rollback to work."

if (Confirm-Step "Take pre-deploy snapshot of acore_world?") {
    New-Item -ItemType Directory -Force -Path $SNAPSHOT_DIR | Out-Null
    Write-Host "Dumping acore_world... (may take a few minutes)" -ForegroundColor Yellow
    docker exec $DB_CONTAINER mysqldump -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 --single-transaction $WORLD_DB 2>$null > "$SNAPSHOT_DIR\acore_world.sql"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: mysqldump acore_world failed." -ForegroundColor Red
        exit 1
    }
    $snapSize = [math]::Round((Get-Item "$SNAPSHOT_DIR\acore_world.sql").Length / 1MB, 1)
    Write-Host "OK: Snapshot saved ($snapSize MB) -> $SNAPSHOT_DIR\acore_world.sql" -ForegroundColor Green

    # Write snapshot path into rollback script's expected variable at runtime
    # (rollback.ps1 reads SNAPSHOT_DIR from a sidecar file)
    "$SNAPSHOT_DIR" | Out-File "$PKG_DIR\snapshot_path.txt" -Encoding UTF8
    Write-Host "OK: Snapshot path recorded in $PKG_DIR\snapshot_path.txt"
} else {
    Write-Host "WARN: Snapshot skipped. Rollback will NOT be possible without it." -ForegroundColor Yellow
}

# ============================================================
# STEP 3: Git merge feat/wow-ak-1-env-effects -> custom
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 3: Merge $FEATURE_BRANCH -> custom" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Current branch must be 'custom'."
Write-Host "  Command: git merge $FEATURE_BRANCH"
Write-Host ""

$currentBranch = git -C $REPO_ROOT rev-parse --abbrev-ref HEAD
Write-Host "  Current branch: $currentBranch"

# Check if feature branch tip is already on custom (merge already done)
$mergeBase = git -C $REPO_ROOT merge-base custom $FEATURE_BRANCH 2>$null
$featureTip = git -C $REPO_ROOT rev-parse $FEATURE_BRANCH 2>$null
$alreadyMerged = ($mergeBase -eq $featureTip)

if ($alreadyMerged) {
    Write-Host "OK: $FEATURE_BRANCH is already merged into custom. Skipping." -ForegroundColor Green
    $SKIP_MERGE = $true
} else {
    $SKIP_MERGE = $false
    if ($currentBranch -ne "custom") {
        Write-Host "WARN: You are not on branch 'custom' (you are on '$currentBranch')." -ForegroundColor Yellow
        Write-Host "      Switch to custom before running the merge: git checkout custom" -ForegroundColor Yellow
        Write-Host ""
    }
    Write-Host "  Commits that will be merged (feat/wow-ak-1-env-effects..custom in reverse):"
    git -C $REPO_ROOT log --oneline "custom..$FEATURE_BRANCH" | ForEach-Object { Write-Host "    $_" }
    Write-Host ""

    if (Confirm-Step "Run: git -C $REPO_ROOT merge $FEATURE_BRANCH (on branch custom)?") {
        if ($currentBranch -ne "custom") {
            Write-Host "  Switching to custom..." -ForegroundColor Yellow
            git -C $REPO_ROOT checkout custom
            if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: git checkout custom failed." -ForegroundColor Red; exit 1 }
        }
        git -C $REPO_ROOT merge $FEATURE_BRANCH
        if ($LASTEXITCODE -ne 0) {
            Write-Host "FAIL: git merge $FEATURE_BRANCH failed. Resolve conflicts, then re-run this script." -ForegroundColor Red
            exit 1
        }
        Write-Host "OK: Merge complete." -ForegroundColor Green
    } else {
        Write-Host "WARN: Merge skipped. Build in Step 7 will use current sources (may be pre-merge)." -ForegroundColor Yellow
    }
}

# ============================================================
# STEP 4: Apply acore_world SQL (3 files)
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 4: Apply acore_world SQL (3 files)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Apply order (dependency order):"
Write-Host "    1. mod_env_effects_v2_spells.sql   (207 spell_dbc rows: 107000-107176, 107500-107528, 108500)"
Write-Host "    2. mod_env_effects_v2_seed.sql      (DROP+CREATE mod_environmental_effects + 296 rule rows)"
Write-Host "    3. mod_env_effects_game_weather.sql (REPLACE INTO game_weather, 6 zones)"
Write-Host ""
Write-Host "  All 3 are idempotent. Safe to re-apply if interrupted."

if (Confirm-Step "Apply all 3 files to $WORLD_DB on $DB_CONTAINER?") {
    foreach ($f in $WORLD_SQL) {
        Apply-SqlFile -Database $WORLD_DB -FilePath $f
    }

    Write-Host ""
    Write-Host "  Verification queries:" -ForegroundColor Cyan

    $buffCount = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM spell_dbc WHERE ID BETWEEN 107000 AND 107199"
    Write-Host "  spell_dbc 107000-107199 (buffs): $buffCount rows (expected: 177)"

    $debuffCount = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM spell_dbc WHERE ID BETWEEN 107500 AND 107599"
    Write-Host "  spell_dbc 107500-107599 (debuffs): $debuffCount rows (expected: 30)"

    $nightDebuff = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM spell_dbc WHERE ID = 108500"
    Write-Host "  spell_dbc 108500 (night debuff): $nightDebuff rows (expected: 1)"

    $ruleCount = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM mod_environmental_effects"
    Write-Host "  mod_environmental_effects rules: $ruleCount rows (expected: 296)"

    $zoneCount = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(DISTINCT zone_id) FROM mod_environmental_effects"
    Write-Host "  mod_environmental_effects zones: $zoneCount (expected: 59)"

    $weatherCount = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM game_weather WHERE zone IN (8,40,130,331,3519,495)"
    Write-Host "  game_weather added zones: $weatherCount rows (expected: 6)"

    Write-Host "OK: acore_world SQL complete." -ForegroundColor Green
}

# ============================================================
# STEP 5: Add TZ to docker-compose.override.yml
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 5: Add TZ: Europe/Moscow to live worldserver" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  File: $COMPOSE_OVERRIDE"
Write-Host "  The ac-worldserver service needs TZ so night window 21:00-06:00 matches"
Write-Host "  Moscow wall-clock time (same as already done for ac-worldserver-ptr)."
Write-Host ""

$overrideContent = Get-Content $COMPOSE_OVERRIDE -Raw

# Detect if TZ is already in the live worldserver block
# The live service block is `ac-worldserver:` (not ac-worldserver-ptr)
# We look for TZ within the section before ac-worldserver-ptr definition
$liveSectionEnd = $overrideContent.IndexOf("ac-worldserver-ptr:")
$liveSection = if ($liveSectionEnd -gt 0) { $overrideContent.Substring(0, $liveSectionEnd) } else { $overrideContent }
$tzPresent = $liveSection -match 'TZ:\s*"Europe/Moscow"'

if ($tzPresent) {
    Write-Host "OK: TZ: Europe/Moscow already present in ac-worldserver service. Skipping." -ForegroundColor Green
    $SKIP_TZ = $true
} else {
    $SKIP_TZ = $false
    Write-Host "  Will insert 'TZ: ""Europe/Moscow""' into the ac-worldserver environment block."
    Write-Host "  Backup will be saved to: $COMPOSE_BAK"

    if (Confirm-Step "Edit docker-compose.override.yml to add TZ for ac-worldserver?") {
        # Backup original
        Copy-Item $COMPOSE_OVERRIDE $COMPOSE_BAK
        Write-Host "  Backup saved: $COMPOSE_BAK"

        # Insert TZ after the last existing environment entry in the ac-worldserver block.
        # The live block has no environment: section, so we need to add one, OR
        # insert before the volumes: key of the ac-worldserver service.
        # Strategy: find the ac-worldserver: container_name line and insert environment + TZ
        # before the volumes: key that follows it.
        #
        # Current structure (lines 23-29):
        #   ac-worldserver:
        #     container_name: ac-worldserver-v2
        #     volumes:
        #       - ...
        #
        # Target structure:
        #   ac-worldserver:
        #     container_name: ac-worldserver-v2
        #     environment:
        #       TZ: "Europe/Moscow"
        #     volumes:
        #       - ...
        #
        $lines = Get-Content $COMPOSE_OVERRIDE
        $newLines = [System.Collections.Generic.List[string]]::new()
        $inLiveWorldserver = $false
        $insertedTZ = $false

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]

            # Detect entry into the live worldserver service block
            if ($line -match '^\s{2}ac-worldserver:\s*$') {
                $inLiveWorldserver = $true
            }
            # Detect exit from the live worldserver service block (another top-level service)
            elseif ($line -match '^\s{2}\w' -and $inLiveWorldserver) {
                $inLiveWorldserver = $false
            }

            # Insert environment block before the volumes: line inside the live block
            if ($inLiveWorldserver -and -not $insertedTZ -and $line -match '^\s{4}volumes:\s*$') {
                $newLines.Add("    environment:")
                $newLines.Add('      TZ: "Europe/Moscow"')
                $insertedTZ = $true
            }

            $newLines.Add($line)
        }

        if (-not $insertedTZ) {
            Write-Host "FAIL: Could not locate insertion point in docker-compose.override.yml." -ForegroundColor Red
            Write-Host "      Restore from backup and edit manually:" -ForegroundColor Red
            Write-Host "      Add 'TZ: ""Europe/Moscow""' under environment: in the ac-worldserver service." -ForegroundColor Red
            Copy-Item $COMPOSE_BAK $COMPOSE_OVERRIDE -Force
            exit 1
        }

        $newLines | Out-File $COMPOSE_OVERRIDE -Encoding UTF8
        Write-Host "OK: TZ added to ac-worldserver service in docker-compose.override.yml." -ForegroundColor Green

        # Verify
        $verify = Get-Content $COMPOSE_OVERRIDE -Raw
        if ($verify -notmatch 'TZ:\s*"Europe/Moscow"') {
            Write-Host "FAIL: TZ not found after edit. Restoring backup." -ForegroundColor Red
            Copy-Item $COMPOSE_BAK $COMPOSE_OVERRIDE -Force
            exit 1
        }
        Write-Host "OK: Verified TZ present in updated file." -ForegroundColor Green
    }
}

# ============================================================
# STEP 6: Create live module conf
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 6: Create live module conf" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Target: $CONF_LIVE"
Write-Host "  Source: $CONF_DIST"
Write-Host "  Settings: Enable=1, Debug=0, RotationMinHours=1, NightStartHour=21,"
Write-Host "            NightEndHour=6, NightDebuffSpell=108500"

if (Test-Path $CONF_LIVE) {
    Write-Host "OK: Conf already exists at $CONF_LIVE. Skipping (idempotent)." -ForegroundColor Green
    Write-Host "    If settings need updating, edit the file manually." -ForegroundColor Yellow
} else {
    if (Confirm-Step "Copy conf.dist to live conf path ($CONF_LIVE)?") {
        Copy-Item $CONF_DIST $CONF_LIVE
        Write-Host "OK: Conf created at $CONF_LIVE" -ForegroundColor Green

        # Verify key values
        $confContent = Get-Content $CONF_LIVE -Raw
        $checks = @(
            @{ Pattern = 'EnvironmentalEffects\.Enable\s*=\s*1';   Label = 'Enable=1' },
            @{ Pattern = 'EnvironmentalEffects\.Debug\s*=\s*0';    Label = 'Debug=0' },
            @{ Pattern = 'EnvironmentalEffects\.NightStartHour\s*=\s*21'; Label = 'NightStartHour=21' },
            @{ Pattern = 'EnvironmentalEffects\.NightEndHour\s*=\s*6';   Label = 'NightEndHour=6' },
            @{ Pattern = 'EnvironmentalEffects\.NightDebuffSpell\s*=\s*108500'; Label = 'NightDebuffSpell=108500' }
        )
        foreach ($check in $checks) {
            if ($confContent -match $check.Pattern) {
                Write-Host "  OK: $($check.Label)" -ForegroundColor Green
            } else {
                Write-Host "  WARN: $($check.Label) — not found or wrong value. Check $CONF_LIVE manually." -ForegroundColor Yellow
            }
        }
    }
}

# ============================================================
# STEP 7: Rebuild live worldserver image
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 7: Rebuild live worldserver image" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  This rebuilds acore/ac-wotlk-worldserver:master from current sources."
Write-Host "  The merge in Step 3 must be complete for GetWeatherState() to be public."
Write-Host "  mod-environmental-effects will be compiled into the worldserver binary."
Write-Host ""
Write-Host "  RECOMMENDATION: Stop ac-worldserver-ptr before building to free WSL2 RAM."
Write-Host "  Command: docker stop ac-worldserver-ptr"
Write-Host ""

if (Confirm-Step "Ready to run: docker compose build ac-worldserver (may take 10-20 min)?" -SkipAllowed) {
    Set-Location $REPO_ROOT
    Write-Host "Building..." -ForegroundColor Yellow
    docker compose build ac-worldserver
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: docker compose build ac-worldserver failed (exit $LASTEXITCODE)" -ForegroundColor Red
        Write-Host "The SQL and conf changes in steps 4-6 are already applied but the new binary is not running." -ForegroundColor Yellow
        Write-Host "Fix the build issue and re-run steps 7-8, or roll back using rollback.ps1." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "OK: Image rebuilt." -ForegroundColor Green
} else {
    Write-Host "Skipped image rebuild. The conf and SQL steps still applied." -ForegroundColor Yellow
    Write-Host "Run steps 7-8 manually when ready to deploy the binary." -ForegroundColor Yellow
}

# ============================================================
# STEP 8: Restart live worldserver
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 8: Restart live worldserver" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  This recreates ac-worldserver-v2 with the new image, picks up TZ env var,"
Write-Host "  and loads mod_environmental_effects.conf + all DB changes."

if (Confirm-Step "Run: docker compose up -d ac-worldserver (in $REPO_ROOT)?") {
    Set-Location $REPO_ROOT
    docker compose up -d ac-worldserver
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: docker compose up -d ac-worldserver failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: ac-worldserver-v2 recreated." -ForegroundColor Green
    Write-Host ""
    Write-Host "Waiting 15 seconds for startup..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    $wsStatus = docker inspect --format "{{.State.Running}}" $WS_CONTAINER 2>$null
    Write-Host "  Container running: $wsStatus"
    if ($wsStatus -eq "true") {
        Write-Host "OK: Container is up." -ForegroundColor Green
    } else {
        Write-Host "WARN: Container does not appear to be running. Check docker logs $WS_CONTAINER" -ForegroundColor Yellow
    }
}

# ============================================================
# Done
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Apply complete. Perform smoke tests:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Server log check:"
Write-Host "    docker logs $WS_CONTAINER 2>&1 | Select-String 'environmental'"
Write-Host "    Expected: 'Loaded 296 rule(s) across 59 zone(s), 207 spell(s)'"
Write-Host ""
Write-Host "  DB spot-check:"
Write-Host "    docker exec $DB_CONTAINER mysql -u$DB_USER -p$DB_PASS -N -e 'SELECT COUNT(*) FROM mod_environmental_effects' acore_world"
Write-Host "    Expected: 296"
Write-Host ""
Write-Host "  In-game:"
Write-Host "    1. Log in to a character in Alterac Mountains (zone 36) — 3 zone buffs should appear."
Write-Host "    2. After 21:00 Moscow time outdoors — Pokrov Nochi debuff (108500) should apply."
Write-Host "    3. Buff icons will show placeholder (SpellIconID=1) until MPQ is patched."
Write-Host ""
Write-Host "If smoke tests pass, report success to the agent to log this deployment."
Write-Host "If anything fails, run: pwsh `"$PKG_DIR\rollback.ps1`""
Write-Host ""
Write-Host "Snapshot for rollback: $SNAPSHOT_DIR"
