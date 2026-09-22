-- mod-advanced-professions: сетка основ, первый тип - меч.
--
-- Материалы заведены (v29), тестовые заглушки сняты (v30), и теперь у верстака
-- есть всё, кроме главного - вещей, которые он делает. Здесь появляется первая
-- настоящая лестница: девять полос уровня от медной до саронитовой, в каждой до
-- четырёх ступеней качества.
--
-- ОСНОВЫ СОБИРАЮТСЯ КОПИЯМИ (решение владельца 2026-09-13, §2.7). Для каждой
-- клетки «качество x полоса» берётся ванильный меч-донор того же качества и
-- уровня, его строка копируется в блок 180000-184999, меняется только имя.
-- Числа, вид, ножны и гнёзда приезжают от донора сами: они уже прошли
-- балансировку Blizzard для своего уровня, и выдумывать формулу урона не надо.
--
-- ДОНОР В КЛЕТКЕ - МЕДИАНА ПО УРОНУ, а не первый попавшийся: в клетке бывает и
-- два десятка мечей, среди них найдётся и квестовая диковина с урона вдвое выше
-- соседей. Медиана даёт обычный меч своего уровня, а не выброс.
--
-- ИМЯ ГОВОРИТ ПОЛОСУ И СТУПЕНЬ: «Медный клинок», «Отменный медный клинок»,
-- «Превосходный медный клинок», «Безупречный медный клинок». Игрок читает
-- название и знает про вещь всё, не наводя курсор.
--
-- РЕЦЕПТ - НА ПОЛОСУ, а ступени качества внутри него: это ровно та форма,
-- которая уже работает у «Бронзового клинка». Набор - рукоять из дерева, гарда
-- из металла полосы и клинок из него же вдвойне; навершие рецепт не называет,
-- значит оно обязано остаться пустым (§5.4.1).
--
-- Навык растёт полосой: медь с первого, саронит с четырёхсотого.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §2.7.

-- --------------------------------------------------------------------------
-- 0. Повторный прогон: снести прошлый результат целиком
-- --------------------------------------------------------------------------
-- Миграция - ГЕНЕРАТОР, и запускать её будут не раз: правило выбора донора или
-- имена ещё не устоялись. Значит, она обязана начинать с чистого листа, иначе
-- каждый прогон удваивает сетку - что и случилось при первой попытке.
--
-- Сносится ровно её собственный след: рецепты меча, названные «... клинок», всё
-- к ним относящееся и основы, которые она же и создала. Плюс учебный
-- «Бронзовый клинок» 180000-180002 - заглушка, на смену которой эта сетка и
-- пришла.
--
-- Ничего выданного не трогается ни при каких условиях: заготовка, лежащая у
-- игрока в сумке, защищена проверкой по `ap_generated_item` (§4).
DELETE rr FROM `ap_recipe_result` rr
JOIN `ap_recipe` r ON r.`id` = rr.`recipe_id`
WHERE r.`type_id` = 1 AND r.`name_ru` LIKE '%клинок';

DELETE ri FROM `ap_recipe_item` ri
JOIN `ap_recipe` r ON r.`id` = ri.`recipe_id`
WHERE r.`type_id` = 1 AND r.`name_ru` LIKE '%клинок';

DELETE rt FROM `ap_recipe_insert_type` rt
JOIN `ap_recipe` r ON r.`id` = rt.`recipe_id`
WHERE r.`type_id` = 1 AND r.`name_ru` LIKE '%клинок';

DELETE rm FROM `ap_recipe_material` rm
JOIN `ap_recipe` r ON r.`id` = rm.`recipe_id`
WHERE r.`type_id` = 1 AND r.`name_ru` LIKE '%клинок';

DELETE FROM `ap_recipe`
WHERE `type_id` = 1 AND `name_ru` LIKE '%клинок';

-- Основы: свои (имя кончается на «клинок») и учебная тройка. Всё, на что
-- ссылается поделка типа, эскиз или выданная вещь, остаётся жить.
DELETE t FROM `item_template` t
WHERE t.`entry` BETWEEN 180000 AND 184999
  AND (t.`name` LIKE '%клинок' OR t.`entry` BETWEEN 180000 AND 180002)
  AND NOT EXISTS (SELECT 1 FROM `ap_recipe_result` r WHERE r.`result_entry` = t.`entry`)
  AND NOT EXISTS (SELECT 1 FROM `ap_synergy` s WHERE s.`result_entry` = t.`entry`)
  AND NOT EXISTS (SELECT 1 FROM `ap_item_type` y WHERE y.`fail_entry` = t.`entry`)
  AND NOT EXISTS (SELECT 1 FROM `ap_generated_item` g WHERE g.`source_entry` = t.`entry`);

