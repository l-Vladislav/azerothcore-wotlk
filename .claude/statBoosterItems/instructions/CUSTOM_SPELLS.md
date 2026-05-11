# Creating Custom Spells for StatBooster

Guide for adding new custom proc spells (like Arcane Burst) that need both server-side and client-side support.

## Overview

Custom spells need entries in **3 places**:
1. **Server DB** — `spell_dbc` table (server behavior)
2. **Client DBC** — `Spell.dbc` in MPQ patch (visual + tooltip)
3. **StatBooster** — `spellitemenchantment_dbc` + `statbooster_enchant_template` + `spell_enchant_proc_data`

## ID Ranges

| Range | Purpose |
|-------|---------|
| 100001-100016 | Craft spells (scrolls) |
| 100017-100019 | Arcane Burst proc spells (T3-T4, T1, T2) |
| 100020+ | Next custom proc spells |
| 90001-90099 | Fortune pool enchant IDs |
| 90070-90076 | Weapon proc enchants (T3-T4 replacements + Arcane Burst) |
| 90077+ | Next enchant IDs |

## Important: Tier-Scaled Spells

Custom proc spells with damage should have **one spell per tier** with appropriate damage:

| Tier | iLvl | Player Level | Damage Scale |
|------|------|-------------|-------------|
| T1 | 1-25 | ~10-20 | Low (20-35) |
| T2 | 26-45 | ~20-40 | Medium (45-70) |
| T3-T4 | 46-92 | ~40-60 | High (80-120) |

Each tier needs: separate spell ID, separate enchant ID, separate template entry.
They share: same visual, same name, same mechanic.

## Spell Types

There are three types of custom spells for StatBooster:

### Type A: Damage Proc (COMBAT_SPELL, Effect_1=1 in enchant)
Triggers on melee hit. Examples: Arcane Burst, Frost Ring, Fiery Weapon.

### Type B: Passive Aura (EQUIP_SPELL, Effect_1=3 in enchant)
Always active while item is equipped. Cannot be toggled. Examples: Water Walk, Water Breathing, Thorns, Blood Pact, Frost Armor.

### Type C: Activatable Aura (USE_SPELL, Effect_1=7 in enchant)
Player clicks item to activate. Buff lasts for a duration (e.g., 5 min). Can be cancelled by right-click. Click again to reapply. Examples: Immolate (fire damage shield).

## Step 1a: Design a Damage Proc Spell

Key fields for a damage proc spell:

| Field | Value | Notes |
|-------|-------|-------|
| `Effect_1` | 2 | SPELL_EFFECT_SCHOOL_DAMAGE |
| `ImplicitTargetA_1` | **17** | **TARGET_DEST_CASTER (AoE origin = caster pos)** |
| `ImplicitTargetB_1` | **15** | **TARGET_UNIT_DEST_AREA_ENEMY (hit enemies at origin)** |
| | 6 | TARGET_UNIT_TARGET_ENEMY (single target) |
| `EffectBasePoints_1` | N-1 | Base damage (actual min = BasePoints + 1) |
| `EffectDieSides_1` | N | Random range added (max = BasePoints + DieSides) |
| `EffectRadiusIndex_1` | 13 | 10 yards (AoE only) |
| | 8 | 5 yards |
| | 28 | 30 yards |
| `SchoolMask` | 1=Physical, 2=Holy, 4=Fire, 8=Nature, 16=Frost, 32=Shadow, 64=Arcane |
| `SpellVisualID_1` | See below | Animation shown to client |
| `CastingTimeIndex` | 1 | Instant (always for procs) |

## Step 1b: Design a Passive Aura Spell

Key fields for a passive aura (EQUIP_SPELL):

| Field | Value | Notes |
|-------|-------|-------|
| `Effect_1` | 6 | SPELL_EFFECT_APPLY_AURA |
| `EffectAura_1` | see below | Aura type |
| `ImplicitTargetA_1` | 1 | TARGET_UNIT_CASTER |
| `DurationIndex` | 21 | Permanent (-1 duration) |
| `ProcChance` | **101** | **CRITICAL — must be 101, not 0!** |
| `EquippedItemClass` | -1 | No weapon requirement |
| `Attributes` | **2147549184** | **0x10000 (show icon) + 0x80000000 (NO_AURA_CANCEL) = visible + can't cancel** |

### How to find correct EffectAura values

**NEVER guess aura IDs.** Always look them up from the exported `Spell.csv`:

