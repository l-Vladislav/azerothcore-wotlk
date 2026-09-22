-- mod-advanced-professions: сетка основ на все типы.
--
-- v31 собрала меч и показала, что приём работает; здесь тот же генератор
-- разворачивается на все включённые типы - от кинжала до щита. Меч он
-- пересобирает заново, поэтому v31 после этой миграции не нужна.
--
-- ЧТО ДЕЛАЕТ. Для каждой клетки «тип x качество x полоса уровня» берётся
-- ванильный предмет-донор того же класса, качества и уровня; его строка
-- копируется в блок основ, меняется только имя. Числа, вид, ножны и гнёзда
-- приезжают от донора - они уже прошли балансировку Blizzard для своего уровня.
--
-- ДВА ИСПРАВЛЕНИЯ ПРОТИВ v31, оба нашлись проверкой данных:
--
-- 1. СТУПЕНЬ, В КОТОРУЮ НЕЧЕГО ВСТАВИТЬ, НЕ ЗАВОДИТСЯ. «Безупречный мифриловый
--    клинок» (эпический, 41 уровень) имел четыре гнезда и НОЛЬ подходящих
--    вставок: эпических материалов ниже пятидесятого уровня в игре нет вовсе
--    (§2.5). Основа с четырьмя пустыми гнёздами, которые нечем заполнить, -
--    обещание, которого система не может выполнить. Теперь клетка проверяется
--    на наличие хотя бы одной вставки и без неё не рождается.
--
-- 2. ДОНОР ДЛЯ ПРОБЕЛА БЕРЁТСЯ БЛИЖАЙШИЙ, А НЕ СРЕДНИЙ. Добор из соседних
--    уровней в v31 шёл по медиане урона, и кобальтовая полоса (70-79) получила
--    редкую ступень с предмета 56-го уровня - на четырнадцать уровней ниже
--    собственной полосы. Теперь у пробела берётся донор, ближайший к середине
--    полосы: лестница не проваливается внутрь себя.
--
-- ОСНОВА - ЕЩЁ НЕ ВЕЩЬ, И ЧИСЛА У НЕЁ СТРИЖЕНЫ (§2.12, решение владельца
-- 2026-09-14). Донор прошёл балансировку Blizzard как ГОТОВАЯ вещь, а копия с
-- верстака - половина пути: её доводят камнями, и на ней стоит именной эскиз,
-- который обязан быть шагом вверх, а не подачкой. Замер показал, во что
-- обходилась полная копия: 83 % эскизов выдавали приз слабее, чем сама основа
-- с полным набором вставок.
--
-- Стрижка: статы - три четверти донорских, урон и броня - девять десятых.
-- Полосы саронита и выше (10-12) стрижены глубже, статы 0.60 и урон 0.80:
-- кованое не должно вставать вровень с рейдом, а безупречный титановый клинок
-- донором брал вещь 264-го уровня с 311 очками статов.
--
-- Уровень предмета стрижка НЕ трогает: он держит полосу, окно призов и набор
-- подходящих камней. Треть бюджета, которую возвращают вставки (§2.12),
-- поднимает доведённую вещь примерно к донорскому уровню - а именной приз
-- остаётся выше.
--
-- ЛЕСТНИЦА КАЧЕСТВА ИДЁТ ВВЕРХ, и теперь не только по урону: отставшая ступень
-- подтягивается до предыдущей плюс десятая часть по урону, броне И СТАТАМ, а
-- уровень предмета с уровнем надевания не падают вовсе. Ванильные числа
-- соседних качеств в ряд не выстроены - замер по 196 парам соседних ступеней:
-- 66 стоят НИЖЕ предыдущей по уровню предмета, 33 несут меньше статов, 58
-- вовсе без статов при непустой предыдущей, 65 требуют МЕНЬШЕГО уровня героя.
-- Для игрока это значит, что удачный бросок качества в трети случаев даёт вещь
-- хуже.
--
-- СТУПЕНЬ КАЧЕСТВА ЗАНИМАЕТ СВОЮ ЧЕТВЕРТЬ ПОЛОСЫ. Донор ищется не по всей
-- полосе, а в её четверти: обычное качество в нижней, эпическое в верхней.
-- Так уровень предмета растёт вместе с качеством сам собой. Прежде он ложился
-- как придётся, лестница выправляла его подъёмом отставшей ступени, и полоса
-- схлопывалась в одну точку - а вместе с уровнем схлопывалось и окно призов:
-- эскизов выходило 1211 вместо 2219. Четверть пуста - донор берётся по всей
-- полосе, как и раньше, поэтому покрытие не падает.
--
-- СЛАЙС ПУЛА БЕРЁТСЯ ИЗ СВОБОДНЫХ, А НЕ СЛЕДОМ ЗА ПОСЛЕДНИМ. Прежний счёт
-- «наибольший плюс шаг» уводил сетку вглубь блока каждый прогон и бросал
-- прежние слайсы: к третьему прогону свободного хвоста осталось на 146 слайсов
-- при нужде в 312. Теперь блок нарезан на 1024 клетки, занятой считается
-- пересечение с чужим живым слайсом или с выданным номером, и сетка забирает
-- свои обратно. Не хватило - прогон падает, а не пропускает молча.
--
-- ВИД У ПОЛОСЫ ОДИН: все ступени одной полосы носят модель, иконку, ножны и
-- слот самой скромной из них. Полоса - это одна вещь, которая бывает лучше или
-- хуже, а не четыре разных предмета с похожими именами.
--
-- ИМЕНА СКЛОНЯЮТСЯ ПО РОДУ. «Медный клинок», но «Медная булава» и «Медное
-- копьё»; приставка качества согласуется так же - «Безупречная саронитовая
-- секира». Род хранится у существительного типа, прилагательное полосы - сразу
-- тремя формами: выводить окончание правилом дороже и ошибается на «стальной».
--
-- БЛОК 181000-182999 ОТДАН ГЕНЕРАТОРУ ЦЕЛИКОМ. Ручные основы живут ниже, в
-- 180000-180999, геройские заготовки боссов - выше, в 183000-184999 (v38), и
-- под перегенерацию не попадают ни те, ни другие. Благодаря этому уборка в
-- начале файла точная: снести всё своё и собрать заново - единственный способ
-- перезапускать генератор, пока правила ещё меняются.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §2.7, §2.12.

-- --------------------------------------------------------------------------
-- 0. Уборка прошлого прогона (и остатков v31)
-- --------------------------------------------------------------------------
-- Выданные заготовки защищены проверкой по `ap_generated_item` в каждом
-- удалении: у игрока в сумке лежит вещь с этим entry, и снос строки превратил
-- бы её в «предмет не существует» (§4).
DELETE rr FROM `ap_recipe_result` rr
WHERE rr.`result_entry` BETWEEN 180006 AND 182999;

DELETE r FROM `ap_recipe` r
WHERE NOT EXISTS (SELECT 1 FROM `ap_recipe_result` x WHERE x.`recipe_id` = r.`id`);

DELETE ri FROM `ap_recipe_item` ri
WHERE NOT EXISTS (SELECT 1 FROM `ap_recipe` r WHERE r.`id` = ri.`recipe_id`);

DELETE rt FROM `ap_recipe_insert_type` rt
WHERE NOT EXISTS (SELECT 1 FROM `ap_recipe` r WHERE r.`id` = rt.`recipe_id`);

DELETE rm FROM `ap_recipe_material` rm
WHERE NOT EXISTS (SELECT 1 FROM `ap_recipe` r WHERE r.`id` = rm.`recipe_id`);

DELETE t FROM `item_template` t
WHERE t.`entry` BETWEEN 180006 AND 182999
  AND NOT EXISTS (SELECT 1 FROM `ap_recipe_result` r WHERE r.`result_entry` = t.`entry`)
  AND NOT EXISTS (SELECT 1 FROM `ap_synergy` s WHERE s.`result_entry` = t.`entry`)
  AND NOT EXISTS (SELECT 1 FROM `ap_item_type` y WHERE y.`fail_entry` = t.`entry`)
  AND NOT EXISTS (SELECT 1 FROM `ap_generated_item` g WHERE g.`source_entry` = t.`entry`);

DELETE t FROM `item_template` t
WHERE t.`entry` BETWEEN 1100000 AND 3199999
  AND NOT EXISTS (SELECT 1 FROM `ap_recipe_result` r
                  WHERE t.`entry` BETWEEN r.`pool_lo` AND r.`pool_hi`)
  AND NOT EXISTS (SELECT 1 FROM `ap_generated_item` g WHERE g.`entry` = t.`entry`);

-- --------------------------------------------------------------------------
-- 1. Полосы уровня
-- --------------------------------------------------------------------------
-- Металл, дерево и кожа - три рода, которые спрашивают схемы частей (больше в
-- них не встречается). Дерева в игре всего два рода, поэтому простая древесина
-- служит нижним полосам, звёздная - верхним.
-- ТАБЛИЦА ПОСТОЯННАЯ, А НЕ ВРЕМЕННАЯ (2026-09-14). Полоса нужна не только
-- сетке: по ней же считается величина вставки и её окно уровня (§2.12), и
-- второй список тех же границ в другой миграции - ровно тот способ, которым в
-- этой системе уже дважды разъезжались лестницы. Пусть будет одна, и пусть она
-- лежит в базе: генератор её переписывает на каждом прогоне, остальные читают.
-- Таблица пересоздаётся: у неё появилась колонка `metal_count` (цена ковки),
-- а содержимое всё равно переписывается целиком на каждом прогоне.
DROP TABLE IF EXISTS `ap_band`;
CREATE TABLE `ap_band` (
  `idx`         TINYINT UNSIGNED PRIMARY KEY,
  `lo`          SMALLINT UNSIGNED NOT NULL,
  `hi`          SMALLINT UNSIGNED NOT NULL,
  `adj_m`       VARCHAR(32) NOT NULL,
  `adj_f`       VARCHAR(32) NOT NULL,
  `adj_n`       VARCHAR(32) NOT NULL,
  `metal`       INT UNSIGNED NOT NULL,
  `wood`        INT UNSIGNED NOT NULL,
  `leather`     INT UNSIGNED NOT NULL,
  `skill`       SMALLINT UNSIGNED NOT NULL,
  `metal_count` SMALLINT UNSIGNED NOT NULL DEFAULT 2
                COMMENT 'Слитков на одну ковку для типа среднего веса (§6)'
);

-- ПОЛОСА - ЭТО УРОВЕНЬ ПРЕДМЕТА, А НЕ УРОВЕНЬ ПЕРСОНАЖА (2026-09-14).
-- Прежняя лестница резала уровни предмета по десятке - 1-9, 10-19, ... 80-85 -
-- и вешала на них названия материалов так, будто это уровни персонажа. До
-- ванильной шестидесятки это сходится: там уровень вещи идёт с уровнем героя
-- почти вровень (замер по базе: размах внутри десятки 9-15 уровней предмета).
-- С TBC они расходятся, и дальше расхождение только растёт:
--
--     треб. уровень 50-59 -> уровни предметов 55-64   (размах  9)
--     треб. уровень 60-69 -> уровни предметов 65-130  (размах  65)
--     треб. уровень 70-79 -> уровни предметов 75-187  (размах 112)
--     треб. уровень 80    -> уровни предметов 187-284 (размах  97)
--
-- Оттого «саронитовая» ступень и оказывалась вещью 85-го уровня предмета, тогда
-- как настоящий саронит в игре - это 175-200: десять уровней героя в Личе стоят
-- сотни уровней предмета. Всё, что выше 91-го, не имело ступени вовсе - семь
-- сотен вещей, весь TBC и Лич.
--
-- Теперь низ идёт по десятке, как и шёл, а с оскверненного железа полосы
-- расширяются по настоящему размаху эпохи. Названия встали на свои места:
-- адамантит на 90-114, кобальт на 140-174, саронит на 175-199, титансталь на
-- 200-232. Навык растянут на тринадцать ступеней: 1, 40, 80 ... 480.
DELETE FROM `ap_band`;
INSERT INTO `ap_band` VALUES
  ( 0,   1,  14, 'Медный',        'Медная',        'Медное',          2840,  4470,  2318,   1, 6),
  ( 1,  15,  24, 'Бронзовый',     'Бронзовая',     'Бронзовое',       2841,  4470,  2318,  40, 6),
  ( 2,  25,  34, 'Железный',      'Железная',      'Железное',        3575,  4470,  2319,  80, 8),
  ( 3,  35,  44, 'Стальной',      'Стальная',      'Стальное',        3859,  4470,  4234, 120, 8),
  ( 4,  45,  54, 'Мифриловый',    'Мифриловая',    'Мифриловое',      3860, 11291,  4304, 160, 10),
  ( 5,  55,  64, 'Ториевый',      'Ториевая',      'Ториевое',       12359, 11291,  8170, 200, 10),
  ( 6,  65,  89, 'Осквернённый',  'Осквернённая',  'Осквернённое',   23445, 11291, 21887, 240, 8),
  ( 7,  90, 114, 'Адамантитовый', 'Адамантитовая', 'Адамантитовое',  23446, 11291, 21887, 280, 8),
  ( 8, 115, 139, 'Кориевый',      'Кориевая',      'Кориевое',       23449, 11291, 21887, 320, 8),
  ( 9, 140, 174, 'Кобальтовый',   'Кобальтовая',   'Кобальтовое',    36916, 11291, 33568, 360, 12),
  (10, 175, 199, 'Саронитовый',   'Саронитовая',   'Саронитовое',    36913, 11291, 38425, 400, 10),
  (11, 200, 232, 'Титанстальной', 'Титанстальная', 'Титанстальное',  37663, 11291, 38425, 440, 4),
  (12, 233, 284, 'Титановый',     'Титановая',     'Титановое',      41163, 11291, 38425, 480, 20);

