# Gear Ascension — testing feedback / polish backlog

Owner notes captured during PTR testing. Address in batched passes (group C++
changes so they share ONE worldserver rebuild). Status: OPEN unless marked done.

## 1. Chat messages — RP + Russian + varied  (DONE 2026-06-18)
- Make the ItemScript chat messages **role-play flavored** and **in Russian**
  (`GearAscensionScript.cpp`).
- **Vary** the lines — random pick from a small pool per outcome, not the same
  string every time. Outcomes that need messages: success (tier up), fail
  (no change), fail+downgrade (purple step), wrong-kit-profession, wrong-kit-tier.
- Watch the 3.3.5a client glyph set: ASCII `-`/`:` only, no U+2014/U+2013/U+2212.
- This is a C++ change → bundle with the pending **data-loss ordering fix**
  (validate template + create new BEFORE destroying the original) so one rebuild
  covers both.

## 2. RP item names per tier  (DONE 2026-06-19 -- combined PREFIX+SUFFIX + ruRU declension LIVE)
- **Combined PREFIX+SUFFIX naming ENGINE implemented and applied to PTR (2026-06-19).**
  6-position rotation: line = baseIndex mod 6.
  line 0/1/2 = SUFFIX variant; line 3/4/5 = PREFIX variant (= line - 3).
  tierIndex = to_quality - 2 (0/1/2).
  5 material categories x 3 tiers x 3 variants x 2 modes (prefix+suffix) = 90 pool entries.
- **ruRU DECLENSION ENGINE:** detects gender/number of base item from first word of ruRU name;
  declines agreeing token (last adj in prefix phrase; first participle in suffix phrase if not
  preposition-led). Full M/F/N/PL coverage. Exceptions lexicon for plural item nouns.
- **CANONICAL SPEC:** DESIGN.md section 10 (both generators carry identical UTF-8 BOM engine block).
- Both generators regenerated and applied to acore_world_ptr (2026-06-19).
  Snapshot 2026-06-19_192108 taken before.
- **Grammar verified in PTR DB (sample, 2026-06-19):**
  CLOTH  F suffix (static prep):  "Корона короля морей из магической ткани" ✓
  METAL  F suffix (declining):    "Бригантина северного сияния усиленная торием" ✓
  LEATHER F suffix (declining):   "Боевая портупея отороченная мехом" ✓
  ACCESS N prefix (adj declined): "зачарованное Ледяное ожерелье Зимней Спячки" ✓
  WEAPON N prefix (simple):       "наточенное Короткое копье" ✓
  WEAPON N prefix (adverb+adj):   "хорошо наточенное Короткое копье" ✓
  LEATHER PL prefix (adj PL):     "выдубленные Цельношитые кожаные брюки" ✓
  METAL PL suffix (participle PL):"Наголенники лавохода усиленные чёрной сталью" ✓
  WEAPON M prefix (trailing mod): "закалённый в крови Клинок проклятия" ✓
  WEAPON M prefix (adverb+adj):   "хорошо заострённый Клинок проклятия" ✓
- **enUS-only bases:** 0 of 18 proto + 0 of 10 white. Fallback rule ready for scale-up.
- **Override table:** empty (no overrides needed so far; extend as needed).

## 3. "Upgradeable" marker on items  (OPEN; design later — it's an addon)
- Show on an item that it CAN be upgraded (tooltip indicator), so players know
  without trying a kit.
- CONSTRAINT: base items are EXISTING rows; additive-only forbids modifying their
  `item_template` — so NO server-side description/spell line on bases.
