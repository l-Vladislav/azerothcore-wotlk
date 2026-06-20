# mod-environmental-effects spell memory

## Spell ID range: 107000-107016

Reserved for `mod-environmental-effects` environmental aura spells.
These are NOT in the 1,000,000+ custom range — they were assigned before
that convention was established. The range is confirmed clear in Spell.csv,
Spell_custom.csv, and spell_dbc SQL base.

## Key files

- SQL migration: `data/sql/updates/pending_db_world/mod_environmental_effects_spells.sql`
- DBC CSV rows: appended to `.claude/dbc/Spell_custom.csv` (lines 288-304 = IDs 107000-107016)
- Rule table seed: `data/sql/updates/pending_db_world/mod_environmental_effects_base.sql`

## PLACEHOLDER icon

All 17 spells use `SpellIconID = 1` as a placeholder. The user must supply
real icon IDs and update:
1. `spell_dbc` rows: run a new SQL `UPDATE spell_dbc SET SpellIconID=X WHERE ID=Y`
2. `Spell_custom.csv` rows: the placeholder `"1"` appears at the SpellIconID
   column position (field 133 in the 250-field row, right after SpellVisualID_2).

Search for SpellIconID replacements: `grep -n '"107[01][0-9][0-9]"' Spell_custom.csv`
or look for `"1","0","0","NAME_RU"` pattern — the SpellIconID is the `"1"` in
`"0","0","0","0","0","0","0","0","0","0","0","0","0","0","0","1","0","0","NAME"`.

## Common spell fields (all 17)

- Effect_1 = 6 (APPLY_AURA)
- DurationIndex = 21 (permanent)
- ProcChance = 101
- CastingTimeIndex = 1 (instant)
- RangeIndex = 1 (self-only)
- ImplicitTargetA_1 = 1 (caster)
- EquippedItemClass = -1

## Attributes

- BUFF: 2147483648 = 0x80000000 (NO_AURA_CANCEL only)
- DEBUFF: 2214592512 = 0x84000000 (NO_AURA_CANCEL + AURA_IS_DEBUFF)

## Per-ID summary

| ID     | Type   | Aura | School MiscVal | BasePoints |
|--------|--------|------|----------------|------------|
| 107000 | DEBUFF | 87   | 4 (Fire)       | 4 (+5%)    |
| 107001 | DEBUFF | 87   | 8 (Nature)     | 4 (+5%)    |
| 107002 | DEBUFF | 79   | 64 (Arcane)    | -6 (-5%)   |
| 107003 | DEBUFF | 87   | 32 (Shadow)    | 4 (+5%)    |
| 107004 | DEBUFF | 33   | 0 (speed)      | -4 (-3%)   |
| 107005 | DEBUFF | 87   | 16 (Frost)     | 4 (+5%)    |
| 107006 | DEBUFF | 33   | 0 (speed)      | -4 (-3%)   |
| 107007 | BUFF   | 79   | 4 (Fire)       | 4 (+5%)    |
| 107008 | BUFF   | 79   | 64 (Arcane)    | 4 (+5%)    |
| 107009 | BUFF   | 79   | 32 (Shadow)    | 4 (+5%)    |
| 107010 | BUFF   | 79   | 8 (Nature)     | 4 (+5%)    |
| 107011 | BUFF   | 79   | 16 (Frost)     | 4 (+5%)    |
| 107012 | BUFF   | 133  | 0              | 2 (+3% HP) |
| 107013 | BUFF   | 31   | 0              | 4 (+5% spd)|
| 107014 | BUFF   | 88+110 | 0+0          | 9+9 (+10%) |
| 107015 | BUFF   | 137  | -1 (all stats) | 1 (+2%)    |
| 107016 | DEBUFF | 87   | 32 (Shadow)    | 4 (+5%)    |

## AURA constants used

- 31 = MOD_INCREASE_SPEED
- 33 = MOD_DECREASE_SPEED
- 79 = MOD_DAMAGE_PERCENT_DONE
- 87 = MOD_DAMAGE_PERCENT_TAKEN
- 88 = MOD_HEALTH_REGEN_PERCENT
- 110 = MOD_POWER_REGEN_PERCENT
- 133 = MOD_INCREASE_HEALTH_PERCENT
- 137 = MOD_TOTAL_STAT_PERCENTAGE

## MOD_DECREASE_SPEED debuff note

By default, MOD_DECREASE_SPEED cast on self is treated as positive by AC's
`_IsPositiveEffect`. The `SPELL_ATTR0_AURA_IS_DEBUFF` flag (0x04000000) in
Attributes=0x84000000 forces debuff display. This is already included in all
debuff spells (107000-107006, 107016).