-- --------------------------------------------------------------------------
-- 2. Существительные типов и их род
-- --------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `ap_noun`;
CREATE TEMPORARY TABLE `ap_noun` (
  `type_id` INT UNSIGNED PRIMARY KEY,
  `noun`    VARCHAR(32) NOT NULL,
  `gender`  CHAR(1) NOT NULL
);

INSERT INTO `ap_noun`
SELECT t.`id`,
       CASE t.`code`
            WHEN 'sword'   THEN 'клинок'
            WHEN 'sword2h' THEN 'меч'
            WHEN 'dagger'  THEN 'кинжал'
            WHEN 'axe'     THEN 'топор'
            WHEN 'axe2h'   THEN 'секира'
            WHEN 'mace'    THEN 'булава'
            WHEN 'mace2h'  THEN 'молот'
            WHEN 'polearm' THEN 'копьё'
            WHEN 'fist'    THEN 'кастет'
            WHEN 'shield'  THEN 'щит'
            ELSE t.`name_ru` END,
       CASE t.`code`
            WHEN 'axe2h'   THEN 'f'
            WHEN 'mace'    THEN 'f'
            WHEN 'polearm' THEN 'n'
            ELSE 'm' END
FROM `ap_item_type` t
WHERE t.`enabled` = 1;

-- --------------------------------------------------------------------------
-- 3. Доноры: по одному на клетку, медиана по силе вещи
-- --------------------------------------------------------------------------
-- Сила - урон для оружия и броня для щита: одним выражением, чтобы правило было
-- одно на все типы. Медиана, а не первый попавшийся: в клетке бывает два
-- десятка предметов, и среди них попадаются квестовые диковины вдвое сильнее
-- соседей.
DROP TEMPORARY TABLE IF EXISTS `ap_cell`;
CREATE TEMPORARY TABLE `ap_cell` (
  `type_id` INT UNSIGNED NOT NULL,
  `band`    TINYINT UNSIGNED NOT NULL,
  `q`       TINYINT UNSIGNED NOT NULL,
  `donor`   INT UNSIGNED NOT NULL,
  PRIMARY KEY (`type_id`, `band`, `q`)
);

-- СТУПЕНЬ КАЧЕСТВА ЗАНИМАЕТ СВОЮ ЧЕТВЕРТЬ ПОЛОСЫ (2026-09-14). Донор для
-- каждой клетки прежде искался по всей полосе, и уровни ступеней ложились как
-- придётся: у адамантитовой полосы (90-114) синяя ступень выходила 94-го
-- уровня, а зелёная 108-го. Лестница качества это потом выправляла, поднимая
-- уровень отставшей ступени до предыдущей, - и вся полоса схлопывалась в одну
-- точку: 108, 108, 108. А раз уровень один, то и окно призов одно: ступени
-- начинали делить между собой один и тот же десяток вещей, и эскизов
-- становилось вдвое меньше (замер: 1211 против 2219).
--
-- Поэтому донор ищется сперва в СВОЕЙ четверти полосы: обычное качество в
-- нижней, эпическое в верхней. Уровень тогда растёт вместе с качеством сам
-- собой, выправлять нечего, а ступени смотрят в разные части полосы.
--
-- Медиана по силе внутри четверти сохраняется: в клетке бывает два десятка
-- предметов, и среди них попадаются квестовые диковины вдвое сильнее соседей.
-- СТУПЕНЬ ВЫШЕ ОБЫЧНОЙ ОБЯЗАНА НЕСТИ СТАТЫ (2026-09-17). Это первый проход, и
-- он о том, чем зелёная вещь отличается от белой.
--
-- В 3.3.5a статы зелёных вещей лежат не в строке предмета, а в СУФФИКСЕ
-- (`RandomSuffix`): «Меч Медведя» получает свою выносливость броском при
-- выпадении. Замер: из зелёного оружия уровней 90-160 суффиксом живут 84 %.
-- Копия суффикс не наследует - и не может, иначе каждая выдача была бы разной
-- (раздел 5, `RandomProperty` = 0). Донор при этом выбирался по одной лишь
-- силе вещи, то есть по урону и броне, а статы в отборе не участвовали вовсе.
--
-- Итог: ступень копировала зелёного донора и теряла ровно то, что делало его
-- зелёным. По базе таких ступеней 67 из 269 - целая «Отменная кобальтовая
-- секира» без единого стата, а гнёзд у неё два. Для игрока это удачный бросок,
-- за которым пусто: качество выше, а вещь та же белая.
--
-- Поэтому клетка качества 2-4 сперва ищет донора СО СВОИМИ статами, и только
-- если такого в четверти нет - идут проходы ниже, по прежним правилам. Замер
-- показывает, что хватает почти везде: доноры со статами есть у 239 клеток
-- из 269.
INSERT INTO `ap_cell` (`type_id`, `band`, `q`, `donor`)
SELECT `type_id`, `band`, `q`, `donor` FROM (
  SELECT t.`id` AS `type_id`, b.`idx` AS `band`, it.`Quality` AS `q`,
         it.`entry` AS `donor`,
         ROW_NUMBER() OVER (PARTITION BY t.`id`, b.`idx`, it.`Quality`
                            ORDER BY it.`dmg_min1` + it.`dmg_max1` + it.`armor`,
                                     it.`entry`) AS `rn`,
         COUNT(*) OVER (PARTITION BY t.`id`, b.`idx`, it.`Quality`) AS `cnt`
  FROM `ap_band` b
  JOIN `ap_item_type` t ON t.`enabled` = 1
  JOIN `item_template` it
    ON it.`class` = t.`item_class` AND it.`subclass` = t.`item_subclass`
   AND it.`ItemLevel` BETWEEN
         CAST(b.`lo` AS SIGNED)
         + FLOOR((CAST(b.`hi` AS SIGNED) - CAST(b.`lo` AS SIGNED))
                 * (CAST(it.`Quality` AS SIGNED) - 1) / 4)
       AND CAST(b.`lo` AS SIGNED)
         + FLOOR((CAST(b.`hi` AS SIGNED) - CAST(b.`lo` AS SIGNED))
                 * CAST(it.`Quality` AS SIGNED) / 4)
  WHERE it.`entry` < 100000
    AND it.`Quality` BETWEEN 2 AND 4
    AND it.`name` <> ''
    AND (it.`dmg_max1` > 0 OR it.`armor` > 0)
    AND (SELECT `total` FROM `ap_item_budget`
         WHERE `entry` = it.`entry`) > 0
    AND NOT EXISTS (SELECT 1 FROM `ap_junk_name` j
                    WHERE it.`name` REGEXP j.`pattern`)
) x
WHERE `rn` = FLOOR((`cnt` + 1) / 2);

-- Дальше - прежние проходы, они добирают то, чего первый не нашёл: обычное
-- качество целиком и те клетки 2-4, где донора со статами в четверти нет.
INSERT IGNORE INTO `ap_cell` (`type_id`, `band`, `q`, `donor`)
SELECT `type_id`, `band`, `q`, `donor` FROM (
  SELECT t.`id` AS `type_id`, b.`idx` AS `band`, it.`Quality` AS `q`,
         it.`entry` AS `donor`,
         ROW_NUMBER() OVER (PARTITION BY t.`id`, b.`idx`, it.`Quality`
                            ORDER BY it.`dmg_min1` + it.`dmg_max1` + it.`armor`,
                                     it.`entry`) AS `rn`,
         COUNT(*) OVER (PARTITION BY t.`id`, b.`idx`, it.`Quality`) AS `cnt`
  FROM `ap_band` b
  JOIN `ap_item_type` t ON t.`enabled` = 1
  JOIN `item_template` it
    ON it.`class` = t.`item_class` AND it.`subclass` = t.`item_subclass`
   AND it.`ItemLevel` BETWEEN
         CAST(b.`lo` AS SIGNED)
         + FLOOR((CAST(b.`hi` AS SIGNED) - CAST(b.`lo` AS SIGNED))
                 * (CAST(it.`Quality` AS SIGNED) - 1) / 4)
       AND CAST(b.`lo` AS SIGNED)
         + FLOOR((CAST(b.`hi` AS SIGNED) - CAST(b.`lo` AS SIGNED))
                 * CAST(it.`Quality` AS SIGNED) / 4)
  WHERE it.`entry` < 100000
    AND it.`Quality` BETWEEN 1 AND 4
    AND it.`name` <> ''
    AND (it.`dmg_max1` > 0 OR it.`armor` > 0)
    AND NOT EXISTS (SELECT 1 FROM `ap_junk_name` j
                    WHERE it.`name` REGEXP j.`pattern`)
) x
WHERE `rn` = FLOOR((`cnt` + 1) / 2);

-- Мусор игры отсеивается по `ap_junk_name` (v47), а не пятью `LIKE` на месте.
-- Пять `LIKE` были шестой копией списка и ловили не то: `%TEST%` уносил
-- Greatest и Contest, а `[PH]%` в LIKE - это «первая буква P или H».
-- Четверть бывает пуста - тогда донор берётся по всей полосе, как и раньше.
-- Покрытие от новой разметки не падает: этот запрос тот же, что стоял здесь до
-- неё, и `INSERT IGNORE` дописывает только клетки, которых четверть не дала.
INSERT IGNORE INTO `ap_cell` (`type_id`, `band`, `q`, `donor`)
SELECT `type_id`, `band`, `q`, `donor` FROM (
  SELECT t.`id` AS `type_id`, b.`idx` AS `band`, it.`Quality` AS `q`,
         it.`entry` AS `donor`,
         ROW_NUMBER() OVER (PARTITION BY t.`id`, b.`idx`, it.`Quality`
                            ORDER BY it.`dmg_min1` + it.`dmg_max1` + it.`armor`,
                                     it.`entry`) AS `rn`,
         COUNT(*) OVER (PARTITION BY t.`id`, b.`idx`, it.`Quality`) AS `cnt`
  FROM `ap_band` b
  JOIN `ap_item_type` t ON t.`enabled` = 1
  JOIN `item_template` it
    ON it.`class` = t.`item_class` AND it.`subclass` = t.`item_subclass`
   AND it.`ItemLevel` BETWEEN b.`lo` AND b.`hi`
  WHERE it.`entry` < 100000
    AND it.`Quality` BETWEEN 1 AND 4
    AND it.`name` <> ''
    AND (it.`dmg_max1` > 0 OR it.`armor` > 0)
    AND NOT EXISTS (SELECT 1 FROM `ap_junk_name` j
                    WHERE it.`name` REGEXP j.`pattern`)
) x
WHERE `rn` = FLOOR((`cnt` + 1) / 2);

-- Пробелы ВНУТРИ полосы добираются из соседних уровней: у кобальтовой (70-79)
-- нет ни зелёного оружия, ни синего - первые появляются на 80-м, - а ступени 1
-- и 4 при этом есть. Бросок качества прижимается к границам рецепта и упёрся бы
-- в «нет изделия на эту ступень»: отказ на ровном месте.
--
-- Донор берётся БЛИЖАЙШИЙ к середине полосы, а не средний по силе: иначе
-- лестница проваливается внутрь себя (v31 дала кобальтовой полосе редкую
-- ступень с 56-го уровня).
DROP TEMPORARY TABLE IF EXISTS `ap_span`;
CREATE TEMPORARY TABLE `ap_span` AS
SELECT `type_id`, `band`, MIN(`q`) AS `qmin`, MAX(`q`) AS `qmax`
FROM `ap_cell` GROUP BY `type_id`, `band`;

INSERT IGNORE INTO `ap_cell` (`type_id`, `band`, `q`, `donor`)
SELECT `type_id`, `band`, `q`, `donor` FROM (
  SELECT s.`type_id`, b.`idx` AS `band`, it.`Quality` AS `q`,
         it.`entry` AS `donor`,
         ROW_NUMBER() OVER (PARTITION BY s.`type_id`, b.`idx`, it.`Quality`
                            ORDER BY ABS(CAST(it.`ItemLevel` AS SIGNED)
                                       - (CAST(b.`lo` AS SIGNED)
                                          + (CAST(b.`hi` AS SIGNED)
                                             - CAST(b.`lo` AS SIGNED))
                                            * (2 * CAST(it.`Quality` AS SIGNED)
                                               - 1) DIV 8)),
                                     it.`entry`) AS `rn`
  FROM `ap_band` b
  JOIN `ap_span` s ON s.`band` = b.`idx`
  JOIN `ap_item_type` t ON t.`id` = s.`type_id`
  JOIN `item_template` it
    ON it.`class` = t.`item_class` AND it.`subclass` = t.`item_subclass`
   AND it.`ItemLevel` BETWEEN GREATEST(1, CAST(b.`lo` AS SIGNED) - 15)
                          AND b.`hi` + 15
   AND it.`Quality` BETWEEN s.`qmin` AND s.`qmax`
  WHERE it.`entry` < 100000
    AND it.`name` <> ''
    AND (it.`dmg_max1` > 0 OR it.`armor` > 0)
    AND NOT EXISTS (SELECT 1 FROM `ap_junk_name` j
                    WHERE it.`name` REGEXP j.`pattern`)
) x
WHERE `rn` = 1;

