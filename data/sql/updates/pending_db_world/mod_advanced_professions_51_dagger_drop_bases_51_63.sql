-- Основы добычи кинжалов подземелий полосы 51-63
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом; книги копий со случайным суффиксом делят его поровну.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(12531, 180253, 'Broken Searing Needle'),
(17710, 180254, 'Broken Charstone Dirk'),
(17780, 180255, 'Broken Blade of Eternal Darkness'),
(11635, 180256, 'Broken Hookfang Shanker'),
(12791, 180257, 'Broken Barman Shanker'),
(22266, 180258, 'Broken Flarethorn'),
(11922, 180259, 'Broken Blood-etched Blade'),
(12582, 180260, 'Broken Keris of Zul''Serak'),
(13218, 180261, 'Broken Fang of the Crystal Spider'),
(14024, 180262, 'Broken Frightalon'),
(13368, 180263, 'Broken Bonescraper'),
(13964, 180264, 'Broken Witchblade'),
(18372, 180265, 'Broken Blade of the New Moon'),
(18392, 180266, 'Broken Distracting Dagger'),
(18758, 180267, 'Broken Specter''s Blade'),
(13360, 180268, 'Broken Gift of the Elven Magi'),
(12590, 180269, 'Broken Felstriker'),
(12709, 180270, 'Broken Finkle''s Skinner'),
(10828, 180271, 'Broken Dire Nail');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(180253, 191284, 1, 'Recipe: Searing Needle'),
(180254, 191285, 1, 'Recipe: Charstone Dirk'),
(180255, 191286, 1, 'Recipe: Blade of Eternal Darkness'),
(180256, 191287, 1, 'Recipe: Hookfang Shanker'),
(180257, 191288, 1, 'Recipe: Barman Shanker'),
(180258, 191289, 1, 'Recipe: Flarethorn'),
(180259, 191290, 1, 'Recipe: Blood-etched Blade'),
(180260, 191291, 1, 'Recipe: Keris of Zul''Serak'),
(180261, 191292, 1, 'Recipe: Fang of the Crystal Spider'),
(180262, 191293, 1, 'Recipe: Frightalon'),
(180263, 191294, 1, 'Recipe: Bonescraper'),
(180264, 191295, 1, 'Recipe: Witchblade'),
(180265, 191296, 1, 'Recipe: Blade of the New Moon'),
(180266, 191297, 1, 'Recipe: Distracting Dagger'),
(180267, 191298, 1, 'Recipe: Specter''s Blade'),
(180268, 191299, 1, 'Recipe: Gift of the Elven Magi'),
(180269, 191300, 1, 'Recipe: Felstriker'),
(180270, 191301, 1, 'Recipe: Finkle''s Skinner'),
(180271, 191302, 6, 'Recipe: Dire Nail of Agility'),
(180271, 191303, 6, 'Recipe: Dire Nail of Strength'),
(180271, 191304, 6, 'Recipe: Dire Nail of Stamina'),
(180271, 191305, 6, 'Recipe: Dire Nail of the Monkey'),
(180271, 191306, 6, 'Recipe: Dire Nail of the Tiger'),
(180271, 191307, 6, 'Recipe: Dire Nail of the Bear');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191284, 191285, 191286, 191287, 191288, 191289, 191290, 191291, 191292, 191293, 191294, 191295, 191296, 191297, 191298, 191299, 191300, 191301, 191302, 191303, 191304, 191305, 191306, 191307);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191284, 191285, 191286, 191287, 191288, 191289, 191290, 191291, 191292, 191293, 191294, 191295, 191296, 191297, 191298, 191299, 191300, 191301, 191302, 191303, 191304, 191305, 191306, 191307);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, b.`book`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) / b.`n`,
       0, o.`LootMode`, 20, 1, 1, b.`book_comment`
FROM `reference_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_drop_book` b ON b.`broken` = o.`Item`
WHERE o.`Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_drop_book`;
DROP TEMPORARY TABLE `ap_tmp_drop_base`;

-- Основа добычи предмета кузнечного дела с чертежом от босса: сломанная основа - отдельной строкой
-- с шансом чертежа, книга эскиза - группа 20 с тем же шансом.
DELETE FROM `creature_loot_template` WHERE `Item` IN (180278, 191308);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, x.`Item`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, x.`GroupId`, 1, 1, x.`Comment`
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN (SELECT 180278 AS `Item`, 0 AS `GroupId`, 'Broken Heartseeker' AS `Comment`
      UNION ALL SELECT 191308, 20, 'Recipe: Heartseeker') x
WHERE o.`Item` = 12839 AND o.`Reference` = 0;
