# Fortune Pool v2c — Full Mechanics Design (Classic Tier, iLvl 1-92)

## Overview

Comprehensive Fortune pool built from the WotLK mechanics reference (чары вов v.1.txt).
Combines passive auras with carefully balanced proc effects and unique utility.
**All values tuned for Classic content (max iLvl 92, level 60 endgame).**
All spells verified in client Spell.dbc. Uses EQUIP_SPELL (type 3) enchantments.
No C++ code changes — SQL only.

## Design Philosophy

- **Pools 1-3** give flat stats (str, sta, int, AP, SP, etc.)
- **Pool 4 (Fortune)** gives **unique mechanics** you can't get from stats:
  speed, regen, procs, CC resist, travel utility, thorns, lifesteal, etc.
- Tiered by iLvl across 4 Classic tiers: T1 (1-25), T2 (26-45), T3 (46-65), T4 (66-92)
- **Weak enchants are capped** — lower-tier versions stop appearing once better ones unlock
- No effect should be game-breaking at level 60 — Classic endgame is the ceiling
- WotLK-tier procs (Mongoose, Executioner, Berserking) removed — too strong for Classic

## Enchant ID Range: 90001-90099

---

## SECTION A: PASSIVE AURAS (always active while equipped)

### A1. Movement & Travel (RoleMask=0, all roles)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90001 | 22586 | +5% Movement Speed | 1-45 | Replaced by +8% at T3 |
| 90002 | 22587 | +8% Movement Speed | 46-92 | T3+ upgrade |
| 90003 | 30424 | Water Walk + Feather Fall | 1-92 | Combo: Aura 104+105 |
| 90004 | 8747 | +15% Swim Speed | 1-92 | Aura 58 |
| 90005 | 48777 | +3% Mounted Speed | 1-92 | Aura 32, subtle but nice |
| 90006 | 1860 | Reduce Fall Damage | 26-92 | Safe Fall, ~17% reduction |

### A2. Detection (RoleMask=0, all roles)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90007 | 58985 | Stealth Detect +5 | 1-92 | "Alertness", Aura 17 |

### A3. Defensive Passives (RoleMask=1, tank)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90008 | 18677 | +6 All Magic Resist | 1-25 | T1 only, replaced by +10 |
| 90009 | 18681 | +10 All Magic Resist | 26-65 | T2-T3, replaced by +20 at T4 |
| 90010 | 21348 | +6 HP5 in Combat | 1-25 | T1 only, replaced by +10 |
| 90011 | 21349 | +10 HP5 in Combat | 26-65 | T2-T3, replaced by +16 at T4 |
| 90012 | 25063 | +2% Threat (all schools) | 1-92 | Aura 10, all tiers |
| 90013 | 23172 | +20 Block Value | 1-45 | Shields only, replaced by +27 |
| 90014 | 23515 | +27 Block Value | 46-92 | Shields only, T3+ upgrade |

### A4. Offensive Passives — Physical (RoleMask=2, phys DPS)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90015 | 9332 | +22 AP (melee+ranged) | 1-25 | T1 only, replaced by +30 |
| 90016 | 9336 | +30 AP (melee+ranged) | 26-45 | T2 only, replaced by +40 |
| 90017 | 14049 | +40 AP (melee+ranged) | 46-65 | T3 only, replaced by +60 at T4 |
| 90018 | 25070 | -4% Threat (all schools) | 1-92 | Aura 10, all tiers |

### A5. Offensive Passives — Caster (RoleMask=8, spell)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90019 | 9416 | +11 SP + Healing | 1-25 | T1 only, replaced by +21 |
| 90020 | 14248 | +21 SP + Healing | 26-45 | T2 only, replaced by +35 |
| 90021 | 14055 | +35 SP + Healing | 46-65 | T3 only, replaced by +43 at T4 |
| 90022 | 21361 | +4 MP5 | 1-25 | T1 only, replaced by +6 |
| 90023 | 21363 | +6 MP5 | 26-65 | T2-T3, replaced by +13 at T4 |

