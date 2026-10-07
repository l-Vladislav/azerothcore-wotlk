-- mod-advanced-professions: таблицы модуля.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §6.

CREATE TABLE IF NOT EXISTS `ap_config` (
  `name` varchar(64) NOT NULL,
  `value` varchar(64) NOT NULL DEFAULT '0',
  `comment` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_quality` (
  `quality` tinyint unsigned NOT NULL,
  `name_ru` varchar(32) NOT NULL DEFAULT '',
  `slots` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`quality`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_quality_chance` (
  `quality` tinyint unsigned NOT NULL COMMENT 'ap_quality.quality',
  `weight` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Вес ступени в общем броске; проценты глобальные, от мастера не зависят',
  PRIMARY KEY (`quality`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_part_kind` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(32) NOT NULL COMMENT 'Латиницей, для миграций и логов',
  `name_ru` varchar(64) NOT NULL COMMENT 'Как род зовётся в панели и в игре',
  `sort` smallint unsigned NOT NULL DEFAULT '0',
  `enabled` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ap_part_kind_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Род материала ячейки ковки: металл, дерево, кожа (DESIGN §2.5)';

CREATE TABLE IF NOT EXISTS `ap_insert_type` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(32) NOT NULL,
  `name_ru` varchar(64) NOT NULL,
  `sort` smallint unsigned NOT NULL DEFAULT '0',
  `enabled` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ap_insert_type_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Тип вставки: самоцвет, кость, руна (DESIGN §2.5)';

CREATE TABLE IF NOT EXISTS `ap_item_type` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(24) NOT NULL DEFAULT '' COMMENT 'ключ для схемы в аддоне',
  `name_ru` varchar(64) NOT NULL DEFAULT '',
  `sub_ru` varchar(32) NOT NULL DEFAULT '' COMMENT 'подпись под именем: одноручное и т.п.',
  `item_class` tinyint unsigned NOT NULL DEFAULT '2',
  `item_subclass` tinyint unsigned NOT NULL DEFAULT '7',
  `displayid` int unsigned NOT NULL DEFAULT '0' COMMENT 'вид по умолчанию, если основа своего не задала',
  `sheet_art` varchar(48) NOT NULL DEFAULT '' COMMENT 'Имя файла чертежа в textures аддона, без пути и расширения',
  `sort` smallint unsigned NOT NULL DEFAULT '100',
  `enabled` tinyint unsigned NOT NULL DEFAULT '1',
  `fail_entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Серая поделка (item_template) для этого типа при неудачной ковке; 0 = не заведена',
  `pool_lo` int unsigned NOT NULL DEFAULT '0' COMMENT 'Начало слайса пула: заготовки item_template с видом этого типа',
  `pool_hi` int unsigned NOT NULL DEFAULT '0' COMMENT 'Конец слайса пула включительно. 0 в паре с pool_lo - слайса нет, доводка этому типу недоступна',
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_type_part` (
  `type_id` int unsigned NOT NULL,
  `idx` tinyint unsigned NOT NULL COMMENT 'порядок на схеме, с 1',
  `label_ru` varchar(48) NOT NULL DEFAULT '',
  `required` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '1 = без этой части предмета не существует: пустой её оставить нельзя',
  `part_kind_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'ap_part_kind.id: какой род принимает ячейка',
  PRIMARY KEY (`type_id`,`idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_ilvl_level` (
  `ilvl_max` smallint unsigned NOT NULL COMMENT 'Уровень предмета не выше этого...',
  `req_level` tinyint unsigned NOT NULL COMMENT '...требует такого уровня персонажа',
  PRIMARY KEY (`ilvl_max`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Уровень предмета -> требуемый уровень персонажа';

CREATE TABLE IF NOT EXISTS `ap_material` (
  `entry` int unsigned NOT NULL COMMENT 'item_template.entry',
  `role` enum('base','insert','catalyst') NOT NULL DEFAULT 'insert' COMMENT 'base - в ячейку схемы, insert - в слот доводки со своим статом, catalyst - в ячейку катализатора без стата',
  `stat_type` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value` smallint unsigned NOT NULL DEFAULT '0',
  `name_ru` varchar(64) NOT NULL DEFAULT '',
  `enabled` tinyint unsigned NOT NULL DEFAULT '1',
  `ilvl_min` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Вставка требует предмет не ниже этого уровня; 0 = без нижней границы',
  `ilvl_max` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Вставка не идёт в предмет выше этого уровня; 0 = потолка нет',
  `part_kind_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'ap_part_kind.id для роли base; 0 - не задан',
  `insert_type_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'ap_insert_type.id для роли insert; 0 - не задан',
  `quality_min` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Нижнее качество вещи-цели; 0 - границы нет',
  `quality_max` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Верхнее качество вещи-цели; 0 - границы нет. Обе нули - строгое совпадение с качеством самого камня',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_recipe` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `type_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'ap_item_type.id',
  `name_ru` varchar(64) NOT NULL DEFAULT '' COMMENT 'Подпись рецепта для панели; настоящее имя изделия живёт в item_template результата',
  `req_skill` smallint unsigned NOT NULL DEFAULT '1' COMMENT 'Требуемый навык мастера; разрыв с ним задаёт шанс успеха (§5.1.1)',
  `teach_item` int unsigned NOT NULL DEFAULT '0' COMMENT 'Обучающий предмет (item_template); 0 = рецепт добывается только угадыванием набора (§5.4.4)',
  `quality_min` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Нижняя граница качества результата, ap_quality.quality (§5.4.5)',
  `quality_max` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Верхняя граница качества результата, ap_quality.quality (§5.4.5)',
  `enabled` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Включён ли рецепт в ковке; держим выключенным, пока нет ни одной строки ap_recipe_result',
  `acquire` enum('forge','drop') NOT NULL DEFAULT 'forge' COMMENT 'forge - куётся на верстаке; drop - только добыча, ковать нельзя',
  `slots_enabled` tinyint unsigned NOT NULL DEFAULT '1' COMMENT '0 - изделия основы без гнёзд доводки при любом качестве',
  PRIMARY KEY (`id`),
  KEY `idx_ap_recipe_type` (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_recipe_item` (
  `recipe_id` int unsigned NOT NULL COMMENT 'ap_recipe.id',
  `part_idx` tinyint unsigned NOT NULL COMMENT 'ap_type_part.idx у типа рецепта',
  `item_entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Требуемый предмет (item_template); 0 при any_material=1',
  `count` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Сколько единиц уходит из сумки за эту ячейку (§5.4.2)',
  PRIMARY KEY (`recipe_id`,`part_idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_recipe_result` (
  `recipe_id` int unsigned NOT NULL COMMENT 'ap_recipe.id',
  `quality` tinyint unsigned NOT NULL COMMENT 'Ступень качества, ap_quality.quality',
  `result_entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Готовый предмет (item_template) для этой ступени качества',
  `pool_lo` int unsigned NOT NULL DEFAULT '0' COMMENT 'Начало слайса основы; 0 - слайса нет',
  `pool_hi` int unsigned NOT NULL DEFAULT '0' COMMENT 'Конец слайса ВКЛЮЧАЯ резерв. Засеяна только первая четверть тысячи',
  PRIMARY KEY (`recipe_id`,`quality`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_recipe_insert_type` (
  `recipe_id` int unsigned NOT NULL COMMENT 'ap_recipe.id',
  `insert_type_id` int unsigned NOT NULL COMMENT 'ap_insert_type.id',
  PRIMARY KEY (`recipe_id`,`insert_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Какие типы вставки принимает основа. Строк нет - принимает любые';

CREATE TABLE IF NOT EXISTS `ap_recipe_material` (
  `recipe_id` int unsigned NOT NULL COMMENT 'ap_recipe.id',
  `item_entry` int unsigned NOT NULL COMMENT 'ap_material.entry роли insert',
  PRIMARY KEY (`recipe_id`,`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Поимённый список вставок основы. Строк нет - действует набор типов';

CREATE TABLE IF NOT EXISTS `ap_synergy` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name_ru` varchar(64) NOT NULL DEFAULT '',
  `pattern` varchar(128) NOT NULL DEFAULT '',
  `enabled` tinyint unsigned NOT NULL DEFAULT '1',
  `recipe_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Рецепт-основа, которой принадлежит сочетание, ap_recipe.id (0 = не привязано)',
  `result_entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Именной предмет (item_template) за верное сочетание вставок; 0 = не задан',
  `order_matters` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Важен ли порядок вставок по слотам при сравнении набора (0 = порядок не важен)',
  `teach_item` int unsigned NOT NULL DEFAULT '0' COMMENT 'entry обучающего предмета: применение записывает сочетание изученным. 0 - книги нет, сочетание только угадывается',
  `catalyst_entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'ap_material.entry роли catalyst; 0 - эскиз без катализатора',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_merge` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name_ru` varchar(64) NOT NULL DEFAULT '' COMMENT 'Имя рецепта в панели; игрок видит имя предмета-результата',
  `type_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'ap_item_type.id: какого рода вещь кладут в центр',
  `result_entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'item_template.entry на выходе. 0 - рецепт нерабочий',
  `teach_item` int unsigned NOT NULL DEFAULT '0' COMMENT 'entry обучающего предмета. 0 - рецепт только находят',
  `enabled` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_ap_merge_type` (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_merge_item` (
  `merge_id` int unsigned NOT NULL,
  `idx` tinyint unsigned NOT NULL COMMENT '0 - середина рецепта без типа, 1..5 - ячейки в порядке панели',
  `item_entry` int unsigned NOT NULL COMMENT 'item_template.entry: что кладут в ячейку',
  PRIMARY KEY (`merge_id`,`idx`),
  KEY `idx_ap_merge_item_entry` (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `ap_generated_item` (
  `entry` int unsigned NOT NULL COMMENT 'Занятый id из пула pool_lo..pool_hi',
  `combo_hash` varchar(64) NOT NULL COMMENT 'Читаемый ключ комбинации: i<изделие>:m<вставки>',
  `source_entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Изделие рецепта (item_template), поверх которого идёт доводка',
  `recipe_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'ap_recipe.id, из которого вышло изделие: по нему считается возврат при разборе (§5.2)',
  `mats` varchar(128) NOT NULL DEFAULT '' COMMENT 'Вставленные материалы по порядку слотов, через запятую',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`entry`),
  UNIQUE KEY `uk_ap_generated_combo` (`combo_hash`),
  KEY `idx_ap_generated_source` (`source_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Род ячейки задаёт part_kind_id; прежняя колонка kind удаляется там, где осталась
SET @has_kind := (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'ap_type_part' AND column_name = 'kind');
SET @ddl := IF(@has_kind > 0, 'ALTER TABLE `ap_type_part` DROP COLUMN `kind`', 'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Роль catalyst и катализатор эскиза
ALTER TABLE `ap_material` MODIFY `role` enum('base','insert','catalyst') NOT NULL DEFAULT 'insert' COMMENT 'base - в ячейку схемы, insert - в слот доводки со своим статом, catalyst - в ячейку катализатора без стата';

SET @has_catalyst := (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'ap_synergy' AND column_name = 'catalyst_entry');
SET @ddl := IF(@has_catalyst = 0, 'ALTER TABLE `ap_synergy` ADD COLUMN `catalyst_entry` int unsigned NOT NULL DEFAULT ''0'' COMMENT ''ap_material.entry роли catalyst; 0 - эскиз без катализатора'' AFTER `teach_item`', 'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Отключаемые гнёзда основы
SET @has_slots := (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'ap_recipe' AND column_name = 'slots_enabled');
SET @ddl := IF(@has_slots = 0, 'ALTER TABLE `ap_recipe` ADD COLUMN `slots_enabled` tinyint unsigned NOT NULL DEFAULT ''1'' COMMENT ''0 - изделия основы без гнёзд доводки при любом качестве'' AFTER `acquire`', 'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
