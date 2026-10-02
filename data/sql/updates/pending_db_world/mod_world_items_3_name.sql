-- mod-world-items: имя контейнера в игре.
-- Клиент кэширует имя объекта по entry, поэтому переименованный контейнер
-- получает свою копию gameobject_template в блоке 900000-909999; base_entry -
-- шаблон, с которого копия снята.

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mod_world_items' AND COLUMN_NAME = 'base_entry');
SET @sql := IF(@has = 0,
    'ALTER TABLE `mod_world_items` ADD COLUMN `base_entry` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''исходный gameobject_template.entry оболочки'' AFTER `go_entry`',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mod_world_items' AND COLUMN_NAME = 'name');
SET @sql := IF(@has = 0,
    'ALTER TABLE `mod_world_items` ADD COLUMN `name` VARCHAR(100) NOT NULL DEFAULT '''' COMMENT ''имя в игре; пусто - имя шаблона'' AFTER `base_entry`',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE `mod_world_items` SET `base_entry` = `go_entry` WHERE `base_entry` = 0;
