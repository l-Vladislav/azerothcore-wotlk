-- Книги эскизов основы булавы «Ториевая палица»
-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1916480, 1916490, 1916500, 1916510, 1916520, 1916530, 1916550);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1916480, 191648, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Baron Charr''s Sceptre'),
(1916480, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1916480, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby'),
(1916480, 12363, 0, 0, 0, 1, 1, 1, 1, 'Arcane Crystal'),
(1916490, 191649, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Bludstone Hammer'),
(1916490, 12359, 0, 0, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1916490, 13926, 0, 0, 0, 1, 1, 1, 1, 'Golden Pearl'),
(1916500, 191650, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Hand of Edward the Odd'),
(1916500, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1916500, 12363, 0, 0, 0, 1, 1, 1, 1, 'Arcane Crystal'),
(1916500, 13926, 0, 0, 0, 1, 1, 1, 1, 'Golden Pearl'),
(1916510, 191651, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Mass of McGowan'),
(1916510, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1916510, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby'),
(1916510, 12799, 0, 0, 0, 1, 1, 1, 1, 'Large Opal'),
(1916520, 191652, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Hammer of Bestial Fury'),
(1916520, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1916520, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby'),
(1916520, 12799, 0, 0, 0, 1, 1, 1, 1, 'Large Opal'),
(1916530, 191653, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Empyrean Demolisher'),
(1916530, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1916530, 12364, 0, 0, 0, 1, 1, 1, 1, 'Huge Emerald'),
(1916530, 7910, 0, 0, 0, 1, 1, 1, 1, 'Star Ruby'),
(1916550, 191655, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Hardened Steel Warhammer'),
(1916550, 12359, 0, 33.3333, 0, 1, 1, 1, 1, 'Thorium Bar'),
(1916550, 12799, 0, 0, 0, 1, 1, 1, 1, 'Large Opal'),
(1916550, 12363, 0, 0, 0, 1, 1, 1, 1, 'Arcane Crystal');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой;
-- строка с долей от 4 % ссылается на таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_single`;
CREATE TEMPORARY TABLE `ap_tmp_single` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_single` VALUES
(18671, 191648, 'Recipe: Baron Charr''s Sceptre'),
(13028, 191649, 'Recipe: Bludstone Hammer'),
(2243, 191650, 'Recipe: Hand of Edward the Odd'),
(13006, 191651, 'Recipe: Mass of McGowan'),
(20580, 191652, 'Recipe: Hammer of Bestial Fury'),
(17112, 191653, 'Recipe: Empyrean Demolisher'),
(20666, 191655, 'Recipe: Hardened Steel Warhammer');

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
(15229, 191656, 'Recipe: Blesswind Hammer of the Monkey'),
(15229, 191657, 'Recipe: Blesswind Hammer of the Tiger'),
(15229, 191658, 'Recipe: Blesswind Hammer of the Bear'),
(15229, 191659, 'Recipe: Blesswind Hammer of the Monkey'),
(15229, 191660, 'Recipe: Blesswind Hammer of the Tiger');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15229) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (15229) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15229) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (15229) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15229) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (15229) AND `Reference` = 0;

INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `item_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15229) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `item_loot_template` WHERE `Item` IN (15229) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;

-- Условие добычи именного предмета переходит на строку таблицы ссылок его книги.
UPDATE `conditions` SET `SourceEntry` = 1916550 WHERE `SourceTypeOrReferenceId` = 1 AND `SourceGroup` = 15206 AND `SourceEntry` = 20666;