-- Эскизы «Когтя демона» (85792-85794) сняты: книги 191496-191498 уходят из добычи,
-- в их строки возвращается «Коготь демона» (15240) с исходным шансом - суммой долей трёх книг.
UPDATE `creature_loot_template` SET `Item` = 15240, `Chance` = `Chance` * 3, `Comment` = 'Demon''s Claw' WHERE `Item` = 191496;
DELETE FROM `creature_loot_template` WHERE `Item` IN (191497, 191498);
UPDATE `reference_loot_template` SET `Item` = 15240, `Chance` = `Chance` * 3, `Comment` = 'Demon''s Claw' WHERE `Item` = 191496;
DELETE FROM `reference_loot_template` WHERE `Item` IN (191497, 191498);
