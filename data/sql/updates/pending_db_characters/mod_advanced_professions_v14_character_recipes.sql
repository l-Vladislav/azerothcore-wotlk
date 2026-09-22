-- mod-advanced-professions: изученные рецепты персонажа.
--
-- Рецепт — сущность, которой владеет персонаж, наравне с предметами и
-- навыком (`ap_character_skill`). Изучается тремя равноправными путями: найден
-- в мире, куплен у торговца верстака (оба через `teach_item`, acore_world) или
-- угадан точным набором в ячейках при ковке. Список изученного показывается в
-- левой части верстака; неизвестные рецепты не показываются вовсе, иначе
-- список сам стал бы подсказкой для угадывания.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §5.4.4, §6 (парная миграция
-- v14 в pending_db_world/mod_advanced_professions_v14_recipes.sql заводит
-- сам ap_recipe).

CREATE TABLE IF NOT EXISTS `ap_character_recipe` (
  `guid`      INT UNSIGNED NOT NULL COMMENT 'characters.guid',
  `recipe_id` INT UNSIGNED NOT NULL COMMENT 'ap_recipe.id (acore_world)',
  `learned`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Когда рецепт изучен или угадан',
  PRIMARY KEY (`guid`, `recipe_id`),
  KEY `idx_ap_character_recipe_recipe` (`recipe_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
