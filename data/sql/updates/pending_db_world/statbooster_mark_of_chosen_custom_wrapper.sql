-- StatBooster — custom wrapper-spell for Mark of the Chosen enchant 90138
--
-- Background: vanilla spell 21969 (Mark of the Chosen aura trigger) is designed
-- to be applied via item-level ppmRate from the trinket itself, NOT as a
-- permanent EQUIP_SPELL enchant aura. AC may not propagate it correctly when
-- used via SpellItemEnchantment.Effect=3 → EffectArg=21969.
--
-- Custom spell 100037 is a clean wrapper:
--   - Attributes 80 (passive, like Fiery Weapon 43929)
--   - DurationIndex 0 (infinite — proper permanent aura)
--   - EffectAura 42 (PROC_TRIGGER_SPELL) → fires spell 21970
--   - ProcTypeMask 1048576 (PROC_FLAG_TAKEN_DAMAGE — any damage taken)
--   - ProcChance 100 (testing — drop to 2 for production)
--   - EffectTriggerSpell_1 = 21970 (the actual +25 all stats buff)
--
-- Then enchant 90138 is rewired: EffectArg_1 changed from 21969 → 100037.
--
-- After this:
--   - Vanilla trinket 17774 keeps using spell 21969 with original 2% ppmRate
--   - Our enchant 90138 uses custom wrapper 100037 with proper aura lifecycle
--   - The cross-contamination (forcing 100% proc on vanilla trinket too) goes away

-- 1) Cleanup: remove the spell_proc override on 21969 (no longer needed; reverts
--    vanilla Mark of the Chosen trinket to its original 2% behavior)
DELETE FROM `spell_proc` WHERE `SpellId` = 21969;

-- 2) Insert custom wrapper spell 100037 into spell_dbc
--    (mirrors the row in Spell_custom.csv which will be in client MPQ)
DELETE FROM `spell_dbc` WHERE `ID` = 100037;
INSERT INTO `spell_dbc` (
  `ID`, `Attributes`, `ProcTypeMask`, `ProcChance`, `ProcCharges`,
  `DurationIndex`, `RangeIndex`, `CastingTimeIndex`,
  `EquippedItemClass`, `SchoolMask`, `SpellLevel`,
  `Effect_1`, `EffectBasePoints_1`, `EffectAura_1`, `EffectTriggerSpell_1`,
  `Name_Lang_zhTW`, `Name_Lang_Mask`,
  `Description_Lang_zhTW`, `Description_Lang_Mask`
) VALUES (
  100037, 80, 1048576, 100, 0,
  0, 1, 1,
  -1, 0, 0,
  6, -1, 42, 21970,
  '##SB##Удача: Знак избранного', 16712190,
  '##SB##Удача: Знак избранного — Шанс при получении удара повысить все характеристики на 25 ед. на 1 мин.', 16712190
);

-- 3) Rewire enchant 90138 to use new wrapper spell 100037
UPDATE `spellitemenchantment_dbc`
SET `EffectArg_1` = 100037
WHERE `ID` = 90138;