-- --------------------------------------------------------------------------
-- 3b. Недостающая ступень качества синтезируется из соседней
-- --------------------------------------------------------------------------
-- Решение владельца 2026-09-14. На меди, бронзе и железе в игре НЕТ ни одной
-- эпической вещи нашего рода - донора взять неоткуда, и бросок качества на
-- этих полосах упирался в потолок «отменной». Лестница обрывалась там, где
-- игрок как раз и учится ремеслу.
--
-- Синтез простой: клетка берёт донора верхней СУЩЕСТВУЮЩЕЙ ступени своей
-- полосы, а качество получает своё. Числа ей потом поднимет та же лестница из
-- 6b - на десятую часть над предыдущей ступенью, - и вид у полосы остаётся
-- один на все ступени.
--
-- Вниз лестница не достраивается: на верхних полосах белых вещей в игре нет, и
-- заводить «треснувший титановый клинок» незачем - рецепт просто начинается с
-- того качества, которое у полосы есть.
-- Считается в три захода не от любви к временным таблицам: mysql не открывает
-- одну и ту же ВРЕМЕННУЮ таблицу дважды в одном запросе, а здесь `ap_cell`
-- нужна и как источник, и как цель.
DROP TEMPORARY TABLE IF EXISTS `ap_top`;
CREATE TEMPORARY TABLE `ap_top` AS
SELECT `type_id`, `band`, MAX(`q`) AS `qmax`
FROM `ap_cell` GROUP BY `type_id`, `band`;

DROP TEMPORARY TABLE IF EXISTS `ap_synth`;
CREATE TEMPORARY TABLE `ap_synth` AS
SELECT s.`type_id` AS `type_id`, s.`band` AS `band`,
       q.`quality` AS `q`, c.`donor` AS `donor`
FROM `ap_top` s
JOIN `ap_cell` c ON c.`type_id` = s.`type_id` AND c.`band` = s.`band`
                AND c.`q` = s.`qmax`
JOIN `ap_quality` q ON q.`quality` > s.`qmax` AND q.`quality` <= 4;

INSERT IGNORE INTO `ap_cell` (`type_id`, `band`, `q`, `donor`)
SELECT `type_id`, `band`, `q`, `donor` FROM `ap_synth`;

DROP TEMPORARY TABLE IF EXISTS `ap_top`;
DROP TEMPORARY TABLE IF EXISTS `ap_synth`;

-- --------------------------------------------------------------------------
-- 4. Ступень, в которую нечего вставить, не заводится
-- --------------------------------------------------------------------------
-- Правило доводки - строгое совпадение качества плюс окно уровня (§2.5).
-- Эпических материалов ниже пятидесятого уровня в игре нет, поэтому эпическая
-- основа сорокового - четыре гнезда, которые нечем заполнить.
-- Качество берётся у КЛЕТКИ (`c.q`), а не у донора: у синтезированной ступени
-- (3b) донор чужого качества, и проверка спрашивала бы не про ту вещь.
DELETE c FROM `ap_cell` c
JOIN `item_template` d ON d.`entry` = c.`donor`
WHERE NOT EXISTS (
  SELECT 1 FROM `ap_material` m
  JOIN `item_template` mi ON mi.`entry` = m.`entry`
  WHERE m.`role` = 'insert' AND m.`enabled` = 1
    AND (m.`ilvl_min` = 0 OR d.`ItemLevel` >= m.`ilvl_min`)
    AND (m.`ilvl_max` = 0 OR d.`ItemLevel` <= m.`ilvl_max`)
    AND ((m.`quality_min` = 0 AND m.`quality_max` = 0 AND c.`q` = mi.`Quality`)
      OR (m.`quality_min` > 0 AND c.`q` >= m.`quality_min`
          AND (m.`quality_max` = 0 OR c.`q` <= m.`quality_max`))
      OR (m.`quality_min` = 0 AND m.`quality_max` > 0 AND c.`q` <= m.`quality_max`)));

-- Снятая ступень могла оставить дыру в середине - тогда всё, что выше дыры,
-- уходит следом: бросок качества ходит по непрерывному отрезку.
DROP TEMPORARY TABLE IF EXISTS `ap_keep`;
CREATE TEMPORARY TABLE `ap_keep` AS
SELECT `type_id`, `band`, `q` FROM (
  SELECT `type_id`, `band`, `q`,
         MIN(`q`) OVER (PARTITION BY `type_id`, `band`) AS `qmin`,
         ROW_NUMBER() OVER (PARTITION BY `type_id`, `band` ORDER BY `q`) AS `rn`
  FROM `ap_cell`
) x
WHERE `q` - `qmin` + 1 = `rn`;

DELETE c FROM `ap_cell` c
LEFT JOIN `ap_keep` k
  ON k.`type_id` = c.`type_id` AND k.`band` = c.`band` AND k.`q` = c.`q`
WHERE k.`q` IS NULL;

-- --------------------------------------------------------------------------
-- 5. Новые основы: номера и имена
-- --------------------------------------------------------------------------
SELECT COALESCE(MAX(`entry`), 180999) + 1 INTO @base_next
FROM `item_template` WHERE `entry` BETWEEN 181000 AND 182999;

DROP TEMPORARY TABLE IF EXISTS `ap_grid`;
CREATE TEMPORARY TABLE `ap_grid` (
  `type_id`   INT UNSIGNED NOT NULL,
  `band`      TINYINT UNSIGNED NOT NULL,
  `q`         TINYINT UNSIGNED NOT NULL,
  `donor`     INT UNSIGNED NOT NULL,
  `new_entry` INT UNSIGNED NOT NULL,
  `name`      VARCHAR(255) NOT NULL,
  PRIMARY KEY (`type_id`, `band`, `q`),
  UNIQUE KEY (`new_entry`),
  KEY (`donor`)
);

INSERT INTO `ap_grid` (`type_id`, `band`, `q`, `donor`, `new_entry`, `name`)
SELECT c.`type_id`, c.`band`, c.`q`, c.`donor`,
       @base_next + ROW_NUMBER() OVER (ORDER BY c.`type_id`, c.`band`, c.`q`) - 1,
       CONCAT(
         CASE WHEN c.`q` = 1 THEN '' ELSE CONCAT(
           CASE n.`gender`
                WHEN 'f' THEN ELT(c.`q` - 1, 'Отменная', 'Превосходная', 'Безупречная')
                WHEN 'n' THEN ELT(c.`q` - 1, 'Отменное', 'Превосходное', 'Безупречное')
                ELSE ELT(c.`q` - 1, 'Отменный', 'Превосходный', 'Безупречный')
           END, ' ') END,
         CASE WHEN c.`q` = 1
              THEN CASE n.`gender` WHEN 'f' THEN b.`adj_f`
                                   WHEN 'n' THEN b.`adj_n`
                                   ELSE b.`adj_m` END
              ELSE LOWER(CASE n.`gender` WHEN 'f' THEN b.`adj_f`
                                         WHEN 'n' THEN b.`adj_n`
                                         ELSE b.`adj_m` END)
         END,
         ' ', n.`noun`)
FROM `ap_cell` c
JOIN `ap_band` b ON b.`idx` = c.`band`
JOIN `ap_noun` n ON n.`type_id` = c.`type_id`;

-- Копия строки донора целиком, а не перечисление полутора сотен колонок:
-- перечисление однажды разойдётся со схемой ядра, `SELECT *` - никогда. И не
-- `LIKE item_template`: у неё полнотекстовый индекс, а временная InnoDB такого
-- не держит.
--
-- Копия делается НА КЛЕТКУ, а не на донора: соседние полосы иногда берут один и
-- тот же предмет (окно добора ±15 у кобальта и саронита перекрывается), и копия
-- по донору давала одну строку на две ступени - вторая оставалась ссылкой в
-- никуда. Так и вышло на первом прогоне: 224 ступени против 221 основы.
--
-- Номер и имя приезжают первыми колонками, а перед вставкой отбрасываются: так
-- порядок оставшихся колонок точь-в-точь совпадает с `item_template`, и
-- `SELECT *` кладётся в неё без перечисления.
-- ВИД У ПОЛОСЫ ОДИН НА ВСЕ СТУПЕНИ (решение владельца 2026-09-13). Каждая
-- ступень копируется со своего донора, и по умолчанию у них разные модели: в
-- игре «Бронзовый клинок» и «Отменный бронзовый клинок» оказывались разными
-- вещами с одним именем. Полоса должна читаться ОДНОЙ вещью, которая бывает
-- лучше или хуже, - как ванильные «Меч» и «Меч высшего сорта».
--
-- Вид берётся у самой скромной ступени полосы: она есть всегда, а эпическая -
-- далеко не в каждой. Вместе с моделью раздаются ножны, материал и звук: это
-- одна семья полей, и разъехаться им нельзя.
DROP TEMPORARY TABLE IF EXISTS `ap_low`;
CREATE TEMPORARY TABLE `ap_low` AS
SELECT `type_id`, `band`, MIN(`q`) AS `q` FROM `ap_grid`
GROUP BY `type_id`, `band`;

DROP TEMPORARY TABLE IF EXISTS `ap_look`;
CREATE TEMPORARY TABLE `ap_look` AS
SELECT g.`type_id`, g.`band`, it.`displayid`, it.`Material`, it.`Sheath`,
       it.`SoundOverrideSubclass` AS `sound`, it.`InventoryType`
FROM `ap_grid` g
JOIN `ap_low` l ON l.`type_id` = g.`type_id` AND l.`band` = g.`band`
                AND l.`q` = g.`q`
JOIN `item_template` it ON it.`entry` = g.`donor`;

DROP TEMPORARY TABLE IF EXISTS `ap_copy`;
CREATE TEMPORARY TABLE `ap_copy` AS
SELECT g.`new_entry` AS `ap_new_entry`, g.`name` AS `ap_new_name`,
       g.`type_id` AS `ap_type_id`, g.`band` AS `ap_band`,
       g.`q` AS `ap_q`, it.*
FROM `ap_grid` g
JOIN `item_template` it ON it.`entry` = g.`donor`;

UPDATE `ap_copy` c
SET c.`entry` = c.`ap_new_entry`,
    c.`name`  = c.`ap_new_name`,
    -- Качество берётся у КЛЕТКИ: у синтезированной ступени (3b) донор чужого
    -- качества, и без этой строки эпическая основа осталась бы синей.
    c.`Quality` = c.`ap_q`,
    -- Случайные суффиксы («Меч Медведя») основе ни к чему: каждая выдача
    -- оказывалась бы разной, а копия из пула наследует строку как есть.
    c.`RandomProperty` = 0,
    c.`RandomSuffix`   = 0,
    -- Изделие верстака свободно торгуется (§1): привязка донора тут не к месту.
    c.`bonding` = 0,
    -- Чужие квесты и скрипты вместе со строкой не переезжают.
    c.`startquest` = 0,
    c.`ScriptName` = '',
    -- ВСЁ, ЧЕМ ДОНОР БЫЛ ПРИВЯЗАН К СВОЕМУ ИСТОЧНИКУ. Список тот же, что у
    -- копий призов (gen-synergies.py) и у геройских заготовок: три блока -
    -- три бывших списка, и они разошлись. Замер по базе: у основ оставалось
    -- 19 строк с запретом по классу, 5 уникальных, 4 с требованием репутации
    -- и 2 с чужим умением, у заготовок - 207, 116, 0 и 1.
    --
    -- Каждая из этих строк - тупик на руках у игрока. Саронитовый кинжал
    -- требовал репутации 1090, копьё - 1073: выковал и не наденешь.
    -- Адамантитовый клинок требовал умения 17039 - специализации кузнеца,
    -- которой у нашего верстака нет вовсе. «Безупречный титановый клинок»,
    -- вершина всей лестницы, был помечен `maxcount` = 1 и не складывался в
    -- сумке. Ториевый кинжал состоял в ванильном наборе 65 и раздавал его
    -- бонус даром.
    c.`AllowableClass` = -1,
    c.`AllowableRace`  = -1,
    c.`RequiredSkill` = 0, c.`RequiredSkillRank` = 0,
    c.`RequiredReputationFaction` = 0, c.`RequiredReputationRank` = 0,
    c.`maxcount` = 0, c.`itemset` = 0, c.`ItemLimitCategory` = 0,
    c.`requiredhonorrank` = 0, c.`RequiredCityRank` = 0,
    c.`requiredspell` = 0, c.`RequiredDisenchantSkill` = -1,
    c.`duration` = 0,
    -- Прок донора не переезжает ни в одном из пяти полей: основу доводят
    -- камнями, а не чужим умением (§2.9).
    c.`spellid_1` = 0, c.`spellid_2` = 0, c.`spellid_3` = 0,
    c.`spellid_4` = 0, c.`spellid_5` = 0;

