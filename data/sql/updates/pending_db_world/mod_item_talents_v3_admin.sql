-- mod-item-talents V3 «редактируемый из админ-панели».
--
-- Выносит из C++ в БД всё, что раньше было захардкожено или лежало в conf:
--   1. item_talent_category      — категории вместо букв A..H в коде;
--   2. item_talent_category_rule — правила «какой предмет в какую категорию»
--      (замена ItemTalentsMgr::GetPool);
--   3. item_talent_row_cfg       — размер ролла и «катать ли качество»
--      по (категория, ряд): меню может быть 10 вариантов, роллится 3;
--   4. item_talent_item_cfg /
--      item_talent_item_def      — ПЕРСОНАЛЬНЫЕ пулы для конкретных предметов
--      (эпики+): свой список вариантов на ряд. Обобщение item_talent_named:
--      если вариантов ровно 3 (= roll_count), они выпадают ВСЕГДА — это и
--      есть именной набор;
--   5. item_talent_kill_curve    — пороги убийств по ilvl и качеству
--      (замена ItemTalents.PointThresholds из conf, который одинаково давил
--      и на ilvl 10, и на ilvl 264);
--   6. item_talent_perk_library  — библиотека готовых перков: из неё панель
--      собирает и меню категорий, и персональные пулы. Ядро её НЕ читает.
--
-- Совместимость: старые таблицы (item_talent_def, item_talent_named) остаются
-- источником меню категорий; item_talent_def.pool = item_talent_category.code.
-- Если новых таблиц нет — модуль работает по-старому (жёсткий GetPool + conf).
--
-- Применять ПОСЛЕ mod_item_talents_def_seed.sql / _subclass.sql / _named.sql.
-- После применения: .itemtalent reload (рестарт не нужен).
--
-- Идемпотентно: CREATE TABLE IF NOT EXISTS + DELETE/INSERT сидов.

