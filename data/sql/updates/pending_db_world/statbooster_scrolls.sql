-- ============================================================================
-- StatBooster Pool Scrolls System — Classic Tier (iLvl 1-92, skill 1-300)
-- 16 craftable items across 4 professions, 4 tiers each
-- Pool scrolls add enchants to UNENCHANTED items only (no reroll)
-- Attribute Recalibrator (41605) is the ONLY way to reroll (endgame)
--
-- Items use custom IDs 100001-100016
-- All reagents are Classic-era materials (available at level 60)
--
-- Tier breakdown:
--   T1: Skill 25  (Apprentice)  — iLvl 1-25   — early leveling
--   T2: Skill 100 (Journeyman)  — iLvl 26-45  — mid leveling
--   T3: Skill 175 (Expert)      — iLvl 46-65  — late leveling
--   T4: Skill 250 (Artisan)     — iLvl 66-92  — Classic endgame (MC/BWL/AQ/Naxx)
-- ============================================================================

-- ============================================================================
-- STEP 0: Clean up deprecated items from old iteration (17827-17896 range)
-- These vanilla QA item IDs were repurposed during an earlier version.
-- Restore originals by deleting any custom overrides, and clean up
-- related spell/skill/trainer data that may still exist.
-- Also purge any AH listings and character inventories of old items.
-- ============================================================================

-- Delete old custom item overrides (restores vanilla QA items on next DB rebuild)
DELETE FROM `item_template` WHERE `entry` BETWEEN 17827 AND 17896
  AND `name` NOT LIKE 'QA%'
  AND `name` NOT LIKE 'Level 60 Test%';

-- Delete old locale entries for deprecated items
DELETE FROM `item_template_locale` WHERE `ID` BETWEEN 17827 AND 17896;

-- Delete old custom spells (if old iteration used matching spell IDs)
DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 17827 AND 17896;

-- Delete old custom skill links
DELETE FROM `skilllineability_dbc` WHERE `ID` BETWEEN 17827 AND 17896;

-- Delete old trainer entries
DELETE FROM `trainer_spell` WHERE `SpellId` BETWEEN 17827 AND 17896;

-- NOTE: To clean up AH listings and inventories of old items, run against
-- the CHARACTERS database (acore_characters):
--   DELETE FROM auctionhouse WHERE itemEntry BETWEEN 17827 AND 17896;
--   DELETE FROM item_instance WHERE itemEntry BETWEEN 17827 AND 17896;

-- ============================================================================
-- STEP 1: Add PoolGroup column to enchant template (if not exists)
-- ============================================================================
SET @col_exists = (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'statbooster_enchant_template' AND COLUMN_NAME = 'PoolGroup');
SET @q = IF(@col_exists = 0, 'ALTER TABLE `statbooster_enchant_template` ADD COLUMN `PoolGroup` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `Note`', 'SELECT 1');
PREPARE stmt FROM @q;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ============================================================================
-- STEP 2: Assign pool groups
-- Pool 0 = General (used by Attribute Recalibrator 41605)
-- Pool 1 = Battle (offensive)
-- Pool 2 = Warding (defensive)
-- Pool 3 = Arcana (caster)
-- Pool 4 = Fortune (use-spell effects)
-- ============================================================================

UPDATE `statbooster_enchant_template` SET `PoolGroup` = 1 WHERE `Description` LIKE '%Strength%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 1 WHERE `Description` LIKE '%Agility%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 1 WHERE `Description` LIKE '%AttackPower%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 1 WHERE `Description` LIKE '%CritRating%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 1 WHERE `Description` LIKE '%HasteRating%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 1 WHERE `Description` LIKE '%ArmorPenetration%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 1 WHERE `Description` LIKE '%ExpertiseRating%';

UPDATE `statbooster_enchant_template` SET `PoolGroup` = 2 WHERE `Description` LIKE '%Stamina%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 2 WHERE `Description` LIKE '%Armor' AND `Description` NOT LIKE '%Penetration%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 2 WHERE `Description` LIKE '%DefenseRating%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 2 WHERE `Description` LIKE '%BlockValue%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 2 WHERE `Description` LIKE '%Health%' AND `Id` < 90000;

