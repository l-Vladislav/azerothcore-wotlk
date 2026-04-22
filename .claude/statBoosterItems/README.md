# StatBooster Custom Items — Complete Reference

## Overview

16 craftable scroll items across 4 professions that apply stat boosts from different pools.
Each scroll targets a specific item level range and enchant pool.

## Architecture

```
Player crafts scroll (profession recipe)
  → Spell.dbc (client) + spell_dbc (server) define the craft spell
  → SkillLineAbility.dbc (client) + skilllineability_dbc (server) link spell to profession
  → trainer_spell (server) makes it learnable from trainers (tier-aware)
  → Item.dbc (client) + item_template (server) define the created item
  → ItemDisplayInfo.dbc (client) provides icon/model for the displayid
  → StatBooster module (server config) maps item ID to enchant pool
```

## Tier System — Classic (iLvl 1-92, skill 1-300)

| Tier | Skill Req | Profession Tier | iLvl Range | Target Content |
|------|-----------|-----------------|------------|----------------|
| T1 | 25 | Apprentice | 1-25 | Early leveling (1-20) |
| T2 | 100 | Journeyman | 26-45 | Mid leveling (20-40) |
| T3 | 175 | Expert | 46-65 | Late leveling (40-55) |
| T4 | 250 | Artisan | 66-92 | Classic endgame (MC/BWL/AQ/Naxx) |

TBC and WotLK tiers to be added later.

## Item IDs: 100001–100016

### Blacksmithing → Battle Pool (1) — Offensive stats
| Item ID | Spell ID | Name (EN) | Name (RU) | iLvl Range | Skill Req | DisplayID | Icon |
|---------|----------|-----------|-----------|------------|-----------|-----------|------|
| 100001 | 100001 | Runed Whetstone | Рунный точильный камень | 1-25 | 25 | 24673 | SharpeningStone_01 |
| 100002 | 100002 | Tempered Whetstone | Закаленный точильный камень | 26-45 | 100 | 24675 | SharpeningStone_03 |
| 100003 | 100003 | Honed Whetstone | Отточенный точильный камень | 46-65 | 175 | 24676 | SharpeningStone_04 |
| 100004 | 100004 | Masterwork Whetstone | Мастерский точильный камень | 66-92 | 250 | 39193 | SharpeningStone_07 |

### Leatherworking → Warding Pool (2) — Defensive stats
| Item ID | Spell ID | Name (EN) | Name (RU) | iLvl Range | Skill Req | DisplayID | Icon |
|---------|----------|-----------|-----------|------------|-----------|-----------|------|
| 100005 | 100005 | Runed Armor Patch | Рунная нашивка | 1-25 | 25 | 38761 | ArmorKit_21 |
| 100006 | 100006 | Tempered Armor Patch | Закаленная нашивка | 26-45 | 100 | 38762 | ArmorKit_25 |
| 100007 | 100007 | Hardened Armor Patch | Упрочненная нашивка | 46-65 | 175 | 38763 | ArmorKit_24 |
| 100008 | 100008 | Masterwork Armor Patch | Мастерская нашивка | 66-92 | 250 | 55478 | ArmorKit_28 |

### Enchanting → Arcana Pool (3) — Caster stats
| Item ID | Spell ID | Name (EN) | Name (RU) | iLvl Range | Skill Req | DisplayID | Icon |
|---------|----------|-----------|-----------|------------|-----------|-----------|------|
| 100009 | 100009 | Minor Arcane Vellum | Малый тайный пергамент | 1-25 | 25 | 634 | Scroll_04 |
| 100010 | 100010 | Arcane Vellum | Тайный пергамент | 26-45 | 100 | 1037 | Scroll_08 |
| 100011 | 100011 | Greater Arcane Vellum | Большой тайный пергамент | 46-65 | 175 | 1093 | Scroll_07 |
| 100012 | 100012 | Superior Arcane Vellum | Превосходный тайный пергамент | 66-92 | 250 | 39201 | Enchant_VoidCrystal |

