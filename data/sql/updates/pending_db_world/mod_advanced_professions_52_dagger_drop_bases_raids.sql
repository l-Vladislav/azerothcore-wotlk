-- Основы добычи кинжалов рейдов и мировых боссов
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом; книги копий со случайным суффиксом делят его поровну.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(18878, 180280, 'Broken Sorcerous Dagger'),
(18805, 180281, 'Broken Core Hound Tooth'),
(17071, 180282, 'Broken Gutgore Ripper'),
(18816, 180283, 'Broken Perdition''s Blade'),
(19903, 180284, 'Broken Fang of Venoxis'),
(19965, 180285, 'Broken Wushoolay''s Poker'),
(19859, 180286, 'Broken Fang of the Faceless'),
(21498, 180287, 'Broken Qiraji Sacrificial Dagger'),
(21802, 180288, 'Broken The Lost Kris of Zedd'),
(19346, 180289, 'Broken Dragonfang Blade'),
(19347, 180290, 'Broken Claw of Chromaggus'),
(21126, 180291, 'Broken Death''s Sting'),
(22803, 180292, 'Broken Midnight Haze'),
(22804, 180293, 'Broken Maexxna''s Fang'),
(23044, 180294, 'Broken Harbinger of Doom'),
(22802, 180295, 'Broken Kingsfall'),
(17070, 180296, 'Broken Fang of the Mystics'),
(20578, 180297, 'Broken Emerald Dragonfang');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(180280, 191309, 1, 'Recipe: Sorcerous Dagger'),
(180281, 191310, 1, 'Recipe: Core Hound Tooth'),
(180282, 191311, 1, 'Recipe: Gutgore Ripper'),
(180283, 191312, 1, 'Recipe: Perdition''s Blade'),
(180284, 191313, 1, 'Recipe: Fang of Venoxis'),
(180285, 191314, 1, 'Recipe: Wushoolay''s Poker'),
(180286, 191315, 1, 'Recipe: Fang of the Faceless'),
(180287, 191316, 1, 'Recipe: Qiraji Sacrificial Dagger'),
(180288, 191317, 1, 'Recipe: The Lost Kris of Zedd'),
(180289, 191318, 1, 'Recipe: Dragonfang Blade'),
(180290, 191319, 1, 'Recipe: Claw of Chromaggus'),
(180291, 191320, 1, 'Recipe: Death''s Sting'),
(180292, 191321, 1, 'Recipe: Midnight Haze'),
(180293, 191322, 1, 'Recipe: Maexxna''s Fang'),
(180294, 191323, 1, 'Recipe: Harbinger of Doom'),
(180295, 191324, 1, 'Recipe: Kingsfall'),
(180296, 191325, 1, 'Recipe: Fang of the Mystics'),
(180297, 191326, 1, 'Recipe: Emerald Dragonfang');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191309, 191310, 191311, 191312, 191313, 191314, 191315, 191316, 191317, 191318, 191319, 191320, 191321, 191322, 191323, 191324, 191325, 191326);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191309, 191310, 191311, 191312, 191313, 191314, 191315, 191316, 191317, 191318, 191319, 191320, 191321, 191322, 191323, 191324, 191325, 191326);
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