-- И заготовки, чей слайс больше никому не принадлежит: каждый прогон нарезает
-- слайсы заново, и без этой уборки прошлые оставались бы в памяти сервера
-- мёртвым грузом.
DELETE t FROM `item_template` t
WHERE t.`entry` BETWEEN 1100000 AND 3199999
  AND NOT EXISTS (SELECT 1 FROM `ap_recipe_result` r
                  WHERE t.`entry` BETWEEN r.`pool_lo` AND r.`pool_hi`)
  AND NOT EXISTS (SELECT 1 FROM `ap_generated_item` g WHERE g.`entry` = t.`entry`);

-- --------------------------------------------------------------------------
-- 1. Полосы уровня
-- --------------------------------------------------------------------------
-- Дерево на верстаке всего двух родов, поэтому простая древесина служит нижним
-- полосам, звёздное дерево - верхним. Металл у каждой полосы свой.
DROP TEMPORARY TABLE IF EXISTS `ap_band`;
CREATE TEMPORARY TABLE `ap_band` (
  `idx`   TINYINT UNSIGNED PRIMARY KEY,
  `lo`    SMALLINT UNSIGNED NOT NULL,
  `hi`    SMALLINT UNSIGNED NOT NULL,
  `adj`   VARCHAR(32) NOT NULL,
  `metal` INT UNSIGNED NOT NULL,
  `wood`  INT UNSIGNED NOT NULL,
  `skill` SMALLINT UNSIGNED NOT NULL
);

INSERT INTO `ap_band` VALUES
  (0,  1,  9,  'Медный',        2840,  4470,   1),
  (1, 10, 19,  'Бронзовый',     2841,  4470,  50),
  (2, 20, 29,  'Железный',      3575,  4470, 100),
  (3, 30, 39,  'Стальной',      3859,  4470, 150),
  (4, 40, 49,  'Мифриловый',    3860, 11291, 200),
  (5, 50, 59,  'Ториевый',     12359, 11291, 250),
  (6, 60, 69,  'Адамантитовый',23446, 11291, 300),
  (7, 70, 79,  'Кобальтовый',  36916, 11291, 350),
  (8, 80, 85,  'Саронитовый',  36913, 11291, 400);

-- --------------------------------------------------------------------------
-- 2. Доноры: по одному на клетку
-- --------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `ap_cell`;
CREATE TEMPORARY TABLE `ap_cell` (
  `band`  TINYINT UNSIGNED NOT NULL,
  `q`     TINYINT UNSIGNED NOT NULL,
  `donor` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`band`, `q`)
);

INSERT INTO `ap_cell` (`band`, `q`, `donor`)
SELECT `band`, `q`, `donor` FROM (
  SELECT b.`idx` AS `band`, it.`Quality` AS `q`, it.`entry` AS `donor`,
         ROW_NUMBER() OVER (PARTITION BY b.`idx`, it.`Quality`
                            ORDER BY it.`dmg_min1` + it.`dmg_max1`, it.`entry`) AS `rn`,
         COUNT(*) OVER (PARTITION BY b.`idx`, it.`Quality`) AS `cnt`
  FROM `ap_band` b
  JOIN `item_template` it
    ON it.`class` = 2 AND it.`subclass` = 7
   AND it.`ItemLevel` BETWEEN b.`lo` AND b.`hi`
  WHERE it.`entry` < 100000
    AND it.`Quality` BETWEEN 1 AND 4
    AND it.`name` <> ''
    AND it.`dmg_max1` > 0
    AND it.`name` NOT LIKE '%Deprecated%'
    AND it.`name` NOT LIKE '%Monster%'
    AND it.`name` NOT LIKE '[PH]%'
    AND it.`name` NOT LIKE '%TEST%'
    AND it.`name` NOT LIKE '%QA%'
) x
WHERE `rn` = FLOOR((`cnt` + 1) / 2);

