# StatBooster Pool Scrolls — Changelog & Rollback Guide

## Date: 2026-03-30

## What was changed

### Code Changes (require rebuild to apply/rollback)

**1. StatBoostCfgMgr.h** — `modules/StatBooster/src/StatBoostCfgMgr.h`
- Added `PoolGroup` field to `EnchantDefinition` struct
- Added `GetFromPool()` method declaration to `EnchantPool` class

**2. StatBoostCfgMgr.cpp** — `modules/StatBooster/src/StatBoostCfgMgr.cpp`
- SQL query updated to SELECT `PoolGroup` column (with IFNULL fallback)
- `enchantDef.PoolGroup` loaded from query results
- New `GetFromPool(poolGroup, itemLevel)` method implemented

**3. StatBoostMgr.h** — `modules/StatBooster/src/StatBoostMgr.h`
- Added `BoostItemFromPool()` method declaration

**4. StatBoostMgr.cpp** — `modules/StatBooster/src/StatBoostMgr.cpp`
- New `BoostItemFromPool(player, item, poolGroup)` method implemented
- Picks random enchant from specific pool group matching item level

**5. StatBoost.cpp** — `modules/StatBooster/src/StatBoost.cpp`
- Replaced hardcoded item ID 41605 check with config-driven `IsRerollScroll()`
- Added `GetScrollPoolGroup()` — reads `StatBooster.ScrollPool.<itemId>` from config
- Pool scrolls (poolGroup > 0): can ONLY enchant unenchanted items
- Attribute Recalibrator (poolGroup = 0): can ONLY reroll already boosted items
- Removed global `AllowBoostedItemsOnly` check (now per-item-type logic)

### Database Changes (SQL)

**File: `data/sql/updates/pending_db_world/statbooster_pool_scrolls.sql`**

Tables modified:
- `statbooster_enchant_template` — added `PoolGroup` column, assigned groups to existing enchants
- `spell_dbc` — 16 new craft spell entries (IDs 100001-100016), each creates the matching item
- `item_template` — 16 scroll items using repurposed vanilla QA IDs (17827-17830, 18599, 17883-17885, 17888-17889, 17891-17896)
- `skilllineability_dbc` — 16 new skill-spell links (IDs 100001-100016)
- `npc_trainer` — 16 new trainer recipe entries

**File: `data/sql/updates/pending_db_world/statbooster_use_spells.sql`**

Tables modified:
- `spellitemenchantment_dbc` — custom enchant entries (IDs 90001-90041)
- `statbooster_enchant_template` — use-spell enchant entries (IDs 90001-90041)

### Config Changes

**File: `env/dist/etc/modules/statbooster.conf`**
- Added `StatBooster.ScrollPool.<itemId> = <poolGroup>` mappings for items 100001-100016
- Changed `StatBooster.Reroll.AllowBoostedItemsOnly = 1` (no longer used by code, kept for reference)

---

## Rollback Instructions

### To rollback SQL (run against acore_world):

```sql
-- Remove scroll items (repurposed vanilla QA IDs)
DELETE FROM `item_template` WHERE `entry` IN (17827,17828,17829,17830,18599,17883,17884,17885,17889,17888,17891,17892,17893,17894,17895,17896);

-- Remove craft spells
DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 100001 AND 100016;

-- Remove skill links
DELETE FROM `skilllineability_dbc` WHERE `ID` BETWEEN 100001 AND 100016;

-- Remove trainer recipes
DELETE FROM `npc_trainer` WHERE `SpellID` BETWEEN 100001 AND 100016;

-- Remove PoolGroup column
ALTER TABLE `statbooster_enchant_template` DROP COLUMN `PoolGroup`;

-- Remove equip-spell proc enchantments
DELETE FROM `spellitemenchantment_dbc` WHERE `ID` BETWEEN 90001 AND 90008;
DELETE FROM `statbooster_enchant_template` WHERE `Id` BETWEEN 90001 AND 90008;
```

### To rollback code:

Use git to restore original files:
```bash
cd modules/StatBooster
git checkout -- src/StatBoostCfgMgr.h src/StatBoostCfgMgr.cpp src/StatBoostMgr.h src/StatBoostMgr.cpp src/StatBoost.cpp
```

