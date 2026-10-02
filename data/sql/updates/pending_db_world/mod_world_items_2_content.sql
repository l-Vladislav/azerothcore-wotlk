-- mod-world-items: содержимое контейнера - отдельная таблица, строка на предмет.
-- Размещение (mod_world_items) задаёт только оболочку, место и правила подбора.

CREATE TABLE IF NOT EXISTS `mod_world_items_content` (
  `placement_id` INT UNSIGNED NOT NULL COMMENT 'mod_world_items.id',
  `item_entry`   INT UNSIGNED NOT NULL COMMENT 'item_template.entry',
  `count_min`    INT UNSIGNED NOT NULL DEFAULT 1,
  `count_max`    INT UNSIGNED NOT NULL DEFAULT 1,
  `chance`       FLOAT NOT NULL DEFAULT 100 COMMENT 'процент; 100 - всегда',
  PRIMARY KEY (`placement_id`, `item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Перенос предмета из прежних колонок размещения.
SET @has_item := (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mod_world_items'
      AND COLUMN_NAME = 'item_entry');

SET @sql := IF(@has_item > 0,
    'INSERT IGNORE INTO `mod_world_items_content` (`placement_id`, `item_entry`, `count_min`, `count_max`)
     SELECT `id`, `item_entry`, GREATEST(`item_count`, 1), GREATEST(`item_count`, 1)
     FROM `mod_world_items` WHERE `item_entry` <> 0',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(@has_item > 0,
    'ALTER TABLE `mod_world_items` DROP INDEX `idx_item`, DROP COLUMN `item_entry`, DROP COLUMN `item_count`',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

ALTER TABLE `mod_world_items`
  MODIFY `one_per_char` TINYINT UNSIGNED NOT NULL DEFAULT 1
    COMMENT '1 - у каждого персонажа свой подбор; 0 - общий: открывший забирает для всех',
  MODIFY `respawn_secs` INT UNSIGNED NOT NULL DEFAULT 0
    COMMENT 'через сколько секунд снова доступен; 0 при one_per_char=1 - никогда, при 0 - 300';
