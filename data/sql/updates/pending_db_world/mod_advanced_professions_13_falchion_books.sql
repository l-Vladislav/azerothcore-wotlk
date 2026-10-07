-- Книги эскизов основы 184139 «Фальшион»
-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1910660, 1910670, 1910680, 1910690, 1910700, 1910710, 1910720, 1910730);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1910660, 191066, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Krol Blade'),
(1910660, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1910660, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1910660, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1910670, 191067, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Assassination Blade'),
(1910670, 3860, 0, 0, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1910670, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1910680, 191068, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Blade of the Wretched'),
(1910680, 3860, 0, 0, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1910680, 185002, 0, 0, 0, 1, 1, 1, 1, 'Lesser Arcane Crystal'),
(1910690, 191069, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Shortsword of Vengeance'),
(1910690, 3860, 0, 0, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1910690, 7971, 0, 0, 0, 1, 1, 1, 1, 'Black Pearl'),
(1910700, 191070, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Serpent Slicer'),
(1910700, 3860, 0, 0, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1910700, 185001, 0, 0, 0, 1, 1, 1, 1, 'Superior Jade'),
(1910710, 191071, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Joonho''s Mercy'),
(1910710, 3860, 0, 0, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1910710, 185002, 0, 0, 0, 1, 1, 1, 1, 'Lesser Arcane Crystal'),
(1910720, 191072, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Hanzo Sword'),
(1910720, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1910720, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1910720, 7971, 0, 0, 0, 1, 1, 1, 1, 'Black Pearl'),
(1910730, 191073, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Bloodrazor'),
(1910730, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1910730, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1910730, 185001, 0, 0, 0, 1, 1, 1, 1, 'Superior Jade'),
(1910730, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(2244, 191066, 'Recipe: Krol Blade'),
(13036, 191067, 'Recipe: Assassination Blade'),
(10803, 191068, 'Recipe: Blade of the Wretched'),
(754, 191069, 'Recipe: Shortsword of Vengeance'),
(13035, 191070, 'Recipe: Serpent Slicer'),
(17054, 191071, 'Recipe: Joonho''s Mercy'),
(8190, 191072, 'Recipe: Hanzo Sword'),
(809, 191073, 'Recipe: Bloodrazor');

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
(15216, 191074, 'Recipe: Rune Sword of the Bear'),
(15216, 191075, 'Recipe: Rune Sword of the Tiger'),
(15216, 191076, 'Recipe: Rune Sword of the Monkey'),
(15216, 191077, 'Recipe: Rune Sword of Strength'),
(15216, 191078, 'Recipe: Rune Sword of Stamina'),
(15217, 191079, 'Recipe: Widow Blade of the Bear'),
(15217, 191080, 'Recipe: Widow Blade of the Tiger'),
(15217, 191081, 'Recipe: Widow Blade of the Monkey'),
(15218, 191082, 'Recipe: Crystal Sword of Strength'),
(15218, 191083, 'Recipe: Crystal Sword of Stamina');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15216, 15217, 15218) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (15216, 15217, 15218) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15216, 15217, 15218) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (15216, 15217, 15218) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15216, 15217, 15218) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (15216, 15217, 15218) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15216, 15217, 15218) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (15216, 15217, 15218) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
