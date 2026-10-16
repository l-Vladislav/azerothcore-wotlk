-- Книги эскизов основы булавы «Буздыхан»
-- Поправки статов и уровня именных предметов - решения владельца.
UPDATE `item_template` SET `stat_value3` = 4 WHERE `entry` = 13026 AND `stat_type3` = 6;
UPDATE `item_template` SET `stat_value4` = 2 WHERE `entry` = 13026 AND `stat_type4` = 5;
UPDATE `item_template` SET `stat_value5` = 2 WHERE `entry` = 13026 AND `stat_type5` = 7;
UPDATE `item_template` SET `stat_value2` = 6 WHERE `entry` = 13025 AND `stat_type2` = 6;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1916080, 1916090, 1916100, 1916110, 1916120, 1916140);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1916080, 191608, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Wirt''s Third Leg'),
(1916080, 3859, 0, 33.3333, 0, 1, 1, 1, 1, 'Steel Bar'),
(1916080, 185001, 0, 0, 0, 1, 1, 1, 1, 'Превосходный нефрит'),
(1916080, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1916090, 191609, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Heaven''s Light'),
(1916090, 3859, 0, 33.3333, 0, 1, 1, 1, 1, 'Steel Bar'),
(1916090, 185001, 0, 0, 0, 1, 1, 1, 1, 'Превосходный нефрит'),
(1916090, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1916090, 7971, 0, 0, 0, 1, 1, 1, 1, 'Black Pearl'),
(1916100, 191610, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Deadwood Sledge'),
(1916100, 3859, 0, 0, 0, 1, 1, 1, 1, 'Steel Bar'),
(1916100, 7971, 0, 0, 0, 1, 1, 1, 1, 'Black Pearl'),
(1916110, 191611, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Midnight Mace'),
(1916110, 3859, 0, 33.3333, 0, 1, 1, 1, 1, 'Steel Bar'),
(1916110, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1916110, 7971, 0, 0, 0, 1, 1, 1, 1, 'Black Pearl'),
(1916120, 191612, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Ardent Custodian'),
(1916120, 3859, 0, 33.3333, 0, 1, 1, 1, 1, 'Steel Bar'),
(1916120, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1916120, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1916140, 191614, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Galgann''s Firehammer'),
(1916140, 3859, 0, 0, 0, 1, 1, 1, 1, 'Steel Bar'),
(1916140, 185002, 0, 0, 0, 1, 1, 1, 1, 'Малый чародейный кристалл');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(9359, 191608, 'Recipe: Wirt''s Third Leg'),
(13026, 191609, 'Recipe: Heaven''s Light'),
(13025, 191610, 'Recipe: Deadwood Sledge'),
(936, 191611, 'Recipe: Midnight Mace'),
(868, 191612, 'Recipe: Ardent Custodian'),
(19808, 191613, 'Recipe: Rockhide Strongfish'),
(9419, 191614, 'Recipe: Galgann''s Firehammer');

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

-- Оригинал со случайным суффиксом: шанс делится поровну между книгами его копий.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book`;
CREATE TEMPORARY TABLE `ap_tmp_book` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_book` VALUES
(15226, 191616, 'Recipe: Giant Club of Agility'),
(15226, 191617, 'Recipe: Giant Club of Strength'),
(15226, 191618, 'Recipe: Giant Club of Stamina'),
(15226, 191619, 'Recipe: Giant Club of the Falcon'),
(15226, 191620, 'Recipe: Giant Club of the Wolf'),
(15226, 191621, 'Recipe: Giant Club of the Monkey'),
(15226, 191622, 'Recipe: Giant Club of the Tiger'),
(15226, 191623, 'Recipe: Giant Club of the Owl'),
(15226, 191624, 'Recipe: Giant Club of the Eagle'),
(15226, 191625, 'Recipe: Giant Club of the Gorilla'),
(15226, 191626, 'Recipe: Giant Club of the Boar'),
(15226, 191627, 'Recipe: Giant Club of the Bear');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15226) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (15226) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15226) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (15226) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15226) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (15226) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15226) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (15226) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;

-- Условия добычи именного предмета переходят на строки его книги.
UPDATE `conditions` SET `SourceEntry` = 191613 WHERE `SourceTypeOrReferenceId` = 4 AND `SourceGroup` = 17280 AND `SourceEntry` = 19808;
UPDATE `conditions` SET `SourceEntry` = 191613 WHERE `SourceTypeOrReferenceId` = 10 AND `SourceGroup` = 11150 AND `SourceEntry` = 19808;