### Inscription → Fortune Pool (4) — Equip-spell proc effects
**How it works:**
1. Use scroll on equipment → applies permanent EQUIP_SPELL enchant (via `SpellItemEnchantment` type 3)
2. When player **wears** the enchanted item → buff icon appears, proc aura is active
3. Unequip item → buff disappears
4. Re-equip item → buff comes back (like Mongoose/Crusader enchants)

**Requires client-side `SpellItemEnchantment.dbc`** — enchant IDs 90001-90008 must exist in the client DBC or the client won't display the enchant name, buff icon, or activate the proc. Server-side `spellitemenchantment_dbc` alone is not enough.
| Item ID | Spell ID | Name (EN) | Name (RU) | iLvl Range | Skill Req | DisplayID | Icon |
|---------|----------|-----------|-----------|------------|-----------|-----------|------|
| 100013 | 100013 | Minor Glyph of Fortune | Малый символ удачи | 1-25 | 25 | 57389 | Inscription_Scroll |
| 100014 | 100014 | Glyph of Fortune | Символ удачи | 26-45 | 100 | 57389 | Inscription_Scroll |
| 100015 | 100015 | Major Glyph of Fortune | Большой символ удачи | 46-65 | 175 | 57389 | Inscription_Scroll |
| 100016 | 100016 | Grand Glyph of Fortune | Великий символ удачи | 66-92 | 250 | 57389 | Inscription_Scroll |

## Reagents (all Classic-era materials)

### Blacksmithing
| Spell | Tier | Reagent 1 (qty) | Reagent 2 (qty) |
|-------|------|-----------------|-----------------|
| 100001 | T1 | 2840 Copper Bar (4) | 2835 Rough Stone (1) |
| 100002 | T2 | 3575 Iron Bar (4) | 2838 Heavy Stone (2) |
| 100003 | T3 | 12359 Thorium Bar (6) | 12365 Dense Stone (2) |
| 100004 | T4 | 6037 Truesilver Bar (4) | 12365 Dense Stone (4) |

### Leatherworking
| Spell | Tier | Reagent 1 (qty) | Reagent 2 (qty) |
|-------|------|-----------------|-----------------|
| 100005 | T1 | 2318 Light Leather (4) | 2320 Coarse Thread (1) |
| 100006 | T2 | 4234 Heavy Leather (6) | 4291 Silken Thread (2) |
| 100007 | T3 | 8170 Rugged Leather (8) | 14341 Rune Thread (2) |
| 100008 | T4 | 4304 Thick Leather (8) | 8171 Rugged Hide (2) |

### Enchanting
| Spell | Tier | Reagent 1 (qty) | Reagent 2 (qty) |
|-------|------|-----------------|-----------------|
| 100009 | T1 | 10940 Strange Dust (2) | 10938 Lesser Magic Essence (1) |
| 100010 | T2 | 11083 Soul Dust (4) | 10939 Greater Magic Essence (2) |
| 100011 | T3 | 16204 Illusion Dust (4) | 16203 Greater Eternal Essence (2) |
| 100012 | T4 | 14344 Large Brilliant Shard (2) | 16203 Greater Eternal Essence (4) |

### Inscription
| Spell | Tier | Reagent 1 (qty) | Reagent 2 (qty) |
|-------|------|-----------------|-----------------|
| 100013 | T1 | 39469 Moonglow Ink (2) | 39354 Light Parchment (1) |
| 100014 | T2 | 39774 Midnight Ink (3) | 10648 Common Parchment (1) |
| 100015 | T3 | 43116 Lion's Ink (3) | 10648 Common Parchment (2) |
| 100016 | T4 | 43120 Celestial Ink (4) | 39501 Heavy Parchment (2) |

## Trainer System

