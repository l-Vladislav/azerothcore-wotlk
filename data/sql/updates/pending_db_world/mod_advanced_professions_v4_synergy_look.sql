-- mod-advanced-professions: у синергии появляется собственный внешний вид.
--
-- Сработавшее «рунное слово» переименовывает предмет - логично, чтобы оно и
-- выглядело иначе. `displayid` это одно поле на две вещи: и иконка в сумке, и
-- 3D-модель в руках (ItemDisplayInfo.dbc). Ноль значит «оставить вид основы»,
-- то есть старые синергии продолжают работать как раньше.

SET @add := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_synergy'
               AND COLUMN_NAME = 'displayid');
SET @sql := IF(@add = 0,
    'ALTER TABLE `ap_synergy` ADD COLUMN `displayid` INT UNSIGNED NOT NULL '
    'DEFAULT 0 COMMENT ''0 = оставить внешний вид основы'' AFTER `stat_value`',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
