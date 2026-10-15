-- Эскизы основ добычи с катализатором: именной предмет сильнее суммы вставок, у двух статов +1 каждому.
-- Источник предметов - только эскиз, оригинал в добыче заменён сломанной основой.
UPDATE `item_template` SET `stat_value1` = 5, `stat_value2` = 9 WHERE `entry` = 7761 AND `stat_type1` = 3 AND `stat_type2` = 7;
UPDATE `item_template` SET `stat_value1` = 13, `stat_value2` = 7 WHERE `entry` = 18498 AND `stat_type1` = 7 AND `stat_type2` = 4;
