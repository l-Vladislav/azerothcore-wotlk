-- Книги эскизов ковочных основ кастетов «Мифриловый коготь» и «Ториевый кастет»
-- Поправки статов и уровня именных предметов - решения владельца.
UPDATE `item_template` SET `stat_value1` = 6 WHERE `entry` = 18202 AND `stat_type1` = 3;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1921830, 1921840, 1921850, 1921880);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1921830, 192183, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Vilerend Slicer'),
(1921830, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1921830, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1921830, 185001, 0, 0, 0, 1, 1, 1, 1, 'Превосходный нефрит'),
(1921840, 192184, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Rockfist'),
(1921840, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1921840, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby'),
(1921850, 192185, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Jagged Bone Fist'),
(1921850, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1921850, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby'),
(1921850, 12799, 0, 0, 0, 1, 1, 1, 1, 'Large Opal'),
(1921880, 192188, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Eskhandar''s Left Claw'),
(1921880, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1921880, 12364, 0, 0, 0, 1, 1, 1, 1, 'Huge Emerald'),
(1921880, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(11603, 192183, 'Recipe: Vilerend Slicer'),
(11743, 192184, 'Recipe: Rockfist'),
(18462, 192185, 'Recipe: Jagged Bone Fist'),
(18202, 192188, 'Recipe: Eskhandar''s Left Claw');

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
