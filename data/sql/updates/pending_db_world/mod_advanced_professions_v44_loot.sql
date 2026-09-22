-- mod-advanced-professions: заготовки и книги ложатся в мир.
--
-- Пункт 10 плана (§11). Заготовок 1026 и книг 2300 - и ни одна никуда не
-- положена: ни один босс их не роняет, ни один торговец не держит. Без этого
-- система существует только в панели: угадать упорядоченный набор из четырёх
-- камней нельзя, а учителя владелец заводить не стал (§«Как рецепт попадает к
-- игроку»), так что добыча - единственный путь.
--
-- ТРИ РАЗДАЧИ, и каждая берёт связь, которая в базе уже есть.
--
--   ЗАГОТОВКА ПАДАЕТ ТАМ ЖЕ, ГДЕ ЕЁ ПРИЗ. У геройской заготовки ровно один
--     эскиз и ровно один исход - именная вещь босса. Значит и место у неё то
--     же: строки добычи приза копируются заготовке с половинным шансом. Ни
--     списка боссов, ни карты подземелий вести не нужно - связь уже описана
--     эскизом;
--   КНИГА ГЕРОЙСКОГО ЭСКИЗА - ОТТУДА ЖЕ, но шансом вровень с призом. Знание
--     распространённее вещи: чаще выпадает «как доделать», реже - «из чего»;
--   КНИГА КОВОЧНОГО ЭСКИЗА - ПО УРОВНЮ СУЩЕСТВ. Приз ковочного эскиза с
--     существ НЕ падает (это вотчина заготовок, §2.6), поэтому места у него
--     нет вовсе. Книги полосы собираются в ссылочную группу, а группа
--     вешается на обычных существ своего уровня - уровень берётся из
--     `ap_ilvl_level`, той самой таблицы «уровень предмета -> уровень героя».
--
-- Ссылочная группа, а не строка на книгу: у бронзовой полосы под сотню
-- эскизов, и вешать каждую книгу на каждое существо значило бы десятки тысяч
-- строк в таблице, которую читают на каждом убийстве. Группа - одна строка на
-- существо, а какая именно книга выпадет, решает бросок внутри группы.
--
-- Блок ссылок 1900000-1909999 свободен (наибольший занятый в базе - 1619100).
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §11 (пункт 10), §2.9, §5.6.

-- --------------------------------------------------------------------------
-- 0. Уборка прошлого прогона
-- --------------------------------------------------------------------------
DELETE FROM `creature_loot_template`
WHERE `Item` BETWEEN 183000 AND 184999 OR `Item` BETWEEN 190000 AND 199999
   OR `Reference` BETWEEN 1900000 AND 1909999;
DELETE FROM `reference_loot_template`
WHERE `Item` BETWEEN 183000 AND 184999 OR `Item` BETWEEN 190000 AND 199999
   OR `Entry` BETWEEN 1900000 AND 1909999;

-- --------------------------------------------------------------------------
-- 1. Заготовка падает там же, где её приз
-- --------------------------------------------------------------------------
-- ШАНС ЗАГОТОВКИ = ШАНС ЕЁ ПРИЗА, ОДИН В ОДИН (решение владельца 2026-09-15:
-- «скопируем шанс дропа с оригинала и пусть пока падает две вещи, для теста»).
--
-- Прежнее правило - «половина призового, но не ниже процента» - на боссах
-- работало, а на мировом дропе разваливалось. У редкой вещи собственный шанс
-- сотые доли процента, половина от него ещё меньше, и срабатывал ПОЛ: заготовка
-- получала свой процент с каждого источника. «Боевой топор лорда Александра»
-- падает с восьми существ на 0.05 % суммарно, а его заготовка выходила на 8 % -
-- в сто шестьдесят раз щедрее вещи, которую из неё доводят. Так вышло у 84
-- заготовок, у 69 из них - двадцатикратно и больше.
--
-- Теперь редкость вещи назначает игра, а не наш пол.
--
-- ДОЛЯ В ГРУППЕ СЧИТАЕТСЯ ОТДЕЛЬНО. У 821 приза из 1026 строка добычи стоит в
-- ГРУППЕ, и `Chance` у неё ноль: долю назначает групповой бросок. Скопировать
-- оттуда ноль нельзя - строка с нулём вне группы не сработает вовсе, и ядро
-- пожалуется в лог. Поэтому у групповой строки берётся её настоящая доля: то,
-- что остаётся группе сверх явных процентов, поделённое на число безшансовых
-- строк.
--
-- Строка по-прежнему кладётся СВОЕЙ группой (`GroupId` = 0): чужой групповой
-- бросок трогать нельзя, иначе мы отнимем долю у вещей, которые там уже лежат.
-- Приз при этом продолжает падать сам по себе - пока обе вещи выпадают
-- независимо, это и есть «падает две вещи» из решения.
DROP TEMPORARY TABLE IF EXISTS `ap_hero_drop`;
CREATE TEMPORARY TABLE `ap_hero_drop` (
  `blank` INT UNSIGNED NOT NULL,
  `book`  INT UNSIGNED NOT NULL,
  `prize` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`blank`),
  KEY (`prize`)
);

