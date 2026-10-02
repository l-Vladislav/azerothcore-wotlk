-- mod-advanced-professions: добыча версий вставок.
--
-- Версия вставки - копия ванильного камня с окном следующей полосы ilvl.
-- Предметы 185000-185001 даёт admin_panel_items.sql, строки ap_material -
-- mod_advanced_professions_2_data.sql.
--
-- 185000 «Превосходный камень теней»: интеллект +2, полоса 20-35, донор - камень
-- теней 1210 (полоса 1-20).
-- 185001 «Превосходный нефрит»: ловкость +4, полоса 35-50, донор - нефрит 1529
-- (полоса 20-35).
--
-- Где падает камень следующей полосы, донор заменяется версией с прежним
-- шансом. Узел перехода полос делит шанс между донором и версией. Если в узлах
-- выше у стата не было вставки, версия встаёт своей строкой.

-- 185000. Оловянная жила - переход полос: 5 % группы пополам с камнем теней
UPDATE `gameobject_loot_template` SET `Chance` = 2.5 WHERE `Item` = 1210 AND `Entry` IN (1503, 1736, 2627, 18093);
DELETE FROM `gameobject_loot_template` WHERE `Item` = 185000 AND `Entry` IN (1503, 1736, 2627, 18093);
INSERT INTO `gameobject_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
  (1503, 185000, 0, 2.5, 0, 1, 1, 1, 1, 'Tin Vein - Superior Shadowgem'),
  (1736, 185000, 0, 2.5, 0, 1, 1, 1, 1, 'Tin Vein - Superior Shadowgem'),
  (2627, 185000, 0, 2.5, 0, 1, 1, 1, 1, 'Tin Vein - Superior Shadowgem'),
  (18093, 185000, 0, 2.5, 0, 1, 1, 1, 1, 'Tin Vein - Superior Shadowgem');

-- 185000. Оловянная руда: та же доля в группе просвечивания, что у камня теней
DELETE FROM `prospecting_loot_template` WHERE `Item` = 185000 AND `Entry` = 2771;
INSERT INTO `prospecting_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
  (2771, 185000, 0, 0, 0, 1, 1, 1, 2, 'Superior Shadowgem');

-- 185000. Остальные источники мохового агата; оловянные жилы поделены выше
UPDATE `gameobject_loot_template` SET `Item` = 185000, `Comment` = REPLACE(`Comment`, 'Shadowgem', 'Superior Shadowgem')
WHERE `Item` = 1210
  AND `Entry` NOT IN (1503, 1736, 2627, 18093)
  AND `Entry` IN (SELECT `Entry` FROM (SELECT `Entry` FROM `gameobject_loot_template` WHERE `Item` = 1206) `agate`);

UPDATE `creature_loot_template` SET `Item` = 185000, `Comment` = REPLACE(`Comment`, 'Shadowgem', 'Superior Shadowgem')
WHERE `Item` = 1210
  AND `Entry` IN (SELECT `Entry` FROM (SELECT `Entry` FROM `creature_loot_template` WHERE `Item` = 1206) `agate`);

UPDATE `item_loot_template` SET `Item` = 185000, `Comment` = REPLACE(`Comment`, 'Shadowgem', 'Superior Shadowgem')
WHERE `Item` = 1210
  AND `Entry` IN (SELECT `Entry` FROM (SELECT `Entry` FROM `item_loot_template` WHERE `Item` = 1206) `agate`);

UPDATE `reference_loot_template` SET `Item` = 185000, `Comment` = REPLACE(`Comment`, 'Shadowgem', 'Superior Shadowgem')
WHERE `Item` = 1210
  AND `Entry` IN (SELECT `Entry` FROM (SELECT `Entry` FROM `reference_loot_template` WHERE `Item` = 1206) `agate`);

-- 185001. Железное месторождение - переход полос: 5 % группы пополам с нефритом
UPDATE `gameobject_loot_template` SET `Chance` = 2.5 WHERE `Item` = 1529 AND `Entry` = 1505;
DELETE FROM `gameobject_loot_template` WHERE `Item` = 185001 AND `Entry` = 1505;
INSERT INTO `gameobject_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
  (1505, 185001, 0, 2.5, 0, 1, 1, 1, 1, 'Iron Deposit - Superior Jade');

-- 185001. Железная руда: доля в группе просвечивания делится так же
UPDATE `prospecting_loot_template` SET `Chance` = 15 WHERE `Item` = 1529 AND `Entry` = 2772;
DELETE FROM `prospecting_loot_template` WHERE `Item` = 185001 AND `Entry` = 2772;
INSERT INTO `prospecting_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
  (2772, 185001, 0, 15, 0, 1, 1, 1, 2, 'Superior Jade');

-- 185001. Узлы выше железа: ловкости в них не было - своя строка
DELETE FROM `gameobject_loot_template` WHERE `Item` = 185001 AND `Entry` IN (1506, 17939, 1742, 13961, 5045, 17938);
INSERT INTO `gameobject_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
  (1506, 185001, 0, 5, 0, 1, 1, 1, 1, 'Gold Vein - Superior Jade'),
  (17939, 185001, 0, 5, 0, 1, 1, 1, 1, 'Gold Vein - Superior Jade'),
  (1742, 185001, 0, 5, 0, 1, 1, 1, 1, 'Mithril Deposit - Superior Jade'),
  (13961, 185001, 0, 5, 0, 1, 1, 1, 1, 'Mithril Deposit - Superior Jade'),
  (5045, 185001, 0, 5, 0, 1, 1, 1, 1, 'Truesilver Deposit - Superior Jade'),
  (17938, 185001, 0, 5, 0, 1, 1, 1, 1, 'Truesilver Deposit - Superior Jade');

-- 185001. Остальные источники цитрина и аквамарина; железо поделено выше
UPDATE `gameobject_loot_template` SET `Item` = 185001, `Comment` = REPLACE(`Comment`, 'Jade', 'Superior Jade')
WHERE `Item` = 1529
  AND `Entry` <> 1505
  AND `Entry` IN (SELECT `Entry` FROM (SELECT `Entry` FROM `gameobject_loot_template` WHERE `Item` IN (3864, 7909)) `upper`);

UPDATE `creature_loot_template` SET `Item` = 185001, `Comment` = REPLACE(`Comment`, 'Jade', 'Superior Jade')
WHERE `Item` = 1529
  AND `Entry` IN (SELECT `Entry` FROM (SELECT `Entry` FROM `creature_loot_template` WHERE `Item` IN (3864, 7909)) `upper`);

UPDATE `item_loot_template` SET `Item` = 185001, `Comment` = REPLACE(`Comment`, 'Jade', 'Superior Jade')
WHERE `Item` = 1529
  AND `Entry` IN (SELECT `Entry` FROM (SELECT `Entry` FROM `item_loot_template` WHERE `Item` IN (3864, 7909)) `upper`);

UPDATE `pickpocketing_loot_template` SET `Item` = 185001, `Comment` = REPLACE(`Comment`, 'Jade', 'Superior Jade')
WHERE `Item` = 1529
  AND `Entry` IN (SELECT `Entry` FROM (SELECT `Entry` FROM `pickpocketing_loot_template` WHERE `Item` IN (3864, 7909)) `upper`);

UPDATE `reference_loot_template` SET `Item` = 185001, `Comment` = REPLACE(`Comment`, 'Jade', 'Superior Jade')
WHERE `Item` = 1529
  AND `Entry` IN (SELECT `Entry` FROM (SELECT `Entry` FROM `reference_loot_template` WHERE `Item` IN (3864, 7909)) `upper`);
