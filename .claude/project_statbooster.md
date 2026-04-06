---
name: StatBooster Module Setup
description: StatBooster enchant module — current config, all stat types, enchant IDs, DB tables, how to add new effects
type: project
---

## Status: DISABLED (StatBooster.Enable = 0)

Config: `env/dist/etc/modules/statbooster.conf`

## Current Config Settings
- Enable: 0 (disabled)
- Triggers: loot (100%), quest reward (100%), craft (100%)
- Quality range: Uncommon (2) to Epic (4)
- Sound: enabled (ID 120)
- Soulbind on enchant: all disabled
- Overwrite existing enchants: enabled
- Reroll: owned items only, not restricted to boosted items
- Reroll visual: spell 62015

## Database Tables (acore_world)

### `statbooster_enchant_template`
Defines which enchantments can roll on items.

Columns: `Id` (SpellItemEnchantment DBC ID), `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`

**RoleMask bitmask:** 0=all, 1=tank, 2=phys, 4=hybrid, 8=spell (combine with addition: 3=tank+phys, 7=tank+phys+hybrid, 12=hybrid+spell, 15=all)

**ItemTypeMask:** 351535086 = all except shields/tabards

### `statbooster_enchant_scores`
Defines how item stats are scored per role to pick the best enchant.

Columns: `mod_type` (0=item stat, 1=spell aura), `mod_id`, `subclass`, `tank_score`, `phys_score`, `spell_score`, `hybrid_score`, `note`

## Currently Installed Stats (285 entries in latest SQL update)

| Stat | Values Available | RoleMask |
|---|---|---|
| Strength | 1-46 (24 tiers) | 3 (tank/phys) |
| Agility | 1-46 (24 tiers) | 7 (tank/phys/hybrid) |
| Intellect | 1-46 (24 tiers) | 12 (hybrid/spell) |
| Stamina | 1-45 (23 tiers) | 0 (all) |
| Spirit | 1-46 (24 tiers) | 8 (spell) |
| Attack Power | 2-130 (29 tiers) | 3 (tank/phys) |
| Spell Power | 1-81 (23 tiers) | 8 (spell) |
| Crit Rating | 3, 7, 14, 28, 42, 56 (6 tiers) | varies |
| Haste Rating | 4, 6, 8, 10, 12, 14, 16, 20, 23, 34 (10 tiers) | varies |
| Defense Rating | 2, 3, 4, 5, 7, 10, 15, 20, 25, 30, 35, 38 (12 tiers) | 1 (tank) |
| Expertise Rating | 4, 6, 8, 12, 14, 16, 20, 34 (8 tiers) | varies |
| Armor Pen Rating | 4, 6, 8, 12, 14, 16, 20, 34 (8 tiers) | varies |
| Block Value | 3, 4, 5, 6, 10, 15, 20 (7 tiers) | 1 (tank) |
| Armor | 32-885 (18 tiers) | varies |
| Health | 15, 50, 100, 150, 275 (5 tiers) | 0 (all) |
| Mana | 20, 30, 50, 65, 100, 150 (6 tiers) | varies |

## Stats NOT in the Module (could be added)

| Stat | Available DBC Enchant IDs |
|---|---|
| Hit Rating | 2880 (+3), 3858 (+5), 2844 (+8), 3660 (+14), 3460 (+16), 3528 (+20) |
| Dodge Rating | 2871 (+4), 2849 (+7), 3304 (+8), 2622 (+12), 3646 (+14), 3450 (+16), 3522 (+20) |
| Resilience Rating | 3821 (+8), 3229 (+12), 3462 (+16), 3530 (+20) |
| Parry Rating | already in enchant_scores but not in template |

## Scoring Table (mod_type = 0: item stats)

| mod_id | Stat | Tank | Phys | Spell | Hybrid |
|---|---|---|---|---|---|
| 4 | Strength | 1 | 2 | 0 | 1 |
| 3 | Agility | 1 | 2 | 0 | 1 |
| 5 | Intellect | varies by subclass | | | |
| 6 | Spirit | 0 | 0 | 1 | 0 |
| 38 | Attack Power | 1 | 2 | 0 | 1 |
| 44 | Armor Pen | 1 | 2 | 0 | 1 |
| 45 | Spell Power | 0 | 0 | 1 | 0 |
| 47 | Spell Penetration | 0 | 0 | 1 | 0 |
| 43 | Mana Regen | 0 | 0 | 1 | 0 |
| 12 | Defense Rating | 3 | 0 | 0 | 0 |
| 13 | Dodge Rating | 3 | 0 | 0 | 0 |
| 14 | Parry Rating | 3 | 0 | 0 | 0 |
| 15 | Block Rating | 3 | 0 | 0 | 0 |
| 37 | Expertise Rating | not in scores |
| 31 | Hit Rating | not in scores |
| 32 | Crit Rating | not in scores |
| 36 | Haste Rating | not in scores |
| 35 | Resilience | not in scores |

## Scoring Table (mod_type = 1: spell auras)

| mod_id | Aura | Tank | Phys | Spell | Hybrid |
|---|---|---|---|---|---|
| 99 | MOD_ATTACK_POWER | 1 | 2 | 0 | 1 |
| 135 | MOD_HEALING_DONE | 0 | 0 | 0 | 1 |
| 85 | MOD_POWER_REGEN | 0 | 0 | 0 | 1 |
| 13 | MOD_DAMAGE_DONE | 0 | 0 | 0 | 1 |

## How to Add New Effects

1. Find enchant ID from SpellItemEnchantment.dbc (or use known IDs above)
2. Add row to `statbooster_enchant_template` via SQL on `acore_world`
3. Optionally add scoring entry to `statbooster_enchant_scores`
4. Restart server (no rebuild needed)

Example SQL:
```sql
INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`) VALUES
(2880, 1, 76, 0, 0, 0, 351535086, '+3 HitRating', 'ALL - ALL - ALL');
```

## SQL Files
- Base: `modules/StatBooster/data/sql/db-world/base/statbooster_world_0000_00_00_00.sql`
- Latest update: `modules/StatBooster/data/sql/db-world/updates/statbooster_world_2024_08_5_01.sql` (285 entries, adds ItemTypeMask column)

## GM Commands
- `.sb` — list subcommands
- `.sb additem <itemid> <count>` — add enchanted item to target player
