-- mod-advanced-professions: пул нарезан по типам предметов.
--
-- Зачем. Доведённая копия занимает id из пула, а клиент берёт из своего
-- `Item.dbc` трёхмерный вид вещи, ножны и материал (иконку и тултип он
-- спрашивает у сервера). Строки для блока пула в клиентской DBC не было вовсе,
-- и вещь приезжала игроку без вида - знаком вопроса.
--
-- Строку дать можно, но она СТАТИЧНА, а один и тот же id со временем изображает
-- разные основы. Отсюда решение владельца 2026-09-05: **пул делится на слайсы
-- по типу предмета**, и строки DBC каждого слайса несут вид своего типа. Меч,
-- собранный на любом id меча, выглядит мечом; щит - щитом.
--
-- Точный вид конкретной основы (бронзовый клинок против стального) слайс не
-- обещает: это стоило бы слайса на каждое изделие и пересборки клиентского
-- патча при заведении каждого рецепта. Род оружия важнее оттенка модели -
-- иконку, имя и числа всё равно присылает сервер, и они точные.
--
-- Новый блок: **1 100 000 - 1 199 999**, сразу за блоком оружия mod-worn-drops
-- (тот держит 1 000 000 - 1 099 999) и выше самого большого id в базе. Десять
-- типов по 10 000 - сто тысяч заготовок.
--
-- Чего это стоит: сто тысяч строк `item_template` живут в памяти worldserver
-- на каждом старте (порядок величины - сотня мегабайт) и столько же строк
-- уезжает в `Item.dbc` внутри MPQ. Для этой сборки цена привычная: у
-- mod-worn-drops таких строк 217 тысяч. Размер слайса стоит одним числом ниже -
-- если сто тысяч окажется много, поменяйте @size и перезасейте.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §4, §2.4.

-- --------------------------------------------------------------------------
-- 1. Границы слайса у типа
-- --------------------------------------------------------------------------
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

CALL `ap_add_column`('ap_item_type', 'pool_lo',
  'INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Начало слайса пула: заготовки item_template с видом этого типа''');
CALL `ap_add_column`('ap_item_type', 'pool_hi',
  'INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''Конец слайса пула включительно. 0 в паре с pool_lo - слайса нет, доводка этому типу недоступна''');

DROP PROCEDURE IF EXISTS `ap_add_column`;

-- --------------------------------------------------------------------------
-- 2. Раздача слайсов
-- --------------------------------------------------------------------------
-- Раздаём только тем, у кого слайса ещё нет, и начинаем с первого свободного
-- места. Так миграция идемпотентна, а тип, заведённый через полгода, получит
-- своё продолжение блока, а не сдвинет чужие границы: сдвиг переназначил бы
-- уже выданные игрокам id другому типу.
SET @size := 10000;
SET @start := 1100000;
SELECT COALESCE(MAX(`pool_hi`) + 1, @start) INTO @next
FROM `ap_item_type` WHERE `pool_hi` > 0;

UPDATE `ap_item_type` t
JOIN (
  SELECT `id`, ROW_NUMBER() OVER (ORDER BY `id`) AS `rn`
  FROM `ap_item_type` WHERE `pool_lo` = 0
) r ON r.`id` = t.`id`
SET t.`pool_lo` = @next + (r.`rn` - 1) * @size,
    t.`pool_hi` = @next + (r.`rn` - 1) * @size + @size - 1;

-- --------------------------------------------------------------------------
-- 3. Клиентская половина слайса
-- --------------------------------------------------------------------------
-- Вид, ножны, материал и подкласс звука берём у ДОНОРА - существующего
-- предмета с тем же `displayid`, что задан типу в панели. Так строка DBC
-- слайса совпадает с тем, как клиент уже умеет носить такую вещь; выдумывать
-- эти числа руками значит однажды получить меч, висящий на спине как посох.
DROP TEMPORARY TABLE IF EXISTS `ap_slice`;
CREATE TEMPORARY TABLE `ap_slice` (
  `type_id`  INT UNSIGNED PRIMARY KEY,
  `lo`       INT UNSIGNED NOT NULL,
  `hi`       INT UNSIGNED NOT NULL,
  `class`    TINYINT UNSIGNED NOT NULL,
  `subclass` TINYINT UNSIGNED NOT NULL,
  `sound`    INT NOT NULL,
  `invtype`  TINYINT UNSIGNED NOT NULL,
  `material` TINYINT NOT NULL,
  `sheath`   TINYINT UNSIGNED NOT NULL,
  `display`  INT UNSIGNED NOT NULL
);

