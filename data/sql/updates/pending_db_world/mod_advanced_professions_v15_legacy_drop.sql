-- mod-advanced-professions: снос легаси прежней модели (DESIGN §11, пункт 12).
--
-- Применять ТОЛЬКО вместе с worldserver протокола 11: до него собранный модуль
-- читает колонки, которые эта миграция убирает, и упадёт на первом же SELECT.
--
-- Что уходит и почему:
--   * ap_base / ap_base_recipe - основа как набор УСЛОВИЙ. Заменены рецептом
--     как набором ПРЕДМЕТОВ (ap_recipe/ap_recipe_item, миграция v14);
--   * ap_skill_bucket и разбивка ap_quality_chance по корзинам - корзин навыка
--     больше нет: навык одно число и на характеристики не влияет (§2.2, §5.1);
--   * проценты вклада частей, allow_proc, count и координаты гнёзд - числа
--     изделия приходят готовыми из результата рецепта, а геометрия чертежа это
--     оформление и живёт в аддоне (§5.4.1, §7);
--   * числа ковки у материала (тир, урон, прочность, илвл, прок) - для ковки
--     материал это просто предмет: entry, род, роль (§2.2);
--   * множители статов у качества и корзины - вставка даёт сырой стат (§5.7).
--
-- ap_ilvl_level НЕ трогаем: таблица не используется, но понадобится, если
-- вставки поедут в сторону «материал поднимает уровень предмета» (§5.5, §5.7).

DROP PROCEDURE IF EXISTS `ap_drop_column`;
DELIMITER $$
CREATE PROCEDURE `ap_drop_column`(IN tbl VARCHAR(64), IN col VARCHAR(64))
BEGIN
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl
        AND COLUMN_NAME = col) = 1 THEN
    SET @s := CONCAT('ALTER TABLE `', tbl, '` DROP COLUMN `', col, '`');
    PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

