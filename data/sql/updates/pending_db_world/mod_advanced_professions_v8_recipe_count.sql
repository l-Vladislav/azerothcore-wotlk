-- mod-advanced-professions: расход материала задаёт ОСНОВА, а не только тип.
--
-- До этой миграции «сколько слитков уходит в клинок» жило единственным числом у
-- части типа (`ap_type_part.count`), то есть было общим для всех мечей сразу.
-- Из-за этого бронзовый клинок и мифриловый стоили одинаково, хотя это вещи
-- разного порядка.
--
-- Теперь у строки рецепта есть свой `count`. Ноль - «как у типа»: основа не
-- обязана перечислять расход по всем частям, достаточно назвать те, где он
-- отличается. Так «бронзовому клинку - 2 слитка на лезвие и 2 на рукоять»
-- пишется двумя строками, а остальные части берут числа типа.
--
-- Следствие для рецепта: строка теперь может существовать и с
-- `material_entry` = 0. Раньше ноль означал «условия нет» и строка удалялась;
-- теперь такая строка законна, если несёт расход. Условием рецепта считается
-- только ненулевой material_entry - подсчёт «чей рецепт подробнее» не меняется.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §5.4

SET @add := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_base_recipe'
               AND COLUMN_NAME = 'count');
SET @sql := IF(@add = 0,
    'ALTER TABLE `ap_base_recipe` '
    'ADD COLUMN `count` TINYINT UNSIGNED NOT NULL DEFAULT 0 '
    'COMMENT ''расход материала в этой части; 0 - взять число у типа'' '
    'AFTER `material_entry`',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
