# MANIFEST

What each instruction file is for. Read the one matching your task.

## Files in this folder

| File | Purpose | Read when you want to… |
|------|---------|------------------------|
| [README.md](README.md) | Index + source-of-truth rule | Orient yourself; see the file list |
| [MANIFEST.md](MANIFEST.md) | This file — what each doc is for | Pick the right doc for your task |
| [01_overview.md](01_overview.md) | Pools, tiers, ID ranges, SQL file layout, data paths | Understand the system's shape |
| [02_workflow.md](02_workflow.md) | Steps to add/change/remove an enchant, and mistakes to avoid | Make a change and not break things |
| [03_spells.md](03_spells.md) | Enchant types, spell Attributes, DurationIndex, Radius, Aura types, gotchas | Configure a custom spell correctly |
| [04_data_locations.md](04_data_locations.md) | Full path list: MD, SQL, DB tables, client CSVs, module code, config | Find where something lives |
| [05_client_server_sync.md](05_client_server_sync.md) | Which fields must match between client MPQ and server DB | Fix icon/tooltip/timer mismatches |
| [06_troubleshooting.md](06_troubleshooting.md) | Common symptoms → root cause → fix | Something's broken and you need a recipe |
| [07_consistency_check.md](07_consistency_check.md) | Shell snippets to verify MD / SQL / DB / addon agree | Audit after a change |
| [08_custom_spells_catalog.md](08_custom_spells_catalog.md) | Per-spell reference for all custom spells 100017-100063 | Look up what a specific custom spell does |
| [../CUSTOM_SPELLS.md](../CUSTOM_SPELLS.md) | Original design spec (not maintained by these instructions) | Compare against design intent when auditing |

## Quick decision tree

- **"How do I add an enchant?"** → 02
- **"Why doesn't the buff icon show?"** → 06 (troubleshooting) or 05 (client sync)
- **"What does spell 100024 do?"** → 08
- **"Which Attributes value do I need?"** → 03
- **"Where is X stored?"** → 04
- **"Is the system in sync?"** → 07
- **"What tiers / pools exist?"** → 01
