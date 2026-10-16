-- Книги эскизов кольчуги Бронника: перчатки
-- Поправки статов именных предметов (#272, карточка слота).
UPDATE `item_template` SET `stat_value1` = 4 WHERE `entry` = 4676 AND `stat_type1` = 4 AND `stat_value1` = 3;
UPDATE `item_template` SET `stat_value2` = 4 WHERE `entry` = 4676 AND `stat_type2` = 4 AND `stat_value2` = 3;
UPDATE `item_template` SET `stat_value3` = 4 WHERE `entry` = 4676 AND `stat_type3` = 4 AND `stat_value3` = 3;
UPDATE `item_template` SET `stat_value4` = 4 WHERE `entry` = 4676 AND `stat_type4` = 4 AND `stat_value4` = 3;
UPDATE `item_template` SET `stat_value5` = 4 WHERE `entry` = 4676 AND `stat_type5` = 4 AND `stat_value5` = 3;
UPDATE `item_template` SET `stat_value1` = 4 WHERE `entry` = 14726 AND `stat_type1` = 4 AND `stat_value1` = 3;
UPDATE `item_template` SET `stat_value2` = 4 WHERE `entry` = 14726 AND `stat_type2` = 4 AND `stat_value2` = 3;
UPDATE `item_template` SET `stat_value3` = 4 WHERE `entry` = 14726 AND `stat_type3` = 4 AND `stat_value3` = 3;
UPDATE `item_template` SET `stat_value4` = 4 WHERE `entry` = 14726 AND `stat_type4` = 4 AND `stat_value4` = 3;
UPDATE `item_template` SET `stat_value5` = 4 WHERE `entry` = 14726 AND `stat_type5` = 4 AND `stat_value5` = 3;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1930790, 1931410);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1930790, 193079, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Thorbia''s Gauntlets'),
(1930790, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1930790, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1931410, 193141, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Felstrom''s Gauntlets'),
(1931410, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1931410, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(2980, 193059, 'Recipe: Veteran Gloves'),
(2274, 193060, 'Recipe: Sapper''s Gloves'),
(4676, 193061, 'Recipe: Skeletal Gauntlets'),
(14726, 193062, 'Recipe: War Paint Gloves'),
(1448, 193063, 'Recipe: Blackrock Gauntlets'),
(2992, 193064, 'Recipe: Burnished Gloves'),
(14747, 193073, 'Recipe: Hulking Gauntlets'),
(5822, 193074, 'Recipe: Hedgeseed Gauntlets'),
(3047, 193075, 'Recipe: Lambent Scale Gloves'),
(3483, 193076, 'Recipe: Silvered Bronze Gauntlets'),
(6733, 193077, 'Recipe: Ironforge Gauntlets'),
(14754, 193078, 'Recipe: Slayer''s Gloves'),
(12994, 193079, 'Recipe: Thorbia''s Gauntlets'),
(3485, 193138, 'Recipe: Green Iron Gauntlets'),
(4072, 193139, 'Recipe: Glimmering Mail Gauntlets'),
(3341, 193140, 'Recipe: Gauntlets of Ogre Strength'),
(4465, 193141, 'Recipe: Felstrom''s Gauntlets'),
(4075, 193142, 'Recipe: Mail Combat Gauntlets'),
(14764, 193143, 'Recipe: Enduring Gauntlets');

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
(3474, 193065, 'Recipe: Gemmed Copper Gauntlets of the Monkey'),
(3474, 193066, 'Recipe: Gemmed Copper Gauntlets of the Gorilla'),
(3474, 193067, 'Recipe: Gemmed Copper Gauntlets of the Boar'),
(3474, 193068, 'Recipe: Gemmed Copper Gauntlets of the Bear'),
(3474, 193069, 'Recipe: Gemmed Copper Gauntlets of the Eagle'),
(3474, 193070, 'Recipe: Gemmed Copper Gauntlets of the Whale'),
(6547, 193071, 'Recipe: Soldier''s Gauntlets of the Wolf'),
(6547, 193072, 'Recipe: Soldier''s Gauntlets of Strength'),
(6577, 193080, 'Recipe: Defender Gauntlets of Strength'),
(6577, 193081, 'Recipe: Defender Gauntlets of Strength'),
(6577, 193082, 'Recipe: Defender Gauntlets of the Tiger'),
(6577, 193083, 'Recipe: Defender Gauntlets of the Monkey'),
(6577, 193084, 'Recipe: Defender Gauntlets of the Gorilla'),
(6577, 193085, 'Recipe: Defender Gauntlets of the Boar'),
(6577, 193086, 'Recipe: Defender Gauntlets of the Bear'),
(6577, 193087, 'Recipe: Defender Gauntlets of the Eagle'),
(6577, 193088, 'Recipe: Defender Gauntlets of the Whale'),
(6577, 193089, 'Recipe: Defender Gauntlets of the Monkey'),
(6577, 193090, 'Recipe: Defender Gauntlets of the Tiger'),
(6577, 193091, 'Recipe: Defender Gauntlets of the Monkey'),
(6577, 193092, 'Recipe: Defender Gauntlets of the Gorilla'),
(6577, 193093, 'Recipe: Defender Gauntlets of the Boar'),
(6577, 193094, 'Recipe: Defender Gauntlets of the Bear'),
(6577, 193095, 'Recipe: Defender Gauntlets of the Gorilla'),
(6577, 193096, 'Recipe: Defender Gauntlets of the Boar'),
(6577, 193097, 'Recipe: Defender Gauntlets of the Eagle'),
(6577, 193098, 'Recipe: Defender Gauntlets of the Eagle'),
(6577, 193099, 'Recipe: Defender Gauntlets of the Whale'),
(6577, 193100, 'Recipe: Defender Gauntlets of the Whale'),
(6577, 193101, 'Recipe: Defender Gauntlets of the Tiger'),
(6577, 193102, 'Recipe: Defender Gauntlets of the Monkey'),
(6577, 193103, 'Recipe: Defender Gauntlets of the Gorilla'),
(6577, 193104, 'Recipe: Defender Gauntlets of the Boar'),
(6577, 193105, 'Recipe: Defender Gauntlets of the Bear'),
(6577, 193106, 'Recipe: Defender Gauntlets of the Eagle'),
(9813, 193107, 'Recipe: Fortified Gauntlets of Agility'),
(9813, 193108, 'Recipe: Fortified Gauntlets of Strength'),
(9813, 193109, 'Recipe: Fortified Gauntlets of the Owl'),
(9813, 193110, 'Recipe: Fortified Gauntlets of Strength'),
(15520, 193111, 'Recipe: Spiked Chain Gauntlets of Agility'),
(15520, 193112, 'Recipe: Spiked Chain Gauntlets of the Owl'),
(15527, 193113, 'Recipe: Sentry''s Gloves of Agility'),
(15527, 193114, 'Recipe: Sentry''s Gloves of the Owl'),
(6595, 193115, 'Recipe: Battleforge Gauntlets of Strength'),
(6595, 193116, 'Recipe: Battleforge Gauntlets of the Tiger'),
(6595, 193117, 'Recipe: Battleforge Gauntlets of the Monkey'),
(6595, 193118, 'Recipe: Battleforge Gauntlets of the Gorilla'),
(6595, 193119, 'Recipe: Battleforge Gauntlets of the Boar'),
(6595, 193120, 'Recipe: Battleforge Gauntlets of the Bear'),
(6595, 193121, 'Recipe: Battleforge Gauntlets of the Eagle'),
(6595, 193122, 'Recipe: Battleforge Gauntlets of the Whale'),
(6595, 193123, 'Recipe: Battleforge Gauntlets of the Tiger'),
(6595, 193124, 'Recipe: Battleforge Gauntlets of the Monkey'),
(6595, 193125, 'Recipe: Battleforge Gauntlets of the Tiger'),
(6595, 193126, 'Recipe: Battleforge Gauntlets of the Monkey'),
(6595, 193127, 'Recipe: Battleforge Gauntlets of the Gorilla'),
(6595, 193128, 'Recipe: Battleforge Gauntlets of the Boar'),
(6595, 193129, 'Recipe: Battleforge Gauntlets of the Bear'),
(6595, 193130, 'Recipe: Battleforge Gauntlets of the Gorilla'),
(6595, 193131, 'Recipe: Battleforge Gauntlets of the Boar'),
(6595, 193132, 'Recipe: Battleforge Gauntlets of the Bear'),
(6595, 193133, 'Recipe: Battleforge Gauntlets of the Owl'),
(6595, 193134, 'Recipe: Battleforge Gauntlets of the Eagle'),
(6595, 193135, 'Recipe: Battleforge Gauntlets of the Eagle'),
(6595, 193136, 'Recipe: Battleforge Gauntlets of the Whale'),
(6595, 193137, 'Recipe: Battleforge Gauntlets of the Whale'),
(15538, 193144, 'Recipe: Wicked Chain Gauntlets of Strength'),
(15538, 193145, 'Recipe: Wicked Chain Gauntlets of the Tiger'),
(15538, 193146, 'Recipe: Wicked Chain Gauntlets of the Monkey'),
(15538, 193147, 'Recipe: Wicked Chain Gauntlets of the Gorilla'),
(15538, 193148, 'Recipe: Wicked Chain Gauntlets of the Boar'),
(15538, 193149, 'Recipe: Wicked Chain Gauntlets of the Bear'),
(15538, 193150, 'Recipe: Wicked Chain Gauntlets of the Owl'),
(15538, 193151, 'Recipe: Wicked Chain Gauntlets of the Eagle'),
(15538, 193152, 'Recipe: Wicked Chain Gauntlets of the Whale'),
(15538, 193153, 'Recipe: Wicked Chain Gauntlets of the Tiger'),
(15538, 193154, 'Recipe: Wicked Chain Gauntlets of the Monkey'),
(15538, 193155, 'Recipe: Wicked Chain Gauntlets of the Tiger'),
(15538, 193156, 'Recipe: Wicked Chain Gauntlets of the Monkey'),
(15538, 193157, 'Recipe: Wicked Chain Gauntlets of the Gorilla'),
(15538, 193158, 'Recipe: Wicked Chain Gauntlets of the Boar'),
(15538, 193159, 'Recipe: Wicked Chain Gauntlets of the Bear'),
(15538, 193160, 'Recipe: Wicked Chain Gauntlets of the Gorilla'),
(15538, 193161, 'Recipe: Wicked Chain Gauntlets of the Boar'),
(15538, 193162, 'Recipe: Wicked Chain Gauntlets of the Bear'),
(15538, 193163, 'Recipe: Wicked Chain Gauntlets of the Eagle'),
(15538, 193164, 'Recipe: Wicked Chain Gauntlets of the Eagle'),
(15538, 193165, 'Recipe: Wicked Chain Gauntlets of the Whale'),
(15538, 193166, 'Recipe: Wicked Chain Gauntlets of the Whale'),
(15538, 193167, 'Recipe: Wicked Chain Gauntlets of the Monkey'),
(15538, 193168, 'Recipe: Wicked Chain Gauntlets of the Gorilla'),
(15538, 193169, 'Recipe: Wicked Chain Gauntlets of the Boar'),
(15538, 193170, 'Recipe: Wicked Chain Gauntlets of the Eagle'),
(15538, 193171, 'Recipe: Wicked Chain Gauntlets of the Whale'),
(9839, 193172, 'Recipe: Banded Gauntlets of Strength'),
(9839, 193173, 'Recipe: Banded Gauntlets of the Monkey'),
(9839, 193174, 'Recipe: Banded Gauntlets of the Tiger'),
(9839, 193175, 'Recipe: Banded Gauntlets of the Gorilla'),
(9839, 193176, 'Recipe: Banded Gauntlets of the Boar'),
(9839, 193177, 'Recipe: Banded Gauntlets of the Bear'),
(9839, 193178, 'Recipe: Banded Gauntlets of the Eagle'),
(9839, 193179, 'Recipe: Banded Gauntlets of the Whale'),
(9839, 193180, 'Recipe: Banded Gauntlets of the Tiger'),
(15548, 193181, 'Recipe: Thick Scale Gauntlets of Strength'),
(15548, 193182, 'Recipe: Thick Scale Gauntlets of the Monkey'),
(15548, 193183, 'Recipe: Thick Scale Gauntlets of the Gorilla'),
(15548, 193184, 'Recipe: Thick Scale Gauntlets of the Boar'),
(15548, 193185, 'Recipe: Thick Scale Gauntlets of the Bear'),
(15548, 193186, 'Recipe: Thick Scale Gauntlets of the Eagle'),
(15548, 193187, 'Recipe: Thick Scale Gauntlets of the Whale'),
(7421, 193188, 'Recipe: Phalanx Gauntlets of Strength'),
(15560, 193189, 'Recipe: Pillager''s Gloves of Strength');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND `Reference` = 0;

INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `pickpocketing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `pickpocketing_loot_template` WHERE `Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND `Reference` = 0;

INSERT INTO `fishing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `fishing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `fishing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `fishing_loot_template` WHERE `Item` IN (3474, 6547, 6577, 9813, 15520, 15527, 6595, 15538, 9839, 15548, 7421, 15560) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
