-- mod-advanced-professions: рецепты как фиксированный набор → фиксированный
-- результат (разворот 2026-09-02, DESIGN §2.2, §5.4, §5.4.5, §5.6).
--
-- Формулы, считавшей предмет из свойств материалов, больше нет. Взамен:
-- «тип + точный набор предметов по ячейкам» ищется в новых таблицах и отдаёт
-- готовый `item_template` результата. Прежние `ap_base`/`ap_base_recipe` были
-- набором УСЛОВИЙ («побеждает подробнейший»), а `ap_recipe`/`ap_recipe_item` -
-- набор ПРЕДМЕТОВ («совпадает точно или не совпадает вовсе»), поэтому таблицы
-- новые, а не ALTER старых.
--
-- ВАЖНО: миграция **только добавляет и переносит**, как и v13. `ap_base`,
-- `ap_base_recipe`, `ap_type_part.count` и все процентные поля остаются на
-- месте - их всё ещё читает собранный worldserver (`AdvancedProfessionsMgr.cpp`,
-- `ResolveBase`). Снос легаси - миграция v15, после того как C++ перейдёт на
-- новые таблицы (DESIGN §11, план правок, пункт 12).
--
-- Нумерация: план DESIGN называет эту миграцию «v13», но это имя уже занято
-- файлом `mod_advanced_professions_v13_insert_ilvl.sql` (границы уровня у
-- вставки), который уже применён на PTR. Поэтому здесь v14, а снос легаси
-- станет v15.

