# PTR identity. Source this from any PTR script:
#   . "$PSScriptRoot\ptr.env.ps1"
# Edit here if container/DB names change — never hard-code elsewhere.

$script:PTR_DB_CONTAINER     = 'ac-database-v2'
$script:PTR_WORLD_CONTAINER  = 'ac-worldserver-ptr'
$script:PTR_DB_WORLD         = 'acore_world_ptr'
$script:PTR_DB_CHARS         = 'acore_characters_ptr'
$script:PTR_DB_USER          = 'root'
$script:PTR_DB_PASS          = if ($env:DOCKER_DB_ROOT_PASSWORD) { $env:DOCKER_DB_ROOT_PASSWORD } else { 'password' }

# Repo root = parent of this script's dir.
$script:PTR_REPO_ROOT        = (Resolve-Path "$PSScriptRoot\..").Path
$script:PTR_BACKUP_ROOT      = Join-Path $script:PTR_REPO_ROOT 'backups\ptr'
$script:PTR_KEEP_SNAPSHOTS   = 5

# Hard list of DBs the agent is allowed to touch via PTR wrappers.
$script:PTR_ALLOWED_DBS      = @($script:PTR_DB_WORLD, $script:PTR_DB_CHARS)

# Pending-SQL directories the apply script accepts, mapped to their target DB.
$script:PTR_PENDING_MAP = @{
    'data/sql/updates/pending_db_world'      = $script:PTR_DB_WORLD
    'data/sql/updates/pending_db_characters' = $script:PTR_DB_CHARS
}

# Host-side log dir (bind-mounted into the PTR container).
$script:PTR_LOGS_DIR         = Join-Path $script:PTR_REPO_ROOT 'env\dist\logs'
$script:PTR_SERVER_LOG       = Join-Path $script:PTR_LOGS_DIR 'Server.log'
$script:PTR_ERRORS_LOG       = Join-Path $script:PTR_LOGS_DIR 'Errors.log'

# Knowledge dirs scanned by ptr-sql-apply.ps1 for relevant warnings before
# applying SQL. Claude Code stores project memory under
# %USERPROFILE%\.claude\projects\<projectKey>\memory where <projectKey> is
# the absolute repo path with the drive letter lowercased, `:` -> `-`,
# `\` -> `-`. E.g. D:\Projects\... -> d--Projects-...
$_drive  = $script:PTR_REPO_ROOT.Substring(0,1).ToLower()
$_tail   = $script:PTR_REPO_ROOT.Substring(1) -replace ':','-' -replace '\\','-'
$_projKey = "${_drive}${_tail}"
$script:PTR_MEMORY_DIR       = Join-Path $env:USERPROFILE ".claude\projects\$_projKey\memory"
$script:PTR_KNOWLEDGE_DIRS   = @(
    $script:PTR_MEMORY_DIR,
    (Join-Path $script:PTR_REPO_ROOT '.claude')
)

function Assert-PtrDb {
    param([Parameter(Mandatory)][string]$Database)
    if ($script:PTR_ALLOWED_DBS -notcontains $Database) {
        throw "Refusing to operate on '$Database'. Allowed: $($script:PTR_ALLOWED_DBS -join ', ')"
    }
}
