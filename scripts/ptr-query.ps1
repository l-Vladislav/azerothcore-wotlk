# Read-only query helper for PTR DBs. Refuses anything that isn't
# SELECT/SHOW/DESCRIBE/EXPLAIN/USE. Use for verification after SQL apply.
#
# Pattern: agents construct a "violation query" — SELECT rows that BREAK
# the expected condition. Empty result = pass. Any row = failure with that
# row printed for diagnosis.
#
# Usage:
#   pwsh scripts/ptr-query.ps1 -Database acore_world_ptr -Query "SELECT * FROM spell_dbc WHERE ID=100032"
#   pwsh scripts/ptr-query.ps1 -Database acore_world_ptr -File queries/blood_pact_violations.sql
#   pwsh scripts/ptr-query.ps1 -Database acore_world_ptr -Query "..." -ExpectEmpty
#
# Exit code:
#   0 — query ran (and matched -ExpectEmpty if set)
#   1 — query failed or assertion mismatch

[CmdletBinding(DefaultParameterSetName='Inline')]
param(
    [Parameter(Mandatory)][string]$Database,
    [Parameter(Mandatory, ParameterSetName='Inline')][string]$Query,
    [Parameter(Mandatory, ParameterSetName='File')][string]$File,
    [switch]$ExpectEmpty
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

Assert-PtrDb -Database $Database

# Resolve the query text.
if ($PSCmdlet.ParameterSetName -eq 'File') {
    if (-not (Test-Path $File)) { throw "Query file not found: $File" }
    $Query = Get-Content $File -Raw
}

# Read-only gate. Strip comments + whitespace, then check the first keyword.
# This is a heuristic, not a sandbox — the deny rules in settings.local.json
# are the real wall. But this catches honest mistakes (apply via -Query).
$normalized = ($Query -replace '/\*.*?\*/','' -replace '--[^\n]*','' -replace '\s+',' ').Trim()
$allowedFirst = @('SELECT', 'SHOW', 'DESCRIBE', 'DESC', 'EXPLAIN', 'USE')
$firstWord = ($normalized -split '\s+', 2)[0].ToUpperInvariant()
if ($firstWord -notin $allowedFirst) {
    throw "Refusing non-read-only query (starts with '$firstWord'). Allowed: $($allowedFirst -join ', ')"
}
# Also refuse anything that contains a write keyword anywhere, as defense in
# depth against compound statements ("SELECT 1; DROP TABLE x").
$banned = '\b(INSERT|UPDATE|DELETE|REPLACE|DROP|ALTER|CREATE|TRUNCATE|RENAME|GRANT|REVOKE|LOAD|HANDLER|CALL|LOCK|UNLOCK|FLUSH|RESET|SET\s+(?:GLOBAL|SESSION|PASSWORD)|INTO\s+OUTFILE|INTO\s+DUMPFILE)\b'
if ($normalized -match $banned) {
    throw "Refusing query — contains a write/admin keyword. Use ptr-sql-apply.ps1 for mutations."
}

# Run via docker exec. -B = batch/tab-separated, -N = no column headers? we want headers.
# Use -B (batch) for tab-separated, no fancy formatting.
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'docker'
$psi.Arguments = "exec -i $PTR_DB_CONTAINER mysql -u $PTR_DB_USER -p$PTR_DB_PASS --default-character-set=utf8mb4 -B $Database"
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow  = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$proc.StandardInput.Write($Query)
$proc.StandardInput.Close()

$stdout = $proc.StandardOutput.ReadToEnd()
$stderr = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()

if ($proc.ExitCode -ne 0) {
    if ($stderr) { Write-Host "STDERR: $stderr" -ForegroundColor Red }
    throw "mysql failed (exit $($proc.ExitCode))"
}

# In -B mode, stdout is: header line (TSV) + zero or more data rows.
$lines = $stdout -split "`r?`n" | Where-Object { $_ -ne '' }
$dataRows = if ($lines.Count -gt 1) { $lines[1..($lines.Count - 1)] } else { @() }

if ($lines.Count -gt 0) { Write-Host $lines[0] }
foreach ($r in $dataRows) { Write-Host $r }

if ($ExpectEmpty) {
    if ($dataRows.Count -eq 0) {
        Write-Host "`nASSERTION OK: query returned 0 rows." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`nASSERTION FAILED: expected 0 rows, got $($dataRows.Count)." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n$($dataRows.Count) row(s)."
