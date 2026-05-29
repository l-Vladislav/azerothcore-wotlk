# Locale codes (WoW 3.3.5 / AzerothCore)

## Codes

| Locale | String (modern SQL) | Old DBC index | Notes |
|---|---|---|---|
| English (US) | `enUS` | 0 | Default / base column in DBC |
| Korean | `koKR` | 1 | |
| French | `frFR` | 2 | |
| German | `deDE` | 3 | |
| Chinese (Simplified) | `zhCN` | 4 | |
| Chinese (Traditional) | `zhTW` | 5 | |
| Spanish (Spain) | `esES` | 6 | |
| Spanish (Mexico) | `esMX` | 7 | |
| **Russian** | **`ruRU`** | **8** | **Default in this fork's RU realm** |

## How locale is stored

**Two parallel systems coexist in 3.3.5:**

1. **DBC columns** (legacy) — every locale has its own column. E.g. `Spell.dbc` has `Name_enUS`, `Name_koKR`, …, `Name_ruRU` as fields 9..16 (and a flag at field 17). When editing `Spell_custom.csv`, write Russian into the `Name_ruRU` / `Description_ruRU` columns.

2. **`*_locale` SQL tables** (modern, for non-DBC entities) — single table per entity type with `locale VARCHAR(4)` as part of PK. Example:
   ```sql
   INSERT INTO creature_template_locale (entry, locale, Name, Title)
   VALUES (1000001, 'ruRU', 'Тестовый моб', 'Аватар Теста');
   ```

**Critical:** for spells, you use system #1 (DBC columns). For creatures/items/quests/gossip/etc. — system #2 (locale SQL tables).

## Worldserver config

The fork's `worldserver.conf.dist` typically has:
- `DBC.Locale = 8` — which DBC locale column the server prefers when no client locale is sent
- `RealmZone = 12` — realm region (12 = Russia)

If a Russian text doesn't appear in-game, check `DBC.Locale` first.
