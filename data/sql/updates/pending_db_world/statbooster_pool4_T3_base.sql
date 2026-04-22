-- ============================================================================
-- Fortune Pool T3 — Base DBC + custom spells + proc data (iLvl 46-65)
-- Source: .claude/statBoosterItems/pools/fortune_pool/fortune_T3.md
-- Self-contained: uses REPLACE INTO for idempotent apply.
-- Apply order: this file first, then statbooster_pool4_T3.sql (template rows).
-- ============================================================================

-- ── Enchant DBC (spellitemenchantment_dbc) for all 35 enchants used by T3 ──
REPLACE INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `Name_Lang_Mask`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(90002, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 22587, 0, 0, '+8% Movement Speed', 0, 0, 0, 0, 0, 0, 0, 0),
(90003, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 10665, 0, 0, 'Water Walk', 0, 0, 0, 0, 0, 0, 0, 0),
(90004, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 8747, 0, 0, '+15% Swim Speed', 0, 0, 0, 0, 0, 0, 0, 0),
(90005, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 48777, 0, 0, '+3% Mounted Speed', 0, 0, 0, 0, 0, 0, 0, 0),
(90007, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 58985, 0, 0, 'Stealth Detect', 0, 0, 0, 0, 0, 0, 0, 0),
(90009, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18681, 0, 0, '+10 All Magic Resist', 0, 0, 0, 0, 0, 0, 0, 0),
(90011, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21349, 0, 0, '+10 HP5 in Combat', 0, 0, 0, 0, 0, 0, 0, 0),
(90012, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 25063, 0, 0, '+2% Threat', 0, 0, 0, 0, 0, 0, 0, 0),
(90014, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 23515, 0, 0, '+27 Block Value', 0, 0, 0, 0, 0, 0, 0, 0),
(90016, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9336, 0, 0, '+30 Attack Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90017, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 14049, 0, 0, '+40 Attack Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90018, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 25070, 0, 0, '-4% Threat', 0, 0, 0, 0, 0, 0, 0, 0),
(90020, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 14248, 0, 0, '+21 Spell Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90021, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 14055, 0, 0, '+35 Spell Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90023, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21363, 0, 0, '+6 Mana per 5', 0, 0, 0, 0, 0, 0, 0, 0),
(90024, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18686, 0, 0, '+15 All Magic Resist', 0, 0, 0, 0, 0, 0, 0, 0),
(90025, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21350, 0, 0, '+14 HP5 in Combat', 0, 0, 0, 0, 0, 0, 0, 0),
(90026, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20555, 0, 0, '+10% Health Regen Rate', 0, 0, 0, 0, 0, 0, 0, 0),
(90027, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 55357, 0, 0, '-10% Fear Duration', 0, 0, 0, 0, 0, 0, 0, 0),
(90028, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 55358, 0, 0, '-10% Stun Duration', 0, 0, 0, 0, 0, 0, 0, 0),
(90029, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20599, 0, 0, '+10% Reputation Gain', 0, 0, 0, 0, 0, 0, 0, 0),
(90032, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100027, 0, 0, 'Thorns (25 damage)', 0, 0, 0, 0, 0, 0, 0, 0),
(90034, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 10729, 0, 0, 'Feather Fall', 0, 0, 0, 0, 0, 0, 0, 0),
(90037, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 9233, 0, 0, 'Fire Damage Proc', 0, 0, 0, 0, 0, 0, 0, 0),
(90042, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 20005, 0, 0, 'Icy Chill', 0, 0, 0, 0, 0, 0, 0, 0),
(90043, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 20006, 0, 0, 'Unholy Weapon', 0, 0, 0, 0, 0, 0, 0, 0),
(90070, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 44622, 0, 0, 'Lifeward', 0, 0, 0, 0, 0, 0, 0, 0),
(90071, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 54043, 0, 0, 'Deathfrost', 0, 0, 0, 0, 0, 0, 0, 0),
(90073, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 56355, 0, 0, 'Giant Slayer', 0, 0, 0, 0, 0, 0, 0, 0),
(90074, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 100017, 0, 0, 'Arcane Burst', 0, 0, 0, 0, 0, 0, 0, 0),
(90077, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100020, 0, 0, 'Water Breathing', 0, 0, 0, 0, 0, 0, 0, 0),
(90079, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 100022, 0, 0, 'Frost Ring', 0, 0, 0, 0, 0, 0, 0, 0),
(90081, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100024, 0, 0, 'Frost Armor', 0, 0, 0, 0, 0, 0, 0, 0),
(90084, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 100030, 0, 0, 'Immolate', 0, 0, 0, 0, 0, 0, 0, 0),
(90088, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100034, 0, 0, 'Blood Pact', 0, 0, 0, 0, 0, 0, 0, 0);

-- ── Custom server spells used by T3 enchants ──
REPLACE INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `EquippedItemClass`, `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`, `EffectMiscValue_1`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `EffectRadiusIndex_1`, `SchoolMask`, `SpellIconID`, `SpellVisualID_1`, `Name_Lang_enUS`) VALUES
(100017, 0, 0, 0, 0, 0, 0, 0, 0, 1, -1, 2, 40, 79, 0, 0, 17, 15, 13, 64, 12, 6950, 'Arcane Burst'),
(100020, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 0, 0, 82, 0, 1, 0, 0, 1, 545, 0, 'Water Breathing'),
(100022, 0, 0, 0, 0, 0, 0, 0, 0, 1, -1, 2, 25, 54, 0, 0, 17, 15, 13, 16, 193, 17, 'Frost Ring'),
(100024, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 0, 199, 22, 1, 1, 0, 0, 16, 181, 0, 'Frost Armor'),
(100027, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 1, 24, 15, 0, 0, 0, 0, 8, 0, 0, 'Thorns (25 damage)'),
(100030, 65536, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 0, 19, 15, 0, 1, 0, 0, 4, 31, 46, 'Immolate'),
(100034, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 65, 0, 269, 230, 2, 1, 0, 23, 32, 541, 0, 'Blood Pact');

-- ── Weapon proc data for T3 COMBAT_SPELL enchants ──
REPLACE INTO `spell_enchant_proc_data` (`entry`, `customChance`, `PPMChance`, `procEx`, `attributeMask`) VALUES
(90037, 0, 6, 0, 0),
(90042, 0, 1.7, 0, 0),
(90043, 0, 1, 0, 0),
(90070, 0, 6, 0, 0),
(90071, 0, 3, 0, 0),
(90073, 0, 3, 0, 0),
(90074, 0, 3, 0, 0),
(90079, 0, 3, 0, 0);
