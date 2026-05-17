# Sync the local mod-playerbots fork with the upstream original repo.
#
# Layout assumed:
#   modules/mod-playerbots/  is a standalone git clone (not a submodule)
#     origin   -> your fork (e.g. https://github.com/<you>/mod-playerbots.git)
#     upstream -> the original (https://github.com/mod-playerbots/mod-playerbots.git)
#
# Default behaviour:
#   1. fetch upstream
#   2. print commits that are on upstream/master but not on your current branch
#   3. attempt a merge of upstream/master into the current branch
#   4. on conflict, leave the tree in conflict state and report which files need attention
#   5. on success, leave the merge committed locally — does NOT push
#
# Flags:
#   -Branch <name>   sync into this branch instead of the current one (will checkout)
#   -Rebase          rebase your branch on upstream/master instead of merging
#   -DryRun          fetch + report only, do not modify the working tree
#   -Push            push the resulting branch to origin after a successful sync

[CmdletBinding()]
param(
    [string]$Branch,
    [switch]$Rebase,
    [switch]$DryRun,
    [switch]$Push
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\ptr.env.ps1"

$modDir = Join-Path $script:PTR_REPO_ROOT 'modules\mod-playerbots'
if (-not (Test-Path $modDir)) {
    throw "mod-playerbots clone not found at $modDir"
}

Push-Location $modDir
try {
    # Sanity-check both remotes exist.
    $remotes = git remote
    if ($remotes -notcontains 'origin')   { throw "Remote 'origin' is missing in $modDir" }
    if ($remotes -notcontains 'upstream') { throw "Remote 'upstream' is missing. Add it with: git -C `"$modDir`" remote add upstream https://github.com/mod-playerbots/mod-playerbots.git" }

    # Refuse to operate on a dirty tree (avoid clobbering unstaged work).
    $dirty = git status --porcelain
    if ($dirty) {
        Write-Host "Working tree has uncommitted changes:" -ForegroundColor Yellow
        Write-Host $dirty
        throw "Commit or stash your changes in mod-playerbots before syncing."
    }

    # Resolve target branch.
    $currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
    if (-not $Branch) { $Branch = $currentBranch }
    if ($Branch -ne $currentBranch) {
        Write-Host "Checking out '$Branch'..."
        git checkout $Branch
    }

    Write-Host "Fetching upstream..."
    git fetch upstream --prune

    # Detect the upstream's default branch (master vs main).
    $upstreamHead = git remote show upstream | Select-String 'HEAD branch:' | ForEach-Object {
        ($_ -split ':')[1].Trim()
    }
    if (-not $upstreamHead) { $upstreamHead = 'master' }
    $upstreamRef = "upstream/$upstreamHead"

    $ahead  = (git rev-list --count "$Branch..$upstreamRef").Trim()
    $behind = (git rev-list --count "$upstreamRef..$Branch").Trim()

    Write-Host ""
    Write-Host "=== Sync status ===" -ForegroundColor Cyan
    Write-Host "Local branch     : $Branch"
    Write-Host "Upstream ref     : $upstreamRef"
    Write-Host "New on upstream  : $ahead commit(s)"
    Write-Host "Local-only       : $behind commit(s)"
    Write-Host ""

    if ([int]$ahead -eq 0) {
        Write-Host "Already up to date." -ForegroundColor Green
        return
    }

    Write-Host "New upstream commits to be merged:" -ForegroundColor Cyan
    git log "$Branch..$upstreamRef" --oneline --no-decorate | ForEach-Object { Write-Host "  $_" }
    Write-Host ""

    if ($DryRun) {
        Write-Host "DryRun: nothing changed." -ForegroundColor Yellow
        return
    }

    if ($Rebase) {
        Write-Host "Rebasing $Branch onto $upstreamRef..." -ForegroundColor Cyan
        $code = 0
        git rebase $upstreamRef
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Host ""
            Write-Host "Rebase paused on conflicts. Resolve, then:" -ForegroundColor Yellow
            Write-Host "  git -C `"$modDir`" add <files>"
            Write-Host "  git -C `"$modDir`" rebase --continue"
            Write-Host "Or abort: git -C `"$modDir`" rebase --abort"
            throw "rebase incomplete"
        }
        Write-Host "Rebase completed cleanly." -ForegroundColor Green
    } else {
        Write-Host "Merging $upstreamRef into $Branch..." -ForegroundColor Cyan
        $code = 0
        git merge --no-edit $upstreamRef
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Host ""
            Write-Host "Merge halted on conflicts. Conflicting files:" -ForegroundColor Yellow
            git diff --name-only --diff-filter=U | ForEach-Object { Write-Host "  $_" }
            Write-Host ""
            Write-Host "Resolve, then:"
            Write-Host "  git -C `"$modDir`" add <files>"
            Write-Host "  git -C `"$modDir`" commit"
            Write-Host "Or abort: git -C `"$modDir`" merge --abort"
            throw "merge incomplete"
        }
        Write-Host "Merge completed cleanly." -ForegroundColor Green
    }

    if ($Push) {
        Write-Host "Pushing $Branch to origin..." -ForegroundColor Cyan
        git push origin $Branch
    } else {
        Write-Host ""
        Write-Host "Sync committed locally. Push with:" -ForegroundColor Yellow
        Write-Host "  git -C `"$modDir`" push origin $Branch"
    }

    Write-Host ""
    Write-Host "Next: rebuild PTR so the new code takes effect:" -ForegroundColor Yellow
    Write-Host "  scripts\ptr-build.ps1"
}
finally {
    Pop-Location
}
