# spell-editor memory — INDEX

Read this file at the start of every task. Then load only the sub-docs whose hooks match the current task.

## Sub-docs

- [dbc-vs-sql.md](dbc-vs-sql.md) — **CRITICAL**. Where spell data lives: DBC vs SQL boundaries. Load whenever the task touches a spell name, description, or icon.
- [locale-codes.md](locale-codes.md) — WoW 3.3.5 locale codes (enUS/ruRU/etc) and their numeric indices. Load when adding any localized text.
- [russian-locations.md](russian-locations.md) — Every place Russian text lives in this fork (no single source of truth). Load when asked for "russian", "ru_RU", "ruRU", "русский".
- [script-registration.md](script-registration.md) — How to register a new spell script (AddSC_*, script_loader.cpp). Load when adding a C++ spell file.
- [custom-id-range.md](custom-id-range.md) — Reserved ID ranges to avoid collisions. Load before assigning any new spell/item/enchant ID.

- [mod-environmental-effects.md](mod-environmental-effects.md) — v2: 177 spells (buffs 107000-107146, debuffs 107500-107528+108500); verified column positions table; SpellIcon_custom.csv added (IDs 50000/50001). Load for any task touching this module.

## How to grow this memory

When you learn a durable fact during a task (new path, new convention, a gotcha that bit you), either:
- Update the relevant sub-doc above, OR
- Create a new sub-doc and add a one-line entry here.

Keep this INDEX under ~30 lines so it stays cheap to load.
