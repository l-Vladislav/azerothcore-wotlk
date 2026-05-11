# Spells — types, attributes, gotchas

## Enchant types (`spellitemenchantment_dbc.Effect_1`)

| | Name | Use |
|--|------|-----|
| 1 | COMBAT_SPELL | Weapon proc — needs `spell_enchant_proc_data` row |
| 3 | EQUIP_SPELL | Cast on equip, removed on unequip |
| 5 | STAT | Direct stat mod (EffectArg = mod id: 5=Int, 6=Spirit, …) |
| 7 | USE_SPELL | Right-click item to activate |

## Spell Attributes (`spell_dbc.Attributes`)

| Bit | Value | Name | Effect |
|-----|-------|------|--------|
| 6 | 64 | PASSIVE | Auto-applies, infinite duration |
| 7 | 128 | HIDDEN_CLIENTSIDE | No buff icon |
| 16 | 65536 | NOT_SHAPESHIFT | Castable in any form |

**Common values:**
- `0` — normal active (has duration, shows icon)
- `64` — passive visible
- `192` — passive silent (no icon) — like vanilla +6 Resist
- `65536` — normal active, shapeshift-safe (like Mage Armor)
- `2147549184` — legacy flag mix; effectively like 65536 + duration

## DurationIndex cheatsheet

| Index | Duration | Reference spell |
|-------|----------|-----------------|
| 0 | **NONE — aura vanishes instantly. Do NOT use for auras.** | — |
| 9 | 5 min | USE_SPELL buffs |
| 21 | **permanent / infinite** — correct for EQUIP_SPELL passive auras | many item buffs |
| 29 | 12s | Shield Wall (871) |
| 30 | 30min | Mage Armor (6117) |
| 64 | 40s | Bloodlust (2825) |

> **CRITICAL — aura persistence requires BOTH:**
> - `DurationIndex = 21` (EQUIP_SPELL) or `9` (USE_SPELL) — **never 0**
> - `ProcChance = 101` — required even for non-proc auras, or aura is discarded
>
> Symptom of wrong values: spell casts successfully, no buff icon, no effect.
> This bit Blood Pact / Frost Armor / Immolate / Water Breathing / Thorns
> because the pool4_T*_base.sql INSERT column list omitted both fields,
> defaulting them to 0. Fix in-place with
> `UPDATE spell_dbc SET DurationIndex=21, ProcChance=101 WHERE ID=...;`
> then restart worldserver.

## Cooldown fields (`spell_dbc`)

USE_SPELL buffs need an explicit cooldown or players can spam-click.
Default value is 0 (no cooldown) — always set one for activatables.

| Column | Unit | Purpose |
|--------|------|---------|
| `RecoveryTime` | ms | **Per-spell cooldown. Use this for USE_SPELL.** |
| `CategoryRecoveryTime` | ms | Shared cooldown across a category (trinkets, healthstones) |
| `Category` | id | Category group — only needed when sharing cooldown |
| `StartRecoveryTime` | ms | GCD trigger — leave at 0 for item procs |
| `StartRecoveryCategory` | id | GCD category — leave at 0 |

Common cooldowns: `60000` = 1 min, `180000` = 3 min, `300000` = 5 min,
`600000` = 10 min. Include `RecoveryTime` in `spell_dbc` INSERT column lists
for any USE_SPELL — defaulting to 0 means players can re-click instantly.

## EffectRadiusIndex (for AoE / area auras)

| Index | Radius | Reference |
|-------|--------|-----------|
| 10 | 20 yd | Imp Blood Pact (6307) |
| 13 | 10 yd | — |
| 23 | 40 yd | Paladin auras (465) |
| 27 | 100 yd | raid-wide |

## Aura types (`EffectAura_1`) commonly used

Verified against `src/server/game/Spells/Auras/SpellAuraDefines.h`.

| | Name | MiscValue meaning |
|--|------|-------------------|
| 8 | PERIODIC_HEAL | — |
| 13 | MOD_DAMAGE_DONE | School mask (2=Holy, 4=Fire, 8=Nature, 16=Frost, 32=Shadow, 64=Arcane, 126=all magic) |
| 15 | DAMAGE_SHIELD (Thorns / Immolate retribution) | — |
| 22 | MOD_RESISTANCE | School mask (1=armor/physical, 2=holy, 4=fire, 8=nature, 16=frost, 32=shadow, 64=arcane) |
| 29 | MOD_STAT | Stat index (0=Str, 1=Agi, 2=Sta, 3=Int, 4=Spi, -1=all) |
| **34** | **MOD_INCREASE_HEALTH** (flat HP — Blood Pact) | — |
| 82 | MOD_WATER_BREATHING | — |
| 105 | FEATHER_FALL (slow fall) | — |

> **WARNING:** Aura **230** is `SPELL_AURA_230` (unused / no-op in AzerothCore).
> Do NOT use it. Flat max-HP bonus is aura **34**, not 230. 250 is `MOD_INCREASE_HEALTH_2`.
> Always verify IDs from `SpellAuraDefines.h` before writing SQL.

## Gotchas

- **Always include `DurationIndex` and `ProcChance` in `spell_dbc` INSERT column lists.** Omitting them defaults to 0, which silently breaks the aura. See the DurationIndex cheatsheet above.
- **Effect_1 = 6 (APPLY_AURA) + self target (ImplicitTargetA_1=1)** is the safe default for EQUIP_SPELL passive auras. `SPELL_EFFECT_APPLY_AREA_AURA_PARTY` (35) is more complex and often fails to show an icon to the caster in this module's context — prefer self-only unless you specifically need party spread.
- **Druid spells (467 Thorns, etc.)** have 10-min duration. Don't use directly as EQUIP_SPELL — expires while equipped. Clone as passive (`Attributes=192`).
- **`EffectMiscValue` for MOD_RESISTANCE**: `1` = physical/armor, not a number index — same bitmask as other schools.
- **PASSIVE + DurationIndex** — server treats as infinite; client may still show countdown if its DBC says otherwise.
- **Visible passive (Attr=64) buff icon requires client DBC entry** for the spell ID. Without MPQ patch, effect applies but no icon.
- **Type 7 USE_SPELL** needs client to know the spell for item right-click to show cooldown bar.