UPDATE `statbooster_enchant_template` SET `PoolGroup` = 3 WHERE `Description` LIKE '%Intellect%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 3 WHERE `Description` LIKE '%Spirit%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 3 WHERE `Description` LIKE '%Spell Power%' OR `Description` LIKE '%SpellPower%';
UPDATE `statbooster_enchant_template` SET `PoolGroup` = 3 WHERE `Description` LIKE '%Mana' AND `Id` < 90000;

UPDATE `statbooster_enchant_template` SET `PoolGroup` = 4 WHERE `Id` >= 90001 AND `Id` <= 90099;

-- ============================================================================
-- STEP 3: Create craft spells (5 sec cast, creates 1 item)
-- CastingTimeIndex 16 = 5000ms, Effect 24 = CREATE_ITEM
-- All reagents are Classic-era materials
-- ============================================================================

-- ------- BLACKSMITHING: Runed/Tempered/Honed/Masterwork Whetstone -------
-- T1: Copper Bar(4) + Rough Stone(1)
-- T2: Iron Bar(4) + Heavy Stone(2)
-- T3: Thorium Bar(6) + Dense Stone(2)
-- T4: Truesilver Bar(4) + Dense Stone(4)
REPLACE INTO `spell_dbc` (`ID`, `Category`, `Attributes`, `AttributesEx`, `CastingTimeIndex`, `Effect_1`, `EffectItemType_1`, `EffectDieSides_1`, `ImplicitTargetA_1`, `Reagent_1`, `ReagentCount_1`, `Reagent_2`, `ReagentCount_2`, `EquippedItemClass`, `SpellIconID`, `SpellVisualID_1`, `Name_Lang_enUS`) VALUES
(100001, 0, 65568, 1024, 16, 24, 100001, 1, 1, 2840,  4, 2835,  1, -1, 140, 13785, 'Runed Whetstone'),
(100002, 0, 65568, 1024, 16, 24, 100002, 1, 1, 3575,  4, 2838,  2, -1, 140, 13785, 'Tempered Whetstone'),
(100003, 0, 65568, 1024, 16, 24, 100003, 1, 1, 12359, 6, 12365, 2, -1, 140, 13785, 'Honed Whetstone'),
(100004, 0, 65568, 1024, 16, 24, 100004, 1, 1, 6037,  4, 12365, 4, -1, 140, 13785, 'Masterwork Whetstone');

-- ------- LEATHERWORKING: Runed/Tempered/Hardened/Masterwork Armor Patch -------
-- T1: Light Leather(4) + Coarse Thread(1)
-- T2: Heavy Leather(6) + Silken Thread(2)
-- T3: Rugged Leather(8) + Rune Thread(2)
-- T4: Thick Leather(8) + Rugged Hide(2)
REPLACE INTO `spell_dbc` (`ID`, `Category`, `Attributes`, `AttributesEx`, `CastingTimeIndex`, `Effect_1`, `EffectItemType_1`, `EffectDieSides_1`, `ImplicitTargetA_1`, `Reagent_1`, `ReagentCount_1`, `Reagent_2`, `ReagentCount_2`, `EquippedItemClass`, `SpellIconID`, `SpellVisualID_1`, `Name_Lang_enUS`) VALUES
(100005, 0, 65568, 1024, 16, 24, 100005, 1, 1, 2318, 4, 2320,  1, -1, 346, 4439, 'Runed Armor Patch'),
(100006, 0, 65568, 1024, 16, 24, 100006, 1, 1, 4234, 6, 4291,  2, -1, 346, 4439, 'Tempered Armor Patch'),
(100007, 0, 65568, 1024, 16, 24, 100007, 1, 1, 8170, 8, 14341, 2, -1, 346, 4439, 'Hardened Armor Patch'),
(100008, 0, 65568, 1024, 16, 24, 100008, 1, 1, 4304, 8, 8171,  2, -1, 346, 4439, 'Masterwork Armor Patch');

