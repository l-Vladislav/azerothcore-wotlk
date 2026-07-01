# =============================================================================
# apply.ps1 — mod-ollama-chat Phase 3 deployment to live
# =============================================================================
# TARGET:   acore_characters (live DB in container ac-database-v2)
# SCOPE:    4 SQL files (DB only). Image rebuild and config edit are separate
#           manual steps documented in manifest.md and config-diff.md.
# RUN AS:   Human operator from the project root directory.
#           pwsh .claude/agent-memory/live-deployer/packages/2026-06-25_1200-mod-ollama-chat-phase3/apply.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

$ProjectRoot = "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk"
$PackageDir  = "$ProjectRoot\.claude\agent-memory\live-deployer\packages\2026-06-25_1200-mod-ollama-chat-phase3"
$Container   = "ac-database-v2"
$DB          = "acore_characters"
$MySQLRoot   = "root"
$MySQLPass   = "password"
$SnapshotFile = "$PackageDir\pre-deploy-snapshot.sql.gz"

$SqlFiles = @(
    "$ProjectRoot\data\sql\updates\pending_db_characters\mod_ollama_chat_memory.sql",
    "$ProjectRoot\data\sql\updates\pending_db_characters\mod_ollama_chat_bot_journal.sql",
    "$ProjectRoot\modules\mod-ollama-chat\data\sql\characters\base\2025_05_31_personality_template.sql",
    "$ProjectRoot\modules\mod-ollama-chat\data\sql\characters\base\2025_11_01_personality_manual_only.sql"
)

Write-Host ""
Write-Host "============================================================"
Write-Host "  mod-ollama-chat Phase 3 — DB apply to live acore_characters"
Write-Host "============================================================"
Write-Host ""

# -------------------------------------------------
# Pre-flight: verify files exist
# -------------------------------------------------
Write-Host "[PRE-FLIGHT] Checking SQL files..."
foreach ($f in $SqlFiles) {
    if (-not (Test-Path $f)) {
        Write-Error "MISSING: $f"
        exit 1
    }
    Write-Host "  OK  $f"
}

# -------------------------------------------------
# Pre-flight: verify container is up
# -------------------------------------------------
Write-Host ""
Write-Host "[PRE-FLIGHT] Checking container $Container..."
$status = docker inspect --format "{{.State.Status}}" $Container 2>$null
if ($status -ne "running") {
    Write-Error "Container $Container is not running (status: $status). Aborting."
    exit 1
}
Write-Host "  OK  Container is running."

# -------------------------------------------------
# Step 1: Pre-deploy snapshot
# -------------------------------------------------
Write-Host ""
Write-Host "[STEP 1] Taking pre-deploy snapshot of $DB ..."
Write-Host "  Snapshot will be saved to: $SnapshotFile"

