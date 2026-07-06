# Custom ID range

This fork reserves IDs above **1,000,000** for fork-private custom content (spells, items, creatures, quests, enchants, titles).

## Why
- Avoids collision with future upstream AC base content (which stays in vanilla 3.3.5 ranges).
- Makes custom content trivially identifiable in queries (`WHERE id > 1000000`).

## Before assigning a new ID

1. Grep `data/sql/base/` and `data/sql/updates/` for the proposed ID — must return zero hits.
2. Check `.claude/dbc/id_mapping.json` — central reservation registry. Search for both the exact ID and the range block.
3. Check `.claude/familiars/familiar_gacha_id_reservations.md` — narrower registry for familiar/nemesis IDs; many ranges within 1M+ are already claimed.
4. For spells specifically: also grep `.claude/dbc/Spell_custom.csv` and `Spell.csv` for the ID.

## After assigning

Update both:
- `.claude/dbc/id_mapping.json` — add the new ID under the right block, with a one-line description.
- The relevant pending-changes log (`.claude/nemesis/pending_changes.md` for familiar/nemesis IDs).

## Common range conventions (verify against id_mapping.json before trusting)

| Range start | Purpose |
|---|---|
| 1,000,000+ | General custom — most things |
| Reserved sub-blocks | See `id_mapping.json` for current allocations (familiar gacha, statbooster scrolls, nemesis encounters, etc.) |

Always treat `id_mapping.json` as authoritative — this doc is a hint, not the source of truth.

## Caveat learned 2026-07-06

`.claude/dbc/id_mapping.json` as it currently exists is a **flat single-object
map** of small integer keys (e.g. `"38": 91001, "64": 91002, ...`) — it does
NOT look like a spell/item ID reservation ledger in practice (no per-system
blocks, no descriptions, keys are tiny numbers unrelated to the 1,000,000+
custom range). Likely serves a narrower purpose (e.g. some display/model ID
remap) left over from another agent's workflow. Don't blindly append spell
reservations into it — it won't help future sessions find them. Instead, for
spell ID ranges below 1,000,000 (legacy fork convention — env-effects
107000+, mod-item-talents 108000+), the actual source of truth is each
feature's own doc (e.g. `.claude/item-talents/CUSTOM_SPELLS.md`,
`.claude/nemesis/*`, this file's "Common range conventions" table) plus a
direct grep of `Spell_custom.csv` / `Spell.csv`. Verify collisions that way
until `id_mapping.json`'s real schema is understood.
