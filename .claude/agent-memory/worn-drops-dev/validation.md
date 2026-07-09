# Item-type validation — run after every regeneration (DB = acore_world_ptr, container ac-database-v2, root/password)

## SQL checks (each MUST return 0 unless noted)
```sql
-- A) ICON↔MATERIAL (the core check): a displayid shared across >1 subclass => one icon serves two
--    materials => "plate item shows cloth icon". This is THE item-type invariant. MUST be 0.
SELECT displayid, COUNT(DISTINCT subclass) FROM item_template
 WHERE entry BETWEEN 400000 AND 999999 GROUP BY displayid HAVING COUNT(DISTINCT subclass) > 1;

-- B) white tier with stats (white = armor/dmg only). MUST be 0.
SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 400000 AND 1099999 AND Quality=1 AND (stat_value1>0 OR stat_value2>0);

-- C) weapon with no damage. MUST be 0.
SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 1000000 AND 1099999 AND Quality=1 AND (dmg_min1+dmg_max1)=0;

-- D) inherited donor requirements. MUST be 0.
SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 400000 AND 1099999
 AND (RequiredSkill>0 OR requiredspell>0 OR RequiredReputationFaction>0 OR requiredhonorrank>0);

-- E) bonding must be BoE=2 (user decision 2026-07-04: tradeable/mailable/AH until equipped,
--    like regular world drops; was BoP=1 through session 13). MUST be 0.
SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 400000 AND 1099999 AND bonding<>2;

-- F) invalid slot/class. MUST be 0.
SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 400000 AND 1099999 AND (InventoryType=0 OR class NOT IN (2,4));

-- G) tier growth (spot-check a group; sta must strictly increase white<green<blue<purple):
--    SET @b := <group base entry, entry%10=0>; SELECT entry,Quality,stat_value1 FROM item_template WHERE entry BETWEEN @b AND @b+3 ORDER BY entry;

-- J) WEAPON TYPE CONSISTENCY (session 5, added after a live weapon-type bug): a generated
--    weapon's subclass/name must match its OWN generation-input intent, not a donor's. This is
--    NOT directly a single SQL query against item_template (subclass alone can't detect a wrong-
--    donor pick without the generation TSVs) -- run the Python ground-truth audit instead:
--    for every REAL creature_equip_template.ItemID{1,3} weapon, look up its real item_template
--    (class,subclass), and confirm it EXACTLY matches what ended up in weapon_creature.tsv's
--    subclass column for that (creature_entry, wslot). See scripts/audit pattern in state.md
--    session 5 notes (compare against creature_equip_template.sql + item_template.sql directly,
--    offline, no DB needed) -- MUST be 0 mismatches. Also spot-check a few weapon_groups.tsv rows'
--    donor_entry's own item_template.subclass == the row's own subclass column (donor picked
--    must never silently be a different weapon TYPE than what the group intends).

-- K) OFFHAND-ARMOR TYPE CONSISTENCY (session 5, shield + held-in-offhand): every item dropped
--    via worn_drop_item at slot=12 (shield) MUST be class=4/subclass=6/InventoryType=14; every
--    item at slot=13 (held-in-offhand) MUST be class=4/subclass=0/InventoryType=23. MUST be 0:
SELECT COUNT(*) FROM item_template it JOIN worn_drop_item wdi ON wdi.item_entry=it.entry AND wdi.slot=12
 WHERE it.class<>4 OR it.subclass<>6 OR it.InventoryType<>14;
SELECT COUNT(*) FROM item_template it JOIN worn_drop_item wdi ON wdi.item_entry=it.entry AND wdi.slot=13
 WHERE it.class<>4 OR it.subclass<>0 OR it.InventoryType<>23;

-- L) MATERIAL PIVOT end-to-end (session 6, query UPDATED session 9 to exclude PROGRESSION
--    sentinels -- see O/P below for the sentinel-specific checks): worn_drop_display carries its
--    OWN material_id per (creature_display_id, slot) row. For rows with a CONCRETE material_id
--    (not 5/6, not tabard slot=10), the item actually resolvable via worn_drop_item+item_template
--    must have subclass == the row's own material_id. MUST be 0:
SELECT COUNT(*) FROM worn_drop_display wds
 JOIN worn_drop_item wdi ON wdi.item_displayid=wds.item_displayid AND wdi.slot=wds.slot AND wdi.material_id=wds.material_id
 JOIN item_template it ON it.entry=wdi.item_entry
 WHERE wds.slot<>10 AND wds.material_id NOT IN (5,6) AND it.subclass<>wds.material_id;

-- M) MATERIAL PIVOT coverage gap (session 6, query UPDATED session 9): every worn_drop_display row
--    with a CONCRETE material_id (excl. tabard, excl. PROGRESSION sentinels 5/6 -- see M-sentinel
--    below) must resolve to AT LEAST one worn_drop_item row for its own (look,slot,material) -- a
--    look/material combo written to the display table with zero matching generated items would
--    silently never drop despite looking correct in worn_drop_display alone. MUST be 0:
SELECT COUNT(*) FROM worn_drop_display wds
 WHERE wds.slot<>10 AND wds.material_id NOT IN (5,6) AND NOT EXISTS (
   SELECT 1 FROM worn_drop_item wdi
   WHERE wdi.item_displayid=wds.item_displayid AND wdi.slot=wds.slot AND wdi.material_id=wds.material_id
 );

-- M-sentinel) PROGRESSION SENTINEL coverage gap (session 9, NEW): every worn_drop_display row
--    carrying a PROGRESSION sentinel (5=Hunter, 6=Warrior) must resolve to AT LEAST one
--    worn_drop_item row for its (look,slot) REGARDLESS of material (since the sentinel resolves to
--    a DIFFERENT concrete material depending on band, worn_drop_item will have MULTIPLE material
--    values for the same look/slot -- one bucket per band range, both must exist for full coverage,
--    but "at least one" is the minimum sanity floor). MUST be 0:
SELECT COUNT(*) FROM worn_drop_display wds
 WHERE wds.material_id IN (5,6) AND NOT EXISTS (
   SELECT 1 FROM worn_drop_item wdi WHERE wdi.item_displayid=wds.item_displayid AND wdi.slot=wds.slot
 );

-- N) NAME/MATERIAL TEXT CONSISTENCY (session 6, NOT a clean single predicate -- beware substring
--    false positives, e.g. "Breastplate" contains "Plate"): after ANY change that makes a new
--    material key reachable in gen-worn.py's BASE dict, spot-check that Leather/Mail items never
--    carry literal Plate-only vocabulary. This check must anchor on WORD boundaries or it produces
--    false positives (a naive 'LIKE %Plate%' on subclass IN (2,3) hit 288 "false" rows here, all
--    "...Breastplate", not real bugs). Tightened form (still not airtight for every future word
--    choice, re-derive per the actual BASE text in use):
SELECT COUNT(*) FROM item_template it JOIN item_template_locale itl ON itl.ID=it.entry
 WHERE it.entry BETWEEN 400000 AND 999999 AND it.subclass IN (2,3)
   AND (it.name LIKE 'Plate %' OR it.name LIKE '% Plate %' OR it.name LIKE '% Plate' OR itl.Name LIKE '%Латны%');

-- O) NO PLATE BELOW BAND 40 (session 9, NEW, user decision -- real WotLK itemization: Plate
--    Specialization was a level-40 skill). Applies UNIVERSALLY (art-evidenced/vote-typed Plate
--    included, not just the Warrior/Paladin progression fallback). MUST be 0:
SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 400000 AND 999999 AND class=4 AND subclass=4 AND ItemLevel<40;

-- P) WEAPON PK / multi-equip-set SET EQUALITY (session 9, NEW after the worn_drop_weapon PK
--    widening to include subclass): weapon_creature.tsv (LOAD DATA INFILE into a TEMP table in the
--    SAME mysql session -- temp tables don't survive across separate `docker exec mysql -e` calls)
--    must be a byte-for-byte SET match against worn_drop_weapon on ALL 4 columns, BOTH directions
--    (a naive JOIN on a 3-column subset, e.g. omitting subclass, silently produces false
--    "mismatches" via cross-matching when a creature has >1 distinct item_displayid sharing the
--    same (entry,wslot,subclass) -- caught live this session, was a query bug not a real bug, see
--    state.md). MUST be 0 both directions:
--    SELECT COUNT(*) FROM _wc c WHERE NOT EXISTS (SELECT 1 FROM worn_drop_weapon w WHERE w.creature_entry=c.creature_entry AND w.wslot=c.wslot AND w.item_displayid=c.item_displayid AND w.subclass=c.subclass);
--    SELECT COUNT(*) FROM worn_drop_weapon w WHERE NOT EXISTS (SELECT 1 FROM _wc c WHERE c.creature_entry=w.creature_entry AND c.wslot=w.wslot AND c.item_displayid=w.item_displayid AND c.subclass=w.subclass);

-- Q) ID-RANGE CAPACITY (session 9, NEW -- see state.md for the ERROR 1062 incident this prevents):
--    armor entries must stay under 1,000,000 (the weapon block start), weapon entries must stay
--    under 1,100,000 (the DEL_HI ceiling). Report the actual max, don't just check a boolean --
--    utilization trending toward the cap is an early warning for the NEXT scope-widening session:
SELECT MAX(entry) FROM item_template WHERE entry < 1000000;   -- MUST be < 1000000
SELECT MAX(entry) FROM item_template WHERE entry >= 1000000;  -- MUST be < 1100000

-- R) RUSSIAN TEXT DOUBLE-ENCODING (session 9, NEW, added after a real live incident -- the apply
--    command omitted `--default-character-set=utf8mb4` and every ruRU row landed double-encoded,
--    mojibake in-game). Cyrillic UTF-8 always starts with a D0/D1 lead byte -- a non-D-prefixed
--    first byte is a reliable, cheap double-encoding smoke test. MUST be 0. RUN THIS IMMEDIATELY
--    AFTER EVERY FUTURE BIG-SQL APPLY, before declaring success -- do not rely on eyeballing
--    sample text (a garbled string can still LOOK plausible in a truncated terminal render):
SELECT SUM(HEX(LEFT(Name,2)) NOT REGEXP '^D[0-9A-F]') FROM item_template_locale WHERE locale='ruRU' AND ID BETWEEN 400000 AND 1099999;

-- U) DANGEROUS ITEM FLAGS (session 13, NEW, added after a real live incident -- "Merle's sword never
--    drops": items inherited the donor's raw `Flags` column verbatim, including
--    ITEM_FLAG_MULTI_DROP=0x800, an FFA-loot flag this module's post-kill AddItem() can never
--    register in anyone's FFA list -> genuinely-added-but-permanently-invisible loot. Also caught
--    ITEM_FLAG_CONJURED=0x2 (silently deletes the item from inventory after >15min offline,
--    UNCONDITIONAL on item class) and 3 more donor-noise bits (DEPRECATED/MULTI_LOOT_QUEST/
--    NO_PICKUP/HAS_LOOT) via a full audit -- see gen-worn.py's FLAGS_STRIP_MASK comment for the
--    bit-by-bit rationale of what's stripped vs kept (NO_DURABILITY_LOSS is legitimately kept).
--    MUST be 0. This check is ORTHOGONAL to A-T (none of them read Flags) -- run it every time:
SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 400000 AND 1099999 AND (Flags & (0x1|0x2|0x4|0x10|0x100|0x800)) <> 0;

-- V) LOOT-SLOT-CAP RISK (session 16, diagnostic only, NOT a pass/fail gate -- run this whenever
--    investigating a "boss killed, zero worn-drops items" report before assuming a pipeline bug).
--    `Loot::AddItem` (src/server/game/Loot/LootMgr.cpp) silently no-ops past MAX_NR_LOOT_ITEMS=18
--    (non-quest) / MAX_NR_QUEST_ITEMS=32 (quest) with ZERO log/error -- since our module's AddItem
--    calls run AFTER the stock creature_loot_template roll already populated creature->loot, a
--    creature with enough guaranteed (Chance=100) non-quest rows can starve our own drops with no
--    trace on either side. Flags any worn-drop-scope creature whose OWN loot table alone could
--    plausibly fill the 18-slot cap (guaranteed rows only -- chance<100 rows adding up over many
--    kills is a separate, much lower-probability tail risk not modeled here). Investigated for
--    Angerforge (9033, only 12 total rows) and swept against the whole scope 2026-07-06: 0 hits.
SELECT clt.Entry, ct.name, COUNT(*) AS guaranteed_nonquest_rows
FROM creature_loot_template clt JOIN creature_template ct ON ct.entry=clt.Entry
WHERE clt.Chance=100 AND clt.QuestRequired=0 AND clt.Entry IN (SELECT creature_entry FROM worn_drop_scope)
GROUP BY clt.Entry HAVING guaranteed_nonquest_rows >= 10 ORDER BY guaranteed_nonquest_rows DESC;

-- W) RELIABLE BOSS SET COVERAGE (2026-07-08, "session 16" per state.md -- NEW): the runtime WD_Boss
--    set is loaded from `instance_encounters` (creditType=0), independent of
--    Creature::IsDungeonBoss()/isWorldBoss() (which depend on a DBC-lookup-gated ObjectMgr flag-set
--    that silently skips custom/non-DBC encounters -- see state.md for the full root-cause writeup,
--    Darkmaster Gandling 1853 is the concrete example this was found from). Not a pass/fail gate
--    with a fixed expected count (the table's row count legitimately grows over time) -- use this to
--    spot-check that a SPECIFIC creature you expect to be a boss is actually covered, and that a
--    SPECIFIC non-boss trash mob is correctly NOT covered, whenever investigating a "boss drop rate
--    looks wrong" report:
SELECT COUNT(DISTINCT creditEntry) FROM instance_encounters WHERE creditType=0;   -- 433 as of 2026-07-08
SELECT creditEntry FROM instance_encounters WHERE creditType=0 AND creditEntry IN (<entry>);  -- membership check

-- X) MATERIAL-VOTE TIE-BREAK COVERAGE (2026-07-08, "session 16" per state.md -- NEW, added after the
--    Jandice Barov 10503 investigation found `display_vote_material()`'s tie-break was an
--    IMPLEMENTATION ACCIDENT -- Python Counter/set iteration order -- not a policy; 389/14180
--    evidenced displays (2.7%) hit an exact top-weighted-score tie system-wide, silently resolved to
--    an essentially arbitrary material before the fix). Not runnable against the live DB directly
--    (the tie is a GENERATION-TIME Python computation, not a stored fact) -- re-run as a Python
--    diagnostic inside build-worn-slice.py (or via the exec-up-to-a-marker reuse pattern established
--    throughout this pipeline) any time the evidence/vote weighting changes (SLOT_WEIGHT,
--    EVIDENCE_TIER_WEIGHT, ROBE_VOTE_SLOTS, or a new evidence tier):
--    for d, pairs in display_pairs.items():
--        vote = <recompute the weighted vote for pairs>
--        if vote and len([m for m,v in vote.items() if v == max(vote.values())]) > 1: TIE
--    MUST print a diagnostic count every run ("Tie-break diagnostic: N displays had a genuine
--    top-vote TIE") -- a silent absence of this line (or a change back to `.most_common(1)[0][0]`
--    without the `len(top)>1: return None` guard) means the accident has regressed. A tied display
--    now correctly falls through to the SAME no-evidence fallback chain as a genuinely-evidence-free
--    display (robe-residue -> hunter-token -> [caster-weapon, currently disabled] -> Rogue/Caster
--    flat -> Warrior/Paladin default) instead of an arbitrary pick.

-- Y) INCREMENTAL-ICON CROSS-MATERIAL BLIND SPOT (2026-07-08, "session 16" per state.md -- PROCESS
--    LESSON, not a single query): after ANY incremental/partial material-changing regen (not a full
--    gen-worn.py run), `gen-worn-icons.py`'s own `cross_material_looks` set (computed ONLY from the
--    FRESH worn_groups.tsv) can MISS a look that's cross-material solely because of a STALE,
--    DB-only, no-longer-regenerated occurrence at a different material (a look used by an
--    UNRELATED, unchanged creature at an old material that just happens not to be reproduced by a
--    from-scratch TSV rebuild today, e.g. due to ordinary level drift). Concretely: 29 looks / 58
--    (look,material) pairs hit exactly this in the caster-staff fix session -- check A regressed to
--    29 on the FIRST post-apply run, caught by the standard immediate re-run of check A (not a new
--    check -- just a reminder that A is the ONLY reliable ground truth after an incremental apply,
--    the fresh TSV-based icon resolver's own cross-material bookkeeping is NOT sufficient on its
--    own for anything less than a full regen). Re-run check A immediately after EVERY incremental
--    material-changing SQL apply, before merging any client CSV or declaring the session done --
--    if it's nonzero, resolve icons for the violating (look,material) pairs manually (tiers 2/3/5 of
--    the normal resolution chain; tier 4 "donor icon" may not have a reliable donor context for a
--    STALE off-TSV pair -- degrading to the generic GEN fallback is an acceptable, PRIME-DIRECTIVE-
--    safe simplification for this rare edge case) and re-point ALL matching item_template rows
--    (both old pre-existing AND newly-inserted) via a (look,material)-scoped remap UPDATE.
```

