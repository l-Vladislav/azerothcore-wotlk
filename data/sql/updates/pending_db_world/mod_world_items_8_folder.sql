-- mod-world-items: папки размещённых предметов (#189).

CREATE TABLE IF NOT EXISTS `mod_world_items_folder` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(60) NOT NULL,
  `sort` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mod_world_items' AND COLUMN_NAME = 'folder_id');
SET @sql := IF(@has = 0,
    'ALTER TABLE `mod_world_items` ADD COLUMN `folder_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''mod_world_items_folder.id; 0 - вне папок'' AFTER `station_id`',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
