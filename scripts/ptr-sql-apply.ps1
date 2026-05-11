# Apply one or more SQL files to the PTR DBs.
# Files MUST live under data/sql/updates/pending_db_world/ or
# .../pending_db_characters/ — the directory determines the target DB.
# Anything else is refused (no arbitrary paths).
#
# Usage:
#   pwsh scripts/ptr-sql-apply.ps1 data/sql/updates/pending_db_world/foo.sql
#   pwsh scripts/ptr-sql-apply.ps1 -All
#   pwsh scripts/ptr-sql-apply.ps1 -DryRun foo.sql

[CmdletBinding()]
param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)][string[]]$Files,
    [switch]$All,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

function Resolve-PendingFile {
    param([string]$Path)

    # Normalize to absolute, resolve symlinks etc.
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $repoFull = (Resolve-Path -LiteralPath $PTR_REPO_ROOT).Path

    if (-not $resolved.StartsWith($repoFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "File is outside the repo: $resolved"
    }

    # Path inside repo, using forward slashes for matching against PTR_PENDING_MAP.
    $rel = $resolved.Substring($repoFull.Length).TrimStart('\','/') -replace '\\','/'

    foreach ($prefix in $PTR_PENDING_MAP.Keys) {
        if ($rel.StartsWith("$prefix/", [StringComparison]::OrdinalIgnoreCase)) {
            return @{
                AbsPath  = $resolved
                RelPath  = $rel
                Database = $PTR_PENDING_MAP[$prefix]
            }
        }
    }
    throw ("Refusing '$rel'. Files must live under one of: " +
        ($PTR_PENDING_MAP.Keys -join ', '))
}

# Build the file list.
$targets = @()
if ($All) {
    foreach ($prefix in $PTR_PENDING_MAP.Keys) {
        $dir = Join-Path $PTR_REPO_ROOT $prefix
        if (Test-Path $dir) {
            Get-ChildItem -File -Filter *.sql $dir | Sort-Object Name | ForEach-Object {
                $targets += (Resolve-PendingFile -Path $_.FullName)
            }
        }
    }
    if ($targets.Count -eq 0) { Write-Host "No pending SQL files found."; return }
} else {
    if (-not $Files) { throw "No files given. Pass paths or -All." }
    foreach ($f in $Files) {
        $targets += (Resolve-PendingFile -Path $f)
    }
}

Write-Host ("Will apply {0} file(s) to PTR:" -f $targets.Count)
foreach ($t in $targets) {
    Write-Host ("  {0,-26} <- {1}" -f $t.Database, $t.RelPath)
}
if ($DryRun) { Write-Host "Dry run — exiting."; return }

foreach ($t in $targets) {
    Assert-PtrDb -Database $t.Database
    Write-Host "applying $($t.RelPath) -> $($t.Database) ..."

    # Stream the file in via stdin to avoid mysql's source-file path issues
    # and so we hit utf8mb4 on the connection (Russian content).
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'docker'
    $psi.Arguments = "exec -i $PTR_DB_CONTAINER mysql -u $PTR_DB_USER -p$PTR_DB_PASS --default-character-set=utf8mb4 $($t.Database)"
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        # Pipe SQL file bytes straight to mysql stdin — no PS text transcoding.
        $fs = [System.IO.File]::OpenRead($t.AbsPath)
        try { $fs.CopyTo($proc.StandardInput.BaseStream) } finally { $fs.Close() }
        $proc.StandardInput.Close()
    } catch {
        $proc.Kill() | Out-Null
        throw
    }

    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    if ($stdout) { $stdout.TrimEnd() | Write-Host }
    # mysql warnings come on stderr — only treat non-zero exit as failure.
    if ($proc.ExitCode -ne 0) {
        if ($stderr) { Write-Host "STDERR: $stderr" -ForegroundColor Red }
        throw "mysql failed for $($t.RelPath) (exit $($proc.ExitCode))"
    }
    if ($stderr) {
        # Surface warnings but don't fail.
        Write-Host "  warnings: $($stderr.TrimEnd())" -ForegroundColor Yellow
    }
    Write-Host "  ok"
}

Write-Host "Apply complete. Restart PTR worldserver to pick up DBC/cached changes:"
Write-Host "  pwsh scripts/ptr-restart.ps1"