### A6. Hybrid (RoleMask=4)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90024 | 18686 | +15 All Magic Resist | 26-92 | Aura 22 |
| 90025 | 21350 | +14 HP5 in Combat | 26-92 | Aura 161, "Vitality" |
| 90026 | 20555 | +10% Health Regen Rate | 1-92 | Aura 88, Troll racial |

### A7. CC Resistance (RoleMask=0, all roles)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90027 | 55357 | -10% Fear Duration | 46-92 | Impassive Skyflare effect |
| 90028 | 55358 | -10% Stun Duration | 46-92 | Earthsiege effect |

### A8. Reputation Bonus (RoleMask=0, all roles)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90029 | 20599 | +10% Reputation Gain | 1-92 | Diplomacy (Human racial) |

---

## SECTION B: DAMAGE / COMBAT PASSIVES (RoleMask varies)

### B1. Thorns — Damage to Attackers (RoleMask=1, tank)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90030 | 467 | 3 Nature dmg to melee attackers | 1-25 | Thorns R1, T1 only |
| 90031 | 9910 | 18 Nature dmg to melee attackers | 26-45 | Thorns R6, T2 only |
| 90032 | 26992 | 25 Nature dmg to melee attackers | 46-92 | Thorns R7, T3+ |

### B2. Spell Reflect (RoleMask=1, tank)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90033 | 11818 | 1% Spell Reflect | 66-92 | Rare, T4 only reward |

---

## SECTION C: PROC EFFECTS (trigger on hit)

Classic-era weapon enchant procs — well known, well balanced for level 60.
All weapons only (ItemClassFilter=2).

### C1. Weapon Procs — Damage (RoleMask=2, phys DPS)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90040 | 43929 | Fiery Weapon: ~40 fire dmg on hit | 1-45 | T1-T2, replaced by better procs |
| 90041 | 20004 | Lifesteal: drain 30 HP on hit | 1-92 | Shadow school, all tiers |
| 90042 | 20005 | Icy Chill: 30% move slow + 25% atk slow 5s | 26-92 | Frost snare, T2+ |
| 90043 | 20006 | Unholy: shadow dmg + reduce phys dmg 15, 12s | 26-92 | Debuff on hit, T2+ |

### C2. Weapon Procs — Buff on Hit (RoleMask=2, phys DPS)

| Enchant ID | Spell ID | Effect | iLvl | Notes |
|---|---|---|---|---|
| 90044 | 20007 | Crusader: +100 Str + heal 75-125 for 15s | 66-92 | Classic top-tier, T4 only |

---

## SECTION D: T4 ENDGAME EXCLUSIVES (iLvl 66-92 only)

These enchants are only available at T4, giving endgame gear the best Fortune rolls.
Every role gets a strong T4 reward.

| Enchant ID | Spell ID | Effect | RoleMask | Notes |
|---|---|---|---|---|
| 90033 | 11818 | 1% Spell Reflect | 1 (tank) | Shields only |
| 90044 | 20007 | Crusader: +100 Str + heal for 15s | 2 (phys) | Weapons only |
| 90045 | 17280 | +43 SP + Healing | 8 (spell) | Best caster Fortune roll |
| 90046 | 20959 | +13 MP5 | 8 (spell) | Best healer regen Fortune roll |
| 90047 | 14052 | +60 AP (melee+ranged) | 2 (phys) | Best melee Fortune roll |
| 90048 | 18691 | +20 All Magic Resist | 1 (tank) | Best resist roll, great for raids |
| 90049 | 23210 | +16 HP5 in Combat | 1 (tank) | Best regen Fortune roll |

---

## SECTION E: ROLE-SPECIFIC SUMMARY

### What each role can get from Fortune:

**Tank (RoleMask=1):**
- All Magic Resist (+6 → +10 → +20)
- HP5 in Combat (+6 → +10 → +16)
- +2% Threat
- Block Value (+20 → +27) — shields only
- Thorns (3 → 18 → 25 nature dmg)
- 1% Spell Reflect (T4, shields only)
- Plus all "all roles" effects

