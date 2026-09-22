-- mod-advanced-professions: ревизия логики 2026-08-28.
--
-- Разбор кода нашёл 15 расхождений между задуманным и реализованным; решения
-- владельца записаны в .claude/advanced-professions/DESIGN.md §2.1, план правок
-- - в §11. Эта миграция готовит схему под них.
--
-- ВАЖНО: миграция **только добавляет**. Легаси-колонки (`ap_base.material_entry`,
-- `ap_base.material_count`, `ap_type_part.required`, `ap_character_skill.exp`)
-- остаются на месте, потому что их читает уже собранный worldserver: снести их
-- сейчас значит уронить модуль на первом же SELECT. Их убирает отдельная
-- миграция v11 - после того, как C++ перестанет их запрашивать (§11, шаг 13).
--
-- Что добавляется:
--   1. ap_type_part.default_material - материал по умолчанию (решение 1)
--   2. ap_base.recipe_count + триггеры  - рецепт обязан иметь условие (решение 4)
--   3. снимок в ap_generated_item       - предмет не меняется задним числом (6)
--   4. ap_ilvl_level                    - уровень предмета -> уровень игрока (14)
--   5. настройки сборки мусора и шанса успеха (решения 5 и 13)

-- ---------------------------------------------------------------------------
-- 1. Материал по умолчанию у части (решение 1)
-- ---------------------------------------------------------------------------
-- Прежний флаг `required` был недостижим: пустая часть уезжала на сервер как
-- ноль, а оба парсера нули выбрасывали. Вместо «часть можно оставить пустой»
-- теперь «часть всегда чем-то заполнена»: ноль здесь значит «часть
-- обязательна, материал выбирает игрок», ненулевой entry - материал, который
-- подставляется сам, не тратится из сумки и не возвращается при разборе.
SET @add := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_type_part'
    AND COLUMN_NAME = 'default_material');
SET @sql := IF(@add = 0,
  'ALTER TABLE `ap_type_part` ADD COLUMN `default_material` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Материал по умолчанию; 0 = часть обязательна'' AFTER `count`',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- 2. Рецепт обязан иметь хотя бы одно условие (решение 4)
-- ---------------------------------------------------------------------------
-- Основа без единого ненулевого material_entry подходила под ЛЮБОЙ набор:
-- «чей рецепт подробнее» давало ей ноль условий, а ноль выигрывает, когда не
-- подошло ничего конкретнее. Пока у типа была такая основа, весь путь
-- неудачной ковки не срабатывал никогда.
--
-- Внешним ключом это не выразить, а CHECK не умеет смотреть в другую таблицу -
-- поэтому счётчик условий живёт рядом со строкой основы и поддерживается
-- триггерами.
SET @add := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_base'
    AND COLUMN_NAME = 'recipe_count');
SET @sql := IF(@add = 0,
  'ALTER TABLE `ap_base` ADD COLUMN `recipe_count` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Сколько у рецепта условий; поддерживается триггерами''',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE `ap_base` b SET b.`recipe_count` = (
  SELECT COUNT(*) FROM `ap_base_recipe` r
  WHERE r.`base_id` = b.`id` AND r.`material_entry` <> 0);

DROP TRIGGER IF EXISTS `ap_base_recipe_ai`;
DROP TRIGGER IF EXISTS `ap_base_recipe_au`;
DROP TRIGGER IF EXISTS `ap_base_recipe_ad`;

DELIMITER $$

CREATE TRIGGER `ap_base_recipe_ai` AFTER INSERT ON `ap_base_recipe`
FOR EACH ROW BEGIN
  UPDATE `ap_base` SET `recipe_count` = (
    SELECT COUNT(*) FROM `ap_base_recipe`
    WHERE `base_id` = NEW.`base_id` AND `material_entry` <> 0)
  WHERE `id` = NEW.`base_id`;
END$$

CREATE TRIGGER `ap_base_recipe_au` AFTER UPDATE ON `ap_base_recipe`
FOR EACH ROW BEGIN
  UPDATE `ap_base` SET `recipe_count` = (
    SELECT COUNT(*) FROM `ap_base_recipe`
    WHERE `base_id` = NEW.`base_id` AND `material_entry` <> 0)
  WHERE `id` = NEW.`base_id`;
  -- Строку рецепта могли перевесить на другую основу: пересчитываем и старую.
  IF OLD.`base_id` <> NEW.`base_id` THEN
    UPDATE `ap_base` SET `recipe_count` = (
      SELECT COUNT(*) FROM `ap_base_recipe`
      WHERE `base_id` = OLD.`base_id` AND `material_entry` <> 0)
    WHERE `id` = OLD.`base_id`;
  END IF;
END$$

CREATE TRIGGER `ap_base_recipe_ad` AFTER DELETE ON `ap_base_recipe`
FOR EACH ROW BEGIN
  UPDATE `ap_base` SET `recipe_count` = (
    SELECT COUNT(*) FROM `ap_base_recipe`
    WHERE `base_id` = OLD.`base_id` AND `material_entry` <> 0)
  WHERE `id` = OLD.`base_id`;
END$$

DELIMITER ;

-- Ограничение вешаем ТОЛЬКО если оно ни на кого не падает: иначе миграция
-- обрушится на живых данных, а включённая основа без условий - это ошибка
-- содержания, которую должен править человек в панели, а не ALTER. Панель
-- проверяет то же самое и объясняет причину словами.
SET @bad := (SELECT COUNT(*) FROM `ap_base`
  WHERE `enabled` = 1 AND `recipe_count` = 0);
SET @has := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_base'
    AND CONSTRAINT_NAME = 'ap_base_recipe_required');
