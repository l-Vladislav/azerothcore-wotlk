-- Книги эскизов основы булавы «Утренняя звезда»
-- Поправки статов и уровня именных предметов - решения владельца.
UPDATE `item_template` SET `stat_value3` = 4 WHERE `entry` = 17055 AND `stat_type3` = 6;

-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1916280, 1916320, 1916330, 1916340, 1916350, 1916360);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1916280, 191628, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Mug O'' Hurt'),
(1916280, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1916280, 185001, 0, 0, 0, 1, 1, 1, 1, 'Превосходный нефрит'),
(1916280, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1916320, 191632, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Fist of the Damned'),
(1916320, 3860, 0, 0, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1916320, 185002, 0, 0, 0, 1, 1, 1, 1, 'Малый чародейный кристалл'),
(1916330, 191633, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Changuk Smasher'),
(1916330, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1916330, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1916330, 185002, 0, 0, 0, 1, 1, 1, 1, 'Малый чародейный кристалл'),
(1916330, 7971, 0, 0, 0, 1, 1, 1, 1, 'Black Pearl'),
(1916340, 191634, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Viking Warhammer'),
(1916340, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1916340, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1916340, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1916350, 191635, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Bonesnapper'),
(1916350, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1916350, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1916350, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1916360, 191636, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Hammer of the Northern Wind'),
(1916360, 3860, 0, 33.3333, 0, 1, 1, 1, 1, 'Mithril Bar'),
(1916360, 185002, 0, 0, 0, 1, 1, 1, 1, 'Малый чародейный кристалл'),
(1916360, 7971, 0, 0, 0, 1, 1, 1, 1, 'Black Pearl');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(4090, 191628, 'Recipe: Mug O'' Hurt'),
(10804, 191632, 'Recipe: Fist of the Damned'),
(17055, 191633, 'Recipe: Changuk Smasher'),
(1721, 191634, 'Recipe: Viking Warhammer'),
(13027, 191635, 'Recipe: Bonesnapper'),
(810, 191636, 'Recipe: Hammer of the Northern Wind');

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
(1608, 191637, 'Recipe: Skullcrusher Mace of Stamina'),
(1608, 191638, 'Recipe: Skullcrusher Mace of the Falcon'),
(1608, 191639, 'Recipe: Skullcrusher Mace of the Owl'),
(1608, 191640, 'Recipe: Skullcrusher Mace of the Eagle'),
(1608, 191641, 'Recipe: Skullcrusher Mace of the Gorilla'),
(1608, 191642, 'Recipe: Skullcrusher Mace of the Whale'),
(1608, 191643, 'Recipe: Skullcrusher Mace of the Boar'),
(15227, 191644, 'Recipe: Diamond-Tip Bludgeon of Stamina'),
(15227, 191645, 'Recipe: Diamond-Tip Bludgeon of Strength');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (1608, 15227) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (1608, 15227) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (1608, 15227) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (1608, 15227) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (1608, 15227) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (1608, 15227) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (1608, 15227) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (1608, 15227) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