```python
# Find what aura type a known spell uses
import csv
with open('.claude/dbc/Spell.csv', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    col = {h: i for i, h in enumerate(header)}
    for row in reader:
        if row[0] == '131':  # Water Breathing
            print(f'EffectAura_1: {row[col["EffectAura_1"]]}')
            print(f'Attributes: {row[col["Attributes"]]}')
            break
```

### Known EffectAura values (verified from Spell.csv)

| Aura | ID | Effect | Source Spell |
|------|----|--------|-------------|
| MOD_WATER_BREATHING | **82** | Breathe underwater | 131 |
| WATER_WALK | 104 | Walk on water | 10665 |
| MOD_INCREASE_SPEED | 31 | Movement speed % | 22586 |
| MOD_INCREASE_SWIM_SPEED | 32 | Swim speed % | 8747 |
| MOD_INCREASE_MOUNTED_SPEED | 43 | Mount speed % | 48777 |
| FEATHER_FALL | 105 | Slow fall | 10729 |
| MOD_RESISTANCE | 22 | All resistances | 18677 |
| PERIODIC_HEAL | 8 | HP regen | 18764 |
| MOD_STAT | 29 | Stat bonus | — |
| PROC_TRIGGER_SPELL | 42 | Proc on event | — |

> **WARNING:** Aura 46 (SPELL_AURA_WATER_BREATHING) does NOT work for water breathing.
> The correct aura is **82** (MOD_WATER_BREATHING). Always verify from Spell.csv!

### Passive aura SQL template

```sql
REPLACE INTO spell_dbc (
  ID, Attributes, EquippedItemClass, ProcChance,
  CastingTimeIndex, DurationIndex,
  Effect_1, EffectAura_1, ImplicitTargetA_1,
  SchoolMask, SpellIconID, Name_Lang_enUS
) VALUES (
  100020,
  65536,           -- shows buff icon (0 = hidden!)
  -1,              -- no weapon requirement
  101,             -- MUST be 101 for passive auras!
  1,               -- instant
  21,              -- permanent duration
  6,               -- APPLY_AURA
  82,              -- MOD_WATER_BREATHING (NOT 46!)
  1,               -- TARGET_UNIT_CASTER
  1,               -- Physical school
  545,             -- buff icon (look up from Spell.csv!)
  'Water Breathing'
);
```

### Passive aura enchant (EQUIP_SPELL = type 3)

```sql
-- Note: Effect_1=3 (EQUIP_SPELL), NOT 1 (COMBAT_SPELL)
INSERT INTO spellitemenchantment_dbc (...) VALUES
(90077, 0, 3, 0, 0, ..., 100020, 0, 0, 'Water Breathing', ...);

-- No spell_enchant_proc_data needed (not a combat proc)
```

## Step 1c: Design an Activatable Aura (USE_SPELL)

Same as passive aura but with key differences:

| Field | Value | Notes |
|-------|-------|-------|
| `Attributes` | **65536** | Show icon only. **NO** `NO_AURA_CANCEL` — player should be able to cancel |
| `DurationIndex` | **9** | 5 minutes (not 21/permanent) |
| `ProcChance` | **101** | Still required for aura to persist |

### USE_SPELL enchant (Effect_1=7)

```sql
-- Enchant: Effect_1=7 (USE_SPELL), NOT 3 (EQUIP_SPELL)
INSERT INTO spellitemenchantment_dbc (...) VALUES
(90085, 0, 7, 0, 0, ..., 100031, 0, 0, 'Immolate', ...);
```

### USE_SPELL tooltip (##SB## tag)

For USE_SPELL, the client shows the spell's **Description** field in the item tooltip (not the enchant name or spell name). To get the StatBoostTooltip addon to recolor it yellow, add `##SB##` to the **Description** fields in `Spell_custom.csv`:

```
Description_Lang_zhTW = ##SB##Удача: При ударе наносит 30 ед. урона от огня атакующему.
Description_Lang_ruRU = ##SB##Удача: При ударе наносит 30 ед. урона от огня атакующему.
```

The `AuraDescription` (buff tooltip when hovering the buff icon) should NOT have `##SB##` — use clean text there.

### Key differences: EQUIP_SPELL vs USE_SPELL

