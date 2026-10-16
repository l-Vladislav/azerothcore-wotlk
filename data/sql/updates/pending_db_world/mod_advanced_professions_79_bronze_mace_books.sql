-- Книги эскизов основы булавы «Бронзовая палица»
-- Поправки статов и уровня именных предметов - решения владельца.
UPDATE `item_template` SET `ItemLevel` = 22 WHERE `entry` = 5197;
UPDATE `item_template` SET `stat_value1` = 5 WHERE `entry` = 6360 AND `stat_type1` = 4;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1915720, 1915730, 1915790, 1915800, 1915810);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1915720, 191572, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Cookie''s Tenderizer'),
(1915720, 2841, 0, 0, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1915720, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1915730, 191573, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Baron''s Scepter'),
(1915730, 2841, 0, 0, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1915730, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1915790, 191579, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Diamond Hammer'),
(1915790, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1915790, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1915790, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone'),
(1915800, 191580, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Beazel''s Basher'),
(1915800, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1915800, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1915800, 5500, 0, 0, 0, 1, 1, 1, 1, 'Iridescent Pearl'),
(1915810, 191581, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Skeletal Club'),
(1915810, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1915810, 185000, 0, 0, 0, 1, 1, 1, 1, 'Превосходный камень теней'),
(1915810, 5500, 0, 0, 0, 1, 1, 1, 1, 'Iridescent Pearl');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(5197, 191572, 'Recipe: Cookie''s Tenderizer'),
(6323, 191573, 'Recipe: Baron''s Scepter'),
(6360, 191575, 'Recipe: Steelscale Crushfish'),
(1457, 191576, 'Recipe: Shadowhide Mace'),
(920, 191577, 'Recipe: Wicked Spiked Mace'),
(2194, 191579, 'Recipe: Diamond Hammer'),
(13024, 191580, 'Recipe: Beazel''s Basher'),
(2256, 191581, 'Recipe: Skeletal Club');

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

UPDATE `fishing_loot_template` o
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
(789, 191582, 'Recipe: Stout Battlehammer of Agility'),
(789, 191583, 'Recipe: Stout Battlehammer of Intellect'),
(789, 191584, 'Recipe: Stout Battlehammer of Spirit'),
(789, 191585, 'Recipe: Stout Battlehammer of the Monkey'),
(789, 191586, 'Recipe: Stout Battlehammer of the Falcon'),
(789, 191587, 'Recipe: Stout Battlehammer of the Wolf'),
(789, 191588, 'Recipe: Stout Battlehammer of the Tiger'),
(789, 191589, 'Recipe: Stout Battlehammer of the Eagle'),
(789, 191590, 'Recipe: Stout Battlehammer of the Gorilla'),
(789, 191591, 'Recipe: Stout Battlehammer of the Whale'),
(789, 191592, 'Recipe: Stout Battlehammer of the Boar'),
(15224, 191593, 'Recipe: Battlesmasher of Stamina'),
(15224, 191594, 'Recipe: Battlesmasher of Intellect');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (789, 15224) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (789, 15224) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (789, 15224) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (789, 15224) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (789, 15224) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (789, 15224) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (789, 15224) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (789, 15224) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