SET @sql := IF(@bad = 0 AND @has = 0,
  'ALTER TABLE `ap_base` ADD CONSTRAINT `ap_base_recipe_required` CHECK (`recipe_count` > 0 OR `enabled` = 0)',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- 3. Снимок предмета (решение 6)
-- ---------------------------------------------------------------------------
-- Раньше в строке лежали ссылки на материалы, и числа считались заново. Из-за
-- этого `.aprof reload` и рестарт вели себя по-разному: reload разливал старые
-- структуры, а рестарт пересчитывал всё - и у игроков ночью менялись
-- характеристики уже выкованного оружия. Теперь числа фиксируются в момент
-- ковки: выкованное - выковано.
--
-- Колонки добавляются по одной, чтобы миграцию можно было применить на базе,
-- где часть из них уже есть.
DROP PROCEDURE IF EXISTS `ap_add_column`;
DELIMITER $$
CREATE PROCEDURE `ap_add_column`(IN tbl VARCHAR(64), IN col VARCHAR(64),
                                 IN spec VARCHAR(255))
BEGIN
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl
        AND COLUMN_NAME = col) = 0 THEN
    SET @s := CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', spec);
    PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

CALL `ap_add_column`('ap_generated_item', 'name_ru',    'VARCHAR(255) NOT NULL DEFAULT ''''');
CALL `ap_add_column`('ap_generated_item', 'slots',      'TINYINT UNSIGNED NOT NULL DEFAULT 0');
CALL `ap_add_column`('ap_generated_item', 'ilvl',       'SMALLINT UNSIGNED NOT NULL DEFAULT 1');
CALL `ap_add_column`('ap_generated_item', 'req_level',  'TINYINT UNSIGNED NOT NULL DEFAULT 1');
CALL `ap_add_column`('ap_generated_item', 'dmg_min',    'SMALLINT UNSIGNED NOT NULL DEFAULT 0');
CALL `ap_add_column`('ap_generated_item', 'dmg_max',    'SMALLINT UNSIGNED NOT NULL DEFAULT 0');
CALL `ap_add_column`('ap_generated_item', 'durability', 'SMALLINT UNSIGNED NOT NULL DEFAULT 0');
CALL `ap_add_column`('ap_generated_item', 'armor',      'SMALLINT UNSIGNED NOT NULL DEFAULT 0');
CALL `ap_add_column`('ap_generated_item', 'block',      'SMALLINT UNSIGNED NOT NULL DEFAULT 0');
CALL `ap_add_column`('ap_generated_item', 'proc_spell', 'INT UNSIGNED NOT NULL DEFAULT 0');
CALL `ap_add_column`('ap_generated_item', 'proc_ppm',   'FLOAT NOT NULL DEFAULT 0');
CALL `ap_add_column`('ap_generated_item', 'displayid',  'INT UNSIGNED NOT NULL DEFAULT 0');
-- Поделка теперь белая и её можно продать торговцу; ноль в цене сделал бы
-- «продажу» пустым обещанием.
CALL `ap_add_column`('ap_generated_item', 'sell_price', 'INT UNSIGNED NOT NULL DEFAULT 0');
-- Статы строкой «тип=значение,тип=значение»: их не больше десяти, отдельная
-- таблица ради этого не окупается.
CALL `ap_add_column`('ap_generated_item', 'stats',      'VARCHAR(255) NOT NULL DEFAULT ''''');

DROP PROCEDURE IF EXISTS `ap_add_column`;

-- ---------------------------------------------------------------------------
-- 4. Уровень предмета -> требуемый уровень персонажа (решение 14)
-- ---------------------------------------------------------------------------
-- RequiredLevel брался у основы, а сила - у материалов: основа с req_level 1 и
-- мифрил в частях давали эпические числа, надеваемые с первого уровня. Кривая
-- 3.3.5a не линейна, поэтому это таблица, а не формула.
CREATE TABLE IF NOT EXISTS `ap_ilvl_level` (
  `ilvl_max`  SMALLINT UNSIGNED NOT NULL COMMENT 'Уровень предмета не выше этого...',
  `req_level` TINYINT UNSIGNED  NOT NULL COMMENT '...требует такого уровня персонажа',
  PRIMARY KEY (`ilvl_max`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Уровень предмета -> требуемый уровень персонажа';

-- Первая прикидка по ванильной кривой: до 60 уровня предмет примерно на 5-8
-- уровней «старше» персонажа, дальше разрыв растёт. Числа владелец правит в
-- панели, вкладка «Баланс».
INSERT IGNORE INTO `ap_ilvl_level` (`ilvl_max`, `req_level`) VALUES
  (10, 1), (15, 5), (20, 10), (25, 15), (30, 20), (35, 25), (40, 30),
  (45, 35), (50, 40), (55, 45), (60, 50), (65, 55), (70, 58), (80, 60),
  (100, 63), (120, 66), (150, 70), (200, 75), (300, 80);

-- ---------------------------------------------------------------------------
-- 5. Настройки: сборка мусора и шанс успеха (решения 5 и 13)
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `ap_config` (`name`, `value`, `comment`) VALUES
  ('gc_enabled', '1',
   'Сборка мусора пула на старте мира: вернуть id, у которых не осталось живых предметов'),
  ('skill_per_ilvl', '5',
   'Сложность работы = уровень предмета x это число (навык против сложности)'),
  ('base_chance', '75',
   'Шанс успеха при разрыве навык-сложность, равном нулю, %'),
  ('chance_step', '1',
   'На сколько % меняется шанс за каждую единицу разрыва'),
  ('fail_floor', '10',
   'Нижняя граница шанса успеха, %: ниже неё не опускаемся никогда');
