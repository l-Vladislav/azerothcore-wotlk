-- mod-advanced-professions: ступень без эскизов не заводится.
--
-- РЕШЕНИЕ ВЛАДЕЛЬЦА (2026-09-14): «нет смысла редкого качества для медного
-- клинка, там нет эскизов - сделай максимальное и минимальное качество по
-- эскизам».
--
-- ЧТО НЕ СХОДИЛОСЬ. Синтез (v32, раздел 3b) достроил каждой полосе все четыре
-- качества, и на низких полосах это дало ступени, которым некуда вести:
-- эскиз - это ванильная именная вещь того же рода, уровня и качества, а
-- эпических мечей одиннадцатого уровня в игре нет. Замер: из 370 ковочных
-- ступеней **104 без единого эскиза** - 7 обычных, 11 отменных, 41 редкая и
-- 45 эпических.
--
-- Для игрока такая ступень - это удачный бросок качества, за которым ничего
-- не стоит: вещь чуть лучше, но доводить её не во что.
--
-- ПРАВИЛО. Границы качества у рецепта задаются эскизами: ступень без эскизов
-- снимается, а `quality_min`/`quality_max` пересчитываются по оставшимся.
-- Отрезок обязан быть непрерывным - бросок качества ходит по нему подряд, -
-- поэтому после сноса оставляем сплошной ряд от нижней уцелевшей ступени.
--
-- И ОДНА ОГОВОРКА СНИЗУ (раздел 2b, 2026-09-15). Правило писалось про верх
-- лестницы, а внизу оно ломало ковку: рецепт, у которого осталась одна
-- ступень, выдаёт её ВСЕГДА - бросок качества прижимается к границам. Поэтому
-- рецепту неэндгеймовой полосы, оставшемуся с единственной ступенью выше
-- зелёной, нижние ступени возвращаются - пустая нижняя ступень и есть
-- неудачный бросок.
--
-- Эскиз принадлежит ступени по ДЛИНЕ НАБОРА: гнёзд у ступени столько же,
-- сколько качество (§2.5), и набор собирается ровно на все гнёзда. Длина
-- считается разбором строки как массива json - дешевле, чем считать запятые.
--
-- Геройских заготовок это не касается: у них одна ступень и один предрешённый
-- эскиз, снимать нечего.
--
-- Прогонять ПОСЛЕ генератора эскизов (v36) - он и решает, где эскизы есть.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §2.12, §2.6.

-- --------------------------------------------------------------------------
-- 1. У каких ступеней есть эскизы
-- --------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `ap_step_sketch`;
CREATE TEMPORARY TABLE `ap_step_sketch` (
  `recipe_id` INT UNSIGNED NOT NULL,
  `quality`   TINYINT UNSIGNED NOT NULL,
  `n`         INT UNSIGNED NOT NULL,
  PRIMARY KEY (`recipe_id`, `quality`)
);

INSERT INTO `ap_step_sketch` (`recipe_id`, `quality`, `n`)
SELECT s.`recipe_id`, JSON_LENGTH(CONCAT('[', s.`pattern`, ']')), COUNT(1)
FROM `ap_synergy` s
JOIN `ap_recipe` r ON r.`id` = s.`recipe_id` AND r.`acquire` = 'forge'
WHERE s.`enabled` = 1 AND s.`pattern` <> ''
GROUP BY s.`recipe_id`, JSON_LENGTH(CONCAT('[', s.`pattern`, ']'));

-- --------------------------------------------------------------------------
-- 2. Что остаётся: сплошной ряд снизу
-- --------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `ap_step_keep`;
CREATE TEMPORARY TABLE `ap_step_keep` (
  `recipe_id` INT UNSIGNED NOT NULL,
  `quality`   TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (`recipe_id`, `quality`)
);

INSERT INTO `ap_step_keep` (`recipe_id`, `quality`)
SELECT `recipe_id`, `quality` FROM (
  SELECT rr.`recipe_id`, rr.`quality`,
         MIN(rr.`quality`) OVER (PARTITION BY rr.`recipe_id`) AS `qmin`,
         ROW_NUMBER() OVER (PARTITION BY rr.`recipe_id`
                            ORDER BY rr.`quality`) AS `rn`
  FROM `ap_recipe_result` rr
  JOIN `ap_recipe` r ON r.`id` = rr.`recipe_id` AND r.`acquire` = 'forge'
  JOIN `ap_step_sketch` k ON k.`recipe_id` = rr.`recipe_id`
                         AND k.`quality` = rr.`quality`
) x
WHERE `quality` - `qmin` + 1 = `rn`;