Then rebuild:
```bash
docker compose up -d --build ac-worldserver
```

### To rollback config:

Remove the `ScrollPool` section from `statbooster.conf` and restart.

---

## Item/Spell/ID Reference

### Pool Groups
| Pool | ID | Description |
|---|---|---|
| General | 0 | All enchants (Attribute Recalibrator 41605) |
| Battle | 1 | Offensive stats (str, agi, AP, crit, haste, arpen, expertise) |
| Warding | 2 | Defensive stats (sta, armor, defense, dodge, block, health) |
| Arcana | 3 | Caster stats (int, spirit, spell power, mana) |
| Fortune | 4 | Use-spell effects (heal, mana restore, rejuv, buffs) |

### Scroll Items (repurposed vanilla QA item IDs)
| Entry | Name | Profession | Pool | iLvl Range | Skill Req |
|---|---|---|---|---|---|
| 17827 | Runed Whetstone | Blacksmithing | 1 | 1-35 | 25 |
| 17828 | Tempered Whetstone | Blacksmithing | 1 | 30-60 | 150 |
| 17829 | Honed Whetstone | Blacksmithing | 1 | 55-80 | 275 |
| 17830 | Masterwork Whetstone | Blacksmithing | 1 | 75-200 | 375 |
| 18599 | Runed Armor Patch | Leatherworking | 2 | 1-35 | 25 |
| 17883 | Tempered Armor Patch | Leatherworking | 2 | 30-60 | 150 |
| 17884 | Hardened Armor Patch | Leatherworking | 2 | 55-80 | 275 |
| 17885 | Masterwork Armor Patch | Leatherworking | 2 | 75-200 | 375 |
| 17889 | Minor Arcane Vellum | Enchanting | 3 | 1-35 | 25 |
| 17888 | Arcane Vellum | Enchanting | 3 | 30-60 | 150 |
| 17891 | Greater Arcane Vellum | Enchanting | 3 | 55-80 | 275 |
| 17892 | Superior Arcane Vellum | Enchanting | 3 | 75-200 | 375 |
| 17893 | Minor Glyph of Fortune | Inscription | 4 | 1-35 | 25 |
| 17894 | Glyph of Fortune | Inscription | 4 | 30-60 | 150 |
| 17895 | Major Glyph of Fortune | Inscription | 4 | 55-80 | 275 |
| 17896 | Grand Glyph of Fortune | Inscription | 4 | 75-200 | 375 |

### Equip-Spell Proc Enchantments (Fortune Pool 4)
Uses EQUIP_SPELL (type 3) with existing client spell IDs — no client DBC patches needed.

| Entry | Client Spell | Effect | Role | iLvl |
|---|---|---|---|---|
| 90001 | 60306 (Vestige of Haldor) | 1024-1536 Fire damage, 15% proc, 45s ICD | All | 55+ |
| 90002 | 60301 (Meteorite Whetstone) | +444 Haste for 10s, 15% proc, 45s ICD | Phys | 55+ |
| 90003 | 33648 (Reflection of Torment) | +1000 AP for 10s on crit, 10% proc, 50s ICD | Phys | 75+ |
| 90004 | 62114 (Flow of Knowledge) | +590 SP for 10s, 10% proc, 50s ICD | Spell | 55+ |
| 90005 | 49623 (Effervescence) | +125 MP5 for 15s, 10% proc, 45s ICD | Hybrid/Spell | 55+ |
| 90006 | 60218 (Essence of Gossamer) | Absorb shield (-140/hit, 10s), 5% proc, 45s ICD | Tank | 55+ |
| 90007 | 51352 (Venture Co Beatdown) | 200 mana on kill, 10s ICD | Hybrid/Spell | 30+ |
| 90008 | 27522 (Mana Drain Trigger) | +8 mana on hit, drain 8 from target | All | 1+ |

### Trainer Template IDs
| Profession | Template IDs |
|---|---|
| Blacksmithing | 201004 (base), 201005 (expert+), 201006 (grand master) |
| Leatherworking | 201029 (all tiers) |
| Enchanting | 201011 (all tiers) |
| Inscription | 201021 (base), 201022 (expert+), 201023 (grand master) |
