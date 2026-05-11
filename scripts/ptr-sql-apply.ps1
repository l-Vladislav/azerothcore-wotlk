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
    [switch]$DryRun,
    # Skip the pre-flight knowledge scan. Set this AFTER you have READ the
    # warnings and decided to apply anyway. Never default this to true.
    [switch]$IKnow
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\ptr.env.ps1"

function Get-AffectedTables {
    # Pull table names out of INSERT/REPLACE/UPDATE/DELETE statements.
    param([string]$SqlPath)
    $sql = Get-Content -LiteralPath $SqlPath -Raw
    # Strip comments to avoid false positives from doc text in headers.
    $sql = $sql -replace '/\*[\s\S]*?\*/','' -replace '(?m)--[^\n]*',''
    $pat = '(?im)(?:INSERT\s+INTO|REPLACE\s+INTO|UPDATE|DELETE\s+FROM)\s+`?(\w+)`?'
    $names = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($m in [regex]::Matches($sql, $pat)) {
        [void]$names.Add($m.Groups[1].Value.ToLower())
    }
    return @($names)
}

function Find-RelatedKnowledge {
    # Look across PTR_KNOWLEDGE_DIRS for any *.md file whose contents mention
    # the SQL file's basename OR any affected table name. Returns matches
    # grouped by file with the matching line and a short snippet.
    param([string]$SqlPath, [string[]]$Tables)

    $basename = [System.IO.Path]::GetFileName($SqlPath)
    # The "interesting" terms — basename first so it gets shown prominently.
    $terms = @($basename) + $Tables | Where-Object { $_ } | Sort-Object -Unique
    if ($terms.Count -eq 0) { return @() }

    # Build a single regex (escaped, OR-joined, word-bounded for tables).
    $escaped = $terms | ForEach-Object { [regex]::Escape($_) }
    $pattern = '(?i)(' + ($escaped -join '|') + ')'

    $hits = @()
    foreach ($root in $PTR_KNOWLEDGE_DIRS) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.md -ErrorAction SilentlyContinue | ForEach-Object {
            $i = 0
            foreach ($line in (Get-Content -LiteralPath $_.FullName)) {
                $i++
                if ($line -match $pattern) {
                    $hits += [PSCustomObject]@{
                        File    = $_.FullName
                        Line    = $i
                        Snippet = $line.Trim()
                        Term    = $matches[1]
                    }
                }
            }
        }
    }
    return $hits
}

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
# ── Pre-flight knowledge scan ─────────────────────────────────────────
# Look for memory/docs entries mentioning each file's basename or the
# tables it touches. This exists because the agent has burned PTR by
# applying SQL files that had documented bugs/workarounds in memory
# that were not consulted first. Refuse to proceed if hits exist, unless
# -IKnow is passed (which means: yes, I have read them).
# In -DryRun mode, the check is informational only — warnings print but
# we still exit cleanly without applying.
$totalHits = 0
if (-not $IKnow) {
    foreach ($t in $targets) {
        $tables = Get-AffectedTables -SqlPath $t.AbsPath
        $hits   = Find-RelatedKnowledge -SqlPath $t.AbsPath -Tables $tables
        if ($hits.Count -gt 0) {
            $totalHits += $hits.Count
            Write-Host ""
            Write-Host "⚠  $($t.RelPath)" -ForegroundColor Yellow
            Write-Host "   tables touched: $($tables -join ', ')" -ForegroundColor DarkYellow
            $hits | Group-Object File | ForEach-Object {
                $rel = [System.IO.Path]::GetFileName($_.Name)
                Write-Host "   $rel" -ForegroundColor Yellow
                $_.Group | Select-Object -First 5 | ForEach-Object {
                    $snip = if ($_.Snippet.Length -gt 110) { $_.Snippet.Substring(0,110) + '…' } else { $_.Snippet }
                    Write-Host ("     :{0,-4} [{1}] {2}" -f $_.Line, $_.Term, $snip)
                }
                if ($_.Count -gt 5) {
                    Write-Host ("     ... and $($_.Count - 5) more matches in this file")
                }
            }
        }
    }
    if ($totalHits -gt 0) {
        Write-Host ""
        Write-Host "Knowledge-check FOUND $totalHits warning(s) above." -ForegroundColor Red
        Write-Host "READ them, then re-run with -IKnow to proceed." -ForegroundColor Red
        Write-Host "Scanned: $($PTR_KNOWLEDGE_DIRS -join '; ')" -ForegroundColor DarkGray
    } else {
        Write-Host "Knowledge-check: no warnings found." -ForegroundColor DarkGray
    }
}

if ($DryRun) { Write-Host "Dry run — exiting."; return }
if ($totalHits -gt 0 -and -not $IKnow) {
    throw "Refusing to apply until knowledge-check is acknowledged. Re-run with -IKnow."
}

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
