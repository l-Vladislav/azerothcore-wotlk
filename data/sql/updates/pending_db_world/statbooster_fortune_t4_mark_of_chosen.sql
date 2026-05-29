-- StatBooster — Fortune T4 trinket proc: Mark of the Chosen
-- Enchant ID 90138, triggers vanilla spell 21969 (Mark of the Chosen)
-- 2% chance when struck in combat → +25 to all stats for 1 minute
-- Source: .claude/statBoosterItems/pools/fortune_pool/fortune_T4.md (Trinket section)

-- 1) Mirror the DBC custom row server-side
DELETE FROM `spellitemenchantment_dbc` WHERE `ID` = 90138;
INSERT INTO `spellitemenchantment_dbc`
  (`ID`, `Charges`, `Effect_1`, `EffectPointsMin_1`, `EffectPointsMax_1`, `EffectArg_1`, `Name_Lang_zhTW`, `Name_Lang_Mask`)
VALUES
  (90138, 0, 3, 0, 0, 21969, '##SB##Удача: Знак избранного', 16712190);

-- 2) Register in StatBooster's pool template
-- Fortune (PoolGroup=4), T4 iLvl 66-92, Trinket slot only (ItemTypeMask=4096)
-- RoleMask=0 — T4 Fortune ignores RoleMask, used by all classes (per fortune_T4.md note)
DELETE FROM `statbooster_enchant_template` WHERE `Id` = 90138;
INSERT INTO `statbooster_enchant_template`
  (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `PoolGroup`, `Description`, `Note`)
VALUES
  (90138, 66, 92, 0, 0, 0, 4096, 4, '+25 to all stats for 1 min, 2% on struck', 'Fortune T4 trinket proc');
