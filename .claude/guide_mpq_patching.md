# MPQ Client Patching Guide (WoW 3.3.5a)

## How MPQ Patches Work

The WoW client loads MPQ archives from the `Data/` folder in alphabetical/numerical order. Files in later-loaded MPQs override earlier ones.

**Default Blizzard patches:** `patch.MPQ`, `patch-2.MPQ`, `patch-3.MPQ`
**Custom patches:** `patch-4.MPQ`, `patch-A.MPQ`, `patch-Z.MPQ` (letters sort after numbers)

Files inside the MPQ must mirror the original directory structure:
```
patch-4.MPQ/
  DBFilesClient/
    Spell.dbc
    SpellItemEnchantment.dbc
    SkillLineAbility.dbc
    ...
  Interface/
    Icons/
      CustomIcon.blp
    ...
```

## What Can Be Customized via MPQ

### DBC Files (`DBFilesClient/`)

| DBC File | What It Controls |
|----------|-----------------|
| `Spell.dbc` | Spell definitions — name, icon, cast time, effects, tooltips, reagents |
| `SpellItemEnchantment.dbc` | Enchantment display names and effects shown on items |
| `SkillLineAbility.dbc` | Maps spells to professions/skill lines (makes recipes appear in profession UI) |
| `SkillLine.dbc` | Profession/skill definitions (name, icon, category) |
| `SpellIcon.dbc` | Maps icon IDs to texture paths |
| `SpellCastTimes.dbc` | Cast time entries referenced by Spell.dbc |
| `SpellDuration.dbc` | Duration entries |
| `SpellRange.dbc` | Range entries |
| `SpellVisual.dbc` | Spell visual effects |
| `Item.dbc` | Client-side item display data |
| `ItemDisplayInfo.dbc` | Item appearance (model, texture, icon) |
| `CreatureDisplayInfo.dbc` | Creature model assignments |
| `Talent.dbc` / `TalentTab.dbc` | Talent trees |
| `ChrRaces.dbc` / `ChrClasses.dbc` | Race/class definitions |
| `Map.dbc` | Map definitions |
| `AreaTable.dbc` | Zone/area definitions |
| `LoadingScreens.dbc` | Loading screen assignments |
| `SoundEntries.dbc` | Sound file references |
| `Achievement.dbc` | Achievement definitions |

### Visual Assets

| Type | Path | Format |
|------|------|--------|
| Spell/item icons | `Interface/Icons/` | BLP (64x64, DXT1/DXT3/DXT5) |
| Loading screens | `Interface/GLUES/LoadingScreens/` | BLP |
| Login screen | `Interface/GLUES/` | BLP + XML/Lua |
| Minimap/worldmap | `Interface/WorldMap/` | BLP |
| Fonts | `Fonts/` | TTF |
| Creature models | various M2 paths | M2 + BLP textures |
| Item models | various M2 paths | M2 + BLP textures |
| Terrain | `World/Maps/` | ADT files |
| Buildings/objects | various WMO paths | WMO + BLP |
| Sound/music | `Sound/` | WAV/MP3 |
| Cinematics | various | AVI |
| Particle effects | embedded in M2/SpellVisualKit | - |

### UI Customization
- Custom addon-like frames via `Interface/` XML/Lua
- Custom fonts in `Fonts/`
- Login screen art and layout

## Adding Custom Profession Recipes (Our Use Case)

To make StatBooster craft spells (100001-100016) appear in profession windows:

### Step 1: Extract base Spell.dbc from client
```
1. Open patch-3.MPQ (or latest Blizzard patch) with Ladik's MPQ Editor
2. Extract DBFilesClient/Spell.dbc
```

### Step 2: Add custom spell entries to Spell.dbc
For each craft spell, add a row with:
- `ID` — spell ID (100001-100016)
- `SpellName` — recipe name (e.g., "Runed Whetstone")
- `SpellIconID` — existing icon ID from SpellIcon.dbc
- `CastingTimeIndex` — reference to SpellCastTimes.dbc
- `Effect1` — 24 (SPELL_EFFECT_CREATE_ITEM) for crafting
- `EffectItemType1` — created item entry (17827, etc.)
- `Reagent1-8` / `ReagentCount1-8` — crafting materials
- `RequiredSkillLine` — profession skill ID
- `RequiredSkillRank` — minimum skill to learn