-- --------------------------------------------------------------------------
-- 2b. Нижняя ступень возвращается: неудачному броску нужно куда падать
-- --------------------------------------------------------------------------
-- РЕШЕНИЕ ВЛАДЕЛЬЦА (2026-09-15). Правило «ступень без эскизов снимается»
-- писалось про ВЕРХ лестницы: эпическая медь - это удачный бросок, за которым
-- ничего не стоит. Внизу оно работает наоборот и ломает саму ковку.
--
-- Бросок качества глобальный (55/30/12/3), но `RollQualityFor` не отбрасывает
-- выпавшее, а ПРИЖИМАЕТ его к границам рецепта. Рецепт, у которого осталась
-- одна ступень, выдаёт её ВСЕГДА - и четыре рецепта оказались гарантированной
-- раздачей редкого и эпического качества за рядовые слитки своей полосы:
--
--     бронзовое копьё   - всегда редкое, ilvl 23, два дешёвых слитка
--     ториевый меч      - всегда редкое, ilvl 60
--     кориевый кинжал   - всегда эпическое, ilvl 136
--     кобальтовое копьё - всегда эпическое, ilvl 154
--
-- Доноры и камни у нижних ступеней при этом ЕСТЬ - их заводит v32. Пропали
-- они не от бедности полосы, а оттого, что соседняя полоса разобрала призы
-- первой: у саронита окно призов ±24 уровня, оно достаёт до титанстали, а
-- приз занимается навсегда и раздаются они по возрастанию номера рецепта.
--
-- Поэтому: ступень без эскизов снимается только СВЕРХУ. Снизу она остаётся -
-- пустая нижняя ступень и есть неудачный бросок. Именной вещи из неё не
-- выйдет, носить и инкрустировать - можно.
--
-- Ниже зелёного не возвращаем: «треснувший титановый клинок» владелец отверг
-- отдельным решением, и в белой клетке верхних полос камень даёт +1 очко на
-- одно гнездо - ступень ради ступени.
--
-- ЭНДГЕЙМОВЫЕ ПОЛОСЫ ИСКЛЮЧЕНЫ (решение владельца 2026-09-15): «слиток
-- титановой стали эндгеймовый предмет, всё нормально если из него только
-- эпики». Титансталь и титан гейтит сам материал, а не бросок качества:
-- слиток титановой стали стоит трёх титановых плюс три извечных, и на одну
-- ковку их уходит от четырёх до шести. (Суточного кулдауна у плавки в 3.3.5a
-- нет - его сняли патчем 3.3.0, в Spell.dbc у 55208 стоят нули.) Порог лежит
-- в `ap_config`, чтобы правило было ОДНО и правилось из панели.
INSERT IGNORE INTO `ap_config` (`name`, `value`, `comment`) VALUES
  ('endgame_band', '11',
   'С какой полосы ap_band ковка считается эндгеймовой: там материал сам себе '
   'гейт, и рецепту позволено иметь одну-единственную ступень качества (v46)');

SELECT CAST(`value` AS UNSIGNED) INTO @endgame
FROM `ap_config` WHERE `name` = 'endgame_band';

-- Полоса рецепта - по уровню его изделий. Берём нижнюю: ступени полосу не
-- покидают, но эпическая стоит в верхней четверти и на границе может уехать.
DROP TEMPORARY TABLE IF EXISTS `ap_step_band`;
CREATE TEMPORARY TABLE `ap_step_band` (
  `recipe_id` INT UNSIGNED PRIMARY KEY,
  `band`      TINYINT UNSIGNED NOT NULL
);

INSERT INTO `ap_step_band` (`recipe_id`, `band`)
SELECT rr.`recipe_id`, MIN(b.`idx`)
FROM `ap_recipe_result` rr
JOIN `ap_recipe` r ON r.`id` = rr.`recipe_id` AND r.`acquire` = 'forge'
JOIN `item_template` it ON it.`entry` = rr.`result_entry`
JOIN `ap_band` b ON it.`ItemLevel` BETWEEN b.`lo` AND b.`hi`
GROUP BY rr.`recipe_id`;

