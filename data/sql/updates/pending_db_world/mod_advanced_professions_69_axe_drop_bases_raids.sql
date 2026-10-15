-- Основы добычи топоров рейдов
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом; книги копий со случайным суффиксом делят его поровну.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(19921, 180471, 'Broken Zulian Hacker'),
(19852, 180477, 'Broken Ancient Hakkari Manslayer'),
(19362, 180478, 'Broken Doom''s Edge'),
(17068, 180479, 'Broken Deathbringer'),
(19363, 180480, 'Broken Crul''shorukh, Edge of Chaos'),
(22816, 180481, 'Broken Hatchet of Sundered Bone');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(180471, 191526, 6, 'Recipe: Zulian Hacker of Agility'),
(180471, 191527, 6, 'Recipe: Zulian Hacker of Strength'),
(180471, 191528, 6, 'Recipe: Zulian Hacker of Stamina'),
(180471, 191529, 6, 'Recipe: Zulian Hacker of the Monkey'),
(180471, 191530, 6, 'Recipe: Zulian Hacker of the Tiger'),
(180471, 191531, 6, 'Recipe: Zulian Hacker of the Bear'),
(180477, 191532, 1, 'Recipe: Ancient Hakkari Manslayer'),
(180478, 191533, 1, 'Recipe: Doom''s Edge'),
(180479, 191534, 1, 'Recipe: Deathbringer'),
(180480, 191535, 1, 'Recipe: Crul''shorukh, Edge of Chaos'),
(180481, 191536, 1, 'Recipe: Hatchet of Sundered Bone');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191526, 191527, 191528, 191529, 191530, 191531, 191532, 191533, 191534, 191535, 191536);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191526, 191527, 191528, 191529, 191530, 191531, 191532, 191533, 191534, 191535, 191536);
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
