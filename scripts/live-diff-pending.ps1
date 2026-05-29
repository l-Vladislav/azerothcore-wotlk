# Show SQL updates that have been applied to PTR but NOT to live (or modified after live apply).
# Read-only — safe for agent and human alike.
#
# Output: list of SQL filenames pending promotion to live, with last-applied timestamps and hashes.
#
# Usage:
#   pwsh scripts/live-diff-pending.ps1
#   pwsh scripts/live-diff-pending.ps1 -Database world      # only acore_world (default = both world+characters)
#   pwsh scripts/live-diff-pending.ps1 -Verbose             # show matched (already-promoted) too

[CmdletBinding()]
param(
    [ValidateSet('world', 'characters', 'both')]
    [string]$Database = 'both'
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

function Invoke-Mysql([string]$Query) {
    # Use System.Diagnostics.Process to bypass PowerShell's native-command-stderr handling.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'docker'
    $psi.Arguments = "exec -i $PTR_DB_CONTAINER mysql -u $PTR_DB_USER -p$PTR_DB_PASS --default-character-set=utf8mb4 -B"
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Write($Query)
    $proc.StandardInput.Close()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit() | Out-Null
    return $stdout
}

function Show-Diff([string]$ProdDb, [string]$PtrDb) {
    $query = @"
SELECT
    ptr.name        AS name,
    ptr.hash        AS ptr_hash,
    IFNULL(live.hash, '<absent>') AS live_hash,
    FROM_UNIXTIME(ptr.timestamp) AS ptr_applied,
    IFNULL(FROM_UNIXTIME(live.timestamp), '<never>') AS live_applied,
    CASE
        WHEN live.name IS NULL THEN 'NEW'
        WHEN ptr.hash != live.hash THEN 'MODIFIED'
        ELSE 'IN_SYNC'
    END AS status
FROM ${PtrDb}.updates ptr
LEFT JOIN ${ProdDb}.updates live ON ptr.name = live.name
ORDER BY ptr.timestamp DESC;
"@

    Write-Host ""
    Write-Host "=== Diff: $PtrDb -> $ProdDb ===" -ForegroundColor Cyan

    $output = Invoke-Mysql -Query $query
    $lines = $output -split "`r?`n" | Where-Object { $_ -ne '' }

    if ($lines.Count -lt 2) {
        Write-Host "  (no rows returned - DB or query issue)" -ForegroundColor Red
        return
    }

    # Print header
    Write-Host $lines[0]

    $pending = 0
    foreach ($line in $lines[1..($lines.Count - 1)]) {
        if ($line -match 'NEW\s*$') {
            Write-Host $line -ForegroundColor Yellow
            $pending++
        } elseif ($line -match 'MODIFIED\s*$') {
            Write-Host $line -ForegroundColor Magenta
            $pending++
        } elseif ($VerbosePreference -eq 'Continue') {
            Write-Host $line -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    if ($pending -eq 0) {
        Write-Host "  OK No pending changes for $ProdDb" -ForegroundColor Green
    } else {
        Write-Host "  ! $pending file(s) pending promotion to $ProdDb" -ForegroundColor Yellow
    }
}

if ($Database -in 'world', 'both')      { Show-Diff -ProdDb 'acore_world'      -PtrDb $PTR_DB_WORLD }
if ($Database -in 'characters', 'both') { Show-Diff -ProdDb 'acore_characters' -PtrDb $PTR_DB_CHARS }

Write-Host ""
Write-Host "To promote a file, run:"
Write-Host "  pwsh scripts/live-deploy-package.ps1 -SqlFile data/sql/updates/pending_db_world/<filename>.sql"
