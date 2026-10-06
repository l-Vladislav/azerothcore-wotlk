-- mod-advanced-professions: добыча версии вставки интеллекта полосы 35-50.
--
-- 185002 «Малый чародейный кристалл»: интеллект +4, полоса 35-50; окно
-- «Чародейного кристалла» 12363 сужено до 51-70. Предмет даёт
-- admin_panel_items.sql, строки ap_material - mod_advanced_professions_2_data.sql.
--
-- Версия падает рядом с вставкой ловкости той же полосы (185001): та же таблица,
-- шанс, группа и режим. Если группа с явными шансами превысила бы 100 %, шанс
-- 185001 делится пополам между двумя камнями. Таблицы книг эскизов
-- (1900000-1919999) не меняются.

DELETE FROM `gameobject_loot_template` WHERE `Item` = 185002;
UPDATE `gameobject_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 185001 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185002, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Lesser Arcane Crystal'
FROM `gameobject_loot_template` WHERE `Item` = 185001 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `creature_loot_template` WHERE `Item` = 185002;
UPDATE `creature_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 185001 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185002, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Lesser Arcane Crystal'
FROM `creature_loot_template` WHERE `Item` = 185001 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `reference_loot_template` WHERE `Item` = 185002;
UPDATE `reference_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 185001 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185002, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Lesser Arcane Crystal'
FROM `reference_loot_template` WHERE `Item` = 185001 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `item_loot_template` WHERE `Item` = 185002;
UPDATE `item_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 185001 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185002, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Lesser Arcane Crystal'
FROM `item_loot_template` WHERE `Item` = 185001 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `pickpocketing_loot_template` WHERE `Item` = 185002;
UPDATE `pickpocketing_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 185001 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185002, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Lesser Arcane Crystal'
FROM `pickpocketing_loot_template` WHERE `Item` = 185001 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `prospecting_loot_template` WHERE `Item` = 185002;
UPDATE `prospecting_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `prospecting_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 185001 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `prospecting_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185002, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Lesser Arcane Crystal'
FROM `prospecting_loot_template` WHERE `Item` = 185001 AND `Entry` NOT BETWEEN 1900000 AND 1919999;
