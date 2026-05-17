-- ============================================================================
-- Arcane Vellum Pool (Pool 3) — Base DBC entries
-- 24 custom school damage spells (100040-100063)
-- 24 school damage enchants (90100-90123) + 4 Intellect (90130-90133) + 4 Spirit (90134-90137)
-- ============================================================================

-- ============================================================================
-- STEP 1: Clean old Pool 3 entries
-- ============================================================================

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 100040 AND 100063;
DELETE FROM `spellitemenchantment_dbc` WHERE `ID` BETWEEN 90100 AND 90137;
DELETE FROM `statbooster_enchant_template` WHERE `PoolGroup` = 3;

-- ============================================================================
-- STEP 2: Custom passive spells — MOD_DAMAGE_DONE per school
-- Aura 13 = SPELL_AURA_MOD_DAMAGE_DONE
-- EffectMiscValue_1 = school mask: Holy=2, Fire=4, Nature=8, Frost=16, Shadow=32, Arcane=64
-- Attributes 192 = PASSIVE + HIDDEN_CLIENTSIDE (item passive)
-- EffectBasePoints_1 = value - 1 (engine adds 1)
-- DurationIndex=21 (permanent) + ProcChance=101 are CRITICAL for APPLY_AURA:
-- without them the aura silently vanishes. See memory/feedback_spell_dbc_aura_fields.md.
-- ============================================================================

INSERT INTO `spell_dbc` (`ID`, `Attributes`, `EquippedItemClass`, `CastingTimeIndex`, `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValue_1`, `SchoolMask`, `DurationIndex`, `ProcChance`, `Name_Lang_enUS`) VALUES
-- T1 (+3 per school)
(100040, 192, -1, 1, 6, 13, 2, 1, 4,  4,  21, 101, '+3 Fire Spell Damage'),
(100041, 192, -1, 1, 6, 13, 2, 1, 16, 16, 21, 101, '+3 Frost Spell Damage'),
(100042, 192, -1, 1, 6, 13, 2, 1, 8,  8,  21, 101, '+3 Nature Spell Damage'),
(100043, 192, -1, 1, 6, 13, 2, 1, 32, 32, 21, 101, '+3 Shadow Spell Damage'),
(100044, 192, -1, 1, 6, 13, 2, 1, 64, 64, 21, 101, '+3 Arcane Spell Damage'),
(100045, 192, -1, 1, 6, 13, 2, 1, 2,  2,  21, 101, '+3 Holy Spell Damage'),
-- T2 (+5 per school)
(100046, 192, -1, 1, 6, 13, 4, 1, 4,  4,  21, 101, '+5 Fire Spell Damage'),
(100047, 192, -1, 1, 6, 13, 4, 1, 16, 16, 21, 101, '+5 Frost Spell Damage'),
(100048, 192, -1, 1, 6, 13, 4, 1, 8,  8,  21, 101, '+5 Nature Spell Damage'),
(100049, 192, -1, 1, 6, 13, 4, 1, 32, 32, 21, 101, '+5 Shadow Spell Damage'),
(100050, 192, -1, 1, 6, 13, 4, 1, 64, 64, 21, 101, '+5 Arcane Spell Damage'),
(100051, 192, -1, 1, 6, 13, 4, 1, 2,  2,  21, 101, '+5 Holy Spell Damage'),
-- T3 (+7 per school)
(100052, 192, -1, 1, 6, 13, 6, 1, 4,  4,  21, 101, '+7 Fire Spell Damage'),
(100053, 192, -1, 1, 6, 13, 6, 1, 16, 16, 21, 101, '+7 Frost Spell Damage'),
(100054, 192, -1, 1, 6, 13, 6, 1, 8,  8,  21, 101, '+7 Nature Spell Damage'),
(100055, 192, -1, 1, 6, 13, 6, 1, 32, 32, 21, 101, '+7 Shadow Spell Damage'),
(100056, 192, -1, 1, 6, 13, 6, 1, 64, 64, 21, 101, '+7 Arcane Spell Damage'),
(100057, 192, -1, 1, 6, 13, 6, 1, 2,  2,  21, 101, '+7 Holy Spell Damage'),
-- T4 (+10 per school)
(100058, 192, -1, 1, 6, 13, 9, 1, 4,  4,  21, 101, '+10 Fire Spell Damage'),
(100059, 192, -1, 1, 6, 13, 9, 1, 16, 16, 21, 101, '+10 Frost Spell Damage'),
(100060, 192, -1, 1, 6, 13, 9, 1, 8,  8,  21, 101, '+10 Nature Spell Damage'),
(100061, 192, -1, 1, 6, 13, 9, 1, 32, 32, 21, 101, '+10 Shadow Spell Damage'),
(100062, 192, -1, 1, 6, 13, 9, 1, 64, 64, 21, 101, '+10 Arcane Spell Damage'),
(100063, 192, -1, 1, 6, 13, 9, 1, 2,  2,  21, 101, '+10 Holy Spell Damage');

