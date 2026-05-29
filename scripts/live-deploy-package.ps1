# Generate a deployment package for promoting a single PTR-tested SQL file to live.
# Read-only against live — produces a self-contained package the human reviews and runs.
#
# Output: .claude/agent-memory/live-deployer/packages/<timestamp>-<sql_basename>/
#   ├── manifest.md             (human-readable summary: what + why + risk)
#   ├── pre-deploy-snapshot.sh  (mysqldump command, executed by apply.ps1)
#   ├── apply.ps1               (HUMAN runs this; takes snapshot, applies SQL, restarts)
#   ├── rollback.ps1            (restore from snapshot if smoke-test fails)
#   └── original.sql            (copy of the SQL file)
#
# Usage:
#   pwsh scripts/live-deploy-package.ps1 -SqlFile data/sql/updates/pending_db_world/statbooster_X.sql
#   pwsh scripts/live-deploy-package.ps1 -SqlFile ... -TargetDb acore_world

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SqlFile,

    [ValidateSet('acore_world', 'acore_characters', 'acore_auth')]
    [string]$TargetDb = 'acore_world',

    [switch]$SkipPtrCheck
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

# --- 1. Validate input ---
if (-not (Test-Path $SqlFile)) { throw "SQL file not found: $SqlFile" }
$sqlContent = Get-Content $SqlFile -Raw
$sqlName = Split-Path $SqlFile -Leaf
$sqlBase = $sqlName -replace '\.sql$', ''

# Hard ban: destructive patterns
$forbidden = @(
    'DROP\s+DATABASE',
    'TRUNCATE\s+TABLE',
    'DROP\s+TABLE',
    'mysql_install_db'
)
foreach ($pat in $forbidden) {
    if ($sqlContent -match $pat) {
        throw "SQL contains forbidden pattern: $pat (manual review required)"
    }
}

# --- 2. PTR-applied check (best-effort; ad-hoc applies bypass updates table) ---
# We can only verify via AC's `updates` table, which only catches files
# imported by worldserver-import. Files applied via ptr-sql-apply.ps1 won't
# show up here. So this is a WARNING, not a hard refusal.
if (-not $SkipPtrCheck) {
    $ptrDb = if ($TargetDb -eq 'acore_world') { $PTR_DB_WORLD }
             elseif ($TargetDb -eq 'acore_characters') { $PTR_DB_CHARS }
             else { Write-Warning "No PTR equivalent for $TargetDb — skipping PTR check"; $null }

    if ($ptrDb) {
        $check = docker exec ac-database-v2 mysql -uroot -ppassword -e "SELECT COUNT(*) FROM ${ptrDb}.updates WHERE name = '${sqlName}'" 2>$null | Select-Object -Last 1
        if ($check -eq '0') {
            Write-Warning "File '$sqlName' is not in ${ptrDb}.updates table."
            Write-Warning "  This is EXPECTED if you applied via ptr-sql-apply.ps1 (ad-hoc apply doesn't update the table)."
            Write-Warning "  Verify manually that the change is on PTR before promoting (e.g., query the affected rows)."
        }
    }
}

# --- 3. Already-on-live check ---
$alreadyApplied = docker exec ac-database-v2 mysql -uroot -ppassword -e "SELECT COUNT(*) FROM ${TargetDb}.updates WHERE name = '${sqlName}'" 2>$null | Select-Object -Last 1
$ptrHash = docker exec ac-database-v2 mysql -uroot -ppassword -e "SELECT hash FROM ${ptrDb}.updates WHERE name = '${sqlName}'" 2>$null | Select-Object -Last 1
$liveHash = if ($alreadyApplied -eq '1') {
    docker exec ac-database-v2 mysql -uroot -ppassword -e "SELECT hash FROM ${TargetDb}.updates WHERE name = '${sqlName}'" 2>$null | Select-Object -Last 1
} else { '<not applied>' }

# --- 4. Create package directory ---
$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
$pkgRoot = Join-Path $PSScriptRoot '..\\.claude\\agent-memory\\live-deployer\\packages'
$pkgDir = Join-Path $pkgRoot "${timestamp}-${sqlBase}"
New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null

# Copy original SQL
Copy-Item $SqlFile (Join-Path $pkgDir 'original.sql')

# --- 5. Generate manifest ---
$manifestPath = Join-Path $pkgDir 'manifest.md'
@"
# Deployment package: $sqlName

**Target DB:** ``$TargetDb``
**PTR DB tested:** ``$ptrDb``
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Pre-flight checks
- ✅ File exists in pending_db_*
- ✅ No forbidden DDL (DROP DATABASE / TRUNCATE / etc.)
- $(if (-not $SkipPtrCheck) { '✅' } else { '⚠️ SKIPPED' }) Applied to PTR (hash: ``$ptrHash``)
- $(if ($alreadyApplied -eq '0') { '✅ NOT yet on live (new deployment)' } else { "⚠️ Already on live with hash ``$liveHash`` — would re-apply with hash ``$ptrHash``" })

## What to do
1. Review the SQL: ``original.sql``
2. Review the apply script: ``apply.ps1``
3. Run: ``pwsh apply.ps1``
4. If smoke-test fails or you want to revert: ``pwsh rollback.ps1``