INSERT IGNORE INTO `ap_hero_drop` (`blank`, `book`, `prize`)
SELECT rr.`result_entry`, s.`teach_item`, s.`result_entry`
FROM `ap_recipe` r
JOIN `ap_recipe_result` rr ON rr.`recipe_id` = r.`id`
JOIN `ap_synergy` s ON s.`recipe_id` = r.`id`
WHERE r.`acquire` = 'drop' AND s.`enabled` = 1;

-- Настоящая доля приза в каждой его строке добычи: явный процент, а у
-- групповой строки - остаток группы, делённый на число безшансовых строк.
-- Ниже сотой доли процента не опускаемся: такую строку ядро принимает, но
-- смысла в ней нет.
--
-- ССЫЛОЧНЫЕ СТРОКИ СЮДА НЕ ВХОДЯТ, и это главное условие всего файла.
-- В строке добычи с `Reference` > 0 колонка `Item` держит не предмет, а номер
-- ссылочной таблицы, а `Chance` = 100 значит «эту ссылку бросать всегда» - то
-- есть ровно противоположное тому, как её читал прежний запрос. Совпадение
-- номеров делало из «бросить таблицу 35014» - «предмет 35014 падает со
-- стопроцентным шансом», и заготовка получала отдельную строку на 100 %:
--
--     Император Дагран Тауриссан (ЧР, ~55) - «Заготовка: Молоток жестокого
--     гладиатора» (ilvl 154, награда четвёртого сезона арены), 100 %;
--     Mushgog, The Razza, Skarr (элиты Тернистой долины, ~50) - «Большой меч
--     жестокого гладиатора», 100 %.
--
-- 164 строки по семи призам, и все - вершина PvP-награды за элиту, которую
-- бьют полусотней уровней раньше. Настоящая доля приза в ссылочной таблице
-- считается ниже, в разделе kind = 1, и берётся уже оттуда.
--
-- ПОТОЛОК ВЕРНУЛСЯ. Правило «шанс копируется у приза» задумано снизу - чтобы
-- редкая вещь не получала щедрую заготовку, - но сверху его никто не держал,
-- и 169 строк заготовок стояли на двадцати процентах и выше. Заготовка не
-- обязана быть щедрее призового броска, но и превращаться в гарантированную
-- добычу ей незачем: это расходник, а не вещь.
DROP TEMPORARY TABLE IF EXISTS `ap_prize_share`;
CREATE TEMPORARY TABLE `ap_prize_share` (
  `kind`   TINYINT UNSIGNED NOT NULL COMMENT '0 - существа, 1 - ссылочная',
  `Entry`  INT UNSIGNED NOT NULL,
  `Item`   INT UNSIGNED NOT NULL,
  `chance` FLOAT NOT NULL,
  PRIMARY KEY (`kind`, `Entry`, `Item`)
);

INSERT INTO `ap_prize_share` (`kind`, `Entry`, `Item`, `chance`)
SELECT 0, cl.`Entry`, cl.`Item`,
       LEAST(20, GREATEST(0.01, IF(cl.`Chance` > 0, cl.`Chance`,
                         (100 - COALESCE(g.`taken`, 0))
                         / GREATEST(COALESCE(g.`free`, 1), 1))))
FROM `creature_loot_template` cl
JOIN `ap_hero_drop` h ON h.`prize` = cl.`Item`
                     AND cl.`Reference` = 0
LEFT JOIN (SELECT `Entry`, `GroupId`,
                  SUM(IF(`Chance` > 0, `Chance`, 0)) AS `taken`,
                  SUM(`Chance` = 0) AS `free`
           FROM `creature_loot_template`
           WHERE `GroupId` > 0 GROUP BY `Entry`, `GroupId`) g
       ON g.`Entry` = cl.`Entry` AND g.`GroupId` = cl.`GroupId`;

