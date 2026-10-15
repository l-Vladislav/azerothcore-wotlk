-- Именные предметы без эффекта, у которых один стат был на 1 ниже вставки эскиза при катализаторе:
-- стат поднят до вставки. Источник предметов - только эскиз.
UPDATE `item_template` SET `stat_value1` = 8 WHERE `entry` = 9384 AND `stat_type1` = 3;
UPDATE `item_template` SET `stat_value3` = 6 WHERE `entry` = 13360 AND `stat_type3` = 7;
UPDATE `item_template` SET `stat_value3` = 4 WHERE `entry` = 1602 AND `stat_type3` = 7;
UPDATE `item_template` SET `stat_value2` = 6 WHERE `entry` = 11702 AND `stat_type2` = 7;