-- === ap_generated_item: снимок доводки поверх фиксированного изделия ========
-- Прежняя строка описывала предмет, собранный из материалов: основа, качество,
-- корзина, части и полтора десятка посчитанных чисел. Теперь доводка ничего не
-- считает - она копирует строку изделия и дописывает статы вставок, поэтому
-- хранить надо ровно три вещи: поверх чего доводим, из какого рецепта это
-- вышло (нужно разбору и именным сочетаниям) и что вставлено.
--
-- Таблица пересоздаётся, а не переносится: на PTR в ней пять строк, и ни одна
-- не лежит у игрока в сумке (проверено по item_instance 2026-09-03), а на live
-- модуль не выкатывался вовсе. Переносить нечего - решение владельца.
DROP TABLE IF EXISTS `ap_generated_item`;
CREATE TABLE `ap_generated_item` (
  `entry`        INT UNSIGNED NOT NULL COMMENT 'Занятый id из пула pool_lo..pool_hi',
  `combo_hash`   VARCHAR(64)  NOT NULL COMMENT 'Читаемый ключ комбинации: i<изделие>:m<вставки>',
  `source_entry` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Изделие рецепта (item_template), поверх которого идёт доводка',
  `recipe_id`    INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ap_recipe.id, из которого вышло изделие: по нему считается возврат при разборе (§5.2)',
  `mats`         VARCHAR(128) NOT NULL DEFAULT '' COMMENT 'Вставленные материалы по порядку слотов, через запятую',
  `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`entry`),
  UNIQUE KEY `uk_ap_generated_combo` (`combo_hash`),
  KEY `idx_ap_generated_source` (`source_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- === ap_quality_chance: одна глобальная таблица процентов (§5.4.5) =========
-- Была разбивка по пяти корзинам навыка. Складывать их нельзя (получилось бы
-- 13 % эпика), выбирать одну за владельца - тем более. Берём числа, которые он
-- сам назвал в §5.4.5, дальше правятся в панели.
DROP TABLE IF EXISTS `ap_quality_chance`;
CREATE TABLE `ap_quality_chance` (
  `quality` TINYINT UNSIGNED  NOT NULL COMMENT 'ap_quality.quality',
  `weight`  SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Вес ступени в общем броске; проценты глобальные, от мастера не зависят',
  PRIMARY KEY (`quality`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `ap_quality_chance` (`quality`, `weight`) VALUES
  (1, 55), (2, 30), (3, 12), (4, 3), (5, 0);

-- === Легаси-таблицы прежней модели =========================================
-- Триггеры v8 (`ap_base_recipe_count_*`) уходят вместе со своей таблицей.
DROP TABLE IF EXISTS `ap_base_recipe`;
DROP TABLE IF EXISTS `ap_base`;
DROP TABLE IF EXISTS `ap_skill_bucket`;

-- === ap_type_part: остаются только род и подпись ===========================
-- У ячейки два состояния: пусто либо предмет с количеством (§5.4.1, решение
-- владельца 2026-09-03). Ни «обязательности», ни материала по умолчанию нет:
-- пустая ячейка - законная часть набора, а рецепт, который её не называет,
-- требует именно пустоты. Расход задаёт рецепт; координаты и текстура -
-- геометрия чертежа, её место в аддоне рядом с картинками (§7).
CALL `ap_drop_column`('ap_type_part', 'count');
CALL `ap_drop_column`('ap_type_part', 'required');
CALL `ap_drop_column`('ap_type_part', 'default_material');
CALL `ap_drop_column`('ap_type_part', 'dmg_pct');
CALL `ap_drop_column`('ap_type_part', 'dura_pct');
CALL `ap_drop_column`('ap_type_part', 'ilvl_pct');
CALL `ap_drop_column`('ap_type_part', 'allow_proc');
CALL `ap_drop_column`('ap_type_part', 'texture');
CALL `ap_drop_column`('ap_type_part', 'x');
CALL `ap_drop_column`('ap_type_part', 'y');

-- === ap_recipe_item: «не задано» вместо «любого материала» =================
-- Поблажка `any_material` отменена (решение владельца 2026-09-03): её место
-- заняло отсутствие строки. Строка без предмета больше ничего не значит,
-- поэтому такие строки удаляются - иначе рецепт требовал бы «предмет 0».
--
-- ВНИМАНИЕ, это меняет смысл перенесённых рецептов: ячейка, которая была
-- «любой», станет ячейкой, которая обязана быть ПУСТОЙ. Наборы после миграции
-- надо пересобрать в панели - на PTR их три, и владелец заводит их сам.
DELETE FROM `ap_recipe_item` WHERE `item_entry` = 0;
CALL `ap_drop_column`('ap_recipe_item', 'any_material');

-- === ap_material: для ковки предмет, для вставки стат и границы уровня =====
CALL `ap_drop_column`('ap_material', 'tier');
CALL `ap_drop_column`('ap_material', 'dmg');
CALL `ap_drop_column`('ap_material', 'durability');
CALL `ap_drop_column`('ap_material', 'ilvl');
CALL `ap_drop_column`('ap_material', 'proc_spell');
CALL `ap_drop_column`('ap_material', 'proc_ppm');

-- Роль «только для сочетаний»: материал без чисел, годный лишь как часть
-- именного набора (§5.7). Панель ставит её явно, а не как «забыли заполнить».
ALTER TABLE `ap_material`
  MODIFY COLUMN `role` ENUM('base','insert','combo') NOT NULL DEFAULT 'insert'
  COMMENT 'base - в ячейку схемы, insert - в слот доводки со своим статом, combo - в слот без чисел, только ради сочетания';

-- === ap_quality: только «качество -> число слотов» =========================
CALL `ap_drop_column`('ap_quality', 'stat_pct');

-- === ap_item_type: скорость и слот надевания - свойства результата =========
CALL `ap_drop_column`('ap_item_type', 'delay');
CALL `ap_drop_column`('ap_item_type', 'inventory_type');

-- === ap_synergy: сочетание отдаёт готовый предмет, а не бонус ==============
-- Статы, бонус и внешний вид переехали в строку именного предмета: у него своё
-- всё, а не только имя и прибавка (§5.6). name_ru остаётся подписью для панели.
CALL `ap_drop_column`('ap_synergy', 'stat_type');
CALL `ap_drop_column`('ap_synergy', 'stat_value');
CALL `ap_drop_column`('ap_synergy', 'displayid');

-- === ap_config: настройки отменённых механик ===============================
DELETE FROM `ap_config` WHERE `name` IN
  ('skill_per_ilvl', 'tier_ceiling', 'skill_per_insert', 'fail_pct');

-- Комментарии к оставшимся числам: часть из них поменяла смысл.
UPDATE `ap_config` SET `comment` =
  'Что делать с набором, которого нет ни в одном рецепте: 0 - отказ, 1 - материалы сгорают впустую, 2 - материалы сгорают и выдаётся поделка типа (§5.4.2)'
  WHERE `name` = 'fail_mode';
UPDATE `ap_config` SET `comment` =
  'Навык за удачную ковку основы. Доводка навыку не учит, неудача тоже (§5.1)'
  WHERE `name` = 'skill_per_craft';

-- Правка справочника обязана поднять его версию, иначе аддон покажет старые
-- подписи и не узнает об этом (§7).
UPDATE `ap_config` SET `value` = `value` + 1 WHERE `name` = 'static_version';

DROP PROCEDURE IF EXISTS `ap_drop_column`;