| | EQUIP_SPELL (3) | USE_SPELL (7) |
|---|---|---|
| Activation | Auto when equipped | Player clicks item |
| Duration | Permanent (DurationIndex=21) | Timed (DurationIndex=9 = 5min) |
| Cancel | NO_AURA_CANCEL (0x80000000) | Allow cancel (Attributes=65536) |
| Reapply | Auto on equip | Click again |
| Tooltip source | Enchant name from SpellItemEnchantment | Spell Description from Spell.dbc |
| ##SB## location | Enchant name in SpellItemEnchantment CSV | Spell Description in Spell CSV |
| MPQ needed | SpellItemEnchantment.dbc | SpellItemEnchantment.dbc + Spell.dbc |

### How to find SpellVisualID

**NEVER guess visual IDs.** Always look them up from the exported `Spell.csv`:

1. Export the full `Spell.dbc` to CSV using your DBC editor
2. Save as `.claude/dbc/Spell.csv`
3. Find the spell you want to copy the visual from:

```python
import csv
with open('.claude/dbc/Spell.csv', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    col = {h: i for i, h in enumerate(header)}
    for row in reader:
        if row[0] == '1449':  # Arcane Explosion
            print(f'SpellVisualID_1: {row[col["SpellVisualID_1"]]}')
            break
```

### Known SpellVisualID values (verified from Spell.csv)

| ID | Source Spell | Visual |
|----|-------------|--------|
| 965 | Arcane Explosion (1449) | Purple AoE burst |
| 657 | Water Walk (10665) | Water ripple |
| 13785 | Craft spells | Crafting sparkle |

### Useful Attributes

| Attribute | Hex | Purpose |
|-----------|-----|---------|
| IMPOSSIBLE_DODGE_PARRY_BLOCK | 0x10000000 | Proc damage can't be dodged |
| CANT_BE_REFLECTED | 0x00000004 (Ex2) | AoE shouldn't be reflected |
| NO_INITIAL_AGGRO | 0x00000100 (Ex3) | Proc doesn't pull extra mobs |

## Step 2: Add to Server DB (spell_dbc)

```sql
REPLACE INTO spell_dbc (
  ID, Attributes, EquippedItemClass,
  CastingTimeIndex, Effect_1, EffectBasePoints_1, EffectDieSides_1,
  ImplicitTargetA_1, ImplicitTargetB_1, EffectRadiusIndex_1,
  SchoolMask, DefenseType, PreventionType,
  SpellIconID, SpellVisualID_1,
  Name_Lang_enUS
) VALUES (
  100017,          -- Unique spell ID
  0,               -- Attributes (keep 0 for triggered procs!)
  -1,              -- EquippedItemClass (-1 = no weapon requirement!)
  1,               -- Instant cast
  2,               -- SCHOOL_DAMAGE
  79, 40,          -- 80-120 damage
  17,              -- TARGET_DEST_CASTER (AoE origin at caster)
  15,              -- TARGET_UNIT_DEST_AREA_ENEMY (hit enemies)
  13,              -- 10 yard radius
  64,              -- Arcane school
  1, 1,            -- DefenseType=Magic, PreventionType=Silence
  12, 6950,        -- Icon, Visual
  'Arcane Burst'
);
```

## Step 3: Add to Client DBC (Spell_custom.csv)

Add a row to `.claude/dbc/Spell_custom.csv` with all 234 columns.

**IMPORTANT:** The CSV column order differs from the `spell_dbc` DB table!
The `_1`/`_2`/`_3` effect fields are offset by 1 vs what you might expect.
Always use the **header names**, not hardcoded column numbers.

Key column positions in `Spell_custom.csv` (0-indexed, from header):

| Col | Header | Example value |
|-----|--------|--------------|
| 0 | ID | 100017 |
| 4 | Attributes | 268435456 |
| 6 | AttributesExB | 4 |
| 7 | AttributesExC | 256 |
| 26 | CastingTimeIndex | 1 (instant) |
| 33 | ProcChance | 101 |
| 44 | RangeIndex | 1 (self) |
| 66 | EquippedItemClass | -1 |
| **69** | **Effect_1** | 2 (SCHOOL_DAMAGE) |
| **72** | **EffectDieSides_1** | 40 |
| **78** | **EffectBasePoints_1** | 79 |
| **84** | **ImplicitTargetA_1** | 22 (AoE) |
| **90** | **EffectRadiusIndex_1** | 13 (10yd) |
| **129** | **SpellVisualID_1** | 6950 |
| **131** | **SpellIconID** | 12 |
| **134** | **Name_Lang_enUS** | Arcane Burst |
| **142** | **Name_Lang_zhTW** | Чародейский взрыв (**ruRU locale quirk — Russian text goes here!**) |
| **145** | **Name_Lang_ruRU** | Чародейский взрыв (also set here) |
| 150 | Name_Lang_Mask | 16712190 |
| **168** | **Description_Lang_enUS** | Deals 80 to 120... |
| **176** | **Description_Lang_zhTW** | Наносит от 80 до 120... (**ruRU locale quirk**) |
| **179** | **Description_Lang_ruRU** | Наносит от 80 до 120... (also set here) |
| 184 | Description_Lang_Mask | 16712190 |
| 185-200 | AuraDescription_Lang_* | (empty for damage spells) |
| 201 | AuraDescription_Lang_Mask | 16712188 (empty) |
| **223** | **SchoolMask** | 64 (Arcane) |

