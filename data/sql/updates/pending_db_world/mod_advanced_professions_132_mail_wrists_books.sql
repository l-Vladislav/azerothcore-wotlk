-- Книги эскизов кольчуги Бронника: наручи

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1929090, 1929360);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1929090, 192909, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Cavedweller Bracers'),
(1929090, 2840, 0, 33.3333, 0, 1, 1, 1, 1, 'Copper Bar'),
(1929090, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1929090, 185008, 0, 0, 0, 1, 1, 1, 1, 'Осколок лунного камня'),
(1929360, 192936, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Yorgen Bracers'),
(1929360, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1929360, 1529, 0, 0, 0, 1, 1, 1, 1, 'Jade'),
(1929360, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(14723, 192908, 'Recipe: War Paint Bindings'),
(14147, 192909, 'Recipe: Cavedweller Bracers'),
(3211, 192910, 'Recipe: Burnished Bracers'),
(14743, 192929, 'Recipe: Hulking Bands'),
(2867, 192930, 'Recipe: Rough Bronze Bracers'),
(2868, 192931, 'Recipe: Patterned Bronze Bracers'),
(5943, 192932, 'Recipe: Rift Bracers'),
(3212, 192933, 'Recipe: Lambent Scale Bracers'),
(14750, 192934, 'Recipe: Slayer''s Cuffs'),
(6387, 192935, 'Recipe: Glimmering Mail Bracers'),
(13012, 192936, 'Recipe: Yorgen Bracers'),
(6403, 192994, 'Recipe: Mail Combat Armguards'),
(14759, 192995, 'Recipe: Enduring Bracers');

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
(6550, 192911, 'Recipe: Soldier''s Wristguards of Agility'),
(6550, 192912, 'Recipe: Soldier''s Wristguards of Strength'),
(6550, 192913, 'Recipe: Soldier''s Wristguards of Stamina'),
(6550, 192914, 'Recipe: Soldier''s Wristguards of the Tiger'),
(6550, 192915, 'Recipe: Soldier''s Wristguards of the Monkey'),
(6550, 192916, 'Recipe: Soldier''s Wristguards of Strength'),
(6550, 192917, 'Recipe: Soldier''s Wristguards of the Gorilla'),
(6550, 192918, 'Recipe: Soldier''s Wristguards of the Boar'),
(6550, 192919, 'Recipe: Soldier''s Wristguards of the Eagle'),
(6550, 192920, 'Recipe: Soldier''s Wristguards of the Whale'),
(6550, 192921, 'Recipe: Soldier''s Wristguards of Stamina'),
(15495, 192922, 'Recipe: Bloodspattered Wristbands of Agility'),
(9785, 192923, 'Recipe: Raider''s Bracers of Strength'),
(9785, 192924, 'Recipe: Raider''s Bracers of Stamina'),
(15507, 192925, 'Recipe: Grunt''s Bracers of Strength'),
(15507, 192926, 'Recipe: Grunt''s Bracers of Stamina'),
(15507, 192927, 'Recipe: Grunt''s Bracers of Strength'),
(15507, 192928, 'Recipe: Grunt''s Bracers of Stamina'),
(6574, 192937, 'Recipe: Defender Bracers of Strength'),
(6574, 192938, 'Recipe: Defender Bracers of Stamina'),
(6574, 192939, 'Recipe: Defender Bracers of the Tiger'),
(6574, 192940, 'Recipe: Defender Bracers of the Monkey'),
(6574, 192941, 'Recipe: Defender Bracers of Strength'),
(6574, 192942, 'Recipe: Defender Bracers of the Gorilla'),
(6574, 192943, 'Recipe: Defender Bracers of the Boar'),
(6574, 192944, 'Recipe: Defender Bracers of the Bear'),
(6574, 192945, 'Recipe: Defender Bracers of the Eagle'),
(6574, 192946, 'Recipe: Defender Bracers of the Whale'),
(6574, 192947, 'Recipe: Defender Bracers of Stamina'),
(6574, 192948, 'Recipe: Defender Bracers of the Tiger'),
(6574, 192949, 'Recipe: Defender Bracers of the Monkey'),
(6574, 192950, 'Recipe: Defender Bracers of the Tiger'),
(6574, 192951, 'Recipe: Defender Bracers of the Monkey'),
(6574, 192952, 'Recipe: Defender Bracers of the Gorilla'),
(6574, 192953, 'Recipe: Defender Bracers of the Boar'),
(6574, 192954, 'Recipe: Defender Bracers of the Gorilla'),
(6574, 192955, 'Recipe: Defender Bracers of the Boar'),
(6574, 192956, 'Recipe: Defender Bracers of the Bear'),
(6574, 192957, 'Recipe: Defender Bracers of the Eagle'),
(6574, 192958, 'Recipe: Defender Bracers of the Eagle'),
(6574, 192959, 'Recipe: Defender Bracers of the Whale'),
(6574, 192960, 'Recipe: Defender Bracers of the Tiger'),
(6574, 192961, 'Recipe: Defender Bracers of the Monkey'),
(6574, 192962, 'Recipe: Defender Bracers of the Gorilla'),
(6574, 192963, 'Recipe: Defender Bracers of the Boar'),
(6574, 192964, 'Recipe: Defender Bracers of the Eagle'),
(6574, 192965, 'Recipe: Defender Bracers of the Whale'),
(9811, 192966, 'Recipe: Fortified Bracers of Strength'),
(9811, 192967, 'Recipe: Fortified Bracers of Stamina'),
(15517, 192968, 'Recipe: Spiked Chain Wristbands of Strength'),
(15517, 192969, 'Recipe: Spiked Chain Wristbands of Stamina'),
(15517, 192970, 'Recipe: Spiked Chain Wristbands of the Tiger'),
(15517, 192971, 'Recipe: Spiked Chain Wristbands of the Monkey'),
(15517, 192972, 'Recipe: Spiked Chain Wristbands of the Gorilla'),
(15517, 192973, 'Recipe: Spiked Chain Wristbands of the Boar'),
(15517, 192974, 'Recipe: Spiked Chain Wristbands of the Bear'),
(15517, 192975, 'Recipe: Spiked Chain Wristbands of the Eagle'),
(15517, 192976, 'Recipe: Spiked Chain Wristbands of the Whale'),
(15517, 192977, 'Recipe: Spiked Chain Wristbands of the Tiger'),
(15517, 192978, 'Recipe: Spiked Chain Wristbands of the Tiger'),
(15517, 192979, 'Recipe: Spiked Chain Wristbands of the Monkey'),
(15517, 192980, 'Recipe: Spiked Chain Wristbands of the Gorilla'),
(15517, 192981, 'Recipe: Spiked Chain Wristbands of the Boar'),
(15517, 192982, 'Recipe: Spiked Chain Wristbands of the Bear'),
(15517, 192983, 'Recipe: Spiked Chain Wristbands of the Gorilla'),
(15517, 192984, 'Recipe: Spiked Chain Wristbands of the Boar'),
(15517, 192985, 'Recipe: Spiked Chain Wristbands of the Bear'),
(15517, 192986, 'Recipe: Spiked Chain Wristbands of the Eagle'),
(15517, 192987, 'Recipe: Spiked Chain Wristbands of the Eagle'),
(15517, 192988, 'Recipe: Spiked Chain Wristbands of the Whale'),
(15517, 192989, 'Recipe: Spiked Chain Wristbands of the Whale'),
(15532, 192990, 'Recipe: Sentry''s Armsplints of Strength'),
(15532, 192991, 'Recipe: Sentry''s Armsplints of Stamina'),
(15535, 192992, 'Recipe: Wicked Chain Bracers of Strength'),
(15535, 192993, 'Recipe: Wicked Chain Bracers of Stamina'),
(9837, 192996, 'Recipe: Banded Bracers of Strength'),
(9837, 192997, 'Recipe: Banded Bracers of Stamina'),
(9837, 192998, 'Recipe: Banded Bracers of the Tiger'),
(9837, 192999, 'Recipe: Banded Bracers of the Monkey'),
(9837, 193000, 'Recipe: Banded Bracers of the Gorilla'),
(9837, 193001, 'Recipe: Banded Bracers of the Boar'),
(9837, 193002, 'Recipe: Banded Bracers of the Bear'),
(9837, 193003, 'Recipe: Banded Bracers of the Eagle'),
(9837, 193004, 'Recipe: Banded Bracers of the Whale'),
(9837, 193005, 'Recipe: Banded Bracers of the Tiger'),
(9837, 193006, 'Recipe: Banded Bracers of the Monkey'),
(9837, 193007, 'Recipe: Banded Bracers of the Tiger'),
(9837, 193008, 'Recipe: Banded Bracers of the Monkey'),
(9837, 193009, 'Recipe: Banded Bracers of the Gorilla'),
(9837, 193010, 'Recipe: Banded Bracers of the Boar'),
(9837, 193011, 'Recipe: Banded Bracers of the Bear'),
(9837, 193012, 'Recipe: Banded Bracers of the Gorilla'),
(9837, 193013, 'Recipe: Banded Bracers of the Boar'),
(9837, 193014, 'Recipe: Banded Bracers of the Bear'),
(9837, 193015, 'Recipe: Banded Bracers of the Eagle'),
(9837, 193016, 'Recipe: Banded Bracers of the Eagle'),
(9837, 193017, 'Recipe: Banded Bracers of the Whale'),
(9837, 193018, 'Recipe: Banded Bracers of the Whale'),
(9837, 193019, 'Recipe: Banded Bracers of the Tiger'),
(9837, 193020, 'Recipe: Banded Bracers of the Monkey'),
(9837, 193021, 'Recipe: Banded Bracers of the Gorilla'),
(9837, 193022, 'Recipe: Banded Bracers of the Boar'),
(9837, 193023, 'Recipe: Banded Bracers of the Bear'),
(9837, 193024, 'Recipe: Banded Bracers of the Eagle'),
(9837, 193025, 'Recipe: Banded Bracers of the Whale'),
(15545, 193026, 'Recipe: Thick Scale Bracelets of Strength'),
(15545, 193027, 'Recipe: Thick Scale Bracelets of Stamina'),
(7416, 193028, 'Recipe: Phalanx Bracers of Strength'),
(7416, 193029, 'Recipe: Phalanx Bracers of Stamina'),
(7416, 193030, 'Recipe: Phalanx Bracers of the Tiger'),
(7416, 193031, 'Recipe: Phalanx Bracers of the Monkey'),
(7416, 193032, 'Recipe: Phalanx Bracers of the Tiger'),
(7416, 193033, 'Recipe: Phalanx Bracers of the Monkey'),
(7416, 193034, 'Recipe: Phalanx Bracers of Strength'),
(7416, 193035, 'Recipe: Phalanx Bracers of the Gorilla'),
(7416, 193036, 'Recipe: Phalanx Bracers of the Boar'),
(7416, 193037, 'Recipe: Phalanx Bracers of the Bear'),
(7416, 193038, 'Recipe: Phalanx Bracers of the Gorilla'),
(7416, 193039, 'Recipe: Phalanx Bracers of the Boar'),
(7416, 193040, 'Recipe: Phalanx Bracers of the Bear'),
(7416, 193041, 'Recipe: Phalanx Bracers of the Eagle'),
(7416, 193042, 'Recipe: Phalanx Bracers of the Eagle'),
(7416, 193043, 'Recipe: Phalanx Bracers of the Whale'),
(7416, 193044, 'Recipe: Phalanx Bracers of the Whale'),
(7416, 193045, 'Recipe: Phalanx Bracers of Stamina'),
(7416, 193046, 'Recipe: Phalanx Bracers of the Tiger'),
(7416, 193047, 'Recipe: Phalanx Bracers of the Monkey'),
(7416, 193048, 'Recipe: Phalanx Bracers of the Gorilla'),
(7416, 193049, 'Recipe: Phalanx Bracers of the Boar'),
(7416, 193050, 'Recipe: Phalanx Bracers of the Bear'),
(7416, 193051, 'Recipe: Phalanx Bracers of the Eagle'),
(7416, 193052, 'Recipe: Phalanx Bracers of the Whale'),
(15556, 193053, 'Recipe: Pillager''s Bracers of Strength'),
(15556, 193054, 'Recipe: Pillager''s Bracers of Stamina'),
(9865, 193055, 'Recipe: Renegade Bracers of Strength'),
(9865, 193056, 'Recipe: Renegade Bracers of Stamina'),
(9865, 193057, 'Recipe: Renegade Bracers of Strength'),
(9865, 193058, 'Recipe: Renegade Bracers of Stamina');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND `Reference` = 0;

INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `pickpocketing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `pickpocketing_loot_template` WHERE `Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND `Reference` = 0;

INSERT INTO `fishing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `fishing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `fishing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `fishing_loot_template` WHERE `Item` IN (6550, 15495, 9785, 15507, 6574, 9811, 15517, 15532, 15535, 9837, 15545, 7416, 15556, 9865) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
