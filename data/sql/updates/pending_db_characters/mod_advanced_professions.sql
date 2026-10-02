-- mod-advanced-professions: навык, изученные рецепты, эскизы и объединения
-- персонажа.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §6.

CREATE TABLE IF NOT EXISTS `ap_character_skill` (
  `guid` int unsigned NOT NULL COMMENT 'characters.guid',
  `skill` smallint unsigned NOT NULL DEFAULT '1',
  `crafted` int unsigned NOT NULL DEFAULT '0' COMMENT 'сколько всего собрано предметов',
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_character_recipe` (
  `guid` int unsigned NOT NULL COMMENT 'characters.guid',
  `recipe_id` int unsigned NOT NULL COMMENT 'ap_recipe.id (acore_world)',
  `learned` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Когда рецепт изучен или угадан',
  PRIMARY KEY (`guid`,`recipe_id`),
  KEY `idx_ap_character_recipe_recipe` (`recipe_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_character_synergy` (
  `guid` int unsigned NOT NULL COMMENT 'characters.guid',
  `synergy_id` int unsigned NOT NULL COMMENT 'ap_synergy.id (acore_world)',
  `learned` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Когда именной рецепт изучен',
  PRIMARY KEY (`guid`,`synergy_id`),
  KEY `idx_ap_character_synergy_synergy` (`synergy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_character_merge` (
  `guid` int unsigned NOT NULL COMMENT 'characters.guid',
  `merge_id` int unsigned NOT NULL COMMENT 'ap_merge.id (acore_world)',
  `learned` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Когда рецепт изучен',
  PRIMARY KEY (`guid`,`merge_id`),
  KEY `idx_ap_character_merge_merge` (`merge_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
