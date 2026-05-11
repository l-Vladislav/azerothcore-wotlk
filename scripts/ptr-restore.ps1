# Restore PTR-only databases from a snapshot in backups/ptr/.
# DESTRUCTIVE: overwrites the current PTR DBs. Confirms unless -Force.
#
# Usage:
#   pwsh scripts/ptr-restore.ps1 latest
#   pwsh scripts/ptr-restore.ps1 2026-05-11_143022
#   pwsh scripts/ptr-restore.ps1 latest -Force

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position=0)][string]$Snapshot,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

if (-not (Test-Path $PTR_BACKUP_ROOT)) {
    throw "No backups directory at $PTR_BACKUP_ROOT"
}

if ($Snapshot -eq 'latest') {
    $dir = Get-ChildItem -Directory $PTR_BACKUP_ROOT | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $dir) { throw "No snapshots found in $PTR_BACKUP_ROOT" }
} else {
    # Allow either exact dir name or prefix match on timestamp.
    $found = @(Get-ChildItem -Directory $PTR_BACKUP_ROOT | Where-Object { $_.Name -like "$Snapshot*" })
    if ($found.Count -eq 0) { throw "No snapshot matching '$Snapshot' in $PTR_BACKUP_ROOT" }
    if ($found.Count -gt 1) { throw "Ambiguous snapshot '$Snapshot' matches: $($found.Name -join ', ')" }
    $dir = $found[0]
}

Write-Host "Restoring from: $($dir.FullName)"
$manifestPath = Join-Path $dir.FullName 'manifest.json'
if (Test-Path $manifestPath) {
    Get-Content $manifestPath | Write-Host
}

if (-not $Force) {
    $reply = Read-Host "This will DROP+RECREATE $($PTR_ALLOWED_DBS -join ', '). Type 'yes' to continue"
    if ($reply -ne 'yes') { Write-Host "Aborted."; return }
}

# Stop PTR worldserver to avoid in-flight writes during restore.
$ptrRunning = (docker ps --filter "name=$PTR_WORLD_CONTAINER" --format '{{.Names}}') -eq $PTR_WORLD_CONTAINER
if ($ptrRunning) {
    Write-Host "Stopping $PTR_WORLD_CONTAINER ..."
    docker stop $PTR_WORLD_CONTAINER | Out-Null
}

foreach ($db in $PTR_ALLOWED_DBS) {
    Assert-PtrDb -Database $db
    $sqlFile = Join-Path $dir.FullName "$db.sql"
    if (-not (Test-Path $sqlFile)) {
        throw "Snapshot is missing $sqlFile"
    }

    Write-Host "  restoring $db ..."
    & docker exec -i $PTR_DB_CONTAINER mysql `
        -u $PTR_DB_USER "-p$PTR_DB_PASS" `
        --default-character-set=utf8mb4 `
        -e "DROP DATABASE IF EXISTS ``$db``; CREATE DATABASE ``$db`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    if ($LASTEXITCODE -ne 0) { throw "DROP/CREATE failed for $db" }

    Get-Content $sqlFile -Raw | & docker exec -i $PTR_DB_CONTAINER mysql `
        -u $PTR_DB_USER "-p$PTR_DB_PASS" `
        --default-character-set=utf8mb4 `
        $db
    if ($LASTEXITCODE -ne 0) { throw "Import failed for $db" }
}

if ($ptrRunning) {
    Write-Host "Starting $PTR_WORLD_CONTAINER ..."
    docker start $PTR_WORLD_CONTAINER | Out-Null
}

Write-Host "Restore complete."