**Physical DPS (RoleMask=2):**
- AP (+22 → +30 → +40 → +60)
- -4% Threat
- Weapon procs: Fiery → Lifesteal/Icy Chill/Unholy → Crusader
- Plus all "all roles" effects

**Caster (RoleMask=8):**
- SP + Healing (+11 → +21 → +35 → +43)
- MP5 (+4 → +6 → +13)
- Plus all "all roles" effects

**Hybrid (RoleMask=4):**
- +15 All Resist
- +14 HP5 in Combat
- +10% Health Regen Rate
- Plus all "all roles" effects

**All Roles (RoleMask=0):**
- Movement Speed (+5% → +8%)
- Water Walk + Feather Fall
- Swim Speed (+15%)
- Mounted Speed (+3%)
- Reduce Fall Damage
- Stealth Detect (+5)
- Fear Duration -10% (T3+)
- Stun Duration -10% (T3+)
- Reputation Gain +10%

---

## ITEM CLASS FILTERING

| Enchant IDs | Item Class | ItemClassFilter |
|---|---|---|
| 90013, 90014 (Block Value) | Shields only | 6 |
| 90030-90032 (Thorns) | Armor only | 4 |
| 90033 (Spell Reflect) | Shields only | 6 |
| 90040-90044, 90047 (Weapon/AP Procs) | Weapons only | 2 |
| All others | Any | 0 |

Note: 90047 (+60 AP) uses ItemClassFilter=0 (any item), same as other AP passives.
Only weapon procs need weapon filtering.

---

## TIER DISTRIBUTION (Classic tiers, iLvl 1-92)

Weak enchants capped so higher tiers only roll better versions (Option A).

### T1: iLvl 1-25 (Apprentice, skill 25) — 19 enchants
- Movement: +5% speed, water walk, swim speed, +3% mount
- Detection: stealth detect +5
- Tank: +6 resist, +6 HP5, +2% threat, +20 block, 3 thorns
- Phys: +22 AP, -4% threat, fiery proc, lifesteal proc
- Caster: +11 SP, +4 MP5
- Hybrid: +10% HP regen
- Utility: +10% rep

### T2: iLvl 26-45 (Journeyman, skill 100) — 21 enchants
**Removed from pool:** +6 resist, +6 HP5, +22 AP, +11 SP, +4 MP5, 3 thorns, +20 block (7 gone)
**Added:** safe fall, +10 resist, +10 HP5, +30 AP, +21 SP, +6 MP5, +15 hybrid resist, +14 hybrid HP5, 18 thorns, icy chill, unholy (11 new)
- Movement: +5% speed, water walk, swim speed, +3% mount, safe fall
- Detection: stealth detect +5
- Tank: +10 resist, +10 HP5, +2% threat, +20 block, 18 thorns
- Phys: +30 AP, -4% threat, fiery proc, lifesteal, icy chill, unholy
- Caster: +21 SP, +6 MP5
- Hybrid: +15 resist, +14 HP5, +10% HP regen
- Utility: +10% rep

### T3: iLvl 46-65 (Expert, skill 175) — 22 enchants
**Removed from pool:** +5% speed, +30 AP, +21 SP, 18 thorns, fiery proc (5 gone)
**Added:** +8% speed, +27 block, +40 AP, +35 SP, 25 thorns, -10% fear, -10% stun (7 new)
- Movement: +8% speed, water walk, swim speed, +3% mount, safe fall
- Detection: stealth detect +5
- Tank: +10 resist, +10 HP5, +2% threat, +27 block, 25 thorns
- Phys: +40 AP, -4% threat, lifesteal, icy chill, unholy
- Caster: +35 SP, +6 MP5
- Hybrid: +15 resist, +14 HP5, +10% HP regen
- CC resist: -10% fear, -10% stun
- Utility: +10% rep

