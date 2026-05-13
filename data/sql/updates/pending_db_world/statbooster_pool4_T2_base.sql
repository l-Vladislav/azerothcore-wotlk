-- ============================================================================
-- Fortune Pool T2 — Base DBC + custom spells + proc data (iLvl 26-45)
-- Source: .claude/statBoosterItems/pools/fortune_pool/fortune_T2.md
-- Self-contained: uses REPLACE INTO for idempotent apply.
-- Apply order: this file first, then statbooster_pool4_T2.sql (template rows).
-- ============================================================================

-- ── Enchant DBC (spellitemenchantment_dbc) for all 33 enchants used by T2 ──
REPLACE INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `Name_Lang_Mask`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
(90001, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 22586, 0, 0, '+5% Movement Speed', 0, 0, 0, 0, 0, 0, 0, 0),
(90003, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 10665, 0, 0, 'Water Walk', 0, 0, 0, 0, 0, 0, 0, 0),
(90004, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 8747, 0, 0, '+15% Swim Speed', 0, 0, 0, 0, 0, 0, 0, 0),
(90005, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 48777, 0, 0, '+3% Mounted Speed', 0, 0, 0, 0, 0, 0, 0, 0),
(90007, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 58985, 0, 0, 'Stealth Detect', 0, 0, 0, 0, 0, 0, 0, 0),
(90009, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18681, 0, 0, '+10 All Magic Resist', 0, 0, 0, 0, 0, 0, 0, 0),
(90011, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21349, 0, 0, '+10 HP5 in Combat', 0, 0, 0, 0, 0, 0, 0, 0),
(90012, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 25063, 0, 0, '+2% Threat', 0, 0, 0, 0, 0, 0, 0, 0),
(90013, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 23172, 0, 0, '+20 Block Value', 0, 0, 0, 0, 0, 0, 0, 0),
(90015, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9332, 0, 0, '+22 Attack Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90016, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9336, 0, 0, '+30 Attack Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90018, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 25070, 0, 0, '-4% Threat', 0, 0, 0, 0, 0, 0, 0, 0),
(90019, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9416, 0, 0, '+11 Spell Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90020, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 14248, 0, 0, '+21 Spell Power', 0, 0, 0, 0, 0, 0, 0, 0),
(90023, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21363, 0, 0, '+6 Mana per 5', 0, 0, 0, 0, 0, 0, 0, 0),
(90024, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18686, 0, 0, '+15 All Magic Resist', 0, 0, 0, 0, 0, 0, 0, 0),
(90025, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21350, 0, 0, '+14 HP5 in Combat', 0, 0, 0, 0, 0, 0, 0, 0),
(90026, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20555, 0, 0, '+10% Health Regen Rate', 0, 0, 0, 0, 0, 0, 0, 0),
(90029, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20599, 0, 0, '+10% Reputation Gain', 0, 0, 0, 0, 0, 0, 0, 0),
(90031, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100026, 0, 0, 'Thorns (18 damage)', 0, 0, 0, 0, 0, 0, 0, 0),
(90034, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 10729, 0, 0, 'Feather Fall', 0, 0, 0, 0, 0, 0, 0, 0),
(90036, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 9782, 0, 0, '+16 Damage on Hit', 0, 0, 0, 0, 0, 0, 0, 0),
(90037, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 9233, 0, 0, 'Fire Damage Proc', 0, 0, 0, 0, 0, 0, 0, 0),
(90040, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 43929, 0, 0, 'Fiery Weapon', 0, 0, 0, 0, 0, 0, 0, 0),
(90041, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 20004, 0, 0, 'Lifestealing', 0, 0, 0, 0, 0, 0, 0, 0),
(90042, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 20005, 0, 0, 'Icy Chill', 0, 0, 0, 0, 0, 0, 0, 0),
(90043, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 20006, 0, 0, 'Unholy Weapon', 0, 0, 0, 0, 0, 0, 0, 0),
(90076, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 100019, 0, 0, 'Arcane Burst', 0, 0, 0, 0, 0, 0, 0, 0),
(90077, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100020, 0, 0, 'Water Breathing', 0, 0, 0, 0, 0, 0, 0, 0),
(90078, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 100021, 0, 0, 'Frost Ring', 0, 0, 0, 0, 0, 0, 0, 0),
(90081, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100024, 0, 0, 'Frost Armor', 0, 0, 0, 0, 0, 0, 0, 0),
(90083, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 100029, 0, 0, 'Immolate', 0, 0, 0, 0, 0, 0, 0, 0),
(90087, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100033, 0, 0, 'Blood Pact', 0, 0, 0, 0, 0, 0, 0, 0);

-- ── Custom server spells used by T2 enchants ──
-- DurationIndex / ProcChance are CRITICAL: omitting them defaults both to 0,
-- which makes APPLY_AURA effects vanish instantly (DI=0) and the aura get
-- discarded on creation (PC=0). See memory/feedback_spell_dbc_aura_fields.md.
-- Values mirror prod: DI=21,PC=101 for passive auras (Attrs=2147549184),
-- DI=9,PC=101 for Immolate-style refreshable (Attrs=65536),
-- DI=0,PC=0 for direct-damage spells (Effect_1=2 SCHOOL_DAMAGE).
REPLACE INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `EquippedItemClass`, `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`, `EffectMiscValue_1`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `EffectRadiusIndex_1`, `SchoolMask`, `SpellIconID`, `SpellVisualID_1`, `DurationIndex`, `ProcChance`, `Name_Lang_enUS`) VALUES
(100019, 0, 0, 0, 0, 0, 0, 0, 0, 1, -1, 2, 25, 44, 0, 0, 17, 15, 13, 64, 12, 6950, 0, 0, 'Arcane Burst'),
(100020, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 0, 0, 82, 0, 1, 0, 0, 1, 545, 0, 21, 101, 'Water Breathing'),
(100021, 0, 0, 0, 0, 0, 0, 0, 0, 1, -1, 2, 15, 29, 0, 0, 17, 15, 13, 16, 193, 17, 0, 0, 'Frost Ring'),
(100024, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 0, 199, 22, 1, 1, 0, 0, 16, 181, 0, 21, 101, 'Frost Armor'),
(100026, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 1, 17, 15, 0, 0, 0, 0, 8, 0, 0, 21, 101, 'Thorns (18 damage)'),
(100029, 65536, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 0, 11, 15, 0, 1, 0, 0, 4, 31, 46, 9, 101, 'Immolate'),
(100033, 2147549184, 0, 0, 0, 0, 0, 0, 0, 1, -1, 6, 0, 69, 34, 0, 1, 0, 0, 32, 541, 0, 21, 101, 'Blood Pact');

-- ── Weapon proc data for T2 COMBAT_SPELL enchants ──
REPLACE INTO `spell_enchant_proc_data` (`entry`, `customChance`, `PPMChance`, `procEx`, `attributeMask`) VALUES
(90036, 0, 6, 0, 0),
(90037, 0, 6, 0, 0),
(90040, 0, 6, 0, 0),
(90041, 0, 6, 0, 0),
(90042, 0, 1.7, 0, 0),
(90043, 0, 1, 0, 0),
(90076, 0, 3, 0, 0),
(90078, 0, 3, 0, 0);
