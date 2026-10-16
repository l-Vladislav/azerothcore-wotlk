-- Книги эскизов кольчуги Бронника: шлем

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1922020, 1922070, 1922080);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1922020, 192202, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Tusken Helm'),
(1922020, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1922020, 1529, 0, 0, 0, 1, 1, 1, 1, 'Jade'),
(1922020, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1922070, 192207, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Frostreaver Crown'),
(1922070, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1922070, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone'),
(1922080, 192208, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Sunblaze Coif'),
(1922080, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1922080, 5500, 0, 0, 0, 1, 1, 1, 1, 'Iridescent Pearl'),
(1922080, 1705, 0, 0, 0, 1, 1, 1, 1, 'Lesser Moonstone');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(6389, 192201, 'Recipe: Glimmering Mail Coif'),
(6686, 192202, 'Recipe: Tusken Helm'),
(14753, 192203, 'Recipe: Slayer''s Skullcap'),
(3836, 192204, 'Recipe: Green Iron Helm'),
(4077, 192205, 'Recipe: Mail Combat Headguard'),
(7915, 192206, 'Recipe: Barbaric Iron Helm'),
(13127, 192207, 'Recipe: Frostreaver Crown'),
(5819, 192208, 'Recipe: Sunblaze Coif');

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
(15533, 192209, 'Recipe: Sentry''s Headdress of Stamina'),
(15533, 192210, 'Recipe: Sentry''s Headdress of Stamina'),
(15533, 192211, 'Recipe: Sentry''s Headdress of the Tiger'),
(15533, 192212, 'Recipe: Sentry''s Headdress of the Monkey'),
(15533, 192213, 'Recipe: Sentry''s Headdress of the Gorilla'),
(15533, 192214, 'Recipe: Sentry''s Headdress of the Boar'),
(15533, 192215, 'Recipe: Sentry''s Headdress of the Bear'),
(15533, 192216, 'Recipe: Sentry''s Headdress of the Eagle'),
(15533, 192217, 'Recipe: Sentry''s Headdress of the Whale'),
(15533, 192218, 'Recipe: Sentry''s Headdress of the Tiger'),
(15533, 192219, 'Recipe: Sentry''s Headdress of the Monkey'),
(15533, 192220, 'Recipe: Sentry''s Headdress of the Tiger'),
(15533, 192221, 'Recipe: Sentry''s Headdress of the Monkey'),
(15533, 192222, 'Recipe: Sentry''s Headdress of the Gorilla'),
(15533, 192223, 'Recipe: Sentry''s Headdress of the Boar'),
(15533, 192224, 'Recipe: Sentry''s Headdress of the Bear'),
(15533, 192225, 'Recipe: Sentry''s Headdress of the Gorilla'),
(15533, 192226, 'Recipe: Sentry''s Headdress of the Boar'),
(15533, 192227, 'Recipe: Sentry''s Headdress of the Bear'),
(15533, 192228, 'Recipe: Sentry''s Headdress of the Eagle'),
(15533, 192229, 'Recipe: Sentry''s Headdress of the Eagle'),
(15533, 192230, 'Recipe: Sentry''s Headdress of the Whale'),
(15533, 192231, 'Recipe: Sentry''s Headdress of the Whale'),
(15533, 192232, 'Recipe: Sentry''s Headdress of the Monkey'),
(15533, 192233, 'Recipe: Sentry''s Headdress of the Gorilla'),
(15533, 192234, 'Recipe: Sentry''s Headdress of the Boar'),
(15533, 192235, 'Recipe: Sentry''s Headdress of the Eagle'),
(10408, 192236, 'Recipe: Banded Helm of Stamina'),
(10408, 192237, 'Recipe: Banded Helm of Stamina'),
(7420, 192238, 'Recipe: Phalanx Headguard of Stamina'),
(7420, 192239, 'Recipe: Phalanx Headguard of Stamina'),
(15540, 192240, 'Recipe: Wicked Chain Helmet of the Tiger'),
(15540, 192241, 'Recipe: Wicked Chain Helmet of the Monkey'),
(15540, 192242, 'Recipe: Wicked Chain Helmet of the Tiger'),
(15540, 192243, 'Recipe: Wicked Chain Helmet of the Monkey'),
(15540, 192244, 'Recipe: Wicked Chain Helmet of the Gorilla'),
(15540, 192245, 'Recipe: Wicked Chain Helmet of the Boar'),
(15540, 192246, 'Recipe: Wicked Chain Helmet of the Gorilla'),
(15540, 192247, 'Recipe: Wicked Chain Helmet of the Boar'),
(15540, 192248, 'Recipe: Wicked Chain Helmet of the Bear'),
(15540, 192249, 'Recipe: Wicked Chain Helmet of the Eagle'),
(15540, 192250, 'Recipe: Wicked Chain Helmet of the Eagle'),
(15540, 192251, 'Recipe: Wicked Chain Helmet of the Whale'),
(15540, 192252, 'Recipe: Wicked Chain Helmet of the Whale'),
(15540, 192253, 'Recipe: Wicked Chain Helmet of Stamina');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15533, 10408, 7420, 15540) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (15533, 10408, 7420, 15540) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15533, 10408, 7420, 15540) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (15533, 10408, 7420, 15540) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15533, 10408, 7420, 15540) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (15533, 10408, 7420, 15540) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15533, 10408, 7420, 15540) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (15533, 10408, 7420, 15540) AND `Reference` = 0;

INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `pickpocketing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15533, 10408, 7420, 15540) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `pickpocketing_loot_template` WHERE `Item` IN (15533, 10408, 7420, 15540) AND `Reference` = 0;

INSERT INTO `fishing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `fishing_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `fishing_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15533, 10408, 7420, 15540) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `fishing_loot_template` WHERE `Item` IN (15533, 10408, 7420, 15540) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
