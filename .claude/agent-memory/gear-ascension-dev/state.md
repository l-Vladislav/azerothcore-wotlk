# Gear Ascension -- state & locked decisions

Module repo: `modules/mod-gear-ascension/` (own git repo). Design: `docs/DESIGN.md`.
Main-repo branch for SQL/conf/core: `feat/wow-ak-1-gear-ascension` (off `custom`).

## Locked decisions (confirmed by owner)
- Ceiling = Epic/purple (Quality 4); steps = `4 - baseQuality`.
- +10% per step, cumulative from ORIGINAL quality; weapons too (min/max dmg);
  round up; ItemLevel does NOT change.
- Architecture = tier-copies (entry per tier), NOT runtime mutation. Tier = entry.
- Mechanic = kit-on-item (ItemScript OnUse + use-spell TARGET_ITEM), NO upgrade NPC.
- Success: green 95% / blue 75% / purple 50%; fail downgrades only on the purple
  step; NO protection charm.
- Materials = profession kits (7 categories: metal/leather/cloth/jewel/weapon_melee/
  weapon_magic/weapon_ranged) by item category; 21 kits (200000-200020);
  kit tier = target quality; sold by vendor for tavern coin (item 110150); tier
  gated by Nemesis rank.
- On upgrade: copy SOCK slots (gems kept), drop PERM slot (player enchant), keep bind.
- Bind on upgrade = same as the item (no new binding).
- **Nemesis rank thresholds (confirmed 2026-06-18):**
  - to_quality=2 (kit tier I, -> green): rank 1
  - to_quality=3 (kit tier II, -> blue): rank 3
  - to_quality=4 (kit tier III, -> purple): rank 5

## Full Phase-1 scope decision (2026-06-18, REFINED -> Classic-only)
- **Classic ONLY** (vanilla, pre-TBC) -- exclude BOTH TBC and WotLK. Owner refined
  the earlier "Classic+TBC" down to Classic only.
- **Best filter (recommended):** item obtainable from VANILLA-WORLD sources only --
  source on maps 0/1 (Eastern Kingdoms / Kalimdor), NOT Outland (530) or Northrend
  (571). Truest "Classic content" definition.
- **Quick proxies (less precise):** `RequiredLevel <= 60` (vanilla cap) and/or
  vanilla item-id range `entry < ~24000` (TBC starts ~24000, WotLK ~37000).
- Pin the exact filter + get the real Classic base count BEFORE mass-generation.
- Rationale: gentler climb; avoid TBC/WotLK high-ilvl near-BiS upgrades.

## Eligibility (grounding from acore_world_ptr, 2026-06-18)
`class IN (2,4) AND RandomProperty=0 AND RandomSuffix=0 AND itemset=0`, non-junk,
and **obtainable** (loot/vendor/container source).
- Raw green/blue (no junk filter): green 4659 + blue 4158 -> 13,476 copies.
- Name-filtered (no QA/test/junk): green 4391 + blue 4030 -> 12,812 copies.
- **Obtainable (ALL sources): 7374 of 8536 (86%); only 1162 non-obtainable.**
- White (Phase 2): 1817 bases -> 5,451 copies.
- WARNING: raw filter catches dev junk -- always require an obtainable source +
  name/Flags exclusion.

## Phases
1. green/blue obtainable bases -- pure x% on existing stats. **PROTOTYPE DONE &
   VALIDATED ON PTR (2026-06-18, 18 bases / 28 copies at 300001-300171). UPGRADE LOOP BUILT
   (kits + C++ + nemesis_rank, 2026-06-18). ID block migrated 1M->300k (2026-06-18).
   Next: rebuild PTR + owner test.**
2. white bases -- generate stats from ilvl (whites have none).
3. set items -- ItemSet.dbc handling.

## Prototype -- BUILT & VERIFIED on acore_world_ptr (2026-06-18)
- **Generator:** `modules/mod-gear-ascension/scripts/gear-ascension-gen-sql.ps1`
  (repeatable; queries the PTR DB for base metadata, emits SQL + Item.dbc rows).
  Now emits correct nemesis_rank (1/3/5 by to_quality 2/3/4).
- **DDL:** `item_upgrade_chain` (CREATE TABLE IF NOT EXISTS, full DESIGN sec-9
  column set). nemesis_rank now correctly set to 1/3/5 (updated 2026-06-18).
- **Generated SQL:** `data/sql/updates/pending_db_world/gear_ascension_proto.sql`
  Applied to PTR. nemesis_rank column updated via gear_ascension_kits.sql.
- **ID MAPPING SCHEME (USED):** `new_entry = 300000 + baseIndex*10 + step`,
  step in 1..3, baseIndex = 0-based position in the base list. => base#0 ->
  300001/2/3, base#1 -> 300011/12/13, ... 9 IDs reserved per base, only `steps`
  used. Range for the 18-base proto = [300001..300171].
  (Owner decision 2026-06-18: moved from 1,000,000 block to 300,000 block for
  6-digit ID preference. Old 1M block fully cleaned from acore_world_ptr.)
