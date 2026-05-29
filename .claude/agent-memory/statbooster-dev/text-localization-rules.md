# Russian text & the `##SB##` tag — the two rules

Two non-obvious conventions that together control how StatBooster Russian text appears in-game. **Both are load-bearing.** Get either wrong and the enchant either won't show in Russian or won't get StatBooster's cosmetic styling.

---

## Rule 1: Russian text goes into the `zhTW` slot

This fork's Russian client uses **`zhTW` (Chinese Traditional)** as its translation slot for DBC-side text. NOT `ruRU`. This applies to both `Spell_custom.csv` and `SpellItemEnchantment_custom.csv`.

The `_ruRU` columns are sometimes filled — but they're not read by the client. Verified by spotting stale template content in `_ruRU` (e.g. all 103xxx familiar auras have `_ruRU = "Аура фамильяра: Волчонок-Страж"` regardless of which familiar) — yet the wrong text never shows in-game, proving the `_ruRU` column is inert.

### Server log confirms

```
Server.log: Using enUS DBC Locale As Default. All Available DBC locales: enUS
```

Plus `worldserver.conf`: `RealmZone = 12` (Russian zone) but `DBC.Locale = 255` (auto → enUS). The Russian client is bootstrapped as enUS with a translation MPQ that maps Cyrillic into the unused zhTW slot.

### Where to write Russian in each table

`Spell_custom.csv` (232 columns):
- Headers are quoted (`"Name_Lang_zhTW"`)
- Find columns by grepping the header — don't memorize indices since the schema may evolve

`SpellItemEnchantment_custom.csv` (38 columns, **no quotes** on values):
- `Name_Lang_zhTW` is column 22 (0-indexed)
- `Name_Lang_ruRU` is column 25 (do not trust)
- `Name_Lang_Mask` is column 30 (typical value: `16712190`)

How to verify column positions yourself:
```powershell
$csv = ".claude/dbc/<file>.csv"
$header = (Get-Content $csv -First 1) -split ','
for ($i=0; $i -lt $header.Count; $i++) { if ($header[$i] -match 'Lang') { "[$i] $($header[$i])" } }
```

---

## Rule 2: Prefix Russian enchant text with `##SB##`

`##SB##` is the **canonical marker that a buff is a real StatBooster effect** (as opposed to a vanilla enchant, a familiar aura, etc.). Both the server-side code and the client addon use it to identify which buffs/lines belong to StatBooster.

On the client, `modules/StatBooster/ClientAddon/StatBoostTooltip/StatBoostTooltip.lua` scans item tooltips for the tag and recolors matching lines.

```lua
local TAG = "##SB##"
-- Boosted item tooltip: recolor ##SB## lines
-- NOTE: Do NOT match non-##SB## lines (like "+27 к силе атаки")
```

### Where the prefix goes

Inside the Russian text value of `Name_Lang_zhTW` (and optionally `Description_Lang_zhTW`), as a literal substring:

```
Name_Lang_zhTW = "##SB##Удача: +5% к скорости передвижения"
Name_Lang_zhTW = "##SB##+5 к рейтингу защиты"
```

The addon shows the line to the player WITHOUT the prefix (it strips it) and recolors the line gold/special. Without the tag the line still appears in the tooltip — but plain-styled like any other enchant, and the system no longer treats the buff as a StatBooster effect for matching/filtering purposes.

### `EnchantDB.lua` confirms the convention

`modules/StatBooster/ClientAddon/StatBoosterUI/EnchantDB.lua` (line 93):
```lua
-- Server uses 90xxx (Fortune/Arcana auras) and 91xxx (##SB## stat copies)
```

So:
- **90xxx** enchants get `##SB##` prefix on their Russian name (e.g. `##SB##Удача: Хождение по воде`) — Fortune/Arcana procs and utility auras
- **91xxx** enchants get `##SB##` prefix on their Russian stat description (e.g. `##SB##+5 к рейтингу защиты`) — stat copies

Always add `##SB##` to a new enchant's `Name_Lang_zhTW` unless you have a deliberate reason not to.

---

## Rule 3: Mirror Russian names into the client addon Lua table

`modules/StatBooster/ClientAddon/StatBoosterUI/EnchantDB.lua` contains a table `SB.DB.EnchantNames` mapping enchant ID → Russian display name (without `##SB##` prefix, stripped). The addon uses this for the spellbook tab listing, not for the tooltip itself.

Pool structure (which IDs go in which pool / iLvl) syncs from the **server** automatically on login. Only display names are baked into the Lua.

