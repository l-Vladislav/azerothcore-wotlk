-- mod-advanced-professions: экран плавки (#188).
-- Бит 32 в ap_profession.screens: верстак открывает окно переплавки.

UPDATE `ap_profession` SET `screens` = `screens` | 32 WHERE `code` = 'smelting';
