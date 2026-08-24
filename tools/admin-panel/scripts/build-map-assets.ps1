<#
.SYNOPSIS
  Собирает файлы карты погоды: подложку из клиента и контуры зон из серверных .map.

.DESCRIPTION
  Результат (app/static/maps/*.jpg и *.zones.json) намеренно не лежит в
  репозитории: подложка — арт Blizzard. После клона репозитория карту нужно
  собрать один раз этим скриптом; без файлов страница погоды работает, но
  вместо карты показывает подсказку.

  Две половины берутся из разных мест:

    * подложка — 12 тайлов BLP из клиентского MPQ (у локализованного клиента
      это Data/ruRU/locale-ruRU.MPQ, а не common.MPQ: на карте выгравированы
      названия, поэтому она переведена);
    * контуры — сетка area-id из maps/*.map, которую worldserver и так грузит.
      Эти файлы лежат в docker-томе ac-client-data-v2, поэтому генератор
      запускается внутри контейнера панели, где том уже примонтирован.

  Хосту нужны Python с mpyq и pillow (pip install mpyq pillow).

.EXAMPLE
  ./build-map-assets.ps1 -Client "E:\torrent\World of Warcraft"
  Собирает оба континента: Восточные королевства и Калимдор.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Client,
  # 'all' - оба собранных континента; иначе ключ панели: ek или kalimdor.
  [ValidateSet('all', 'ek', 'kalimdor')][string]$Continent = 'all',
  [string]$Locale = 'ruRU',
  [string]$Container = 'ac-admin-panel'
)

# Ключ панели (weather.CONTINENTS) -> папка арта в клиенте и MapID сервера.
# Названия не совпадают: клиент зовёт Восточные королевства Azeroth, а карта
# мира у него нулевая.
$continents = [ordered]@{
  ek       = @{ art = 'Azeroth';  map = 0 }
  kalimdor = @{ art = 'Kalimdor'; map = 1 }
}

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$panel = Split-Path -Parent $here
$outDir = Join-Path $panel 'app/static/maps'

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$keys = if ($Continent -eq 'all') { $continents.Keys } else { @($Continent) }

# Контейнер обязан быть живым: том с maps/ монтируется только в него. Если
# панель погашена, честнее упасть до первого файла, чем оставить половину карты.
$running = docker ps --filter "name=$Container" --format '{{.Names}}'
if ($running -notcontains $Container) {
  throw "контейнер $Container не запущен: подними профиль ptr и повтори"
}
docker cp (Join-Path $here 'gen_zone_geometry.py') "${Container}:/tmp/gen_zone_geometry.py"
if ($LASTEXITCODE -ne 0) { throw 'не удалось скопировать генератор в контейнер' }

$made = @()
foreach ($key in $keys) {
  $art = Join-Path $outDir "$key.jpg"
  $zones = Join-Path $outDir "$key.zones.json"

  Write-Host "[$key] подложка $($continents[$key].art) из клиента" -ForegroundColor Cyan
  python (Join-Path $here 'gen_map_art.py') --client $Client `
    --continent $continents[$key].art --locale $Locale --out $art
  if ($LASTEXITCODE -ne 0) { throw "gen_map_art.py вернул $LASTEXITCODE" }

  Write-Host "[$key] контуры зон из серверных .map (карта $($continents[$key].map))" -ForegroundColor Cyan
  docker exec $Container python /tmp/gen_zone_geometry.py `
    --map $continents[$key].map --out /tmp/zones.json
  if ($LASTEXITCODE -ne 0) { throw 'генератор контуров упал' }

  # Именно docker cp, а не «docker exec cat > файл»: труба PowerShell
  # пропускает вывод через кодировку консоли и дописывает BOM, а тут байты
  # копируются как есть — в JSON лежат русские названия зон.
  docker cp "${Container}:/tmp/zones.json" $zones
  if ($LASTEXITCODE -ne 0) { throw 'не удалось забрать zones.json из контейнера' }

  $made += $art
  $made += $zones
}

Write-Host ''
Write-Host 'готово:' -ForegroundColor Green
Get-Item $made | ForEach-Object {
  Write-Host ("  {0}  {1} КБ" -f $_.Name, [int]($_.Length / 1KB))
}
Write-Host ''
Write-Host 'Файлы копируются в образ при сборке, поэтому чтобы их увидела'
Write-Host 'запущенная панель: docker compose --profile ptr up -d --build ac-admin-panel'
