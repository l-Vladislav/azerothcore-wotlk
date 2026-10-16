-- Книги эскизов кольчуги Бронника: нагрудник
-- Поправки статов именных предметов (#272, карточка слота).
UPDATE `item_template` SET `stat_value1` = 2 WHERE `entry` = 3471 AND `stat_type1` = 4 AND `stat_value1` = 1;
UPDATE `item_template` SET `stat_value2` = 2 WHERE `entry` = 3471 AND `stat_type2` = 4 AND `stat_value2` = 1;
UPDATE `item_template` SET `stat_value3` = 2 WHERE `entry` = 3471 AND `stat_type3` = 4 AND `stat_value3` = 1;
UPDATE `item_template` SET `stat_value4` = 2 WHERE `entry` = 3471 AND `stat_type4` = 4 AND `stat_value4` = 1;
UPDATE `item_template` SET `stat_value5` = 2 WHERE `entry` = 3471 AND `stat_type5` = 4 AND `stat_value5` = 1;
UPDATE `item_template` SET `stat_value1` = 3 WHERE `entry` = 2965 AND `stat_type1` = 4 AND `stat_value1` = 2;
UPDATE `item_template` SET `stat_value2` = 3 WHERE `entry` = 2965 AND `stat_type2` = 4 AND `stat_value2` = 2;
UPDATE `item_template` SET `stat_value3` = 3 WHERE `entry` = 2965 AND `stat_type3` = 4 AND `stat_value3` = 2;
UPDATE `item_template` SET `stat_value4` = 3 WHERE `entry` = 2965 AND `stat_type4` = 4 AND `stat_value4` = 2;
UPDATE `item_template` SET `stat_value5` = 3 WHERE `entry` = 2965 AND `stat_type5` = 4 AND `stat_value5` = 2;
UPDATE `item_template` SET `stat_value1` = 2 WHERE `entry` = 3330 AND `stat_type1` = 7 AND `stat_value1` = 1;
UPDATE `item_template` SET `stat_value2` = 2 WHERE `entry` = 3330 AND `stat_type2` = 7 AND `stat_value2` = 1;
UPDATE `item_template` SET `stat_value3` = 2 WHERE `entry` = 3330 AND `stat_type3` = 7 AND `stat_value3` = 1;
UPDATE `item_template` SET `stat_value4` = 2 WHERE `entry` = 3330 AND `stat_type4` = 7 AND `stat_value4` = 1;
UPDATE `item_template` SET `stat_value5` = 2 WHERE `entry` = 3330 AND `stat_type5` = 7 AND `stat_value5` = 1;
UPDATE `item_template` SET `stat_value1` = 4 WHERE `entry` = 2977 AND `stat_type1` = 4 AND `stat_value1` = 3;
UPDATE `item_template` SET `stat_value2` = 4 WHERE `entry` = 2977 AND `stat_type2` = 4 AND `stat_value2` = 3;
UPDATE `item_template` SET `stat_value3` = 4 WHERE `entry` = 2977 AND `stat_type3` = 4 AND `stat_value3` = 3;
UPDATE `item_template` SET `stat_value4` = 4 WHERE `entry` = 2977 AND `stat_type4` = 4 AND `stat_value4` = 3;
UPDATE `item_template` SET `stat_value5` = 4 WHERE `entry` = 2977 AND `stat_type5` = 4 AND `stat_value5` = 3;
UPDATE `item_template` SET `stat_value1` = 5 WHERE `entry` = 3306 AND `stat_type1` = 4 AND `stat_value1` = 4;
UPDATE `item_template` SET `stat_value2` = 5 WHERE `entry` = 3306 AND `stat_type2` = 4 AND `stat_value2` = 4;
UPDATE `item_template` SET `stat_value3` = 5 WHERE `entry` = 3306 AND `stat_type3` = 4 AND `stat_value3` = 4;
UPDATE `item_template` SET `stat_value4` = 5 WHERE `entry` = 3306 AND `stat_type4` = 4 AND `stat_value4` = 4;
UPDATE `item_template` SET `stat_value5` = 5 WHERE `entry` = 3306 AND `stat_type5` = 4 AND `stat_value5` = 4;
UPDATE `item_template` SET `stat_value1` = 9 WHERE `entry` = 14744 AND `stat_type1` = 7 AND `stat_value1` = 8;
UPDATE `item_template` SET `stat_value2` = 9 WHERE `entry` = 14744 AND `stat_type2` = 7 AND `stat_value2` = 8;
UPDATE `item_template` SET `stat_value3` = 9 WHERE `entry` = 14744 AND `stat_type3` = 7 AND `stat_value3` = 8;
UPDATE `item_template` SET `stat_value4` = 9 WHERE `entry` = 14744 AND `stat_type4` = 7 AND `stat_value4` = 8;
UPDATE `item_template` SET `stat_value5` = 9 WHERE `entry` = 14744 AND `stat_type5` = 7 AND `stat_value5` = 8;
UPDATE `item_template` SET `stat_value1` = 6 WHERE `entry` = 14744 AND `stat_type1` = 4 AND `stat_value1` = 5;
UPDATE `item_template` SET `stat_value2` = 6 WHERE `entry` = 14744 AND `stat_type2` = 4 AND `stat_value2` = 5;
UPDATE `item_template` SET `stat_value3` = 6 WHERE `entry` = 14744 AND `stat_type3` = 4 AND `stat_value3` = 5;
UPDATE `item_template` SET `stat_value4` = 6 WHERE `entry` = 14744 AND `stat_type4` = 4 AND `stat_value4` = 5;
UPDATE `item_template` SET `stat_value5` = 6 WHERE `entry` = 14744 AND `stat_type5` = 4 AND `stat_value5` = 5;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1923660, 1923820, 1923830, 1924120, 1924820);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1923660, 192366, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Warrior''s Tunic'),
(1923660, 2840, 0, 33.3333, 0, 1, 1, 1, 1, 'Copper Bar'),
(1923660, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1923820, 192382, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Slarkskin'),
(1923820, 2840, 0, 33.3333, 0, 1, 1, 1, 1, 'Copper Bar'),
(1923820, 774, 0, 0, 0, 1, 1, 1, 1, 'Malachite'),
(1923820, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня'),
(1923830, 192383, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Wax-polished Armor'),
(1923830, 2840, 0, 33.3333, 0, 1, 1, 1, 1, 'Copper Bar'),
(1923830, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1923830, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня'),
(1924120, 192412, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Husk of Naraxis'),
(1924120, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1924120, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1924120, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone'),
(1924820, 192482, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Double Link Tunic'),
(1924820, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1924820, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня'),
(1924820, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(3471, 192365, 'Recipe: Copper Chain Vest'),
(2965, 192366, 'Recipe: Warrior''s Tunic'),
(3330, 192367, 'Recipe: Dargol''s Hauberk'),
(2273, 192381, 'Recipe: Guerrilla Armor'),
(6180, 192382, 'Recipe: Slarkskin'),
(6195, 192383, 'Recipe: Wax-polished Armor'),
(2977, 192384, 'Recipe: Veteran Armor'),
(6730, 192385, 'Recipe: Ironforge Chain'),
(2864, 192386, 'Recipe: Runed Copper Breastplate'),
(3306, 192387, 'Recipe: Brackwater Vest'),
(6731, 192388, 'Recipe: Ironforge Breastplate'),
(2989, 192389, 'Recipe: Burnished Tunic'),
(14730, 192408, 'Recipe: War Paint Chestpiece'),
(2016, 192409, 'Recipe: Dusty Chain Armor'),
(2869, 192410, 'Recipe: Silvered Bronze Breastplate'),
(3049, 192411, 'Recipe: Lambent Scale Breastplate'),
(4448, 192412, 'Recipe: Husk of Naraxis'),
(3053, 192413, 'Recipe: Humbert''s Chestpiece'),
(14744, 192414, 'Recipe: Hulking Chestguard'),
(2870, 192415, 'Recipe: Shining Silver Breastplate'),
(914, 192477, 'Recipe: Large Ogre Chain Armor'),
(4071, 192478, 'Recipe: Glimmering Mail Breastplate'),
(7914, 192479, 'Recipe: Barbaric Iron Breastplate'),
(14751, 192480, 'Recipe: Slayer''s Surcoat'),
(5755, 192481, 'Recipe: Onyx Shredder Plate'),
(1717, 192482, 'Recipe: Double Link Tunic');

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
(6336, 192368, 'Recipe: Infantry Tunic of Agility'),
(6336, 192369, 'Recipe: Infantry Tunic of Intellect'),
(6336, 192370, 'Recipe: Infantry Tunic of the Tiger'),
(6336, 192371, 'Recipe: Infantry Tunic of the Falcon'),
(6336, 192372, 'Recipe: Infantry Tunic of the Monkey'),
(6336, 192373, 'Recipe: Infantry Tunic of Strength'),
(6336, 192374, 'Recipe: Infantry Tunic of the Gorilla'),
(6336, 192375, 'Recipe: Infantry Tunic of the Boar'),
(6336, 192376, 'Recipe: Infantry Tunic of the Bear'),
(6336, 192377, 'Recipe: Infantry Tunic of the Owl'),
(6336, 192378, 'Recipe: Infantry Tunic of the Eagle'),
(6336, 192379, 'Recipe: Infantry Tunic of the Whale'),
(6336, 192380, 'Recipe: Infantry Tunic of Stamina'),
(9765, 192390, 'Recipe: Cadet Vest of Agility'),
(9765, 192391, 'Recipe: Cadet Vest of Strength'),
(9765, 192392, 'Recipe: Cadet Vest of Intellect'),
(9765, 192393, 'Recipe: Cadet Vest of Stamina'),
(9765, 192394, 'Recipe: Cadet Vest of the Tiger'),
(9765, 192395, 'Recipe: Cadet Vest of the Falcon'),
(9765, 192396, 'Recipe: Cadet Vest of Strength'),
(9765, 192397, 'Recipe: Cadet Vest of the Gorilla'),
(9765, 192398, 'Recipe: Cadet Vest of the Boar'),
(9765, 192399, 'Recipe: Cadet Vest of the Owl'),
(9765, 192400, 'Recipe: Cadet Vest of the Eagle'),
(9765, 192401, 'Recipe: Cadet Vest of the Whale'),
(15487, 192402, 'Recipe: War Torn Tunic of Strength'),
(15487, 192403, 'Recipe: War Torn Tunic of Stamina'),
(9783, 192404, 'Recipe: Raider''s Chestpiece of Stamina'),
(9783, 192405, 'Recipe: Raider''s Chestpiece of Stamina'),
(9783, 192406, 'Recipe: Raider''s Chestpiece of Strength'),
(15488, 192407, 'Recipe: Bloodspattered Surcoat of Stamina'),
(6580, 192416, 'Recipe: Defender Tunic of Strength'),
(6580, 192417, 'Recipe: Defender Tunic of Stamina'),
(6580, 192418, 'Recipe: Defender Tunic of the Tiger'),
(6580, 192419, 'Recipe: Defender Tunic of the Monkey'),
(6580, 192420, 'Recipe: Defender Tunic of Strength'),
(6580, 192421, 'Recipe: Defender Tunic of the Gorilla'),
(6580, 192422, 'Recipe: Defender Tunic of the Boar'),
(6580, 192423, 'Recipe: Defender Tunic of the Bear'),
(6580, 192424, 'Recipe: Defender Tunic of the Eagle'),
(6580, 192425, 'Recipe: Defender Tunic of the Whale'),
(6580, 192426, 'Recipe: Defender Tunic of Stamina'),
(6580, 192427, 'Recipe: Defender Tunic of the Tiger'),
(6580, 192428, 'Recipe: Defender Tunic of the Monkey'),
(6580, 192429, 'Recipe: Defender Tunic of the Tiger'),
(6580, 192430, 'Recipe: Defender Tunic of the Monkey'),
(6580, 192431, 'Recipe: Defender Tunic of the Gorilla'),
(6580, 192432, 'Recipe: Defender Tunic of the Boar'),
(6580, 192433, 'Recipe: Defender Tunic of the Bear'),
(6580, 192434, 'Recipe: Defender Tunic of the Gorilla'),
(6580, 192435, 'Recipe: Defender Tunic of the Boar'),
(6580, 192436, 'Recipe: Defender Tunic of the Eagle'),
(6580, 192437, 'Recipe: Defender Tunic of the Eagle'),
(6580, 192438, 'Recipe: Defender Tunic of the Whale'),
(6580, 192439, 'Recipe: Defender Tunic of the Whale'),
(6580, 192440, 'Recipe: Defender Tunic of the Tiger'),
(6580, 192441, 'Recipe: Defender Tunic of the Monkey'),
(6580, 192442, 'Recipe: Defender Tunic of the Gorilla'),
(6580, 192443, 'Recipe: Defender Tunic of the Boar'),
(6580, 192444, 'Recipe: Defender Tunic of the Eagle'),
(6580, 192445, 'Recipe: Defender Tunic of the Whale'),
(15500, 192446, 'Recipe: Outrunner''s Chestguard of Strength'),
(15500, 192447, 'Recipe: Outrunner''s Chestguard of Stamina'),
(15500, 192448, 'Recipe: Outrunner''s Chestguard of Stamina'),
(9818, 192449, 'Recipe: Fortified Chain of Strength'),
(9818, 192450, 'Recipe: Fortified Chain of Stamina'),
(9818, 192451, 'Recipe: Fortified Chain of the Tiger'),
(9818, 192452, 'Recipe: Fortified Chain of the Monkey'),
(9818, 192453, 'Recipe: Fortified Chain of Strength'),
(9818, 192454, 'Recipe: Fortified Chain of the Gorilla'),
(9818, 192455, 'Recipe: Fortified Chain of the Boar'),
(9818, 192456, 'Recipe: Fortified Chain of the Bear'),
(9818, 192457, 'Recipe: Fortified Chain of the Eagle'),
(9818, 192458, 'Recipe: Fortified Chain of the Whale'),
(9818, 192459, 'Recipe: Fortified Chain of Stamina'),
(9818, 192460, 'Recipe: Fortified Chain of the Tiger'),
(9818, 192461, 'Recipe: Fortified Chain of the Monkey'),
(9818, 192462, 'Recipe: Fortified Chain of the Tiger'),
(9818, 192463, 'Recipe: Fortified Chain of the Monkey'),
(9818, 192464, 'Recipe: Fortified Chain of the Gorilla'),
(9818, 192465, 'Recipe: Fortified Chain of the Boar'),
(9818, 192466, 'Recipe: Fortified Chain of the Bear'),
(9818, 192467, 'Recipe: Fortified Chain of the Gorilla'),
(9818, 192468, 'Recipe: Fortified Chain of the Boar'),
(9818, 192469, 'Recipe: Fortified Chain of the Bear'),
(9818, 192470, 'Recipe: Fortified Chain of the Eagle'),
(9818, 192471, 'Recipe: Fortified Chain of the Eagle'),
(9818, 192472, 'Recipe: Fortified Chain of the Whale'),
(15514, 192473, 'Recipe: Grunt''s Chestpiece of Strength'),
(15514, 192474, 'Recipe: Grunt''s Chestpiece of Stamina'),
(15514, 192475, 'Recipe: Grunt''s Chestpiece of Stamina'),
(6592, 192476, 'Recipe: Battleforge Armor of Stamina'),
(15518, 192483, 'Recipe: Spiked Chain Breastplate of Strength'),
(15518, 192484, 'Recipe: Spiked Chain Breastplate of Stamina'),
(15518, 192485, 'Recipe: Spiked Chain Breastplate of the Tiger'),
(15518, 192486, 'Recipe: Spiked Chain Breastplate of the Monkey'),
(15518, 192487, 'Recipe: Spiked Chain Breastplate of Strength'),
(15518, 192488, 'Recipe: Spiked Chain Breastplate of the Gorilla'),
(15518, 192489, 'Recipe: Spiked Chain Breastplate of the Boar'),
(15518, 192490, 'Recipe: Spiked Chain Breastplate of the Bear'),
(15518, 192491, 'Recipe: Spiked Chain Breastplate of the Eagle'),
(15518, 192492, 'Recipe: Spiked Chain Breastplate of the Whale'),
(15518, 192493, 'Recipe: Spiked Chain Breastplate of Stamina'),
(15518, 192494, 'Recipe: Spiked Chain Breastplate of the Tiger'),
(15518, 192495, 'Recipe: Spiked Chain Breastplate of the Monkey'),
(15518, 192496, 'Recipe: Spiked Chain Breastplate of the Tiger'),
(15518, 192497, 'Recipe: Spiked Chain Breastplate of the Monkey'),
(15518, 192498, 'Recipe: Spiked Chain Breastplate of the Gorilla'),
(15518, 192499, 'Recipe: Spiked Chain Breastplate of the Boar'),
(15518, 192500, 'Recipe: Spiked Chain Breastplate of the Bear'),
(15518, 192501, 'Recipe: Spiked Chain Breastplate of the Gorilla'),
(15518, 192502, 'Recipe: Spiked Chain Breastplate of the Boar'),
(15518, 192503, 'Recipe: Spiked Chain Breastplate of the Bear'),
(15518, 192504, 'Recipe: Spiked Chain Breastplate of the Eagle'),
(15518, 192505, 'Recipe: Spiked Chain Breastplate of the Eagle'),
(15518, 192506, 'Recipe: Spiked Chain Breastplate of the Whale'),
(15518, 192507, 'Recipe: Spiked Chain Breastplate of the Whale'),
(15518, 192508, 'Recipe: Spiked Chain Breastplate of the Tiger'),
(15518, 192509, 'Recipe: Spiked Chain Breastplate of the Monkey'),
(15518, 192510, 'Recipe: Spiked Chain Breastplate of the Gorilla'),
(15518, 192511, 'Recipe: Spiked Chain Breastplate of the Boar'),
(15518, 192512, 'Recipe: Spiked Chain Breastplate of the Bear'),
(15518, 192513, 'Recipe: Spiked Chain Breastplate of the Eagle'),
(15518, 192514, 'Recipe: Spiked Chain Breastplate of the Whale'),
(15524, 192515, 'Recipe: Sentry''s Surcoat of Strength'),
(15524, 192516, 'Recipe: Sentry''s Surcoat of Stamina'),
(15524, 192517, 'Recipe: Sentry''s Surcoat of Strength'),
(15524, 192518, 'Recipe: Sentry''s Surcoat of Stamina'),
(9836, 192519, 'Recipe: Banded Armor of Strength'),
(9836, 192520, 'Recipe: Banded Armor of Stamina'),
(15536, 192521, 'Recipe: Wicked Chain Chestpiece of the Tiger'),
(15536, 192522, 'Recipe: Wicked Chain Chestpiece of the Monkey'),
(15536, 192523, 'Recipe: Wicked Chain Chestpiece of the Gorilla'),
(15536, 192524, 'Recipe: Wicked Chain Chestpiece of the Boar'),
(15536, 192525, 'Recipe: Wicked Chain Chestpiece of the Bear'),
(15536, 192526, 'Recipe: Wicked Chain Chestpiece of the Eagle'),
(15536, 192527, 'Recipe: Wicked Chain Chestpiece of the Whale');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND `Reference` = 0;

INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `pickpocketing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `pickpocketing_loot_template` WHERE `Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND `Reference` = 0;

INSERT INTO `fishing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `fishing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `fishing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `fishing_loot_template` WHERE `Item` IN (6336, 9765, 15487, 9783, 15488, 6580, 15500, 9818, 15514, 6592, 15518, 15524, 9836, 15536) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
