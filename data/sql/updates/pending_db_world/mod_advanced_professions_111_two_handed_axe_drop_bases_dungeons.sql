-- Основы добычи двуручного топора подземелий
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом. Доля в группе с равными шансами записывается явным шансом.
-- Поправки статов и уровня именных предметов - решения владельца.
UPDATE `item_template` SET `stat_value1` = 12 WHERE `entry` = 6687 AND `stat_type1` = 4;
UPDATE `item_template` SET `stat_value2` = 8 WHERE `entry` = 9459 AND `stat_type2` = 7;
UPDATE `item_template` SET `stat_value2` = 8 WHERE `entry` = 9383 AND `stat_type2` = 4;
UPDATE `item_template` SET `stat_value1` = 20 WHERE `entry` = 9481 AND `stat_type1` = 7;
UPDATE `item_template` SET `stat_value2` = 4 WHERE `entry` = 9481 AND `stat_type2` = 6;
UPDATE `item_template` SET `stat_value2` = 12 WHERE `entry` = 11816 AND `stat_type2` = 7;
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(1318, 180882, 'Broken Night Reaver'),
(5194, 180883, 'Broken Taskmaster Axe'),
(23171, 180884, 'Broken Axe of Severing'),
(6687, 180885, 'Broken Corpsemaker'),
(9459, 180886, 'Broken Thermaplugg''s Left Arm'),
(10570, 180887, 'Broken Manslayer'),
(9383, 180888, 'Broken Obsidian Cleaver'),
(7717, 180889, 'Broken Ravager'),
(9425, 180890, 'Broken Pendulum of Doom'),
(9481, 180891, 'Broken Minotaur'),
(17730, 180892, 'Broken Gatorbite Axe'),
(11816, 180893, 'Broken Angerforge''s Battle Axe'),
(13285, 180894, 'Broken Blackrock Slicer'),
(18324, 180895, 'Broken Waveslicer'),
(11931, 180896, 'Broken Dreadforge Retaliator'),
(13983, 180897, 'Broken Gravestone War Axe'),
(18759, 180898, 'Broken Malicious Axe'),
(18538, 180900, 'Broken Treant''s Bane');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(180882, 192013, 1, 'Recipe: Night Reaver'),
(180883, 192014, 1, 'Recipe: Taskmaster Axe'),
(180884, 192015, 1, 'Recipe: The Axe of Severing'),
(180885, 192016, 1, 'Recipe: Corpsemaker'),
(180886, 192017, 1, 'Recipe: Thermaplugg''s Left Arm'),
(180887, 192018, 1, 'Recipe: Manslayer'),
(180888, 192019, 1, 'Recipe: Obsidian Cleaver'),
(180889, 192020, 1, 'Recipe: Ravager'),
(180890, 192021, 1, 'Recipe: Pendulum of Doom'),
(180891, 192022, 1, 'Recipe: The Minotaur'),
(180892, 192023, 1, 'Recipe: Gatorbite Axe'),
(180893, 192024, 1, 'Recipe: Angerforge''s Battle Axe'),
(180894, 192025, 1, 'Recipe: The Blackrock Slicer'),
(180895, 192026, 1, 'Recipe: Waveslicer'),
(180896, 192027, 1, 'Recipe: Dreadforge Retaliator'),
(180897, 192028, 1, 'Recipe: Gravestone War Axe'),
(180898, 192029, 1, 'Recipe: Malicious Axe'),
(180900, 192031, 1, 'Recipe: Treant''s Bane');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (192013, 192014, 192015, 192016, 192017, 192018, 192019, 192020, 192021, 192022, 192023, 192024, 192025, 192026, 192027, 192028, 192029, 192031);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, b.`book`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) / b.`n`,
       0, o.`LootMode`, 20, 1, 1, b.`book_comment`
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_drop_book` b ON b.`broken` = o.`Item`
WHERE o.`Reference` = 0;

UPDATE `reference_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (192013, 192014, 192015, 192016, 192017, 192018, 192019, 192020, 192021, 192022, 192023, 192024, 192025, 192026, 192027, 192028, 192029, 192031);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, b.`book`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) / b.`n`,
       0, o.`LootMode`, 20, 1, 1, b.`book_comment`
FROM `reference_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_drop_book` b ON b.`broken` = o.`Item`
WHERE o.`Reference` = 0;

UPDATE `gameobject_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `gameobject_loot_template` WHERE `GroupId` = 20 AND `Item` IN (192013, 192014, 192015, 192016, 192017, 192018, 192019, 192020, 192021, 192022, 192023, 192024, 192025, 192026, 192027, 192028, 192029, 192031);
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, b.`book`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) / b.`n`,
       0, o.`LootMode`, 20, 1, 1, b.`book_comment`
FROM `gameobject_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_drop_book` b ON b.`broken` = o.`Item`
WHERE o.`Reference` = 0;

UPDATE `item_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `item_loot_template` WHERE `GroupId` = 20 AND `Item` IN (192013, 192014, 192015, 192016, 192017, 192018, 192019, 192020, 192021, 192022, 192023, 192024, 192025, 192026, 192027, 192028, 192029, 192031);
INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, b.`book`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) / b.`n`,
       0, o.`LootMode`, 20, 1, 1, b.`book_comment`
FROM `item_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_drop_book` b ON b.`broken` = o.`Item`
WHERE o.`Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_drop_book`;
DROP TEMPORARY TABLE `ap_tmp_drop_base`;

-- Основа добычи предмета кузнечного дела с чертежом от боссов: сломанная основа - отдельной строкой
-- с шансом чертежа, книга эскиза - группа 20 с тем же шансом. Только таблицы боссов.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_plan_source`;
CREATE TEMPORARY TABLE `ap_tmp_plan_source` (`tbl` varchar(16), `Entry` int unsigned);
INSERT INTO `ap_tmp_plan_source` VALUES
('creature', 9596);

DELETE FROM `creature_loot_template` WHERE `Item` IN (180899, 192030);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, x.`Item`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, x.`GroupId`, 1, 1, x.`Comment`
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_plan_source` p ON p.`tbl` = 'creature' AND p.`Entry` = o.`Entry`
JOIN (SELECT 180899 AS `Item`, 0 AS `GroupId`, 'Broken Arcanite Reaper' AS `Comment`
      UNION ALL SELECT 192030, 20, 'Recipe: Arcanite Reaper') x
WHERE o.`Item` = 12838 AND o.`Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_plan_source`;
