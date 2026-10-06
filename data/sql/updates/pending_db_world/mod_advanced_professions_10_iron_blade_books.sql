-- Книги эскизов основы 184137 «Железный клинок»
-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1910300, 1910310, 1910320, 1910390, 1910400);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1910300, 191030, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Darkwater Talwar'),
(1910300, 3575, 0, 0, 0, 1, 1, 1, 1, 'Iron Bar'),
(1910300, 185000, 0, 0, 0, 1, 1, 1, 1, 'Superior Shadowgem'),
(1910310, 191031, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Sword of Corruption'),
(1910310, 3575, 0, 0, 0, 1, 1, 1, 1, 'Iron Bar'),
(1910310, 185000, 0, 0, 0, 1, 1, 1, 1, 'Superior Shadowgem'),
(1910320, 191032, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: The Black Knight'),
(1910320, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1910320, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1910320, 185000, 0, 0, 0, 1, 1, 1, 1, 'Superior Shadowgem'),
(1910390, 191039, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Twisted Sabre'),
(1910390, 3575, 0, 0, 0, 1, 1, 1, 1, 'Iron Bar'),
(1910390, 5500, 0, 0, 0, 1, 1, 1, 1, 'Iridescent Pearl'),
(1910400, 191040, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Zealot Blade'),
(1910400, 3575, 0, 33.3333, 0, 1, 1, 1, 1, 'Iron Bar'),
(1910400, 5500, 0, 0, 0, 1, 1, 1, 1, 'Iridescent Pearl'),
(1910400, 185000, 0, 0, 0, 1, 1, 1, 1, 'Superior Shadowgem');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой; доля от 4 % - ссылка на таблицу книги.
UPDATE `creature_loot_template` SET `Item` = 191029, `Comment` = 'Recipe: Dragonmaw Shortsword' WHERE `Item` = 753;
UPDATE `creature_loot_template` SET `Item` = 191038, `Comment` = 'Recipe: Black Metal Shortsword' WHERE `Item` = 886;
UPDATE `reference_loot_template` SET `Item` = 191038, `Comment` = 'Recipe: Black Metal Shortsword' WHERE `Item` = 886;
UPDATE `creature_loot_template` SET `Item` = 1910300, `Reference` = 1910300, `Comment` = 'Recipe: Darkwater Talwar and materials' WHERE `Item` = 11121;

UPDATE `reference_loot_template` SET `Item` = 1910310, `Reference` = 1910310, `Comment` = 'Recipe: Sword of Corruption and materials' WHERE `Item` = 13032;
UPDATE `gameobject_loot_template` SET `Item` = 191031, `Comment` = 'Recipe: Sword of Corruption' WHERE `Item` = 13032;
UPDATE `item_loot_template` SET `Item` = 191031, `Comment` = 'Recipe: Sword of Corruption' WHERE `Item` = 13032;

UPDATE `reference_loot_template` SET `Item` = 1910320, `Reference` = 1910320, `Comment` = 'Recipe: The Black Knight and materials' WHERE `Item` = 12974;
UPDATE `gameobject_loot_template` SET `Item` = 191032, `Comment` = 'Recipe: The Black Knight' WHERE `Item` = 12974;

UPDATE `reference_loot_template` SET `Item` = 1910390, `Reference` = 1910390, `Comment` = 'Recipe: Twisted Sabre and materials' WHERE `Item` = 2011;
UPDATE `gameobject_loot_template` SET `Item` = 191039, `Comment` = 'Recipe: Twisted Sabre' WHERE `Item` = 2011;

UPDATE `reference_loot_template` SET `Item` = 1910400, `Reference` = 1910400, `Comment` = 'Recipe: Zealot Blade and materials' WHERE `Item` = 13033;
UPDATE `gameobject_loot_template` SET `Item` = 191040, `Comment` = 'Recipe: Zealot Blade' WHERE `Item` = 13033;

-- Оригинал со случайным суффиксом: шанс делится поровну между книгами его копий.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book`;
CREATE TEMPORARY TABLE `ap_tmp_book` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_book` VALUES
(3186, 191033, 'Recipe: Viking Sword of the Monkey'),
(3186, 191034, 'Recipe: Viking Sword of the Bear'),
(3186, 191035, 'Recipe: Viking Sword of Strength'),
(3186, 191036, 'Recipe: Viking Sword of the Eagle'),
(3186, 191037, 'Recipe: Viking Sword of Stamina'),
(3186, 191041, 'Recipe: Viking Sword of Spirit'),
(3186, 191042, 'Recipe: Viking Sword of the Boar'),
(3186, 191043, 'Recipe: Viking Sword of the Whale');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` = 3186) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` = 3186;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` = 3186) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` = 3186;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` = 3186) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` = 3186;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
