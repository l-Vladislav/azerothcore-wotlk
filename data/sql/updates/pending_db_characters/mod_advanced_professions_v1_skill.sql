-- mod-advanced-professions: навык «Мастерство верстака».
--
-- Своя профессия, не ванильная: слот профессии не занимает, в окне умений
-- клиента не видна, показывается только в аддоне. Поэтому и хранится здесь, а
-- не в character_skills.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §5.1

CREATE TABLE IF NOT EXISTS `ap_character_skill` (
  `guid`    INT UNSIGNED      NOT NULL COMMENT 'characters.guid',
  `skill`   SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  `exp`     INT UNSIGNED      NOT NULL DEFAULT 0 COMMENT 'опыт внутри текущего уровня навыка',
  `crafted` INT UNSIGNED      NOT NULL DEFAULT 0 COMMENT 'сколько всего собрано предметов',
  `updated` TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
