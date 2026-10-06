-- Книги эскизов основ 184133, 184134 и 184135 вместо добычи именных предметов
-- Предмет с одной книгой: книга занимает его строки с тем же шансом и группой.
UPDATE `creature_loot_template` SET `Item` = 190001, `Comment` = 'Recipe: Defias Rapier' WHERE `Item` = 1925;
UPDATE `creature_loot_template` SET `Item` = 191000, `Comment` = 'Recipe: Blackwater Cutlass' WHERE `Item` = 1951;
UPDATE `creature_loot_template` SET `Item` = 191001, `Comment` = 'Recipe: Bluegill Kukri' WHERE `Item` = 2046;
UPDATE `creature_loot_template` SET `Item` = 191002, `Comment` = 'Recipe: Buzz Saw' WHERE `Item` = 1937;
UPDATE `creature_loot_template` SET `Item` = 191003, `Comment` = 'Recipe: Butcher''s Slicer' WHERE `Item` = 6633;
UPDATE `creature_loot_template` SET `Item` = 191004, `Comment` = 'Recipe: Cursed Felblade' WHERE `Item` = 14145;

UPDATE `reference_loot_template` SET `Item` = 191006, `Comment` = 'Recipe: Militant Shortsword of the Monkey' WHERE `Item` = 15211;
UPDATE `gameobject_loot_template` SET `Item` = 191006, `Comment` = 'Recipe: Militant Shortsword of the Monkey' WHERE `Item` = 15211;

-- «Северный короткий меч» (2078): шанс оригинала делится поровну между книгами трёх копий.
-- Доля в группе с равными шансами записывается книгам явным шансом: доли остальных предметов не меняются.
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, b.`book`, o.`Reference`,
       IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) / 3,
       o.`QuestRequired`, o.`LootMode`, o.`GroupId`, o.`MinCount`, o.`MaxCount`, b.`comment`
FROM `reference_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN (SELECT 191005 AS `book`, 'Recipe: Northern Shortsword of Stamina' AS `comment`
      UNION ALL SELECT 191007, 'Recipe: Northern Shortsword of Strength'
      UNION ALL SELECT 191008, 'Recipe: Northern Shortsword of the Monkey') b
WHERE o.`Item` = 2078;
DELETE FROM `reference_loot_template` WHERE `Item` = 2078;

INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, b.`book`, o.`Reference`,
       IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`) / 3,
       o.`QuestRequired`, o.`LootMode`, o.`GroupId`, o.`MinCount`, o.`MaxCount`, b.`comment`
FROM `gameobject_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN (SELECT 191005 AS `book`, 'Recipe: Northern Shortsword of Stamina' AS `comment`
      UNION ALL SELECT 191007, 'Recipe: Northern Shortsword of Strength'
      UNION ALL SELECT 191008, 'Recipe: Northern Shortsword of the Monkey') b
WHERE o.`Item` = 2078;
DELETE FROM `gameobject_loot_template` WHERE `Item` = 2078;
