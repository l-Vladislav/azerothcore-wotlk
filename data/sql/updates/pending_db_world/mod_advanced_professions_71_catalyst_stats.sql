-- Именные предметы игры, чей эскиз с катализатором совпадал с двойником без катализатора:
-- стат поднят на 1, чтобы катализатор давал прибавку. Источник предметов - только эскиз.
UPDATE `item_template` SET `stat_value1` = 2 WHERE `entry` = 5112 AND `stat_type1` = 3;
UPDATE `item_template` SET `stat_value1` = 2 WHERE `entry` = 2088 AND `stat_type1` = 7;
UPDATE `item_template` SET `stat_value1` = 2 WHERE `entry` = 5255 AND `stat_type1` = 3;
