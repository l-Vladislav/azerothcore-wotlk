-- mod-advanced-professions: лестница материалов.
--
-- До сих пор в `ap_material` жили двенадцать строк - ровно столько, сколько
-- нужно было, чтобы проверить механику. Играть в это нельзя: на верстаке
-- выбирать не из чего, а доводка упирается в четыре камня.
--
-- Здесь заводится настоящий набор, и заводится он ЗАПРОСОМ по item_template, а
-- не списком: правило видно целиком, повторить его можно на любой базе, и
-- потеряться в одной строке из восьмисот негде.
--
-- ЧТО СЧИТАЕТСЯ ВСТАВКОЙ (решение владельца 2026-09-13). Самоцветов ниже 55-го
-- уровня в игре почти нет: огранённые все из BC и Лича (60-80), простых два
-- десятка и все зелёные, белых четырнадцать и те на 55-м. Чистая лестница «по
-- цвету камня» на низких уровнях не строится - нечем. Поэтому вставкой
-- считаются три семейства сразу:
--
--   самоцветы    - огранённые и простые, стат по цвету;
--   реагенты чар - пыль, эссенции, осколки: ровная лесенка 5-80 по качествам;
--   стихии       - земля, огонь, вода, воздух: 25-75.
--
-- Тематически это и честнее: в основу вкладывают не только самоцвет, но и
-- пыль, эссенцию, осколок стихии. Доводка становится насыщением, а не
-- ювелиркой.
--
-- КАЧЕСТВО РАЗБИВАЕТ НАБОР. Границы у всех новых строк нулевые, а ноль здесь -
-- это не «пускай куда угодно», а СТРОГОЕ СОВПАДЕНИЕ: камень идёт только в вещь
-- своего качества (§2.5, миграция v22). Это единственный рычаг, который держит
-- число эскизов в рамках: слоты растут с качеством, а эскизы - степенью от
-- слотов. Прежние двенадцать строк с окном 1-2 остаются как есть: INSERT
-- IGNORE их не трогает, и владелец правит их в панели, если захочет.
--
-- ПОЛОСА УРОВНЯ берётся от собственного уровня материала с нахлёстом:
-- ilvl_min = уровень - 10, ilvl_max = уровень + 15. Нахлёст намеренный - так у
-- каждой полосы цели набирается несколько кандидатов, а не ровно один. Уровень
-- тоже приводится к знаковому типу: у камня пятого уровня «минус десять» без
-- этого уходит в переполнение.
-- Сверяются эти границы с уровнем ЦЕЛИ, а не камня (§2.5).
--
-- СТАТ ПО ЦВЕТУ, и цвета те же, что владелец задал в MVP: зелёный - ловкость,
-- жёлтый - сила, фиолетовый - интеллект, голубой - выносливость. Огранённые
-- самоцветы дают цвет подклассом, простые - именем, реагенты и стихии - родом.
--
-- ВЕЛИЧИНА СТАТА растёт с уровнем и качеством: восьмая доля уровня плюс две
-- единицы за каждую ступень выше зелёной. Качество приводится к знаковому
-- типу: оно UNSIGNED, и у белой вещи «качество минус два» ушло бы в
-- переполнение, а не в минус единицу.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §2.5, §5.7.

-- --- справочники -----------------------------------------------------------
-- Родов вставки было два, а семейств теперь пять: рецепт отбирает вставки
-- именно по роду (v23), и без своих строк пыль с эссенцией попали бы в один
-- мешок с самоцветом.
INSERT IGNORE INTO `ap_insert_type` (`id`, `code`, `name_ru`) VALUES
  (3, 'dust',      'Пыль'),
  (4, 'essence',   'Эссенция'),
  (5, 'shard',     'Осколок'),
  (6, 'elemental', 'Стихия');

-- Камень как часть чертежа: точильные камни и грубые самоцветы кладут в
-- ячейку, а не в гнездо.
INSERT IGNORE INTO `ap_part_kind` (`id`, `code`, `name_ru`) VALUES
  (6, 'stone', 'Камень');

-- --- роль base: что кладут в ячейки чертежа --------------------------------
-- Ткань, кожа, металл с камнем, травы. Качество и уровень для этой роли не
-- проверяются вовсе - ячейка спрашивает только род (§5.4.1), - поэтому границы
-- остаются нулевыми.
INSERT IGNORE INTO `ap_material`
  (`entry`, `role`, `kind`, `part_kind_id`, `insert_type_id`,
   `stat_type`, `stat_value`, `ilvl_min`, `ilvl_max`,
   `quality_min`, `quality_max`, `enabled`)
