-- Книги эскизов основы древкового «Мифриловая глефа»
-- Поправки статов и уровня именных предметов - решения владельца.
UPDATE `item_template` SET `stat_value1` = 20 WHERE `entry` = 13058 AND `stat_type1` = 7;
UPDATE `item_template` SET `stat_value1` = 22 WHERE `entry` = 9480 AND `stat_type1` = 3;
UPDATE `item_template` SET `stat_value1` = 22 WHERE `entry` = 13055 AND `stat_type1` = 4;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1917190, 1917200, 1917210);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1917190, 191719, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Khoo''s Point'),
(1917190, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1917190, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1917190, 7971, 0, 0, 0, 1, 1, 1, 1, 'Black Pearl'),
(1917200, 191720, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Eyegouger'),
(1917200, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1917200, 185001, 0, 0, 0, 1, 1, 1, 1, 'Превосходный нефрит'),
(1917200, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1917210, 191721, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Bonechewer'),
(1917210, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1917210, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1917210, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(13058, 191719, 'Recipe: Khoo''s Point'),
(9480, 191720, 'Recipe: Eyegouger'),
(13055, 191721, 'Recipe: Bonechewer');

DROP TEMPORARY TABLE IF EXISTS `ap_tmp_share`;
CREATE TEMPORARY TABLE `ap_tmp_share` (`tbl` varchar(16), `Entry` int unsigned, `Item` int unsigned, `share` float);
INSERT INTO `ap_tmp_share`
SELECT 'creature', o.`Entry`, o.`Item`, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`)
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
WHERE o.`Item` IN (SELECT `original` FROM `ap_tmp_single`) AND o.`Reference` = 0;
INSERT INTO `ap_tmp_share`
SELECT 'reference', o.`Entry`, o.`Item`, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`)
FROM `reference_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
WHERE o.`Item` IN (SELECT `original` FROM `ap_tmp_single`) AND o.`Reference` = 0;

UPDATE `creature_loot_template` o
JOIN `ap_tmp_share` s ON s.`tbl` = 'creature' AND s.`Entry` = o.`Entry` AND s.`Item` = o.`Item`
JOIN `ap_tmp_single` b ON b.`original` = o.`Item`
SET o.`Item` = b.`book` * 10, o.`Reference` = b.`book` * 10, o.`Comment` = CONCAT(b.`comment`, ' and materials')
WHERE o.`Reference` = 0 AND s.`share` >= 4;
UPDATE `creature_loot_template` o
JOIN `ap_tmp_single` b ON b.`original` = o.`Item`
SET o.`Item` = b.`book`, o.`Comment` = b.`comment`
WHERE o.`Reference` = 0;

UPDATE `reference_loot_template` o
JOIN `ap_tmp_share` s ON s.`tbl` = 'reference' AND s.`Entry` = o.`Entry` AND s.`Item` = o.`Item`
JOIN `ap_tmp_single` b ON b.`original` = o.`Item`
SET o.`Item` = b.`book` * 10, o.`Reference` = b.`book` * 10, o.`Comment` = CONCAT(b.`comment`, ' and materials')
WHERE o.`Reference` = 0 AND s.`share` >= 4;
UPDATE `reference_loot_template` o
JOIN `ap_tmp_single` b ON b.`original` = o.`Item`
SET o.`Item` = b.`book`, o.`Comment` = b.`comment`
WHERE o.`Reference` = 0;

UPDATE `gameobject_loot_template` o
JOIN `ap_tmp_single` b ON b.`original` = o.`Item`
SET o.`Item` = b.`book`, o.`Comment` = b.`comment`
WHERE o.`Reference` = 0;

UPDATE `item_loot_template` o
JOIN `ap_tmp_single` b ON b.`original` = o.`Item`
SET o.`Item` = b.`book`, o.`Comment` = b.`comment`
WHERE o.`Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_share`;
DROP TEMPORARY TABLE `ap_tmp_single`;
