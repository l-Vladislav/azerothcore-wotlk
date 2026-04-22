# StatBooster — Instructions

Quick reference for the enchant pool system.

| File | Topic |
|------|-------|
| [01_overview.md](01_overview.md) | Pools, tiers, ID ranges, files |
| [02_workflow.md](02_workflow.md) | How to add/change/remove enchants |
| [03_spells.md](03_spells.md) | Enchant types, spell Attributes, DurationIndex, gotchas |
| [04_troubleshooting.md](04_troubleshooting.md) | Common issues |
| [05_consistency_check.md](05_consistency_check.md) | Verify MD/SQL/DB/client are in sync |
| [06_custom_spells_catalog.md](06_custom_spells_catalog.md) | Per-spell reference for 100017-100063 |

**Source of truth:** MD files in `pools/`. After editing MD, regenerate SQL → apply to DB → update addon/client.
