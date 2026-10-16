-- Превышение больше +4 в полосах 1-50 не допускается: статы именного предмета снижены до превышения +4.
UPDATE `item_template` SET `stat_value1` = 4, `stat_value2` = 4 WHERE `entry` = 13033 AND `stat_type1` = 6 AND `stat_type2` = 5;
-- Двойник «Сератила» на той же вставке берёт стихийный плавень: превышение больше +4.
UPDATE `item_template` SET `stat_value1` = 11 WHERE `entry` = 17016 AND `stat_type1` = 4;
