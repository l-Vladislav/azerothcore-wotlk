-- mod-advanced-professions: найденные рецепты объединения.
--
-- Третий род рецепта (DESIGN §5.8) ведёт себя как два первых: его находят,
-- покупают или получают книгой, и только изученные видны в списке слева на
-- вкладке «Объединение».
--
-- Как и у именных рецептов, изучение - это ЗНАНИЕ, а не право: сервер сверяет
-- набор со всеми включёнными рецептами объединения. Разница в том, что здесь
-- незнание почти непреодолимо - пять ячеек принимают любой предмет игры, и
-- угадать набор перебором нельзя. Поэтому книга тут не украшение, а
-- единственный разумный путь.
--
-- Парная миграция: pending_db_world/mod_advanced_professions_v19_merge.sql.

CREATE TABLE IF NOT EXISTS `ap_character_merge` (
  `guid`     INT UNSIGNED NOT NULL COMMENT 'characters.guid',
  `merge_id` INT UNSIGNED NOT NULL COMMENT 'ap_merge.id (acore_world)',
  `learned`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Когда рецепт изучен',
  PRIMARY KEY (`guid`, `merge_id`),
  KEY `idx_ap_character_merge_merge` (`merge_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
