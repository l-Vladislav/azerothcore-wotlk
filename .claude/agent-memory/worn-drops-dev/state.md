# mod-worn-drops — current state (2026-07-08, updated after SESSION 16: reliable boss list +
# guaranteed-armor + boss quality (C++) + caster-staff/tie-break material fix (data))

## Session 16 (2026-07-08): two independent tasks, both LIVE on PTR
### (Numbering note: validation.md's check V is ALSO labeled "session 16" but is dated 2026-07-06 —
### an earlier, unrelated loot-slot-cap diagnostic from a prior agent run that didn't get its number
### bumped in state.md at the time. Session numbers have drifted slightly out of sync between the two
### files; when in doubt, go by DATE, not by number. This session's own new validation checks below
### are added as W/X in validation.md to avoid re-colliding with V's number.)

### Task 1 — C++ ONLY, no data/SQL/MPQ change: reliable boss detection + guaranteed armor + boss quality
User report: Darkmaster Gandling (1853) dropped at the normal 15% armor chance instead of the
boosted boss rate — `killed->IsDungeonBoss() || killed->isWorldBoss()` returned FALSE for him despite
being a real dungeon boss. **Root cause confirmed via code read**:
`ObjectMgr::LoadInstanceEncounters()` (`src/server/game/Globals/ObjectMgr.cpp`) only OR's
`CREATURE_FLAG_EXTRA_DUNGEON_BOSS` into a creature's in-memory `CreatureTemplate` for
`instance_encounters` rows whose `entry` (a DungeonEncounter ID, NOT the creature id) resolves in
the client's `DungeonEncounter.dbc` (`sDungeonEncounterStore.LookupEntry(entry)`) — a
custom/non-DBC-backed encounter row silently skips the WHOLE row (including the flag-set), with only
a log line, invisible to this module. Confirmed live: Gandling's `creature_template` row has
`rank=1, type_flags=0, flags_extra=0` (both old predicates correctly evaluate false) YET he IS
present in `instance_encounters` with `creditType=0` — this ObjectMgr code path is simply not
reaching him. **Not fixed in ObjectMgr.cpp** (out of scope, a core-behavior change with wider blast
radius) — worked around entirely inside mod-worn-drops instead.
- **New `WD_Boss` set** (`std::unordered_set<uint32>`, creature_entry), loaded in `LoadData()` via
  `SELECT DISTINCT creditEntry FROM instance_encounters WHERE creditType = 0` (creditType=0 ==
  `ENCOUNTER_CREDIT_KILL_CREATURE`, `Map.h`'s `EncounterCreditType` enum), guarded by
  `TableExists("instance_encounters")` (defensive, same pattern as `worn_drop_offhand`/
  `plate_override`). **433 rows live** — verified to contain Gandling 1853, Instructor Malicia
  10505, both Barovs 10502/10503; verified Private Merle 1421 is CORRECTLY absent (stays at the
  normal 15% chance). Boot log line gained an `{} bosses` field (now 8 fields total):
  `mod-worn-drops: loaded 13701 scope, 14271 displays, 2562 tabard-maps, 10306 weapon-maps, 1490
  offhand-maps, 2094 plate-overrides, 433 bosses, 220881 items.`
- **`isBoss = WD_Boss.count(entry) || killed->IsDungeonBoss() || killed->isWorldBoss()`** — WD_Boss is
  the reliable primary source, the two Creature predicates stay as an OR-backup (isWorldBoss() still
  matters for open-world bosses that may not be in `instance_encounters` at all).
- **Guaranteed armor on boss** (user: "только броня"): new config `WornDrops.BossGuaranteeArmor`
  (bool, C++ default **true**). When `isBoss && WD_BossGuaranteeArmor`, the ARMOR roll's
  `effChance` is forced to **100%** instead of `min(100, WD_Chance*mult)`. Weapon/tabard rolls are
  explicitly NOT forced — they keep the pre-existing `WD_BossMultiplier` (x4) behavior. Offhand
  (shield/held) rides the SAME gate as armor (`(inArmor||inOffhand) && effChance...`), so it is ALSO
  effectively guaranteed on a boss — a deliberate, documented interpretation (offhand is
  "armor-class" per this module's existing design, shares the same roll+quality mechanism).
- **Boss-only quality weights** (user: bosses should reward better gear): new
  `WD_BossQWeight[4]` array + config keys `WornDrops.Boss.Quality.White/Green/Blue/Epic`, C++
  defaults **40/35/20/5** (vs the normal 90/7/2.7/0.3). `RollQuality(bool isBoss)` now takes an
  `isBoss` flag and picks `WD_BossQWeight` instead of `WD_QWeight` when true; `AddWornItem(...,
  uint8 forcedQuality=0, bool isBoss=false)` threads it through. Applied to the ARMOR roll, the
  OFFHAND roll (same rationale as the guarantee above), AND the WEAPON roll (per the ask: "armor
  AND weapon quality rolls use WD_BossQWeight"). Tabard is untouched (`forcedQuality=1`, single
  quality, `RollQuality()` never called for it regardless of `isBoss`).
- **Code-path trace for Gandling (1853)** (no headless kill performed — code review + boot-log +
  DB query verification, per this module's established "enough" bar for a data/config-level change):
  (a) `WD_Boss.count(1853)==1` (confirmed via `SELECT` against `instance_encounters`) → `isBoss=true`
  regardless of the two old predicates; (b) `WD_BossGuaranteeArmor(true) && isBoss(true)` →
  `effChance=100.0f`, `roll_chance_f(100.0f)` always succeeds; (c) the armor-roll lambda calls
  `AddWornItem(..., epic, 0, isBoss=true)` → `RollQuality(true)` uses `WD_BossQWeight`
  {40,35,20,5} instead of {90,7,2.7,0.3}. **Negative check**: Private Merle (1421) has
  `WD_Boss.count(1421)==0` (confirmed absent from `instance_encounters`) and `rank=type_flags=
  flags_extra=0` → `isBoss=false` → unaffected, stays at the normal 15%/prod-conf chance.
- **Files changed**: `modules/mod-worn-drops/src/mod_worn_drops.cpp` (WD_Boss set, LoadData boss
  query+log field, WD_BossGuaranteeArmor/WD_BossQWeight fields+config reads+config echo,
  RollQuality(bool)/AddWornItem(...,bool isBoss) signature changes, isBoss computation + effChance
  guard in HandleKill, isBoss threaded through armor/offhand/weapon AddWornItem calls),
  `modules/mod-worn-drops/conf/mod-worn-drops.conf.dist` (documented new keys + prod defaults),
  `env/dist/etc-ptr/modules/mod-worn-drops.conf` (same new keys appended, PROD values — **existing
  drop-all TEST values (Chance/WeaponChance/TabardChance=100, ArmorPerKill/WeaponPerKill=0,
  LevelDiffMax=0) were LEFT UNTOUCHED**, confirmed post-edit; on PTR the guarantee is a no-op since
  armor is already 100%, boss quality (40/35/20/5) still applies and is harmless for PTR testing).
- **PTR rebuilt** (`docker compose --profile ptr build ac-worldserver-ptr && up -d`) — clean build,
  clean boot, config echo + boss count verified in logs (see above). **LIVE PROMOTION = image
  rebuild + restart ONLY — zero SQL, zero MPQ delta** for this task (C++/config only). The C++
  DEFAULTS already equal the intended prod values (chance 15/5/5, ArmorPerKill=1,
  BossGuaranteeArmor=true, boss quality 40/35/20/5) so live behaves correctly even before its own
  `.conf` is updated with the 2 new key blocks.

### Task 2 — DATA regen: caster-staff material fix (Jandice Barov) + a bigger, related bug found in the process
User report: Jandice Barov (10503) + her illusion (11439), display 11073, wields a STAFF but
resolved to material sentinel 6 (Warrior-Paladin progression → Plate at her band 60). Coordinator's
initial ask was a calibrated "staff/wand main-weapon → Cloth" NO-EVIDENCE-fallback rule (symmetric
to the existing hunter-token/loadout signals). **Investigation found the initial diagnosis was
WRONG in an important way, and led to a different (and more broadly impactful) fix:**
1. **The requested staff/wand-caster signal was CALIBRATED AND REJECTED** (same >=85%-agreement/
   >=5-sample bar this file uses everywhere): `caster:staff_or_wand`=24.1%/n=290 (no-robe evidenced
   displays), `caster:staff_only`=23.4%/n=277, `caster:wand_only`=75.0%/**n=4** (fails the sample
   floor). Excluding melee-mainhand+shield/2H-melee/hunter-name conflicts barely moved the numbers
   (24.6%/n=284) — the signal is NOT noise-from-conflicts, it's INHERENTLY weak: a material
   breakdown of the raw population showed staff/wand-wielding non-robe evidenced displays split
   **Leather 159 (troll/tribal shadow-hunter/witch-doctor archetype) / Cloth 70 / Mail 56
   (shaman-type) / Plate 5** — staves are a PAN-ARCHETYPE prop in this dataset (canonically used by
   Leather trolls and Mail shamans just as much as Cloth casters), not a reliable Cloth signal at
   all. **Implemented but disabled** (`caster_loadout_validated=False` on the live dataset) — same
   convention as the pre-existing rejected "pure ranged loadout" signal; kept in code (2 new helper
   fns `has_caster_main_weapon`/`has_melee_mainhand_shield`/`has_2h_melee` +
   `CASTER_WEAPON_SUB={10,19}`/`ONEH_MELEE_SUB`/`TWOH_MELEE_SUB` constants + a full calibration
   block in `build-worn-slice.py`) for a future re-calibration if the token/weapon-set choice ever
   changes — 0 live displays currently resolve via this path (`0 fallback-CASTER` in the per-display
   resolution print).
2. **Jandice's ACTUAL display (11073) is NOT a no-evidence display at all** — direct investigation
   (`display_pairs`/`evidence_of` dump) found she has REAL ART evidence on 3 slots: Belt(19178)=
   Plate(art,3pts), Legs(20405)=Cloth(art,3pts), Gloves(10387)=Leather(art,3pts) — a **genuine 3-way
   TIE** in the weighted vote (`vote.most_common(1)[0][0]` on a `Counter` with 3 equal-max keys).
   Her equipped weapon (item 12866) is ALSO subclass=**14 (Misc)**, not Staff(10) — so even the
   requested rule (had it been validated) would never have fired for her specific case; the "staff
   in her hand" the user describes is a Misc-subclass prop, invisible to the CASTER_WEAPON_SUB={10,19}
   check entirely.
3. **REAL ROOT CAUSE (new finding, bigger than Jandice alone): `display_vote_material()`'s tie-break
   was an IMPLEMENTATION ACCIDENT, not a policy.** `vote.most_common(1)[0][0]` silently picks
   whichever material happens to be first in Python's `Counter`/`set` iteration order when 2+
   materials share the exact max weighted score — confirmed via direct measurement: **389/14180
   evidenced displays (2.7%)** hit an exact tie system-wide (a pre-existing bug present since
   session 9's material-vote design, never previously noticed because it silently "resolved" to
   SOME material and never showed up as a coverage gap in checks M/M-sentinel). **Fixed**:
   `display_vote_material()` now returns `None` (same as "no evidence at all") when the top-weighted
   score is tied among >=2 materials, deferring the display to the SAME no-evidence fallback chain
   (`archetype_material()`: robe-residue → hunter-token → [rejected caster-weapon] → Rogue/Caster
   flat → Warrior/Paladin default) used for genuinely-no-evidence displays — **zero new heuristics
   needed**, this is how Jandice actually gets fixed: her Shoulder look (4925) IS robe-flagged (but
   shoulder is deliberately excluded from `ROBE_VOTE_SLOTS={1,4,6}` as a VOTE contributor, per a
   session-2 design decision), and `archetype_material()`'s OWN robe-residue check scans ALL slots
   (not just `ROBE_VOTE_SLOTS`) — so her display resolves to Cloth via the PRE-EXISTING robe rule,
   once the tie stops masking it. **A tempting alternative — extending `ROBE_VOTE_SLOTS` to include
   shoulder as a first-class VOTE contributor — was calibrated and REJECTED**: only 78.1% agreement
   (n=465) on the CURRENT (post session-15 scope-widening) dataset, below the bar — a state.md note
   from session 2 claiming 95.8%/n=260 for this exact same idea is now STALE (the population shifted
   materially since the session-15 `type==7` removal added ~1000 new creatures); always re-derive a
   calibration number against the CURRENT dataset before trusting an old written percentage.
4. **Result: 315 displays flip material** (1389 (creature_display_id,slot) rows in
   `worn_drop_display`), breaking down as (old_material → new_resolution): `Leather(2)→sentinel6`
   636, `Cloth(1)→sentinel6` 397, `Mail(3)→sentinel6` 200 (i.e. most ties fall through ALL THE WAY
   to the Warrior/Paladin DEFAULT once robe/hunter don't apply — expected, that IS the design's
   catch-all), `Leather(2)→sentinel5(Hunter)` 43, `Mail(3)→Cloth(1)` 40, `Leather(2)→Cloth(1)` 44,
   `sentinel6→Cloth(1)` 23 (robe-caught), `Mail(3)→sentinel5` 6. **New diagnostic print** in
   `build-worn-slice.py`: "Tie-break diagnostic: N displays had a genuine top-vote TIE... deferred to
   the no-evidence fallback" (N=389 on this run). Per-display resolution print gained a
   `fallback-CASTER` field (0 live, see point 1) and an explicit tie count is now visible pre-fallback.
5. **Deploy shape (PURE-APPEND, session-10-style — NEVER a full gen-worn.py regen)**: a full
   `gen-worn.py` run does `DELETE FROM item_template WHERE entry BETWEEN 400000 AND 1099999` +
   fresh sequential re-numbering of the ENTIRE sorted `groups` set — since `groups` is a SET of
   4-tuples sorted for `bi` assignment, ANY net change to the group set shifts the enumeration index
   of every group after the first change point, which would renumber almost the WHOLE existing
   180k+-item block (breaking any player's already-looted/equipped item references). **Never do a
   full regen for a material-correction fix** — always compute the MINIMAL new-groups delta and
   append at the live high-water mark, exactly like session 10's plate-override.
   - Computed the delta TWICE: a naive "fresh worn_groups.tsv vs whole live worn_drop_item" diff
     produced a misleadingly large 1034-row delta contaminated by ~6400 UNRELATED stale groups from
     ordinary session-to-session LEVEL DRIFT (creature levels changing in the live DB since session
     15, an orthogonal and expected source of churn per session 9's `load_live_levels()` policy) —
     discarded. **Correct approach**: restrict the group computation to ONLY the 315 displays whose
     `display_vote_material()` output actually changed (comparing fresh vs. the live
     `worn_drop_display` snapshot), using EACH such display's own current wearer levels (still a
     legitimate/correct use of live level data, just properly SCOPED to the touched displays only,
     not the whole 13537-creature population) — yielded **1308 scoped groups, of which 916 were
     genuinely new** (not already covered by an existing `worn_drop_item` row from some other
     creature/band sharing the same look+material). New groups by material: Plate 443 / Mail 425 /
     Cloth 48 (Plate/Mail dominate because most ties fell through to the Warrior/Paladin
     band-progression default, as noted in point 4).
   - **3664 new `item_template` rows** (916 groups x4 quality), entries **893930-903083** (bi
     49393-50308, started at live-max-entry-893923's next free bi, NEVER hardcoded), + 2748
     `item_upgrade_chain` rows, generated by literally REUSING `gen-worn.py`'s real `emit_group()`/
     `base_for()`/`armor_look_family` (built fresh from the regenerated, now-correct
     `creature_worn.tsv`) via the established "exec the script's source up to a safe marker, discard
     its `out`/`item_map` state, drive `emit_group()` directly for just the new groups" technique
     (same technique family as session 10's plate-override and this whole pipeline's read-only
     reuse pattern) — this guarantees byte-for-byte naming/stat/flags/bonding consistency with a
     real full regen, without touching a single existing row.
   - `worn_drop_item`: 3664 new rows appended. `worn_drop_display.material_id`: 1389 rows UPDATEd
     in place (NOT re-inserted — same PK, only the material_id column changes) for the 315 affected
     displays.
   - **A REAL regression caught by check A after the first apply (29 icon/material violations,
     NOT a false alarm)**: fixing material for a look at a NEW material can make that look
     CROSS-MATERIAL system-wide for the first time, even though `gen-worn-icons.py`'s icon-tier
     resolver (re-run fresh against the CURRENT `worn_groups.tsv`) did NOT flag these 58
     `(look,material)` pairs, because the look's OTHER (pre-existing, now-stale) material usage no
     longer appears in the FRESH `worn_groups.tsv` at all (it's one of the ~6648 "stale" groups from
     ordinary level drift, still LIVE in the DB from an earlier session, but not reproduced by a
     from-scratch regen today) — `cross_material_looks` is computed ONLY from the fresh TSV, so it
     is BLIND to a live-DB-only stale occurrence. Concretely: e.g. displayid 1980 has LIVE entries at
     subclass=1 (old, entries 731450-53, pre-existing, using the RAW stock displayid — was legitimately
     single-material and icon-fine when originally generated) AND subclass=3 (new, entries
     901300-03, my fix, ALSO using the raw stock displayid since gen-worn-icons.py's fresh view
     thought 1980 was still single-material at 3 only). **Caught via the standard post-apply re-run
     of check A** (this is EXACTLY the kind of thing A exists to catch) — **fixed** by manually
     resolving custom icons for these 29 looks x 2 materials = 58 pairs (tiers 2/3/5 only — tier 4
     "donor icon" was skipped since no reliable donor-entry context exists for a look's STALE,
     off-TSV material side; a minor, documented, low-risk simplification, degrading at worst to the
     generic GEN fallback icon, never a PRIME DIRECTIVE violation), minting **58 more custom
     ItemDisplayInfo ids (128124-128181)**, and re-pointing ALL matching `item_template` rows (BOTH
     the old pre-existing entries AND my newly-inserted ones) via a `(look,material)`-scoped remap
     UPDATE, same pattern as `worn_displayid_remap.sql`. Re-verified check A = 0 after.
     **LESSON for any future incremental icon fix**: `cross_material_looks`/`chosen` computed from
     ONLY a fresh regen's TSV can miss a look that's cross-material ONLY because of a STALE
     (DB-only, no-longer-regenerated) occurrence at a different material — always re-run check A
     against the LIVE DB as the actual ground truth after ANY incremental material-changing apply,
     never trust "the fresh icon resolver's own cross-material set" alone for an incremental/partial
     regen (only safe for a genuine FULL regen where the TSV IS the complete ground truth).
   - **Total new custom ItemDisplayInfo ids this session: 511** (453 for the 916 new groups'
     genuinely-new `(look,material)` pairs, ids 127671-128123, tiers real_item=2/donor=422/
     model_match=27/generic=2; + 58 for the cross-material-collision fix above, ids 128124-128181,
     tiers real_item=8/model_match=3/generic=47 — mostly generic since tier-4 was skipped for these).
     4 of the 58 collision-fix rows had `GroupSoundIndex=0` from the stock look's own row (no donor
     to borrow from) — patched to a known-good non-zero value before merging (validation H
     requirement). `worn_iconmap.tsv`: 17516→18027 rows (append-only). `.claude/dbc/Item_custom.csv`:
     227586→231250 rows (3664 appended for the new items + **120 EXISTING rows UPDATED in place**
     for the old-range collision entries whose `displayid` changed — NOT a pure append this time,
     the FIRST time this module's Item_custom.csv merge needed an update-not-just-append path).
     `.claude/dbc/ItemDisplayInfo_custom.csv`: 17535→18046 rows (511 appended).
   - **Both S-pattern DB<->CSV orphan checks 0/0 both directions** (icon-id set: 18027 DB / 18046 CSV
     with the 19-row gap being pre-existing non-worn-drops customs, confirmed 0 missing/0 orphaned
     after accounting for that; full item-entry set: 220881/220881 exact match). T (empty/
     unrenderable) 0/0 on the full 200153-row armor scan. H (GroupSoundIndex) 0/453 AND 0/58 (both
     new-icon batches). A/B/C/D/E/F/K1/K2/L/M/Msentinel/O/R/U all reconfirmed 0 on the final
     220,881-item state. MaxArmorEntry=903083 (<1,000,000 [OK]; **budget now ~50,309/60,000 groups =
     83.9% utilized — getting tight, same flag as session 15, worth raising ARMOR_GROUP_CAP in the
     NEXT scope-widening session**). MaxWeaponEntry unchanged 1,051,813 (weapons untouched by this
     entire session).
   - **worldserver RESTARTED ONLY** (data/SQL-only fix, zero C++ touched in this task) — clean boot,
     `220881 items` in the boot log, zero worn-drops errors. Boss count (433) and config echo
     unaffected/unchanged, confirming task 1 and task 2 are cleanly independent.
   - **Live promotion for this task = SQL apply (utf8mb4) + MPQ rebuild (511 new
     ItemDisplayInfo rows + 3664 new Item.dbc rows + 120 UPDATED Item.dbc rows) + worldserver
     restart** (no C++ rebuild needed for this task specifically, though task 1's rebuilt image
     should obviously be used for the same deploy).

### Combined session-16 "what the coordinator promotes to live" summary
1. **Image rebuild** (task 1's C++ change: WD_Boss/BossGuaranteeArmor/BossQWeight) +
   `env/dist/etc/modules/mod-worn-drops.conf` needs the 2 new key blocks added (BossGuaranteeArmor=1,
   Boss.Quality.White/Green/Blue/Epic=40/35/20/5) — though the C++ DEFAULTS already match, so this
   is a belt-and-suspenders correctness step, not a hard requirement for correct live behavior.
2. **SQL delta** (task 2): the combined apply = `caster_fix_items.sql` (3664 item_template INSERTs +
   locale) + `caster_fix_chain.sql` (2748 item_upgrade_chain INSERTs) + `caster_fix_maps.sql` (3664
   worn_drop_item INSERTs + 1389 worn_drop_display UPDATEs) + `collision_fix_remap.sql` (58
   displayid-remap UPDATEs) — apply in that exact order, `--default-character-set=utf8mb4`,
   `SET autocommit=0; ...; COMMIT;` wrapper. Scratchpad copies were used this session (not committed
   anywhere persistent) — **if re-deriving for live, re-run the full computation chain documented
   above against the live `acore_world` DB's own current state, do NOT blindly replay the PTR SQL
   files verbatim** (entry numbers/high-water-marks will differ between acore_world_ptr and
   acore_world).
3. **MPQ delta** (task 2 only): 511 new ItemDisplayInfo rows + 3664 new + 120 UPDATED Item.dbc rows,
   merged into `.claude/dbc/ItemDisplayInfo_custom.csv` / `.claude/dbc/Item_custom.csv` already (PTR
   client-side artifact prep) — needs ONE MPQ rebuild + Cache/WDB clear covering both.
4. **Config**: PTR conf (`env/dist/etc-ptr/modules/mod-worn-drops.conf`) intentionally UNCHANGED in
   its drop-all TEST shape (Chance/WeaponChance/TabardChance=100, ArmorPerKill/WeaponPerKill=0,
   LevelDiffMax=0) — only the 2 new boss key blocks were appended, confirmed post-edit. Do NOT copy
   the PTR conf's values to live.

# mod-worn-drops — earlier state (2026-07-02, updated after WEAPON-MISC(14) NOUN FIX -- session 11)

## Session 11 addendum: weapon subclass=14 (Misc) generic "Оружие"/"Weapon" naming fixed
Same class of bug as session 10's held-in-offhand fix, this time for class=2/subclass=14 weapons:
subclass 14 is a generic catch-all covering WILDLY different visual props (bottles, brooms,
tankards, fish, books, orbs, scepters, a mining pick, a lance...) that donors (a tiny pool of 4
generic subclass-14 stat templates, unrelated to the visual model) give zero naming signal for.
**2,036 items (74 distinct looks) were named "Оружие"/"Weapon"** — fixed via a per-LOOK
`WEAPON_MISC_NOUN` override dict in `gen-worn.py` (permanent fix for future full regens) +
retroactive text-only UPDATE against the live DB (74 looks audited: real item_template name parsing
first — "Monster - Item, <Type> - <variant>" convention, e.g. displayid 7445 "Monster - Item,
Bottle - Black" → Bottle/«Бутыль» — donor's OWN name is NEVER used, only the LOOK's; then
ModelName_1 prefix fallback for pure "NPC Equip NNNNN" placeholders with no real name at all, e.g.
`Misc_2H_Broom_A_01.mdx`→Broom/«Метла», `polearm_2h_lance_a_01.mdx`→Lance/«Пика»; real-item-join
tie-break preferring thematic consistency with sibling looks over a coincidental unrelated
crossover, e.g. displayid 23323 keeps "Tome" from its Monster-Item-Book siblings 23321/23322 over
the coincidentally-shared real item "Jade Bracers"). **73/74 looks mapped (2,028 items renamed);
1 look (displayid 48403, `Offhand_OutlandRaid_D_01.mdx`, zero real-item/model signal) stays
generic — 8 items**. Also audited full WBASE coverage while in there: subclass 17 (Spear) was
MISSING from the dict (added, `17:("Копье","Spear")` — 0 live items currently use it, pure
future-proofing); 9/11/12 are genuinely-obsolete WotLK subclass ids, correctly absent; every other
subclass (0,1,2,3,4,5,6,7,8,10,13,15,16,18,19,20) already had a proper entry. subclass is
INTENTIONALLY unchanged at 14 for all of these (out of scope per the ask — functional weapons with
correct dmg via the donor, name-only fix, no schema churn), even for displayid 59115 which visually
IS a lance/polearm model.
**Zero client CSV delta** — confirmed and reported: Item.dbc carries no name field at all (names
come from the server's `item_template.name` via the `ITEM_QUERY` opcode response, not from any
client DBC), so this is a pure server-side text change, no MPQ impact whatsoever, unlike sessions
9-10's material/icon work. Applied directly to the live DB (`--default-character-set=utf8mb4`,
mandatory per the session-9 post-mortem rule) + a plain `docker compose restart` (data-only change,
no C++, no rebuild needed) — verified via a fresh boot log with unchanged counts and zero errors.
Check N and R both re-ran and confirmed 0 after the apply. Full noun-count breakdown and samples in
the delivered report; not re-duplicated here — see git/session history if this needs re-deriving.

# mod-worn-drops — current state (2026-07-02, updated after PLATE-OVERRIDE + TIER-3 NAMING + HELD-NOUN -- session 10)

## Live on PTR
- **200,204 items** on `acore_world_ptr` (session 9: 187,288 → session 10: +12,916 plate-override items): armor 179,476 + weapons 20,728. Module loaded cleanly: `mod-worn-drops: loaded 12878 scope, 13264 displays, 2490 tabard-maps, 10306 weapon-maps, 1490 offhand-maps, 2094 plate-overrides, 200204 items.` (`plate-overrides` field added session 10, log line now 7 fields).
- **ID ranges** (session 9): armor 400000-999999 (60000 groups; session 10 pushed usage to 44935/60000 = 74.9%), weapons 1000000-1099999 (unaffected by session 10, still 5182/10000 = 51.8%). Live max armor entry now 849853 (<1,000,000 ✓), max weapon entry unchanged 1,051,813.
- **PLATE-OVERRIDE (session 10, user decision from the Scarlet Praetorian 9448 verdict)**: a creature with a 2H melee weapon OR a 1H melee weapon+shield in its equip pool, at band>=40, not Mage, ALWAYS drops Plate for its ENTIRE armor set, overriding the display's own art-vote material. PER-CREATURE (new `worn_drop_scope.plate_override` column, idempotent-migrated), applied at kill time by `mod_worn_drops.cpp`'s new `WD_PlateOverride` set (unconditional matkey=4 override, checked BEFORE the progression-sentinel resolution, only when band>=40). **2,094 qualifying creatures**; **3,229 NEW (slot,look,band) Plate groups** generated as a PURE-APPEND partial regen (12,916 new item_template rows, entries 817570-849853, zero existing rows touched/renumbered).
- **TIER-3 POSSESSIVE NAMING (session 10, user decision)**: new naming tier between family (tier1/2) and generic — a look with a single deduped-by-name wearer (passing a "generic profession word" gate reusing `FAMILY_STOP`) gets `"<Wearer>'s <noun>"` EN / `"<noun> <Wearer RU genitive>"` RU, via a conservative all-or-nothing per-word RU declension engine (falls back to generic on ANY uncertain word). **3,151 armor looks + 15 held looks eligible; 14,196 existing items retroactively renamed** via a safe text-only UPDATE (no class/subclass/material/displayid touched).
- **HELD-IN-OFFHAND MODEL-DERIVED NOUNS (session 10, user decision)**: the generic «Талисман»/"Talisman" base noun is now derived from the look's actual `ModelName_1` (potion→Flask/«Флакон», book→Tome/«Фолиант», torch→Torch/«Факел», etc.) for **59/62 looks (95%)** — the remaining 3 (2 distinct model names, `offhand_pvehorde/pvealliance`) have no confident real-item cross-reference and stay generic. Folded into the same retroactive naming UPDATE as tier-3.
- Server displayids: custom ItemDisplayInfo **110000-126135 (16,136 ids, up from 14,067)** — 2,069 new ids from the plate-override's icon needs (**a live bug was found+fixed mid-session: a 2-run icon-generation process overwrote its own output file, losing 2,034 icon row definitions that WERE already referenced by item_template.displayid — caught via a DB↔CSV cross-consistency audit, recovered via a dedicated re-resolution script, see Gotchas**). Client CSVs: `.claude/dbc/Item_custom.csv` (132 + 200,204 = 200,336) and `.claude/dbc/ItemDisplayInfo_custom.csv` (16 + 16,136 = 16,152). **User needs ONE MORE MPQ rebuild + Cache/WDB clear** covering session 10's new plate-override items/icons + the naming retrofit (naming is text-only, no MPQ impact by itself, but ships in the same delta window as the icon change).
- Material distribution (session 9 baseline unaffected by session 10 except for the +12,916 new Plate items, which come from OTHER materials' bands via the override, not from regenerating the base material vote): see session 9 entry below for the full Cloth/Leather/Mail/Plate baseline.
- Fixes done+verified through session 9 (material spec, scope widening, ID range fix, weapon PK fix) — see below sections, all still live and unaffected by session 10 except where explicitly noted.

## DONE 2026-07-02 (session 10: PLATE-OVERRIDE + TIER-3 NAMING + HELD-NOUN — 3 features, 1 bundle)

### 1. Plate-override rule (`modules/mod-worn-drops/scripts/gen-worn-plate-override.py`, NEW script)
User decision triggered by "Scarlet Praetorian 9448 should be Plate" (his display's art-vote said
Mail, but he personally wields a sword+shield — the coordinator generalized this into a rule rather
than special-casing one creature): **level 40+ AND (2H melee weapon OR 1H melee weapon + shield in
the equip pool) → armor set is ALWAYS Plate**, overriding the art vote. Mage clamp stays above this
rule; below band 40 the universal no-plate-below-40 cap still wins (qualifying-but-<40 creatures
keep their normal resolution).
- **Qualification**: `TWOH_MELEE_SUB={1,5,6,8}` (Axe2H/Mace2H/Polearm/Sword2H, explicitly NOT
  staff(10)/fishing pole(20)); `ONEH_MELEE_SUB={0,4,7,13,15}` (Axe1H/Mace1H/Sword1H/Fist/Dagger);
  shield = class4/subclass6/InventoryType14. Checked across ALL creature_equip_template SETS
  (inventory-pool model, same as session 9's weapon fix) using the LIVE DB (not base SQL — same
  lesson as the Argent Sentry level-drift bug, equip/level data must be live). unit_class==8 (Mage)
  excluded outright. **2,094 qualifying creatures** (out of 12,612 armored).
- **Architecture (PER-CREATURE flag over PER-DISPLAY material)**: material lives per-display
  (shared across creatures), but equip+level are creature properties — a display CAN be shared by a
  qualifying and a non-qualifying creature. New `worn_drop_scope.plate_override` column (idempotent
  PREPARE/EXECUTE migration, same pattern as every prior schema change this arc), read into a new
  C++ `std::unordered_set<uint32> WD_PlateOverride` (creature_entry set). Applied in the armor-roll
  lambda: `if (band >= 40 && WD_PlateOverride.count(entry)) matkey = WD_MAT_PLATE;` — checked BEFORE
  `ResolveProgressionMaterial()`, so it takes unconditional priority over sentinel resolution too.
- **PURE-APPEND partial regen** (explicitly NOT a full regen — a full regen's sorted-group bi
  assignment would renumber ALL 187,288 existing entries just to insert a few thousand new groups
  in the middle of the sort order): computed the 6,893 (slot,look,band>=40) triples touched by
  qualifying creatures, checked which already have a Plate(4) `worn_drop_item` row (3,664 already
  did, e.g. genuinely-Plate-art-voted looks), leaving **3,229 NEW groups** needed. New entries start
  at `bi=41757` (the live high-water mark + 1, computed fresh via `MAX(entry)`, never hardcoded) →
  entries 817570-849853 (well inside the 60,000-group armor budget, 74.9% utilized after this).
  **12,916 new item_template rows** (3,229 groups × 4 qualities). Donor selection reuses
  build-worn-slice.py's exact pattern (Plate-subclass donors per InventoryType; falls back to "any
  subclass, same slot" for capes, which have ZERO real Plate donor at all — confirmed 0 stock
  Plate-subclass cloaks exist, same pre-existing limitation as the main pipeline; the generated
  item's subclass is FORCED to 4 regardless of the fallback donor's own subclass, via the same
  `ov["subclass"]=4` override pattern used everywhere else in this pipeline — 51/3229 groups needed
  this fallback, all capes). Naming reuses gen-worn.py's `armor_look_family` + this session's new
  tier-3 dict, so plate-override items correctly inherit curated family names where applicable
  (verified: Praetorian 9448's new items say "Scarlet Plate Helm"/«Латный шлем Алого ордена» etc).
- **Icon resolution**: reused gen-worn-icons.py's exact tier chain (real_item > model_match > donor
  > generic), executed read-only via the same "exec up to before the main loop" technique used
  elsewhere this session for safe code reuse. **2,069 new (look,4) icon pairs needed** (many fewer
  than 3,229 groups, since most looks already had a Plate icon from a DIFFERENT band's normal
  art-vote resolution — e.g. a look Plate at band 60 via art-vote already has a (look,4) icon, so a
  qualifying creature needing THAT SAME look at band 45 reuses it, no new icon needed).

### 2. Tier-3 possessive naming (`gen-worn.py`'s existing family infra, reused; retroactive UPDATE applied live)
New tier: **curated family (1) > auto-derived family (2) > single-wearer possessive (3) > generic**.
For a look NOT claimed by tier1/2, if its (deduped-by-NAME) wearer set is EXACTLY 1 distinct
creature name: EN = `"<Name>'s <base noun>"`, RU = `"<base noun> <Name RU genitive>"`.
- **Generic-word gate**: reuses `FAMILY_STOP` (the existing family-token stoplist) via
  `_family_token(name) is not None` — a bare profession word like "Ranger" (entry 8564) correctly
  fails the gate (no distinctive token), while "Ranger Lord Hawkspear" passes (token="Hawkspear").
  Also caught 2 "TEST GEAR PALADIN"/"TEST GEAR WARRIOR" dev/test NPCs as a side effect (every token
  happened to be stoplisted) — a nice bonus, not the primary purpose.
- **Comma-name handling**: "Korfax, Champion of the Light" → only "Korfax" (before the comma) is
  used as the possessor, for BOTH EN and RU (RU: "Корфакс, Воитель Света" → "Корфакс"). A no-comma
  title+name pattern ("Командир рыцарей Валделмар") is NOT special-cased — it goes through the
  full-phrase declension engine below and typically FAILS (falls back to generic) because a middle
  word like "рыцарей" (already-genitive-plural, not a nominative the engine can re-decline) doesn't
  match any confident rule — this is CORRECT/intended per "any doubt → generic", not a bug.
- **RU declension engine** (conservative, ALL-OR-NOTHING per multi-word phrase — ANY uncertain word
  aborts the WHOLE phrase, falls back to generic): consonant ending → +а; -й→-я; -ь(masc, via a
  curated override list of known masc -ь nouns PLUS a blanket rule for -тель agentive nouns)→-я;
  -а→-ы (or -и after г/к/х/ж/ч/ш/щ); -я→-и; adjective endings -ый/-ой→-ого, -ая→-ой, -ий→-его,
  -яя→-ей (handles titles like "Свирепый таурен"→"Свирепого таурена", declining BOTH words). Endings
  -е/-о/-у/-ю/-ё/-и/-ы (as a BARE noun, not already handled above) → uncertain, abort. Verified
  extensively against real names: "Морган Лукавая"→"Морганы Лукавой" (fem noun+adjective, both
  correctly declined), "Ладноской"→"Ладноского" (surname-as-frozen-adjective, standard Russian
  pattern, e.g. real-world Толстой→Толстого), foreign names ending in -и (Бенни/Реми/Кимберли/Марти/
  Томми) correctly treated as uncertain/indeclinable (no confident RU rule covers this ending).
- **Results**: 3,151 armor looks + 15 held looks eligible (out of looks not already family-tagged);
  140 armor looks skipped by the generic-word gate; 1,291 skipped by declension uncertainty
  (fallback to generic, "better generic than broken grammar" as designed). **14,196 existing items
  retroactively renamed** via a safe, text-only `UPDATE item_template SET name=...` +
  `UPDATE item_template_locale SET Name=...` pass (class/subclass/material/displayid untouched,
  zero risk to item-type consistency) — applied directly against the live DB with
  `--default-character-set=utf8mb4` (per the mandatory charset rule, see Gotchas), verified 0
  double-encoding via check R.

### 3. Held-in-offhand model-derived base noun (folded into the same naming pass)
The generic «Талисман»/"Talisman" base noun (same for ALL 62 held-in-offhand looks regardless of
what they actually depict — a potion bottle, a book, a torch, a bag...) is now derived from the
look's own `ModelName_1`: enumerated all 62 distinct held looks' models, built a curated
token→noun map (bag→Pouch/«Мешочек», tankard→Tankard/«Кружка», book→Tome/«Фолиант»,
potion→Flask/«Флакон», flower→Flower/«Цветок», bucket→Bucket/«Ведро», bottle→Bottle/«Бутыль»,
skull→Skull/«Череп», torch→Torch/«Факел», lantern→Lantern/«Фонарь», orb→Orb/«Сфера», mutton→Mutton
Leg/«Баранья нога», holysymbol→Holy Symbol/«Символ веры», hotpoker→Poker/«Кочерга»,
stave/wand→Rod/«Жезл», glass→Goblet/«Кубок»), cross-checked against REAL item names sharing the
same displayid where one exists (e.g. displayid 31953 "Offhand_Blackwing_A_01.mdx" → real item
"Master Dragonslayer's Orb"/«Сфера великого драконоборца» confirms Orb/«Сфера» even though the
model FILENAME gives no lexical hint; displayid 41453 → "Jewel of Infinite Possibilities" confirms
Gem/«Самоцвет»; displayid 46817 → "Voodoo Shaker" simplified to Fetish/«Фетиш» rather than the
awkward literal "Трясун"). **59/62 looks (95%) mapped**; the remaining 3 (`offhand_pvehorde_d_01.mdx`
×2, `offhand_pvealliance_d_01.mdx` ×1 — generic PvP faction relic props with no real-item anchor)
stay «Талисман»/Talisman (quality gate — no confident noun to assign). Coordinator's estimate of
"~137 looks" was off — the ACTUAL count, confirmed twice (worn_offhand_groups.tsv and a live DB
`COUNT(DISTINCT item_displayid)`), is 62; reported the discrepancy rather than silently using
either number.

### Results / validation
- 200,204 total items (187,288 + 12,916 new Plate). A/B/C/D/E/F/K/O/R all 0. MaxArmorEntry=849,853
  (<1,000,000 ✓). M (coverage gap) reconfirmed 0 (plate-override doesn't touch worn_drop_display at
  all, so this check is structurally unaffected — reran as a sanity check anyway).
- **All 3 required traces PASS**: Praetorian 9448 (level 56, sword+shield) → `plate_override=1`,
  confirmed ALL 7 armor slots have a genuine Plate `worn_drop_item` row at his exact band (55),
  several correctly keeping the curated "Scarlet"/«Алого ордена» family name; следопыт 8564
  (axe+bow, no shield) → `plate_override=0`, stays Mail (unchanged from session 9); a 40+ staff
  caster (Maginor Dumas 331, session 9's own robe-residue example) → `plate_override=0`, stays
  Cloth (correctly excluded — staff is in neither TWOH_MELEE_SUB nor ONEH_MELEE_SUB).
- **Client-side**: custom ItemDisplayInfo 14,067→16,136 ids (110000-126135). `Item_custom.csv`
  132+200,204=200,336. `ItemDisplayInfo_custom.csv` 16+16,136=16,152. Both cross-checked 0 orphans
  either direction vs the live DB after the recovery fix below.
- worldserver REBUILT (`.cpp`: `WD_PlateOverride` + `ResolveProgressionMaterial` priority ordering)
  — clean build, restarted, verified via the new 7-field boot log line with `2094 plate-overrides`
  matching the qualifying-creature count exactly, zero errors after `World Initialized`.

### Gotcha caught + fixed mid-session (real data-integrity bug, not just a process nit)
The plate-override icon generator was run TWICE (once, then again after fixing a donor-fallback gap
for capes) — each run's icon-resolution step wrote `ItemDisplayInfo_plate_override.csv` via
**`open(path, "w", ...)`, OVERWRITING the previous run's file** instead of appending. Run 1 minted
2,034 new custom icons (written to the CSV); run 2 minted only 35 MORE (the capes unlocked by the
donor fix) and, since it overwrote the file, the CSV ended up with ONLY those 35 rows — but
`worn_iconmap.tsv` (a genuinely append-mode file) still correctly listed all 2,069 (look,material)
pairs, and the SQL already applied to the DB correctly referenced all 2,069 custom displayids in
`item_template.displayid`. Net effect: 2,034 items in the LIVE DB pointed at custom ItemDisplayInfo
ids that had NO row in the client CSV at all — would have rendered as a broken/missing icon
("?") in-game despite every SQL-side validation check passing (this class of bug is invisible to
A-N/O/R entirely, since none of them cross-reference the DB against the client CSV file).
**Caught** by running the established DB↔CSV cross-consistency audit (`SELECT DISTINCT displayid
FROM item_template WHERE displayid>=110000` vs the CSV's ID column) as a matter of routine before
finalizing — found exactly 2,034 missing. **Fixed** by writing a small recovery script that
re-resolved the exact same icon for each of the 2,034 orphaned custom ids (using `worn_iconmap.tsv`
to recover which (look,material) each orphaned id represented, then re-running the identical
tier-chain logic) and merging the recovered rows in. Re-verified 0 missing / 0 orphaned both
directions after the fix. **Lesson for any future multi-run/iterative generator**: an APPEND-ONLY
artifact (worn_iconmap.tsv here) is not sufficient proof that a PAIRED artifact (the actual
ItemDisplayInfo row content) was also preserved across runs if that second file is opened in "w"
mode by each run — always verify with a DB↔CSV cross-consistency check as the LAST step before
declaring a partial/incremental regen complete, never trust "the SQL applied with no errors" alone
(SQL applying successfully only proves the DATABASE is internally consistent, not that the
CLIENT-SIDE artifact was correctly assembled across multiple script invocations).

## DONE 2026-07-02 (session 9: Argent Sentry multi-bug + FINAL material spec — the big one)

### Trigger: user-reported bug on "Караульный из Серебряного Авангарда" (entry 16378, "Argent Sentry")
Coordinator's hypothesis was "multiple creature_equip_template sets, we only ingest the first" —
**verified false for THIS specific creature** (only ONE equip row exists: ItemID1=42544 mace,
ItemID2=42543 shield, ItemID3=2551 crossbow, all in the SAME set; the visual melee/ranged toggle is
SmartAI `SET_SHEATH` switching which of the two is DRAWN, not two equip sets). **Real root cause**:
`build-worn-weapons.py`/`build-worn-offhand.py` compute level BANDS from the STATIC base-SQL
snapshot (`data/sql/base/db_world/creature_template.sql`), which is STALE vs the LIVE
`acore_world_ptr` DB (base file says this creature is level 70/70, live DB says 60/60 — confirmed
**1130-1575/~30000 entries (~4-5%) have a different band bucket live-vs-base**, likely from
mod-player-bot-level-brackets or similar). The mace+shield looks are NPC-exclusive (only this
creature uses them) so they were generated ONLY at bands 70/75/80 — band 60 (his true live band)
never existed for those two looks, so `WD_Item.find(...,band=60,...)` always missed for mace/shield.
The crossbow still worked ONLY because that displayid is ALSO a widely-shared stock look, correctly
covering band 60 via many OTHER correctly-leveled creatures. **Fixed**: `load_live_levels()` (new
function, duplicated in all 3 generation scripts per this pipeline's no-shared-module convention)
queries `SELECT entry,minlevel,maxlevel FROM creature_template` directly against `acore_world_ptr`
via `docker exec ... mysql`, OVERRIDING the base-SQL level for any entry present in both (falls back
silently to base-SQL-only behavior if the DB is unreachable, so a regen never hard-fails on that
alone). **278 entries exist ONLY in the live DB** (not in base SQL at all — likely
custom/module-added creatures) — **NOT fixed this session**, still invisible to the whole pipeline
(backlog item).
Separately, the coordinator's ORIGINAL hypothesis (multi-equip-set ingestion) WAS a real, if smaller,
bug for OTHER creatures: `build-worn-weapons.py`/`build-worn-offhand.py`'s `equip` dict used
`dict.setdefault()` on `creature_equip_template`, silently keeping only the FIRST row (ID=1) per
creature — **62/10796 creatures (0.57%) have >1 equip_template row** and were missing every
non-first-set weapon/offhand from their drop pool. Fixed: `equip` is now
`collections.defaultdict(list)`, ALL sets ingested ("inventory-pool model": every set's items are
eligible to drop, regardless of which set is currently visually drawn). **Caught a NEW PK collision
this created**: `worn_drop_weapon`'s PK was `(creature_entry,wslot,item_displayid)` — but creature
28579 has TWO equip sets sharing the SAME (wslot=21,displayid=46750) with DIFFERENT real subclass
(Axe1H entry 33594 vs Axe2H entry 39359, same displayid — a genuinely shared 1H/2H axe model).
**Fixed**: widened the PK to `(creature_entry,wslot,item_displayid,subclass)` via the standard
`information_schema.KEY_COLUMN_USAGE`-guarded PREPARE/EXECUTE idempotent migration (checks the
CURRENT PK column list, only ALTERs if still on the old 3-column shape). `worn_drop_offhand` does
NOT need this — its material is always the wearer's own unit_class-derived value, identical across
that creature's sets by construction, so no analogous collision can occur there.

### Scope widening (user decision): npcflag is no longer a gate anywhere
"Loot from everyone who has >=1 equipped item/weapon model" — drops only ever fire on
`OnPlayerCreatureKill`, so a friendly/vendor/questgiver NPC is completely unaffected unless someone
actually kills it; there was no gameplay reason to pre-filter by npcflag. Removed the `npcflag==0`
condition from `build-worn-slice.py`'s `work` filter AND from both `build-worn-weapons.py`'s and
`build-worn-offhand.py`'s `creatures` dicts (all three, for consistency — only `build-worn-slice.py`
was explicitly named but leaving the other two npcflag-gated would have caused inconsistent partial
coverage). Only `type==7` (humanoid, armor-only) + the junk-name stoplist remain. Result: armored
creatures in scope 6244→12612 (~2x), weapon-bearing creatures 6207→10306, offhand-bearing
1490 (was 914).

### FINAL MATERIAL SPEC (supersedes ALL prior sessions' material-resolution logic, including this
### session's own two earlier iterations — do not re-litigate without an explicit new user ask)
User+coordinator-approved, fully implemented in `build-worn-slice.py` (all logic in ONE script) +
`mod_worn_drops.cpp` (sentinel resolution) + `gen-worn-icons.py` (completed GEN icon dict):

**1. Evidence per (slot,look), tier 1 = ART (NEW, definitive)**: the look's OWN ItemDisplayInfo
model/texture literally encodes its material. Modeled slots (head/shoulder, non-empty
`ModelName_1`): material token IN the filename (`Helm_Mail_D_01.mdx`, regex `_(Mail|Plate|Cloth|
Leather|Robe)_`). Geoset/body slots (chest/belt/legs/boots/wrist/gloves/**cape** — empty
`ModelName_1`): material PREFIX on `Texture_1`..`Texture_8` (`Mail_A_01_Boot_LL`, regex
`^(Mail|Plate|Cloth|Leather|Robe)_`). Live counts: 28,455 ids with an unambiguous token (6,900
modeled + 21,555 geoset), **+7,646 ids flagged "Robe"** (see residue rule below). "Robe" is
EXCLUDED from `art_material_of` (ambiguous material) but tracked separately in `robe_looks`
(**gotcha hit + fixed**: `robe_looks` keys are STRINGS from `csv.DictReader`, `display_pairs`
stores INT displayids — a bare `look in robe_looks` is always False; must `str(look) in
robe_looks`, same trap `art_material_of.get(str(look))` already avoided correctly). Cape (11) is
EXCLUDED from tier-2 real-item-join (session 6 reason: cloak donors carry zero genuine signal) but
NOT excluded from tier-1 art evidence (its own texture columns are a direct, independent fact).
**Tier 2 = REAL-ITEM JOIN** (session 6 pivot, kept, used only where art evidence is absent).

**2. SET UNIFICATION ("unify everything", user decision)**: ONE material per
`creature_display_id`, no per-slot exceptions (this REPLACES two earlier same-session iterations
that tried to preserve "corroborated minority" slots — the user explicitly rejected that in favor
of full unification). WEIGHTED VOTE over every evidenced slot: `EVIDENCE_TIER_WEIGHT={art:3,
real:1}` × `SLOT_WEIGHT={head:3,chest:3,shoulder:2,else:1}` (multiplicative). Winning material
applies to EVERY slot on the display, cape included, even slots whose own evidence disagreed.
**Mage hard clamp (unit_class==8) is UNCONDITIONAL** — forces Cloth(1), overriding the vote outright,
applied LAST, no exceptions (also replaces an earlier same-session "corroborated survives the
clamp" carve-out the user rejected). Tabard(0)/shield(fixed 6)/held(fixed 0) stay OUTSIDE
unification entirely, unaffected.

**3. ROBE RESIDUE RULE (added mid-session after live calibration)**: a no-evidence display whose
looks include a ROBE (tier-1 "ambiguous" flag) resolves to Cloth(1) OUTRIGHT, checked BEFORE the
hunter-token/unit_class fallback below. Root finding: the initial no-evidence residue (876 displays)
was overwhelmingly robed casters (Maginor Dumas, High Priestess Laurena, Demisette Cloyce, Bethor
Iceshard, ...) with `unit_class=1` (Warrior) in `creature_template` — without this rule they'd
incorrectly default to Warrior-progression (Mail/Plate). After the rule: 1171 fallback-ROBE
(→Cloth), only 69 fallback-WARRIOR-progression remain genuinely ambiguous.

**4. NO-EVIDENCE FALLBACK = CALIBRATED ARCHETYPE PROGRESSION** (replaces the old flat `UC_MAT`
unit_class table entirely): checked in this order (robe rule above runs first):
   - **Hunter/Shaman archetype**: name-token match against a CALIBRATED list (candidates tested,
     kept only if ≥85% agreement with ART+REAL evidenced material being Leather/Mail, n≥5 samples;
     full table in validation.md) — **validated: ranger(97%,n=64), hunter(86%,n=135),
     marksman(95%,n=56), stalker(92%,n=39), farstrider(100%,n=9), poacher(100%,n=12),
     bowman(96%,n=22)**. Rejected (didn't clear the bar): archer(66%), sharpshooter(50%),
     trapper(70%), beastmaster(83%,n=6 too small), shaman(78%), strider(67%), warden(65%),
     scout(73%), skirmisher(33%), outrider(33%), windrunner(100%,n=2 too small), gunner(100%,n=4
     too small), rifleman(76%). **Loadout signal ("pure ranged weapon", empty mainhand + a real
     bow/gun/crossbow in the ranged slot) was CALIBRATED and REJECTED** (68.6% agreement, n=290 —
     below the bar; "warriors carry bows too" as the user predicted) — implemented but NOT used
     (`loadout_validated=False` live; the mechanism stays in code for a future re-calibration if the
     token list or threshold ever changes).
     -> `PROGRESSION_HUNTER` sentinel: band<40 Leather(2), band>=40 Mail(3).
   - **Warrior/Paladin** (unit_class 1/2, and the DEFAULT for anything else once Hunter+Mage+Robe
     are ruled out) -> `PROGRESSION_WARRIOR` sentinel: band<40 Mail(3), band>=40 Plate(4) (real
     WotLK itemization — Plate Specialization was a level-40 skill, no Plate below that even for
     these classes).
   - **Rogue** (unit_class 4) -> Leather(2), flat, no band dependency.
   - **Caster** (unit_class 8) -> Cloth(1), flat (redundant with the Mage hard clamp, harmless).
   Live: 0 fallback-HUNTER (current no-evidence residue happens not to hit a validated token; the
   mechanism is proven correct via calibration and DOES fire for evidence-typed Hunter looks via
   the vote instead, e.g. Ranger Lord Hawkspear 10824 resolves via ART evidence directly to Mail),
   69 fallback-WARRIOR, 2 fallback-FLAT, 1171 fallback-ROBE, 403 total Mage-clamped.

**5. UNIVERSAL "no Plate below band 40"** — applies to EVERY source of Plate, not just the
Warrior/Paladin fallback (which already band-gates via its own sentinel). **Bug found + fixed
mid-session** (validation M caught it: 349 real coverage-gap violations): an ART-EVIDENCED or
VOTE-typed display resolving to concrete Plate(4) whose creature's level range DIPS below band 40
was storing a static "4" in `worn_drop_display` while item generation correctly capped those
low-band GROUPS to Mail(3) — the runtime lookup for band<40+matkey=4 then permanently missed.
**Fixed**: in the final per-display assembly, ANY display resolving to concrete `m==4` is
UNCONDITIONALLY converted to the `PROGRESSION_WARRIOR` sentinel too (not just the fallback path) —
this makes Plate NEVER a bare stored value in `worn_drop_display`, always band-gated through the
same sentinel+runtime-resolve mechanism regardless of provenance. Verified: **2,435 evidence-vote
Plate displays converted**; a data-level invariant check (`gen-worn.py`... actually
`build-worn-slice.py`'s own end-of-run assert) now HARD-FAILS generation if any Plate-below-40 group
ever appears again. Live: **0 Plate items below ItemLevel 40** (checked directly against
`item_template`).

**6. MAIL PRIMARY STAT is band-dependent** (user decision): Strength for band<40 ("warrior mail"),
Agility for band>=40 ("hunter/shaman mail") — `primary_for(mat,band)` in `build-worn-slice.py`,
computed per-band at generation time (no runtime change needed, this only affects `stat_type2`
baked into the item at generation, unrelated to the material-sentinel mechanism). Every other
material keeps one fixed primary stat (Plate/Str, Leather/Agi, Cloth/Int) at all bands.

**7. RUNTIME (`mod_worn_drops.cpp`) sentinel resolution — REQUIRED A REBUILD**: `worn_drop_display.
material_id` can now hold `WD_MAT_PROGRESSION_HUNTER=5` or `WD_MAT_PROGRESSION_WARRIOR=6` instead
of a concrete material. New `ResolveProgressionMaterial(matkey, band)` (mirrors
`resolve_band_material()` in Python exactly) is called in the armor-roll lambda RIGHT BEFORE
`AddWornItem`, converting a sentinel to the creature's actual band-correct concrete material before
the `WD_Item` lookup — `worn_drop_item` ONLY ever stores already-resolved concrete materials, an
unresolved sentinel would never match anything. Shield/held (`WD_Offhand`) are UNCHANGED/OUT OF
SCOPE for this whole material redesign — they still use the old flat per-creature unit_class value
for their wearer-derived stat/kit selection (their SUBCLASS was always fixed 6/0 regardless of
material, orthogonal to this whole system) — noted as a deliberate scope boundary, not an oversight
(see PENDING).

**8. GEN icon dict completed** (`gen-worn-icons.py`): Leather(2)/Mail(3) previously only had a
CHEST fallback icon (dead code before this session, since those materials were near-zero) — now
have a FULL per-slot set (head/shoulder/chest/belt/legs/boots/wrist/gloves/cape), each picked as the
single most-common REAL stock `InventoryIcon_1` among genuine `entry<40000 class=4` items of that
exact (subclass,InventoryType) — cross-referenced live against `item_template.sql` +
`ItemDisplayInfo.csv`, NOT guessed from memory, with runner-ups substituted where the #1 pick
collided with an already-used Plate/Cloth icon (so every (material,slot) cell is visually distinct).
`KITPROF`/RU base-noun dicts already had full Mail/Leather entries since session 6 — no change
needed there.

### Results
- **Row counts**: item_template 187,288 (armor 166,560 + weapons 20,728), worn_drop_item 187,288,
  worn_drop_display 70,001 raw rows (13,264 distinct displays), worn_drop_weapon 12,411 (10,306
  distinct entries), worn_drop_offhand 1,494 (1,490 distinct entries), worn_drop_scope 12,878,
  item_upgrade_chain 140,349.
- **Material distribution** (real armor, excl. shield/held/tabard): Cloth 62,820 / Leather 51,296 /
  Mail 22,568 / Plate 27,116 (was Plate 75,164/Cloth 9,692/Leather 3,872/Mail 2,400 end of session
  8) — Mail ~9.4x, Leather ~13.2x, Cloth ~6.5x, Plate roughly HALVED (band-40 floor + robe fix).
- **Client-side**: custom ItemDisplayInfo 6,311→14,067 (ids 110000-124066). `Item_custom.csv`
  132+187,288=187,420 rows. `ItemDisplayInfo_custom.csv` 16+14,067=14,083 rows. Both cross-checked
  0 orphans either direction vs the live DB; 15/15 random type-agreement spot checks passed.
- **Validation A-N + new invariants all 0/clean**: A (icon-material), B-F (stat/dmg/reqs/bonding/
  slot), K (shield/held type), L (material-pivot), **M (coverage gap, was 349, now 0 after the
  Plate-sentinel fix)**, N (name text), J (weapon donor + weapon_creature.tsv↔worn_drop_weapon set
  equality, 12,411/12,411 both directions), NoPlateBelow40 (0 items with subclass=4 and
  ItemLevel<40), MaxArmorEntry=817,563 (<1,000,000 ✓), MaxWeaponEntry=1,051,813 (<1,100,000 ✓).
- **Verification traces, all PASS**: Korfax 16112 in scope (was excluded, npcflag=3 questgiver) ✓;
  Crusader Lord Valdelmar 11898 in scope, Plate ✓; Караульный/Argent Sentry 16378 — mace(wslot21)
  AND shield(wslot12) AND crossbow(wslot23) all present in the drop pool at his true band 60 ✓;
  Scarlet Cleric 9449 — ALL 4 displays now uniformly Cloth (was split 2 Cloth/2 Plate even after
  this session's FIRST iteration; full unification fixed it completely) ✓; Scarlet Archmage 9451 —
  ALL slots incl. head uniformly Cloth ✓; следопыт/Ranger 8564 (unit_class=1 but named "Ranger",
  level 59-60/band≥40) — Mail via direct ART evidence vote ✓; Ranger Lord Hawkspear 10824 (level 60)
  — Mail via ART evidence ✓; 3 low-level Farstrider NPCs (level 12-18, band<40) — Leather (Hunter
  progression, band<40 branch) ✓; Novice Ranger 16923 — fully unified to Leather(2) across all 5
  slots (was a 3-material mess: Plate chest/hands, Mail belt, Leather legs/feet, before ANY of this
  session's fixes) ✓.
- **Rebuild required and done**: `.cpp` change (progression sentinel resolution) — rebuilt
  `ac-worldserver-ptr` clean, restarted, verified via the 6-field boot log line with the new counts
  and zero errors after `World Initialized`.

### Gotchas specific to this session (see also the Gotchas section at the end of this file)
- **A killed/interrupted `docker exec ... mysql < big.sql` piped via a backgrounded shell job
  (`... &` INSIDE the command string) plus the Bash tool's OWN `run_in_background:true` is DOUBLE
  backgrounding** — the tool reports "completed" almost instantly (it's reporting the PARENT shell
  that launched the `&` job returning immediately, not the actual mysql import) while the real
  import keeps running detached for many more minutes. Symptom: row counts look unchanged right
  after a "completed" notification. Fix: check `information_schema.innodb_trx`/`SHOW PROCESSLIST`
  for an actually-running thread before trusting a "completed" status on a backgrounded big-SQL
  apply; for a single big apply, prefer running it in the FOREGROUND with a long `timeout` (this
  tool supports up to 600000ms) instead of backgrounding at all.
- **A killed/aborted mid-script `mysql < file` (hit a real `ERROR 1062` partway through) does NOT
  commit partial work even under `SET autocommit=0` wrapping** — mysql's default non-interactive
  mode STOPS at the first error without ever reaching the appended `COMMIT;`, and the dropped
  connection auto-ROLLS BACK the entire transaction. Symptom: exit code non-zero AND all-old-data
  still present — always `SELECT entry,name FROM item_template WHERE entry=<first announced
  entry>` (or similar) to CONFIRM fresh vs stale data before assuming any partial success, never
  assume "some" of a huge INSERT script landed.
- **A scope/architecture change that increases per-creature "how many DISTINCT things can this
  produce" (multi-equip-set ingestion, in this case) can silently create a NEW primary-key
  collision in a downstream table whose key was implicitly sized for the OLD, narrower assumption**
  — `worn_drop_weapon`'s 3-column PK worked fine when "one equip set = at most one subclass per
  wslot" was true; multi-set ingestion broke that invisible assumption. When widening ANY "ingest
  ALL X" fix, explicitly ask "does any downstream table's PK assume there's only ONE Y per key?"
  before applying, or scan the generated TSV/CSV for duplicate-key-with-differing-payload rows
  BEFORE ever hitting the DB with it (a cheap Python `collections.defaultdict(set)` groupby is
  enough, see the working example in this session's investigation).
- **A `str`/`int` key-type mismatch in a Python dict/set membership check fails SILENTLY (always
  False), never raises** — `robe_looks` (built from `csv.DictReader`, string IDs) checked against
  `look` (an int from earlier int-casting) via a bare `look in robe_looks` always returned False,
  making the entire robe-residue rule a silent no-op (0/0 in diagnostics) until caught by comparing
  actual output against a KNOWN expected example (Maginor Dumas). Always cross-check a brand-new
  rule's diagnostic COUNT against at least one hand-verified real example before trusting a
  plausible-looking "N applied" number — a bug that makes a rule apply to ZERO cases produces a
  perfectly plausible-looking (if suspiciously round) diagnostic line, not an error.

## DONE 2026-07-02 (session 8: TABARD-CHANCE SEPARATION — own independent roll)

### User decision
Tabards should drop RARER than regular armor (cosmetic collectible); shields/talismans (held-in-
offhand) stay in the general armor roll as-is — only tabard gets pulled out.

### Fix (`modules/mod-worn-drops/src/mod_worn_drops.cpp`)
- New config key `WornDrops.TabardChance` (float, %, default 5.0f in code + `conf/mod-worn-drops.conf.dist`; PTR test conf `env/dist/etc-ptr/modules/mod-worn-drops.conf` set to 100 to keep drop-all testing behavior). Read in `LoadConfig()` alongside `WD_Chance`/`WD_WeaponChance`.
- `LoadData()`: tabard rows (`slot == WD_TABARD_SLOT`) are now split out of `WD_Display` at load time into a NEW map `WD_Tabard` (`unordered_map<uint32/*creature_display_id*/, uint32/*item_displayid*/>` — a plain scalar, not a vector, since a live DB check confirmed 0 displays ever have >1 tabard row: `NPCItemDisplay_10` is a single field per `CreatureDisplayInfoExtra` row, so the 1:1 assumption is safe). `WD_Display` now contains ONLY real armor slots.
- `OnPlayerCreatureKill`: the armor-roll lambda no longer special-cases `slot == WD_TABARD_SLOT` (dead code removed — that slot can never appear in `WD_Display` anymore). A NEW standalone block right after the armor-roll block does the tabard roll: `if (inArmor && WD_TabardChance > 0.0f && roll_chance_f(WD_TabardChance))` → look up `WD_Tabard[displayId]` → `AddWornItem(..., forcedQuality=1)` (same band=0/material=WD_TABARD_MAT/quality=1 override as before, unrelated to this change, still required for the `WD_Item` lookup to match). This roll is fully ADDITIVE like the weapon roll: independent of `WD_Chance`, independent of `WD_ArmorPerKill` (tabard is a single scalar per display, no per-kill cap needed/added), can succeed even if the main armor roll failed (or vice versa).
- **Kept the `inArmor` gate** (same `WD_Scope` membership check used by the main armor roll) rather than gating solely on `WD_Tabard.find(...)` succeeding — verified via a live query that ALL 1693 tabard-bearing displays also have at least one real-armor `worn_drop_display` row (`SELECT COUNT(*) FROM (SELECT creature_display_id FROM worn_drop_display GROUP BY creature_display_id HAVING COUNT(*)=1 AND MAX(slot)=10) t` → 0), so no coverage is lost by keeping this gate — a "tabard-only, no other armor" creature is not a real category in this dataset. If that ever changes (future data), gate on `WD_Tabard` membership directly instead.
- Boot log line gained a `{} tabard-maps` field (between `displays` and `weapon-maps`): `mod-worn-drops: loaded 6244 scope, 7461 displays, 1693 tabard-maps, 6207 weapon-maps, 914 offhand-maps, 108643 items.` — **any future doc/validation reference to the old 5-field log format is now stale, this is a 6-field format.**
- **Zero SQL/DB/DBC change** — `worn_drop_display` schema and data are completely untouched; the split from one C++ map into two happens purely in `LoadData()`. No regen, no re-apply, no MPQ delta.
- **Required a worldserver REBUILD** (not just restart) — `.cpp` change. Rebuilt clean first try (`docker compose --profile ptr build ac-worldserver-ptr && ... up -d`), verified via fresh boot log (6-field line above) + confirmed no errors after `World Initialized`.
- **End-to-end verified** for the Scarlet Champion (entry 4302, the same creature traced in session 5's tabard-chain bug): `creature_template_model` → display ids 2460/2461 → `worn_drop_display` (2460,10,3865,0)/(2461,10,3865,0) → now loaded into `WD_Tabard[2460]=3865`/`WD_Tabard[2461]=3865` (not `WD_Display`) → `worn_drop_scope[4302]=4` (Plate, satisfies the `inArmor` gate) → `worn_drop_item` (3865,10,band=0,mat=0,quality=1) → entry 624470 "Scarlet Tabard" — the full chain still resolves through the new split path with the band/quality override intact.
- A/F/tabard-item-count reconfirmed unchanged (0 / 0 / 123) post-rebuild directly against the live DB — pure C++/config change, DB completely untouched.

## DONE 2026-07-01 (session 7: ICON QUALITY PASS — model-match + real-item-provenance chain)

### Problem
Iconless NPC-baked looks (no player-obtainable equivalent item) fell back to ONE crude generic
icon per (material,slot) bucket (e.g. every iconless Plate helm showed the same `INV_Helmet_04`)
whenever the donor's own icon wasn't material-matched either. User: "possibly via displayId we can
find proper icons."

### Fix: 5-tier icon resolution chain in `gen-worn-icons.py`, most-accurate first
1. Stock look's own icon, single-material look → keep stock displayid (unchanged, pre-existing).
2. **NEW**: cross-material look whose STOCK icon is attributable to a REAL `item_template` row of
   THIS specific material (`displayid==look`, `subclass==mat`) → reuse that exact icon (small,
   13 pairs, but strictly correct-by-construction).
3. **NEW, the main lever**: MODEL MATCH. Built an index of every `ItemDisplayInfo` row that HAS an
   icon, keyed by `(ModelName_1, ModelName_2)` lowercased (NOT also texture — WoW encodes material
   IN the model filename itself, e.g. `Helm_Plate_D_02.mdx` vs `Helm_Mail_D_01.mdx` are physically
   different models, so a model-name match can never cross a material boundary; requiring exact
   texture too would reject valid same-model colorway variants for no safety benefit). For an
   iconless look with a non-empty `ModelName_1` (head/shoulder/held-in-offhand only — see "geoset
   slots" below), find a same-model icon-bearing row and borrow its icon.
   **Quality gate (found + fixed live this session)**: candidates are restricted to
   `ItemDisplayInfo` ids that are THEMSELVES a real `class=4` item's displayid with an
   `InventoryType` matching the target slot. Without this gate, some stock models (confirmed:
   `Helm_Eyepatch_A_01.mdx`) are reused by Blizzard across UNRELATED item categories (amulets,
   belts, bandanas, shields, as well as actual helmets), each with a different icon TYPE — an
   unfiltered "any same-model icon" pick landed on `INV_Box_01`/`INV_Shield_09` for a HEAD-slot
   look, a worse mismatch than the generic fallback it was replacing. With the gate: prefer a
   same-material real item of the right slot type, else any-material real item of the right slot
   type; if NO slot-type-valid candidate exists, tier 3 yields nothing (falls through to 4/5)
   rather than risk a wrong-category icon. **Note**: a real head-slot item CAN legitimately have an
   unusual-looking icon (confirmed: stock id 13219 is a genuine Cloth head item using
   `INV_Shield_09` — Blizzard's own icon choice, not a bug) — the gate verifies item-TYPE
   provenance (same slot), not "does the icon look conventional".
4. Donor-material icon (pre-existing, unchanged): donor's own icon, only if donor's own subclass
   equals `mat`.
5. Generic `GEN` fallback (unchanged, last resort).
**Geoset slots (chest/legs/belt/wrist/gloves/gauntlets/boots/cape/tabard) render off the body
texture and have an EMPTY `ModelName_1`** — tier 3 is a structural no-op for them (0 candidates,
by design, not a bug) — they keep the donor→generic path exactly as before. This is expected and
was called out by the coordinator up front: the visible win is head/shoulder/held only.

### Results (live, `worn_iconmap.tsv` = 6311 (look,material) pairs needing a custom icon)
| Tier | Before (session 6) | After (session 7) |
|---|---|---|
| real_item (exact stock icon, material-verified) | 0 (tier didn't exist) | 13 |
| model_match (exact-visual, borrowed from a same-model real item) | 0 (tier didn't exist) | 1003 |
| donor (material-matched donor icon) | 6228 | 5232 |
| generic (crude one-per-bucket fallback) | 83 | 63 |
Net: **1016 (look,material) pairs upgraded from a substituted/generic icon to an exact-visual,
type-verified icon** (13 real_item + 1003 model_match), concentrated in head/shoulder (990 pairs)
and held-in-offhand (22 pairs, all upgrading straight out of the generic talisman bucket) — exactly
the slots predicted, since geoset slots have no model to match on. Each (look,material) pair spans
up to 4 quality tiers in `item_template`, so this affects roughly 3000-4000 individual items
(exact count depends on how many of the 1016 pairs are 4-quality vs cross-material subsets already
counted elsewhere — not separately re-tallied at the item level since the pair-level count is the
meaningful unit for an icon change).
Concrete examples (look id / material / slot : old icon → new icon):
- 34068 Plate Head: `INV_Helmet_19` (generic) → `INV_Helmet_67` (a real Christmas-cosmetic head
  item sharing the exact `Helm_Cloth_Holiday_Christmas_A_01.mdx` model).
- 8380 Plate Head: `INV_Helmet_03` (generic) → `INV_Helmet_19` (a same-model real head item).
- Plate Shoulder, exact per-look mapping (verified 2026-07-02 audit, corrects an earlier imprecise
  list that implied loose positional correspondence): look 17821 → `INV_Shoulder_25`, look 12916 →
  `INV_Shoulder_08`, look 49776 → `INV_Shoulder_25` (same real-item candidate as 17821 — both share
  the identical underlying model, so tier 3 legitimately lands on the same borrowed icon for both).
  All were generic `INV_Shoulder_20` before this session.
- Held-in-offhand, exact per-look mapping (verified 2026-07-02 audit, corrects an earlier imprecise
  list that implied a 1:1 positional correspondence with the look-id list that didn't actually
  hold): look 6531 (Cloth+Plate) → `INV_Misc_Gem_Opal_01` (tier-3 model-match on
  `Misc_1H_Potion_B_01.mdx`, borrowed from stock entry 4642 "NPC Equip 4642", the only real
  class=4/InventoryType=23 item sharing that exact model — same icon for BOTH materials since
  neither is a same-material candidate); look 6536 → `INV_Potion_07`; look 6537 → `INV_Torch_Lit`;
  look 23175 → `INV_Misc_Book_09`; look 23318 → `INV_Misc_Bag_10`. All were the generic
  `INV_Jewelry_Talisman_03` before this session — the model IS the held prop (potion bottle, torch,
  tome, bag, gem), so the borrowed icon is exactly what the prop looks like, a huge upgrade from one
  generic talisman icon for every held prop.

### Client-side delta and DB delta
- Custom ItemDisplayInfo COUNT is **unchanged** (still 6311 ids, 110000-116310) — this session only
  changes the `InventoryIcon_1` field VALUE within existing custom rows, mints no new ids.
- `item_template.displayid` in the DB is **completely unchanged** — items already pointed at their
  (session 6) custom ids; `worn_displayid_remap.sql` was applied as a verification step and
  confirmed a true no-op (row counts at custom-id range identical before/after: 57386). **No SQL
  needed for this task at all** — it is a pure `ItemDisplayInfo` (icon) content change, invisible
  to any DB query, only visible after an MPQ rebuild.
- Re-merged `.claude/dbc/ItemDisplayInfo_custom.csv` (16 base + 6311 worn = 6327 rows, same count
  as before, only icon values changed). `.claude/dbc/Item_custom.csv` untouched (108775 rows,
  confirmed identical — Item.dbc doesn't carry icon data, only ItemDisplayInfo does).
- Validation A-M reconfirmed 0 (unaffected by an icon-only change, run as a sanity check per the
  coordinator's request rather than skipped). Check H (GroupSoundIndex non-zero on all 6311 custom
  rows) reconfirmed 0-violations on the freshly regenerated `ItemDisplayInfo_worn_custom.csv` — GSI
  is untouched by this session's tier logic (always sourced from the donor's own sound profile,
  orthogonal to which icon tier fired).
- **No worldserver restart or rebuild needed** — no DB row changed, no C++ changed.
- **This is the LAST client-CSV change in the material-pivot/shield/tabard/icon arc** — user should
  do ONE MPQ rebuild + Cache/WDB clear now, covering sessions 5-7 together.

## DONE 2026-07-01 (session 6: ARMOR MATERIAL PIVOT — material now resolved from the LOOK, not unit_class)

### Problem
Armor material was derived SOLELY from the wearer creature's `unit_class` (idx 28): Warrior(1)/
Paladin(2)→Plate(4), Rogue(4)→Leather(2), Mage(8)→Cloth(1). Every OTHER unit_class (Priest,
Shaman, Hunter, generic 0/no-class NPCs — the overwhelming majority of humanoid NPCs) fell through
to a default, and **no unit_class value maps to Mail(3) at all** — Mail was structurally
impossible to generate regardless of what any NPC actually visually wore. Confirmed via live data:
drops were observed as essentially 100% Plate/Cloth, ~0% Leather, 0% Mail.

### Fix (user-approved): resolve material from a REAL-ITEM join on the baked look itself
`build-worn-slice.py` now resolves material **per (slot, look) pair**, not per creature:
```python
REAL_MATERIAL_SLOTS = {1, 2, 4, 5, 6, 7, 8, 9}   # head/shoulder/chest/belt/legs/boots/wrist/gloves
def resolve_real_material(slot, look):
    """displayid==look, InventoryType matches slot (+CHEST_ALT robe alt), class=4, subclass in
    {1,2,3,4}. Tie-break: most common subclass among matches. None if no real item shares the look."""
```
Built alongside the existing donor-collection pass: `disp_items[displayid] -> [(invtype, subclass), ...]`
across ALL stock (entry<40000) `item_template` rows. **Fallback**: if no real item shares the
(slot,look) pair (an NPC-exclusive look with no equivalent player item), keep the OLD unit_class→
material mapping (via a `slot_look_ucs` Counter, majority-vote across wearers sharing that look).
Live coverage: **1300/9922 (slot,look) pairs resolved via real-item join (13.1%), 8622 via
unit_class fallback (86.9%)**. This lines up with expectations — most NPC-worn looks genuinely have
no equivalent player-obtainable item (unique bosses, event skins, etc.), so the fallback carrying
the majority is correct and expected, not a bug.

**Cape (slot 11) deliberately EXCLUDED from the real-item join, stays unit_class-only**: a
feasibility check found 71/71 "real-matched" capes resolved to Cloth regardless of the actual
wearer, because stock cloak donors (InventoryType=16) are ALWAYS subclass∈{0,1} in item_template —
zero genuine material signal exists in the cloak donor pool (this was already a known gotcha from
session 2's cape/tabard subclass bug, see Gotchas). Tabard (slot 10) is untouched — still the
universal TABARD_MAT=0 pseudo-material bucket, orthogonal to this pivot. Shield (12) / held-in-
offhand (13) are explicitly OUT OF SCOPE — they keep their FIXED subclass constants (6/0)
regardless of material; the wearer's material still flows through only for THEIR item's stat/kit
selection (KITPROF), never their subclass identity.

### Runtime implication: material now travels PER ROW, not per creature
A single NPC can legitimately wear, e.g., a Plate chest AND Leather boots (each independently
resolved from ITS OWN baked look) — material can no longer be a single per-creature value.
- `worn_drop_display` schema: **added `material_id TINYINT UNSIGNED NOT NULL DEFAULT 0` column**,
  PK unchanged `(creature_display_id, slot)`. `worn_drop_scope` is UNCHANGED (still
  `creature_entry -> material_id`, single value) but its ROLE is now DOWNGRADED: only used (a) as
  the "does this creature have a baked armor look at all" GATE (`inArmor` in C++) and (b) supplying
  the material fallback baseline that build-worn-slice.py's Python-side fallback uses when computing
  the majority-vote unit_class value per look (the C++ runtime itself never reads WD_Scope for
  armor material anymore).
- C++ (`mod_worn_drops.cpp`): `WD_Display` changed from `unordered_map<uint32, vector<pair<uint8,uint32>>>`
  (display -> [(slot,look)]) to `unordered_map<uint32, vector<tuple<uint8,uint32,uint8>>>`
  (display -> [(slot,look,material_id)]). The armor-roll lambda in `OnPlayerCreatureKill` now reads
  `matkey = std::get<2>(t)` directly off each row instead of using one blanket `WD_Scope[entry]`
  value for every slot. **Required a worldserver REBUILD** (not just restart) — done, verified via
  `mod-worn-drops: loaded ... 108643 items` in fresh boot logs with the new binary.

### MySQL 8.4 gotcha hit + fixed: `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` is NOT valid syntax
Needed an idempotent upgrade path so a pre-existing 3-column `worn_drop_display` on a live DB gets
the new `material_id` column added (the `CREATE TABLE IF NOT EXISTS` at the top of the generated
SQL only handles a from-scratch install, not an existing table). First attempt used
`ALTER TABLE worn_drop_display ADD COLUMN IF NOT EXISTS material_id ...` — **this MariaDB-only
extension throws `ERROR 1064` on real MySQL 8.4.4** (confirmed directly against the container: bare
`ALTER TABLE t ADD COLUMN IF NOT EXISTS b INT` also fails identically, so it's a genuine
vanilla-MySQL syntax gap, not a formatting mistake). **Fixed** with the standard
`information_schema`-guarded `PREPARE`/`EXECUTE` idiom (verified working against the container
before embedding):
```sql
SET @wd_disp_has_mat := (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='worn_drop_display' AND column_name='material_id');
SET @wd_disp_sql := IF(@wd_disp_has_mat = 0, 'ALTER TABLE `worn_drop_display` ADD COLUMN `material_id` TINYINT UNSIGNED NOT NULL DEFAULT 0', 'SELECT 1');
PREPARE wd_disp_stmt FROM @wd_disp_sql;
EXECUTE wd_disp_stmt;
DEALLOCATE PREPARE wd_disp_stmt;
```
**Gotcha for future idempotent schema changes on this DB**: vanilla MySQL 8.x has NO
`IF NOT EXISTS` support for `ADD COLUMN`/`DROP COLUMN`/`MODIFY COLUMN` (only `CREATE TABLE`/
`CREATE INDEX` support it) — always use this PREPARE/EXECUTE pattern for column-level idempotent
DDL, never assume the MariaDB-only sugar syntax works here.

### SECOND bug caught post-generation, pre-report (naming table gap, NOT in any SQL validation check)
After applying, spot-checked sample Mail/Leather items for the report and found EVERY Leather/Mail
item was named "Plate Helm"/"Латный шлем" etc. regardless of its real subclass. Root cause:
`gen-worn.py`'s `BASE` dict (armor base-noun text per material) only ever had keys `{0: tabard,
1: Cloth, 4: Plate}` — Leather(2)/Mail(3) entries never existed because material could only ever be
1 or 4 via the OLD unit_class-only path; `base_for()`'s `BASE.get(mat, BASE[4])` fallback silently
substituted PLATE TEXT for any other material key, which was invisible/dead code until this
session's pivot made Leather/Mail reachable. **This is NOT caught by ANY of the checks A-M** — the
DB-level checks all validate class/subclass/InventoryType/stat numeric consistency, never the name
STRING against the material. **Fixed**: added full `BASE[2]` (Leather: Кожаный шлем/Leather Helm,
Кожаные наплечники/Leather Shoulders, Кожаная безрукавка/Leather Tunic, Кожаный пояс/Leather Belt,
Кожаные штаны/Leather Leggings, Кожаные сапоги/Leather Boots, Кожаные наручи/Leather Bracers,
Кожаные рукавицы/Leather Gloves) and `BASE[3]` (Mail: Кольчужный шлем/Mail Helm, Кольчужные
наплечники/Mail Pauldrons, Кольчужная кираса/Mail Breastplate, Кольчужный пояс/Mail Belt,
Кольчужные поножи/Mail Leggings, Кольчужные сапоги/Mail Boots, Кольчужные наручи/Mail Bracers,
Кольчужные рукавицы/Mail Gauntlets) — standard WoW terminology, cape/shield/held slots (11/12/13)
reuse the SAME text as Plate/Cloth for those 3 (materially-neutral: "Плащ"/"Щит"/"Талисман") since
those slots don't have material-specific naming conventions in stock WoW either. Re-applied
(naming-only re-run, no structural/schema change, just an UPDATE-shaped DELETE+reinsert since the
generator always does full regen) — verified 0/288-false-positive-then-confirmed-0-true-mismatch
Leather/Mail items now say "Plate" anywhere in EN or "Латны" in RU (the initial 288 hits were a
false-positive substring match on "…Breastplate" containing "Plate", NOT a real bug — tightened the
check to anchor on word boundaries, confirmed a TRUE 0 after excluding that noise).
**New validation lesson**: whenever a NEW material/subclass value becomes reachable for the first
time (via a pivot like this one), grep EVERY naming/text lookup table in gen-worn.py for the full
set of newly-possible material keys BEFORE trusting sample output — a `dict.get(key, default)`
fallback with a same-shape wrong-value default is invisible until someone eyeballs actual names.

### New validation checks added this session (see validation.md for exact SQL)
- **(L) material-pivot end-to-end**: for every `worn_drop_display` row (excl. tabard), the item
  resolvable via `worn_drop_item`+`item_template` must have `subclass == the row's own material_id`.
- **(M) coverage gap**: every `worn_drop_display` row (excl. tabard) must resolve to at least one
  `worn_drop_item` row for its own (look,slot,material) — catches a look/material combo that got
  written to the display table but never got a matching item generated.
- **(N) name/material text consistency** (Python/manual, not a clean single SQL predicate — beware
  substring false positives like "Breastplate" containing "Plate"): spot-check that Leather/Mail
  item names never contain literal Plate-only vocabulary. Not automatable as cleanly as A-M since it
  requires anchoring on word boundaries per-language; worth a manual sample pull after any BASE/
  naming-table change, especially one that makes a previously-unreachable material key reachable.
Both L and M returned 0 on first check (the pivot's SQL/schema mechanics were correct from the
start) — only N caught a real bug, and only because a human looked at actual sample text rather
than trusting numeric-only validation.

## DONE 2026-07-01 (session 5: weapon-type consistency + tabard drop chain + shield/offhand generation)
User-reported bugs, all traced end-to-end on live `acore_world_ptr` data before any code change.

### Bug 1 — weapon subclass/name/icon mismatch (systemic, e.g. a "Ружьё"/Gun-named item showing a Bow's icon+sounds)
Root cause #1 (main): `build-worn-weapons.py`'s `pick_donor(sub, inv, band)` fallback, when no
exact `(sub, inv)` white donor pool existed, matched **ANY subclass sharing the same InventoryType**
(`for (s2,i2) in donors: if i2==inv`) instead of restricting to the SAME subclass. Bow/Gun/Crossbow
all share InventoryType 26 -- confirmed a real case: displayid 47228 (a genuine stock Bow,
subclass=2) got donor 30758 "Aldor Guardian Rifle" (subclass=3/Gun) because no exact Bow donor
existed at band=70, silently making the GENERATED item a Gun (donor's subclass flows straight into
item_template via `INSERT...SELECT`, `emit_group` never forces weapon subclass). **Fixed**: fallback
now matches `s2 == sub` (same subclass, any invtype) -- subclass is NEVER crossed. 160/3903
weapon_groups.tsv rows were affected pre-fix (spread across many subclass pairs, e.g.
Sword2H->Sword1H, Axe2H->Mace1H, Dagger->Axe1H, plus a handful of Bow/Gun/Crossbow/Thrown pairs);
0 after the fix (audited: donor subclass == intended subclass for all 3903 rows).
Root cause #2 (secondary, `worn_drop_weapon` only): `gen-worn.py`'s old `look_sub = {}` was a
plain dict KEYED BY DISPLAYID ALONE, overwritten on every `weapon_groups.tsv` row -- 16 stock
displayids are genuinely worn by weapons of >1 real subclass across different creatures/equip
rows (confirmed via a full `creature_equip_template` ground-truth audit), so the last-processed
row's subclass silently "won" for ALL creatures sharing that displayid, regardless of what THAT
creature actually wields. **Fixed**: `build-worn-weapons.py` now writes the per-creature TRUE
subclass directly into `weapon_creature.tsv` (`(creature_entry, wslot, item_displayid, subclass)`,
was 3 cols, now 4) instead of `gen-worn.py` reconstructing it from a shared lookup. Audited
end-to-end against real `creature_equip_template`: 7655/7655 rows now correct (was would-be-wrong
for creatures using one of the 16 ambiguous-displayid looks with the "wrong" subclass).
**No MPQ delta** -- this is a server-side name+subclass fix; displayids are unchanged (still real
stock item ids the client already has).

### Bug 2 — tabards never drop despite existing in the DB (traced via a real Scarlet Champion, entry 4302)
Confirmed the FULL chain was correct up to the very last step: `CreatureDisplayInfoExtra`
NPCItemDisplay_10=3865 (real tabard look) -> `worn_drop_display` correctly has
(2460,10,3865)/(2461,10,3865) -> `worn_drop_item` correctly has (3865,10,**band=0**,material=0,
quality=1)->632580 "Scarlet Tabard". Root cause: `mod_worn_drops.cpp` computes ONE `band` from
`killed->GetLevel()` (e.g. band=40 for a level-40 mob) and passes it uniformly to EVERY slot's
`AddWornItem` call, including tabard -- but tabards are ALWAYS generated at the fixed `band=0`
(single-band, white-only, no GA tiers). The lookup `WD_Item.find((look,10,40,0,quality))` can
NEVER match a row stored at band=0 -- tabards were 100% unreachable for any creature above band 0
(and even band=1, since C++ clamps `band<1` to 1, not 0). A SECOND latent bug on top: even fixing
band alone wouldn't have been enough, because `RollQuality()` normally rolls 1-4 but tabards only
exist at Quality=1 -- a roll landing on 2/3/4 would ALSO silently miss. **Fixed**: `AddWornItem`
gained a `forcedQuality` param (default 0 = roll normally); the tabard-slot branch in
`OnPlayerCreatureKill` now calls `AddWornItem(loot, look, slot, 0, WD_TABARD_MAT, epic, /*forcedQuality=*/1)`
-- band, matkey, AND quality all overridden together for that slot only. **C++ change, required a
rebuild** (not just restart). No MPQ delta (existing tabard items, no new displayids).

### Bug 3 — generalized to ALL off-hand slots (shield was the initial ask; coordinator expanded scope mid-task)
`creature_equip_template.ItemID2` (offhand) routes by the REAL source item's (class,subclass,
InventoryType) -- never guessed:
- **Shield**: class4/subclass6/InvType14 -> ARMOR path (donor=real white shield, has armor no dmg).
- **Held-in-off-hand**: class4/subclass0/InvType23 (torches/totems/flowers/etc, cosmetic) -> NEW,
  same ARMOR path but donors have ~0 armor/stats so nothing is invented. Base noun chosen:
  "Талисман"/"Talisman" (generic, matches the real donor variety; fallback icon
  `INV_Jewelry_Talisman_03`, a real icon already used by several stock held items).
- **class-2 off-hand weapons** (InvType 22/13/21 etc): were ALREADY correctly generated by the
  EXISTING weapon pipeline (`build-worn-weapons.py`'s `WSLOT={0:21,1:22,2:23}` already covers
  ItemID2 whenever the real item is class=2) -- confirmed via data audit (627 wslot=22 rows
  already present), no code change needed for this part.
New script `build-worn-offhand.py` (replaces an earlier shield-only `build-worn-shields.py`
draft) handles shield+held together, routed by a `SLOT_META = {SHIELD_SLOT:(6,14), HELD_SLOT:(0,23)}`
table (never guesses -- unmatched (class,subclass,invtype) triples are skipped, not force-fit).
**ARCHITECTURE BUG caught before ever reaching PTR** (would have been a live SQL failure):
initially wired shield/held into `worn_drop_display` (creature_display_id-keyed, same table as
baked armor) -- but `creature_equip_template` is keyed by CREATURE_ENTRY, and the SAME
`creature_display_id` can wield a DIFFERENT offhand item depending on which entry uses it
(confirmed real collision: display_id 370 used by "Ravenclaw Guardian" wielding shield-look 1755
AND "Scourge Guard" wielding shield-look 1706 -- a `(370,12)` PK insert collision, caught as a
literal `ERROR 1062 Duplicate entry` on apply). **Fixed** by giving offhand-armor its own table,
`worn_drop_offhand(creature_entry, wslot, item_displayid, material_id)`, entry-keyed like
`worn_drop_weapon` -- NOT display-keyed. C++ gained `WD_Offhand` (mirrors `WD_Weapon`'s shape) and
an offhand roll folded into the SAME `WD_Chance`/`WD_ArmorPerKill` gate as the armor roll (per
spec: "armor-class offhands ride the armor roll"), with its own independent `PickAndAdd` so a
creature with both a full armor set AND a shield can drop from both sources on one successful roll.
**SECOND bug caught before apply** (this one caught by a post-generation type-consistency audit,
not by a live error): `emit_group`'s existing `force_subclass=matkey if is_armor else None` logic
(added in an EARLIER session to fix the cape/tabard subclass bug) blindly forces subclass = the
WEARER'S MATERIAL for every `is_armor=True` call -- correct for real armor pieces (subclass IS the
material there) but WRONG for shield/held, where subclass is a fixed type constant (6/0)
independent of material (a Plate NPC's shield is still subclass=6, never subclass=4). Confirmed:
first apply attempt generated shields with subclass=4 (matching the Plate wearer) instead of 6.
**Fixed**: `emit_group()` gained a `subclass_override` param (takes precedence over `matkey` when
given); the offhand call site passes `SHIELD_SUBCLASS=6` or `HELD_SUBCLASS=0` explicitly. Verified
post-fix: 0/1232 shields and 0/548 held items have a wrong class/subclass/InventoryType triple.
Result: **1232 shield items (308 groups, 117 distinct looks) + 548 held-in-offhand items (137
groups, ~40 distinct looks) = 1780 new item_template rows**, both with full GA upgrade chains and
family-naming support (26 shield looks + 5 held looks got a family name). +22 new custom
ItemDisplayInfo ids (110000-117573 -> 110000-117595) for the handful of iconless/cross-material
shield+held looks -- **this DOES need an MPQ delta** (new icons), unlike bugs 1-2 which are
server-side only. Most shield/held looks (141/163) already had real stock icons (they're real
equipped items, same as weapons) and needed no custom id.

### Extra finding (not a bug): creature 17853 "Tracker of the Hand" / "Следопыт Длани" chest non-drop
User asked why this NPC's chest never drops. Traced: `creature_template_model` -> displayids
17280/17281/17282 -> `CreatureDisplayInfoExtra` ext ids 11942/11943/11944 -> **`NPCItemDisplay_4`
(chest) = 0 for ALL THREE display variants** (wrist, index 8, is also 0 for this NPC). Verdict:
**NOT a pipeline bug** -- this NPC's torso is baked into its base skin with no separate chest
"item" layer at all (same class of case as other incomplete-model NPCs). Correctly generates
nothing for this creature's chest slot; nothing to fix.

## DONE 2026-07-01 (cape + tabard + family-naming bundle)
1. **Cape fix**: `build-worn-slice.py`'s `MODEL_SLOTS` was `{1,2,11}` — capes (slot 11) have an EMPTY `ModelName_1` in ItemDisplayInfo (geoset/texture-based like tabards), so requiring a model wrongly filtered out EVERY cape look → 0 cape items ever generated. Fixed `MODEL_SLOTS = {1,2}` (only head/shoulder attach a model). Result: cape now yields 370 generation groups / 184 distinct looks / ~1480 item_template rows (was 0).
2. **Tabards added**: NPCItemDisplay index 10 = tabard, VERIFIED via real item cross-ref (entries 746 "Lord Brandon's Tabard (Test)" and 3557 "Unused Tabard of Chow" are class=4/subclass=0/InventoryType=19 at displayids 3865/3864, icon `INV_Banner_02`, empty ModelName — matches prediction exactly). New constants `TABARD_SLOT=10`, `TABARD_MAT=0` (pseudo-material bucket, universal/cosmetic — added to `GEAR`/`SLOT_INVTYPE`/`MAT_NAME`/`MAT_PRIMARY` dicts in build-worn-slice.py) in BOTH build-worn-slice.py and gen-worn.py (kept independently defined, not shared — no shared-constants module in this pipeline). Tabard rows forced to a single band (0) and `TABARD_MAT` regardless of wearer's `unit_class` (universal look). Donor junk filter (`_JUNK`) extended with `"deprecated"` (bare word, no brackets — real stock donor 7725 "Tabard of the Scarlet Crusade DEPRECATED") and applied specifically to tabard donors (`SLOT_INVTYPE[TABARD_SLOT]==19`) in the donor-collection loop. Result: 123 generation groups = 123 distinct tabard looks (1:1 since single-band single-quality) = **123 item_template rows, ALL Quality=1 (white-only, no GA tiers)**. `emit_group()` takes `n_quality` param (tabards pass 1, everything else 4); `item_upgrade_chain` loop uses `range(1, n_quality)` so tabards correctly get 0 chain rows (no upgrade path — by design, single quality).
   - **worn_drop_scope gotcha (fixed)**: a creature can wear BOTH real armor (material 1-4) AND a tabard (material 0). `gen-worn.py`'s scope-building loop now explicitly skips `material_id==TABARD_MAT` rows when populating `scope[creature_entry]` (previously relied on sort-order luck: cw_rows tuple sorts material_id 4th field, so 0 < 4 meant armor rows happened to win as "last write" — fragile, now explicit).
   - **CRITICAL C++ RUNTIME BUG caught + fixed** (would have made tabards silently never drop despite correct DB data): `mod_worn_drops.cpp`'s armor-roll lambda called `AddWornItem(loot, look, slot, band, material, epic)` using the SAME creature-scope `material` (e.g. Plate=4) for EVERY slot in `WD_Display[displayid]`, including a tabard slot — but `worn_drop_item` stores tabards keyed at `matkey=0`. The lookup `WD_Item.find((look, 10, band, 4, quality))` would never match. **Fixed**: added `WD_TABARD_SLOT=10`/`WD_TABARD_MAT=0` constants (mirroring the Python-side constants — no shared header, keep in sync manually if slot/bucket ever changes) and the lambda now does `matkey = (p.first == WD_TABARD_SLOT) ? WD_TABARD_MAT : material`. **Required a worldserver REBUILD** (not just restart) since it's a .cpp change — rebuilt clean first try, `docker compose --profile ptr up -d ac-worldserver-ptr` recreated the container.
3. **Cape/tabard donor subclass bug caught + fixed (validation A)**: stock WoW cloak donors (InventoryType=16) are NOT material-differentiated in item_template — `subclass` is always 0 or 1 regardless of what material class actually wears that cloak model (confirmed: `SELECT DISTINCT subclass FROM item_template WHERE InventoryType=16` → only {0,1}, never 2/3/4). Since `emit_group` copies the DONOR's subclass via `INSERT...SELECT`, generated Plate/Leather capes were silently getting subclass=0 or 1 from the donor — this collided with the tabard pseudo-material bucket (0) → validation A found 12 displayids shared between subclass 0 (mis-subclassed Plate/Leather capes) and 1 (Cloth), because a cape LOOK can be worn by multiple materials while the STORED subclass ignores that entirely. **Fixed**: `int_overrides()` gained a `force_subclass` param; `emit_group()` gained `is_armor` bool (armor call site passes `is_armor=True`, weapon call site leaves it `False` since weapon subclass legitimately varies per donor and must NOT be forced). When `is_armor=True`, `ov['subclass'] = matkey` (the true intended material) — overrides whatever the donor's subclass column says. This is now the FOURTH thing forced independent of the donor's own value (alongside displayid/Quality/RequiredLevel/ItemLevel). Verified post-fix: `SELECT InventoryType, subclass, COUNT(*) ... GROUP BY` shows cape subclass now cleanly splits 1/2/4 (Cloth/Leather/Plate) with zero 0-subclass leakage; validation A → 0.
4. **Family-based naming** (replaces the old Scarlet-hardcoded `SUF` rank-suffix dict `{2:[рекрута,...], 3:[...], 4:[...]}`, which was thematically wrong once scope became all-NPCs). New scheme in `gen-worn.py`:
   - Per stock LOOK (not per (look,material)!), compute the dominant wearer-name family token from `creature_template.sql`'s English name field (parsed OFFLINE from base SQL — no live-DB dependency, same pattern as build-worn-slice.py). Tokenizer (`_family_token`): checks a `FAMILY_MULTI` list of known multi-word phrases first (case-insensitive, `.` normalized to space so `"Venture Co. Air Patrol"` matches `"Venture Co"`), else falls to the first non-stoplisted single token. `FAMILY_STOP` is a large curated stoplist of titles/ranks/races/generic-adjectives/vendor-role-words (see gen-worn.py `FAMILY_STOP` — ~130 entries) so garbage never becomes a family candidate.
   - A look gets a family name ONLY IF: (a) the dominant token/phrase is in the curated `worn_family_map.tsv` (EN family → RU genitive), AND (b) that family covers ≥60% (`FAMILY_THRESH`) of the look's distinct wearers. Otherwise generic (base noun only, unchanged behavior).
   - Curated map lives in `modules/mod-worn-drops/scripts/worn_family_map.tsv` (3 cols: en_family, ru_genitive, notes) — **134 families** (grew from 88 in session 3), all cross-referenced against real `creature_template_locale`/`item_template_locale` ruRU text before being added (never invented). User-editable — add/remove rows, no code change needed (gen-worn.py just re-reads it).
   - `name_for(en0, ru0, family)`: EN = `"<Family> <base noun>"` (e.g. "Defias Plate Helmet"); RU = `"<base noun> <Family genitive>"` (e.g. "Латный шлем Братства Справедливости"). Name is IDENTICAL across ALL bands/qualities of the same (look,material,family) group — intentional aggregation, no more per-tier rank suffixes.
   - **Session 3 added a TIER-2 auto-derive fallback** for looks not in the curated map — see "Family naming: two tiers" section below for full details.
   - Final coverage after session 3: **armor 2630/9957 looks (26.4%, curated 2601 + auto 29) + weapon 175/1249 looks (14.0%, curated 170 + auto 5)**.
   - Gotcha found+fixed during grounding: a family added to `worn_family_map.tsv` but NOT also added to `FAMILY_MULTI` (when it's a multi-word phrase) silently never matches — the bare first-token falls through and never equals the curated key. Always add multi-word families to BOTH `FAMILY_MULTI` and `worn_family_map.tsv`.
   - Gotcha: a MULTI phrase only matches at the START of a name (`str.startswith`) — "Citizen of New Avalon" does NOT match a "New Avalon" MULTI entry (the tokenizer falls through to a mid-string single-token "Avalon" instead). No general fix implemented (would need substring/anywhere matching, higher false-positive risk) — just curate the bare fallback token too (done for Avalon).

## FIXED 2026-07-01 (this session) — both prior PENDING items closed
1. **Icon-material mismatch (validation A, was ~941 looks / 65400 items affected)**: root cause was `gen-worn-icons.py`'s `chosen` dict (and `worn_iconmap.tsv`, and `gen-worn.py`'s `ICONMAP`, and `gen-worn-itemdbc.py`'s `icon` map) all keyed by **look only**. Fixed all four to key by **(look, material)**:
   - `gen-worn-icons.py`: `chosen[(look,mat)]`; also precomputes `cross_material_looks` (a look used by >1 material in worn_groups.tsv) and denies those the "stock look already has an icon, skip" shortcut — a cross-material look ALWAYS gets a custom id per material even if the stock displayid has an icon (328 of the 941 were this case: shared stock icon, not iconless). Icon choice per (look,mat): donor icon only if `donor's own item_template.subclass == mat` (never borrow another material's donor icon), else the GEN[(material,slot)] fallback.
   - `worn_iconmap.tsv` format changed: 3 columns now `stock_look, material_id, custom_displayid` (was 2: `stock_look, custom_displayid`).
   - `worn_displayid_remap.sql`: UPDATE now scoped `AND subclass=<mat>` per row (was un-scoped by material).
   - `gen-worn.py`: `ICONMAP` keyed `(str(look), matkey)`; weapons never match (armor-only map) so fall through to stock look unchanged.
   - `gen-worn-itemdbc.py`: `icon` map keyed `(look, subclass)`; only applied for `cls=="4"` (armor) rows — weapons always use stock look.
   - Result: 6125 -> **7398** custom ItemDisplayInfo ids (110000-117397). Applied to PTR via a fast JOIN-vs-MEMORY-table UPDATE (LOAD DATA INFILE into a MEMORY temp table `_worn_iconmap`, then `UPDATE item_template it JOIN _worn_iconmap m ON m.stock_look=it.displayid AND m.material_id=it.subclass SET it.displayid=m.custom_displayid`) — 65400 rows in ~1s. **Validation query A now returns 0.**
   - IMPORTANT: before the JOIN-update, had to REVERT item_template.displayid back to the true stock look first (`UPDATE item_template it JOIN worn_drop_item w ON w.item_entry=it.entry SET it.displayid=w.item_displayid WHERE entry BETWEEN 400000 AND 699999 AND it.displayid<>w.item_displayid`) because the DB still held a STALE remap from an earlier (buggy, look-only-keyed) run — the new remap SQL's `WHERE displayid=<stock>` wouldn't match rows already sitting at an old custom id. **Gotcha for next time**: always check `SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 400000 AND 699999 AND displayid>=110000` before applying a fresh `worn_displayid_remap.sql` — if nonzero, revert-to-stock-via-worn_drop_item first.
2. **Sound (validation H)**: `.claude/dbc/ItemDisplayInfo_custom.csv` was stuck on a stale pre-sound-fix merge (6125 rows, ALL GroupSoundIndex=0). Rebuilt by taking `.claude/dbc/ItemDisplayInfo_custom.csv.bak` (confirmed to be the true pristine 16-row baseline: ids 100001-100016 only) + appending the fresh 7398-row `ItemDisplayInfo_worn_custom.csv` (all non-zero GroupSoundIndex). **Note**: `Item_custom.csv.bak` (in the same dir) is NOT a pristine baseline — it's a stale mid-session snapshot containing 132 non-worn rows (100001-100032 misc customs + AN UNRELATED 110000-110150 "reagent"/ClassID=15 Item.dbc block that coincidentally shares the 110000+ numeric neighborhood in a DIFFERENT dbc table/keyspace — Item.dbc IDs and ItemDisplayInfo.dbc IDs don't collide with each other). For Item_custom.csv, correctly rebuilt by filtering the CURRENT file to `id NOT BETWEEN 400000 AND 799999` (132 rows, verified identical to the `.bak`'s non-worn set) + fresh `Item_custom_worn.csv` (108632 rows). **Don't blindly trust `.bak` files as "pristine" — verify by diffing against the current file's non-worn-drops slice first.**

## Pipeline order (regen)
**Full regen (donors/bands/materials/looks changed)**: build-worn-slice.py (now resolves material PER (slot,look) via the real-item join + unit_class fallback — session 6) → build-worn-weapons.py → **build-worn-offhand.py** (shield + held-in-offhand, NEW in session 5 — replaces the earlier shield-only `build-worn-shields.py` draft, which no longer exists) → gen-worn-icons.py (produces worn_iconmap.tsv from worn_groups.tsv + **worn_offhand_groups.tsv**) → gen-worn.py (reads worn_iconmap.tsv via `ICONMAP`, writes the FINAL custom-or-stock displayid DIRECTLY into each INSERT's `displayid` column — no separate remap step needed for a full regen) → apply SQL to DB → THEN export `items.tsv` fresh from DB (`SELECT entry,class,subclass,Material,InventoryType,sheath,displayid FROM item_template WHERE entry BETWEEN 400000 AND 799999`, strip the 2 mysql warning header lines) → gen-worn-itemdbc.py. Output SQL = `data/worn_drops_scarlet.sql`. Client = `Item_custom_worn.csv` + `ItemDisplayInfo_worn_custom.csv` → merge into `.claude/dbc/`.
- **Naming-only re-run** (e.g. session 6's Leather/Mail BASE-dict fix, or any `worn_family_map.tsv`/naming-table edit with NO donor/material/look/schema change): just re-run gen-worn.py (full DELETE+reinsert is how this generator always works, there's no incremental name-only path) → re-apply the SQL → restart (no rebuild, no `items.tsv`/icon re-export needed since class/subclass/displayid columns are provably unchanged — diff `items.tsv` before/after to confirm if in doubt) → no MPQ delta (text only).
- **Material-pivot-shaped change (schema + per-row material)**: build-worn-slice.py → ... → gen-worn.py writes the NEW `worn_drop_display.material_id` column (needs the MySQL-8-safe PREPARE/EXECUTE idempotent ADD COLUMN, see Gotchas) → apply → **worldserver REBUILD required** (WD_Display's C++ tuple shape changed from pair to 3-tuple) → re-export `items.tsv` → gen-worn-itemdbc.py → re-merge `.claude/dbc/*` (icon churn — MPQ delta needed even if the custom-id COUNT went down, since which (look,material) pairs exist shifted).
- **Icon-only incremental re-run** (no stat/donor/look/material changes -- e.g. session 7's model-match quality pass): just gen-worn-icons.py (produces worn_iconmap.tsv + worn_displayid_remap.sql + ItemDisplayInfo_worn_custom.csv). **If the SET of (look,material) pairs needing a custom id is unchanged** (same custom-id count/range as before), the remap SQL will be a no-op (items already point at the right custom ids from a prior full regen) — verify by re-running it and confirming 0 rows affected before assuming so, don't just skip the DB step on faith. In that case the ONLY artifact that matters is the re-merged `.claude/dbc/ItemDisplayInfo_custom.csv` (icon field values changed within existing rows) — no SQL apply, no restart, no rebuild needed at all, purely a client MPQ content change. If the pair SET DID change (a full regen touched donors/materials/looks), use the JOIN-vs-MEMORY-table pattern for the remap (see Gotchas) same as any other targeted displayid change.
- After ANY regen that only changes `item_template`/`worn_drop_*` DATA (subclass, displayid, stats, new offhand rows, etc.): **restart** worldserver (no rebuild — table data only, even for a brand-NEW table like `worn_drop_offhand` since it's just SQL). After a **C++ change** to `src/mod_worn_drops.cpp` (tabard band/quality override, WD_Offhand roll, etc.): must **rebuild** the image (`docker compose --profile ptr build ac-worldserver-ptr && docker compose --profile ptr up -d ac-worldserver-ptr`), a plain restart reuses the stale binary.
- New data files (session 5): `worn_offhand_groups.tsv` (armor-shaped, same 13 columns as worn_groups.tsv, slot_idx∈{12=shield,13=held}) + `creature_worn_offhand.tsv` (4 cols: creature_entry,wslot,item_displayid,material_id — NOTE this is entry-keyed, NOT the `creature_worn.tsv`/`creature_worn_shields.tsv` shape which carries creature_display_id — do not confuse the two "creature_worn_*" naming patterns). `weapon_creature.tsv` gained a 4th column (`subclass`) this session — any script still assuming 3 columns there is stale.

## Family naming: two tiers (session 3, 2026-07-01 follow-up)
1. **Tier 1 = curated** (`worn_family_map.tsv`, 134 rows). Highest quality, always preferred when the look's dominant EN family token is in the map AND covers >=60% of DISTINCT wearers (deduped by name — see dedup gotcha below).
2. **Tier 2 = auto-derived** (`_common_ru_suffix_phrase()` in gen-worn.py). For a look whose dominant token is NOT curated but clears >=60% dominance AND has >=3 distinct wearers (`AUTO_MIN_WEARERS`), extract the LONGEST COMMON TRAILING WORD SEQUENCE shared by the wearers' own ruRU `creature_template_locale` names (stripping a leading из/с/со preposition). This works because WoW's RU localization convention places the faction reference at the END of an NPC name ("Рубака из легиона Огненного Клейма") and that trailing phrase is ALREADY grammatically genitive — tier 2 is pure EXTRACTION, never invented declension. Cross-validated: temporarily removing several tier-1 entries (Blackwing/Hammerfall/Hakkari/Wyrmcult/etc.) and re-running auto-derive alone reproduced IDENTICAL RU phrases, which is what built confidence to trust it in production.
3. **YO (ё) normalization — DECIDED OFF, 2026-07-01 (final).** History: mid-session-3 a `_apply_yo()` dictionary (е→ё on чёрный/тёмный/мёртвый/рождённый/закалённый roots) was added and briefly LIVE on PTR. Investigation proved this was NOT restoring "official" spelling — byte-exact Python check (NOT MySQL `LIKE '%ё%'`, which is a FALSE POSITIVE on this DB: default collation `utf8mb4_unicode_ci`/`0900_ai_ci` treats е/ё as equal for LIKE, so it falsely claimed 75% of item names had ё) showed neither `creature_template_locale` (17/25562 rows) nor STOCK `item_template_locale` (0/28936 entry<40000 rows — real Blizzard text is "Палица Черной горы", no ё) use ё anywhere in this corpus. **User's final decision (explicit): go WITHOUT ё, exactly matching the real WotLK original.** `_apply_yo()` is now a plain no-op passthrough (`def _apply_yo(s): return s`), left in place (call sites unchanged) purely so a future "turn it back on" ask is a one-line revert, but the `YO_WORDS` dictionary itself was REMOVED — do not add it back without an explicit new user request, and if this question ever resurfaces, remember the LIKE-collation trap above before re-litigating "does official text use ё". `worn_family_map.tsv`'s 6 entries that briefly had ё (Ebon Blade/Blackrock/Dark Iron/Murkblood/Frostborn/Death's Head/Frostmane/Darkspear/Ravenholdt/Dark Strand) were reverted to plain е. **One pre-existing, UNRELATED ё remains by design**: `WBASE[3] = ("Ружьё","Gun")` — dictionary-mandatory Russian spelling (predates this whole investigation, never touched, not part of any family/YO logic) — its presence in `_apply_yo` sweeps is expected and correct, not a bug.
4. **Dedup gotcha (found + fixed this session)**: `creature_template` often has ONE NPC/boss repeated across many entries (scripted clones, phase copies, holiday reskins like "Christmas High Botanist Freywinn" vs "High Botanist Freywinn" — 2 DIFFERENT name strings, 1 real entity). Counting raw entries (not distinct names) let a single repeated boss fake "63% dominant family" purely from row-count. Fixed in `_dominant_family` (EN side) and the RU-name list feeder in `build_look_family` by deduping on NAME before counting. Residual risk: a true 2-string alias of the same boss can still slip past the `AUTO_MIN_WEARERS=3` floor if it appears alongside 1-2 genuinely different NPCs — caught 5+ instances this session (Botanist Freywinn, Goraluk Anvilcrack, Farseer Grimwalker, Snivel Rustrocket, Rend Blackhand) by manually adding the leaking token to `FAMILY_STOP`; there's no fully general alias-detector (not implemented).
5. Both tiers, plus `FAMILY_STOP`/`FAMILY_MULTI` expansions and `worn_family_map.tsv` growth (88→134), are entirely in `modules/mod-worn-drops/scripts/gen-worn.py` + `worn_family_map.tsv`. No other script touched. No new displayids/ItemDisplayInfo minted by this work (naming-only) — the custom ItemDisplayInfo range stayed at 110000-117573 (7574 ids) unchanged from the prior session.

## DONE 2026-07-02 (session 11: EMPTY-LOOK / INVISIBLE ARMOR FIX)
User-reported bug: some equipped chest models render **invisible/transparent** (e.g. "Матерчатое
одеяние" from Alexandra Bolero, creature 1347, chest look 5440, items 462730-33, custom displayid
110725, InvType 20). Root cause: stock `ItemDisplayInfo` 5440 has NO `ModelName_1/2`, NO
`Texture_1..8` — only `GeosetGroup_2=1` — i.e. the dress is baked into the CREATURE's own skin
texture (`CreatureDisplayInfoExtra`), not into a transferable player-item displayid. A custom icon
copy (session 1's icon fix) can never fix this — it copies the SAME empty model/texture fields, it's
a renderability bug, not an icon bug.
- **Detection**: a look is EMPTY (unrenderable on a player model) iff it has no `ModelName_1`,
  `ModelName_2`, `ModelTexture_1`, `ModelTexture_2`, AND no `Texture_1..8`. **Gotcha caught mid-session
  (real, would have shipped a false-positive regression)**: the FIRST cut of this check only tested
  `ModelName_1`+`Texture_1..8`, which wrongly flagged **every stock cloak** as empty — cloaks render
  EXCLUSIVELY via `ModelTexture_1` (e.g. ID 23122 = `ModelTexture_1='Cape_Cloth_A_02Green'`,
  `Texture_1..8` all blank). Caught because the fix-up script found ZERO valid cloak donors left in
  the entire donor pool (749→603 affected items once `ModelTexture_1/2` was added to the check;
  Cape/Wrist dropped out of the affected-slot list entirely — they were never really broken). Final
  render-column list: `ModelName_1, ModelName_2, ModelTexture_1, ModelTexture_2, Texture_1..8`.
- **Real scope after the fix**: 603 live items / 23 distinct (slot,look) groups affected (not
  741/599-mostly-Cape as first estimated) — Chest 280, Gloves 176, Boots 100, Belt 40, Legs 4,
  Tabard 3 (a handful of tabards genuinely have neither channel either).
- **Fix mechanism (permanent, tier-3 of the resolution hierarchy — "problematic look → a REAL
  item's displayid")**: for an EMPTY look, the generated item's `item_template.displayid` is
  redirected to the DONOR's own displayid (the real white item of matching material+slot+band
  already chosen by the pipeline) instead of the stock look. `worn_drop_item.item_displayid` still
  stores the TRUE original stock look unchanged (source-of-truth contract preserved) — only the
  actually-rendered `item_template.displayid` changes. No custom ItemDisplayInfo is minted for an
  empty look at all (would be wasted/orphaned, never referenced).
  - `build-worn-slice.py`: added `EMPTY_DISPLAY` (ItemDisplayInfo ids with neither channel) computed
    alongside `has_model`; donor-pool collection loop now excludes ANY donor whose OWN displayid is
    in `EMPTY_DISPLAY` (a donor that can't render itself is worthless as an empty-look substitute).
  - `gen-worn.py`: `EMPTY_LOOKS` set (same definition) checked in `emit_group`'s `dlook` computation
    — if `look in EMPTY_LOOKS`, `dlook=None`; `int_overrides(look=None, ...)` then OMITS the
    `displayid` key from its override dict entirely, letting the bare `displayid` column reference
    in the `INSERT...SELECT` fall through to the DONOR's own value.
  - `gen-worn-icons.py`: same `EMPTY_LOOKS` set; the main loop `continue`s immediately for any
    `(look,material)` pair whose look is empty — no icon tier logic runs, nothing is minted.
  - All 3 scripts compute `EMPTY_DISPLAY`/`EMPTY_LOOKS` independently (no shared module, matches this
    pipeline's existing convention) — if this definition ever needs a 4th render channel added,
    update all 3 in lockstep.
- **A SECOND, deeper bug found mid-fix (donor pool itself had junk)**: the existing `_JUNK`
  substring stoplist (`"[ph]","(ph)","proxy","image","[chapter","[dep","[test","(test","dummy",
  "trigger","unused","deprecated"`) was being matched, but it only catches BRACKETED test markers
  (`[test]`/`(test)`) — 14 stock white Plate chest items literally named `Test Defense Chest`/`Test
  Armor Chest`/.../`Test Quality Modifier Chest` (no brackets) all share displayid 15897, which is
  ALSO a real Mail chest item's stock displayid elsewhere in the game → picking one of these as a
  donor produces a live icon/material mismatch the moment the substitute is applied (caught by
  validation check A regressing to 1 after the first live apply: entries 462900-903, band 70, look
  5440 again but at Plate this time, got redirected to displayid 15897 shared with a real subclass=3
  Mail item at 485200-213 — a genuine PRIME DIRECTIVE violation, not a false alarm). Fixed by adding
  a WORD-BOUNDARY regex `\btest\b` (case-insensitive) to the donor-pool filter (NOT a bare substring
  — `"Contest Winner's Tabard"`, entry 19160, is a REAL item and must not be excluded just because it
  contains "test" as a substring). Re-ran the live-DB targeted patch after this fix; the 4 affected
  entries now correctly land on displayid 26658 (`PVP Plate Breastplate Alliance`, a real Plate
  chest). **Lesson**: a junk/deprecated-name stoplist built for one purpose (originally tabard-only)
  can have blind spots when its scope is later widened to a different item population — always
  re-derive the actual name patterns present in the NEWLY-included population rather than assuming
  the existing token list is complete.
- **Live-DB targeted patch (not a full 200k-item regen)** built in scratchpad
  (`fix_empty_looks2.py`, reusable pattern: `exec(compile(build-worn-slice.py's prefix up to "#
  ---------- Pass 1:", ...))` to reuse the FRESHLY-FIXED `donors`/`pick_donor()`/`EMPTY_DISPLAY`
  globals with zero side effects — this is more robust than trying to recompute an equivalent donor
  pool by hand, and automatically stays in sync with any future donor-filter change in
  `build-worn-slice.py`). For each live `worn_drop_item` row whose stock look is empty, calls the
  SAME `pick_donor(slot, material, band)` the original generator would use, resolves the donor's
  live displayid, and emits a plain `UPDATE item_template SET displayid=... WHERE entry=...`.
  `worn_groups.tsv` (session 9's TSV snapshot) was NOT used for this — it's stale relative to session
  10's plate-override partial regen and would have produced 248 missing-donor lookups; going through
  `pick_donor()` directly avoids depending on any stale intermediate TSV at all.
- **Applied to acore_world_ptr** (`--default-character-set=utf8mb4`, wrapped in
  `SET autocommit=0; ...; COMMIT;`) — 603 UPDATE statements, applied twice (first pass had the 4
  bad-donor rows from the `\btest\b` bug above, caught by re-running check A before declaring done,
  second pass after the junk-filter fix corrected exactly those 4 and left the other 599 unchanged/
  idempotent).
- **Client CSV updates**: `Item_custom.csv` — 603 rows' `DisplayInfoID` column updated to match.
  `ItemDisplayInfo_custom.csv` — 27 now-fully-orphaned custom ids removed (110272-81, 110664-65,
  110725-28, 110817-20, 110949, 111069-70, 111375, 115454-55, 125402 — confirmed via a live-DB
  `COUNT(*) WHERE displayid IN (...)` query returning exactly 0 remaining references for all 27
  before removal); `worn_iconmap.tsv` had the same 27 rows removed for consistency (16136→16109).
  Two of the pre-fix displayids on affected items were STOCK ids used directly (224, 3506 — passed
  session 7's "stock look has an icon" tier-1 check despite being renderability-empty; NOT customs,
  nothing to remove from the CSV for those, just no longer referenced).
- **New validation check T** (see validation.md): zero generated armor items whose LIVE displayid
  (post-fix) points at an ItemDisplayInfo row (stock OR custom, union of both CSVs) with no
  render channel. Ran clean (0/179476) after the fix. Re-ran A/B/C/D/E/F/K/O/R (all 0) and the two
  DB↔CSV orphan checks (S-pattern, both directions, both CSVs) — all 0 after the corrected apply.
- **worldserver restarted** (data-only fix, no C++ touched) — clean boot, boot log line unchanged
  in shape (`... 2094 plate-overrides, 200204 items.`), zero worn-drops errors.
- **Verified the exact reported case**: items 462730-33 now resolve to displayid 22033
  ("Gamemaster's Robe", real Cloth robe, InvType 20, has full `Texture_1..8`). Spot-checked 4 more
  affected looks across different slots — Belt→17126 (`Rough Leather Belt`, Leather), Boots→16854
  (`Soft Fur-lined Shoes`, Cloth), Gloves→14482 (`Russet Gloves`, Cloth), Tabard→20621 (`Guild
  Tabard`, subclass 0) — all real, renderable, material-correct.
- **MPQ rebuild needed**: YES, stated clearly to the user — 603 items changed their live displayid
  (Item.dbc DisplayInfoID) and 27 custom ItemDisplayInfo rows disappeared. Small in absolute item
  count relative to the full 200k catalog, but the merged CSV files are monolithic so the rebuild
  covers the whole file regardless — same one-more-rebuild-needed framing as every prior session's
  MPQ-affecting change.

## SUPERSEDED same day (2026-07-02, session 11 follow-up): donor-substitution REVERSED to REMOVAL
User decision, verbatim rationale: **«предмет будет дропаться не валидный»** — a drop whose
rendered look no longer matches the NPC it came from is worse than no drop at all. Coordinator
framed this as "same philosophy as the earlier no-FillMissingSlots / Morbent-Fel precedent" —
**NOTE: searched `project_worn_armor_drop.md` and all other accessible memory for this precedent
and found no record of it; it may live in a different agent's history/session not visible here.**
Not re-verified independently — recorded as the coordinator's stated rationale, taken at face
value. The operative rule either way: if a look is not transferable to a player model, it must not
be dropped, full stop — not "dropped with a different look instead". This REVERSES the donor-
substitution mechanism described in the section above; the DETECTION work (EMPTY_DISPLAY/
EMPTY_LOOKS, the union-of-3-render-channels definition, the `\btest\b` junk-donor word-boundary
fix) all stayed exactly as designed and remains valuable — only the disposition of an empty look
changed, from "substitute a donor's displayid" to "never generate at all".
- **DB (acore_world_ptr)**: the same 603 items (23 (slot,look) groups) were fully DELETED —
  `item_upgrade_chain` (450 rows, WHERE `entry` IN the 603), `item_template_locale` (603),
  `worn_drop_item` (603), `item_template` (603), and `worn_drop_display` (375 rows, matched by
  `(slot, item_displayid)` tuple IN the 23 pairs — this is what stops the runtime from ever rolling
  that slot for that creature_display_id; the creature still drops normally from its OTHER worn
  slots). Applied with `--default-character-set=utf8mb4`, wrapped in one
  `SET autocommit=0; ...; COMMIT;` transaction. **Noted to the user as expected/accepted**: any BoP
  copies of these 603 entries already sitting in a PTR tester's bags will simply vanish (item_entry
  no longer exists) on next login/inventory refresh — acceptable on PTR, not attempted to be
  cleaned up in `acore_characters` (out of scope, different DB, coordinator's own instruction did
  not ask for it).
- **Pipeline (permanent)**: `build-worn-slice.py`'s Pass 1 (`raw_rows` collection, the very first
  stage) now does `if str(app) in EMPTY_DISPLAY: continue` for EVERY slot (not just MODEL_SLOTS'
  head/shoulder check) — an empty look never becomes a `worn_drop_display`/`worn_groups.tsv` row at
  all for any FUTURE full regen. `gen-worn.py`'s `emit_group()` donor-substitution branch was
  replaced with a **defensive `assert str(look) not in EMPTY_LOOKS`** (should be structurally
  unreachable now that Pass 1 filters at the source; firing would mean a NEW code path is feeding
  an empty look into generation and needs a Pass-1-level fix, not a patch in `emit_group`).
  `gen-worn-icons.py`'s pre-existing "skip minting for an empty look" behavior needed no change (it
  was already "skip", never "substitute" — only `gen-worn.py` had implemented actual substitution).
  Re-ran `build-worn-slice.py` end-to-end as a smoke test (does NOT touch the live DB, TSV output
  only) — confirmed 0/0 for all existing invariant counts (Plate-below-40, donor coverage 40964/
  40964 groups matched) and confirmed by direct grep that all 23 previously-affected (slot,look)
  pairs (e.g. `4 Chest 5440`) are now completely ABSENT from the freshly generated
  `worn_groups.tsv` — the Pass-1 filter works as designed.
- **Client CSVs**: `Item_custom.csv` — removed the same 603 rows entirely (200336→199733 rows); the
  27 orphaned `ItemDisplayInfo_custom.csv` rows were ALREADY removed by the (now-reversed)
  substitution work and did not need touching again (16125 rows, unchanged by this reversal).
- **Validation**: A-F/K1/K2/O/R all reconfirmed 0. Both S-pattern DB↔CSV orphan checks (custom
  ItemDisplayInfo id set, full item entry set) reconfirmed 0/0 both directions. Check T reconfirmed
  0/0 (trivially — there are no more empty-look items to violate it). **Final totals**: armor
  178,873 (was 179,476, -603 exact) + weapon 20,728 (unchanged) = **199,601 total** (matches the
  coordinator's predicted ~199,601 exactly). Alexandra Bolero's display 1497 confirmed to have NO
  chest row in `worn_drop_display` (slot=4 count=0) while belt(5)/legs(6)/boots(7) rows are all
  still present at material=1(Cloth); items 462730-33 confirmed gone from `item_template` (count=0).
- **worldserver restarted** (data-only, no C++ change) — clean boot, new boot log line:
  `mod-worn-drops: loaded 12878 scope, 13264 displays, 2437 tabard-maps, 10306 weapon-maps, 1490
  offhand-maps, 2094 plate-overrides, 199601 items.` **Gotcha worth noting**: `displays`
  (`WD_Display.size()`) and `tabard-maps` (`WD_Tabard.size()`) are counts of DISTINCT
  `creature_display_id` KEYS (map size), not `worn_drop_display` ROW counts — `WD_Display` is
  `unordered_map<uint32, vector<tuple<...>>>` (one display can hold several slot rows in its
  vector), so removing ONE slot's row from a display that still has OTHER slots does not shrink
  `WD_Display.size()` at all (confirmed: `displays` stayed at 13264, identical to session 10, even
  though 322 non-tabard `worn_drop_display` rows were deleted) — while `WD_Tabard` is effectively
  1 row per display (a display can have at most one tabard row by construction), so its count DOES
  move 1:1 with row deletions (2490→2437, -53, matching the tabard portion of the 375 removed
  `worn_drop_display` rows). Don't read `displays`/`tabard-maps` boot-log deltas as row-count deltas
  without checking which map shape backs each field.
- **MPQ rebuild**: still needed (same underlying CSV files touched, now via removal instead of
  substitution) — no additional/new rebuild beyond what was already stated for the substitution
  attempt; this just changes WHAT changed within the files (603 rows now gone entirely from
  `Item_custom.csv` rather than having a different DisplayInfoID value).

## DONE 2026-07-02 (session 12: BALANCE PASS -- boss multiplier, lower trash chances, global float quality weights)
User-approved balance changes, C++ + config only, NO SQL/DB/data change, **zero client CSV delta**
(confirmed: no `.claude/dbc/*` file touched, `git status`/`git diff --stat` on those files showed
no additional change beyond what session 11 had already staged before this session started).
1. **`WornDrops.BossMultiplier`** (new, float, default **4.0**): on a boss kill, multiplies ALL 3
   independent roll chances (armor `WD_Chance`, weapon `WD_WeaponChance`, tabard `WD_TabardChance`)
   by this factor, each individually capped at 100%. Boss detection:
   `killed->IsDungeonBoss() || killed->isWorldBoss()` — both confirmed to exist exactly as named on
   `Creature` (`src/server/game/Entities/Creature/Creature.h`): `isWorldBoss()` is an inline check on
   `CREATURE_TYPE_FLAG_BOSS_MOB`, `IsDungeonBoss()` is declared here and defined elsewhere in core
   (scripted-instance-boss detection) — ORed since either alone misses a real boss category. Applied
   as 3 new locals (`effChance`/`effWeaponChance`/`effTabardChance`) computed ONCE near the top of
   `OnPlayerCreatureKill`, used everywhere `WD_Chance`/`WD_WeaponChance`/`WD_TabardChance` used to be
   read directly in the 3 roll `if` conditions — the raw globals themselves are untouched by the
   multiplier (only the effective per-kill locals are), so `WD_Chance` etc. always still reflect the
   pure config value if inspected/logged elsewhere.
2. **Trash-drop chances lowered** (prod `.conf.dist` defaults AND the hardcoded `GetOption` fallback
   defaults in `LoadConfig()`, kept in lockstep as always in this module): `WornDrops.Chance`
   30→**15**, `WornDrops.WeaponChance` 10→**5**. `WornDrops.TabardChance` unchanged (5). Combined
   with item 1: prod boss kill = 60/20/20 armor/weapon/tabard (15×4/5×4/5×4).
3. **Quality weights switched int→FLOAT and changed to a new GLOBAL distribution 90/7/2.7/0.3**
   (was 70/25/4/1) — `WD_QWeight[4]` is now `float[4]`, `RollQuality()` now sums as float and rolls
   via `frand(0.0f, total)` instead of `urand(1, total)` (an int roll cannot represent the 2.7/0.3
   fractional weights at all). **Mid-session correction, IMPORTANT**: the ORIGINAL ask (from the
   coordinator's first message this session) was for this to be a SEPARATE, INSTANCE-ONLY
   distribution (`WornDrops.Dungeon.Quality.*`, gated on `map->IsDungeon() || map->IsRaid()`, open
   world keeping the old 70/25/4/1) — investigated the exact AC API
   (`Map::IsDungeon()`/`Map::IsNonRaidDungeon()`/`Map::IsRaid()` all exist in `src/server/game/Maps/Map.h`
   lines 295-297, confirmed `IsDungeon()` does NOT include raids, they're genuinely separate map-type
   predicates needing an explicit OR) but this was SCRAPPED before implementation by a follow-up
   correction: the user decided 90/7/2.7/0.3 should be the single GLOBAL distribution everywhere,
   open world and instances alike — **there is no map-type branch anywhere in this module**, and no
   `WornDrops.Dungeon.Quality.*` config key exists. If a future session is asked to "add back"
   instance-specific quality weights, the `Map::IsDungeon()/IsRaid()` API investigation above is
   already done and can be reused directly.
- **Config echo log line added** (new, in `LoadConfig()`, fires on every config load/reload): `mod-
  worn-drops: config chance=X% weaponChance=X% tabardChance=X% bossMultiplier=Xx
  quality(white/green/blue/epic)=X/X/X/X` — makes it possible to confirm the ACTUAL effective values
  from the boot log alone, without a DB query or an in-game kill (useful precedent: the existing
  boot log line only ever reported table ROW COUNTS from `LoadData()`, never the config values
  themselves from `LoadConfig()` — this is the first time this module echoes config, worth keeping
  the pattern for future config additions too).
- **Config files updated**: `modules/mod-worn-drops/conf/mod-worn-drops.conf.dist` (prod defaults:
  Chance=15, WeaponChance=5, TabardChance=5, BossMultiplier=4.0, Quality.White/Green/Blue/Epic=
  90/7/2.7/0.3, full doc comments for all 3 new/changed keys). `env/dist/etc-ptr/modules/mod-worn-drops.conf`
  (PTR TEST conf): kept drop-all (Chance/WeaponChance/TabardChance=100, PerKill=0, LevelDiffMax=0)
  — BossMultiplier's effect is invisible here since 100%×4.0 still caps at 100%, but it's set to the
  real prod value (4.0) anyway so the `IsDungeonBoss()/isWorldBoss()` CODE PATH itself still executes
  and is exercised on PTR; Quality weights DELIBERATELY set to the real prod 90/7/2.7/0.3 (not further
  test-ified) so the user can observe the true distribution shape while drop-rate testing.
- `modules/mod-worn-drops/README.md`'s quality/chance-defaults line updated to match (it was
  already stale before this session, documented an old "70/15/10/5" shape that didn't even match
  any real historical config state — only the specific line was fixed, not a full README rewrite,
  out of scope for this session).
- **Verification**: clean rebuild (`docker compose --profile ptr build ac-worldserver-ptr`, 0
  warnings/errors related to this module) + restart. Boot log confirms: `mod-worn-drops: config
  chance=100.0% weaponChance=100.0% tabardChance=100.0% bossMultiplier=4.0x
  quality(white/green/blue/epic)=90.0/7.0/2.7/0.3` (exactly the new PTR conf values) followed by the
  unchanged data-load line `... 199601 items.` (proves zero DB/data impact — same total as session
  11's end state). **Not verified in-game** (spawning/killing a dungeon-boss-flagged creature
  headless on PTR wasn't attempted — cheap code-path review + the config echo above is what was
  actually checked, per the coordinator's own framing of what would be "enough").

## DONE 2026-07-02 (session 13: ROBE-VOTE fix + FLAGS SANITIZATION -- two combined bugs)
**IMPORTANT CONTEXT**: this session ran while `ac-worldserver-ptr` was on a TEMP DEBUG image (WD-DEBUG
log lines added by the coordinator for an unrelated weapon investigation) — per explicit instruction,
NO C++ was touched and NO image rebuild was performed; both fixes are 100% generator+SQL, finished
with plain `docker compose --profile ptr restart` calls (never `build`).

### Fix 1: ROBE-VOTE (Darkmaster Gandling, entry 1853, displays 11070/15732)
Root problem: a robed caster's UNDER-ROBE pieces (sleeves/hands/feet) are frequently textured with a
semantically-meaningless Blizzard-reused Mail_/Leather_/Plate_ prefix (color/palette reuse, not a
real material signal), while the actual ROBE texture on chest/legs (or a Helm_Robe_*/Robe model on
head) — the TRUE identity of the outfit — contributed NOTHING to the material vote (looks flagged
`robe_looks` were excluded from `art_material_of` for being cross-material-ambiguous, and only ever
consulted as a last-resort residue fallback for displays with ZERO other evidence). Gandling's own
vote was leather×4 vs plate×4 (a dead tie from pure under-robe noise) despite unambiguous robe
identity on 2 of his 7 slots.
- **Calibration** (same ≥85%/n≥5 bar this file already uses for the hunter-token calibration,
  measured against REAL stock items sharing a robe-flagged displayid): CHEST invtype 97.7% Cloth
  (n=386), LEGS invtype 87.2% Cloth (n=156), HEAD model-based 93.8% Cloth (n=144) — all clear the
  bar. No systematic non-Cloth robe "family" found among the exceptions (isolated 1-3-item cases).
  Shoulder (95.8%, n=260) would also clear the bar but was deliberately NOT included — kept to
  exactly chest/legs/head, the 3 slots where "robe" is a coherent real-world garment concept.
- **Implementation** (`modules/mod-worn-drops/scripts/build-worn-slice.py`): new `ROBE_VOTE_SLOTS =
  {1,4,6}` (head/chest/legs); `evidence_for(slot, look)` now checks `str(look) in robe_looks` for
  these 3 slots (between the `art_material_of` check and the `resolve_real_material` fallback),
  returning `(1, "robe")` — a brand new evidence tier. `EVIDENCE_TIER_WEIGHT["robe"] = 50` (vs
  `art=3`, `real=1`) — DOMINANT but still a vote contribution, not a hardcoded override (a real
  display could theoretically still be outvoted by overwhelming contrary evidence across many other
  slots, by design, consistent with every other material signal in this pipeline). The pre-existing
  residue-rule check in `archetype_material()` (robe_looks at ANY slot, for zero-evidence displays)
  was deliberately left UNCHANGED — it still covers the narrower case of a robe-tagged look at a
  non-{head,chest,legs} slot with no other evidence at all.
- **Scope measured**: 1112 displays flip material (817 Leather→Cloth, 201 Plate→Cloth, 94
  Mail→Cloth — ALL flips converge to Cloth, provably so since robe evidence only ever ADDS Cloth
  weight, never removes existing evidence) + 1201 displays that went from ZERO evidence (would have
  used the archetype/progression fallback) to HAVING evidence directly via robe. 4409
  `worn_drop_display` (display,slot) rows needed a material UPDATE (3011 Leather→Cloth, 925
  Warrior-Prog(sentinel)→Cloth, 473 Mail→Cloth). 2331 NEW (slot,look,band,Cloth) groups needed
  generation (9324 item_template rows, x4 quality) — this number is an EXACT match to the item-level
  Cloth delta independently computed from a full fresh `build-worn-slice.py` run (62580→71904,
  Δ=9324), a strong cross-check that the additive approach captured the fix completely.
- **Live-DB mechanics (PURE APPEND, no renumbering, no full regen)** — same established pattern as
  session 10's `gen-worn-plate-override.py`: `build-worn-slice.py` re-run fully first (writes fresh
  `worn_groups.tsv`/`creature_worn.tsv` reflecting the NEW resolution for the ENTIRE catalog), then a
  dedicated scratchpad delta script (1) reused `build-worn-slice.py`'s exec-prefix (cut at
  `"# ---------- Pass 3:"`) to get the freshly-computed `display_material` dict and diffed it
  against the LIVE `worn_drop_display` table to produce `robe_fix_display_updates.sql` (plain
  per-row UPDATEs); (2) diffed fresh `worn_groups.tsv` against live `worn_drop_item`'s distinct
  (look,slot,band,material) key set to find the 2331 missing groups; (3) minted 849 new custom
  ItemDisplayInfo icons via `gen-worn-icons.py`'s real tier-chain (exec-prefix, read-only); (4)
  emitted the actual item_template/locale/upgrade_chain/worn_drop_item rows by calling `gen-worn.py`'s
  REAL `emit_group()` function (not a hand-duplicated simplified copy) at a fresh live high-water
  mark (`next_bi` computed from `MAX(entry)`, never hardcoded), entries 849860-873163.
- **A real near-miss caught by reviewing the generated SQL before applying, not by any assertion**:
  the FIRST attempt exec'd `gen-worn.py`'s prefix cut at `"# ---------- ARMOR ----------"` (intending
  to get `emit_group`/`armor_look_family` cleanly) — but gen-worn.py's HEADER section (which queues
  the FULL-REGEN `DELETE FROM item_template WHERE entry BETWEEN 400000 AND 1099999` + 4 more
  DELETEs into the SAME `out` list this script harvests) sits BEFORE that marker, not after. Exec'ing
  past it silently accumulated those catastrophic DELETEs into the "pure append" SQL file. Caught by
  eyeballing the generated SQL's head before applying (a hard-learned habit from this whole project's
  history) — fixed by cutting at the EARLIER `"# ---------- header ----------"` marker instead
  (before ANY `w()` calls fire) + asserting `out`/`item_map`/`chain_rows` are all empty at that cut
  point, + manually rebuilding `armor_look_family` (normally built AFTER the header, from
  creature_worn.tsv) via the still-available `build_look_family()` function + `CW` path constant.
  **Lesson for any future partial-regen script that reuses gen-worn.py's `emit_group()` via
  exec-prefix: the cut marker MUST be `"# ---------- header ----------"`, never `"# ---------- ARMOR
  ----------"` (or later) — ALWAYS review the generated SQL's head for stray DELETE/CREATE TABLE
  statements before applying, regardless of how carefully the cut point was chosen.**
- **Client CSVs**: `Item_custom.csv` +9324 rows (new item entries, DisplayInfoID = each item's own
  final `item_template.displayid`, already correct — no separate icon-lookup logic needed since
  `emit_group()` already resolved the correct displayid at generation time). `ItemDisplayInfo_custom.csv`
  +849 rows (the newly-minted custom icons). **Gotcha confirmed while merging**: this repo's
  `.claude/dbc/Item_custom.csv` / `ItemDisplayInfo_custom.csv` are SHARED across multiple unrelated
  systems (Gear Ascension, Familiars, Nemesis, StatBooster, etc., not just worn-drops) — a
  worn-drops-only row-count expectation (e.g. "should be ~199733 + 9324") will NOT match the file's
  TOTAL row count; always filter to the `entry`/`ID` BETWEEN 400000 AND 1099999 sub-range before
  comparing against worn-drops' own DB counts (confirmed exact match: 208925 rows in-range == live
  DB's exact item_template count in that range, 0 duplicates, 0 orphans either direction via check S).
- **Verified end-to-end**: Gandling's BOTH displays (11070, 15732) now show `material_id=1` (Cloth)
  for EVERY slot (head/shoulder/chest/belt/legs/boots/gloves) in `worn_drop_display` — full
  unification confirmed, "«Матерчатый...» set" as expected.
- **Validation**: A/B/C/D/E/F/K1/K2/L/M/M-sentinel/O/R all 0. Both S-pattern DB↔CSV orphan checks
  0/0 both directions. Check T 0/0. `MAX(entry)` for armor = 873163 (<999999, still safe headroom).

### Fix 2: FLAGS SANITIZATION ("Merle's sword never drops" bug, items 1010210-13)
Root problem (found by the coordinator via live runtime debug logging, independently confirmed here
via a full Flags audit): `emit_group()`'s `INSERT...SELECT ... FROM item_template WHERE entry=<donor>`
copies the donor's raw `Flags` column VERBATIM (never in `int_overrides()`'s override dict, so it
falls through to the bare `` `Flags` `` column reference). Merle's sword items inherited
`Flags=2048=ITEM_FLAG_MULTI_DROP` ("looting this item does not remove it from available loot", an
FFA-loot flag) — FFA items are only ever added to a player's PERSONAL FFA list during the corpse's
INITIAL `FillLoot`; this module adds items AFTER that (`OnPlayerCreatureKill` runs post-kill), so a
MULTI_DROP-flagged item lands in `loot.items` (genuinely added, confirmed via debug logs) but is
NEVER placed in anyone's FFA list — permanently invisible in the loot window despite being real data.
- **Full audit of every distinct Flags value actually present** across the WHOLE 400000-1099999
  range on acore_world_ptr (not just the coordinator's spot-check) — a blacklist approach (strip
  known-bad bits) was chosen over a zero-everything whitelist, since a whitelist risks silently
  clobbering a legitimate donor trait from a future, not-yet-seen donor:
  - `0x001 NO_PICKUP` — 0 items observed, stripped anyway (defensive: worse than MULTI_DROP if it
    ever occurs — a picked-up drop item that can't be picked up at all).
  - `0x002 CONJURED` — 104 items observed. **A SECOND, independently-confirmed real bug**, found
    auditing this same column: `PlayerStorage.cpp`'s `proto->HasFlag(ITEM_FLAG_CONJURED)` check
    (line ~6105, UNCONDITIONAL, not gated by item class) deletes the item from a player's inventory
    on next login if offline >15 minutes — a silent equipped-gear data-loss bug for any of these 104
    items a player happened to loot. STRIPPED.
  - `0x004 HAS_LOOT` — 0 items observed, stripped anyway (defensive, nonsensical for armor/weapons).
  - `0x010 DEPRECATED` — **5384 items observed** (16 alone: 5272; combined w/ CONJURED as 18: 104;
    combined w/ MULTI_LOOT_QUEST as 272: 8) — by far the most numerous flag found, NOT previously
    flagged by the coordinator. Documented "cannot equip or use" but `grep`-confirmed ZERO
    server-side enforcement anywhere in this AzerothCore fork (vestigial on this codebase, likely
    only a retail-client legacy-content filter) — not a CONFIRMED currently-dangerous bit, but
    semantically wrong for a freshly-generated item (it is definitionally not deprecated) and pure
    donor noise. STRIPPED for correctness/cleanliness (own judgment call, reported per the
    coordinator's explicit invitation to "judge each bit").
  - `0x100 MULTI_LOOT_QUEST` — 8 items observed (always combined with DEPRECATED). Documented "NYI"
    (not yet implemented anywhere in this fork) — inert, stripped for the same donor-noise reason.
  - `0x800 MULTI_DROP` — 344 items observed. THE original bug. STRIPPED.
  - `0x400000 NO_DURABILITY_LOSS` — 172 items observed, "some Thrown weapons have it (and only
    Thrown) but not all" per the enum comment — a plausible, harmless, CORRECT trait for a
    same-category Thrown-weapon donor copy, no confirmed or plausible bug mechanism. **KEPT.**
  - Final mask: `FLAGS_STRIP_MASK = 0x1|0x2|0x4|0x10|0x100|0x800 = 0x917 = 2327` (note: the
    coordinator's own tentative "0xB07??" guess in their report was NOT the correct OR of their own
    named bits — 0x1|0x2|0x4|0x800 = 0x807, and adding 0x10|0x100 for the 2 extra bits this audit
    found gives 0x917; used the CORRECTLY COMPUTED value, not either guess).
- **Permanent fix** (`gen-worn.py`): new `FLAGS_STRIP_MASK` constant (full bit-by-bit audit comment
  at its definition site). `emit_group()`'s per-column SELECT-list builder special-cases `c=='Flags'`
  to emit `` (`Flags` & ~2327) `` as a SQL expression (computed by the DATABASE against the donor's
  own Flags column at INSERT...SELECT time) instead of the bare column reference — applies
  UNIFORMLY since `emit_group()` is the ONE function used for armor, weapon, shield/held-offhand,
  AND tabard generation (all 4 call sites automatically covered, no per-path special-casing needed).
- **Live-DB data fix**: single blanket `UPDATE item_template SET Flags = Flags & ~2327 WHERE entry
  BETWEEN 400000 AND 1099999 AND (Flags & 2327) <> 0` — covers pre-existing items, THIS session's
  2331 new robe-fix groups, AND all weapons in one statement (idempotent, safe to re-run). 5728 rows
  affected (5272+344+104+8, matching the audit breakdown exactly). Combined into
  `worn_drops_robe_fix.sql`'s tail (same live-promotion delta file) for a future live promotion,
  alongside a note that `robe_fix_display_updates.sql` must be applied together with it.
- **New validation check U**: `SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 400000 AND
  1099999 AND (Flags & (0x1|0x2|0x4|0x10|0x100|0x800)) <> 0` — MUST be 0. Confirmed 0 after the fix;
  Merle's sword (1010210-13) confirmed `Flags=0`.
- **worldserver restarted TWICE this session** (once after the robe-fix DB apply, once more after
  discovering+fixing the Flags bug) — both plain `restart`, NO rebuild (per explicit instruction, the
  TEMP WD-DEBUG image must survive untouched for the coordinator's separate weapon investigation).
  Final boot log: `mod-worn-drops: loaded 12878 scope, 13264 displays, 2437 tabard-maps, 10306
  weapon-maps, 1490 offhand-maps, 2094 plate-overrides, 208925 items.` clean, zero errors.

### MPQ rebuild for session 13
YES, needed — 9324 new Item.dbc rows + 849 new custom ItemDisplayInfo rows (robe-fix). The Flags
sanitization fix has **ZERO client CSV impact** (Item.dbc/ItemDisplayInfo.dbc don't carry the Flags
field at all in this client version — Flags is server-side-only, delivered via
SMSG_ITEM_QUERY_SINGLE_RESPONSE — confirmed by `Item_custom.csv`'s own 8-column header having no
Flags column). Bundle with any other pending rebuild as always.

## PENDING (backlog, most important first)
-1a. **[session 15, NEW] User needs ANOTHER MPQ rebuild + Cache/WDB clear** — 8,292 new `Item_custom.csv`
  rows (entries 873170-893923) + 686 new `ItemDisplayInfo_custom.csv` rows (ids 126985-127670,
  post-orphan-cleanup) from the armor `type==7` scope-widening fix. Bundle with any prior
  not-yet-rebuilt delta (this module has needed a rebuild after nearly every session — always ask
  "has the user rebuilt MPQ since the LAST reported session totals" before assuming it's covered).
-1b. **[session 15, NEW] Armor ID-range budget is now 82.3% utilized (49,393/60,000 groups, MAX(entry)=
  893,923 of the 999,999 ceiling)** — comfortably safe today, but the LAST 3 scope-widening sessions
  (9, 10, 15) have each consumed a meaningful chunk; the NEXT one (weapon-side ALL-type scan
  extending similarly, or another armor scope relaxation) should check this number FIRST and
  consider widening `ARMOR_GROUP_CAP`/`ARMOR_BASE`'s range (mirroring the exact ERROR-1062-avoidance
  workflow already documented in gen-worn.py's ID RANGE header comment) before generating, not after.
-1c. **[session 15, NEW, low priority] 164 stale `worn_drop_scope` rows point at a creature with ZERO
  real armor evidence** (pre-dates evidence-gating, e.g. entry 98 "Riverpaw Taskmaster", a Gnoll) —
  harmless (wastes an armor-roll chance, produces nothing) but worth a `DELETE FROM worn_drop_scope
  WHERE creature_entry NOT IN (<creatures with >=1 real worn_drop_display/worn_drop_offhand row>)`
  cleanup pass sometime. See state.md SESSION 15 for the full list/mechanism.
-1d. **[session 15, NEW, low priority] At least 1 obviously-QA/test creature (entry 128 "Angry
  Programmer Tweedle Dee", type=10, no bracket/junk-word in its name) is now in armor scope** —
  the `_JUNK` stoplist only catches bracket/parenthesis-wrapped or single-keyword test markers; a
  broader "internal/dev NPC" naming audit (of the newly-widened 823-creature population, and
  possibly the pre-existing 12,878 too) could catch more of these. Not harmful (correct item-type
  consistency regardless), just content hygiene.
0. **[session 9, NEW #1 priority] User needs ANOTHER MPQ rebuild + Cache/WDB clear** — covers session 9's material redesign (custom ItemDisplayInfo now 110000-124066, 14,067 ids, +7,756 vs session 8's 6,311; thousands of looks re-materialized, e.g. every look that used to fall back to a generic Plate/Cloth icon for a now-Leather/Mail item). This is on top of, not instead of, the sessions 5-8 MPQ delta (item #1 below) if the user hasn't already done that one. **SUPERSEDED AGAIN by session 11** (see below) — one further rebuild is needed on top of everything already accumulated; the custom ItemDisplayInfo id SET shrank slightly (-27, now capped below 126135, some ids in the 110000-125402 range removed) and 603 `Item_custom.csv` DisplayInfoID values changed.
0d. **[session 11, NEW, UPDATED same day after the removal reversal] User needs ONE MORE MPQ rebuild + Cache/WDB clear** for the empty-look/invisible-armor fix — final mechanism is REMOVAL, not substitution (see "SUPERSEDED same day" section): 603 items were deleted entirely from `Item_custom.csv` (200336→199733 rows) and the same 27 `ItemDisplayInfo_custom.csv` rows are gone (16125 rows, orphaned by the original substitution attempt, unaffected by the later reversal). Small in absolute count, but bundle it with any other pending rebuild — the merged CSV files are monolithic regardless of how many rows actually changed.
0b. **[session 9] Shield/held wearer-derived material is UNCHANGED/OUT OF SCOPE for the whole session-9 material redesign** — `build-worn-offhand.py` still uses the OLD flat `UC_MAT` unit_class table (Warrior/Paladin→Plate, Rogue→Leather, Mage→Cloth) for a shield/held item's STAT/kit-profession selection (their SUBCLASS was always a fixed constant 6/0 regardless of material, so this never affected item-type consistency, only which stat/kit a shield's Strength-vs-Agility roll gets). Not touched this session — deliberate scope boundary (the coordinator's spec was framed entirely around "armor material" / `build-worn-slice.py`). Could be extended later with the same art-evidence/progression logic if the user wants shield/held stat selection to match the new system too.
0c. **[session 9] 278 creature_template entries exist ONLY in the live `acore_world_ptr` DB, not in `data/sql/base/db_world/creature_template.sql` at all** — likely custom/module-added creatures (Nemesis/Familiars/other). The ENTIRE pipeline (`creatures` dict in all 3 generation scripts) is seeded from the base SQL file first, so these 278 entries are invisible to generation even after `load_live_levels()`'s override (that function only OVERRIDES minlevel/maxlevel for entries the base file already has — it can't ADD a creature the base file never had, since name/unit_class/npcflag/type would all be missing too). A full fix would mean sourcing `creature_template` ENTIRELY from the live DB instead of the base SQL snapshot (bigger architecture change, not done this session — flagged as a real, if likely small, coverage gap).
1. **User needs to rebuild MPQ ONCE, covering ALL client-side deltas accumulated across sessions 5-7 (this is the current end state, no further server-triggered MPQ churn expected until a new feature ships)**: session 5's shield/held icons, session 6's material-pivot icon churn (custom ItemDisplayInfo range settled at 110000-116310, 6311 ids), AND session 7's icon-quality pass (same 6311 ids, but ~1016 of them now have a materially better icon value) + clear Cache/WDB + relog. Naming-only fixes (Leather/Mail base nouns) are server-side text, no MPQ delta. **SUPERSEDED by item #0 above** — the custom ItemDisplayInfo range moved again in session 9, so a fresh MPQ rebuild now needs to cover sessions 5-9 all at once if not already done incrementally.
2. After testing: revert PTR test conf (ArmorPerKill=1, WeaponPerKill=1, Chance=30, WeaponChance=10, TabardChance=5, LevelDiffMax=12) → `.reload config`. **Note (session 8): `WornDrops.TabardChance` is now a config KEY change, not just a value change — `.reload config` alone is sufficient (LoadConfig reads it every reload), no rebuild/restart needed for a future chance-only revert.**
3. Weapon icons: use the weapon's real displayid → occasional base-game icon/model mismatch (cosmetic, not our bug). Could remap to matched icons later.
4. Consider refreshing `.claude/dbc/*.bak` files now that the pristine merge is correct, so future restores don't need the same forensic diffing — but only if/when doing so doesn't risk losing a needed rollback point.
5. `worn_family_map.tsv` now has 134 curated families; coverage has plateaued around 26%/14% (look-basis) — most further ranking-tail candidates are personal boss names or role/title words (confirmed by manual grounding), not real curatable factions. Tier-2 auto-derive (see above) is the mechanism for pushing past curated-only coverage; could still lower `AUTO_MIN_WEARERS` or add alias-detection for more tail coverage, at some quality-control cost.
6. YO is OFF (final decision, see "Family naming: two tiers" #3) — no dictionary to maintain. If this is ever revisited, re-read that section first (it documents the LIKE-collation false-positive trap so the same investigation isn't repeated from scratch).
7. Offhand family-naming coverage is currently small (26 shield + 5 held looks) since most offhand looks have few distinct wearers (shields/held items are less commonly shared across large NPC families than baked armor). Could extend `worn_family_map.tsv`/auto-derive further if the user wants more shield/held names, using the same family-frequency-ranking method from session 3.
8. The `(4,0,13)` offhand triple (3 creature_equip_template rows, doesn't match shield OR held-in-offhand OR class-2-weapon) is intentionally left ungenerated — too small/ambiguous to route confidently (see build-worn-offhand.py's "never guess" comment).
9. Real-item material coverage (13.1%) could in principle be pushed higher by relaxing the `REAL_MATERIAL_SLOTS`/InventoryType matching (e.g. accepting a near-miss invtype), but this trades precision for coverage — the current 86.9% unit_class fallback is not "wrong", it's simply the best available signal for NPC-exclusive looks with no player-obtainable equivalent. Not recommended to touch without a specific new user ask.
10. **Found (not fixed, low priority) session 8**: `env/dist/etc-ptr/modules/mod-worn-drops.conf.dist` is STALE — it documents a config schema that no longer exists in the C++ (`WornDrops.Chance.Normal/Elite/RareElite/Boss/Rare` per creature-rank, `WornDrops.Quality.Green=15/Blue=10/Epic=5`) instead of the current `WornDrops.Chance`/`WornDrops.WeaponChance`/`WornDrops.TabardChance`/`ArmorPerKill`/`WeaponPerKill` shape actually read by `LoadConfig()`. Harmless today (the real, already-populated `mod-worn-drops.conf` next to it is what's actually loaded — confirmed via `docker exec ac-worldserver-ptr cat .../env/dist/etc/modules/mod-worn-drops.conf`, and `.dist` templates are typically only consulted by the entrypoint to populate a MISSING `.conf` on first setup), but worth syncing to the current schema before it misleads a future fresh PTR/live setup that deletes `.conf` and lets the entrypoint regenerate from this stale template. NOT touched this session (out of the explicit two-file scope the user approved: `modules/mod-worn-drops/conf/mod-worn-drops.conf.dist` for the prod default + `env/dist/etc-ptr/modules/mod-worn-drops.conf` for the PTR runtime value — both of those ARE current/correct).

## Gotchas
- **CRITICAL, project-wide rule that got missed in session 9 — EVERY `docker exec ... mysql < file.sql` (or piped) apply of worn-drops SQL MUST include `--default-character-set=utf8mb4`** on the `mysql` client invocation, not just on ad-hoc `SELECT` verification queries. Session 9's big-SQL apply (`cat prefix worn_drops_scarlet.sql suffix | mysql -uroot -ppassword acore_world_ptr`, no charset flag) landed all 187,288 ruRU `item_template_locale` rows DOUBLE-ENCODED (mysql's default client charset on this container is NOT utf8mb4, so UTF-8 bytes already present in the SQL file's `'...'` literals got interpreted as latin1 and re-encoded) — user saw mojibake in-game (`ÐšÐ¾Ð¶Ð°Ð½Ñ‹Ð¹ ÑˆÐ»ÐµÐ¼` instead of `Кожаный шлем`). This is the SAME class of bug as the pre-existing project-wide memory rule "SQL charset for Russian" (see the user's global MEMORY.md) — it was already known project-wide and STILL got missed here because the apply command template used throughout this whole session's work never had the flag. **Fixed going forward**: the correct apply command is
  `docker exec <db-container> sh -c "cat prefix.sql big.sql suffix.sql | mysql --default-character-set=utf8mb4 -uroot -ppassword <db>"`
  — the flag goes as a plain `mysql` client option, works fine positioned before `-uroot`. Coordinator repaired the live DB in place this time (`UPDATE item_template_locale SET Name=CONVERT(BINARY CONVERT(Name USING latin1) USING utf8mb4)` +Description, ID range 400000-1099999, verified 0 broken, restarted worldserver) — no DB action needed from a future session for THIS incident, but the apply template itself must never omit the flag again. **New validation check R** (see validation.md): `SELECT SUM(HEX(LEFT(Name,2)) NOT REGEXP '^D[0-9A-F]') FROM item_template_locale WHERE locale='ruRU' AND ID BETWEEN 400000 AND 1099999` MUST be 0 after every apply — Cyrillic UTF-8 always starts with a `D0`/`D1` lead byte, so a non-`D`-prefixed first byte is a reliable double-encoding smoke test cheaper than eyeballing sample text. Run this IMMEDIATELY after every future big-SQL apply, before declaring success.
- Killed `docker exec mysql < big.sql` keeps running server-side (locks/transaction) → KILL the thread id from `SHOW PROCESSLIST`/`information_schema.innodb_trx`. If the whole script was wrapped in one `SET autocommit=0; ... COMMIT;` transaction, a KILL rolls back everything applied so far in that session — convenient for a clean retry, but don't assume partial progress survived.
- .claude/dbc/Item_custom.csv and Item_custom_worn.csv (module data) have a BOM on the merged file → read/write utf-8-sig for Item_custom.csv; the raw gen-worn-itemdbc.py output (Item_custom_worn.csv) itself is NOT BOM'd (utf-8) — only the merged `.claude/dbc/` copy is.
- worldserver caches item_template at startup → DB changes need a restart.
- Per-row displayid UPDATEs (6000+ individual statements via `docker exec -i mysql < remap.sql`) are too slow (~10-40 rows/sec observed, would take hours) — ALWAYS use the JOIN-vs-MEMORY-table pattern: `docker cp` the tsv to `/var/lib/mysql-files/` inside the container (NOT `/tmp` — blocked by `secure_file_priv`), `LOAD DATA INFILE` into a `CREATE TEMPORARY TABLE ... ENGINE=MEMORY`, then a single `UPDATE ... JOIN` (7398-row map, 65400 target rows updated in ~1s).
- On this Windows/Git-Bash environment, `docker exec ac-database-v2 <cmd touching a /path>` gets MSYS path-mangled (rewrites `/tmp/x` to a Windows path) unless you prefix `MSYS_NO_PATHCONV=1`. `docker cp host:X container:Y` itself is fine without the prefix.
- `python3` is not on PATH here; use `python` (3.13).
- Before applying any fresh `worn_displayid_remap.sql`/iconmap, check whether `item_template.displayid` for our range is already sitting on a PRIOR custom id (>=110000) from an earlier run — if so, revert to true stock via `worn_drop_item.item_displayid` first (see FIXED #1 above), otherwise the new remap's `WHERE displayid=<stock>` silently matches nothing. (Not an issue for a FULL regen — DELETE+reinsert wipes the stale rows entirely.)
- **A ModelName_1=='' slot (currently cape=11 and tabard=10) is geoset/texture-based, NOT model-based** — never add it to `MODEL_SLOTS` in build-worn-slice.py (that check exists ONLY for attached-3D-model slots like head/shoulder; applying it to a geoset slot filters out 100% of that slot's looks, as happened to cape for at least one prior session).
- **Stock donor `subclass` is NOT trustworthy as a material signal for every slot** — confirmed cloaks (InventoryType=16) are always subclass∈{0,1} in stock item_template regardless of which material class wears that look. Any slot where the PRIME DIRECTIVE's "subclass must equal material" can't be guaranteed by donor selection alone needs an explicit `force_subclass` override in `int_overrides()` (already applied to ALL armor via `is_armor=True`, cheap insurance — never rely on `pick_donor`'s chosen donor's subclass column matching the material key you searched with).
- **A new pseudo-material bucket (like TABARD_MAT=0) needs its own scope-priority logic** — `gen-worn.py`'s `scope[creature_entry] = material_id` loop must explicitly skip pseudo-material rows (a creature can wear both a real-material item AND a universal one; last-dict-write-wins is fragile, make the skip explicit).
- **A new slot/pseudo-material needs BOTH a Python-side AND a C++-side check** if the C++ runtime uses the creature's scope-material for every slot uniformly (it does, by default) — `mod_worn_drops.cpp`'s `AddWornItem` call must special-case `slot == <pseudo-material slot>` to use the pseudo-material key instead of the creature's real material, else `WD_Item.find(...)` never matches and the item silently never drops despite fully correct DB data. This is a C++ change → needs an image REBUILD, not just a restart.
- Multi-word family names (`worn_family_map.tsv`) MUST also be added to `FAMILY_MULTI` in gen-worn.py — a curated RU entry without a matching MULTI-list phrase silently never triggers (the tokenizer falls through to the bare first word, which never equals the multi-word key).
- **MySQL `LIKE '%ё%'` is a FALSE-POSITIVE-PRONE check for byte-exact ё presence** on this DB — the default collation (`utf8mb4_unicode_ci`/`0900_ai_ci`) is accent-insensitive and treats е/ё as equal for LIKE/`=` comparisons. Always verify actual ё usage via a byte-level check (Python `"ё" in s`) on an exported TSV, never via a SQL LIKE/WHERE clause, or you'll get wildly inflated false-positive counts (observed: LIKE claimed 39693/75% ё-rows in item_template_locale; the true byte-exact figure was 3183/2%, and further filtering to STOCK-only entries showed 0%).
- Any `creature_template`-driven family/dominance computation must dedupe by NAME (not raw entry id) before counting — `creature_template` frequently has ONE NPC repeated across many rows (encounter clones, phase copies, holiday reskins) which can otherwise fake a "dominant family" from row-count alone. See "dedup gotcha" in the two-tiers section above.
- **A donor-selection fallback that broadens the search must NEVER cross the axis that determines the item's TYPE identity** (weapon subclass, armor material) — only broaden along axes that don't affect visual/audio/name identity (e.g. invtype, once subclass is pinned; or ilvl/band, always). The `pick_donor` invtype-only fallback (broadening across ANY subclass sharing an invtype) is exactly this class of bug — confirmed root cause of Bug 1. When adding a new fallback anywhere in this pipeline, ask "could this substitute a donor whose TYPE (icon/sound/name) is wrong for the group being generated?" before shipping it.
- **`emit_group`'s `force_subclass=matkey` (added for the cape/tabard fix) is ONLY correct when the wearer's MATERIAL and the item's SUBCLASS are the same axis** (true for real armor 1-4 and the tabard pseudo-material 0). For any FUTURE slot where subclass is a fixed type constant independent of material (shield=6, held-in-offhand=0), you MUST pass `subclass_override` explicitly — `is_armor=True` alone is not sufic to get the right subclass. Caught live before the shield fix shipped (shields generated with subclass=<wearer material> instead of 6).
- **`creature_equip_template` is keyed by CREATURE_ENTRY, not creature_display_id** — unlike baked armor (CreatureDisplayInfoExtra, keyed by display id, safe to dedupe/aggregate by display id since the model IS the source of truth), the SAME display_id can be equipped with a DIFFERENT weapon/shield/held-item depending on which creature_entry uses that display. Never feed equip-template-sourced looks into `worn_drop_display` (its PK is `(creature_display_id, slot)`) — use an entry-keyed table (`worn_drop_weapon`, `worn_drop_offhand`) instead, or you'll get a live `ERROR 1062 Duplicate entry` on apply (or worse, silently wrong data if the collision happens not to violate the PK). This is now the THIRD such table (scope was already correctly entry-keyed) — if a fourth equip-template-sourced item type is ever added, follow the same pattern.
- **Vanilla MySQL 8.x has NO `ADD COLUMN IF NOT EXISTS` / `DROP COLUMN IF NOT EXISTS` / `MODIFY COLUMN IF NOT EXISTS`** (confirmed against this DB's actual MySQL 8.4.4 — that's a MariaDB-only extension and throws `ERROR 1064`). `CREATE TABLE IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS` DO work. For an idempotent column-add on a table that might already exist with an old schema, use the `information_schema.columns`-guarded `SET @x:=(SELECT COUNT(*)...); SET @sql:=IF(@x=0,'ALTER TABLE...','SELECT 1'); PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;` idiom (see session 6's `worn_drop_display.material_id` upgrade path in gen-worn.py for the exact working pattern) — always test the bare statement directly against the container first if unsure, don't assume MariaDB syntax sugar carries over.
- **A `dict.get(key, default)` fallback with a same-SHAPE wrong-VALUE default (e.g. `BASE.get(mat, BASE[4])`) is invisible dead code until the previously-unreachable key becomes reachable** — session 6's material pivot made Leather(2)/Mail(3) reachable for the first time, silently exposing that `gen-worn.py`'s `BASE` naming dict never had entries for those keys (every Leather/Mail item was named "Plate Helm"/"Латный шлем" until caught by eyeballing sample output, NOT by any SQL validation check). Whenever a pivot/change makes a new enum/key value reachable for the first time, grep EVERY lookup table keyed by that same enum in the whole pipeline (naming, icons, kit-profile, primary-stat, etc.) for a full case list BEFORE trusting generated output — SQL-only validation (A-M) cannot catch a wrong-but-well-formed STRING value.
- **Material is now a per-(creature_display_id, slot) property, not a per-creature property** (session 6 pivot) — `worn_drop_scope`'s single `creature_entry -> material_id` value is DOWNGRADED to a gate+offhand-fallback role only; any FUTURE code (Python generation OR C++ runtime) that needs "this creature's armor material" for anything beyond a yes/no scope check must go through `worn_drop_display`'s per-row `material_id`, never `worn_drop_scope`. Re-introducing a per-creature material assumption anywhere would silently regress Mail/Leather back toward near-zero.
- **A shared `ModelName_1` does NOT imply a shared item CATEGORY in stock WoW DBC data** (session 7 icon quality gate) — confirmed `Helm_Eyepatch_A_01.mdx` is reused by Blizzard for helmets AND amulets AND belts AND at least one shield-icon'd item; a naive "any ItemDisplayInfo row sharing this model has a usable icon" match can land on a wrong-category icon (a head-slot look showing a shield or gift-box icon), which is a WORSE outcome than the crude generic fallback it was meant to replace. Any future same-model/same-texture matching scheme in this pipeline MUST additionally verify the candidate is a REAL item of the SAME InventoryType/slot family (via the `disp_items`-style real-item join, not just "has an icon") before trusting its icon — matching on visual asset identity alone is not sufficient to guarantee category correctness. Conversely, a real same-slot item CAN legitimately have an unusual/unexpected-looking icon (confirmed: stock id 13219, a genuine Cloth head item, uses `INV_Shield_09`) — don't second-guess an icon just because it looks visually surprising once the slot-type provenance check has passed; that's real, intentional Blizzard data.
- **The mod-worn-drops boot log line format changed (session 8)**: was 5 comma-separated counts (`scope, displays, weapon-maps, offhand-maps, items`), now 6 (`scope, displays, tabard-maps, weapon-maps, offhand-maps, items`) — a new `{} tabard-maps` field was inserted between `displays` and `weapon-maps` when tabard was split out of `WD_Display` into its own `WD_Tabard` map. Any future memory note, validation script, or eyeballed sample that assumes the old 5-field shape (all of sessions 1-7's write-ups do) is describing the PRE-session-8 format — don't flag a 6-field line as "wrong" when diffing against those old notes.
- **Prose examples in memory that list N look-ids alongside N icon-names side-by-side are NOT a guaranteed positional 1:1 mapping unless explicitly stated** (found session 8, auditing session 7's write-up: the "6531/6536/6537/23175/23318 → INV_Potion_17/INV_Potion_08/INV_Sword_09/INV_Misc_Book_09/INV_Misc_Bag_10" line implied ordered correspondence that didn't actually hold for the first 3 of 5 — real values were INV_Misc_Gem_Opal_01/INV_Potion_07/INV_Torch_Lit; only positions 4-5 happened to line up by coincidence). When writing a multi-item example list in future session notes, either verify true 1:1 correspondence before writing it that way, or write it as an unordered set explicitly (avoid the visual implication of pairing). When AUDITING an old note's examples, don't assume a `grep worn_iconmap.tsv` + CSV lookup will confirm the exact string quoted — verify each one directly rather than trusting the prose.
- **`ItemDisplayInfo.dbc`'s renderable-content columns are `ModelName_1/2` AND `ModelTexture_1/2` AND `Texture_1..8` — THREE independent channels, not two** (session 11, "invisible chest" fix). `ModelTexture_1/2` is its OWN channel, structurally separate from `Texture_1..8` — confirmed EVERY stock cloak (InventoryType=16) renders EXCLUSIVELY via `ModelTexture_1` (e.g. ID 23122 `ModelTexture_1='Cape_Cloth_A_02Green'`, `Texture_1..8` all blank, `ModelName_1/2` both blank). Any "is this look renderable" check in this codebase MUST test all 3 channels (`ModelName_1`, `ModelName_2`, `ModelTexture_1`, `ModelTexture_2`, `Texture_1..8`) — checking only `ModelName_1`+`Texture_1..8` (the first cut this session) wrongly flags 100% of cloaks as unrenderable. The TRUE empty case (confirmed via display 5440, the original Alexandra Bolero bug) has NONE of the 3 channels populated, only a bare `GeosetGroup_2` value (geoset selection alone, with nothing to apply it to, renders nothing).
- **A junk/deprecated-name donor stoplist (`_JUNK` in build-worn-slice.py) built for a NARROW original purpose (tabard-only) can have real blind spots once its scope is widened to a bigger population** (session 11) — `_JUNK` only matched BRACKETED test markers (`"[test"`, `"(test"`), missing 14 stock white Plate items literally named `Test Defense Chest`/`Test Armor Chest`/etc. (no brackets) that all share a stock displayid ALSO used by a real Mail item elsewhere — picking one as a donor is a live PRIME-DIRECTIVE (icon/material) violation, not just a cosmetic issue. Caught by validation check A regressing to 1 after a live apply, not by any static review. Fixed with a WORD-BOUNDARY regex (`\btest\b`, case-insensitive) — deliberately NOT a bare substring, since `"Contest Winner's Tabard"` (a real, legitimate item) contains "test" as a substring and must not be excluded. Lesson: whenever a filter's scope widens to a new item population, re-derive the actual junk-name patterns present in THAT population (e.g. `SELECT name FROM item_template WHERE class=4 AND Quality=1 AND LOWER(name) LIKE '%test%'` or similar) rather than assuming an existing stoplist built for a different, narrower population is complete.
- **The `exec(compile(prefix_of_other_script, ...))` code-reuse pattern also works for "give me this script's freshly-fixed data structures without re-deriving them by hand"** (session 11) — cutting `build-worn-slice.py` at `"# ---------- Pass 1:"` (before the expensive per-creature slice computation, after the cheap donor-pool/EMPTY_DISPLAY/pick_donor setup) gave a live-DB targeted-patch script direct access to the CURRENT, bug-fixed `donors`/`pick_donor()`/`EMPTY_DISPLAY` globals with zero risk of the patch script's own hand-rolled donor logic drifting out of sync with the real generator. Prefer this over re-implementing donor-selection logic in a one-off scratchpad script whenever the real generator already has a reusable prefix.
- **A core WoW-server hook that dispatches on "who/what dealt the killing blow" (`Player*` type check) will silently skip a whole class of legitimate scenario if the killer is a pet/totem/guardian** (session 15) — `Unit::Kill()` resolves a SEPARATE local `player` variable (via `GetCharmerOrOwnerPlayerOrPlayerItself()`) for loot/XP/reward purposes, but its `sScriptMgr->OnPlayerCreatureKill(...)` DISPATCH uses the RAW killer object's `ToPlayer()`, which is null for a pet/totem — only `OnPlayerCreatureKilledByPet(petOwner, killed)` fires in that case, a SEPARATE `PlayerScript` hook. Any custom on-kill loot/reward/quest logic added to ANY module (not just this one) that only implements `OnPlayerCreatureKill` will silently miss every pet/totem-finished kill with zero error trace — always grep `PlayerScript.h` for sibling `*KilledByPet`/`*KilledByCreature`-style hooks when adding a new on-kill feature and consider whether they need the same handling (usually yes, via a small shared private helper, exactly the `HandleKill()` refactor pattern used here).
- **A per-display AGGREGATE signal computed over "every creature currently in scope" (e.g. `display_dom_uc`'s majority-unit_class vote, used for the Mage hard-clamp) is NOT safe to assume stable across a scope-WIDENING change** (session 15) — adding creatures to `work` can shift an aggregate vote for an EXISTING, unrelated, already-correct display purely by adding more voters to it (2 real cases found: a Blizzard `"[DND]"`-tagged internal test NPC and an unrelated real NPC, both `unit_class=8`/Mage, sharing a display with a pre-existing non-Mage creature, tipped the majority enough to flip that display's material from Mail/Leather to Cloth). **General mitigation for ANY future scope-widening session in this pipeline**: diff the fresh per-display resolution against LIVE `worn_drop_display` before writing apply SQL, and if doing a PURE-APPEND (not a full regen), make the append conservative — never touch/insert-conflict with a `creature_display_id` that already has ANY live coverage, so a newly-in-scope creature sharing an old display just inherits its existing rows for free (correct by construction, zero risk of side-effect pollution) instead of re-deriving that display's material from a widened voter pool.
- **The icon-minting step (`gen-worn-icons.py`) scans the FULL `worn_groups.tsv`, which can be a strict superset of what a CONSERVATIVE partial-append item-generation pass actually emits** (session 15) — minting icons for "every (look,material) pair the full recomputed population needs" and then filtering item-generation more narrowly (e.g. "brand-new displays only") can mint icons for pairs that end up referenced by NOTHING in `item_template`, an ORPHANED-CSV-ROW class of S-check violation (the OPPOSITE direction from session 10's original incident, which was a DB-references-a-missing-CSV-row bug) — both directions of the S check are real and must both be verified, not just the historically-more-dangerous one. Fix: after computing which NEW icon keys were actually minted, cross-check the resulting id set against `SELECT DISTINCT displayid FROM item_template WHERE displayid>=110000` and drop any id (from BOTH `worn_iconmap.tsv` and the CSV) that isn't actually referenced, before merging into the shared `.claude/dbc/` files.

## SESSION 14 (2026-07-04, coordinator-applied) — BoP -> BoE
- User decision: worn items are now **bonding=2 (BIND_WHEN_EQUIPPED)** — tradeable/mailable/AH until equipped. Was 1 (BoP) since the pilot.
- Applied: UPDATE item_template bonding=2 on BOTH acore_world_ptr AND acore_world (208,925 rows each, verified 0 non-BoE). gen-worn.py int_overrides emits bonding=2 permanently. validation.md check E now asserts bonding<>2 = 0 (was <>1).
- Already-looted instances in player bags keep their per-instance soulbound flag; only new loots are BoE. Zero client/MPQ impact (bonding travels via item query; players clear WDB to see the new tooltip line).
- Worldservers NOT restarted by the coordinator (PC was being shut down; next container start loads the new bonding automatically).

## SESSION 15 (2026-07-05) — Karazhan bug report: 2 root causes found + fixed (1 C++ hook gap, 1 armor-scope gap)
User report: "Attumen the Huntsman" (Karazhan boss) dropped NOTHING (armor or weapon); "Phantom
Guardsman" (Karazhan opera-event trash) drops ONLY weapons, never armor. Both investigated against
LIVE PTR data (never assumed), both were real bugs, both fixed.

### Bug 1: `OnPlayerCreatureKilledByPet` was never implemented — pet/totem killing blows dropped NOTHING
**Root cause (confirmed by reading `Unit::Kill()`, `src/server/game/Entities/Unit/Unit.cpp` ~14062-14276)**:
the core dispatches `sScriptMgr->OnPlayerCreatureKill(killerPlr, killedCre)` ONLY if the raw killing-blow
`killer` object's `ToPlayer()` succeeds. A Hunter pet / Warlock demon / DK ghoul / Mage water elemental /
Shaman fire totem IS a `Creature` (not a `Player`) even though `Unit::Kill()`'s LOCAL `player` variable
(used for loot/XP/group reward, resolved via `GetCharmerOrOwnerPlayerOrPlayerItself()`) correctly
points at the owner — the OnPlayerCreatureKill dispatch does NOT use that resolved `player`, it checks
the RAW `killer` directly. A pet/totem killing blow instead fires ONLY `OnPlayerCreatureKilledByPet
(petOwner, killed)` — a hook `mod-worn-drops` NEVER implemented before this session. Net effect:
**every kill whose final blow lands from a pet/totem silently skipped BOTH the armor and weapon rolls**,
zero errors/log trace, indistinguishable from bad luck. This is not Attumen-specific — it's a
systemic, silent drop-rate loss server-wide for pet classes (very common on long boss fights where a
raid Hunter's pet tanks/finishes), and is the leading, code-confirmed hypothesis for "boss killed,
literally nothing dropped" reports in general. **Not provably THE cause of this specific user report**
(no per-kill log existed to confirm the killing blow's source retroactively) but a real, confirmed,
previously-unknown gap regardless, worth fixing on its own merits.
- **Fix** (`modules/mod-worn-drops/src/mod_worn_drops.cpp`): refactored `OnPlayerCreatureKill`'s body
  into a new private `HandleKill(Player* killer, Creature* killed)`; `OnPlayerCreatureKill` now just
  calls `HandleKill(killer, killed)`; added `void OnPlayerCreatureKilledByPet(Player* petOwner,
  Creature* killed) override { HandleKill(petOwner, killed); }`. `CALL_ENABLED_HOOKS`'s per-script
  hook-enable mechanism is automatic (vtable-override detection at script registration, same pattern
  every other PlayerScript hook in this codebase uses) — no separate registration/flag needed.
- **Attumen-specific data check (ruled out as the cause, DB was already correct)**: Attumen the
  Huntsman has 3 creature_template rows — unmounted `15550`, `Midnight` (the horse) `16151`, mounted
  `16152`. `boss_midnight.cpp`'s real fight mechanics (traced in full): `15550` never actually "dies"
  (`DamageTaken` clamps its health at 1 until it mounts, then `DespawnOrUnsummon`s itself — no kill
  event ever fires for it, by design); the summoned MOUNTED unit `16152` starts in `PHASE_MOUNTED`
  (set via `IsSummonedBy`) so ITS `DamageTaken` does NOT clamp health — it dies for real via normal
  player damage, `JustDied()` also kills Midnight via `midnight->KillSelf()` (a self-kill, correctly
  fires no player-facing hook, Midnight has no armor/weapon data anyway — a horse, not humanoid).
  `worn_drop_weapon` HAS rows for BOTH `15550` and `16152` (wslot=21, displayid=21555=item 11591
  "Battlefield Destroyer" 2H sword, subclass=8) at his true live band 70 (level 73 -> band 70,
  `worn_drop_item` confirmed to have all 4 qualities at band=70) — **the weapon SHOULD have dropped**
  given PTR's 100%-chance TEST conf; the pet-kill hook gap is the most plausible explanation found.
  Attumen has **NO baked armor look at all** (`ExtendedDisplayInfoID=0` on all 3 of his
  CreatureDisplayInfo rows — 16040/16416/19640, all "MountedDemonKnight..."-style bespoke mounted
  models, not player-rig humanoid models) — **"no armor for Attumen" is CORRECT/expected, not a bug**,
  independent of the scope-widening fix below (confirmed he still has zero worn_drop_scope/display
  rows after the fix — his displays genuinely carry no equip-slot data to derive armor from).
- **Rebuild required and done**: `.cpp` change — `docker compose --profile ptr build
  ac-worldserver-ptr` (clean, 0 errors) + `up -d`. Boot log confirmed clean restart, zero errors.
  **Not verified with an actual in-game pet kill** (no headless pet-summon-and-kill was attempted) —
  code-path review (the exact `Unit::Kill()` branch was read line-by-line) is what was checked.

### Bug 2: armor scope's `type == 7` (Humanoid) filter wrongly excluded 823 real humanoid-shaped NPCs
**Root cause** (`modules/mod-worn-drops/scripts/build-worn-slice.py`'s `work` filter): armor scope was
gated on `creature_template.type == 7` (CreatureType.dbc Humanoid) — but `type` is a GAMEPLAY
classification (CC immunities/loot flavor/hunter pet family), NOT a reliable proxy for "is this a
player-model-rigged humanoid with a real baked equipment look". **Confirmed via live data**: Karazhan's
opera-event ghosts (Phantom Guardsman 16425, Phantom Attendant 16406, Phantom Valet 16408, Phantom
Guest 16409, Phantom Stagehand 16472) are ALL `type=6` (Undead) yet their `CreatureDisplayInfoExtra`
rows have a FULL set of non-zero `NPCItemDisplay_*` gear slots (verified directly against
`.claude/dbc/CreatureDisplayInfoExtra.csv`, e.g. Phantom Guardsman's 4 model variants 16454-16457 each
carry head/shoulder/chest/belt/legs/boots/gloves) — real, derivable, player-rig armor looks that were
being silently denied ANY armor purely by the `type` gate, while still getting weapons (
`build-worn-weapons.py` never had a type filter, hence the exact reported symptom: "drops weapons,
never armor", a CONSISTENT/deterministic bug, not bad luck). **Scale check across the whole DB**
(not just Karazhan): 1,003 non-type-7 creatures have genuine evidence-backed armor looks once `type`
stops gating them (type 6/Undead=650, 10/Not-specified=262, 2/Dragonkin=67, 3/Demon=12, 5/9/12=3 each,
4/Elemental=2, 1/Beast=1) vs 0-2 false positives among the genuinely non-humanoid types (0/220
Critters, 0/26 type-0, 0/262 Totems, 0/8 Gas Clouds, 1/2781 Beasts, 2/1002 Elementals) — confirming
the EXISTING per-look evidence gate (`ExtendedDisplayInfoID` + non-empty `NPCItemDisplay` +
`MODEL_SLOTS`/`EMPTY_DISPLAY` checks, already in Pass 1) is ALREADY the real, precise "has a
derivable armor look" filter; `type==7` was a redundant, overly coarse PRE-filter sitting in front of
a gate that already does this job correctly (same class of fix as session 9's npcflag removal).
- **Fix**: removed the `type == 7` condition from `work` entirely (only the junk-name stoplist
  remains). Also added `"[dnd]"` to `_JUNK` (see gotcha below).
- **GOTCHA caught before applying (real, would-have-been-silent regression)**: a first full re-run of
  `build-worn-slice.py` with the type filter simply removed changed the CONCRETE material for TWO
  PRE-EXISTING, already-live, already-correct displays (24030 Mail->Cloth, 23751 Leather->Cloth) —
  root cause: `display_dom_uc[d]` (the display's dominant-unit_class, used ONLY for the unconditional
  Mage hard-clamp) is a per-ROW-weighted Counter across ALL creatures sharing that `creature_display_id`
  — two newly-in-scope creatures sharing those exact displays happened to have `unit_class=8` (Mage):
  `"[DND] Dalaran Sewer Arena - Controller"` (entry 32339, an internal test/arena-control NPC — added
  `"[dnd]"` to `_JUNK`, Blizzard's "Do Not Delete" internal-NPC naming convention, to exclude this
  WHOLE class of pollution permanently) and `"Indu'le Mystic"` (entry 26336, a real but unrelated
  NPC that legitimately shares a display with an existing Hunter-Trainer-type creature). Their
  class=8 rows tipped the MAJORITY vote enough to trip the Mage clamp, silently overriding the
  pre-existing correct Mail/Leather resolution for creatures that were NEVER part of this fix's
  intended scope. **Lesson for ANY future scope-widening in this pipeline**: a per-display AGGREGATE
  signal (majority unit_class vote, in this case) computed over "every creature currently in `work`"
  is NOT safe to treat as stable across a scope change — widening `work` can silently repolish an
  unrelated, already-correct EXISTING display's resolution as a side effect purely by adding more
  voters to its aggregate, even with zero code path specific to the new creatures actually firing.
  **Mitigation applied (belt-and-suspenders, keep BOTH for any future session)**: (1) `"[dnd]"` added
  to `_JUNK` (removes the worst offender class at the source); (2) the actual DB patch was engineered
  as a **conservative "brand-new creature_display_id only" append** (see mechanics below) — ANY
  `creature_display_id` that already had >=1 live `worn_drop_display` row was left 100% untouched by
  this session's SQL, regardless of what the freshly-recomputed vote would say for it, specifically
  to make this whole class of pollution structurally impossible to land silently in a partial-append
  patch (a creature newly sharing an OLD display simply inherits that display's existing, unmodified
  rows for free via the runtime's `GetDisplayId()`-keyed lookup — no DB change needed for it at all).
- **PURE-APPEND mechanics** (same established pattern as sessions 10/13 — exec-prefix cut at
  `gen-worn.py`'s `"# ---------- header ----------"` marker to reuse the REAL `emit_group()`/
  `build_look_family()`/`base_for()`/`FLAGS_STRIP_MASK`/`ICONMAP` machinery, asserting
  `out`/`item_map`/`chain_rows` are empty at the cut point):
  1. Re-ran `build-worn-slice.py` fully (fresh `worn_groups.tsv` 42,728 rows / `creature_worn.tsv`
     112,561 rows for the WHOLE catalog, widened scope + `[dnd]` filter).
  2. **823 new creature_entry values** (`worn_drop_scope` — every new creature gets one, REGARDLESS
     of whether its display is brand-new or shared, since the runtime `inArmor` gate is keyed by
     creature_entry and would never even consult `WD_Display` without it).
  3. **1,007 brand-new `creature_display_id` values** (zero prior live `worn_drop_display` coverage)
     -> **5,480 new `worn_drop_display` rows**. Any fresh-run row on an ALREADY-known display_id was
     explicitly excluded (105,264 rows skipped this way) per the mitigation above.
  4. **2,076 new (slot,look,band,material) groups** needed for those brand-new displays' (slot,look)
     pairs (2,396 distinct pairs, minus 320 already covered by an existing group via a DIFFERENT,
     already-known display sharing the same stock look) -> **8,292 new item_template rows** (entries
     873170-893923, fresh `bi` computed from `MAX(entry)=873163`, well inside the 60,000-group/
     1,000,000-id armor budget — armor now at ~49,393/60,000 groups, 82.3%, WORTH WATCHING for the
     next scope-widening session, see PENDING).
  5. **686 new (look,material) icon pairs** minted via `gen-worn-icons.py`'s real tier chain
     (exec-prefix cut at `"# assign custom ids..."`, diffed against the LIVE `worn_iconmap.tsv` for
     genuinely-new keys only, ids 126985-127670) — tier breakdown: donor 527, real_item 44,
     model_match 102, generic 13. **A second real gotcha caught by the S-check before declaring
     done**: 128 of these 686 minted icon ids ended up UNREFERENCED by any `item_template.displayid`
     — because the icon-minting step (correctly, per its own script design) scans the FULL fresh
     `worn_groups.tsv` (old+new together) for "needs an icon", which includes groups that exist in
     the recomputed full population but that this session's CONSERVATIVE item-generation step
     deliberately never emits (they belong to already-known/shared displays this session doesn't
     touch, per the mitigation above) — minted-but-orphaned. Caught via check S (0 missing, 128
     orphaned) exactly as the session-10 postmortem prescribed ("always cross-check S as the LAST
     step"); fixed by removing those 128 rows from both `ItemDisplayInfo_custom.csv` and
     `worn_iconmap.tsv` before merging (re-verified S=0/0 after).
- **Applied to `acore_world_ptr`** via `docker cp` (MSYS_NO_PATHCONV=1, per the standing Windows/
  Git-Bash gotcha) + `cat prefix full_patch suffix | mysql --default-character-set=utf8mb4 ...`
  (38MB SQL, ran in the foreground, no backgrounding — per the session-9 postmortem). **All of
  A/B/C/D/E/F/K1/K2/L/M/M-sentinel/O/Q/R/U/S(both directions)/T/H reconfirmed 0/clean** against the
  new 217,217-item total (armor 196,489 + weapon 20,728 unchanged). `Item_custom.csv` 219,294->227,586
  rows, `ItemDisplayInfo_custom.csv` 16,977->17,535 rows (both `.claude/dbc/` merges, orphan-free).
  **worn_drop_weapon (12,411) and worn_drop_offhand (1,494) UNCHANGED** — confirms the fix is
  armor-only, weapon/offhand paths untouched, as intended.
- **End-to-end trace, all PASS**: Phantom Guardsman (16425) — `worn_drop_scope` row present
  (`material_id=4`, the scope-level legacy/offhand-fallback value; the REAL per-slot material,
  resolved independently per (display,slot) as always since the session-6 material pivot, is
  Mail=3), all 4 of his display variants (16454-16457) have 7 full slot rows each at material=3
  (Mail), `worn_drop_item` confirmed present at his exact band 70 for all 7 slots x4 qualities.
  The other 4 opera-event ghosts (Attendant/
  Valet/Guest/Stagehand, all their model variants) also independently confirmed fully covered
  (3-4 slot rows per display, matching their own resolved material). Attumen's weapon rows
  unaffected (still present, `worn_drop_weapon`/`worn_drop_item` untouched by this armor-only fix).
- **Rebuild + restart**: same image rebuild as Bug 1 (both fixes shipped in the SAME rebuild+restart
  cycle) — boot log: `mod-worn-drops: loaded 13701 scope, 14271 displays, 2562 tabard-maps, 10306
  weapon-maps, 1490 offhand-maps, 2094 plate-overrides, 217217 items.` clean, zero errors.
- **Found but NOT fixed this session (pre-existing, unrelated to either reported bug, low priority)**:
  164 `worn_drop_scope` rows point at a creature whose display has ZERO real armor evidence at all
  (e.g. entry 98 "Riverpaw Taskmaster", a Gnoll — `ExtendedDisplayInfoID=0`) — clearly STALE rows
  from an OLDER, pre-session-9 scope-assignment mechanism (before evidence-gating existed) that no
  partial-append session has ever cleaned up. Harmless in practice (the armor roll just wastes a
  chance and produces nothing — `WD_Display.find()` returns `end()`), but worth a dedicated cleanup
  pass (`DELETE FROM worn_drop_scope WHERE creature_entry NOT IN (<creatures with >=1 real
  worn_drop_display/worn_drop_offhand row>)`) in a future session. Also unaddressed: at least one
  obviously QA/test creature name slipped into the new 823 despite the `[dnd]` filter (which DID
  correctly exclude both "[DND] Dalaran Sewer Arena - Controller" AND its "...- Death" sibling,
  verified 0 rows for entry 32328/32339 in `worn_drop_scope` post-apply) — entry 128 "Angry
  Programmer Tweedle Dee" (type=10, no bracket/junk-word match) is now in scope with a Cloth armor
  set. Low-impact (harmless if a player ever actually finds/kills it — correct item-type consistency
  regardless, just silly content), noted for a future naming-stoplist audit pass, not blocking.
- **MPQ rebuild needed**: YES — 8,292 new `Item_custom.csv` rows + 686 new `ItemDisplayInfo_custom.csv`
  rows, on top of whatever the user hasn't yet rebuilt from prior sessions (bundle together as always).

## SESSION 16 (2026-07-06) — Angerforge (9033) "zero drops" report: EXHAUSTIVE VERIFICATION, NO BUG FOUND, 2 new durable facts recorded
User report: killed General Angerforge (BRD boss, entry 9033) on PTR at drop-all test config
(Chance=100/WeaponChance=100/ArmorPerKill=0=all/WeaponPerKill=0=all/LevelDiffMax=0) and got ZERO
worn-drops items. Traced the ENTIRE chain end-to-end against live `acore_world_ptr` + the running
`ac-worldserver-ptr` container — **every single link checks out correct; no data/config/C++ bug was
found for this creature**. Full checklist (all confirmed against LIVE data, not assumed):
- `creature_template` 9033: type=7 (Humanoid, never excluded), npcflag=0, unit_class=1 (Warrior),
  minlevel=maxlevel=57, AIName empty, ScriptName=`boss_general_angerforge` (`src/server/scripts/
  EasternKingdoms/BlackrockMountain/BlackrockDepths/boss_general_angerforge.cpp` — plain `ScriptedAI`,
  no `JustDied` override, no special death handling that could bypass `Unit::Kill()`'s normal
  reward/loot/hook path; only mechanic is HP<21%→`SummonAdds`/`SummonMedics`, no model/health-clamp
  trickery unlike Attumen).
- `worn_drop_scope`: row present, `material_id=6` (PROGRESSION_WARRIOR sentinel), `plate_override=1`
  (he wields a 2H axe — `creature_equip_template` ItemID1=11342 "Monster - Axe, 2H Pendulum of
  Doom", class=2/subclass=1/InvType=17 — subclass 1 = Axe2H, inside `TWOH_MELEE_SUB`; at band>=40
  this unconditionally forces Plate(4) regardless of the display's own art-vote, correct per the
  session-10 spec, thematically right for a Dark Iron general).
- `creature_template_model`: single row, `CreatureDisplayID=8756` (no multi-model roll to worry
  about). `worn_drop_display` has **5 rows for display 8756** (slots 2/5/6/7/9 = Shoulder/Belt/
  Legs/Boots/Gloves, all `material_id=6`) — Head/Chest/Wrist/Cape have no baked-armor evidence for
  this look (**not a bug**, same as every other partially-baked NPC model in this dataset, e.g. the
  session-5 "Следопыт Длани" chest case — his skin bakes those slots directly, no separate item
  layer exists to derive from).
- `worn_drop_item`: **band=55 (his live level 57 → `(57/5)*5=55`, matches C++'s band formula
  exactly) has a full Plate(4) row-set for ALL 5 of his looks** (21235/17939/21237/17936/17937,
  all 4 qualities each) — confirmed directly, not inferred. Weapon: `worn_drop_weapon` has
  `(9033, wslot=21, look=21238, subclass=1)`, and `worn_drop_item` has the matching band=55/
  subclass=1 row-set too (`entry` 1016660-63). `worn_drop_offhand`: correctly empty (ItemID2/3=0,
  he has no shield/held item).
- **PTR config, read directly from the file the running container actually mounts**
  (`env/dist/etc/modules/mod-worn-drops.conf` inside `ac-worldserver-ptr`) — confirmed
  `Chance=100/WeaponChance=100/TabardChance=100/BossMultiplier=4.0/ArmorPerKill=0/WeaponPerKill=0/
  LevelDiffMax=0`, and independently reconfirmed via the boot log's own config-echo line
  (`chance=100.0% weaponChance=100.0% tabardChance=100.0% bossMultiplier=4.0x ...`) — the two
  sources agree, ruling out "stale/wrong conf file being read" entirely.
- **Boot log confirms the session-15 dataset is loaded**: `mod-worn-drops: loaded 13701 scope,
  14271 displays, 2562 tabard-maps, 10306 weapon-maps, 1490 offhand-maps, 2094 plate-overrides,
  217217 items.` — exact match to session 15's end state, so this is not a stale-DB issue either.
- **The running `ac-worldserver-ptr` image (`azerothcore-wotlk-ac-worldserver-ptr:latest`,
  id `86e81e7a4d04`) was built TODAY** (2026-07-06, container started same day) **from the current
  source tree, which already contains session 15's `HandleKill()`/`OnPlayerCreatureKilledByPet`
  refactor** (confirmed by reading `modules/mod-worn-drops/src/mod_worn_drops.cpp` directly — no
  uncommitted diff exists against this file, `git status` at session start showed zero pending
  changes to it) — the pet-kill fix is definitely compiled into the binary the user tested against.
  **Context, not a bug**: this rebuild coincides with an UNRELATED, independently-running
  live-deployer promotion package for the same session-15 delta
  (`.claude/agent-memory/live-deployer/packages/2026-07-06_1300-mod-worn-drops-session15/`,
  targeting LIVE `acore_world`/`ac-worldserver-v2`, prepared same day) — not touched by this
  investigation, noted purely to explain why the PTR image timestamp is today rather than
  session-15's original 2026-07-05 date; no evidence it altered PTR's worn-drops data (full
  per-table trace above shows everything intact and correct).
- **`Loot::AddItem` cap theory investigated and RULED OUT for this specific creature**: `LootMgr.h`
  defines `MAX_NR_LOOT_ITEMS=18` (non-quest) / `MAX_NR_QUEST_ITEMS=32` (quest); `Loot::AddItem`
  (`src/server/game/Loot/LootMgr.cpp`) silently no-ops (`for (...; lootItems.size() < limit; ...)`,
  zero log/error) once either cap is hit — since `OnPlayerCreatureKill` fires AFTER the stock
  `creature_loot_template` roll already populated `creature->loot`, a boss with a big enough
  guaranteed-loot table COULD theoretically starve our module's `AddItem` calls with no trace at
  all. Checked directly: Angerforge's own `creature_loot_template` has only **12 total rows** (1
  guaranteed QuestRequired item, a handful of chance-based trash, 5 GroupId=1 "pick one" boss-drop
  candidates) — nowhere close to 18, ruled out for him. **Swept the WHOLE worn-drops scope for this
  class of risk** (`creature_loot_template` rows with `Chance=100 AND QuestRequired=0` grouped by
  Entry, `HAVING COUNT(*)>=10`, restricted to `Entry IN (SELECT creature_entry FROM
  worn_drop_scope)`) — **0 creatures currently at risk** (guaranteed-row counts are all low across
  the board). **Recorded as a durable fact for any FUTURE "boss killed, nothing worn-drops dropped"
  report**: always check the boss's OWN `creature_loot_template` row count/guaranteed-chance rows
  before assuming a pipeline bug — this failure mode produces literally zero log output on either
  side (stock loot fill or our own `AddItem`), the ONLY way to catch it is checking `creature_loot_
  template` row counts directly, no SQL check in `validation.md` can catch it (it's a RUNTIME/RNG
  condition, not a static data-correctness issue).
- **One remaining, genuinely unfixable-via-hooks kill-attribution gap identified (not proven to be
  THIS report's cause, no per-kill server log exists to confirm retroactively)**: `Unit::Kill()`
  resolves `killer` from the raw killing-blow object; if `killer` is null (killer left the map, an
  ownerless/untraceable damage source, e.g. a very late-ticking DoT or environmental damage with no
  live caster reference) NEITHER `OnPlayerCreatureKill` NOR `OnPlayerCreatureKilledByPet` fires —
  grepped `PlayerScript.h` for every kill-related hook (`OnPlayerCreatureKill`,
  `OnPlayerCreatureKilledByPet`, `OnPlayerKilledByCreature` — the last is the inverse, player-died
  case) and confirmed **there is no third hook for "killed by an untraceable source"** — closing this
  would require a core-level change (e.g. hooking `Creature::JustDied`/`Unit::Kill()` itself, which
  fires for EVERY creature death including ones with no player involvement at all, a much bigger
  scope change), not a `mod-worn-drops`-side fix. Noted for awareness only, not actioned.
- **Verdict**: no code change made, no SQL applied, no rebuild performed this session (nothing to
  fix was found). **Re-test guidance given to the user**: kill Angerforge again now — the currently
  running PTR image+DB are independently verified correct end-to-end for this creature, so a normal
  player-damage killing blow (not letting a pet/summoned add score the finishing hit, to rule out
  the one remaining unfixable edge case above) should reliably drop his 5-piece Plate set + 2H axe
  under the current 100%-everything test config. If a repeat kill STILL drops nothing, the next step
  is temporary debug logging inside `HandleKill()` (log `killer`'s type/entry, `band`, `plateOverride`,
  and each `AddWornItem` lookup's hit/miss) to capture a live trace of the actual failure — offered,
  not yet added (no evidence yet that a repeat will actually fail, would be speculative instrumentation
  with no confirmed target condition to catch).
