# ID range map (verified from actual CSV data, 2026-05-26)

This is what's **actually in the custom DBC files**, verified by direct grep — not aspirational reservations. The canonical convention from `EnchantDB.lua` line 93:

> Server uses 90xxx (Fortune/Arcana auras) and 91xxx (##SB## stat copies)

## Enchant IDs (`SpellItemEnchantment_custom.csv` — 348 rows)

| Range | Effect_1 mix | Purpose | Status |
|---|---|---|---|
| 90001 – 90050 | mostly EQUIP_SPELL (3), some COMBAT_SPELL (1) | Fortune T1 utility procs & auras (speed, water walking, fiery weapon, life steal, +AP, +SP, etc.) | live |
| 90051 – 90100 | mixed: COMBAT_SPELL (1), EQUIP_SPELL (3), USE_SPELL (7) | Higher-tier Fortune procs + use-spell scrolls | live |
| 90100 – 90105 | EQUIP_SPELL (3) | **Arcana T1 school spell damage** (Fire/Frost/Nature/Shadow/Arcane/Holy +3 ea, triggers custom spells 100040-100045) | live |
| 90101 – 90137 | EQUIP_SPELL (3) + STAT (5) | Arcana caster stats (Int, Spirit) + more procs | live |
| 91001 – 91241 | mostly STAT (5) — 228 rows; some RESISTANCE (4) — 12 rows | **##SB## stat copies** — basic stat-bonus enchants used across all pools (Battle, Warding, Arcana stats). All have `##SB##+N к рейтингу X` Russian names. | live |
| 91242+ | unused | free for new enchants | safe to claim |

**Gaps inside the 90001-91241 range:** `90006, 90033, 90038-90039, 90056-90069, 90091-90099, 90124-90129, 90138-91000` (896 free IDs).

### Picking a new enchant ID

| Need | Recommended range |
|---|---|
| New utility proc / aura (Fortune-style) | First free in `90138-91000` (e.g. 90138, 90139, …) |
| New stat-copy enchant (##SB## stat) | `91242+` (clean range, no risk of colliding with future T2/T3/T4 pool additions in 90xxx) |
| Other (resistance, use-spell scroll) | Verify which existing block uses that Effect_1, then claim the next free slot in that block |

Always grep `.claude/dbc/SpellItemEnchantment_custom.csv` to confirm an ID isn't taken before claiming.

## Spell IDs (`Spell_custom.csv` — 57 rows)

Custom spells live in this CSV (mirrored to `spell_dbc` SQL table). The 90xxx enchants' `EffectArg_1` references either a vanilla spell (in `Spell.csv`) or a custom spell here.

| Range | Owner | Status | Notes |
|---|---|---|---|
| 1 – ~70000 | Vanilla 3.3.5 | read-only | Reference via `.claude/dbc/Spell.csv` (~49k rows). Do not modify. |
| 10665, 10729 | (legacy custom) | live | "Хождение по воде", "Замедленное падение" — referenced by Fortune T1 enchants 90003, 90034. Do not reuse. |
| 100000 | **StatBooster** | live | "Apply Boost" — base spell that triggers a boost |
| 100001 – 100016 | **StatBooster** | live | Pool scroll **craft recipes** (one per scroll item). Need client MPQ patch for trainer UI. |
| 100017 – 100036 | **StatBooster** | live | Custom proc/aura spells referenced by Fortune-pool enchants. Examples: 100017-19 Чародейский взрыв (3 tiers), 100020 Подводное дыхание, 100021-23 Кольцо льда (3 tiers), 100024 Морозный доспех, 100025-27 Шипы (3 tiers), 100028-31 Жертвенный огонь (4 tiers), 100032-35 Кровавый союз (4 tiers), 100036 Чародейский взрыв lv4 |
| **100037** | **StatBooster** | live | **Mark of the Chosen wrapper** — custom permanent-aura wrapper for vanilla spell 21969. EffectAura=42 (PROC_TRIGGER_SPELL) → 21970. Used by enchant 90138. See [examples/vanilla-wrapper-pattern.md](examples/vanilla-wrapper-pattern.md). |
| 100038 – 100039 | reserved free | — | Safe for new StatBooster custom spells (Spell.dbc range, needs client MPQ patch) |
| 100040 – 100045 | **StatBooster** (Arcana) | live | School spell damage triggers (Fire/Frost/Nature/Shadow/Arcane/Holy) used by Arcana T1 enchants 90100-90105 |
| 100046 – 100119 | reserved free | — | Safe for new StatBooster custom spells |
| 100120 – 100122 | **familiars** | live | Familiar summon spells (Волчонок-Страж, Соколёнок, Вороненок). **Hands off — owned by [[familiars-dev]].** |
| 100123 – 101099 | familiars (reserve) | — | Treat as familiars territory. |
| 101100 – 101102 | **familiars** | live | Familiar aura spells (matching summons above). |
| 101103 – 101999 | familiars (reserve) | — | Familiar aura spill range. |
| 102000 – 104999 | **familiars** | live (partial) | Tiered familiar spells. |

### Picking a new spell ID

| Need | Recommended range |
|---|---|
| New custom proc spell triggered by an enchant | First free in `100037-100039` or `100046-100119` |
| New craft recipe (profession-trainable scroll) | New ID adjacent to 100001-100016 (but the block is contiguous — extending probably means 100017+ which collides with proc spells; prefer NOT extending — see Notes below) |
| Anything in `100120+` | DON'T — that's familiars territory. Delegate to [[familiars-dev]]. |

## Item IDs (StatBooster scope only)

| Range | Owner | Status |
|---|---|---|
| Vanilla 3.3.5 range | base | Read-only |
| `17827-17830, 17883-17885, 17888-17889, 17891-17896, 18599` | **StatBooster** | live — 16 scroll items (repurposed vanilla QA placeholders, no client patch needed) |
| 41605 | **StatBooster** | live — Attribute Recalibrator (existing vanilla item, repurposed) |
| Other custom items (100017+, etc.) | various features | Out of StatBooster scope — check `.claude/familiars/familiar_gacha_id_reservations.md` and `.claude/dbc/Item_custom.csv` before claiming |

## Notes

- **`.claude/dbc/id_mapping.json`** is a mapping file whose semantics are unclear (keys look like small numeric IDs, values are 91001-91241). My best current guess: it relates 91xxx stat enchants to their underlying stat type / mod_id, used by some pipeline. **Do not rely on it for ownership** — use the actual `SpellItemEnchantment_custom.csv` grep instead.
- **Pool design docs in `.claude/statBoosterItems/pools/`** are the canonical source for which enchant IDs are in which pool and at which tier. This map shows the *total reserved space*; pool docs show the *active roster*.
- **Familiar IDs (100120+, 101xxx+, 102xxx-104xxx)** also reserve overlapping ID space — never assign across the 100120 line without delegating to [[familiars-dev]].
- **Item-ID strategy in this fork**: prefer **repurposing vanilla QA placeholder items** (the 17xxx scroll IDs are the canonical example) over claiming high custom item IDs — it avoids needing client MPQ patches for `Item.dbc`/`ItemDisplayInfo.dbc`.
