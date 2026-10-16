-- Основы добычи булав рейдов
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом. Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(19908, 180605, 'Broken Sceptre of Smiting'),
(19890, 180606, 'Broken Jin''do''s Hexxer'),
(19961, 180607, 'Broken Gri''lek''s Grinder'),
(22713, 180608, 'Broken Zulian Scepter of Rites'),
(17105, 180609, 'Broken Aurastone Hammer'),
(21466, 180610, 'Broken Stinger of Ayamiss'),
(21837, 180611, 'Broken Anubisath Warhammer'),
(21715, 180612, 'Broken Sand Polished Hammer'),
(19335, 180613, 'Broken Spineshatter'),
(19360, 180614, 'Broken Lok''amir il Romathis'),
(22942, 180615, 'Broken Widow''s Embrace'),
(22808, 180616, 'Broken Castigator'),
(22988, 180617, 'Broken End of Dreams'),
(23221, 180618, 'Broken Misplaced Servo Arm'),
(21839, 180619, 'Broken Scepter of the False Prophet'),
(23056, 180620, 'Broken Hammer of the Twisting Nether');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(180605, 191693, 1, 'Recipe: Sceptre of Smiting'),
(180606, 191694, 1, 'Recipe: Jin''do''s Hexxer'),
(180607, 191695, 1, 'Recipe: Gri''lek''s Grinder'),
(180608, 191696, 1, 'Recipe: Zulian Scepter of Rites'),
(180609, 191697, 1, 'Recipe: Aurastone Hammer'),
(180610, 191698, 1, 'Recipe: Stinger of Ayamiss'),
(180611, 191699, 1, 'Recipe: Anubisath Warhammer'),
(180612, 191700, 1, 'Recipe: Sand Polished Hammer'),
(180613, 191701, 1, 'Recipe: Spineshatter'),
(180614, 191702, 1, 'Recipe: Lok''amir il Romathis'),
(180615, 191703, 1, 'Recipe: The Widow''s Embrace'),
(180616, 191704, 1, 'Recipe: The Castigator'),
(180617, 191705, 1, 'Recipe: The End of Dreams'),
(180618, 191706, 1, 'Recipe: Misplaced Servo Arm'),
(180619, 191707, 1, 'Recipe: Scepter of the False Prophet'),
(180620, 191708, 1, 'Recipe: Hammer of the Twisting Nether');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191693, 191694, 191695, 191696, 191697, 191698, 191699, 191700, 191701, 191702, 191703, 191704, 191705, 191706, 191707, 191708);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191693, 191694, 191695, 191696, 191697, 191698, 191699, 191700, 191701, 191702, 191703, 191704, 191705, 191706, 191707, 191708);
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
DELETE FROM `gameobject_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191693, 191694, 191695, 191696, 191697, 191698, 191699, 191700, 191701, 191702, 191703, 191704, 191705, 191706, 191707, 191708);
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
DELETE FROM `item_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191693, 191694, 191695, 191696, 191697, 191698, 191699, 191700, 191701, 191702, 191703, 191704, 191705, 191706, 191707, 191708);
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
('reference', 30171), ('reference', 34002), ('reference', 301710), ('creature', 12397);

DELETE FROM `creature_loot_template` WHERE `Item` IN (180621, 191709);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, x.`Item`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, x.`GroupId`, 1, 1, x.`Comment`
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_plan_source` p ON p.`tbl` = 'creature' AND p.`Entry` = o.`Entry`
JOIN (SELECT 180621 AS `Item`, 0 AS `GroupId`, 'Broken Persuader' AS `Comment`
      UNION ALL SELECT 191709, 20, 'Recipe: Persuader') x
WHERE o.`Item` = 22390 AND o.`Reference` = 0;

DELETE FROM `reference_loot_template` WHERE `Item` IN (180621, 191709);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, x.`Item`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, x.`GroupId`, 1, 1, x.`Comment`
FROM `reference_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_plan_source` p ON p.`tbl` = 'reference' AND p.`Entry` = o.`Entry`
JOIN (SELECT 180621 AS `Item`, 0 AS `GroupId`, 'Broken Persuader' AS `Comment`
      UNION ALL SELECT 191709, 20, 'Recipe: Persuader') x
WHERE o.`Item` = 22390 AND o.`Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_plan_source`;
