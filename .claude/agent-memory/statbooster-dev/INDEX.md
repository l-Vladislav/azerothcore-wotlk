# statbooster-dev memory — INDEX

Read this file at the start of every task. Then load only the sub-docs whose hooks match the current task.

## ⚠️ Two load-bearing conventions you must know

1. **`##SB##` prefix** on Russian enchant names — client addon uses it as a tooltip-recolor marker. Without it, your enchant works mechanically but isn't visually styled as a StatBooster boost.
2. **Three-place sync** for any new enchant Russian name: DBC CSV (`Name_Lang_zhTW`) + SQL (`spellitemenchantment_dbc`) + client addon Lua (`EnchantDB.lua`'s `SB.DB.EnchantNames`).

Both are detailed in [text-localization-rules.md](text-localization-rules.md). Load it for **any** task touching enchant or spell text.

## Sub-docs

- [text-localization-rules.md](text-localization-rules.md) — **CRITICAL**. zhTW vs ruRU, `##SB##` tag, EnchantDB.lua sync. Load for any text-bearing task.
- [current-config.md](current-config.md) — **CRITICAL**. Live runtime values (Enable=1, item chances 25%, scroll pool mappings, iLvl bands). Load whenever the task involves config keys, chances, qualities, or scrolls.
- [id-range-map.md](id-range-map.md) — Verified ID ranges from real CSV data. 90xxx = Fortune/Arcana auras; 91xxx = ##SB## stat copies. Includes gap analysis. Load before assigning ANY new ID.
- [pool-scrolls-reference.md](pool-scrolls-reference.md) — Short overview + pointers to canonical pool design docs. Load for scroll/pool work.
- [template-vs-runtime.md](template-vs-runtime.md) — `.dist` template ≠ `env/dist/etc/` runtime. Module-wide gotcha. Load for any config question.
- [examples/add-new-enchant.md](examples/add-new-enchant.md) — End-to-end worked example with all 3 syncs. Load when adding a new enchant.
- [examples/vanilla-wrapper-pattern.md](examples/vanilla-wrapper-pattern.md) — Pattern for wrapping a vanilla trinket-style proc spell as a permanent enchant aura (e.g., Mark of the Chosen 21969 → custom wrapper 100037). Load when an EQUIP_SPELL enchant referencing a vanilla spell doesn't proc in-game.
- [existing-instructions-pointer.md](existing-instructions-pointer.md) — Pointer to `.claude/statBoosterItems/instructions/` (MANIFEST → 01-08) — the rich pre-existing playbook.
- [history/](history/) — Archived stale docs (CHANGELOG 2026-03, plans 2026-04, OUTDATED project doc). Read only for archaeology, never as current truth.

## Canonical sources of truth (external to this memory)

| For… | Source |
|---|---|
| Current runtime config | `env/dist/etc/modules/statbooster.conf` (live), `env/dist/etc-ptr/modules/statbooster.conf` (PTR) |
| Pool design (which enchants in which pool/tier) | `.claude/statBoosterItems/pools/{fortune,arcane_vellum}_pool/<tier>.md` |
| Step-by-step workflows / paths / troubleshooting | `.claude/statBoosterItems/instructions/MANIFEST.md` → `0X_*.md` |
| Latest active design version | `.claude/statBoosterItems/fortune_pool_v2c_design.md` (older v2/v2b are archaeology) |
| Russian display names (client) | `modules/StatBooster/ClientAddon/StatBoosterUI/EnchantDB.lua` |
| Tooltip recolor logic (`##SB##` matcher) | `modules/StatBooster/ClientAddon/StatBoostTooltip/StatBoostTooltip.lua` |

## How to grow this memory

When a task surfaces a durable fact (new SQL table, new config key, a sync gotcha, a path you had to grep for, an undocumented convention), update the appropriate sub-doc or add a new one and link from this INDEX.

Keep this INDEX under ~40 lines.
