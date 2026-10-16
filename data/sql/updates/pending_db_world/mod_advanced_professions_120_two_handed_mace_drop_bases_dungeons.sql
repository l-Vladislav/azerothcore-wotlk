-- Основы добычи двуручного молота подземелий
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом. Доля в группе с равными шансами записывается явным шансом.
-- Поправки статов и уровня именных предметов - решения владельца.
UPDATE `item_template` SET `stat_value1` = 9 WHERE `entry` = 1976 AND `stat_type1` = 7;
UPDATE `item_template` SET `stat_value1` = 15 WHERE `entry` = 9449 AND `stat_type1` = 4;
UPDATE `item_template` SET `stat_value1` = 15 WHERE `entry` = 7723 AND `stat_type1` = 6;
UPDATE `item_template` SET `stat_value1` = 8 WHERE `entry` = 9413 AND `stat_type1` = 4;
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(3194, 181011, 'Broken Black Malice'),
(7230, 181012, 'Broken Smite''s Mighty Hammer'),
(1976, 181013, 'Broken Slaghammer'),
(9449, 181014, 'Broken Manual Crowd Pummeler'),
(7723, 181015, 'Broken Mograine''s Might'),
(9423, 181016, 'Broken Jackhammer'),
(9413, 181017, 'Broken Rockpounder'),
(17766, 181018, 'Broken Princess Theradras'' Scepter'),
(11803, 181020, 'Broken Force of Magma'),
(11921, 181021, 'Broken Impervious Giant'),
(22208, 181022, 'Broken Lavastone Hammer'),
(14531, 181023, 'Broken Frightskull Shaft'),
(13167, 181024, 'Broken Fist of Omokk'),
(13393, 181025, 'Broken Malown''s Slam'),
(18531, 181026, 'Broken Unyielding Maul'),
(22333, 181027, 'Broken Hammer of Divine Might'),
(12969, 181029, 'Broken Seeping Willow'),
(18717, 181030, 'Broken Hammer of the Grand Crusader');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(181011, 192154, 1, 'Recipe: Black Malice'),
(181012, 192155, 1, 'Recipe: Smite''s Mighty Hammer'),
(181013, 192156, 1, 'Recipe: Slaghammer'),
(181014, 192157, 1, 'Recipe: Manual Crowd Pummeler'),
(181015, 192158, 1, 'Recipe: Mograine''s Might'),
(181016, 192159, 1, 'Recipe: The Jackhammer'),
(181017, 192160, 1, 'Recipe: The Rockpounder'),
(181018, 192161, 1, 'Recipe: Princess Theradras'' Scepter'),
(181020, 192163, 1, 'Recipe: Force of Magma'),
(181021, 192164, 1, 'Recipe: Impervious Giant'),
(181022, 192165, 1, 'Recipe: Lavastone Hammer'),
(181023, 192166, 1, 'Recipe: Frightskull Shaft'),
(181024, 192167, 1, 'Recipe: Fist of Omokk'),
(181025, 192168, 1, 'Recipe: Malown''s Slam'),
(181026, 192169, 1, 'Recipe: Unyielding Maul'),
(181027, 192170, 1, 'Recipe: Hammer of Divine Might'),
(181029, 192172, 1, 'Recipe: Seeping Willow'),
(181030, 192173, 1, 'Recipe: Hammer of the Grand Crusader');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (192154, 192155, 192156, 192157, 192158, 192159, 192160, 192161, 192163, 192164, 192165, 192166, 192167, 192168, 192169, 192170, 192172, 192173);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (192154, 192155, 192156, 192157, 192158, 192159, 192160, 192161, 192163, 192164, 192165, 192166, 192167, 192168, 192169, 192170, 192172, 192173);
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
DELETE FROM `gameobject_loot_template` WHERE `GroupId` = 20 AND `Item` IN (192154, 192155, 192156, 192157, 192158, 192159, 192160, 192161, 192163, 192164, 192165, 192166, 192167, 192168, 192169, 192170, 192172, 192173);
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
DELETE FROM `item_loot_template` WHERE `GroupId` = 20 AND `Item` IN (192154, 192155, 192156, 192157, 192158, 192159, 192160, 192161, 192163, 192164, 192165, 192166, 192167, 192168, 192169, 192170, 192172, 192173);
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
('creature', 9028);

DELETE FROM `creature_loot_template` WHERE `Item` IN (181019, 192162);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, x.`Item`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, x.`GroupId`, 1, 1, x.`Comment`
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_plan_source` p ON p.`tbl` = 'creature' AND p.`Entry` = o.`Entry`
JOIN (SELECT 181019 AS `Item`, 0 AS `GroupId`, 'Broken Dark Iron Pulverizer' AS `Comment`
      UNION ALL SELECT 192162, 20, 'Recipe: Dark Iron Pulverizer') x
WHERE o.`Item` = 11610 AND o.`Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_plan_source`;
-- Чертёж падает со 100 %: книга вне группы, иначе сумма группы 20 превышает 100 %.
UPDATE `creature_loot_template` SET `GroupId` = 0 WHERE `Entry` = 9028 AND `Item` = 192162;
-- Основа добычи предмета кузнечного дела с чертежом от боссов: сломанная основа - отдельной строкой
-- с шансом чертежа, книга эскиза - группа 20 с тем же шансом. Только таблицы боссов.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_plan_source`;
CREATE TEMPORARY TABLE `ap_tmp_plan_source` (`tbl` varchar(16), `Entry` int unsigned);
INSERT INTO `ap_tmp_plan_source` VALUES
('creature', 10438);

DELETE FROM `creature_loot_template` WHERE `Item` IN (181028, 192171);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, x.`Item`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, x.`GroupId`, 1, 1, x.`Comment`
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_plan_source` p ON p.`tbl` = 'creature' AND p.`Entry` = o.`Entry`
JOIN (SELECT 181028 AS `Item`, 0 AS `GroupId`, 'Broken Hammer of the Titans' AS `Comment`
      UNION ALL SELECT 192171, 20, 'Recipe: Hammer of the Titans') x
WHERE o.`Item` = 12833 AND o.`Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_plan_source`;
