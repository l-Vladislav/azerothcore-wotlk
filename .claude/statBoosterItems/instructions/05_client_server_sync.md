# Client ↔ Server Sync

Two DBC layers. Must match.

- **Server DB** (`spell_dbc`, `spellitemenchantment_dbc`) — runtime behavior (auras, procs, cooldowns).
- **Client MPQ** (`Spell_custom.csv`, `SpellItemEnchantment_custom.csv`) — UI rendering (icons, tooltips, timers).

## Symptoms of mismatch

| Symptom | Cause |
|---------|-------|
| Aura applies, no icon | Spell ID not in client MPQ, or HIDDEN_CLIENTSIDE bit set |
| Icon shows, no effect | Spell not in server `spell_dbc`, or server hasn't restarted |
| Wrong tooltip/timer | Client CSV field disagrees with server |
| No cooldown on "Use" item | Client CSV `RecoveryTime` = 0 while server has a value |

## Fields that MUST match

`Attributes`, `DurationIndex`, `RecoveryTime`, `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectMiscValue_1`, `EffectRadiusIndex_1`, `SchoolMask`, `SpellIconID`, `SpellVisualID_1`.

Names/descriptions can differ between layers (server internal vs client display).

## `##SB##` prefix

Russian names in client CSV use `##SB##` prefix (`##SB##Удача: …`, `##SB##Тайный: …`) to mark StatBooster-owned entries for tooling. Server uses plain English names.

## Sync procedure

After UPDATE on server `spell_dbc`:
1. Update matching row in `Spell_custom.csv`.
2. Rebuild MPQ, deploy.
3. Restart worldserver (DBC cached at startup).

Skipping any step → client disagrees with server.
