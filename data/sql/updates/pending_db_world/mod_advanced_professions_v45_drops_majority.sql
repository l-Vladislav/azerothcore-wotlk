-- mod-advanced-professions: вставку добывают, а не заказывают у ювелира.
--
-- РЕШЕНИЕ ВЛАДЕЛЬЦА (2026-09-14): «нужно чтобы дроп был в большинстве случаев.
-- Рецепты с ремесленными материалами оставить можно, но 5-10 % максимум».
--
-- ЧТО НЕ СХОДИЛОСЬ. Замер достижимости по клеткам «полоса + качество» показал,
-- что наверху система опирается на то, чего в мире нет:
--
--     полоса 115-139, зелёная - из 26 материалов в мире не достаётся НИ ОДИН
--     полоса 175-199, синяя   - из 26 материалов ни одного
--     полоса 90-114,  зелёная - один из 28
--
-- Причина простая: выше тория почти вся вставка - это ОГРАНЁННЫЕ самоцветы, а
-- их не добывают, а режут ювелиром. То же и с реагентами чар: пыль, субстанции
-- и осколки получают распылением вещей, в таблицах добычи их нет вовсе
-- (владелец: «пыль от энчанта - так же»). Для игрока без профессии такая
-- клетка пуста, сколько бы строк в ней ни лежало.
--
-- ПРАВИЛО. В каждой клетке ремесленные материалы - меньшинство: не больше
-- десятой части. Остальное - то, за чем можно пойти и принести: добыча с
-- существ и объектов, вскрытие предметов, ссылочные таблицы, рыбалка,
-- торговцы. Ремесленное не выбрасывается совсем - огранённый самоцвет
-- остаётся как дорогой вариант для тех, у кого ювелир под рукой.
--
-- Что остаётся из ремесленного - выбирается не наугад: сперва те статы, у
-- которых добываемых материалов меньше всего. Так квота идёт туда, где от неё
-- есть польза.
--
-- Дыры при этом не образуются: своих камней с добычей заведено 222 (v43), и
-- шесть статов в каждой клетке они держат сами.
--
-- ПОВТОРНЫЙ ПРОГОН. Сперва возвращается то, что миграция сняла в прошлый раз
-- (свой список она помнит в `ap_material_auto_off`), потом правило применяется
-- заново - иначе второй прогон считал бы отключённое отсутствующим и квота
-- поехала бы. Ручное отключение материала в панели при этом переживает прогон:
-- в списке его нет, значит и включать его обратно правило не станет.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §2.12, §2.5.

-- --------------------------------------------------------------------------
-- 0. Чистый лист
-- --------------------------------------------------------------------------
-- Возвращается только то, что сняла САМА миграция: она помнит свой список в
-- `ap_material_auto_off`. Прежде «чистый лист» включал все ванильные вставки
-- подряд - и ручное отключение материала в панели не переживало ближайшего
-- прогона. Теперь решение владельца лежит поверх правила, а не под ним.
CREATE TABLE IF NOT EXISTS `ap_material_auto_off` (
  `entry` INT UNSIGNED NOT NULL PRIMARY KEY
) COMMENT 'что отключило правило «добыча - большинство» (v45)';

-- РАЗОВЫЙ ДОСЕВ. Список завёлся позже самого правила, и первые прогоны сняли
-- четыре с лишним сотни строк, о которых он не знает: не вернув их, следующий
-- прогон считал бы отключённое отсутствующим, и квота поехала бы. До появления
-- списка ВСЁ отключённое среди ванильных вставок снято этим правилом - ручных
-- решений тогда ещё не было, - поэтому досев безопасен, а повторно он ничего
-- не добавит: строки уже в списке.
INSERT IGNORE INTO `ap_material_auto_off` (`entry`)
SELECT m.`entry` FROM `ap_material` m
WHERE m.`role` <> 'base' AND m.`entry` < 100000 AND m.`enabled` = 0;

UPDATE `ap_material` m
JOIN `ap_material_auto_off` a ON a.`entry` = m.`entry`
SET m.`enabled` = 1;

DELETE FROM `ap_material_auto_off`;

-- Свои камни (185000-189999) включаются безусловно: правило их не снимает
-- никогда - они заводились именно как добываемые, - но один из прошлых
-- прогонов успел записать в недостижимые тех, у кого шанс упал ниже порога.
UPDATE `ap_material` SET `enabled` = 1
WHERE `role` <> 'base' AND `entry` BETWEEN 185000 AND 189999;

-- --------------------------------------------------------------------------
-- 1. Кого можно принести из мира
-- --------------------------------------------------------------------------
-- Продукты профессий сюда НЕ входят - ни огранка руды, ни распыление, ни
-- размол: они требуют профессии или чужих рук ровно так же, как сам огранённый
-- самоцвет. Шанс ниже двадцатой доли процента за источник не считается: это не
-- добыча, а лотерея.
--
-- Список источников и порог обязаны совпадать с генератором своих вставок
-- (`tools/gen-own-materials.py`): он по ним решает, какую клетку закрывать
-- копией, а эта миграция - какую ванильную строку снимать со стола. Разойдутся
-- на одну таблицу - и клетка останется без шести статов ровно потому, что
-- каждый считал по-своему (так и случилось со `spell_loot_template`).
DROP TEMPORARY TABLE IF EXISTS `ap_reach`;
CREATE TEMPORARY TABLE `ap_reach` (`entry` INT UNSIGNED PRIMARY KEY);