- **Prototype bases (18):** 15 owner armor + 3 weapons I added for dmg scaling.

## Kits -- REBUILT 7 categories (2026-06-19)
- **SQL:** `data/sql/updates/pending_db_world/gear_ascension_kits.sql`
- **Kit entries:** 200000-200020 (21 kits, 7 categories x 3 tiers)
  - metal:         200000 (I), 200001 (II), 200002 (III)
  - leather:       200003 (I), 200004 (II), 200005 (III)
  - cloth:         200006 (I), 200007 (II), 200008 (III)
  - jewel:         200009 (I), 200010 (II), 200011 (III)
  - weapon_melee:  200012 (I), 200013 (II), 200014 (III)
  - weapon_magic:  200015 (I), 200016 (II), 200017 (III)
  - weapon_ranged: 200018 (I), 200019 (II), 200020 (III)
- **Quality per tier:** tier I = Quality 1 (white), II = Quality 2 (green), III = Quality 3 (blue).
- **Properties:** class=15 subclass=0, stackable=200, bonding=0 (tradeable),
  spellid_1=105000, ScriptName='gear_ascension_kit'.
- **DisplayIDs:**
  - metal kits (200000-200002): custom 70001/70002/70003 (gladiator achievement icons)
  - leather (200003-200005): 55479/56642/56641
  - cloth (200006-200008): 39462/57460/39454
  - jewel (200009-200011): 31204/31205/31203
  - weapon_melee (200012-200014): 24678/24680/24681
  - weapon_magic (200015-200017): 1501/38758/38760
  - weapon_ranged (200018-200020): 20624/40549/52196
- **Custom ItemDisplayInfo IDs (metal): 70001/70002/70003**
  - Max vanilla ID: 68742; custom band: 70001-70003 (below StatBooster 100xxx)
  - 70001: Achievement_FeatsOfStrength_Gladiator_05 (tier I)
  - 70002: Achievement_FeatsOfStrength_Gladiator_01 (tier II)
  - 70003: Achievement_FeatsOfStrength_Gladiator_09 (tier III)
  - Rows in `.claude/dbc/ItemDisplayInfo_custom.csv`
- **Descriptions:** item_template.description (enUS) + ruRU in item_template_locale
  stating what item types the kit upgrades and the target RARITY NAME (not color).
  enUS: "Uncommon" / "Rare" / "Epic". ruRU: "необычного" / "редкого" / "эпического".
- **Item.dbc rows:** updated in `.claude/dbc/Item_custom.csv` (200000-200020, 21 rows).

## Use-spell -- BUILT & APPLIED (2026-06-18)
- **Spell ID: 105000** ("Gear Ascension: Apply Kit")
- **spell_dbc row (canonical, 2026-06-19):** Targets=16 (TARGET_FLAG_ITEM),
  Effect_1=77 (SPELL_EFFECT_SCRIPT_EFFECT), CastingTimeIndex=5 (2000ms),
  RangeIndex=1, ProcChance=101, EquippedItemClass=-1, EquippedItemSubclass=0,
  EquippedItemInvTypes=0, **ImplicitTargetA_1=26** (TARGET_GAMEOBJECT_ITEM_TARGET),
  ImplicitTargetB_1=0, **InterruptFlags=1** (SPELL_INTERRUPT_FLAG_MOVEMENT = 0x01;
  movement cancels the cast), **SpellVisualID_1=3182** (enchant-item visual; caster anim +
  sparkles + arcane sound during 2s cast), SpellVisualID_2=0.
- **ImplicitTargetA_1=26 is CRITICAL:** without it the item-target from
  TARGET_FLAG_ITEM never resolves to the effect and OnEffectHitTarget is never
  invoked. This was the root cause of "cast completes, nothing happens" (fixed
  2026-06-19). Confirmed value from SharedDefines.h:1436.
- **SpellVisualID_1=3182:** same visual used by Enchant Item recipes (7420/7421/27944).
  Server-side for DBC parity; client only sees it after MPQ rebuild.
- **Spell.dbc CSV row:** in `.claude/dbc/Spell_custom.csv`, col85=ImplicitTargetA_1
  (0-based 84), col130=SpellVisualID_1 (0-based 129, set to 3182).
- **Gear Ascension spell ID range: 105000-105099** (reserved; 105001-105099 available
  for future needs). Do not use 100000-104099 (occupied by StatBooster + familiars).

## C++ ItemScript -- UPDATED (2026-06-19, 7-category kit restructure; 2026-06-19 per-category messages)
- **Files:**
  - `modules/mod-gear-ascension/src/GearAscensionScript.cpp` -- ItemScript
    'gear_ascension_kit', handles OnUse for all 21 kit items (200000-200020).
  - `modules/mod-gear-ascension/src/gear_ascension_loader.cpp` -- module loader.
  - `modules/mod-gear-ascension/CMakeLists.txt` -- AC_ADD_SCRIPT both files.
  - `modules/mod-gear-ascension/conf/mod_gear_ascension.conf.dist`
