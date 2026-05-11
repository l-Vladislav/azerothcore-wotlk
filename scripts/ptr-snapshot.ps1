# Snapshot the PTR-only databases to backups/ptr/<timestamp>/.
# Keeps the most recent $PTR_KEEP_SNAPSHOTS snapshots and prunes the rest.
#
# Usage: pwsh scripts/ptr-snapshot.ps1 [-Label "before-familiar-rework"]

[CmdletBinding()]
param(
    [string]$Label
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$dirName   = if ($Label) { "${timestamp}_$Label" } else { $timestamp }
$dest      = Join-Path $PTR_BACKUP_ROOT $dirName
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "Snapshot -> $dest"

foreach ($db in $PTR_ALLOWED_DBS) {
    Assert-PtrDb -Database $db
    $outFile = Join-Path $dest "$db.sql"
    Write-Host "  dumping $db ..."

    # Stream raw bytes from docker stdout straight to disk — no PS text-mode
    # transcoding, no UTF-8 BOM, exact bytes from mysqldump.
    # --default-character-set=utf8mb4 per project memory (Russian content).
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'docker'
    $psi.Arguments = "exec $PTR_DB_CONTAINER mysqldump -u $PTR_DB_USER -p$PTR_DB_PASS " `
        + '--default-character-set=utf8mb4 ' `
        + '--single-transaction --quick --routines --triggers --skip-lock-tables ' `
        + $db
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $fs = [System.IO.File]::Create($outFile)
    try {
        $proc.StandardOutput.BaseStream.CopyTo($fs)
    } finally {
        $fs.Close()
    }
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
        throw "mysqldump failed for ${db} (exit $($proc.ExitCode)): $stderr"
    }

    $size = (Get-Item $outFile).Length
    Write-Host ("    {0} ({1:N0} bytes)" -f $outFile, $size)
}

# Manifest so the human/agent can read what's in this snapshot.
$manifest = [PSCustomObject]@{
    timestamp = $timestamp
    label     = $Label
    branch    = (git rev-parse --abbrev-ref HEAD 2>$null)
    commit    = (git rev-parse --short HEAD 2>$null)
    databases = $PTR_ALLOWED_DBS
}
$manifest | ConvertTo-Json | Out-File -FilePath (Join-Path $dest 'manifest.json') -Encoding utf8

# Prune: keep the newest $PTR_KEEP_SNAPSHOTS dirs (by name, which is timestamp-sorted).
$all = Get-ChildItem -Directory $PTR_BACKUP_ROOT | Sort-Object Name -Descending
if ($all.Count -gt $PTR_KEEP_SNAPSHOTS) {
    $toDelete = $all | Select-Object -Skip $PTR_KEEP_SNAPSHOTS
    foreach ($d in $toDelete) {
        Write-Host "  prune $($d.Name)"
        Remove-Item -Recurse -Force $d.FullName
    }
}

Write-Host "Snapshot complete: $dirName"