-- Дыры внутри полосы добираем из соседних уровней. У кобальтовой полосы
-- (70-79) нет ни зелёного меча, ни синего - их первые появляются на 80-м, - а
-- ступени 1 и 4 при этом есть. Бросок качества прижимается к границам рецепта и
-- честно упёрся бы в «нет изделия на эту ступень»: отказ на ровном месте.
--
-- Добираем только ВНУТРЕННИЕ пробелы: между худшей и лучшей ступенью полосы.
-- Придумывать эпик там, где полоса его не знает, никто не просит.
-- Границы ступеней полосы выносим в свою таблицу: `ap_cell` в следующем
-- запросе стоит получателем, а MySQL не даёт открыть временную таблицу в одном
-- запросе дважды.
DROP TEMPORARY TABLE IF EXISTS `ap_span`;
CREATE TEMPORARY TABLE `ap_span` AS
SELECT `band`, MIN(`q`) AS `qmin`, MAX(`q`) AS `qmax`
FROM `ap_cell` GROUP BY `band`;

INSERT IGNORE INTO `ap_cell` (`band`, `q`, `donor`)
SELECT `band`, `q`, `donor` FROM (
  SELECT b.`idx` AS `band`, it.`Quality` AS `q`, it.`entry` AS `donor`,
         ROW_NUMBER() OVER (PARTITION BY b.`idx`, it.`Quality`
                            ORDER BY it.`dmg_min1` + it.`dmg_max1`, it.`entry`) AS `rn`,
         COUNT(*) OVER (PARTITION BY b.`idx`, it.`Quality`) AS `cnt`
  FROM (SELECT b2.`idx`, b2.`lo`, b2.`hi`, s.`qmin`, s.`qmax`
        FROM `ap_band` b2
        JOIN `ap_span` s ON s.`band` = b2.`idx`) b
  JOIN `item_template` it
    ON it.`class` = 2 AND it.`subclass` = 7
   AND it.`ItemLevel` BETWEEN GREATEST(1, CAST(b.`lo` AS SIGNED) - 15)
                          AND b.`hi` + 15
   AND it.`Quality` BETWEEN b.`qmin` AND b.`qmax`
  WHERE it.`entry` < 100000
    AND it.`name` <> ''
    AND it.`dmg_max1` > 0
    AND it.`name` NOT LIKE '%Deprecated%'
    AND it.`name` NOT LIKE '%Monster%'
    AND it.`name` NOT LIKE '[PH]%'
    AND it.`name` NOT LIKE '%TEST%'
    AND it.`name` NOT LIKE '%QA%'
) x
WHERE `rn` = FLOOR((`cnt` + 1) / 2);

-- --------------------------------------------------------------------------
-- 3. Новые основы: номера и имена
-- --------------------------------------------------------------------------
SELECT COALESCE(MAX(`entry`), 180000) + 1 INTO @base_next
FROM `item_template` WHERE `entry` BETWEEN 180000 AND 184999;

DROP TEMPORARY TABLE IF EXISTS `ap_grid`;
CREATE TEMPORARY TABLE `ap_grid` (
  `band`      TINYINT UNSIGNED NOT NULL,
  `q`         TINYINT UNSIGNED NOT NULL,
  `donor`     INT UNSIGNED NOT NULL,
  `new_entry` INT UNSIGNED NOT NULL,
  `name`      VARCHAR(255) NOT NULL,
  PRIMARY KEY (`band`, `q`),
  UNIQUE KEY (`new_entry`),
  KEY (`donor`)
);

INSERT INTO `ap_grid` (`band`, `q`, `donor`, `new_entry`, `name`)
SELECT c.`band`, c.`q`, c.`donor`,
       @base_next + ROW_NUMBER() OVER (ORDER BY c.`band`, c.`q`) - 1,
       CONCAT(
         CASE c.`q` WHEN 2 THEN 'Отменный '
                    WHEN 3 THEN 'Превосходный '
                    WHEN 4 THEN 'Безупречный '
                    ELSE '' END,
         CASE c.`q` WHEN 1 THEN b.`adj` ELSE LOWER(b.`adj`) END,
         ' клинок')
FROM `ap_cell` c
JOIN `ap_band` b ON b.`idx` = c.`band`;

-- Копия строки донора целиком, а не перечисление полутора сотен колонок:
-- перечисление однажды разойдётся со схемой ядра, а `SELECT *` из той же
-- таблицы - никогда.
-- Не `LIKE item_template`: у неё полнотекстовый индекс по имени, а временная
-- таблица InnoDB такого не держит. `AS SELECT` копирует колонки без индексов -
-- ровно то, что нужно.
DROP TEMPORARY TABLE IF EXISTS `ap_copy`;
CREATE TEMPORARY TABLE `ap_copy` AS
SELECT * FROM `item_template`
WHERE `entry` IN (SELECT `donor` FROM `ap_grid`);