### T4: iLvl 66-92 (Artisan, skill 250) — 24 enchants
**Removed from pool:** +10 resist, +10 HP5, +40 AP, +35 SP, +6 MP5 (5 gone)
**Added:** +20 resist, +16 HP5, +60 AP, +43 SP, +13 MP5, Crusader, 1% spell reflect (7 new)
- Movement: +8% speed, water walk, swim speed, +3% mount, safe fall
- Detection: stealth detect +5
- Tank: +20 resist, +16 HP5, +2% threat, +27 block, 25 thorns, 1% spell reflect
- Phys: +60 AP, -4% threat, lifesteal, icy chill, unholy, Crusader
- Caster: +43 SP, +13 MP5
- Hybrid: +15 resist, +14 HP5, +10% HP regen
- CC resist: -10% fear, -10% stun
- Utility: +10% rep

---

## SPELL VERIFICATION

All spell IDs verified present in client Spell.dbc (Spell.csv):

```
22586, 22587, 30424, 8747, 48777, 1860, 58985,
18677, 18681, 21348, 21349, 25063, 23172, 23515,
9332, 9336, 14049, 25070,
9416, 14248, 14055, 21361, 21363,
18686, 21350, 20555,
55357, 55358, 20599,
467, 9910, 26992, 11818,
43929, 20004, 20005, 20006, 20007,
17280, 20959, 14052, 18691, 23210
```

---

## BALANCE NOTES (Classic context)

### Classic stat budget reference (level 60):
- Good melee DPS has ~300-500 AP, 15-25% crit
- Good caster has ~300-500 SP, 15-20% spell crit
- Tank has ~5000-8000 HP, ~50-65% damage reduction
- MP5 items range from 4-12 MP5
- Magic resist: 100+ resist = noticeable in raid, 200+ = meaningful

### Why these values work for Classic:
- **+60 AP** (T4) = ~4.3 DPS bonus. Strong but not game-breaking for iLvl 66+ gear.
- **+43 SP** (T4) = roughly a high-end Classic weapon enchant equivalent. Fair for endgame.
- **+13 MP5** (T4) = top-tier single-slot regen. Strong but appropriate for raid healers.
- **+20 All Resist** (T4) = noticeable raid benefit for MC/BWL/AQ resist fights.
- **+16 HP5 combat** (T4) = strong tank sustain, better than most items at this level.
- **Crusader proc** (T4) = the premier Classic enchant; fits naturally at iLvl 66+.
- **+5%/+8% speed** = meaningful QoL, not combat-breaking.
- **Thorns R7 (25 dmg)** at T3 = the actual Classic Thorns value at level 60; fair.

### Tier graduation ensures quality:
- T1 scroll can't roll +6 resist when +10 exists (it's capped at iLvl 25)
- T4 scroll won't waste a roll on +22 AP when +60 AP is available
- Utility effects (speed, water walk, rep) persist across all tiers — always valuable

### Removed from v2c (too strong for Classic):
- ~~Mongoose (+120 Agi +30 haste)~~ — TBC enchant, +120 Agi = ~5% crit + dodge at 60
- ~~Executioner (+120 ArP)~~ — WotLK enchant, ArP barely exists in Classic
- ~~Berserking (+400 AP -5% armor)~~ — WotLK enchant, nearly doubles Classic DPS AP
- ~~+3% Crit Damage (44797)~~ — Chaotic Skyflare effect, multiplicative scaling too strong

### Potentially strong — monitor in testing:
- **90033 (1% Spell Reflect)** — rare (T4 shields only) but strong in PvP
- **90029 (+10% Rep)** — very desirable, universal
- **90044 (Crusader)** — strong but already a common Classic weapon enchant

---

## IMPLEMENTATION PLAN

### Current state (v1):
- **Client MPQ** has `SpellItemEnchantment_custom.csv` with 96 proc-based entries (IDs 90001-90105)
  referencing WotLK boss/trinket spells with ruRU names
