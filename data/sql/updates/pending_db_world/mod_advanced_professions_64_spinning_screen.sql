-- mod-advanced-professions: прядильный станок и экран прядения (#190).
-- Бит 64 в ap_profession.screens: прядильный станок открывает окно прядения.
-- Ткацкий станок остаётся верстаком Портняжного дела.

INSERT IGNORE INTO `ap_station` (`id`, `code`, `name_ru`, `sort`, `enabled`) VALUES
(15, 'spinning_wheel', 'Прядильный станок', 150, 1);

INSERT IGNORE INTO `ap_profession` (`id`, `code`, `name_ru`, `station_id`, `screens`, `has_skill`, `skill_max`, `sort`, `enabled`) VALUES
(16, 'spinning', 'Прядение', 15, 64, 0, 500, 160, 1);
