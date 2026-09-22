-- mod-advanced-professions: пул нарезан ПО ОСНОВАМ, а не по типам.
--
-- Зачем. v18 дала слайс каждому типу предмета - меч, щит, кинжал. Этого хватало,
-- пока вид обещался с точностью до рода оружия. Но основы различаются видом
-- между собой (бронзовый клинок против стального), а строка клиентской
-- `Item.dbc` статична: одному слайсу двух моделей не показать. Значит, слайс
-- принадлежит ОСНОВЕ (DESIGN §2.5, «Пул и нумерация»).
--
--   Слайс   | 256 заготовок на основу - двойной запас над самой тяжёлой
--           | ступенью (эпическая, 125 эскизов)
--   Резерв  | 2048 на основу: засеяно 256, остальное ждёт уплотнения полос
--   Блок    | 1 100 000 - 3 199 999 = 2 097 152 id = 1024 основы x 2048
--
-- Резерв дёшев: `_itemTemplateStoreFast` растягивается по максимальному
-- СУЩЕСТВУЮЩЕМУ entry (ObjectMgr.cpp:3900), а не по границе блока, и пустой
-- промежуток в нумерации не стоит ни байта.
--
-- Основа - это строка `ap_recipe_result`, то есть пара «рецепт + ступень
-- качества». Там слайс и живёт: у каждой основы своя строка `item_template`,
-- свой вид и своя иконка.
--
-- `displayid` заготовки берётся у САМОЙ основы, а не у донора типа, как было в
-- v18. Иначе основа и её пул разошлись бы видом - ровно то, ради чего нарезка и
-- переделывается.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §2.5, «Пул и нумерация».

-- --------------------------------------------------------------------------
-- 1. Границы слайса у основы
-- --------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `ap_add_column`;
DELIMITER $$
CREATE PROCEDURE `ap_add_column`(IN tbl VARCHAR(64), IN col VARCHAR(64),
                                 IN spec VARCHAR(255))
BEGIN
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl
        AND COLUMN_NAME = col) = 0 THEN
    SET @sql = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', spec);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

CALL `ap_add_column`('ap_recipe_result', 'pool_lo',
  "INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Начало слайса основы; 0 - слайса нет'");
CALL `ap_add_column`('ap_recipe_result', 'pool_hi',
  "INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Конец слайса ВКЛЮЧАЯ резерв. Засеяна только первая четверть тысячи'");

DROP PROCEDURE IF EXISTS `ap_add_column`;

-- --------------------------------------------------------------------------
-- 2. Раздача слайсов
-- --------------------------------------------------------------------------
-- Раздаём только тем, у кого слайса ещё нет, и начинаем с первого свободного
-- места. Так миграция идемпотентна, а основа, заведённая через полгода, получит
-- продолжение блока, а не сдвинет чужие границы: сдвиг переназначил бы уже
-- выданные игрокам id другой основе.
SET @stride := 2048;
SET @seed   := 256;
SET @start  := 1100000;
SET @endcap := 3199999;

SELECT COALESCE(MAX(`pool_lo`) + @stride, @start) INTO @next
FROM `ap_recipe_result` WHERE `pool_lo` > 0;

UPDATE `ap_recipe_result` r
JOIN (
  SELECT `recipe_id`, `quality`,
         ROW_NUMBER() OVER (ORDER BY `recipe_id`, `quality`) AS `rn`
  FROM `ap_recipe_result`
  WHERE `pool_lo` = 0 AND `result_entry` > 0
) q ON q.`recipe_id` = r.`recipe_id` AND q.`quality` = r.`quality`
SET r.`pool_lo` = @next + (q.`rn` - 1) * @stride,
    r.`pool_hi` = @next + (q.`rn` - 1) * @stride + @stride - 1
-- За край блока не выходим: лучше основа без слайса, о которой worldserver
-- скажет в лог, чем id, налезающий на чужой блок.
WHERE @next + (q.`rn` - 1) * @stride + @stride - 1 <= @endcap;

