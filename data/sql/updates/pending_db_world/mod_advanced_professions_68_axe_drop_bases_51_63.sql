-- Основы добычи топоров подземелий полосы 51-63
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20)
-- с тем же шансом; книги копий со случайным суффиксом делят его поровну.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `broken_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(12527, 180454, 'Broken Ribsplitter'),
(11702, 180460, 'Broken Grizzle''s Skinner'),
(10837, 180461, 'Broken Tooth of Eranikus'),
(11920, 180462, 'Broken Wraith Scythe'),
(13408, 180463, 'Broken Soul Breaker'),
(13286, 180464, 'Broken Rivenspike'),
(12621, 180465, 'Broken Demonfork'),
(18498, 180466, 'Broken Hedgecutter'),
(13952, 180467, 'Broken Iceblade Hacker'),
(18737, 180468, 'Broken Bone Slicing Hatchet');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_book`;
CREATE TEMPORARY TABLE `ap_tmp_drop_book` (`broken` int unsigned, `book` int unsigned, `n` int unsigned, `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_book` VALUES
(180454, 191510, 6, 'Recipe: Ribsplitter of Agility'),
(180454, 191511, 6, 'Recipe: Ribsplitter of Strength'),
(180454, 191512, 6, 'Recipe: Ribsplitter of Stamina'),
(180454, 191513, 6, 'Recipe: Ribsplitter of the Monkey'),
(180454, 191514, 6, 'Recipe: Ribsplitter of the Tiger'),
(180454, 191515, 6, 'Recipe: Ribsplitter of the Bear'),
(180460, 191516, 1, 'Recipe: Grizzle''s Skinner'),
(180461, 191517, 1, 'Recipe: Tooth of Eranikus'),
(180462, 191518, 1, 'Recipe: Wraith Scythe'),
(180463, 191519, 1, 'Recipe: Soul Breaker'),
(180464, 191520, 1, 'Recipe: Rivenspike'),
(180465, 191521, 1, 'Recipe: Demonfork'),
(180466, 191522, 1, 'Recipe: Hedgecutter'),
(180467, 191523, 1, 'Recipe: Iceblade Hacker'),
(180468, 191524, 1, 'Recipe: Bone Slicing Hatchet');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191510, 191511, 191512, 191513, 191514, 191515, 191516, 191517, 191518, 191519, 191520, 191521, 191522, 191523, 191524);
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
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191510, 191511, 191512, 191513, 191514, 191515, 191516, 191517, 191518, 191519, 191520, 191521, 191522, 191523, 191524);
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

-- «Аннигилятор» (12798) куётся кузнечным делом: сломанная основа - строкой рядом с чертежом 12835
-- в той же группе и с его шансом, книга эскиза - в группе 20 с тем же шансом; чертёж остаётся.
DELETE FROM `creature_loot_template` WHERE `Item` IN (180469, 191525);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, x.`Item`, 0, o.`Chance`, 0, o.`LootMode`, IF(x.`GroupId` = 20, 20, o.`GroupId`), 1, 1, x.`Comment`
FROM `creature_loot_template` o
JOIN (SELECT 180469 AS `Item`, 0 AS `GroupId`, 'Broken Annihilator' AS `Comment`
      UNION ALL SELECT 191525, 20, 'Recipe: Annihilator') x
WHERE o.`Item` = 12835 AND o.`Reference` = 0;