From `fortune_T2.md` design doc:
```
> SYNC: When editing this file, also update `SB.DB.EnchantNames[id]` in
> modules/StatBooster/ClientAddon/StatBoosterUI/EnchantDB.lua with Russian names
> for any new enchant IDs.
```

### Format of the Lua entry — strip BOTH `##SB##` AND pool prefix

The DBC `Name_Lang_zhTW` has format: `##SB##<PoolPrefix>: <name>`. The Lua table stores ONLY `<name>` — both the `##SB##` tag and the pool prefix (`Удача:`, `Тайный:`, etc.) are stripped.

```lua
SB.DB.EnchantNames = {
    [90001] = "+5% к скорости передвижения",         -- CSV had: ##SB##Удача: +5% к скорости передвижения
    [90041] = "Похищение жизни",                      -- CSV had: ##SB##Удача: Похищение жизни
    [90130] = "+3 к интеллекту",                      -- CSV had: ##SB##Тайный: +3 к интеллекту
    [90138] = "Знак избранного",                      -- CSV had: ##SB##Удача: Знак избранного
}
```

### Pool prefixes (in DBC text only)

| Pool | DBC prefix |
|---|---|
| 1 Battle | `Боевой:` |
| 2 Warding | `Защитный:` |
| 3 Arcana | `Тайный:` |
| 4 Fortune | `Удача:` |
| 0 General (Recalibrator) | none |

### ⚠️ Where `##SB##` MUST go — depends on enchant `Effect_1` type

**Critical:** WoW 3.3.5 client renders enchant tooltip differently based on `SpellItemEnchantment.dbc.Effect_1`:

| `Effect_1` | What client renders in item tooltip | Where to put `##SB##` |
|---|---|---|
| **5 (STAT)** | Enchant `Name_Lang_zhTW` (e.g. `+5 к защите`) | `SpellItemEnchantment.dbc.Name_Lang_zhTW` |
| **4 (RESISTANCE)** | Enchant `Name_Lang_zhTW` | `SpellItemEnchantment.dbc.Name_Lang_zhTW` |
| **3 (EQUIP_SPELL)** | **ONLY** triggered spell's `Description_Lang_zhTW` (from `Spell.dbc`), prefixed by `Использование:` / `Equip:` / `Chance on hit:`. **Enchant's own `Name_Lang_zhTW` is NOT shown.** | `Spell.dbc.Description_Lang_zhTW` of the triggered spell |
| **1 (COMBAT_SPELL)** | Same as type 3 — spell Description only | `Spell.dbc.Description_Lang_zhTW` |
| **7 (USE_SPELL)** | Same as type 3 — spell Description only | `Spell.dbc.Description_Lang_zhTW` |

