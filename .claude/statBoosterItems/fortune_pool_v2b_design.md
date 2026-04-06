# Fortune Pool v2b — Passive Auras (SQL Only, No Code Changes)

## Overview
Replaces the old proc-based Fortune pool (random trinket effects with ICD) with permanent passive auras.
Effects are always active while the item is equipped — consistent and predictable.

All spells exist in client Spell.dbc. Uses EQUIP_SPELL (type 3) enchantments.
No C++ code changes needed — just SQL + existing StatBooster module logic.

## Pool Groups Reference
- Pool 0 = General (Attribute Recalibrator 41605)
- Pool 1 = Battle (str, agi, AP, crit, haste, armor pen, expertise)
- Pool 2 = Warding (sta, armor, defense, dodge, block, health)
- Pool 3 = Arcana (int, spirit, spell power, mana)
- Pool 4 = Fortune (passive auras — this document)

## RoleMask Reference
- 0 = all roles
- 1 = tank
- 2 = physical DPS
- 4 = hybrid
- 8 = spell/caster

## Enchant ID Range: 90001-90099

---

## Utility (All roles, RoleMask=0)

| Enchant ID | Spell ID | Effect | Value | iLvl Range | Notes |
|---|---|---|---|---|---|
| 90001 | 22586 | +Movement Speed | +5% | 1-200 | Clean single-effect, Attr=128 |
| 90002 | 22587 | +Movement Speed | +8% | 30-200 | Mid-level+, Attr=128 |
| 90003 | 30424 | Water Walk + Feather Fall | — | 1-200 | Combo spell (Spirit Walk), Attr=0 |
| 90004 | 58985 | Stealth Detect | +5 | 1-200 | Named "Alertness", Attr=320 |

## Defensive / Tank (RoleMask=1)

| Enchant ID | Spell ID | Effect | Value | iLvl Range | Notes |
|---|---|---|---|---|---|
| 90005 | 18677 | +All Magic Resist | +6 | 1-200 | Attr=192, item passive |
| 90006 | 18681 | +All Magic Resist | +10 | 30-200 | Attr=192, item passive |
| 90007 | 21348 | +HP5 in Combat | +6 | 1-200 | "Vitality" series, Attr=448 |
| 90008 | 21349 | +HP5 in Combat | +10 | 30-200 | "Vitality" series, Attr=448 |
| 90009 | 25063 | +Threat Generation | +2% all | 1-200 | Attr=192, item passive |

## Offensive Physical (RoleMask=2)

| Enchant ID | Spell ID | Effect | Value | iLvl Range | Notes |
|---|---|---|---|---|---|
| 90010 | 9332 | +Attack Power | +22 AP (melee+ranged) | 1-200 | Dual AP/RAP, Attr=192 |
| 90011 | 9336 | +Attack Power | +30 AP (melee+ranged) | 26-200 | Dual AP/RAP, Attr=192 |
| 90012 | 14049 | +Attack Power | +40 AP (melee+ranged) | 46-200 | Dual AP/RAP, Attr=192 |
| 90013 | 25070 | -Threat | -4% all | 1-200 | Attr=192, item passive |

## Caster (RoleMask=8)

| Enchant ID | Spell ID | Effect | Value | iLvl Range | Notes |
|---|---|---|---|---|---|
| 90014 | 9416 | +Spell Power + Healing | +11 | 1-200 | Dual SP/Healing, Attr=192 |
| 90015 | 14248 | +Spell Power + Healing | +21 | 26-200 | Dual SP/Healing, Attr=192 |
| 90016 | 14055 | +Spell Power + Healing | +35 | 46-200 | Dual SP/Healing, Attr=192 |
| 90017 | 21361 | +Mana per 5 | +4 MP5 | 1-200 | Attr=448, passive |
| 90018 | 21363 | +Mana per 5 | +6 MP5 | 26-200 | Attr=448, passive |

## Hybrid (RoleMask=4)

| Enchant ID | Spell ID | Effect | Value | iLvl Range | Notes |
|---|---|---|---|---|---|
| 90019 | 18686 | +All Magic Resist | +15 | 30-200 | Attr=192, item passive |
| 90020 | 21350 | +HP5 in Combat | +14 | 30-200 | "Vitality" series, Attr=448 |

