-- mod-advanced-professions: цвет книги - цвет того, что из неё выйдет.
--
-- Решение владельца 2026-09-13. Чертежи основ (v33) заводились все белыми, а
-- книги эскизов (v40) упирались в эпик, даже когда учили легендарной вещи. И то,
-- и другое врёт игроку в самом дешёвом месте: цвет предмета в игре - это первое,
-- что читает глаз, ещё до имени.
--
-- Теперь:
--
-- * чертёж основы носит ЛУЧШЕЕ качество своей полосы (`quality_max` рецепта).
--   Саронитовый чертёж, с которого выходит эпик, и выглядит эпическим - а
--   медный, с которого выходит только обычная вещь, остаётся белым;
-- * книга эскиза носит качество своего именного предмета, вплоть до
--   легендарного: потолка больше нет.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §5.4.4.1, §5.6.

UPDATE `item_template` it
JOIN `ap_recipe` r ON r.`teach_item` = it.`entry`
SET it.`Quality` = r.`quality_max`
WHERE it.`entry` BETWEEN 190000 AND 199999;

UPDATE `item_template` it
JOIN `ap_synergy` s ON s.`teach_item` = it.`entry`
JOIN `item_template` pz ON pz.`entry` = s.`result_entry`
SET it.`Quality` = pz.`Quality`
WHERE it.`entry` BETWEEN 190000 AND 199999;

-- Каталог меняется: у книг другой цвет (§7, «Кэш каталога»).
UPDATE `ap_config` SET `value` = `value` + 1 WHERE `name` = 'catalog_version';