SELECT it.`entry`, 'base',
       CASE it.`subclass`
            WHEN 5 THEN 'cloth'
            WHEN 6 THEN 'leather'
            WHEN 9 THEN 'other'
            ELSE CASE WHEN it.`name` LIKE '%Wood%' OR it.`name` LIKE '%Lumber%'
                      THEN 'wood'
                      WHEN it.`name` LIKE '%Stone%' OR it.`name` LIKE '%Flint%'
                      THEN 'stone'
                      ELSE 'metal' END
       END,
       CASE it.`subclass`
            WHEN 5 THEN 4        -- ткань
            WHEN 6 THEN 3        -- кожа
            WHEN 9 THEN 5        -- прочее: травы, смолы
            ELSE CASE WHEN it.`name` LIKE '%Wood%' OR it.`name` LIKE '%Lumber%'
                      THEN 2     -- дерево
                      WHEN it.`name` LIKE '%Stone%' OR it.`name` LIKE '%Flint%'
                      THEN 6     -- камень
                      ELSE 1 END -- металл
       END,
       0, 0, 0, 0, 0, 0, 0, 1
FROM `item_template` it
WHERE it.`class` = 7
  AND it.`subclass` IN (5, 6, 7, 9, 11)
  AND it.`entry` < 100000
  AND it.`Quality` BETWEEN 1 AND 4
  AND it.`name` <> ''
  AND it.`name` NOT LIKE '%Deprecated%'
  AND it.`name` NOT LIKE '[PH]%'
  AND it.`name` NOT LIKE '%TEST%'
  AND it.`name` NOT LIKE '%Monster%'
  AND it.`name` NOT LIKE '%Unused%'
  -- Подкласс 11 - общая свалка игры (пергамент, мёд, ядовитые железы), оттуда
  -- берём только дерево: остальное на верстаке ни к чему.
  AND (it.`subclass` <> 11
       OR it.`name` LIKE '%Wood%' OR it.`name` LIKE '%Lumber%');

-- --- роль insert: огранённые самоцветы -------------------------------------
-- Цвет знает подкласс: 0 красный, 1 синий, 2 жёлтый, 3 фиолетовый, 4 зелёный,
-- 5 оранжевый, 6 мета, 8 радужный.
INSERT IGNORE INTO `ap_material`
  (`entry`, `role`, `kind`, `part_kind_id`, `insert_type_id`,
   `stat_type`, `stat_value`, `ilvl_min`, `ilvl_max`,
   `quality_min`, `quality_max`, `enabled`)
SELECT it.`entry`, 'insert', 'gem', 0, 1,
       CASE it.`subclass`
            WHEN 0 THEN 4        -- красный    - сила
            WHEN 1 THEN 7        -- синий      - выносливость
            WHEN 2 THEN 3        -- жёлтый     - ловкость
            WHEN 3 THEN 5        -- фиолетовый - интеллект
            WHEN 4 THEN 6        -- зелёный    - дух
            WHEN 5 THEN 32       -- оранжевый  - критический удар
            WHEN 6 THEN 38       -- мета       - сила атаки
            ELSE 45              -- радужный   - сила заклинаний
       END,
       GREATEST(2, ROUND(it.`ItemLevel` / 8)) + (CAST(it.`Quality` AS SIGNED) - 2) * 2,
       GREATEST(0, CAST(it.`ItemLevel` AS SIGNED) - 10), it.`ItemLevel` + 15,
       0, 0, 1
FROM `item_template` it
WHERE it.`class` = 3
  AND it.`subclass` <> 7
  AND it.`entry` < 100000
  AND it.`Quality` BETWEEN 1 AND 4
  AND it.`ItemLevel` > 0
  AND it.`name` <> ''
  AND it.`name` NOT LIKE '%Deprecated%'
  AND it.`name` NOT LIKE '[PH]%'
  AND it.`name` NOT LIKE '%TEST%'
  AND it.`name` NOT LIKE '%Monster%';

-- --- роль insert: простые самоцветы ----------------------------------------
-- Цвета у них в имени, и четыре из них владелец уже разложил вручную (малахит,
-- тигровый глаз, камень теней, лунный камень). Правило повторяет его выбор,
-- сами четыре строки остаются нетронутыми - INSERT IGNORE.
INSERT IGNORE INTO `ap_material`
  (`entry`, `role`, `kind`, `part_kind_id`, `insert_type_id`,
   `stat_type`, `stat_value`, `ilvl_min`, `ilvl_max`,
   `quality_min`, `quality_max`, `enabled`)
SELECT it.`entry`, 'insert', 'gem', 0, 1,
       CASE
            WHEN it.`name` LIKE '%Malachite%' OR it.`name` LIKE '%Jade%'
              OR it.`name` LIKE '%Emerald%'   OR it.`name` LIKE '%Agate%'
              THEN 3             -- зелёный - ловкость
            WHEN it.`name` LIKE '%Tigerseye%' OR it.`name` LIKE '%Citrine%'
              OR it.`name` LIKE '%Topaz%'     OR it.`name` LIKE '%Amber%'
              THEN 4             -- жёлтый - сила
            WHEN it.`name` LIKE '%Shadowgem%' OR it.`name` LIKE '%Amethyst%'
              OR it.`name` LIKE '%Opal%'
              THEN 5             -- фиолетовый - интеллект
            WHEN it.`name` LIKE '%Moonstone%' OR it.`name` LIKE '%Sapphire%'
              OR it.`name` LIKE '%Aquamarine%' OR it.`name` LIKE '%Pearl%'
              THEN 7             -- голубой - выносливость
            WHEN it.`name` LIKE '%Ruby%' OR it.`name` LIKE '%Garnet%'
              THEN 38            -- красный - сила атаки
            ELSE 6               -- прочее - дух
       END,
       GREATEST(2, ROUND(it.`ItemLevel` / 8)) + (CAST(it.`Quality` AS SIGNED) - 2) * 2,
       GREATEST(0, CAST(it.`ItemLevel` AS SIGNED) - 10), it.`ItemLevel` + 15,
       0, 0, 1
