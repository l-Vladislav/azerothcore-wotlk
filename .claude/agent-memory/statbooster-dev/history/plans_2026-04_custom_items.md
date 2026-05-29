# StatBooster Pool Scrolls — Implementation Plan

## Goal
16 craftable scroll items that apply stat boosts from different skill pools to a selected item.
Each profession creates scrolls for a specific pool:
- Blacksmithing → Battle pool (offensive stats)
- Leatherworking → Warding pool (defensive stats)
- Enchanting → Arcana pool (caster stats)
- Inscription → Fortune pool (use-spell procs)

4 tiers per profession (scaling with skill level and item level).

## What's Done (Server-Side)
- 16 items created by repurposing vanilla QA item IDs (17827-17830, 17883-17896, 18599)
- Items overwritten in `item_template` with custom names/stats/displayIDs
- Custom craft spells in `spell_dbc` (IDs 100001-100016)
- Skill links in `skilllineability_dbc` (IDs 100001-100016)
- Recipes added to profession trainers via `trainer_spell` (tier-aware dynamic SQL)
  - Uses 3-table system: `trainer` + `trainer_spell` + `creature_default_trainer`
  - Each recipe only added to trainers whose max skill rank covers it
  - Covers both base AC trainers (58-124) and playerbots-added trainers (616-651)
- StatBooster code updated: pool scrolls enchant unenchanted items, reroll scroll re-rolls existing
- Config maps scroll item IDs to pool groups

## Current Problem — RESOLVED
~~Recipes don't appear in the client profession UI.~~ Fixed by:
1. Using `trainer_spell` table instead of deprecated `npc_trainer`
2. Using correct TrainerIds (58-651) instead of non-existent 201xxx IDs
3. Tier-aware dynamic SQL that respects trainer NPC rank limits
4. Client-side DBC patch (Spell.dbc + SkillLineAbility.dbc in MPQ)

## Solution: Client MPQ Patch (Option B)
Create a `patch-4.MPQ` with modified `Spell.dbc` and `SkillLineAbility.dbc` containing our custom entries.

---

## Implementation Plan

### Phase 1: Extract & Prepare DBC Files

#### Step 1.1 — Get tools
- [ ] Download **Ladik's MPQ Editor** (for MPQ create/extract)
- [ ] Download **WDBX Editor** (for DBC editing, GitHub: WowDevTools/WDBXEditor)

#### Step 1.2 — Extract base DBCs from client
- [ ] Open the client's latest patch MPQ (likely `Data/patch-3.MPQ` or `Data/enUS/patch-enUS-3.MPQ`)
- [ ] Extract `DBFilesClient/Spell.dbc`
- [ ] Extract `DBFilesClient/SkillLineAbility.dbc`
- [ ] Keep backups of originals

### Phase 2: Add Custom Spells to Spell.dbc

#### Step 2.1 — Add 16 craft spell entries (IDs 100001-100016)

Each spell needs these fields populated (all others = 0):

| Field | Value | Notes |
|-------|-------|-------|
| `Id` | 100001-100016 | Matching server `spell_dbc` |
| `CastingTimeIndex` | 16 | 5000ms (5 sec cast) |
| `Effect_1` | 24 | SPELL_EFFECT_CREATE_ITEM |
| `EffectDieSides_1` | 1 | Creates 1 item |
| `EffectItemType_1` | (item entry) | 17827, 17828, ... per spell |
| `Reagent_1..2` | (material IDs) | Match server SQL |
| `ReagentCount_1..2` | (quantities) | Match server SQL |
| `EquippedItemClass` | -1 | No equipment requirement |
| `SpellIconID` | (pick per profession) | Existing icon from SpellIcon.dbc |
| `SpellName_enUS` | Recipe name | "Runed Whetstone", etc. |
| `Rank_enUS` | (optional) | Tier text if desired |

#### Full spell data table (must match server SQL exactly):

