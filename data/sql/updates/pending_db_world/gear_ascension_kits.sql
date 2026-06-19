-- ============================================================================
-- mod-gear-ascension -- profession kits (7 categories x 3 tiers = 21 kits)
-- PTR only (acore_world_ptr). Idempotent: DELETE before INSERT.
--
-- Kit entry layout:
--   category      | tier I (->green) | tier II (->blue) | tier III (->purple)
--   metal         | 200000           | 200001           | 200002
--   leather       | 200003           | 200004           | 200005
--   cloth         | 200006           | 200007           | 200008
--   jewel         | 200009           | 200010           | 200011
--   weapon_melee  | 200012           | 200013           | 200014
--   weapon_magic  | 200015           | 200016           | 200017
--   weapon_ranged | 200018           | 200019           | 200020
--
-- Kit Quality = target quality: tier I = 1 (white), II = 2 (green), III = 3 (blue).
-- Use-spell: 105000 (Gear Ascension: Apply Kit -- item-target SCRIPT_EFFECT).
-- Custom ItemDisplayInfo IDs for metal kits: 70001/70002/70003
--   (gladiator achievement icons; rows in .claude/dbc/ItemDisplayInfo_custom.csv).
-- Nemesis rank gates (owner decision 2026-06-18):
--   to_quality=2 (-> green):  rank 1
--   to_quality=3 (-> blue):   rank 3
--   to_quality=4 (-> purple): rank 5
-- ============================================================================

-- -- 0. Use-spell (spell_dbc row for ID 105000) ----------------------------
-- Effect_1=77 (SPELL_EFFECT_SCRIPT_EFFECT), Targets=16 (TARGET_FLAG_ITEM).
-- CastingTimeIndex=5 = 2000ms cast bar (same as Regrowth/Holy Fire).
-- ImplicitTargetA_1=26 (TARGET_GAMEOBJECT_ITEM_TARGET): required so the
--   item-target carried by TARGET_FLAG_ITEM resolves to the effect and
--   GetHitItem() returns the target in SpellScript::OnEffectHitTarget.
--   Without this the effect fires with no target and the upgrade never runs.
-- EquippedItemClass=-1: no equipped-item restriction (client gate suppressed).
-- ProcChance=101: conventional "always" for custom spells.
DELETE FROM spell_dbc WHERE ID = 105000;
REPLACE INTO spell_dbc
  (ID, Targets, Effect_1, CastingTimeIndex, RangeIndex, ProcChance,
   EquippedItemClass, EquippedItemSubclass, EquippedItemInvTypes,
   ImplicitTargetA_1, ImplicitTargetB_1,
   SpellVisualID_1, SpellVisualID_2,
   SpellIconID, Name_Lang_enUS)
VALUES
  (105000, 16, 77, 5, 1, 101,
   -1, 0, 0,
   26, 0,
   3182, 0,
   1, 'Gear Ascension: Apply Kit');

-- -- 1. Idempotency cleanup -------------------------------------------------
DELETE FROM item_template_locale WHERE ID BETWEEN 200000 AND 200020 AND locale = 'ruRU';
DELETE FROM item_template WHERE entry BETWEEN 200000 AND 200020;

-- -- 2. Kit item_template rows (21 kits) ------------------------------------
-- Strategy: clone from tavern coin (110150, class=15 subclass=0 Misc),
-- then UPDATE kit-specific columns.
-- bonding=0: kits are tradeable (110150 is bonding=1, overridden).
-- Quality per tier: tier I=1(white), tier II=2(green), tier III=3(blue).

INSERT INTO item_template
  SELECT 200000 AS entry, class, subclass, SoundOverrideSubclass, name, displayid,
    Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType,
    AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill,
    RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank,
    RequiredReputationFaction, RequiredReputationRank, maxcount, stackable,
    ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2,
    stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5,
    stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8,
    stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution,
    ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2,
    armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res,
    delay, ammo_type, RangedModRange,
    spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1,
    spellcategory_1, spellcategorycooldown_1,
    spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2,
    spellcategory_2, spellcategorycooldown_2,
    spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3,
    spellcategory_3, spellcategorycooldown_3,
    spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4,
    spellcategory_4, spellcategorycooldown_4,
    spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5,
    spellcategory_5, spellcategorycooldown_5,
    bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid,
    Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability,
    area, Map, BagFamily, TotemCategory,
    socketColor_1, socketContent_1, socketColor_2, socketContent_2,
    socketColor_3, socketContent_3, socketBonus, GemProperties,
    RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory,
    HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot,
    flagsCustom, VerifiedBuild
  FROM item_template WHERE entry = 110150;