-- ------- ENCHANTING: Minor/Arcane/Greater/Superior Arcane Vellum -------
-- T1: Strange Dust(2) + Lesser Magic Essence(1)
-- T2: Soul Dust(4) + Greater Magic Essence(2)
-- T3: Illusion Dust(4) + Greater Eternal Essence(2)
-- T4: Large Brilliant Shard(2) + Greater Eternal Essence(4)
REPLACE INTO `spell_dbc` (`ID`, `Category`, `Attributes`, `AttributesEx`, `CastingTimeIndex`, `Effect_1`, `EffectItemType_1`, `EffectDieSides_1`, `ImplicitTargetA_1`, `Reagent_1`, `ReagentCount_1`, `Reagent_2`, `ReagentCount_2`, `EquippedItemClass`, `SpellIconID`, `SpellVisualID_1`, `Name_Lang_enUS`) VALUES
(100009, 0, 65568, 1024, 16, 24, 100009, 1, 1, 10940, 2, 10938, 1, -1, 241, 3182, 'Minor Arcane Vellum'),
(100010, 0, 65568, 1024, 16, 24, 100010, 1, 1, 11083, 4, 10939, 2, -1, 241, 3182, 'Arcane Vellum'),
(100011, 0, 65568, 1024, 16, 24, 100011, 1, 1, 16204, 4, 16203, 2, -1, 241, 3182, 'Greater Arcane Vellum'),
(100012, 0, 65568, 1024, 16, 24, 100012, 1, 1, 14344, 2, 16203, 4, -1, 241, 3182, 'Superior Arcane Vellum');

-- ------- INSCRIPTION: Minor/Regular/Major/Grand Glyph of Fortune -------
-- T1: Moonglow Ink(2) + Light Parchment(1)
-- T2: Midnight Ink(3) + Common Parchment(1)
-- T3: Lion's Ink(3) + Common Parchment(2)
-- T4: Celestial Ink(4) + Heavy Parchment(2)
REPLACE INTO `spell_dbc` (`ID`, `Category`, `Attributes`, `AttributesEx`, `CastingTimeIndex`, `Effect_1`, `EffectItemType_1`, `EffectDieSides_1`, `ImplicitTargetA_1`, `Reagent_1`, `ReagentCount_1`, `Reagent_2`, `ReagentCount_2`, `EquippedItemClass`, `SpellIconID`, `SpellVisualID_1`, `Name_Lang_enUS`) VALUES
(100013, 0, 65568, 1024, 16, 24, 100013, 1, 1, 39469, 2, 39354, 1, -1, 2557, 10130, 'Minor Glyph of Fortune'),
(100014, 0, 65568, 1024, 16, 24, 100014, 1, 1, 39774, 3, 10648, 1, -1, 2557, 10130, 'Glyph of Fortune'),
(100015, 0, 65568, 1024, 16, 24, 100015, 1, 1, 43116, 3, 10648, 2, -1, 2557, 10130, 'Major Glyph of Fortune'),
(100016, 0, 65568, 1024, 16, 24, 100016, 1, 1, 43120, 4, 39501, 2, -1, 2557, 10130, 'Grand Glyph of Fortune');

-- ============================================================================
-- STEP 4: Create/replace items (custom IDs 100001-100016, matching DBC Item patch)
-- class 0 = consumable, subclass 8 = other
-- spelltrigger_1 = 0 means "Use:" effect
-- spellid_1 = 100000 (generic "Enchant Item" use-on-item spell)
-- iLvl ranges: T1=1-25, T2=26-45, T3=46-65, T4=66-92
-- ============================================================================

-- ------- BLACKSMITHING ITEMS (100001-100004) -------
REPLACE INTO `item_template` (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `ItemLevel`, `RequiredLevel`, `MaxCount`, `stackable`, `spellid_1`, `spelltrigger_1`, `spellcooldown_1`, `spellcategory_1`, `spellcategorycooldown_1`, `bonding`, `description`, `Material`) VALUES
(100001, 0, 8, 'Runed Whetstone',      24673, 2, 64, 5000,    1000,  0, -1, 1,  1,  20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 1-25) to add an offensive enchant.', 1),
(100002, 0, 8, 'Tempered Whetstone',    24675, 2, 64, 25000,   5000,  0, -1, 1,  15, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 26-45) to add an offensive enchant.', 1),
(100003, 0, 8, 'Honed Whetstone',       24676, 3, 64, 100000,  20000, 0, -1, 1,  35, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 46-65) to add an offensive enchant.', 1),
(100004, 0, 8, 'Masterwork Whetstone',  39193, 4, 64, 500000,  100000,0, -1, 1,  50, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 66-92) to add an offensive enchant.', 1);

