-- mod-advanced-professions: строгое совпадение качества у вставки.
--
-- Зачем. Качество - единственный рычаг, который держит комбинаторику в рамках.
-- Гнёзд у основы столько, какого она качества (1..5), число эскизов растёт от
-- гнёзд степенью, а камней своего качества в мире тем меньше, чем оно выше. Два
-- правила тянут в одну сторону: эскизов выходит от 12 до 125 на основу вместо
-- десятков тысяч (DESIGN §2.5, «Качество, слоты, материалы»).
--
-- Правило: зелёный камень идёт только в зелёную основу. Сравнивается качество
-- строки item_template самого камня с качеством вещи-цели - хранить его в
-- ap_material незачем, оно уже есть.
--
-- Исключения задаются парой `quality_min` / `quality_max` у материала, ноль -
-- «границы нет». Пара работает ровно как уже сделанная для уровня, с одной
-- оговоркой: пока обе нули, действует СТРОГОЕ совпадение, а не «всё подряд».
-- Проставили хоть одну - строгое правило заменяется этим окном.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §2.5, §5.7.

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

CALL `ap_add_column`('ap_material', 'quality_min',
  "TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Нижнее качество вещи-цели; 0 - границы нет'");
CALL `ap_add_column`('ap_material', 'quality_max',
  "TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Верхнее качество вещи-цели; 0 - границы нет. Обе нули - строгое совпадение с качеством самого камня'");

DROP PROCEDURE IF EXISTS `ap_add_column`;

-- Данные не трогаем: нули у всех камней и означают строгое совпадение, то есть
-- ровно то правило, ради которого миграция и написана. Четыре нынешних камня -
-- зелёные, и с этого дня они идут только в зелёные основы.
