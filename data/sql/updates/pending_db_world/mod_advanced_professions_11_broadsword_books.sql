-- Книги эскизов основы 184138 «Палаш»
-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1910440, 1910450, 1910460, 1910470, 1910480);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1910440, 191044, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Speedsteel Rapier'),
(1910440, 3859, 0, 0, 0, 1, 1, 1, 1, 'Steel Bar'),
(1910440, 185001, 0, 0, 0, 1, 1, 1, 1, 'Superior Jade'),
(1910450, 191045, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Silithid Ripper'),
(1910450, 3859, 0, 0, 0, 1, 1, 1, 1, 'Steel Bar'),
(1910450, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1910460, 191046, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Blade of the Basilisk'),
(1910460, 3859, 0, 0, 0, 1, 1, 1, 1, 'Steel Bar'),
(1910460, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1910470, 191047, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Scorpion Sting'),
(1910470, 3859, 0, 33.3333, 0, 1, 1, 1, 1, 'Steel Bar'),
(1910470, 185001, 0, 0, 0, 1, 1, 1, 1, 'Superior Jade'),
(1910470, 7909, 0, 0, 0, 1, 1, 1, 1, 'Aquamarine'),
(1910480, 191048, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Dazzling Longsword'),
(1910480, 3859, 0, 33.3333, 0, 1, 1, 1, 1, 'Steel Bar'),
(1910480, 3864, 0, 0, 0, 1, 1, 1, 1, 'Citrine'),
(1910480, 185001, 0, 0, 0, 1, 1, 1, 1, 'Superior Jade');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой; доля от 4 % - ссылка на таблицу книги.
UPDATE `reference_loot_template` SET `Item` = 1910440, `Reference` = 1910440, `Comment` = 'Recipe: Speedsteel Rapier and materials' WHERE `Item` = 13034;
UPDATE `gameobject_loot_template` SET `Item` = 191044, `Comment` = 'Recipe: Speedsteel Rapier' WHERE `Item` = 13034;

UPDATE `creature_loot_template` SET `Item` = 1910450, `Reference` = 1910450, `Comment` = 'Recipe: Silithid Ripper and materials' WHERE `Item` = 8224;

UPDATE `creature_loot_template` SET `Item` = 1910460, `Reference` = 1910460, `Comment` = 'Recipe: Blade of the Basilisk and materials' WHERE `Item` = 8223;

UPDATE `reference_loot_template` SET `Item` = 1910470, `Reference` = 1910470, `Comment` = 'Recipe: Scorpion Sting and materials' WHERE `Item` = 1265;
UPDATE `gameobject_loot_template` SET `Item` = 191047, `Comment` = 'Recipe: Scorpion Sting' WHERE `Item` = 1265;

UPDATE `reference_loot_template` SET `Item` = 1910480, `Reference` = 1910480, `Comment` = 'Recipe: Dazzling Longsword and materials' WHERE `Item` = 869;
UPDATE `gameobject_loot_template` SET `Item` = 191048, `Comment` = 'Recipe: Dazzling Longsword' WHERE `Item` = 869;

-- Оригинал со случайным суффиксом: шанс делится поровну между книгами его копий.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book`;
CREATE TEMPORARY TABLE `ap_tmp_book` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_book` VALUES
(15215, 191049, 'Recipe: Furious Falchion of the Bear'),
(15215, 191050, 'Recipe: Furious Falchion of the Monkey'),
(15215, 191051, 'Recipe: Furious Falchion of the Tiger'),
(15215, 191052, 'Recipe: Furious Falchion of Strength'),
(15215, 191053, 'Recipe: Furious Falchion of Stamina'),
(15213, 191054, 'Recipe: Mercenary Blade of Strength'),
(15213, 191055, 'Recipe: Mercenary Blade of Stamina'),
(864, 191056, 'Recipe: Knightly Longsword of Agility'),
(864, 191057, 'Recipe: Knightly Longsword of Spirit'),
(864, 191058, 'Recipe: Knightly Longsword of Intellect'),
(864, 191059, 'Recipe: Knightly Longsword of the Wolf'),
(864, 191060, 'Recipe: Knightly Longsword of the Boar'),
(864, 191061, 'Recipe: Knightly Longsword of the Whale'),
(864, 191062, 'Recipe: Knightly Longsword of the Falcon'),
(864, 191063, 'Recipe: Knightly Longsword of the Eagle'),
(864, 191064, 'Recipe: Knightly Longsword of the Gorilla'),
(864, 191065, 'Recipe: Knightly Longsword of the Owl');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `creature_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15215, 15213, 864) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `creature_loot_template` WHERE `Item` IN (15215, 15213, 864) AND `Reference` = 0;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15215, 15213, 864) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (15215, 15213, 864) AND `Reference` = 0;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (15215, 15213, 864) AND o.`Reference` = 0) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (15215, 15213, 864) AND `Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