-- ------- LEATHERWORKING ITEMS (100005-100008) -------
REPLACE INTO `item_template` (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `ItemLevel`, `RequiredLevel`, `MaxCount`, `stackable`, `spellid_1`, `spelltrigger_1`, `spellcooldown_1`, `spellcategory_1`, `spellcategorycooldown_1`, `bonding`, `description`, `Material`) VALUES
(100005, 0, 8, 'Runed Armor Patch',      38761, 2, 64, 5000,    1000,  0, -1, 1,  1,  20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 1-25) to add a defensive enchant.', 8),
(100006, 0, 8, 'Tempered Armor Patch',    38762, 2, 64, 25000,   5000,  0, -1, 1,  15, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 26-45) to add a defensive enchant.', 8),
(100007, 0, 8, 'Hardened Armor Patch',    38763, 3, 64, 100000,  20000, 0, -1, 1,  35, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 46-65) to add a defensive enchant.', 8),
(100008, 0, 8, 'Masterwork Armor Patch',  55478, 4, 64, 500000,  100000,0, -1, 1,  50, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 66-92) to add a defensive enchant.', 8);

-- ------- ENCHANTING ITEMS (100009-100012) -------
REPLACE INTO `item_template` (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `ItemLevel`, `RequiredLevel`, `MaxCount`, `stackable`, `spellid_1`, `spelltrigger_1`, `spellcooldown_1`, `spellcategory_1`, `spellcategorycooldown_1`, `bonding`, `description`, `Material`) VALUES
(100009, 0, 8, 'Minor Arcane Vellum',    634,   2, 64, 5000,    1000,  0, -1, 1,  1,  20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 1-25) to add a caster enchant.', 0),
(100010, 0, 8, 'Arcane Vellum',           1037,  2, 64, 25000,   5000,  0, -1, 1,  15, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 26-45) to add a caster enchant.', 0),
(100011, 0, 8, 'Greater Arcane Vellum',   1093,  3, 64, 100000,  20000, 0, -1, 1,  35, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 46-65) to add a caster enchant.', 0),
(100012, 0, 8, 'Superior Arcane Vellum',  39201, 4, 64, 500000,  100000,0, -1, 1,  50, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 66-92) to add a caster enchant.', 0);

-- ------- INSCRIPTION ITEMS (100013-100016) -------
REPLACE INTO `item_template` (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `ItemLevel`, `RequiredLevel`, `MaxCount`, `stackable`, `spellid_1`, `spelltrigger_1`, `spellcooldown_1`, `spellcategory_1`, `spellcategorycooldown_1`, `bonding`, `description`, `Material`) VALUES
(100013, 0, 8, 'Minor Glyph of Fortune',  57389, 2, 64, 5000,    1000,  0, -1, 1,  1,  20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 1-25) to add a special use-effect.', 0),
(100014, 0, 8, 'Glyph of Fortune',        57389, 2, 64, 25000,   5000,  0, -1, 1,  15, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 26-45) to add a special use-effect.', 0),
(100015, 0, 8, 'Major Glyph of Fortune',  57389, 3, 64, 100000,  20000, 0, -1, 1,  35, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 46-65) to add a special use-effect.', 0),
(100016, 0, 8, 'Grand Glyph of Fortune',  57389, 4, 64, 500000,  100000,0, -1, 1,  50, 20, 20, 100000, 0, -1, 0, -1, 0, 'Use on equipment (iLvl 66-92) to add a special use-effect.', 0);

-- ============================================================================
-- STEP 5: Link craft spells to professions (SkillLine)
-- 164 = Blacksmithing, 165 = Leatherworking, 333 = Enchanting, 773 = Inscription
-- Classic skill tiers: T1=25, T2=100, T3=175, T4=250
-- TrivialHigh/Low = skill-up color thresholds (orange→yellow→green→gray)
-- ============================================================================

