-- mod-advanced-professions: условия добычи именных предметов переходят на строки их книг.
--
-- Книга эскиза заменяет именной предмет в строке добычи существа (сама или
-- через таблицу ссылок номер книги × 10); условие строки (например, прогресс
-- рейда) переходит на книгу, иначе ConditionMgr не находит предмет в таблице.

UPDATE `conditions` c
JOIN `ap_synergy` s ON s.`result_entry` = c.`SourceEntry`
JOIN `creature_loot_template` l ON l.`Entry` = c.`SourceGroup` AND l.`Item` IN (s.`teach_item`, s.`teach_item` * 10)
SET c.`SourceEntry` = l.`Item`
WHERE c.`SourceTypeOrReferenceId` = 1
  AND NOT EXISTS (SELECT 1 FROM `creature_loot_template` o WHERE o.`Entry` = c.`SourceGroup` AND o.`Item` = c.`SourceEntry`);
