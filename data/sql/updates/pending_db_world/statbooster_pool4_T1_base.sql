-- ============================================================================
-- Fortune Pool T1 — Base DBC + custom spells + proc data (iLvl 1-25)
-- Source: .claude/statBoosterItems/pools/fortune_pool/fortune_T1.md
-- Self-contained: uses REPLACE INTO for idempotent apply.
-- Apply order: this file first, then statbooster_pool4_T1.sql (template rows).
-- ============================================================================

-- ── Enchant DBC (spellitemenchantment_dbc) for all 30 enchants used by T1 ──
REPLACE INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `Name_Lang_Mask`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(90001, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 22586, 0, 0, '+5% Movement Speed', 0, 0, 0, 0, 0, 0, 0, 0),
(90003, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 10665, 0, 0, 'Water Walk', 0, 0, 0, 0, 0, 0, 0, 0),
(90004, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 8747, 0, 0, '+15% Swim Speed', 0, 0, 0, 0, 0, 0, 0, 0),
(90005, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 48777, 0, 0, '+3% Mounted Speed', 0, 0, 0, 0, 0, 0, 0, 0),
(90007, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 58985, 0, 0, 'Stealth Detect', 0, 0, 0, 0, 0, 0, 0, 0),
(90008, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18677, 0, 0, '+6 All Magic Resist', 0, 0, 0, 0, 0, 0, 0, 0),
(90010, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21348, 0, 0, '+6 HP5 in Combat', 0, 0, 0, 0, 0, 0, 0, 0),
(90012, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 25063, 0, 0, '+2% Threat', 0, 0, 0, 0, 0, 0, 0, 0),
(90013, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 23172, 0, 0, '+20 Block Value', 0, 0, 0, 0, 0, 0, 0, 0),
(90015, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9332, 0, 0, '+22 Attack Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90018, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 25070, 0, 0, '-4% Threat', 0, 0, 0, 0, 0, 0, 0, 0),
(90019, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9416, 0, 0, '+11 Spell Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90022, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21361, 0, 0, '+4 Mana per 5', 0, 0, 0, 0, 0, 0, 0, 0),
(90026, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20555, 0, 0, '+10% Health Regen Rate', 0, 0, 0, 0, 0, 0, 0, 0),
(90029, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20599, 0, 0, '+10% Reputation Gain', 0, 0, 0, 0, 0, 0, 0, 0),
(90030, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100025, 0, 0, 'Thorns (3 damage)', 0, 0, 0, 0, 0, 0, 0, 0),
(90034, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 10729, 0, 0, 'Feather Fall', 0, 0, 0, 0, 0, 0, 0, 0),
(90036, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 9782, 0, 0, '+16 Damage on Hit', 0, 0, 0, 0, 0, 0, 0, 0),
(90040, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 43929, 0, 0, 'Fiery Weapon', 0, 0, 0, 0, 0, 0, 0, 0),
(90041, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 20004, 0, 0, 'Lifestealing', 0, 0, 0, 0, 0, 0, 0, 0),
(90050, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18764, 0, 0, '+3 HP Periodic Heal', 0, 0, 0, 0, 0, 0, 0, 0),
(90051, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 12896, 0, 0, '+5 Damage Shield', 0, 0, 0, 0, 0, 0, 0, 0),
(90052, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 34343, 0, 0, '+5 Melee Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90053, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9784, 0, 0, '+7 Melee Damage', 0, 0, 0, 0, 0, 0, 0, 0),
(90054, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21592, 0, 0, '+3 HP5 in Combat', 0, 0, 0, 0, 0, 0, 0, 0),
(90055, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18673, 0, 0, '+2 All Magic Resist', 0, 0, 0, 0, 0, 0, 0, 0),
(90075, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 100018, 0, 0, 'Arcane Burst', 0, 0, 0, 0, 0, 0, 0, 0),
(90077, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100020, 0, 0, 'Water Breathing', 0, 0, 0, 0, 0, 0, 0, 0),
(90082, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 100028, 0, 0, 'Immolate', 0, 0, 0, 0, 0, 0, 0, 0),
(90086, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100032, 0, 0, 'Blood Pact', 0, 0, 0, 0, 0, 0, 0, 0);

-- ── Custom server spells used by T1 enchants ──
REPLACE INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `EquippedItemClass`, `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`, `EffectMiscValue_1`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `EffectRadiusIndex_1`, `SchoolMask`, `SpellIconID`, `SpellVisualID_1`, `Name_Lang_enUS`) VALUES
(100018, 0, 0, 0, 0, 0, 0, 0, 0, 1, -1, 2, 15, 19, 0, 0, 17, 15, 13, 64, 12, 6950, 'Arcane Burst'),
(100020, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 0, 0, 82, 0, 1, 0, 0, 1, 545, 0, 'Water Breathing'),
(100025, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 1, 2, 15, 0, 0, 0, 0, 8, 0, 0, 'Thorns (3 damage)'),
(100028, 65536, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 0, 4, 15, 0, 1, 0, 0, 4, 31, 46, 'Immolate'),
(100032, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 65, 0, 19, 230, 2, 1, 0, 23, 32, 541, 0, 'Blood Pact');

-- ── Weapon proc data for T1 COMBAT_SPELL enchants ──
REPLACE INTO `spell_enchant_proc_data` (`entry`, `customChance`, `PPMChance`, `procEx`, `attributeMask`) VALUES
(90036, 0, 6, 0, 0),
(90040, 0, 6, 0, 0),
(90041, 0, 6, 0, 0),
(90075, 0, 3, 0, 0);