REPLACE INTO `skilllineability_dbc` (`ID`, `SkillLine`, `Spell`, `MinSkillLineRank`, `TrivialSkillLineRankHigh`, `TrivialSkillLineRankLow`, `SupercededBySpell`, `AcquireMethod`) VALUES
-- Blacksmithing
(100001, 164, 100001, 25,  75,  25,  0, 1),
(100002, 164, 100002, 100, 150, 100, 0, 1),
(100003, 164, 100003, 175, 225, 175, 0, 1),
(100004, 164, 100004, 250, 300, 250, 0, 1),
-- Leatherworking
(100005, 165, 100005, 25,  75,  25,  0, 1),
(100006, 165, 100006, 100, 150, 100, 0, 1),
(100007, 165, 100007, 175, 225, 175, 0, 1),
(100008, 165, 100008, 250, 300, 250, 0, 1),
-- Enchanting
(100009, 333, 100009, 25,  75,  25,  0, 1),
(100010, 333, 100010, 100, 150, 100, 0, 1),
(100011, 333, 100011, 175, 225, 175, 0, 1),
(100012, 333, 100012, 250, 300, 250, 0, 1),
-- Inscription
(100013, 773, 100013, 25,  75,  25,  0, 1),
(100014, 773, 100014, 100, 150, 100, 0, 1),
(100015, 773, 100015, 175, 225, 175, 0, 1),
(100016, 773, 100016, 250, 300, 250, 0, 1);

-- ============================================================================
-- STEP 6: Add recipes to profession trainers (tier-aware)
-- Uses `trainer_spell` table (NOT the deprecated `npc_trainer`)
-- Each recipe is only added to trainers whose existing skill range covers it:
--   recipe ReqSkillRank must be <= trainer's max taught ReqSkillRank
-- This respects the apprentice/journeyman/expert/artisan/master tier system.
-- Classic skill reqs: T1=25, T2=100, T3=175, T4=250
-- ============================================================================

-- Remove old entries first (idempotent re-run)
DELETE FROM `trainer_spell` WHERE `SpellId` BETWEEN 100001 AND 100016;

-- Blacksmithing (SkillLine 164): spells 100001-100004
INSERT IGNORE INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`)
SELECT t.TrainerId, s.SpellId, s.MoneyCost, s.ReqSkillLine, s.ReqSkillRank, 0, 0, 0, 0, 0
FROM (
    SELECT TrainerId, MAX(ReqSkillRank) AS max_rank
    FROM trainer_spell WHERE ReqSkillLine = 164 GROUP BY TrainerId
) t
CROSS JOIN (
    SELECT 100001 AS SpellId, 500    AS MoneyCost, 164 AS ReqSkillLine, 25  AS ReqSkillRank UNION ALL
    SELECT 100002,            5000,                 164,                 100                 UNION ALL
    SELECT 100003,            25000,                164,                 175                 UNION ALL
    SELECT 100004,            100000,               164,                 250
) s
WHERE s.ReqSkillRank <= t.max_rank;

-- Leatherworking (SkillLine 165): spells 100005-100008
INSERT IGNORE INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`)
SELECT t.TrainerId, s.SpellId, s.MoneyCost, s.ReqSkillLine, s.ReqSkillRank, 0, 0, 0, 0, 0
FROM (
    SELECT TrainerId, MAX(ReqSkillRank) AS max_rank
    FROM trainer_spell WHERE ReqSkillLine = 165 GROUP BY TrainerId
) t
CROSS JOIN (
    SELECT 100005 AS SpellId, 500    AS MoneyCost, 165 AS ReqSkillLine, 25  AS ReqSkillRank UNION ALL
    SELECT 100006,            5000,                 165,                 100                 UNION ALL
    SELECT 100007,            25000,                165,                 175                 UNION ALL
    SELECT 100008,            100000,               165,                 250
) s
WHERE s.ReqSkillRank <= t.max_rank;

