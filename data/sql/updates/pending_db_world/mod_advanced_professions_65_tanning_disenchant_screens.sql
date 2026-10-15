-- mod-advanced-professions: дубильная рама и стол распыления (#190).
-- Бит 128 в ap_profession.screens: дубильная рама открывает окно выделки кожи.
-- Бит 256: стол распыления открывает окно распыления.
-- Стол кожевника остаётся верстаком Кожевничества, стол разбора - Разбора.

INSERT IGNORE INTO `ap_station` (`id`, `code`, `name_ru`, `sort`, `enabled`) VALUES
(16, 'tanning_rack', 'Дубильная рама', 160, 1),
(17, 'disenchant_table', 'Стол распыления', 170, 1);

INSERT IGNORE INTO `ap_profession` (`id`, `code`, `name_ru`, `station_id`, `screens`, `has_skill`, `skill_max`, `sort`, `enabled`) VALUES
(17, 'tanning', 'Выделка кожи', 16, 128, 0, 500, 170, 1),
(18, 'disenchanting', 'Распыление', 17, 256, 0, 500, 180, 1);
