# DBC vs SQL — where spell data actually lives

This is the most-misunderstood thing about WoW 3.3.5 spells. Get this wrong and your spell will compile but have no name in the client.

## The rule

**Spell metadata (name, description, icon, school, range, cooldown, effects) lives in DBC, NOT in SQL.**

There is **no** `spell_dbc_locale` or `spell_template_locale` table in this codebase. If you grep for it you will not find one. AzerothCore reads `Spell.dbc` at startup and that's what the client sees.

## What this means in practice

| If you want to… | Edit… | Not… |
|---|---|---|
| Change spell name (any locale) | `.claude/dbc/Spell_custom.csv` (the row for that spell ID) | `*_locale` SQL table — doesn't exist for spells |
| Change spell description | `.claude/dbc/Spell_custom.csv` | same |
| Change spell behaviour (proc, dmg, target) | C++ script in `src/server/scripts/Spells/spell_*.cpp` | the DBC row's effect fields, usually |
| Tweak numeric effect values without a script | `.claude/dbc/Spell_custom.csv` `EffectBasePoints*` etc. | a C++ override |
| Add a spell to a creature | SQL: `creature_template.spell1..8` or `creature_template_addon` | DBC |
| Sell spell as a tome | SQL: `item_template.spellid_1`, `npc_vendor` | DBC |
| Make NPC click cast a spell | SQL: `npc_spellclick_spells` | DBC |
| Smart-script casts | SQL: `smart_scripts` | DBC |

## When SQL *does* enter the picture for spells

Indirect uses — the spell *exists* in DBC, but SQL connects it to other entities:
- `creature_template.spell1..8` — passive spells a creature has
- `creature_template_addon.auras` — auras applied on spawn
- `item_template.spellid_1..5` + `spelltrigger_1..5` — items that cast/trigger spells
- `npc_spellclick_spells` — gossip-click-to-cast
- `smart_scripts` with `action_type=11 SMART_ACTION_CAST` — scripted casts
- `playercreateinfo_spell_custom` — class starter spells
- `disables` with type=0 — disable a spell
- `spell_proc` / `spell_proc_event` — proc tuning (DOES use SQL for proc settings)
- `spell_script_names` — links a script name to a spell ID (registration table)
- `spell_target_position` — coordinate teleport targets

For these, delegate the SQL part to [[sql-migration-writer]] but **you** verify the spell ID exists in DBC first.

## Custom-DBC workflow in this fork

1. Add a row to `.claude/dbc/Spell_custom.csv` (or `Item_custom.csv` etc.).
2. Mention the new ID in `.claude/dbc/id_mapping.json` under the relevant reservation block.
3. If the spell needs custom logic, add a `.cpp` under `src/server/scripts/Spells/spell_<class>.cpp` and register it (see [script-registration.md](script-registration.md)).
4. Insert a row in `spell_script_names` SQL (`pending_db_world/`) tying the spell ID to the script name.
5. The DBC builder/extractor rebuilds the binary DBCs from the CSVs on next deployment.

## Gotchas

- **Row ID collisions** — `Spell_custom.csv` rows merge with `Spell.csv` at runtime; identical IDs are a hard error. Always check both before adding.
- **`Attributes*` fields** — bitfields. Don't write a decimal value, copy from a similar existing spell and tweak.
- **Effects must match** — `Effect1..3`, `EffectMechanic1..3`, `EffectBasePoints1..3`, etc. — keep indices consistent; mismatched effects cause the spell to do nothing.