UPDATE `ap_copy` c
JOIN `ap_look` k ON k.`type_id` = c.`ap_type_id` AND k.`band` = c.`ap_band`
SET c.`displayid`             = k.`displayid`,
    c.`Material`              = k.`Material`,
    c.`Sheath`                = k.`Sheath`,
    c.`SoundOverrideSubclass` = k.`sound`,
    -- Слот тоже общий: одинаковые с виду вещи не должны надеваться
    -- по-разному (одна «в правую руку», другая «в любую»).
    c.`InventoryType`         = k.`InventoryType`;

-- --------------------------------------------------------------------------
-- 5b. Стрижка: основа слабее своего донора
-- --------------------------------------------------------------------------
-- Донор сбалансирован как ГОТОВАЯ вещь, а основа - половина пути: её доводят
-- камнями (§2.12), и на ней стоит именной эскиз. Полная копия донора делала
-- обе половины бессмысленными: замер дал 83 процента эскизов, где приз слабее
-- самой основы с полным набором вставок, и треть - где он слабее по урону.
--
-- Стрижётся то, что игрок читает как силу: статы, урон, броня. Уровень
-- предмета не трогается - на нём держатся полоса, окно призов и список
-- подходящих камней, и сдвинуть его значило бы пересобрать заодно всё это.
--
-- Верхние полосы стрижены глубже. Решение владельца 2026-09-14: кованое идёт
-- ступенью НИЖЕ рейда, а донором безупречного титанового клинка была вещь
-- 264-го уровня с 311 очками статов - то есть верстак на навыке 480 выдавал
-- рейдовую вещь целиком.
--
-- Ноль остаётся нулём, а не превращается в единицу: у белой ступени статов
-- нет вовсе, и заводить их стрижкой не дело. Отрицательные значения (ванильные
-- штрафы) тоже не трогаются - их стрижка сделала бы МЕНЬШЕ по модулю, то есть
-- вещь стала бы лучше.
SET @k_stat     := 0.75;   -- статы полос 0-9
SET @k_dmg      := 0.90;   -- урон и броня полос 0-9
SET @k_stat_top := 0.60;   -- статы полос 10-12: саронит, титансталь, титан
SET @k_dmg_top  := 0.80;

UPDATE `ap_copy` c
SET c.`stat_value1` = IF(c.`stat_value1` > 0,
        GREATEST(1, ROUND(c.`stat_value1` * @k_stat)), c.`stat_value1`),
    c.`stat_value2` = IF(c.`stat_value2` > 0,
        GREATEST(1, ROUND(c.`stat_value2` * @k_stat)), c.`stat_value2`),
    c.`stat_value3` = IF(c.`stat_value3` > 0,
        GREATEST(1, ROUND(c.`stat_value3` * @k_stat)), c.`stat_value3`),
    c.`stat_value4` = IF(c.`stat_value4` > 0,
        GREATEST(1, ROUND(c.`stat_value4` * @k_stat)), c.`stat_value4`),
    c.`stat_value5` = IF(c.`stat_value5` > 0,
        GREATEST(1, ROUND(c.`stat_value5` * @k_stat)), c.`stat_value5`),
    c.`stat_value6` = IF(c.`stat_value6` > 0,
        GREATEST(1, ROUND(c.`stat_value6` * @k_stat)), c.`stat_value6`),
    c.`stat_value7` = IF(c.`stat_value7` > 0,
        GREATEST(1, ROUND(c.`stat_value7` * @k_stat)), c.`stat_value7`),
    c.`stat_value8` = IF(c.`stat_value8` > 0,
        GREATEST(1, ROUND(c.`stat_value8` * @k_stat)), c.`stat_value8`),
    c.`stat_value9` = IF(c.`stat_value9` > 0,
        GREATEST(1, ROUND(c.`stat_value9` * @k_stat)), c.`stat_value9`),
    c.`stat_value10` = IF(c.`stat_value10` > 0,
        GREATEST(1, ROUND(c.`stat_value10` * @k_stat)), c.`stat_value10`),
    c.`dmg_min1` = IF(c.`dmg_min1` > 0,
        GREATEST(1, ROUND(c.`dmg_min1` * @k_dmg)), c.`dmg_min1`),
    c.`dmg_max1` = IF(c.`dmg_max1` > 0,
        GREATEST(1, ROUND(c.`dmg_max1` * @k_dmg)), c.`dmg_max1`),
    c.`dmg_min2` = IF(c.`dmg_min2` > 0,
        GREATEST(1, ROUND(c.`dmg_min2` * @k_dmg)), c.`dmg_min2`),
    c.`dmg_max2` = IF(c.`dmg_max2` > 0,
        GREATEST(1, ROUND(c.`dmg_max2` * @k_dmg)), c.`dmg_max2`),
    c.`armor` = IF(c.`armor` > 0,
        GREATEST(1, ROUND(c.`armor` * @k_dmg)), c.`armor`)
WHERE c.`ap_band` < 10;

UPDATE `ap_copy` c
SET c.`stat_value1` = IF(c.`stat_value1` > 0,
        GREATEST(1, ROUND(c.`stat_value1` * @k_stat_top)), c.`stat_value1`),
    c.`stat_value2` = IF(c.`stat_value2` > 0,
        GREATEST(1, ROUND(c.`stat_value2` * @k_stat_top)), c.`stat_value2`),
    c.`stat_value3` = IF(c.`stat_value3` > 0,
        GREATEST(1, ROUND(c.`stat_value3` * @k_stat_top)), c.`stat_value3`),
    c.`stat_value4` = IF(c.`stat_value4` > 0,
        GREATEST(1, ROUND(c.`stat_value4` * @k_stat_top)), c.`stat_value4`),
    c.`stat_value5` = IF(c.`stat_value5` > 0,
        GREATEST(1, ROUND(c.`stat_value5` * @k_stat_top)), c.`stat_value5`),
    c.`stat_value6` = IF(c.`stat_value6` > 0,
        GREATEST(1, ROUND(c.`stat_value6` * @k_stat_top)), c.`stat_value6`),
    c.`stat_value7` = IF(c.`stat_value7` > 0,
        GREATEST(1, ROUND(c.`stat_value7` * @k_stat_top)), c.`stat_value7`),
    c.`stat_value8` = IF(c.`stat_value8` > 0,
        GREATEST(1, ROUND(c.`stat_value8` * @k_stat_top)), c.`stat_value8`),
    c.`stat_value9` = IF(c.`stat_value9` > 0,
        GREATEST(1, ROUND(c.`stat_value9` * @k_stat_top)), c.`stat_value9`),
    c.`stat_value10` = IF(c.`stat_value10` > 0,
        GREATEST(1, ROUND(c.`stat_value10` * @k_stat_top)), c.`stat_value10`),
    c.`dmg_min1` = IF(c.`dmg_min1` > 0,
        GREATEST(1, ROUND(c.`dmg_min1` * @k_dmg_top)), c.`dmg_min1`),
    c.`dmg_max1` = IF(c.`dmg_max1` > 0,
        GREATEST(1, ROUND(c.`dmg_max1` * @k_dmg_top)), c.`dmg_max1`),
    c.`dmg_min2` = IF(c.`dmg_min2` > 0,
        GREATEST(1, ROUND(c.`dmg_min2` * @k_dmg_top)), c.`dmg_min2`),
    c.`dmg_max2` = IF(c.`dmg_max2` > 0,
        GREATEST(1, ROUND(c.`dmg_max2` * @k_dmg_top)), c.`dmg_max2`),
    c.`armor` = IF(c.`armor` > 0,
        GREATEST(1, ROUND(c.`armor` * @k_dmg_top)), c.`armor`)
WHERE c.`ap_band` >= 10;

-- Стрижка записывается в таблицу, а не остаётся в @-переменных этого файла.
-- ЗАЧЕМ. Величину вставки считает v42 как треть бюджета ТОЙ вещи, в которую
-- камень ляжет, - а вещь эта пострижена вот здесь. Пока числа стояли только в
-- двух местах сразу (здесь множитель, там замер по ванильным вещам), они
-- расходились: замер давал бюджет непостриженной рейдовой вещи, камень выходил
-- вдвое тяжелее задуманного, и «треть бюджета» на верхней полосе обращалась
-- в две трети. Один список на одно правило - иначе лестницы разъезжаются
-- (тем же способом здесь уже дважды ломались пул и чертежи).
CREATE TABLE IF NOT EXISTS `ap_band_trim` (
  `band`   TINYINT UNSIGNED NOT NULL,
  `k_stat` FLOAT NOT NULL,
  `k_dmg`  FLOAT NOT NULL,
  PRIMARY KEY (`band`)
);
DELETE FROM `ap_band_trim`;
INSERT INTO `ap_band_trim` (`band`, `k_stat`, `k_dmg`)
SELECT b.`idx`,
       IF(b.`idx` >= 10, @k_stat_top, @k_stat),
       IF(b.`idx` >= 10, @k_dmg_top,  @k_dmg)
FROM `ap_band` b;

ALTER TABLE `ap_copy` DROP COLUMN `ap_new_entry`, DROP COLUMN `ap_new_name`,
                      DROP COLUMN `ap_type_id`, DROP COLUMN `ap_band`,
                      DROP COLUMN `ap_q`;

INSERT IGNORE INTO `item_template` SELECT * FROM `ap_copy`;

-- --------------------------------------------------------------------------
-- 6. Рецепты: по одному на «тип + полоса»
-- --------------------------------------------------------------------------
-- Номера рецептов сетки берутся из СВОЕГО угла - ниже 183000, - а не «следом
-- за наибольшим»: наибольший здесь геройская заготовка (её блок 183000-184999),
-- и сетка заезжала прямо в него. А прогон заготовок сносит свой блок целиком,
-- по номеру, - и в первый же раз унёс с собой 116 рецептов сетки и 1202 эскиза
-- на них.
SELECT COALESCE(MAX(`id`), 999) INTO @rid FROM `ap_recipe` WHERE `id` < 183000;

DROP TEMPORARY TABLE IF EXISTS `ap_rec`;
CREATE TEMPORARY TABLE `ap_rec` (
  `type_id`   INT UNSIGNED NOT NULL,
  `band`      TINYINT UNSIGNED NOT NULL,
  `recipe_id` INT UNSIGNED NOT NULL,
  `qmin`      TINYINT UNSIGNED NOT NULL,
  `qmax`      TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (`type_id`, `band`)
);

INSERT INTO `ap_rec` (`type_id`, `band`, `recipe_id`, `qmin`, `qmax`)
SELECT `type_id`, `band`,
       @rid + ROW_NUMBER() OVER (ORDER BY `type_id`, `band`),
       `qmin`, `qmax`
FROM (SELECT `type_id`, `band`, MIN(`q`) AS `qmin`, MAX(`q`) AS `qmax`
      FROM `ap_grid` GROUP BY `type_id`, `band`) g;

INSERT INTO `ap_recipe`
  (`id`, `type_id`, `name_ru`, `req_skill`, `teach_item`,
   `quality_min`, `quality_max`, `enabled`, `acquire`)
SELECT r.`recipe_id`, r.`type_id`,
       CONCAT(CASE n.`gender` WHEN 'f' THEN b.`adj_f`
                              WHEN 'n' THEN b.`adj_n`
                              ELSE b.`adj_m` END, ' ', n.`noun`),
       b.`skill`, 0, r.`qmin`, r.`qmax`, 1, 'forge'
FROM `ap_rec` r
JOIN `ap_band` b ON b.`idx` = r.`band`
JOIN `ap_noun` n ON n.`type_id` = r.`type_id`;

-- ЦЕНА НАБОРА (решение владельца 2026-09-15). До этого дня металл стоил ровно
-- два слитка в ячейке на ВСЕХ полосах и у ВСЕХ типов. Выходило вот что:
--
--   * медный клинок и титановый стоили одинаково - по четыре слитка, хотя один
--     это вещь шестого уровня, а другой двести восемьдесят четвёртого;
--   * двуручный топор стоил ВДВОЕ ДЕШЕВЛЕ одноручного меча: у топора в схеме
--     одна обязательная ячейка металла, у меча две;
--   * щит не стоил металла вовсе. У него обязательных ячеек металла нет ни
--     одной, и титановый щит собирался из деревяшки и куска кожи.
--
-- Мерка взята у самой игры: замер 145 ванильных рецептов кузнечного дела на
-- наши типы даёт 6 слитков на предмет медной полосы, 9 на железной, 18-20 на
-- мифриловой и ториевой, 12-15 на полосах Лича; по типам медиана идёт от 22 у
-- древкового и 17-18 у двуручного до 12 у кинжала и 9 у щита. Наши числа стоят
-- на этом уровне или ниже: у нас ковка ещё может не удаться, а изделие - это
-- половина пути, его потом доводят камнями.
--
-- Считается в два множителя:
--
--     слитков на ковку = metal_count полосы * вес типа
--
-- и эта сумма делится по ячейкам металла, которые рецепт называет. Дерево и
-- кожа остаются по одному: дерево покупается у торговца, кожа снимается, и
-- цена всё равно лежит в металле.
--
-- ВАЖНО ПРО ПОЛОСУ 11. Четыре слитка титановой стали - это не описка: каждый
-- такой слиток сам стоит трёх титановых плюс три извечных, то есть 24 единицы
-- титановой руды и 12 извечных на ковку. Титановая полоса (12) при двадцати
-- слитках стоит 40 единиц руды и извечных не требует - так верхняя полоса
-- остаётся дороже предыдущей, не меняя названий материалов.
DROP TEMPORARY TABLE IF EXISTS `ap_mass`;
CREATE TEMPORARY TABLE `ap_mass` (
  `type_id` INT UNSIGNED PRIMARY KEY,
  `pct`     SMALLINT UNSIGNED NOT NULL
);

