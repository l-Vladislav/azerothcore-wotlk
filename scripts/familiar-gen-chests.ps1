#requires -Version 5.1
# ============================================================================
# Familiar gacha CHEST generator (11 loot bags).
#
# Reads ALL 10 family JSONs (.claude/familiars/NN_<key>.json) and emits:
#   * SQL  -> data/sql/updates/pending_db_world/nemesis_familiars_gacha_chests.sql
#            (item_template + item_template_locale + item_loot_template)
#   * CSV  -> upserts 11 chest rows into .claude/dbc/Item_custom.csv (-Csv)
#            (client Item.dbc needs them or icons show as "?")
#
# Mechanics: data-driven, NO C++ — item_template.Flags=4 (HAS_LOOT) +
# item_loot_template with ONE loot group per chest (GroupId=1).
# LootTemplate::LootGroup::Roll (LootMgr.cpp ~1292): explicit chances roll
# cumulatively against one rand(0..100); if none hit, an EQUAL-share pick
# among Chance=0 entries -> drop GUARANTEED. Not scaled by Rate.Drop.*.
#
#   Universal 110120: 60 Common @ 1.4833 + 30 Rare @ 0.3333 + 10 Epic @ 0
#                     => ~89% C / ~10% R / ~1.003% E (~0.1% per specific epic)
#   Element  1101xx:   6 Common @ 11.6667 + 3 Rare @ 6.6667 + 1 Epic @ 0
#                     => ~70% C / ~20% R / ~10% E
#
# stackable=1 is MANDATORY: LootHandler.cpp DoLootRelease destroys the whole
# item SLOT when its loot is emptied — a stack of 20 would vanish on one open.
# (That is why every Blizzard lootbox is stackable=1.)
#
# Names + icons owner-confirmed 2026-06-07. DisplayIDs resolved from
# .claude/dbc/ItemDisplayInfo.csv (clean rows, no models, std bag sound).
#
# This .ps1 MUST be saved with a UTF-8 BOM (PS5.1 reads BOM-less as ANSI and
# mangles the Cyrillic literals). JSON is read with explicit UTF-8.
#
# Usage:
#   powershell scripts/familiar-gen-chests.ps1 [-Csv]
# ============================================================================

