# Nemesis Familiar Gacha — Design Document

Status: Phase 1 design, not implemented
Supersedes: `familiar_system_design.md` (3 roles × 5 tiers system, only T1 was shipped)
Companion doc: [familiar_gacha_catalog.md](familiar_gacha_catalog.md) — full 100-pet table with effects, names, IDs

## Concept

Convert the existing 3-pet familiar system into a **100-pet gacha collection** organised into **10 elemental families × 10 pets per family**. Pets are awarded only via lootbox-style chests purchased with a daily-quest currency. Most pets are pure buffs; some Commons carry intentional small +N / −1% trade-offs as "побитые" (flawed) variants of their clean siblings.

### Why gacha
- Long collection arc gives the rank/bounty/reputation system a meaningful sink.
- Many pets keep small individual power gains (no power creep) while the collection itself becomes the reward.
- Duplicate handling is simple: each scroll sells to vendor for 100g. Duplicates = gold, not waste.
- "Natural variant" Commons (clean + flawed pair sharing the same base creature model) make the pool feel more organic — pulling a known pet again with a slightly worse stat line still gives the player something distinctive to collect.

## Element families (10)

| # | Стихия | Доминирующая роль | Базовые темы Common | Models theme |
|---|---|---|---|---|
| 1 | Механический | Tank | Механокурица, Механобелка, Щитоносец | Механические конструкты, роботы, гномьи гизмо, шестерёнки |
| 2 | Огонь | Magic DPS (Fire) | Imp Igniter, Ember, Firewing Cub | Бесы, искры, огнекоты, лавовые слизни |
| 3 | Лёд | Magic DPS (Frost) | Snowflake, Icicle, Frost Mote | Ледяные духи, морозные зверьки |
| 4 | Природа | Healer | Firefly, Forest Sprite, Root Sapling | Сприты, светлячки, лесные создания, корешки |
| 5 | Свет | Healer / Resist Tank | Light Wing, Holy Dove, Cherub | Святые дрейки, голуби, ангелочки |
| 6 | Тень | Shadow DoT / Debuff-res | Raven, Shadow Moth, Plague Rat | Призрачные коты, мотыльки, нежить-мини, чума, туман |
| 7 | Тайна | Arcane DPS | Mana Wisp, Star Dust, Starlet | Манчики, звёздная пыль, эльфята, кометы |
| 8 | Гроза | Speed / Crit / Burst | Falcon Chick, Hawk, Spark | Соколята, ястребки, грозовые коты, молнии |
| 9 | Зверь | Phys DPS | Fox Cub, Tiger Cub, Scarab | Хищники, лисята, тигрята, скорпионы |
| 10 | Общий (бывш. Дух) | Utility (XP/honor/rep) | Сквернокот, Хлебная Жаба, Тотемный Дух | Питомцы-талисманы: кот, жаба, тотем, яйцо, мурлок, слайм, кролик |

Each family: **6 Common + 3 Rare + 1 Epic = 10 pets**. Commons are arranged as **3 базовых питомца × 2 варианта** — «чистый» (1 положительный эффект) и «побитый» (тот же бафф + маленький −1% дебафф, та же модель / DisplayID). See [familiar_gacha_catalog.md](familiar_gacha_catalog.md) for the full table.

## ID reservations (new ranges)

| Range | Purpose | Size |
|---|---|---|
| `102000–102099` | Summon spells (per pet) | 100 |
| `103000–103099` | Owner-aura spells, **positive-only** effects (buff bar) | 100 |
| `104000–104099` | Owner-aura spells, **negative-only** effects (debuff bar). Exists for flawed Commons and Epics with penalties — absent for clean Commons and Rares. | up to 100 |
| `191000–191099` | Familiar creatures | 100 |
| `110000–110099` | Familiar scroll items | 100 |
| `110100–110109` | Element-specific chests (10, one per family) | 10 |
| `110120` | Universal chest | 1 |
| `110150` | «Монета авантюриста» (gacha currency) | 1 |

Note: `110110–110119` is freed compared to the old 20×5 reservation; remains reserved for future chest variants if needed.

**Linear allocation:** family `F` (1-based, 1..10), pet `P` (1..10) within family →
- creature entry = `191000 + (F-1)*10 + (P-1)`
- summon spell = `102000 + (F-1)*10 + (P-1)`
- aura positive = `103000 + (F-1)*10 + (P-1)` (always exists)
- aura negative = `104000 + (F-1)*10 + (P-1)` (exists only for flawed Commons + Epics with penalties)
- scroll item = `110000 + (F-1)*10 + (P-1)`
- element chest = `110100 + (F-1)`

