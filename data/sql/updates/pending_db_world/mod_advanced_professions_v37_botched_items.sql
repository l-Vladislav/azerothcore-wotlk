-- mod-advanced-professions: поделка у каждого типа.
--
-- Поделка была одна на весь верстак - «Botched Bronze Shortsword» у меча, из
-- тестовых времён. У остальных девяти типов в `fail_entry` стоял ноль, и это
-- не мелочь: при `fail_mode = 2` набор без рецепта ОТКАЗЫВАЕТ, если выдать
-- нечего (§5.4.2). То есть на кинжале, топоре и щите угадывание не работало
-- вовсе - верстак молча говорил «из такого набора ничего не выходит», хотя
-- игрок делал ровно то, ради чего угадывание задумано.
--
-- Теперь у каждого типа своя: серая, с видом самого типа, со склонением по
-- роду - «Испорченный клинок», «Испорченная булава», «Испорченное копьё».
--
-- ЧТО ОНА ТАКОЕ. Хлам (класс 15), а не оружие: надеть поделку нельзя, разобрать
-- тоже - её путь на торговца (§5.2). Продаётся за серебро, кладётся стопкой по
-- десять: череда неудач не должна превращаться в возню с сумкой.
--
-- ПОЧЕМУ ОДНА НА ТИП, А НЕ НА ПОЛОСУ. `fail_entry` живёт у типа, и этого пока
-- хватает: поделка - не награда, а след неудачи, и саронитовый обломок от
-- медного отличается только ценой. Если захочется цены по полосе, это колонка
-- у рецепта и отдельный заход.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §5.4.2.

-- --------------------------------------------------------------------------
-- 1. Повторный прогон
-- --------------------------------------------------------------------------
DELETE t FROM `item_template` t
WHERE t.`entry` BETWEEN 180100 AND 180199
  AND t.`name` LIKE 'Испорчен%'
  AND NOT EXISTS (SELECT 1 FROM `ap_item_type` y WHERE y.`fail_entry` = t.`entry`);

-- --------------------------------------------------------------------------
-- 2. Имена по роду
-- --------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `ap_scrap`;
CREATE TEMPORARY TABLE `ap_scrap` (
  `type_id` INT UNSIGNED PRIMARY KEY,
  `entry`   INT UNSIGNED NOT NULL,
  `name`    VARCHAR(255) NOT NULL,
  `display` INT UNSIGNED NOT NULL
);

INSERT INTO `ap_scrap` (`type_id`, `entry`, `name`, `display`)
SELECT t.`id`,
       180100 + ROW_NUMBER() OVER (ORDER BY t.`id`) - 1,
       CONCAT(
         CASE t.`code`
              WHEN 'axe2h'   THEN 'Испорченная'
              WHEN 'mace'    THEN 'Испорченная'
              WHEN 'polearm' THEN 'Испорченное'
              ELSE 'Испорченный' END,
         ' ',
         CASE t.`code`
              WHEN 'sword'   THEN 'клинок'
              WHEN 'sword2h' THEN 'меч'
              WHEN 'dagger'  THEN 'кинжал'
              WHEN 'axe'     THEN 'топор'
              WHEN 'axe2h'   THEN 'секира'
              WHEN 'mace'    THEN 'булава'
              WHEN 'mace2h'  THEN 'молот'
              WHEN 'polearm' THEN 'копьё'
              WHEN 'fist'    THEN 'кастет'
              WHEN 'shield'  THEN 'щит'
              ELSE LOWER(t.`name_ru`) END),
       t.`displayid`
FROM `ap_item_type` t;

-- --------------------------------------------------------------------------
-- 3. Сами поделки
-- --------------------------------------------------------------------------
-- Класс 15 подкласс 0 - «хлам». Вид берётся у типа: обломок узнаётся по силуэту
-- того, что не получилось.
INSERT IGNORE INTO `item_template`
  (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`,
   `Quality`, `Flags`, `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`,
   `Stackable`, `MaxCount`, `Material`, `Sheath`, `RequiredLevel`, `ItemLevel`,
   `bonding`)
SELECT s.`entry`, 15, 0, -1, s.`name`, s.`display`,
       0, 0, 1, 0, 120, 0, 10, 0, 1, 0, 0, 1, 0
FROM `ap_scrap` s;

UPDATE `ap_item_type` t
JOIN `ap_scrap` s ON s.`type_id` = t.`id`
SET t.`fail_entry` = s.`entry`;

DROP TEMPORARY TABLE IF EXISTS `ap_scrap`;

-- Прежняя тестовая поделка меча больше ни при чём: на неё никто не ссылается, и
-- у игроков её нет - пул выдан не был.
DELETE t FROM `item_template` t
WHERE t.`entry` = 180003
  AND NOT EXISTS (SELECT 1 FROM `ap_item_type` y WHERE y.`fail_entry` = t.`entry`)
  AND NOT EXISTS (SELECT 1 FROM `ap_recipe_result` r WHERE r.`result_entry` = t.`entry`);

-- Каталог меняется: у типов появилась поделка (§7, «Кэш каталога»).
UPDATE `ap_config` SET `value` = `value` + 1 WHERE `name` = 'catalog_version';
