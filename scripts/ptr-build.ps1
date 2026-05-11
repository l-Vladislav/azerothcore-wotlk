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

$buildArgs = @('compose', '--profile', 'ptr', 'build')
if ($NoCache) { $buildArgs += '--no-cache' }
$buildArgs += $PTR_WORLD_CONTAINER

Write-Host "docker $($buildArgs -join ' ')"
$ts0 = Get-Date
& docker @buildArgs
if ($LASTEXITCODE -ne 0) {
    throw "Build failed (exit $LASTEXITCODE)"
}
$elapsed = [int]((Get-Date) - $ts0).TotalSeconds
Write-Host "Build complete in ${elapsed}s."

Write-Host "Bringing up $PTR_WORLD_CONTAINER (no deps) ..."
& docker compose --profile ptr up -d --no-deps $PTR_WORLD_CONTAINER
if ($LASTEXITCODE -ne 0) {
    throw "Compose up failed (exit $LASTEXITCODE)"
}

Write-Host "Done. To verify readiness:"
Write-Host "  pwsh scripts/ptr-restart.ps1   # (just `docker restart` — same effect, also waits)"
