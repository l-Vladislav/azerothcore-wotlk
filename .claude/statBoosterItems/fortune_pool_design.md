# Fortune Pool Redesign — 30+ Effects with Smart Apply

## Design: Smart Apply by Equipment Type

One Fortune scroll → detects target item type → picks appropriate proc from subcategory:

| Target Item | Subcategory | Effect Type |
|-------------|-------------|-------------|
| Weapon (class=2) | WEAPON | Offensive on-hit procs (damage, haste, AP, crit) |
| Shield (class=4, subclass=6) | SHIELD | Tank/special procs (reflect, absorb, block value, thorns) |
| Armor (class=4, not shield) | ARMOR | Defensive/utility procs (health, mana regen, SP, resist) |

### Implementation: Use existing `RoleMask` + new `ItemClassMask` field in `statbooster_enchant_template`

Option A (config/DB only, no code change):
- Use existing `ItemTypeMask` bitmask field to restrict enchants to specific inventory types
- Weapon slots = InventoryType 13,14,15,17,21,22,23,24,25,26
- Shield = InventoryType 14 (offhand, subclass check in code)
- Armor = everything else

Option B (small code change in `BoostItemFromPool`):
- Check `item->GetTemplate()->Class` and `SubClass` 
- Filter enchant pool by item type before random selection
- Most flexible, clean code

**Recommended: Option B** — add item class filter to `GetFromPool()` method.

## Verified Fortune Enchants (IDs 90001-90040)

All client spell IDs verified to exist in Spell.dbc (checked 2026-04-01).

### WEAPON Procs (on melee/ranged hit) — applied to ITEM_CLASS_WEAPON only

**Tier 1 (iLvl 1-35):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90008 | 27522 | +8 mana on hit, drain 8 from target | Weak, any level |
| 90010 | 42083 | Nature damage proc | Low-level damage proc |

**Tier 2 (iLvl 30-60):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90011 | 34774 | Lifesteal on hit | Mid-level sustain |
| 90012 | 23689 | Move speed proc | Utility |

**Tier 3 (iLvl 55-80):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90001 | 60306 | 1024-1536 Fire damage | Classic damage proc |
| 90002 | 60301 | +444 Haste Rating 10s | Offensive buff |

**Tier 4 (iLvl 75+):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90003 | 33648 | +1000 AP 10s on crit | Endgame melee |
| 90013 | 67556 | Crit proc | Endgame burst |
| 90014 | 72998 | Shadow damage proc | Endgame damage |

### ARMOR Procs (on cast / on hit taken) — applied to ITEM_CLASS_ARMOR (not shields)

**Tier 1 (iLvl 1-35):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90020 | 37656 | +Spirit 15s | Basic caster sustain |
| 90021 | 43764 | +All Resistances 10s | Defensive utility |

**Tier 2 (iLvl 30-60):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90022 | 43750 | +Armor 15s on hit taken | Defensive proc |
| 90023 | 65000 | Mana regen proc | Caster sustain |

**Tier 3 (iLvl 55-80):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90004 | 62114 | +590 SP 10s on cast | Caster DPS |
| 90005 | 49623 | +125 MP5 15s on cast | Healer sustain |
| 90024 | 54808 | +Crit Rating 10s on heal | Healer throughput |
| 90025 | 64411 | +450 SP on cast | Caster DPS alt |

**Tier 4 (iLvl 75+):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90026 | 60235 | +SP on heal | Endgame healer |
| 90027 | 47753 | Absorb shield on cast | Divine Aegis-like |
| 90028 | 73572 | Endgame caster proc | Top tier caster |
| 90029 | 66233 | Dodge proc | Endgame tank/melee |

### SHIELD Procs (on block / on hit taken) — applied to ITEM_CLASS_ARMOR + SubClass=SHIELD(6)

**Tier 1 (iLvl 1-35):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90030 | 43748 | +Block Value 15s | Basic tank |

**Tier 2 (iLvl 30-60):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90031 | 55019 | +Dodge Rating 10s | Avoidance |
| 90032 | 57345 | Holy damage reflect | Thorns-like |

