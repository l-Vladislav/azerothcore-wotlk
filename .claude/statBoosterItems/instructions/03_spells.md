# Spells — types, attributes, gotchas

## Enchant types (`spellitemenchantment_dbc.Effect_1`)

| | Name | Use |
|--|------|-----|
| 1 | COMBAT_SPELL | Weapon proc — needs `spell_enchant_proc_data` row |
| 3 | EQUIP_SPELL | Cast on equip, removed on unequip |
| 5 | STAT | Direct stat mod (EffectArg = mod id: 5=Int, 6=Spirit, …) |
| 7 | USE_SPELL | Right-click item to activate |

## Spell Attributes (`spell_dbc.Attributes`)

| Bit | Value | Name | Effect |
|-----|-------|------|--------|
| 6 | 64 | PASSIVE | Auto-applies, infinite duration |
| 7 | 128 | HIDDEN_CLIENTSIDE | No buff icon |
| 16 | 65536 | NOT_SHAPESHIFT | Castable in any form |

**Common values:**
- `0` — normal active (has duration, shows icon)
- `64` — passive visible
- `192` — passive silent (no icon) — like vanilla +6 Resist
- `65536` — normal active, shapeshift-safe (like Mage Armor)
- `2147549184` — legacy flag mix; effectively like 65536 + duration

## DurationIndex cheatsheet

| Index | Duration | Reference spell |
|-------|----------|-----------------|
| 0 | passive/infinite | — |
| 9 | 30s | Death Wish (12328) |
| 21 | 15min | many item buffs |
| 29 | 12s | Shield Wall (871) |
| 30 | 30min | Mage Armor (6117) |
| 64 | 40s | Bloodlust (2825) |

## EffectRadiusIndex (for AoE / area auras)

| Index | Radius | Reference |
|-------|--------|-----------|
| 10 | 20 yd | Imp Blood Pact (6307) |
| 13 | 10 yd | — |
| 23 | 40 yd | Paladin auras (465) |
| 27 | 100 yd | raid-wide |

## Aura types (`EffectAura_1`) commonly used

| | Name | MiscValue meaning |
|--|------|-------------------|
| 13 | MOD_DAMAGE_DONE | School mask (2=Holy, 4=Fire, 8=Nature, 16=Frost, 32=Shadow, 64=Arcane, 126=all magic) |
| 15 | DAMAGE_SHIELD (Thorns) | — |
| 22 | MOD_RESISTANCE | School mask (1=armor/physical, 2=holy, 4=fire, 8=nature, 16=frost, 32=shadow, 64=arcane) |
| 82 | WATER_BREATHING | — |
| 230 | MOD_MAX_HEALTH (flat) | — |

## Gotchas

- **Druid spells (467 Thorns, etc.)** have 10-min duration. Don't use directly as EQUIP_SPELL — expires while equipped. Clone as passive (`Attributes=192`).
- **`EffectMiscValue` for MOD_RESISTANCE**: `1` = physical/armor, not a number index — same bitmask as other schools.
- **PASSIVE + DurationIndex** — server treats as infinite; client may still show countdown if its DBC says otherwise.
- **Visible passive (Attr=64) buff icon requires client DBC entry** for the spell ID. Without MPQ patch, effect applies but no icon.
- **Type 7 USE_SPELL** needs client to know the spell for item right-click to show cooldown bar.