INSERT INTO `ap_prize_share` (`kind`, `Entry`, `Item`, `chance`)
SELECT 1, rl.`Entry`, rl.`Item`,
       LEAST(20, GREATEST(0.01, IF(rl.`Chance` > 0, rl.`Chance`,
                         (100 - COALESCE(g.`taken`, 0))
                         / GREATEST(COALESCE(g.`free`, 1), 1))))
FROM `reference_loot_template` rl
JOIN `ap_hero_drop` h ON h.`prize` = rl.`Item`
                     AND rl.`Reference` = 0
LEFT JOIN (SELECT `Entry`, `GroupId`,
                  SUM(IF(`Chance` > 0, `Chance`, 0)) AS `taken`,
                  SUM(`Chance` = 0) AS `free`
           FROM `reference_loot_template`
           WHERE `GroupId` > 0 GROUP BY `Entry`, `GroupId`) g
       ON g.`Entry` = rl.`Entry` AND g.`GroupId` = rl.`GroupId`;

INSERT IGNORE INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
   `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT sh.`Entry`, h.`blank`, 0, sh.`chance`, 0, 1, 0, 1, 1,
       CONCAT('Верстак: заготовка - ', COALESCE(pl.`Name`, pz.`name`))
FROM `ap_hero_drop` h
JOIN `item_template` pz ON pz.`entry` = h.`prize`
LEFT JOIN `item_template_locale` pl ON pl.`ID` = pz.`entry`
                                  AND pl.`locale` = 'ruRU'
JOIN `ap_prize_share` sh ON sh.`kind` = 0 AND sh.`Item` = h.`prize`;

INSERT IGNORE INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
   `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT sh.`Entry`, h.`blank`, 0, sh.`chance`, 0, 1, 0, 1, 1,
       CONCAT('Верстак: заготовка - ', COALESCE(pl.`Name`, pz.`name`))
FROM `ap_hero_drop` h
JOIN `item_template` pz ON pz.`entry` = h.`prize`
LEFT JOIN `item_template_locale` pl ON pl.`ID` = pz.`entry`
                                  AND pl.`locale` = 'ruRU'
JOIN `ap_prize_share` sh ON sh.`kind` = 1 AND sh.`Item` = h.`prize`;

-- --------------------------------------------------------------------------
-- 2. Книга геройского эскиза - оттуда же, но чаще
-- --------------------------------------------------------------------------
-- Вровень с призом, но не ниже полутора процентов: знание попадается не реже
-- вещи. Иначе заготовка без книги превращается в тупик - угадать предрешённый
-- набор из трёх-четырёх камней со значимым порядком нельзя.
--
-- ДОЛЯ БЕРЁТСЯ ИЗ `ap_prize_share`, ТОЙ ЖЕ, ЧТО У ЗАГОТОВКИ. Прежде книга
-- читала сырой `cl.Chance`, а заготовка - посчитанную долю группы, и правило
-- переворачивалось само собой: у групповой строки сырой `Chance` равен нулю,
-- значит книга садилась на пол в 1.5 %, а заготовка получала настоящую долю
-- в двадцать. Замер: в 237 парах из 388 (61 %) заготовка выпадала ЧАЩЕ своей
-- книги - 18.9 % против 7.6 % в среднем, - то есть ровно наоборот замыслу.
--
-- Теперь обе половины считают по одной таблице, и «книга не реже заготовки»
-- держится само: пол книги выше, потолок выше, а тело - то же число.
INSERT IGNORE INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
   `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT sh.`Entry`, h.`book`, 0,
       LEAST(25, GREATEST(1.5, sh.`chance`)), 0, 1, 0, 1, 1,
       CONCAT('Верстак: книга эскиза - ', COALESCE(pl.`Name`, pz.`name`))
FROM `ap_hero_drop` h
JOIN `item_template` pz ON pz.`entry` = h.`prize`
LEFT JOIN `item_template_locale` pl ON pl.`ID` = pz.`entry`
                                  AND pl.`locale` = 'ruRU'
JOIN `ap_prize_share` sh ON sh.`kind` = 0 AND sh.`Item` = h.`prize`
WHERE h.`book` > 0;

INSERT IGNORE INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
   `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT sh.`Entry`, h.`book`, 0,
       LEAST(25, GREATEST(1.5, sh.`chance`)), 0, 1, 0, 1, 1,
       CONCAT('Верстак: книга эскиза - ', COALESCE(pl.`Name`, pz.`name`))
