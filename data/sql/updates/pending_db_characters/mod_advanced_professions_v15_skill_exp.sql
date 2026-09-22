-- mod-advanced-professions: снос легаси в acore_characters (DESIGN §11, п. 12).
--
-- `exp` писался и читался с первого дня, но всегда был нулём: опыта у навыка
-- нет, он растёт целыми единицами за удачную ковку (§5.1). Держать поле,
-- которое никто не заполняет, значит однажды на него положиться.
--
-- Парная миграция в pending_db_world/mod_advanced_professions_v15_legacy_drop.sql;
-- применять обе только вместе с worldserver протокола 11.

DROP PROCEDURE IF EXISTS `ap_drop_column`;
DELIMITER $$
CREATE PROCEDURE `ap_drop_column`(IN tbl VARCHAR(64), IN col VARCHAR(64))
BEGIN
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl
        AND COLUMN_NAME = col) = 1 THEN
    SET @s := CONCAT('ALTER TABLE `', tbl, '` DROP COLUMN `', col, '`');
    PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

CALL `ap_drop_column`('ap_character_skill', 'exp');

DROP PROCEDURE IF EXISTS `ap_drop_column`;
