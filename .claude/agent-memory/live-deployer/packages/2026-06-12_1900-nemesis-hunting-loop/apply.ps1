#Requires -Version 5.1
<#
.SYNOPSIS
    Apply: Nemesis Hunting Loop v2 -> live server
    Package: 2026-06-12_1900-nemesis-hunting-loop

.DESCRIPTION
    Human-run script. Applies the full hunting-loop feature set to production.
    Performs no writes until explicit confirmation prompts are answered.

    Apply order:
      Step 1  Pre-flight safety checks
      Step 2  Rebuild live worldserver image (docker compose build ac-worldserver)
      Step 3  Apply acore_world SQL (13 files)
      Step 4  Apply acore_characters SQL (2 files)
      Step 5  Append new conf keys (non-destructive, new keys only)
      Step 6  Restart live worldserver (docker compose up -d ac-worldserver)

    IMPORTANT: Do NOT run while a live player session is active.
    Shut down ac-worldserver-ptr before building to free WSL2 RAM (avoid OOM).

.NOTES
    Agent permission policy: this script is USER-RUN, NOT agent-run.
    The agent prepared this package but does not execute it.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Config ---
$REPO_ROOT     = "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk"
$DB_CONTAINER  = "ac-database-v2"
$WS_CONTAINER  = "ac-worldserver-v2"
$DB_USER       = "root"
$DB_PASS       = if ($env:DOCKER_DB_ROOT_PASSWORD) { $env:DOCKER_DB_ROOT_PASSWORD } else { "password" }
$WORLD_DB      = "acore_world"
$CHARS_DB      = "acore_characters"

$PKG_DIR       = "$REPO_ROOT\.claude\agent-memory\live-deployer\packages\2026-06-12_1900-nemesis-hunting-loop"
$CONF_FILE     = "$REPO_ROOT\env\dist\etc\modules\mod_nemesis_system.conf"
$BACKUP_DIR    = "$REPO_ROOT\backups\live\2026-06-12_175354_pre-hunting-loop-deploy"

# SQL files in apply order
$WORLD_SQL = @(
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_mech.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_fire.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_ice.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_nature.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_light.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_shadow.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_arcane.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_demon.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_beast.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_spirit.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_chests.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\nemesis_familiars_gacha_vendor.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_world\statbooster_scrolls.sql"
)

$CHARS_SQL = @(
    "$REPO_ROOT\data\sql\updates\pending_db_characters\nemesis_special_task.sql",
    "$REPO_ROOT\data\sql\updates\pending_db_characters\nemesis_special_task_target.sql"
)

# New conf keys to append (PROD values — FreeChoice=0, NoDailyLimit=0)
$NEW_CONF_KEYS = @"

# --- HUNTING LOOP v2 (appended 2026-06-12) ---

# Ambient generation
NemesisSystem.AmbientGeneration.Enable = 1
NemesisSystem.AmbientGeneration.IntervalMinSeconds = 300
NemesisSystem.AmbientGeneration.IntervalMaxSeconds = 600
NemesisSystem.AmbientGeneration.FillPercent = 50
NemesisSystem.AmbientGeneration.RankUpChance = 10
NemesisSystem.AmbientGeneration.EliteChance = 25
NemesisSystem.AmbientGeneration.RequireRealPlayers = 1
NemesisSystem.AmbientGeneration.Announce = 1
NemesisSystem.AmbientGeneration.AnnounceZoneOnly = 1

# Dungeon nemesis
NemesisSystem.DungeonNemesis.Enable = 1
NemesisSystem.DungeonNemesis.Chance = 3.0
NemesisSystem.DungeonNemesis.IncludeRaids = 0
NemesisSystem.DungeonNemesis.RequireRealPlayers = 1
NemesisSystem.DungeonNemesis.PresenceCooldownSeconds = 120

# Hunter rank scaling
NemesisSystem.HunterRankScaling.Enable = 1

# Rank-gated bounty vendor submenus
NemesisSystem.BountyVendor.RankMenus.Enable = 1
NemesisSystem.BountyVendor.GeneralEntry = 190100
NemesisSystem.BountyVendor.StatBoosterEntry = 190101
NemesisSystem.BountyVendor.FamiliarEntry = 190102
NemesisSystem.BountyVendor.VeteranEntry = 190103
NemesisSystem.BountyVendor.StatBoosterRank = 2
NemesisSystem.BountyVendor.FamiliarRank = 3
NemesisSystem.BountyVendor.VeteranRank = 4

# Special daily task (PROD invariant: FreeChoice=0, NoDailyLimit=0)
NemesisSpecialTask.Enable = 1
NemesisSpecialTask.SpeedKillMinutes = 120
NemesisSpecialTask.DungeonMinKills = 3
NemesisSpecialTask.RewardItem = 110150
NemesisSpecialTask.Reward.Speed = 1
NemesisSpecialTask.Reward.Continent = 1
NemesisSpecialTask.Reward.Dungeon = 1
NemesisSpecialTask.FreeChoice = 0
NemesisSpecialTask.NoDailyLimit = 0

