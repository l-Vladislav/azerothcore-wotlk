-- Основы добычи двуручного меча подземелий
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом. Доля в группе с равными шансами записывается явным шансом.
-- Поправки статов и уровня именных предметов - решения владельца.
UPDATE `item_template` SET `stat_value3` = 9 WHERE `entry` = 3417 AND `stat_type3` = 4;
UPDATE `item_template` SET `stat_value1` = 6 WHERE `entry` = 3417 AND `stat_type1` = 6;
UPDATE `item_template` SET `stat_value1` = 13 WHERE `entry` = 1975 AND `stat_type1` = 6;
UPDATE `item_template` SET `stat_value1` = 14 WHERE `entry` = 9490 AND `stat_type1` = 4;
UPDATE `item_template` SET `stat_value1` = 12 WHERE `entry` = 7689 AND `stat_type1` = 7;
UPDATE `item_template` SET `stat_value2` = 8 WHERE `entry` = 7689 AND `stat_type2` = 4;
UPDATE `item_template` SET `stat_value1` = 8 WHERE `entry` = 10573 AND `stat_type1` = 7;
UPDATE `item_template` SET `stat_value3` = 5 WHERE `entry` = 10573 AND `stat_type3` = 3;
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(2205, 180742, 'Broken Duskbringer'),
(3417, 180743, 'Broken Onyx Claymore'),
(1975, 180744, 'Broken Pysan''s Old Greatsword'),
(9490, 180745, 'Broken Gizmotron Megachopper'),
(6909, 180746, 'Broken Strike of the Hydra'),
(7689, 180747, 'Broken Morbid Dawn'),
(10573, 180748, 'Broken Boneslasher'),
(10758, 180749, 'Broken X''caliboar'),
(9418, 180750, 'Broken Stoneslayer'),
(12463, 180751, 'Broken Drakefang Butcher'),
(11786, 180752, 'Broken Stone of the Earth'),
(14541, 180753, 'Broken Barovian Family Sword'),
(13163, 180754, 'Broken Relentless Scythe'),
(12592, 180755, 'Broken Blackblade of Shahram'),
(13348, 180756, 'Broken Demonshear'),
(13505, 180757, 'Broken Runeblade of Baron Rivendare'),
(18520, 180758, 'Broken Barbarous Blade');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(180742, 191855, 1, 'Recipe: Duskbringer'),
(180743, 191856, 1, 'Recipe: Onyx Claymore'),
(180744, 191857, 1, 'Recipe: Pysan''s Old Greatsword'),
(180745, 191858, 1, 'Recipe: Gizmotron Megachopper'),
(180746, 191859, 1, 'Recipe: Strike of the Hydra'),
(180747, 191860, 1, 'Recipe: Morbid Dawn'),
(180748, 191861, 1, 'Recipe: Boneslasher'),
(180749, 191862, 1, 'Recipe: X''caliboar'),
(180750, 191863, 1, 'Recipe: Stoneslayer'),
(180751, 191864, 1, 'Recipe: Drakefang Butcher'),
(180752, 191865, 1, 'Recipe: Stone of the Earth'),
(180753, 191866, 1, 'Recipe: Barovian Family Sword'),
(180754, 191867, 1, 'Recipe: Relentless Scythe'),
(180755, 191868, 1, 'Recipe: Blackblade of Shahram'),
(180756, 191869, 1, 'Recipe: Demonshear'),
(180757, 191870, 1, 'Recipe: Runeblade of Baron Rivendare'),
(180758, 191871, 1, 'Recipe: Barbarous Blade');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191855, 191856, 191857, 191858, 191859, 191860, 191861, 191862, 191863, 191864, 191865, 191866, 191867, 191868, 191869, 191870, 191871);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191855, 191856, 191857, 191858, 191859, 191860, 191861, 191862, 191863, 191864, 191865, 191866, 191867, 191868, 191869, 191870, 191871);
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
DELETE FROM `gameobject_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191855, 191856, 191857, 191858, 191859, 191860, 191861, 191862, 191863, 191864, 191865, 191866, 191867, 191868, 191869, 191870, 191871);
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
DELETE FROM `item_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191855, 191856, 191857, 191858, 191859, 191860, 191861, 191862, 191863, 191864, 191865, 191866, 191867, 191868, 191869, 191870, 191871);
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
