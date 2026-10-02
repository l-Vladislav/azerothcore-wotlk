# Rebuild the PTR worldserver image. Long-running.
# Use after C++ changes (core / module .cpp). SQL/Lua/.conf-only changes do NOT
# need a rebuild — just ptr-sql-apply.ps1 + ptr-restart.ps1.
#
# Usage:
#   pwsh scripts/ptr-build.ps1
#   pwsh scripts/ptr-build.ps1 -NoCache

[CmdletBinding()]
param(
    [switch]$NoCache
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

# docker writes progress to stderr. Windows PowerShell 5.1 turns redirected
# stderr lines into error records, which abort the script under 'Stop' while
# the build keeps running. Output is passed through as text; success is judged
# by the exit code only.
function Invoke-Docker {
    $ErrorActionPreference = 'Continue'
    & docker @args 2>&1 | ForEach-Object { Write-Host "$_" }
    if ($LASTEXITCODE -ne 0) {
        throw "docker $($args -join ' ') failed (exit $LASTEXITCODE)"
    }
}

$buildArgs = @('compose', '--progress', 'plain', '--profile', 'ptr', 'build')
if ($NoCache) { $buildArgs += '--no-cache' }
$buildArgs += $PTR_WORLD_CONTAINER

Write-Host "docker $($buildArgs -join ' ')"
$ts0 = Get-Date
Invoke-Docker @buildArgs
$elapsed = [int]((Get-Date) - $ts0).TotalSeconds
Write-Host "Build complete in ${elapsed}s."

Write-Host "Bringing up $PTR_WORLD_CONTAINER (no deps) ..."
Invoke-Docker compose --profile ptr up -d --no-deps $PTR_WORLD_CONTAINER

Write-Host "Done. To verify readiness:"
Write-Host "  pwsh scripts/ptr-restart.ps1   # (just `docker restart` — same effect, also waits)"