So Механический family 1.1 has creature 191000, spell 102000, aura 103000, scroll 110000, family chest 110100. Family 10.10 (Везунчик / Общий) has creature 191099, spell 102099, aura 103099, scroll 110099, family chest 110109.

**Retired ranges:**
- `100120–100134` (old T1 summons) — migrate `character_spell` rows to new 102000-099 mapping, then drop.
- `101100–101114` (old T1 auras) — drop.
- `190010–190024` (old T1 creatures) — drop.
- `100030–100044` (old T1 scrolls) — drop.

The 3 existing T1 pets are integrated into the new 10×10 pool as Common starters (slot 1 of their family):
| Old | New | Family.Slot |
|---|---|---|
| Волчонок-Страж (entry 190010) | entry 191000 | 1.1 Механический |
| Соколёнок (entry 190011) | entry 191070 | 8.1 Демонический (бывш. Гроза) |
| Воронёнок (entry 190012) | entry 191050 | 6.1 Тень |

## Gacha mechanics

### Currency
- **«Монета авантюриста»** (item 110150, LIVE on PTR 2026-06-07) — class 15, BoP,
  stackable 200, Quality 3, иконка inv_misc_coin_17 (displayid 55217).
- One per day via special quests (Фаза 7, отложено).
- Until quests exist: GM-grant (`.additem 110150`).
- Продажа сумок: у **мастера таверны** (тот же NPC, что и товары за жетоны
  немезиды) через ранговые гослип-подменю — см. familiar_gacha_chests_plan.md.

### Chests (LIVE on PTR 2026-06-07)
**Universal bag «Сумка Авантюриста»** (item 110120):
- Cost: 1 монета авантюриста
- Pool: all 100 pets
- Drop distribution: 89% Common / 10% Rare / 1% Epic
- Per-pet odds (60C+30R+10E): Common 1.483% · Rare 0.333% · Epic 0.100%

**Element bag «<Стихия> сумка»** (items 110100–110109):
- Cost: 5 монет авантюриста
- Pool: 10 pets of that family only (6C+3R+1E)
- Drop distribution: 75% Common / 20% Rare / 5% Epic (owner 2026-06-07: epic 10→5)
- Per-pet odds: Common 12.5% · Rare 6.67% · Epic 5.00%

→ Universal Epic chance per specific pet: 0.10%. Element-bag Epic of *that* family: 5% = **50× ratio for 5× cost**.

### Duplicates
No protection. Duplicate scroll = sellable to any vendor for **100g** (`SellPrice = 1000000` copper). Right-click on a duplicate scroll teaches nothing (server check on use; or scroll fails silently). Players liquidate dupes for gold.

### Chest opening flow (REVISED 2026-06-07 — data-driven, NO C++)

Chests are standard openable loot items: `item_template.Flags = 4` (`ITEM_FLAG_HAS_LOOT`)
+ **`item_loot_template`** rows with one loot GROUP per chest. Right-click → стандартное
лут-окно с одной клеткой. Преимущества: ноль C++/ребилдов, движковый лут-UI, mail-fallback
не нужен (лут висит в окне, пока не заберут).

Group semantics (verified in `src/server/game/Loot/LootMgr.cpp` `LootGroup::Roll`, ~line 1292):
explicit chances roll cumulatively against one rand(0..100); if none hit, a random pick
among the `Chance=0` (equal-chanced) entries — drop GUARANTEED. Group chances are NOT
scaled by `Rate.Drop.*` config.

Encoding (exact, sums to 100):
- Universal 110120, group 1: 60 Common cages @ `Chance=1.4833` + 30 Rare @ `0.3333`
  + 10 Epic @ `Chance=0` (split the ~1.003% remainder → ~0.1003% each).
- Element 1101xx, group 1: 6 Common @ `11.6667` + 3 Rare @ `6.6667`
  + 1 Epic @ `Chance=0` (remainder ≈ 10%).

Generated by `scripts/familiar-gen-chests.ps1` (план: см. familiar_gacha_chests_plan.md)
from the 10 family JSONs. The old C++ `ItemScript::OnUse` plan is RETIRED.

## Aura effect encoding

