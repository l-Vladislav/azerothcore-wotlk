# Custom ID range

This fork reserves IDs above **1,000,000** for fork-private custom content (spells, items, creatures, quests, enchants, titles).

## Why
- Avoids collision with future upstream AC base content (which stays in vanilla 3.3.5 ranges).
- Makes custom content trivially identifiable in queries (`WHERE id > 1000000`).

## Before assigning a new ID

1. Grep `data/sql/base/` and `data/sql/updates/` for the proposed ID — must return zero hits.
2. Check `.claude/dbc/id_mapping.json` — central reservation registry. Search for both the exact ID and the range block.
3. Check `.claude/nemesis/familiar_gacha_id_reservations.md` — narrower registry for familiar/nemesis IDs; many ranges within 1M+ are already claimed.
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