-- --------------------------------------------------------------------------
-- 3. Сами заготовки
-- --------------------------------------------------------------------------
-- Вид, ножны, материал, класс и подкласс берём у САМОЙ основы: её строка уже
-- заведена в панели и уже такая, какой её увидит игрок. Донор типа из v18
-- больше не нужен - и не годится, он давал всем мечам один вид.
DROP TEMPORARY TABLE IF EXISTS `ap_slice`;
CREATE TEMPORARY TABLE `ap_slice` (
  `lo`       INT UNSIGNED PRIMARY KEY,
  `class`    TINYINT UNSIGNED NOT NULL,
  `subclass` TINYINT UNSIGNED NOT NULL,
  `sound`    INT NOT NULL,
  `invtype`  TINYINT UNSIGNED NOT NULL,
  `material` TINYINT NOT NULL,
  `sheath`   TINYINT UNSIGNED NOT NULL,
  `display`  INT UNSIGNED NOT NULL
);

INSERT INTO `ap_slice`
SELECT r.`pool_lo`, b.`class`, b.`subclass`, b.`SoundOverrideSubclass`,
       b.`InventoryType`, b.`Material`, b.`Sheath`, b.`displayid`
FROM `ap_recipe_result` r
JOIN `item_template` b ON b.`entry` = r.`result_entry`
WHERE r.`pool_lo` > 0;

-- Заготовки помечены ITEM_FLAG_DEPRECATED (0x10) - «нельзя надеть и нельзя
-- использовать»: попади такая строка игроку до выдачи, она будет мусором в
-- сумке, а не работающим предметом. При выдаче модуль флаг снимает вместе со
-- всей строкой - он копирует основу целиком.
SET SESSION cte_max_recursion_depth = 1000;

DROP TEMPORARY TABLE IF EXISTS `ap_seq`;
CREATE TEMPORARY TABLE `ap_seq` (`n` INT UNSIGNED PRIMARY KEY);
INSERT INTO `ap_seq`
WITH RECURSIVE `seq` (`n`) AS (
  SELECT 0
  UNION ALL
  SELECT `n` + 1 FROM `seq` WHERE `n` < @seed - 1
)
SELECT `n` FROM `seq`;

-- REPLACE, а не INSERT IGNORE: блок 1 100 000 - 1 199 999 уже засеян по типам
-- (v18), и эти же id теперь принадлежат основам. Оставить их с прежним видом
-- значило бы ровно ту рассинхронизацию, ради которой нарезка и переделана.
--
-- Выданным id это не грозит: они лежат в резерве слайсов, а не в засеваемой
-- четверти тысячи, и под REPLACE не попадают. Проверка ниже это подтверждает.
REPLACE INTO `item_template`
  (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`,
   `Quality`, `Flags`, `InventoryType`, `Stackable`, `MaxCount`, `Material`,
   `Sheath`)
SELECT s.`lo` + q.`n`, s.`class`, s.`subclass`, s.`sound`,
       CONCAT('[заготовка верстака ', s.`lo` + q.`n`, ']'),
       s.`display`, 0, 16, s.`invtype`, 1, 0, s.`material`, s.`sheath`
FROM `ap_slice` s
JOIN `ap_seq` q
WHERE NOT EXISTS (SELECT 1 FROM `ap_generated_item` g
                  WHERE g.`entry` = s.`lo` + q.`n`);

-- --------------------------------------------------------------------------
-- 4. Прежняя нарезка по типам уходит
-- --------------------------------------------------------------------------
-- Заготовки, которые не попали ни в один слайс основы, больше не нужны: сто
-- тысяч строк держать в памяти на каждом старте не за что. Выданные не трогаем
-- ни при каких условиях - у игрока в сумке лежит вещь с этим entry, и удаление
-- строки превратило бы её в «предмет не существует».
DELETE t FROM `item_template` t
WHERE t.`entry` BETWEEN @start AND @endcap
  AND NOT EXISTS (SELECT 1 FROM `ap_generated_item` g WHERE g.`entry` = t.`entry`)
  AND NOT EXISTS (
    SELECT 1 FROM `ap_slice` s JOIN `ap_seq` q
    WHERE s.`lo` + q.`n` = t.`entry`);

DROP TEMPORARY TABLE IF EXISTS `ap_slice`;
DROP TEMPORARY TABLE IF EXISTS `ap_seq`;

-- Слайсы типа больше не читает никто: их место заняли слайсы основ. Колонки
-- оставляем до ближайшей чистки легаси - так же, как v21 оставила `kind`.
UPDATE `ap_item_type` SET `pool_lo` = 0, `pool_hi` = 0;
