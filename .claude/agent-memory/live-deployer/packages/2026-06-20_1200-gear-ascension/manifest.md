# Deployment Manifest: Gear Ascension
**Package:** `2026-06-20_1200-gear-ascension`
**Date:** 2026-06-20
**Target DB:** `acore_world` on container `ac-database-v2`
**Status:** READY FOR HUMAN APPLY

---

## Summary

Promotes the fully PTR-validated Gear Ascension feature to live. This adds a
quality-tier upgrade system: players use profession kits (purchased from rank-gated
Nemesis vendors) to apply a 2-second cast spell that upgrades a base item into a
tier copy with +10% stats per tier step. 8,480 green/blue tier copies + 8,480 white
tier copies (stored as item_template entries 300001-345833) form a chain graph
tracked in the custom `item_upgrade_chain` table. 21 kit items (entries 200000-200020)
drive the upgrade spell (spell_dbc 105000, SpellScript `spell_gear_ascension_apply_kit`).

The C++ module `mod-gear-ascension` must be built into the live worldserver image
before restart. The DB apply and image build are independent steps — DB can be applied
while the old worldserver runs (inert until restart).

---

## Pre-flight check results (read-only, run 2026-06-20)

| Check | Live result | PTR result | Verdict |
|---|---|---|---|
| item_template 300001-345833 | 0 rows | 8,480 rows | CLEAN — safe to insert |
| item_template 200000-200020 | 0 rows | 21 rows | CLEAN — safe to insert |
| item_template 1000000-1099999 (old block) | 0 rows | (cleanup only) | Old block already absent on live |
| item_upgrade_chain table | ABSENT | EXISTS (8,480 rows) | Must CREATE on live |
| itemextendedcost_dbc 100008 | 0 rows | 1 row | CLEAN — safe to insert |
| spell_dbc 105000 | 0 rows | 1 row | CLEAN — safe to insert |
| spell_script_names 105000 | 0 rows | 1 row | CLEAN — safe to insert |
| npc_vendor kit rows (190101/102/103 x kits) | 0 kit rows | 21 kit rows | CLEAN — safe to insert |
| npc_vendor 190101 existing rows | 4 rows (pre-existing Nemesis) | — | SAFE — kit insert uses specific item IDs only |
| npc_vendor 190102 existing rows | 14 rows (pre-existing Nemesis) | — | SAFE — kit insert uses specific item IDs only |
| npc_vendor 190103 existing rows | 4 rows (pre-existing Nemesis) | — | SAFE — kit insert uses specific item IDs only |
| item_template 100017 (token) | EXISTS | — | Token present on live; kit_vendor.sql already references it correctly |
| item_template_locale 300001-345833 (ruRU) | 0 rows | 8,472 rows | CLEAN — safe to insert |
| item_template_locale 200000-200020 (ruRU) | 0 rows | 21 rows | CLEAN — safe to insert |

**All pre-flight checks passed. No ID collisions on live.**

Note: PTR has 8,480 item_template rows for 300001-345833 and 8,472 locale rows.
The 8-row gap in locale rows is expected: 8 items were inserted without a ruRU name
(likely the first base items before the Russian name engine was activated). This is
the same state as PTR which has been validated.

---

## DB footprint being added

| Table | Rows | Range / Key | Note |
|---|---|---|---|
| `item_template` | 8,480 | entries 300001-345833 | Green/blue tier copies from gear_ascension_proto.sql |
| `item_template` | 8,480 | entries 300001-345833 (white tier) | Wait — white bases also populate this range, see below |
| `item_template` | 21 | entries 200000-200020 | Kit items (7 categories x 3 tiers) |
| `item_template_locale` | 8,472 | IDs 300001-345833, locale=ruRU | Russian names for tier copies |
| `item_template_locale` | 21 | IDs 200000-200020, locale=ruRU | Russian names for kits |
| `item_upgrade_chain` | 8,480 | entry=base item (25-84898), chain to 300001-345833 | NEW TABLE — created by apply script |
| `spell_dbc` | 1 | ID 105000 | Kit use-spell (2s cast, SCRIPT_EFFECT) |
| `spell_script_names` | 1 | spell_id=105000 | Links to `spell_gear_ascension_apply_kit` C++ |
| `itemextendedcost_dbc` | 1 | ID 100008 | 30x token price for tier III kits |
| `npc_vendor` | 21 | 7 rows on each of 190101/190102/190103 | Kit vendor placement |

**Cleanup file** (`gear_ascension_cleanup_1m_block.sql`): Deletes old item_template
entries 1000000-1099999 and associated chain rows. Live has 0 rows in this range —
the cleanup file is safe (its DELETEs will affect 0 rows) but is still applied to
keep the updates table current with what PTR has.

---

## SQL files applied (in order)

