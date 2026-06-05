# Familiar owner-aura — spell_dbc row template

**Critical.** Skipping any required field makes the aura silently no-op or apply with amount=0. Empirically validated end-to-end on PTR 2026-05-29 (5 test pets, both buff bar + debuff bar render correctly).

## School-damage % auras (79) work but are INVISIBLE in the char sheet — accepted

Verified 2026-06-05 with a +100% diagnostic boost: aura 79 (`MOD_DAMAGE_PERCENT_DONE`,
misc = school mask, `EquippedItemClass=-1`) **does multiply real damage** (Fireball hit
20 → 40), but the paperdoll «Доп. урон» line shows only flat `MOD_DAMAGE_DONE_POS` —
the 3.3.5 client ignores the `_PCT` field there even at ×2. Owner decided to LEAVE IT
(declined an addon hook of `PaperDollFrame_SetSpellBonusDamage`). Don't re-investigate
"X% school damage doesn't work" reports — first check real hit numbers, not the sheet.
Stat % auras (137) and crit/armor DO show computed values in the sheet, which is why
those "look working" and 79 doesn't.

## Required Attributes per row type

| Row type | `Attributes` value | Hex | Composed of |
|---|---|---|---|
| Buff (103xxx, buff bar) | `2147483648` | `0x80000000` | `NO_AURA_CANCEL` |
| Debuff (104xxx, debuff bar) | `2214592512` | `0x84000000` | `NO_AURA_CANCEL` \| `AURA_IS_DEBUFF` |

**Why both flags on debuffs:**
- `NO_AURA_CANCEL` (`0x80000000`) — player can't right-click off (harmless on debuff since debuffs aren't right-cancellable anyway, but kept for consistency; C++ hook removes on despawn).
- `AURA_IS_DEBUFF` (`0x04000000`) — **REQUIRED** for debuff-bar placement. The server's `SpellInfo::_IsPositiveEffect()` only sign-detects negativity for a hardcoded set of aura types (`MOD_STAT` 29, `MOD_DAMAGE_PERCENT_DONE` 79, `MOD_DODGE_PERCENT` 49, etc.). `MOD_TOTAL_STAT_PERCENTAGE` (137) and `MOD_RESISTANCE` (22) — the ones we use for debuffs — are NOT in that list, so a negative-value 137/22 aura defaults to POSITIVE and lands on the buff bar. `AURA_IS_DEBUFF` forces `_IsPositiveEffect()=false` → `AFLAG_NEGATIVE` in `SMSG_AURA_UPDATE` → client renders on debuff bar. The `AFLAG_NEGATIVE` flag is computed server-side; updating server `spell_dbc.Attributes` + worldserver restart is enough — MPQ rebuild not required for bar placement (but CSV should match for consistency).

## Row-level (every familiar buff `103000–103099` and debuff `104000–104099`)

```
Attributes        = 2147483648 (buff)    -- 0x80000000 = SPELL_ATTR0_NO_AURA_CANCEL
                    2214592512 (debuff)  -- 0x84000000 = NO_AURA_CANCEL | AURA_IS_DEBUFF
                                       (NEVER use 0x40 PASSIVE — passive routes
                                        triggered cast through learned-only path
                                        and the aura silently no-ops.)
DurationIndex     = 21              -- SpellDuration.dbc row 21 = -1/-1/-1 (permanent).
                                       30-min comment in old T1 SQL was a bug.
ProcChance        = 101             -- REQUIRED. Without this, APPLY_AURA discarded
                                       at spell-creation time.
RangeIndex        = 1               -- self
EquippedItemClass = -1
SchoolMask        = 1
SpellIconID       = TBD             -- Phase 2 verification, ≤ 4375
```

## Per-effect (slots 1..3)

```
Effect_N            = 6             -- APPLY_AURA
EffectAura_N        = <aura ID>
EffectBasePoints_N  = <amount − 1>  -- BasePoints + DieSides = amount; DS=1 ⇒ BP=amt−1
EffectDieSides_N    = 1             -- REQUIRED. Without it amount = 0 silently.
EffectMiscValue_N   = <stat/mask>
ImplicitTargetA_N   = 1             -- caster (the summoning player)
```

## Split positive / negative — buff bar vs debuff bar

The client 3.3.5a classifies a spell as positive or negative **as a whole** — not per-effect. A spell with both `+Sta` and `−Spi` in one row shows up as a single buff-bar icon with both lines in the tooltip. To get separate buff + debuff icons we **split** the aura into two spell rows:

| Range | Role | Bar shown on |
|---|---|---|
| `103000–103099` | positive-only effects | top-right buff bar |
| `104000–104099` | negative-only effects | debuff bar |

Both rows are cast by the C++ hook on summon and removed on despawn. The 104xxx row exists for any pet that has at least one penalty, not only Epics. Cast site guards with `sSpellMgr->GetSpellInfo(104000+idx)` so the absence of a debuff row is silent.

## Amount rules by rarity (post-split)

| Rarity | 103xxx (positive aura) | 104xxx (negative aura) |
|---|---|---|
| Common clean | 1 positive (+1% or +2%) | — |
| Common flawed («побитый») | 1 positive (same buff as the clean pair) | 1 negative (−1% or −1 abs-resist) |
| Rare | 2 positives (+3% each) | — |
| Epic | 3 positives (+5% each) | 1–2 negatives (−5% to −10% each) |

Penalty encoding: same aura ID, negative `EffectBasePoints`. Example «−3% AP»: aura 166 (`MOD_ATTACK_POWER_PCT`), `BP=−4`, `DS=1`, amount = −3.

## Why split, not mixed-in-one-row

A mixed row would render as a single buff icon (or single debuff icon if the spell's primary effect was negative — unreliable heuristic). Players wouldn't see the trade-off visually. Split = honest UI: bonus is on the buff bar, penalty is on the debuff bar, both visible at once.

## Penalty encoding

Same aura ID, negative `EffectBasePoints`. Example «−3% AP»: aura 166 (`MOD_ATTACK_POWER_PCT`), `BP=−4`, `DS=1`, amount = −3.

## Common aura IDs (full table in design doc)

22 MOD_RESISTANCE · 29 MOD_STAT · 31 MOD_INCREASE_SPEED · 47 MOD_PARRY_PERCENT · 49 MOD_DODGE_PERCENT · 51 MOD_BLOCK_PERCENT · 57 MOD_SPELL_CRIT_CHANCE · 65 MOD_CASTING_SPEED_NOT_STACK · 79 MOD_DAMAGE_PERCENT_DONE (school mask in misc) · 85 MOD_POWER_REGEN · 99 MOD_ATTACK_POWER · 101 MOD_RESISTANCE_PCT · 110 MOD_POWER_REGEN_PERCENT · 118 MOD_HEALING_PCT · 133 MOD_INCREASE_HEALTH_PERCENT · 135 MOD_HEALING_DONE · 136 MOD_HEALING_DONE_PERCENT · 137 MOD_TOTAL_STAT_PERCENTAGE · 138 MOD_MELEE_HASTE · 156 MOD_REPUTATION_GAIN · 166 MOD_ATTACK_POWER_PCT · 178 MOD_DEBUFF_RESISTANCE · 192 MOD_MELEE_RANGED_HASTE · 200 MOD_XP_PCT · 235 MOD_DISPEL_RESIST · 280 MOD_ARMOR_PENETRATION_PCT · 281 MOD_HONOR_GAIN_PCT · 290 MOD_CRIT_PCT
