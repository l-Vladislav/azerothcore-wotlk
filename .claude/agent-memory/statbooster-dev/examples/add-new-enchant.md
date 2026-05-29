# Worked example: adding a new Fortune-pool proc enchant

Realistic, grounded in the actual conventions of this fork (verified 2026-05-26 against `SpellItemEnchantment_custom.csv`, `EnchantDB.lua`, and `fortune_T1_summary.md`).

**Goal:** add a new Fortune-pool enchant that triggers an existing client-known proc spell on melee hit. We'll call it **"Удача: Шквал ярости"** (Luck: Burst of Fury), enchant ID **90138** (first free in the safe utility range — see [id-range-map.md](../id-range-map.md)).

## Step 0 — confirm scope

This example assumes you want to add an enchant that:
- Uses an **existing** client-known spell as the proc trigger → no `Spell_custom.csv` edits, no client MPQ patch
- Goes into the Fortune pool (poolGroup = 4) → Inscription scrolls (Glyph of Fortune T1-T4)
- Targets a specific iLvl band and a specific slot set

If you need a brand-new custom **trigger spell**, that's a [[spell-editor]] task — comes back here for the enchant wrapper after the spell exists.

## Step 1 — pick a triggered spell

Examples already in use by Fortune T1 (from `pools/fortune_pool/fortune_T1_summary.md`):
- 22586 = +5% movement speed (used by enchant 90001)
- 10665 = Water Walking (used by 90003)
- 43929 = Fiery Weapon (used by 90040)
- 20004 = Life Steal (used by 90041)

For "burst of fury" pick a vanilla buff spell with a temporary AP/haste boost. Use [[dbc-investigator]] to search `Spell.csv` for the right ID. For this example, assume we picked spell **15600** (placeholder — VERIFY before using).

```
# Use dbc-investigator, or:
grep '^"15600",' .claude/dbc/Spell.csv | head -c 800
```

Confirm: it's a buff spell (Effect=APPLY_AURA), has a reasonable duration, and is one the client already knows. If your editor's chosen spell isn't in `Spell.csv`, it might still exist (the CSV may be partial) — in that case verify via the live `spell_dbc` table or pick a different spell.

## Step 2 — pick a free enchant ID

Per [id-range-map.md](../id-range-map.md): free gaps in 90xxx are `90138-91000`. Pick **90138** (first in that block).

Verify it's free:
```powershell
$csv = ".claude/dbc/SpellItemEnchantment_custom.csv"
Get-Content $csv | Where-Object { $_.StartsWith('90138,') }
# Must return nothing
```

## Step 3 — add row to `SpellItemEnchantment_custom.csv`

`SpellItemEnchantment_custom.csv` is comma-separated, **no quotes** on values, 38 columns. Mirror the structure of an existing 90001-style proc row.

Key fields for an EQUIP_SPELL proc:

| Col | Field | Value | Why |
|---|---|---|---|
| 0 | `ID` | `90138` | the new enchant |
| 1 | `Charges` | `0` | infinite |
| 2 | `Effect_1` | `3` | `ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL` (proc on equip/combat) |
| 11 | `EffectArg_1` | `15600` | the triggered spell ID from step 1 |
| 14 | `Name_Lang_enUS` | (leave empty) | optional English fallback; existing rows leave blank |
| 22 | `Name_Lang_zhTW` | `##SB##Удача: Шквал ярости` | **Russian — zhTW slot, with ##SB## prefix. See [../text-localization-rules.md](../text-localization-rules.md).** |
| 30 | `Name_Lang_Mask` | `16712190` | standard mask used by all existing custom enchants |

All other columns: `0`.

A full row looks like:
```
90138,0,3,0,0,0,0,0,0,0,0,15600,0,0,,,,,,,,,##SB##Удача: Шквал ярости,,,,,,,,16712190,0,0,0,0,0,0,0
```

## Step 4 — SQL: mirror into `spellitemenchantment_dbc` + register in `statbooster_enchant_template`

Delegate to [[sql-migration-writer]] with these statements (target: `data/sql/updates/pending_db_world/`):

```sql
-- 4a. Mirror the DBC row server-side
DELETE FROM `spellitemenchantment_dbc` WHERE `ID` = 90138;
INSERT INTO `spellitemenchantment_dbc`
  (`ID`, `Charges`, `Effect_1`, `EffectArg_1`, `Name_Lang_zhTW`, `Name_Lang_Mask`)
VALUES
  (90138, 0, 3, 15600, '##SB##Удача: Шквал ярости', 16712190);

-- 4b. Register enchant in StatBooster's pool template.
-- Note: one ID may have multiple rows for different tiers/slot masks.
-- For this example: T1 Fortune, all weapons.
-- ItemTypeMask = 8192 (1H) + 131072 (2H) + 2097152 (MH) + 4194304 (OH) = 6430720
DELETE FROM `statbooster_enchant_template`
WHERE `Id` = 90138;

INSERT INTO `statbooster_enchant_template`
  (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `PoolGroup`, `Description`, `Note`)
VALUES
  -- T1: iLvl 1-25, all weapons
  (90138, 1, 25, 2, 0, 0, 6430720, 4, '+AP/haste 10s on melee crit', 'Fortune T1 weapons');
```

