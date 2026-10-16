-- Исправления анализа Оружейника.
-- Именные предметы поднимаются до ilvl своей основы, урон - по росту DPS основ типа.
UPDATE `item_template` SET `ItemLevel` = 25, `RequiredLevel` = 20, `dmg_min1` = 14, `dmg_max1` = 28 WHERE `entry` = 2035;
UPDATE `item_template` SET `ItemLevel` = 25, `RequiredLevel` = 20, `dmg_min1` = 14, `dmg_max1` = 27 WHERE `entry` = 5192;
UPDATE `item_template` SET `ItemLevel` = 55, `RequiredLevel` = 50, `dmg_min1` = 102, `dmg_max1` = 154 WHERE `entry` = 12769;

-- Эскиз «Разрушителя преисподней» (24044) снят: предмет TBC возвращается в общую таблицу 12003.
UPDATE `reference_loot_template` SET `Item` = 24044, `Reference` = 0, `Comment` = 'Hellreaver'
WHERE `Entry` = 12003 AND `Item` = 1917290;
DELETE FROM `reference_loot_template` WHERE `Entry` = 1917290;