UPDATE `ap_copy` c
JOIN `ap_grid` g ON g.`donor` = c.`entry`
SET c.`entry` = g.`new_entry`,
    c.`name`  = g.`name`,
    -- Случайные суффиксы («Меч Медведя») основе ни к чему: её числа и так
    -- достанутся копии из пула, а суффикс сделал бы каждую выдачу разной.
    c.`RandomProperty` = 0,
    c.`RandomSuffix`   = 0,
    -- Изделие верстака свободно торгуется (§1): привязка донора тут не к месту.
    c.`bonding` = 0,
    -- Чужие скрипты и квесты вместе со строкой не переезжают.
    c.`startquest` = 0,
    c.`ScriptName` = '',
    c.`spellid_1` = 0, c.`spellid_2` = 0;

INSERT IGNORE INTO `item_template` SELECT * FROM `ap_copy`;

-- --------------------------------------------------------------------------
-- 4. Рецепты: по одному на полосу
-- --------------------------------------------------------------------------
SELECT COALESCE(MAX(`id`), 0) INTO @rid FROM `ap_recipe`;

DROP TEMPORARY TABLE IF EXISTS `ap_rec`;
CREATE TEMPORARY TABLE `ap_rec` (
  `band`      TINYINT UNSIGNED PRIMARY KEY,
  `recipe_id` INT UNSIGNED NOT NULL,
  `qmin`      TINYINT UNSIGNED NOT NULL,
  `qmax`      TINYINT UNSIGNED NOT NULL
);

-- Границы качества считаем здесь же: временную таблицу MySQL не позволяет
-- открыть дважды в одном запросе, а два подзапроса к `ap_grid` - ровно это.
INSERT INTO `ap_rec` (`band`, `recipe_id`, `qmin`, `qmax`)
SELECT `band`, @rid + ROW_NUMBER() OVER (ORDER BY `band`), `qmin`, `qmax`
FROM (SELECT `band`, MIN(`q`) AS `qmin`, MAX(`q`) AS `qmax`
      FROM `ap_grid` GROUP BY `band`) b;

INSERT INTO `ap_recipe`
  (`id`, `type_id`, `name_ru`, `req_skill`, `teach_item`,
   `quality_min`, `quality_max`, `enabled`, `acquire`)
SELECT r.`recipe_id`, 1, CONCAT(b.`adj`, ' клинок'), b.`skill`, 0,
       r.`qmin`, r.`qmax`, 1, 'forge'
FROM `ap_rec` r
JOIN `ap_band` b ON b.`idx` = r.`band`;

-- Набор: рукоять, гарда, клинок. Навершие (ячейка 1) рецептом не названо -
-- значит, обязано остаться пустым.
-- Три отдельных запроса, а не один с UNION: временную таблицу MySQL не даёт
-- открыть в одном запросе дважды, а тут её пришлось бы открыть трижды.
INSERT INTO `ap_recipe_item` (`recipe_id`, `part_idx`, `item_entry`, `count`)
SELECT r.`recipe_id`, 2, b.`wood`, 1
FROM `ap_rec` r JOIN `ap_band` b ON b.`idx` = r.`band`;

INSERT INTO `ap_recipe_item` (`recipe_id`, `part_idx`, `item_entry`, `count`)
SELECT r.`recipe_id`, 3, b.`metal`, 1
FROM `ap_rec` r JOIN `ap_band` b ON b.`idx` = r.`band`;

INSERT INTO `ap_recipe_item` (`recipe_id`, `part_idx`, `item_entry`, `count`)
SELECT r.`recipe_id`, 4, b.`metal`, 2
FROM `ap_rec` r JOIN `ap_band` b ON b.`idx` = r.`band`;

INSERT INTO `ap_recipe_result`
  (`recipe_id`, `quality`, `result_entry`, `pool_lo`, `pool_hi`)
SELECT r.`recipe_id`, g.`q`, g.`new_entry`, 0, 0
FROM `ap_grid` g
JOIN `ap_rec` r ON r.`band` = g.`band`;

-- --------------------------------------------------------------------------
-- 5. Слайсы пула и заготовки
-- --------------------------------------------------------------------------
-- Тот же порядок, что в v25: слайс получает только тот, у кого его ещё нет, и
-- начинается он с первого свободного места - чужие границы не сдвигаются.
SET @stride := 2048;
SET @seed   := 256;
SET @endcap := 3199999;

SELECT COALESCE(MAX(`pool_lo`) + @stride, 1100000) INTO @next
FROM `ap_recipe_result` WHERE `pool_lo` > 0;

