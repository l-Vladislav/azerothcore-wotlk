-- Основы добычи кольчуги Бронника 1-35 (подземелья, #281)
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом. Доля в группе с равными шансами записывается явным шансом.
UPDATE `item_template` SET `stat_value1` = 16 WHERE `entry` = 7688 AND `stat_type1` = 7 AND `stat_value1` = 17;
UPDATE `item_template` SET `stat_value2` = 16 WHERE `entry` = 7688 AND `stat_type2` = 7 AND `stat_value2` = 17;
UPDATE `item_template` SET `stat_value3` = 16 WHERE `entry` = 7688 AND `stat_type3` = 7 AND `stat_value3` = 17;
UPDATE `item_template` SET `stat_value4` = 16 WHERE `entry` = 7688 AND `stat_type4` = 7 AND `stat_value4` = 17;
UPDATE `item_template` SET `stat_value5` = 16 WHERE `entry` = 7688 AND `stat_type5` = 7 AND `stat_value5` = 17;
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(1488, 181989, 'Broken Avenger''s Armor'),
(3228, 181990, 'Broken Jimmied Handcuffs'),
(3416, 181991, 'Broken Martyr''s Chain'),
(4438, 181992, 'Broken Pugilist Bracers'),
(6460, 181993, 'Broken Cobrahn''s Grasp'),
(6627, 181994, 'Broken Mutant Scale Breastplate'),
(6642, 181995, 'Broken Phantom Armor'),
(6906, 181996, 'Broken Algae Fists'),
(6907, 181997, 'Broken Tortoise Armor'),
(7688, 181998, 'Broken Ironspine''s Ribcage'),
(9445, 181999, 'Broken Grubbis Paws'),
(23170, 182000, 'Broken The Frozen Clutch');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(181989, 193190, 1, 'Recipe: Avenger''s Armor'),
(181990, 193191, 1, 'Recipe: Jimmied Handcuffs'),
(181991, 193192, 1, 'Recipe: Martyr''s Chain'),
(181992, 193193, 1, 'Recipe: Pugilist Bracers'),
(181993, 193194, 1, 'Recipe: Cobrahn''s Grasp'),
(181994, 193195, 1, 'Recipe: Mutant Scale Breastplate'),
(181995, 193196, 1, 'Recipe: Phantom Armor'),
(181996, 193197, 1, 'Recipe: Algae Fists'),
(181997, 193198, 1, 'Recipe: Tortoise Armor'),
(181998, 193199, 1, 'Recipe: Ironspine''s Ribcage'),
(181999, 193200, 1, 'Recipe: Grubbis Paws'),
(182000, 193201, 1, 'Recipe: The Frozen Clutch');
UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (193190, 193191, 193192, 193193, 193194, 193195, 193196, 193197, 193198, 193199, 193200, 193201);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (193190, 193191, 193192, 193193, 193194, 193195, 193196, 193197, 193198, 193199, 193200, 193201);
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
DELETE FROM `gameobject_loot_template` WHERE `GroupId` = 20 AND `Item` IN (193190, 193191, 193192, 193193, 193194, 193195, 193196, 193197, 193198, 193199, 193200, 193201);
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
DELETE FROM `item_loot_template` WHERE `GroupId` = 20 AND `Item` IN (193190, 193191, 193192, 193193, 193194, 193195, 193196, 193197, 193198, 193199, 193200, 193201);
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