- **Server DB** has:
  - `spellitemenchantment_dbc`: 8 entries from `statbooster_use_spells.sql` (90001-90008)
  - `statbooster_enchant_template`: 96 entries from `fortune_enchants.sql` (90010-90105, PoolGroup=4)
    + 8 entries from `statbooster_use_spells.sql` (90001-90008, PoolGroup=4)
- **Other DBC patches** (unchanged by v2c):
  - `Spell_custom16.csv`: 17 spells (100000 use-spell + 100001-100016 craft spells)
  - `SkillLineAbility_custom16.csv`: 16 profession links
  - `Item_custom16.csv`: 16 scroll items (100001-100016)
  - `ItemDisplayInfo_custom16.csv`: display info for 16 items

### Step 1: Update client MPQ — `SpellItemEnchantment_custom.csv`
Replace 96 v1 proc entries with 42 v2c passive aura entries.
Each row: ID, Effect_1=3 (EQUIP_SPELL), EffectArg_1=spell ID, ruRU name.

**ID mapping (v2c enchant ID → spell ID → ruRU name):**
```
90001 → 22586 → "+5% к скорости передвижения"
90002 → 22587 → "+8% к скорости передвижения"
90003 → 30424 → "Хождение по воде + Замедленное падение"
90004 → 8747  → "+15% к скорости плавания"
90005 → 48777 → "+3% к скорости на маунте"
90006 → 1860  → "Уменьшение урона от падения"
90007 → 58985 → "Обнаружение незаметности"
90008 → 18677 → "+6 ко всем сопротивлениям"
90009 → 18681 → "+10 ко всем сопротивлениям"
90010 → 21348 → "+6 к регенерации здоровья в бою"
90011 → 21349 → "+10 к регенерации здоровья в бою"
90012 → 25063 → "+2% к угрозе"
90013 → 23172 → "+20 к блокированию"
90014 → 23515 → "+27 к блокированию"
90015 → 9332  → "+22 к силе атаки"
90016 → 9336  → "+30 к силе атаки"
90017 → 14049 → "+40 к силе атаки"
90018 → 25070 → "-4% к угрозе"
90019 → 9416  → "+11 к силе заклинаний"
90020 → 14248 → "+21 к силе заклинаний"
90021 → 14055 → "+35 к силе заклинаний"
90022 → 21361 → "+4 к восполнению маны за 5 сек."
90023 → 21363 → "+6 к восполнению маны за 5 сек."
90024 → 18686 → "+15 ко всем сопротивлениям"
90025 → 21350 → "+14 к регенерации здоровья в бою"
90026 → 20555 → "+10% к регенерации здоровья"
90027 → 55357 → "-10% к длительности страха"
90028 → 55358 → "-10% к длительности оглушения"
90029 → 20599 → "+10% к получению репутации"
90030 → 467   → "Шипы (3 урона)"
90031 → 9910  → "Шипы (18 урона)"
90032 → 26992 → "Шипы (25 урона)"
90033 → 11818 → "1% отражения заклинаний"
90040 → 43929 → "Огненное оружие"
90041 → 20004 → "Похищение жизни"
90042 → 20005 → "Леденящий холод"
90043 → 20006 → "Нечестивое проклятие"
90044 → 20007 → "Крестоносец"
90045 → 17280 → "+43 к силе заклинаний"
90046 → 20959 → "+13 к восполнению маны за 5 сек."
90047 → 14052 → "+60 к силе атаки"
90048 → 18691 → "+20 ко всем сопротивлениям"
90049 → 23210 → "+16 к регенерации здоровья в бою"
```

### Step 2: Update server SQL — `statbooster_use_spells.sql`
Replace entire file with v2c content:

