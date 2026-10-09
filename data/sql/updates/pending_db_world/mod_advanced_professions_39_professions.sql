-- mod-advanced-professions: профессии верстаков (#153).
-- Профессия задаёт верстак, экраны и навык; тип изделия и материал принадлежат профессии.
-- Схема - в _1_schema.sql, навык персонажа - pending_db_characters/mod_advanced_professions.sql.

INSERT IGNORE INTO `ap_profession` (`id`, `code`, `name_ru`, `station_id`, `screens`, `has_skill`, `skill_max`, `sort`, `enabled`) VALUES
(1, 'weaponsmith', 'Оружейник', 1, 3, 1, 500, 10, 1),
(2, 'armorsmith', 'Бронник', 1, 3, 1, 500, 20, 1),
(3, 'leatherworking', 'Кожевничество', 2, 3, 1, 500, 30, 1),
(4, 'tailoring', 'Портняжное дело', 3, 3, 1, 500, 40, 1),
(5, 'alchemy', 'Алхимия', 4, 3, 1, 500, 50, 1),
(6, 'enchanting', 'Наложение чар', 5, 3, 1, 500, 60, 1),
(7, 'cooking', 'Кулинария', 6, 3, 1, 500, 70, 1),
(8, 'first_aid', 'Первая помощь', 7, 3, 1, 500, 80, 1),
(9, 'engineering', 'Инженерное дело', 8, 3, 1, 500, 90, 1),
(10, 'jewelcrafting', 'Ювелирное дело', 9, 3, 1, 500, 100, 1),
(11, 'inscription', 'Начертание', 10, 3, 1, 500, 110, 1),
(12, 'inlay', 'Инкрустация', 11, 4, 0, 500, 120, 1),
(13, 'salvage', 'Разбор', 12, 16, 0, 500, 130, 1),
(14, 'merge', 'Объединение', 13, 8, 0, 500, 140, 1),
(15, 'smelting', 'Плавка', 14, 0, 0, 500, 150, 1);

UPDATE `ap_item_type` SET `profession_id` = 1 WHERE `profession_id` = 0;

UPDATE `ap_material` SET `profession_id` = 1 WHERE `profession_id` = 0;

-- Инкрустация берёт камни и катализаторы своими строками
INSERT IGNORE INTO `ap_material` (`profession_id`, `entry`, `role`, `stat_type`, `stat_value`, `name_ru`, `enabled`,
    `ilvl_min`, `ilvl_max`, `part_kind_id`, `insert_type_id`, `quality_min`, `quality_max`)
SELECT 12, `entry`, `role`, `stat_type`, `stat_value`, `name_ru`, `enabled`,
    `ilvl_min`, `ilvl_max`, `part_kind_id`, `insert_type_id`, `quality_min`, `quality_max`
FROM `ap_material` WHERE `profession_id` = 1 AND `role` IN ('insert', 'catalyst');

DELETE FROM `ap_config` WHERE `name` = 'skill_max';
