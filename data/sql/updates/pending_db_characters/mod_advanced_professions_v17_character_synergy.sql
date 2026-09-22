-- mod-advanced-professions: изученные именные рецепты персонажа.
--
-- Сочетание вставок (ap_synergy, acore_world) стало вторым родом рецепта
-- (решение владельца 2026-09-05, DESIGN §5.6): оно изучается обучающим
-- предметом, как рецепт основы, и после изучения видно в левом списке окна
-- верстака на вкладке инкрустации.
--
-- Таблица - точная копия `ap_character_recipe` по устройству, и это намеренно:
-- два рода рецептов ведут себя одинаково, и код, который их читает, отличается
-- только именем таблицы.
--
-- Изучение НЕ ТРЕБУЕТСЯ, чтобы собрать именной предмет: завершение доводки
-- по-прежнему сверяет набор со всеми включёнными сочетаниями. Запись здесь
-- значит «игрок знает, что этот набор существует», а не «игроку разрешено».
--
-- Парная миграция: pending_db_world/mod_advanced_professions_v17_synergy_teach.sql
-- (колонка `teach_item` у сочетания). Применять обе вместе с worldserver
-- протокола 13.

CREATE TABLE IF NOT EXISTS `ap_character_synergy` (
  `guid`       INT UNSIGNED NOT NULL COMMENT 'characters.guid',
  `synergy_id` INT UNSIGNED NOT NULL COMMENT 'ap_synergy.id (acore_world)',
  `learned`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Когда именной рецепт изучен',
  PRIMARY KEY (`guid`, `synergy_id`),
  KEY `idx_ap_character_synergy_synergy` (`synergy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
