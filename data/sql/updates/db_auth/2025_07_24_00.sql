-- DB update 2025_07_03_00 -> 2025_07_24_00
--
SET @column_exists = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'account' AND COLUMN_NAME = 'Flags');
SET @query = IF(@column_exists = 0, 'ALTER TABLE `account` ADD COLUMN `Flags` INT UNSIGNED NOT NULL DEFAULT \'0\' AFTER `expansion`', 'SELECT 1');
PREPARE stmt FROM @query;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
