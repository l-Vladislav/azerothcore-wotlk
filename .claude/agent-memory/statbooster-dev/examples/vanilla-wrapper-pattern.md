# Pattern: wrapping a vanilla proc-spell as a permanent enchant aura

## When you need this

Use this pattern when:
- You want to bind a **vanilla trinket-style proc** (e.g., Mark of the Chosen 21969, "+25 stats when struck") to a StatBooster enchant
- The vanilla spell was designed for **item-level `spellppmRate_1`** (i.e., the original trinket configures proc rate at `item_template.spellppmRate_1 = 2.00`)
- Directly referencing the vanilla spell via `SpellItemEnchantment.Effect_1=3 → EffectArg_1=<vanilla>` does **NOT** propagate the aura to the wearer

## Why direct reference fails

Vanilla trinket-style proc spells often have:
- `DurationIndex > 0` (timed aura, e.g. 1 minute)
- `Attributes` flags that imply "applied via item-level trigger, not as permanent aura"
- No own ProcChance/ProcFlags (because original trinket sets them at item level)

When such a spell is used as `EffectArg_1` of a type-3 EQUIP_SPELL enchant, AC's enchant application logic may not register the aura on the player (or registers it but it expires immediately, or doesn't pass proc evaluation).

**Diagnosis: how to confirm this is the case**
- Wear the trinket with the enchant
- Hit a mob, take damage
- Watch buff bar — no proc buff appears
- Apply the aura directly via `.aura <spellId>` GM command on yourself — if THAT triggers proc on damage, the spell mechanic itself works; the issue is purely the enchant→aura propagation

## The wrapper pattern

Create a custom spell that:
1. **Is permanent** (`DurationIndex = 0`) — no expiration
2. **Has clean passive attributes** — `Attributes = 80` (matches working enchant trigger spell 43929 Fiery Weapon)
3. **Has `EffectAura_1 = 42` (PROC_TRIGGER_SPELL)** — triggers another spell on proc
4. **Triggers the original effect spell** — `EffectTriggerSpell_1 = <vanilla effect>` (e.g., 21970 for Mark of the Chosen's +25-stats buff, NOT 21969 the aura-wrapper)
5. **Has its own ProcChance + ProcTypeMask** — so it fires correctly as enchant aura

Then update the enchant: `SpellItemEnchantment_custom.csv` `EffectArg_1` points to your new wrapper, NOT the vanilla spell.

## Live example: spell 100037 (Mark of the Chosen wrapper)

| Field | Value | Why |
|---|---|---|
| `ID` | 100037 | new custom ID |
| `Attributes` | 80 (PASSIVE) | copied from 43929 (Fiery Weapon — known working enchant trigger) |
| `DurationIndex` | 0 | permanent aura |
| `Effect_1` | 6 (APPLY_AURA) | applies the proc aura |
| `EffectAura_1` | 42 (PROC_TRIGGER_SPELL) | triggers the buff on proc |
| `EffectBasePoints_1` | -1 | use trigger spell's own defaults |
| `EffectTriggerSpell_1` | **21970** | the actual `+25 to all stats for 1min` buff (NOT 21969 the wrapper!) |
| `ProcTypeMask` | 1048576 (PROC_FLAG_TAKEN_DAMAGE) | fires on any damage received |
| `ProcChance` | 100 (testing) → drop to 2 for production | matches original 2% vanilla rate when tuned |
| `Name_Lang_zhTW` | `##SB##Удача: Знак избранного` | enchant marker + pool prefix + name |
| `Description_Lang_zhTW` | `##SB##Удача: Знак избранного — Шанс при получении удара повысить все характеристики на 25 ед. на 1 мин.` | shown to player on item tooltip |

Wired up via `SpellItemEnchantment_custom.csv` row 90138: `EffectArg_1 = 100037` (not 21969).

## Watch out — CSV editing pitfall

**Do NOT copy a row from main `Spell.csv` by naive split/modify/join.** Vanilla rows may contain commas INSIDE quoted text fields (e.g., spell descriptions with internal commas). Naive `string -split ','` breaks the quote-aware structure, your "cell indices" shift, and the resulting row imports either:
- With wrong column count (caught by importer), OR
- With shifted values in wrong columns (silent corruption — much worse)

**Correct approach:** build the new row from scratch — initialize all 232 cells to `"0"`, then override specific positions by index. No splitting of existing rows.

```powershell
$cells = New-Object string[] 232
for ($i = 0; $i -lt 232; $i++) { $cells[$i] = '"0"' }
$cells[0]   = '"<your-id>"'
$cells[114] = '"<EffectTriggerSpell_1>"'
$cells[142] = '"<Russian-name-here>"'
# ... etc
$row = $cells -join ','
```

## Column-position reference (Spell_custom.csv, 232 cols)

Key positions (0-indexed):
| col | field |
|---|---|
| 0 | ID |
| 4 | Attributes |
| 5-11 | AttributesEx, ExB-ExG |
| 26 | CastingTimeIndex |
| 32 | ProcTypeMask |
| 33 | ProcChance |
| 34 | ProcCharges |
| 38 | DurationIndex |
| 44 | RangeIndex |
| 66 | EquippedItemClass |
| 69-71 | Effect_1, Effect_2, Effect_3 |
| 72-74 | EffectDieSides_1..3 |
| 78-80 | EffectBasePoints_1..3 |
| 93-95 | EffectAura_1..3 |
| 108-110 | EffectMiscValue_1..3 |
| 114-116 | EffectTriggerSpell_1..3 |
| 131 | SpellIconID |
| 134-149 | Name_Lang_* (16 locales) |
| 142 | **Name_Lang_zhTW** (where Russian goes) |
| 150 | Name_Lang_Mask (typically 16712190) |
| 168-183 | Description_Lang_* |
| 176 | **Description_Lang_zhTW** |
| 184 | Description_Lang_Mask |
| 185-200 | AuraDescription_Lang_* |
| 193 | **AuraDescription_Lang_zhTW** |
| 223 | SchoolMask |

## Required SQL after editing CSV

1. `INSERT spell_dbc` — server-side mirror of the new spell row
2. `UPDATE spellitemenchantment_dbc SET EffectArg_1 = <new-id> WHERE ID = <enchant-id>` — rewire the enchant
3. `DELETE FROM spell_proc WHERE SpellId = <old-vanilla-spell>` — IF you previously added a hacky `spell_proc` override on the original vanilla spell, remove it (cleans up cross-contamination on any vanilla item using the original spell)

## Client deployment after CSV edit

- Regenerate `Spell.dbc` from `Spell_custom.csv` + main `Spell.csv` into client MPQ
- Regenerate `SpellItemEnchantment.dbc` from `SpellItemEnchantment_custom.csv`
- Delete client WDB cache: `spellcache.wdb`, `itemenchantcache.wdb`
- Update `EnchantDB.lua` in `Interface\AddOns\StatBoosterUI\` — strip `##SB##` AND pool prefix from the name (see [text-localization-rules.md](../text-localization-rules.md))
- `/reload` in game
