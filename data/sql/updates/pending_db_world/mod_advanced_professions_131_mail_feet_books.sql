-- Книги эскизов кольчуги Бронника: сапоги
-- Поправки статов именных предметов (#272, карточка слота).
UPDATE `item_template` SET `stat_value1` = 8 WHERE `entry` = 9510 AND `stat_type1` = 7 AND `stat_value1` = 10;
UPDATE `item_template` SET `stat_value2` = 8 WHERE `entry` = 9510 AND `stat_type2` = 7 AND `stat_value2` = 10;
UPDATE `item_template` SET `stat_value3` = 8 WHERE `entry` = 9510 AND `stat_type3` = 7 AND `stat_value3` = 10;
UPDATE `item_template` SET `stat_value4` = 8 WHERE `entry` = 9510 AND `stat_type4` = 7 AND `stat_value4` = 10;
UPDATE `item_template` SET `stat_value5` = 8 WHERE `entry` = 9510 AND `stat_type5` = 7 AND `stat_value5` = 10;
UPDATE `item_template` SET `stat_value1` = 11 WHERE `entry` = 10332 AND `stat_type1` = 7 AND `stat_value1` = 12;
UPDATE `item_template` SET `stat_value2` = 11 WHERE `entry` = 10332 AND `stat_type2` = 7 AND `stat_value2` = 12;
UPDATE `item_template` SET `stat_value3` = 11 WHERE `entry` = 10332 AND `stat_type3` = 7 AND `stat_value3` = 12;
UPDATE `item_template` SET `stat_value4` = 11 WHERE `entry` = 10332 AND `stat_type4` = 7 AND `stat_value4` = 12;
UPDATE `item_template` SET `stat_value5` = 11 WHERE `entry` = 10332 AND `stat_type5` = 7 AND `stat_value5` = 12;
UPDATE `item_template` SET `stat_value1` = 8 WHERE `entry` = 13124 AND `stat_type1` = 7 AND `stat_value1` = 11;
UPDATE `item_template` SET `stat_value2` = 8 WHERE `entry` = 13124 AND `stat_type2` = 7 AND `stat_value2` = 11;
UPDATE `item_template` SET `stat_value3` = 8 WHERE `entry` = 13124 AND `stat_type3` = 7 AND `stat_value3` = 11;
UPDATE `item_template` SET `stat_value4` = 8 WHERE `entry` = 13124 AND `stat_type4` = 7 AND `stat_value4` = 11;
UPDATE `item_template` SET `stat_value5` = 8 WHERE `entry` = 13124 AND `stat_type5` = 7 AND `stat_value5` = 11;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1927810, 1927920, 1928580, 1928600, 1928610, 1928620);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1927810, 192781, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Silver-linked Footguards'),
(1927810, 2840, 0, 33.3333, 0, 1, 1, 1, 1, 'Copper Bar'),
(1927810, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1927810, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone'),
(1927920, 192792, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Savage Trodders'),
(1927920, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1927920, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня'),
(1927920, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone'),
(1928580, 192858, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Trouncing Boots'),
(1928580, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1928580, 1529, 0, 0, 0, 1, 1, 1, 1, 'Jade'),
(1928580, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1928600, 192860, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Caverndeep Trudgers'),
(1928600, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1928600, 1529, 0, 0, 0, 1, 1, 1, 1, 'Jade'),
(1928600, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1928610, 192861, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Scarlet Boots'),
(1928610, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1928610, 1529, 0, 0, 0, 1, 1, 1, 1, 'Jade'),
(1928610, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone'),
(1928620, 192862, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Ravasaur Scale Boots'),
(1928620, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1928620, 5500, 0, 0, 0, 1, 1, 1, 1, 'Iridescent Pearl'),
(1928620, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(3302, 192777, 'Recipe: Brackwater Boots'),
(14722, 192778, 'Recipe: War Paint Anklewraps'),
(1446, 192779, 'Recipe: Blackrock Boots'),
(2991, 192780, 'Recipe: Burnished Boots'),
(12982, 192781, 'Recipe: Silver-linked Footguards'),
(6459, 192792, 'Recipe: Savage Trodders'),
(14742, 192793, 'Recipe: Hulking Boots'),
(3482, 192794, 'Recipe: Silvered Bronze Boots'),
(1955, 192795, 'Recipe: Dragonmaw Chain Boots'),
(3045, 192796, 'Recipe: Lambent Scale Boots'),
(3484, 192797, 'Recipe: Green Iron Boots'),
(14756, 192798, 'Recipe: Slayer''s Slippers'),
(4073, 192857, 'Recipe: Glimmering Mail Greaves'),
(4464, 192858, 'Recipe: Trouncing Boots'),
(4076, 192859, 'Recipe: Mail Combat Boots'),
(9510, 192860, 'Recipe: Caverndeep Trudgers'),
(10332, 192861, 'Recipe: Scarlet Boots'),
(13124, 192862, 'Recipe: Ravasaur Scale Boots');

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
(15489, 192782, 'Recipe: Bloodspattered Sabatons of Stamina'),
(15489, 192783, 'Recipe: Bloodspattered Sabatons of the Tiger'),
(15489, 192784, 'Recipe: Bloodspattered Sabatons of the Monkey'),
(15489, 192785, 'Recipe: Bloodspattered Sabatons of the Gorilla'),
(15489, 192786, 'Recipe: Bloodspattered Sabatons of the Boar'),
(15489, 192787, 'Recipe: Bloodspattered Sabatons of the Owl'),
(15489, 192788, 'Recipe: Bloodspattered Sabatons of the Eagle'),
(15489, 192789, 'Recipe: Bloodspattered Sabatons of the Whale'),
(6551, 192790, 'Recipe: Soldier''s Boots of Stamina'),
(9784, 192791, 'Recipe: Raider''s Boots of the Wolf'),
(6573, 192799, 'Recipe: Defender Boots of Stamina'),
(6573, 192800, 'Recipe: Defender Boots of Stamina'),
(6573, 192801, 'Recipe: Defender Boots of the Tiger'),
(6573, 192802, 'Recipe: Defender Boots of the Falcon'),
(6573, 192803, 'Recipe: Defender Boots of the Monkey'),
(6573, 192804, 'Recipe: Defender Boots of the Gorilla'),
(6573, 192805, 'Recipe: Defender Boots of the Boar'),
(6573, 192806, 'Recipe: Defender Boots of the Bear'),
(6573, 192807, 'Recipe: Defender Boots of the Eagle'),
(6573, 192808, 'Recipe: Defender Boots of the Whale'),
(6573, 192809, 'Recipe: Defender Boots of the Tiger'),
(6573, 192810, 'Recipe: Defender Boots of the Tiger'),
(6573, 192811, 'Recipe: Defender Boots of the Monkey'),
(6573, 192812, 'Recipe: Defender Boots of the Gorilla'),
(6573, 192813, 'Recipe: Defender Boots of the Boar'),
(6573, 192814, 'Recipe: Defender Boots of the Bear'),
(6573, 192815, 'Recipe: Defender Boots of the Gorilla'),
(6573, 192816, 'Recipe: Defender Boots of the Boar'),
(6573, 192817, 'Recipe: Defender Boots of the Bear'),
(6573, 192818, 'Recipe: Defender Boots of the Eagle'),
(6573, 192819, 'Recipe: Defender Boots of the Eagle'),
(6573, 192820, 'Recipe: Defender Boots of the Whale'),
(6573, 192821, 'Recipe: Defender Boots of the Tiger'),
(6573, 192822, 'Recipe: Defender Boots of the Monkey'),
(6573, 192823, 'Recipe: Defender Boots of the Gorilla'),
(6573, 192824, 'Recipe: Defender Boots of the Eagle'),
(6573, 192825, 'Recipe: Defender Boots of the Whale'),
(9810, 192826, 'Recipe: Fortified Boots of Stamina'),
(15525, 192827, 'Recipe: Sentry''s Slippers of Stamina'),
(15525, 192828, 'Recipe: Sentry''s Slippers of the Tiger'),
(15525, 192829, 'Recipe: Sentry''s Slippers of the Monkey'),
(15525, 192830, 'Recipe: Sentry''s Slippers of the Gorilla'),
(15525, 192831, 'Recipe: Sentry''s Slippers of the Boar'),
(15525, 192832, 'Recipe: Sentry''s Slippers of the Bear'),
(15525, 192833, 'Recipe: Sentry''s Slippers of the Eagle'),
(15525, 192834, 'Recipe: Sentry''s Slippers of the Whale'),
(15525, 192835, 'Recipe: Sentry''s Slippers of the Tiger'),
(15525, 192836, 'Recipe: Sentry''s Slippers of the Monkey'),
(15525, 192837, 'Recipe: Sentry''s Slippers of the Tiger'),
(15525, 192838, 'Recipe: Sentry''s Slippers of the Monkey'),
(15525, 192839, 'Recipe: Sentry''s Slippers of the Gorilla'),
(15525, 192840, 'Recipe: Sentry''s Slippers of the Boar'),
(15525, 192841, 'Recipe: Sentry''s Slippers of the Bear'),
(15525, 192842, 'Recipe: Sentry''s Slippers of the Gorilla'),
(15525, 192843, 'Recipe: Sentry''s Slippers of the Boar'),
(15525, 192844, 'Recipe: Sentry''s Slippers of the Bear'),
(15525, 192845, 'Recipe: Sentry''s Slippers of the Eagle'),
(15525, 192846, 'Recipe: Sentry''s Slippers of the Eagle'),
(15525, 192847, 'Recipe: Sentry''s Slippers of the Whale'),
(15525, 192848, 'Recipe: Sentry''s Slippers of the Whale'),
(6590, 192849, 'Recipe: Battleforge Boots of Stamina'),
(6590, 192850, 'Recipe: Battleforge Boots of the Tiger'),
(6590, 192851, 'Recipe: Battleforge Boots of the Monkey'),
(6590, 192852, 'Recipe: Battleforge Boots of the Gorilla'),
(6590, 192853, 'Recipe: Battleforge Boots of the Boar'),
(6590, 192854, 'Recipe: Battleforge Boots of the Bear'),
(6590, 192855, 'Recipe: Battleforge Boots of the Eagle'),
(6590, 192856, 'Recipe: Battleforge Boots of the Whale'),
(15534, 192863, 'Recipe: Wicked Chain Boots of Stamina'),
(15534, 192864, 'Recipe: Wicked Chain Boots of the Tiger'),
(15534, 192865, 'Recipe: Wicked Chain Boots of the Monkey'),
(15534, 192866, 'Recipe: Wicked Chain Boots of the Gorilla'),
(15534, 192867, 'Recipe: Wicked Chain Boots of the Boar'),
(15534, 192868, 'Recipe: Wicked Chain Boots of the Bear'),
(15534, 192869, 'Recipe: Wicked Chain Boots of the Eagle'),
(15534, 192870, 'Recipe: Wicked Chain Boots of the Whale'),
(15534, 192871, 'Recipe: Wicked Chain Boots of the Tiger'),
(15534, 192872, 'Recipe: Wicked Chain Boots of the Monkey'),
(15534, 192873, 'Recipe: Wicked Chain Boots of the Tiger'),
(15534, 192874, 'Recipe: Wicked Chain Boots of the Monkey'),
(15534, 192875, 'Recipe: Wicked Chain Boots of the Gorilla'),
(15534, 192876, 'Recipe: Wicked Chain Boots of the Boar'),
(15534, 192877, 'Recipe: Wicked Chain Boots of the Bear'),
(15534, 192878, 'Recipe: Wicked Chain Boots of the Gorilla'),
(15534, 192879, 'Recipe: Wicked Chain Boots of the Boar'),
(15534, 192880, 'Recipe: Wicked Chain Boots of the Bear'),
(15534, 192881, 'Recipe: Wicked Chain Boots of the Eagle'),
(15534, 192882, 'Recipe: Wicked Chain Boots of the Eagle'),
(15534, 192883, 'Recipe: Wicked Chain Boots of the Whale'),
(15534, 192884, 'Recipe: Wicked Chain Boots of the Whale'),
(15534, 192885, 'Recipe: Wicked Chain Boots of the Monkey'),
(15534, 192886, 'Recipe: Wicked Chain Boots of the Gorilla'),
(15534, 192887, 'Recipe: Wicked Chain Boots of the Boar'),
(15534, 192888, 'Recipe: Wicked Chain Boots of the Eagle'),
(15534, 192889, 'Recipe: Wicked Chain Boots of the Whale'),
(10409, 192890, 'Recipe: Banded Boots of Stamina'),
(10409, 192891, 'Recipe: Banded Boots of the Tiger'),
(10409, 192892, 'Recipe: Banded Boots of the Monkey'),
(10409, 192893, 'Recipe: Banded Boots of the Gorilla'),
(10409, 192894, 'Recipe: Banded Boots of the Boar'),
(10409, 192895, 'Recipe: Banded Boots of the Bear'),
(10409, 192896, 'Recipe: Banded Boots of the Eagle'),
(10409, 192897, 'Recipe: Banded Boots of the Whale'),
(15544, 192898, 'Recipe: Thick Scale Sabatons of Stamina'),
(15544, 192899, 'Recipe: Thick Scale Sabatons of the Tiger'),
(15544, 192900, 'Recipe: Thick Scale Sabatons of the Monkey'),
(15544, 192901, 'Recipe: Thick Scale Sabatons of the Gorilla'),
(15544, 192902, 'Recipe: Thick Scale Sabatons of the Boar'),
(15544, 192903, 'Recipe: Thick Scale Sabatons of the Bear'),
(15544, 192904, 'Recipe: Thick Scale Sabatons of the Eagle'),
(15544, 192905, 'Recipe: Thick Scale Sabatons of the Whale'),
(15555, 192906, 'Recipe: Pillager''s Boots of Stamina'),
(7417, 192907, 'Recipe: Phalanx Boots of Stamina');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND `Reference` = 0;

INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `pickpocketing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `pickpocketing_loot_template` WHERE `Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND `Reference` = 0;

INSERT INTO `fishing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `fishing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `fishing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `fishing_loot_template` WHERE `Item` IN (15489, 6551, 9784, 6573, 9810, 15525, 6590, 15534, 10409, 15544, 15555, 7417) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