INSERT INTO item_template SELECT 200001 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200002 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200003 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200004 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200005 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200006 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200007 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200008 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200009 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200010 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200011 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200012 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200013 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200014 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200015 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200016 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200017 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200018 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200019 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;
INSERT INTO item_template SELECT 200020 AS entry, class, subclass, SoundOverrideSubclass, name, displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace, ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank, requiredspell, requiredhonorrank, RequiredCityRank, RequiredReputationFaction, RequiredReputationRank, maxcount, stackable, ContainerSlots, stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3, stat_type4, stat_value4, stat_type5, stat_value5, stat_type6, stat_value6, stat_type7, stat_value7, stat_type8, stat_value8, stat_type9, stat_value9, stat_type10, stat_value10, ScalingStatDistribution, ScalingStatValue, dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res, delay, ammo_type, RangedModRange, spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2, spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3, spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4, spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5, bonding, description, PageText, LanguageID, PageMaterial, startquest, lockid, Material, sheath, RandomProperty, RandomSuffix, block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory, socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3, socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier, duration, ItemLimitCategory, HolidayId, ScriptName, DisenchantID, FoodType, minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild FROM item_template WHERE entry = 110150;

-- -- 3. Update kit-specific columns for all 21 kits ---------------------------
-- metal kits (plate/mail/shield) -- custom gladiator display IDs 70001/70002/70003
UPDATE item_template SET
    name='Crude Blacksmith''s Kit', displayid=70001, Quality=1, BuyPrice=1000, bonding=0,
    description='Upgrades plate, mail and shields to green quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200000;
UPDATE item_template SET
    name='Sturdy Blacksmith''s Kit', displayid=70002, Quality=2, BuyPrice=2000, bonding=0,
    description='Upgrades plate, mail and shields to blue quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200001;
UPDATE item_template SET
    name='Master Blacksmith''s Kit', displayid=70003, Quality=3, BuyPrice=4000, bonding=0,
    description='Upgrades plate, mail and shields to epic quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200002;
-- leather kits
UPDATE item_template SET
    name='Crude Leatherworker''s Kit', displayid=55479, Quality=1, BuyPrice=1000, bonding=0,
    description='Upgrades leather armor to green quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200003;
UPDATE item_template SET
    name='Sturdy Leatherworker''s Kit', displayid=56642, Quality=2, BuyPrice=2000, bonding=0,
    description='Upgrades leather armor to blue quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200004;
UPDATE item_template SET
    name='Master Leatherworker''s Kit', displayid=56641, Quality=3, BuyPrice=4000, bonding=0,
    description='Upgrades leather armor to epic quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200005;
-- cloth kits
UPDATE item_template SET
    name='Crude Tailor''s Kit', displayid=39462, Quality=1, BuyPrice=1000, bonding=0,
    description='Upgrades cloth armor to green quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200006;
UPDATE item_template SET
    name='Sturdy Tailor''s Kit', displayid=57460, Quality=2, BuyPrice=2000, bonding=0,
    description='Upgrades cloth armor to blue quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200007;
UPDATE item_template SET
    name='Master Tailor''s Kit', displayid=39454, Quality=3, BuyPrice=4000, bonding=0,
    description='Upgrades cloth armor to epic quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200008;
-- jewel kits
UPDATE item_template SET
    name='Crude Jeweler''s Kit', displayid=31204, Quality=1, BuyPrice=1000, bonding=0,
    description='Upgrades rings, amulets and trinkets to green quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200009;
UPDATE item_template SET
    name='Sturdy Jeweler''s Kit', displayid=31205, Quality=2, BuyPrice=2000, bonding=0,
    description='Upgrades rings, amulets and trinkets to blue quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200010;
UPDATE item_template SET
    name='Master Jeweler''s Kit', displayid=31205, Quality=3, BuyPrice=4000, bonding=0,
    description='Upgrades rings, amulets and trinkets to epic quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200011;
-- weapon_melee kits
UPDATE item_template SET
    name='Crude Sharpener''s Kit', displayid=24678, Quality=1, BuyPrice=1000, bonding=0,
    description='Upgrades melee weapons to green quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200012;
UPDATE item_template SET
    name='Sturdy Sharpener''s Kit', displayid=24680, Quality=2, BuyPrice=2000, bonding=0,
    description='Upgrades melee weapons to blue quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200013;
UPDATE item_template SET
    name='Master Sharpener''s Kit', displayid=24681, Quality=3, BuyPrice=4000, bonding=0,
    description='Upgrades melee weapons to epic quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200014;
-- weapon_magic kits
UPDATE item_template SET
    name='Crude Sorcerer''s Kit', displayid=1501, Quality=1, BuyPrice=1000, bonding=0,
    description='Upgrades wands and staves to green quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200015;
