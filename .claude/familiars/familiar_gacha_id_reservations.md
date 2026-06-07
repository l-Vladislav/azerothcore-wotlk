# Nemesis Familiar Gacha — ID Reservations

Active ID ranges for the **100-pet gacha system** (**10 elemental families × 10 pets**). Companion to [familiar_gacha_design.md](familiar_gacha_design.md) и [familiar_gacha_catalog.md](familiar_gacha_catalog.md).

> Сборка от 2026-05-22: схема пересобрана с 20×5 на **10×10**. Диапазоны спеллов / сущностей / свитков сохранены, изменилась только формула линейного маппинга и набор сундуков стихий (теперь 10 вместо 20).

## Active ranges

| Range | Purpose | Size |
|---|---|---|
| `102000–102099` | Familiar summon spells | 100 |
| `103000–103099` | Owner-aura spells, **positive-only** (buff bar) | 100 |
| `104000–104099` | Owner-aura spells, **negative-only** (debuff bar). Used by flawed Commons + Epics with penalties. | up to 100 |
| `191000–191099` | Familiar creatures | 100 |
| `110000–110099` | Familiar scroll items | 100 |
| `110100–110109` | Element-specific chests (one per family) | 10 |
| `110110–110119` | (free) — reserved for future chest variants | 10 |
| `110120` | Universal chest | 1 |
| `110150` | «Монета авантюриста» (gacha currency, LIVE on PTR) | 1 |
| `190100–190102` | Виртуальные npc_vendor-листы магазина таверны (общие / StatBooster / сумки) — не creature_template! | 3 |

## Linear mapping (10×10)

For family `F` (1..10), pet `P` (1..10) within family:

| Resource | Formula |
|---|---|
| creature entry | `191000 + (F−1)*10 + (P−1)` |
| summon spell | `102000 + (F−1)*10 + (P−1)` |
| aura positive (buff bar) | `103000 + (F−1)*10 + (P−1)` |
| aura negative (debuff bar) | `104000 + (F−1)*10 + (P−1)` *(only created when the pet has at least one penalty — flawed Commons and Epics)* |
| scroll item | `110000 + (F−1)*10 + (P−1)` |
| element chest | `110100 + (F−1)` |

Examples:
- 1.2 (Механический / Ржавая Механокурица) → creature 191001, summon 102001, aura+103001 (buff), aura−104001 (debuff −1%), scroll 110001, family chest 110100.
- 6.4 (Тень / Полинялый Мотылёк) → creature 191053, summon 102053, aura+103053 (buff), aura−104053 (debuff), scroll 110053, family chest 110105.
- 10.10 (Общий / Везунчик) → creature 191099, summon 102099, aura+103099 (3 buffs), aura−104099 (1–2 penalties), scroll 110099, family chest 110109.
- 1.1 (Механический / Механокурица — clean Common) → creature 191000, summon 102000, aura+103000 (buff only), **no 104000** (clean has no penalty), scroll 110000.

## Retired ranges (cleaned up in gacha migration SQL)

| Range | Old purpose | Migration action |
|---|---|---|
| `100120–100134` | Old T1 summon spells (3 used: 100120/121/122) | DELETE; migrate `character_spell` rows → new 102000 / 102070 / 102050 |
| `101100–101114` | Old T1 owner auras (3 used: 101100/101/102) | DELETE |
| `190010–190024` | Old T1 creatures (3 used: 190010/011/012) | DELETE `creature_template` + `_model` + `_locale` |
| `100030–100044` | Old T1 scrolls (3 used: 100030/031/032) | DELETE `item_template` + `_locale`; `npc_vendor` rows on entry 190000 cleared |

## T1 → Gacha pool integration

The 3 existing T1 pets are re-integrated as Common starters in the new 10×10 pool (slot 1 of their family — clean variant):

| Old entry | Old name | New entry | New family.slot |
|---|---|---|---|
| 190010 | Волчонок-Страж | 191000 | 1.1 Механический |
| 190011 | Соколёнок | 191070 | 8.1 Демонический (бывш. Гроза) |
| 190012 | Воронёнок | 191050 | 6.1 Тень |

`character_spell` rows where `spell IN (100120, 100121, 100122)` are remapped to `102000`, `102070`, `102050` respectively in the migration script.

## StatBooster collision awareness (UNCHANGED)

StatBooster occupies `100030–100063` in `spell_dbc` (Immolate, Blood Pact, Arcane Burst, +3/+5/+7/+10 spell damage auras per school) and its enchants `90110/90111/90112` reference `100050/051/052` specifically. The new familiar ranges (`102000+`, `103000+`, `191000+`, `110000+`) are entirely clear of StatBooster.

## How to extend

When adding new gacha content (extra family beyond 10, additional chest variant, special promo pets) — stay within these ranges:
- New families beyond F=10: `102100+`, `103100+`, `191100+`, `110200+`, `110110+` for chests.
- Promo/event chest variants: `110110–110119` (the freed-up block) or `110200+`.
- Coin/currency variants: `110150–110199`.

For per-family expansion (>10 pets in a single family), use the spare block right after the current family's 10-slot range starts colliding — there is currently no spare inside `191000–191099`, so extensions require moving to `191100+` and remapping the family offset.