INSERT INTO `ap_mass` (`type_id`, `pct`)
SELECT t.`id`,
       CASE t.`code`
            WHEN 'polearm' THEN 150   -- древко и наконечник
            WHEN 'sword2h' THEN 150
            WHEN 'axe2h'   THEN 150
            WHEN 'mace2h'  THEN 150
            WHEN 'dagger'  THEN 70    -- меньше металла, чем на что бы то ни было
            WHEN 'shield'  THEN 70
            ELSE 100 END
FROM `ap_item_type` t
WHERE t.`enabled` = 1;

-- ПО СКОЛЬКИМ ЯЧЕЙКАМ РАЗЛОЖИТЬ. Обязательных ячеек металла у типа от нуля
-- (щит) до двух (меч, кинжал, древковое), а цена наверху доходит до тридцати
-- слитков. Класть тридцать в одну ячейку нельзя: РУЧНОЙ счётчик в аддоне
-- упирается в двадцать, и такой рецепт стало бы невозможно угадать - а
-- угадывание это один из трёх равноправных путей к рецепту (§5.4.4).
--
-- Поэтому ячеек берётся столько, чтобы в каждой лежало не больше двадцати:
-- сперва обязательные, а если их не хватает - добираются необязательные того
-- же рода. Остальные необязательные рецепт по-прежнему не называет: они
-- требуют пустоты (§5.4.1) и остаются местом для будущих вариаций.
DROP TEMPORARY TABLE IF EXISTS `ap_metal_cells`;
CREATE TEMPORARY TABLE `ap_metal_cells` (
  `type_id` INT UNSIGNED PRIMARY KEY,
  `req`     TINYINT UNSIGNED NOT NULL,
  `all`     TINYINT UNSIGNED NOT NULL
);

INSERT INTO `ap_metal_cells` (`type_id`, `req`, `all`)
SELECT p.`type_id`, SUM(p.`required` = 1), COUNT(1)
FROM `ap_type_part` p
WHERE p.`part_kind_id` = 1
GROUP BY p.`type_id`;

-- План на рецепт: сколько всего слитков и по скольким ячейкам их разложить.
DROP TEMPORARY TABLE IF EXISTS `ap_metal_plan`;
CREATE TEMPORARY TABLE `ap_metal_plan` (
  `recipe_id` INT UNSIGNED PRIMARY KEY,
  `cells`     TINYINT UNSIGNED NOT NULL,
  `per_cell`  SMALLINT UNSIGNED NOT NULL
);

INSERT INTO `ap_metal_plan` (`recipe_id`, `cells`, `per_cell`)
SELECT pl.`recipe_id`, pl.`cells`,
       LEAST(255, GREATEST(1, CEILING(pl.`total` / pl.`cells`)))
FROM (
  SELECT r.`recipe_id` AS `recipe_id`,
         CEILING(b.`metal_count` * m.`pct` / 100) AS `total`,
         LEAST(c.`all`, GREATEST(1, GREATEST(c.`req`,
               CEILING(CEILING(b.`metal_count` * m.`pct` / 100) / 20)))) AS `cells`
  FROM `ap_rec` r
  JOIN `ap_band` b ON b.`idx` = r.`band`
  JOIN `ap_mass` m ON m.`type_id` = r.`type_id`
  JOIN `ap_metal_cells` c ON c.`type_id` = r.`type_id`
) pl;

-- Ячейки металла нумеруются «сперва обязательные, потом по порядку схемы»:
-- план забирает первые `cells` из этого ряда.
DROP TEMPORARY TABLE IF EXISTS `ap_metal_order`;
CREATE TEMPORARY TABLE `ap_metal_order` (
  `type_id` INT UNSIGNED NOT NULL,
  `idx`     TINYINT UNSIGNED NOT NULL,
  `rn`      TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (`type_id`, `idx`)
);

INSERT INTO `ap_metal_order` (`type_id`, `idx`, `rn`)
SELECT `type_id`, `idx`, `rn` FROM (
  SELECT p.`type_id`, p.`idx`,
         ROW_NUMBER() OVER (PARTITION BY p.`type_id`
                            ORDER BY p.`required` DESC, p.`idx`) AS `rn`
  FROM `ap_type_part` p WHERE p.`part_kind_id` = 1
) x;

-- Металл: по плану.
INSERT INTO `ap_recipe_item` (`recipe_id`, `part_idx`, `item_entry`, `count`)
SELECT r.`recipe_id`, o.`idx`, b.`metal`, pl.`per_cell`
FROM `ap_rec` r
JOIN `ap_band` b ON b.`idx` = r.`band`
JOIN `ap_metal_plan` pl ON pl.`recipe_id` = r.`recipe_id`
JOIN `ap_metal_order` o ON o.`type_id` = r.`type_id` AND o.`rn` <= pl.`cells`;

-- Дерево и кожа: по одному, и только обязательные. Цена системы лежит в
-- металле - дерево покупается у торговца, кожа снимается.
INSERT INTO `ap_recipe_item` (`recipe_id`, `part_idx`, `item_entry`, `count`)
SELECT r.`recipe_id`, p.`idx`,
       CASE p.`part_kind_id` WHEN 2 THEN b.`wood` WHEN 3 THEN b.`leather` END, 1
FROM `ap_rec` r
JOIN `ap_band` b ON b.`idx` = r.`band`
JOIN `ap_type_part` p ON p.`type_id` = r.`type_id` AND p.`required` = 1
WHERE p.`part_kind_id` IN (2, 3);

DROP TEMPORARY TABLE IF EXISTS `ap_mass`;
DROP TEMPORARY TABLE IF EXISTS `ap_metal_cells`;
DROP TEMPORARY TABLE IF EXISTS `ap_metal_plan`;
DROP TEMPORARY TABLE IF EXISTS `ap_metal_order`;

INSERT INTO `ap_recipe_result`
  (`recipe_id`, `quality`, `result_entry`, `pool_lo`, `pool_hi`)
SELECT r.`recipe_id`, g.`q`, g.`new_entry`, 0, 0
FROM `ap_grid` g
JOIN `ap_rec` r ON r.`type_id` = g.`type_id` AND r.`band` = g.`band`;


-- --------------------------------------------------------------------------
-- 6b. Лестница качества обязана идти вверх
-- --------------------------------------------------------------------------
-- Доноры выбираются в каждой клетке сами по себе, и ванильные числа соседних
-- качеств не выстроены в ряд. Замер по 196 парам соседних ступеней сетки:
-- 66 стоят НИЖЕ предыдущей по уровню предмета, 33 несут меньше статов, 58
-- вовсе без статов при непустой предыдущей, 65 требуют МЕНЬШЕГО уровня героя.
-- Для игрока это значит одно: удачный бросок качества в трети случаев даёт
-- вещь хуже, то есть бросок теряет смысл.
--
-- Правим самым мягким способом: не трогаем ничего, пока ступень и так сильнее,
-- а отставшую подтягиваем до предыдущей плюс десятая часть. Вид, имя и полоса
-- не меняются вовсе.
--
-- Мерок теперь четыре, а не одна (решение владельца 2026-09-14, §2.12):
--
--   урон            - средний в секунду, а не верхняя граница: ступени внутри
--                     полосы бывают разной скорости и разброса. Первая версия
--                     мерила по верху, и один кинжал проскочил;
--   броня           - для щита то же, что урон для оружия;
--   статы           - сумма очков. Пустая ступень не тянется множителем (на
--                     ноль не умножишь), она БЕРЁТ набор предыдущей с
--                     прибавкой: иначе безупречная вещь остаётся без статов
--                     при отменной с ними;
--   уровни          - уровень предмета и уровень надевания просто не падают.
--                     Поднимать их незачем: силу несут урон и статы.
--
-- Проходов три, потому что ступеней самое большее четыре, а каждая опирается
-- на УЖЕ подтянутую предыдущую: одним запросом такую цепочку не выразить.
--
-- Множитель считается ОТДЕЛЬНО и кладётся во временную таблицу, а не в сам
-- UPDATE: в MySQL второе присваивание видит уже изменённое первое, и формула,
-- где число зависит от нескольких колонок, посчиталась бы по наполовину новой
-- строке.
--
-- Правка ограничена блоком генератора (181000-182999): ручные основы владельца
-- живут ниже и под общее правило не идут.

-- ---- ступень 2: не слабее ступени 1 ----------------------------

-- Урон.
DROP TEMPORARY TABLE IF EXISTS `ap_fix`;
CREATE TEMPORARY TABLE `ap_fix` AS
SELECT cur.`entry` AS `entry`,
       ((prv.`dmg_min1` + prv.`dmg_max1`) / GREATEST(prv.`delay`, 1) * 1.10)
       / GREATEST((cur.`dmg_min1` + cur.`dmg_max1`) / GREATEST(cur.`delay`, 1),
                  0.0001) AS `k`
FROM `ap_recipe_result` rc
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 1
JOIN `item_template` cur ON cur.`entry` = rc.`result_entry`
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
WHERE rc.`quality` = 2
  AND cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`dmg_max1` > 0 AND prv.`dmg_max1` > 0
  AND (cur.`dmg_min1` + cur.`dmg_max1`) / GREATEST(cur.`delay`, 1)
      < (prv.`dmg_min1` + prv.`dmg_max1`) / GREATEST(prv.`delay`, 1) * 1.10;

UPDATE `item_template` it
JOIN `ap_fix` f ON f.`entry` = it.`entry`
SET it.`dmg_min1` = it.`dmg_min1` * f.`k`,
    it.`dmg_max1` = it.`dmg_max1` * f.`k`;

-- Броня: для щита то же, что урон для оружия.
UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 2
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 1
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET cur.`armor` = ROUND(prv.`armor` * 1.10)
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`armor` > 0 AND prv.`armor` > 0
  AND cur.`armor` < prv.`armor` * 1.10;

-- Статы, случай первый: ступень без статов БЕРЁТ набор предыдущей с прибавкой.
-- Множителем такую не вытянуть - умножать нечего. Сюда же попадает ступень с
-- ванильным ШТРАФОМ в минус (донор безупречного осквернённого меча нёс -25):
-- у неё сумма статов тоже не положительна, а множитель сделал бы штраф
-- меньше, то есть вещь лучше.
UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 2
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 1
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET
    cur.`stat_type1` = prv.`stat_type1`,
    cur.`stat_value1` = CEILING(prv.`stat_value1` * 1.10),
    cur.`stat_type2` = prv.`stat_type2`,
    cur.`stat_value2` = CEILING(prv.`stat_value2` * 1.10),
    cur.`stat_type3` = prv.`stat_type3`,
    cur.`stat_value3` = CEILING(prv.`stat_value3` * 1.10),
    cur.`stat_type4` = prv.`stat_type4`,
    cur.`stat_value4` = CEILING(prv.`stat_value4` * 1.10),
    cur.`stat_type5` = prv.`stat_type5`,
    cur.`stat_value5` = CEILING(prv.`stat_value5` * 1.10),
    cur.`stat_type6` = prv.`stat_type6`,
    cur.`stat_value6` = CEILING(prv.`stat_value6` * 1.10),
    cur.`stat_type7` = prv.`stat_type7`,
    cur.`stat_value7` = CEILING(prv.`stat_value7` * 1.10),
    cur.`stat_type8` = prv.`stat_type8`,
    cur.`stat_value8` = CEILING(prv.`stat_value8` * 1.10),
    cur.`stat_type9` = prv.`stat_type9`,
    cur.`stat_value9` = CEILING(prv.`stat_value9` * 1.10),
    cur.`stat_type10` = prv.`stat_type10`,
    cur.`stat_value10` = CEILING(prv.`stat_value10` * 1.10)
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND ((SELECT `total` FROM `ap_item_budget`
        WHERE `entry` = cur.`entry`)) <= 0
  AND ((SELECT `total` FROM `ap_item_budget`
        WHERE `entry` = prv.`entry`)) > 0;

