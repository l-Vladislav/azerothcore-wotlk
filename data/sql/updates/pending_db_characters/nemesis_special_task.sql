-- ============================================================================
-- Nemesis special daily tasks (особые поручения) — per-player day state.
-- One row per player; day_start aligns to the server daily-quest reset.
-- task_type: 1 = speed kill, 2 = opposite continent, 3 = dungeon nemesis.
-- accepted_at = 0 while abandoned (the day stays locked to task_type).
-- Companion C++: mod-nemesis-system NemesisSpecialTask namespace.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `character_nemesis_special_task` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Player guid low',
  `day_start` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix ts of the daily window start',
  `task_type` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 speed / 2 continent / 3 dungeon',
  `accepted_at` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Unix ts; 0 = abandoned',
  `param` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'continent: target mapId; dungeon: kill counter',
  `target_spawn` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Named target spawnId',
  `completed` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
