# mod-environmental-effects spell memory

## v2 Spell ID ranges (current)

- Buffs: 107000-107146 (147 spells) — positive auras
- Debuffs: 107500-107528 (29 spells) + 108500 (1 spell) — negative auras
- Total: 177 DBC rows in `Spell_custom.csv`

These are NOT in the 1,000,000+ custom range — assigned before that convention.
All confirmed clear in Spell.csv base. v1 range (107000-107016) replaced in v2.

## Key files

- SQL migration: `data/sql/updates/pending_db_world/mod_environmental_effects_spells.sql`
- DBC CSV rows: `.claude/dbc/Spell_custom.csv` (last 177 rows)
- SpellIcon additions: `.claude/dbc/SpellIcon_custom.csv` (IDs 50000, 50001)
- Manifest (authoritative per-spell client data): `modules/mod-environmental-effects/docs/client_manifest.csv`
- SpellIcon additions source: `modules/mod-environmental-effects/docs/spellicon_additions.csv`
- Rule table seed: `data/sql/updates/pending_db_world/mod_environmental_effects_base.sql`

## Verified column positions in Spell_custom.csv (232 columns)

| Index | Field             | Notes                          |
|-------|-------------------|--------------------------------|
| 0     | ID                |                                |
| 4     | Attributes        | BUFF=2147483648, DEBUFF=2214592512 |
| 26    | CastingTimeIndex  | =1 (instant)                   |
| 33    | ProcChance        | =101                           |
| 38    | DurationIndex     | =21 (permanent)                |
| 44    | RangeIndex        | =1 (self)                      |
| 66    | EquippedItemClass | =-1                            |
| 69    | Effect_1          | =6 (APPLY_AURA)                |
| 72    | EffectDieSides_1  | =1                             |
| 78    | EffectBasePoints_1|                                |
| 84    | ImplicitTargetA_1 | =1 (caster)                    |
| 93    | EffectAura_1      |                                |
| 108   | EffectMiscValue_1 |                                |
| 131   | SpellIconID       |                                |
| 134   | Name_Lang_enUS    | RU text fills this too         |
| 145   | Name_Lang_ruRU    |                                |
| 150   | Name_Lang_Mask    | =16712190                      |
| 167   | NameSubtext_Mask  | =16712188                      |
| 168   | Desc_Lang_enUS    | RU text fills this too         |
| 179   | Desc_Lang_ruRU    |                                |
| 184   | Desc_Lang_Mask    | =16712190                      |
| 185   | AuraDesc_enUS     | RU text fills this too         |
| 196   | AuraDesc_ruRU     |                                |
| 201   | AuraDesc_Mask     | =16712190                      |
| 223   | SchoolMask        | =1 (physical placeholder)      |

NOTE: The grep-based column index tool (counting header tokens) gives WRONG results
for this CSV. Always verify column positions by parsing actual data rows.

## v2 Common spell fields

- Effect_1 = 6 (APPLY_AURA)
- DurationIndex = 21 (permanent)
- ProcChance = 101
- CastingTimeIndex = 1 (instant)
- RangeIndex = 1 (self-only)
- ImplicitTargetA_1 = 1 (caster)
- EquippedItemClass = -1
- SchoolMask = 1 (placeholder; server overrides)

## v2 Aura template (display-only; server spell_dbc has real effects)

- BUFF (107000-107146): Aura=137 (MOD_TOTAL_STAT_PERCENTAGE), MiscVal=-1, BP=1
- DEBUFF (107500-107528, 108500): Aura=87 (MOD_DAMAGE_PERCENT_TAKEN), MiscVal=32 (shadow), BP=4

## Attributes

- BUFF: 2147483648 = 0x80000000 (NO_AURA_CANCEL only)
- DEBUFF: 2214592512 = 0x84000000 (NO_AURA_CANCEL + AURA_IS_DEBUFF)

## SpellIcon_custom.csv

Created at `.claude/dbc/SpellIcon_custom.csv` with 2 rows:
- ID 50000 → Interface\Icons\achievement_ladydeathwhisper
- ID 50001 → Interface\Icons\achievement_zone_dragonblight_05

Used by spells 107517 (Воля Плети) and 107525 (Тлен Драконьего Погоста).

## AURA constants used (v2 template)

- 87 = MOD_DAMAGE_PERCENT_TAKEN (debuff display)
- 137 = MOD_TOTAL_STAT_PERCENTAGE (buff display)