-- Статы, случай второй: отставшая ступень подтягивается множителем.
DROP TEMPORARY TABLE IF EXISTS `ap_sfix`;
CREATE TEMPORARY TABLE `ap_sfix` AS
SELECT `entry`, (`prv_total` * 1.10) / GREATEST(`cur_total`, 0.0001) AS `k`
FROM (
  SELECT cur.`entry` AS `entry`,
         (SELECT `total` FROM `ap_item_budget`
          WHERE `entry` = cur.`entry`) AS `cur_total`,
         (SELECT `total` FROM `ap_item_budget`
          WHERE `entry` = prv.`entry`) AS `prv_total`
  FROM `ap_recipe_result` rc
  JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                            AND rp.`quality` = 1
  JOIN `item_template` cur ON cur.`entry` = rc.`result_entry`
  JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
  WHERE rc.`quality` = 2
    AND cur.`entry` BETWEEN 181000 AND 182999
) t
WHERE `cur_total` > 0 AND `cur_total` < `prv_total` * 1.10;

UPDATE `item_template` it
JOIN `ap_sfix` f ON f.`entry` = it.`entry`
SET
    it.`stat_value1` = IF(it.`stat_value1` > 0,
        GREATEST(1, ROUND(it.`stat_value1` * f.`k`)),
        it.`stat_value1`),
    it.`stat_value2` = IF(it.`stat_value2` > 0,
        GREATEST(1, ROUND(it.`stat_value2` * f.`k`)),
        it.`stat_value2`),
    it.`stat_value3` = IF(it.`stat_value3` > 0,
        GREATEST(1, ROUND(it.`stat_value3` * f.`k`)),
        it.`stat_value3`),
    it.`stat_value4` = IF(it.`stat_value4` > 0,
        GREATEST(1, ROUND(it.`stat_value4` * f.`k`)),
        it.`stat_value4`),
    it.`stat_value5` = IF(it.`stat_value5` > 0,
        GREATEST(1, ROUND(it.`stat_value5` * f.`k`)),
        it.`stat_value5`),
    it.`stat_value6` = IF(it.`stat_value6` > 0,
        GREATEST(1, ROUND(it.`stat_value6` * f.`k`)),
        it.`stat_value6`),
    it.`stat_value7` = IF(it.`stat_value7` > 0,
        GREATEST(1, ROUND(it.`stat_value7` * f.`k`)),
        it.`stat_value7`),
    it.`stat_value8` = IF(it.`stat_value8` > 0,
        GREATEST(1, ROUND(it.`stat_value8` * f.`k`)),
        it.`stat_value8`),
    it.`stat_value9` = IF(it.`stat_value9` > 0,
        GREATEST(1, ROUND(it.`stat_value9` * f.`k`)),
        it.`stat_value9`),
    it.`stat_value10` = IF(it.`stat_value10` > 0,
        GREATEST(1, ROUND(it.`stat_value10` * f.`k`)),
        it.`stat_value10`);

-- Уровень предмета и уровень надевания просто не падают: поднимать их незачем,
-- силу несут урон и статы.
UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 2
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 1
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET cur.`ItemLevel` = prv.`ItemLevel`
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`ItemLevel` < prv.`ItemLevel`;

UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 2
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 1
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET cur.`RequiredLevel` = prv.`RequiredLevel`
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`RequiredLevel` < prv.`RequiredLevel`;

-- ---- ступень 3: не слабее ступени 2 ----------------------------

-- Урон.
DROP TEMPORARY TABLE IF EXISTS `ap_fix`;
CREATE TEMPORARY TABLE `ap_fix` AS
SELECT cur.`entry` AS `entry`,
       ((prv.`dmg_min1` + prv.`dmg_max1`) / GREATEST(prv.`delay`, 1) * 1.10)
       / GREATEST((cur.`dmg_min1` + cur.`dmg_max1`) / GREATEST(cur.`delay`, 1),
                  0.0001) AS `k`
FROM `ap_recipe_result` rc
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 2
JOIN `item_template` cur ON cur.`entry` = rc.`result_entry`
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
WHERE rc.`quality` = 3
  AND cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`dmg_max1` > 0 AND prv.`dmg_max1` > 0
  AND (cur.`dmg_min1` + cur.`dmg_max1`) / GREATEST(cur.`delay`, 1)
      < (prv.`dmg_min1` + prv.`dmg_max1`) / GREATEST(prv.`delay`, 1) * 1.10;

UPDATE `item_template` it
JOIN `ap_fix` f ON f.`entry` = it.`entry`
SET it.`dmg_min1` = it.`dmg_min1` * f.`k`,
    it.`dmg_max1` = it.`dmg_max1` * f.`k`;

-- Броня: для щита то же, что урон для оружия.
UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 3
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 2
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET cur.`armor` = ROUND(prv.`armor` * 1.10)
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`armor` > 0 AND prv.`armor` > 0
  AND cur.`armor` < prv.`armor` * 1.10;

-- Статы, случай первый: ступень без статов БЕРЁТ набор предыдущей с прибавкой.
-- Множителем такую не вытянуть - умножать нечего. Сюда же попадает ступень с
-- ванильным ШТРАФОМ в минус (донор безупречного осквернённого меча нёс -25):
-- у неё сумма статов тоже не положительна, а множитель сделал бы штраф
-- меньше, то есть вещь лучше.
UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 3
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 2
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET
    cur.`stat_type1` = prv.`stat_type1`,
    cur.`stat_value1` = CEILING(prv.`stat_value1` * 1.10),
    cur.`stat_type2` = prv.`stat_type2`,
    cur.`stat_value2` = CEILING(prv.`stat_value2` * 1.10),
    cur.`stat_type3` = prv.`stat_type3`,
    cur.`stat_value3` = CEILING(prv.`stat_value3` * 1.10),
    cur.`stat_type4` = prv.`stat_type4`,
    cur.`stat_value4` = CEILING(prv.`stat_value4` * 1.10),
    cur.`stat_type5` = prv.`stat_type5`,
    cur.`stat_value5` = CEILING(prv.`stat_value5` * 1.10),
    cur.`stat_type6` = prv.`stat_type6`,
    cur.`stat_value6` = CEILING(prv.`stat_value6` * 1.10),
    cur.`stat_type7` = prv.`stat_type7`,
    cur.`stat_value7` = CEILING(prv.`stat_value7` * 1.10),
    cur.`stat_type8` = prv.`stat_type8`,
    cur.`stat_value8` = CEILING(prv.`stat_value8` * 1.10),
    cur.`stat_type9` = prv.`stat_type9`,
    cur.`stat_value9` = CEILING(prv.`stat_value9` * 1.10),
    cur.`stat_type10` = prv.`stat_type10`,
    cur.`stat_value10` = CEILING(prv.`stat_value10` * 1.10)
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND ((SELECT `total` FROM `ap_item_budget`
        WHERE `entry` = cur.`entry`)) <= 0
  AND ((SELECT `total` FROM `ap_item_budget`
        WHERE `entry` = prv.`entry`)) > 0;

-- Статы, случай второй: отставшая ступень подтягивается множителем.
DROP TEMPORARY TABLE IF EXISTS `ap_sfix`;
CREATE TEMPORARY TABLE `ap_sfix` AS
SELECT `entry`, (`prv_total` * 1.10) / GREATEST(`cur_total`, 0.0001) AS `k`
FROM (
  SELECT cur.`entry` AS `entry`,
         (SELECT `total` FROM `ap_item_budget`
          WHERE `entry` = cur.`entry`) AS `cur_total`,
         (SELECT `total` FROM `ap_item_budget`
          WHERE `entry` = prv.`entry`) AS `prv_total`
  FROM `ap_recipe_result` rc
  JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                            AND rp.`quality` = 2
  JOIN `item_template` cur ON cur.`entry` = rc.`result_entry`
  JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
  WHERE rc.`quality` = 3
    AND cur.`entry` BETWEEN 181000 AND 182999
) t
WHERE `cur_total` > 0 AND `cur_total` < `prv_total` * 1.10;

UPDATE `item_template` it
JOIN `ap_sfix` f ON f.`entry` = it.`entry`
SET
    it.`stat_value1` = IF(it.`stat_value1` > 0,
        GREATEST(1, ROUND(it.`stat_value1` * f.`k`)),
        it.`stat_value1`),
    it.`stat_value2` = IF(it.`stat_value2` > 0,
        GREATEST(1, ROUND(it.`stat_value2` * f.`k`)),
        it.`stat_value2`),
    it.`stat_value3` = IF(it.`stat_value3` > 0,
        GREATEST(1, ROUND(it.`stat_value3` * f.`k`)),
        it.`stat_value3`),
    it.`stat_value4` = IF(it.`stat_value4` > 0,
        GREATEST(1, ROUND(it.`stat_value4` * f.`k`)),
        it.`stat_value4`),
    it.`stat_value5` = IF(it.`stat_value5` > 0,
        GREATEST(1, ROUND(it.`stat_value5` * f.`k`)),
        it.`stat_value5`),
    it.`stat_value6` = IF(it.`stat_value6` > 0,
        GREATEST(1, ROUND(it.`stat_value6` * f.`k`)),
        it.`stat_value6`),
    it.`stat_value7` = IF(it.`stat_value7` > 0,
        GREATEST(1, ROUND(it.`stat_value7` * f.`k`)),
        it.`stat_value7`),
    it.`stat_value8` = IF(it.`stat_value8` > 0,
        GREATEST(1, ROUND(it.`stat_value8` * f.`k`)),
        it.`stat_value8`),
    it.`stat_value9` = IF(it.`stat_value9` > 0,
        GREATEST(1, ROUND(it.`stat_value9` * f.`k`)),
        it.`stat_value9`),
    it.`stat_value10` = IF(it.`stat_value10` > 0,
        GREATEST(1, ROUND(it.`stat_value10` * f.`k`)),
        it.`stat_value10`);

-- Уровень предмета и уровень надевания просто не падают: поднимать их незачем,
-- силу несут урон и статы.
UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 3
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 2
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET cur.`ItemLevel` = prv.`ItemLevel`
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`ItemLevel` < prv.`ItemLevel`;

UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 3
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 2
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET cur.`RequiredLevel` = prv.`RequiredLevel`
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`RequiredLevel` < prv.`RequiredLevel`;

-- ---- ступень 4: не слабее ступени 3 ----------------------------

-- Урон.
DROP TEMPORARY TABLE IF EXISTS `ap_fix`;
CREATE TEMPORARY TABLE `ap_fix` AS
SELECT cur.`entry` AS `entry`,
       ((prv.`dmg_min1` + prv.`dmg_max1`) / GREATEST(prv.`delay`, 1) * 1.10)
       / GREATEST((cur.`dmg_min1` + cur.`dmg_max1`) / GREATEST(cur.`delay`, 1),
                  0.0001) AS `k`
FROM `ap_recipe_result` rc
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 3
JOIN `item_template` cur ON cur.`entry` = rc.`result_entry`
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
WHERE rc.`quality` = 4
  AND cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`dmg_max1` > 0 AND prv.`dmg_max1` > 0
  AND (cur.`dmg_min1` + cur.`dmg_max1`) / GREATEST(cur.`delay`, 1)
      < (prv.`dmg_min1` + prv.`dmg_max1`) / GREATEST(prv.`delay`, 1) * 1.10;

UPDATE `item_template` it
JOIN `ap_fix` f ON f.`entry` = it.`entry`
SET it.`dmg_min1` = it.`dmg_min1` * f.`k`,
    it.`dmg_max1` = it.`dmg_max1` * f.`k`;

-- Броня: для щита то же, что урон для оружия.
UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 4
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 3
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET cur.`armor` = ROUND(prv.`armor` * 1.10)
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`armor` > 0 AND prv.`armor` > 0
  AND cur.`armor` < prv.`armor` * 1.10;

-- Статы, случай первый: ступень без статов БЕРЁТ набор предыдущей с прибавкой.
-- Множителем такую не вытянуть - умножать нечего. Сюда же попадает ступень с
-- ванильным ШТРАФОМ в минус (донор безупречного осквернённого меча нёс -25):
-- у неё сумма статов тоже не положительна, а множитель сделал бы штраф
-- меньше, то есть вещь лучше.
UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 4
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 3
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET
    cur.`stat_type1` = prv.`stat_type1`,
    cur.`stat_value1` = CEILING(prv.`stat_value1` * 1.10),
    cur.`stat_type2` = prv.`stat_type2`,
    cur.`stat_value2` = CEILING(prv.`stat_value2` * 1.10),
    cur.`stat_type3` = prv.`stat_type3`,
    cur.`stat_value3` = CEILING(prv.`stat_value3` * 1.10),
    cur.`stat_type4` = prv.`stat_type4`,
    cur.`stat_value4` = CEILING(prv.`stat_value4` * 1.10),
    cur.`stat_type5` = prv.`stat_type5`,
    cur.`stat_value5` = CEILING(prv.`stat_value5` * 1.10),
    cur.`stat_type6` = prv.`stat_type6`,
    cur.`stat_value6` = CEILING(prv.`stat_value6` * 1.10),
    cur.`stat_type7` = prv.`stat_type7`,
    cur.`stat_value7` = CEILING(prv.`stat_value7` * 1.10),
    cur.`stat_type8` = prv.`stat_type8`,
    cur.`stat_value8` = CEILING(prv.`stat_value8` * 1.10),
    cur.`stat_type9` = prv.`stat_type9`,
    cur.`stat_value9` = CEILING(prv.`stat_value9` * 1.10),
    cur.`stat_type10` = prv.`stat_type10`,
    cur.`stat_value10` = CEILING(prv.`stat_value10` * 1.10)
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND ((SELECT `total` FROM `ap_item_budget`
        WHERE `entry` = cur.`entry`)) <= 0
  AND ((SELECT `total` FROM `ap_item_budget`
        WHERE `entry` = prv.`entry`)) > 0;

