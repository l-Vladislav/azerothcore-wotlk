#requires -Version 5.1
# ============================================================================
# Familiar gacha SQL/DBC generator.
#
# Reads a per-family JSON (.claude/familiars/NN_<key>.json) — the single
# source of truth — and emits:
#   * SQL  -> data/sql/updates/pending_db_world/nemesis_familiars_gacha_<key>.sql
#   * CSV  -> appends summon + aura rows to .claude/dbc/Spell_custom.csv (-Csv)
#
# Encoding (per agent-memory aura-template.md): amount = BasePoints + 1
#   (DieSides=1) => BP = value-1. buff Attr=2147483648 (0x80000000 NO_AURA_CANCEL),
#   debuff Attr=2214592512 (0x84000000 NO_AURA_CANCEL|AURA_IS_DEBUFF),
#   DurationIndex=21, ProcChance=101, Effect=6 APPLY_AURA, ImplicitTargetA=1,
#   SchoolMask=1. summon: Attr=262416, Effect=28, MiscValueB=41, ImplicitTargetA=32.
#
# Effect text is GENERATED from codes via StatRu — COMPACT genitive tokens
# ("+5% брони", "-10% силы атаки", flat "+3 сопротивления..."). Placement:
#   buff aura (103xxx)  = buffs only      debuff aura (104xxx) = debuffs only
#   summon spell + scroll = FULL list "buffs; debuffs", e.g.
#   "+5% брони, +5% выносливости, +5% уворота; -10% силы атаки, -5% шанса критического удара"
# Full Russian stat names (no English, no abbreviations), ASCII punctuation.
# See agent-memory russian-text.md. nameAcc = animate accusative for «Призывает …».
#
# Generated SQL uses unquoted identifiers (no MySQL backticks).
# This .ps1 MUST be saved with a UTF-8 BOM (PS5.1 reads BOM-less as ANSI and
# mangles the Cyrillic literals). JSON is read with explicit UTF-8.
#
# Usage:
#   pwsh scripts/familiar-gen-sql.ps1 -Json .claude/familiars/01_mech.json [-Csv]
# ============================================================================