---

## Spell Details (from Spell.dbc)

### Movement Speed (Aura 31)
- **22586**: Effect_1=6, EffectAura_1=31, BasePoints=4 (+5%), single effect
- **22587**: Effect_1=6, EffectAura_1=31, BasePoints=7 (+8%), single effect

### Water Walk + Feather Fall
- **30424**: Effect_1=6 EffectAura_1=104 (Water Walk) + Effect_2=6 EffectAura_2=105 (Feather Fall)

### Stealth Detect (Aura 17)
- **58985**: Effect_1=6, EffectAura_1=17, BasePoints=4 (+5), named "Alertness"

### All Magic Resist (Aura 22, MiscVal=126)
- **18677**: BP=5 (+6), **18681**: BP=9 (+10), **18686**: BP=14 (+15)

### Combat HP Regen (Aura 161)
- **21348**: BP=5 (+6), **21349**: BP=9 (+10), **21350**: BP=13 (+14)

### Threat (Aura 10, MiscVal=127 all schools)
- **25063**: BP=1 (+2% threat increase), **25070**: BP=-3 (-4% threat reduction)

### Attack Power (Aura 99 + Aura 124 ranged)
- **9332**: BP=21 (+22), **9336**: BP=29 (+30), **14049**: BP=39 (+40)

### Spell Power (Aura 13 MiscVal=126 + Aura 135 healing)
- **9416**: BP=10 (+11), **14248**: BP=20 (+21), **14055**: BP=34 (+35)

### Mana Regen (Aura 85, MiscVal=0)
- **21361**: BP=3 (+4), **21363**: BP=5 (+6)

---

## Implementation

Each enchant needs two SQL entries:

### 1. `spellitemenchantment_dbc` — EQUIP_SPELL pointing to the passive aura spell

```sql
REPLACE INTO `spellitemenchantment_dbc`
  (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`,
   `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`,
   `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`,
   `EffectArg_1`, `EffectArg_2`, `EffectArg_3`,
   `Name_Lang_enUS`, `Name_Lang_Mask`,
   `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`,
   `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`)
VALUES
  (90001, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 22586, 0, 0,
   '+5% Movement Speed', 0, 0, 0, 0, 0, 0, 0, 0);
-- Effect_1=3 = ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL
-- EffectArg_1 = spell ID from Spell.dbc
```

### 2. `statbooster_enchant_template` — pool entry with PoolGroup=4

```sql
REPLACE INTO `statbooster_enchant_template`
  (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`,
   `ItemTypeMask`, `Description`, `Note`, `PoolGroup`)
VALUES
  (90001, 1, 200, 0, 0, 0, 351535086, '+5% Movement Speed', 'ALL - any iLvl', 4);
```

### ItemTypeMask
- 351535086 = all except shields/tabards (same as other pools)

---

## Balance Notes

- **Movement speed** (+5-8%) is the standout unique effect — not available in any other pool
- **Water Walk + Feather Fall** is a rare utility combo — high perceived value, low combat impact
- **Threat modification** is niche but valuable for tanks/DPS in group content
- **Combat HP regen** benefits all roles during leveling
- **Stealth Detect** is PvP/world utility
- **AP/SP** values overlap with Pool 1/3 stat enchants but use passive aura spells with dual melee+ranged AP or dual SP+healing — slightly different from flat stat enchants
- iLvl gating prevents overpowered effects on low-level gear

## Comparison: v1 (Procs) vs v2b (Passive Auras)

| Aspect | v1 (procs) | v2b (passive auras) |
|--------|-----------|---------------------|
| Behavior | Random chance to fire, ICD | Always active while equipped |
| Predictability | Unpredictable | Consistent |
| Power budget | Spike damage/buffs | Steady passive bonuses |
| Code changes | None | None (same EQUIP_SPELL mechanism) |
| Client DBC | Existing trinket spell IDs | Existing passive aura spell IDs |
| Player feel | Exciting procs | Reliable enchants |

## Files to Modify

### SQL only:
- `data/sql/updates/pending_db_world/statbooster_use_spells.sql` — replace proc enchants with passive aura enchants
- No C++ changes, no client MPQ changes
