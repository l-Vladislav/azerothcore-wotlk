-- mod-world-items: область (подзона) размещённого предмета (#152).
-- Считается сервером по vmaps: кварталы городов задаются областями WMO и по сетке карты не видны.

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mod_world_items' AND COLUMN_NAME = 'area');
SET @sql := IF(@has = 0,
    'ALTER TABLE `mod_world_items` ADD COLUMN `area` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''область (AreaTable) по vmaps; 0 - не посчитана'' AFTER `zone`',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