-- Кому возвращать: рецепту неэндгеймовой полосы, у которого после сноса
-- осталась ОДНА ступень, и та выше зелёной.
DROP TEMPORARY TABLE IF EXISTS `ap_step_thin`;
CREATE TEMPORARY TABLE `ap_step_thin` (
  `recipe_id` INT UNSIGNED PRIMARY KEY,
  `qkeep`     TINYINT UNSIGNED NOT NULL
);

INSERT INTO `ap_step_thin` (`recipe_id`, `qkeep`)
SELECT k.`recipe_id`, MIN(k.`quality`)
FROM `ap_step_keep` k
JOIN `ap_step_band` sb ON sb.`recipe_id` = k.`recipe_id`
WHERE sb.`band` < @endgame
GROUP BY k.`recipe_id`
HAVING COUNT(1) = 1 AND MIN(k.`quality`) >= 3;

-- Возвращаются ВСЕ ступени от зелёной до уцелевшей: отрезок обязан остаться
-- сплошным, по нему ходит бросок качества.
INSERT IGNORE INTO `ap_step_keep` (`recipe_id`, `quality`)
SELECT rr.`recipe_id`, rr.`quality`
FROM `ap_recipe_result` rr
JOIN `ap_step_thin` t ON t.`recipe_id` = rr.`recipe_id`
WHERE rr.`quality` >= 2 AND rr.`quality` < t.`qkeep`;

-- --------------------------------------------------------------------------
-- 2c. Рецепт без единого эскиза не пропадает - у него остаётся нижняя ступень
-- --------------------------------------------------------------------------
-- Основа, с которой не выходит ни одной именной вещи, - состояние законное:
-- ковать её можно, носить можно, инкрустировать можно, а дальше дороги нет.
-- Так прямо и сказано в генераторе эскизов, и он о таких основах предупреждает
-- вслух. Но снос ступеней доводил дело до конца: нет эскизов ни на одной
-- ступени - нет ступеней - нет рецепта, и тип пропадал с полосы целиком.
--
-- Стало заметно, когда награды за задания перестали быть призами (2026-09-15):
-- семь рецептов - кориевые клинок, топор и молот, кобальтовые меч и молот,
-- мифриловый кинжал, бронзовое копьё - разом остались ни с чем.
--
-- Поэтому: нет эскизов вовсе - остаётся САМАЯ НИЖНЯЯ ступень. Рецепт живёт,
-- вещь куётся, а незаслуженной высокой ступени не появляется.
DROP TEMPORARY TABLE IF EXISTS `ap_step_barren`;
CREATE TEMPORARY TABLE `ap_step_barren` (
  `recipe_id` INT UNSIGNED PRIMARY KEY,
  `quality`   TINYINT UNSIGNED NOT NULL
);

INSERT INTO `ap_step_barren` (`recipe_id`, `quality`)
SELECT rr.`recipe_id`, MIN(rr.`quality`)
FROM `ap_recipe_result` rr
JOIN `ap_recipe` r ON r.`id` = rr.`recipe_id` AND r.`acquire` = 'forge'
WHERE NOT EXISTS (SELECT 1 FROM `ap_step_keep` k
                  WHERE k.`recipe_id` = rr.`recipe_id`)
GROUP BY rr.`recipe_id`;

INSERT IGNORE INTO `ap_step_keep` (`recipe_id`, `quality`)
SELECT `recipe_id`, `quality` FROM `ap_step_barren`;

