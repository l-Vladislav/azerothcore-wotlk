-- Книги эскизов основы 184136 «Бронзовая сабля» и основы добычи 184149 «Сломанный Тяжелый ятаган мародера»
-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1910200, 1910210);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1910200, 191020, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Sword of the Night Sky'),
(1910200, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1910200, 1529, 0, 0, 0, 1, 1, 1, 1, 'Jade'),
(1910200, 1206, 0, 0, 0, 1, 1, 1, 1, 'Moss Agate'),
(1910210, 191021, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Thief''s Blade'),
(1910210, 2841, 0, 0, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1910210, 1529, 0, 0, 0, 1, 1, 1, 1, 'Jade');

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой; доля от 4 % - ссылка на таблицу книги.
UPDATE `creature_loot_template` SET `Item` = 1910200, `Reference` = 1910200, `Comment` = 'Recipe: Sword of the Night Sky and materials' WHERE `Item` = 2035;
UPDATE `creature_loot_template` SET `Item` = 1910210, `Reference` = 1910210, `Comment` = 'Recipe: Thief''s Blade and materials' WHERE `Item` = 5192;
UPDATE `creature_loot_template` SET `Item` = 191022, `Comment` = 'Recipe: Skeletal Longsword' WHERE `Item` = 2018;

-- Основа добычи: сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20) с тем же шансом.
UPDATE `creature_loot_template` SET `Item` = 180031, `Comment` = 'Broken Heavy Marauder Scimitar' WHERE `Item` = 1493;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` = 191028;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, 191028, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, 20, 1, 1, 'Recipe: Heavy Marauder Scimitar'
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
WHERE o.`Item` = 180031;

-- Оригинал со случайным суффиксом: шанс делится поровну между книгами его копий.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book`;
CREATE TEMPORARY TABLE `ap_tmp_book` (`original` int unsigned, `book` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_book` VALUES
(3740, 191024, 'Recipe: Decapitating Sword of Strength'),
(3740, 191025, 'Recipe: Decapitating Sword of Stamina'),
(15212, 191026, 'Recipe: Fighter Broadsword of Strength'),
(15212, 191027, 'Recipe: Fighter Broadsword of the Monkey'),
(15212, 191023, 'Recipe: Fighter Broadsword of the Bear');
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book_count`;
CREATE TEMPORARY TABLE `ap_tmp_book_count` SELECT `original`, COUNT(*) AS `n` FROM `ap_tmp_book` GROUP BY `original`;

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (3740, 15212)) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (3740, 15212);

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, b.`book`, 0, s.`share` / c.`n`, s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (3740, 15212)) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`
JOIN `ap_tmp_book_count` c ON c.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (3740, 15212);

DROP TEMPORARY TABLE `ap_tmp_book_count`;
DROP TEMPORARY TABLE `ap_tmp_book`;
