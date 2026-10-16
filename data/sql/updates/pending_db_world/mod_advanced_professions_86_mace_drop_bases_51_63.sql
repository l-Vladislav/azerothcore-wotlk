-- Основы добычи булав подземелий полосы 51-63
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом. Доля в группе с равными шансами записывается явным шансом.
-- Поправки статов и уровня именных предметов - решения владельца.
UPDATE `item_template` SET `stat_value2` = 6 WHERE `entry` = 10838 AND `stat_type2` = 6;
UPDATE `item_template` SET `stat_value1` = 6 WHERE `entry` = 11805 AND `stat_type1` = 4;
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(17943, 180587, 'Broken Fist of Stone'),
(10838, 180588, 'Broken Might of Hakkar'),
(11805, 180589, 'Broken Rubidium Hammer'),
(11923, 180590, 'Broken Hammer of Grace'),
(18044, 180591, 'Broken Hurley''s Tankard'),
(18321, 180592, 'Broken Energetic Rod'),
(11684, 180593, 'Broken Ironfoe'),
(13183, 180594, 'Broken Venomspitter'),
(13204, 180595, 'Broken Bashguuder'),
(18048, 180596, 'Broken Mastersmith''s Hammer'),
(13401, 180597, 'Broken Cruel Hand of Timmy'),
(18683, 180598, 'Broken Hammer of the Vesper'),
(22315, 180599, 'Broken Hammer of Revitalization'),
(22322, 180600, 'Broken Jaw Breaker'),
(14487, 180601, 'Broken Bonechill Hammer'),
(18376, 180602, 'Broken Timeworn Mace'),
(13349, 180603, 'Broken Scepter of the Unholy');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(180587, 191675, 1, 'Recipe: Fist of Stone'),
(180588, 191676, 1, 'Recipe: Might of Hakkar'),
(180589, 191677, 1, 'Recipe: Rubidium Hammer'),
(180590, 191678, 1, 'Recipe: The Hammer of Grace'),
(180591, 191679, 1, 'Recipe: Hurley''s Tankard'),
(180592, 191680, 1, 'Recipe: Energetic Rod'),
(180593, 191681, 1, 'Recipe: Ironfoe'),
(180594, 191682, 1, 'Recipe: Venomspitter'),
(180595, 191683, 1, 'Recipe: Bashguuder'),
(180596, 191684, 1, 'Recipe: Mastersmith''s Hammer'),
(180597, 191685, 1, 'Recipe: The Cruel Hand of Timmy'),
(180598, 191686, 1, 'Recipe: Hammer of the Vesper'),
(180599, 191687, 1, 'Recipe: Hammer of Revitalization'),
(180600, 191688, 1, 'Recipe: The Jaw Breaker'),
(180601, 191689, 1, 'Recipe: Bonechill Hammer'),
(180602, 191690, 1, 'Recipe: Timeworn Mace'),
(180603, 191691, 1, 'Recipe: Scepter of the Unholy');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191675, 191676, 191677, 191678, 191679, 191680, 191681, 191682, 191683, 191684, 191685, 191686, 191687, 191688, 191689, 191690, 191691);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191675, 191676, 191677, 191678, 191679, 191680, 191681, 191682, 191683, 191684, 191685, 191686, 191687, 191688, 191689, 191690, 191691);
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
DELETE FROM `gameobject_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191675, 191676, 191677, 191678, 191679, 191680, 191681, 191682, 191683, 191684, 191685, 191686, 191687, 191688, 191689, 191690, 191691);
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
DELETE FROM `item_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191675, 191676, 191677, 191678, 191679, 191680, 191681, 191682, 191683, 191684, 191685, 191686, 191687, 191688, 191689, 191690, 191691);
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
('creature', 10899);

DELETE FROM `creature_loot_template` WHERE `Item` IN (180604, 191692);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, x.`Item`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, x.`GroupId`, 1, 1, x.`Comment`
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_plan_source` p ON p.`tbl` = 'creature' AND p.`Entry` = o.`Entry`
JOIN (SELECT 180604 AS `Item`, 0 AS `GroupId`, 'Broken Masterwork Stormhammer' AS `Comment`
      UNION ALL SELECT 191692, 20, 'Recipe: Masterwork Stormhammer') x
WHERE o.`Item` = 12837 AND o.`Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_plan_source`;