Recipes are added to the `trainer_spell` table (NOT the deprecated `npc_trainer`).
The SQL uses a **tier-aware dynamic INSERT**: it discovers all TrainerIds for a profession
by querying existing `trainer_spell` rows, then only adds recipes whose `ReqSkillRank`
falls within each trainer's existing max skill rank. This respects the
apprentice/journeyman/expert/artisan/master NPC tier system.

### Trainer tables (3-table system):
- `trainer` — defines trainer entities (Id, Type, Requirement, Greeting)
- `trainer_spell` — spells per trainer (TrainerId, SpellId, MoneyCost, ReqSkillLine, ReqSkillRank, ReqAbility1-3, ReqLevel)
- `creature_default_trainer` — links NPC CreatureIds to TrainerIds

### Trainer tiers per profession:

**Blacksmithing (164):** (skill reqs: 25/100/175/250)
| TrainerId | Max Rank | Tiers Taught | Recipes Added |
|-----------|----------|--------------|---------------|
| 616 | 75 | Apprentice | T1 only |
| 617 | 150 | Journeyman | T1-T2 |
| 618 | 215 | Expert | T1-T3 |
| 60 | 300 | Artisan | T1-T4 |
| 58 | 350 | Artisan+ | T1-T4 |
| 104, 123, 124 | 415 | Master | T1-T4 |
| 59 | 440 | Grand Master | T1-T4 |

**Leatherworking (165):** (skill reqs: 25/100/175/250)
| TrainerId | Max Rank | Tiers Taught | Recipes Added |
|-----------|----------|--------------|---------------|
| 631 | 75 | Apprentice | T1 only |
| 632 | 150 | Journeyman | T1-T2 |
| 633 | 225 | Expert | T1-T3 |
| 61 | 250 | Expert+ | T1-T4 |
| 651 | 350 | Artisan | T1-T4 |
| 62 | 350 | Artisan | T1-T4 |
| 105, 106, 107 | 375 | Master | T1-T4 |
| 64 | 450 | Grand Master | T1-T4 |
| 63 | 450 | Grand Master | T1-T4 |

**Enchanting (333):** (skill reqs: 25/100/175/250)
| TrainerId | Max Rank | Tiers Taught | Recipes Added |
|-----------|----------|--------------|---------------|
| 621 | 70 | Apprentice | T1 only |
| 622 | 150 | Journeyman | T1-T2 |
| 623 | 225 | Expert | T1-T3 |
| 96 | 250 | Expert+ | T1-T4 |
| 95 | 350 | Artisan | T1-T4 |
| 114 | 445 | Master | T1-T4 |
| 94 | 445 | Grand Master | T1-T4 |

**Inscription (773):** (skill reqs: 25/100/175/250)
| TrainerId | Max Rank | Tiers Taught | Recipes Added |
|-----------|----------|--------------|---------------|
| 121 | 315 | Expert | T1-T4 |
| 120 | 350 | Artisan | T1-T4 |
| 119 | 440 | Grand Master | T1-T4 |

## Client-Side Files (MPQ Patch)

All DBC files go into `Data/ruRU/patch-ruRU-B.MPQ` (or whichever is the last-loading MPQ) under `DBFilesClient/`.

### Required DBC modifications:

1. **Spell.dbc** — 16 new craft spell entries (Effect_1=24 CREATE_ITEM)
   - Reference CSV: `.claude/statBoosterItems/dbc/Spell_custom16.csv`

2. **SkillLineAbility.dbc** — 16 entries linking spells to professions
   - Reference CSV: `.claude/statBoosterItems/dbc/SkillLineAbility_custom16.csv`
   - **AcquireMethod = 0** (learn from trainer, NOT 1)
   - **MinSkillLineRank** = required skill level
   - **CharacterPoints_1/2** = skill-up color thresholds

3. **Item.dbc** — 16 entries mapping item IDs to displayids
   - Reference CSV: `.claude/statBoosterItems/dbc/Item_custom16.csv`
   - Required for icons and item names in recipe tooltips

