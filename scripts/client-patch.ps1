# Build the client MPQ patch from the DBC overlays.
#
# This is now a thin wrapper: the build itself runs in the ac-patch-builder
# container, because that is the only place that has both StormLib and the
# right to write into launcher/cdn. The container keeps its own work directory
# in a docker volume, so there is no second copy of the 92 MB DBC base on the
# host any more.
#
#   scripts\client-patch.ps1 -DryRun      what would change, writes nothing
#   scripts\client-patch.ps1              build, publish, refresh the manifest
#   scripts\client-patch.ps1 -Status      what the last run did
#   scripts\client-patch.ps1 -Bootstrap   re-take the base from the CDN archives
#
# Start the builder first (once):
#   docker compose --profile ptr up -d ac-patch-builder

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoPublish,
    [switch]$NoManifest,
    [switch]$Bootstrap,
    [switch]$Force,
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()

# Loopback on purpose - see the port mapping in docker-compose.override.yml.
$base = 'http://127.0.0.1:8092'
$token = $env:PATCH_BUILDER_TOKEN
$headers = @{}
if ($token) { $headers['X-Builder-Token'] = $token }

function Invoke-Builder {
    param([string]$Path, [string]$Method = 'Get', $Body = $null)
    # Not $args: that is an automatic variable inside a function.
    $req = @{ Uri = "$base$Path"; Method = $Method; Headers = $headers;
              TimeoutSec = 30 }
    if ($null -ne $Body) {
        $req['Body'] = ($Body | ConvertTo-Json -Compress)
        $req['ContentType'] = 'application/json'
    }
    try {
        return Invoke-RestMethod @req
    } catch {
        throw ("Builder not reachable at $base - is it running?" +
               "  docker compose --profile ptr up -d ac-patch-builder" +
               "`n$($_.Exception.Message)")
    }
}

function Show-Log {
    # The build is not interactive, so the log is fetched once it is over
    # rather than streamed; a full run takes about ten seconds.
    $log = Invoke-WebRequest -Uri "$base/log" -Headers $headers -TimeoutSec 30
    [Text.Encoding]::UTF8.GetString($log.RawContentStream.ToArray())
}

function Wait-Build {
    while ($true) {
        $state = Invoke-Builder '/status'
        if (-not $state.running) { return $state }
        Start-Sleep -Seconds 3
    }
}

if ($Status) {
    $state = Invoke-Builder '/status'
    $health = Invoke-Builder '/health'
    $log = Show-Log
    "builder : $base"
    "stormlib: $($health.stormlib)   base ready: $($health.base_ready)"
    if ($state.command) {
        "last run: $($state.command)  started $($state.started)  exit $($state.code)"
    } elseif ($log -match '^\(') {
        # Show-Log returns a parenthesised placeholder when there is no log.
        'last run: never'
    } else {
        # The log lives in the volume, the in-memory state does not: a restart
        # of the container loses the latter but keeps the former.
        'last run: not recorded (builder restarted since) - see the log below'
    }
    ''
    $log
    return
}

if ($Bootstrap) {
    Invoke-Builder '/bootstrap' 'Post' @{ force = [bool]$Force } | Out-Null
} else {
    Invoke-Builder '/build' 'Post' @{
        dry_run     = [bool]$DryRun
        no_publish  = [bool]$NoPublish
        no_manifest = [bool]$NoManifest
    } | Out-Null
}

$final = Wait-Build
Show-Log

if ($final.code -ne 0) {
    Write-Error "Build failed (exit $($final.code))."
}
