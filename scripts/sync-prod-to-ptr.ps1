# Sync the prod world+characters DBs into their PTR copies.
#
# !!! USER-RUN, NOT AGENT-RUN !!!
# This script touches the prod databases (acore_world, acore_characters)
# — the agent permission policy explicitly denies these. The script is here
# for the human to run manually when prod has diverged from PTR and we want
# a fresh baseline.
#
# What it does:
#   1) Stops ac-worldserver-ptr (to avoid in-flight writes).
#   2) Snapshots the current PTR state (so this sync itself is reversible).
#   3) For each of (acore_world, acore_characters):
#        DROP+CREATE the _ptr copy
#        mysqldump prod | mysql _ptr   (streamed inside the DB container,
#        so 480MB doesn't go through the Windows host)
#   4) Starts ac-worldserver-ptr.
#
# Usage:
#   pwsh scripts/sync-prod-to-ptr.ps1            # confirms before each step
#   pwsh scripts/sync-prod-to-ptr.ps1 -Force     # no prompts

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

$pairs = @(
    @{ Prod = 'acore_world';      Ptr = $PTR_DB_WORLD },
    @{ Prod = 'acore_characters'; Ptr = $PTR_DB_CHARS }
)

Write-Host "This will OVERWRITE the following PTR databases with prod data:"
foreach ($p in $pairs) {
    Write-Host ("  {0}  <-  {1}" -f $p.Ptr, $p.Prod)
}
Write-Host ""
if (-not $Force) {
    $reply = Read-Host "Type 'yes' to continue"
    if ($reply -ne 'yes') { Write-Host "Aborted."; return }
}

# --- 1. stop PTR worldserver ---
# Match the exact container name with an anchored regex — the previous
# `-eq` comparison against `--format '{{.Names}}'` was brittle (trailing
# whitespace/newline made it return false), letting the script proceed to
# DROP DATABASE while PTR was still using it (SIGKILL on shutdown).
$ptrRunning = [bool](docker ps --quiet --filter "name=^${PTR_WORLD_CONTAINER}$")
if ($ptrRunning) {
    Write-Host "Stopping $PTR_WORLD_CONTAINER ..."
    docker stop $PTR_WORLD_CONTAINER | Out-Null
} else {
    Write-Host "$PTR_WORLD_CONTAINER not running — proceeding."
}

# --- 2. snapshot current PTR (safety net) ---
Write-Host "Snapshotting current PTR state ..."
& "$PSScriptRoot\ptr-snapshot.ps1" -Label "before-prod-sync"

# --- 3. dump + restore per pair, all inside the DB container ---
# Running mysqldump | mysql inside the container avoids streaming the full
# dump through the host. Use `sh -c` so the pipe stays in-container.
foreach ($p in $pairs) {
    Assert-PtrDb -Database $p.Ptr
    Write-Host ""
    Write-Host "===== $($p.Prod) -> $($p.Ptr) ====="

    Write-Host "  DROP+CREATE $($p.Ptr) ..."
    & docker exec $PTR_DB_CONTAINER mysql `
        -u $PTR_DB_USER "-p$PTR_DB_PASS" `
        --default-character-set=utf8mb4 `
        -e "DROP DATABASE IF EXISTS ``$($p.Ptr)``; CREATE DATABASE ``$($p.Ptr)`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    if ($LASTEXITCODE -ne 0) { throw "DROP/CREATE failed for $($p.Ptr)" }

    Write-Host "  mysqldump $($p.Prod) | mysql $($p.Ptr) (in-container) ..."
    $shCmd = "mysqldump -u$PTR_DB_USER -p$PTR_DB_PASS --default-character-set=utf8mb4 --single-transaction --quick --routines --triggers --skip-lock-tables '$($p.Prod)' | mysql -u$PTR_DB_USER -p$PTR_DB_PASS --default-character-set=utf8mb4 '$($p.Ptr)'"
    & docker exec $PTR_DB_CONTAINER sh -c $shCmd
    if ($LASTEXITCODE -ne 0) { throw "Sync failed for $($p.Prod) -> $($p.Ptr) (exit $LASTEXITCODE)" }

    Write-Host "  done."
}

# --- 4. start PTR worldserver back up ---
if ($ptrRunning) {
    Write-Host ""
    Write-Host "Starting $PTR_WORLD_CONTAINER ..."
    docker start $PTR_WORLD_CONTAINER | Out-Null
    Write-Host "Tip: pwsh scripts/ptr-restart.ps1   # wait for it to be ready"
}

Write-Host ""
Write-Host "Sync complete."