4. **SpellItemEnchantment.dbc** — 8 entries for Fortune pool proc enchants (IDs 90001-90008)
   - Reference CSV: `.claude/statBoosterItems/dbc/SpellItemEnchantment_custom8.csv` (TODO: create)
   - Required for enchant tooltip text, buff icon on equip, and proc activation
   - Without this: enchant applies server-side but client shows nothing

### ruRU Locale Quirk
Russian text goes in the **zhTW** column (index 142 for Name, 176 for Description), NOT the ruRU column. This is a known WoW 3.3.5a ruRU client quirk.

### MPQ Loading Order
- Files in `Data/ruRU/` override `Data/` base files
- Patches load alphabetically: numbers (1-9) then letters (A-Z)
- `patch-ruRU-10.MPQ` does NOT work — only single character suffixes
- DBC files are NOT merged across MPQs — the last-loaded MPQ completely replaces the file
- Must include ALL original rows + custom rows in the DBC

## Server-Side Data

### Databases
- **acore_world** — main server
- **acore_world_ptr** — PTR server (separate DB, same MySQL instance)
- Changes must be applied to BOTH databases

### Tables modified:
- `item_template` — 16 new items (entries 100001-100016)
- `spell_dbc` — 16 craft spells (IDs 100001-100016)
  - Attributes=65568, AttributesEx=1024, CastingTimeIndex=16, Effect_1=24
  - SpellIconID set per profession (140=BS, 346=LW, 241=Ench, 2557=Insc)
- `skilllineability_dbc` — 16 skill links (IDs 100001-100016)
  - AcquireMethod=0, Classic skill reqs: 25/100/175/250
  - TrivialHigh/Low (skill-up thresholds): 75/150/225/300
- `trainer_spell` — recipes added tier-aware to trainers (NOT the deprecated `npc_trainer`).
  Dynamic SQL only adds a recipe to a trainer if `ReqSkillRank <= trainer's max_rank`
- `item_template` — spellid_1 = **100000** (custom "Apply Enhancement" spell)
- `item_template_locale` — Russian names/descriptions (locale='ruRU', must use `--default-character-set=utf8mb4`)
- `spell_dbc` ID 100000 — custom use-on-item spell (Effect_1=99, Targets=16, EquippedItemClass=-1, modeled after 10694)

### Config files:
- `env/dist/etc/modules/statbooster.conf` — main server
- `env/dist/etc-ptr/modules/statbooster.conf` — PTR server
- Maps `StatBooster.ScrollPool.<itemId>` / `ScrollMinILvl` / `ScrollMaxILvl`
- Classic iLvl ranges: T1=1-25, T2=26-45, T3=46-65, T4=66-92 (no overlaps, no gaps)

## SpellIconIDs (from SpellIcon.dbc)

| Profession | SpellIconID | SpellVisualID_1 | Source spell |
|------------|-------------|-----------------|-------------|
| Blacksmithing | 140 | 13785 | 2660 (Rough Sharpening Stone) |
| Leatherworking | 346 | 4439 | 2152 (Light Armor Kit) |
| Enchanting | 241 | 3182 | 7418 (Enchant Bracer - Minor Health) |
| Inscription | 2557 | 10130 | 58472 (Scroll of Agility) |

## School-Specific Spell Damage Spells (Aura 13 MOD_DAMAGE_DONE, Attr=192 ITEM)

All verified in Spell.dbc. Can be used as stat enchants in Pool 3 (Arcana) or EQUIP_SPELL in Pool 4.
Misc values: 2=holy, 4=fire, 8=nature, 16=frost, 32=shadow, 64=arcane, 126=all magic.

