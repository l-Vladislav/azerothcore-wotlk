-- Книги эскизов основы древкового «Ториевая алебарда»
-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1917230, 1917240, 1917250, 1917270);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1917230, 191723, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Stoneraven'),
(1917230, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1917230, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby'),
(1917230, 12364, 0, 0, 0, 1, 1, 1, 1, 'Huge Emerald'),
(1917230, 12799, 0, 0, 0, 1, 1, 1, 1, 'Large Opal'),
(1917240, 191724, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Frenzied Striker'),
(1917240, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1917240, 12799, 0, 0, 0, 1, 1, 1, 1, 'Large Opal'),
(1917240, 12364, 0, 0, 0, 1, 1, 1, 1, 'Huge Emerald'),
(1917250, 191725, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: The Needler'),
(1917250, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1917250, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby'),
(1917250, 12799, 0, 0, 0, 1, 1, 1, 1, 'Large Opal'),
(1917270, 191727, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Stonecutting Glaive'),
(1917270, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1917270, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby'),
(1917270, 12364, 0, 0, 0, 1, 1, 1, 1, 'Huge Emerald');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(13059, 191723, 'Recipe: Stoneraven'),
(13056, 191724, 'Recipe: Frenzied Striker'),
(13060, 191725, 'Recipe: The Needler'),
(20660, 191727, 'Recipe: Stonecutting Glaive');

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

-- Условие добычи именного предмета переходит на строку таблицы ссылок его книги.
UPDATE `conditions` SET `SourceEntry` = 1917270 WHERE `SourceTypeOrReferenceId` = 1 AND `SourceGroup` = 15212 AND `SourceEntry` = 20660;
