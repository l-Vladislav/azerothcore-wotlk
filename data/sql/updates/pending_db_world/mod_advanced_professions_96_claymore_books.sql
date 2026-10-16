-- Книги эскизов основы двуручного меча «Клеймор»
-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1917640);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1917640, 191764, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Shiver Blade'),
(1917640, 2841, 0, 0, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1917640, 1210, 0, 0, 0, 1, 1, 1, 1, 'Shadowgem');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(2822, 191761, 'Recipe: Mo''grosh Toothpick'),
(1460, 191763, 'Recipe: Shadowhide Two-handed Sword'),
(5182, 191764, 'Recipe: Shiver Blade');

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
(4567, 191765, 'Recipe: Merc Sword of Agility'),
(4567, 191766, 'Recipe: Merc Sword of Agility'),
(4567, 191767, 'Recipe: Merc Sword of Stamina'),
(4567, 191768, 'Recipe: Merc Sword of Strength'),
(4567, 191769, 'Recipe: Merc Sword of Strength'),
(4567, 191770, 'Recipe: Merc Sword of the Bear'),
(4567, 191771, 'Recipe: Merc Sword of the Boar'),
(4567, 191772, 'Recipe: Merc Sword of the Eagle'),
(4567, 191773, 'Recipe: Merc Sword of the Falcon'),
(4567, 191774, 'Recipe: Merc Sword of the Monkey'),
(4567, 191775, 'Recipe: Merc Sword of the Owl'),
(4567, 191776, 'Recipe: Merc Sword of the Tiger'),
(4567, 191777, 'Recipe: Merc Sword of the Whale'),
(4567, 191778, 'Recipe: Merc Sword of the Wolf'),
(15248, 191779, 'Recipe: Gleaming Claymore of Agility'),
(15248, 191780, 'Recipe: Gleaming Claymore of Agility'),
(15248, 191781, 'Recipe: Gleaming Claymore of Stamina'),
(15248, 191782, 'Recipe: Gleaming Claymore of Strength'),
(15248, 191783, 'Recipe: Gleaming Claymore of Strength');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (4567, 15248) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (4567, 15248) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (4567, 15248) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (4567, 15248) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (4567, 15248) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (4567, 15248) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (4567, 15248) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (4567, 15248) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