-- --------------------------------------------------------------------------
-- 2d. Пол качества у полосы не падает
-- --------------------------------------------------------------------------
-- РАЗБОР 2026-09-17. Границы качества задаются наличием эскизов, то есть тем,
-- какие именные вещи игра завела на этом уровне, - а это не прогрессия. Отсюда
-- откат на полосе Запределья: на ториевой (навык 200) обычная ступень выпадала
-- в 6 % бросков, а на осквернённой (навык 240) - в 55 %, у всех девяти типов
-- разом. Игрок поднимается на полосу выше, приносит материал дороже, и получает
-- белую вещь с одним гнездом там, где полосой ниже брал зелёную с двумя.
--
-- Замер ожидаемой отдачи за успешную ковку: полоса 5 - 7.2 очка статов и
-- камней, полоса 6 - 6.3. Ступень вверх по навыку и вниз по награде.
--
-- ПОЛ СЧИТАЕТСЯ ПО ПОЛОСЕ, А НЕ ПО ТИПУ. Иначе одна клетка тянет за собой всю
-- колонку: у ториевого копья пол стоит на редком качестве (эпических копий
-- 55-64 в игре нет вовсе), и правило «по типу» сделало бы копья редкими от
-- тория до саронита - лучшим оружием системы по одной лишь случайности
-- ассортимента игры. Полосе пол назначает БОЛЬШИНСТВО её типов, то есть
-- медиана; тип, у которого свой пол выше, остаётся при своём.
--
-- Поднимаем, но не опускаем: ступень, которой нет, назад не вернуть - её
-- эскизы уже сняты разделом 2, - да и незачем.
DROP TEMPORARY TABLE IF EXISTS `ap_band_qfloor`;
CREATE TEMPORARY TABLE `ap_band_qfloor` (
  `band`  TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  `qfloor` TINYINT UNSIGNED NOT NULL
);

INSERT INTO `ap_band_qfloor` (`band`, `qfloor`)
SELECT `band`, `qfloor` FROM (
  SELECT `band`, `f` AS `qfloor`,
         ROW_NUMBER() OVER (PARTITION BY `band` ORDER BY `f`) AS `rn`,
         COUNT(*) OVER (PARTITION BY `band`) AS `cnt`
  FROM (
    SELECT sb.`band` AS `band`, MIN(k.`quality`) AS `f`
    FROM `ap_step_keep` k
    JOIN `ap_step_band` sb ON sb.`recipe_id` = k.`recipe_id`
    GROUP BY k.`recipe_id`, sb.`band`
  ) t
) x
WHERE `rn` = FLOOR((`cnt` + 1) / 2);

-- Накопительный максимум: полоса не бывает щедрее на брак, чем пройденные.
DROP TEMPORARY TABLE IF EXISTS `ap_band_qrun`;
CREATE TEMPORARY TABLE `ap_band_qrun` (
  `band`   TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  `qfloor` TINYINT UNSIGNED NOT NULL
);

INSERT INTO `ap_band_qrun` (`band`, `qfloor`)
SELECT `band`,
       MAX(`qfloor`) OVER (ORDER BY `band` ROWS UNBOUNDED PRECEDING)
FROM `ap_band_qfloor`;

-- Ступень ниже пола снимается - но только если рецепту есть чем остаться.
-- Временную таблицу mysql не даёт открыть дважды, отсюда копия.
DROP TEMPORARY TABLE IF EXISTS `ap_step_keep2`;
CREATE TEMPORARY TABLE `ap_step_keep2` AS SELECT * FROM `ap_step_keep`;

DELETE k FROM `ap_step_keep` k
JOIN `ap_step_band` sb ON sb.`recipe_id` = k.`recipe_id`
JOIN `ap_band_qrun` bq ON bq.`band` = sb.`band`
WHERE k.`quality` < bq.`qfloor`
  AND EXISTS (SELECT 1 FROM `ap_step_keep2` k2
              WHERE k2.`recipe_id` = k.`recipe_id`
                AND k2.`quality` >= bq.`qfloor`);

DROP TEMPORARY TABLE IF EXISTS `ap_step_keep2`;
DROP TEMPORARY TABLE IF EXISTS `ap_band_qfloor`;
DROP TEMPORARY TABLE IF EXISTS `ap_band_qrun`;

-- --------------------------------------------------------------------------
-- 3. Снос
-- --------------------------------------------------------------------------
-- Заготовки снятого слайса уходят вместе с ним: они засеяны под эту ступень и
-- больше никому не достанутся (выданные не трогаются - у игрока в сумке лежит
-- вещь с этим номером).
DROP TEMPORARY TABLE IF EXISTS `ap_step_gone`;
CREATE TEMPORARY TABLE `ap_step_gone` (
  `recipe_id` INT UNSIGNED NOT NULL,
  `quality`   TINYINT UNSIGNED NOT NULL,
  `entry`     INT UNSIGNED NOT NULL,
  `pool_lo`   INT UNSIGNED NOT NULL,
  `pool_hi`   INT UNSIGNED NOT NULL,
  PRIMARY KEY (`recipe_id`, `quality`),
  KEY (`entry`)
);