UPDATE `ap_recipe_result` r
JOIN (
  SELECT `recipe_id`, `quality`,
         ROW_NUMBER() OVER (ORDER BY `recipe_id`, `quality`) AS `rn`
  FROM `ap_recipe_result`
  WHERE `pool_lo` = 0 AND `result_entry` > 0
) q ON q.`recipe_id` = r.`recipe_id` AND q.`quality` = r.`quality`
SET r.`pool_lo` = @next + (q.`rn` - 1) * @stride,
    r.`pool_hi` = @next + (q.`rn` - 1) * @stride + @stride - 1
WHERE @next + (q.`rn` - 1) * @stride + @stride - 1 <= @endcap;

DROP TEMPORARY TABLE IF EXISTS `ap_slice`;
CREATE TEMPORARY TABLE `ap_slice` (
  `lo`       INT UNSIGNED PRIMARY KEY,
  `class`    TINYINT UNSIGNED NOT NULL,
  `subclass` TINYINT UNSIGNED NOT NULL,
  `sound`    INT NOT NULL,
  `invtype`  TINYINT UNSIGNED NOT NULL,
  `material` TINYINT NOT NULL,
  `sheath`   TINYINT UNSIGNED NOT NULL,
  `display`  INT UNSIGNED NOT NULL
);

-- Только свежие слайсы: у «Бронзового клинка» заготовки уже засеяны.
INSERT INTO `ap_slice`
SELECT r.`pool_lo`, b.`class`, b.`subclass`, b.`SoundOverrideSubclass`,
       b.`InventoryType`, b.`Material`, b.`Sheath`, b.`displayid`
FROM `ap_recipe_result` r
JOIN `item_template` b ON b.`entry` = r.`result_entry`
WHERE r.`pool_lo` >= @next;

SET SESSION cte_max_recursion_depth = 1000;

DROP TEMPORARY TABLE IF EXISTS `ap_seq`;
CREATE TEMPORARY TABLE `ap_seq` (`n` INT UNSIGNED PRIMARY KEY);
INSERT INTO `ap_seq`
WITH RECURSIVE `seq` (`n`) AS (
  SELECT 0 UNION ALL SELECT `n` + 1 FROM `seq` WHERE `n` < @seed - 1
)
SELECT `n` FROM `seq`;

-- Заготовки помечены ITEM_FLAG_DEPRECATED (0x10): попади такая строка игроку до
-- выдачи, она будет мусором в сумке, а не работающим предметом. При выдаче
-- модуль копирует основу целиком, вместе с её флагами.
INSERT IGNORE INTO `item_template`
  (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`,
   `Quality`, `Flags`, `InventoryType`, `Stackable`, `MaxCount`, `Material`,
   `Sheath`)
SELECT s.`lo` + q.`n`, s.`class`, s.`subclass`, s.`sound`,
       CONCAT('[заготовка верстака ', s.`lo` + q.`n`, ']'),
       s.`display`, 0, 16, s.`invtype`, 1, 0, s.`material`, s.`sheath`
FROM `ap_slice` s
JOIN `ap_seq` q;

DROP TEMPORARY TABLE IF EXISTS `ap_slice`;
DROP TEMPORARY TABLE IF EXISTS `ap_seq`;
DROP TEMPORARY TABLE IF EXISTS `ap_copy`;
DROP TEMPORARY TABLE IF EXISTS `ap_grid`;
DROP TEMPORARY TABLE IF EXISTS `ap_cell`;
DROP TEMPORARY TABLE IF EXISTS `ap_span`;
DROP TEMPORARY TABLE IF EXISTS `ap_rec`;
DROP TEMPORARY TABLE IF EXISTS `ap_band`;

-- --------------------------------------------------------------------------
-- 6. Эскиз - к новой бронзовой основе
-- --------------------------------------------------------------------------
-- «Клык Тьмы» был привязан к учебному рецепту, которого больше нет. Его место
-- занимает бронзовая полоса сетки: две вставки в зелёную основу по-прежнему
-- дают синий Shadowfang. Привязка идёт по ИМЕНИ - номера рецептов каждый
-- прогон новые.
UPDATE `ap_synergy` s
JOIN `ap_recipe` r ON r.`type_id` = 1 AND r.`name_ru` = 'Бронзовый клинок'
SET s.`recipe_id` = r.`id`
WHERE s.`result_entry` > 0;

-- Каталог вырос на девять рецептов: аддон держит его в кэше и без этой строки
-- покажет старый список (§7, «Кэш каталога»).
UPDATE `ap_config` SET `value` = `value` + 1 WHERE `name` = 'catalog_version';