**WARNING:** Effect_1 is col **69**, NOT 70! Effect_2 is 70, Effect_3 is 71.
Same pattern for all `_1`/`_2`/`_3` fields — the `_1` variant is always 1 less than you'd guess from the DB table order.

**Best practice:** Copy an existing row (e.g., 100017) as template, then only change ID, damage values, and descriptions. Use a script with `header[col_name]` lookup instead of hardcoded indices.

### Validation checklist

After adding/modifying rows, run this verification:

```python
import csv

path = r'.claude/dbc/Spell_custom.csv'
with open(path, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    col = {h: i for i, h in enumerate(header)}
    
    for row in reader:
        errors = []
        # 1. Column count
        if len(row) != len(header):
            errors.append(f'Column count {len(row)} != {len(header)}')
        
        # 2. Lang_Mask values must be numeric, not text
        for h in header:
            if '_Mask' in h:
                v = row[col[h]]
                if v and not v.isdigit():
                    errors.append(f'{h}(col {col[h]}) has text: [{v[:50]}]')
        
        # 3. Effect fields in _1 slot (not _2)
        if row[col['Effect_1']] == '0' and row[col['Effect_2']] != '0':
            errors.append(f'Effect in _2 slot instead of _1')
        
        # 4. Description matches damage values
        bp = row[col['EffectBasePoints_1']]
        ds = row[col['EffectDieSides_1']]
        desc = row[col['Description_Lang_enUS']]
        if bp and ds and bp != '0' and desc:
            expected_min = str(int(bp) + 1)
            expected_max = str(int(bp) + int(ds))
            if expected_min not in desc or expected_max not in desc:
                errors.append(f'Description damage mismatch: BP={bp} DS={ds} -> {expected_min}-{expected_max}, desc=[{desc}]')
        
        if errors:
            print(f'ERROR {row[0]}: {"; ".join(errors)}')
        else:
            print(f'OK {row[0]}')
```

### Common mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Effect data in `_2` cols instead of `_1` | Spell does nothing | Use col 69 (Effect_1), not 70 (Effect_2) |
| Text in `_Mask` column | DBC import crash | `NameSubtext_Lang_Mask` = 16712188, `Description_Lang_Mask` = 16712190 |
| Wrong Description for tier variants | Tooltip shows wrong damage | Update both `enUS` (col 168) and `ruRU` (col 179) per tier |
| AuraDescription filled for damage spells | Confusing tooltip | Leave AuraDescription empty, set Mask = 16712188 |
| Extra/missing column | DBC import crash | Always copy from existing row, verify col count = 232 |
| `EquippedItemClass = 0` | "You must hold %s" error | Set to `-1` (no weapon requirement). Col 66 in CSV. Default `0` means "requires consumable" |
| `TargetA=22` AoE hits self | Proc damages caster | Use `TargetA=17` (DEST_CASTER) + `TargetB=15` (DEST_AREA_ENEMY). Never use `TargetA=22` alone for triggered procs |
| `Attributes = 268435456` | Various proc issues | Set `Attributes=0` for triggered proc spells. Fancy attr flags interfere with proc targeting |
| `ProcChance = 0` on passive aura | Aura applies then instantly expires | Set `ProcChance = 101` in spell_dbc. ALL passive aura spells need this |
| `Attributes = 0` on passive aura | Buff works but no icon visible | Set `Attributes = 2147549184` to show icon + prevent cancel |
| NO_AURA_CANCEL only in server DB | Player can still right-click cancel | `NO_AURA_CANCEL` is a **client-side check** — must be set in BOTH server `spell_dbc` AND client `Spell.dbc` (MPQ) |
| USE_SPELL tooltip not yellow | Addon doesn't recolor "Use:" line | For USE_SPELL, put `##SB##` in spell **Description** (not enchant name). The client shows Description for "Use:" lines |
| USE_SPELL with NO_AURA_CANCEL | Player can't deactivate the buff | USE_SPELL should use `Attributes=65536` (no NO_AURA_CANCEL). Player needs right-click to cancel |
| Wrong `EffectAura` (46 vs 82) | Spell does nothing | Always verify aura ID from Spell.csv. e.g. Water Breathing = 82, NOT 46 |
| `SpellIconID = 0` | Buff has blank icon | Look up icon from source spell in Spell.csv (e.g. 545 for water breathing) |
| Wrong `SpellVisualID` | No visual in-game | **Never guess.** Export `Spell.dbc` → `Spell.csv`, find the source spell, copy its `SpellVisualID_1` value |
| Russian text only in `ruRU` | Name shows blank in-game | ruRU client reads `zhTW` column — put Russian text in BOTH `Name_Lang_zhTW` (col 142) AND `Name_Lang_ruRU` (col 145). Same for Description (cols 176 + 179) |

