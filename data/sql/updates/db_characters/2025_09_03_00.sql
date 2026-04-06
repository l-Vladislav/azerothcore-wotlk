-- DB update 2025_07_29_00 -> 2025_09_03_00
-- Add petition_id column to petition table (if not exists)
SET @col_exists = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'petition' AND COLUMN_NAME = 'petition_id');
SET @q = IF(@col_exists = 0, 'ALTER TABLE `petition` ADD COLUMN `petition_id` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `petitionguid`', 'SELECT 1');
PREPARE stmt FROM @q;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
-- Populate petition_id based on petitionguid
UPDATE `petition` SET `petition_id` = CASE WHEN `petitionguid` <= 2147483647 THEN `petitionguid` ELSE `petitionguid` - 2147483648 END WHERE `petition_id` = 0;
-- Add index on petition_id (if not exists)
SET @idx_exists = (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'petition' AND INDEX_NAME = 'idx_petition_id');
SET @q = IF(@idx_exists = 0, 'ALTER TABLE `petition` ADD INDEX `idx_petition_id` (`petition_id`)', 'SELECT 1');
PREPARE stmt FROM @q;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
-- Add petition_id column to petition_sign table (if not exists)
SET @col_exists = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'petition_sign' AND COLUMN_NAME = 'petition_id');
SET @q = IF(@col_exists = 0, 'ALTER TABLE `petition_sign` ADD COLUMN `petition_id` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `petitionguid`', 'SELECT 1');
PREPARE stmt FROM @q;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
-- Populate petition_id in petition_sign from petition table
UPDATE `petition_sign` AS `ps` JOIN `petition` AS `p` ON `p`.`petitionguid` = `ps`.`petitionguid` SET `ps`.`petition_id` = `p`.`petition_id` WHERE `ps`.`petition_id` = 0;
-- Add index on petition_id and playerguid in petition_sign (if not exists)
SET @idx_exists = (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'petition_sign' AND INDEX_NAME = 'idx_petition_id_player');
SET @q = IF(@idx_exists = 0, 'ALTER TABLE `petition_sign` ADD INDEX `idx_petition_id_player` (`petition_id`, `playerguid`)', 'SELECT 1');
PREPARE stmt FROM @q;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
-- Update enchantments in item_instance with petition_id prefix
UPDATE `item_instance` AS `ii` JOIN `petition` AS `p` ON `p`.`petitionguid` = `ii`.`guid` SET `ii`.`enchantments` = CONCAT(`p`.`petition_id`, SUBSTRING(`ii`.`enchantments`, LOCATE(' ', `ii`.`enchantments`))) WHERE `ii`.`enchantments` IS NOT NULL AND `ii`.`enchantments` <> '';
