# Familiar gacha — ID ranges

Authoritative source: [.claude/nemesis/familiar_gacha_id_reservations.md](../../nemesis/familiar_gacha_id_reservations.md). This file is a quick reference — re-read the source if anything conflicts.

## Linear formula (10 families × 10 pets)

For family `F` (1..10), pet `P` (1..10):

| Resource | Formula | Range |
|---|---|---|
| creature entry | `191000 + (F−1)*10 + (P−1)` | 191000–191099 |
| summon spell | `102000 + (F−1)*10 + (P−1)` | 102000–102099 |
| aura positive (buff bar) | `103000 + (F−1)*10 + (P−1)` | 103000–103099 |
| aura negative (debuff bar) | `104000 + (F−1)*10 + (P−1)` | 104000–104099 (exists for flawed Commons and Epics with penalties) |
| scroll item | `110000 + (F−1)*10 + (P−1)` | 110000–110099 |
| element chest | `110100 + (F−1)` | 110100–110109 |
| universal chest | `110120` | — |
| tavern coin | `110150` | — |
| free for promo | `110110–110119`, `110151–110199` | — |

## Family index

1 Механический · 2 Огонь · 3 Лёд · 4 Природа · 5 Свет · 6 Тень · 7 Тайна · 8 Гроза · 9 Зверь · 10 Дух

## Retired ranges — do NOT reuse

- `100120–100134` — old T1 summons. Migrate `character_spell` 100120/121/122 → 102000/102070/102050.
- `101100–101114` — old T1 owner-auras.
- `190010–190024` — old T1 creatures (3 used). Delete `creature_template` + `_model` + `_locale`.
- `100030–100044` — old T1 scrolls.

## T1 migration map (3 already-shipped pets)

| Old entry | Old name | New entry | Family.Slot |
|---|---|---|---|
| 190010 | Волчонок-Страж | 191000 | 1.1 Механический |
| 190011 | Соколёнок | 191070 | 8.1 Гроза |
| 190012 | Воронёнок | 191050 | 6.1 Тень |

## Collisions to avoid

- StatBooster owns `spell_dbc` `100030–100063` (Immolate/BloodPact/ArcaneBurst/+spell-dmg auras) and enchants `90110/90111/90112`. Familiar gacha ranges (`102000+`, `103000+`, `191000+`, `110000+`) are clear.