- **KitProfession() updated:** returns metal/leather/cloth/jewel/weapon_melee/
  weapon_magic/weapon_ranged for 200000-200020 (3-entry blocks, offset 0=I/1=II/2=III).
- **KitTier() updated:** uses `(kitEntry - 200000) % 3 + 2` for any entry in 200000-200020.
- **[Восхождение] tag removed** from all RP chat messages (testing-feedback #5 DONE).
- **Per-category outcome messages (2026-06-19):** replaced single generic pools
  MSG_SUCCESS/MSG_FAIL_SAFE/MSG_FAIL_DOWNGRADE with 7 per-category pool sets
  (metal/leather/cloth/jewel/weapon_melee/weapon_magic/weapon_ranged), 2 variants each,
  plus a generic fallback. Added enum Outcome + RandOutcomeMsg(cat, o) dispatcher.
  All 3 call sites in HandleEffect updated to RandOutcomeMsg(chain.kitProf, OUTCOME_*).
  MSG_WRONG_PROF + MSG_WRONG_TIER left unchanged (ItemScript validation path, neutral).
- **NEEDS RECOMPILE:** these C++ changes are file-only; PTR worldserver must be
  rebuilt for them to take effect.

## Scaling impl (DB-side)
- Each scalable field: `CASE WHEN x>0 THEN GREATEST(CEIL(x*(1+0.10*step)), x+1)
  ELSE x END`. Only POSITIVE values scale.

## VERIFIED ladders on PTR (2026-06-18)
- 37462 Sea King's Crown (Q2,ilvl145): armor 144->159->173, int 34->38->41, Q2->3->4.
- 35574 Chestplate of the Northern Lights (Q3,ilvl155): armor 1753->1929, Q3->4.
- 6641 Haunting Blade (Q2,ilvl26): dmg 53-80 -> 59-88 -> 64-96, Q2->3->4.
- 4446 Blackvenom Blade (Q3): dmg1 21-39->24-43, dmg2 1-7->2-8 (+1 floor), Q3->4.

## Item names (FINALIZED 2026-06-19; WEAPON split 2026-06-19: weapon_melee/ranged/magic; Decline-Prefix forward-scan fix 2026-06-19; velar-ий Decline-Adj fix 2026-06-19)
- **6-position rotation:** line = baseIndex mod 6 (same for all tiers of one chain).
  tierIndex = to_quality - 2 (0/1/2).
  line 0/1/2 = SUFFIX variant (= line); line 3/4/5 = PREFIX variant (= line - 3).
- **enUS:** prefix = "<pre> <base name>"; suffix = "<base name> <suf>".
- **ruRU:** same with full gender/number declension.
  - Gender detected from first word of ruRU base name (adj endings / noun endings /
    exception list for plural nouns).
  - PREFIX: decline FIRST adj/participle token (-ый/-ій/-ой) scanning LEFT TO RIGHT
    to item gender; adverbs and trailing modifiers are static.
    FORWARD scan (not backward) prevents postfix nouns like Скверной/бездной (which
    end in -ой) from being mistakenly treated as the declining token.
  - SUFFIX: if starts with preposition (с/со/из/в/без/...) = fully static; else
    decline first token (participle) only.
  - Declension: -ый/-ой (hard): F=-ая, N=-ое, PL=-ые (velar stem = -ие); -ий:
    soft (синий/stem does NOT end in velar): F=-яя, N=-ее, PL=-ие;
    velar-stem -ий (рунический/stem ends in к/г/х/ж/ч/ш/щ): F=-ая, N=-ое, PL=-ие.
- ruRU FALLBACK RULE: if base has NO ruRU locale row, NO ruRU locale row is emitted.
- DESIGN.md section 10 = canonical pool + algorithm. Both generators carry identical
  engine block in UTF-8 BOM .ps1 files.
- **WEAPON naming split (2026-06-19):** WEAPON single category split into
  WEAPON_MELEE / WEAPON_RANGED / WEAPON_MAGIC (mirrors kit_profession subclass logic).
  Both generators updated (Get-MaterialCategory, all 4 pool dicts).
- **PTR counts after weapon split (2026-06-19):** 1516 copies / 1516 locale / 1516 chain.
  weapon_melee: 253 / weapon_ranged: 73 / weapon_magic: 67 (match kit_profession counts).
- **Sample verified (weapon split, 2026-06-19):**
  WEAPON_RANGED M suffix: Иссеченный короткий лук с роговой накладкой (static с)
  WEAPON_RANGED M suffix: Иссеченный короткий лук с мифриловым воротом (static с)
  WEAPON_RANGED M prefix: Выверенный многослойный изогнутый лук (M adj, T1 v0)
  WEAPON_RANGED M prefix: Хорошо выверенный многослойный изогнутый лук (adverb static + M token, T2 v0)
  WEAPON_RANGED M prefix: Туго натянутый изысканный мушкетон (adverb static + M token, T2 v2)
  WEAPON_RANGED M prefix: Усиленный воротом массивный короткий лук (FIRST token M, воротом static, T3 v2)
  WEAPON_MAGIC F suffix: Большая палка усиленная Скверной (F participle, Скверной static; Большая палка = F)
  WEAPON_MAGIC M suffix: Охранный посох с сердцевиной из звёздного рубина (static с)
  WEAPON_MAGIC M prefix: Зачарованный кривой посох (M adj, T1 v0)
  WEAPON_MAGIC F prefix: Наговорённая трость (F adj from наговорённый, трость = F, T1 v2)
  WEAPON_MELEE M suffix: Полуночный топор с лезвием из чёрной стали (static с, unchanged style)

## PTR snapshots
- `2026-06-18_175509` (taken before gear_ascension_kits.sql apply).
- `2026-06-18_183418_before-id-block-300k-migration` (taken before 1M->300k ID migration).
- `2026-06-19_165747` (taken before names+whitestats-v2 regen, 2026-06-19).
- `2026-06-19_171311` (taken before suffix-names+weapon-injection regen, 2026-06-19).
- `2026-06-19_173854` (taken before 3-variant pool + ruRU fallback regen, 2026-06-19).
- `2026-06-19_192108` (taken before combined PREFIX+SUFFIX + declension engine regen, 2026-06-19).
- `2026-06-19_193853_before-capitalization-fix` (taken before Cap-First fix, 2026-06-19).
- `2026-06-19_195640_before-collision-guard-regen` (taken before collision-guard regen, 2026-06-19).
- `2026-06-19_200533` (taken before Lower-First PREFIX fix, 2026-06-19).

## ID blocks (VERIFIED -- no collision before insert)
- tier-copy item_template: 300,000-399,999 (moved from 1M block, owner decision 2026-06-18)
  - Vendor LOCKED range: 300001-306933 (694 vendor bases / 1516 copies; bi 0-693)
  - Non-vendor Q2+Q3 range: 306941-340222 (3329 bases / 4952 copies; bi 694-4022)
  - Non-vendor Q1 range: 340231-345833 (561 bases / 1683 copies; bi 4023-4583)
  - Full used block: 300001-345,833
- kits: 200000-200020 (USED, 21 kits, 7 categories x 3 tiers)
- kit block reserved: 200021-200099 (available for future kits)
- vendor NPC: 200100 (or reuse tavern vendor 190xxx) -- NOT YET BUILT
- gear-ascension spells: 105000-105099 (105000 USED for use-spell)
Existing in project: items 100001-100016, 110000-110120; creatures 191000-191099;
spells 100000-104099; enchants 90001-91241.

## kit_profession derivation (in generator -- UPDATED 2026-06-19 to 7 categories)
- class 2 weapon by subclass:
  - subclass 10 (staff) or 19 (wand) -> weapon_magic
  - subclass 2 (bow) / 3 (gun) / 16 (thrown) / 18 (crossbow) -> weapon_ranged
  - all other weapon subclasses -> weapon_melee
- class 4 armor by subclass:
  - subclass 1 -> cloth
  - subclass 2 -> leather
  - subclass 3 (mail) / 4 (plate) / 6 (shield) -> metal
  - subclass 0 misc (and any other) -> jewel

## Generator collision guard (UPDATED 2026-06-19)
The guard now only blocks on FOREIGN entries (entries in our block NOT in the planned
entry list). Our own prior-gen orphaned entries (item_template rows whose chain rows
were already cleaned) are in the planned list and will be cleaned by the idempotency
DELETE at import time, so they are not true collisions. Old guard (check all entries
in block range) would false-positive on re-runs.

## Naming collision guard -- stem-repeat prevention (ADDED 2026-06-19)
Functions `Test-StemCollision` + `Get-EffectiveLine` in BOTH generators.
Prevents suffix/prefix phrases from repeating a material root already in the base name
(e.g. "Доспех из обработанной кожи" + "из кожи дьявозавра" = two "кожи").
Algorithm: tokenise to lowercase content words (skip stopwords); resolve each word to
its root via $materialRootForms lookup (exact inflection match) or 4-char prefix
heuristic; if any phrase-root shares a 3+-char prefix with any base-name-root -> collision.
Get-EffectiveLine rotates naturalLine (bi%6) by offset 0..5 until finding a clean position
across ALL tiers of the chain. Prefix-mode (lines 3-5 = treatment verbs) is guaranteed safe.
Result (2026-06-19): 1 collision detected and fixed (bi=18, entry 236 "Доспех из обработанной
кожи", naturalLine=0->effectiveLine=3): green/blue/purple copies now use LEATHER prefix
"продублённый"/"хорошо продублённый"/"прошитый жилами" instead of "кожей" suffixes.
Scan of all 58 ruRU names: ZERO remaining collisions.

## GOTCHAS (PS5.1)
- A single-row mysql result, when filtered with `| Where-Object`, gets unwrapped
  to a scalar STRING; indexing `[0]` then returns a CHAR. Always wrap in `@(...)`.
- `$Out` and `$out` are THE SAME variable in PS5.1 (case-insensitive).
- Don't put box-drawing/em-dash chars in here-strings: BOM-less .ps1 read as ANSI.
- **SQL import with Cyrillic: copy file into container + use bash redirect.**
  `docker cp file.sql container:/tmp/file.sql` then
  `docker exec container bash -c "mysql -u root -ppassword --default-character-set=utf8mb4 db < /tmp/file.sql"`.
  Do NOT use `Get-Content | cmd /c "docker exec -i ... mysql"` — PowerShell
  re-encodes the byte stream and mangles Cyrillic to `?` (0x3F). Do NOT use
  `ProcessStartInfo + StandardInput.Write(query)` for large SQL -- it truncates.
  The `Invoke-PtrRead` function (for short queries / SELECT) is fine since it
  uses Write(string) and the query is ASCII only.

## GOTCHAS (C++)
- `targets.GetItemTarget()` returns the target item from the spell cast; works when
  the player clicks a target item while casting the use-spell.
- SOCK_ENCHANTMENT_SLOT=2, SOCK_ENCHANTMENT_SLOT_2=3, SOCK_ENCHANTMENT_SLOT_3=4.
- PERM_ENCHANTMENT_SLOT=0 (NOT copied by design).
- `DestroyItem(bag, slot, true)` removes the item; then `CanStoreNewItem +
  StoreNewItem` places the new one. Try same slot first.
- `OnItemUse` fires at CAST START (CMSG_USE_ITEM handler) -- BEFORE the spell cast.
  A non-instant CastingTimeIndex does NOT gate an ItemScript returning true/false.
  To gate logic behind a cast bar: return false in OnUse (let spell proceed), put
  the actual logic in a SpellScript OnEffectHitTarget on SPELL_EFFECT_SCRIPT_EFFECT.
- `GetCastItem()` in SpellScript returns the item that triggered the spell cast.
- `GetHitItem()` in OnEffectHitTarget returns itemTarget (the explicit item target).
- CastingTimeIndex=5 = 2000ms (same as Regrowth 8936, Holy Fire 15262).
- spell_script_names links a SpellScript class by name (class name = script name).

## Polish pass A (2026-06-18) -- DONE
- **A1 data-loss fix:** SafeSwapItem() now pre-flight checks template+bag space
  BEFORE destroying the old item. Old item only removed after CanStoreNewItem OK.
- **A2 Russian RP messages:** 4-pool success, 3-pool fail-safe, 3-pool downgrade,
  2-pool wrong-prof, 2-pool wrong-tier. Color-coded (green/orange/red). ASCII only.
- **A3 2s cast:** CastingTimeIndex=5 in spell_dbc + Spell_custom.csv (105000).
  Effect_1 changed from 99 (DISENCHANT) to 77 (SCRIPT_EFFECT). Upgrade logic moved
  from ItemScript::OnUse to SpellScript::OnEffectHitTarget (fires post-cast).
  ItemScript now validation-only (returns false on OK, true+error on fail).
  spell_script_names (105000, 'spell_gear_ascension_apply_kit') inserted on PTR.
- SQL: `data/sql/updates/pending_db_world/gear_ascension_polish_a.sql` (applied PTR).
- Rebuild: docker compose --profile ptr build ac-worldserver-ptr (started 2026-06-18).

## Phase 2 -- White bases (REGENERATED 2026-06-19 with v2 stat routing + suffix names + weapon injection)
- Generator: `modules/mod-gear-ascension/scripts/gear-ascension-gen-white.ps1`
- SQL: `data/sql/updates/pending_db_world/gear_ascension_white_bases.sql` (applied PTR)
- **ARMOR White stat-gen formula v2 (FINAL, 2026-06-19):** k=0.4
  - points = round(ilvl * 0.4); Sta=ceil(pts*0.6); Pri=pts-Sta
  - Primary by ROLE: cloth->Int, plate->Str, leather/mail by AllowableClass bitmask
  - misc(sub0)->Spi; casterMask=&0x4C2; physMask=&0x02D
- **WEAPON White stat injection v1 (FINALIZED 2026-06-19): weaponK=0.30**
  - points = round(ilvl * 0.30); Sta=ceil(pts*0.6); Pri=pts-Sta
  - stat_type1/value1=Stamina; stat_type2/value2=primary stat
  - Primary by ROLE via weapon subclass + AllowableClass:
    wand(19)->Int; bow/gun/xbow/thrown->Agi; staff(10) unrestricted->Int;
    dagger/fist->Agi; melee unrestricted->Str; melee caster-only->Int;
    melee Hunter/Rogue->Agi; melee Warrior/DK->Str
  - Damage (dmg_min/max) scaling continues IN ADDITION to stat injection
  - Calibration (real green weapons acore_world_ptr Quality=2 class=2, meaningful stats):
    ilvl10-19 avg_k=0.312, ilvl20-29=0.372, ilvl30-59~0.29;
    weaponK=0.30 conservative (lower median; damage is the primary weapon value)
    ilvl16 example: pts=5, Sta=3, Pri=2 (matches real green weapon budget)
    ilvl25 example: pts=8, Sta=5, Pri=3 (real greens 9-11; k=0.30 intentionally modest)
- **10 white bases (baseIndex 18..27), ID range 300181-300273:**
  - 18: 236  Cured Leather Armor   ilvl22 leather  Sta6 Agi3  armor77
  - 19: 837  Heavy Weave Armor     ilvl17 cloth    Sta5 Int3  armor29
  - 20: 926  Battle Axe            ilvl25 weapon   dmg46-70 + Sta6 Str4 (at step+1)
  - 21: 928  Long Staff            ilvl25 weapon   dmg36-55 + Sta6 Int4 (at step+1)
  - 22: 2141 Cuirboulli Vest       ilvl27 leather  Sta7 Agi4  armor84
  - 23: 2507 Laminated Recurve Bow ilvl16 weapon   dmg10-20 + Sta4 Agi3 (at step+1)
  - 24: 3891 Augmented Chain Helm  ilvl37 mail     Sta9 Str6  armor169
  - 25: 3894 Brigandine Helm       ilvl50 mail     Sta12 Str8 armor211
  - 26: 6526 Battle Harness        ilvl37 leather  Sta9 Agi6  armor100
  - 27: 15810 Short Spear          ilvl25 weapon   dmg40-60 + Sta6 Str4 (at step+1)
- **Sample weapon ladder (Battle Axe, ilvl25, axe2h, AllowableClass=-1 -> Str):**
  - Base (white): dmg46-70, no stats
  - +1 (green): dmg51-77, Sta6, Str4
  - +2 (blue):  dmg56-84, Sta6, Str4
  - +3 (purple): dmg60-91, Sta7, Str4
- **Sample armor ladder (Cured Leather Armor, ilvl22, leather -> Agi):**
  - Base (white): armor77, 0 stats
  - +1 (green): armor85, Sta7, Agi4
  - +2 (blue):  armor93, Sta8, Agi4  [NOTE: step+2 stat same as +1 at low ilvl due to CEIL]
  - +3 (purple): armor101, Sta8, Agi4
- **Item.dbc:** 30 rows in .claude/dbc/Item_custom.csv (regenerated).
- **Chain:** nemesis_rank 1/3/5 by to_quality 2/3/4; success 95/75/50; fail_downgrade=1 at Q4.

## BUG FIXES APPLIED (2026-06-19, updated)
- **spell 105000 InterruptFlags=0 bug (FIXED 2026-06-19):**
  Root cause: REPLACE INTO in gear_ascension_kits.sql omitted InterruptFlags,
  so it defaulted to 0. With SPELL_INTERRUPT_FLAG_MOVEMENT (0x01) not set,
  the server never cancelled the 2s cast when the player moved.
  Fix: UPDATE spell_dbc SET InterruptFlags=1 WHERE ID=105000 applied to
  acore_world_ptr (snapshot 2026-06-19_223828 taken before). Verified: SELECT
  returns 1. SQL idempotency: gear_ascension_kits.sql REPLACE INTO now includes
  InterruptFlags=1. Spell_custom.csv row 288 col29 updated from "0" to "1".
  Client note: server-side fix (after PTR restart) cancels the cast on movement;
  client Spell.dbc needs MPQ rebuild for fully clean client-side cancel.

## BUG FIXES APPLIED (2026-06-19)
- **Prefix-line names start lowercase (FIXED 2026-06-19, pass 1 Cap-First):**
  Root cause: ruRU prefix lemmas stored as lowercase ("зачарованное", "хорошо простёганный",
  etc.); composed prefix-line string therefore began lowercase. enUS prefixes were uppercase
  already but the fix is applied universally for safety.
  Fix: added `Cap-First` helper function to BOTH generators: `$s[0].ToString().ToUpper() + $s.Substring(1)`.
  Called at the return point of both `Build-RuName` and `Build-EnName`.
  .NET `ToUpper()` is Unicode-aware and handles Cyrillic correctly.
  SQL regenerated + reimported to acore_world_ptr (snapshot taken before).
  Verified: 58 ruRU locale rows, 0 lowercase-starting names in DB.
- **Prefix-line ruRU names have TWO leading capitals (FIXED 2026-06-19, pass 2 Lower-First):**
  Root cause: PREFIX composition was "<prefix> <baseRuName>" where baseRuName retains
  its own leading capital from DB. Cap-First then uppercases the prefix's first letter too,
  giving two capitals: "Продублённый Доспех...", "Хорошо простёганный Элунский наплеч", etc.
  Russian sentence-case requires exactly ONE leading capital; the base name's first letter
  must be lowercased before prepending the prefix.
  Fix: added `Lower-First` helper (`$s[0].ToString().ToLower() + $s.Substring(1)`) to
  BOTH generators. In PREFIX branch of Build-RuName: `"$pre $(Lower-First $baseRuName)"`.
  Only [0] is changed; mid-name proper nouns (e.g. "Зимней Спячки", "Черного яда") untouched.
  enUS Build-EnName: NOT changed (enUS is title-case; all-caps-each-word is correct English).
  SQL regenerated + reimported (snapshot 2026-06-19_200533 taken before).
- **spell 105000 ImplicitTargetA_1=0 bug (FIXED 2026-06-19):**
  Root cause: REPLACE INTO in gear_ascension_kits.sql omitted ImplicitTargetA_1,
  so it defaulted to 0. With no implicit target, TARGET_FLAG_ITEM (Targets=16)
  never resolved to the SCRIPT_EFFECT, so OnEffectHitTarget never fired and
  GetHitItem() returned null. Symptom: "cast completes, nothing happens".
  Fix: UPDATE spell_dbc SET ImplicitTargetA_1=26 WHERE ID=105000 applied to
  acore_world_ptr (snapshot 2026-06-19_163104 taken before). Verified: SELECT
  returns 26. SQL idempotency: gear_ascension_kits.sql REPLACE INTO updated to
  include ImplicitTargetA_1=26 and also corrected Effect_1=77 + CastingTimeIndex=5
  (kits.sql was still at the pre-PolishA values of Effect_1=99 + CastingTimeIndex=1).
  Spell_custom.csv row 288 col85 updated from "0" to "26".
- **spell 105000 EquippedItemClass=0 bug (FIXED 2026-06-19):**
  Root cause: the original REPLACE INTO in gear_ascension_kits.sql omitted
  EquippedItemClass, so MySQL defaulted it to 0 (requires class-0 item equipped).
  Client refused to cast with "вы должны держать в руке /s" error.
  Fix: `UPDATE spell_dbc SET EquippedItemClass=-1, EquippedItemSubclass=0,
  EquippedItemInvTypes=0 WHERE ID=105000` applied to acore_world_ptr (snapshot
  2026-06-19_161452 taken before). Verified: SELECT returns -1.
  SQL idempotency fix: gear_ascension_kits.sql REPLACE INTO now includes
  EquippedItemClass=-1, EquippedItemSubclass=0, EquippedItemInvTypes=0.
  Spell_custom.csv was already correct (had -1 at EquippedItemClass column).
  **OWNER ACTION REQUIRED:** rebuild client Spell.dbc into MPQ so the client
  enforces -1 (no equipped-item gate). Then main will restart PTR to reload.

## MASS GENERATION PHASE 2 ALL-OBTAINABLE -- DONE (2026-06-19)

Expanded from vendor-only (694 bases) to ALL OBTAINABLE Classic items.
Vendor entries LOCKED (bi 0-693, entries 300001-306933, 1516 copies).
New non-vendor entries start at bi=694, entry 306941.

### Counts (verified in acore_world_ptr after import):
- Proto (Q2+Q3) bases: 3644 (vendor=315: Q2=64 Q3=251; non-vendor=3329: Q2=1952 Q3=1377)
- White (Q1) bases: 940 (vendor=379, non-vendor=561)
- Total bases: 4584
- Total tier copies: 8480 (proto=5660 + white=2820)
- Chain rows: 8480 (TRUNCATE+INSERT in proto; DELETE+INSERT in white)
- ruRU locale rows: 8472 (8480 - 8 = enUS-only copies: 1 proto Q2 base×2 + 2 white bases×3 = 8)
- enUS-only bases: proto=1, white=2 (total 3 bases, 8 copies without ruRU locale)

### ID ranges (locked 2026-06-19):
- bi 0-314:    vendor Q2+Q3   → entries 300001-303142 (LOCKED, UNCHANGED)
- bi 315-693:  vendor Q1      → entries 303151-306933 (LOCKED, UNCHANGED)
- bi 694-4022: non-vendor Q2+Q3 → entries 306941-340222 (NEW)
- bi 4023-4583: non-vendor Q1  → entries 340231-345833 (NEW)
- Full block used: 300001-345,833 (within 399,999 ceiling)
- Gap 303143-303150: intentional unused step slots at vendor Q2+Q3 edge (bi 314 max step)
- Gap 306934-306940: similarly between vendor Q1 and non-vendor Q2+Q3

### CSV (Item_custom.csv) -- UPDATED 2026-06-19 (all-obtainable regen):
- File: 8634 lines = 1 header + 8633 data rows
  Breakdown: 132 pre-existing non-kit rows + 21 kit rows + 1516 vendor-locked rows + 6964 new rows
- Duplicate IDs: 0

### Generator architecture (mass-gen-all, 2026-06-19):
- gear-ascension-gen-sql.ps1: two-group approach
  Group 1 (bi 0-314): vendor Q2+Q3 (LOCKED)
  Group 2 (bi 694+): non-vendor obtainable Q2+Q3 (NEW)
  Both groups processed in Process-BaseGroup(bases, biStart).
  Fetch-Meta batches 1000 entries per mysql call.
  Cleanup: TRUNCATE chain + DELETE 300001-399999 (expanded range).
- gear-ascension-gen-white.ps1: two-group approach
  Group 1 (bi 315-693): vendor Q1 (LOCKED)
  Group 2 (bi 4023+): non-vendor obtainable Q1 (NEW)
  NONVENDOR_Q1_BI_START = 694 + count(non-vendor Q2+Q3) = 694+3329=4023 (dynamic query).
  Both groups processed in Process-WhiteGroup(bases, biStart).
  Fetch-WhiteMeta batches 1000 entries per mysql call.

### Anomaly scans (2026-06-19 all-obtainable):
- Soft-sign gender defaults (-ь → F by default rule): 141 (proto) + 8 (white) = 149 total
  Most are words like -шитель/-губитель/-крушитель (compound nouns ending in -ь), which
  the engine defaults to F (correct default for many), but some may be M (cosmetic issue only).
  The 5 $softSignOverrides entries (камен/перстен/когот/ремен/трост) are handled correctly.
  New soft-sign anomalies from non-vendor set: not systematically reviewed (too many).
  Impact: incorrect grammatical gender agreement in some ruRU names. Minor cosmetic.
- Collision-rotates: 58 (proto) + 44 (white) = 102 total -- all resolved by Get-EffectiveLine.
- enUS-only bases: 3 total.

### PTR snapshots:
- `2026-06-19_233659` (taken before all-obtainable mass gen).

## Soft-sign overrides (ADDED 2026-06-19)
Full scan of all 694 base ruRU head-words confirmed 5 words ending in -ь:
- трость (F) -- correct by default, NOT in override table
- камень (M) -- added: stem 'камен'
- перстень (M) -- added: stem 'перстен'
- коготь (M) -- added: stem 'когот'
- ремень (M) -- added: stem 'ремен'

Both generators ($softSignOverrides hashtable) updated.
SQL regenerated + reimported to acore_world_ptr (snapshot 2026-06-19_204423).
Counts unchanged: 1516 copies / 1516 locale / 1516 chain.
DESIGN.md sec 10 gender table updated with masculine -ь override table.

BEFORE/AFTER summary (gender-affected copies):
- 302121: усиленная -> усиленный (ремень горца, LEATHER suffix)
- 302131: Прошитая жилами -> Прошитый жилами (ремень горца, LEATHER prefix)
- 302541: усиленная -> усиленный (ремень Осквернителя, LEATHER suffix)
- 302551: Прошитая жилами -> Прошитый жилами (ремень Осквернителя, LEATHER prefix)
- 306051: Начищенная -> Начищенный (камень, ACCESSORY prefix)
- 306052: Искусно огранённая -> Искусно огранённый (камень, ACCESSORY prefix)
- 306053: Проклятая -> Проклятый (камень, ACCESSORY prefix)
- 306401: Заострённая -> Заострённый (коготь левой руки, WEAPON prefix)
- 306402: Хорошо заострённая -> Хорошо заострённый (коготь, WEAPON prefix)
- 306403: Закалённая в крови -> Закалённый в крови (коготь, WEAPON prefix)
Not changed (suffix preposition-led = static gender-invariant):
- 302111/302531: 'с чешуёй...' = starts with 'с', static -- unchanged
- 306081/306082/306083: 'в оправе/с кристаллом' = static -- unchanged
- 306361/306362/306363: 'с навершием/лезвием' = starts with 'с', static -- unchanged
Trosts (305151-305153): трость is F, adjectives correctly declined to F -- not changed.

## PTR snapshots (continued)
- `2026-06-19_212233` (taken before 7-category kit restructure, 2026-06-19).
- `2026-06-19_220940` (taken before accessory T3 icon fix + rarity-word descriptions, 2026-06-19).
- `2026-06-19_223828` (taken before InterruptFlags=1 fix for spell 105000, 2026-06-19).
- `2026-06-19_224708` (taken before weapon naming split: WEAPON->WEAPON_MELEE/RANGED/MAGIC, 2026-06-19).

## Open / TODO
- **PTR REBUILD REQUIRED**: KitProfession/KitTier C++ updated + [Восхождение] removed.
  Main must rebuild worldserver PTR (ptr-build.ps1) for C++ changes to take effect.
- **MPQ/DBC build** (main's job) -- EXPANDED after all-obtainable mass gen:
  - Item.dbc: **8480 copies + 21 kits = 8501 custom Item.dbc rows** (plus 132 pre-existing = 8633 rows; total data rows in Item_custom.csv = 8633).
    This is a LARGE DBC patch. The MPQ builder must include ALL 8633 rows.
  - ItemDisplayInfo.dbc: add 3 custom rows (70001-70003 from ItemDisplayInfo_custom.csv).
    Without this, metal kits will show a blank icon on the client.
  - Spell.dbc: MUST include EquippedItemClass=-1 and SpellVisualID_1=3182 for 105000
    (both already correct in Spell_custom.csv col 67 and col 130 respectively).
- Vendor for kits (creature_template + npc_vendor) -- NOT built yet.
- testing-feedback #3 (addon "upgradeable" marker) -- OPEN (design later).
- Soft-sign gender anomalies: 149 new-set entries with potentially wrong gender agreement.
  Not systematically reviewed. Can be addressed as a polish pass post-validation.