**For type-3/1/7 enchants you SHOULD also put `##SB##` in `SpellItemEnchantment.dbc.Name_Lang_zhTW` for completeness** (other systems may read it, and it's harmless cosmetic). But the addon's tooltip detection relies on the spell Description line.

### Addon detection logic (DetectEnchantPool)

The addon scans tooltip lines for `##SB##`. For a type-3 enchant the matched line is the spell Description, which after client prefixing looks like:

```
Использование: ##SB##Удача: Жертвенный огонь — При ударе наносит 5 ед...
```

After `##SB##` strip: `Использование: Удача: Жертвенный огонь — ...`. The addon needs to strip **both** the client prefix (`Использование:`) AND the pool prefix (`Удача:`) to recover the canonical enchant name. As of 2026-05-26 the addon does double-strip via two consecutive `gsub("^[^:]+:%s*", "")` calls.

### Historical bugs (don't repeat)

- **2026-05-26 (a)**: Tried stripping `##SB##` from Spell.dbc Description for spells 100028-100031 (Жертвенный огонь) thinking it would help addon matching. Wrong — for type=3 enchants the client renders ONLY the spell Description, so removing `##SB##` from Description = no marker anywhere = addon doesn't detect the enchant at all. **Reverted in `statbooster_sacrificial_fire_restore_sb_prefix.sql`.** The real fix was double-prefix-strip in `DetectEnchantPool` (`EnchantDB.lua` ~line 645).

- **2026-05-26 (b)**: Wired enchant 90138 directly to vanilla spell 21969 (Mark of the Chosen). Spell never procced in-game because 21969 was designed for item-level `spellppmRate_1`, not for permanent EQUIP_SPELL enchant aura — AC's enchant application doesn't propagate it correctly to the wearer. **Diagnosed** via `.aura 21969` on dummy (worked) vs. on player via enchant (silent failure). **Fixed** by creating custom wrapper spell **100037** with `Attributes=80`, `DurationIndex=0` (infinite), `EffectAura=42` (PROC_TRIGGER_SPELL), `EffectTriggerSpell_1=21970` (the real buff). Pattern documented in [examples/vanilla-wrapper-pattern.md](examples/vanilla-wrapper-pattern.md).

- **2026-05-26 (c)**: When building the wrapper spell 100037, naively copied vanilla 43929 row from `Spell.csv` via `string -split ','` and modify. The 43929 row contained commas INSIDE quoted Description text, so naive split broke the structure and cells shifted into wrong columns. WDBXEditor CSV import flagged this as "data-to-datatype mismatch". **Fixed** by rebuilding the row from scratch — all 232 cells initialized to `"0"`, only specific positions overridden by index. **Rule for any future Spell_custom.csv additions:** never naive-split a vanilla row to copy it. Build from scratch.

### Rule of thumb when adding a new custom proc spell + enchant

1. Pick `Effect_1 = 3` (EQUIP_SPELL) for "proc on hit / on struck" enchants.
2. Add the triggered spell to `Spell_custom.csv`:
   - `Description_Lang_zhTW = ##SB##<PoolPrefix>: <Name> — <body>`
   - `AuraDescription_Lang_zhTW = <PoolPrefix>: <Name> — <body>` (no `##SB##` here — Aura description shows in buff bar tooltip, not item tooltip)
3. Add the enchant to `SpellItemEnchantment_custom.csv`:
   - `Name_Lang_zhTW = ##SB##<PoolPrefix>: <Name>` (cosmetic, in case some system reads it; client won't show it for type-3)
   - `EffectArg_1 = <triggered spell ID>`
4. Mirror to SQL: `INSERT spellitemenchantment_dbc` + `INSERT statbooster_enchant_template`.
5. Add Lua entry to `EnchantDB.lua` `SB.DB.EnchantNames[id] = "<Name>"` — strip ALL prefixes, just the bare name.

Existing reference examples (type-3 enchants that work): 90030 Шипы → spell 100025, 90040 Огненное оружие → spell 43929 (vanilla), 90082-90085 Жертвенный огонь → spells 100028-100031.

**Why two formats:** the DBC text is what the player sees on the item tooltip (after addon recoloring). The pool prefix there is informational ("this is a Fortune enchant"). The Lua table is used by the StatBooster UI spellbook tab, where the pool is already shown as a separate UI element — so the prefix would be redundant.

**Canonical comment in `EnchantDB.lua` (line 94):**
```lua
-- To regenerate: grep DBC CSV, strip ##SB## and pool prefixes
```

Cyrillic in the Lua file: UTF-8 source can be written either as literal Cyrillic OR as `"\208\145..."` byte sequences. Both work; existing entries use literal Cyrillic for readability. If your editor preserves UTF-8, use literal text.

### Three places, one Russian string

Adding a new enchant means writing the Russian name in **three places** that must stay in sync:

| Location | Format | Notes |
|---|---|---|
| `.claude/dbc/SpellItemEnchantment_custom.csv` `Name_Lang_zhTW` | `##SB##<russian>` | Source of truth for client display |
| `data/sql/updates/pending_db_world/*.sql` INSERT into `spellitemenchantment_dbc.Name_Lang_zhTW` | `##SB##<russian>` | DB-side mirror so worldserver sends it to clients |
| `modules/StatBooster/ClientAddon/StatBoosterUI/EnchantDB.lua` `SB.DB.EnchantNames[id]` | `<russian>` (no `##SB##`) | Cosmetic display in spellbook UI |

If you skip the Lua update: enchant works in-game and tooltips work, but the spellbook tab shows `???` or blank for that ID until the next addon update.

If you skip the `##SB##` prefix in DBC/SQL: enchant works mechanically but tooltip line isn't recolored — looks like a vanilla enchant.

---

## Quick checklist for any new enchant

1. ✅ Russian goes in `Name_Lang_zhTW` (NOT `_ruRU`)
2. ✅ Prefix with `##SB##`
3. ✅ Mirror into `EnchantDB.lua` `SB.DB.EnchantNames[id]` (without `##SB##`)
4. ✅ Both `SpellItemEnchantment_custom.csv` (DBC) and `spellitemenchantment_dbc` (SQL) match
5. ✅ Other `_locale` SQL tables (creature, quest, item_template) still use the standard `locale='ruRU'` — this zhTW quirk is **only** for DBC-style data

See [examples/add-new-enchant.md](examples/add-new-enchant.md) for a full worked example with all three syncs.
