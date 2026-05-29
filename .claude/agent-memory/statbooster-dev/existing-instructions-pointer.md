# Pointer to .claude/statBoosterItems/instructions/

The project already maintains a structured playbook for StatBooster work at `.claude/statBoosterItems/instructions/`. **Use it as your primary detailed reference for non-trivial changes** — it covers gotchas this memory doesn't repeat.

## Entry point

Always start at `.claude/statBoosterItems/instructions/MANIFEST.md` — it has the decision tree.

## File map (cheat sheet)

| If the task is… | Read this |
|---|---|
| Add / change / remove an enchant | `02_workflow.md` |
| Configure a custom spell (Attributes, DurationIndex, Radius, Aura types) | `03_spells.md` |
| Find where X is stored (path lookup) | `04_data_locations.md` |
| Fix icon / tooltip / timer mismatch between client and server | `05_client_server_sync.md` |
| Diagnose a broken behaviour | `06_troubleshooting.md` |
| Audit consistency after a change | `07_consistency_check.md` |
| Look up what custom spell X does | `08_custom_spells_catalog.md` |
| Understand pool/tier/ID system shape | `01_overview.md` |

## Related folders (read as needed)

- `.claude/statBoosterItems/pools/` — per-tier pool definitions (fortune_T1..T4, arcane_vellum_T1..T4)
- `.claude/statBoosterItems/fortune_pool_v2c_design.md` — current active design (latest version). Older `v2`/`v2b` are archaeology — see [history/](history/) note.
- `.claude/statBoosterItems/all_enchants.txt` and `all_enchants_ru.txt` — full enchant catalog (Lua tables, EN + RU)

## Old/superseded design docs to ignore

These predate the current architecture and are kept for archaeology only:
- `fortune_pool_design.md` (original)
- `fortune_pool_v2_design.md`
- `fortune_pool_v2b_design.md`

Current is **`fortune_pool_v2c_design.md`**. When asked about "the design", default to v2c unless the user explicitly references an earlier version.

## Source-of-truth rule

Where two docs disagree:
1. `env/dist/etc/modules/statbooster.conf` wins for config values
2. `.claude/statBoosterItems/instructions/0X.md` wins for workflow / data layout
3. `fortune_pool_v2c_design.md` wins for design intent
4. Older docs ≠ truth — treat as historical context only