FROM `ap_hero_drop` h
JOIN `item_template` pz ON pz.`entry` = h.`prize`
LEFT JOIN `item_template_locale` pl ON pl.`ID` = pz.`entry`
                                  AND pl.`locale` = 'ruRU'
JOIN `ap_prize_share` sh ON sh.`kind` = 1 AND sh.`Item` = h.`prize`
WHERE h.`book` > 0;

-- --------------------------------------------------------------------------
-- 3. Книги ковочных эскизов: группа на полосу и качество
-- --------------------------------------------------------------------------
-- Полоса у книги берётся от рецепта (все его ступени лежат в одной полосе),
-- качество - от приза: эскиз «через ступень» выдаёт вещь качеством выше своей
-- основы, и книга принадлежит той вещи, которую обещает.
DROP TEMPORARY TABLE IF EXISTS `ap_book`;
CREATE TEMPORARY TABLE `ap_book` (
  `book` INT UNSIGNED NOT NULL,
  `band` TINYINT UNSIGNED NOT NULL,
  `q`    TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (`book`),
  KEY (`band`, `q`)
);

INSERT IGNORE INTO `ap_book` (`book`, `band`, `q`)
SELECT s.`teach_item`, MIN(b.`idx`), p.`Quality`
FROM `ap_synergy` s
JOIN `ap_recipe` r ON r.`id` = s.`recipe_id` AND r.`acquire` = 'forge'
JOIN `item_template` p ON p.`entry` = s.`result_entry`
JOIN `ap_recipe_result` rr ON rr.`recipe_id` = r.`id`
JOIN `item_template` bb ON bb.`entry` = rr.`result_entry`
JOIN `ap_band` b ON bb.`ItemLevel` BETWEEN b.`lo` AND b.`hi`
WHERE s.`enabled` = 1 AND s.`teach_item` > 0
GROUP BY s.`teach_item`, p.`Quality`;

DROP TEMPORARY TABLE IF EXISTS `ap_book_group`;
CREATE TEMPORARY TABLE `ap_book_group` (
  `band` TINYINT UNSIGNED NOT NULL,
  `q`    TINYINT UNSIGNED NOT NULL,
  `ref`  INT UNSIGNED NOT NULL,
  `cnt`  INT UNSIGNED NOT NULL,
  PRIMARY KEY (`band`, `q`),
  KEY (`ref`)
);

INSERT INTO `ap_book_group` (`band`, `q`, `ref`, `cnt`)
SELECT `band`, `q`, 1900000 + `band` * 10 + `q`, COUNT(*)
FROM `ap_book` GROUP BY `band`, `q`;

-- Внутри группы бросок выбирает ОДНУ книгу: доли равные, сумма - сто
-- процентов. Группа (`GroupId` = 1) для того и нужна, чтобы с существа падала
-- одна книга, а не вся полоса разом.
INSERT IGNORE INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
   `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT g.`ref`, k.`book`, 0, ROUND(100.0 / g.`cnt`, 3), 0, 1, 1, 1, 1,
       CONCAT('Верстак: книги эскизов - ', b.`adj_f`, ' полоса, ',
              ELT(k.`q`, 'обычное', 'необычное', 'редкое', 'эпическое'))
FROM `ap_book` k
JOIN `ap_book_group` g ON g.`band` = k.`band` AND g.`q` = k.`q`
JOIN `ap_band` b ON b.`idx` = k.`band`;

-- --------------------------------------------------------------------------
-- 4. Группа вешается на существ своего уровня
-- --------------------------------------------------------------------------
-- Уровень героя для полосы берётся из `ap_ilvl_level` - таблицы «уровень
-- предмета -> уровень героя», которая до сих пор в ковке не использовалась.
-- Полоса 65-89 по ней приходится на героев 55-63, полоса 233-284 - на
-- восьмидесятый.
DROP TEMPORARY TABLE IF EXISTS `ap_band_level`;
DROP TEMPORARY TABLE IF EXISTS `ap_plan_group`;
CREATE TEMPORARY TABLE `ap_band_level` (
  `band`   TINYINT UNSIGNED PRIMARY KEY,
  `lvl_lo` TINYINT UNSIGNED NOT NULL,
  `lvl_hi` TINYINT UNSIGNED NOT NULL
);

INSERT INTO `ap_band_level` (`band`, `lvl_lo`, `lvl_hi`)
SELECT b.`idx`,
       (SELECT MIN(l.`req_level`) FROM `ap_ilvl_level` l
        WHERE l.`ilvl_max` >= b.`lo`),
       (SELECT MIN(l.`req_level`) FROM `ap_ilvl_level` l
        WHERE l.`ilvl_max` >= b.`hi`)
FROM `ap_band` b;

-- Восемьдесят источников на группу. Больше не нужно: книга и так падает редко,
-- а таблицу добычи читают на каждом убийстве. Отбор идёт по хешу номера -
-- он раскидывает источники по всему миру, но повторяется от прогона к прогону,
-- то есть миграция остаётся предсказуемой.
--
-- Только обычные существа (`rank` = 0): книга ремесла не должна лежать на
-- боссе - его добыча расписана и без нас.
INSERT IGNORE INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
   `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `lootid`, 0, `ref`, 0.4, 0, 1, 0, 1, 1, `note`
