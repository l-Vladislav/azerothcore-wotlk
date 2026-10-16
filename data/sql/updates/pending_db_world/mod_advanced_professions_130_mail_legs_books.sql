-- Книги эскизов кольчуги Бронника: поножи
-- Поправки статов именных предметов (#272, карточка слота).
UPDATE `item_template` SET `stat_value1` = 2 WHERE `entry` = 2966 AND `stat_type1` = 7 AND `stat_value1` = 1;
UPDATE `item_template` SET `stat_value2` = 2 WHERE `entry` = 2966 AND `stat_type2` = 7 AND `stat_value2` = 1;
UPDATE `item_template` SET `stat_value3` = 2 WHERE `entry` = 2966 AND `stat_type3` = 7 AND `stat_value3` = 1;
UPDATE `item_template` SET `stat_value4` = 2 WHERE `entry` = 2966 AND `stat_type4` = 7 AND `stat_value4` = 1;
UPDATE `item_template` SET `stat_value5` = 2 WHERE `entry` = 2966 AND `stat_type5` = 7 AND `stat_value5` = 1;
UPDATE `item_template` SET `stat_value1` = 2 WHERE `entry` = 3282 AND `stat_type1` = 4 AND `stat_value1` = 1;
UPDATE `item_template` SET `stat_value2` = 2 WHERE `entry` = 3282 AND `stat_type2` = 4 AND `stat_value2` = 1;
UPDATE `item_template` SET `stat_value3` = 2 WHERE `entry` = 3282 AND `stat_type3` = 4 AND `stat_value3` = 1;
UPDATE `item_template` SET `stat_value4` = 2 WHERE `entry` = 3282 AND `stat_type4` = 4 AND `stat_value4` = 1;
UPDATE `item_template` SET `stat_value5` = 2 WHERE `entry` = 3282 AND `stat_type5` = 4 AND `stat_value5` = 1;
UPDATE `item_template` SET `stat_value1` = 9 WHERE `entry` = 14748 AND `stat_type1` = 4 AND `stat_value1` = 8;
UPDATE `item_template` SET `stat_value2` = 9 WHERE `entry` = 14748 AND `stat_type2` = 4 AND `stat_value2` = 8;
UPDATE `item_template` SET `stat_value3` = 9 WHERE `entry` = 14748 AND `stat_type3` = 4 AND `stat_value3` = 8;
UPDATE `item_template` SET `stat_value4` = 9 WHERE `entry` = 14748 AND `stat_type4` = 4 AND `stat_value4` = 8;
UPDATE `item_template` SET `stat_value5` = 9 WHERE `entry` = 14748 AND `stat_type5` = 4 AND `stat_value5` = 8;
UPDATE `item_template` SET `stat_value1` = 7 WHERE `entry` = 13010 AND `stat_type1` = 7 AND `stat_value1` = 8;
UPDATE `item_template` SET `stat_value2` = 7 WHERE `entry` = 13010 AND `stat_type2` = 7 AND `stat_value2` = 8;
UPDATE `item_template` SET `stat_value3` = 7 WHERE `entry` = 13010 AND `stat_type3` = 7 AND `stat_value3` = 8;
UPDATE `item_template` SET `stat_value4` = 7 WHERE `entry` = 13010 AND `stat_type4` = 7 AND `stat_value4` = 8;
UPDATE `item_template` SET `stat_value5` = 7 WHERE `entry` = 13010 AND `stat_type5` = 7 AND `stat_value5` = 8;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1926450, 1926590, 1926760);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1926450, 192645, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Warrior''s Pants'),
(1926450, 2840, 0, 33.3333, 0, 1, 1, 1, 1, 'Copper Bar'),
(1926450, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня'),
(1926590, 192659, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Goblin Mail Leggings'),
(1926590, 2840, 0, 33.3333, 0, 1, 1, 1, 1, 'Copper Bar'),
(1926590, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1926590, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня'),
(1926760, 192676, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Dreamsinger Legguards'),
(1926760, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1926760, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1926760, 5500, 0, 0, 0, 1, 1, 1, 1, 'Iridescent Pearl');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(2966, 192645, 'Recipe: Warrior''s Pants'),
(3282, 192646, 'Recipe: Battle Chain Pants'),
(3473, 192647, 'Recipe: Runed Copper Pants'),
(2978, 192657, 'Recipe: Veteran Leggings'),
(3305, 192658, 'Recipe: Brackwater Leggings'),
(1943, 192659, 'Recipe: Goblin Mail Leggings'),
(14727, 192660, 'Recipe: War Paint Legguards'),
(2166, 192661, 'Recipe: Foreman''s Leggings'),
(2865, 192662, 'Recipe: Rough Bronze Leggings'),
(2990, 192663, 'Recipe: Burnished Leggings'),
(14748, 192674, 'Recipe: Hulking Leggings'),
(3048, 192675, 'Recipe: Lambent Scale Legguards'),
(13010, 192676, 'Recipe: Dreamsinger Legguards'),
(6386, 192735, 'Recipe: Glimmering Mail Legguards'),
(3842, 192736, 'Recipe: Green Iron Leggings'),
(10423, 192737, 'Recipe: Silvered Bronze Leggings'),
(14757, 192738, 'Recipe: Slayer''s Pants'),
(3843, 192739, 'Recipe: Golden Scale Leggings');

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
UPDATE `reference_loot_template` o
JOIN `ap_tmp_share` s ON s.`tbl` = 'reference' AND s.`Entry` = o.`Entry` AND s.`Item` = o.`Item`
JOIN `ap_tmp_single` b ON b.`original` = o.`Item`
SET o.`Item` = b.`book` * 10, o.`Reference` = b.`book` * 10, o.`Comment` = CONCAT(b.`comment`, ' and materials')
WHERE o.`Reference` = 0 AND s.`share` >= 4;
UPDATE `creature_loot_template` o
JOIN `ap_tmp_single` b ON b.`original` = o.`Item`
SET o.`Item` = b.`book`, o.`Comment` = b.`comment`
WHERE o.`Reference` = 0;
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
UPDATE `pickpocketing_loot_template` o
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
(15477, 192648, 'Recipe: Charger''s Pants of the Wolf'),
(9763, 192649, 'Recipe: Cadet Leggings of the Tiger'),
(9763, 192650, 'Recipe: Cadet Leggings of the Monkey'),
(9763, 192651, 'Recipe: Cadet Leggings of Strength'),
(9763, 192652, 'Recipe: Cadet Leggings of the Gorilla'),
(9763, 192653, 'Recipe: Cadet Leggings of the Boar'),
(9763, 192654, 'Recipe: Cadet Leggings of the Owl'),
(9763, 192655, 'Recipe: Cadet Leggings of the Eagle'),
(9763, 192656, 'Recipe: Cadet Leggings of the Whale'),
(6546, 192664, 'Recipe: Soldier''s Leggings of Strength'),
(6546, 192665, 'Recipe: Soldier''s Leggings of Strength'),
(6546, 192666, 'Recipe: Soldier''s Leggings of the Gorilla'),
(6546, 192667, 'Recipe: Soldier''s Leggings of the Eagle'),
(6546, 192668, 'Recipe: Soldier''s Leggings of the Whale'),
(6546, 192669, 'Recipe: Soldier''s Leggings of Strength'),
(6546, 192670, 'Recipe: Soldier''s Leggings of the Bear'),
(9789, 192671, 'Recipe: Raider''s Legguards of Strength'),
(9789, 192672, 'Recipe: Raider''s Legguards of the Falcon'),
(9789, 192673, 'Recipe: Raider''s Legguards of Strength'),
(15503, 192677, 'Recipe: Outrunner''s Legguards of Strength'),
(15503, 192678, 'Recipe: Outrunner''s Legguards of the Tiger'),
(15503, 192679, 'Recipe: Outrunner''s Legguards of the Monkey'),
(15503, 192680, 'Recipe: Outrunner''s Legguards of Strength'),
(15503, 192681, 'Recipe: Outrunner''s Legguards of the Gorilla'),
(15503, 192682, 'Recipe: Outrunner''s Legguards of the Boar'),
(15503, 192683, 'Recipe: Outrunner''s Legguards of the Bear'),
(15503, 192684, 'Recipe: Outrunner''s Legguards of the Eagle'),
(15503, 192685, 'Recipe: Outrunner''s Legguards of the Whale'),
(15503, 192686, 'Recipe: Outrunner''s Legguards of the Monkey'),
(15503, 192687, 'Recipe: Outrunner''s Legguards of the Tiger'),
(15503, 192688, 'Recipe: Outrunner''s Legguards of the Monkey'),
(15503, 192689, 'Recipe: Outrunner''s Legguards of the Gorilla'),
(15503, 192690, 'Recipe: Outrunner''s Legguards of the Boar'),
(15503, 192691, 'Recipe: Outrunner''s Legguards of the Bear'),
(15503, 192692, 'Recipe: Outrunner''s Legguards of the Gorilla'),
(15503, 192693, 'Recipe: Outrunner''s Legguards of the Boar'),
(15503, 192694, 'Recipe: Outrunner''s Legguards of the Bear'),
(15503, 192695, 'Recipe: Outrunner''s Legguards of the Eagle'),
(15503, 192696, 'Recipe: Outrunner''s Legguards of the Eagle'),
(15503, 192697, 'Recipe: Outrunner''s Legguards of the Whale'),
(15503, 192698, 'Recipe: Outrunner''s Legguards of the Whale'),
(15503, 192699, 'Recipe: Outrunner''s Legguards of the Tiger'),
(15503, 192700, 'Recipe: Outrunner''s Legguards of the Monkey'),
(15503, 192701, 'Recipe: Outrunner''s Legguards of the Gorilla'),
(15503, 192702, 'Recipe: Outrunner''s Legguards of the Boar'),
(15503, 192703, 'Recipe: Outrunner''s Legguards of the Bear'),
(15503, 192704, 'Recipe: Outrunner''s Legguards of the Eagle'),
(15503, 192705, 'Recipe: Outrunner''s Legguards of the Whale'),
(6578, 192706, 'Recipe: Defender Leggings of Strength'),
(6578, 192707, 'Recipe: Defender Leggings of Strength'),
(9815, 192708, 'Recipe: Fortified Leggings of Strength'),
(9815, 192709, 'Recipe: Fortified Leggings of the Tiger'),
(9815, 192710, 'Recipe: Fortified Leggings of the Monkey'),
(9815, 192711, 'Recipe: Fortified Leggings of Strength'),
(9815, 192712, 'Recipe: Fortified Leggings of the Gorilla'),
(9815, 192713, 'Recipe: Fortified Leggings of the Boar'),
(9815, 192714, 'Recipe: Fortified Leggings of the Bear'),
(9815, 192715, 'Recipe: Fortified Leggings of the Eagle'),
(9815, 192716, 'Recipe: Fortified Leggings of the Whale'),
(9815, 192717, 'Recipe: Fortified Leggings of the Monkey'),
(9815, 192718, 'Recipe: Fortified Leggings of the Tiger'),
(9815, 192719, 'Recipe: Fortified Leggings of the Monkey'),
(9815, 192720, 'Recipe: Fortified Leggings of the Gorilla'),
(9815, 192721, 'Recipe: Fortified Leggings of the Boar'),
(9815, 192722, 'Recipe: Fortified Leggings of the Bear'),
(9815, 192723, 'Recipe: Fortified Leggings of the Gorilla'),
(9815, 192724, 'Recipe: Fortified Leggings of the Boar'),
(9815, 192725, 'Recipe: Fortified Leggings of the Bear'),
(9815, 192726, 'Recipe: Fortified Leggings of the Eagle'),
(9815, 192727, 'Recipe: Fortified Leggings of the Eagle'),
(9815, 192728, 'Recipe: Fortified Leggings of the Whale'),
(9815, 192729, 'Recipe: Fortified Leggings of the Whale'),
(15521, 192730, 'Recipe: Spiked Chain Leggings of Strength'),
(15521, 192731, 'Recipe: Spiked Chain Leggings of Strength'),
(6596, 192732, 'Recipe: Battleforge Legguards of the Owl'),
(6596, 192733, 'Recipe: Battleforge Legguards of Strength'),
(15529, 192734, 'Recipe: Sentry''s Leggings of the Owl'),
(9841, 192740, 'Recipe: Banded Leggings of Strength'),
(9841, 192741, 'Recipe: Banded Leggings of the Tiger'),
(9841, 192742, 'Recipe: Banded Leggings of the Monkey'),
(9841, 192743, 'Recipe: Banded Leggings of Strength'),
(9841, 192744, 'Recipe: Banded Leggings of the Gorilla'),
(9841, 192745, 'Recipe: Banded Leggings of the Boar'),
(9841, 192746, 'Recipe: Banded Leggings of the Bear'),
(9841, 192747, 'Recipe: Banded Leggings of the Eagle'),
(9841, 192748, 'Recipe: Banded Leggings of the Whale'),
(9841, 192749, 'Recipe: Banded Leggings of the Tiger'),
(9841, 192750, 'Recipe: Banded Leggings of the Monkey'),
(9841, 192751, 'Recipe: Banded Leggings of the Tiger'),
(9841, 192752, 'Recipe: Banded Leggings of the Monkey'),
(9841, 192753, 'Recipe: Banded Leggings of the Gorilla'),
(9841, 192754, 'Recipe: Banded Leggings of the Boar'),
(9841, 192755, 'Recipe: Banded Leggings of the Bear'),
(9841, 192756, 'Recipe: Banded Leggings of the Gorilla'),
(9841, 192757, 'Recipe: Banded Leggings of the Boar'),
(9841, 192758, 'Recipe: Banded Leggings of the Bear'),
(9841, 192759, 'Recipe: Banded Leggings of the Eagle'),
(9841, 192760, 'Recipe: Banded Leggings of the Eagle'),
(9841, 192761, 'Recipe: Banded Leggings of the Whale'),
(9841, 192762, 'Recipe: Banded Leggings of the Whale'),
(9841, 192763, 'Recipe: Banded Leggings of the Tiger'),
(9841, 192764, 'Recipe: Banded Leggings of the Monkey'),
(9841, 192765, 'Recipe: Banded Leggings of the Gorilla'),
(9841, 192766, 'Recipe: Banded Leggings of the Eagle'),
(9841, 192767, 'Recipe: Banded Leggings of the Whale'),
(15541, 192768, 'Recipe: Wicked Chain Legguards of Strength'),
(15541, 192769, 'Recipe: Wicked Chain Legguards of Strength'),
(15541, 192770, 'Recipe: Wicked Chain Legguards of the Tiger'),
(15541, 192771, 'Recipe: Wicked Chain Legguards of the Monkey'),
(15541, 192772, 'Recipe: Wicked Chain Legguards of the Gorilla'),
(15541, 192773, 'Recipe: Wicked Chain Legguards of the Boar'),
(15541, 192774, 'Recipe: Wicked Chain Legguards of the Bear'),
(15541, 192775, 'Recipe: Wicked Chain Legguards of the Eagle'),
(15541, 192776, 'Recipe: Wicked Chain Legguards of the Whale');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND `Reference` = 0;

INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `pickpocketing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `pickpocketing_loot_template` WHERE `Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND `Reference` = 0;

INSERT INTO `fishing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `fishing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `fishing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `fishing_loot_template` WHERE `Item` IN (15477, 9763, 6546, 9789, 15503, 6578, 9815, 15521, 6596, 15529, 9841, 15541) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