-- Статы, случай второй: отставшая ступень подтягивается множителем.
DROP TEMPORARY TABLE IF EXISTS `ap_sfix`;
CREATE TEMPORARY TABLE `ap_sfix` AS
SELECT `entry`, (`prv_total` * 1.10) / GREATEST(`cur_total`, 0.0001) AS `k`
FROM (
  SELECT cur.`entry` AS `entry`,
         (SELECT `total` FROM `ap_item_budget`
          WHERE `entry` = cur.`entry`) AS `cur_total`,
         (SELECT `total` FROM `ap_item_budget`
          WHERE `entry` = prv.`entry`) AS `prv_total`
  FROM `ap_recipe_result` rc
  JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                            AND rp.`quality` = 3
  JOIN `item_template` cur ON cur.`entry` = rc.`result_entry`
  JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
  WHERE rc.`quality` = 4
    AND cur.`entry` BETWEEN 181000 AND 182999
) t
WHERE `cur_total` > 0 AND `cur_total` < `prv_total` * 1.10;

UPDATE `item_template` it
JOIN `ap_sfix` f ON f.`entry` = it.`entry`
SET
    it.`stat_value1` = IF(it.`stat_value1` > 0,
        GREATEST(1, ROUND(it.`stat_value1` * f.`k`)),
        it.`stat_value1`),
    it.`stat_value2` = IF(it.`stat_value2` > 0,
        GREATEST(1, ROUND(it.`stat_value2` * f.`k`)),
        it.`stat_value2`),
    it.`stat_value3` = IF(it.`stat_value3` > 0,
        GREATEST(1, ROUND(it.`stat_value3` * f.`k`)),
        it.`stat_value3`),
    it.`stat_value4` = IF(it.`stat_value4` > 0,
        GREATEST(1, ROUND(it.`stat_value4` * f.`k`)),
        it.`stat_value4`),
    it.`stat_value5` = IF(it.`stat_value5` > 0,
        GREATEST(1, ROUND(it.`stat_value5` * f.`k`)),
        it.`stat_value5`),
    it.`stat_value6` = IF(it.`stat_value6` > 0,
        GREATEST(1, ROUND(it.`stat_value6` * f.`k`)),
        it.`stat_value6`),
    it.`stat_value7` = IF(it.`stat_value7` > 0,
        GREATEST(1, ROUND(it.`stat_value7` * f.`k`)),
        it.`stat_value7`),
    it.`stat_value8` = IF(it.`stat_value8` > 0,
        GREATEST(1, ROUND(it.`stat_value8` * f.`k`)),
        it.`stat_value8`),
    it.`stat_value9` = IF(it.`stat_value9` > 0,
        GREATEST(1, ROUND(it.`stat_value9` * f.`k`)),
        it.`stat_value9`),
    it.`stat_value10` = IF(it.`stat_value10` > 0,
        GREATEST(1, ROUND(it.`stat_value10` * f.`k`)),
        it.`stat_value10`);

-- Уровень предмета и уровень надевания просто не падают: поднимать их незачем,
-- силу несут урон и статы.
UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 4
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 3
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET cur.`ItemLevel` = prv.`ItemLevel`
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`ItemLevel` < prv.`ItemLevel`;

UPDATE `item_template` cur
JOIN `ap_recipe_result` rc ON rc.`result_entry` = cur.`entry`
                          AND rc.`quality` = 4
JOIN `ap_recipe_result` rp ON rp.`recipe_id` = rc.`recipe_id`
                          AND rp.`quality` = 3
JOIN `item_template` prv ON prv.`entry` = rp.`result_entry`
SET cur.`RequiredLevel` = prv.`RequiredLevel`
WHERE cur.`entry` BETWEEN 181000 AND 182999
  AND cur.`RequiredLevel` < prv.`RequiredLevel`;

DROP TEMPORARY TABLE IF EXISTS `ap_fix`;
DROP TEMPORARY TABLE IF EXISTS `ap_sfix`;

-- --------------------------------------------------------------------------
-- 6c. Лестница ПОЛОС тоже идёт вверх
-- --------------------------------------------------------------------------
-- 6b выправила ступени ВНУТРИ полосы, но сами полосы в ряд не выстроены:
-- доноры выбираются в каждой клетке сами по себе, и замер показал 61 пару, где
-- следующая полоса того же типа и качества СЛАБЕЕ предыдущей - кобальтовый
-- клинок несёт 87 очков статов, саронитовый 67, а навык для него нужен выше.
-- Для игрока это значит, что тратить полосу на «следующий» рецепт незачем.
--
-- Правило то же, что у ступеней: не трогаем, пока полоса и так сильнее, а
-- отставшую подтягиваем. Порог здесь скромнее (плюс двадцатая часть вместо
-- десятой): между полосами и так стоит переход эпохи, раздувать его не нужно.
--
-- Цепочки проходов не требуется, и это не экономия, а арифметика: планка для
-- полосы - это НАКОПИТЕЛЬНЫЙ МАКСИМУМ по предыдущим полосам, а он считается
-- одним окном. Подтягивать к уже подтянутому здесь нечего: мы поднимаем до
-- «не слабее лучшего из пройденного», а не «на десятую часть выше соседа».
DROP TEMPORARY TABLE IF EXISTS `ap_bandstep`;
CREATE TEMPORARY TABLE `ap_bandstep` AS
SELECT r.`type_id` AS `type_id`, rr.`quality` AS `q`, b.`idx` AS `band`,
       rr.`result_entry` AS `entry`,
       (SELECT `total` FROM `ap_item_budget`
        WHERE `entry` = it.`entry`) AS `stats`,
       (it.`dmg_min1` + it.`dmg_max1`) / GREATEST(it.`delay`, 1) AS `dps`,
       it.`armor` AS `armor`,
       it.`RequiredLevel` AS `req`
FROM `ap_recipe_result` rr
JOIN `ap_recipe` r ON r.`id` = rr.`recipe_id` AND r.`acquire` = 'forge'
JOIN `item_template` it ON it.`entry` = rr.`result_entry`
JOIN `ap_band` b ON it.`ItemLevel` BETWEEN b.`lo` AND b.`hi`
WHERE rr.`result_entry` BETWEEN 181000 AND 182999;

-- ПУСТАЯ СТУПЕНЬ БЕРЁТ НАБОР У СВОЕЙ ЖЕ КЛЕТКИ ПОЛОСОЙ НИЖЕ (2026-09-17).
--
-- Прежде здесь стояло «полосу без статов не поднимаем: брать набор у соседней
-- значило бы переносить чужие статы через эпоху». Возражение верное, но выбор
-- был не между своим набором и чужим, а между чужим и НИКАКИМ: ступень
-- качества выше обычной выходила с нулём статов и парой пустых гнёзд.
--
-- Первый проход донора (раздел 3) закрывает такие клетки там, где в игре есть
-- из чего: 239 клеток из 269. Остальные тридцать - это места, где ВСЁ зелёное
-- оружие полосы живёт суффиксом, и фиксированные статы взять просто неоткуда.
-- Там набор и берётся у той же клетки полосой ниже, поднятый на двадцатую
-- часть. «Ловкость мифрилового клинка в кориевом» - это ровно тот стат, что
-- носит соседняя ступень того же оружия, и он честнее пустоты.
--
-- Временная таблица открывается в запросе только один раз (mysql иначе
-- откажет), поэтому источник ищется по её копии.
DROP TEMPORARY TABLE IF EXISTS `ap_bandstep2`;
CREATE TEMPORARY TABLE `ap_bandstep2` AS SELECT * FROM `ap_bandstep`;

DROP TEMPORARY TABLE IF EXISTS `ap_bandfill`;
CREATE TEMPORARY TABLE `ap_bandfill` (
  `entry` INT UNSIGNED NOT NULL PRIMARY KEY,
  `src`   INT UNSIGNED NULL
);

INSERT INTO `ap_bandfill` (`entry`, `src`)
SELECT s.`entry`,
       (SELECT s2.`entry` FROM `ap_bandstep2` s2
        WHERE s2.`type_id` = s.`type_id` AND s2.`q` = s.`q`
          AND s2.`band` < s.`band` AND s2.`stats` > 0
        ORDER BY s2.`band` DESC LIMIT 1)
FROM `ap_bandstep` s
WHERE s.`q` >= 2 AND s.`stats` <= 0;

DELETE FROM `ap_bandfill` WHERE `src` IS NULL;

UPDATE `item_template` cur
JOIN `ap_bandfill` f ON f.`entry` = cur.`entry`
JOIN `item_template` prv ON prv.`entry` = f.`src`
SET cur.`stat_type1`   = prv.`stat_type1`,
    cur.`stat_value1`  = CEILING(prv.`stat_value1` * 1.05),
    cur.`stat_type2`   = prv.`stat_type2`,
    cur.`stat_value2`  = CEILING(prv.`stat_value2` * 1.05),
    cur.`stat_type3`   = prv.`stat_type3`,
    cur.`stat_value3`  = CEILING(prv.`stat_value3` * 1.05),
    cur.`stat_type4`   = prv.`stat_type4`,
    cur.`stat_value4`  = CEILING(prv.`stat_value4` * 1.05),
    cur.`stat_type5`   = prv.`stat_type5`,
    cur.`stat_value5`  = CEILING(prv.`stat_value5` * 1.05),
    cur.`stat_type6`   = prv.`stat_type6`,
    cur.`stat_value6`  = CEILING(prv.`stat_value6` * 1.05),
    cur.`stat_type7`   = prv.`stat_type7`,
    cur.`stat_value7`  = CEILING(prv.`stat_value7` * 1.05),
    cur.`stat_type8`   = prv.`stat_type8`,
    cur.`stat_value8`  = CEILING(prv.`stat_value8` * 1.05),
    cur.`stat_type9`   = prv.`stat_type9`,
    cur.`stat_value9`  = CEILING(prv.`stat_value9` * 1.05),
    cur.`stat_type10`  = prv.`stat_type10`,
    cur.`stat_value10` = CEILING(prv.`stat_value10` * 1.05);

-- Снимок пересчитывается: дальше по нему считается планка полосы, и
-- наполненная ступень обязана войти в неё уже со своими числами.
UPDATE `ap_bandstep` s
JOIN `ap_bandfill` f ON f.`entry` = s.`entry`
JOIN `ap_item_budget` b ON b.`entry` = s.`entry`
SET s.`stats` = b.`total`;

DROP TEMPORARY TABLE IF EXISTS `ap_bandstep2`;
DROP TEMPORARY TABLE IF EXISTS `ap_bandfill`;

DROP TEMPORARY TABLE IF EXISTS `ap_bandfloor`;
CREATE TEMPORARY TABLE `ap_bandfloor` AS
SELECT `entry`, `stats`, `dps`, `armor`, `req`,
       MAX(`req`) OVER (PARTITION BY `type_id`, `q` ORDER BY `band`
                        ROWS BETWEEN UNBOUNDED PRECEDING
                                 AND 1 PRECEDING) AS `req_floor`,
       MAX(`stats`) OVER (PARTITION BY `type_id`, `q` ORDER BY `band`
                          ROWS BETWEEN UNBOUNDED PRECEDING
                                   AND 1 PRECEDING) AS `stats_floor`,
       MAX(`dps`) OVER (PARTITION BY `type_id`, `q` ORDER BY `band`
                        ROWS BETWEEN UNBOUNDED PRECEDING
                                 AND 1 PRECEDING) AS `dps_floor`,
       MAX(`armor`) OVER (PARTITION BY `type_id`, `q` ORDER BY `band`
                          ROWS BETWEEN UNBOUNDED PRECEDING
                                   AND 1 PRECEDING) AS `armor_floor`
FROM `ap_bandstep`;

-- Урон.
DROP TEMPORARY TABLE IF EXISTS `ap_fix`;
CREATE TEMPORARY TABLE `ap_fix` AS
SELECT `entry`, (`dps_floor` * 1.05) / GREATEST(`dps`, 0.0001) AS `k`
FROM `ap_bandfloor`
WHERE `dps` > 0 AND `dps_floor` IS NOT NULL AND `dps` < `dps_floor` * 1.05;

UPDATE `item_template` it
JOIN `ap_fix` f ON f.`entry` = it.`entry`
SET it.`dmg_min1` = it.`dmg_min1` * f.`k`,
    it.`dmg_max1` = it.`dmg_max1` * f.`k`;

-- Броня щита.
UPDATE `item_template` it
JOIN `ap_bandfloor` bf ON bf.`entry` = it.`entry`
SET it.`armor` = ROUND(bf.`armor_floor` * 1.05)
WHERE it.`armor` > 0 AND bf.`armor_floor` IS NOT NULL
  AND it.`armor` < bf.`armor_floor` * 1.05;