Each pet has a **positive owner-aura spell** in `103000–103099` (lands on the buff bar). Pets that also have penalties (flawed Commons, Epics) get a **second negative-only spell** in `104000–104099` (lands on the debuff bar). The C++ hook (`OnCreatureAddWorld`) casts both with `triggered=true`; the cast site guards with `sSpellMgr->GetSpellInfo(104000+idx)` so the absence of a debuff row is silent. Both are removed by `OnCreatureRemoveWorld` on despawn.

The split is mandatory: the 3.3.5a client classifies a spell as positive or negative as a whole, so a mixed row (+Sta and −Spi together) would render as one icon on the buff bar with both lines in the tooltip — not what we want. Two separate rows = buff icon + debuff icon visible at the same time.

### spell_dbc row shape (per aura row)
Inherits the post-2026-05-17 fixed pattern (see memory `feedback_spell_dbc_aura_fields` and `feedback_familiar_aura_uncancellable`):
```
Attributes        = 2147483648 (buff 103xxx)    -- 0x80000000 = NO_AURA_CANCEL
                  = 2214592512 (debuff 104xxx)  -- 0x84000000 = NO_AURA_CANCEL | AURA_IS_DEBUFF
                                 NOT 0x40 PASSIVE — passive routes triggered CastSpell through
                                 a "learned-only" path and silently no-ops.
                                 AURA_IS_DEBUFF on 104xxx forces _IsPositiveEffect()=false
                                 → AFLAG_NEGATIVE in SMSG_AURA_UPDATE → debuff bar (the
                                 server-side aura-positivity heuristic doesn't sign-detect
                                 MOD_TOTAL_STAT_PERCENTAGE/MOD_RESISTANCE; without the flag
                                 the debuff renders on the buff bar).
DurationIndex     = 21          (SpellDuration.dbc row 21 = -1/-1/-1 → PERMANENT, no timer.
                                 Earlier "30 min" comment in T1 SQL was wrong.)
ProcChance        = 101         (required, else APPLY_AURA effect discarded on creation)
RangeIndex        = 1           (self)
EquippedItemClass = -1
SchoolMask        = 1
SpellIconID       = TBD         (per pet, must be ≤ 4375)
```

Each effect slot (1..3) is filled with:
```
Effect_N            = 6   (APPLY_AURA)
EffectAura_N        = <aura ID from SpellAuraDefines.h>
EffectBasePoints_N  = <amount - 1>   (because DieSides_N=1 adds +1)
EffectDieSides_N    = 1               (REQUIRED, else amount = 0 silently)
EffectMiscValue_N   = <stat/mask>
ImplicitTargetA_N   = 1   (caster — applies to summoning player)
```

### Effect amounts by rarity (post-split scheme)
- **Common (clean):** 103xxx with 1 positive effect (+1% or +2%). No 104xxx.
- **Common (flawed "побитый" variant):** 103xxx with same +1–2% buff as its clean sibling, **and** 104xxx with 1 negative effect (−1% or −1 abs-resist). Uses same DisplayID as the clean version — only the name differs. Net-power slightly lower; intentional collectible variation.
- **Rare:** 103xxx with 2 positive effects (+3% +3%). No 104xxx.
- **Epic:** 103xxx with 3 positive effects (+5% +5% +5%) and 104xxx with 1–2 negative effects (−5% to −10% each).

