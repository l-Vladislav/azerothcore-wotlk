-- mod-advanced-professions: основы перестают быть только оружием.
--
-- Пока в MVP только мечи, но следом идут булавы, топоры и щиты. Три вещи,
-- которых для них не хватало:
--   * броня и блок - у щита нет урона, у него armor и block;
--   * прочность - у оружия и брони она своя;
--   * ножны (Sheath) считаются по подклассу, а не задаются: игрок не должен
--     знать, что у одноручного меча это 3, а у двуручного 1.
--
-- Заодно убираем `name_prefix`: настройка была задумана как «слово, с которого
-- строится имя», но имя типа предмета живёт в ap_base.name_ru («Бронзовый
-- клинок», «Стальная булава»), и род для склонений берётся оттуда же. Одно
-- глобальное слово сломалось бы на первом же щите. Код её никогда не читал.

DELETE FROM `ap_config` WHERE `name` = 'name_prefix';

-- ADD COLUMN IF NOT EXISTS в MySQL нет, поэтому проверяем сами: миграция
-- должна переживать повторный прогон.
SET @add := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_base'
               AND COLUMN_NAME = 'armor');
SET @sql := IF(@add = 0,
    'ALTER TABLE `ap_base` '
    'ADD COLUMN `armor` SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER `delay`, '
    'ADD COLUMN `block` SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER `armor`, '
    'ADD COLUMN `durability` SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER `block`',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Прочность мечей MVP: среднее по одноручным мечам того же уровня.
UPDATE `ap_base` SET `durability` = 55 WHERE `durability` = 0 AND `item_class` = 2;
