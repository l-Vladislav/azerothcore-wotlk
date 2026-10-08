-- mod-worn-drops: предметы несут только основу (броня, урон, блок)
--
-- Бонусы характеристик и эффекты, унаследованные от предмета-донора, снимаются
-- со всех предметов модуля. Повторный запуск ничего не меняет.

UPDATE `item_template` it
JOIN `worn_drop_item` wdi ON wdi.`item_entry` = it.`entry`
SET it.`stat_type1` = 0, it.`stat_value1` = 0, it.`stat_type2` = 0, it.`stat_value2` = 0,
    it.`stat_type3` = 0, it.`stat_value3` = 0, it.`stat_type4` = 0, it.`stat_value4` = 0,
    it.`stat_type5` = 0, it.`stat_value5` = 0, it.`stat_type6` = 0, it.`stat_value6` = 0,
    it.`stat_type7` = 0, it.`stat_value7` = 0, it.`stat_type8` = 0, it.`stat_value8` = 0,
    it.`stat_type9` = 0, it.`stat_value9` = 0, it.`stat_type10` = 0, it.`stat_value10` = 0,
    it.`spellid_1` = 0, it.`spelltrigger_1` = 0, it.`spellcharges_1` = 0, it.`spellppmRate_1` = 0,
    it.`spellcooldown_1` = -1, it.`spellcategory_1` = 0, it.`spellcategorycooldown_1` = -1,
    it.`spellid_2` = 0, it.`spelltrigger_2` = 0, it.`spellcharges_2` = 0, it.`spellppmRate_2` = 0,
    it.`spellcooldown_2` = -1, it.`spellcategory_2` = 0, it.`spellcategorycooldown_2` = -1,
    it.`spellid_3` = 0, it.`spelltrigger_3` = 0, it.`spellcharges_3` = 0, it.`spellppmRate_3` = 0,
    it.`spellcooldown_3` = -1, it.`spellcategory_3` = 0, it.`spellcategorycooldown_3` = -1,
    it.`spellid_4` = 0, it.`spelltrigger_4` = 0, it.`spellcharges_4` = 0, it.`spellppmRate_4` = 0,
    it.`spellcooldown_4` = -1, it.`spellcategory_4` = 0, it.`spellcategorycooldown_4` = -1,
    it.`spellid_5` = 0, it.`spelltrigger_5` = 0, it.`spellcharges_5` = 0, it.`spellppmRate_5` = 0,
    it.`spellcooldown_5` = -1, it.`spellcategory_5` = 0, it.`spellcategorycooldown_5` = -1
WHERE it.`entry` BETWEEN 400000 AND 1099999;
