# Nemesis Familiar System — Implementation Log

Implementation log for Phase 2 of the design at [familiar_system_design.md](familiar_system_design.md).

Session date: 2026-04-22

## Status at end of session

- **Server-side**: 3 Tier-1 familiars fully wired in the DB (tank / damage / mage). `.cast 100050/100051/100052` summons a companion that follows. Item vendor rows are in place.
- **Client MPQ**: `Spell_custom.csv` and `Item_custom.csv` rebuilt and deployed. Pet tab now shows the 3 familiars with correct icons; tooltip + name render correctly in ruRU.
- **Per-familiar auras (+1% armor / crit / spell-crit)**: implemented as separate passive `spell_dbc` rows (101100/101101/101102), applied/removed by a C++ hook in `NemesisSystemAllCreatureScript` (`OnCreatureAddWorld` / `OnCreatureRemoveWorld`). Kept out of the summon spell itself because a second effect would break companion-menu classification (see bug #8). Buff-bar icon pre-MPQ is generic; stats apply correctly server-side.
- **Unified icons across all 3 familiars**:
  - Scroll item icon → `displayid = 20629` (`inv_box_petcarrier_01`, same pet-carrier box used by stock Worg Carrier / Sprite Darter Egg / Mechanical Chicken).
  - Summon spell icon → `SpellIconID = 1582` (Mechanical Yeti's icon — known-good stock 3.3.5a value). Earlier attempt used `132311` (modern FileDataID for ability_seal) which rendered blank in 3.3.5a because valid SpellIconID range is 1..4375; the client silently fell back to no icon when the lookup failed.

## ID pool for the Nemesis Familiar System

Reserved ranges (keep T2–T5 and any new roles inside these blocks to avoid
collisions with StatBooster and other modules):

| Range | Purpose | Size | Usage so far |
|---|---|---|---|
| `100120` – `100134` | Familiar summon spells | 15 | T1: 100120/100121/100122 |
| `100030` – `100044` | Familiar scroll items | 15 | T1: 100030/100031/100032 |
| `190010` – `190024` | Familiar creatures | 15 | T1: 190010/190011/190012 |
| `101100` – `101114` | Familiar owner-aura spells | 15 | T1: 101100/101101/101102 |
| `190000` | Bounty-board vendor (innkeeper) | 1 | Existing |
| `100001` | `itemextendedcost_dbc` — 10 Bounty Tokens | 1 | Existing |
| `100017` | Nemesis Bounty Token item | 1 | Existing |

Ranges below are *recommended slots* for future tiers (3 roles × 5 tiers = 15
entries each):

- T1 = offset +0..2 (tank / damage / mage), T2 = +3..5, T3 = +6..8, T4 = +9..11, T5 = +12..14.
- So T2 would use summon spells `100123/100124/100125`, auras `101103/101104/101105`, creatures `190013/190014/190015`, scrolls `100033/100034/100035`.

**Important:** spell IDs 100050–100063 are used by StatBooster (`+X Spell Damage` pool3 auras). Familiar summon IDs must stay inside 100120+ to avoid collision.

### Spells (`spell_dbc`)
| ID | Role | Effect shape |
|---|---|---|
| 100120 | Summon Familiar: Guardian Wolf Cub | Pure `SPELL_EFFECT_SUMMON` (28) → creature 190010, SummonProperties 41 |
| 100121 | Summon Familiar: Falcon Chick | Same pattern → creature 190011 |
| 100122 | Summon Familiar: Raven Fledgling | Same pattern → creature 190012 |
| 101100 | Familiar Aura: Guardian Wolf Cub | `APPLY_AURA` → +1% armor (`MOD_RESISTANCE_PCT`, school mask 1), 30 min |
| 101101 | Familiar Aura: Falcon Chick | `APPLY_AURA` → +1% melee crit (`MOD_CRIT_PCT`), 30 min |
| 101102 | Familiar Aura: Raven Fledgling | `APPLY_AURA` → +1% spell crit (`MOD_SPELL_CRIT_CHANCE`), 30 min |

Aura shape (fixed 2026-05-17): `Attributes=0` (NOT passive — `PASSIVE=64` caused triggered `CastSpell` to silently no-op), `DurationIndex=21` (30 min — matches companion duration), `ProcChance=101` (without ProcChance the APPLY_AURA effect is silently discarded on creation — see `feedback_spell_dbc_aura_fields.md`). Re-applied automatically on re-summon, removed explicitly by the C++ hook on dismiss.

**Historical note:** the original migration (commit 7ce2c7cb6) shipped with `Attributes=64, DurationIndex=0, ProcChance=0` — exactly the failure mode that bug #13 below documented as "fixed". The fix had been described in this doc but never actually landed in `nemesis_familiars_t1.sql`. Fixed in-place 2026-05-17 after rediscovery during audit. Verify any "✓ fixed" claim against the SQL itself.

Standard shape for all three (verified against stock Worg Pup 15999 in client Spell.csv):

```
Attributes        = 262416 (0x40150)
CastingTimeIndex  = 1   (instant)
DurationIndex     = 21  (30 min)
RangeIndex        = 1   (self)
EquippedItemClass = -1
Effect_1          = 28  SPELL_EFFECT_SUMMON
EffectMiscValue_1 = <creature entry>
EffectMiscValueB_1= 41  (SummonProperties row id → MINIPET)
ImplicitTargetA_1 = 32  TARGET_DEST_CASTER_SUMMON
Effect_2          = 0   (none — stripped; was APPLY_AURA, broke classification)
SchoolMask        = 1
SpellIconID       = 1582    (Mech Yeti icon — unified across all 3 T1 familiars;
                             must stay in 3.3.5a valid range 1..4375)
```

### Creatures (`creature_template` + `creature_template_model` + `creature_template_locale`)
| Entry | Name (EN) | Name (RU) | Display ID | Source |
|---|---|---|---|---|
| 190010 | Guardian Wolf Cub | Волчонок-Страж | 9563 | Worg Pup (creature 10259 — AV "Worg Carrier" companion) |
| 190011 | Falcon Chick | Соколёнок | 6299 | Hawk Owl (creature 7555 — stock non-combat pet) |
| 190012 | Raven Fledgling | Вороненок | 6435 | Raven (creature 7605) |

**Display ID correction (2026-05-17):** initial values were 903 / 6573 / 15533 — wildly off-target (Mangy Wolf adult / Ravenholdt Guard *human* / Vekniss Hive Crawler *insect*). Replaced with the stock minipet-grade models above after verifying via the local creature_template DB. When picking a model, always cross-check with `SELECT entry, name FROM creature_template ct JOIN creature_template_model ctm ON ct.entry = ctm.CreatureID WHERE ctm.CreatureDisplayID = <id>` before committing.

Spell icon (shared across all three): `SpellIconID = 1582` (Mech Yeti icon, valid 3.3.5a SpellIcon.dbc row).

Shared settings:
```
type       = 7   (CRITTER)
family     = 0   (not a hunter-pet family)
AIName     = ''  (empty — lets FollowerAI auto-install on summon)
faction    = 35  (friendly to all)
npcflag    = 0
```

### Items (`item_template` + `item_template_locale`)
| Entry | Name (EN) | Name (RU) |
|---|---|---|
| 100030 | Scroll of Summoning: Guardian Wolf Cub | Свиток призыва: Волчонок-Страж |
| 100031 | Scroll of Summoning: Falcon Chick | Свиток призыва: Соколёнок |
| 100032 | Scroll of Summoning: Raven Fledgling | Свиток призыва: Вороненок |

Shared settings mirror stock Worg Carrier (item 12264) / Sprite Darter Egg (11474):
```
class          = 15    (Miscellaneous)
subclass       = 2     (Companion Pet)
Quality        = 3     (rare)
Flags          = 64    (stock companion-item flag)
MaxCount       = 0     (unlimited inventory count — matches stock)
stackable      = 1
bonding        = 1     (BoP)
Material       = 4     (parchment)
displayid      = 20629 (inv_box_petcarrier_01 — same icon stock companion
                        scrolls use in inventory)
SellPrice      = 100

spellid_1      = 55884  (hardcoded universal teach wrapper — see
                         AuctionHouseSearcher.cpp:697 comment)
spelltrigger_1 = 0      (USE)
spellcharges_1 = -1     (consumed on use)

spellid_2      = 100050/100051/100052  (actual summon spell)
spelltrigger_2 = 6      (LEARN_SPELL_ID — core teaches this on USE via the 55884 wrapper)
spellcharges_2 = 0
```

### Vendor (`npc_vendor` entry 190000 — the bounty board innkeeper)
| Slot | Item | ExtendedCost | Tokens |
|---|---|---|---|
| 100 | 100030 (tank scroll) | 100001 | 10 |
| 101 | 100031 (damage scroll) | 100001 | 10 |
| 102 | 100032 (mage scroll) | 100001 | 10 |

No gossip rank gating yet (Phase 5 work).

## Client-side DBC additions (not yet in MPQ)

### `Spell_custom.csv` — 3 new rows
Full 232-column entries for 100050, 100051, 100052 mirroring the server `spell_dbc` shape. Russian text in `Name_Lang_zhTW` / `Description_Lang_zhTW` slots per the ruRU client quirk documented in `project_custom_items_mpq.md`.

### `Item_custom.csv` — 3 new rows
```
ID,ClassID,SubclassID,SoundOverrideSubclassID,Material,DisplayInfoID,InventoryType,SheatheType
100030,15,2,-1,4,20629,0,0
100031,15,2,-1,4,20629,0,0
100032,15,2,-1,4,20629,0,0
```

DisplayInfoID 20629 = `inv_box_petcarrier_01` (pet carrier box); Material 4 = parchment.

## Files touched

### Server SQL migration — consolidated
- `data/sql/updates/pending_db_world/nemesis_familiars_t1.sql` — single file with all Tier-1 content (3 summon spells + 3 owner-aura spells + 3 creatures + 3 scrolls + 3 vendor rows).

**Why one file, and why this path:** the module-local path (`modules/mod-nemesis-system/data/sql/db-world/updates/`) is **not** scanned by `ac-db-import`, so migrations there were silently skipped and `spell_dbc` rows got wiped on every `docker compose up --build` (the import step reloads base Spell.dbc from scratch and our custom rows aren't registered in the `updates` tracking table). The project convention per root `CLAUDE.md` is:
> SQL updates go in `data/sql/updates/pending_*` with separate subdirectories per database until pull request is merged.

So the file now lives at `data/sql/updates/pending_db_world/` and is auto-applied on every rebuild. The 4 earlier per-family/per-aura files (`2026_04_22_01…04`) were consolidated into this single file and removed.

### Server C++ — `modules/mod-nemesis-system/src/NemesisSystem.cpp`
- New includes: `TemporarySummon.h`, `ObjectAccessor.h`.
- Added `GetFamiliarOwnerAuraSpell(uint32 entry)` helper mapping familiar creature entries to their aura spell.
- `NemesisSystemAllCreatureScript::OnCreatureAddWorld` — early branch: if entry is a familiar, resolve the owning `Player*` via `TempSummon::GetSummonerUnit()` (fallback to `GetOwner()`), cast the owner aura with `triggered=true`, then `return` (familiars are not nemeses).
- `NemesisSystemAllCreatureScript::OnCreatureRemoveWorld` — symmetric lookup + `RemoveAurasDueToSpell` before the existing temporary-nemesis cleanup.

### Client DBC CSVs (shared, moved this session from `.claude/statBoosterItems/dbc/` → `.claude/dbc/`)
- `.claude/dbc/Spell_custom.csv` — 3 familiar rows appended
- `.claude/dbc/Item_custom.csv` — 3 scroll rows appended

### Design doc
- `.claude/familiars/familiar_system_design.md` (до 2026-06-07 — `.claude/nemesis/`) — restructured to match what was actually implemented; added "Confirmed values from Phase 2 prototyping" table; corrected the owner-only aura section; removed Pattern A (proven unworkable).

### Docs path refactor
- All `.claude/statBoosterItems/**` docs updated to point to `.claude/dbc/` instead of `.claude/statBoosterItems/dbc/`, and to drop the `_custom16` suffix (files renamed to `Spell_custom.csv` / `Item_custom.csv` / `SkillLineAbility_custom.csv` etc.).

## Debugging trail — what broke and what fixed it

This is the sequence of bugs found while getting `.cast 100050` to actually summon a follower-pet. Each row is a *distinct* problem; none are theoretical.

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | Item use does nothing | Items 100030–32 not in client Item.dbc | Add rows to `Item_custom.csv` for MPQ rebuild |
| 2 | `.cast 100050` silent no-op | **`Effect_1 = 75` is `SPELL_EFFECT_HEAL_MECHANICAL`**, not SUMMON | Change to **28** (`SPELL_EFFECT_SUMMON`) per `SharedDefines.h:794` |
| 3 | Still silent after #2 | `ImplicitTargetA_1 = 1` (TARGET_UNIT_CASTER) doesn't populate `destTarget` for SUMMON → `SummonCreature` no-ops | Change to **18** (TARGET_DEST_CASTER) first, then **32** (TARGET_DEST_CASTER_SUMMON) to match stock |
| 4 | Still silent | `RangeIndex = 0` — unset range → `SpellInfo::RangeEntry` null → cast rejected | Set to **1** (self) |
| 5 | Wolf spawns but doesn't follow | `AIName = 'SmartAI'` overrides FollowerAI that the minipet summon path would install | Set `AIName = ''` (empty); drop SAI row |
| 6 | Aura didn't land on owner | `creature_template.auras` applies auras via direct `AddAura` — bypasses `Spell::Effect` target resolution; `TARGET_UNIT_MASTER` doesn't redirect | Merged aura into summon spell as `Effect_2` with ImplicitTargetA=1 (caster). Worked but caused problem #8. |
| 7 | Wolf appeared but NOT in Companions tab | `EffectMiscValueB_1 = 64` is **not** the MINIPET SummonProperties row in 3.3.5a. 64 was wrong; 3001 (from one research round) is also wrong | Verified from user's own `.claude/dbc/Spell.csv`: stock Worg Pup (15999), Mech Chicken (12243), Sprite Darter (15067) all use **41**. Set `EffectMiscValueB_1 = 41` |
| 8 | Still not in Companions tab after #7 | Having `Effect_2 = APPLY_AURA` on a summon spell disqualifies it from AC's companion flagging — stock companions are single-effect pure summons | **Removed Effect_2 entirely.** Auras now a follow-up (see Open items) |
| 9 | Item scroll still didn't dispatch properly | Our `spellid_1 = <summon>, spelltrigger_1 = 6` was not the stock pattern. Stock uses `spellid_1 = 55884` (AC's hardcoded teach wrapper), `spellid_2 = <summon>`, `spelltrigger_2 = 6` — documented at `AuctionHouseSearcher.cpp:697` comment | Reworked items to the stock two-slot pattern |
| 10 | Pet tab entry shows but icon is blank (tooltip fine) | `SpellIconID = 132311` is a modern FileDataID; 3.3.5a `SpellIcon.dbc` row ids max out at 4375. Client found no row → silent blank fallback. Confirmed via `.claude/dbc/Spell.csv`: no stock row exceeds ~4375 | Set `SpellIconID = 1582` (Mech Yeti's icon — known-good stock value). Rebuilt MPQ + cleared `WDB/` → icon renders |
| 11 | Rebuild wiped custom `spell_dbc` rows | Migrations under `modules/mod-nemesis-system/data/sql/db-world/updates/` are not scanned by `ac-db-import`; `spell_dbc` is re-extracted from base DBC on every rebuild so our rows silently disappeared | Consolidated all 4 familiar migrations into a single file at `data/sql/updates/pending_db_world/nemesis_familiars_t1.sql` (the auto-scanned path per root CLAUDE.md) — now auto-applied on rebuild |
| 12 | Owner aura not applied even after summon | For minipets (SPELL_EFFECT_SUMMON + SummonProperties 41), AC uses `TempSummon` and sets summoner GUID — NOT `m_ownerGUID`. `creature->GetOwner()` returned null, so the aura cast path never executed | Changed hook to use `TempSummon::GetSummonerUnit()` with `GetOwner()` as fallback. Added `#include "TemporarySummon.h"` and `"ObjectAccessor.h"` |
| 13 | `.cast 101100` on self did nothing | `Attributes = 64 (SPELL_ATTR0_PASSIVE)` routes passives through a "learned-only" path; triggered `CastSpell` silently no-ops for them | `Attributes = 0`, `DurationIndex = 21` (30 min matches companion). Aura is explicitly applied/removed via the C++ hook |
| 14 | StatBooster enchants `90110/90111/90112` silently broke on re-equip | We used spell IDs `100050/100051/100052` which were **already claimed** by StatBooster's `statbooster_pool3_base.sql` as "+5 Arcane / +5 Holy / +7 Fire Spell Damage" passives. Our `REPLACE INTO spell_dbc` overwrote them, so on item re-equip the enchant path cast our summon spell instead of applying the damage aura | Moved familiar summons to clean range **100120–100134** (T1: 100120/100121/100122). Restored StatBooster rows at 100050/051/052 inside our migration. Updated scroll `spellid_2` and migrated any already-learned `character_spell` rows |

## Stock companion reference data (verified)

All values below are pulled directly from the user's `.claude/dbc/Spell.csv` (extracted client DBC) and `item_template` DB:

### Summon-spell shape

| Spell | Name | Creature | MiscValueB | TargetA | Duration | Attributes |
|---|---|---|---|---|---|---|
| 15999 | Summon Worg Pup | 10259 | 41 | 32 | 21 | 262160 |
| 12243 | Summon Mechanical Chicken | 8376 | 41 | 32 | 21 | 262416 |
| 15067 | Summon Sprite Darter Hatchling | 9662 | 41 | 32 | 21 | 262160 |

`EffectMiscValueB = 41` and `ImplicitTargetA = 32` are the canonical values for minipets in 3.3.5a — confirmed across 3+ unrelated stock spells. Our custom spells now match this exactly.

### Companion-scroll item shape

| Item | Name | class | subclass | spellid_1 | trigger_1 | spellid_2 | trigger_2 | Flags | bonding | Material |
|---|---|---|---|---|---|---|---|---|---|---|
| 12264 | Worg Carrier | 15 | 0 | 55884 | 0 | 15999 | 6 | 64 | 1 | 4 |
| 11474 | Sprite Darter Egg | 15 | 2 | 55884 | 0 | 15067 | 6 | 64 | 1 | 4 |
| 10398 | Mechanical Chicken | 15 | 2 | 55884 | 0 | 12243 | 6 | 64 | 3 | -1 |
| 23007 | Piglet's Collar | 15 | 2 | 55884 | 0 | ? | ? | 64 | 1 | -1 |
| 29364 | Brown Rabbit Crate | 15 | 2 | 55884 | 0 | ? | ? | 64 | 3 | -1 |

Subclass 2 (Companion Pet) is the dominant pattern; subclass 0 on Worg Carrier is a legacy outlier. We use 2.

`spellid_1 = 55884` across all stock companion items — this is the universal teach wrapper hardcoded in AzerothCore to read the real target spell from `Spells[1]`. Confirmed by the comment at `src/server/game/AuctionHouse/AuctionHouseSearcher.cpp:697`:

> "Spells are learned through 483 and 55884, the second spell in the item will be the actual spell learned."

## Open items

### 1. ~~Rebuild MPQ~~ ✓ Done

MPQ rebuilt and deployed. All 3 familiars are visible in the Pet tab with their correct icons. Tooltip and Russian names render correctly.

### 2. ~~Reintroduce per-familiar auras~~ ✓ Done (server-side), partial (client)

Implemented via **Option 1** (server C++ hook) — see "Files touched" above. Auras: 101100 (+1% armor), 101101 (+1% melee crit), 101102 (+1% spell crit). Applied/removed in `OnCreatureAddWorld` / `OnCreatureRemoveWorld`.

**Still open:** client-side buff-bar icons/names will be generic until Spell.dbc rows are added for 101100–101102 via the next MPQ rebuild. Stats apply correctly without this; it's purely cosmetic.

### 3. Rank gating via gossip (Phase 5 of design)

Still open. Currently all 3 T1 scrolls are visible in the vendor regardless of player rank. Gossip filter is noted in the design doc — implemented only after T2–T5 content is in.

### 4. T2–T5 content

Each tier follows the same shape: one summon creature + one summon spell + one scroll item. Scale the T1 SQL migration pattern; bump aura values per the design doc's ladder.

### 5. T5 kill-stack mechanic

Server `OnCreatureKill` hook applies a stackable buff keyed off the nemesis kill event (same trigger as bounty token grant). Deferred to after T1 works end-to-end.

## How to apply / rollback what exists

### Apply
```
docker exec -i ac-database-v2 mysql --default-character-set=utf8mb4 \
  -uroot -ppassword acore_world \
  < data/sql/updates/pending_db_world/nemesis_familiars_t1.sql

# In-game: .reload spell_dbc   (or: docker restart ac-worldserver-v2)
```

Or just rely on auto-apply: `docker compose up -d --build ac-worldserver` will run db-import which re-applies the file.

Always use `--default-character-set=utf8mb4` or the Cyrillic names will double-encode (see `feedback_sql_charset.md` in memory).

### Rollback (if needed)
```sql
-- Three spells
DELETE FROM spell_dbc WHERE ID IN (100050, 100051, 100052);

-- Three creatures (+ locale + model)
DELETE FROM creature_template WHERE entry IN (190010, 190011, 190012);
DELETE FROM creature_template_model WHERE CreatureID IN (190010, 190011, 190012);
DELETE FROM creature_template_locale WHERE entry IN (190010, 190011, 190012);

-- Three items (+ locale)
DELETE FROM item_template WHERE entry IN (100030, 100031, 100032);
DELETE FROM item_template_locale WHERE ID IN (100030, 100031, 100032);

-- Vendor rows
DELETE FROM npc_vendor WHERE entry = 190000 AND item IN (100030, 100031, 100032);
```

Revert the MPQ by redeploying the previous patch without our custom DBC rows (or removing the last-loading MPQ if only these changes were in it).

## Test plan (once MPQ is rebuilt)

1. **Server-side direct**: `.cast 100050` — wolf cub appears and follows. (Already verified.)
2. **Pet menu classification**: `.learn 100050` → open Pet menu (`Shift-P` → Companions tab) → wolf cub entry with icon 381 appears; click to summon/dismiss.
3. **Item use flow**: from a character with 10 bounty tokens, visit any innkeeper → bounty board gossip → buy "Scroll of Summoning: Guardian Wolf Cub" → right-click → spell permanently learned → companion appears in Pet menu.
4. **Multiple familiars**: learn all 3 T1 summons → all 3 appear in Pet menu simultaneously → summoning a new one replaces the old (standard minipet behavior).
5. **Russian rendering**: on ruRU client, tooltip and Pet menu show Russian names (Волчонок-Страж etc.) correctly — no mojibake.

## References

- Design doc: [familiar_system_design.md](familiar_system_design.md)
- Encoding rule (Cyrillic SQL imports): memory file `feedback_sql_charset.md`
- Custom items / MPQ workflow: memory file `project_custom_items_mpq.md`, `.claude/guide_mpq_patching.md`
- StatBooster DBC pattern (reference for similar custom-spell work): `.claude/statBoosterItems/instructions/CUSTOM_SPELLS.md`
- AC comment on the 55884 universal teach wrapper: `src/server/game/AuctionHouse/AuctionHouseSearcher.cpp:697`
- SUMMON effect implementation: `src/server/game/Spells/SpellEffects.cpp:2349,2439-2466`
