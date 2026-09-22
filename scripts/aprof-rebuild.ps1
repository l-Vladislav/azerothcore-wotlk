# Пересборка содержимого mod-advanced-professions одной командой.
#
# ЗАЧЕМ. Сетка основ перенумеровывает рецепты и основы на каждом прогоне, и всё,
# что на них ссылается, обязано пересобраться следом. Цепочка из десяти звеньев
# держалась на памяти - и один раз уже порвалась: генератор чертежей (v33) не
# входил в список, и 116 рецептов стояли без чертежей неизвестно сколько, пока
# это не нашлось случайной проверкой.
#
# Порядок звеньев не произволен:
#
#   v47  общие словари        - мусор игры и веса статов, на них смотрят все
#   v32  сетка основ          - заводит `ap_band`, рецепты и ступени
#   v33  чертежи основ        - берут имена у рецептов, значит после сетки
#   v42  величина вставок     - считает по `ap_band` и стрижке, заполняет
#                               `ap_band_value`
#   v43  свои камни           - берут величину из `ap_band_value`
#   v45  доля ремесла         - решает по готовому справочнику материалов
#   v36  эскизы               - собираются из ВКЛЮЧЁННЫХ материалов
#   v46  ступени по эскизам   - снимает ступени, которым некуда вести
#   v38  геройские заготовки  - смотрят, какие призы уже заняты эскизами
#   v40  книги эскизов        - книга на каждый эскиз, обоих родов
#   v44  добыча               - раскладывает заготовки, книги и чертежи по миру
#
# Usage:
#   pwsh scripts/aprof-rebuild.ps1            # вся цепочка и перезапуск PTR
#   pwsh scripts/aprof-rebuild.ps1 -NoRestart # без перезапуска
#   pwsh scripts/aprof-rebuild.ps1 -From v36  # начиная с указанного звена

[CmdletBinding()]
param(
    [switch]$NoRestart,
    [string]$From
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sqlDir = Join-Path $root 'data\sql\updates\pending_db_world'
$tools  = Join-Path $root 'modules\mod-advanced-professions\tools'

# Звено: имя, генератор (может отсутствовать), миграция.
$chain = @(
    @{ name = 'v47'; gen = $null;                   sql = 'mod_advanced_professions_v47_shared_dicts.sql' },
    @{ name = 'v32'; gen = $null;                   sql = 'mod_advanced_professions_v32_grid_all_types.sql' },
    @{ name = 'v33'; gen = $null;                   sql = 'mod_advanced_professions_v33_recipe_books.sql' },
    @{ name = 'v42'; gen = $null;                   sql = 'mod_advanced_professions_v42_insert_by_band.sql' },
    @{ name = 'v43'; gen = 'gen-own-materials.py';  sql = 'mod_advanced_professions_v43_own_materials.sql' },
    @{ name = 'v45'; gen = $null;                   sql = 'mod_advanced_professions_v45_drops_majority.sql' },
    @{ name = 'v36'; gen = 'gen-synergies.py';      sql = 'mod_advanced_professions_v36_synergies.sql' },
    @{ name = 'v46'; gen = $null;                   sql = 'mod_advanced_professions_v46_steps_by_sketches.sql' },
    @{ name = 'v38'; gen = 'gen-heroic-bases.py';   sql = 'mod_advanced_professions_v38_heroic_bases.sql' },
    @{ name = 'v40'; gen = 'gen-synergy-books.py';  sql = 'mod_advanced_professions_v40_synergy_books.sql' },
    @{ name = 'v44'; gen = $null;                   sql = 'mod_advanced_professions_v44_loot.sql' }
)

if ($From) {
    $idx = [array]::FindIndex([object[]]$chain, [Predicate[object]]{ param($x) $x.name -eq $From })
    if ($idx -lt 0) { throw "Нет такого звена: $From" }
    $chain = $chain[$idx..($chain.Count - 1)]
}

$started = Get-Date
foreach ($link in $chain) {
    Write-Host ''
    Write-Host "=== $($link.name) ===" -ForegroundColor Cyan

    if ($link.gen) {
        $genPath = Join-Path $tools $link.gen
        Write-Host "  генератор: $($link.gen)"
        $env:PYTHONIOENCODING = 'utf-8'
        & python $genPath
        if ($LASTEXITCODE -ne 0) { throw "Генератор $($link.gen) упал (код $LASTEXITCODE)" }
    }

    $sqlPath = Join-Path $sqlDir $link.sql
    if (-not (Test-Path $sqlPath)) { throw "Нет миграции: $sqlPath" }
    Write-Host "  миграция: $($link.sql)"
    # Проверять $LASTEXITCODE тут нельзя: его ставят только внешние программы,
    # а после вызова скрипта PowerShell там остаётся код от python или пусто.
    # `ptr-sql-apply.ps1` сам бросает исключение, и при $ErrorActionPreference
    # = 'Stop' оно останавливает цепочку.
    & (Join-Path $PSScriptRoot 'ptr-sql-apply.ps1') -IKnow $sqlPath
}

if (-not $NoRestart) {
    Write-Host ''
    Write-Host '=== перезапуск PTR ===' -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'ptr-restart.ps1')
}

$took = [int]((Get-Date) - $started).TotalSeconds
Write-Host ''
Write-Host "Цепочка пройдена за $took с." -ForegroundColor Green
Write-Host 'Проверить содержимое: scripts/ptr-query.ps1 с запросами из DESIGN §11.'