- Clean approach = CLIENT ADDON (like StatBooster's StatBoostTooltip): detect items
  whose entry is in `item_upgrade_chain` (list synced from server) and add a tooltip
  line e.g. "Можно улучшить". Covers base + copies non-invasively.
- Cheap partial: set `item_template.description` on OUR tier copies (300xxx) server-side
  (additive, our items) — but base items still need the addon.
- Defer; needs Lua addon + a server→client chain-list sync + distribution.

## 6. Cast completes but upgrade never happens, no chat message  (FIXED 2026-06-19)
- **Symptom:** 2s cast bar fills, spell completes, but nothing happens — no upgrade,
  no kit consumed, no chat message. Client showed no error.
- **Root cause:** spell 105000 Effect_1=77 (SCRIPT_EFFECT) had `ImplicitTargetA_1=0`.
  With no implicit target the item-target carried by Targets=16 (TARGET_FLAG_ITEM)
  never resolved to the effect, so `SpellScript::OnEffectHitTarget` was never invoked
  and `GetHitItem()` returned null. The upgrade logic never ran.
- **Fix:** `ImplicitTargetA_1 = 26` (TARGET_GAMEOBJECT_ITEM_TARGET, confirmed in
  SharedDefines.h:1436 — same value used by enchant/disenchant item-target spells).
  Applied to acore_world_ptr (snapshot 2026-06-19_163104 taken before).
  Verified: SELECT returns 26. SQL idempotency: gear_ascension_kits.sql REPLACE INTO
  updated to include `ImplicitTargetA_1=26, ImplicitTargetB_1=0` and corrected
  Effect_1 to 77 + CastingTimeIndex to 5 (bringing kits.sql up to date with all
  prior fixes). Spell_custom.csv row 105000 col85 updated from "0" to "26".

## 7. Animation/sound during 2s cast  (ADDRESSED 2026-06-19; pending MPQ rebuild)
- **Request:** enchanting-style animation + sparkle + sound DURING the 2s cast bar
  (SpellVisualID was 0 -> no visual).
- **Fix:** SpellVisualID_1 = 3182 (standard "Enchant Item" visual, same as spells
  7420/7421/27944; caster hand-cast animation + sparkles on target item + arcane sound).
- **DB (acore_world_ptr):** UPDATE spell_dbc SET SpellVisualID_1=3182 WHERE ID=105000.
  Verified SELECT returns 3182. SpellVisualID_2 left at 0.
  Snapshot 2026-06-19_163531 taken before.
- **SQL (gear_ascension_kits.sql):** REPLACE INTO now includes SpellVisualID_1=3182,
  SpellVisualID_2=0 so DB rebuilds won't regress it.
- **Spell_custom.csv:** col 129 (SpellVisualID_1) set from "0" to "3182".
- **Client-side note:** SpellVisualID is read by the client from its own Spell.dbc.
  The animation will only appear after the owner rebuilds the MPQ. No server restart
  needed for this specific change.

## 9. White weapon stat injection  (DONE 2026-06-19)
- **Added Stamina + primary stat injection to white WEAPONS (class=2, Phase 2).**
  weaponK=0.30 (calibrated against real green weapons in acore_world_ptr).
  stat_type1/value1=Stamina, stat_type2/value2=primary.
  Damage scaling (dmg_min/max) continues IN ADDITION.
- **Weapon primary stat routing by subclass + AllowableClass:**
  wand->Int; bow/gun/xbow/thrown->Agi; staff(unrestricted)->Int;
  dagger/fist->Agi; melee unrestricted->Str; caster-only melee->Int;
  Hunter/Rogue melee->Agi; Warrior/DK melee->Str.
- **Calibration:** real green weapons ilvl10-60 meaningful-stat items avg_k=0.28-0.37;
  k=0.30 conservative lower-median. ilvl16: pts=5,Sta=3,Pri=2 = real green match.
- **Verified in PTR DB (entry 300201 Battle Axe step+1):**
  dmg 46-70 -> 51-77, stat_type1=7(Sta) stat_value1=6, stat_type2=4(Str) stat_value2=4.
- Implemented in gear-ascension-gen-white.ps1 (PROTO gen remains pure-scaling, no injection).

## 8. White stat routing v2 + k calibration  (DONE 2026-06-19)
- **Problem (v1):** primary stat routed by armor subclass only. Leather->Agi,
  mail->Str, which misrouted caster leather/mail (Druid-balance, caster Shaman).
- **Fix (v2):** primary stat routed by ROLE = AllowableClass bitmask + armor type.
  cloth->Int, plate->Str, leather/mail unrestricted->Agi, caster-restricted->Int,
  physical-restricted->Agi or Str (Warrior/DK-only->Str). Implemented in
  gear-ascension-gen-white.ps1 + regenerated SQL applied to PTR.
- **k calibration:** queried real green items in acore_world_ptr. k=0.4 confirmed
  correct for ilvl30+ (avg_k=0.392-0.419); slightly generous for ilvl17-22 but
  acceptable. k kept at 0.4.
- **No-suffix names:** same pass removed " +N" suffix from white gen.

## 5. Remove 'Восхождение' tag from RP chat messages  (DONE 2026-06-19)
- Removed [Восхождение] prefix from all RP message pools in `GearAscensionScript.cpp`.
- All message pools (MSG_SUCCESS, MSG_FAIL_SAFE, MSG_FAIL_DOWNGRADE, MSG_WRONG_PROF,
  MSG_WRONG_TIER) and all inline hardcoded chat messages updated.
- Messages remain RP + Russian + varied; color codes preserved.
- NEEDS worldserver recompile (bundled with KitProfession/KitTier 7-category update).

## 4. 2-second cast on kit use  (DONE 2026-06-18)
- Make using a kit a 2s cast (cast bar, interruptible) instead of instant.
- Core change: set use-spell **105000** `CastingTimeIndex` to a 2000ms index — in
  BOTH `spell_dbc` (server, _ptr) AND `Spell.dbc` (client MPQ); they must match or
  the cast desyncs. Find the 2000ms index in SpellCastTimes.dbc (or copy from a
  known 2s-cast spell).
- VERIFY the upgrade + kit-consume fire on cast COMPLETION (not start), so the 2s
  gates it and interrupt/move cancels with no kit lost. If `ItemScript::OnUse` fires
  post-cast → pure DBC/DB change (no worldserver rebuild). If it fires at cast start
  → move the effect into a SpellScript on 105000's SCRIPT_EFFECT (small C++ → batch).
