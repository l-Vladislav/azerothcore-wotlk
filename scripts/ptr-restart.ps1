# Restart the PTR worldserver and wait for the "World initialized" signal in
# Server.log. Exits non-zero on timeout.
#
# Usage:
#   pwsh scripts/ptr-restart.ps1
#   pwsh scripts/ptr-restart.ps1 -TimeoutSec 180

[CmdletBinding()]
param(
    [int]$TimeoutSec = 120
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

# Pattern that worldserver prints once initialization is done.
# Common forms across AC builds: "World initialized in", "World initialized."
$readyPattern = 'World initialized'

function Get-ReadyCount {
    if (-not (Test-Path $PTR_SERVER_LOG)) { return 0 }
    # Open with shared read/write so we don't fight AC's writer.
    $fs = [System.IO.File]::Open($PTR_SERVER_LOG, 'Open', 'Read', 'ReadWrite')
    try {
        $reader = New-Object System.IO.StreamReader($fs)
        $content = $reader.ReadToEnd()
        $reader.Close()
    } finally {
        $fs.Close()
    }
    return ([regex]::Matches($content, $readyPattern, 'IgnoreCase')).Count
}

# Count "World Initialized" occurrences BEFORE restart — works regardless of
# whether AC truncates Server.log on startup or appends to it.
$preCount = Get-ReadyCount
Write-Host "Pre-restart ready-marker count: $preCount"

Write-Host "Restarting $PTR_WORLD_CONTAINER ..."
$ts0 = Get-Date
& docker restart $PTR_WORLD_CONTAINER | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "docker restart failed (exit $LASTEXITCODE). Is the container created? Try: docker compose --profile ptr up -d ac-worldserver-ptr"
}

Write-Host "Waiting for new '$readyPattern' marker (timeout ${TimeoutSec}s) ..."
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$found = $false
# AC truncates Server.log on startup, so the marker count goes preCount -> 0 -> 1.
# Track whether we've observed a truncation (count dropping below preCount).
# Once seen, any subsequent count >= 1 means the new init line was printed.
$sawTruncation = ($preCount -eq 0)  # if pre was already 0, no truncation needed

while ((Get-Date) -lt $deadline) {
    $curCount = Get-ReadyCount
    if (-not $sawTruncation -and $curCount -lt $preCount) {
        $sawTruncation = $true
    }
    if ($sawTruncation -and $curCount -ge 1) { $found = $true; break }
    # Append-only case (no truncation): count strictly increases past preCount.
    if ($curCount -gt $preCount) { $found = $true; break }

    # Detect early container death so we don't wait forever.
    $state = (docker inspect -f '{{.State.Status}}' $PTR_WORLD_CONTAINER 2>$null)
    if ($state -and $state -notin @('running','restarting','created')) {
        throw "Container $PTR_WORLD_CONTAINER is in state '$state'. Check logs."
    }

    Start-Sleep -Milliseconds 1000
}

$elapsed = [int]((Get-Date) - $ts0).TotalSeconds
if (-not $found) {
    throw "Timed out after ${elapsed}s waiting for '$readyPattern'. Container may still be starting; check $PTR_SERVER_LOG."
}
Write-Host "Ready in ${elapsed}s."
