-- mod-advanced-professions: типы предметов и рецепты основ.
--
-- Что меняется по сравнению с v5. Раньше игрок выбирал ГОТОВУЮ основу
-- («Бронзовый клинок»), а части висели на ней. Теперь он выбирает ТИП того, что
-- хочет сделать («Меч одноручный»), заполняет его части материалами, а какая
-- именно основа получится - решает РЕЦЕПТ:
--
--     тип + материалы в частях  ->  рецепт  ->  основа
--
-- Отсюда три таблицы:
--   ap_item_type   что вообще можно ковать; ему же принадлежит схема частей;
--   ap_type_part   части ТИПА (переехали из ap_base_part);
--   ap_base_recipe условия основы: «в части N лежит материал X».
--
-- Побеждает самый ПОДРОБНЫЙ рецепт: если основа «Бронзовый клинок» требует
-- только бронзовое лезвие, а «Клинок кузнеца» - бронзовое лезвие И мифриловую
-- гарду, то при мифриловой гарде выйдет второй. Так частные случаи не надо
-- перечислять полностью, а общий рецепт остаётся запасным.
--
-- Схемы частей взяты из макета владельца (кузнец с модульным крафтом):
-- координаты x/y - из того же холста 460x160, в котором нарисован силуэт.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §5.4

