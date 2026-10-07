-- Основы добычи: Зул'Гуруб - 184186 «Сломанный Боевой клинок племени Хаккари», 184187 «Сломанная Защита Повелителя Крови», 184188 «Сломанный Кровавый зов», 184189 «Сломанный Боевой клинок племени Хаккари», 184190 «Сломанный Зулианский тесак», 184191 «Сломанный Посредник душ Ренатаки», 184192 «Сломанный Огненный Мститель»
-- Сломанный предмет встаёт в строку оригинала, книга эскиза - в группу именных рецептов (GroupId 20) с тем же шансом.
-- Доля в группе с равными шансами записывается явным шансом.
DROP TEMPORARY TABLE IF EXISTS `ap_tmp_drop_base`;
CREATE TEMPORARY TABLE `ap_tmp_drop_base` (`original` int unsigned, `broken` int unsigned, `book` int unsigned,
                                           `broken_comment` varchar(255), `book_comment` varchar(255));
INSERT INTO `ap_tmp_drop_base` VALUES
(19866, 180149, 191149, 'Broken Warblade of the Hakkari', 'Recipe: Warblade of the Hakkari'),
(19867, 180150, 191150, 'Broken Bloodlord''s Defender', 'Recipe: Bloodlord''s Defender'),
(19864, 180151, 191151, 'Broken Bloodcaller', 'Recipe: Bloodcaller'),
(19865, 180152, 191152, 'Broken Warblade of the Hakkari', 'Recipe: Warblade of the Hakkari'),
(19901, 180153, 191153, 'Broken Zulian Slicer', 'Recipe: Zulian Slicer'),
(19964, 180154, 191154, 'Broken Renataki''s Soul Conduit', 'Recipe: Renataki''s Soul Conduit'),
(19968, 180155, 191155, 'Broken Fiery Retributer', 'Recipe: Fiery Retributer');

UPDATE `creature_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191149, 191150, 191151, 191152, 191153, 191154, 191155);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, b.`book`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, 20, 1, 1, b.`book_comment`
FROM `creature_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `creature_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_drop_base` b ON b.`broken` = o.`Item`
WHERE o.`Reference` = 0;

UPDATE `reference_loot_template` o JOIN `ap_tmp_drop_base` b ON b.`original` = o.`Item`
SET o.`Item` = b.`broken`, o.`Comment` = b.`broken_comment` WHERE o.`Reference` = 0;
DELETE FROM `reference_loot_template` WHERE `GroupId` = 20 AND `Item` IN (191149, 191150, 191151, 191152, 191153, 191154, 191155);
INSERT INTO `reference_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT o.`Entry`, b.`book`, 0, IF(o.`Chance` > 0, o.`Chance`, (100 - g.`explicit_sum`) / g.`equal_count`),
       0, o.`LootMode`, 20, 1, 1, b.`book_comment`
FROM `reference_loot_template` o
JOIN (SELECT `Entry`, `GroupId`, SUM(`Chance`) AS `explicit_sum`, SUM(`Chance` = 0) AS `equal_count`
      FROM `reference_loot_template` GROUP BY `Entry`, `GroupId`) g
  ON g.`Entry` = o.`Entry` AND g.`GroupId` = o.`GroupId`
JOIN `ap_tmp_drop_base` b ON b.`broken` = o.`Item`
WHERE o.`Reference` = 0;

DROP TEMPORARY TABLE `ap_tmp_drop_base`;
