# Where the familiar docs live

## Source of truth per topic

| Topic | File |
|---|---|
| Overall concept, phases, attribute rules | `.claude/nemesis/familiar_gacha_design.md` |
| Chest implementation plan (Flags=4 + item_loot_template, NO C++) | `.claude/nemesis/familiar_gacha_chests_plan.md` — START HERE for chest work |
| Per-pet effects, names, exact ID per slot | `.claude/familiars/0X_<element>.json` (migrated families — SOURCE OF TRUTH) or `0X_<element>.md` (not-yet-migrated baseline) |
| JSON schema, input format, SQL/CSV generator | `json-workflow.md` (this folder) |
| Family index, drop-rates aggregate, history | `.claude/nemesis/familiar_gacha_catalog.md` |
| Active ID ranges, retired ranges, T1 migration | `.claude/nemesis/familiar_gacha_id_reservations.md` |
| Phase status, what's done / pending | `.claude/nemesis/familiar_gacha_status.md` |
| In-flight changes log | `.claude/nemesis/pending_changes.md` |
| Old T1 (rollback-only reference) | `.claude/nemesis/familiar_system_design.md`, `familiar_system_implementation.md` |

## Read order before any task

1. `familiar_gacha_status.md` — what phase / what was done last
2. `pending_changes.md` — what's uncommitted
3. The relevant per-family file in `.claude/familiars/` — prefer `0X_*.json` if it exists, else `0X_*.md`
4. `familiar_gacha_id_reservations.md` — only if reserving new IDs
5. This memory's `aura-template.md` — only if writing `spell_dbc`

## When you change something

- New pet effect / new variant → update the per-family JSON (`.claude/familiars/0X_*.json`) if migrated, else the `.md`. Then regenerate SQL via `scripts/familiar-gen-sql.ps1`. See `json-workflow.md`.
- New ID block → update `familiar_gacha_id_reservations.md`.
- Phase progress → update `familiar_gacha_status.md` (newest-on-top in the activity log).
- In-flight branch work → leave a note in `.claude/nemesis/pending_changes.md`.
- New durable convention or gotcha → update or add a sub-doc here in `agent-memory/familiars-dev/` and link it from `INDEX.md`.
