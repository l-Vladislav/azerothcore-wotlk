-- mod-advanced-professions: основа собирается из ЧАСТЕЙ.
--
-- До этой миграции основа ковалась из одного реагента («4 бронзовых слитка»), а
-- слоты под самоцветы давало качество. Теперь ковка - это сборка: у меча есть
-- клинок, гарда, рукоять и навершие, у щита - поле, кайма, умбон и ремни.
-- Каждая часть ждёт материал своего РОДА (металл, дерево, кожа), а не
-- конкретный предмет: любой металл годится в клинок, разным будет результат.
--
-- Части задают четыре вещи (решение владельца): сырой урон, прочность, уровень
-- предмета и возможный прок. Качество и слоты под самоцветы остаются как были -
-- это вторая ступень, «доводка».
--
-- Совместимость: если у основы нет ни одной части, она куётся по-старому из
-- `material_entry` x `material_count`. Так уже выданные предметы и старые
-- рецепты продолжают работать.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §5.4

-- --------------------------------------------------------------------------
-- Материал получает род и вклад в части.
-- --------------------------------------------------------------------------
SET @add := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_material'
               AND COLUMN_NAME = 'kind');
SET @sql := IF(@add = 0,
    'ALTER TABLE `ap_material` '
    'ADD COLUMN `kind` ENUM(''metal'',''wood'',''leather'',''cloth'',''stone'','
    '''gem'',''other'') NOT NULL DEFAULT ''other'' AFTER `role`, '
    'ADD COLUMN `dmg` SMALLINT UNSIGNED NOT NULL DEFAULT 0 '
    'COMMENT ''средний прирост урона, если материал ушёл в часть'', '
    'ADD COLUMN `durability` SMALLINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `ilvl` SMALLINT UNSIGNED NOT NULL DEFAULT 0, '
    'ADD COLUMN `proc_spell` INT UNSIGNED NOT NULL DEFAULT 0 '
    'COMMENT ''спелл прока; сработает только в части с allow_proc'', '
    'ADD COLUMN `proc_ppm` DECIMAL(4,2) NOT NULL DEFAULT 0',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- --------------------------------------------------------------------------
-- Части основы. Строка = одна ячейка на схеме предмета.
--
-- Проценты - вклад материала именно этой части: клинок берёт от металла двойной
-- урон и почти не даёт прочности, рукоять наоборот. Так «быстрый лёгкий кинжал»
-- и «тяжёлый тесак» получаются из одних и тех же материалов.
--
-- texture/x/y нужны будущему окну аддона: в 3.3.5a нет векторной графики,
-- поэтому силуэт предмета собирается слоями текстур, а не полигонами.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_base_part` (
  `base_id`    INT UNSIGNED     NOT NULL,
  `idx`        TINYINT UNSIGNED NOT NULL COMMENT 'порядок на схеме, с 1',
  `label_ru`   VARCHAR(48)      NOT NULL DEFAULT '',
  `kind`       ENUM('metal','wood','leather','cloth','stone','gem','other')
               NOT NULL DEFAULT 'metal',
  `count`      TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'сколько единиц материала съедает',
  `dmg_pct`    SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  `dura_pct`   SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  `ilvl_pct`   SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  `allow_proc` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'может ли материал этой части дать прок',
  `texture`    VARCHAR(128)     NOT NULL DEFAULT '' COMMENT 'слой силуэта для аддона',
  `x`          SMALLINT         NOT NULL DEFAULT 0,
  `y`          SMALLINT         NOT NULL DEFAULT 0,
  PRIMARY KEY (`base_id`, `idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Комбинация предмета теперь включает и материалы частей: бронзовый клинок с
-- дубовой рукоятью и он же с мифриловой - разные предметы.
SET @add := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_generated_item'
               AND COLUMN_NAME = 'parts');
SET @sql := IF(@add = 0,
    'ALTER TABLE `ap_generated_item` ADD COLUMN `parts` VARCHAR(128) NOT NULL '
    'DEFAULT '''' COMMENT ''материалы частей через запятую'' AFTER `mats`',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- --------------------------------------------------------------------------
-- Роды у уже заведённых материалов.
-- --------------------------------------------------------------------------
UPDATE `ap_material` SET `kind` = 'gem'   WHERE `role` = 'insert';
UPDATE `ap_material` SET `kind` = 'metal' WHERE `entry` IN (2841, 3859);

UPDATE `ap_material` SET `dmg` = 6,  `durability` = 20, `ilvl` = 10 WHERE `entry` = 2841;
UPDATE `ap_material` SET `dmg` = 10, `durability` = 30, `ilvl` = 18 WHERE `entry` = 3859;

-- --------------------------------------------------------------------------
-- Материалы под остальные рода. Числа низкие намеренно: занизить безопаснее,
-- чем раздать эпик по ошибке. Мифрил несёт демонстрационный прок - тот же
-- спелл, что у «Молота северного ветра» (13439).
-- --------------------------------------------------------------------------
INSERT IGNORE INTO `ap_material`
  (`entry`, `role`, `kind`, `tier`, `stat_type`, `stat_value`, `name_ru`,
   `dmg`, `durability`, `ilvl`, `proc_spell`, `proc_ppm`) VALUES
(2840, 'base', 'metal',   1, 0, 0, 'Медный слиток',       4,  15,  6, 0,     0),
(3860, 'base', 'metal',   3, 0, 0, 'Мифриловый слиток',  16,  40, 28, 13439, 1.50),
(4470, 'base', 'wood',    1, 0, 0, 'Простая древесина',   1,  10,  3, 0,     0),
(2318, 'base', 'leather', 1, 0, 0, 'Тонкая кожа',         1,  12,  4, 0,     0),
(4234, 'base', 'leather', 2, 0, 0, 'Толстая кожа',        2,  18,  8, 0,     0),
(2589, 'base', 'cloth',   1, 0, 0, 'Льняной материал',    0,   8,  3, 0,     0);

-- --------------------------------------------------------------------------
-- Части для двух основ MVP. Схема как в макете кузнеца: навершие, рукоять,
-- гарда, клинок. Координаты - под будущее окно аддона (460x160, как в макете).
-- --------------------------------------------------------------------------
INSERT IGNORE INTO `ap_base_part`
  (`base_id`, `idx`, `label_ru`, `kind`, `count`, `dmg_pct`, `dura_pct`,
   `ilvl_pct`, `allow_proc`, `x`, `y`) VALUES
(1, 1, 'Навершие', 'metal',  1,  30,  40,  50, 0,  -8,   8),
(1, 2, 'Рукоять',  'wood',   1,  10,  60,  40, 0,  60,  96),
(1, 3, 'Гарда',    'metal',  1,  20, 120,  60, 0, 104,   8),
(1, 4, 'Клинок',   'metal',  3, 200,  80, 150, 1, 230,  96),
(2, 1, 'Навершие', 'metal',  1,  30,  40,  50, 0,  -8,   8),
(2, 2, 'Рукоять',  'wood',   1,  10,  60,  40, 0,  60,  96),
(2, 3, 'Гарда',    'metal',  2,  20, 120,  60, 0, 104,   8),
(2, 4, 'Клинок',   'metal',  4, 200,  80, 150, 1, 230,  96);

-- База теперь даёт лишь пол: остальное приносят части. Иначе бронзовый клинок с
-- мифриловым лезвием получил бы и полный урон основы, и полный вклад мифрила.
UPDATE `ap_base` SET `dmg_min` = 4, `dmg_max` = 8, `item_level` = 5,
                     `durability` = 20
WHERE `id` IN (1, 2);