FROM (
  SELECT ct.`lootid` AS `lootid`, g.`ref` AS `ref`,
         CONCAT('Верстак: книги эскизов - ', b.`adj_f`, ' полоса, ',
                ELT(g.`q`, 'обычное', 'необычное', 'редкое',
                    'эпическое')) AS `note`,
         ROW_NUMBER() OVER (PARTITION BY g.`ref`
                            ORDER BY MD5(ct.`entry`)) AS `rn`
  FROM `ap_book_group` g
  JOIN `ap_band` b ON b.`idx` = g.`band`
  JOIN `ap_band_level` bl ON bl.`band` = g.`band`
  JOIN `creature_template` ct
    ON ct.`rank` = 0 AND ct.`lootid` > 0
   AND ct.`minlevel` BETWEEN bl.`lvl_lo` AND bl.`lvl_hi`
   -- Таблица добычи общая у разных существ: повесив её по одному уровню, мы
   -- ловим заодно и низкоуровневых соседей с тем же `lootid`. Берём только те
   -- таблицы, у которых ВСЕ хозяева в границах полосы.
   AND NOT EXISTS (SELECT 1 FROM `creature_template` c2
                   WHERE c2.`lootid` = ct.`lootid`
                     AND (c2.`minlevel` + 5 < bl.`lvl_lo`
                       OR c2.`minlevel` > bl.`lvl_hi` + 5))
) x WHERE `rn` <= 80;

-- --------------------------------------------------------------------------
-- 4b. Чертежи основ - той же дорогой
-- --------------------------------------------------------------------------
-- Чертёж (`ap_recipe.teach_item`, блок 190000-190999) - входной билет полосы:
-- без него рецепт добывается только угадыванием набора, а на верхних полосах
-- материалов под тысячу. Раздаётся он там же, где книги эскизов, и чуть чаще:
-- знать, ЧТО куётся, игрок должен раньше, чем узнает, во что это доводится.
--
-- Своя группа на полосу (1909000 + полоса), а не общая с эскизами: у полосы
-- под сотню эскизов и всего девять чертежей, и в общей куче чертёж терялся бы.
DROP TEMPORARY TABLE IF EXISTS `ap_plan_group`;
CREATE TEMPORARY TABLE `ap_plan_group` (
  `band` TINYINT UNSIGNED PRIMARY KEY,
  `ref`  INT UNSIGNED NOT NULL,
  `cnt`  INT UNSIGNED NOT NULL
);

INSERT INTO `ap_plan_group` (`band`, `ref`, `cnt`)
SELECT b.`idx`, 1909000 + b.`idx`, COUNT(DISTINCT r.`teach_item`)
FROM `ap_recipe` r
JOIN `ap_recipe_result` rr ON rr.`recipe_id` = r.`id`
JOIN `item_template` bb ON bb.`entry` = rr.`result_entry`
JOIN `ap_band` b ON bb.`ItemLevel` BETWEEN b.`lo` AND b.`hi`
WHERE r.`acquire` = 'forge' AND r.`teach_item` > 0
GROUP BY b.`idx`;

INSERT IGNORE INTO `reference_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
   `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT g.`ref`, x.`teach_item`, 0, ROUND(100.0 / g.`cnt`, 3), 0, 1, 1, 1, 1,
       CONCAT('Верстак: чертежи основ - ', b.`adj_f`, ' полоса')