INSERT INTO `ap_step_gone` (`recipe_id`, `quality`, `entry`, `pool_lo`, `pool_hi`)
SELECT rr.`recipe_id`, rr.`quality`, rr.`result_entry`,
       rr.`pool_lo`, rr.`pool_hi`
FROM `ap_recipe_result` rr
JOIN `ap_recipe` r ON r.`id` = rr.`recipe_id` AND r.`acquire` = 'forge'
LEFT JOIN `ap_step_keep` k ON k.`recipe_id` = rr.`recipe_id`
                          AND k.`quality` = rr.`quality`
WHERE k.`recipe_id` IS NULL;

DELETE t FROM `item_template` t
JOIN `ap_step_gone` g ON t.`entry` BETWEEN g.`pool_lo` AND g.`pool_hi`
WHERE NOT EXISTS (SELECT 1 FROM `ap_generated_item` x WHERE x.`entry` = t.`entry`);

DELETE rr FROM `ap_recipe_result` rr
JOIN `ap_step_gone` g ON g.`recipe_id` = rr.`recipe_id`
                     AND g.`quality` = rr.`quality`;

-- Эскизы снятой ступени уходят вместе с ней. Прежде уходили только эскизы
-- рецепта, у которого не осталось НИ ОДНОЙ ступени, - а ступень снимается и по
-- одиночке, правилом непрерывности. Так на PTR остались восемь эскизов под
-- четыре гнезда у рецептов, где выше зелёной ступени ничего нет: книги на них
-- лежат в добыче, игрок их учит, а собрать набор не на чем.
--
-- Принадлежность та же, что и везде: длина набора равна числу гнёзд, а гнёзд
-- столько же, сколько качество (§2.5).
DELETE s FROM `ap_synergy` s
JOIN `ap_recipe` r ON r.`id` = s.`recipe_id` AND r.`acquire` = 'forge'
WHERE s.`pattern` <> ''
  AND NOT EXISTS (SELECT 1 FROM `ap_recipe_result` rr
                  JOIN `item_template` bi ON bi.`entry` = rr.`result_entry`
                  JOIN `ap_quality` q ON q.`quality` = bi.`Quality`
                  WHERE rr.`recipe_id` = s.`recipe_id`
                    AND q.`slots` = JSON_LENGTH(CONCAT('[', s.`pattern`, ']')));

DELETE t FROM `item_template` t
JOIN `ap_step_gone` g ON g.`entry` = t.`entry`
WHERE t.`entry` BETWEEN 181000 AND 182999
  AND NOT EXISTS (SELECT 1 FROM `ap_recipe_result` r2
                  WHERE r2.`result_entry` = t.`entry`)
  AND NOT EXISTS (SELECT 1 FROM `ap_synergy` s WHERE s.`result_entry` = t.`entry`)
  AND NOT EXISTS (SELECT 1 FROM `ap_generated_item` x
                  WHERE x.`source_entry` = t.`entry`);

-- --------------------------------------------------------------------------
-- 4. Границы качества у рецепта - по уцелевшим ступеням
-- --------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `ap_step_range`;
CREATE TEMPORARY TABLE `ap_step_range` (
  `recipe_id` INT UNSIGNED PRIMARY KEY,
  `qmin`      TINYINT UNSIGNED NOT NULL,
  `qmax`      TINYINT UNSIGNED NOT NULL
);

INSERT INTO `ap_step_range` (`recipe_id`, `qmin`, `qmax`)
SELECT `recipe_id`, MIN(`quality`), MAX(`quality`)
FROM `ap_recipe_result` GROUP BY `recipe_id`;

UPDATE `ap_recipe` r
JOIN `ap_step_range` s ON s.`recipe_id` = r.`id`
SET r.`quality_min` = s.`qmin`, r.`quality_max` = s.`qmax`
WHERE r.`acquire` = 'forge';