# Reputation: special task bonuses (new keys only)
NemesisRep.SpecialTaskBonus = 100
NemesisRep.SpecialTaskPerRank = 1
"@

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

function Apply-SqlFile {
    param([string]$Database, [string]$FilePath)
    $filename = Split-Path $FilePath -Leaf
    Write-Host "  Applying: $filename -> $Database ..." -NoNewline
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    # Write to temp file inside container via stdin
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

# Check DB container is running
$dbStatus = docker inspect --format "{{.State.Running}}" $DB_CONTAINER 2>$null
if ($dbStatus -ne "true") {
    Write-Host "FAIL: DB container '$DB_CONTAINER' is not running." -ForegroundColor Red
    exit 1
}
Write-Host "OK: DB container is running."

# Check backup exists
if (-not (Test-Path "$BACKUP_DIR\acore_world.sql")) {
    Write-Host "FAIL: Pre-deploy backup not found at $BACKUP_DIR" -ForegroundColor Red
    Write-Host "      Take a backup before proceeding (see rollback.ps1 header)." -ForegroundColor Red
    exit 1
}
Write-Host "OK: Pre-deploy backup present at $BACKUP_DIR"

# Verify all SQL files exist
$allSql = $WORLD_SQL + $CHARS_SQL
foreach ($f in $allSql) {
    if (-not (Test-Path $f)) {
        Write-Host "FAIL: SQL file missing: $f" -ForegroundColor Red
        exit 1
    }
}
Write-Host "OK: All $($allSql.Count) SQL files present."

# PROD invariant guard: ensure conf block to append has FreeChoice=0 and NoDailyLimit=0
if ($NEW_CONF_KEYS -match "FreeChoice\s*=\s*1" -or $NEW_CONF_KEYS -match "NoDailyLimit\s*=\s*1") {
    Write-Host "FAIL: PROD invariant violation — FreeChoice or NoDailyLimit is set to 1 in conf block!" -ForegroundColor Red
    Write-Host "      Edit this script and set both to 0 before deploying to live." -ForegroundColor Red
    exit 1
}
Write-Host "OK: PROD invariant check passed (FreeChoice=0, NoDailyLimit=0)."

# Check if conf already has hunting loop keys (re-run guard)
$existingConf = Get-Content $CONF_FILE -Raw
if ($existingConf -match "HUNTING LOOP v2") {
    Write-Host "WARN: Conf already contains HUNTING LOOP v2 block. Conf step will be skipped." -ForegroundColor Yellow
    $SKIP_CONF = $true
} else {
    $SKIP_CONF = $false
    Write-Host "OK: Conf does not yet have hunting-loop keys (will be appended)."
}

# Verify live worldserver state
$wsRunning = docker inspect --format "{{.State.Running}}" $WS_CONTAINER 2>$null
if ($wsRunning -eq "true") {
    Write-Host "WARN: Live worldserver '$WS_CONTAINER' is currently running." -ForegroundColor Yellow
    Write-Host "      SQL applies are safe while server is up; image rebuild requires it to stop." -ForegroundColor Yellow
} else {
    Write-Host "OK: Live worldserver is stopped (good for rebuild)."
}

Write-Host ""
Write-Host "Pre-flight checks passed." -ForegroundColor Green

# ============================================================
# STEP 2: Rebuild live worldserver image
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 2: Rebuild live worldserver image" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  This rebuilds acore/ac-wotlk-worldserver:master from current sources."
Write-Host "  mod-nemesis-system will be at commit 215c4ef (branch feat/wow-ak-1-nemesis-familiars)."
Write-Host ""
Write-Host "  RECOMMENDATION: Stop ac-worldserver-ptr before building to free WSL2 RAM."
Write-Host "  Command: docker stop ac-worldserver-ptr"
Write-Host ""

if (Confirm-Step "Ready to run: docker compose build ac-worldserver (in $REPO_ROOT)?") {
    Set-Location $REPO_ROOT
    Write-Host "Building..." -ForegroundColor Yellow
    docker compose build ac-worldserver
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: docker compose build ac-worldserver failed (exit $LASTEXITCODE)" -ForegroundColor Red
        Write-Host "Do not proceed with SQL applies if you want a clean rollback point." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: Image rebuilt." -ForegroundColor Green
} else {
    Write-Host "Skipped image rebuild. SQL applies and conf update will still proceed." -ForegroundColor Yellow
}

# ============================================================
# STEP 3: Apply acore_world SQL (13 files)
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 3: Apply acore_world SQL (13 files)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Files:"
foreach ($f in $WORLD_SQL) { Write-Host "    - $(Split-Path $f -Leaf)" }

if (Confirm-Step "Apply all 13 files to $WORLD_DB on $DB_CONTAINER?") {
    foreach ($f in $WORLD_SQL) {
        Apply-SqlFile -Database $WORLD_DB -FilePath $f
    }
    Write-Host ""
    Write-Host "Verification query:" -ForegroundColor Cyan
    $creatureCount = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM creature_template WHERE entry BETWEEN 191000 AND 191099"
    Write-Host "  creature_template 191000-191099: $creatureCount rows (expected: 100)"
    $vendorCount = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM npc_vendor WHERE entry IN (190100,190101,190102,190103)"
    Write-Host "  npc_vendor 190100-190103: $vendorCount rows (expected: 28)"
    $coinPresent = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT entry FROM item_template WHERE entry = 110150"
    Write-Host "  item_template 110150: $coinPresent (expected: 110150)"
    $iecPresent = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM itemextendedcost_dbc WHERE ID IN (100006,100007)"
    Write-Host "  itemextendedcost_dbc 100006/100007: $iecPresent rows (expected: 2)"
    Write-Host "OK: acore_world SQL complete." -ForegroundColor Green
}

# ============================================================
# STEP 4: Apply acore_characters SQL (2 files)
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 4: Apply acore_characters SQL (2 files)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Files:"
foreach ($f in $CHARS_SQL) { Write-Host "    - $(Split-Path $f -Leaf)" }

if (Confirm-Step "Apply 2 files to $CHARS_DB on $DB_CONTAINER?") {
    foreach ($f in $CHARS_SQL) {
        Apply-SqlFile -Database $CHARS_DB -FilePath $f
    }
    $tableExists = Invoke-LiveQuery -Database $CHARS_DB -Query "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='acore_characters' AND TABLE_NAME='character_nemesis_special_task'"
    Write-Host "  character_nemesis_special_task exists: $tableExists (expected: 1)"
    $colExists = Invoke-LiveQuery -Database $CHARS_DB -Query "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='acore_characters' AND TABLE_NAME='character_nemesis_special_task' AND COLUMN_NAME='target_spawn'"
    Write-Host "  target_spawn column present: $colExists (expected: 1)"
    Write-Host "OK: acore_characters SQL complete." -ForegroundColor Green
}

# ============================================================
# STEP 5: Append new conf keys
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 5: Append hunting-loop conf keys" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($SKIP_CONF) {
    Write-Host "Skipped: HUNTING LOOP v2 block already present in conf." -ForegroundColor Yellow
} else {
    Write-Host "  Target: $CONF_FILE"
    Write-Host "  Adding ~35 new keys. Existing tuned values (cooldowns, rep thresholds) are untouched."
    Write-Host "  FreeChoice=0, NoDailyLimit=0 (PROD invariant)."

    if (Confirm-Step "Append new hunting-loop keys to mod_nemesis_system.conf?") {
        Add-Content -Path $CONF_FILE -Value $NEW_CONF_KEYS -Encoding UTF8
        # Verify
        $verifyConf = Get-Content $CONF_FILE -Raw
        if ($verifyConf -match "NemesisSpecialTask.Enable") {
            Write-Host "OK: Conf keys appended successfully." -ForegroundColor Green
        } else {
            Write-Host "FAIL: Could not verify conf append. Check $CONF_FILE manually." -ForegroundColor Red
            exit 1
        }
    }
}

