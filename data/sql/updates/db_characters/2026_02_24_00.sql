-- DB update 2025_09_03_00 -> 2026_02_24_00
--
ALTER TABLE `quest_tracker`
  MODIFY COLUMN `id` int UNSIGNED NOT NULL DEFAULT 0 FIRST;
SET @idx_exists = (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'quest_tracker' AND INDEX_NAME = 'idx_latest_quest_for_character');
SET @q = IF(@idx_exists = 0, 'ALTER TABLE `quest_tracker` ADD UNIQUE INDEX `idx_latest_quest_for_character`(`id`, `character_guid`, `quest_accept_time` DESC)', 'SELECT 1');
PREPARE stmt FROM @q;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