INSERT INTO `ap_slice`
SELECT t.`id`, t.`pool_lo`, t.`pool_hi`, t.`item_class`, t.`item_subclass`,
       COALESCE(d.`SoundOverrideSubclass`, -1),
       -- Донора нет (вид заведён своим, custom): слот считаем по подклассу -
       -- двуручное и щит носят иначе, чем одноручное.
       COALESCE(d.`InventoryType`,
                CASE WHEN t.`item_class` = 4 THEN 14
                     WHEN t.`item_subclass` IN (1, 5, 6, 8) THEN 17
                     ELSE 21 END),
       COALESCE(d.`Material`, 1),
       COALESCE(d.`Sheath`,
                CASE WHEN t.`item_class` = 4 THEN 4
                     WHEN t.`item_subclass` IN (1, 5, 6, 8) THEN 1
                     ELSE 3 END),
       t.`displayid`
FROM `ap_item_type` t
LEFT JOIN `item_template` d
  ON d.`entry` = (SELECT x.`entry` FROM `item_template` x
                  WHERE x.`displayid` = t.`displayid`
                    AND x.`class` = t.`item_class`
                  ORDER BY x.`entry` LIMIT 1)
WHERE t.`pool_lo` > 0;

-- --------------------------------------------------------------------------
-- 4. Сами заготовки
-- --------------------------------------------------------------------------
-- Заготовки помечены ITEM_FLAG_DEPRECATED (0x10) - «нельзя надеть и нельзя
-- использовать»: попади такая строка игроку до выдачи, она будет мусором в
-- сумке, а не работающим предметом. При выдаче модуль флаг снимает вместе со
-- всей строкой - он копирует изделие целиком.
SET SESSION cte_max_recursion_depth = 100000;

INSERT IGNORE INTO `item_template`
  (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`,
   `Quality`, `Flags`, `InventoryType`, `Stackable`, `MaxCount`, `Material`,
   `Sheath`)
WITH RECURSIVE `seq` (`n`) AS (
  SELECT 0
  UNION ALL
  SELECT `n` + 1 FROM `seq` WHERE `n` < @size - 1
)
SELECT s.`lo` + q.`n`, s.`class`, s.`subclass`, s.`sound`,
       CONCAT('[заготовка верстака ', s.`lo` + q.`n`, ']'),
       s.`display`, 0, 16, s.`invtype`, 1, 0, s.`material`, s.`sheath`
FROM `ap_slice` s
JOIN `seq` q ON s.`lo` + q.`n` <= s.`hi`;

DROP TEMPORARY TABLE IF EXISTS `ap_slice`;

-- --------------------------------------------------------------------------
-- 5. Старый общий пул уходит
-- --------------------------------------------------------------------------
-- Заготовки 130000-134999 никому не выданы: `ap_generated_item` пуста с тех
-- пор, как v15 пересоздала её (проверено 2026-09-05), а значит ни одной такой
-- вещи нет ни в сумках, ни в почте, ни на аукционе. Удаляем - иначе пять тысяч
-- строк так и будут занимать память на каждом старте.
--
-- Условие DELETE намеренно смотрит в `ap_generated_item`: если строки там
-- всё-таки появятся, удаление не тронет НИЧЕГО. Лучше оставить мусор, чем
-- превратить чужую вещь в «предмет не существует».
DELETE FROM `item_template`
WHERE `entry` BETWEEN 130000 AND 134999
  AND NOT EXISTS (SELECT 1 FROM `ap_generated_item`);

DELETE FROM `ap_config` WHERE `name` IN ('pool_lo', 'pool_hi')
  AND NOT EXISTS (SELECT 1 FROM `ap_generated_item`);