**Blacksmithing (Pool 1 — Battle):**
| ID | Name | Creates | Reagent1 (qty) | Reagent2 (qty) | Icon |
|----|------|---------|-----------------|-----------------|------|
| 100001 | Runed Whetstone | 17827 | 2840 Copper Bar (4) | 2835 Rough Stone (1) | BS scroll icon |
| 100002 | Tempered Whetstone | 17828 | 3575 Iron Bar (4) | 2838 Heavy Stone (2) | BS scroll icon |
| 100003 | Honed Whetstone | 17829 | 12359 Thorium Bar (6) | 12365 Dense Stone (2) | BS scroll icon |
| 100004 | Masterwork Whetstone | 17830 | 36913 Saronite Bar (8) | 41163 bar (2) | BS scroll icon |

**Leatherworking (Pool 2 — Warding):**
| ID | Name | Creates | Reagent1 (qty) | Reagent2 (qty) | Icon |
|----|------|---------|-----------------|-----------------|------|
| 100005 | Runed Armor Patch | 18599 | 2318 Light Leather (4) | 2320 Coarse Thread (1) | LW scroll icon |
| 100006 | Tempered Armor Patch | 17883 | 4234 Heavy Leather (6) | 4291 Silken Thread (2) | LW scroll icon |
| 100007 | Hardened Armor Patch | 17884 | 8170 Rugged Leather (8) | 14341 Rune Thread (2) | LW scroll icon |
| 100008 | Masterwork Armor Patch | 17885 | 38425 Heavy Borean (8) | 44128 Arctic Fur (2) | LW scroll icon |

**Enchanting (Pool 3 — Arcana):**
| ID | Name | Creates | Reagent1 (qty) | Reagent2 (qty) | Icon |
|----|------|---------|-----------------|-----------------|------|
| 100009 | Minor Arcane Vellum | 17889 | 10940 Strange Dust (2) | 10938 Lesser Magic (1) | Ench scroll icon |
| 100010 | Arcane Vellum | 17888 | 11083 Soul Dust (4) | 10939 Greater Magic (2) | Ench scroll icon |
| 100011 | Greater Arcane Vellum | 17891 | 16204 Illusion Dust (4) | 16203 Greater Eternal (2) | Ench scroll icon |
| 100012 | Superior Arcane Vellum | 17892 | 34054 Infinite Dust (4) | 34055 Greater Cosmic (2) | Ench scroll icon |

**Inscription (Pool 4 — Fortune):**
| ID | Name | Creates | Reagent1 (qty) | Reagent2 (qty) | Icon |
|----|------|---------|-----------------|-----------------|------|
| 100013 | Minor Glyph of Fortune | 17893 | 39469 Moonglow Ink (2) | 39354 Light Parch (1) | Insc scroll icon |
| 100014 | Glyph of Fortune | 17894 | 39774 Royal Ink (3) | 10648 parch (1) | Insc scroll icon |
| 100015 | Major Glyph of Fortune | 17895 | 43120 Darkflame Ink (3) | 39501 Heavy Parch (2) | Insc scroll icon |
| 100016 | Grand Glyph of Fortune | 17896 | 43127 Snowfall Ink (3) | 39502 Resilient Parch (2) | Insc scroll icon |

#### Step 2.2 — Choose SpellIconIDs
- [ ] Look up existing profession recipe icons in SpellIcon.dbc
- [ ] Pick appropriate icons per profession (anvil for BS, leather for LW, sparkle for Ench, quill for Insc)
- [ ] Use same icon for all 4 tiers within a profession (or vary by tier)

### Phase 3: Add Custom Entries to SkillLineAbility.dbc

Add 16 rows matching the server-side `skilllineability_dbc` SQL:

