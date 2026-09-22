-- mod-advanced-professions: требование по уровню предмета у вставки.
--
-- Разворот 2026-09-02 (DESIGN §2.2) убирает у материала все числа ковки: тир,
-- урон, прочность, прок и его частоту. Взамен вставка получает единственное
-- ограничение - в какой предмет её вообще пускают: большой лунный камень не
-- должен вставляться в медный меч.
--
-- Диапазон, а не один минимум: верхнюю границу владелец ставит по желанию,
-- ноль означает «потолка нет». Так дешёвый камень можно при необходимости
-- запереть на низких вещах, но по умолчанию он никому не мешает.
--
-- ВАЖНО: миграция **только добавляет**. Колонки `tier`, `dmg`, `durability`,
-- `ilvl`, `proc_spell`, `proc_ppm` остаются на месте - их читает уже
-- собранный worldserver (`AdvancedProfessionsMgr.cpp`, загрузка ap_material),
-- и снос сейчас уронил бы модуль на первом же SELECT. Их убирает v14 вместе
-- с остальным легаси (§11, пункт 12).

DROP PROCEDURE IF EXISTS `ap_add_column`;
DELIMITER $$
CREATE PROCEDURE `ap_add_column`(IN tbl VARCHAR(64), IN col VARCHAR(64),
                                 IN spec VARCHAR(255))
BEGIN
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl
        AND COLUMN_NAME = col) = 0 THEN
    SET @s := CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', spec);
    PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

CALL `ap_add_column`('ap_material', 'ilvl_min',
  'SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Вставка требует предмет не ниже этого уровня; 0 = без нижней границы''');
CALL `ap_add_column`('ap_material', 'ilvl_max',
  'SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Вставка не идёт в предмет выше этого уровня; 0 = потолка нет''');

DROP PROCEDURE IF EXISTS `ap_add_column`;

-- Навык больше не растёт от вставки и не упирается в потолок тира: он растёт
-- только за удачную ковку основы (§5.1). Настройка остаётся в таблице до v14,
-- но её значение теперь ни на что не влияет - помечаем это в комментарии,
-- чтобы её не крутили в панели, ожидая эффекта.
UPDATE `ap_config`
   SET `comment` = 'Не используется с 2026-09-02: потолок тира отменён (DESIGN §2.2), колонка уйдёт в v14'
 WHERE `name` = 'tier_ceiling';
