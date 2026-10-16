-- Книги эскизов кольчуги Бронника: наплечники

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1922540, 1922580);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1922540, 192254, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Cutthroat Pauldrons'),
(1922540, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1922540, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1922540, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone'),
(1922580, 192258, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Sparkleshell Mantle'),
(1922580, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1922580, 1529, 0, 0, 0, 1, 1, 1, 1, 'Jade'),
(1922580, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(3231, 192254, 'Recipe: Cutthroat Pauldrons'),
(3481, 192255, 'Recipe: Silvered Bronze Shoulders'),
(14749, 192256, 'Recipe: Hulking Spaulders'),
(4705, 192257, 'Recipe: Lambent Scale Pauldrons'),
(13131, 192258, 'Recipe: Sparkleshell Mantle'),
(6388, 192313, 'Recipe: Glimmering Mail Pauldrons'),
(14758, 192314, 'Recipe: Slayer''s Shoulderguards'),
(3840, 192315, 'Recipe: Green Iron Shoulders'),
(7913, 192316, 'Recipe: Barbaric Iron Shoulders'),
(3841, 192317, 'Recipe: Golden Scale Shoulders'),
(6404, 192318, 'Recipe: Mail Combat Spaulders');

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
(15513, 192259, 'Recipe: Grunt''s Pauldrons of Stamina'),
(15513, 192260, 'Recipe: Grunt''s Pauldrons of Stamina'),
(15513, 192261, 'Recipe: Grunt''s Pauldrons of the Tiger'),
(15513, 192262, 'Recipe: Grunt''s Pauldrons of the Monkey'),
(15513, 192263, 'Recipe: Grunt''s Pauldrons of the Gorilla'),
(15513, 192264, 'Recipe: Grunt''s Pauldrons of the Boar'),
(15513, 192265, 'Recipe: Grunt''s Pauldrons of the Bear'),
(15513, 192266, 'Recipe: Grunt''s Pauldrons of the Eagle'),
(15513, 192267, 'Recipe: Grunt''s Pauldrons of the Whale'),
(15513, 192268, 'Recipe: Grunt''s Pauldrons of the Tiger'),
(15513, 192269, 'Recipe: Grunt''s Pauldrons of the Monkey'),
(15513, 192270, 'Recipe: Grunt''s Pauldrons of the Tiger'),
(15513, 192271, 'Recipe: Grunt''s Pauldrons of the Monkey'),
(15513, 192272, 'Recipe: Grunt''s Pauldrons of the Gorilla'),
(15513, 192273, 'Recipe: Grunt''s Pauldrons of the Boar'),
(15513, 192274, 'Recipe: Grunt''s Pauldrons of the Bear'),
(15513, 192275, 'Recipe: Grunt''s Pauldrons of the Gorilla'),
(15513, 192276, 'Recipe: Grunt''s Pauldrons of the Bear'),
(15513, 192277, 'Recipe: Grunt''s Pauldrons of the Eagle'),
(15513, 192278, 'Recipe: Grunt''s Pauldrons of the Eagle'),
(15513, 192279, 'Recipe: Grunt''s Pauldrons of the Whale'),
(15513, 192280, 'Recipe: Grunt''s Pauldrons of the Whale'),
(15513, 192281, 'Recipe: Grunt''s Pauldrons of the Tiger'),
(15513, 192282, 'Recipe: Grunt''s Pauldrons of the Monkey'),
(15513, 192283, 'Recipe: Grunt''s Pauldrons of the Gorilla'),
(15513, 192284, 'Recipe: Grunt''s Pauldrons of the Boar'),
(15513, 192285, 'Recipe: Grunt''s Pauldrons of the Eagle'),
(15513, 192286, 'Recipe: Grunt''s Pauldrons of the Whale'),
(9817, 192287, 'Recipe: Fortified Spaulders of Stamina'),
(9817, 192288, 'Recipe: Fortified Spaulders of Stamina'),
(15523, 192289, 'Recipe: Spiked Chain Shoulder Pads of Stamina'),
(15523, 192290, 'Recipe: Spiked Chain Shoulder Pads of Stamina'),
(6597, 192291, 'Recipe: Battleforge Shoulderguards of Stamina'),
(6597, 192292, 'Recipe: Battleforge Shoulderguards of the Tiger'),
(6597, 192293, 'Recipe: Battleforge Shoulderguards of the Monkey'),
(6597, 192294, 'Recipe: Battleforge Shoulderguards of the Gorilla'),
(6597, 192295, 'Recipe: Battleforge Shoulderguards of the Bear'),
(6597, 192296, 'Recipe: Battleforge Shoulderguards of the Owl'),
(6597, 192297, 'Recipe: Battleforge Shoulderguards of the Eagle'),
(6597, 192298, 'Recipe: Battleforge Shoulderguards of the Whale'),
(6597, 192299, 'Recipe: Battleforge Shoulderguards of the Tiger'),
(6597, 192300, 'Recipe: Battleforge Shoulderguards of the Monkey'),
(6597, 192301, 'Recipe: Battleforge Shoulderguards of the Tiger'),
(6597, 192302, 'Recipe: Battleforge Shoulderguards of the Monkey'),
(6597, 192303, 'Recipe: Battleforge Shoulderguards of the Gorilla'),
(6597, 192304, 'Recipe: Battleforge Shoulderguards of the Boar'),
(6597, 192305, 'Recipe: Battleforge Shoulderguards of the Bear'),
(6597, 192306, 'Recipe: Battleforge Shoulderguards of the Gorilla'),
(6597, 192307, 'Recipe: Battleforge Shoulderguards of the Boar'),
(6597, 192308, 'Recipe: Battleforge Shoulderguards of the Bear'),
(6597, 192309, 'Recipe: Battleforge Shoulderguards of the Eagle'),
(6597, 192310, 'Recipe: Battleforge Shoulderguards of the Eagle'),
(6597, 192311, 'Recipe: Battleforge Shoulderguards of the Whale'),
(6597, 192312, 'Recipe: Battleforge Shoulderguards of the Whale'),
(15531, 192319, 'Recipe: Sentry''s Shoulderguards of Stamina'),
(15531, 192320, 'Recipe: Sentry''s Shoulderguards of the Tiger'),
(15531, 192321, 'Recipe: Sentry''s Shoulderguards of the Monkey'),
(15531, 192322, 'Recipe: Sentry''s Shoulderguards of the Gorilla'),
(15531, 192323, 'Recipe: Sentry''s Shoulderguards of the Boar'),
(15531, 192324, 'Recipe: Sentry''s Shoulderguards of the Bear'),
(15531, 192325, 'Recipe: Sentry''s Shoulderguards of the Owl'),
(15531, 192326, 'Recipe: Sentry''s Shoulderguards of the Eagle'),
(15531, 192327, 'Recipe: Sentry''s Shoulderguards of the Whale'),
(15531, 192328, 'Recipe: Sentry''s Shoulderguards of the Tiger'),
(15531, 192329, 'Recipe: Sentry''s Shoulderguards of the Monkey'),
(15531, 192330, 'Recipe: Sentry''s Shoulderguards of the Tiger'),
(15531, 192331, 'Recipe: Sentry''s Shoulderguards of the Monkey'),
(15531, 192332, 'Recipe: Sentry''s Shoulderguards of the Gorilla'),
(15531, 192333, 'Recipe: Sentry''s Shoulderguards of the Boar'),
(15531, 192334, 'Recipe: Sentry''s Shoulderguards of the Bear'),
(15531, 192335, 'Recipe: Sentry''s Shoulderguards of the Gorilla'),
(15531, 192336, 'Recipe: Sentry''s Shoulderguards of the Boar'),
(15531, 192337, 'Recipe: Sentry''s Shoulderguards of the Bear'),
(15531, 192338, 'Recipe: Sentry''s Shoulderguards of the Eagle'),
(15531, 192339, 'Recipe: Sentry''s Shoulderguards of the Eagle'),
(15531, 192340, 'Recipe: Sentry''s Shoulderguards of the Whale'),
(15531, 192341, 'Recipe: Sentry''s Shoulderguards of the Whale'),
(15531, 192342, 'Recipe: Sentry''s Shoulderguards of the Monkey'),
(15531, 192343, 'Recipe: Sentry''s Shoulderguards of the Gorilla'),
(15531, 192344, 'Recipe: Sentry''s Shoulderguards of the Eagle'),
(15531, 192345, 'Recipe: Sentry''s Shoulderguards of the Whale'),
(9842, 192346, 'Recipe: Banded Pauldrons of Stamina'),
(9842, 192347, 'Recipe: Banded Pauldrons of the Tiger'),
(9842, 192348, 'Recipe: Banded Pauldrons of the Monkey'),
(9842, 192349, 'Recipe: Banded Pauldrons of the Gorilla'),
(9842, 192350, 'Recipe: Banded Pauldrons of the Boar'),
(9842, 192351, 'Recipe: Banded Pauldrons of the Bear'),
(9842, 192352, 'Recipe: Banded Pauldrons of the Eagle'),
(9842, 192353, 'Recipe: Banded Pauldrons of the Whale'),
(15542, 192354, 'Recipe: Wicked Chain Shoulder Pads of Stamina'),
(15542, 192355, 'Recipe: Wicked Chain Shoulder Pads of the Tiger'),
(15542, 192356, 'Recipe: Wicked Chain Shoulder Pads of the Monkey'),
(15542, 192357, 'Recipe: Wicked Chain Shoulder Pads of the Gorilla'),
(15542, 192358, 'Recipe: Wicked Chain Shoulder Pads of the Boar'),
(15542, 192359, 'Recipe: Wicked Chain Shoulder Pads of the Bear'),
(15542, 192360, 'Recipe: Wicked Chain Shoulder Pads of the Eagle'),
(15542, 192361, 'Recipe: Wicked Chain Shoulder Pads of the Whale'),
(7424, 192362, 'Recipe: Phalanx Spaulders of Stamina'),
(7424, 192363, 'Recipe: Phalanx Spaulders of the Bear'),
(15553, 192364, 'Recipe: Thick Scale Shoulder Pads of Stamina');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND `Reference` = 0;

INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `pickpocketing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `pickpocketing_loot_template` WHERE `Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND `Reference` = 0;

INSERT INTO `fishing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `fishing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `fishing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `fishing_loot_template` WHERE `Item` IN (15513, 9817, 15523, 6597, 15531, 9842, 15542, 7424, 15553) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