| School | +3 | +5 | +6 | +8 | +9 | +10 | +12 | +13 |
|--------|------|------|------|------|------|------|------|------|
| Fire | 7685 | 7686 | 7687 | 7688 | 7689 | 9399 | 9400 | 9401 |
| Frost | 7699 | 7700 | 7701 | 7702 | 7703 | 9402 | 9403 | 9404 |
| Nature | 7692 | 7693 | 7694 | 7695 | 7696 | 9409 | — | 9411 |
| Shadow | 7706 | 7707 | 7708 | 7710 | 7709 | 9412 | 9413 | 9414 |
| Arcane | 13592 | 13593 | 13594 | 13595 | 13596 | 13597 | 13598 | 13599 |
| Holy | 21501 | 21502 | 21503 | 21504 | 21505 | 21506 | 21507 | 21508 |

**Design note:** School-specific gives higher value but narrower use. Example: +6 frost vs +3 all-magic — trade versatility for power.

## Lessons Learned

1. **DBC column offsets matter** — always verify against the actual exported CSV header, not assumed positions
2. **ruRU locale uses zhTW column** — not the ruRU column in DBC files
3. **AcquireMethod=0 for trainer recipes** — value 1 means auto-learn, won't show at trainer
4. **CharacterPoints_1/2 for skill thresholds** — not TrivialSkillLineRankHigh/Low
5. **MPQ patches don't merge DBCs** — must include all original + custom rows
6. **Only single-char MPQ suffixes** — patch-ruRU-A.MPQ works, patch-ruRU-10.MPQ doesn't
7. **Item.dbc needed for icons** — without it, items show as red question marks with "0" names
8. **Server spell_dbc overrides client** — SpellIconID must be set on server side too
9. **PTR uses separate database** — acore_world_ptr, must update both
10. **PTR has separate config folder** — env/dist/etc-ptr/modules/
11. **spellid_1 on items matters** — 59404 is Lockpicking, 10694 is Disenchant. Use custom spell 100000 ("Apply Enhancement") instead
12. **item_template_locale for Russian item names** — server sends item names, not client DBC. Add ruRU entries to `item_template_locale` table
13. **MySQL charset matters** — use `--default-character-set=utf8mb4` flag when inserting Russian text via docker exec, otherwise double-encoding occurs (C3xx instead of D0xx)
14. **Custom use-spell 100000** — uses Effect_1=99 (FEED_PET as dummy item target), NOT 33 (OPEN_LOCK which only targets lockboxes). Modeled after spell 10694 used by original Attribute Recalibrator (41605). Don't override 59404 or lockpicks break
15. **StatBoost.cpp scan ranges are hardcoded** — `LoadScrollPoolMap()` in StatBoost.cpp has hardcoded item ID ranges. New item IDs must be added to `scanRanges[]` array (line ~155) or the config mappings won't load and the module won't intercept the spell. Requires rebuild.
16. **EQUIP_SPELL enchants need client DBC** — enchant IDs 90001-90008 (Fortune pool) use SpellItemEnchantment type 3 (EQUIP_SPELL). The server applies them correctly, but the client needs matching entries in `SpellItemEnchantment.dbc` to show enchant name in tooltip, buff icon when equipped, and activate the proc aura. Without client DBC: enchant exists but is invisible.
17. **PERM_ENCHANTMENT_SLOT for non-weapons** — changed from TEMP_ENCHANTMENT_SLOT so enchants persist permanently and EQUIP_SPELL buffs activate when item is worn
18. **`trainer_spell` NOT `npc_trainer`** — AzerothCore uses `trainer` + `trainer_spell` + `creature_default_trainer` tables. The old `npc_trainer` table is completely ignored by the server. TrainerIds are small numbers (58-651), not the old 201xxx format
19. **Trainer tiers matter** — not all trainers teach all skill levels. Apprentice NPCs (max rank ~75) should only get low-tier recipes. Use dynamic SQL with `WHERE ReqSkillRank <= trainer's MAX(ReqSkillRank)` to respect tiers. Extra trainer IDs (616-651) are added by playerbots module for additional NPC trainers
