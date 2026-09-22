-- mod-advanced-professions: роль материала снова двоичная.
--
-- Зачем. Ролей было три: «на основу», «в слот» и «только для сочетаний» -
-- камень без чисел, годный лишь как часть именного набора. Третью владелец
-- отменил 2026-09-07: каждый камень обязан давать числа, и панель это теперь
-- требует - ноль не сохраняется.
--
-- Побочно это закрыло вопрос, который иначе пришлось бы решать: что делать,
-- если ключевой материал попал в несошедшийся эскиз. Ключевых материалов нет,
-- значит несошедшийся эскиз всегда возвращает полезную вещь, и правило «камни
-- всегда что-то дают» становится правилом без исключений.
--
-- Данных это не трогает: строк с ролью 'combo' не было заведено ни одной.
-- Строка, которая всё же попадётся, станет вставкой, и, если стата у неё нет,
-- worldserver скажет об этом при старте отдельной строкой в логе - править её
-- руками в панели.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §2.5, «Роли и два справочника».

DROP PROCEDURE IF EXISTS `ap_role_binary`;
DELIMITER $$
CREATE PROCEDURE `ap_role_binary`()
BEGIN
  -- Смотрим на САМ ТИП колонки, а не на данные: миграция обязана быть
  -- повторяемой, а после сужения ENUM сравнение `role` = 'combo' сравнивало бы
  -- колонку со значением, которого в перечислении больше нет.
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ap_material'
        AND COLUMN_NAME = 'role' AND COLUMN_TYPE LIKE '%combo%') > 0 THEN

    UPDATE `ap_material` SET `role` = 'insert' WHERE `role` = 'combo';

    ALTER TABLE `ap_material`
      MODIFY COLUMN `role` ENUM('base','insert') NOT NULL DEFAULT 'insert'
      COMMENT 'base - в ячейку схемы, insert - в слот доводки со своим статом';
  END IF;
END$$
DELIMITER ;

CALL `ap_role_binary`();
DROP PROCEDURE IF EXISTS `ap_role_binary`;
