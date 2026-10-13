-- Основы добычи кинжалов подземелий полосы 21-35
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом; книги копий со случайным суффиксом делят его поровну.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(3413, 180237, 'Broken Doomspike'),
(2941, 180238, 'Broken Prison Shank'),
(6904, 180239, 'Broken Bite of Serra''kis'),
(6220, 180240, 'Broken Meteor Shard'),
(776, 180241, 'Broken Vendetta'),
(9453, 180242, 'Broken Toxic Revenger'),
(7682, 180243, 'Broken Torturing Poker'),
(6691, 180244, 'Broken Swinetusk Shank'),
(23168, 180245, 'Broken Scorn''s Focal Dagger');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(180237, 191268, 1, 'Recipe: Doomspike'),
(180238, 191269, 1, 'Recipe: Prison Shank'),
(180239, 191270, 1, 'Recipe: Bite of Serra''kis'),
(180240, 191271, 1, 'Recipe: Meteor Shard'),
(180241, 191272, 1, 'Recipe: Vendetta'),
(180242, 191273, 1, 'Recipe: Toxic Revenger'),
(180243, 191274, 1, 'Recipe: Torturing Poker'),
(180244, 191275, 1, 'Recipe: Swinetusk Shank'),
(180245, 191276, 1, 'Recipe: Scorn''s Focal Dagger');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191268, 191269, 191270, 191271, 191272, 191273, 191274, 191275, 191276);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191268, 191269, 191270, 191271, 191272, 191273, 191274, 191275, 191276);
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