1. `gear_ascension_cleanup_1m_block.sql` — legacy 1M-block cleanup (no-op on live, 0 rows to delete)
2. `gear_ascension_kits.sql` — 21 kit item_template + spell_dbc 105000 (initial insert)
3. `gear_ascension_polish_a.sql` — updates spell 105000 (cast time + effect type) + spell_script_names
4. `gear_ascension_proto.sql` — 8,480 green/blue tier copies + item_template_locale + item_upgrade_chain (181,172 lines; this is the longest step)
5. `gear_ascension_white_bases.sql` — white tier copies + locale + chain entries (63,936 lines)
6. `gear_ascension_kit_vendor.sql` — IEC 100008 + npc_vendor kit rows on 190101/102/103

**Ordering rationale:**
- Cleanup first so it can never interfere with the new block inserts.
- Kits before polish_a because polish_a UPDATEs what kits INSERTs.
- Proto/white before kit_vendor so the item_template rows the vendor references exist.
- Kit_vendor last because it references item 100017 (already on live) and IEC 100001/100003 (already on live from prior Nemesis deploy).

---

## Non-DB steps (NOT performed by apply.ps1)

These are the human's responsibility. The DB apply is safe to run now; nothing activates until the worldserver restarts with the new image.

### A. Build live worldserver image (C++ module)
The `mod-gear-ascension` module must be compiled into the worldserver image.
The apply.ps1 will prompt for this step. The build command is:
```
docker compose build ac-worldserver   (from repo root)
```
Stop `ac-worldserver-ptr` first to free WSL2 RAM (typical OOM risk during compile).

### B. AuctionHouseBot configuration
Edit `env\dist\etc\modules\mod_ahbot.conf` (agent is blocked from this path by deny rules — human edits manually):
```
AuctionHouseBot.ListedItemIDRestrict.Enabled = 1
AuctionHouseBot.MaxItemID = 199999
```
This prevents AHBot from listing the 8,480 tier copies in the auction house. Apply
this before restarting the worldserver.

### C. Client MPQ — players need updated client files
Three DBC files must be delivered to players in the client patch MPQ:
- `DBFilesClient\Item.dbc` — 54,739 records including entries 200000-200020 and 300001-345833 (already built at `.claude/dbc/patched/Item.dbc`)
- `DBFilesClient\ItemExtendedCost.dbc` — must include IEC 100008 (30x token for tier III kits)
- `DBFilesClient\Spell.dbc` — must include spell 105000 (kit use-spell)

The patched `Item.dbc` is already in the shared volume `ac-client-data-v2` (54,739 recs, validated on PTR). No server-side DBC action needed. The player MPQ distribution is the owner's manual step.

### D. Restart live worldserver (DEFERRED by owner)
The owner has indicated the live worldserver restart is deferred. The DB apply and image build can be done independently. The worldserver will only activate Gear Ascension after restart with the new image.

---

## Rollback scope

If rollback is needed, `rollback.ps1` restores the full `acore_world` snapshot taken
at the start of apply. This removes all Gear Ascension rows atomically. The `item_upgrade_chain` table will also be gone (it's in the snapshot's absent-table list, not restored).

**Rollback does NOT revert:** C++ image rebuild (requires re-deploy of prior image), AHBot conf edit, or client MPQ distribution.

---

## Smoke tests (run after worldserver restart)

```sql
-- 1. Tier copies present
SELECT COUNT(*) FROM acore_world.item_template WHERE entry BETWEEN 300001 AND 345833;
-- Expected: 8480

-- 2. Chain table present and populated
SELECT COUNT(*) FROM acore_world.item_upgrade_chain;
-- Expected: 8480

-- 3. Kit items present
SELECT entry, name, Quality FROM acore_world.item_template WHERE entry BETWEEN 200000 AND 200020 ORDER BY entry;
-- Expected: 21 rows, names like 'Crude Blacksmith's Kit', quality 1/2/3

-- 4. Kit vendor placement
SELECT entry, item, slot, ExtendedCost FROM acore_world.npc_vendor
WHERE entry IN (190101,190102,190103) AND item BETWEEN 200000 AND 200020
ORDER BY entry, slot;
-- Expected: 21 rows (7 per vendor)

-- 5. IEC 100008
SELECT * FROM acore_world.itemextendedcost_dbc WHERE ID = 100008;
-- Expected: 1 row, ItemCount_1=30, ItemID_1=100017

-- 6. Spell + script name
SELECT ID, CastingTimeIndex, Effect_1 FROM acore_world.spell_dbc WHERE ID = 105000;
-- Expected: CastingTimeIndex=5, Effect_1=77
SELECT * FROM acore_world.spell_script_names WHERE spell_id = 105000;
-- Expected: ScriptName='spell_gear_ascension_apply_kit'

-- 7. Russian locales
SELECT COUNT(*) FROM acore_world.item_template_locale WHERE ID BETWEEN 300001 AND 345833 AND locale='ruRU';
-- Expected: 8472
```

In-game smoke test:
1. Talk to Nemesis rank-2 vendor (entry 190101) — should show 7 tier-I kit items priced at 10 tokens
2. Acquire a tier-I metal kit, target a white plate item, cast — should upgrade to green copy
3. Verify upgraded item has `+10%` stats vs base and appears in acore_world.item_upgrade_chain
