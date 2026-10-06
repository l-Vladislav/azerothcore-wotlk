-- Книги эскизов основ 184133 и 184135; книга с долей от 4 % делит её с материалами
-- Таблица ссылок книги (номер книги × 10): книга, слиток основы и вставки эскиза по трети.
DELETE FROM `reference_loot_template` WHERE `Entry` IN (1900010, 1910000, 1910020, 1910030, 1910040, 1910120, 1910130, 1910140);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(1900010, 190001, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Defias Rapier'),
(1900010, 2840, 0, 0, 0, 1, 1, 1, 1, 'Copper Bar'),
(1900010, 774, 0, 0, 0, 1, 1, 1, 1, 'Malachite'),
(1910000, 191000, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Blackwater Cutlass'),
(1910000, 2841, 0, 0, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1910000, 774, 0, 0, 0, 1, 1, 1, 1, 'Malachite'),
(1910020, 191002, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Buzz Saw'),
(1910020, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1910020, 774, 0, 0, 0, 1, 1, 1, 1, 'Malachite'),
(1910020, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1910030, 191003, 0, 33.3333, 0, 1, 1, 1, 1, 'Recipe: Butcher''s Slicer'),
(1910030, 2841, 0, 33.3333, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1910030, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1910030, 5498, 0, 0, 0, 1, 1, 1, 1, 'Small Lustrous Pearl'),
(1910040, 191004, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Cursed Felblade'),
(1910040, 2841, 0, 0, 0, 1, 1, 1, 1, 'Bronze Bar'),
(1910040, 1210, 0, 0, 0, 1, 1, 1, 1, 'Shadowgem'),
(1910120, 191012, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Notched Shortsword of Strength'),
(1910120, 2840, 0, 0, 0, 1, 1, 1, 1, 'Copper Bar'),
(1910120, 818, 0, 0, 0, 1, 1, 1, 1, 'Tigerseye'),
(1910130, 191013, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Notched Shortsword of Stamina'),
(1910130, 2840, 0, 0, 0, 1, 1, 1, 1, 'Copper Bar'),
(1910130, 5498, 0, 0, 0, 1, 1, 1, 1, 'Small Lustrous Pearl'),
(1910140, 191014, 0, 0, 0, 1, 1, 1, 1, 'Recipe: Notched Shortsword of Intellect'),
(1910140, 2840, 0, 0, 0, 1, 1, 1, 1, 'Copper Bar'),
(1910140, 1210, 0, 0, 0, 1, 1, 1, 1, 'Shadowgem');

-- Книги из mod_advanced_professions_4 с долей от 4 % - ссылка на таблицу книги с тем же шансом и группой.
UPDATE `creature_loot_template` SET `Item` = 1900010, `Reference` = 1900010, `Comment` = 'Recipe: Defias Rapier and materials' WHERE `Item` = 190001 AND `Chance` >= 4;
UPDATE `creature_loot_template` SET `Item` = 1910000, `Reference` = 1910000, `Comment` = 'Recipe: Blackwater Cutlass and materials' WHERE `Item` = 191000 AND `Chance` >= 4;
UPDATE `creature_loot_template` SET `Item` = 1910020, `Reference` = 1910020, `Comment` = 'Recipe: Buzz Saw and materials' WHERE `Item` = 191002 AND `Chance` >= 4;
UPDATE `creature_loot_template` SET `Item` = 1910030, `Reference` = 1910030, `Comment` = 'Recipe: Butcher''s Slicer and materials' WHERE `Item` = 191003 AND `Chance` >= 4;
UPDATE `creature_loot_template` SET `Item` = 1910040, `Reference` = 1910040, `Comment` = 'Recipe: Cursed Felblade and materials' WHERE `Item` = 191004 AND `Chance` >= 4;

-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой.
UPDATE `creature_loot_template` SET `Item` = 191009, `Comment` = 'Recipe: Slicer Blade' WHERE `Item` = 820;
UPDATE `creature_loot_template` SET `Item` = 191010, `Comment` = 'Recipe: Redridge Machete' WHERE `Item` = 1219;
UPDATE `creature_loot_template` SET `Item` = 191011, `Comment` = 'Recipe: Scimitar of Atun' WHERE `Item` = 1469;
UPDATE `reference_loot_template` SET `Item` = 191011, `Comment` = 'Recipe: Scimitar of Atun' WHERE `Item` = 1469;

-- Оригинал со случайным суффиксом: шанс делится поровну между книгами его копий.
-- Доля в группе с равными шансами записывается явным шансом; доля книги от 4 % уходит в таблицу книги.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_book`;
CREATE TEMPORARY TABLE `ap_tmp_book` (`original` int unsigned, `book` int unsigned, `ref` int unsigned, `comment` varchar(255));
INSERT INTO `ap_tmp_book` VALUES
(727, 191012, 1910120, 'Recipe: Notched Shortsword of Strength'),
(727, 191013, 1910130, 'Recipe: Notched Shortsword of Stamina'),
(727, 191014, 1910140, 'Recipe: Notched Shortsword of Intellect'),
(15210, 191015, 0, 'Recipe: Raider Shortsword of Strength'),
(15210, 191016, 0, 'Recipe: Raider Shortsword of the Monkey'),
(15210, 191017, 0, 'Recipe: Raider Shortsword of Stamina');

INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, IF(s.`share` >= 4 AND b.`ref`, b.`ref`, b.`book`), IF(s.`share` >= 4 AND b.`ref`, b.`ref`, 0), s.`share`,
       s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) / 3 AS `share`
      FROM `reference_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (727, 15210)) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`;
DELETE FROM `reference_loot_template` WHERE `Item` IN (727, 15210);

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, IF(s.`share` >= 4 AND b.`ref`, b.`ref`, b.`book`), IF(s.`share` >= 4 AND b.`ref`, b.`ref`, 0), s.`share`,
       s.`QuestRequired`, s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, b.`comment`
FROM (SELECT o.*, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) / 3 AS `share`
      FROM `gameobject_loot_template` o
      JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
            FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
        ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
      WHERE o.`Item` IN (727, 15210)) s
JOIN `ap_tmp_book` b ON b.`original` = s.`Item`;
DELETE FROM `gameobject_loot_template` WHERE `Item` IN (727, 15210);

DROP TEMPORARY TABLE `ap_tmp_book`;
