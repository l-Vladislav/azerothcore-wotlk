-- Предметы панели — выгружено админ-панелью (Каталог предметов).
-- Источник правды — acore_world_ptr.item_template, блоки 120000-129999.
-- Правьте в панели, не здесь: следующая выгрузка перепишет файл.
--
-- Клиентская половина (Item.dbc внутри MPQ) сюда не входит: её
-- выдаёт кнопка «Строка для Item.dbc», сборка MPQ ручная.

DELETE FROM `item_template` WHERE `entry` BETWEEN 120000 AND 129999;
DELETE FROM `item_template_locale` WHERE `ID` BETWEEN 120000 AND 129999;