| ID | SkillLine | Spell | MinSkillRank | TrivialHigh | TrivialLow | AcquireMethod |
|----|-----------|-------|-------------|-------------|------------|---------------|
| 100001 | 164 (BS) | 100001 | 0 | 75 | 25 | 1 (trainer) |
| 100002 | 164 (BS) | 100002 | 0 | 200 | 150 | 1 |
| 100003 | 164 (BS) | 100003 | 0 | 325 | 275 | 1 |
| 100004 | 164 (BS) | 100004 | 0 | 425 | 375 | 1 |
| 100005 | 165 (LW) | 100005 | 0 | 75 | 25 | 1 |
| 100006 | 165 (LW) | 100006 | 0 | 200 | 150 | 1 |
| 100007 | 165 (LW) | 100007 | 0 | 325 | 275 | 1 |
| 100008 | 165 (LW) | 100008 | 0 | 425 | 375 | 1 |
| 100009 | 333 (Ench) | 100009 | 0 | 75 | 25 | 1 |
| 100010 | 333 (Ench) | 100010 | 0 | 200 | 150 | 1 |
| 100011 | 333 (Ench) | 100011 | 0 | 325 | 275 | 1 |
| 100012 | 333 (Ench) | 100012 | 0 | 425 | 375 | 1 |
| 100013 | 773 (Insc) | 100013 | 0 | 75 | 25 | 1 |
| 100014 | 773 (Insc) | 100014 | 0 | 200 | 150 | 1 |
| 100015 | 773 (Insc) | 100015 | 0 | 325 | 275 | 1 |
| 100016 | 773 (Insc) | 100016 | 0 | 425 | 375 | 1 |

### Phase 4: Package MPQ

#### Step 4.1 — Create patch-4.MPQ
- [ ] Open Ladik's MPQ Editor → Create new archive → `patch-4.MPQ`
- [ ] Add `DBFilesClient\Spell.dbc` (modified)
- [ ] Add `DBFilesClient\SkillLineAbility.dbc` (modified)
- [ ] Save archive with default compression

#### Step 4.2 — Install
- [ ] Place `patch-4.MPQ` in client `Data/` folder
- [ ] Delete `WDB/` cache folder (or at least `WDB/enUS/` to clear cached spell data)

### Phase 5: Test

- [ ] Launch client, log in
- [ ] Visit a Blacksmithing trainer → verify Runed/Tempered/Honed/Masterwork Whetstone recipes appear and can be learned
- [ ] Visit Leatherworking, Enchanting, Inscription trainers → same check
- [ ] Learn a recipe → verify it appears in the profession window with correct name/icon
- [ ] Craft a scroll → verify item is created with correct name
- [ ] Use the scroll on equipment → verify StatBooster enchant is applied
- [ ] Verify existing profession recipes still work (no corruption from DBC edit)
- [ ] Test with PTR server first, then main server

### Phase 6: Distribution (Later)
- [ ] Host `patch-4.MPQ` for download
- [ ] Document install instructions (copy to `Data/`, clear `WDB/`)
- [ ] Consider auto-patcher/launcher for future updates

---

## Key Risks & Notes

- **DBC column count must be exact** — Spell.dbc has 258 columns in the SQL / ~234 indices in the DBC binary. Wrong structure = client crash.
- **Locale strings** — Spell names have 16 locale slots (enUS, koKR, frFR, deDE, zhCN, zhTW, esES, esMX, ruRU, etc.). Populate at least enUS and ruRU for your players.
- **Server-client match** — The `spell_dbc` SQL and the client DBC must agree on spell IDs, effects, and reagents. They already match since we're building the client DBC from the same data.
- **SpellIconID** — Must reference a valid ID in SpellIcon.dbc or the client shows a blank icon.
- **WDB cache** — Players must clear their WDB folder after installing the patch or they may see stale data.
- **Other client-only fields** — Description, Tooltip, SpellVisual can be set for polish but aren't required for basic functionality.

## ID Reference
- Vanilla QA item IDs used: 17827-17830, 17883-17885, 17888-17889, 17891-17896, 18599
- Available gap: 17882 (unused)
- Custom spell IDs: 100001-100016
- Custom enchant IDs: 90001-90008
- Profession SkillLine IDs: 164 (BS), 165 (LW), 333 (Ench), 773 (Insc)