-- --------------------------------------------------------------------------
-- Типы предметов
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_item_type` (
  `id`             INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  `code`           VARCHAR(24)       NOT NULL DEFAULT '' COMMENT 'ключ для схемы в аддоне',
  `name_ru`        VARCHAR(64)       NOT NULL DEFAULT '',
  `sub_ru`         VARCHAR(32)       NOT NULL DEFAULT '' COMMENT 'подпись под именем: одноручное и т.п.',
  `item_class`     TINYINT UNSIGNED  NOT NULL DEFAULT 2,
  `item_subclass`  TINYINT UNSIGNED  NOT NULL DEFAULT 7,
  `inventory_type` TINYINT UNSIGNED  NOT NULL DEFAULT 13,
  `delay`          SMALLINT UNSIGNED NOT NULL DEFAULT 2000,
  `displayid`      INT UNSIGNED      NOT NULL DEFAULT 0 COMMENT 'вид по умолчанию, если основа своего не задала',
  `sort`           SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  `enabled`        TINYINT UNSIGNED  NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `ap_item_type`
  (`id`, `code`, `name_ru`, `sub_ru`, `item_class`, `item_subclass`,
   `inventory_type`, `delay`, `displayid`, `sort`) VALUES
(1, 'sword',   'Меч',              'одноручное', 2,  7, 13, 2100,  3855, 10),
(2, 'sword2h', 'Двуручный меч',    'двуручное',  2,  8, 17, 3000, 20071, 20),
(3, 'dagger',  'Кинжал',           'одноручное', 2, 15, 13, 1700, 20221, 30),
(4, 'axe',     'Топор',            'одноручное', 2,  0, 13, 1900, 14035, 40),
(5, 'axe2h',   'Двуручный топор',  'двуручное',  2,  1, 17, 3400, 14035, 50),
(6, 'mace',    'Булава',           'одноручное', 2,  4, 13, 2600,  5198, 60),
(7, 'mace2h',  'Двуручный молот',  'двуручное',  2,  5, 17, 3200,  5198, 70),
(8, 'polearm', 'Древковое',        'двуручное',  2,  6, 17, 3000, 22079, 80),
(9, 'fist',    'Кастеты',          'одноручное', 2, 13, 13, 2000,  3855, 90),
(10,'shield',  'Щит',              'левая рука', 4,  6, 14,    0, 18661, 100);

-- --------------------------------------------------------------------------
-- Части ТИПА (переезд из ap_base_part)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_type_part` (
  `type_id`    INT UNSIGNED     NOT NULL,
  `idx`        TINYINT UNSIGNED NOT NULL COMMENT 'порядок на схеме, с 1',
  `label_ru`   VARCHAR(48)      NOT NULL DEFAULT '',
  `kind`       ENUM('metal','wood','leather','cloth','stone','gem','other')
               NOT NULL DEFAULT 'metal',
  `count`      TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `dmg_pct`    SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  `dura_pct`   SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  `ilvl_pct`   SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  `allow_proc` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `texture`    VARCHAR(128)     NOT NULL DEFAULT '',
  `x`          SMALLINT         NOT NULL DEFAULT 0,
  `y`          SMALLINT         NOT NULL DEFAULT 0,
  PRIMARY KEY (`type_id`, `idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Схемы из макета. Ведущая часть (клинок, лезвие, боёк) берёт двойной урон и
-- имеет право на прок; древко и обмотка дают прочность, но почти не дают урона.
INSERT IGNORE INTO `ap_type_part`
  (`type_id`, `idx`, `label_ru`, `kind`, `count`, `dmg_pct`, `dura_pct`,
   `ilvl_pct`, `allow_proc`, `x`, `y`) VALUES
-- меч
(1, 1, 'Навершие',  'metal',   1,  30,  40,  50, 0,  -8,   8),
(1, 2, 'Рукоять',   'wood',    1,  10,  60,  40, 0,  60,  96),
(1, 3, 'Гарда',     'metal',   1,  20, 120,  60, 0, 104,   8),
(1, 4, 'Клинок',    'metal',   3, 200,  80, 150, 1, 230,  96),
-- двуручный меч
(2, 1, 'Навершие',  'metal',   1,  30,  40,  50, 0, -16,   8),
(2, 2, 'Рукоять',   'wood',    1,  10,  60,  40, 0,  62,  96),
(2, 3, 'Обмотка',   'leather', 1,  15,  80,  40, 0,  66,   6),
(2, 4, 'Гарда',     'metal',   2,  20, 120,  60, 0, 119, 100),
(2, 5, 'Клинок',    'metal',   4, 240,  80, 170, 1, 246,   4),
-- кинжал
(3, 1, 'Навершие',  'metal',   1,  30,  40,  50, 0,  98,   8),
(3, 2, 'Рукоять',   'leather', 1,  10,  60,  40, 0, 136,  96),
(3, 3, 'Гарда',     'metal',   1,  20, 120,  60, 0, 170,   8),
(3, 4, 'Клинок',    'metal',   2, 150,  70, 120, 1, 274,  96),
-- топор
(4, 1, 'Топорище',  'wood',    1,  10,  70,  40, 0,  90,  96),
(4, 2, 'Обмотка',   'leather', 1,  15,  80,  40, 0, 215,  96),
(4, 3, 'Лезвие',    'metal',   3, 210,  80, 150, 1, 342,   8),
-- двуручный топор
(5, 1, 'Древко',    'wood',    2,  10,  70,  40, 0,  96,  96),
(5, 2, 'Обмотка',   'leather', 1,  15,  80,  40, 0, 155,  96),
(5, 3, 'Лезвие',    'metal',   4, 250,  80, 170, 1, 348,   8),
(5, 4, 'Противовес','metal',   1,  30,  90,  60, 0, -10,   8),
-- булава
(6, 1, 'Рукоять',   'wood',    1,  10,  70,  40, 0, 100,  96),
(6, 2, 'Обмотка',   'leather', 1,  15,  80,  40, 0,  55,   6),
(6, 3, 'Навершие',  'metal',   3, 210, 100, 150, 1, 344,  96),
-- двуручный молот
(7, 1, 'Древко',    'wood',    2,  10,  70,  40, 0, 110,  96),
(7, 2, 'Обмотка',   'leather', 1,  15,  80,  40, 0,  46,   6),
(7, 3, 'Боёк',      'metal',   4, 250, 110, 170, 1, 300,  96),
(7, 4, 'Клин',      'metal',   1,  40,  90,  60, 0, 404,   6),
-- древковое
(8, 1, 'Древко',    'wood',    2,  10,  70,  40, 0,  70,  96),
(8, 2, 'Обмотка',   'leather', 1,  15,  80,  40, 0, 182,   6),
(8, 3, 'Втулка',    'metal',   1,  20, 110,  60, 0, 309,  96),
(8, 4, 'Наконечник','metal',   3, 230,  80, 160, 1, 372,   8),
-- кастеты
(9, 1, 'Ремень',    'leather', 1,  15,  80,  40, 0, 165,   8),
(9, 2, 'Скоба',     'metal',   1,  30, 110,  60, 0, 240,  96),
(9, 3, 'Ударная пластина', 'metal', 2, 180, 90, 140, 1, 326, 8),
(9, 4, 'Шипы',      'metal',   1,  60,  70,  70, 0, 400,  96),
-- щит
(10, 1, 'Поле',     'wood',    2,   0, 140,  80, 0, 172,  96),
(10, 2, 'Кайма',    'metal',   2,   0, 160, 100, 0, 217, -12),
(10, 3, 'Умбон',    'metal',   2,   0, 180, 120, 1, 217,  46),
(10, 4, 'Ремни',    'leather', 1,   0, 100,  40, 0,  73,  96);

-- --------------------------------------------------------------------------
-- Основа теперь принадлежит типу и является РЕЗУЛЬТАТОМ рецепта.
-- --------------------------------------------------------------------------
SET @add := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_base'
               AND COLUMN_NAME = 'type_id');
SET @sql := IF(@add = 0,
    'ALTER TABLE `ap_base` ADD COLUMN `type_id` INT UNSIGNED NOT NULL '
    'DEFAULT 0 COMMENT ''ap_item_type.id'' AFTER `id`',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Обе основы MVP - мечи.
UPDATE `ap_base` SET `type_id` = 1 WHERE `id` IN (1, 2);

CREATE TABLE IF NOT EXISTS `ap_base_recipe` (
  `base_id`        INT UNSIGNED     NOT NULL,
  `part_idx`       TINYINT UNSIGNED NOT NULL COMMENT 'какая часть типа',
  `material_entry` INT UNSIGNED     NOT NULL COMMENT 'какой материал в ней должен лежать',
  PRIMARY KEY (`base_id`, `part_idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Металл клинка и решает, что за меч получился.
INSERT IGNORE INTO `ap_base_recipe` (`base_id`, `part_idx`, `material_entry`) VALUES
(1, 4, 2841),   -- бронзовое лезвие -> Бронзовый клинок
(2, 4, 3859);   -- стальное лезвие  -> Стальной клинок

-- Демонстрация «подробный рецепт побеждает»: тот же меч, но с мифриловым
-- лезвием и стальной гардой - уже другая основа.
INSERT IGNORE INTO `ap_base`
  (`id`, `type_id`, `name_ru`, `item_class`, `item_subclass`, `inventory_type`,
   `material_entry`, `material_count`, `req_skill`, `item_level`, `req_level`,
   `dmg_min`, `dmg_max`, `delay`, `armor`, `block`, `durability`, `displayid`)
VALUES
(3, 1, 'Мифриловый клинок', 2, 7, 13, 3860, 4, 200, 8, 40, 6, 12, 2000, 0, 0, 70, 20221);

INSERT IGNORE INTO `ap_base_recipe` (`base_id`, `part_idx`, `material_entry`) VALUES
(3, 4, 3860),
(3, 3, 3859);

-- Части, привязанные к основам, больше не нужны: схема принадлежит типу.
DROP TABLE IF EXISTS `ap_base_part`;