**Tier 3 (iLvl 55-80):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90006 | 60218 | Absorb shield (-140/hit 10s) | Damage reduction |
| 90033 | 64677 | Absorb shield proc | Alt absorb |

**Tier 4 (iLvl 75+):**
| ID | Client Spell | Effect | Notes |
|----|-------------|--------|-------|
| 90034 | 64413 | +375 Stamina 10s | Endgame tank EHP |
| 90035 | 71516 | Endgame tank proc | Top tier tank |

### UNIVERSAL (any equipment slot) — weaker/utility effects

| ID | Client Spell | Effect | iLvl | Notes |
|----|-------------|--------|------|-------|
| 90007 | 51352 | 200 mana on kill | 30+ | Farming utility |
| 90036 | 43764 | +All Resistances 10s | 1+ | Universal defense |
| 90037 | 23689 | Move speed | 1+ | Quality of life |

**Target: 10+ options per tier per category = ~160+ enchants total**

### Available Proc Spells in Client (verified 2026-04-01)

| Category | Tier 1 (ID<35k) | Tier 2 (35-50k) | Tier 3 (50-65k) | Tier 4 (65k+) | Total |
|----------|----------------|-----------------|-----------------|---------------|-------|
| W_DMG (weapon damage) | 84 | 108 | 78 | 37 | 307 |
| W_BUFF (weapon buffs) | 14 | 17 | 17 | 6 | 54 |
| A_DEF (armor defensive) | 47 | 21 | 23 | 4 | 95 |
| A_CAST (armor caster) | 75 | 88 | 31 | 9 | 203 |
| A_HEAL (armor healer) | 18 | 11 | 5 | 5 | 39 |
| SHIELD (shield procs) | 97 | 47 | 81 | 31 | 256 |

More than enough for 10+ per tier. Each spell needs individual testing to confirm the proc works correctly when applied via EQUIP_SPELL enchant.

### Selection Criteria
- Must have a recognizable icon (IconID > 1)
- No test/debug/DND/cosmetic spells
- Proc effect must be meaningful for the item level range
- Avoid duplicate effects within same tier
- Prefer spells from real trinkets/set bonuses (known to work as procs)

## IMPORTANT: All spell IDs must exist in client Spell.dbc

Before using any spell ID, verify it exists:
1. Search in `.claude/statBoosterItems/dbc/Spell.csv` by ID
2. The spell must have an icon and name in the client
3. The server can override effects but NOT add new client visuals

## Required Changes

### Database (SQL only, no rebuild):
- Add new rows to `spellitemenchantment_dbc` (IDs 90009-90040)
- Add new rows to `statbooster_enchant_template` with PoolGroup=4 and appropriate filters

### Code (requires rebuild):
- Modify `BoostItemFromPool()` to filter enchants by item class (weapon/armor/shield)
- Or add `ItemClassFilter` column to `statbooster_enchant_template`

### Client (MPQ patch):
- Add all new enchant IDs to `SpellItemEnchantment.dbc`
- This is required for enchant names to show in tooltip and buff icons when equipped

## SpellItemEnchantment.dbc Format
```
ID, Charges=0, Effect_1=3, Effect_2=0, Effect_3=0, 
EffectPointsMin_1=0, ..., EffectPointsMax_1=0, ...,
EffectArg_1=<SPELL_ID>, EffectArg_2=0, EffectArg_3=0,
Name_Lang_zhTW=<Russian name>, (other locales empty),
Name_Lang_Mask=16712190,
ItemVisual=0, Flags=0, Src_ItemID=0, Condition_Id=0,
RequiredSkillID=0, RequiredSkillRank=0, MinLevel=0
```

## TODO
- [ ] Verify all proposed spell IDs exist in client Spell.dbc
- [ ] Create SpellItemEnchantment entries (server SQL + client DBC)
- [ ] Add to statbooster_enchant_template with proper filters
- [ ] Implement smart-apply code in BoostItemFromPool
- [ ] Create SpellItemEnchantment_custom.csv for client MPQ
- [ ] Test each proc works when item is equipped