INSERT IGNORE INTO `ap_reach` (`entry`)
SELECT m.`entry`
FROM `ap_material` m
-- `Reference` = 0 в каждой строке: у строки со ссылкой колонка `Item` держит
-- номер ссылочной ТАБЛИЦЫ, а не предмета, и номера эти живут в одном
-- пространстве с номерами вещей. Совпадение объявляло достижимым то, что
-- не падает нигде.
WHERE m.`role` <> 'base'
  AND (EXISTS (SELECT 1 FROM `creature_loot_template` x
               WHERE x.`Item` = m.`entry` AND x.`Chance` >= 0.05
                 AND x.`Reference` = 0)
    OR EXISTS (SELECT 1 FROM `gameobject_loot_template` x
               WHERE x.`Item` = m.`entry` AND x.`Chance` >= 0.05
                 AND x.`Reference` = 0)
    OR EXISTS (SELECT 1 FROM `item_loot_template` x
               WHERE x.`Item` = m.`entry` AND x.`Chance` >= 0.05
                 AND x.`Reference` = 0)
    OR EXISTS (SELECT 1 FROM `reference_loot_template` x
               WHERE x.`Item` = m.`entry` AND x.`Chance` >= 0.05
                 AND x.`Reference` = 0)
    OR EXISTS (SELECT 1 FROM `fishing_loot_template` x
               WHERE x.`Item` = m.`entry` AND x.`Chance` >= 0.05
                 AND x.`Reference` = 0)
    OR EXISTS (SELECT 1 FROM `spell_loot_template` x
               WHERE x.`Item` = m.`entry` AND x.`Chance` >= 0.05
                 AND x.`Reference` = 0)
    OR EXISTS (SELECT 1 FROM `npc_vendor` v WHERE v.`item` = m.`entry`));

-- --------------------------------------------------------------------------
-- 2. Клетки: сколько добываемого, сколько ремесленного
-- --------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `ap_cellmat`;
CREATE TEMPORARY TABLE `ap_cellmat` (
  `entry` INT UNSIGNED PRIMARY KEY,
  `band`  TINYINT UNSIGNED NOT NULL,
  `q`     TINYINT UNSIGNED NOT NULL,
  `stat`  TINYINT UNSIGNED NOT NULL,
  `drops` TINYINT UNSIGNED NOT NULL,
  KEY (`band`, `q`)
);

INSERT IGNORE INTO `ap_cellmat` (`entry`, `band`, `q`, `stat`, `drops`)
SELECT m.`entry`, b.`idx`, g.`Quality`, m.`stat_type`,
       IF(r.`entry` IS NULL, 0, 1)
FROM `ap_material` m
JOIN `item_template` g ON g.`entry` = m.`entry`
JOIN `ap_band` b ON b.`lo` = m.`ilvl_min`
LEFT JOIN `ap_reach` r ON r.`entry` = m.`entry`
WHERE m.`role` <> 'base' AND m.`enabled` = 1;

DROP TEMPORARY TABLE IF EXISTS `ap_quota`;
CREATE TEMPORARY TABLE `ap_quota` (
  `band` TINYINT UNSIGNED NOT NULL,
  `q`    TINYINT UNSIGNED NOT NULL,
  `keep` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`band`, `q`)
);

-- Десятая часть клетки, но не меньше одного: ремесленное остаётся вариантом,
-- а не исчезает. D добываемых держат долю: keep = CEIL(D / 9) даёт ровно
-- десять процентов от итогового размера клетки.
INSERT INTO `ap_quota` (`band`, `q`, `keep`)
SELECT `band`, `q`, GREATEST(1, CEILING(SUM(`drops`) / 9))
FROM `ap_cellmat` GROUP BY `band`, `q`;

-- Сколько добываемых у каждого стата в клетке: по этому счёту решается, какому
-- стату достанется ремесленная добавка.
DROP TEMPORARY TABLE IF EXISTS `ap_statfill`;
CREATE TEMPORARY TABLE `ap_statfill` (
  `band` TINYINT UNSIGNED NOT NULL,
  `q`    TINYINT UNSIGNED NOT NULL,
  `stat` TINYINT UNSIGNED NOT NULL,
  `n`    INT UNSIGNED NOT NULL,
  PRIMARY KEY (`band`, `q`, `stat`)
);

INSERT INTO `ap_statfill` (`band`, `q`, `stat`, `n`)
SELECT `band`, `q`, `stat`, SUM(`drops`)
FROM `ap_cellmat` GROUP BY `band`, `q`, `stat`;