-- ============================================================================
-- STEP 3: SpellItemEnchantment entries
-- School damage (90100-90123): EQUIP_SPELL (type 3) → cast custom spell
-- Intellect (90130-90133): STAT (type 5), stat mod 5 (ITEM_MOD_INTELLECT)
-- Spirit (90134-90137): STAT (type 5), stat mod 6 (ITEM_MOD_SPIRIT)
-- ============================================================================

INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `Name_Lang_Mask`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
-- T1 School damage (+3)
(90100, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100040, 0, 0, '+3 Fire Spell Damage',   0, 0, 0, 0, 0, 0, 0, 0),
(90101, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100041, 0, 0, '+3 Frost Spell Damage',  0, 0, 0, 0, 0, 0, 0, 0),
(90102, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100042, 0, 0, '+3 Nature Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90103, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100043, 0, 0, '+3 Shadow Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90104, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100044, 0, 0, '+3 Arcane Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90105, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100045, 0, 0, '+3 Holy Spell Damage',   0, 0, 0, 0, 0, 0, 0, 0),
-- T2 School damage (+5)
(90106, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100046, 0, 0, '+5 Fire Spell Damage',   0, 0, 0, 0, 0, 0, 0, 0),
(90107, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100047, 0, 0, '+5 Frost Spell Damage',  0, 0, 0, 0, 0, 0, 0, 0),
(90108, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100048, 0, 0, '+5 Nature Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90109, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100049, 0, 0, '+5 Shadow Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90110, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100050, 0, 0, '+5 Arcane Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90111, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100051, 0, 0, '+5 Holy Spell Damage',   0, 0, 0, 0, 0, 0, 0, 0),
-- T3 School damage (+7)
(90112, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100052, 0, 0, '+7 Fire Spell Damage',   0, 0, 0, 0, 0, 0, 0, 0),
(90113, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100053, 0, 0, '+7 Frost Spell Damage',  0, 0, 0, 0, 0, 0, 0, 0),
(90114, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100054, 0, 0, '+7 Nature Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90115, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100055, 0, 0, '+7 Shadow Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90116, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100056, 0, 0, '+7 Arcane Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90117, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100057, 0, 0, '+7 Holy Spell Damage',   0, 0, 0, 0, 0, 0, 0, 0),
-- T4 School damage (+10)
(90118, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100058, 0, 0, '+10 Fire Spell Damage',   0, 0, 0, 0, 0, 0, 0, 0),
(90119, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100059, 0, 0, '+10 Frost Spell Damage',  0, 0, 0, 0, 0, 0, 0, 0),
(90120, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100060, 0, 0, '+10 Nature Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90121, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100061, 0, 0, '+10 Shadow Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90122, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100062, 0, 0, '+10 Arcane Spell Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90123, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100063, 0, 0, '+10 Holy Spell Damage',   0, 0, 0, 0, 0, 0, 0, 0),
-- Intellect (STAT type 5, mod 5)
(90130, 0, 5, 0, 0, 3,  0, 0, 3,  0, 0, 5, 0, 0, '+3 Intellect',   0, 0, 0, 0, 0, 0, 0, 0),
(90131, 0, 5, 0, 0, 6,  0, 0, 6,  0, 0, 5, 0, 0, '+6 Intellect',   0, 0, 0, 0, 0, 0, 0, 0),
(90132, 0, 5, 0, 0, 9,  0, 0, 9,  0, 0, 5, 0, 0, '+9 Intellect',   0, 0, 0, 0, 0, 0, 0, 0),
(90133, 0, 5, 0, 0, 12, 0, 0, 12, 0, 0, 5, 0, 0, '+12 Intellect',  0, 0, 0, 0, 0, 0, 0, 0),
-- Spirit (STAT type 5, mod 6)
(90134, 0, 5, 0, 0, 3,  0, 0, 3,  0, 0, 6, 0, 0, '+3 Spirit',   0, 0, 0, 0, 0, 0, 0, 0),
(90135, 0, 5, 0, 0, 6,  0, 0, 6,  0, 0, 6, 0, 0, '+6 Spirit',   0, 0, 0, 0, 0, 0, 0, 0),
(90136, 0, 5, 0, 0, 9,  0, 0, 9,  0, 0, 6, 0, 0, '+9 Spirit',   0, 0, 0, 0, 0, 0, 0, 0),
(90137, 0, 5, 0, 0, 12, 0, 0, 12, 0, 0, 6, 0, 0, '+12 Spirit',  0, 0, 0, 0, 0, 0, 0, 0);
