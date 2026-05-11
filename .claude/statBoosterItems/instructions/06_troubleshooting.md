# Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| No buff icon on equip | `Attributes=192` has HIDDEN bit | Set `Attributes=64` (visible passive) or `65536` (active) |
| No buff icon, effect applies | Spell missing from client MPQ | Add to `Spell_custom.csv`, rebuild MPQ |
| Aura expires after 10-15 min | Pointing at non-passive spell with duration | Clone as passive (`Attributes=192`) or accept refresh-on-reequip |
| Pool cleared after SQL apply | DELETE range too broad | Pool 4 DELETE should be 90001-90090, not 90001-90105 |
| Duplicate rows after tier apply | Old base + tier both INSERT same ID | Clean pool first: `DELETE FROM statbooster_enchant_template WHERE PoolGroup=4` |
| Enchant rolls on wrong slot | MD says one thing, SQL another | Regenerate SQL from MD |
| Addon shows "Enchant #90xxx" | Missing from `EnchantDB.lua` | Add `[90xxx] = "Russian name"` |
| MOD_RESISTANCE gives wrong type | `EffectMiscValue_1` wrong school | 1=armor, 2=holy, 4=fire, 8=nature, 16=frost, 32=shadow, 64=arcane |
| COMBAT_SPELL doesn't proc | Missing `spell_enchant_proc_data` | Add row with `PPMChance` or `customChance` |
| DBC change didn't take effect | DBC cached at server start | `docker compose restart ac-worldserver` |
| Russian item name/description garbled in tooltip (mojibake) | SQL applied with wrong connection charset → double-encoded UTF-8 | Re-apply with `docker exec -i ac-database-v2 mysql --default-character-set=utf8mb4 -uroot -ppassword acore_world < file.sql`, restart worldserver, clear client WDB folder |
| Russian text correct in DB (verified via HEX()) but still garbled in-game | WoW client cached stale bytes in WDB before the fix | Close WoW, delete `WDB/` folder inside the WoW client directory, relaunch |
| `HEX(Name)` shows patterns like `C390E28093...` instead of `D0xx...` | Classic double-encoding: UTF-8 bytes treated as latin1 then re-encoded | Data inserted via latin1 connection; re-insert using utf8mb4 |
