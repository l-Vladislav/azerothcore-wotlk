-- ============================================================================
-- Special tasks: named target (owner test round 2026-06-07).
-- target_spawn stores the spawnId of the CONCRETE nemesis the task names in
-- its accept text/menu (speed/continent flavor; completion stays generous).
-- Conditional ALTER — idempotent on re-run.
-- ============================================================================

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'character_nemesis_special_task'
      AND COLUMN_NAME = 'target_spawn');
SET @sql := IF(@col = 0,
    'ALTER TABLE `character_nemesis_special_task` ADD COLUMN `target_spawn` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Named target spawnId'' AFTER `param`',
    'SELECT 1');
PREPARE s FROM @sql;
EXECUTE s;
DEALLOCATE PREPARE s;