## Step 4: Add StatBooster Enchant

```sql
-- Enchant entry (Effect_1=1 for COMBAT_SPELL = melee proc)
INSERT INTO spellitemenchantment_dbc (...) VALUES
(90074, 0, 1, 0, 0, ..., 100017, 0, 0, 'Arcane Burst', ...);

-- Pool template
INSERT INTO statbooster_enchant_template (...) VALUES
(90074, 46, 92, 0, 0, 0, 0, 'Arcane Burst', 'T3-T4, weapons', 4, 2);

-- Proc rate
INSERT INTO spell_enchant_proc_data (entry, customChance, PPMChance, procEx, attributeMask) VALUES
(90074, 0, 3, 0, 0);  -- 3 PPM
```

## Step 5: Add to Client DBC (SpellItemEnchantment_custom.csv)

```
90074,0,1,0,0,0,0,0,0,0,0,100017,0,0,,,,,,,,,##SB##Удача: Чародейский взрыв,,,,,,,,16712190,0,0,0,0,0,0,0
```

## Step 6: Build MPQ

1. Convert CSVs to DBC format using your DBC editor
2. Pack into `patch-4.MPQ` (or next available patch number)
3. Place in WoW `Data` folder
4. Distribute to all players

## Existing Custom Spells

| Spell ID | Enchant ID | Name | Damage | Tier | iLvl |
|----------|-----------|------|--------|------|------|
| 100018 | 90075 | Arcane Burst | 20-35 Arcane AoE, 10yd | T1 | 1-25 |
| 100019 | 90076 | Arcane Burst | 45-70 Arcane AoE, 10yd | T2 | 26-45 |
| 100017 | 90074 | Arcane Burst | 80-120 Arcane AoE, 10yd | T3-T4 | 46-92 |
| **Passive Auras (EQUIP_SPELL)** | | | | | |
| 100020 | 90077 | Water Breathing | Breathe underwater | All | 1-92 |
| 100024 | 90081 | Frost Armor | +200 armor, frost slow proc | T2-T4 | 26-92 |
| 100025 | 90030 | Thorns | 3 Nature retribution | T1 | 1-25 |
| 100026 | 90031 | Thorns | 18 Nature retribution | T2 | 26-45 |
| 100027 | 90032 | Thorns | 25 Nature retribution | T3-T4 | 46-92 |
| 100032 | 90086 | Blood Pact | +20 HP party aura | T1 | 1-25 |
| 100033 | 90087 | Blood Pact | +70 HP party aura | T2 | 26-45 |
| 100034 | 90088 | Blood Pact | +270 HP party aura | T3 | 46-65 |
| 100035 | 90089 | Blood Pact | +380 HP party aura | T4 | 66-92 |
| **Activatable Auras (USE_SPELL)** | | | | | |
| 100028 | 90082 | Immolate | 5 Fire retribution, 5min | T1 | 1-25 |
| 100029 | 90083 | Immolate | 12 Fire retribution, 5min | T2 | 26-45 |
| 100030 | 90084 | Immolate | 20 Fire retribution, 5min | T3 | 46-65 |
| 100031 | 90085 | Immolate | 30 Fire retribution, 5min | T4 | 66-92 |

## File Locations

| File | Purpose |
|------|---------|
| `.claude/dbc/Spell_custom.csv` | Client Spell.dbc entries |
| `.claude/dbc/SpellItemEnchantment_custom.csv` | Client enchant tooltips |
| `data/sql/updates/pending_db_world/statbooster_use_spells.sql` | Server DB (enchants + spells + templates) |
