# Overview

## Pools (4 scroll families × 4 tiers)

| Pool | Theme | Scrolls | Enchant IDs |
|------|-------|---------|-------------|
| 1 | Whetstones (physical DPS) | 100001-100004 | 91xxx |
| 2 | Armor Patches (tank/caster stats) | 100005-100008 | 91xxx |
| 3 | Arcane Vellums (spell damage + Int/Spirit) | 100009-100012 | 90100-90137 |
| 4 | Glyphs of Fortune (themed passives/procs) | 100013-100016 | 90001-90090 |

Tiers: T1 iLvl 1-25, T2 26-45, T3 46-65, T4 66-92.

## Files

| Kind | Path |
|------|------|
| Design (source of truth) | `.claude/statBoosterItems/pools/{fortune_pool,arcane_vellum_pool}/*.md` |
| SQL (13 files) | `data/sql/updates/pending_db_world/statbooster_*.sql` |
| Server DB tables | `statbooster_enchant_template`, `spellitemenchantment_dbc`, `spell_dbc`, `spell_enchant_proc_data` |
| Client MPQ CSVs | `.claude/dbc/{Spell_custom,SpellItemEnchantment_custom,Item_custom}.csv` |
| Addon | `modules/StatBooster/ClientAddon/StatBoosterUI/EnchantDB.lua` |
| Module config | `env/dist/etc/modules/statbooster.conf` (scroll→pool mapping) |

## SQL file layout

- `statbooster_scrolls.sql` — 16 craftable items
- `statbooster_pool1_base.sql` / `pool2_base.sql` — Pool 1/2 DBCs
- `statbooster_pool3_base.sql` + `pool3_T<N>.sql` — Pool 3 (arcane vellum)
- `statbooster_pool4_T<N>_base.sql` + `pool4_T<N>.sql` — Pool 4 per-tier (fortune)

Tier base = DBC + custom spells + proc data; uses `REPLACE INTO` so any tier applies independently.
Tier template = `statbooster_enchant_template` INSERTs.

## Custom spell ID ranges

- **100017-100019, 100036**: Arcane Burst (4 damage tiers)
- **100020**: Water Breathing
- **100021-100023**: Frost Ring
- **100024**: Frost Armor
- **100025-100027**: Thorns (passive damage shield)
- **100028-100031**: Immolate (activatable)
- **100032-100035**: Blood Pact (area aura)
- **100040-100063**: Pool 3 school spell damage (6 schools × 4 tiers)
