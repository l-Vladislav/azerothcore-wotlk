-- mod-advanced-professions: справочники крафта.
--
-- Всё, что тут заведено, редактируется из админ-панели (/aprof.html), а не
-- правкой этого файла: сид ставится через INSERT IGNORE ровно один раз, чтобы
-- повторный прогон миграции не затирал настройки владельца.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md

-- --------------------------------------------------------------------------
-- Настройки модуля (одна строка = одно число, чтобы панель правила их без
-- рестарта и без правки .conf).
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_config` (
  `name`    VARCHAR(64)  NOT NULL,
  `value`   VARCHAR(64)  NOT NULL DEFAULT '0',
  `comment` VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `ap_config` (`name`, `value`, `comment`) VALUES
('salvage_pct',  '20',     'Сколько процентов вложенного возвращает разбор'),
('skill_max',    '500',    'Потолок навыка «Мастерство верстака»'),
('pool_lo',      '130000', 'Начало блока id для генерируемых предметов'),
('pool_hi',      '179999', 'Конец блока id для генерируемых предметов'),
('name_prefix',  'Клинок', 'Слово, с которого строится имя (движок склонений)');

-- --------------------------------------------------------------------------
-- Качество основы: сколько слотов открывает и на сколько усиливает вставки.
-- stat_pct — проценты: 100 = без изменений.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_quality` (
  `quality`  TINYINT UNSIGNED NOT NULL,
  `name_ru`  VARCHAR(32)      NOT NULL DEFAULT '',
  `slots`    TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `stat_pct` SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  PRIMARY KEY (`quality`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `ap_quality` (`quality`, `name_ru`, `slots`, `stat_pct`) VALUES
(1, 'Обычная',      1, 100),
(2, 'Необычная',    2, 110),
(3, 'Редкая',       3, 125),
(4, 'Эпическая',    4, 145),
(5, 'Легендарная',  5, 170);

-- --------------------------------------------------------------------------
-- Корзины навыка. Корзина, а не точное значение навыка, — чтобы у одной и той
-- же комбинации материалов было 5 вариантов предмета, а не 500.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_skill_bucket` (
  `bucket`    TINYINT UNSIGNED  NOT NULL,
  `name_ru`   VARCHAR(32)       NOT NULL DEFAULT '',
  `skill_min` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `skill_max` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `stat_pct`  SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  PRIMARY KEY (`bucket`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `ap_skill_bucket`
  (`bucket`, `name_ru`, `skill_min`, `skill_max`, `stat_pct`) VALUES
(1, 'Подмастерье', 1,   99,  90),
(2, 'Ремесленник', 100, 199, 100),
(3, 'Умелец',      200, 299, 110),
(4, 'Мастер',      300, 399, 120),
(5, 'Виртуоз',     400, 500, 135);

-- --------------------------------------------------------------------------
-- Шанс качества основы при крафте: вес по (корзина навыка, качество).
-- Веса, а не проценты: строку можно добавить или убрать, не пересчитывая
-- остальные до сотни.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_quality_chance` (
  `bucket`  TINYINT UNSIGNED  NOT NULL,
  `quality` TINYINT UNSIGNED  NOT NULL,
  `weight`  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`bucket`, `quality`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `ap_quality_chance` (`bucket`, `quality`, `weight`) VALUES
(1, 1, 70), (1, 2, 25), (1, 3, 5),  (1, 4, 0),  (1, 5, 0),
(2, 1, 45), (2, 2, 35), (2, 3, 18), (2, 4, 2),  (2, 5, 0),
(3, 1, 25), (3, 2, 35), (3, 3, 30), (3, 4, 9),  (3, 5, 1),
(4, 1, 10), (4, 2, 25), (4, 3, 38), (4, 4, 22), (4, 5, 5),
(5, 1, 5),  (5, 2, 15), (5, 3, 35), (5, 4, 33), (5, 5, 12);

-- --------------------------------------------------------------------------
-- Материалы. Одна таблица на два назначения:
--   role = 'base'   — из чего куётся сама основа (слитки);
--   role = 'insert' — что вставляется в слот и даёт статы (камни и прочее).
-- stat_type — те же номера, что и в item_template.stat_type* (ITEM_MOD_*).
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_material` (
  `entry`      INT UNSIGNED         NOT NULL COMMENT 'item_template.entry',
  `role`       ENUM('base','insert') NOT NULL DEFAULT 'insert',
  `tier`       TINYINT UNSIGNED     NOT NULL DEFAULT 1,
  `stat_type`  TINYINT UNSIGNED     NOT NULL DEFAULT 0,
  `stat_value` SMALLINT UNSIGNED    NOT NULL DEFAULT 0,
  `name_ru`    VARCHAR(64)          NOT NULL DEFAULT '',
  `enabled`    TINYINT UNSIGNED     NOT NULL DEFAULT 1,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- MVP: два металла на основу и четыре камня на вставку. Цвет камня задаёт
-- стат: зелёный — ловкость, жёлтый — сила, фиолетовый — интеллект,
-- голубой — выносливость.
INSERT IGNORE INTO `ap_material`
  (`entry`, `role`, `tier`, `stat_type`, `stat_value`, `name_ru`) VALUES
(2841, 'base',   1, 0, 0, 'Бронзовый слиток'),
(3859, 'base',   2, 0, 0, 'Стальной слиток'),
(774,  'insert', 1, 3, 4, 'Малахит'),
(818,  'insert', 1, 4, 4, 'Тигровый глаз'),
(1210, 'insert', 2, 5, 4, 'Камень теней'),
(1705, 'insert', 2, 7, 6, 'Малый лунный камень');

-- --------------------------------------------------------------------------
-- Основы: что вообще можно выковать. Качество тут не задаётся — оно катается
-- при крафте по ap_quality_chance.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_base` (
  `id`             INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  `name_ru`        VARCHAR(64)       NOT NULL DEFAULT '',
  `item_class`     TINYINT UNSIGNED  NOT NULL DEFAULT 2,
  `item_subclass`  TINYINT UNSIGNED  NOT NULL DEFAULT 7,
  `inventory_type` TINYINT UNSIGNED  NOT NULL DEFAULT 21,
  `material_entry` INT UNSIGNED      NOT NULL DEFAULT 0,
  `material_count` TINYINT UNSIGNED  NOT NULL DEFAULT 1,
  `req_skill`      SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  `item_level`     SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  `req_level`      TINYINT UNSIGNED  NOT NULL DEFAULT 1,
  `dmg_min`        SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `dmg_max`        SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `delay`          SMALLINT UNSIGNED NOT NULL DEFAULT 2000,
  `displayid`      INT UNSIGNED      NOT NULL DEFAULT 0,
  `enabled`        TINYINT UNSIGNED  NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- MVP: только мечи. Числа урона и displayid взяты у существующего оружия
-- того же уровня (2850 Bronze Shortsword, 2520 Broadsword).
INSERT IGNORE INTO `ap_base`
  (`id`, `name_ru`, `item_class`, `item_subclass`, `inventory_type`,
   `material_entry`, `material_count`, `req_skill`, `item_level`, `req_level`,
   `dmg_min`, `dmg_max`, `delay`, `displayid`) VALUES
(1, 'Бронзовый клинок', 2, 7, 21, 2841, 4, 1,   24, 19, 16, 31, 2100, 3855),
(2, 'Стальной клинок',  2, 7, 21, 3859, 6, 120, 36, 31, 28, 53, 2300, 22085);

-- --------------------------------------------------------------------------
-- Синергии («рунные слова»): набор материалов в заданном порядке даёт бонус
-- сверх суммы и своё имя предмету.
-- `pattern` — entry материалов через запятую, порядок значим.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_synergy` (
  `id`         INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  `name_ru`    VARCHAR(64)       NOT NULL DEFAULT '',
  `pattern`    VARCHAR(128)      NOT NULL DEFAULT '',
  `stat_type`  TINYINT UNSIGNED  NOT NULL DEFAULT 0,
  `stat_value` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `enabled`    TINYINT UNSIGNED  NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `ap_synergy`
  (`id`, `name_ru`, `pattern`, `stat_type`, `stat_value`) VALUES
(1, 'Клинок ловчего',  '774,774',  3, 6),
(2, 'Клинок исполина', '818,1705', 7, 8);

-- --------------------------------------------------------------------------
-- Выданные из пула id. Заполняет модуль, не человек: строка появляется, когда
-- игрок первым в мире собрал такую комбинацию.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_generated_item` (
  `entry`        INT UNSIGNED     NOT NULL COMMENT 'id из блока pool_lo..pool_hi',
  `combo_hash`   CHAR(40)         NOT NULL,
  `base_id`      INT UNSIGNED     NOT NULL DEFAULT 0,
  `quality`      TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `skill_bucket` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `mats`         VARCHAR(128)     NOT NULL DEFAULT '' COMMENT 'entry через запятую, по слотам',
  `synergy_id`   INT UNSIGNED     NOT NULL DEFAULT 0,
  `created_at`   TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`entry`),
  UNIQUE KEY `combo` (`combo_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
