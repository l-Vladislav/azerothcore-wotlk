-- Книги эскизов кольчуги Бронника: пояс
-- Поправки статов именных предметов (#272, карточка слота).
UPDATE `item_template` SET `stat_value1` = 8 WHERE `entry` = 6200 AND `stat_type1` = 4 AND `stat_value1` = 7;
UPDATE `item_template` SET `stat_value2` = 8 WHERE `entry` = 6200 AND `stat_type2` = 4 AND `stat_value2` = 7;
UPDATE `item_template` SET `stat_value3` = 8 WHERE `entry` = 6200 AND `stat_type3` = 4 AND `stat_value3` = 7;
UPDATE `item_template` SET `stat_value4` = 8 WHERE `entry` = 6200 AND `stat_type4` = 4 AND `stat_value4` = 7;
UPDATE `item_template` SET `stat_value5` = 8 WHERE `entry` = 6200 AND `stat_type5` = 4 AND `stat_value5` = 7;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1925310, 1925320, 1925410, 1925450, 1925980);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1925310, 192531, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Runescale Girdle'),
(1925310, 2840, 0, 33.3333, 0, 1, 1, 1, 1, 'Copper Bar'),
(1925310, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1925320, 192532, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Stormbringer Belt'),
(1925320, 2840, 0, 33.3333, 0, 1, 1, 1, 1, 'Copper Bar'),
(1925320, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1925320, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня'),
(1925410, 192541, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Warchief''s Girdle'),
(1925410, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1925410, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1925410, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня'),
(1925450, 192545, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Garneg''s War Belt'),
(1925450, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1925450, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1925450, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1925980, 192598, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Girdle of Golem Strength'),
(1925980, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1925980, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1925980, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(832, 192528, 'Recipe: Silver Defias Belt'),
(14725, 192529, 'Recipe: War Paint Waistband'),
(4697, 192530, 'Recipe: Burnished Girdle'),
(5425, 192531, 'Recipe: Runescale Girdle'),
(12978, 192532, 'Recipe: Stormbringer Belt'),
(14746, 192540, 'Recipe: Hulking Belt'),
(5750, 192541, 'Recipe: Warchief''s Girdle'),
(4707, 192542, 'Recipe: Lambent Scale Girdle'),
(14755, 192543, 'Recipe: Slayer''s Sash'),
(4712, 192544, 'Recipe: Glimmering Mail Girdle'),
(6200, 192545, 'Recipe: Garneg''s War Belt'),
(4717, 192596, 'Recipe: Mail Combat Belt'),
(14761, 192597, 'Recipe: Enduring Belt'),
(9405, 192598, 'Recipe: Girdle of Golem Strength');

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
(15492, 192533, 'Recipe: Bloodspattered Sash of the Tiger'),
(15492, 192534, 'Recipe: Bloodspattered Sash of the Monkey'),
(15492, 192535, 'Recipe: Bloodspattered Sash of the Gorilla'),
(15492, 192536, 'Recipe: Bloodspattered Sash of the Boar'),
(15492, 192537, 'Recipe: Bloodspattered Sash of the Eagle'),
(15492, 192538, 'Recipe: Bloodspattered Sash of the Whale'),
(6548, 192539, 'Recipe: Soldier''s Girdle of Strength'),
(6576, 192546, 'Recipe: Defender Girdle of Strength'),
(6576, 192547, 'Recipe: Defender Girdle of Strength'),
(6576, 192548, 'Recipe: Defender Girdle of the Tiger'),
(6576, 192549, 'Recipe: Defender Girdle of the Monkey'),
(6576, 192550, 'Recipe: Defender Girdle of the Gorilla'),
(6576, 192551, 'Recipe: Defender Girdle of the Boar'),
(6576, 192552, 'Recipe: Defender Girdle of the Bear'),
(6576, 192553, 'Recipe: Defender Girdle of the Eagle'),
(6576, 192554, 'Recipe: Defender Girdle of the Whale'),
(6576, 192555, 'Recipe: Defender Girdle of the Tiger'),
(6576, 192556, 'Recipe: Defender Girdle of the Monkey'),
(6576, 192557, 'Recipe: Defender Girdle of the Tiger'),
(6576, 192558, 'Recipe: Defender Girdle of the Monkey'),
(6576, 192559, 'Recipe: Defender Girdle of the Gorilla'),
(6576, 192560, 'Recipe: Defender Girdle of the Boar'),
(6576, 192561, 'Recipe: Defender Girdle of the Bear'),
(6576, 192562, 'Recipe: Defender Girdle of the Gorilla'),
(6576, 192563, 'Recipe: Defender Girdle of the Boar'),
(6576, 192564, 'Recipe: Defender Girdle of the Eagle'),
(6576, 192565, 'Recipe: Defender Girdle of the Eagle'),
(6576, 192566, 'Recipe: Defender Girdle of the Whale'),
(6576, 192567, 'Recipe: Defender Girdle of the Whale'),
(6576, 192568, 'Recipe: Defender Girdle of the Tiger'),
(6576, 192569, 'Recipe: Defender Girdle of the Monkey'),
(6576, 192570, 'Recipe: Defender Girdle of the Gorilla'),
(6576, 192571, 'Recipe: Defender Girdle of the Boar'),
(6576, 192572, 'Recipe: Defender Girdle of the Eagle'),
(6576, 192573, 'Recipe: Defender Girdle of the Whale'),
(6594, 192574, 'Recipe: Battleforge Girdle of Strength'),
(6594, 192575, 'Recipe: Battleforge Girdle of the Tiger'),
(6594, 192576, 'Recipe: Battleforge Girdle of the Monkey'),
(6594, 192577, 'Recipe: Battleforge Girdle of the Gorilla'),
(6594, 192578, 'Recipe: Battleforge Girdle of the Boar'),
(6594, 192579, 'Recipe: Battleforge Girdle of the Bear'),
(6594, 192580, 'Recipe: Battleforge Girdle of the Eagle'),
(6594, 192581, 'Recipe: Battleforge Girdle of the Whale'),
(6594, 192582, 'Recipe: Battleforge Girdle of the Tiger'),
(6594, 192583, 'Recipe: Battleforge Girdle of the Monkey'),
(6594, 192584, 'Recipe: Battleforge Girdle of the Tiger'),
(6594, 192585, 'Recipe: Battleforge Girdle of the Monkey'),
(6594, 192586, 'Recipe: Battleforge Girdle of the Gorilla'),
(6594, 192587, 'Recipe: Battleforge Girdle of the Boar'),
(6594, 192588, 'Recipe: Battleforge Girdle of the Bear'),
(6594, 192589, 'Recipe: Battleforge Girdle of the Gorilla'),
(6594, 192590, 'Recipe: Battleforge Girdle of the Boar'),
(6594, 192591, 'Recipe: Battleforge Girdle of the Bear'),
(6594, 192592, 'Recipe: Battleforge Girdle of the Eagle'),
(6594, 192593, 'Recipe: Battleforge Girdle of the Eagle'),
(6594, 192594, 'Recipe: Battleforge Girdle of the Whale'),
(6594, 192595, 'Recipe: Battleforge Girdle of the Whale'),
(15539, 192599, 'Recipe: Wicked Chain Waistband of Strength'),
(15539, 192600, 'Recipe: Wicked Chain Waistband of the Tiger'),
(15539, 192601, 'Recipe: Wicked Chain Waistband of the Monkey'),
(15539, 192602, 'Recipe: Wicked Chain Waistband of the Gorilla'),
(15539, 192603, 'Recipe: Wicked Chain Waistband of the Boar'),
(15539, 192604, 'Recipe: Wicked Chain Waistband of the Bear'),
(15539, 192605, 'Recipe: Wicked Chain Waistband of the Eagle'),
(15539, 192606, 'Recipe: Wicked Chain Waistband of the Whale'),
(15539, 192607, 'Recipe: Wicked Chain Waistband of the Tiger'),
(15539, 192608, 'Recipe: Wicked Chain Waistband of the Monkey'),
(15539, 192609, 'Recipe: Wicked Chain Waistband of the Tiger'),
(15539, 192610, 'Recipe: Wicked Chain Waistband of the Monkey'),
(15539, 192611, 'Recipe: Wicked Chain Waistband of the Gorilla'),
(15539, 192612, 'Recipe: Wicked Chain Waistband of the Boar'),
(15539, 192613, 'Recipe: Wicked Chain Waistband of the Bear'),
(15539, 192614, 'Recipe: Wicked Chain Waistband of the Gorilla'),
(15539, 192615, 'Recipe: Wicked Chain Waistband of the Boar'),
(15539, 192616, 'Recipe: Wicked Chain Waistband of the Eagle'),
(15539, 192617, 'Recipe: Wicked Chain Waistband of the Eagle'),
(15539, 192618, 'Recipe: Wicked Chain Waistband of the Whale'),
(15539, 192619, 'Recipe: Wicked Chain Waistband of the Whale'),
(15539, 192620, 'Recipe: Wicked Chain Waistband of the Tiger'),
(15539, 192621, 'Recipe: Wicked Chain Waistband of the Monkey'),
(15539, 192622, 'Recipe: Wicked Chain Waistband of the Gorilla'),
(15539, 192623, 'Recipe: Wicked Chain Waistband of the Boar'),
(15539, 192624, 'Recipe: Wicked Chain Waistband of the Bear'),
(15539, 192625, 'Recipe: Wicked Chain Waistband of the Eagle'),
(15539, 192626, 'Recipe: Wicked Chain Waistband of the Whale'),
(9840, 192627, 'Recipe: Banded Girdle of Strength'),
(9840, 192628, 'Recipe: Banded Girdle of the Tiger'),
(9840, 192629, 'Recipe: Banded Girdle of the Monkey'),
(9840, 192630, 'Recipe: Banded Girdle of the Gorilla'),
(9840, 192631, 'Recipe: Banded Girdle of the Boar'),
(9840, 192632, 'Recipe: Banded Girdle of the Bear'),
(9840, 192633, 'Recipe: Banded Girdle of the Eagle'),
(9840, 192634, 'Recipe: Banded Girdle of the Whale'),
(15549, 192635, 'Recipe: Thick Scale Belt of Strength'),
(15549, 192636, 'Recipe: Thick Scale Belt of the Tiger'),
(15549, 192637, 'Recipe: Thick Scale Belt of the Monkey'),
(15549, 192638, 'Recipe: Thick Scale Belt of the Gorilla'),
(15549, 192639, 'Recipe: Thick Scale Belt of the Boar'),
(15549, 192640, 'Recipe: Thick Scale Belt of the Bear'),
(15549, 192641, 'Recipe: Thick Scale Belt of the Eagle'),
(15549, 192642, 'Recipe: Thick Scale Belt of the Whale'),
(7422, 192643, 'Recipe: Phalanx Girdle of Strength'),
(15554, 192644, 'Recipe: Pillager''s Girdle of Strength');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND `Reference` = 0;

INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `pickpocketing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `pickpocketing_loot_template` WHERE `Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND `Reference` = 0;

INSERT INTO `fishing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `fishing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `fishing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `fishing_loot_template` WHERE `Item` IN (15492, 6548, 6576, 6594, 15539, 9840, 15549, 7422, 15554) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