Reference for `ItemTypeMask` slot values: see [../pool-scrolls-reference.md](../pool-scrolls-reference.md) or `EnchantDB.lua` `SB.DB.SlotMask` (lines 52-75). To target multiple slots, sum the bits.

If the same enchant should also be available at T2-T4, add more rows with the appropriate `iLvlMin/Max`.

## Step 5 — sync into `EnchantDB.lua`

**Do NOT skip this step** — without it the in-game spellbook tab will show the enchant as unknown.

Edit `modules/StatBooster/ClientAddon/StatBoosterUI/EnchantDB.lua`. Find the `SB.DB.EnchantNames` table and add:

```lua
SB.DB.EnchantNames = {
    ...
    [90137] = "...",
    [90138] = "Шквал ярости",   -- ← NEW: strip BOTH ##SB## AND pool prefix ("Удача:")
    ...
}
```

Important:
- Russian text in the Lua table is **without** the `##SB##` tag AND **without** the pool prefix (`Удача:`, `Тайный:`, etc.) — both are stripped per the canonical comment in `EnchantDB.lua` line 94: "strip ##SB## and pool prefixes"
- DBC `Name_Lang_zhTW` keeps the full `##SB##Удача: Шквал ярости` form (used for item tooltip)
- The Lua entry is only for StatBooster's spellbook UI, where the pool is shown as a separate column — prefix would be redundant
- Use literal Cyrillic; the file is UTF-8

## Step 6 — sync into the pool design doc

Add a row to `.claude/statBoosterItems/pools/fortune_pool/fortune_T1.md` (or whichever tier(s) you're adding to) so the design source-of-truth stays in sync. Don't skip — future audits read those docs.

## Step 7 — apply & verify on PTR

This fork is **PTR-first** (see [../current-config.md](../current-config.md)). Always test on PTR before live.

```bash
# Apply SQL on PTR
docker compose exec ac-database-v2 mysql -uacore -pacore acore_world < data/sql/updates/pending_db_world/<your-file>.sql

# Restart PTR worldserver
docker compose restart ac-worldserver-ptr
```

In-game on PTR:
1. As GM: get a Glyph of Fortune T1 (item `100013`) and apply it to an iLvl 1-25 weapon repeatedly until your new enchant rolls — or reload to force selection.
2. Hover the enchanted weapon → tooltip line should appear as **"Удача: Шквал ярости"** colored as a StatBooster boost (gold tint).
3. Trigger the proc by attacking a target dummy. Confirm the buff appears as the original spell 15600 buff (icon + tooltip in whatever locale the client cached for that spell).
4. Open the StatBooster spellbook tab → "Удача: Шквал ярости" should be listed (proves the EnchantDB.lua update took effect).

### Diagnostics if it doesn't appear

| Symptom | Likely cause |
|---|---|
| Tooltip line says "Удача: Шквал ярости" but no gold color | `##SB##` prefix missing in DBC/SQL `Name_Lang_zhTW` |
| Tooltip line is empty / "Unknown enchant" | Mismatch between `SpellItemEnchantment_custom.csv` and `spellitemenchantment_dbc` SQL — re-grep both |
| Spellbook tab shows "???" but tooltip works | `EnchantDB.lua` `SB.DB.EnchantNames[90138]` missing — refresh in-game with `/reload` |
| Enchant never rolls | Check `Enable=1` in `env/dist/etc-ptr/modules/statbooster.conf`; check that target weapon iLvl is in [1, 25]; verify `statbooster_enchant_template` row exists |

## Step 8 — promote to live

After PTR validation:
1. The SQL file in `pending_db_world/` is shared between realms (same `acore_world` schema). Leave the file in `pending_db_world/` until PR merge — that's the convention.
2. Restart `ac-worldserver` (the live one): `docker compose restart ac-worldserver`.
3. Players on live will pick up the addon update on their next client patch — pure-server enchants work without addon updates, but the spellbook listing needs the new `EnchantDB.lua` to be distributed.

## What this example deliberately skips

- **New custom triggered spells** (would need a row in `Spell_custom.csv` + client MPQ patch for `Spell.dbc`) → [[spell-editor]] task
- **New scroll items** (would need `item_template` updates and possibly a new vanilla QA repurpose) → see [../pool-scrolls-reference.md](../pool-scrolls-reference.md)
- **New pool groups** (would need C++ changes in `StatBoostCfgMgr.cpp`) → architectural, requires user approval
- **Stat-copy enchants (`##SB##+N к рейтингу X`)** → those go in the 91xxx range, use `Effect_1=5` and `EffectArg_1=<stat_mod_id>`, NOT the EQUIP_SPELL pattern shown here. The 3-place sync (DBC / SQL / Lua) still applies.