FROM `item_template` it
WHERE it.`class` = 3
  AND it.`subclass` = 7
  AND it.`entry` < 100000
  AND it.`Quality` BETWEEN 1 AND 4
  AND it.`ItemLevel` > 0
  AND it.`name` <> ''
  AND it.`name` NOT LIKE '%Deprecated%'
  AND it.`name` NOT LIKE '[PH]%';

-- --- роль insert: реагенты чар ---------------------------------------------
-- Пыль, эссенция, осколок, кристалл - каждый со своим родом вставки, чтобы
-- рецепт мог спросить именно пыль.
INSERT IGNORE INTO `ap_material`
  (`entry`, `role`, `kind`, `part_kind_id`, `insert_type_id`,
   `stat_type`, `stat_value`, `ilvl_min`, `ilvl_max`,
   `quality_min`, `quality_max`, `enabled`)
SELECT it.`entry`, 'insert', 'other', 0,
       CASE
            WHEN it.`name` LIKE '%Dust%'    THEN 3
            WHEN it.`name` LIKE '%Essence%' THEN 4
            ELSE 5                                   -- осколки и кристаллы
       END,
       CASE
            WHEN it.`name` LIKE '%Dust%'    THEN 7   -- выносливость
            WHEN it.`name` LIKE '%Lesser Essence%' OR it.`name` LIKE '%Small%'
              THEN 6                                 -- дух
            WHEN it.`name` LIKE '%Essence%' THEN 5   -- интеллект
            WHEN it.`name` LIKE '%Crystal%' THEN 45  -- сила заклинаний
            ELSE 32                                  -- осколок - крит
       END,
       GREATEST(2, ROUND(it.`ItemLevel` / 8)) + (CAST(it.`Quality` AS SIGNED) - 2) * 2,
       GREATEST(0, CAST(it.`ItemLevel` AS SIGNED) - 10), it.`ItemLevel` + 15,
       0, 0, 1
FROM `item_template` it
WHERE it.`class` = 7
  AND it.`subclass` = 12
  AND it.`entry` < 100000
  AND it.`Quality` BETWEEN 1 AND 4
  AND it.`ItemLevel` > 0
  AND it.`name` <> ''
  AND it.`name` NOT LIKE '%Deprecated%'
  AND it.`name` NOT LIKE '[PH]%'
  AND it.`name` NOT LIKE '%TEST%';

-- --- роль insert: стихии ---------------------------------------------------
INSERT IGNORE INTO `ap_material`
  (`entry`, `role`, `kind`, `part_kind_id`, `insert_type_id`,
   `stat_type`, `stat_value`, `ilvl_min`, `ilvl_max`,
   `quality_min`, `quality_max`, `enabled`)
SELECT it.`entry`, 'insert', 'other', 0, 6,
       CASE
            WHEN it.`name` LIKE '%Fire%'   OR it.`name` LIKE '%Flame%'  THEN 4
            WHEN it.`name` LIKE '%Earth%'  OR it.`name` LIKE '%Stone%'  THEN 7
            WHEN it.`name` LIKE '%Water%'  OR it.`name` LIKE '%Ice%'    THEN 6
            WHEN it.`name` LIKE '%Air%'    OR it.`name` LIKE '%Wind%'   THEN 36
            WHEN it.`name` LIKE '%Shadow%' OR it.`name` LIKE '%Mana%'   THEN 5
            WHEN it.`name` LIKE '%Life%'   OR it.`name` LIKE '%Nature%' THEN 6
            ELSE 3
       END,
       GREATEST(2, ROUND(it.`ItemLevel` / 8)) + (CAST(it.`Quality` AS SIGNED) - 2) * 2,
       GREATEST(0, CAST(it.`ItemLevel` AS SIGNED) - 10), it.`ItemLevel` + 15,
       0, 0, 1
FROM `item_template` it
WHERE it.`class` = 7
  AND it.`subclass` = 10
  AND it.`entry` < 100000
  AND it.`Quality` BETWEEN 1 AND 4
  AND it.`ItemLevel` > 0
  AND it.`name` <> ''
  AND it.`name` NOT LIKE '%Deprecated%'
  AND it.`name` NOT LIKE '[PH]%'
  AND it.`name` NOT LIKE '%TEST%';

-- Каталог сменился целиком: аддон держит его в кэше и без этой строки будет
-- рисовать окно по старому справочнику (§7, «Кэш каталога»).
UPDATE `ap_config` SET `value` = `value` + 1 WHERE `name` = 'catalog_version';