docker exec $Container mysqldump -u$MySQLRoot -p$MySQLPass --default-character-set=utf8mb4 --single-transaction $DB | & "$env:SystemRoot\System32\cmd.exe" /c "gzip > `"$SnapshotFile`"" 2>&1 | Out-Null
# Fallback if gzip not available via cmd: use PowerShell compression
if (-not (Test-Path $SnapshotFile)) {
    $rawDump = "$PackageDir\pre-deploy-snapshot.sql"
    docker exec $Container mysqldump -u$MySQLRoot -p$MySQLPass --default-character-set=utf8mb4 --single-transaction $DB | Out-File -FilePath $rawDump -Encoding UTF8
    # Compress using .NET
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $inStream  = [System.IO.File]::OpenRead($rawDump)
    $outStream = [System.IO.File]::Create($SnapshotFile)
    $gzStream  = [System.IO.Compression.GZipStream]::new($outStream, [System.IO.Compression.CompressionMode]::Compress)
    $inStream.CopyTo($gzStream)
    $gzStream.Close(); $outStream.Close(); $inStream.Close()
    Remove-Item $rawDump -Force
}

if (-not (Test-Path $SnapshotFile)) {
    Write-Error "Snapshot file was not created. Aborting."
    exit 1
}
$sizeKB = [math]::Round((Get-Item $SnapshotFile).Length / 1KB, 1)
Write-Host "  OK  Snapshot created: $sizeKB KB"

# -------------------------------------------------
# Step 2: Apply SQL files
# -------------------------------------------------
Write-Host ""
Write-Host "[STEP 2] Applying SQL migrations to $DB ..."

foreach ($f in $SqlFiles) {
    $baseName = Split-Path $f -Leaf
    Write-Host "  Applying: $baseName"
    # Copy SQL file into container, apply, then remove
    $tmpPath = "/tmp/ollama_deploy_$baseName"
    docker cp $f "${Container}:${tmpPath}" 2>&1 | Out-Null
    $result = docker exec $Container bash -c "mysql -u$MySQLRoot -p$MySQLPass --default-character-set=utf8mb4 $DB < $tmpPath && rm -f $tmpPath" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR applying $baseName : $result"
        Write-Host ""
        Write-Host "FAILED. Run rollback.ps1 to restore from snapshot."
        exit 1
    }
    Write-Host "  OK  $baseName applied."
}

# -------------------------------------------------
# Step 3: Verify new tables exist
# -------------------------------------------------
Write-Host ""
Write-Host "[STEP 3] Verifying new tables..."

$tables = docker exec $Container mysql -u$MySQLRoot -p$MySQLPass $DB -se "SHOW TABLES LIKE 'mod_ollama%';" 2>&1
$expected = @("mod_ollama_chat_memory", "mod_ollama_chat_bot_journal")
foreach ($t in $expected) {
    if ($tables -match $t) {
        Write-Host "  OK  Table $t exists."
    } else {
        Write-Host "  WARN  Table $t not found after apply. Check manually."
    }
}

# -------------------------------------------------
# Step 4: Verify personality_templates manual_only column
# -------------------------------------------------
$colCheck = docker exec $Container mysql -u$MySQLRoot -p$MySQLPass $DB -se "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB' AND TABLE_NAME='mod_ollama_chat_personality_templates' AND COLUMN_NAME='manual_only';" 2>&1
if ($colCheck -match "1") {
    Write-Host "  OK  manual_only column present in personality_templates."
} else {
    Write-Host "  WARN  manual_only column not detected. Check manually."
}

# -------------------------------------------------
# Done — reminder for manual steps
# -------------------------------------------------
Write-Host ""
Write-Host "============================================================"
Write-Host "  DB APPLY COMPLETE"
Write-Host "============================================================"
Write-Host ""
Write-Host "NEXT MANUAL STEPS (NOT automated — you must do these):"
Write-Host ""
Write-Host "  1. EDIT CONFIG:"
Write-Host "     File: $ProjectRoot\env\dist\etc\modules\mod_ollama_chat.conf"
Write-Host "     See:  $PackageDir\config-diff.md"
Write-Host "     Key changes: Model=gemma4:12b, NumCtx=8192, NumPredict=80,"
Write-Host "     Temperature=0.3, TopP=0.9, RepeatPenalty=1.15,"
Write-Host "     + new EnableNamedCharacters/NewsFeed/LongTermMemory/ExtendedMemory block,"
Write-Host "     + ChatPromptTemplate adds {bot_memory} {bot_journal}"
Write-Host ""
Write-Host "  2. VERIFY MODULE CODE AT CORRECT COMMIT:"
Write-Host "     cd modules\mod-ollama-chat && git log --oneline -1"
Write-Host "     Expected: bfef7f9 (feat/ollama-chat-llm tip)"
Write-Host ""
Write-Host "  3. REBUILD LIVE IMAGE (from project root):"
Write-Host "     docker compose build ac-worldserver"
Write-Host "     (This takes 5-15 min. Uses same Dockerfile as PTR.)"
Write-Host ""
Write-Host "  4. START LIVE WORLDSERVER:"
Write-Host "     docker compose up -d ac-worldserver"
Write-Host "     (Container name will be ac-worldserver-v2 per override)"
Write-Host ""
Write-Host "  5. SMOKE TEST:"
Write-Host "     - Log in and whisper any bot"
Write-Host "     - Verify response (should use gemma4:12b — check logs)"
Write-Host "     - After ~10 messages, check mod_ollama_chat_memory table"
Write-Host "     - Check bot journal for named bots (GUIDs 566, 568)"
Write-Host ""
Write-Host "  Snapshot for rollback: $SnapshotFile"
Write-Host ""