-- --------------------------------------------------------------------------
-- 3. Кого оставляем из ремесленного
-- --------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `ap_keep`;
CREATE TEMPORARY TABLE `ap_keep` (`entry` INT UNSIGNED PRIMARY KEY);

INSERT IGNORE INTO `ap_keep` (`entry`)
SELECT `entry` FROM (
  SELECT c.`entry`,
         ROW_NUMBER() OVER (PARTITION BY c.`band`, c.`q`
                            ORDER BY COALESCE(sf.`n`, 0), c.`stat`,
                                     c.`entry`) AS `rn`,
         qt.`keep` AS `keep`
  FROM `ap_cellmat` c
  JOIN `ap_quota` qt ON qt.`band` = c.`band` AND qt.`q` = c.`q`
  LEFT JOIN `ap_statfill` sf ON sf.`band` = c.`band` AND sf.`q` = c.`q`
                            AND sf.`stat` = c.`stat`
  WHERE c.`drops` = 0
    -- Мёртвое в квоту не идёт. Правило делит вставки надвое - добываемые и
    -- ремесленные, - а третий случай есть: вещь, которую НЕ добывают и НЕ
    -- делают. Для квоты она выглядела ремесленной, да ещё и желанной: отбор
    -- идёт от статов с наименьшим числом добываемых, а у мёртвой строки
    -- соперников нет. Так два порошка чар, снятых с игры ещё в классике,
    -- заняли по гнезду на полосах 0 и 1 и заперли 16 эскизов намертво.
    -- Список - `ap_dead_item` (v47), новых ищет `tools/audit.py` по Spell.dbc.
    AND NOT EXISTS (SELECT 1 FROM `ap_dead_item` d
                    WHERE d.`entry` = c.`entry`)
) x WHERE `rn` <= `keep`;

-- --------------------------------------------------------------------------
-- 4. Прочее ремесленное уходит со стола
-- --------------------------------------------------------------------------
-- Свой блок не трогается ни при каких числах: он и есть та добыча, ради
-- которой правило затевалось.
UPDATE `ap_material` m
JOIN `ap_cellmat` c ON c.`entry` = m.`entry`
LEFT JOIN `ap_keep` k ON k.`entry` = m.`entry`
SET m.`enabled` = 0
WHERE c.`drops` = 0 AND k.`entry` IS NULL
  AND m.`entry` < 185000;

-- Запоминаем, что сняли именно мы: по этому списку следующий прогон вернёт
-- строки обратно, не тронув ручные решения владельца.
INSERT IGNORE INTO `ap_material_auto_off` (`entry`)
SELECT m.`entry`
FROM `ap_material` m
JOIN `ap_cellmat` c ON c.`entry` = m.`entry`
LEFT JOIN `ap_keep` k ON k.`entry` = m.`entry`
WHERE c.`drops` = 0 AND k.`entry` IS NULL
  AND m.`entry` < 185000 AND m.`enabled` = 0;

-- --------------------------------------------------------------------------
-- 5. Проверки: пустой ответ - сходится
-- --------------------------------------------------------------------------
-- Клетка без шести добываемых статов - это гнездо, которое игроку нечем
-- закрыть; доля ремесленного выше десятой части - это обратно тот перекос, от
-- которого уходили.
SELECT COUNT(*) INTO @thin
FROM (
  SELECT c.`band`, c.`q`
  FROM `ap_cellmat` c
  JOIN `ap_material` m ON m.`entry` = c.`entry` AND m.`enabled` = 1
  WHERE c.`drops` = 1
  GROUP BY c.`band`, c.`q`
  HAVING COUNT(DISTINCT c.`stat`) < 6
) z;

SELECT COUNT(*) INTO @fat
FROM (
  SELECT c.`band`, c.`q`
  FROM `ap_cellmat` c
  JOIN `ap_material` m ON m.`entry` = c.`entry` AND m.`enabled` = 1
  GROUP BY c.`band`, c.`q`
  HAVING SUM(c.`drops` = 0) > CEILING(COUNT(*) * 0.12)
) z;

SET @chk := IF(@thin = 0 AND @fat = 0,
               'SELECT ''добыча - большинство'' AS `проверка`',
               'SELECT 1 FROM `ОШИБКА_клетка_без_добычи_или_перекос_ремесла`');
PREPARE `chk` FROM @chk;
EXECUTE `chk`;
DEALLOCATE PREPARE `chk`;

DROP TEMPORARY TABLE IF EXISTS `ap_reach`;
DROP TEMPORARY TABLE IF EXISTS `ap_cellmat`;
DROP TEMPORARY TABLE IF EXISTS `ap_quota`;
DROP TEMPORARY TABLE IF EXISTS `ap_statfill`;
DROP TEMPORARY TABLE IF EXISTS `ap_keep`;

-- Справочник изменился: аддон держит его в кэше по версии (§7).
UPDATE `ap_config` SET `value` = `value` + 1 WHERE `name` = 'catalog_version';