```sql
-- 1. Clean old Fortune enchants (v1)
DELETE FROM `spellitemenchantment_dbc` WHERE `ID` BETWEEN 90001 AND 90105;
DELETE FROM `statbooster_enchant_template` WHERE `Id` BETWEEN 90001 AND 90105;

-- 2. Insert 42 new spellitemenchantment_dbc entries (EQUIP_SPELL → passive aura)
REPLACE INTO `spellitemenchantment_dbc` (...) VALUES
  (90001, 0, 3, 0, 0, ..., 22586, ..., '+5% Movement Speed', ...),
  -- ... all 42 entries

-- 3. Insert 42 statbooster_enchant_template entries (PoolGroup=4)
REPLACE INTO `statbooster_enchant_template` (...) VALUES
  (90001, 1, 45, 0, 0, 0, 351535086, '+5% Movement Speed', 'ALL - T1-T2', 4),
  -- ... all 42 entries with correct iLvl ranges, RoleMask, ItemClassFilter
```

### Step 3: Clean up old files
- Delete or archive `fortune_enchants.sql` (replaced by updated `statbooster_use_spells.sql`)
- The old `fortune_pool_data.json`, `fortune_pool_design.md`, `fortune_spell_pool.md`,
  `gen_pool.py` in `.claude/statBoosterItems/` are v1 artifacts — can be archived

### Step 4: Rebuild client MPQ patch
- Replace `SpellItemEnchantment_custom.csv` in the MPQ with the new 42-entry version
- No changes to: `Spell_custom16.csv`, `Item_custom16.csv`,
  `SkillLineAbility_custom16.csv`, `ItemDisplayInfo_custom16.csv`
- Distribute updated MPQ to all clients

### Step 5: Apply to server
```
1. Stop worldserver
2. Run the updated statbooster_use_spells.sql against acore_world
3. Start worldserver
4. Verify: SELECT COUNT(*) FROM statbooster_enchant_template WHERE PoolGroup = 4;
   → should return 42
```

### Step 6: Test
- `.sb additem <scroll_id> 1` to get scrolls without crafting
- Use each tier scroll on items at matching iLvl ranges
- Verify:
  - Passive auras apply on equip (check buffs panel)
  - Auras remove on unequip
  - Tier graduation works (T4 doesn't roll +22 AP)
  - ItemClassFilter works (weapon procs only on weapons, block value only on shields)
  - Attribute Recalibrator (41605) re-rolls Fortune enchants within Pool 4

---

## FILES TO MODIFY

| File | Action | Notes |
|------|--------|-------|
| `.claude/statBoosterItems/dbc/SpellItemEnchantment_custom.csv` | **Replace** | 96 → 42 entries |
| `data/sql/updates/pending_db_world/statbooster_use_spells.sql` | **Replace** | Full v2c SQL |
| `.claude/statBoosterItems/fortune_enchants.sql` | **Archive/Delete** | Replaced by use_spells |
| No changes to C++ code | — | Same EQUIP_SPELL mechanism |
| No changes to Spell/Item/SkillLine DBC patches | — | All aura spells already in client |

## TOTAL: 42 enchants across 4 tiers

| Section | Count | Type |
|---------|-------|------|
| A: Passive Auras | 29 | Always-on |
| B: Combat Passives | 4 | Thorns + Reflect |
| C: Weapon Procs | 5 | On-hit triggers |
| D: T4 Exclusives | 5 | Endgame rewards (new) |
| **Total unique IDs** | **42** | *(some from A-C also appear in D)* |

Unique enchant IDs: 90001-90033, 90040-90049 = **42 enchants**

## COMPARISON: v1 vs v2b vs v2c

| Aspect | v1 (procs only) | v2b (passive only) | v2c (Classic balanced) |
|--------|-----------------|--------------------|-----------------------|
| Enchant count | 8 | 20 | 42 |
| iLvl cap | 200 | 200 | 92 |
| Passive auras | 0 | 20 | 34 |
| Proc effects | 8 (WotLK trinkets) | 0 | 5 (Classic enchants) |
| Utility effects | 0 | 4 | 10 |
| CC resistance | 0 | 0 | 2 |
| T4 exclusives | 0 | 0 | 7 |
| Tier graduation | No | No | Yes (weak capped) |
| Power level | WotLK endgame | Mixed | Classic-appropriate |
| Code changes | None | None | None |
