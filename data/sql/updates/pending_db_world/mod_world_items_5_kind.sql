-- mod-world-items: тип размещённого предмета. Контейнер выдаёт содержимое, верстак
-- открывает окно верстака (mod-advanced-professions, ap_station), статичный - декорация
-- без взаимодействия.

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mod_world_items' AND COLUMN_NAME = 'kind');
SET @sql := IF(@has = 0,
    'ALTER TABLE `mod_world_items` ADD COLUMN `kind` ENUM(''container'',''station'',''static'') NOT NULL DEFAULT ''container'' COMMENT ''тип: container - контейнер, station - верстак, static - декорация'' AFTER `id`',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mod_world_items' AND COLUMN_NAME = 'station_id');
SET @sql := IF(@has = 0,
    'ALTER TABLE `mod_world_items` ADD COLUMN `station_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''верстак: ap_station.id'' AFTER `kind`',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

ALTER TABLE `mod_world_items` MODIFY `kind` ENUM('container','station','static') NOT NULL DEFAULT 'container'
    COMMENT 'тип: container - контейнер, station - верстак, static - декорация';