param(
    [Parameter(Mandatory)][string]$Json,
    [switch]$Csv
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$jsonPath = (Resolve-Path $Json).Path
$fam = [System.IO.File]::ReadAllText($jsonPath, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json

$key = $fam.key
$sqlPath = Join-Path $repo "data/sql/updates/pending_db_world/nemesis_familiars_gacha_$key.sql"

$scrollDisplay = 20629  # ItemDisplayInfo with InventoryIcon INV_Box_PetCarrier_01 (cage, stock)
$qualityMap = @{ 'C' = 1; 'R' = 3; 'E' = 4 }
$sellPrice = 1000000   # 100g (catalog: duplicate scrolls vendor for 100g)

function Esc([string]$s) { return ($s -replace "'", "''") }
function Parse-Code([string]$code) {
    $parts = $code -split '/'
    return @{ Aura = [int]$parts[0]; Misc = if ($parts.Count -gt 1) { [int]$parts[1] } else { 0 } }
}
function BP([int]$value) { return $value - 1 }
function JoinList($arr) { return ($arr -join ', ') }
function TrimComma([string]$s) { return $s.Trim().TrimEnd(',') }

# aura code -> Russian stat in GENITIVE (for "+N% <gen>"), flat = no percent.
# Source: agent-memory/familiars-dev/russian-text.md translation table.
function StatRu([string]$code) {
    $c = Parse-Code $code; $aura = $c.Aura; $misc = $c.Misc
    $flat = $false; $gen = $null
    switch ($aura) {
        137 { $gen = @{'0'='силы';'1'='ловкости';'2'='выносливости';'3'='интеллекта';'4'='духа'}["$misc"] }
        101 { if ($misc -eq 1) { $gen = 'брони' } else { $gen = 'сопротивления' } }
        22  { $flat = $true; $gen = @{'2'='сопротивления свету';'4'='сопротивления огню';'8'='сопротивления природе';'16'='сопротивления морозу';'32'='сопротивления тени';'64'='сопротивления тайной магии';'126'='сопротивления всем школам магии';'127'='сопротивления всем школам магии'}["$misc"] }
        79  { $gen = @{'1'='физического урона';'2'='урона светом';'4'='урона огнём';'8'='урона природой';'16'='урона морозом';'32'='урона тенью';'64'='урона тайной магией';'126'='урона магией';'127'='всего урона'}["$misc"] }
        31  { $gen = 'скорости передвижения' }
        49  { $gen = 'уворота' }
        51  { $gen = 'блока' }
        57  { $gen = 'шанса критического удара заклинаний' }
        65  { $gen = 'скорости накладывания заклинаний' }
        110 { $gen = 'восстановления маны' }
        118 { $gen = 'получаемого лечения' }
        136 { $gen = 'исходящего лечения' }
        156 { $gen = 'прироста репутации' }
        166 { $gen = 'силы атаки' }
        178 { $gen = 'сопротивления дебаффам' }
        192 { $gen = 'скорости атаки' }
        200 { $gen = 'опыта' }
        235 { $gen = 'сопротивления развеиванию' }
        280 { $gen = 'пробивания брони' }
        281 { $gen = 'прироста чести' }
        290 { $gen = 'шанса критического удара' }
    }
    if (-not $gen) { Write-Warning "StatRu: unmapped aura code '$code'"; return $null }
    return @{ gen = $gen; flat = $flat }
}

# One effect -> "+5% брони" / "-10% силы атаки" / "+3 сопротивления..." (flat).
function EffTokens($effects) {
    $toks = @()
    foreach ($x in @($effects)) {
        $info = StatRu $x.code
        $val = [int]$x.value
        $sign = if ($val -ge 0) { '+' } else { '-' }
        $a = [math]::Abs($val)
        if ($null -eq $info) { $toks += $x.text; continue }
        $unit = if ($info.flat) { "$a" } else { "$a%" }
        $toks += "$sign$unit $($info.gen)"
    }
    return $toks
}

# Full compact effect list: "<buffs>; <debuffs>" (whichever present). '' if none.
function EffFull($pos, $neg) {
    $b = (EffTokens $pos) -join ', '
    $d = (EffTokens $neg) -join ', '
    return (@($b, $d) | Where-Object { $_ }) -join '; '
}

$summonIds = @(); $buffIds = @(); $debuffIds = @(); $creatureIds = @(); $scrollIds = @()
$sbSummon = New-Object System.Text.StringBuilder
$sbBuff   = New-Object System.Text.StringBuilder
$sbDebuff = New-Object System.Text.StringBuilder
$ctRows = @(); $cmRows = @(); $clRows = @(); $itRows = @(); $ilRows = @()
$mutedSpecs = @()   # pets with muteAmbient: custom CDI/CSD clone with LoopSoundID=0

foreach ($p in $fam.pets) {
    $cre = $p.ids.creature; $sum = $p.ids.summon; $buff = $p.ids.buffAura
    $deb = $p.ids.debuffAura; $scr = $p.ids.scroll; $icon = $p.icon.spellIconId
    $nm = $p.name; $scale = $p.scale
    $accName = if ($p.nameAcc) { $p.nameAcc } else { $nm }

    # muteAmbient: use a custom displayId (65000 + linear offset) whose cloned
    # sound kit has LoopSoundID=0. Rows for client+server DBC go to *_custom.csv.
    $effDisplay = $p.displayId
    if ($p.muteAmbient) {
        $fpp = $p.fp -split '\.'
        $mid = 65000 + ([int]$fpp[0] - 1) * 10 + ([int]$fpp[1] - 1)
        $mutedSpecs += @{ MutedId = $mid; SourceDisplay = $p.displayId; Fp = $p.fp }
        $effDisplay = $mid
    }

    $pos = @($p.effects.positive); $neg = @($p.effects.negative)
    $full = EffFull $pos $neg                       # combined buffs+debuffs — summon + scroll only
    $buffList = (EffTokens $pos) -join ', '          # buffs only — buff aura tooltip
    $debList  = (EffTokens $neg) -join ', '          # debuffs only — debuff aura tooltip
    $scrollDesc = ("Обучает призывать фамильяра: $nm." + $(if ($full) { " $full" } else { '' }))
    $summonDesc = ("Призывает $accName." + $(if ($full) { " $full" } else { '' }))

    $summonIds += $sum; $buffIds += $buff; $creatureIds += $cre; $scrollIds += $scr

    [void]$sbSummon.AppendLine("($sum, 262416, 1, 21, 1, -1, 28, $cre, 41, 32, 1, $icon, 'Summon Familiar: $(Esc $nm)'),")

    # buff aura (positive effects on buff bar); tooltip shows buffs only
    $cols = @('ID','Attributes','DurationIndex','ProcChance','RangeIndex','EquippedItemClass')
    $vals = @("$buff", '2147483648', '21', '101', '1', '-1')
    for ($i = 0; $i -lt $pos.Count; $i++) {
        $n = $i + 1; $c = Parse-Code $pos[$i].code
        $cols += @("Effect_$n","EffectAura_$n","EffectBasePoints_$n","EffectDieSides_$n","EffectMiscValue_$n","ImplicitTargetA_$n")
        $vals += @('6', "$($c.Aura)", "$(BP $pos[$i].value)", '1', "$($c.Misc)", '1')
    }
    $cols += @('SchoolMask','SpellIconID','Name_Lang_enUS','Description_Lang_enUS')
    $vals += @('1', "$icon", "'Familiar Aura: $(Esc $nm)'", "'$(Esc $buffList)'")
    [void]$sbBuff.AppendLine("REPLACE INTO spell_dbc ($($cols -join ', ')) VALUES")
    [void]$sbBuff.AppendLine("($($vals -join ', '));")

    # debuff aura (negative effects on debuff bar); tooltip shows debuffs only
    if ($deb -and $neg.Count -gt 0) {
        $debuffIds += $deb
        $cols = @('ID','Attributes','DurationIndex','ProcChance','RangeIndex','EquippedItemClass')
        $vals = @("$deb", '2214592512', '21', '101', '1', '-1')
        for ($i = 0; $i -lt $neg.Count; $i++) {
            $n = $i + 1; $c = Parse-Code $neg[$i].code
            $cols += @("Effect_$n","EffectAura_$n","EffectBasePoints_$n","EffectDieSides_$n","EffectMiscValue_$n","ImplicitTargetA_$n")
            $vals += @('6', "$($c.Aura)", "$(BP $neg[$i].value)", '1', "$($c.Misc)", '1')
        }
        $cols += @('SchoolMask','SpellIconID','Name_Lang_enUS','Description_Lang_enUS')
        $vals += @('1', "$icon", "'Familiar Debuff: $(Esc $nm)'", "'$(Esc $debList)'")
        [void]$sbDebuff.AppendLine("REPLACE INTO spell_dbc ($($cols -join ', ')) VALUES")
        [void]$sbDebuff.AppendLine("($($vals -join ', '));")
    }

    $ctRows += "($cre, '$(Esc $nm)', '', 1, 1, 35, 1, 7, 0, 0, ''),"
    $cmRows += "($cre, 0, $effDisplay, $scale, 1, 0),"
    $clRows += "($cre, 'ruRU', '$(Esc $nm)', ''),"

    $q = $qualityMap[$p.rarity]
    $itRows += "($scr, 15, 2, 'Клетка с: $(Esc $nm)', $scrollDisplay, $q, 64, 0, $sellPrice, 0, -1, 1, 1, 0, 1, 55884, 0, -1, $sum, 6, 0, 1, '$(Esc $scrollDesc)', 4),"
    $ilRows += "($scr, 'ruRU', 'Клетка с: $(Esc $nm)', '$(Esc $scrollDesc)'),"
}

# creature_model_info for muted custom displays — copy bounding from source display.
$cmiSql = ''
if ($mutedSpecs.Count -gt 0) {
    $mutedIds = ($mutedSpecs | ForEach-Object { $_.MutedId }) -join ', '
    $cmiSql = "`n-- muted-ambient custom displays (need rows in patched CreatureDisplayInfo.dbc, server+client)`n"
    $cmiSql += "DELETE FROM creature_model_info WHERE DisplayID IN ($mutedIds);`n"
    foreach ($ms in $mutedSpecs) {
        $cmiSql += "INSERT INTO creature_model_info (DisplayID, BoundingRadius, CombatReach, Gender, DisplayID_Other_Gender)`n"
        $cmiSql += "SELECT $($ms.MutedId), BoundingRadius, CombatReach, Gender, 0 FROM creature_model_info WHERE DisplayID = $($ms.SourceDisplay);`n"
    }
}

$sql = @"
-- ============================================================================
-- Nemesis Familiar Gacha — family $($fam.family) ($($fam.name) / $key)
-- AUTO-GENERATED by scripts/familiar-gen-sql.ps1 from $([System.IO.Path]::GetFileName($jsonPath))
-- Do not hand-edit: change the JSON and regenerate.
--
-- amount = EffectBasePoints + 1 (DieSides=1). buff=0x80000000,
-- debuff=0x84000000 (NO_AURA_CANCEL | AURA_IS_DEBUFF). See generator header.
-- ============================================================================

-- STEP 1: spell_dbc — summon spells
DELETE FROM spell_dbc WHERE ID IN ($(JoinList $summonIds));
REPLACE INTO spell_dbc (ID, Attributes, CastingTimeIndex, DurationIndex, RangeIndex, EquippedItemClass, Effect_1, EffectMiscValue_1, EffectMiscValueB_1, ImplicitTargetA_1, SchoolMask, SpellIconID, Name_Lang_enUS) VALUES
$(TrimComma $sbSummon.ToString());

-- STEP 2: spell_dbc — positive owner-auras (103xxx, buff bar)
DELETE FROM spell_dbc WHERE ID IN ($(JoinList $buffIds));
$($sbBuff.ToString().Trim())

-- STEP 3: spell_dbc — negative owner-auras (104xxx, debuff bar)
DELETE FROM spell_dbc WHERE ID IN ($(JoinList $debuffIds));
$($sbDebuff.ToString().Trim())

-- STEP 4: creature_template + _model + _locale
DELETE FROM creature_template_locale WHERE entry IN ($(JoinList $creatureIds));
DELETE FROM creature_template_model  WHERE CreatureID IN ($(JoinList $creatureIds));
DELETE FROM creature_template        WHERE entry IN ($(JoinList $creatureIds));

REPLACE INTO creature_template (entry, name, subname, minlevel, maxlevel, faction, unit_class, type, family, npcflag, AIName) VALUES
$(TrimComma ($ctRows -join "`n"));

INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) VALUES
$(TrimComma ($cmRows -join "`n"));

INSERT INTO creature_template_locale (entry, locale, Name, Title) VALUES
$(TrimComma ($clRows -join "`n"));
$cmiSql
-- STEP 5: item_template (scrolls) + _locale
DELETE FROM item_template_locale WHERE ID IN ($(JoinList $scrollIds)) AND locale = 'ruRU';
DELETE FROM item_template        WHERE entry IN ($(JoinList $scrollIds));

REPLACE INTO item_template (entry, class, subclass, name, displayid, Quality, Flags, BuyPrice, SellPrice, InventoryType, AllowableClass, ItemLevel, RequiredLevel, MaxCount, stackable, spellid_1, spelltrigger_1, spellcharges_1, spellid_2, spelltrigger_2, spellcharges_2, bonding, description, Material) VALUES
$(TrimComma ($itRows -join "`n"));

INSERT INTO item_template_locale (ID, locale, Name, Description) VALUES
$(TrimComma ($ilRows -join "`n"));
"@

[System.IO.File]::WriteAllText($sqlPath, $sql, (New-Object System.Text.UTF8Encoding $false))
Write-Host "SQL written: $sqlPath"
Write-Host ("  pets={0} summons={1} buffs={2} debuffs={3}" -f $fam.pets.Count, $summonIds.Count, $buffIds.Count, $debuffIds.Count)

if (-not $Csv) { return }

# ---------------------------------------------------------------------------
# CSV — append summon + aura rows to Spell_custom.csv (client DBC for MPQ).
# Template rows (100120/101100) + ruRU = enUS+8 locale offset.
# ---------------------------------------------------------------------------
$csvPath = (Resolve-Path (Join-Path $repo '.claude/dbc/Spell_custom.csv')).Path
$enc = New-Object System.Text.UTF8Encoding $true
$lines = [System.IO.File]::ReadAllLines($csvPath, [System.Text.UTF8Encoding]::new($true))
$cols2 = $lines[0] -split '","' | ForEach-Object { $_.Trim('"') }
$idx = @{}; for ($i = 0; $i -lt $cols2.Count; $i++) { $idx[$cols2[$i]] = $i }

function Split-CsvRow([string]$row) { return $row.Substring(1, $row.Length - 2) -split '","' }
function Join-CsvRow([string[]]$f) { return '"' + ($f -join '","') + '"' }

$tmplSummon = $null; $tmplAura = $null
for ($i = 1; $i -lt $lines.Count; $i++) {
    $id = ($lines[$i] -split '","')[0].TrimStart('"')
    if ($id -eq '100120') { $tmplSummon = Split-CsvRow $lines[$i] }
    if ($id -eq '101100') { $tmplAura   = Split-CsvRow $lines[$i] }
}
if (-not $tmplSummon -or -not $tmplAura) { throw "Template rows 100120/101100 not found in $csvPath" }

$nameEn = $idx['Name_Lang_enUS'];        $nameRu = $nameEn + 8
$subEn  = $idx['NameSubtext_Lang_enUS']; $subRu  = $subEn + 8
$descEn = $idx['Description_Lang_enUS'];  $descRu = $descEn + 8
$adEn   = $idx['AuraDescription_Lang_enUS']; $adRu = $adEn + 8

$newRows = @(); $targetIds = @{}
foreach ($p in $fam.pets) {
    $nm = $p.name
    $accName = if ($p.nameAcc) { $p.nameAcc } else { $nm }
    $full = EffFull @($p.effects.positive) @($p.effects.negative)
    $summonDesc = ("Призывает $accName." + $(if ($full) { " $full" } else { '' }))

    $row = [string[]]@($tmplSummon)
    $row[$idx['ID']] = "$($p.ids.summon)"
    $row[$idx['EffectMiscValue_1']] = "$($p.ids.creature)"
    $row[$idx['SpellIconID']] = "$($p.icon.spellIconId)"
    $row[$nameEn] = "Summon Familiar: $nm"; $row[$nameRu] = "Призыв фамильяра: $nm"
    $row[$descEn] = $summonDesc; $row[$descRu] = $summonDesc
    $newRows += Join-CsvRow $row
    $targetIds["$($p.ids.summon)"] = $true

    $auraSpecs = @(@{ Id = $p.ids.buffAura; Attr = '2147483648'; NameEn = "Familiar Aura: $nm"; NameRu = "Аура фамильяра: $nm"; Eff = @($p.effects.positive) })
    if ($p.ids.debuffAura -and @($p.effects.negative).Count -gt 0) {
        $auraSpecs += @{ Id = $p.ids.debuffAura; Attr = '2214592512'; NameEn = "Familiar Debuff: $nm"; NameRu = "Штраф фамильяра: $nm"; Eff = @($p.effects.negative) }
    }
    foreach ($a in $auraSpecs) {
        $row = [string[]]@($tmplAura)
        $row[$idx['ID']] = "$($a.Id)"
        $row[$idx['Attributes']] = $a.Attr
        $row[$idx['SpellIconID']] = "$($p.icon.spellIconId)"
        $row[$nameEn] = $a.NameEn; $row[$nameRu] = $a.NameRu
        $row[$subEn] = ''; $row[$subRu] = $a.NameRu
        $adesc = (EffTokens $a.Eff) -join ', '           # aura tooltip = its OWN side only
        $row[$descEn] = $adesc; $row[$descRu] = $adesc
        $row[$adEn] = $adesc;   $row[$adRu] = $adesc
        foreach ($n in 1, 2, 3) {
            $row[$idx["Effect_$n"]] = '0'; $row[$idx["EffectDieSides_$n"]] = '0'
            $row[$idx["EffectBasePoints_$n"]] = '0'; $row[$idx["ImplicitTargetA_$n"]] = '0'
            $row[$idx["EffectAura_$n"]] = '0'; $row[$idx["EffectMiscValue_$n"]] = '0'
        }
        for ($i = 0; $i -lt $a.Eff.Count; $i++) {
            $n = $i + 1; $c = Parse-Code $a.Eff[$i].code
            $row[$idx["Effect_$n"]] = '6'; $row[$idx["EffectDieSides_$n"]] = '1'
            $row[$idx["EffectBasePoints_$n"]] = "$(BP $a.Eff[$i].value)"
            $row[$idx["ImplicitTargetA_$n"]] = '1'
            $row[$idx["EffectAura_$n"]] = "$($c.Aura)"; $row[$idx["EffectMiscValue_$n"]] = "$($c.Misc)"
        }
        $newRows += Join-CsvRow $row
        $targetIds["$($a.Id)"] = $true
    }
}

$output = New-Object System.Collections.ArrayList
$output.Add($lines[0]) | Out-Null
for ($i = 1; $i -lt $lines.Count; $i++) {
    $rowId = ($lines[$i] -split '","')[0].TrimStart('"')
    if (-not $targetIds.ContainsKey($rowId)) { $output.Add($lines[$i]) | Out-Null }
}
foreach ($r in $newRows) { $output.Add($r) | Out-Null }
[System.IO.File]::WriteAllLines($csvPath, $output, $enc)
Write-Host ("CSV: appended {0} rows to {1}" -f $newRows.Count, $csvPath)

# ---------------------------------------------------------------------------
# muteAmbient — clone CDI row (+ its effective sound kit with LoopSoundID=0)
# into CreatureDisplayInfo_custom.csv / CreatureSoundData_custom.csv.
# Owner merges these via WDBX into BOTH the client MPQ DBCs AND the server's
# dbc/CreatureDisplayInfo.dbc (server validates displayIds against it).
# ---------------------------------------------------------------------------
if ($mutedSpecs.Count -gt 0) {
    $cdiL = [System.IO.File]::ReadAllLines((Join-Path $repo '.claude/dbc/CreatureDisplayInfo.csv'), [System.Text.UTF8Encoding]::new($true))
    $csdL = [System.IO.File]::ReadAllLines((Join-Path $repo '.claude/dbc/CreatureSoundData.csv'), [System.Text.UTF8Encoding]::new($true))
    $cmdL = [System.IO.File]::ReadAllLines((Join-Path $repo '.claude/dbc/CreatureModelData.csv'), [System.Text.UTF8Encoding]::new($true))
    $cdiCols = $cdiL[0] -split '","' | ForEach-Object { $_.Trim('"') }; $cdiIdx = @{}; for ($i = 0; $i -lt $cdiCols.Count; $i++) { $cdiIdx[$cdiCols[$i]] = $i }
    $csdCols = $csdL[0] -split '","' | ForEach-Object { $_.Trim('"') }; $csdIdx = @{}; for ($i = 0; $i -lt $csdCols.Count; $i++) { $csdIdx[$csdCols[$i]] = $i }
    $cmdCols = $cmdL[0] -split '","' | ForEach-Object { $_.Trim('"') }; $cmdIdx = @{}; for ($i = 0; $i -lt $cmdCols.Count; $i++) { $cmdIdx[$cmdCols[$i]] = $i }

    function FindRowById($lines, [string]$id) {
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ((($lines[$i] -split '","')[0].TrimStart('"')) -eq $id) { return Split-CsvRow $lines[$i] }
        }
        return $null
    }
    function UpsertCustomCsv([string]$path, [string]$header, $rows, $ids) {
        $o = New-Object System.Collections.ArrayList
        if (Test-Path $path) {
            $ex = [System.IO.File]::ReadAllLines($path, [System.Text.UTF8Encoding]::new($true))
            [void]$o.Add($ex[0])
            for ($i = 1; $i -lt $ex.Count; $i++) {
                $rid = ($ex[$i] -split '","')[0].TrimStart('"')
                if ($ids -notcontains $rid) { [void]$o.Add($ex[$i]) }
            }
        } else { [void]$o.Add($header) }
        foreach ($r in $rows) { [void]$o.Add($r) }
        [System.IO.File]::WriteAllLines($path, $o, $enc)
    }

    $newCdi = @(); $newCsd = @()
    foreach ($ms in $mutedSpecs) {
        $src = FindRowById $cdiL "$($ms.SourceDisplay)"
        if (-not $src) { throw "muteAmbient: CDI row $($ms.SourceDisplay) not found in CreatureDisplayInfo.csv" }
        $kitId = $src[$cdiIdx['SoundID']]
        if ($kitId -eq '0') {
            $mrow = FindRowById $cmdL $src[$cdiIdx['ModelID']]
            if (-not $mrow) { throw "muteAmbient: CMD row $($src[$cdiIdx['ModelID']]) not found" }
            $kitId = $mrow[$cmdIdx['SoundID']]
        }
        $kit = FindRowById $csdL $kitId
        if (-not $kit) { throw "muteAmbient: CSD kit $kitId not found" }
        $kit2 = [string[]]@($kit); $kit2[$csdIdx['ID']] = "$($ms.MutedId)"; $kit2[$csdIdx['LoopSoundID']] = '0'
        $cdi2 = [string[]]@($src); $cdi2[$cdiIdx['ID']] = "$($ms.MutedId)"; $cdi2[$cdiIdx['SoundID']] = "$($ms.MutedId)"
        $newCsd += Join-CsvRow $kit2
        $newCdi += Join-CsvRow $cdi2
        Write-Host ("  muted display: {0} (src {1}, kit {2} -> {3} Loop=0)" -f $ms.MutedId, $ms.SourceDisplay, $kitId, $ms.MutedId)
    }
    $mids = $mutedSpecs | ForEach-Object { "$($_.MutedId)" }
    UpsertCustomCsv (Join-Path $repo '.claude/dbc/CreatureDisplayInfo_custom.csv') $cdiL[0] $newCdi $mids
    UpsertCustomCsv (Join-Path $repo '.claude/dbc/CreatureSoundData_custom.csv') $csdL[0] $newCsd $mids
    Write-Host ("CSV: wrote {0} muted rows to CreatureDisplayInfo_custom.csv / CreatureSoundData_custom.csv" -f $newCdi.Count)
}