### Step 3: Add to SkillLineAbility.dbc
Link each spell to its profession:
- `SkillLine` — 164 (Blacksmithing), 165 (Leatherworking), 333 (Enchanting), 773 (Inscription)
- `SpellID` — matching spell ID
- `MinSkillLineRank` — minimum skill to learn
- `TrivialSkillLineRankHigh/Low` — skill-up color thresholds

### Step 4: Package into MPQ
```
1. Create new MPQ archive: patch-4.MPQ
2. Add modified files at DBFilesClient/Spell.dbc, DBFilesClient/SkillLineAbility.dbc
3. Place patch-4.MPQ in client Data/ folder
```

### Step 5: Verify server-side matches
- Server `spell_dbc` table must have matching entries (already done: IDs 100001-100016)
- `skilllineability_dbc` table must match (already done)
- `npc_trainer` entries must match (already done)

## Important Profession Skill Line IDs

| Profession | SkillLine ID |
|------------|-------------|
| Blacksmithing | 164 |
| Leatherworking | 165 |
| Alchemy | 171 |
| Enchanting | 333 |
| Engineering | 202 |
| Tailoring | 197 |
| Mining | 186 |
| Herbalism | 182 |
| Skinning | 393 |
| Jewelcrafting | 755 |
| Inscription | 773 |
| Cooking | 185 |
| First Aid | 129 |
| Fishing | 356 |

## Key Spell.dbc Fields for Crafting Recipes

| Field | Description |
|-------|-------------|
| `Effect1` | 24 = CREATE_ITEM, 53 = ENCHANT_ITEM |
| `EffectItemType1` | Item entry to create |
| `EffectMiscValue1` | Enchantment ID (for ENCHANT_ITEM) |
| `Reagent1-8` | Required material item IDs |
| `ReagentCount1-8` | Quantity of each reagent |
| `EquippedItemClass` | Target item class filter (-1 = any) |
| `EquippedItemSubClassMask` | Target subclass bitmask |
| `SpellIconID` | Icon reference (from SpellIcon.dbc) |
| `CastingTimeIndex` | Cast time reference (from SpellCastTimes.dbc) |
| `ManaCost` | Mana cost to cast |

## Tools

### DBC Editors
- **WDBX Editor** — modern, open-source (GitHub: WowDevTools/WDBXEditor), import/export CSV
- **SpellWork / Spell Editor** — specialized for Spell.dbc with human-readable fields
- **MyDBCEditor** — older but functional
- **DBCUtil** — CLI tool for DBC ↔ CSV conversion

### MPQ Tools
- **Ladik's MPQ Editor** — gold standard GUI tool for creating/editing MPQ archives
- **StormLib** — C/C++ library for programmatic MPQ manipulation
- **mpq-tools** — CLI tools for Linux

### Texture Tools
- **BLP Lab / BLPConverter** — BLP ↔ PNG/TGA conversion
- **WoW Model Viewer** — view and export M2/WMO models

## Gotchas and Limitations

- **DBC structure is version-locked** — 3.3.5a expects exact column counts/types; wrong structure crashes the client
- **Client-server mismatch** — both sides must agree on spell IDs; mismatched data causes disconnects
- **String localization** — DBC strings have slots per locale (enUS, deDE, frFR...); populate the correct locale column or other-language players see blank text
- **Spell tooltip formulas** — client computes tooltips client-side; complex custom effects may show wrong values
- **Max spell ID** — very high IDs (millions) can cause memory issues; stay under ~200000
- **BLP format** — textures must be correct format (DXT1/DXT3/DXT5) and power-of-2 dimensions
- **WDB cache** — clients may cache old DBC data in `WDB/` folder; clear it after patching
- **Only include changed files** — keep patch MPQ small; don't include unmodified DBCs
- **Cannot change hardcoded client behavior** — class mechanics, combo points, rune system, opcodes are compiled into the client binary

## Distribution to Players

1. **Direct download** — host `patch-4.MPQ` on server website, players drop it in `Data/`
2. **Custom launcher** — auto-downloads and places patches, sets realmlist
3. **Full client repack** — pre-modified client download (large, but simplest for players)
4. Provide checksums (MD5/SHA) for integrity verification
5. Version patches so players know when to update
