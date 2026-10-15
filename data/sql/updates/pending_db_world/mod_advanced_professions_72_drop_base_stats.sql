-- Именные предметы основ добычи, у которых стат был на 1 ниже вставки эскиза при катализаторе:
-- стат поднят до вставки. Источник предметов - только эскиз, оригинал в добыче заменён сломанной основой.
UPDATE `item_template` SET `stat_value1` = 4 WHERE `entry` = 7761 AND `stat_type1` = 3;
UPDATE `item_template` SET `stat_value2` = 6 WHERE `entry` = 18498 AND `stat_type2` = 4;
UPDATE `item_template` SET `stat_value2` = 6 WHERE `entry` = 18737 AND `stat_type2` = 7;