## Client-CSV cross-consistency (NOT SQL -- Python, run against a FRESH DB export, see H below for the pattern)
```python
# T) EMPTY/UNRENDERABLE LIVE DISPLAYID (session 11, NEW, added after a real live incident -- "Alexandra
#    Bolero invisible chest": stock ItemDisplayInfo 5440 had NO model/texture, only a bare
#    GeosetGroup, so equipping it rendered NOTHING even though the icon/tooltip looked fine). Zero
#    generated ARMOR items may have a live displayid (stock OR custom -- union of BOTH
#    `.claude/dbc/ItemDisplayInfo.csv` and `.claude/dbc/ItemDisplayInfo_custom.csv`) with NO
#    ModelName_1/2, NO ModelTexture_1/2, AND NO Texture_1..8. **Gotcha**: checking only
#    ModelName_1+Texture_1..8 (first cut) wrongly flags EVERY stock cloak (they render exclusively
#    via ModelTexture_1) -- always check all 3 channels together. MUST be 0 (both the "empty"
#    count and the "displayid has no ItemDisplayInfo row in either CSV at all" count):
import csv
RENDER_COLS = (["ModelName_1","ModelName_2","ModelTexture_1","ModelTexture_2"]
               + ["Texture_%d" % i for i in range(1,9)])
idi = {}
for path in ('.claude/dbc/ItemDisplayInfo.csv', '.claude/dbc/ItemDisplayInfo_custom.csv'):
    for row in csv.DictReader(open(path, encoding='utf-8-sig')):
        idi[row['ID']] = row
def is_empty(did):
    r = idi.get(str(did))
    return None if r is None else not any(r[c].strip() for c in RENDER_COLS)
# armor_displayids.tsv: `SELECT entry, displayid FROM item_template WHERE class=4 AND entry BETWEEN 400000 AND 999999;`
violations = unknown = 0
for line in open('armor_displayids.tsv', encoding='utf-8'):
    entry, disp = line.rstrip('\n').split('\t')
    e = is_empty(disp)
    if e is None: unknown += 1
    elif e: violations += 1
print('empty/unrenderable live displayids (MUST be 0):', violations)
print('displayid with no ItemDisplayInfo row at all in either CSV (MUST be 0):', unknown)
```
```python
# S) DB<->CLIENT-CSV ORPHAN CHECK (session 10, NEW -- added after a real live incident: a 2-run
#    icon generator overwrote its own output file, losing 2,034 icon rows that WERE already
#    referenced by item_template.displayid; every DB-internal check A-R passed the whole time since
#    none of them read the client CSV file at all). MUST be 0 missing/orphaned BOTH directions.
#    Run this as the LAST step of ANY icon-generation work (full regen OR a partial/iterative one),
#    not just after a full regen:
import csv
# db_disp.txt: `SELECT DISTINCT displayid FROM item_template WHERE entry BETWEEN 400000 AND 1099999 AND displayid>=110000;`
db_disp = set(int(l.strip()) for l in open('db_disp.txt', encoding='utf-8') if l.strip().isdigit())
csv_ids = set(int(r['ID']) for r in csv.DictReader(open('.claude/dbc/ItemDisplayInfo_custom.csv', encoding='utf-8-sig')) if int(r['ID']) >= 110000)
print('DB displayids missing from CSV:', len(db_disp - csv_ids))   # MUST be 0
print('CSV ids orphaned (not referenced by any DB item_template row):', len(csv_ids - db_disp))   # MUST be 0
# Same pattern for Item_custom.csv vs item_template.entry (the full-item, not just-displayid, check
# already established in earlier sessions' audits -- just re-run it after ANY partial regen too).
```