-- === ap_recipe: рецепт как сущность игрока (§5.4.4) =======================
-- Тип, требуемый навык и границы качества. Сам результат — не здесь: у
-- рецепта по строке-результату на каждую ступень качества (ap_recipe_result,
-- §5.4.5), потому что качество меняет число слотов и, значит, это другой
-- item_template.
CREATE TABLE IF NOT EXISTS `ap_recipe` (
  `id`          INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  `type_id`     INT UNSIGNED      NOT NULL DEFAULT 0 COMMENT 'ap_item_type.id',
  `name_ru`     VARCHAR(64)       NOT NULL DEFAULT '' COMMENT 'Подпись рецепта для панели; настоящее имя изделия живёт в item_template результата',
  `req_skill`   SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Требуемый навык мастера; разрыв с ним задаёт шанс успеха (§5.1.1)',
  `teach_item`  INT UNSIGNED      NOT NULL DEFAULT 0 COMMENT 'Обучающий предмет (item_template); 0 = рецепт добывается только угадыванием набора (§5.4.4)',
  `quality_min` TINYINT UNSIGNED  NOT NULL DEFAULT 1 COMMENT 'Нижняя граница качества результата, ap_quality.quality (§5.4.5)',
  `quality_max` TINYINT UNSIGNED  NOT NULL DEFAULT 1 COMMENT 'Верхняя граница качества результата, ap_quality.quality (§5.4.5)',
  `enabled`     TINYINT UNSIGNED  NOT NULL DEFAULT 0 COMMENT 'Включён ли рецепт в ковке; держим выключенным, пока нет ни одной строки ap_recipe_result',
  PRIMARY KEY (`id`),
  KEY `idx_ap_recipe_type` (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- === ap_recipe_item: точный набор рецепта по ячейкам (§5.4, §5.4.2) =======
-- Строка на каждую ячейку типа. `any_material` = ячейке безразличен материал
-- (единственная поблажка в точном сравнении, §5.4). `count` — расход именно
-- этой ячейки: в новой модели расход часть набора, а не отдельная настройка.
CREATE TABLE IF NOT EXISTS `ap_recipe_item` (
  `recipe_id`    INT UNSIGNED     NOT NULL COMMENT 'ap_recipe.id',
  `part_idx`     TINYINT UNSIGNED NOT NULL COMMENT 'ap_type_part.idx у типа рецепта',
  `item_entry`   INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT 'Требуемый предмет (item_template); 0 при any_material=1',
  `count`        TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Сколько единиц уходит из сумки за эту ячейку (§5.4.2)',
  `any_material` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Ячейке безразличен материал: годится что угодно своего рода (§5.4)',
  PRIMARY KEY (`recipe_id`, `part_idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- === ap_recipe_result: результат на каждую ступень качества (§5.4.5) ======
-- Не названа явно в плане правок (§11, пункт 1), но без неё у рецепта нет
-- результата вовсе - требуют её §5.4.5 и таблица схемы БД §6, добавляем.
CREATE TABLE IF NOT EXISTS `ap_recipe_result` (
  `recipe_id`    INT UNSIGNED     NOT NULL COMMENT 'ap_recipe.id',
  `quality`      TINYINT UNSIGNED NOT NULL COMMENT 'Ступень качества, ap_quality.quality',
  `result_entry` INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT 'Готовый предмет (item_template) для этой ступени качества',
  PRIMARY KEY (`recipe_id`, `quality`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- === ap_item_type.fail_entry: строка-результат поделки (§5.4.2) ===========
-- Набор без рецепта - неудача, а не отказ (fail_mode 1/2). Поделка - одна
-- серая строка-результат на тип, ссылку на неё держит сам тип.
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

CALL `ap_add_column`('ap_item_type', 'fail_entry',
  'INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Серая поделка (item_template) для этого типа при неудачной ковке; 0 = не заведена''');

-- === ap_synergy: сочетание принадлежит рецепту-основе, даёт entry (§5.6) ==
-- `recipe_id` ссылается на рецепт целиком, а не на конкретную его строку
-- результата: качество основы решает, сколько сочетаний доступно, а не какие
-- именно (§5.6, «качество задаёт вариативность, а не список»).
CALL `ap_add_column`('ap_synergy', 'recipe_id',
  'INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Рецепт-основа, которой принадлежит сочетание, ap_recipe.id (0 = не привязано)''');
CALL `ap_add_column`('ap_synergy', 'result_entry',
  'INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Именной предмет (item_template) за верное сочетание вставок; 0 = не задан''');
CALL `ap_add_column`('ap_synergy', 'order_matters',
  'TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Важен ли порядок вставок по слотам при сравнении набора (0 = порядок не важен)''');

DROP PROCEDURE IF EXISTS `ap_add_column`;

-- === ap_config.learn_gap (§5.1) ============================================
-- Рецепты слабее, чем «навык минус learn_gap», не учат навыку - иначе он
-- фармится самым дешёвым известным рецептом. INSERT IGNORE: если владелец уже
-- где-то проставил своё значение, второй прогон миграции его не тронет.
INSERT IGNORE INTO `ap_config` (`name`, `value`, `comment`) VALUES
  ('learn_gap', '50', 'Рецепты слабее, чем «навык минус learn_gap», успешную ковку навыку больше не учат (§5.1)');

-- === Перенос ap_base -> ap_recipe (id сохраняется, §11 план) ==============
-- id сохраняется намеренно: тогда ap_base_recipe.base_id ложится на
-- ap_recipe_item.recipe_id один в один, и перенос легко сверить построчно.
-- enabled = 0: у перенесённого рецепта ещё нет ни одной строки
-- ap_recipe_result, а рецепт без результата - кнопка, которая ничего не
-- делает. quality_min/max = 1/1 и teach_item = 0 - решает владелец в панели.
INSERT IGNORE INTO `ap_recipe` (`id`, `type_id`, `name_ru`, `req_skill`,
                                 `teach_item`, `quality_min`, `quality_max`, `enabled`)
SELECT `id`, `type_id`, `name_ru`, `req_skill`, 0, 1, 1, 0
  FROM `ap_base`;

-- === Перенос ap_base_recipe -> ap_recipe_item ==============================
-- material_entry = 0 в старой строке значило «ради расхода», без условия на
-- материал -> any_material = 1. count = 0 в старой строке значило «взять
-- число из ap_type_part.count того же type_id+idx» -> подставляем его явно,
-- запасной вариант 1, если у типа part нет вовсе.
INSERT IGNORE INTO `ap_recipe_item` (`recipe_id`, `part_idx`, `item_entry`, `count`, `any_material`)
SELECT `br`.`base_id`,
       `br`.`part_idx`,
       `br`.`material_entry`,
       CASE WHEN `br`.`count` = 0 THEN COALESCE(`tp`.`count`, 1) ELSE `br`.`count` END,
       CASE WHEN `br`.`material_entry` = 0 THEN 1 ELSE 0 END
  FROM `ap_base_recipe` `br`
  JOIN `ap_base` `b` ON `b`.`id` = `br`.`base_id`
  LEFT JOIN `ap_type_part` `tp` ON `tp`.`type_id` = `b`.`type_id` AND `tp`.`idx` = `br`.`part_idx`;

-- === Добор недостающих ячеек «любой материал» ==============================
-- В старой модели ячейка, не упомянутая в ap_base_recipe, значила «любая».
-- Новое сравнение точное (§5.4): у перенесённого рецепта должна быть строка
-- на КАЖДУЮ ячейку его типа, иначе он станет требовать меньше ячеек, чем
-- раньше, и поведение молча изменится. Добираем как any_material=1,
-- item_entry=0, count из ap_type_part.count.
INSERT IGNORE INTO `ap_recipe_item` (`recipe_id`, `part_idx`, `item_entry`, `count`, `any_material`)
SELECT `b`.`id`, `tp`.`idx`, 0, `tp`.`count`, 1
  FROM `ap_base` `b`
  JOIN `ap_type_part` `tp` ON `tp`.`type_id` = `b`.`type_id`
  LEFT JOIN `ap_base_recipe` `br` ON `br`.`base_id` = `b`.`id` AND `br`.`part_idx` = `tp`.`idx`
 WHERE `br`.`base_id` IS NULL;

-- ap_synergy: recipe_id и result_entry намеренно остаются 0 у существующих
-- строк - привязку к рецепту-основе и именной предмет владелец проставит в
-- панели (на PTR их всего 2, угадывать нечего).