-- ---------------------------------------------------------------------------
-- 1. Категории
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `item_talent_category` (
  `code`     CHAR(1)      NOT NULL,           -- A..Z, ключ в item_talent_def.pool
  `name_ru`  VARCHAR(64)  NOT NULL,
  `comment`  VARCHAR(255) NOT NULL DEFAULT '',
  `enabled`  TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `sort`     SMALLINT UNSIGNED NOT NULL DEFAULT 0, -- порядок в панели
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELETE FROM `item_talent_category` WHERE `code` IN ('A','B','C','D','E','F','G','H');
INSERT INTO `item_talent_category` (`code`,`name_ru`,`comment`,`enabled`,`sort`) VALUES
('A','Ткань','Тканевая броня + «держим в руке» (тома, сферы, скипетры)',1,10),
('B','Кожа','Кожаная броня',1,20),
('C','Кольчуга','Кольчужная броня',1,30),
('D','Латы','Латная броня',1,40),
('E','Щит','Щиты',1,50),
('F','Ближний бой','Мечи, топоры, булавы, древковое, кинжалы, кастеты',1,60),
('G','Дальний бой','Луки, ружья, арбалеты',1,70),
('H','Кастерское','Посохи и жезлы',1,80);

-- ---------------------------------------------------------------------------
-- 2. Правила подбора категории (замена GetPool)
--    Матчинг: все поля должны совпасть; -1 / 0 = «любой».
--    Побеждает правило с наибольшим priority (при равном — меньший id).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `item_talent_category_rule` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`        CHAR(1)  NOT NULL,                  -- item_talent_category.code
  `item_class`  SMALLINT NOT NULL DEFAULT -1,       -- 2 оружие, 4 броня; -1 любой
  `subclass`    SMALLINT NOT NULL DEFAULT -1,
  `inv_type`    SMALLINT NOT NULL DEFAULT -1,
  `quality_min` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `quality_max` TINYINT UNSIGNED NOT NULL DEFAULT 7,
  `entry_lo`    INT UNSIGNED NOT NULL DEFAULT 0,    -- 0,0 = любой entry
  `entry_hi`    INT UNSIGNED NOT NULL DEFAULT 0,
  `priority`    SMALLINT NOT NULL DEFAULT 0,
  `comment`     VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELETE FROM `item_talent_category_rule` WHERE `comment` LIKE 'seed:%';
INSERT INTO `item_talent_category_rule`
    (`code`,`item_class`,`subclass`,`inv_type`,`priority`,`comment`) VALUES
-- Броня (class 4)
('A',4, 1,-1, 0,'seed: ткань'),
('A',4, 0,23,10,'seed: держим в руке (том/сфера/скипетр), только InvType 23'),
('B',4, 2,-1, 0,'seed: кожа'),
('C',4, 3,-1, 0,'seed: кольчуга'),
('D',4, 4,-1, 0,'seed: латы'),
('E',4, 6,-1, 0,'seed: щит'),
-- Оружие (class 2)
('F',2, 0,-1, 0,'seed: топор одноручный'),
('F',2, 1,-1, 0,'seed: топор двуручный'),
('F',2, 4,-1, 0,'seed: булава одноручная'),
('F',2, 5,-1, 0,'seed: булава двуручная'),
('F',2, 6,-1, 0,'seed: древковое'),
('F',2, 7,-1, 0,'seed: меч одноручный'),
('F',2, 8,-1, 0,'seed: меч двуручный'),
('F',2,13,-1, 0,'seed: кастеты'),
('F',2,15,-1, 0,'seed: кинжал'),
('G',2, 2,-1, 0,'seed: лук'),
('G',2, 3,-1, 0,'seed: ружьё'),
('G',2,18,-1, 0,'seed: арбалет'),
('H',2,10,-1, 0,'seed: посох'),
('H',2,19,-1, 0,'seed: жезл');

-- ---------------------------------------------------------------------------
-- 3. Настройка ряда категории: сколько вариантов роллить и катать ли качество
--    Нет строки -> roll_count = 3, quality_enabled = 1 (ряд 5: 0).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `item_talent_row_cfg` (
  `code`            CHAR(1) NOT NULL,
  `row`             TINYINT UNSIGNED NOT NULL,       -- 1..5
  `roll_count`      TINYINT UNSIGNED NOT NULL DEFAULT 3, -- 1..3 (UI: 3 слота)
  `quality_enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`code`,`row`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------------
-- 4. Персональные пулы предметов (эпики+ и именные наборы)
--    item_talent_item_def — меню ряда КОНКРЕТНОГО предмета; перекрывает меню
--    категории. Вариантов может быть сколько угодно (до 30) — роллится
--    roll_count (по умолчанию 3). Ровно 3 варианта = «всегда эти три».
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `item_talent_item_cfg` (
  `item_entry`      INT UNSIGNED NOT NULL,
  `row`             TINYINT UNSIGNED NOT NULL,
  `roll_count`      TINYINT UNSIGNED NOT NULL DEFAULT 3,
  `quality_enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`item_entry`,`row`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `item_talent_item_def` (
  `item_entry`  INT UNSIGNED NOT NULL,
  `row`         TINYINT UNSIGNED NOT NULL,           -- 1..5
  `choice`      TINYINT UNSIGNED NOT NULL,           -- 1..30, id варианта в меню
  `name_ru`     VARCHAR(64)  NOT NULL,
  `desc_ru`     VARCHAR(255) NOT NULL,               -- {N} подставляет модуль
  `effect`      VARCHAR(32)  NOT NULL,               -- STAT_STA, ..., PROC
  `base`        FLOAT NOT NULL DEFAULT 0,            -- PROC: id триггер-спелла
  `per_ilvl`    FLOAT NOT NULL DEFAULT 0,
  `proc_chance` TINYINT UNSIGNED NOT NULL DEFAULT 0, -- справочно (легаси именных)
  `icd_secs`    INT UNSIGNED NOT NULL DEFAULT 0,     -- справочно
  PRIMARY KEY (`item_entry`,`row`,`choice`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Перенос именного набора «Посох Джордана» (873) из item_talent_named:
-- ряд 5, три варианта, качество не катается.
DELETE FROM `item_talent_item_def` WHERE `item_entry` = 873 AND `row` = 5;
INSERT INTO `item_talent_item_def`
    (`item_entry`,`row`,`choice`,`name_ru`,`desc_ru`,`effect`,`base`,`per_ilvl`,
     `proc_chance`,`icd_secs`)
SELECT `item_entry`, 5, `choice`, `name_ru`, `desc_ru`, `effect`, `base`, `per_ilvl`,
       `proc_chance`, `icd_secs`
FROM `item_talent_named` WHERE `item_entry` = 873;

DELETE FROM `item_talent_item_cfg` WHERE `item_entry` = 873 AND `row` = 5;
INSERT INTO `item_talent_item_cfg` (`item_entry`,`row`,`roll_count`,`quality_enabled`)
VALUES (873, 5, 3, 0);

-- ---------------------------------------------------------------------------
-- 5. Пороги убийств по ilvl и качеству (замена ItemTalents.PointThresholds)
--    Матч: quality и ilvl предмета попадают в диапазон; побеждает наибольший
--    priority. lvlN — убийства ЗА уровень N (НЕ кумулятивно, счётчик
--    обнуляется при взятии уровня). Нет подходящей строки -> conf.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `item_talent_kill_curve` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(64) NOT NULL DEFAULT '',
  `quality_min` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `quality_max` TINYINT UNSIGNED NOT NULL DEFAULT 7,
  `ilvl_min`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `ilvl_max`    SMALLINT UNSIGNED NOT NULL DEFAULT 999,
  `lvl1`        INT UNSIGNED NOT NULL DEFAULT 50,
  `lvl2`        INT UNSIGNED NOT NULL DEFAULT 150,
  `lvl3`        INT UNSIGNED NOT NULL DEFAULT 400,
  `lvl4`        INT UNSIGNED NOT NULL DEFAULT 1000,
  `lvl5`        INT UNSIGNED NOT NULL DEFAULT 2500,
  `priority`    SMALLINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Стартовая кривая: низкий ilvl прокачивается быстро (предмет 10 ilvl больше
-- не требует 50 убийств на первый уровень), топовый — в темпе старого конфига.
DELETE FROM `item_talent_kill_curve` WHERE `name` LIKE 'seed:%';
INSERT INTO `item_talent_kill_curve`
    (`name`,`quality_min`,`quality_max`,`ilvl_min`,`ilvl_max`,
     `lvl1`,`lvl2`,`lvl3`,`lvl4`,`lvl5`,`priority`) VALUES
('seed: ilvl 0-24',   0,7,   0, 24,   5,  12,  30,   70,  150, 0),
('seed: ilvl 25-59',  0,7,  25, 59,  10,  25,  60,  150,  350, 0),
('seed: ilvl 60-99',  0,7,  60, 99,  20,  50, 130,  320,  750, 0),
('seed: ilvl 100-159',0,7, 100,159,  35,  90, 240,  600, 1400, 0),
('seed: ilvl 160-199',0,7, 160,199,  50, 150, 400, 1000, 2500, 0),
('seed: ilvl 200+',   0,7, 200,999,  75, 220, 600, 1500, 3500, 0);

-- ---------------------------------------------------------------------------
-- 6. Библиотека перков (только для панели; ядро её не читает)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `item_talent_perk_library` (
  `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name_ru`  VARCHAR(64)  NOT NULL,
  `desc_ru`  VARCHAR(255) NOT NULL,
  `effect`   VARCHAR(32)  NOT NULL,
  `base`     FLOAT NOT NULL DEFAULT 0,
  `per_ilvl` FLOAT NOT NULL DEFAULT 0,
  `tags`     VARCHAR(128) NOT NULL DEFAULT '',   -- «ряд1, статы» и т.п.
  PRIMARY KEY (`id`),
  KEY `idx_effect` (`effect`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Первичное наполнение — уникальные перки из уже существующих меню категорий.
DELETE FROM `item_talent_perk_library` WHERE `tags` LIKE 'seed:%';
INSERT INTO `item_talent_perk_library` (`name_ru`,`desc_ru`,`effect`,`base`,`per_ilvl`,`tags`)
SELECT `name_ru`, MIN(`desc_ru`), `effect`, `base`, `per_ilvl`,
       CONCAT('seed: ряд ', MIN(`row`))
FROM `item_talent_def`
GROUP BY `name_ru`, `effect`, `base`, `per_ilvl`;
