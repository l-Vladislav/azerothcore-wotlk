-- mod-advanced-professions: вставка выносливости полосы 1-20.
--
-- 185008 «Осколок лунного камня»: выносливость +1, полоса 1-20; «Маленькая
-- блестящая жемчужина» 5498 переходит на дух +1. Предмет даёт
-- admin_panel_items.sql, строки ap_material и эскизов - mod_advanced_professions_2_data.sql.
--
-- Осколок падает рядом с «Камнем теней» (1210): та же таблица, шанс, группа и
-- режим. Если группа с явными шансами превысила бы 100 %, шанс 1210 делится
-- пополам между двумя камнями. Таблицы книг эскизов (1900000-1919999) не меняются.

DELETE FROM `gameobject_loot_template` WHERE `Item` = 185008;
UPDATE `gameobject_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `gameobject_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 1210 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185008, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Moonstone Shard'
FROM `gameobject_loot_template` WHERE `Item` = 1210 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `creature_loot_template` WHERE `Item` = 185008;
UPDATE `creature_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 1210 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185008, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Moonstone Shard'
FROM `creature_loot_template` WHERE `Item` = 1210 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `reference_loot_template` WHERE `Item` = 185008;
UPDATE `reference_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 1210 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185008, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Moonstone Shard'
FROM `reference_loot_template` WHERE `Item` = 1210 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `item_loot_template` WHERE `Item` = 185008;
UPDATE `item_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `item_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 1210 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `item_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185008, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Moonstone Shard'
FROM `item_loot_template` WHERE `Item` = 1210 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `pickpocketing_loot_template` WHERE `Item` = 185008;
UPDATE `pickpocketing_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `pickpocketing_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 1210 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `pickpocketing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185008, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Moonstone Shard'
FROM `pickpocketing_loot_template` WHERE `Item` = 1210 AND `Entry` NOT BETWEEN 1900000 AND 1919999;

DELETE FROM `prospecting_loot_template` WHERE `Item` = 185008;
UPDATE `prospecting_loot_template` x
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `total` FROM `prospecting_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = x.`Entry` AND g.`GroupId` = x.`GroupId`
SET x.`Chance` = x.`Chance` / 2
WHERE x.`Item` = 1210 AND x.`GroupId` > 0 AND x.`Chance` > 0 AND g.`total` + x.`Chance` > 100
  AND x.`Entry` NOT BETWEEN 1900000 AND 1919999;
INSERT INTO `prospecting_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, 185008, 0, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Moonstone Shard'
FROM `prospecting_loot_template` WHERE `Item` = 1210 AND `Entry` NOT BETWEEN 1900000 AND 1919999;
