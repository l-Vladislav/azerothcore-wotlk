# Custom Spells Catalog

Live snapshot of every server-side custom spell. For interpretation of columns see [03_spells.md](03_spells.md).

## Pool 4 — Arcane Burst (AoE weapon proc)

| Spell | Enchant | Damage | School |
|-------|---------|--------|--------|
| 100018 | 90075 (T1) | 20-35 Arcane | Arcane |
| 100019 | 90076 (T2) | 45-70 | Arcane |
| 100017 | 90074 (T3) | 80-120 | Arcane |
| 100036 | 90090 (T4) | 130-180 | Arcane |

Enchant type 1 (COMBAT_SPELL), PPM 3, Radius 13 (10yd).

## Pool 4 — Water Breathing (passive utility)

| Spell | Enchant |
|-------|---------|
| 100020 | 90077 |

Aura 82 WATER_BREATHING. Attributes 2147549184, DurationIndex 21 (refreshes on re-equip).

## Pool 4 — Frost Ring (weapon proc)

| Spell | Enchant | Damage |
|-------|---------|--------|
| 100021 | 90078 (T2) | 30-45 Frost |
| 100022 | 90079 (T3) | 55-80 |
| 100023 | 90080 (T4) | 90-130 |

Enchant type 1, PPM 3. Effect is direct damage (`Effect_1=2`), SchoolMask 16 (Frost).

## Pool 4 — Frost Armor (passive armor)

| Spell | Enchant | Effect |
|-------|---------|--------|
| 100024 | 90081 (shield only, T2-T4) | +200 Armor |

Aura 22 MOD_RESISTANCE, Misc 1 (physical/armor).

## Pool 4 — Thorns (passive damage shield)

| Spell | Enchant | Reflect |
|-------|---------|---------|
| 100025 | 90030 (T1) | +3 |
| 100026 | 90031 (T2) | +18 |
| 100027 | 90032 (T3-T4) | +25 |

Aura 15 DAMAGE_SHIELD, SchoolMask 8 (Nature).

## Pool 4 — Immolate (activatable damage shield)

| Spell | Enchant | Reflect | Duration | Cooldown |
|-------|---------|---------|----------|----------|
| 100028 | 90082 (T1) | +5 Fire | 30s | 3min |
| 100029 | 90083 (T2) | +12 | 30s | 3min |
| 100030 | 90084 (T3) | +20 | 30s | 3min |
| 100031 | 90085 (T4) | +30 | 30s | 3min |

Enchant type 7 (USE_SPELL). Attributes 65536, DurationIndex 9 (30s), RecoveryTime 180000 (3min).

## Pool 4 — Blood Pact (area aura +max HP)

| Spell | Enchant | Bonus HP |
|-------|---------|----------|
| 100032 | 90086 (T1) | +20 |
| 100033 | 90087 (T2) | +70 |
| 100034 | 90088 (T3) | +270 |
| 100035 | 90089 (T4) | +380 |

`Effect_1=65` (APPLY_AREA_AURA_RAID), Aura 230 MOD_MAX_HEALTH flat, Radius 23 (40yd), SchoolMask 32 (Shadow).

## Pool 3 — School Spell Damage (passive caster bonus)

24 spells: 6 schools × 4 tiers. Attributes 192 (passive silent), DurationIndex 0.

| Tier | Value | Spell IDs (Fire/Frost/Nature/Shadow/Arcane/Holy) | Enchant IDs |
|------|-------|--------------------------------------------------|-------------|
| T1 | +3 | 100040/041/042/043/044/045 | 90100-90105 |
| T2 | +5 | 100046/047/048/049/050/051 | 90106-90111 |
| T3 | +7 | 100052/053/054/055/056/057 | 90112-90117 |
| T4 | +10 | 100058/059/060/061/062/063 | 90118-90123 |

Aura 13 MOD_DAMAGE_DONE. Misc = school bitmask (4/16/8/32/64/2).

## Known design gaps

- **Frost Armor frost slow proc** — design doc mentions it; not implemented (only +armor).
- **Frost Ring** uses AoE targeting despite "Ring" naming — review if single-target was intended.