UPDATE item_template SET
    name='Sturdy Sorcerer''s Kit', displayid=38758, Quality=2, BuyPrice=2000, bonding=0,
    description='Upgrades wands and staves to blue quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200016;
UPDATE item_template SET
    name='Master Sorcerer''s Kit', displayid=38760, Quality=3, BuyPrice=4000, bonding=0,
    description='Upgrades wands and staves to epic quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200017;
-- weapon_ranged kits
UPDATE item_template SET
    name='Crude Engineer''s Kit', displayid=20624, Quality=1, BuyPrice=1000, bonding=0,
    description='Upgrades bows, guns, crossbows and thrown to green quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200018;
UPDATE item_template SET
    name='Sturdy Engineer''s Kit', displayid=40549, Quality=2, BuyPrice=2000, bonding=0,
    description='Upgrades bows, guns, crossbows and thrown to blue quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200019;
UPDATE item_template SET
    name='Master Engineer''s Kit', displayid=52196, Quality=3, BuyPrice=4000, bonding=0,
    description='Upgrades bows, guns, crossbows and thrown to epic quality.',
    spellid_1=105000, spelltrigger_1=0, spellcharges_1=-1, spellppmRate_1=0,
    spellcooldown_1=-1, spellcategory_1=0, spellcategorycooldown_1=-1,
    spellid_2=0, spelltrigger_2=0, spellcharges_2=0,
    ScriptName='gear_ascension_kit', VerifiedBuild=12340
WHERE entry=200020;

-- -- 4. ruRU locale for all 21 kits ------------------------------------------
INSERT INTO item_template_locale (ID, locale, Name, Description) VALUES
(200000,'ruRU','Грубый набор кузнеца',       'Улучшает латы, кольчугу и щиты до зелёного качества.'),
(200001,'ruRU','Добротный набор кузнеца',    'Улучшает латы, кольчугу и щиты до синего качества.'),
(200002,'ruRU','Мастерский набор кузнеца',   'Улучшает латы, кольчугу и щиты до фиолетового качества.'),
(200003,'ruRU','Грубый набор кожевника',      'Улучшает кожаные доспехи до зелёного качества.'),
(200004,'ruRU','Добротный набор кожевника',  'Улучшает кожаные доспехи до синего качества.'),
(200005,'ruRU','Мастерский набор кожевника', 'Улучшает кожаные доспехи до фиолетового качества.'),
(200006,'ruRU','Грубый набор портного',       'Улучшает тканевые доспехи до зелёного качества.'),
(200007,'ruRU','Добротный набор портного',   'Улучшает тканевые доспехи до синего качества.'),
(200008,'ruRU','Мастерский набор портного',  'Улучшает тканевые доспехи до фиолетового качества.'),
(200009,'ruRU','Грубый набор ювелира',        'Улучшает кольца, амулеты и безделушки до зелёного качества.'),
(200010,'ruRU','Добротный набор ювелира',    'Улучшает кольца, амулеты и безделушки до синего качества.'),
(200011,'ruRU','Мастерский набор ювелира',   'Улучшает кольца, амулеты и безделушки до фиолетового качества.'),
(200012,'ruRU','Грубый набор точильщика',     'Улучшает оружие ближнего боя до зелёного качества.'),
(200013,'ruRU','Добротный набор точильщика', 'Улучшает оружие ближнего боя до синего качества.'),
(200014,'ruRU','Мастерский набор точильщика','Улучшает оружие ближнего боя до фиолетового качества.'),
(200015,'ruRU','Грубый набор чародея',        'Улучшает жезлы и посохи до зелёного качества.'),
(200016,'ruRU','Добротный набор чародея',    'Улучшает жезлы и посохи до синего качества.'),
(200017,'ruRU','Мастерский набор чародея',   'Улучшает жезлы и посохи до фиолетового качества.'),
(200018,'ruRU','Грубый набор инженера',       'Улучшает луки, ружья и арбалеты до зелёного качества.'),
(200019,'ruRU','Добротный набор инженера',   'Улучшает луки, ружья и арбалеты до синего качества.'),
(200020,'ruRU','Мастерский набор инженера',  'Улучшает луки, ружья и арбалеты до фиолетового качества.');

-- -- 5. Update nemesis_rank in item_upgrade_chain --------------------------
-- Owner decision 2026-06-18:
--   to_quality=2 (kit tier I,  -> green):  rank 1
--   to_quality=3 (kit tier II, -> blue):   rank 3
--   to_quality=4 (kit tier III,-> purple): rank 5
UPDATE item_upgrade_chain SET nemesis_rank = 1 WHERE to_quality = 2;
UPDATE item_upgrade_chain SET nemesis_rank = 3 WHERE to_quality = 3;
UPDATE item_upgrade_chain SET nemesis_rank = 5 WHERE to_quality = 4;
