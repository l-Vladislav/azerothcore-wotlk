-- ============================================================================
-- Gear Ascension -- kit vendor placement in rank-gated tavern shop
-- Adds 21 profession kits (200000-200020) to the Nemesis innkeeper submenus.
--
-- Rank gating (via existing gossip submenus, no C++ needed):
--   Tier I  kits (-> green,  rank 2+): vendor entry 190101, IEC 100001 (10 x 100017)
--   Tier II kits (-> blue,   rank 3+): vendor entry 190102, IEC 100003 (20 x 100017)
--   Tier III kits (-> purple, rank 4+): vendor entry 190103, IEC 100008 (30 x 100017)
--
-- IEC 100008 = 30 x item 100017 (Жетон немезиды) — NEW for tier III kits.
-- CLIENT NOTE: ItemExtendedCost.dbc must be rebuilt with IEC 100008 for the
-- vendor price to render correctly client-side.
-- See .claude/dbc/ItemExtendedCost_custom.csv (row added for MPQ rebuild).
--
-- Kit categories (7 x 3 tiers = 21 kits):
--   metal:         200000 (I), 200001 (II), 200002 (III)
--   leather:       200003 (I), 200004 (II), 200005 (III)
--   cloth:         200006 (I), 200007 (II), 200008 (III)
--   jewel:         200009 (I), 200010 (II), 200011 (III)
--   weapon_melee:  200012 (I), 200013 (II), 200014 (III)
--   weapon_magic:  200015 (I), 200016 (II), 200017 (III)
--   weapon_ranged: 200018 (I), 200019 (II), 200020 (III)
--
-- Slots appended after existing entries per vendor:
--   190101 current max slot = 4  -> kits at slots 5-11
--   190102 current max slot = 14 -> kits at slots 15-21
--   190103 current max slot = 4  -> kits at slots 5-11
-- ============================================================================

-- STEP 1: New IEC row — 30 x Жетон немезиды for tier III kits
DELETE FROM itemextendedcost_dbc WHERE ID = 100008;
INSERT INTO itemextendedcost_dbc (ID, HonorPoints, ArenaPoints, ArenaBracket, ItemID_1, ItemID_2, ItemID_3, ItemID_4, ItemID_5, ItemCount_1, ItemCount_2, ItemCount_3, ItemCount_4, ItemCount_5, RequiredArenaRating, ItemPurchaseGroup) VALUES
(100008, 0, 0, 0, 100017, 0, 0, 0, 0, 30, 0, 0, 0, 0, 0, 0);  -- 30 Жетонов немезиды

-- STEP 2: Idempotent kit rows — remove any prior placement, then insert.
-- Targets only the kit item IDs; leaves StatBooster + familiar rows untouched.
DELETE FROM npc_vendor WHERE entry IN (190101, 190102, 190103) AND item IN (
    200000, 200001, 200002,
    200003, 200004, 200005,
    200006, 200007, 200008,
    200009, 200010, 200011,
    200012, 200013, 200014,
    200015, 200016, 200017,
    200018, 200019, 200020
);

-- 190101 «Награды охотника» (rank 2+): Tier I kits (-> green), 10 tokens each
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, VerifiedBuild) VALUES
(190101, 5,  200000, 0, 0, 100001, 0),  -- Набор кузнеца I (металл -> необычный)
(190101, 6,  200003, 0, 0, 100001, 0),  -- Набор кожевника I (кожа -> необычный)
(190101, 7,  200006, 0, 0, 100001, 0),  -- Набор портного I (ткань -> необычный)
(190101, 8,  200009, 0, 0, 100001, 0),  -- Набор ювелира I (украшения -> необычный)
(190101, 9,  200012, 0, 0, 100001, 0),  -- Набор оружейника I (ближний бой -> необычный)
(190101, 10, 200015, 0, 0, 100001, 0),  -- Набор чародея I (магическое оружие -> необычный)
(190101, 11, 200018, 0, 0, 100001, 0);  -- Набор лучника I (дальний бой -> необычный)

-- 190102 «Награды следопыта» (rank 3+): Tier II kits (-> blue), 20 tokens each
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, VerifiedBuild) VALUES
(190102, 15, 200001, 0, 0, 100003, 0),  -- Набор кузнеца II (металл -> редкий)
(190102, 16, 200004, 0, 0, 100003, 0),  -- Набор кожевника II (кожа -> редкий)
(190102, 17, 200007, 0, 0, 100003, 0),  -- Набор портного II (ткань -> редкий)
(190102, 18, 200010, 0, 0, 100003, 0),  -- Набор ювелира II (украшения -> редкий)
(190102, 19, 200013, 0, 0, 100003, 0),  -- Набор оружейника II (ближний бой -> редкий)
(190102, 20, 200016, 0, 0, 100003, 0),  -- Набор чародея II (магическое оружие -> редкий)
(190102, 21, 200019, 0, 0, 100003, 0);  -- Набор лучника II (дальний бой -> редкий)

-- 190103 «Награды ветерана» (rank 4+): Tier III kits (-> purple), 30 tokens each
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, VerifiedBuild) VALUES
(190103, 5,  200002, 0, 0, 100008, 0),  -- Набор кузнеца III (металл -> эпический)
(190103, 6,  200005, 0, 0, 100008, 0),  -- Набор кожевника III (кожа -> эпический)
(190103, 7,  200008, 0, 0, 100008, 0),  -- Набор портного III (ткань -> эпический)
(190103, 8,  200011, 0, 0, 100008, 0),  -- Набор ювелира III (украшения -> эпический)
(190103, 9,  200014, 0, 0, 100008, 0),  -- Набор оружейника III (ближний бой -> эпический)
(190103, 10, 200017, 0, 0, 100008, 0),  -- Набор чародея III (магическое оружие -> эпический)
(190103, 11, 200020, 0, 0, 100008, 0);  -- Набор лучника III (дальний бой -> эпический)