## Client-side checks (icons/sound live in ItemDisplayInfo, not the DB)
```python
# H) custom ItemDisplayInfo (110000+, current live max ~117397 -- check the actual max ID in
#    worn_iconmap.tsv / ItemDisplayInfo_worn_custom.csv rather than hardcoding an upper bound,
#    the block grows whenever more (look,material) pairs are minted) must all have a non-zero
#    GroupSoundIndex (equip sound). Count of 0 MUST be 0.
import csv
z=sum(1 for r in csv.DictReader(open('.claude/dbc/ItemDisplayInfo_custom.csv',encoding='utf-8-sig'))
      if int(r['ID'])>=110000 and r['GroupSoundIndex'] in ('0',''))
print('custom rows with GroupSoundIndex=0:', z)   # must be 0

# I) icon prefix vs material (fuzzy): plate->INV_*Plate/Helmet/Shoulder..., cloth->INV_*Cloth..., etc.
#    SQL check (A) is the reliable proxy for icon-material correctness — trust A.
```

## Interpretation
- (A) > 0  → a look is shared across materials without per-(look,material) displayids → icon mismatch. Fix per the agent's resolution hierarchy (custom ItemDisplayInfo keyed by (look,material), or fall back to a real item's displayid).
- Any B–F > 0 → generation regression; check gen-worn.py int_overrides / stat injection / donor filter.
- (H) > 0 → sound missing on custom ItemDisplayInfo; gen-worn-icons.py must set GroupSoundIndex from the donor.

## Fixed 2026-07-01 (session 1: icon/sound)
Both (A) (~941 looks / 65400 items, root cause: icon pipeline keyed by look only instead of
(look,material)) and (H) (stale pre-sound-fix merge in `.claude/dbc/ItemDisplayInfo_custom.csv`)
were fixed. Full details + exact fix mechanics in `state.md`'s "FIXED 2026-07-01" section — read
that before re-touching gen-worn-icons.py/gen-worn.py/gen-worn-itemdbc.py or the `.claude/dbc/*`
merge logic again, it documents the (look,material) keying contract all three scripts now share
and the .bak-is-not-pristine gotcha.