param(
    [switch]$Csv
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sqlPath = Join-Path $repo 'data/sql/updates/pending_db_world/nemesis_familiars_gacha_chests.sql'

$universalId = 110120

# Owner-confirmed names + icons (2026-06-07).
# Display = ItemDisplayInfo ID whose InventoryIcon matches the requested icon.
$chestCfg = @{
    'U'  = @{ Name = 'Сумка Авантюриста';     Display = 19595; Icon = 'inv_misc_bag_19' }
    '1'  = @{ Name = 'Механический сундук';   Display = 12333; Icon = 'inv_box_01' }
    '2'  = @{ Name = 'Огненная сумка';        Display = 20342; Icon = 'inv_misc_bag_13' }
    '3'  = @{ Name = 'Ледяная сумка';         Display = 34780; Icon = 'inv_misc_bag_enchantedmageweave' }
    '4'  = @{ Name = 'Природная сумка';       Display = 20503; Icon = 'inv_misc_bag_18' }
    '5'  = @{ Name = 'Светлая сумка';         Display = 6430;  Icon = 'inv_misc_bag_08' }
    '6'  = @{ Name = 'Теневая сумка';         Display = 33942; Icon = 'inv_misc_bag_corefelclothbag' }
    '7'  = @{ Name = 'Тайная сумка';          Display = 31783; Icon = 'inv_misc_bag_21' }
    '8'  = @{ Name = 'Демоническая сумка';    Display = 33940; Icon = 'inv_misc_bag_soulbag' }
    '9'  = @{ Name = 'Звериная сумка';        Display = 39459; Icon = 'inv_misc_bag_26_spellfire' }
    '10' = @{ Name = 'Странная сумка';        Display = 21202; Icon = 'inv_misc_bag_17' }
}

$qualityUniversal = 3   # rare/blue (cheap chest, 1 coin)
$qualityElement   = 4   # epic/purple (3 coins, 10% family epic)
$uniC = 1.4833; $uniR = 0.3333      # universal group chances (epic = 0 -> remainder)
$elC  = 11.6667; $elR = 6.6667      # element group chances (epic = 0 -> remainder)

function Esc([string]$s) { return ($s -replace "'", "''") }
function TrimComma([string]$s) { return $s.Trim().TrimEnd(',') }

# --- read all 10 family JSONs (single source of truth) ---------------------
$famFiles = Get-ChildItem (Join-Path $repo '.claude/familiars') -Filter '*.json' | Sort-Object Name
if ($famFiles.Count -ne 10) { throw "Expected 10 family JSONs, found $($famFiles.Count)" }
$families = @()
foreach ($f in $famFiles) {
    $fam = [System.IO.File]::ReadAllText($f.FullName, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json
    $byR = @{ C = 0; R = 0; E = 0 }
    foreach ($p in $fam.pets) { $byR[$p.rarity] += 1 }
    if ($byR.C -ne 6 -or $byR.R -ne 3 -or $byR.E -ne 1) {
        throw "Family $($fam.family) ($($fam.name)): rarity split C=$($byR.C)/R=$($byR.R)/E=$($byR.E), expected 6/3/1"
    }
    $families += $fam
}

# --- build rows -------------------------------------------------------------
$itRows = @(); $ilRows = @(); $lootRows = @(); $chestIds = @()

function ChestChance([string]$rarity, [bool]$universal) {
    if ($rarity -eq 'C') { if ($universal) { return $uniC } else { return $elC } }
    if ($rarity -eq 'R') { if ($universal) { return $uniR } else { return $elR } }
    return 0    # Epic: equal-share remainder of the group -> guaranteed drop path
}

# universal chest: all 100 cages in one group
$cfgU = $chestCfg['U']
$descU = 'Содержит клетку со случайным фамильяром любого семейства. Шансы: обычный 89%, редкий 10%, эпический 1%.'
$chestIds += $universalId
$itRows += "($universalId, 15, 0, -1, '$(Esc $cfgU.Name)', $($cfgU.Display), $qualityUniversal, 4, 0, 0, 0, -1, 1, 0, 0, 1, 1, '$(Esc $descU)', 4),"
$ilRows += "($universalId, 'ruRU', '$(Esc $cfgU.Name)', '$(Esc $descU)'),"
foreach ($fam in $families) {
    foreach ($p in $fam.pets) {
        $ch = ChestChance $p.rarity $true
        $lootRows += "($universalId, $($p.ids.scroll), 0, $ch, 0, 1, 1, 1, 1, '$(Esc "Familiar gacha universal: $($p.fp) $($p.name) ($($p.rarity))")'),"
    }
}

# element chests: 10 cages of the family in one group
foreach ($fam in $families) {
    $cfg = $chestCfg["$($fam.family)"]
    if (-not $cfg) { throw "No chest config for family $($fam.family)" }
    $chest = $fam.chestItem
    $expected = 110100 + ($fam.family - 1)
    if ($chest -ne $expected) { throw "Family $($fam.family): chestItem $chest != formula $expected" }
    $desc = "Содержит клетку со случайным фамильяром семейства `"$($fam.name)`". Шансы: обычный 70%, редкий 20%, эпический 10%."
    $chestIds += $chest
    $itRows += "($chest, 15, 0, -1, '$(Esc $cfg.Name)', $($cfg.Display), $qualityElement, 4, 0, 0, 0, -1, 1, 0, 0, 1, 1, '$(Esc $desc)', 4),"
    $ilRows += "($chest, 'ruRU', '$(Esc $cfg.Name)', '$(Esc $desc)'),"
    foreach ($p in $fam.pets) {
        $ch = ChestChance $p.rarity $false
        $lootRows += "($chest, $($p.ids.scroll), 0, $ch, 0, 1, 1, 1, 1, '$(Esc "Familiar gacha $($fam.key): $($p.fp) $($p.name) ($($p.rarity))")'),"
    }
}

$idList = $chestIds -join ', '

$sql = @"
-- ============================================================================
-- Nemesis Familiar Gacha — chests (10 element + 1 universal)
-- AUTO-GENERATED by scripts/familiar-gen-chests.ps1 from .claude/familiars/*.json
-- Do not hand-edit: change the JSONs / generator config and regenerate.
--
-- Flags=4 (HAS_LOOT) + one loot group per chest. Group semantics
-- (LootMgr.cpp LootGroup::Roll): explicit chances cumulative vs one
-- rand(0..100); Chance=0 entries equal-share the remainder (guaranteed drop).
-- stackable=1 REQUIRED: DoLootRelease destroys the whole slot when looted.
-- ============================================================================

-- STEP 1: item_template (chests) + _locale
DELETE FROM item_template_locale WHERE ID IN ($idList) AND locale = 'ruRU';
DELETE FROM item_template        WHERE entry IN ($idList);

REPLACE INTO item_template (entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, BuyPrice, SellPrice, InventoryType, AllowableClass, ItemLevel, RequiredLevel, maxcount, stackable, bonding, description, Material) VALUES
$(TrimComma ($itRows -join "`n"));

INSERT INTO item_template_locale (ID, locale, Name, Description) VALUES
$(TrimComma ($ilRows -join "`n"));

-- STEP 2: item_loot_template — one group per chest
DELETE FROM item_loot_template WHERE Entry IN ($idList);

INSERT INTO item_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES
$(TrimComma ($lootRows -join "`n"));
"@

[System.IO.File]::WriteAllText($sqlPath, $sql, (New-Object System.Text.UTF8Encoding $false))
Write-Host "SQL written: $sqlPath"
Write-Host ("  chests={0} loot rows={1} (universal 100 + 10x10)" -f $chestIds.Count, $lootRows.Count)
Write-Host ("  universal sums: C={0} R={1} (E remainder={2})" -f (60 * $uniC), (30 * $uniR), (100 - 60 * $uniC - 30 * $uniR))
Write-Host ("  element   sums: C={0} R={1} (E remainder={2})" -f (6 * $elC), (3 * $elR), (100 - 6 * $elC - 3 * $elR))

if (-not $Csv) { return }

# ---------------------------------------------------------------------------
# Item.dbc rows for the chests — client shows "?" icons for items missing
# from its Item.dbc. Owner merges Item_custom.csv into the MPQ's Item.dbc.
# Columns: ID, ClassID(15), SubclassID(0), SoundOverrideSubclassID(-1),
# Material(4), DisplayInfoID, InventoryType(0), SheatheType(0).
# ---------------------------------------------------------------------------
$itemCsvPath = Join-Path $repo '.claude/dbc/Item_custom.csv'
$itemHeader = '"ID","ClassID","SubclassID","SoundOverrideSubclassID","Material","DisplayInfoID","InventoryType","SheatheType"'
$enc = New-Object System.Text.UTF8Encoding $true

$chestRows = @(); $chestIdStrs = @()
$chestRows += ('"{0}","15","0","-1","4","{1}","0","0"' -f $universalId, $chestCfg['U'].Display)
$chestIdStrs += "$universalId"
foreach ($fam in $families) {
    $cfg = $chestCfg["$($fam.family)"]
    $chestRows += ('"{0}","15","0","-1","4","{1}","0","0"' -f $fam.chestItem, $cfg.Display)
    $chestIdStrs += "$($fam.chestItem)"
}

$o = New-Object System.Collections.ArrayList
if (Test-Path $itemCsvPath) {
    $ex = [System.IO.File]::ReadAllLines($itemCsvPath, [System.Text.UTF8Encoding]::new($true))
    [void]$o.Add($ex[0])
    for ($i = 1; $i -lt $ex.Count; $i++) {
        $rid = ($ex[$i] -split '","')[0].TrimStart('"')
        if ($chestIdStrs -notcontains $rid) { [void]$o.Add($ex[$i]) }
    }
} else { [void]$o.Add($itemHeader) }
foreach ($r in $chestRows) { [void]$o.Add($r) }
[System.IO.File]::WriteAllLines($itemCsvPath, $o, $enc)
Write-Host ("CSV: upserted {0} chest rows into Item_custom.csv" -f $chestRows.Count)