-- Enchanting (SkillLine 333): spells 100009-100012
INSERT IGNORE INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`)
SELECT t.TrainerId, s.SpellId, s.MoneyCost, s.ReqSkillLine, s.ReqSkillRank, 0, 0, 0, 0, 0
FROM (
    SELECT TrainerId, MAX(ReqSkillRank) AS max_rank
    FROM trainer_spell WHERE ReqSkillLine = 333 GROUP BY TrainerId
) t
CROSS JOIN (
    SELECT 100009 AS SpellId, 500    AS MoneyCost, 333 AS ReqSkillLine, 25  AS ReqSkillRank UNION ALL
    SELECT 100010,            5000,                 333,                 100                 UNION ALL
    SELECT 100011,            25000,                333,                 175                 UNION ALL
    SELECT 100012,            100000,               333,                 250
) s
WHERE s.ReqSkillRank <= t.max_rank;

-- Inscription (SkillLine 773): spells 100013-100016
INSERT IGNORE INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`)
SELECT t.TrainerId, s.SpellId, s.MoneyCost, s.ReqSkillLine, s.ReqSkillRank, 0, 0, 0, 0, 0
FROM (
    SELECT TrainerId, MAX(ReqSkillRank) AS max_rank
    FROM trainer_spell WHERE ReqSkillLine = 773 GROUP BY TrainerId
) t
CROSS JOIN (
    SELECT 100013 AS SpellId, 500    AS MoneyCost, 773 AS ReqSkillLine, 25  AS ReqSkillRank UNION ALL
    SELECT 100014,            5000,                 773,                 100                 UNION ALL
    SELECT 100015,            25000,                773,                 175                 UNION ALL
    SELECT 100016,            100000,               773,                 250
) s
WHERE s.ReqSkillRank <= t.max_rank;

-- ============================================================================
-- STEP 7: Russian locale entries (ruRU)
-- Server sends item names via SMSG_ITEM_QUERY_SINGLE_RESPONSE using
-- item_template_locale. Without these, ruRU clients see English names.
-- ============================================================================

DELETE FROM `item_template_locale` WHERE `ID` BETWEEN 100001 AND 100016 AND `locale` = 'ruRU';
INSERT INTO `item_template_locale` (`ID`, `locale`, `Name`, `Description`) VALUES
-- Blacksmithing
(100001, 'ruRU', 'Рунный точильный камень',       'Используйте на снаряжении (уИП 1-25) для наложения боевых чар.'),
(100002, 'ruRU', 'Закаленный точильный камень',    'Используйте на снаряжении (уИП 26-45) для наложения боевых чар.'),
(100003, 'ruRU', 'Отточенный точильный камень',    'Используйте на снаряжении (уИП 46-65) для наложения боевых чар.'),
(100004, 'ruRU', 'Мастерский точильный камень',    'Используйте на снаряжении (уИП 66-92) для наложения боевых чар.'),
-- Leatherworking
(100005, 'ruRU', 'Рунная нашивка',                 'Используйте на снаряжении (уИП 1-25) для наложения защитных чар.'),
(100006, 'ruRU', 'Закаленная нашивка',             'Используйте на снаряжении (уИП 26-45) для наложения защитных чар.'),
(100007, 'ruRU', 'Упрочненная нашивка',            'Используйте на снаряжении (уИП 46-65) для наложения защитных чар.'),
(100008, 'ruRU', 'Мастерская нашивка',             'Используйте на снаряжении (уИП 66-92) для наложения защитных чар.'),
-- Enchanting
(100009, 'ruRU', 'Малый тайный пергамент',         'Используйте на снаряжении (уИП 1-25) для наложения чар заклинателя.'),
(100010, 'ruRU', 'Тайный пергамент',               'Используйте на снаряжении (уИП 26-45) для наложения чар заклинателя.'),
(100011, 'ruRU', 'Большой тайный пергамент',       'Используйте на снаряжении (уИП 46-65) для наложения чар заклинателя.'),
(100012, 'ruRU', 'Превосходный тайный пергамент',  'Используйте на снаряжении (уИП 66-92) для наложения чар заклинателя.'),
-- Inscription
(100013, 'ruRU', 'Малый символ удачи',             'Используйте на снаряжении (уИП 1-25) для наложения особого эффекта.'),
(100014, 'ruRU', 'Символ удачи',                   'Используйте на снаряжении (уИП 26-45) для наложения особого эффекта.'),
(100015, 'ruRU', 'Большой символ удачи',           'Используйте на снаряжении (уИП 46-65) для наложения особого эффекта.'),
(100016, 'ruRU', 'Великий символ удачи',           'Используйте на снаряжении (уИП 66-92) для наложения особого эффекта.');
