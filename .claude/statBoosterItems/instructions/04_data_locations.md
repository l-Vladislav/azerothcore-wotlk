# Data Locations

Where each piece of data lives. Check in order when something's off.

## MD (design, source of truth)

`.claude/statBoosterItems/pools/fortune_pool/fortune_T<N>.md`
`.claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_T<N>.md`

Rows under `## <Slot> (<mask>)` define which enchant rolls on which slot.

## SQL (rebuild source)

`data/sql/updates/pending_db_world/statbooster_*.sql` — 13 files total (see [01_overview.md](01_overview.md#sql-file-layout)).

## Server DB (runtime)

Database `acore_world`:
- `statbooster_enchant_template` — the roll pool
- `spellitemenchantment_dbc` — enchant DBC override
- `spell_dbc` — custom spells (100xxx)
- `spell_enchant_proc_data` — weapon proc rates

## Client MPQ (UI rendering)

`.claude/dbc/Spell_custom.csv`
`.claude/dbc/SpellItemEnchantment_custom.csv`
`.claude/dbc/Item_custom.csv`
`.claude/dbc/SkillLineAbility_custom.csv`

Must be rebuilt into MPQ patch and deployed to clients.

## Module code + config

- C++: `modules/StatBooster/src/`
- Config: `env/dist/etc/modules/statbooster.conf` (scroll ID → pool mapping)
- Base module SQL (Pool 1/2 templates): `modules/StatBooster/data/sql/db-world/`

## Addon

`modules/StatBooster/ClientAddon/StatBoosterUI/EnchantDB.lua` — enchant ID → Russian name map.
`modules/StatBooster/ClientAddon/StatBoostTooltip/` — tooltip recolor.