## Fixed 2026-07-01 (session 2: cape/tabard/family-naming bundle)
- (A) regressed to 12 violations after the cape fix (capes previously generated 0 items, so this
  bug was latent/invisible): stock cloak donors are subclass∈{0,1} regardless of real material,
  causing Plate/Leather capes to inherit the wrong subclass and collide with the tabard pseudo-
  material bucket (0). Fixed via `int_overrides(force_subclass=...)` — armor items now ALWAYS get
  `subclass = matkey` (the true intended material) instead of trusting the donor's own subclass
  column. Re-verified 0 after the fix (see state.md "DONE 2026-07-01" #3 for full mechanics).
- All of A-F confirmed 0 on the live PTR DB after the full regen + subclass fix + worldserver
  rebuild (C++ tabard-matkey fix required a rebuild, not just a restart). H confirmed 0 on the
  freshly regenerated + re-merged `.claude/dbc/ItemDisplayInfo_custom.csv` (7590 rows total, all
  custom rows 110000+ have non-zero GroupSoundIndex).
- G (tier growth) spot-checked on a Plate helm group (400000-400003: stat_value1 0→17→18→20,
  armor 440→484→528→572, strictly increasing) AND a cape group (633780-633783: same pattern) —
  both clean.
- New check worth running after any tabard/pseudo-material change: verify the RUNTIME (C++) uses
  the correct matkey per slot, not just the DB. A DB-only fix is NOT sufficient if `mod_worn_drops.cpp`
  hardcodes a single material for the whole creature (it does, by design, for normal armor slots) —
  a pseudo-material slot needs an explicit override in `OnPlayerCreatureKill`'s armor-roll lambda
  (see state.md Gotchas). This class of bug is invisible to all SQL-only validation queries A-H —
  it can only be caught by reading the C++ consumer of `worn_drop_item`/`worn_drop_scope`.

## Fixed/verified 2026-07-01 (session 3: YO normalization + curated-map expansion + tier-2 auto-derive)
Naming-only change (no displayid/subclass/donor logic touched) — A-F all reconfirmed 0 after the
full regen + apply + restart (no rebuild needed, no C++ touched this round). Tier growth
unchanged/clean. Custom ItemDisplayInfo range unchanged (110000-117573) — naming mints no new
displayids, so no MPQ delta expected or produced.
- **New non-SQL validation technique this session**: byte-exact Python ё-presence check
  (`"ё" in s`) on an exported item_template_locale/creature_template_locale TSV, used to ground
  the YO-normalization decision. Do NOT use `SELECT ... WHERE Name LIKE '%ё%'` for this — the
  default collation (`utf8mb4_unicode_ci`/`0900_ai_ci`) is ACCENT-INSENSITIVE and treats е/ё as
  equal, producing wildly inflated false-positive counts (LIKE claimed 75% of item names had ё;
  the true byte-exact figure was 2%, and 0% among genuinely-stock entry<40000 rows).
- **New auto-derive-specific check worth running after any tier-2 change**: preview ALL
  auto-derived (look → RU phrase) pairs before applying (see `preview_names2.py`-style script in
  this session's scratchpad, reusable pattern: exec gen-worn.py up to the `# ---------- ARMOR`
  marker, then inspect `armor_look_family`/`weapon_look_family` dict entries with tier=='auto').
  Eyeball every phrase for personal-boss-name leakage (a title/role word immediately followed by
  what looks like a proper name, e.g. "ботаник Фрейвин") — this is NOT caught by any of the A-H
  SQL checks (grammatically/structurally valid RU text, just semantically wrong as a "family").

## Fixed/verified 2026-07-01 (session 4: YO reverted OFF, final decision)
User decided against YO after seeing the finding above — `_apply_yo()` reverted to a no-op and
`worn_family_map.tsv`'s ~9 ё-bearing rows reverted to plain е. Naming-only, no displayid/subclass
touched — A-F reconfirmed 0, tier growth clean, custom ItemDisplayInfo range unchanged
(110000-117573), no MPQ delta. Post-apply byte-exact sweep of ALL 110235 live
`item_template_locale` rows in the 400000-799999 range confirms exactly ONE surviving ё source:
`Ружьё` (Gun base noun, WBASE[3]) — pre-existing, dictionary-mandatory, untouched by any of this
session's edits, correctly NOT part of the reverted family-naming ё. If regenerating and this
count changes, something in WBASE/BASE changed unexpectedly — investigate before assuming it's fine.

## Fixed/verified 2026-07-01 (session 5: 3 bugs — weapon type, tabard drop, shield/offhand)
Full root-cause writeups in state.md's "DONE 2026-07-01 (session 5...)" section — summary here:
- **(J) weapon type consistency, NEW check, was failing pre-fix**: 160/3903 weapon_groups.tsv
  rows had a donor whose real subclass didn't match the group's intended subclass (`pick_donor`'s
  invtype-only fallback crossed subclass boundaries); separately, 16 displayids' `worn_drop_weapon`
  subclass was reconstructed via a fragile look-keyed dict that could silently pick the WRONG
  creature's subclass. Both fixed (see state.md). Post-fix: 0/3903 donor mismatches, 7655/7655
  worn_drop_weapon rows verified correct against real `creature_equip_template` ground truth.
- **(A) regressed to 1232 violations mid-session** (all shields, subclass=<wearer material>
  instead of 6) when shields were first wired in — caught by check (K) before it ever reached a
  live apply. Root cause: `emit_group`'s `force_subclass=matkey` (correct for real armor/tabard)
  wrongly applied to shield/held too. Fixed via a new `subclass_override` param. Re-verified (A)=0
  and (K)=0/0 (shields, held) after the fix.
- **A live SQL apply failure** (`ERROR 1062 Duplicate entry '370-12' for key
  'worn_drop_display.PRIMARY'`) caught the architecture bug of feeding equip-template-sourced
  offhand items into the display-keyed `worn_drop_display` table — fixed by adding a new
  entry-keyed `worn_drop_offhand` table (see state.md Gotchas, "creature_equip_template is keyed
  by CREATURE_ENTRY" note). This is a class of bug worth checking for FIRST (before any other
  validation) whenever a new item source is added: is the natural key of the SOURCE DATA
  (creature_display_id vs creature_entry) the same as the key of the runtime table it's being
  fed into? If not, a collision (or worse, silent wrong data) is likely.
- Final state: A-F all 0, (J) 0/3903 + 0/7655, (K) 0/1232 + 0/548. Tier growth spot-checked on
  both a normal armor group (400000-400003) and a shield group (637480-637483, armor 5→6→7→8) —
  both strictly increasing. Custom ItemDisplayInfo grew 117573→117595 (+22, shield/held icons) —
  **this DOES need an MPQ delta**, unlike sessions 2-4's naming-only work. worldserver REBUILT
  (not just restarted) for the tabard band/quality-override + WD_Offhand roll C++ changes.

## Fixed/verified 2026-07-01 (session 6: ARMOR MATERIAL PIVOT — material from LOOK not unit_class)
Full root-cause + mechanics writeup in state.md's "DONE 2026-07-01 (session 6...)" section —
summary here:
- **Material distribution BEFORE**: effectively 100% Plate/Cloth, Leather near-zero, Mail
  IMPOSSIBLE (no unit_class value maps to it). **AFTER** (live, entry 400000-699999, class=4):
  Plate 75164, Cloth 9692, Leather 3872, Mail 2400, plus 671 held-offhand(subclass=0)/1232
  shield(subclass=6) unaffected by the pivot. Mail and Leather are now solidly represented.
- **Coverage**: 1300/9922 (slot,look) pairs resolved via a REAL stock item_template join (13.1%),
  8622 via the old unit_class fallback (86.9%) — expected shape, most NPC looks have no
  player-obtainable equivalent item to join against; the fallback carrying the majority is correct,
  not a partial-failure state.
- Cape (slot 11) deliberately kept OFF the real-item join (stock cloak donors are always
  subclass∈{0,1} regardless of true wearer material — zero genuine signal, confirmed 71/71 via a
  feasibility check) — still unit_class-only, matching pre-pivot behavior for this one slot only.
  Shield/held (12/13) untouched — fixed subclass constants independent of material, out of scope.
- (A) through (K) all reconfirmed 0 after the pivot. **New (L) material-pivot end-to-end and (M)
  coverage-gap checks both 0 on first try** — the SQL/schema mechanics were correct from the start.
- **(N) caught a REAL bug that A-M structurally cannot see**: `gen-worn.py`'s armor base-noun
  `BASE` dict had no Leather(2)/Mail(3) entries (only ever needed 0/1/4 before this pivot) — its
  `.get(mat, BASE[4])` fallback silently named EVERY Leather/Mail item with Plate text ("Leather
  Helm" showed as "Plate Helm"/"Латный шлем"). Caught by eyeballing sample output for the report,
  not by any automated check. Fixed by adding full Leather/Mail base-noun sets; re-verified via a
  WORD-BOUNDARY-anchored version of (N) → true 0 (the naive substring version returned a
  false-positive 288, all "...Breastplate" containing the substring "Plate").
- Tier growth spot-checked on a fresh Leather group (401880-401883: armor 13→15→16→17,
  stat_value1 0→2→3→4) and a fresh Mail group (437990-437993: armor 151→167→182→197,
  stat_value1 0→5→6→7) — both strictly increasing, white has no stats, matches the existing
  pattern for Plate/Cloth groups.
- Client-side: custom ItemDisplayInfo COUNT went DOWN (7596→6311, ids 110000-116310) since each
  look now resolves to exactly one material instead of following whichever unit_class wore it
  (fewer cross-material collisions) — but the SET of (look,material) pairs shifted, so this is
  still an MPQ-affecting change (existing cached client icons for some looks would show the WRONG
  material's icon until the user rebuilds MPQ + clears Cache/WDB). Rebuilt `.claude/dbc/Item_custom.csv`
  (132 base + 108643 worn = 108775 rows) and `.claude/dbc/ItemDisplayInfo_custom.csv` (16 base +
  6311 worn = 6327 rows) fresh from this session's live DB export — both include session 5's
  shield/held rows too (one clean merge covering everything since the last MPQ rebuild).
- **New MySQL 8.4 gotcha surfaced+fixed this session**: `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`
  is NOT valid vanilla-MySQL syntax (MariaDB-only extension) — see state.md Gotchas for the
  `information_schema`+`PREPARE`/`EXECUTE` idiom now used instead for the `worn_drop_display.material_id`
  upgrade path.
- worldserver REBUILT (not just restarted) — `WD_Display`'s C++ shape changed from
  `vector<pair<uint8,uint32>>` to `vector<tuple<uint8,uint32,uint8>>` to carry the per-row material.
  Verified via fresh boot log: `mod-worn-drops: loaded 6244 scope, 7461 displays, 6207 weapon-maps,
  914 offhand-maps, 108643 items.` with zero errors.

## Fixed/verified 2026-07-01 (session 7: ICON QUALITY PASS — model-match + real-item provenance)
Full writeup in state.md's "DONE 2026-07-01 (session 7...)" section — summary here:
- **New icon resolution chain** in `gen-worn-icons.py` (5 tiers, most-accurate first): (1) stock
  look's own icon if single-material [unchanged]; (2) NEW — cross-material look's stock icon if
  attributable to a real item of THIS material; (3) NEW — model-name match (ModelName_1+2,
  case-insensitive, texture-agnostic) against any icon-bearing ItemDisplayInfo row, GATED to
  candidates that are themselves a real class=4 item's displayid with a matching InventoryType
  (prevents cross-category icon borrowing, see Gotcha below); (4) donor-material icon [unchanged];
  (5) generic GEN fallback [unchanged, last resort].
- **Result** (6311 total (look,material) pairs needing a custom icon): real_item 0→13,
  model_match 0→1003 (tier didn't exist before), donor 6228→5232, generic 83→63. Net **1016 pairs
  upgraded** from a substituted/generic icon to an exact-visual type-verified icon — concentrated in
  head (many), shoulder (many), held-in-offhand (22, ALL of them, since held props are literally
  the model itself — potion bottles/books/bags/swords instead of one generic talisman icon for
  everything). Geoset slots (chest/legs/belt/wrist/gloves/boots/cape/tabard) structurally
  unaffected — no ModelName_1 to match on, exactly as predicted going in.
- **A real live bug caught+fixed mid-session, NOT covered by A-N**: an unfiltered "any same-model
  icon" tier 3 landed on `INV_Shield_09`/`INV_Box_01` for HEAD-slot looks (model
  `Helm_Eyepatch_A_01.mdx`/`Helm_Cloth_Holiday_Christmas_A_01.mdx` reused by Blizzard across
  unrelated item categories — amulets/belts/shields/gift-boxes as well as actual helmets). Added a
  quality gate requiring the candidate to be a real item of the SAME slot's InventoryType before
  its icon can be borrowed. **This class of bug (wrong item-CATEGORY icon, not wrong-material icon)
  is invisible to every check A-N** — those validate class/subclass/material/name-text agreement,
  never "does this icon's shape/theme match the SLOT the item occupies". No systematic SQL check
  exists for it; the only guard is the generation-time gate itself plus eyeballing sample icon
  names for shape-vs-slot plausibility (a "Box"/"Shield" icon on a head item is an obvious red flag
  on sight, a "Helmet_NN" icon is not, even if the specific helmet icon looks unusual).
- **A-M all reconfirmed 0** (icon-only change cannot affect them; run anyway as a sanity check per
  request, not skipped). **H reconfirmed 0** on the freshly regenerated 6311-row
  `ItemDisplayInfo_worn_custom.csv` — GroupSoundIndex is untouched by tier logic (always sourced
  from the donor, independent of which icon tier fired).
- **No SQL/DB change at all this session** — confirmed by actually applying
  `worn_displayid_remap.sql` and observing 0 net effect (custom-displayid row count identical
  before/after: 57386) — the custom-id SET is unchanged from session 6, only the `InventoryIcon_1`
  VALUE within existing `ItemDisplayInfo` rows changed, which is invisible to any `item_template`
  query. No worldserver restart or rebuild needed (verify this reasoning holds — if a future icon
  change ALSO altered which (look,material) pairs get a custom id, the remap step would no longer
  be a no-op and would need the full JOIN-vs-MEMORY-table apply).

## Verified 2026-07-02 (full read-only audit sweep, post-reboot — all PASS)
Ran the complete A-N set plus J's TSV-ground-truth cross-check plus K/L/M plus a 20-row random
DB↔`.claude/dbc/*.csv` cross-consistency spot-check (armor/weapon/shield/held/tabard) — **all 0
violations, all counts exact matches to state.md's documented session-7 end state** (108643 items,
6311 custom ItemDisplayInfo ids 110000-116310, material distribution Plate 75164/Cloth 9692/
Leather 3872/Mail 2400, zero orphans either direction between DB and the two `.claude/dbc/*.csv`
files). One documentation-only finding (not a validation-check failure): a session-7 icon example
line in state.md implied a positional 1:1 look-id/icon-name mapping that didn't actually hold for
3 of 5 entries — corrected in state.md, no underlying pipeline defect (traced the real tier-3
model-match resolution and confirmed it's working exactly as designed). See state.md's new Gotchas
entries on this.

## DONE 2026-07-02 (session 8: TABARD-CHANCE SEPARATION — C++/config only, zero DB delta)
User decision: tabard drop should be rarer than regular armor, with its own independently-tunable
chance (`WornDrops.TabardChance`), decoupled from `WornDrops.Chance`/`ArmorPerKill` so tabard
rarity doesn't distort armor-slot odds. Implemented entirely in
`modules/mod-worn-drops/src/mod_worn_drops.cpp` (new `WD_Tabard` map split out of `WD_Display` at
`LoadData()` time, new standalone roll block in `OnPlayerCreatureKill`) + 2 config files (prod
default 5 in `conf/mod-worn-drops.conf.dist`, PTR test value 100 in
`env/dist/etc-ptr/modules/mod-worn-drops.conf`). **Zero SQL/DB/DBC change** — `worn_drop_display`
table schema and data are untouched, the split happens purely in the C++ load path. Required a
worldserver image REBUILD (`.cpp` change) — rebuilt clean, verified via the new 6-field boot log
line (`... 7461 displays, 1693 tabard-maps, 6207 weapon-maps ...`) and a live DB trace confirming
the Scarlet Champion (entry 4302) tabard still resolves end-to-end through the new split path.
A/F and the tabard item count (123) reconfirmed unchanged directly against the live DB post-rebuild
(nothing else could plausibly regress from a pure C++/config change with no SQL touched). Full
mechanics in state.md's "DONE 2026-07-02 (session 8...)" section.

## DONE 2026-07-02 (session 9: Argent Sentry multi-bug + FINAL material spec)
Full root-cause + mechanics writeup in state.md's "DONE 2026-07-02 (session 9...)" section — this
is the biggest single-session change in this module's history (108,643 → 187,288 items, ID ranges
widened and relocated, entire material-resolution algorithm replaced). Summary of validation outcomes:
- **A-F, K, L (updated for sentinel exclusion), N**: all 0, checked against the NEW id ranges
  (400000-999999 armor / 1000000-1099999 weapons).
- **M (coverage gap) — CAUGHT A REAL BUG, initially 349 violations**: an art-evidenced/vote-typed
  display resolving to concrete Plate(4) whose creature's level range dipped below band 40 stored a
  static "4" in `worn_drop_display` while item generation correctly capped those low bands to
  Mail(3) — the runtime lookup for band<40+matkey=4 permanently missed. Fixed by unconditionally
  sentinel-izing EVERY display that resolves to concrete Plate (not just the Warrior/Paladin
  fallback path) — see the new M-sentinel check. Re-verified 0/0 after the fix.
- **M-sentinel (NEW)**: 0 — every PROGRESSION-sentinel display has >=1 matching worn_drop_item row.
- **O (NEW, no Plate below band 40)**: 0 items with class=4/subclass=4/ItemLevel<40, checked
  directly against `item_template` (the generation-time assert in `build-worn-slice.py` also
  independently confirms this at the TSV level before any SQL is even written).
- **P (weapon PK / multi-set set-equality)**: initially investigated a spurious "162 mismatches"
  that turned out to be a QUERY bug (joining on a non-unique 3-column key when both sides can now
  have >1 distinct item_displayid per (entry,wslot,subclass) after multi-equip-set ingestion) —
  the CORRECT bidirectional 4-column set-equality check is 0/0 both directions, 12,411/12,411 rows.
  Also caught + fixed a REAL bug: creature 28579 has 2 equip sets sharing (wslot=21,displayid=46750)
  with DIFFERENT subclass (Axe1H vs Axe2H) — `ERROR 1062` on the OLD 3-column
  `worn_drop_weapon` PK, fixed by widening the PK to include subclass (idempotent migration).
- **Q (id-range capacity)**: MaxArmorEntry=817,563 (<1,000,000 ✓, 69.6% of the 60,000-group armor
  budget used), MaxWeaponEntry=1,051,813 (<1,100,000 ✓, 51.8% of the 10,000-group weapon budget
  used). Both ranges confirmed 100% empty in the live DB before being claimed (no collision with
  Gear Ascension 300000-356762 or the small 200000-200020 kit-item block).
- **Calibration study** (name-token + weapon-loadout signals vs ART+REAL evidenced material,
  threshold ≥85% agreement + ≥5 samples): 7/20 candidate name tokens validated (ranger 97%/n=64,
  hunter 86%/n=135, marksman 95%/n=56, stalker 92%/n=39, farstrider 100%/n=9, poacher 100%/n=12,
  bowman 96%/n=22); loadout signal ("pure ranged weapon") REJECTED at 68.6%/n=290 (implemented,
  calibrated, held to the same bar, and correctly NOT used since it didn't clear it — exactly the
  discipline the user asked for, not a token gesture).
- **All 9 verification traces PASS**: Korfax 16112 + Valdelmar 11898 in scope; Караульный/Argent
  Sentry 16378 mace+shield+crossbow all in the pool at true band 60; Scarlet Cleric 9449 fully
  unified to Cloth (was split Cloth/Plate even after this session's FIRST iteration); Scarlet
  Archmage 9451 fully unified to Cloth incl. head; следопыт/Ranger 8564 + Ranger Lord Hawkspear
  10824 → Mail via direct ART evidence; 3 low-level Farstriders (band<40) → Leather via Hunter
  progression; Novice Ranger 16923 fully unified to Leather (was a 3-material mess before this
  whole session's work).
- **2 non-trivial process gotchas hit this session** (see state.md Gotchas for full detail): a
  double-backgrounded `docker exec mysql < big.sql` produces a FALSE "completed" notification almost
  instantly while the real import keeps running for minutes (always verify via
  `information_schema.innodb_trx`/fresh-vs-stale data spot-check, never trust the notification
  alone for a backgrounded big-SQL apply); a `str`/`int` key-type mismatch made an entire new rule
  (robe residue) silently apply to ZERO cases (0/0 in diagnostics, which LOOKS plausible) until
  cross-checked against a hand-verified real example.
- **worldserver REBUILT** (`.cpp` change: `ResolveProgressionMaterial()` sentinel resolution in the
  armor-roll lambda) — clean build, restarted, verified via the new boot log line:
  `mod-worn-drops: loaded 12878 scope, 13264 displays, 2490 tabard-maps, 10306 weapon-maps, 1490
  offhand-maps, 187288 items.` with zero errors after `World Initialized`.
- **POST-MORTEM (caught AFTER this session's report, by the coordinator, not by any A-N/O-Q check):
  the SQL apply command omitted `--default-character-set=utf8mb4`** — all 187,288 ruRU
  `item_template_locale` rows landed double-encoded (mojibake in-game, e.g. `ÐšÐ¾Ð¶Ð°Ð½Ñ‹Ð¹
  ÑˆÐ»ÐµÐ¼` instead of `Кожаный шлем`). This is a KNOWN project-wide rule (see the user's global
  MEMORY.md "SQL charset for Russian") that still got missed because this session's own apply
  command template never had the flag. Coordinator repaired the live DB in place (byte-level
  `CONVERT(BINARY CONVERT(... USING latin1) USING utf8mb4)` re-decode, ID range 400000-1099999,
  verified 0 broken, restarted worldserver) — no further DB action needed for this specific
  incident. **New check R added** (see SQL checks above) specifically to catch this class of bug
  going forward — cheap (one aggregate query), should be run immediately after every future
  big-SQL apply, not just A-N/O-Q. **Lesson: neither A-N nor O-Q would have ever caught this** —
  they validate class/subclass/stat/slot/id-range correctness, none of them read locale TEXT byte
  content. A text-correctness check (R here, or N's word-boundary text check) is a structurally
  DIFFERENT validation category from every numeric/relational check and must be run separately,
  not assumed to be covered by "the usual suite passed."

## DONE 2026-07-02 (session 10: PLATE-OVERRIDE + TIER-3 NAMING + HELD-NOUN)
Full writeup in state.md's "DONE 2026-07-02 (session 10...)" section. Validation summary:
- A/B/C/D/E/F/K/O/R all reconfirmed 0 against the new 200,204-item total. MaxArmorEntry=849,853
  (<1,000,000 ✓, budget now 74.9% utilized — worth tracking if another scope-widening session adds
  more groups, see the id-range capacity backlog note). M (coverage gap) reconfirmed 0 — the
  plate-override system doesn't touch `worn_drop_display` at all (it's a separate per-creature flag
  in `worn_drop_scope`), so this check is structurally orthogonal, reran anyway as a sanity check.
- **NEW cross-consistency check that caught a real bug this session, not previously formalized as
  a lettered check**: DB↔client-CSV orphan check (`item_template.displayid` set vs
  `ItemDisplayInfo_custom.csv`'s `ID` column set, both directions) — this is NOT covered by ANY of
  A-R (all of which are DB-internal or DB-vs-TSV-input checks; none cross-reference the actual
  MERGED client CSV file against the live DB). Caught 2,034 orphaned displayids (DB referenced them,
  CSV had no row) from a multi-run icon generator overwriting its own output file instead of
  appending. **Should be added as a formal lettered check (suggest "S") for any future session that
  does a multi-step/iterative partial regen** — run it as the LAST step before declaring any
  icon-generation work complete, not just after a full regen (where it was already established
  practice from earlier sessions' audits).
- All 3 required traces PASS (Praetorian 9448→Plate at his band with family name intact, следопыт
  8564→still Mail, Maginor Dumas 331 the 40+ staff caster→still Cloth). Tier-3 naming spot-checked
  extensively against real Russian grammar (see state.md for the specific examples) — no formal
  automated linguistic-correctness check exists for RU declension quality (inherently needs a
  native-speaker eyeball pass per the user's own request), but the "all-or-nothing per phrase,
  uncertain→generic" design means a WRONG declension can only ever look "too plain" (fell back to
  generic when it maybe could have been declined), never "grammatically broken" (a half-declined
  phrase) — this asymmetry was a deliberate design goal, not an accident.
- worldserver REBUILT (`.cpp`: `WD_PlateOverride` set + priority-ordered override in the armor-roll
  lambda, checked before `ResolveProgressionMaterial()`) — clean build, restarted, verified via the
  new 7-field boot log line (`... 1490 offhand-maps, 2094 plate-overrides, 200204 items.`).

## DONE 2026-07-02 (session 11: EMPTY-LOOK / INVISIBLE ARMOR FIX)
Full root-cause + mechanics writeup in state.md's "DONE 2026-07-02 (session 11...)" section.
Validation summary:
- **New check T added and run clean (0/179476, 0 unknown)** after the fix — see SQL/Python checks
  above for the exact query. Checked against the union of BOTH client CSVs (stock + custom).
- **A regressed to 1 mid-session** (a genuine new bug, not a false alarm) when the FIRST live apply
  picked a "Test Defense Chest"-style junk donor sharing a stock displayid with a real Mail item —
  fixed via the `\btest\b` word-boundary donor filter (see state.md Gotchas), re-applied, re-verified
  A=0.
- **A/B/C/D/E/F/K1/K2/O/R all reconfirmed 0** against the corrected live DB (179,476 armor +
  20,728 weapon = 200,204 total items, unchanged from session 10's total since this was a pure
  displayid substitution, no new/removed items).
- **Both S-pattern DB↔CSV orphan checks (custom ItemDisplayInfo id set, and full item entry set)
  reconfirmed 0/0 both directions** after removing the 27 fully-orphaned custom ItemDisplayInfo rows
  and updating 603 `Item_custom.csv` DisplayInfoID values.
- Verified the exact reported case (items 462730-33 → displayid 22033, a real Cloth robe) plus 4
  more spot-checks across Belt/Boots/Gloves/Tabard — all real, renderable, material-correct.
- Data/pipeline-only fix — worldserver RESTARTED (not rebuilt), clean boot, boot log line unchanged
  in shape from session 10 (`... 2094 plate-overrides, 200204 items.`).
- **MPQ rebuild needed**: yes (603 Item.dbc DisplayInfoID changes + 27 custom ItemDisplayInfo rows
  removed) — stated clearly to the user, bundled with any other pending rebuild.

## SUPERSEDED same day (2026-07-02, session 11 follow-up: REMOVAL instead of substitution)
User reversed the fix direction — see state.md's "SUPERSEDED same day" section for full rationale
and mechanics. Validation re-run after the reversal:
- A/B/C/D/E/F/K1/K2/O/R: all reconfirmed 0 against the post-removal DB.
- Both S-pattern DB↔CSV orphan checks (custom ItemDisplayInfo id set + full item entry set):
  reconfirmed 0/0 both directions after removing the same 603 rows from `Item_custom.csv`
  (`ItemDisplayInfo_custom.csv`'s 27-row removal from the substitution attempt already covered the
  icon side, untouched by the reversal).
- T: reconfirmed 0/0 — trivially true now (no empty-look items exist to violate it at all, vs. the
  substitution version where T was 0 because every affected item had been repointed to a *different*,
  non-empty, real displayid).
- **Final totals**: armor 178,873 (-603 from the pre-fix 179,476) + weapon 20,728 (unchanged) =
  **199,601 total items**, exactly matching the coordinator's predicted figure. Module boot log:
  `... 13264 displays, 2437 tabard-maps, ... 199601 items.` (`tabard-maps` -53 from session 10's
  2490, reflecting the 3 removed tabard (slot,look) groups; `displays` unchanged at 13264 since
  `WD_Display.size()` counts DISTINCT creature_display_id keys, not rows — see state.md Gotchas).
- Verified Alexandra Bolero's display 1497: chest row (slot=4) count=0 in `worn_drop_display`;
  belt(5)/legs(6)/boots(7) rows still present at material=1 Cloth. Items 462730-33 confirmed absent
  from `item_template` (count=0).
- worldserver restarted (data-only, no C++), clean boot, zero worn-drops errors.

## DONE 2026-07-02 (session 12: BALANCE PASS -- boss multiplier / lower trash chances / global float quality weights)
Pure C++/config change — none of the A-T SQL/Python checks apply (no DB row, no item, no displayid,
no name text changed). Full mechanics in state.md's "DONE 2026-07-02 (session 12...)" section.
What WAS verified: clean rebuild (0 errors), clean restart, boot log's NEW config-echo line matches
the PTR conf exactly (`chance=100.0% weaponChance=100.0% tabardChance=100.0% bossMultiplier=4.0x
quality(white/green/blue/epic)=90.0/7.0/2.7/0.3`), and the data-load line's item count (199601)
UNCHANGED from session 11's post-removal end state — confirms zero DB/data impact from this purely
C++/config session, exactly as expected. `git status`/`git diff --stat` on `.claude/dbc/*` showed no
additional delta beyond what session 11 had already staged — confirmed zero client CSV impact.
Not independently verified: actual in-game boss-kill behavior (no headless dungeon-boss spawn/kill
attempted this session — code-path review + config echo was the agreed-sufficient verification).

## DONE 2026-07-02 (session 13: ROBE-VOTE fix + FLAGS SANITIZATION)
Full mechanics in state.md's "DONE 2026-07-02 (session 13...)" section. Two independent bugs fixed
in one combined pass (worldserver restarted only ONCE at the very end, covering both):
- **ROBE-VOTE fix**: A/B/C/D/E/F/K1/K2/L/M/M-sentinel/O/R all reconfirmed 0. Both S-pattern DB↔CSV
  orphan checks 0/0 both directions (208925 in-range rows in both CSVs, exact match against the live
  DB — remember `.claude/dbc/Item_custom.csv`/`ItemDisplayInfo_custom.csv` are SHARED across
  unrelated systems, always filter to the 400000-1099999 sub-range before comparing counts). Check T
  0/0. Gandling (displays 11070/15732) verified fully Cloth-unified across all slots.
- **New check U (FLAGS SANITIZATION), NEW this session**: zero generated items with any of
  NO_PICKUP|CONJURED|HAS_LOOT|DEPRECATED|MULTI_LOOT_QUEST|MULTI_DROP set:
  ```sql
  SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 400000 AND 1099999
   AND (Flags & (0x1|0x2|0x4|0x10|0x100|0x800)) <> 0;   -- MUST be 0
  ```
  Confirmed 0 after the fix (was 5728 before: 5272 DEPRECATED-only, 344 MULTI_DROP-only, 104
  DEPRECATED+CONJURED, 8 DEPRECATED+MULTI_LOOT_QUEST). Merle's sword (entries 1010210-13) confirmed
  `Flags=0` post-fix. This check is ORTHOGONAL to A-T (none of them read the Flags column at all) —
  add it to the standard post-regen sweep going forward, same status as R (text-correctness) and T
  (renderability) — a structurally different validation category each time (class/subclass/material
  numeric checks vs. Flags/behavior checks vs. text-encoding checks vs. renderability checks all
  need their OWN dedicated query, none of them substitute for another).
- **worldserver**: TEMP WD-DEBUG image (coordinator's unrelated weapon investigation) was NOT
  rebuilt, NOT touched at the C++ level at all this session — both fixes are pure generator+SQL,
  finished with 2 plain `restart` calls. Final boot: `... 208925 items.` clean, zero errors.

## DONE 2026-07-05 (session 15: Karazhan bug report — pet-kill hook gap + armor `type==7` scope gap)
Full root-cause + mechanics writeup in state.md's "SESSION 15" section. Validation summary:
- **A/B/C/D/E/F/K1/K2/L/M/M-sentinel/O/Q/R/U all reconfirmed 0** against the new 217,217-item total
  (armor 196,489 + weapon 20,728, weapon side untouched/unaffected by this armor-only fix).
  `MAX(entry)` for armor = 893,923 (<1,000,000 ✓; **budget now 49,393/60,000 groups = 82.3%
  utilized — getting tight, flag for the NEXT scope-widening session to consider raising
  ARMOR_GROUP_CAP before it's exhausted**).
- **Both S-pattern DB<->CSV orphan checks (icon-id set AND full item-entry set) 0/0 both directions**
  — but S-icon was NOT 0/0 on the first pass (128 orphaned custom `ItemDisplayInfo_custom.csv` rows,
  minted-but-never-referenced — see state.md for why: the icon-minting step scans the FULL
  recomputed `worn_groups.tsv`, which is a strict superset of what this session's CONSERVATIVE
  "brand-new-display-only" item-generation step actually emits). Fixed by removing those 128 rows
  from both `ItemDisplayInfo_custom.csv` and `worn_iconmap.tsv` before merging; re-verified 0/0.
  **This is the FIRST time an S-violation came from the "CSV has an extra unused row" direction**
  (session 10's original S-incident was the opposite/more dangerous direction: DB referenced an id
  the CSV was missing entirely) — both directions matter, don't assume only one direction is
  possible for a given class of generator bug.
- **T (empty/unrenderable) and H (GroupSoundIndex) both 0** on the full post-merge CSV state.
- **New validation-process lesson this session (not a new lettered check, a methodology note)**: when
  widening a `work`/scope filter in `build-worn-slice.py`, diff the FRESH per-display material
  resolution against LIVE `worn_drop_display` BEFORE writing any apply SQL — a "GONE"/"changed_vote"
  row (a (display,slot) key whose material differs between live and a fresh from-scratch run) can
  indicate either (a) a genuinely pre-existing, unrelated discrepancy (harmless to ignore, don't fix
  opportunistically in an unrelated bug-fix session) or (b) a NEW regression the scope change itself
  introduced (the Mage-clamp vote-pollution case this session, which WAS worth fixing via the
  `[dnd]` stoplist entry) — either way, the safe default for a scope-WIDENING (not a full regen) is
  to **never insert/update a row for a `creature_display_id` that already has ANY live coverage**,
  making the whole class of vote-pollution risk structurally unreachable regardless of root cause.
- End-to-end traces: Phantom Guardsman (16425) + the other 4 Karazhan opera-event ghosts (Attendant/
  Valet/Guest/Stagehand, all 16 model variants) all confirmed with full per-slot `worn_drop_display`
  + `worn_drop_item` (band-70) coverage. Attumen's `worn_drop_weapon`/`worn_drop_item` rows
  reconfirmed UNCHANGED (armor-only fix, correctly no-ops for a creature with zero baked-armor
  evidence). `worn_drop_weapon` (12,411) and `worn_drop_offhand` (1,494) row counts UNCHANGED,
  confirming zero cross-contamination into the weapon/offhand paths.
- **worldserver REBUILT** (`.cpp`: new `OnPlayerCreatureKilledByPet` override, `HandleKill()`
  refactor) — clean build 0 errors, restarted, verified via boot log: `mod-worn-drops: loaded 13701
  scope, 14271 displays, 2562 tabard-maps, 10306 weapon-maps, 1490 offhand-maps, 2094
  plate-overrides, 217217 items.` clean, zero worn-drops errors after `World Initialized`.
- **Not independently verified in-game**: no headless pet-kill or Karazhan-instance kill was
  performed this session (PTR has no active Karazhan raid instance to test against) — verification
  was DB-state + boot-log + full validation-suite based, per this module's established "enough"
  bar for a data/config-level change (see session 12's precedent for the same standard).

## DONE 2026-07-08 (session 16: reliable boss list + guaranteed armor + boss quality [C++] +
## caster-staff/tie-break material fix [data] -- two independent tasks)
Full root-cause + mechanics writeup in state.md's "Session 16" section (also see the numbering note
there re: validation.md's pre-existing check V being an EARLIER, unrelated "session 16"). Validation
summary:
- **Task 1 (C++/config only, zero DB delta)**: new checks **W** (reliable boss set, 433 rows,
  Gandling/Malicia/both Barovs confirmed present, Merle confirmed absent). A/B/C/D/E/F/K1/K2/L/M/
  Msentinel/O/R/U all reconfirmed 0 immediately before AND after this task (a pure C++/config change
  cannot touch item data) — `total_items` unchanged at 217217 before task 2 started. Boot log
  confirmed `433 bosses` field + a correct config echo (`bossGuaranteeArmor=true
  bossQuality(white/green/blue/epic)=40.0/35.0/20.0/5.0`).
- **Task 2 (data regen)**: new checks **X** (tie-break diagnostic, 389/14180 evidenced displays hit
  a genuine top-vote tie, now correctly deferred to the no-evidence fallback instead of an arbitrary
  hash-order pick) and **Y** (process lesson: an incremental icon regen's own `cross_material_looks`
  bookkeeping is blind to a STALE, DB-only cross-material occurrence — caught 29 looks / 58 pairs via
  a REGRESSION in check A after the first apply, fixed via manual per-pair icon resolution + a scoped
  remap, re-verified A=0). **Final state, ALL reconfirmed 0**: A/B/C/D/E/F/K1/K2/L/M/Msentinel/O/R/U
  against the new 220,881-item total. MaxArmorEntry=903,083 (<1,000,000 [OK], budget now ~83.9%
  utilized — same capacity-watch flag as session 15, worth raising ARMOR_GROUP_CAP soon).
  MaxWeaponEntry unchanged 1,051,813 (weapons untouched all session).
- **Both S-pattern DB<->CSV orphan checks 0/0 both directions** after the full merge (icon-id set
  18027 DB / 18046 CSV with a pre-existing 19-row non-worn-drops gap accounted for; full item-entry
  set 220,881/220,881 exact match). T (empty/unrenderable) 0/200153. H (GroupSoundIndex) 0/453 new +
  0/58 collision-fix icons (4 of the 58 needed a manual GSI patch since no donor context existed for
  a stale off-TSV pair — see Y above).
- **End-to-end traces, all PASS**: Jandice Barov (10503) + her illusion (11439), display 11073 —
  ALL 6 armor slots resolve to real, renderable Cloth `item_template` rows at her true band 60
  (e.g. entry 851080 "Cloth Cowl" subclass=1, entry 901020 "Cloth Slippers" subclass=1 — one of the
  new appended entries). следопыт/Ranger (8564) — reconfirmed Mail(3) unaffected. Darkmaster Gandling
  (1853, display 11070) — reconfirmed Cloth(1) unaffected. Instructor Malicia (10505, display 20981)
  + Lady Illucia Barov (10502, display 11835) — reconfirmed Cloth(1) unaffected (both were ALSO
  robe-residue-caught pre-existing cases, correctly untouched by this session's tie-break fix since
  they were never tied to begin with). The requested staff/wand-caster archetype signal itself:
  calibrated and REJECTED (24.1%/n=290, well under the 85% bar) — 0 live displays resolve via that
  path (`0 fallback-CASTER` in the per-display resolution print), fully consistent with this file's
  established "don't apply a signal that doesn't clear the bar" discipline (same treatment as the
  earlier "pure ranged loadout" signal).
- **worldserver**: task 1 REBUILT (`.cpp` change), task 2 RESTARTED ONLY (pure data/SQL, zero C++)
  — final boot log: `mod-worn-drops: loaded 13701 scope, 14271 displays, 2562 tabard-maps, 10306
  weapon-maps, 1490 offhand-maps, 2094 plate-overrides, 433 bosses, 220881 items.` clean, zero
  worn-drops errors after `World Initialized`.
