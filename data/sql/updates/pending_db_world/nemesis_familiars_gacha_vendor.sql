-- ============================================================================
-- Nemesis Familiar Gacha — rank-gated tavern shop (vendor lists + coin costs)
-- Companion to the NemesisBountyVendorScript gossip submenus (NemesisSystem.cpp):
--   190100 «Общие товары»        (rank 1+): universal bag, Recalibrator, T1
--   190101 «Печати и нашивки»    (rank 2+): all StatBooster consumables T1-T4
--   190102 «Сумки с фамильярами» (rank 3+): 10 element gacha bags
-- The legacy flat vendor 190000 is kept untouched as a config fallback
-- (NemesisSystem.BountyVendor.RankMenus.Enable = 0).
--
-- ItemExtendedCost lives in the SERVER DB-DBC override table
-- itemextendedcost_dbc (loaded into sItemExtendedCostStore at startup).
-- The CLIENT additionally needs rows 100006/100007 merged into its
-- ItemExtendedCost.dbc (see .claude/dbc/ItemExtendedCost_custom.csv) or the
-- vendor price renders incorrectly.
-- ============================================================================

-- STEP 1: adventurer-coin extended costs
-- 100006 = 1 x 110150 (universal bag), 100007 = 5 x 110150 (element bags)
DELETE FROM itemextendedcost_dbc WHERE ID IN (100006, 100007);
INSERT INTO itemextendedcost_dbc (ID, HonorPoints, ArenaPoints, ArenaBracket, ItemID_1, ItemID_2, ItemID_3, ItemID_4, ItemID_5, ItemCount_1, ItemCount_2, ItemCount_3, ItemCount_4, ItemCount_5, RequiredArenaRating, ItemPurchaseGroup) VALUES
(100006, 0, 0, 0, 110150, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0),  -- 1 Монета авантюриста
(100007, 0, 0, 0, 110150, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0);  -- 5 Монет авантюриста

-- STEP 2: vendor lists (virtual npc_vendor entries, no creature_template
-- needed — the fork's IsVendorItemValid creature check is disabled and
-- SendListInventory(guid, vendorEntry) reads the list directly)
DELETE FROM npc_vendor WHERE entry IN (190100, 190101, 190102);

-- 190100 «Общие товары» (rank 1+)
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, VerifiedBuild) VALUES
(190100, 1, 110120, 0, 0, 100006, 0),  -- Сумка Авантюриста (1 монета)
(190100, 2, 41605,  0, 0, 100003, 0),  -- Attribute Recalibrator (20 жетонов)
(190100, 3, 100001, 0, 0, 100001, 0),  -- Рунный точильный камень (T1, 10 жетонов)
(190100, 4, 100005, 0, 0, 100001, 0),  -- Рунная нашивка (T1, 10 жетонов)
(190100, 5, 100009, 0, 0, 100001, 0),  -- Малый тайный пергамент (T1, 10 жетонов)
(190100, 6, 100013, 0, 0, 100001, 0);  -- Малый символ удачи (T1, 10 жетонов)

-- 190101 «Печати и нашивки» — все расходники StatBooster T1-T4 (rank 2+)
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, VerifiedBuild) VALUES
(190101, 1,  100001, 0, 0, 100001, 0),  -- Рунный точильный камень (10)
(190101, 2,  100005, 0, 0, 100001, 0),  -- Рунная нашивка (10)
(190101, 3,  100009, 0, 0, 100001, 0),  -- Малый тайный пергамент (10)
(190101, 4,  100013, 0, 0, 100001, 0),  -- Малый символ удачи (10)
(190101, 5,  100002, 0, 0, 100002, 0),  -- Закаленный точильный камень (15)
(190101, 6,  100006, 0, 0, 100002, 0),  -- Закаленная нашивка (15)
(190101, 7,  100010, 0, 0, 100002, 0),  -- Тайный пергамент (15)
(190101, 8,  100014, 0, 0, 100002, 0),  -- Символ удачи (15)
(190101, 9,  100003, 0, 0, 100003, 0),  -- Отточенный точильный камень (20)
(190101, 10, 100007, 0, 0, 100003, 0),  -- Упрочненная нашивка (20)
(190101, 11, 100011, 0, 0, 100003, 0),  -- Большой тайный пергамент (20)
(190101, 12, 100015, 0, 0, 100003, 0),  -- Большой символ удачи (20)
(190101, 13, 100004, 0, 0, 100004, 0),  -- Мастерский точильный камень (25)
(190101, 14, 100008, 0, 0, 100004, 0),  -- Мастерская нашивка (25)
(190101, 15, 100012, 0, 0, 100004, 0),  -- Превосходный тайный пергамент (25)
(190101, 16, 100016, 0, 0, 100004, 0);  -- Великий символ удачи (25)

-- 190102 «Сумки с фамильярами» — 10 сумок семейств по 5 монет (rank 3+)
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, VerifiedBuild) VALUES
(190102, 1,  110100, 0, 0, 100007, 0),  -- Механический сундук
(190102, 2,  110101, 0, 0, 100007, 0),  -- Огненная сумка
(190102, 3,  110102, 0, 0, 100007, 0),  -- Ледяная сумка
(190102, 4,  110103, 0, 0, 100007, 0),  -- Природная сумка
(190102, 5,  110104, 0, 0, 100007, 0),  -- Светлая сумка
(190102, 6,  110105, 0, 0, 100007, 0),  -- Теневая сумка
(190102, 7,  110106, 0, 0, 100007, 0),  -- Тайная сумка
(190102, 8,  110107, 0, 0, 100007, 0),  -- Демоническая сумка
(190102, 9,  110108, 0, 0, 100007, 0),  -- Звериная сумка
(190102, 10, 110109, 0, 0, 100007, 0);  -- Странная сумка
