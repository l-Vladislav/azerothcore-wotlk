# Pool scrolls — overview & pointers

This file is a **short overview**. The canonical design lives in `.claude/statBoosterItems/pools/` and `.claude/statBoosterItems/instructions/`. Read those for any non-trivial work.

## What pool scrolls are

Profession-crafted consumables that, when used on an item, apply a random enchant from a specific pool tied to the scroll's profession. 4 pools × 4 tiers = 16 scroll items. Plus the Attribute Recalibrator (item 41605) which re-rolls boosted items.

Landed in commits `026933e02` (initial) and `481a3e814` (pool iteration + slot 4).

## The 4 pools

| Pool | ID | Profession | Theme | Scroll items |
|---|---|---|---|---|
| Battle | 1 | Blacksmithing | Offensive stats | Runed/Tempered/Honed/Masterwork Whetstone |
| Warding | 2 | Leatherworking | Defensive stats | Runed/Tempered/Hardened/Masterwork Armor Patch |
| Arcana | 3 | Enchanting | Caster stats + school spell damage | Minor/Arcane/Greater/Superior Arcane Vellum |
| Fortune | 4 | Inscription | Utility / weapon procs / auras | Minor/Glyph/Major/Grand Glyph of Fortune |
| General | 0 | — | All enchants (Recalibrator re-roll only) | Attribute Recalibrator (41605) |

## Scroll item entries & tiers

See [current-config.md](current-config.md) for the full mapping (item ID → pool → iLvl band → profession tier). The runtime config is the source of truth.

Vanilla QA item IDs repurposed: `17827-17830, 18599, 17883-17885, 17888-17889, 17891-17896`. Repurposing existing IDs avoids needing a client MPQ patch for `Item.dbc`.

## Where the pool contents live

For each tier, the canonical roster of enchant IDs + slot rules + Russian names is in:

| Pool / Tier | Design file |
|---|---|
| Fortune T1 (overview of all 4 pools T1) | `.claude/statBoosterItems/pools/fortune_pool/fortune_T1_summary.md` |
| Fortune T1 (detail) | `.claude/statBoosterItems/pools/fortune_pool/fortune_T1.md` |
| Fortune T2 | `.claude/statBoosterItems/pools/fortune_pool/fortune_T2.md` |
| Fortune T3 | `.claude/statBoosterItems/pools/fortune_pool/fortune_T3.md` |
| Fortune T4 | `.claude/statBoosterItems/pools/fortune_pool/fortune_T4.md` |
| Arcana T1 | `.claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_T1.md` |
| Arcana T2 | `.claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_T2.md` |
| Arcana T3 | `.claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_T3.md` |
| Arcana T4 | `.claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_T4.md` |

**Tier overlap is allowed.** The same enchant ID can appear in multiple tiers with different `iLvlMin/Max` + `ItemTypeMask` — each combo is a separate row in `statbooster_enchant_template`. Example: enchant 90007 "Обнаружение незаметности" is in both T1 Fortune (Head, Wrists) and T2 Fortune (Head only). Don't model the system as "one enchant ID → one row" — it's "one enchant ID → many rows".

## Custom craft spells (`Spell_custom.csv`)

Pool scrolls' craft recipes (the spell you cast to make a scroll) use **`Spell_custom.csv` IDs 100001-100016**, plus 100000 as a base "apply boost" spell. See [id-range-map.md](id-range-map.md) for the full picture (including 100017-100036 = custom proc spells like Шипы 100025, Чародейский взрыв 100017-19, Жертвенный огонь 100028-31, etc., referenced by Fortune-pool enchants as the `EffectArg_1`).

These 100001-100016 craft spells need to be **also patched into the client's `Spell.dbc` via MPQ** so the trainer UI can display them. See `history/plans_2026-04_custom_items.md` for the MPQ workflow.

## Code architecture (`modules/StatBooster/src/`)

- **`StatBoostCfgMgr.h/cpp`** — `EnchantDefinition.PoolGroup` field; `EnchantPool::GetFromPool(poolGroup, itemLevel)` picks a weighted enchant matching the iLvl band
- **`StatBoostMgr.h/cpp`** — `BoostItemFromPool(player, item, poolGroup)` entry point
- **`StatBoost.cpp`** — `IsRerollScroll()` + `GetScrollPoolGroup()` route scroll uses:
  - `poolGroup > 0` → can ONLY enchant un-enchanted items (pool scrolls)
  - `poolGroup = 0` (Recalibrator 41605) → can ONLY re-roll already-boosted items

## DB tables touched

| Table | DB | What it stores |
|---|---|---|
| `statbooster_enchant_template` | acore_world | The enchant roster — multiple rows per enchant for tier/slot combos |
| `statbooster_enchant_scores` | acore_world | Scoring weights per role/stat (for "best enchant" picking) |
| `spell_dbc` | acore_world | Mirror of `Spell_custom.csv` (server-side DBC) |
| `skilllineability_dbc` | acore_world | Skill→spell links (100001-100016 craft spells) |
| `spellitemenchantment_dbc` | acore_world | Mirror of `SpellItemEnchantment_custom.csv` |
| `item_template` | acore_world | 16 repurposed scroll items |
| `trainer_spell` + `trainer` + `creature_default_trainer` | acore_world | Recipe additions to profession trainers (NOT `npc_trainer` — that's deprecated; see `history/plans_2026-04_custom_items.md`) |

## Rollback

If a change ever needs to be reverted: see `history/CHANGELOG_2026-03_pool_scrolls.md`. **Caveat:** the CHANGELOG was an early implementation snapshot — the actual roster in `SpellItemEnchantment_custom.csv` has evolved. The rollback SQL there is structurally useful (which tables to clear, which ID ranges) but the specific row contents won't match the current live state. Use it as a recipe, not a verbatim script.
