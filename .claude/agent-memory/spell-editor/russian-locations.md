# Where Russian text lives in this fork

There is **no single source of truth** for Russian. Different subsystems put RU in different places. Always confirm where to write before writing.

## Catalog

| Subsystem | Location | Format |
|---|---|---|
| Spell name/description | `.claude/dbc/Spell_custom.csv`, `Name_ruRU` + `Description_ruRU` columns | CSV column |
| Item name/description | `item_template_locale` (SQL, `pending_db_world/`) for non-custom items; `.claude/dbc/Item_custom.csv` for fork-added items | mixed |
| Quest text | `quest_template_locale` SQL | SQL row |
| Creature name/title | `creature_template_locale` SQL | SQL row |
| Gossip option text | `gossip_menu_option_locale` SQL | SQL row |
| Broadcast text | `broadcast_text_locale` SQL | SQL row |
| Custom enchants | `.claude/statBoosterItems/all_enchants_ru.txt` | Lua table format |
| Module hardcoded messages | `modules/mod-autobalance/src/Message.cpp` with `{LOCALE_ruRU, "текст"}` macro | C++ macro |
| Page text (in-game books) | `page_text_locale` SQL | SQL row |
| NPC text (creature dialog) | `npc_text_locale` SQL | SQL row |

## Decision tree for "куда положить русский для X"

```
Is X a spell, item-icon, or other DBC-row attribute?
  → DBC CSV column (.claude/dbc/<Table>_custom.csv, *_ruRU column)
Is X a creature/quest/item/gossip/broadcast row?
  → SQL *_locale table, locale='ruRU'
Is X an in-game message printed by a module?
  → C++ source with {LOCALE_ruRU, "..."} pattern (see mod-autobalance/Message.cpp for template)
Is X an enchant description label?
  → .claude/statBoosterItems/all_enchants_ru.txt (lua-style)
```

## Gotchas

- **Cyrillic encoding**: All RU text files in this project are UTF-8 (no BOM). When writing SQL with PowerShell on Windows, use `Out-File -Encoding utf8` or pipe through a here-string in Bash to avoid mojibake.
- **String length**: `*_locale` tables often have shorter `VARCHAR` than the base table — verify column width before inserting long descriptions.
- **Apostrophes**: escape `'` in SQL as `''` or use `\'` consistently. Russian text rarely has them but quest objectives sometimes do.
- **`LOCALE_ruRU` macro** in C++ is `LocaleConstant::LOCALE_ruRU == 8` — same as the DBC index.