-- Статы: отставшая полоса тянется множителем.
--
-- Полоса, где статов НЕТ ВОВСЕ, не поднимается: подтянуть нечего, а брать
-- набор у предыдущей полосы значило бы переносить чужие статы через эпоху -
-- «ловкость мифрилового клинка» в кориевый. Такие ступени и так редки и лежат
-- внизу, где числа крошечные; их лечит не лестница, а донор.
DROP TEMPORARY TABLE IF EXISTS `ap_sfix`;
CREATE TEMPORARY TABLE `ap_sfix` AS
SELECT `entry`, (`stats_floor` * 1.05) / GREATEST(`stats`, 0.0001) AS `k`
FROM `ap_bandfloor`
WHERE `stats` > 0 AND `stats_floor` IS NOT NULL
  AND `stats` < `stats_floor` * 1.05;

UPDATE `item_template` it
JOIN `ap_sfix` f ON f.`entry` = it.`entry`
SET
    it.`stat_value1` = IF(it.`stat_value1` > 0,
        GREATEST(1, ROUND(it.`stat_value1` * f.`k`)),
        it.`stat_value1`),
    it.`stat_value2` = IF(it.`stat_value2` > 0,
        GREATEST(1, ROUND(it.`stat_value2` * f.`k`)),
        it.`stat_value2`),
    it.`stat_value3` = IF(it.`stat_value3` > 0,
        GREATEST(1, ROUND(it.`stat_value3` * f.`k`)),
        it.`stat_value3`),
    it.`stat_value4` = IF(it.`stat_value4` > 0,
        GREATEST(1, ROUND(it.`stat_value4` * f.`k`)),
        it.`stat_value4`),
    it.`stat_value5` = IF(it.`stat_value5` > 0,
        GREATEST(1, ROUND(it.`stat_value5` * f.`k`)),
        it.`stat_value5`),
    it.`stat_value6` = IF(it.`stat_value6` > 0,
        GREATEST(1, ROUND(it.`stat_value6` * f.`k`)),
        it.`stat_value6`),
    it.`stat_value7` = IF(it.`stat_value7` > 0,
        GREATEST(1, ROUND(it.`stat_value7` * f.`k`)),
        it.`stat_value7`),
    it.`stat_value8` = IF(it.`stat_value8` > 0,
        GREATEST(1, ROUND(it.`stat_value8` * f.`k`)),
        it.`stat_value8`),
    it.`stat_value9` = IF(it.`stat_value9` > 0,
        GREATEST(1, ROUND(it.`stat_value9` * f.`k`)),
        it.`stat_value9`),
    it.`stat_value10` = IF(it.`stat_value10` > 0,
        GREATEST(1, ROUND(it.`stat_value10` * f.`k`)),
        it.`stat_value10`);

-- Уровень надевания. Внутри рецепта он уже не падает (6b), а между полосами
-- падал у 21 ступени: «Отменный кориевый меч» 138-го уровня предметов
-- надевался с первого, потому что таким был его донор, а сосед полосой ниже
-- требовал шестьдесят третьего. Планка та же накопительная.
UPDATE `item_template` it
JOIN `ap_bandfloor` bf ON bf.`entry` = it.`entry`
SET it.`RequiredLevel` = bf.`req_floor`
WHERE bf.`req_floor` IS NOT NULL
  AND it.`RequiredLevel` < bf.`req_floor`;

DROP TEMPORARY TABLE IF EXISTS `ap_bandstep`;
DROP TEMPORARY TABLE IF EXISTS `ap_bandfloor`;
DROP TEMPORARY TABLE IF EXISTS `ap_fix`;
DROP TEMPORARY TABLE IF EXISTS `ap_sfix`;
-- --------------------------------------------------------------------------
-- 6d. Уровень надевания не бывает нулевым
-- --------------------------------------------------------------------------
-- §5.5 говорит: уровень надевания - свойство результата, и ставит его человек.
-- Верно для рецептов, заведённых руками; сетка же копирует его у донора, и
-- если донор молчит, молчит и копия. Молчащих оказалось 16, и среди них
-- «Отменный кобальтовый кинжал»: уровень предмета 154, урон 82 в секунду,
-- надевается с ПЕРВОГО уровня. Кузнец восьмидесятого уровня кует такое и
-- отдаёт твинку - ковка ведь свободно торгуется (§1).
--
-- Ноль и есть признак того, что донор ничего не сказал: у настоящей вещи
-- уровень надевания стоит всегда. Нулям - и только им - его назначает
-- `ap_ilvl_level`, та самая таблица «уровень предмета -> уровень героя».
-- Донорские значения при этом не трогаются: игра расставила их точнее нашей
-- лестницы (аренная вещь 154-го уровня надевается с семидесятого, а не с
-- семьдесят пятого), и спорить с ней здесь не о чем.
UPDATE `item_template` it
JOIN `ap_recipe_result` rr ON rr.`result_entry` = it.`entry`
SET it.`RequiredLevel` = (
      SELECT MIN(l.`req_level`) FROM `ap_ilvl_level` l
      WHERE l.`ilvl_max` >= it.`ItemLevel`)
WHERE it.`entry` BETWEEN 181000 AND 182999
  AND it.`RequiredLevel` = 0
  AND it.`ItemLevel` > 0
  AND (it.`dmg_max1` > 0 OR it.`armor` > 0);


-- --------------------------------------------------------------------------
-- 7. Слайсы пула и заготовки
-- --------------------------------------------------------------------------
SET @stride := 2048;
SET @seed   := 256;
SET @block  := 1100000;

-- СЛАЙС БЕРЁТСЯ ИЗ СВОБОДНЫХ, А НЕ СЛЕДОМ ЗА ПОСЛЕДНИМ.
--
-- Прежде номер считался как «наибольший занятый плюс шаг», и каждый прогон
-- генератора уводил сетку дальше в блок, бросая прежние слайсы навсегда.
-- Замер после третьего прогона: занято 1329 слайсов, свободного хвоста на 146,
-- а сетке нужно 312 - следующий прогон молча оставил бы две трети ступеней без
-- пула, то есть без единой заготовки. Это и есть цена «повторяемого
-- генератора», которую забыли заплатить.
--
-- Теперь блок нарезан на 1024 клетки по 2048 номеров, и занятой считается та,
-- что пересекается с ЧУЖИМ живым слайсом или содержит выданный номер
-- (`ap_generated_item`). Свои слайсы к этому моменту уже снесены уборкой,
-- значит сетка забирает их обратно - прогон за прогоном по одним и тем же
-- номерам.
--
-- Проверять выданные номера обязательно, даже когда таблица пуста: она пуста
-- ровно до первой доводки на PTR, а слайс, отданный другой основе, показал бы
-- игроку чужую вещь из его же itemcache.wdb.
SET SESSION cte_max_recursion_depth = 2000;

DROP TEMPORARY TABLE IF EXISTS `ap_cellseq`;
CREATE TEMPORARY TABLE `ap_cellseq` (`n` INT UNSIGNED PRIMARY KEY);
INSERT INTO `ap_cellseq`
WITH RECURSIVE `seq` (`n`) AS (
  SELECT 0 UNION ALL SELECT `n` + 1 FROM `seq` WHERE `n` < 1023
)
SELECT `n` FROM `seq`;

DROP TEMPORARY TABLE IF EXISTS `ap_free`;
CREATE TEMPORARY TABLE `ap_free` (
  `rn` INT UNSIGNED PRIMARY KEY,
  `lo` INT UNSIGNED NOT NULL
);

INSERT INTO `ap_free` (`rn`, `lo`)
SELECT ROW_NUMBER() OVER (ORDER BY `lo`), `lo`
FROM (SELECT @block + s.`n` * @stride AS `lo` FROM `ap_cellseq` s) c
WHERE NOT EXISTS (
        SELECT 1 FROM `ap_recipe_result` r
        WHERE r.`pool_lo` > 0
          AND r.`pool_lo` <= c.`lo` + @stride - 1
          AND r.`pool_hi` >= c.`lo`)
  AND NOT EXISTS (
        SELECT 1 FROM `ap_generated_item` g
        WHERE g.`entry` BETWEEN c.`lo` AND c.`lo` + @stride - 1);

DROP TEMPORARY TABLE IF EXISTS `ap_need`;
CREATE TEMPORARY TABLE `ap_need` AS
SELECT `recipe_id`, `quality`,
       ROW_NUMBER() OVER (ORDER BY `recipe_id`, `quality`) AS `rn`
FROM `ap_recipe_result`
WHERE `pool_lo` = 0 AND `result_entry` > 0;

-- Свободных слайсов не хватило - роняем прогон ДО первой вставки. Молчаливый
-- пропуск здесь дороже падения: основа без слайса не доводится вовсе, и узнать
-- об этом можно только в игре.
--
-- Идиома с подготовленным запросом, а не `IF(...)`: имена таблиц MySQL
-- разбирает до выполнения, и ветка `IF` от несуществующего имени не спасает -
-- запрос падал бы ВСЕГДА.
SELECT COUNT(*) INTO @need FROM `ap_need`;
SELECT COUNT(*) INTO @have FROM `ap_free`;
SET @chk := IF(@have >= @need, 'SELECT 1',
               'SELECT * FROM `ОШИБКА_свободных_слайсов_не_хватило`');
PREPARE `chk` FROM @chk;
EXECUTE `chk`;
DEALLOCATE PREPARE `chk`;

UPDATE `ap_recipe_result` r
JOIN `ap_need` q ON q.`recipe_id` = r.`recipe_id` AND q.`quality` = r.`quality`
JOIN `ap_free` f ON f.`rn` = q.`rn`
SET r.`pool_lo` = f.`lo`,
    r.`pool_hi` = f.`lo` + @stride - 1;

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

INSERT INTO `ap_slice`
SELECT r.`pool_lo`, b.`class`, b.`subclass`, b.`SoundOverrideSubclass`,
       b.`InventoryType`, b.`Material`, b.`Sheath`, b.`displayid`
FROM `ap_recipe_result` r
JOIN `ap_need` q ON q.`recipe_id` = r.`recipe_id` AND q.`quality` = r.`quality`
JOIN `item_template` b ON b.`entry` = r.`result_entry`;

SET SESSION cte_max_recursion_depth = 1000;

DROP TEMPORARY TABLE IF EXISTS `ap_seq`;
CREATE TEMPORARY TABLE `ap_seq` (`n` INT UNSIGNED PRIMARY KEY);
INSERT INTO `ap_seq`
WITH RECURSIVE `seq` (`n`) AS (
  SELECT 0 UNION ALL SELECT `n` + 1 FROM `seq` WHERE `n` < @seed - 1
)
SELECT `n` FROM `seq`;

-- Заготовки помечены ITEM_FLAG_DEPRECATED (0x10): попади такая строка игроку до
-- выдачи, она будет мусором в сумке, а не работающим предметом.
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
DROP TEMPORARY TABLE IF EXISTS `ap_free`;
DROP TEMPORARY TABLE IF EXISTS `ap_need`;
DROP TEMPORARY TABLE IF EXISTS `ap_cellseq`;
DROP TEMPORARY TABLE IF EXISTS `ap_copy`;
DROP TEMPORARY TABLE IF EXISTS `ap_look`;
DROP TEMPORARY TABLE IF EXISTS `ap_low`;
DROP TEMPORARY TABLE IF EXISTS `ap_grid`;
DROP TEMPORARY TABLE IF EXISTS `ap_keep`;
DROP TEMPORARY TABLE IF EXISTS `ap_span`;
DROP TEMPORARY TABLE IF EXISTS `ap_cell`;
DROP TEMPORARY TABLE IF EXISTS `ap_rec`;
DROP TEMPORARY TABLE IF EXISTS `ap_noun`;

-- --------------------------------------------------------------------------
-- 8. Эскизы сюда больше не переезжают
-- --------------------------------------------------------------------------
-- Здесь стояла перепривязка учебного «Клыка Тьмы» к бронзовой основе: номера
-- рецептов каждый прогон новые, и ручной эскиз искал свой рецепт по имени.
--
-- Строка снята 2026-09-14, и не как устаревшая, а как ОПАСНАЯ: условие у неё
-- было `WHERE s.result_entry > 0`, то есть под него подходил КАЖДЫЙ эскиз в
-- базе. Прогон сетки перевешивал на бронзовый клинок все эскизы разом - вместе
-- с геройскими, - а следующий за ним прогон `gen-synergies.py` сносил их как
-- ковочные. Так на PTR молча исчезли восемь сотен эскизов геройских заготовок,
-- и заметно это стало только по счётчику книг.
--
-- Заменять нечем и незачем: ручных эскизов у сетки не осталось (§2.6, «учебный
-- Клык Тьмы снят вместе с прочими ручными»), а ковочные эскизы после каждой
-- пересборки сетки выдаёт генератор - порядок прогона сетка -> эскизы -> книги
-- записан в §5.6.

-- Каталог вырос на несколько десятков рецептов: аддон держит его в кэше и без
-- этой строки покажет старый список (§7, «Кэш каталога»).
UPDATE `ap_config` SET `value` = `value` + 1 WHERE `name` = 'catalog_version';
