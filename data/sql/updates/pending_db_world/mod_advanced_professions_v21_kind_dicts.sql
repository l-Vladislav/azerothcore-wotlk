-- mod-advanced-professions: род и тип вставки переезжают в справочники.
--
-- Зачем. Род материала жил перечислением `ENUM` сразу в трёх местах: в базе, в
-- `MatKind` на C++ и выпадающим списком в панели. Завести «кость» стоило правки
-- всех трёх и пересборки worldserver - при том, что род это чистое содержание,
-- как имя чертежа, уехавшее из Lua в базу ещё в v12.
--
-- Справочника ДВА, и разведены они нарочно (DESIGN §2.5): «дерево» гнезду
-- доводки не нужно никогда, «самоцвет» ячейке ковки - тоже. Роль материала
-- двоичная (v20), и каждой роли отвечает ровно один справочник:
--
--   роль «на основу» -> род        -> ap_part_kind    -> металл, дерево, кожа
--   роль «в слот»    -> тип вставки -> ap_insert_type -> самоцвет, кость, руна
--
-- «Тип вставки» с «типом предмета» (ap_item_type) не сталкивается: рядом всегда
-- стоит уточнение, а в коде это InsertType против TypeDef.
--
-- Старые колонки `kind` НЕ УДАЛЯЮТСЯ. Пока они на месте, база остаётся годной и
-- для прежнего worldserver, и порядок выката перестаёт быть жёстким. Уберёт их
-- следующая чистка легаси, как v15 убрала tier и dmg.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §2.5, «Роли и два справочника».

-- --------------------------------------------------------------------------
-- 1. Сами справочники
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ap_part_kind` (
  `id`      INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  `code`    VARCHAR(32)       NOT NULL COMMENT 'Латиницей, для миграций и логов',
  `name_ru` VARCHAR(64)       NOT NULL COMMENT 'Как род зовётся в панели и в игре',
  `sort`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `enabled` TINYINT UNSIGNED  NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ap_part_kind_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Род материала ячейки ковки: металл, дерево, кожа (DESIGN §2.5)';

CREATE TABLE IF NOT EXISTS `ap_insert_type` (
  `id`      INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  `code`    VARCHAR(32)       NOT NULL,
  `name_ru` VARCHAR(64)       NOT NULL,
  `sort`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `enabled` TINYINT UNSIGNED  NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ap_insert_type_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Тип вставки: самоцвет, кость, руна (DESIGN §2.5)';

-- Id заданы явно, а не отданы AUTO_INCREMENT: по ним пойдёт перенос ниже, и
-- повторный прогон миграции обязан попасть в те же строки.
--
-- Нынешние семь родов раскладываются сами: металл, дерево, кожа, ткань и прочее
-- ячейке ковки, камень и самоцвет - гнезду доводки. Кость, руну и кристалл
-- владелец заведёт в панели, правки кода это больше не требует.
INSERT IGNORE INTO `ap_part_kind` (`id`, `code`, `name_ru`, `sort`) VALUES
(1, 'metal',   'Металл',  10),
(2, 'wood',    'Дерево',  20),
(3, 'leather', 'Кожа',    30),
(4, 'cloth',   'Ткань',   40),
(5, 'other',   'Прочее',  90);

INSERT IGNORE INTO `ap_insert_type` (`id`, `code`, `name_ru`, `sort`) VALUES
(1, 'gem',   'Самоцвет', 10),
(2, 'stone', 'Камень',   20);

-- --------------------------------------------------------------------------
-- 2. Ссылки вместо перечисления
-- --------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `ap_add_column`;
DELIMITER $$
CREATE PROCEDURE `ap_add_column`(IN tbl VARCHAR(64), IN col VARCHAR(64),
                                 IN spec VARCHAR(255))
BEGIN
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl
        AND COLUMN_NAME = col) = 0 THEN
    SET @sql = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', spec);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

-- Ноль значит «не задан». Внешних ключей нет намеренно: справочник чистится
-- панелью, которая сперва проверяет ссылки, а жёсткая связь мешала бы порядку
-- применения миграций.
CALL `ap_add_column`('ap_material', 'part_kind_id',
  "INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ap_part_kind.id для роли base; 0 - не задан'");
CALL `ap_add_column`('ap_material', 'insert_type_id',
  "INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ap_insert_type.id для роли insert; 0 - не задан'");
CALL `ap_add_column`('ap_type_part', 'part_kind_id',
  "INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'ap_part_kind.id: какой род принимает ячейка'");

DROP PROCEDURE IF EXISTS `ap_add_column`;

-- --------------------------------------------------------------------------
-- 3. Перенос
-- --------------------------------------------------------------------------
-- Переносим ТОЛЬКО в незаполненные строки: миграция повторяемая, а после неё
-- род правится в панели, и второй прогон не должен возвращать старое значение
-- из колонки `kind`, которую панель больше не пишет.
UPDATE `ap_material` m
  JOIN `ap_part_kind` k ON k.`code` = m.`kind`
   SET m.`part_kind_id` = k.`id`
 WHERE m.`role` = 'base' AND m.`part_kind_id` = 0;

UPDATE `ap_material` m
  JOIN `ap_insert_type` t ON t.`code` = m.`kind`
   SET m.`insert_type_id` = t.`id`
 WHERE m.`role` = 'insert' AND m.`insert_type_id` = 0;

-- Вставка с родом ячейки (самоцветов среди них нет, но строка могла приехать
-- из старых данных) остаётся без типа - её видно в панели пустым полем.
UPDATE `ap_type_part` p
  JOIN `ap_part_kind` k ON k.`code` = p.`kind`
   SET p.`part_kind_id` = k.`id`
 WHERE p.`part_kind_id` = 0;