# ============================================================
# STEP 6: Restart live worldserver
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " STEP 6: Start live worldserver" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  This starts ac-worldserver-v2 with the new image + conf."
Write-Host "  If the server is currently running it will be replaced in-place."

if (Confirm-Step "Run: docker compose up -d ac-worldserver (in $REPO_ROOT)?") {
    Set-Location $REPO_ROOT
    docker compose up -d ac-worldserver
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: docker compose up -d ac-worldserver failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: ac-worldserver-v2 started." -ForegroundColor Green
    Write-Host ""
    Write-Host "Waiting 10 seconds for startup..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    $wsStatus = docker inspect --format "{{.State.Running}}" $WS_CONTAINER 2>$null
    Write-Host "  Container running: $wsStatus"
}

# ============================================================
# Done
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Apply complete. Perform in-game smoke tests:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  1. Talk to innkeeper — verify 4 rank submenus appear"
Write-Host "  2. GM: .nemesis ambient  (forces ambient pass, should print births)"
Write-Host "  3. GM: verify special task gossip at innkeeper"
Write-Host "  4. Run smoke queries from manifest.md"
Write-Host ""
Write-Host "If smoke tests pass, report success so the agent can log this deployment."
Write-Host "If anything fails, run: pwsh rollback.ps1"