FROM (
  SELECT DISTINCT r.`teach_item` AS `teach_item`, b.`idx` AS `band`
  FROM `ap_recipe` r
  JOIN `ap_recipe_result` rr ON rr.`recipe_id` = r.`id`
  JOIN `item_template` bb ON bb.`entry` = rr.`result_entry`
  JOIN `ap_band` b ON bb.`ItemLevel` BETWEEN b.`lo` AND b.`hi`
  WHERE r.`acquire` = 'forge' AND r.`teach_item` > 0
) x
JOIN `ap_plan_group` g ON g.`band` = x.`band`
JOIN `ap_band` b ON b.`idx` = x.`band`;

INSERT IGNORE INTO `creature_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
   `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `lootid`, 0, `ref`, 0.6, 0, 1, 0, 1, 1, `note`
FROM (
  SELECT ct.`lootid` AS `lootid`, g.`ref` AS `ref`,
         CONCAT('Верстак: чертежи основ - ', b.`adj_f`,
                ' полоса') AS `note`,
         ROW_NUMBER() OVER (PARTITION BY g.`ref`
                            ORDER BY MD5(ct.`entry`)) AS `rn`
  FROM `ap_plan_group` g
  JOIN `ap_band` b ON b.`idx` = g.`band`
  JOIN `ap_band_level` bl ON bl.`band` = g.`band`
  JOIN `creature_template` ct
    ON ct.`rank` = 0 AND ct.`lootid` > 0
   AND ct.`minlevel` BETWEEN bl.`lvl_lo` AND bl.`lvl_hi`
   -- Таблица добычи общая у разных существ: повесив её по одному уровню, мы
   -- ловим заодно и низкоуровневых соседей с тем же `lootid`. Берём только те
   -- таблицы, у которых ВСЕ хозяева в границах полосы.
   AND NOT EXISTS (SELECT 1 FROM `creature_template` c2
                   WHERE c2.`lootid` = ct.`lootid`
                     AND (c2.`minlevel` + 5 < bl.`lvl_lo`
                       OR c2.`minlevel` > bl.`lvl_hi` + 5))
) x WHERE `rn` <= 80;

-- --------------------------------------------------------------------------
-- 5. Проверки: пустой ответ - сходится
-- --------------------------------------------------------------------------
-- Заготовка без источника - вещь, которой в мире нет; книга без источника -
-- эскиз, который нельзя узнать. И то и другое молчит, пока не спросишь.
SELECT COUNT(*) INTO @blank_nodrop
FROM `ap_hero_drop` h
WHERE NOT EXISTS (SELECT 1 FROM `creature_loot_template` c
                  WHERE c.`Item` = h.`blank`)
  AND NOT EXISTS (SELECT 1 FROM `reference_loot_template` f
                  WHERE f.`Item` = h.`blank`);

SELECT COUNT(*) INTO @book_nodrop
FROM `ap_book` k
WHERE NOT EXISTS (SELECT 1 FROM `reference_loot_template` f
                  WHERE f.`Item` = k.`book`);

SELECT COUNT(*) INTO @group_nohost
FROM `ap_book_group` g
WHERE NOT EXISTS (SELECT 1 FROM `creature_loot_template` c
                  WHERE c.`Reference` = g.`ref`);

SELECT COUNT(*) INTO @plan_nodrop
FROM `ap_recipe` r
WHERE r.`acquire` = 'forge' AND r.`teach_item` > 0
  AND NOT EXISTS (SELECT 1 FROM `reference_loot_template` f
                  WHERE f.`Item` = r.`teach_item`);

SET @chk := IF(@blank_nodrop = 0 AND @book_nodrop = 0 AND @group_nohost = 0
               AND @plan_nodrop = 0,
               'SELECT ''добыча разложена'' AS `проверка`',
               'SELECT 1 FROM `ОШИБКА_заготовка_или_книга_без_источника`');
PREPARE `chk` FROM @chk;
EXECUTE `chk`;
DEALLOCATE PREPARE `chk`;

DROP TEMPORARY TABLE IF EXISTS `ap_hero_drop`;
DROP TEMPORARY TABLE IF EXISTS `ap_prize_share`;
DROP TEMPORARY TABLE IF EXISTS `ap_book`;
DROP TEMPORARY TABLE IF EXISTS `ap_book_group`;
DROP TEMPORARY TABLE IF EXISTS `ap_band_level`;
DROP TEMPORARY TABLE IF EXISTS `ap_plan_group`;
