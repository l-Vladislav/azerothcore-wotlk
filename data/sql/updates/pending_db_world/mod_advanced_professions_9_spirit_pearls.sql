-- Вставка духа: жемчуг полос 21-35 (5500), 36-50 (7971), 51-70 (13926)
-- У существа падает жемчужина его полосы (по наибольшему уровню существ таблицы); шанс сохраняется,
-- две жемчужины одной таблицы сливаются в одну строку с суммой шансов.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_loot_level`;
CREATE TEMPORARY TABLE `ap_tmp_loot_level` (PRIMARY KEY (`Entry`))
SELECT `lootid` AS `Entry`, MAX(`maxlevel`) AS `level` FROM `creature_template` WHERE `lootid` > 0 GROUP BY `lootid`;

DROP TEMPORARY TABLE IF EXISTS `ap_tmp_pearl`;
CREATE TEMPORARY TABLE `ap_tmp_pearl` (PRIMARY KEY (`Entry`))
SELECT c.`Entry`, IF(t.`level` <= 50, 7971, 13926) AS `pearl`, SUM(c.`Chance`) AS `Chance`
FROM `creature_loot_template` c
JOIN `ap_tmp_loot_level` t ON t.`Entry` = c.`Entry`
WHERE t.`level` > 35 AND c.`Item` IN (5500, 7971, 13926)
GROUP BY c.`Entry`, t.`level`
HAVING SUM(c.`Item` <> IF(t.`level` <= 50, 7971, 13926)) > 0;

DELETE c FROM `creature_loot_template` c JOIN `ap_tmp_pearl` p ON p.`Entry` = c.`Entry` WHERE c.`Item` IN (5500, 7971, 13926);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `Entry`, `pearl`, 0, `Chance`, 0, 1, 0, 1, 1, IF(`pearl` = 7971, 'Black Pearl', 'Golden Pearl') FROM `ap_tmp_pearl`;

DROP TEMPORARY TABLE `ap_tmp_pearl`;
DROP TEMPORARY TABLE `ap_tmp_loot_level`;

-- «Моллюск-болтун» (7973, вскрытие 58165): «Черная жемчужина» 4 -> 5 %, «Радужная жемчужина» 1 -> 2 %
UPDATE `spell_loot_template` SET `Chance` = 5 WHERE `Entry` = 58165 AND `Item` = 7971;
UPDATE `spell_loot_template` SET `Chance` = 2 WHERE `Entry` = 58165 AND `Item` = 5500;

-- Продажа у торговцев рыболовными снастями с ограниченным запасом
DELETE FROM `npc_vendor` WHERE `item` IN (5500, 7971, 13926) AND `entry` IN (1678, 2383, 2626, 3178, 3572, 7945, 12031);
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(3178, 0, 5500, 2, 3600, 0),
(2383, 0, 5500, 2, 3600, 0),
(3572, 0, 5500, 2, 3600, 0),
(1678, 0, 5500, 2, 3600, 0),
(2626, 0, 7971, 2, 3600, 0),
(7945, 0, 7971, 2, 3600, 0),
(12031, 0, 7971, 2, 3600, 0),
(2626, 0, 13926, 1, 7200, 0);