## SQL preview (first 30 lines)
``````sql
$(($sqlContent -split "`n" | Select-Object -First 30) -join "`n")
``````
"@ | Set-Content -Path $manifestPath -Encoding UTF8

# --- 6. Generate apply.ps1 ---
$applyPath = Join-Path $pkgDir 'apply.ps1'
@"
# Apply '$sqlName' to live ($TargetDb).
# Take snapshot first; restart worldserver after.
# DO NOT modify this script — regenerate from live-deploy-package.ps1 if scope changes.

`$ErrorActionPreference = 'Stop'
`$pkgDir = `$PSScriptRoot

Write-Host '=== 1. Taking pre-deploy snapshot of $TargetDb ===' -ForegroundColor Cyan
`$snapshotPath = Join-Path `$pkgDir 'pre-deploy-snapshot.sql.gz'
docker exec ac-database-v2 sh -c "mysqldump -uroot -ppassword $TargetDb | gzip" > `$snapshotPath
Write-Host "  Snapshot saved: `$snapshotPath (`$([Math]::Round((Get-Item `$snapshotPath).Length / 1MB, 1)) MB)"

Write-Host ''
Write-Host '=== 2. Applying $sqlName to $TargetDb ===' -ForegroundColor Cyan
Get-Content (Join-Path `$pkgDir 'original.sql') -Raw | docker exec -i ac-database-v2 mysql -uroot -ppassword $TargetDb
if (`$LASTEXITCODE -ne 0) { throw "SQL apply failed. Snapshot is at: `$snapshotPath" }
Write-Host '  Applied successfully'

Write-Host ''
Write-Host '=== 3. Verifying via updates table ===' -ForegroundColor Cyan
`$verify = docker exec ac-database-v2 mysql -uroot -ppassword -e "SELECT name, hash, FROM_UNIXTIME(timestamp) FROM ${TargetDb}.updates WHERE name = '${sqlName}'" 2>`$null
Write-Host `$verify

Write-Host ''
Write-Host '=== 4. Restarting ac-worldserver-v2 (live) ===' -ForegroundColor Cyan
Write-Host '  This will disconnect live players for ~30 seconds.'
`$reply = Read-Host '  Type ''yes'' to restart, or ''skip'' to skip'
if (`$reply -eq 'yes') {
    docker restart ac-worldserver-v2
    Write-Host '  Restart initiated. Tail logs to verify:'
    Write-Host '    docker logs --tail 30 ac-worldserver-v2'
} else {
    Write-Host '  Restart skipped — changes will apply on next live worldserver restart.'
}

Write-Host ''
Write-Host '=== Done ===' -ForegroundColor Green
Write-Host "If anything looks wrong, rollback with: pwsh `"`$pkgDir\rollback.ps1`""
"@ | Set-Content -Path $applyPath -Encoding UTF8

# --- 7. Generate rollback.ps1 ---
$rollbackPath = Join-Path $pkgDir 'rollback.ps1'
@"
# ROLLBACK '$sqlName' from live ($TargetDb).
# Restores the database from the pre-deploy snapshot.
# WARNING: this is a full-DB restore — any OTHER changes made between deploy and rollback will be LOST.
# Use only immediately after a failed deploy.

`$ErrorActionPreference = 'Stop'
`$pkgDir = `$PSScriptRoot

`$snapshotPath = Join-Path `$pkgDir 'pre-deploy-snapshot.sql.gz'
if (-not (Test-Path `$snapshotPath)) { throw "No snapshot found at `$snapshotPath — cannot rollback" }

Write-Host 'This will RESTORE $TargetDb from the pre-deploy snapshot.' -ForegroundColor Red
Write-Host 'Any changes to $TargetDb after the original apply will be LOST.' -ForegroundColor Red
`$reply = Read-Host "Type 'rollback' to confirm"
if (`$reply -ne 'rollback') { Write-Host 'Aborted.'; return }

Write-Host '=== 1. Stopping ac-worldserver-v2 (live) ===' -ForegroundColor Cyan
docker stop ac-worldserver-v2

Write-Host '=== 2. Restoring snapshot ===' -ForegroundColor Cyan
Get-Content `$snapshotPath -Raw -Encoding Byte | docker exec -i ac-database-v2 sh -c "gunzip | mysql -uroot -ppassword $TargetDb"

Write-Host '=== 3. Verifying ===' -ForegroundColor Cyan
docker exec ac-database-v2 mysql -uroot -ppassword -e "SELECT name, FROM_UNIXTIME(timestamp) FROM ${TargetDb}.updates WHERE name = '${sqlName}'" 2>`$null

Write-Host '=== 4. Starting ac-worldserver-v2 ===' -ForegroundColor Cyan
docker start ac-worldserver-v2

Write-Host 'Rollback complete.' -ForegroundColor Green
"@ | Set-Content -Path $rollbackPath -Encoding UTF8

# --- 8. Done — print summary ---
Write-Host ''
Write-Host "✅ Deployment package generated:" -ForegroundColor Green
Write-Host "   $pkgDir"
Write-Host ''
Write-Host "Review and apply manually:"
Write-Host "   pwsh `"$applyPath`""
Write-Host ''
Write-Host "Rollback if needed (after apply):"
Write-Host "   pwsh `"$rollbackPath`""
