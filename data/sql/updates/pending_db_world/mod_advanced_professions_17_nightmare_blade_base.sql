-- Основа добычи 184156 «Сломанный Кошмарный клинок»: сломанная основа занимает строки оригинала 20577,
-- книга эскиза - группа 20 с долей оригинала в его группе.
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` = 191106;
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, 191106, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, 20, 1, 1, 'Recipe: Nightmare Blade'
FROM `reference_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
WHERE o.`Item` IN (20577, 180088) AND o.`Reference` = 0 AND o.`GroupId` <> 20;

UPDATE `reference_loot_template` SET `Item` = 180088, `Comment` = 'Broken Nightmare Blade'
WHERE `Item` = 20577 AND `Reference` = 0;
UPDATE `creature_loot_template` SET `Item` = 180088, `Comment` = 'Broken Nightmare Blade'
WHERE `Item` = 20577 AND `Reference` = 0;