-- Рецепт, у которого не осталось ни одной ступени, снимается целиком - вместе
-- с набором, чертежом и эскизами: ковать по нему нечего.
DELETE s FROM `ap_synergy` s
WHERE NOT EXISTS (SELECT 1 FROM `ap_recipe_result` rr
                  WHERE rr.`recipe_id` = s.`recipe_id`);

DELETE ri FROM `ap_recipe_item` ri
WHERE NOT EXISTS (SELECT 1 FROM `ap_recipe_result` rr
                  WHERE rr.`recipe_id` = ri.`recipe_id`);

DELETE r FROM `ap_recipe` r
WHERE r.`acquire` = 'forge'
  AND NOT EXISTS (SELECT 1 FROM `ap_recipe_result` rr
                  WHERE rr.`recipe_id` = r.`id`);

-- --------------------------------------------------------------------------
-- 5. Проверки: пустой ответ - сходится
-- --------------------------------------------------------------------------
-- Ступень без эскизов законна только одна: возвращённая нижняя (раздел 2b).
SELECT COUNT(*) INTO @empty
FROM `ap_recipe_result` rr
JOIN `ap_recipe` r ON r.`id` = rr.`recipe_id` AND r.`acquire` = 'forge'
LEFT JOIN `ap_step_sketch` k ON k.`recipe_id` = rr.`recipe_id`
                            AND k.`quality` = rr.`quality`
LEFT JOIN `ap_step_thin` t ON t.`recipe_id` = rr.`recipe_id`
                          AND rr.`quality` < t.`qkeep`
LEFT JOIN `ap_step_barren` z ON z.`recipe_id` = rr.`recipe_id`
                            AND z.`quality` = rr.`quality`
WHERE k.`recipe_id` IS NULL AND t.`recipe_id` IS NULL
  AND z.`recipe_id` IS NULL;

-- И ни одного эскиза, которому некуда лечь.
SELECT COUNT(*) INTO @orphan
FROM `ap_synergy` s
JOIN `ap_recipe` r ON r.`id` = s.`recipe_id` AND r.`acquire` = 'forge'
WHERE s.`pattern` <> ''
  AND NOT EXISTS (SELECT 1 FROM `ap_recipe_result` rr
                  JOIN `item_template` bi ON bi.`entry` = rr.`result_entry`
                  JOIN `ap_quality` q ON q.`quality` = bi.`Quality`
                  WHERE rr.`recipe_id` = s.`recipe_id`
                    AND q.`slots` = JSON_LENGTH(CONCAT('[', s.`pattern`, ']')));

SELECT COUNT(*) INTO @gap
FROM (
  SELECT rr.`recipe_id`
  FROM `ap_recipe_result` rr
  GROUP BY rr.`recipe_id`
  HAVING MAX(rr.`quality`) - MIN(rr.`quality`) + 1 <> COUNT(1)
) z;

SELECT COUNT(*) INTO @range
FROM `ap_recipe` r
JOIN `ap_step_range` s ON s.`recipe_id` = r.`id`
WHERE r.`quality_min` <> s.`qmin` OR r.`quality_max` <> s.`qmax`;

SET @chk := IF(@empty = 0 AND @gap = 0 AND @range = 0 AND @orphan = 0,
               'SELECT ''ступени по эскизам'' AS `проверка`',
               'SELECT 1 FROM `ОШИБКА_ступень_без_эскизов_или_дыра_в_качествах`');
PREPARE `chk` FROM @chk;
EXECUTE `chk`;
DEALLOCATE PREPARE `chk`;

DROP TEMPORARY TABLE IF EXISTS `ap_step_sketch`;
DROP TEMPORARY TABLE IF EXISTS `ap_step_keep`;
DROP TEMPORARY TABLE IF EXISTS `ap_step_gone`;
DROP TEMPORARY TABLE IF EXISTS `ap_step_range`;
DROP TEMPORARY TABLE IF EXISTS `ap_step_band`;
DROP TEMPORARY TABLE IF EXISTS `ap_step_thin`;
DROP TEMPORARY TABLE IF EXISTS `ap_step_barren`;

-- Каталог изменился: аддон держит его в кэше по версии (§7).
UPDATE `ap_config` SET `value` = `value` + 1 WHERE `name` = 'catalog_version';