### Common aura IDs (with notation used in the catalog)
| Aura ID | Const | Notation in catalog | Misc |
|---|---|---|---|
| 22 | MOD_RESISTANCE | "+N res(X)" | school mask (2/4/8/16/32/64; 126=all magic) |
| 29 | MOD_STAT | "+N <stat>" | 0=Str 1=Agi 2=Sta 3=Int 4=Spi |
| 31 | MOD_INCREASE_SPEED | "+N% движ." | — |
| 47 | MOD_PARRY_PERCENT | "+N% парир." | — |
| 49 | MOD_DODGE_PERCENT | "+N% уворот" | — |
| 51 | MOD_BLOCK_PERCENT | "+N% блок" | — |
| 57 | MOD_SPELL_CRIT_CHANCE | "+N% spell crit" | — |
| 65 | MOD_CASTING_SPEED_NOT_STACK | "+N% spell-haste" | — |
| 79 | MOD_DAMAGE_PERCENT_DONE | "+N% урон(X)" | school mask (X) |
| 85 | MOD_POWER_REGEN | "+N мана-регена" | 0=mana |
| 99 | MOD_ATTACK_POWER | "+N AP" | — |
| 101 | MOD_RESISTANCE_PCT | "+N% броня" | 1 (armor) |
| 110 | MOD_POWER_REGEN_PERCENT | "+N% мана регена" | 0=mana |
| 118 | MOD_HEALING_PCT | "+N% получ. лечения" | — |
| 133 | MOD_INCREASE_HEALTH_PERCENT | "+N% HP" | — |
| 135 | MOD_HEALING_DONE | "+N лечения" | — |
| 136 | MOD_HEALING_DONE_PERCENT | "+N% лечения" | — |
| 137 | MOD_TOTAL_STAT_PERCENTAGE | "+N% <stat>" | stat index (0..4); -1=all |
| 138 | MOD_MELEE_HASTE | "+N% мили-хейст" | — |
| 156 | MOD_REPUTATION_GAIN | "+N% репутации" | — |
| 166 | MOD_ATTACK_POWER_PCT | "+N% AP" | — |
| 178 | MOD_DEBUFF_RESISTANCE | "+N% debuff resist" | — |
| 192 | MOD_MELEE_RANGED_HASTE | "+N% хейст" | — |
| 200 | MOD_XP_PCT | "+N% XP" | — |
| 235 | MOD_DISPEL_RESIST | "+N% dispel resist" | — |
| 280 | MOD_ARMOR_PENETRATION_PCT | "+N% armor pen" | — |
| 281 | MOD_HONOR_GAIN_PCT | "+N% honor" | — |
| 290 | MOD_CRIT_PCT | "+N% крит" | unified |

Penalties = same aura IDs with negative `EffectBasePoints`. Example: "−3% AP" → aura 166, BP=−4, DS=1, amount = −3.

## Server vs client

### Fully server-side (no MPQ needed for mechanics):
- spell_dbc rows (summon + aura) — added via SQL, loaded at worldserver startup
- creature_template + model + locale — purely DB
- item_template + locale — DB, client queries server on first sight
- vendor rows — DB
- chest opening logic — C++ ItemScript

### Needs client MPQ (cosmetic only — game-mechanically works without):
- 100 summon spells in Spell_custom.csv (names + icons in Pet menu)
- 100 owner-aura spells in Spell_custom.csv (buff-bar names + icons)
- 100 scroll items in Item_custom.csv (inventory icons + tooltips show Russian names)
- 21 chest items in Item_custom.csv
- 1 coin item in Item_custom.csv

Per memory rule [[feedback_csv_updates]] — only update CSVs when explicitly preparing an MPQ build. Iterative work uses server-side only.

## Implementation phases

| # | Phase | Status |
|---|---|---|
| 1 | Design docs + memory updates | **in progress** |
| 2 | DisplayID / SpellIconID verification (needs docker + ptr-query) | pending |
| 3 | SQL migration (split into 5 files: spells, creatures, items, chests, t1-migrate) | pending |
| 4 | C++ — extended aura map + chest ItemScript | pending |
| 5 | Pool config table `nemesis_familiar_pool` (BD-driven weights) | pending |
| 6 | MPQ rebuild (Spell_custom.csv + Item_custom.csv) | deferred |
| 7 | Tavern daily quest for coin | deferred |

## Open decisions for next iteration

1. **Pool config in DB vs hardcoded:** Phase 5 proposes a `nemesis_familiar_pool` table for tunable weights. Recommended yes — designers tweak weights without recompile. Confirmed on first run, code reads weights at startup.
2. **Coin reuse:** new entry `110150` vs reuse `100017` (Жетон немезиды). Plan assumes new — keeps bounty economy separate from gacha. Change if you want unified token.
3. **Starter pack:** new players get 1 universal chest free via existing onboarding flow, or strictly cold-start via daily quest. Plan assumes cold-start.
4. **Element-chest vendor gating:** all 20 element chests visible from day 1, or unlock progressively (e.g. need 5/10/15 of that family collected to see the chest)? Plan assumes all visible.

## References

- Existing T1 implementation log: [familiar_system_implementation.md](familiar_system_implementation.md) — keep for rollback reference; will be retired after this design is shipped.
- Server-side capability matrix: [../server-side-capabilities.md](../server-side-capabilities.md)
- MPQ workflow: [../guide_mpq_patching.md](../guide_mpq_patching.md)
- Custom-spell quirks: `feedback_spell_dbc_aura_fields` in memory
- DisplayID verification rule: `feedback_verify_displayid` in memory
